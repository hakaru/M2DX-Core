// MarkICalibrationCharacterizationTests.swift
// M2DX-Core — INVESTIGATION harness for audit markI-ops-dac finding 1 (carrier output level).
// Renders ONE pure carrier (alg 32, op0 only — no modulation) at a sweep of output levels for
// Modern vs Mark I and prints the raw-peak gain curve + Mark I/Modern ratio. This decides whether
// finding 1 is a constant 4× offset (constant-shift fixable) or a level-dependent curve divergence.
// Not a pass/fail behavior test. Env-gated (mutates the process-global markIModScaleQ12).
// Run: `M2DX_MARKI_CHAR=1 swift test --filter renderCarrierGainCurve`

import Testing
import Foundation
@testable import M2DXCore

@Suite("Mark I carrier gain-curve characterization (investigation — prints a curve)")
struct MarkICalibrationCharacterizationTests {

    private let sampleRate: Float = 48000
    private let total = 12000          // 0.25 s at 48 kHz — enough for a steady carrier

    /// Render a single pure carrier (alg 32, op0 only) at `carrierLevel` and return the
    /// steady-state raw peak (max |sample| over the post-attack window).
    private func carrierPeak(engine: FMEngine, divisor: Double?, carrierLevel: Float) -> Float {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(engine)
        if let d = divisor { synth.setMarkIModDivisor(d) }

        synth.loadDX7Preset(DX7FactoryPresets.all[0])
        synth.setAlgorithm(32)                                   // all ops parallel carriers (no modulation)
        for op in 0..<6 { synth.setOperatorLevel(op, level: op == 0 ? carrierLevel : 0.0) }
        synth.setOperatorEGLevels(0, l1: 1, l2: 1, l3: 1, l4: 1) // flat sustain = the carrier's full level
        synth.setOperatorEGRates(0, r1: 99, r2: 99, r3: 99, r4: 99) // instant attack/decay -> steady

        let blk = 512
        var pL = [Float](repeating: 0, count: blk), pR = [Float](repeating: 0, count: blk)
        pL.withUnsafeMutableBufferPointer { lp in pR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))

        var outL = [Float](repeating: 0, count: total)
        var outR = [Float](repeating: 0, count: total)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        // Steady-state window: skip the first 2400 samples (50 ms) of attack settling.
        var peak: Float = 0
        for i in 2400..<total { peak = max(peak, abs(outL[i])) }
        return peak
    }

    @Test("Render Modern vs Mark I carrier gain curve")
    func renderCarrierGainCurve() {
        guard ProcessInfo.processInfo.environment["M2DX_MARKI_CHAR"] != nil else {
            print("MarkICalibrationCharacterizationTests skipped — set M2DX_MARKI_CHAR=1 to render the curve")
            return
        }
        defer { SynthEngine().setMarkIModDivisor(8.0) }          // restore process-global default

        let levels: [Float] = [0.1, 0.2, 0.35, 0.5, 0.7, 0.85, 1.0]
        print("level, modernPeak, markIDiv5Peak, ratio(markI/modern)")
        var modernPeaks: [Float] = [], markIPeaks: [Float] = []
        for lv in levels {
            let m = carrierPeak(engine: .modern, divisor: nil, carrierLevel: lv)
            let k = carrierPeak(engine: .markI, divisor: 5.0, carrierLevel: lv)
            modernPeaks.append(m); markIPeaks.append(k)
            let ratio = m > 0 ? k / m : 0
            print(String(format: "%.2f, %.5f, %.5f, %.3f", lv, m, k, ratio))
            // Sanity only — peaks are finite and within the [-1,1] sample range.
            #expect(m.isFinite && k.isFinite)
            #expect(m <= 1.0 && k <= 1.0)
        }
        // Sanity: peak is monotonic non-decreasing in carrier level for both engines.
        for i in 1..<levels.count {
            #expect(modernPeaks[i] >= modernPeaks[i - 1] - 1e-4)
            #expect(markIPeaks[i] >= markIPeaks[i - 1] - 1e-4)
        }
    }

    /// Render the given factory preset (algorithm INTACT — feedback op stays in the
    /// signal path) at a chosen global feedback amount and return the full left buffer.
    private func feedbackRender(_ preset: DX7Preset, engine: FMEngine, divisor: Double?, feedback: Int) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(engine)
        if let d = divisor { synth.setMarkIModDivisor(d) }

        synth.loadDX7Preset(preset)                            // preset's own algorithm kept intact
        synth.setOperatorFeedback(feedback)                    // global feedback (lands on the fb op)

        let blk = 512
        var pL = [Float](repeating: 0, count: blk), pR = [Float](repeating: 0, count: blk)
        pL.withUnsafeMutableBufferPointer { lp in pR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))

        var outL = [Float](repeating: 0, count: total)
        var outR = [Float](repeating: 0, count: total)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return outL
    }

    /// Spectral centroid (Hz) over `range` via a coarse 40 Hz-grid DFT (lower = darker).
    /// Copied verbatim from MarkIDivisorABTests.swift.
    private func centroid(_ samples: [Float], over range: Range<Int>) -> Double {
        let sr = Double(sampleRate)
        let n = range.count
        var numer = 0.0, denom = 0.0, f = 40.0
        while f < 10000.0 {
            var re = 0.0, im = 0.0
            let w = 2.0 * Double.pi * f / sr
            for i in range {
                let s = Double(samples[i]); let p = w * Double(i - range.lowerBound)
                re += s * cos(p); im -= s * sin(p)
            }
            let mag2 = (re * re + im * im) / Double(n * n)
            numer += f * mag2; denom += mag2; f += 40.0
        }
        return denom > 0 ? numer / denom : 0
    }

    // MARK: - DAC A/B helpers

    /// Render the given factory preset with Mark I engine, vintage DAC toggled.
    /// The preset's own algorithm is kept intact (no alg-32 override).
    /// Returns the full left channel buffer.
    private func renderMarkI(_ preset: DX7Preset, dacOn: Bool) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(.markI)
        synth.setVintageDAC(dacOn)

        synth.loadDX7Preset(preset)             // preset's own algorithm kept intact

        let blk = 512
        var pL = [Float](repeating: 0, count: blk), pR = [Float](repeating: 0, count: blk)
        pL.withUnsafeMutableBufferPointer { lp in pR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))

        var outL = [Float](repeating: 0, count: total)
        var outR = [Float](repeating: 0, count: total)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return outL
    }

    /// Minimal 16-bit mono PCM WAV writer (copied verbatim from MarkIDivisorABTests.swift).
    private func writeWAV(_ samples: [Float], sampleRate: Int, to url: URL) throws {
        var data = Data()
        func le32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        let dataSize = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); le32(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); le32(16); le16(1); le16(1)
        le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        data.append(contentsOf: Array("data".utf8)); le32(UInt32(dataSize))
        for s in samples {
            let c = max(-1.0, min(1.0, s))
            le16(UInt16(bitPattern: Int16(c * 32767.0)))
        }
        try data.write(to: url)
    }

    @Test("Render DAC on/off A/B WAVs + coarse render-time delta")
    func renderDACAB() throws {
        guard ProcessInfo.processInfo.environment["M2DX_MARKI_CHAR"] != nil else {
            print("MarkICalibrationCharacterizationTests skipped — set M2DX_MARKI_CHAR=1")
            return
        }
        let dir = URL(fileURLWithPath: "/tmp/m2dx-marki-dac")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // A bright multi-carrier / feedback-bearing patch shows the DAC grit most.
        let preset = DX7FactoryPresets.all.first(where: { $0.feedback > 0 }) ?? DX7FactoryPresets.all[11]
        print("DAC A/B preset: \(preset.name) (feedback=\(preset.feedback), algorithm=\(preset.algorithm))")

        var offElapsed: Double = 0
        var onElapsed: Double = 0
        for dacOn in [false, true] {
            let start = Date()
            let buf = renderMarkI(preset, dacOn: dacOn)
            let elapsed = Date().timeIntervalSince(start)
            if dacOn { onElapsed = elapsed } else { offElapsed = elapsed }
            // Peak-normalize to −3 dBFS so the A/B compares grit/timbre, not loudness.
            let peak = buf.map { abs($0) }.max() ?? 1
            let g = peak > 0 ? (0.707 / peak) : 1
            let norm = buf.map { $0 * g }
            let name = "\(preset.name)_dac\(dacOn ? "on" : "off").wav"
            try writeWAV(norm, sampleRate: Int(sampleRate), to: dir.appendingPathComponent(name))
            print("  Wrote \(dir.appendingPathComponent(name).path)  rawPeak=\(String(format: "%.4f", peak))")
        }
        print(String(format: "Render-time delta (coarse wall-clock on host — NOT a benchmark; measure on-device for RT budget):"))
        print(String(format: "  DAC-off: %.1f ms  DAC-on: %.1f ms  Δ(on−off): %+.1f ms  (%d samples @ %d Hz)",
                     offElapsed * 1000, onElapsed * 1000, (onElapsed - offElapsed) * 1000,
                     total, Int(sampleRate)))
        print("DAC A/B WAVs written to \(dir.path) — on-device listen: does DAC-on add the intended grit, or is it filtered by downsampling?")
    }

    // MARK: - R-sweep DAC A/B

    /// Render the given preset with Mark I engine for `frames` samples.
    /// `dacOn` and the caller-set `kMarkIDACFullScale` are respected.
    private func renderMarkIR(_ preset: DX7Preset, dacOn: Bool, frames: Int) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(.markI)
        synth.setVintageDAC(dacOn)
        synth.loadDX7Preset(preset)

        let blk = 512
        var wL = [Float](repeating: 0, count: blk), wR = [Float](repeating: 0, count: blk)
        wL.withUnsafeMutableBufferPointer { lp in wR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))

        var outL = [Float](repeating: 0, count: frames)
        var outR = [Float](repeating: 0, count: frames)
        outL.withUnsafeMutableBufferPointer { op in outR.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < frames {
                let c = min(blk, frames - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return outL
    }

    /// R-sweep: render three representative Mark I patches at DAC-off plus DAC-on for
    /// R ∈ {2^26, 2^25, 2^24, 2^23} and write peak-normalised (−3 dBFS) WAVs.  Also
    /// prints per-(patch,R) exponent-region engagement counts so we can see how lowering
    /// R shifts more signal into the coarse exponent bands.
    @Test("R-sweep DAC A/B: WAVs at R ∈ {2^26,2^25,2^24,2^23} (#95)")
    func renderDACScaleAB() throws {
        guard ProcessInfo.processInfo.environment["M2DX_MARKI_CHAR"] != nil else {
            print("MarkICalibrationCharacterizationTests skipped — set M2DX_MARKI_CHAR=1")
            return
        }
        // Restore shipping default R regardless of how the test exits.
        defer { kMarkIDACFullScale = Float(1 << 25) }

        let dir = URL(fileURLWithPath: "/tmp/m2dx-marki-dac")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let allPresets = DX7FactoryPresets.all
        // 1. E.PIANO (decay tail): tine decay exposes both fine and coarse exponent regions.
        let ePiano = allPresets.first(where: { $0.name.hasPrefix("E.PIANO") }) ?? allPresets[0]
        // 2. Bell/tine (long quiet decay where the fine 1/16384-step grid matters most).
        let bell = allPresets.first(where: { $0.name == "TINE BELL" })
                ?? allPresets.first(where: { $0.name.contains("BELL") })
                ?? allPresets[1]
        // 3. Bright/sustained with high feedback (brass sustain → coarse exponent engagement).
        let bright = allPresets.first(where: { $0.name == "BRASS" })
                  ?? allPresets.first(where: { $0.name.contains("STRINGS") && $0.feedback > 0 })
                  ?? allPresets.first(where: { $0.feedback > 0 })
                  ?? allPresets[2]

        let patches: [(slug: String, preset: DX7Preset)] = [
            ("epiano", ePiano),
            ("bell",   bell),
            ("bright", bright),
        ]
        let rEntries: [(suffix: String, r: Float)] = [
            ("R2p26", Float(1 << 26)),
            ("R2p25", Float(1 << 25)),
            ("R2p24", Float(1 << 24)),
            ("R2p23", Float(1 << 23)),
        ]
        let renderFrames = 120000   // 2.5 s at 48 kHz — covers attack + long decay tail
        let targetPeak: Float = 0.707   // −3 dBFS peak-normalise

        print("── R-sweep DAC A/B (note 60 vel 100, peak-normalised −3 dBFS) ──")
        print("Patches: \(ePiano.name)  \(bell.name)  \(bright.name)")
        print("  patch      variant    rawPeak  exp1     exp2     exp4     exp8     file")

        for (slug, preset) in patches {
            // DAC-OFF reference
            let offBuf = renderMarkIR(preset, dacOn: false, frames: renderFrames)
            let offPeak = offBuf.map { abs($0) }.max() ?? 1
            let offG = offPeak > 0 ? targetPeak / offPeak : 1
            let offNorm = offBuf.map { $0 * offG }
            let offURL = dir.appendingPathComponent("\(slug)_dacoff.wav")
            try writeWAV(offNorm, sampleRate: Int(sampleRate), to: offURL)
            let sp = slug.padding(toLength: 10, withPad: " ", startingAt: 0)
            print(String(format: "  %@ dacoff     %.4f  —        —        —        —        %@",
                         sp, offPeak, offURL.lastPathComponent))

            // DAC-ON at each R value
            for (suffix, rVal) in rEntries {
                kMarkIDACFullScale = rVal
                let buf = renderMarkIR(preset, dacOn: true, frames: renderFrames)
                let peak = buf.map { abs($0) }.max() ?? 1

                // Approximate pre-compand input level per sample: outL[s] ≈ blockBuf[s] * scale,
                // where scale = masterVol * pL / 2^28 (pL = 0.7071 center pan, masterVol = 1.0).
                // So blockBuf[s] / R ≈ outL[s] * 2^28 / (R * 0.7071).
                // We use 2^28 / R as a close approximation (pL difference only shifts thresholds ~41%).
                let invR: Float = 268435456.0 / rVal
                var cnt1 = 0, cnt2 = 0, cnt4 = 0, cnt8 = 0
                for s in buf {
                    let a = abs(s) * invR
                    if      a > 0.5   { cnt1 += 1 }
                    else if a > 0.25  { cnt2 += 1 }
                    else if a > 0.125 { cnt4 += 1 }
                    else              { cnt8 += 1 }
                }

                let g = peak > 0 ? targetPeak / peak : 1
                let norm = buf.map { $0 * g }
                let url = dir.appendingPathComponent("\(slug)_\(suffix).wav")
                try writeWAV(norm, sampleRate: Int(sampleRate), to: url)
                let sfx = suffix.padding(toLength: 9, withPad: " ", startingAt: 0)
                print(String(format: "  %@ %@  %.4f  %-8d %-8d %-8d %-8d %@",
                             sp, sfx, peak, cnt1, cnt2, cnt4, cnt8, url.lastPathComponent))
            }
        }
        print("── WAVs written to \(dir.path) ──")
    }

    // MARK: - Feedback comparison

    @Test("Render Modern vs Mark I feedback comparison")
    func renderFeedbackComparison() {
        guard ProcessInfo.processInfo.environment["M2DX_MARKI_CHAR"] != nil else {
            print("MarkICalibrationCharacterizationTests skipped — set M2DX_MARKI_CHAR=1 to render the curve")
            return
        }
        defer { SynthEngine().setMarkIModDivisor(8.0) }          // restore process-global default

        // Finding 3 ("Mark I feedback 4× too strong") shows up in BRIGHTNESS more than peak:
        // Mark I re-injects a 4×-larger internal feedback signal → brighter timbre even when
        // rendered level matches. So we measure BOTH peak and spectral centroid and sweep the
        // global feedback. If centroidRatio (and/or peakRatio) grows above ~1 as fb climbs 0→7,
        // finding 3 is real; if both stay ≈1.0, it does not manifest as rendered.
        //
        // Select a preset that ACTUALLY exercises the Mark I feedback-deepening branch:
        // DX7Voice.swift:417 deepens feedback by 2 shifts only for algIndex 3/5/31 (DX7 alg
        // 4/6/32). A hardcoded index is fragile — the existing MarkIDivisorABTests comment
        // "all[11] = E.PIANO 1 (alg 4)" is stale (all[11] is now "TINE BELL", algIndex 6 = DX7
        // alg 7, OUTSIDE the deepened set), so we scan for the first feedback-bearing preset
        // whose algorithm is in the deepened set instead.
        // Prefer a feedback STACK (algIndex 3/5 = DX7 alg 4/6, a modulator→carrier feedback
        // chain — the canonical finding-3 case) over the all-carriers alg 32 (algIndex 31),
        // whose lone self-feedback carrier dilutes the effect. Fall back to any deepened alg.
        let deepened: Set<Int> = [3, 5, 31]
        guard let preset = DX7FactoryPresets.all.first(where: { ($0.algorithm == 3 || $0.algorithm == 5) && $0.feedback > 0 })
            ?? DX7FactoryPresets.all.first(where: { deepened.contains($0.algorithm) && $0.feedback > 0 }) else {
            Issue.record("no feedback-deepened-algorithm preset found in DX7FactoryPresets.all")
            return
        }
        // Feedback-ACTIVE window: DX7 feedback operators are typically fast-decay transients
        // (tine/sparkle), so by the steady-state window (50 ms+) the fb op has decayed and the
        // feedback amount no longer affects output. Measured empirically: for the alg-32 fb
        // preset, the entire fb-0-vs-7 difference lives in the first 2400 samples; the steady
        // tail is identical. So we measure peak + centroid over the attack window where the
        // feedback op (and the Mark I feedback-deepening, DX7Voice.swift:417) actually manifests.
        let window = 0..<2400
        let feedbacks = [0, 4, 7]
        print("feedback-deepened preset: \(preset.name) (algorithm field \(preset.algorithm)); window = attack 0..2400")
        print("fb, modernPeak, markIPeak, peakRatio, modernCentroid, markICentroid, centroidRatio")
        for fb in feedbacks {
            let mBuf = feedbackRender(preset, engine: .modern, divisor: nil, feedback: fb)
            let kBuf = feedbackRender(preset, engine: .markI, divisor: 5.0, feedback: fb)
            // Peak + centroid over the feedback-active attack window.
            var mPeak: Float = 0, kPeak: Float = 0
            for i in window { mPeak = max(mPeak, abs(mBuf[i])); kPeak = max(kPeak, abs(kBuf[i])) }
            let peakRatio = mPeak > 0 ? kPeak / mPeak : 0
            let mCent = centroid(mBuf, over: window)
            let kCent = centroid(kBuf, over: window)
            let centRatio = mCent > 0 ? kCent / mCent : 0
            print(String(format: "%d, %.5f, %.5f, %.3f, %.1f, %.1f, %.3f",
                         fb, mPeak, kPeak, peakRatio, mCent, kCent, centRatio))
            // Sanity only — peaks finite and in range, centroids finite and positive.
            #expect(mPeak.isFinite && kPeak.isFinite)
            #expect(mPeak <= 1.0 && kPeak <= 1.0)
            #expect(mCent.isFinite && kCent.isFinite && mCent > 0 && kCent > 0)
        }
    }
}
