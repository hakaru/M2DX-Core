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

    /// NRPN assignable-controller event for an operator output level (#67 Phase 1):
    /// bank = operator index (0–5), index = 0 (output level), value = level (0–99) in the low 24 bits.
    private func nrpnOpLevel(op: UInt8, level: UInt32) -> MIDIEvent {
        MIDIEvent(kind: .assignableController, data1: op, data2: (UInt32(0) << 24) | (level & 0x00FFFFFF))
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
        e.sendMIDI(nrpnOpLevel(op: 0, level: 50))
        render(e)
        #expect(e.debugCurrentSnapshot.ops.0.dx7OutputLevel == 50)
    }

    /// Render a held middle-C past attack + gain smoothing and return the peak |sample|,
    /// optionally driving every operator's output level to 0 via NRPN host automation first.
    private func playPeak(automateSilence: Bool) -> Float {
        let e = SynthEngine(); e.setSampleRate(48000)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: 100 << 9))
        if automateSilence {
            for op in UInt8(0)..<6 { e.sendMIDI(nrpnOpLevel(op: op, level: 0)) }
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
