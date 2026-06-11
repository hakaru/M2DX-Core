// KeysPresets.swift
// M2DX-Core — Original hand-designed DX7-style key presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. Independent FM-theory derivation
// only; no proprietary patch data was opened, parsed, or referenced while
// generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// KEYS-category preset bank. The E.PIANO family is intentionally
    /// over-represented — it's the patch family the user identified as the
    /// most "DX-like" and the strongest centerpiece of the bank.
    static let keysBatch: [DX7Preset] = [
        /// E.PIANO 1 is a warm Rhodes-style voice built on three independent modulator-carrier pairs.
        /// Algorithm 5 lets OP2 → OP1 hold the fundamental, OP4 → OP3 shape the wooden bar, and OP6 → OP5 add a short tine without cross-contaminating the sustain.
        /// Modulator output levels sit high (84–90) with velocity sensitivity 7, so soft notes render as a near-pure sine and hard notes open up a full FM bark — the velocity-brightness contrast lives entirely in the modulators.
        /// Body modulators keep tall EG sustain shelves (egLevel2 60s) so the bark survives past the strike; the coarse-14 tine modulator decays fast so its sparkle stays in the first few tens of milliseconds.
        /// Carrier egRate1 70–72 gives a ~10 ms hammer onset (the EG steps once per 64-sample block, so rates above ~80 are effectively instant), and carriers stay at velocity sensitivity 1–3 for a moderate loudness swing.
        DX7Preset(
            name: "E.PIANO 1",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate1: 70, egRate2: 58, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 84, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): warm fundamental sustain
                .init(outputLevel: 90, frequencyFine: 3, detune: 7, egRate2: 64, egRate3: 38, egRate4: 76, egLevel2: 68, egLevel3: 32, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): velocity-opened bark
                .init(outputLevel: 92, detune: 8, egRate1: 70, egRate2: 60, egRate3: 34, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): woody midrange body
                .init(outputLevel: 86, frequencyCoarse: 2, detune: 8, egRate2: 66, egRate3: 40, egRate4: 76, egLevel2: 62, egLevel3: 26, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP4 (modulator → OP3): velocity-opened hammer overtone
                .init(outputLevel: 80, detune: 9, egRate1: 72, egRate2: 66, egRate3: 44, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): short metallic tine carrier
                .init(outputLevel: 84, frequencyCoarse: 14, detune: 9, feedback: 3, egRate2: 78, egRate3: 48, egRate4: 76, egLevel2: 22, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): fast-decay coarse-14 tine sparkle
            ],
            category: .keys
        ),

        /// E.PIANO 2 is a bell-tinged Mk II voice using the branched Algorithm 7 layout.
        /// OP2 → OP1 carries the warm body while the OP4 → OP3 branch and OP6 → OP5 → OP3 cascade put a harder struck tine on the secondary carrier.
        /// All modulators run hot (78–88) with velocity sensitivity 6–7, so soft notes collapse toward plain carriers and hard notes open the full bell bark.
        /// The direct body modulators hold tall sustain shelves so the brightness survives the strike window; the high-ratio OP6 driver decays fast for attack-only sparkle.
        /// Carrier egRate1 70 sets a ~10 ms hammer onset; feedback on OP6 supplies the bell edge.
        DX7Preset(
            name: "E.PIANO 2",
            algorithm: 6,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate1: 70, egRate2: 60, egRate3: 38, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 85, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): full fundamental body
                .init(outputLevel: 88, frequencyFine: 4, detune: 7, egRate2: 66, egRate3: 40, egRate4: 77, egLevel2: 65, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): velocity-opened bark
                .init(outputLevel: 92, detune: 8, egRate1: 70, egRate2: 62, egRate3: 37, egRate4: 75, egLevel1: 99, egLevel2: 94, egLevel3: 83, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): bell-tinged secondary body
                .init(outputLevel: 84, frequencyCoarse: 3, detune: 8, egRate2: 68, egRate3: 41, egRate4: 77, egLevel2: 60, egLevel3: 24, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP4 (modulator → OP3): velocity-opened hammer partial
                .init(outputLevel: 78, frequencyCoarse: 2, frequencyFine: 5, detune: 6, egRate2: 68, egRate3: 42, egRate4: 77, egLevel2: 45, egLevel3: 10, velocitySensitivity: 6, keyboardRateScaling: 2), // OP5 (modulator → OP3): branched bell index
                .init(outputLevel: 80, frequencyCoarse: 10, frequencyFine: 2, detune: 9, feedback: 4, egRate2: 74, egRate3: 46, egRate4: 77, egLevel2: 22, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 7, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): fast-decay high-ratio tine driver
            ],
            category: .keys
        ),

        /// E.PIANO 3 is a dark Wurly-style additive patch with no active FM branches.
        /// Algorithm 32 makes every operator a carrier, so the tone is built from layered partials — and the velocity response is built by tilting the stack: the fundamental pair stays at sensitivity 2 while progressively higher partials ride sensitivity 4–7.
        /// Soft notes collapse to the dark 1:1 pair; hard notes raise the 2nd/3rd/6th partials ~12–25 dB for a reedy bark without any modulation index.
        /// OP6 is a fast-decaying 14th-partial strike that exists only in the first ~100 ms, supplying the high-band sparkle of the hammer; light global feedback roughens it slightly.
        /// Carrier egRate1 70 gives the ~10 ms onset; uneven detune keeps the sustain rounded and vocal instead of glassy.
        DX7Preset(
            name: "E.PIANO 3",
            algorithm: 31,
            feedback: 3,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate1: 70, egRate2: 54, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 79, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): dark fundamental body
                .init(outputLevel: 92, frequencyCoarse: 1, detune: 5, egRate1: 70, egRate2: 53, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 77, velocitySensitivity: 2, keyboardRateScaling: 1), // OP2 (carrier): slow-beating reed body (detune chorus)
                .init(outputLevel: 85, frequencyCoarse: 2, detune: 8, egRate1: 70, egRate2: 55, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 74, velocitySensitivity: 4, keyboardRateScaling: 1), // OP3 (carrier): velocity-raised octave support
                .init(outputLevel: 82, frequencyCoarse: 3, frequencyFine: 1, detune: 5, egRate1: 72, egRate2: 57, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 72, velocitySensitivity: 5, keyboardRateScaling: 1), // OP4 (carrier): velocity-raised nasal third partial
                .init(outputLevel: 79, frequencyCoarse: 6, detune: 9, egRate1: 72, egRate2: 58, egRate3: 40, egRate4: 74, egLevel1: 99, egLevel2: 70, egLevel3: 40, velocitySensitivity: 7, keyboardRateScaling: 1), // OP5 (carrier): hard-strike reed bite partial
                .init(outputLevel: 76, frequencyCoarse: 14, detune: 6, feedback: 3, egRate2: 80, egRate3: 60, egRate4: 74, egLevel1: 99, egLevel2: 18, egLevel3: 0, velocitySensitivity: 7, keyboardRateScaling: 2), // OP6 (carrier, feedback): fast-decay 14th-partial hammer sparkle
            ],
            category: .keys
        ),

        /// E.PIANO 4 is a CP70-style acoustic-electric piano built on Algorithm 15: OP2 → OP1 holds the low body while OP5 and OP6 both feed the OP4 → OP3 cascade as a coordinated hammer strike.
        /// All modulators run hot (72–88) at velocity sensitivity 6–7, so the string brightness scales steeply with how hard the key is hit.
        /// The direct OP2/OP4 modulators hold tall sustain shelves to keep string color in the held note; the coarse-9 OP6 hammer decays fast so its steel sparkle lives only in the strike.
        /// Carrier egRate1 70 gives the ~10 ms hammer onset; feedback on OP2 (this algorithm's feedback op) adds low string grain.
        DX7Preset(
            name: "E.PIANO 4",
            algorithm: 14,
            feedback: 3,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate1: 70, egRate2: 64, egRate3: 42, egRate4: 76, egLevel1: 99, egLevel2: 96, egLevel3: 78, velocitySensitivity: 3, keyboardRateScaling: 2), // OP1 (carrier): fundamental piano body
                .init(outputLevel: 88, frequencyCoarse: 2, frequencyFine: 2, detune: 7, feedback: 3, egRate2: 70, egRate3: 44, egRate4: 78, egLevel2: 65, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1, alg-15 feedback op): velocity-opened string warmth
                .init(outputLevel: 92, detune: 8, egRate1: 70, egRate2: 62, egRate3: 40, egRate4: 76, egLevel1: 99, egLevel2: 94, egLevel3: 76, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): bright CP-style string body
                .init(outputLevel: 86, frequencyCoarse: 2, detune: 8, egRate2: 68, egRate3: 42, egRate4: 78, egLevel2: 60, egLevel3: 26, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP4 (modulator → OP3): velocity-opened harmonic brightener
                .init(outputLevel: 72, frequencyCoarse: 5, frequencyFine: 2, detune: 6, egRate2: 72, egRate3: 44, egRate4: 78, egLevel2: 40, egLevel3: 10, velocitySensitivity: 6, keyboardRateScaling: 3), // OP5 (modulator → OP4): shared hammer color stage
                .init(outputLevel: 82, frequencyCoarse: 9, frequencyFine: 3, detune: 9, egRate2: 78, egRate3: 46, egRate4: 78, egLevel2: 20, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 4, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP4): fast-decay percussive hammer sparkle
            ],
            category: .keys
        ),

        /// E.PIANO 5 is a layered Suitcase voice on Algorithm 22: carriers OP1/OP3/OP4/OP5 form body, octave, and shimmer layers.
        /// OP2 is a strong always-on 1:1 modulator into OP1 — that constant index, scaled by velocity, gives the patch its wide velocity-brightness swing.
        /// OP6 is the shared modulator into OP3/OP4/OP5, decaying to a small shelf so the chorus-like sheen persists without a late swell; feedback on OP6.
        /// Carrier egRate1 70–72 sets the ~10 ms onset, and carrier stage-3 plateaus step down to the mid-60s/70 so the held note relaxes ~9 dB over the first second like a struck reed.
        /// Light pitch modulation adds motion after the attack while preserving the dry FM core.
        DX7Preset(
            name: "E.PIANO 5",
            algorithm: 21,
            feedback: 2,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate1: 70, egRate2: 60, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 70, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): warm Suitcase fundamental
                .init(outputLevel: 92, frequencyCoarse: 1, frequencyFine: 3, detune: 6, egRate2: 61, egRate3: 35, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP2 (modulator → OP1): constant 1:1 index, velocity-scaled bark
                .init(outputLevel: 84, frequencyCoarse: 2, detune: 8, egRate1: 70, egRate2: 62, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 68, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): octave body layer
                .init(outputLevel: 80, frequencyCoarse: 3, frequencyFine: 1, detune: 5, egRate1: 72, egRate2: 64, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 66, velocitySensitivity: 1, keyboardRateScaling: 2), // OP4 (carrier): soft upper shimmer
                .init(outputLevel: 76, frequencyCoarse: 4, frequencyFine: 2, detune: 9, egRate1: 72, egRate2: 66, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 64, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): quiet bell-like top
                .init(outputLevel: 42, frequencyCoarse: 7, frequencyFine: 4, detune: 8, feedback: 2, egRate2: 66, egRate3: 39, egRate4: 76, egLevel2: 28, egLevel3: 12, velocitySensitivity: 5, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 26, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP3/OP4/OP5, feedback): shared Suitcase shimmer
            ],
            category: .keys,
            lfoSpeed: 34,
            lfoPMD: 2,
            lfoPMS: 2
        ),

        /// E.PIANO 6 is a clean Stage-style electric piano using the Algorithm 6 three-pair variant.
        /// Its topology separates fundamental, mid body, and tine into three independent paths like E.PIANO 1; low global feedback (1) keeps the tone smoother and more studio-polished.
        /// Modulators run hot (82–88) at velocity sensitivity 7, so the polish comes from the velocity curve rather than from muting the modulators: soft notes stay glassy-clean, hard notes bark.
        /// Body modulators hold tall sustain shelves for FM identity in held notes; the coarse-8 tine modulator decays fast for strike-only sheen.
        /// Carrier egRate1 70–72 gives the ~10 ms onset; carrier stage-3 plateaus step down for a gentle e-piano decay.
        DX7Preset(
            name: "E.PIANO 6",
            algorithm: 5,
            feedback: 1,
            operators: [
                .init(outputLevel: 99, detune: 7, egRate1: 70, egRate2: 56, egRate3: 34, egRate4: 72, egLevel1: 99, egLevel2: 94, egLevel3: 80, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): clean fundamental body
                .init(outputLevel: 88, frequencyFine: 2, detune: 7, egRate2: 62, egRate3: 36, egRate4: 74, egLevel2: 65, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): velocity-opened bark
                .init(outputLevel: 92, detune: 8, egRate1: 70, egRate2: 58, egRate3: 33, egRate4: 72, egLevel1: 99, egLevel2: 93, egLevel3: 78, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): polished mid sustain
                .init(outputLevel: 84, frequencyCoarse: 2, detune: 8, egRate2: 64, egRate3: 35, egRate4: 74, egLevel2: 60, egLevel3: 25, velocitySensitivity: 7, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP4 (modulator → OP3): velocity-opened hammer partial
                .init(outputLevel: 80, detune: 6, egRate1: 72, egRate2: 64, egRate3: 42, egRate4: 72, egLevel1: 99, egLevel2: 92, egLevel3: 75, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): gentle tine sustain
                .init(outputLevel: 82, frequencyCoarse: 8, frequencyFine: 2, detune: 9, feedback: 1, egRate2: 76, egRate3: 44, egRate4: 74, egLevel2: 22, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 1), // OP6 (modulator → OP5, feedback): fast-decay tine edge
            ],
            category: .keys,
            lfoSpeed: 32,
            lfoPMD: 1,
            lfoPMS: 2
        ),

        /// E.PIANO 7 is the driven-grit patch built around Algorithm 2: OP2 (the feedback op) modulates carrier OP1, and the OP6 → OP5 → OP4 cascade drives the octave carrier OP3.
        /// OP2 runs hot at velocity sensitivity 7 with feedback 5, so hard playing produces audible bite right at the output while soft notes stay round.
        /// OP3 is a true second carrier an octave up, velocity-gated at sensitivity 5 so soft notes collapse to the fundamental; the cascade modulators above it run at 70–85 with high sensitivity, creating compressed upper harmonics that scale with touch.
        /// Direct modulators keep sustained FM shelves so the grit lives in the note tail, not just the transient; the coarse-6 top of the cascade decays fast for strike sparkle.
        /// Carrier egRate1 70 sets the ~10 ms onset; wide detune offsets give the slow overdriven-stage-piano beating.
        DX7Preset(
            name: "E.PIANO 7",
            algorithm: 1,
            feedback: 5,
            operators: [
                .init(outputLevel: 99, detune: 5, egRate1: 70, egRate2: 60, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 72, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): driven fundamental
                .init(outputLevel: 88, frequencyCoarse: 1, frequencyFine: 4, detune: 9, feedback: 5, egRate2: 66, egRate3: 49, egRate4: 76, egLevel2: 65, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1, feedback): velocity-opened feedback grit
                .init(outputLevel: 90, frequencyCoarse: 2, frequencyFine: 1, detune: 5, egRate1: 70, egRate2: 62, egRate3: 33, egRate4: 76, egLevel1: 99, egLevel2: 93, egLevel3: 68, velocitySensitivity: 5, keyboardRateScaling: 2), // OP3 (carrier): velocity-gated octave drive body
                .init(outputLevel: 85, frequencyCoarse: 3, frequencyFine: 2, detune: 9, egRate2: 74, egRate3: 52, egRate4: 76, egLevel2: 60, egLevel3: 24, velocitySensitivity: 7, keyboardRateScaling: 2), // OP4 (modulator → OP3): hard mid-harmonic pressure
                .init(outputLevel: 70, frequencyCoarse: 4, frequencyFine: 3, detune: 6, egRate2: 78, egRate3: 54, egRate4: 76, egLevel2: 35, egLevel3: 8, velocitySensitivity: 5, keyboardRateScaling: 3), // OP5 (modulator → OP4): upper crunch stage
                .init(outputLevel: 72, frequencyCoarse: 6, detune: 10, egRate2: 82, egRate3: 56, egRate4: 76, egLevel2: 20, egLevel3: 4, velocitySensitivity: 6, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5): fast-decay high-harmonic grit
            ],
            category: .keys,
            lfoSpeed: 28,
            lfoPMD: 4,
            lfoPMS: 4
        ),

        /// E.PIANO 8 is a Dyno-bright voice built from Algorithm 12: OP2 (the feedback op) modulates carrier OP1, and OP4/OP5/OP6 all modulate the secondary carrier OP3 in parallel.
        /// The three parallel modulators sum their indices on OP3, so the treble bite scales steeply with velocity (all at sensitivity 6–7) without thinning the primary body.
        /// OP4 holds a tall sustain shelf for lasting Dyno sheen; the coarse-5 and coarse-9 modulators decay fast so the top-octave glass lives only in the strike.
        /// Right-side keyboard scaling raises the FM index in the upper register for the classic bright top; feedback on OP2 adds edge to the fundamental.
        /// Carrier egRate1 70 sets the ~10 ms onset; carrier stage-3 plateaus step down for the e-piano decay.
        DX7Preset(
            name: "E.PIANO 8",
            algorithm: 11,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate1: 70, egRate2: 61, egRate3: 33, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 74, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): clean fundamental
                .init(outputLevel: 87, frequencyCoarse: 2, frequencyFine: 2, detune: 8, feedback: 4, egRate2: 68, egRate3: 44, egRate4: 77, egLevel2: 62, egLevel3: 28, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 36, klsLeftDepth: 6, klsRightDepth: 15, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator → OP1, feedback): velocity-opened Dyno bite
                .init(outputLevel: 92, detune: 8, egRate1: 70, egRate2: 62, egRate3: 33, egRate4: 75, egLevel1: 99, egLevel2: 94, egLevel3: 72, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): bright secondary tine body
                .init(outputLevel: 82, frequencyCoarse: 3, frequencyFine: 4, detune: 9, egRate2: 68, egRate3: 42, egRate4: 77, egLevel2: 55, egLevel3: 20, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 36, klsLeftDepth: 4, klsRightDepth: 16, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator → OP3): sustained high-register index
                .init(outputLevel: 76, frequencyCoarse: 5, frequencyFine: 2, detune: 6, egRate2: 74, egRate3: 44, egRate4: 77, egLevel2: 30, egLevel3: 8, velocitySensitivity: 6, keyboardRateScaling: 3), // OP5 (modulator → OP3): fast-decay upper color
                .init(outputLevel: 78, frequencyCoarse: 9, frequencyFine: 1, detune: 10, egRate2: 78, egRate3: 46, egRate4: 77, egLevel2: 22, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 36, klsLeftDepth: 4, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator → OP3): fast-decay top-octave sheen
            ],
            category: .keys,
            lfoSpeed: 36,
            lfoPMD: 2,
            lfoPMS: 2
        ),

        /// E.PIANO 9 is a soft PF-style patch using Algorithm 28: carriers are OP1 (fundamental pair with OP2), OP3 (octave body driven by the OP5 → OP4 cascade), and OP6 as a standalone strike partial.
        /// The OP2 and OP4 modulators run hot (84–86) at velocity sensitivity 7 with tall sustain shelves, so touch opens a warm string bloom rather than a bell.
        /// OP6 is a fast-decaying 13th-partial carrier at sensitivity 7 — it is the hammer sparkle, present only in the first ~100 ms of hard notes.
        /// Feedback sits on OP5 (this algorithm's feedback op) for a slightly roughened cascade; a slow LFO adds mild pitch and amplitude motion for the swimming ensemble feel.
        /// Carrier egRate1 70 sets the ~10 ms onset; stage-3 plateaus step down for the gentle e-piano decay.
        DX7Preset(
            name: "E.PIANO 9",
            algorithm: 27,
            feedback: 2,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate1: 70, egRate2: 56, egRate3: 33, egRate4: 72, egLevel1: 99, egLevel2: 94, egLevel3: 76, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): mellow centered fundamental
                .init(outputLevel: 86, frequencyFine: 2, detune: 6, egRate2: 62, egRate3: 35, egRate4: 74, egLevel2: 62, egLevel3: 28, velocitySensitivity: 7, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): velocity-opened low bloom
                .init(outputLevel: 90, frequencyCoarse: 2, detune: 8, egRate1: 70, egRate2: 60, egRate3: 33, egRate4: 72, egLevel1: 99, egLevel2: 93, egLevel3: 70, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): warm secondary octave body
                .init(outputLevel: 84, frequencyCoarse: 2, frequencyFine: 4, detune: 5, egRate2: 66, egRate3: 37, egRate4: 74, egLevel2: 58, egLevel3: 22, velocitySensitivity: 7, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP4 (modulator → OP3): velocity-opened string bloom
                .init(outputLevel: 70, frequencyCoarse: 1, frequencyFine: 6, detune: 5, feedback: 2, egRate2: 70, egRate3: 38, egRate4: 72, egLevel2: 35, egLevel3: 8, velocitySensitivity: 5, keyboardRateScaling: 1), // OP5 (modulator → OP4, feedback): roughened cascade stage
                .init(outputLevel: 72, frequencyCoarse: 13, detune: 9, egRate2: 78, egRate3: 55, egRate4: 74, egLevel1: 99, egLevel2: 20, egLevel3: 0, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP6 (carrier): fast-decay 13th-partial hammer sparkle
            ],
            category: .keys,
            lfoSpeed: 28,
            lfoPMD: 3,
            lfoAMD: 6,
            lfoWaveform: 0,
            lfoPMS: 3
        ),

        /// E.PIANO 10 is the DX-classic patch on Algorithm 1: OP2 → OP1 is the body pair and the OP6 → OP5 → OP4 cascade drives the second carrier OP3.
        /// OP2 runs at 88 with velocity sensitivity 7 and a tall sustain shelf — it is the bell shaper, collapsing to a sine on soft notes and barking on hard ones.
        /// OP4 is a coarse-14 tine that decays fast, so the crystalline glass exists only in the strike; OP5/OP6 (with feedback 5) roughen it into the familiar synthetic FM attack.
        /// OP3 itself is a near-full-level second carrier so the glass branch has real output weight.
        /// Carrier egRate1 70 sets the ~10 ms onset; the result stays intentionally brighter and more synthetic than the Rhodes-style paired algorithms.
        DX7Preset(
            name: "E.PIANO 10",
            algorithm: 0,
            feedback: 5,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate1: 70, egRate2: 66, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 76, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): dominant classic FM body
                .init(outputLevel: 88, frequencyCoarse: 2, frequencyFine: 1, detune: 8, egRate2: 72, egRate3: 48, egRate4: 76, egLevel2: 64, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 6, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1): velocity-opened bell shaper
                .init(outputLevel: 90, frequencyCoarse: 1, frequencyFine: 2, detune: 6, egRate1: 70, egRate2: 64, egRate3: 33, egRate4: 76, egLevel1: 99, egLevel2: 93, egLevel3: 72, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): glass-branch body
                .init(outputLevel: 82, frequencyCoarse: 14, detune: 9, egRate2: 78, egRate3: 52, egRate4: 76, egLevel2: 22, egLevel3: 4, velocitySensitivity: 7, keyboardRateScaling: 3), // OP4 (modulator → OP3): fast-decay coarse-14 tine glass
                .init(outputLevel: 62, frequencyCoarse: 1, frequencyFine: 3, detune: 5, egRate2: 84, egRate3: 54, egRate4: 76, egLevel2: 26, egLevel3: 6, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator → OP4): upper harmonic coupler
                .init(outputLevel: 58, frequencyCoarse: 1, detune: 10, feedback: 5, egRate2: 88, egRate3: 56, egRate4: 76, egLevel2: 22, egLevel3: 4, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): self-modulating glass driver
            ],
            category: .keys
        ),

        /// Inharmonic tine bell with an electric-piano core, slow beating partials, and a long natural decay.
        /// Algorithm 7 combines OP2->OP1 for the struck fundamental with an inharmonic OP6->OP5->OP3 and OP4->OP3 bell branch.
        /// OP4 uses a 3.50 ratio and OP6 uses a high 7.x ratio so the overtones avoid simple octave locking while still reading as a keyed instrument.
        /// Feedback on OP6 roughens the bell onset, and a small pitch LFO adds shimmer after the attack without becoming vibrato-heavy.
        /// v4 velocity opening: the direct modulators OP2/OP4 run hot (62-68) at velocity sensitivity 6-7 so soft notes collapse toward plain carriers and hard strikes open the inharmonic bell bark; carriers keep the v3 88-93 level-2 / 74-82 level-3 plateaus for the long audible core.
        DX7Preset(
            name: "TINE BELL",
            algorithm: 6,
            feedback: 3,
            operators: [
                .init(outputLevel: 96, detune: 7, egRate2: 39, egRate3: 22, egRate4: 25, egLevel2: 93, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): electric-piano fundamental
                .init(outputLevel: 68, frequencyCoarse: 2, frequencyFine: 9, detune: 6, egRate2: 52, egRate3: 31, egRate4: 30, egLevel2: 32, egLevel3: 1, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 9, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): velocity-opened tine color
                .init(outputLevel: 86, frequencyFine: 14, detune: 8, egRate2: 34, egRate3: 18, egRate4: 21, egLevel2: 88, egLevel3: 74, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): sustained bell partial body
                .init(outputLevel: 62, frequencyCoarse: 3, frequencyFine: 50, detune: 9, egRate2: 47, egRate3: 27, egRate4: 28, egLevel2: 28, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 12, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): velocity-opened 3.50-ratio bell sideband
                .init(outputLevel: 46, frequencyCoarse: 2, frequencyFine: 68, detune: 6, egRate2: 43, egRate3: 25, egRate4: 27, egLevel2: 26, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): slow-decay inharmonic index
                .init(outputLevel: 48, frequencyCoarse: 7, frequencyFine: 12, detune: 8, feedback: 3, egRate2: 55, egRate3: 34, egRate4: 33, egLevel2: 22, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 16, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): high bell shimmer
            ],
            category: .keys,
            lfoPMD: 3
        ),

        /// Pure crystalline bell with no electric-piano fundamental and no pitch-modulation movement.
        /// Algorithm index 4 keeps three parallel pairs so OP1, OP3, and OP5 can speak as independent bell partials rather than one stacked piano tone.
        /// Carrier ratios 1, 4, and 9 form the main partial set, while the modulators use 3, 4, and 7 with fine offsets for inharmonic shimmer.
        /// Slow carrier decay on OP1/OP3 keeps the ring long, while the 9th-partial OP5 decays faster so the glassy top fades into a warmer tail; modulators run hot (70-74) at velocity sensitivity 6-7 with fast EG decay, putting the shimmer in the strike and the velocity contrast in the modulation index.
        /// LFO pitch depth and pitch sensitivity are disabled so the bell stays still and transparent.
        DX7Preset(
            name: "GLASS BELL",
            algorithm: 4,
            feedback: 2,
            operators: [
                .init(outputLevel: 96, frequencyCoarse: 1, detune: 7, egRate2: 36, egRate3: 20, egRate4: 18, egLevel2: 92, egLevel3: 75, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): low glass fundamental partial
                .init(outputLevel: 72, frequencyCoarse: 3, frequencyFine: 5, detune: 6, egRate2: 50, egRate3: 32, egRate4: 28, egLevel2: 30, egLevel3: 2, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): velocity-opened low glass index
                .init(outputLevel: 87, frequencyCoarse: 4, detune: 8, egRate2: 40, egRate3: 22, egRate4: 17, egLevel2: 90, egLevel3: 68, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): fourth-ratio crystalline partial
                .init(outputLevel: 70, frequencyCoarse: 4, frequencyFine: 10, detune: 8, egRate2: 53, egRate3: 34, egRate4: 29, egLevel2: 26, egLevel3: 1, velocitySensitivity: 6, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): velocity-opened fine-offset shimmer
                .init(outputLevel: 73, frequencyCoarse: 9, detune: 9, egRate2: 60, egRate3: 32, egRate4: 16, egLevel2: 58, egLevel3: 20, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (carrier): high bell partial, fades well before the body
                .init(outputLevel: 80, frequencyCoarse: 7, frequencyFine: 15, detune: 9, feedback: 2, egRate2: 78, egRate3: 40, egRate4: 30, egLevel2: 8, egLevel3: 0, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): fast-decay strike sparkle burst
            ],
            category: .keys,
            lfoPMD: 0,
            lfoPMS: 0
        ),

        /// Heavy deep long-decay church bell voiced in a lowered cathedral register.
        /// Algorithm index 6 uses OP6->OP5->OP3 plus OP4->OP3 for the upper bell body, with OP2->OP1 anchoring the fundamental.
        /// OP1 is the slow-speaking coarse-1 fundamental, while OP3 carries the darker secondary bell resonance.
        /// Deep inharmonic structure comes from OP4 at 5.25 and OP6 at 9.50, with OP6 feedback adding weight to the strike.
        /// Long carrier rate-3 values and high level-3 plateaus keep the bell body present after the transient fades.
        DX7Preset(
            name: "CHURCHBELL",
            algorithm: 6,
            feedback: 4,
            operators: [
                .init(outputLevel: 97, frequencyCoarse: 1, detune: 7, egRate1: 82, egRate2: 35, egRate3: 21, egRate4: 20, egLevel2: 92, egLevel3: 78, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): slow cathedral fundamental
                .init(outputLevel: 44, frequencyCoarse: 1, detune: 6, egRate2: 47, egRate3: 29, egRate4: 26, egLevel2: 32, egLevel3: 2, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 6, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): low bell strike color
                .init(outputLevel: 87, frequencyCoarse: 2, detune: 8, egRate2: 32, egRate3: 19, egRate4: 19, egLevel2: 88, egLevel3: 68, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): broad secondary bell body
                .init(outputLevel: 50, frequencyCoarse: 5, frequencyFine: 25, detune: 9, egRate2: 45, egRate3: 27, egRate4: 25, egLevel2: 28, egLevel3: 1, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): deep inharmonic sideband
                .init(outputLevel: 48, frequencyCoarse: 2, frequencyFine: 4, detune: 6, egRate2: 41, egRate3: 25, egRate4: 24, egLevel2: 26, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): slow intermediate bell index
                .init(outputLevel: 52, frequencyCoarse: 9, frequencyFine: 50, detune: 8, feedback: 4, egRate2: 52, egRate3: 32, egRate4: 28, egLevel2: 22, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 16, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): heavy high bell strike
            ],
            category: .keys,
            transpose: -12
        ),

        /// Modern bright shimmering bell with a fast icy front and a controlled sustaining core.
        /// Algorithm index 6 stacks OP6->OP5->OP3 beside OP4->OP3, while OP2->OP1 provides a clearer lower anchor.
        /// High-coarse modulators on OP6 and OP4 create inharmonic content that reads as cold and synthetic rather than acoustic; the direct modulators OP2/OP4 run hot (68-75) at velocity sensitivity 6-7 so soft notes thin out to near-pure partials and hard strikes open the full icy edge.
        /// Carrier rate-2 values are fast for an immediate attack, with level-3 plateaus kept in the 60-72 range for a glassy hold.
        /// Strong sine LFO pitch modulation adds shimmer after the transient without using amplitude tremolo.
        DX7Preset(
            name: "ICY BELL",
            algorithm: 6,
            feedback: 3,
            operators: [
                .init(outputLevel: 97, frequencyCoarse: 1, detune: 7, egRate2: 68, egRate3: 30, egRate4: 32, egLevel2: 92, egLevel3: 72, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): clear icy fundamental
                .init(outputLevel: 75, frequencyCoarse: 2, frequencyFine: 8, detune: 6, egRate2: 58, egRate3: 46, egRate4: 45, egLevel2: 42, egLevel3: 1, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): velocity-opened bright lower attack
                .init(outputLevel: 88, frequencyCoarse: 2, frequencyFine: 2, detune: 8, egRate2: 72, egRate3: 27, egRate4: 31, egLevel2: 90, egLevel3: 63, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): shimmering upper body
                .init(outputLevel: 68, frequencyCoarse: 7, frequencyFine: 6, detune: 9, egRate2: 62, egRate3: 50, egRate4: 48, egLevel2: 38, egLevel3: 1, velocitySensitivity: 6, keyboardRateScaling: 3, klsBreakPoint: 47, klsLeftDepth: 0, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): velocity-opened high inharmonic ice edge
                .init(outputLevel: 46, frequencyCoarse: 3, frequencyFine: 3, detune: 7, egRate2: 60, egRate3: 44, egRate4: 42, egLevel2: 34, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): intermediate shimmer index
                .init(outputLevel: 52, frequencyCoarse: 13, frequencyFine: 0, detune: 9, feedback: 3, egRate2: 88, egRate3: 60, egRate4: 50, egLevel2: 20, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4, klsBreakPoint: 49, klsLeftDepth: 0, klsRightDepth: 18, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): very high icy sparkle
            ],
            category: .keys,
            lfoSpeed: 42,
            lfoPMD: 12,
            lfoWaveform: 4,
            lfoPMS: 5
        ),

        /// Vibraphone-style keyed bell with rounded mallet attack and strong tremolo.
        /// Algorithm index 4 keeps three parallel 4:1 modulator-to-1:1 carrier pairs for a clean struck-bar tone.
        /// OP1 carries the main bar, OP3 adds a slightly softer secondary bar, and OP5 supplies a quieter tertiary layer for width.
        /// Modulators run hot (68-72) at velocity sensitivity 6-7 with the burst held through the strike window, so soft notes stay near-pure bars and hard mallet hits open the bell-bar overtones.
        /// Sine LFO amplitude modulation is kept light (AMD 24, sensitivity 2) so the motor pulse colors the ring without swallowing the strike transient.
        /// OP5 is a quiet 12th-partial carrier with a slower release than the bars: it is the metallic sheen of the strike and keeps a trace of shimmer in the ring-down, like the high modes of a real aluminum bar.
        /// v5 ring: carrier/modulator release slowed to 42/46 (36 on the shimmer partial) so the bar rings naturally for about a second after the mallet leaves.
        DX7Preset(
            name: "VIBES",
            algorithm: 4,
            feedback: 1,
            operators: [
                .init(outputLevel: 97, frequencyCoarse: 1, detune: 7, egRate2: 48, egRate3: 31, egRate4: 42, egLevel2: 92, egLevel3: 80, velocitySensitivity: 2, ampModSensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): primary vibraphone bar
                .init(outputLevel: 72, frequencyCoarse: 4, frequencyFine: 0, detune: 6, egRate2: 60, egRate3: 43, egRate4: 46, egLevel2: 40, egLevel3: 1, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): velocity-opened rounded mallet index
                .init(outputLevel: 88, frequencyCoarse: 1, detune: 8, egRate2: 51, egRate3: 29, egRate4: 42, egLevel2: 90, egLevel3: 76, velocitySensitivity: 2, ampModSensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): secondary resonant bar
                .init(outputLevel: 68, frequencyCoarse: 4, frequencyFine: 2, detune: 8, egRate2: 62, egRate3: 46, egRate4: 46, egLevel2: 36, egLevel3: 1, velocitySensitivity: 6, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): velocity-opened bell bar overtone
                .init(outputLevel: 52, frequencyCoarse: 12, detune: 9, egRate2: 50, egRate3: 22, egRate4: 36, egLevel2: 88, egLevel3: 72, velocitySensitivity: 1, ampModSensitivity: 2, keyboardRateScaling: 1), // OP5 (carrier): quiet 12th-partial metallic shimmer that rings through the tail
                .init(outputLevel: 36, frequencyCoarse: 4, frequencyFine: 4, detune: 9, feedback: 1, egRate2: 64, egRate3: 49, egRate4: 46, egLevel2: 20, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 2, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 12, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): light color on the shimmer partial
            ],
            category: .keys,
            lfoSpeed: 38,
            lfoPMD: 0,
            lfoAMD: 24,
            lfoWaveform: 4
        ),

        /// Bright digital piano with fast hammer definition, clean sustain, and a narrow chorused spread between carriers.
        /// Algorithm 1 puts the OP6->OP5->OP4 hammer cascade over carrier OP3 beside the OP2->OP1 body pair for a crisp layered attack.
        /// OP2 and OP4 run hot (84-88) at velocity sensitivity 7: OP2 keeps a tall sustain shelf for lasting digital sheen, while OP4's glass index decays quickly so brightness leaves before the body.
        /// OP5/OP6 sharpen only the transient (fast EG to near-zero); feedback on OP6 generates the fine digital edge.
        /// Carrier egRate1 70 gives a ~10 ms hammer onset and the stage-3 plateaus step down to 70-76 for a clean e-piano decay ladder.
        DX7Preset(
            name: "DIGI PIANO",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 97, detune: 6, egRate1: 70, egRate2: 72, egRate3: 33, egRate4: 75, egLevel2: 94, egLevel3: 76, velocitySensitivity: 3, keyboardRateScaling: 2), // OP1 (carrier): clean fundamental
                .init(outputLevel: 88, frequencyCoarse: 2, frequencyFine: 2, detune: 7, egRate2: 74, egRate3: 42, egRate4: 75, egLevel2: 62, egLevel3: 30, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 39, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): velocity-opened bright hammer partial
                .init(outputLevel: 85, detune: 8, egRate1: 70, egRate2: 69, egRate3: 33, egRate4: 75, egLevel2: 90, egLevel3: 70, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): detuned digital body
                .init(outputLevel: 84, frequencyCoarse: 3, frequencyFine: 1, detune: 8, egRate2: 76, egRate3: 42, egRate4: 75, egLevel2: 58, egLevel3: 26, velocitySensitivity: 7, keyboardRateScaling: 2, klsBreakPoint: 39, klsLeftDepth: 0, klsRightDepth: 0, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): velocity-opened glass index
                .init(outputLevel: 64, frequencyCoarse: 2, frequencyFine: 7, detune: 6, egRate2: 90, egRate3: 66, egRate4: 75, egLevel2: 24, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator -> OP4): transient sharpening stage
                .init(outputLevel: 76, frequencyCoarse: 9, frequencyFine: 3, detune: 9, feedback: 4, egRate2: 92, egRate3: 74, egRate4: 75, egLevel2: 20, egLevel3: 0, velocitySensitivity: 7, keyboardRateScaling: 4, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 13, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): fine attack fizz
            ],
            category: .keys
        ),
    ]
}
