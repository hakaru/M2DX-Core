// Downsampler.swift
// M2DX-Core — 2x oversampling with FIR decimation using Accelerate vDSP

import Foundation
import Accelerate

// MARK: - Downsampler

/// Real-time safe stereo 2x downsampler using vDSP.
///
/// `@unchecked Sendable`: all mutable state is accessed exclusively from the audio render thread.
package final class Downsampler: @unchecked Sendable {

    private let hqTaps: Int = 31
    private let hqCoeffs: UnsafeMutablePointer<Float>
    private let hqTailL: UnsafeMutablePointer<Float>
    private let hqTailR: UnsafeMutablePointer<Float>

    private let lcTaps: Int = 15
    private let lcCoeffs: UnsafeMutablePointer<Float>
    private let lcTailL: UnsafeMutablePointer<Float>
    private let lcTailR: UnsafeMutablePointer<Float>

    private let kMaxOversampledFrames = 2048
    let oversampledL: UnsafeMutablePointer<Float>
    let oversampledR: UnsafeMutablePointer<Float>

    private var crossfadeRemaining: Int = 0
    private var crossfadeLength: Int = 0

    init() {
        hqCoeffs = Self.computeHalfbandLowpass(taps: 31, kaiserBeta: 6.0)
        let hqTailSize = 30
        hqTailL = .allocate(capacity: hqTailSize)
        hqTailR = .allocate(capacity: hqTailSize)
        hqTailL.initialize(repeating: 0, count: hqTailSize)
        hqTailR.initialize(repeating: 0, count: hqTailSize)

        lcCoeffs = Self.computeHalfbandLowpass(taps: 15, kaiserBeta: 4.0)
        let lcTailSize = 14
        lcTailL = .allocate(capacity: lcTailSize)
        lcTailR = .allocate(capacity: lcTailSize)
        lcTailL.initialize(repeating: 0, count: lcTailSize)
        lcTailR.initialize(repeating: 0, count: lcTailSize)

        oversampledL = .allocate(capacity: kMaxOversampledFrames)
        oversampledR = .allocate(capacity: kMaxOversampledFrames)
        oversampledL.initialize(repeating: 0, count: kMaxOversampledFrames)
        oversampledR.initialize(repeating: 0, count: kMaxOversampledFrames)
    }

    deinit {
        hqCoeffs.deallocate()
        hqTailL.deallocate(); hqTailR.deallocate()
        lcCoeffs.deallocate()
        lcTailL.deallocate(); lcTailR.deallocate()
        oversampledL.deallocate(); oversampledR.deallocate()
    }

    // MARK: - FIR Coefficient Computation

    private static func computeHalfbandLowpass(taps: Int, kaiserBeta: Double) -> UnsafeMutablePointer<Float> {
        let buf = UnsafeMutablePointer<Float>.allocate(capacity: taps)
        let M = Double(taps - 1) / 2.0
        let i0Beta = besselI0(kaiserBeta)
        var dcSum: Double = 0

        for n in 0..<taps {
            let nm = Double(n) - M
            let h: Double
            if abs(nm) < 1e-10 { h = 0.5 }
            else { h = sin(Double.pi * 0.5 * nm) / (Double.pi * nm) }
            let ratio = nm / M
            let arg = max(0.0, 1.0 - ratio * ratio)
            let w = besselI0(kaiserBeta * sqrt(arg)) / i0Beta
            let coeff = h * w
            buf[n] = Float(coeff)
            dcSum += coeff
        }

        if abs(dcSum) > 1e-10 {
            let scale = Float(1.0 / dcSum)
            for n in 0..<taps { buf[n] *= scale }
        }
        return buf
    }

    private static func besselI0(_ x: Double) -> Double {
        var sum = 1.0; var term = 1.0
        for k in 1...25 {
            let half = x / (2.0 * Double(k))
            term *= half * half; sum += term
        }
        return sum
    }

    // MARK: - Mode Transition

    func beginTransition(sampleRate: Float) {
        hqTailL.initialize(repeating: 0, count: hqTaps - 1)
        hqTailR.initialize(repeating: 0, count: hqTaps - 1)
        lcTailL.initialize(repeating: 0, count: lcTaps - 1)
        lcTailR.initialize(repeating: 0, count: lcTaps - 1)
        let fadeSamples = Int(sampleRate * 0.005)
        crossfadeLength = max(fadeSamples, 1)
        crossfadeRemaining = crossfadeLength
    }

    func applyCrossfade(bufferL: UnsafeMutablePointer<Float>,
                        bufferR: UnsafeMutablePointer<Float>,
                        frameCount: Int) {
        guard crossfadeRemaining > 0 else { return }
        let fadeFrames = min(crossfadeRemaining, frameCount)
        let invLength = 1.0 / Float(crossfadeLength)
        for i in 0..<fadeFrames {
            let t = Float(crossfadeRemaining - i) * invLength
            let gain = 1.0 - 0.3 * sinf(t * .pi)
            bufferL[i] *= gain; bufferR[i] *= gain
        }
        crossfadeRemaining -= fadeFrames
    }

    // MARK: - Downsample (High Quality)

    func downsampleHalfband(
        srcL: UnsafePointer<Float>, srcR: UnsafePointer<Float>,
        dstL: UnsafeMutablePointer<Float>, dstR: UnsafeMutablePointer<Float>,
        oversampledCount: Int, outputCount: Int
    ) {
        downsampleDirect(
            srcL: srcL, srcR: srcR, dstL: dstL, dstR: dstR,
            oversampledCount: oversampledCount, outputCount: outputCount,
            coeffs: hqCoeffs, taps: hqTaps, tailL: hqTailL, tailR: hqTailR
        )
    }

    // MARK: - Downsample (Low CPU)

    func downsamplePolyphase(
        srcL: UnsafePointer<Float>, srcR: UnsafePointer<Float>,
        dstL: UnsafeMutablePointer<Float>, dstR: UnsafeMutablePointer<Float>,
        oversampledCount: Int, outputCount: Int
    ) {
        downsampleDirect(
            srcL: srcL, srcR: srcR, dstL: dstL, dstR: dstR,
            oversampledCount: oversampledCount, outputCount: outputCount,
            coeffs: lcCoeffs, taps: lcTaps, tailL: lcTailL, tailR: lcTailR
        )
    }

    // MARK: - Core FIR Decimation

    private func downsampleDirect(
        srcL: UnsafePointer<Float>, srcR: UnsafePointer<Float>,
        dstL: UnsafeMutablePointer<Float>, dstR: UnsafeMutablePointer<Float>,
        oversampledCount: Int, outputCount: Int,
        coeffs: UnsafeMutablePointer<Float>, taps: Int,
        tailL: UnsafeMutablePointer<Float>, tailR: UnsafeMutablePointer<Float>
    ) {
        let tailSize = taps - 1

        for i in 0..<outputCount {
            let newest = i * 2 + 1
            var sumL: Float = 0; var sumR: Float = 0
            for k in 0..<taps {
                let srcIdx = newest - k
                let sL: Float; let sR: Float
                if srcIdx >= 0 {
                    sL = srcL[srcIdx]; sR = srcR[srcIdx]
                } else {
                    let tailIdx = tailSize + srcIdx
                    sL = tailL[tailIdx]; sR = tailR[tailIdx]
                }
                sumL += sL * coeffs[k]; sumR += sR * coeffs[k]
            }
            dstL[i] = sumL; dstR[i] = sumR
        }

        let tailStart = oversampledCount - tailSize
        for i in 0..<tailSize {
            tailL[i] = srcL[tailStart + i]; tailR[i] = srcR[tailStart + i]
        }
    }
}
