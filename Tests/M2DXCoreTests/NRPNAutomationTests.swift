// NRPNAutomationTests.swift
// #67 Phase 1: render-thread-safe synth-param automation via MIDI 2.0 NRPN
// (assignable controllers). The AUv3 render handler converts host automation for the
// ~163 non-FX synth params into NRPN MIDIEvents and pushes them on the lock-free
// `sendMIDI` ring (producer==consumer==render in the AUv3), where `doNRPN` applies them
// audio-locally — never touching the main-thread `shadowSnapshot`/`snapshotRing` producer.
import Testing
@testable import M2DXCore

@Suite("NRPN Parameter Automation (#67)")
struct NRPNAutomationTests {

    /// Build an operator NRPN assignable-controller event (#67): bank = operator index (0–5),
    /// index = the AUv3 `Operator` offset, value = signed 16.8 fixed point in the low 24 bits.
    private func nrpnOp(_ op: UInt8, _ offset: UInt8, _ value: Float) -> MIDIEvent {
        let v24 = UInt32(bitPattern: Int32((value * 256).rounded())) & 0x00FFFFFF
        return MIDIEvent(kind: .assignableController, data1: op, data2: (UInt32(offset) << 24) | v24)
    }

    private func render(_ e: SynthEngine, frames: Int = 64) {
        let L = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer { L.deallocate(); R.deallocate() }
        e.render(into: L, bufferR: R, frameCount: frames)
    }

    @Test("NRPN operator output level updates the render-thread snapshot (no main-thread setter)")
    func nrpnSetsOperatorLevel() {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(nrpnOp(0, 0, 50))
        render(e)
        #expect(e.debugCurrentSnapshot.ops.0.dx7OutputLevel == 50)
    }

    @Test("NRPN routes every operator param kind to its snapshot field (signed 16.8 value)")
    func nrpnOperatorParams() {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(nrpnOp(0, 1, 3.5))     // ratio (continuous)
        e.sendMIDI(nrpnOp(1, 2, -3))      // detune cents (signed), op 1
        e.sendMIDI(nrpnOp(2, 7, 5))       // velocity sensitivity, op 2
        e.sendMIDI(nrpnOp(0, 9, 4))       // keyboard rate scaling
        e.sendMIDI(nrpnOp(0, 10, 80))     // EG rate 1
        e.sendMIDI(nrpnOp(0, 23, 60))     // EG level 4
        e.sendMIDI(nrpnOp(3, 30, 45))     // KLS break point, op 3
        e.sendMIDI(nrpnOp(3, 33, 2))      // KLS left curve, op 3
        e.sendMIDI(nrpnOp(0, 5, 12))      // fixed-freq coarse
        render(e)
        let s = e.debugCurrentSnapshot
        #expect(abs(s.ops.0.ratio - 3.5) < 0.01)
        #expect(abs(s.ops.1.detuneCents - (-3)) < 0.01)
        #expect(s.ops.1.detune < 1.0)                 // negative cents → factor < 1
        #expect(s.ops.2.velocitySensitivity == 5)
        #expect(s.ops.0.keyboardRateScaling == 4)
        #expect(s.ops.0.dx7EgR0 == 80)
        #expect(s.ops.0.dx7EgL3 == 60)
        #expect(s.ops.3.klsBreakPoint == 45)
        #expect(s.ops.3.klsLeftCurve == 2)
        #expect(s.ops.0.fixedFreqCoarse == 12)
    }

    /// Any-group NRPN event: bank + index + signed 16.8 value.
    private func nrpn(_ bank: UInt8, _ index: UInt8, _ value: Float) -> MIDIEvent {
        let v24 = UInt32(bitPattern: Int32((value * 256).rounded())) & 0x00FFFFFF
        return MIDIEvent(kind: .assignableController, data1: bank, data2: (UInt32(index) << 24) | v24)
    }

    @Test("NRPN routes global / LFO / PitchEG / controller params to their snapshot fields")
    func nrpnGroupParams() {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(nrpn(64, 0, 7))      // global algorithm
        e.sendMIDI(nrpn(64, 2, 5))      // global feedback (op0)
        e.sendMIDI(nrpn(64, 4, -5))     // performance transpose (signed)
        e.sendMIDI(nrpn(65, 0, 40))     // LFO speed
        e.sendMIDI(nrpn(65, 5, 3))      // LFO waveform
        e.sendMIDI(nrpn(66, 0, 70))     // PitchEG rate 1
        e.sendMIDI(nrpn(66, 10, 88))    // PitchEG level 1
        e.sendMIDI(nrpn(67, 0, 50))     // mod-wheel pitch
        e.sendMIDI(nrpn(67, 11, 30))    // foot amp
        e.sendMIDI(nrpn(67, 32, 99))    // aftertouch EG bias
        render(e)
        let s = e.debugCurrentSnapshot
        #expect(s.slots.0.algorithm == 7)
        #expect(abs(s.ops.0.feedback - 5.0 / 7.0) < 0.01)
        #expect(s.transpose == -5)
        #expect(s.slots.0.lfoSpeed == 40)
        #expect(s.slots.0.lfoWaveform == 3)
        #expect(s.slots.0.pitchEGR0 == 70)
        #expect(s.slots.0.pitchEGL0 == 88)
        #expect(s.slots.0.wheelPitch == 50)
        #expect(s.slots.0.footAmp == 30)
        #expect(s.slots.0.aftertouchEGBias == 99)
    }

    @Test("doNRPN clamps out-of-range values to each param's range")
    func nrpnClamps() {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(nrpnOp(0, 0, 999))     // level → 99
        e.sendMIDI(nrpnOp(1, 7, 50))      // velocity sensitivity → 7
        e.sendMIDI(nrpnOp(2, 0, -10))     // level → 0
        e.sendMIDI(nrpn(64, 4, 99))       // transpose → 24
        e.sendMIDI(nrpn(64, 4, -99))      // (overwrite) transpose → -24
        render(e)
        let s = e.debugCurrentSnapshot
        #expect(s.ops.0.dx7OutputLevel == 99)
        #expect(s.ops.1.velocitySensitivity == 7)
        #expect(s.ops.2.dx7OutputLevel == 0)
        #expect(s.transpose == -24)
    }

    /// Render a held middle-C past attack + gain smoothing and return the peak |sample|,
    /// optionally driving every operator's output level to 0 via NRPN host automation first.
    private func playPeak(automateSilence: Bool) -> Float {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: 100 << 9))
        if automateSilence {
            for op in UInt8(0)..<6 { e.sendMIDI(nrpnOp(op, 0, 0)) }
        }
        let L = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let R = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { L.deallocate(); R.deallocate() }
        var pk: Float = 0
        // Measure ONLY the final block: the level-0 change smooths in over a few blocks via the
        // gain de-zipper, so an all-blocks peak would just capture the attack transient. By block
        // 31 the de-zip has settled while the (sustaining) default note still rings in the control.
        for blk in 0..<32 {
            e.render(into: L, bufferR: R, frameCount: 64)
            if blk == 31 { for i in 0..<64 { pk = max(pk, abs(L[i]), abs(R[i])) } }
        }
        return pk
    }

    @Test("NRPN automation reaches the voices: level-0 on every operator silences a held note")
    func nrpnSilencesNote() {
        let control = playPeak(automateSilence: false)
        let silenced = playPeak(automateSilence: true)
        #expect(control > 0.001, "sanity: a default note should produce output (got \(control))")
        // A >10× drop is unambiguous silencing; the small residual is the gain de-zipper still
        // settling at the measured block (operators are at level 0 → effectively muted).
        #expect(silenced < control * 0.1,
                "NRPN level-0 on all operators must silence the note via the render-thread apply (got \(silenced) vs control \(control))")
    }
}
