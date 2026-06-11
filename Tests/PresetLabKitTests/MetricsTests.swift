import Testing
import Foundation
@testable import PresetLabKit

@Suite("Preset metrics math")
struct MetricsTests {
    let sr: Float = 48000

    func sine(_ hz: Float, seconds: Float, amp: Float = 0.5) -> [Float] {
        (0..<Int(seconds * sr)).map { amp * sin(2 * .pi * hz * Float($0) / sr) }
    }

    @Test("peak and RMS of a 0.5-amp sine")
    func peakAndRMS() {
        let x = sine(440, seconds: 1)
        #expect(abs(Metrics.peakDBFS(x) - (-6.02)) < 0.1)
        let rms = Metrics.rmsDBFS(x[24000..<48000])
        #expect(abs(rms - (-9.03)) < 0.1)   // sine RMS = amp/√2
    }

    @Test("spectral centroid of a pure sine sits at its frequency")
    func centroid() {
        let x = sine(440, seconds: 1)
        let c = Metrics.spectralCentroidHz(x[0..<8192], sampleRate: sr)
        #expect(abs(c - 440) < 15)
    }

    @Test("attack time of a linear 100ms ramp is ~80ms (10%→90%)")
    func attack() {
        let rampLen = Int(0.1 * sr)
        var x = (0..<rampLen).map { Float($0) / Float(rampLen) * 0.8 }
        x += [Float](repeating: 0.8, count: Int(0.4 * sr))
        let a = Metrics.attackMs(x, sampleRate: sr)
        #expect(abs(a - 80) < 12)
    }

    @Test("release tail finds the -60dBFS point after noteOff")
    func release() {
        var x = [Float](repeating: 0.5, count: 48000)          // 1s sustain
        let tail = Int(0.5 * sr)                               // 500ms exp decay
        x += (0..<tail).map { 0.5 * exp(-9.21 * Float($0) / Float(tail)) } // -80dB over tail
        x += [Float](repeating: 0, count: 24000)
        let ms = Metrics.releaseTailMs(x, noteOffSample: 48000, sampleRate: sr)
        #expect(ms > 250 && ms < 500)                          // -60dB ≈ 75% of an -80dB tail
    }

    @Test("sparkle index: noisy attack vs pure sustain is > 1")
    func sparkle() {
        var rng = SystemRandomNumberGenerator()
        let attack = (0..<8192).map { _ in Float.random(in: -0.4...0.4, using: &rng) }
        let sustain = sine(440, seconds: 0.3)
        let s = Metrics.sparkleIndex(attack: attack[0..<8192], sustain: sustain[0..<8192], sampleRate: sr)
        #expect(s > 1.5)
    }

    @Test("flags: NaN, clip, silence")
    func flags() {
        #expect(Metrics.flags([0.5, .nan, 0.1]).nan)
        #expect(Metrics.flags([1.2, 0.1]).clipped)
        #expect(Metrics.flags([Float](repeating: 0.00005, count: 1000)).silent)
    }
}
