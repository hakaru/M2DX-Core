// ReferenceTests.swift
// M2DX-Core — DEXED msfa reference comparison tests
// Compares M2DX Swift engine functions against DEXED C reference implementations.

import Testing
import Foundation
@testable import M2DXCore
import DX7Ref

@Suite("DEXED Reference Comparison")
struct DX7RefTests {

    // MARK: - 1. ScaleRate (Keyboard Rate Scaling)

    @Test("ScaleRate matches DEXED for all notes × all sensitivities")
    func scaleRateMatchesDEXED() {
        for note: UInt8 in 0...127 {
            for sens: UInt8 in 0...7 {
                let m2dx = keyboardRateScaling(note: note, scaling: sens)
                let dexed = Int(dx7ref_scale_rate(Int32(note), Int32(sens)))
                #expect(m2dx == dexed,
                    "ScaleRate mismatch: note=\(note), sens=\(sens) → M2DX=\(m2dx), DEXED=\(dexed)")
            }
        }
    }

    // MARK: - 2. ScaleVelocity

    @Test("ScaleVelocity matches DEXED for all velocities × all sensitivities")
    func scaleVelocityMatchesDEXED() {
        for vel7 in 0...127 {
            for sens in 0...7 {
                // M2DX uses 16-bit velocity (vel7 << 9)
                let vel16 = UInt16(vel7) << 9
                let m2dx = scaleVelocity(vel16, sens: sens)
                let dexed = Int(dx7ref_scale_velocity(Int32(vel7), Int32(sens)))
                #expect(m2dx == dexed,
                    "ScaleVelocity mismatch: vel=\(vel7), sens=\(sens) → M2DX=\(m2dx), DEXED=\(dexed)")
            }
        }
    }

    // MARK: - 3. ScaleLevel (Keyboard Level Scaling)

    @Test("ScaleLevel matches DEXED for representative parameters")
    func scaleLevelMatchesDEXED() {
        let notes: [UInt8] = [0, 21, 36, 48, 60, 72, 84, 96, 108, 127]
        let breakPoints: [UInt8] = [0, 20, 39, 60, 99]
        let depths: [UInt8] = [0, 25, 50, 75, 99]
        let curves: [UInt8] = [0, 1, 2, 3]  // neg_lin, neg_exp, pos_exp, pos_lin

        for note in notes {
            for bp in breakPoints {
                for depth in depths {
                    for lCurve in curves {
                        for rCurve in curves {
                            let m2dx = scaleKeyboardLevel(
                                note, breakPoint: bp,
                                leftDepth: depth, rightDepth: depth,
                                leftCurve: lCurve, rightCurve: rCurve
                            )
                            let dexed = Int(dx7ref_scale_level(
                                Int32(note), Int32(bp),
                                Int32(depth), Int32(depth),
                                Int32(lCurve), Int32(rCurve)
                            ))
                            #expect(m2dx == dexed,
                                "ScaleLevel mismatch: note=\(note), bp=\(bp), depth=\(depth), lC=\(lCurve), rC=\(rCurve) → M2DX=\(m2dx), DEXED=\(dexed)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3b. ScaleLevel vs REAL Dexed (non-circular golden values)

    @Test("scaleKeyboardLevel matches REAL Dexed ScaleLevel golden values")
    func scaleKeyboardLevelMatchesRealDexedGoldens() {
        // Golden values computed directly from asb2m10/dexed Source/msfa/dx7note.cc
        // ScaleLevel/ScaleCurve: offset = midinote - break_pt - 17; group = (offset+1)/3 (right)
        // or -(offset-1)/3 (left); linear (curve 0/3) = (group*depth*329)>>12; exp (curve 1/2) =
        // (exp_scale_data[min(group,32)]*depth*329)>>15; then `if (curve < 2) scale = -scale`.
        // Curve encoding 0=-LIN, 1=-EXP, 2=+EXP, 3=+LIN. No internal 127 cap (clamped later at
        // the outlevel sum). This is intentionally NOT compared against the C-twin, breaking the
        // circular scaleLevelMatchesDEXED reference.
        // (note, bp, leftDepth, rightDepth, leftCurve, rightCurve) -> expected
        let cases: [(UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, Int)] = [
            (36,  39, 99, 99, 0, 0, -55),  // left  -LIN: roll off below breakpoint (NEGATIVE)
            (108, 39,  0, 99, 0, 2,  38),  // right +EXP: boost above breakpoint (POSITIVE)
            (60,  39, 50, 99, 1, 3,   7),  // right +LIN
            (48,  60, 99, 50, 1, 0, -10),  // left  -EXP
            (56,  39, 99, 99, 2, 2,   0),  // exactly at hinge (break_pt + 17) -> 0
            (100, 39,  0,  0, 2, 2,   0),  // depth 0 -> 0
            (120, 39,  0, 99, 0, 3, 166),  // right +LIN, uncapped (>127 before the outlevel clamp)
            (30,  60, 99,  0, 2, 0,  32),  // left  +EXP: boost below breakpoint
            (24,  39, 99,  0, 0, 0, -87),  // left  -LIN
        ]
        for (note, bp, ld, rd, lc, rc, expected) in cases {
            let result = scaleKeyboardLevel(note, breakPoint: bp, leftDepth: ld, rightDepth: rd,
                                            leftCurve: lc, rightCurve: rc)
            #expect(result == expected,
                "scaleKeyboardLevel(\(note), bp:\(bp), L:\(ld), R:\(rd), lC:\(lc), rC:\(rc)) = \(result), expected real-Dexed \(expected)")
        }
    }

    // MARK: - 4. scaleOutputLevel

    @Test("scaleOutputLevel matches DEXED for all OL values (0-99)")
    func scaleOutputLevelMatchesDEXED() {
        for ol in 0...99 {
            let m2dx = scaleOutputLevel(ol)
            let dexed = Int(dx7ref_scale_outlevel(Int32(ol)))
            #expect(m2dx == dexed,
                "scaleOutputLevel mismatch: OL=\(ol) → M2DX=\(m2dx), DEXED=\(dexed)")
        }
    }

    // MARK: - 4b. Operator detune (frequency-dependent, #96)

    @Test("Operator detune is frequency-dependent, matching DEXED dx7ref_osc_freq (#96)")
    func detuneMatchesDexedFrequencyDependent() {
        let notes: [UInt8] = [24, 36, 48, 60, 69, 84, 96, 108]   // C1 … C8
        let detunes = [0, 1, 4, 7, 10, 13, 14]                   // DX7 param 0-14 (7 = center)
        for note in notes {
            let freq = kMIDIFreqLUT[Int(note)]
            for d in detunes {
                // M2DX production detune (cents) via the per-note factor used at note-on.
                let factor = dexedDetuneFactor(freq, detuneCents: Float(d - 7))
                let m2dxCents = log2(Double(factor)) * 1200.0
                // DEXED reference: logfreq(detune) − logfreq(center) in cents (ratio mode).
                let lfDet = Double(dx7ref_osc_freq(Int32(note), 0, 0, 0, Int32(d)))
                let lfCtr = Double(dx7ref_osc_freq(Int32(note), 0, 0, 0, 7))
                let refCents = (lfDet - lfCtr) / Double(1 << 24) * 1200.0
                #expect(abs(m2dxCents - refCents) < 0.4,
                    "detune note=\(note) param=\(d): M2DX \(m2dxCents)c vs DEXED \(refCents)c (Δ=\(m2dxCents - refCents))")
            }
        }
        // Frequency-dependence: max detune is much larger in the bass than the treble. The old
        // pitch-independent constant ±7c would give equal values and fail this.
        let bass = abs(log2(Double(dexedDetuneFactor(kMIDIFreqLUT[24], detuneCents: 7))) * 1200)
        let treble = abs(log2(Double(dexedDetuneFactor(kMIDIFreqLUT[108], detuneCents: 7))) * 1200)
        #expect(bass > treble * 2.5, "C1 detune (\(bass)c) should be >2.5× C8 (\(treble)c)")
    }

    @Test("Live param edit on a held note keeps the per-note frequency-dependent detune (#96)")
    func liveEditKeepsPerNoteDetune() {
        var voice = DX7Voice()
        var snap = OperatorSnapshot()
        snap.ratio = 1.0
        snap.detuneCents = 7                        // max detune
        snap.detune = Float(exp2(7.0 / 1200.0))     // the old pitch-independent constant factor
        snap.dx7OutputLevel = 99
        voice.applyParams(snap, opIndex: 0)
        voice.noteOn(24, velocity16: UInt16(100) << 9)   // C1 — large frequency-dependent detune
        let freshFreq = voice.ops.0.frequency
        // Simulate a live param edit on the held note (snapshot version bump → applyParams on all voices).
        voice.applyParams(snap, opIndex: 0)
        let editedFreq = voice.ops.0.frequency
        #expect(abs(editedFreq - freshFreq) < 0.001,
                "live edit must keep the per-note detune (fresh=\(freshFreq), edited=\(editedFreq))")
    }

    // MARK: - 5. Exp2 Lookup

    @Test("exp2 lookup matches DEXED for representative input values")
    func exp2LookupMatchesDEXED() {
        // Test a range of meaningful input values
        // Typical range: EG level (0 to ~4096<<16) minus 14*(1<<24)
        let testValues: [Int32] = [
            0,                          // 1.0
            1 << 24,                    // 2.0
            -(1 << 24),                 // 0.5
            -(14 << 24),               // very quiet (typical min)
            2 << 24,                    // 4.0
            -(2 << 24),                // 0.25
            (1 << 23),                  // sqrt(2)
            -(1 << 23),                // 1/sqrt(2)
            -(10 << 24),              // very quiet
            -(5 << 24),               // quiet
            3 << 24,                    // 8.0
        ]

        for x in testValues {
            let m2dx = exp2LookupQ24(x)
            let dexed = dx7ref_exp2_lookup(x)
            #expect(m2dx == dexed,
                "exp2 mismatch: x=\(x) → M2DX=\(m2dx), DEXED=\(dexed)")
        }
    }

    @Test("exp2 lookup matches DEXED across wide range")
    func exp2LookupWideRange() {
        // Sweep across the useful range in steps
        var x: Int32 = -(14 << 24)
        while x <= (4 << 24) {
            let m2dx = exp2LookupQ24(x)
            let dexed = dx7ref_exp2_lookup(x)
            #expect(m2dx == dexed,
                "exp2 mismatch: x=\(x) → M2DX=\(m2dx), DEXED=\(dexed)")
            x += (1 << 20)  // step by 1/16 of an octave
        }
    }

    // MARK: - 6. EG inc Computation

    @Test("EG advance inc matches DEXED for all rate × rateScaling combinations")
    func egIncMatchesDEXED() {
        for rate in 0...99 {
            for rs in 0...31 {
                // M2DX computation (same logic as advance())
                var qrate = (rate * 41) >> 6
                qrate = min(63, qrate + rs)
                let m2dxInc = (4 + (qrate & 3)) << (8 + (qrate >> 2))

                let dexedInc = Int(dx7ref_eg_compute_inc(Int32(rate), Int32(rs)))
                #expect(m2dxInc == dexedInc,
                    "EG inc mismatch: rate=\(rate), rs=\(rs) → M2DX=\(m2dxInc), DEXED=\(dexedInc)")
            }
        }
    }

    // MARK: - 7. EG Level Trace (E.PIANO1)

    @Test("EG level trace matches DEXED for E.PIANO1 OP1")
    func egLevelTraceEPiano1() {
        // E.PIANO1 OP1 (carrier): R1=96 R2=25 R3=25 R4=67, L1=99 L2=75 L3=0 L4=0
        // OL=99, KRS=3, note=60
        let rates = [96, 25, 25, 67]
        let levels = [99, 75, 0, 0]
        let ol = 99
        let krs = Int(dx7ref_scale_rate(60, 3))

        // Setup DEXED reference EG
        var refEg = dx7ref_eg_t()
        var cRates = rates.map { Int32($0) }
        var cLevels = levels.map { Int32($0) }
        dx7ref_eg_init(&refEg, &cRates, &cLevels, Int32(ol), Int32(krs))
        dx7ref_eg_note_on(&refEg)

        // Setup M2DX EG
        var m2dxEg = DX7Envelope()
        m2dxEg.setRates(rates[0], rates[1], rates[2], rates[3])
        m2dxEg.setLevels(levels[0], levels[1], levels[2], levels[3])
        m2dxEg.setOutputLevel(ol)
        m2dxEg.rateScaling = krs
        // Use default srMultiplier (1<<24 = 44100Hz, no correction needed)
        m2dxEg.noteOn()

        // Run for 3000 blocks (~4.4 seconds at 44.1kHz) and compare
        let totalBlocks = 3000
        var mismatches = 0
        var firstMismatchBlock = -1
        for block in 0..<totalBlocks {
            let refLevel = dx7ref_eg_getsample(&refEg)
            let m2dxLevel = m2dxEg.getsample()

            if refLevel != m2dxLevel {
                mismatches += 1
                if firstMismatchBlock < 0 {
                    firstMismatchBlock = block
                }
            }
        }

        #expect(mismatches == 0,
            "EG trace: \(mismatches)/\(totalBlocks) blocks differ, first at block \(firstMismatchBlock)")
    }

    @Test("EG level trace matches DEXED for E.PIANO1 OP1 with note-off")
    func egLevelTraceEPiano1WithRelease() {
        let rates = [96, 25, 25, 67]
        let levels = [99, 75, 0, 0]
        let ol = 99
        let krs = Int(dx7ref_scale_rate(60, 3))

        var refEg = dx7ref_eg_t()
        var cRates = rates.map { Int32($0) }
        var cLevels = levels.map { Int32($0) }
        dx7ref_eg_init(&refEg, &cRates, &cLevels, Int32(ol), Int32(krs))
        dx7ref_eg_note_on(&refEg)

        var m2dxEg = DX7Envelope()
        m2dxEg.setRates(rates[0], rates[1], rates[2], rates[3])
        m2dxEg.setLevels(levels[0], levels[1], levels[2], levels[3])
        m2dxEg.setOutputLevel(ol)
        m2dxEg.rateScaling = krs
        m2dxEg.noteOn()

        // Run 500 blocks, then note-off, then 2000 more blocks
        var mismatches = 0
        for _ in 0..<500 {
            let refLevel = dx7ref_eg_getsample(&refEg)
            let m2dxLevel = m2dxEg.getsample()
            if refLevel != m2dxLevel { mismatches += 1 }
        }

        dx7ref_eg_note_off(&refEg)
        m2dxEg.noteOff()

        for _ in 0..<2000 {
            let refLevel = dx7ref_eg_getsample(&refEg)
            let m2dxLevel = m2dxEg.getsample()
            if refLevel != m2dxLevel { mismatches += 1 }
        }

        #expect(mismatches == 0,
            "EG trace with release: \(mismatches)/2500 blocks differ")
    }

    // MARK: - 8. Algorithm Flags

    @Test("Algorithm flags match DEXED for all 32 algorithms")
    func algorithmFlagsMatchDEXED() {
        for alg in 1...32 {
            var dexedFlags: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0)
            withUnsafeMutablePointer(to: &dexedFlags) { ptr in
                ptr.withMemoryRebound(to: UInt8.self, capacity: 6) { buf in
                    let result = dx7ref_get_algorithm_flags(Int32(alg), buf)
                    #expect(result == 0, "dx7ref_get_algorithm_flags failed for alg \(alg)")
                }
            }

            let m2dxFlags = kAlgorithmFlags[alg - 1]
            #expect(m2dxFlags.0 == dexedFlags.0 &&
                    m2dxFlags.1 == dexedFlags.1 &&
                    m2dxFlags.2 == dexedFlags.2 &&
                    m2dxFlags.3 == dexedFlags.3 &&
                    m2dxFlags.4 == dexedFlags.4 &&
                    m2dxFlags.5 == dexedFlags.5,
                "Algorithm \(alg) flags mismatch: M2DX=(\(m2dxFlags.0),\(m2dxFlags.1),\(m2dxFlags.2),\(m2dxFlags.3),\(m2dxFlags.4),\(m2dxFlags.5)) DEXED=(\(dexedFlags.0),\(dexedFlags.1),\(dexedFlags.2),\(dexedFlags.3),\(dexedFlags.4),\(dexedFlags.5))")
        }
    }
}
