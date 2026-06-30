// PitchEGTests.swift
// M2DX-Core — DX7 Pitch EG fidelity vs DEXED PitchEnv (pitchenv.cc). #93
// The Pitch EG had no reference twin and no non-default coverage; this closes that gap.

import Testing
@testable import M2DXCore

@Suite("DX7 Pitch EG (#93)")
struct PitchEGTests {

    /// Steady pitch (semitones) for an all-equal-levels EG that instantly sits at `level`.
    private func steadySemitones(_ level: UInt8) -> Float {
        var eg = PitchEG()
        eg.noteOn(r0: 99, r1: 99, r2: 99, r3: 99,
                  l0: level, l1: level, l2: level, l3: level, sampleRate: 44100)
        eg.process(sampleRate: 44100)
        return eg.semitones
    }

    @Test("Level→pitch is the non-linear DEXED pitchenv_tab, not a linear ramp")
    func nonLinearCurve() {
        // DEXED pitchenv_tab[70] = 20 → 20 × 0.375 st ≈ 7.5 st. The old linear formula
        // ((level−50)/49×48) gave 19.6 st — ~2.6× too sensitive mid-range.
        #expect(abs(steadySemitones(70) - 7.5) < 0.3, "level 70 → ~7.5 st (pitchenv_tab), not 19.6 (linear)")
        #expect(abs(steadySemitones(50) - 0.0) < 0.02, "level 50 → 0 st (center)")
        #expect(abs(steadySemitones(99) - 47.6) < 0.6, "level 99 → ~47.6 st (max)")
        #expect(abs(steadySemitones(0) - (-48.0)) < 0.6, "level 0 → ~−48 st (min)")
    }

    @Test("Pitch EG starts at L4 (not L1) — DEXED level rotation")
    func startsAtL4() {
        // L1=99, L2=L3=L4=50, slow R1. DEXED seeds at L4 (=50 → 0 st) and ramps UP toward L1.
        // The old code seeded at L1 (=99 → ~48 st).
        var eg = PitchEG()
        eg.noteOn(r0: 30, r1: 99, r2: 99, r3: 99,
                  l0: 99, l1: 50, l2: 50, l3: 50, sampleRate: 44100)
        #expect(abs(eg.semitones) < 1.0,
                "pitch EG must START at L4=50 (≈0 st), not L1=99 (≈48 st)")
    }

    @Test("Pitch EG sustains at L3 while held, releases toward L4 on note-off")
    func sustainAtL3ReleaseToL4() {
        // L1=L2=99, L3=60, L4=50. Held: should settle/sustain at L3 (60 → >0 st). After
        // note-off: should head toward L4 (50 → 0 st).
        var eg = PitchEG()
        eg.noteOn(r0: 99, r1: 99, r2: 99, r3: 30,
                  l0: 99, l1: 99, l2: 60, l3: 50, sampleRate: 44100)
        for _ in 0..<200 { eg.process(sampleRate: 44100) }   // settle into sustain
        let sustain = eg.semitones
        #expect(sustain > 1.0, "held pitch EG should sustain at L3=60 (>0 st), got \(sustain)")
        eg.noteOff(sampleRate: 44100)
        for _ in 0..<5000 { eg.process(sampleRate: 44100) }  // release toward L4
        #expect(abs(eg.semitones) < 1.0, "after release should approach L4=50 (≈0 st), got \(eg.semitones)")
    }
}
