// CodeReviewRegressionTests.swift
// M2DX-Core — Regression tests for the 2026-05-31 full code-review bug fixes.

import Testing
import Darwin
import Foundation
@testable import M2DXCore

@Suite("Code Review Regression Fixes")
struct CodeReviewRegressionTests {

    // H1: pitchBendFactorExt previously clamped its ±12-semitone LUT, silently
    // compressing Pitch EG (±48) and RPN coarse tuning (±64) to ±1 octave.
    @Test("pitchBendFactorExt is accurate beyond ±12 semitones")
    func pitchBendFactorExtBeyondOctave() {
        // +24 st = 2 octaves = factor 4.0 (used to clamp to 2.0)
        let f24 = pitchBendFactorExt(24.0)
        #expect(abs(f24 - 4.0) < 0.02, "pitchBendFactorExt(24) should be ~4.0, got \(f24)")
        // +48 st = DX7 Pitch EG max = factor 16.0 (used to clamp to ~2.0)
        let f48 = pitchBendFactorExt(48.0)
        #expect(abs(f48 - 16.0) < 0.1, "pitchBendFactorExt(48) should be ~16.0, got \(f48)")
        // -24 st = factor 0.25 (used to clamp to 0.5)
        let fm24 = pitchBendFactorExt(-24.0)
        #expect(abs(fm24 - 0.25) < 0.01, "pitchBendFactorExt(-24) should be ~0.25, got \(fm24)")
        // In-range value must stay accurate (LUT fast path)
        let f2 = pitchBendFactorExt(2.0)
        #expect(abs(f2 - powf(2.0, 2.0 / 12.0)) < 0.005, "in-range factor preserved, got \(f2)")
    }

    // H4: setTimbreMode's `activeSlotCount..<slotCount` loop trapped with
    // "Range requires lowerBound <= upperBound" when shrinking slot count.
    @Test("setTimbreMode shrinking slot count does not crash")
    func setTimbreModeShrinkDoesNotCrash() {
        let engine = SynthEngine()
        engine.setTimbreMode(.tx816)          // activeSlotCount -> 8
        engine.setTimbreMode(.single)         // 8 -> 1  (was 8..<1 trap)
        engine.setTimbreMode(.dual)           // 1 -> 2
        engine.setTimbreMode(.split, splitPoint: 60)
        engine.setTimbreMode(.single)         // 2 -> 1
        #expect(Bool(true), "reached here without trapping")
    }

    // H2: parse(data:) indexed with absolute offsets but guarded on the relative
    // `count`, so a Data slice with nonzero startIndex passed the guard then
    // trapped on data[0] / subdata(in:). It must parse such a slice, not crash.
    @Test("SysEx parse handles a Data slice with nonzero startIndex")
    func parseHandlesNonZeroStartIndexSlice() {
        var bank = Data(count: 4104)
        bank[0] = 0xF0; bank[1] = 0x43
        bank[3] = 0x09; bank[4] = 0x20; bank[5] = 0x00
        bank[4103] = 0xF7
        // Carve the 4104-byte bank out of a larger buffer so the slice's
        // startIndex is 3, not 0.
        let big = Data([1, 2, 3]) + bank
        let slice = big[3...]
        #expect(slice.startIndex == 3, "precondition: slice is not zero-based")
        #expect(slice.count == 4104, "precondition: relative count matches")

        let result = DX7SysExParser.parse(data: slice, bankName: "slice-test")
        #expect(result != nil, "sliced bank should parse, not crash")
        #expect(result?.presets.count == 32, "32 voices expected")
    }

    // H3: at low base sample rates srMultiplier inflates `inc`, and the attack
    // step `Int32(...)` narrowing (non-wrapping) trapped on the render thread.
    // It must use wrapping semantics (matching the C reference) and not crash.
    @Test("Envelope attack does not trap at low sample rates")
    func envelopeAttackNoTrapAtLowSampleRate() {
        for sr in [Float(8000), 11025, 4000] {
            var env = DX7Envelope()
            env.setRates(99, 99, 99, 99)   // fastest attack -> qrate clamps to 63
            env.setLevels(99, 99, 99, 0)
            env.setOutputLevel(99)
            env.setSampleRate(sr)
            env.noteOn()
            for _ in 0..<32 { _ = env.getsample() }
        }
        #expect(Bool(true), "reached here without trapping")
    }

    // MARK: - MEDIUM

    // M3: fixedFreqHz used 10^(coarse/10)*(1+fine/100); DX7 uses the low 2 bits of
    // coarse as the decade and fine as a base-10 mantissa: 10^((coarse&3)+fine/100).
    @Test("fixedFreqHz matches the DX7 decade + log-mantissa formula")
    func fixedFreqHzFormula() {
        #expect(abs(fixedFreqHz(coarse: 0, fine: 0) - 1.0) < 0.001, "coarse0 -> 1Hz")
        #expect(abs(fixedFreqHz(coarse: 1, fine: 0) - 10.0) < 0.01, "coarse1 -> 10Hz")
        #expect(abs(fixedFreqHz(coarse: 2, fine: 0) - 100.0) < 0.1, "coarse2 -> 100Hz")
        #expect(abs(fixedFreqHz(coarse: 3, fine: 0) - 1000.0) < 1.0, "coarse3 -> 1000Hz")
        // fine is log-domain: coarse0,fine50 -> 10^0.5 ≈ 3.1623
        #expect(abs(fixedFreqHz(coarse: 0, fine: 50) - 3.16228) < 0.01, "fine is base-10 mantissa")
        // coarse wraps to its low 2 bits: 5 (0b101) -> decade 1 -> 10Hz
        #expect(abs(fixedFreqHz(coarse: 5, fine: 0) - 10.0) < 0.01, "coarse low 2 bits select decade")
    }

    // M4: setSampleRate stored its raw argument; sr=0/NaN/<0 propagated to the
    // render thread where Int(inc)/Int64(...) trapped. It must validate.
    @Test("setSampleRate with invalid values does not trap the render thread")
    func setSampleRateValidation() {
        let n = 64
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)

        let engine = SynthEngine()
        for badRate in [Float(0), .nan, -44100, .infinity] {
            engine.setSampleRate(badRate)
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
            engine.render(into: L, bufferR: R, frameCount: n)  // would trap pre-fix
        }
        #expect(Bool(true), "reached here without trapping")
    }

    // M1: CC7 (channel volume) wrote the render-local masterVolume, which line ~697
    // overwrites from the snapshot on any version bump — so a later UI param change
    // discarded the MIDI volume. CC7 must survive a subsequent parameter change.
    @Test("CC7 channel volume survives a subsequent parameter change")
    func cc7VolumeSurvivesParamChange() {
        let n = 256
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)

        func energy() -> Float {
            var e: Float = 0
            for i in 0..<n { e += abs(L[i]) }
            return e
        }

        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setMasterVolume(0.8)
        engine.render(into: L, bufferR: R, frameCount: n)   // apply params

        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(110) << 9))
        engine.render(into: L, bufferR: R, frameCount: n)   // note sounding at full volume
        let baseline = energy()
        #expect(baseline > 0.0001, "control: patch should be audible (baseline=\(baseline))")

        // CC7 -> channel volume 0 (silence)
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 7, data2: 0))
        engine.render(into: L, bufferR: R, frameCount: n)

        // Unrelated UI parameter change -> bumps version -> snapshot apply path.
        engine.setTranspose(1)
        engine.render(into: L, bufferR: R, frameCount: n)
        let afterParamChange = energy()

        #expect(afterParamChange < baseline * 0.05,
                "CC7 volume must persist after a param change (baseline=\(baseline), after=\(afterParamChange))")
    }

    // M2: keyboard rate scaling was not applied to the attack-stage EG increment
    // at note-on (computed before rateScaling was set, with no recompute). A high
    // note with high keyboardRateScaling must attack faster than with none.
    @Test("Keyboard rate scaling is applied to the attack stage at note-on")
    func keyboardRateScalingAppliedToAttack() {
        let n = 256
        func earlyEnergy(keyboardRateScaling ks: UInt8) -> Float {
            let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
            let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
            defer { L.deallocate(); R.deallocate() }
            L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)

            let engine = SynthEngine()
            engine.setSampleRate(44100)
            engine.setAlgorithm(31)   // alg 32: all six operators are carriers
            for op in 0..<6 {
                engine.setOperatorDX7OutputLevel(op, level: 99)
                engine.setOperatorDX7EGRates(op, r1: 40, r2: 99, r3: 99, r4: 50) // moderate attack
                engine.setOperatorDX7EGLevels(op, l1: 99, l2: 99, l3: 99, l4: 0)
                engine.setOperatorRatio(op, ratio: 1.0)
                engine.setOperatorKeyboardRateScaling(op, value: ks)
            }
            engine.render(into: L, bufferR: R, frameCount: n)   // apply params

            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 120, data2: UInt32(110) << 9))
            engine.render(into: L, bufferR: R, frameCount: n)   // first 256 frames of attack
            var e: Float = 0
            for i in 0..<n { e += abs(L[i]) }
            return e
        }

        let e0 = earlyEnergy(keyboardRateScaling: 0)
        let e7 = earlyEnergy(keyboardRateScaling: 7)
        #expect(e7 > e0 * 5,
                "high keyboard rate scaling must speed up the attack (e0=\(e0), e7=\(e7))")
    }

    // MARK: - LOW

    /// Build a structurally valid 4104-byte 32-voice bulk dump (correct framing,
    /// format ID, and checksum). `mutateVoice` may set voice-data bytes [6,4102)
    /// before the checksum is computed.
    private func makeValidBank(_ mutateVoice: (inout [UInt8]) -> Void = { _ in }) -> Data {
        var b = [UInt8](repeating: 0, count: 4104)
        b[0] = 0xF0; b[1] = 0x43; b[2] = 0x00
        b[3] = 0x09; b[4] = 0x20; b[5] = 0x00
        b[4103] = 0xF7
        mutateVoice(&b)
        var sum = 0
        for i in 6..<4102 { sum = (sum + Int(b[i])) & 0x7F }
        b[4102] = UInt8((128 - sum) & 0x7F)
        return Data(b)
    }

    // L12: setOperatorFeedback(_ fb: Int) did not clamp; fb>9 produced a negative
    // feedback shift (a left shift) and garbage output. fb=10 must behave as fb=7.
    @Test("setOperatorFeedback(Int) clamps to 0...7")
    func setOperatorFeedbackIntClamps() {
        let n = 256
        func energy(feedback fb: Int) -> Float {
            let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
            let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
            defer { L.deallocate(); R.deallocate() }
            L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)
            let engine = SynthEngine()
            engine.setAlgorithm(0)                 // alg 1: OP6 is the feedback op
            engine.setOperatorDX7OutputLevel(0, level: 99)  // opIdx 0 == OP6
            engine.setOperatorFeedback(fb)
            engine.render(into: L, bufferR: R, frameCount: n)
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(110) << 9))
            engine.render(into: L, bufferR: R, frameCount: n)
            var e: Float = 0
            for i in 0..<n { e += abs(L[i]) }
            return e
        }
        let e7 = energy(feedback: 7)
        let e10 = energy(feedback: 10)   // out of range; should clamp to 7
        #expect(abs(e10 - e7) < max(e7, 1e-6) * 0.001,
                "fb=10 must clamp to fb=7 (e7=\(e7), e10=\(e10))")
    }

    // L5: updateFreq did an unguarded Double->Int conversion that traps on a
    // non-finite operator frequency (e.g. ratio set to infinity).
    @Test("updateFreq does not trap on a non-finite operator frequency")
    func updateFreqNonFiniteGuard() {
        let n = 64
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)
        let engine = SynthEngine()
        engine.setOperatorRatio(0, ratio: .infinity)
        engine.render(into: L, bufferR: R, frameCount: n)   // apply params
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        engine.render(into: L, bufferR: R, frameCount: n)   // doNoteOn -> updateFreq (would trap)
        #expect(Bool(true), "reached here without trapping")
    }

    // L9: parser propagated raw 0-255 bytes for fields whose DX7 range is 0-99.
    @Test("SysEx parser clamps out-of-range operator parameters")
    func sysExParamClamp() {
        // OP6 (raw operator index 0) klsBreakPoint byte = 6 + 0*128 + 0*17 + 8 = 14
        let data = makeValidBank { $0[14] = 200 }
        let bank = DX7SysExParser.parse(data: data, bankName: "clamp")
        #expect(bank != nil)
        let op6 = bank?.presets.first?.operators[5]   // operators[5] == OP6 after reverse
        #expect((op6?.klsBreakPoint ?? 0) <= 99,
                "klsBreakPoint should be clamped to <=99, got \(op6?.klsBreakPoint ?? -1)")
    }

    // L7: the checksum was never validated.
    @Test("SysEx parser rejects an invalid checksum")
    func sysExChecksumRejected() {
        #expect(DX7SysExParser.parse(data: makeValidBank(), bankName: "ok") != nil,
                "control: a valid bank parses")
        var corrupt = makeValidBank()
        corrupt[4102] = corrupt[4102] &+ 1
        #expect(DX7SysExParser.parse(data: corrupt, bankName: "bad") == nil,
                "a corrupted checksum must be rejected")
    }

    // L8: the format/byte-count ID bytes were never validated.
    @Test("SysEx parser rejects a non-32-voice-bulk format ID")
    func sysExFormatIdRejected() {
        let wrongFormat = makeValidBank { $0[3] = 0x00 }   // 0x00 = single voice, not 0x09
        #expect(DX7SysExParser.parse(data: wrongFormat, bankName: "wrongfmt") == nil)
    }

    // L10: per-operator feedback fields must sit on each algorithm's actual
    // feedback operator (the one kAlgorithmFlags marks with the 0xC0 bits).
    @Test("Factory presets place per-operator feedback on the algorithm's feedback operator")
    func presetFeedbackOnCorrectOperator() {
        func feedbackOpNumber(algo0: Int) -> Int? {
            let f = kAlgorithmFlags[max(0, min(31, algo0))]
            let elems = [f.0, f.1, f.2, f.3, f.4, f.5]   // index 0=OP6 .. 5=OP1
            for j in 0..<6 where (elems[j] & 0xC0) == 0xC0 { return 6 - j }
            return nil
        }
        for preset in DX7FactoryPresets.all {
            guard let fbOp = feedbackOpNumber(algo0: preset.algorithm) else { continue }
            for (i, op) in preset.operators.enumerated() where op.feedback != 0 {
                #expect(i + 1 == fbOp,
                        "\(preset.name) (alg \(preset.algorithm + 1)): per-op feedback on OP\(i + 1) but feedback operator is OP\(fbOp)")
            }
        }
    }

    // MARK: - Round 2

    // R1: a stolen/reused voice that was held by the sustain pedal kept
    // sustained=true, so a later pedal release cut the new (key-held) note.
    @Test("noteOn clears the sustained flag (voice-steal safety)")
    func noteOnClearsSustained() {
        var v = DX7Voice()
        v.noteOff(held: true)   // held by pedal -> sustained = true
        #expect(v.sustained, "precondition: a held note is sustained")
        v.noteOn(60, velocity16: 0xFE00)
        #expect(!v.sustained, "a reused/stolen voice must not inherit sustained")
    }

    // R8: the Float feedback overload fed log2f into a non-guarded Int() conversion.
    @Test("setOperatorFeedback(Float) does not trap on non-finite input")
    func setOperatorFeedbackFloatNonFinite() {
        let engine = SynthEngine()
        engine.setOperatorFeedback(0, feedback: .nan)
        engine.setOperatorFeedback(0, feedback: .infinity)
        engine.setOperatorFeedback(0, feedback: -5.0)
        #expect(Bool(true), "reached here without trapping")
    }

    // R3: hasPitchMod only checked lfoPMD/modWheel, so breath/foot/aftertouch
    // pitch modulation used alone was silently dropped.
    //
    // The correct DX7 model: controller pitch assignments scale the LFO vibrato
    // DEPTH (added to lfoPMD) rather than adding a static DC pitch offset.
    // With lfoPMD=0 and aftertouchPitch=99 the LFO now oscillates with depth
    // proportional to aftertouch pressure; the test verifies vibrato is present
    // (frequency dips below the unmodulated base) over a 1-second render window.
    @Test("Aftertouch pitch modulation drives LFO vibrato, not a static offset")
    func aftertouchPitchAppliedAlone() {
        let blockSize = 256
        let sr: Float = 44100
        let e = SynthEngine()
        e.setSampleRate(sr)
        e.setAlgorithm(0)       // Alg1: OP1 (opIdx 5) is the output carrier

        // OP1 (opIdx 5) carrier — audible
        e.setOperatorDX7OutputLevel(5, level: 99)
        e.setOperatorDX7EGRates(5, r1: 99, r2: 99, r3: 99, r4: 99)
        e.setOperatorDX7EGLevels(5, l1: 99, l2: 99, l3: 99, l4: 0)
        e.setOperatorRatio(5, ratio: 1.0)
        // All others silent
        for op in 0..<5 { e.setOperatorDX7OutputLevel(op, level: 0) }

        // Fast LFO, lfoPMD=0 (only aftertouch drives pitch depth), high PMS
        e.setLFOSpeed(50)       // ~14 Hz — many cycles in 1 s
        e.setLFOSync(0)         // free-running so phase is not reset on note-on
        e.setLFOPMD(0)
        e.setLFOAMD(0)
        e.setLFOPMS(7)
        e.setLFOWaveform(0)     // triangle −1…+1
        e.setAftertouchPitch(99)

        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        defer { bufL.deallocate(); bufR.deallocate() }

        // Warm-up: let snapshot propagate and LFO spin up before note-on
        for _ in 0..<10 { e.render(into: bufL, bufferR: bufR, frameCount: blockSize) }

        // Establish base frequency with no aftertouch pressure
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        e.render(into: bufL, bufferR: bufR, frameCount: blockSize)

        #expect(e.activeVoiceCount == 1)
        let baseFreq = e.activeVoiceOperatorFreqs(5).first ?? 0

        // Apply max channel pressure (aftertouch) and render ~1 second
        e.sendMIDI(MIDIEvent(kind: .channelPressure, data1: 0, data2: UInt32.max))

        var minFreq: Float = .greatestFiniteMagnitude
        var maxFreq: Float = 0
        let renderBlocks = 187  // ≈ 1.0 s at 44100 Hz / 256 frames
        for _ in 0..<renderBlocks {
            e.render(into: bufL, bufferR: bufR, frameCount: blockSize)
            if let f = e.activeVoiceOperatorFreqs(5).first {
                minFreq = Swift.min(minFreq, f)
                maxFreq = Swift.max(maxFreq, f)
            }
        }

        // Aftertouch-pitch must produce vibrato: freq oscillates BELOW base (negative
        // half of triangle LFO) — the pitch-mod block must be entered (hasPitchMod)
        // and the effect must be bipolar, not a static upward shift.
        #expect(
            minFreq < baseFreq * 0.999,
            "aftertouch->pitch must produce vibrato (pitch dips below base \(baseFreq) Hz); got min=\(minFreq)"
        )
        #expect(
            maxFreq > baseFreq * 1.001,
            "aftertouch->pitch must raise pitch above base \(baseFreq) Hz; got max=\(maxFreq)"
        )
    }

    // R2: resetControllers() must not mutate render-owned voice/controller state
    // from the UI thread. After the deferral fix, loadDX7Preset must still work.
    @Test("loadDX7Preset loads and produces sound (deferred controller reset)")
    func loadDX7PresetStillWorks() {
        let n = 256
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)
        let e = SynthEngine()
        e.setSampleRate(44100)
        e.loadDX7Preset(DX7FactoryPresets.initVoice)
        e.render(into: L, bufferR: R, frameCount: n)     // apply snapshot + consume ctrl reset
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(110) << 9))
        var peak: Float = 0
        for _ in 0..<10 {
            e.render(into: L, bufferR: R, frameCount: n)
            for i in 0..<n { peak = max(peak, abs(L[i])) }
        }
        #expect(peak > 0.001, "preset should load and produce sound, peak=\(peak)")
    }

    // MARK: - Round 3

    // R3-A: loadSlotParams stored ops.0.feedback unvalidated; the render thread's
    // Int(feedback*7+0.5) traps on a non-finite value.
    @Test("loadSlotParams sanitizes non-finite operator feedback")
    func loadSlotParamsFeedbackSanitized() {
        let n = 64
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)
        let e = SynthEngine()
        var slot = SlotSnapshot()
        slot.ops.0.feedback = .nan
        e.loadSlotParams(0, slot: slot)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        e.render(into: L, bufferR: R, frameCount: n)   // version-apply + noteOn would trap
        #expect(Bool(true), "reached here without trapping")
    }

    // R3-C: loadSlotParams stored a negative algorithm; renderBlock indexes
    // kAlgorithmFlags[min(algorithm,31)] which traps on a negative index.
    @Test("loadSlotParams clamps a negative algorithm")
    func loadSlotParamsAlgorithmClamped() {
        let n = 64
        let L = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { L.deallocate(); R.deallocate() }
        L.initialize(repeating: 0, count: n); R.initialize(repeating: 0, count: n)
        let e = SynthEngine()
        var slot = SlotSnapshot()
        slot.algorithm = -1
        e.loadSlotParams(0, slot: slot)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(100) << 9))
        e.render(into: L, bufferR: R, frameCount: n)   // renderBlock kAlgorithmFlags[-1] would trap
        #expect(Bool(true), "reached here without trapping")
    }

    // R3-G: the Float operator setters used unguarded Int(Float) conversions
    // that trap on NaN/Inf/out-of-range (siblings of the round-2 feedback fix).
    @Test("Float operator setters do not trap on non-finite input")
    func floatOperatorSettersNonFinite() {
        let e = SynthEngine()
        e.setOperatorLevel(0, level: .nan)
        e.setOperatorEGRates(0, r1: .nan, r2: .infinity, r3: 1e30, r4: -5)
        e.setOperatorEGLevels(0, l1: .nan, l2: .infinity, l3: 1e30, l4: -1)
        #expect(Bool(true), "reached here without trapping")
    }
}
