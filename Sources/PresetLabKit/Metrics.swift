import Foundation
import Accelerate

public enum Metrics {
    public static func peakDBFS(_ x: some Collection<Float>) -> Float {
        20 * log10(max(x.map(abs).max() ?? 0, 1e-9))
    }

    public static func rmsDBFS(_ x: some Collection<Float>) -> Float {
        guard !x.isEmpty else { return -180 }
        let sum = x.reduce(Float(0)) { $0 + $1 * $1 }
        return 20 * log10(max(sqrt(sum / Float(x.count)), 1e-9))
    }

    /// Magnitude spectrum via vDSP DFT (next power-of-2 ≥ count, Hann window, zero-padded).
    static func magnitudeSpectrum(_ x: ArraySlice<Float>, sampleRate: Float) -> (mags: [Float], hzPerBin: Float) {
        let n = 1 << Int(ceil(log2(Float(max(x.count, 256)))))
        var buf = [Float](repeating: 0, count: n)
        let w = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: x.count, isHalfWindow: false)
        for (i, s) in x.enumerated() { buf[i] = s * w[i] }
        let dft = try! vDSP.DiscreteFourierTransform(count: n, direction: .forward, transformType: .complexComplex, ofType: Float.self)
        let real = buf, imag = [Float](repeating: 0, count: n)
        let (or_, oi) = dft.transform(real: real, imaginary: imag)
        let half = n / 2
        var mags = [Float](repeating: 0, count: half)
        for i in 0..<half { mags[i] = sqrt(or_[i] * or_[i] + oi[i] * oi[i]) }
        return (mags, sampleRate / Float(n))
    }

    public static func spectralCentroidHz(_ x: ArraySlice<Float>, sampleRate: Float) -> Float {
        let (mags, hzPerBin) = magnitudeSpectrum(x, sampleRate: sampleRate)
        let total = mags.reduce(0, +)
        guard total > 1e-6 else { return 0 }
        var acc: Float = 0
        for (i, m) in mags.enumerated() { acc += Float(i) * hzPerBin * m }
        return acc / total
    }

    /// 10%→90% of the absolute peak, scanning a 1ms-hop envelope of 5ms max-windows.
    public static func attackMs(_ x: [Float], sampleRate: Float) -> Float {
        let hop = max(1, Int(sampleRate / 1000)), win = Int(5 * sampleRate / 1000)
        var env: [Float] = []
        var i = 0
        while i < x.count { env.append(x[i..<min(i + win, x.count)].map(abs).max() ?? 0); i += hop }
        let peak = env.max() ?? 0
        guard peak > 0,
              let t90 = env.firstIndex(where: { $0 >= 0.9 * peak }),
              let t10 = env.firstIndex(where: { $0 >= 0.1 * peak }) else { return 0 }
        return Float(max(t90 - t10, 0))   // hop = 1ms ⇒ index delta IS milliseconds
    }

    /// Time from noteOff until 50ms-window RMS stays ≤ -60dBFS.
    public static func releaseTailMs(_ x: [Float], noteOffSample: Int, sampleRate: Float) -> Float {
        let win = Int(0.05 * sampleRate)
        var i = noteOffSample
        while i + win <= x.count {
            if rmsDBFS(x[i..<i + win]) <= -60 { return Float(i - noteOffSample) / sampleRate * 1000 }
            i += win
        }
        return Float(x.count - noteOffSample) / sampleRate * 1000   // never reached -60
    }

    /// Energy above 3kHz in the attack window ÷ same band in the sustain window.
    public static func sparkleIndex(attack: ArraySlice<Float>, sustain: ArraySlice<Float>, sampleRate: Float) -> Float {
        func highBand(_ s: ArraySlice<Float>) -> Float {
            let (mags, hzPerBin) = magnitudeSpectrum(s, sampleRate: sampleRate)
            let lo = Int(3000 / hzPerBin)
            guard lo < mags.count else { return 0 }
            return mags[lo...].reduce(0) { $0 + $1 * $1 }
        }
        let s = highBand(sustain)
        return highBand(attack) / max(s, 1e-9)
    }

    public struct Flags { public let nan: Bool, clipped: Bool, silent: Bool }
    public static func flags(_ x: [Float]) -> Flags {
        Flags(nan: x.contains { $0.isNaN || $0.isInfinite },
              clipped: x.contains { abs($0) > 1.0 },
              silent: peakDBFS(x) < -70)
    }
}
