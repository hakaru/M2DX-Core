// PerformanceTests.swift
// M2DX-Core — Performance tests for DX7 rendering

import Testing
import Foundation
@testable import M2DXCore

@Suite("Performance Tests")
struct PerformanceTests {

    // Wall-clock timing in an unoptimized `swift test` build is not a stable
    // signal: on this machine the same render averages 31–68 ms against the
    // 50 ms bound, and a shared CI runner is noisier still (it turned CI red on
    // 2026-09-15 without any code being slower). The render itself still runs on
    // every CI pass — it is the only 16-voice load in the suite — and is checked
    // for finite output; the timing bound is opt-in via M2DX_PERF, and only
    // means anything in a release build on known hardware.
    @Test("16-voice 512-frame render stays finite (timing bound behind M2DX_PERF)")
    func renderPerformance() {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        engine.setAlgorithm(0)
        engine.setMasterVolume(0.7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 70, r3: 50, r4: 50)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 80, l3: 70, l4: 0)
            engine.setOperatorRatio(i, ratio: Float(i + 1))
        }
        engine.setOperatorFeedback(5)

        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        // Trigger 16 notes
        for n in 0..<16 {
            let note = UInt8(48 + n)
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(0x7F00)))
        }

        // Warm up
        for _ in 0..<10 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }

        // Measure
        let iterations = 100
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let avgMs = (elapsed / Double(iterations)) * 1000.0

        print("  Performance: 16-voice 512-frame render = \(String(format: "%.3f", avgMs))ms average")

        // What CI is allowed to fail on: the 16-voice render must stay finite.
        for i in 0..<frameCount {
            #expect(bufL[i].isFinite, "L[\(i)] is not finite after a 16-voice render")
            #expect(bufR[i].isFinite, "R[\(i)] is not finite after a 16-voice render")
        }

        // At 48kHz, 512 frames = 10.67ms realtime budget. Apple Silicon renders
        // this in < 2ms in release; the 50ms bound below is a safety margin, not
        // a target, and strict numbers belong in Instruments on target hardware.
        guard ProcessInfo.processInfo.environment["M2DX_PERF"] != nil else {
            print("  (timing bound skipped — set M2DX_PERF=1, ideally with -c release, to enforce it)")
            return
        }
        #expect(avgMs < 50.0, "16-voice 512-frame render averaged \(String(format: "%.2f", avgMs))ms, exceeds safety margin")
    }

    @Test("Voice allocation stress: 128 simultaneous voices")
    func voiceAllocationStress() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(0)
        engine.setMasterVolume(0.5)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 80, l3: 60, l4: 0)
        }

        // Trigger notes beyond max voices to test voice stealing
        for n in 0..<128 {
            let note = UInt8(n % 128)
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(0x7F00)))
        }

        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        // Render should not crash even with voice stealing
        for _ in 0..<20 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }

        // Verify output is valid (clipped to [-1, 1])
        for i in 0..<frameCount {
            #expect(bufL[i] >= -1.0 && bufL[i] <= 1.0)
            #expect(bufR[i] >= -1.0 && bufR[i] <= 1.0)
            #expect(!bufL[i].isNaN && !bufR[i].isNaN, "Output should never be NaN")
        }
    }

    @Test("Block render consistency across different frame counts")
    func blockRenderConsistency() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(31)
        engine.setMasterVolume(0.7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
        }

        // Test various frame counts (should handle non-power-of-2)
        let frameCounts = [64, 128, 256, 512, 1024, 100, 333]
        for fc in frameCounts {
            let bufL = UnsafeMutablePointer<Float>.allocate(capacity: fc)
            let bufR = UnsafeMutablePointer<Float>.allocate(capacity: fc)
            defer { bufL.deallocate(); bufR.deallocate() }
            bufL.initialize(repeating: 0, count: fc)
            bufR.initialize(repeating: 0, count: fc)

            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
            engine.render(into: bufL, bufferR: bufR, frameCount: fc)

            // Check no NaN or Inf
            for i in 0..<fc {
                #expect(!bufL[i].isNaN && !bufL[i].isInfinite, "Frame count \(fc): output L[\(i)] invalid")
                #expect(!bufR[i].isNaN && !bufR[i].isInfinite, "Frame count \(fc): output R[\(i)] invalid")
            }

            engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))
            engine.render(into: bufL, bufferR: bufR, frameCount: fc)
        }
    }
}
