import Testing
import M2DXCore
@testable import PresetLabKit

@Suite("Archetype evaluation")
struct ArchetypeTests {
    @Test("every factory preset maps to exactly one archetype")
    func mappingTotal() {
        for p in DX7FactoryPresets.all {
            #expect(Archetype.forPresetName(p.name) != nil, "unmapped: \(p.name)")
        }
    }

    @Test("EP target catches a slow attack")
    func epAttack() {
        var m = PresetMetrics.fixture()      // helper: all-passing EP values
        m.attackMs = 45
        let v = Archetype.ep.violations(m)
        #expect(v.contains { $0.contains("attack") })
    }

    @Test("ORGAN rejects strong velocity response")
    func organVel() {
        var m = PresetMetrics.fixture()
        m.velocityBrightnessDelta = 1.5
        #expect(!Archetype.organ.violations(m).isEmpty)
    }

    @Test("fixture passes all EP targets")
    func fixturePasses() {
        #expect(Archetype.ep.violations(PresetMetrics.fixture()).isEmpty)
    }

    @Test("per-preset base notes: bass C2, MARIMBA/TROMBONE C3, FLUTE/bells C5, default C4")
    func baseNotes() {
        #expect(Archetype.baseNote(for: "FAT BASS") == 36)
        #expect(Archetype.baseNote(for: "MARIMBA") == 48)
        #expect(Archetype.baseNote(for: "TROMBONE") == 48)
        #expect(Archetype.baseNote(for: "FLUTE") == 72)
        #expect(Archetype.baseNote(for: "TINE BELL") == 72)
        #expect(Archetype.baseNote(for: "E.PIANO 1") == 60)
        #expect(Archetype.baseNote(for: "TRUMPET") == 60)
        #expect(Archetype.baseNote(for: "VIBES") == 60)
    }

    @Test("percussive archetypes get the short noteOff")
    func noteOff() {
        #expect(Archetype.bell.noteOffSeconds == 0.15)
        #expect(Archetype.mallet.noteOffSeconds == 0.15)
        #expect(Archetype.ep.noteOffSeconds == 1.5)
        #expect(Archetype.exempt.noteOffSeconds == 1.5)
    }

    @Test("EXEMPT archetype never reports violations")
    func exemptEmpty() {
        var m = PresetMetrics.fixture()
        m.attackMs = 500
        m.velocityBrightnessDelta = 0.5
        #expect(Archetype.exempt.violations(m).isEmpty)
    }

    @Test("unknown preset name maps to nil")
    func unknownNil() {
        #expect(Archetype.forPresetName("NOT A PRESET") == nil)
    }
}

@Suite("PresetReport RMS ladder windows")
struct RMSLadderWindowTests {
    @Test("rmsAt1_5 window does not straddle the 1.5 s noteOff instant")
    func trailingWindowAt1_5() {
        let sr: Float = 48000
        // Constant 0.5 amplitude up to exactly sample 72000 (= 1.5 s @ 48 kHz,
        // the sustained-archetype noteOff instant), then instant silence.
        var x = [Float](repeating: 0.5, count: 72_000)
        x.append(contentsOf: [Float](repeating: 0, count: 24_000)) // out to 2.0 s
        let ladder = PresetReport.rmsLadder(samples: x, sampleRate: sr)
        // RMS of the pre-noteOff region is 0.5 → −6.02 dBFS. A window that
        // straddles noteOff mixes in post-1.5 s silence and reads low
        // (centered 1.45–1.55 s: sqrt(0.125) → ≈ −9.03 dBFS).
        let expected: Float = -6.0206
        #expect(abs(ladder.at1_5 - expected) < 0.2,
                "rmsAt1_5 = \(ladder.at1_5) dBFS, expected \(expected) ± 0.2")
    }
}
