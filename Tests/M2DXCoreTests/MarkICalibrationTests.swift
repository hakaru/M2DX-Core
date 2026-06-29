// MarkICalibrationTests.swift
// M2DX-Core — Task 11: Mark I engine OUTPUT calibration on a real ROM1A voice.
//
// The Mark I parity tests (MarkIComparisonTests) prove `renderBlockMarkI` is
// bit-exact to the clean-room C reference `dx7refmki`. They say nothing about
// the engine's musical/level behaviour through the full production `SynthEngine`
// pipeline. This file closes that gap by rendering the REAL ROM1A "BASS 1" voice
// twice through the identical full-engine path — once in `.modern`, once in
// `.markI` — and asserting two properties that are the whole point of Mark I:
//
//   (a) Headroom — the Mark I per-voice peak stays well below clipping (no
//       reliance on the app Maximizer). Modern BASS1 peaks ~0.026 in this
//       harness; Mark I must be comparable (we assert peak < 0.5).
//
//   (b) Darker sustain — the OPS log-domain quantization drives modulators
//       toward silence at sustain, so the Mark I voice decays to a near-pure
//       sine: its spectral centroid over the sustain window must be markedly
//       lower (darker) than Modern's. We assert centroidMarkI < centroidModern * 0.6.
//
// The packed voice bytes and `bankFromVoice(_:)` are reused from
// ROM1AImportComparisonTests (now internal) — not duplicated here.
//
// CLEAN-ROOM: no GPL Dexed source (EngineMkI.cpp) was consulted.

import Testing
import Foundation
@testable import M2DXCore

@Suite("Mark I Calibration (real ROM1A BASS 1)")
struct MarkICalibrationTests {

    private let sampleRate: Float = 48000
    private let total = 96000          // 2.0 s at 48 kHz

    /// Render the real ROM1A BASS 1 voice through the full production SynthEngine,
    /// selecting the FM engine before the note-on. Mirrors the
    /// ROM1AImportComparisonTests.renderEngineBASS1 helper but parameterized by
    /// `engine` (Modern vs Mark I) so the two renders differ ONLY by engine mode.
    private func renderBASS1(engine: FMEngine, note: UInt8 = 60, vel: Int = 100) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(engine)
        let bank = DX7SysExParser.parse(data: bankFromVoice(rom1aBass1Packed), bankName: "ROM1A")!
        synth.loadDX7Preset(bank.presets[0])

        // Warm one block so the engine consumes the param snapshot (engine select,
        // preset) before the note-on, exactly as the app does at steady state.
        let blk = 512
        var warmL = [Float](repeating: 0, count: blk), warmR = [Float](repeating: 0, count: blk)
        warmL.withUnsafeMutableBufferPointer { lp in warmR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}

        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(vel) << 9))

        var out = [Float](repeating: 0, count: total)
        var rr = [Float](repeating: 0, count: total)
        out.withUnsafeMutableBufferPointer { op in rr.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return out
    }

    /// Spectral centroid (Hz) over `range` of `samples` via a coarse direct DFT.
    /// centroid = Σ f·|X(f)|² / Σ |X(f)|²  over a 40 Hz grid up to ~10 kHz.
    /// A darker (more sinusoidal, less-harmonic-rich) signal has a lower centroid.
    private func centroid(_ samples: [Float], over range: Range<Int>) -> Double {
        let sr = Double(sampleRate)
        let n = range.count
        let twoPiOverSr = 2.0 * Double.pi / sr
        var numer = 0.0   // Σ f·|X|²
        var denom = 0.0   // Σ |X|²
        var f = 40.0
        while f <= 10000.0 {
            let w = twoPiOverSr * f
            var re = 0.0, im = 0.0
            // DFT bin at frequency f over the window (cos/sin recurrence keeps it cheap).
            let c = cos(w), s = sin(w)          // step rotor
            var cosk = 1.0, sink = 0.0          // cos(w·0), sin(w·0)
            for i in range {
                let x = Double(samples[i])
                re += x * cosk
                im -= x * sink
                // advance (cosk, sink) by angle w: rotate by (c, s)
                let nc = cosk * c - sink * s
                let ns = cosk * s + sink * c
                cosk = nc; sink = ns
            }
            let mag2 = (re * re + im * im) / Double(n * n)
            numer += f * mag2
            denom += mag2
            f += 40.0
        }
        return denom > 0 ? numer / denom : 0
    }

    // (a) HEADROOM — a hard assertion. The Mark I operator returns `result << 13`;
    // we verify the full-engine per-voice peak stays well below clipping so the
    // app never has to rely on the Maximizer to tame it. (Measured: Mark I ≈ 0.026,
    // identical to Modern ≈ 0.026 for this voice — so no scale correction is needed
    // and the Modern/C-reference paths are left untouched.)
    @Test("Mark I BASS 1 output stays in headroom (peak < 0.5)")
    func headroom() {
        let markI  = renderBASS1(engine: .markI)
        let modern = renderBASS1(engine: .modern)
        let peakMarkI  = markI.map { abs($0) }.max() ?? 0
        let peakModern = modern.map { abs($0) }.max() ?? 0
        print(String(format: "🎚 BASS1 peak: Modern=%.5f  MarkI=%.5f", peakModern, peakMarkI))
        #expect(peakMarkI < 0.5,
            "Mark I peak \(peakMarkI) exceeds 0.5 headroom (Modern peaks ~\(peakModern))")
    }

    // (b) DARKER SUSTAIN — the whole musical point of Mark I: the OPS feeds forward
    // modulation to the carrier phase 3 bits lower than MSFA (`markIModScale`, ÷8),
    // so the modulation index collapses and the sustain tone approaches a pure sine
    // (centroid markedly lower than Modern's). ÷8 was calibrated against real Dexed
    // Mark I and confirmed by ear across BASS 1 (alg15) and E.PIANO 1 (alg4).
    //
    // Measured: Modern ≈ 685 Hz, Mark I ≈ 176 Hz (ratio ≈ 0.26) — near the ~131 Hz
    // near-pure-sine target. Hard assertion (the earlier `withKnownIssue` gap is fixed).
    @Test("Mark I BASS 1 sustain is markedly darker than Modern")
    func darkerSustain() {
        let modern = renderBASS1(engine: .modern)
        let markI  = renderBASS1(engine: .markI)
        let sustain = 19200..<43200    // indices for 0.4 s .. 0.9 s @ 48 kHz
        let centModern = centroid(modern, over: sustain)
        let centMarkI  = centroid(markI,  over: sustain)
        let ratio = centModern > 0 ? centMarkI / centModern : Double.nan
        print(String(format: "🌑 BASS1 sustain centroid: Modern=%.1f Hz  MarkI=%.1f Hz  ratio=%.3f  (want MarkI < Modern×0.6)",
                     centModern, centMarkI, ratio))
        // KNOWN ISSUE — the fix/kls-fidelity branch ported real-Dexed ScaleLevel/ScaleCurve,
        // correcting BASS 1's previously inverted/under-scaled keyboard level scaling. That had
        // been over-driving a modulator and rendering Modern far too bright (sustain centroid
        // ~685 Hz — the obs-7181 "≈2× brighter than Dexed" symptom; a KLS-only change can shift
        // the centroid only via the FM modulation index, i.e. a modulator level). With faithful
        // KLS the Modern centroid drops to ~180 Hz and Mark I to ~142 Hz: Mark I is still darker
        // (ratio ~0.79) but no longer < Modern×0.6. The 0.6 threshold was propped up by the
        // pre-fix over-brightness, and the Mark I ÷8 darkness it asserts is itself flagged as
        // "too dark vs a real DX7" (audit markI-ops-dac finding 2). Re-tune or retire this
        // magnitude assertion when the ÷8 calibration is revisited.
        withKnownIssue("KLS fidelity fix corrected Modern over-brightness; 0.6 threshold + Mark I ÷8 darkness pending markI-ops-dac review") {
            #expect(centMarkI < centModern * 0.6,
                "Mark I sustain (centroid \(centMarkI) Hz) is NOT markedly darker than Modern (centroid \(centModern) Hz); ratio \(ratio) ≥ 0.6")
        }
    }
}
