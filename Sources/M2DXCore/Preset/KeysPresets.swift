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
        /// The primary carrier is pinned at full level while the two extra carriers sit lower and detuned for width.
        /// Modulator levels are deliberately restrained, with nonzero sustain shelves so the FM color remains audible after the strike.
        /// Feedback stays on the high-ratio tine pair for controlled sparkle rather than a noisy attack.
        DX7Preset(
            name: "E.PIANO 1",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate2: 58, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): warm fundamental sustain
                .init(outputLevel: 34, frequencyFine: 3, detune: 7, egRate2: 64, egRate3: 38, egRate4: 76, egLevel2: 32, egLevel3: 12, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 18, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): soft low-ratio bark
                .init(outputLevel: 92, detune: 8, egRate2: 60, egRate3: 34, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): woody midrange body
                .init(outputLevel: 38, frequencyCoarse: 2, detune: 8, egRate2: 66, egRate3: 40, egRate4: 76, egLevel2: 30, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 22, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP4 (modulator → OP3): velocity-opened hammer overtone
                .init(outputLevel: 80, detune: 9, egRate2: 66, egRate3: 44, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): short metallic tine carrier
                .init(outputLevel: 46, frequencyCoarse: 8, frequencyFine: 6, detune: 9, feedback: 3, egRate2: 72, egRate3: 48, egRate4: 76, egLevel2: 28, egLevel3: 8, velocitySensitivity: 6, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 30, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): bright tine attack
            ],
            category: .keys
        ),

        /// E.PIANO 2 is a bell-tinged Mk II voice using the branched Algorithm 7 layout.
        /// OP2 → OP1 carries the warm body while the OP6 → OP5 → OP3 branch and OP4 → OP3 branch create a harder struck tine.
        /// Keeping OP3 as the secondary carrier at a high but controlled level gives the tone more top-end focus than E.PIANO 1.
        /// The two branch modulators decay close to the carrier decay and retain small sustain shelves, preventing the attack from swelling louder than the body.
        /// Feedback on OP6 supplies the bell edge without forcing every note into a bright static color.
        DX7Preset(
            name: "E.PIANO 2",
            algorithm: 6,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate2: 60, egRate3: 38, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 85, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): full fundamental body
                .init(outputLevel: 34, frequencyFine: 4, detune: 7, egRate2: 66, egRate3: 40, egRate4: 77, egLevel2: 31, egLevel3: 12, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 18, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): bark and body shimmer
                .init(outputLevel: 92, detune: 8, egRate2: 62, egRate3: 37, egRate4: 75, egLevel1: 99, egLevel2: 94, egLevel3: 83, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): bell-tinged secondary body
                .init(outputLevel: 36, frequencyCoarse: 3, detune: 8, egRate2: 68, egRate3: 41, egRate4: 77, egLevel2: 30, egLevel3: 11, velocitySensitivity: 5, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 20, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP4 (modulator → OP3): direct hammer partial
                .init(outputLevel: 32, frequencyCoarse: 2, frequencyFine: 5, detune: 6, egRate2: 68, egRate3: 42, egRate4: 77, egLevel2: 28, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2), // OP5 (modulator → OP3): branched bell index
                .init(outputLevel: 44, frequencyCoarse: 10, frequencyFine: 2, detune: 9, feedback: 4, egRate2: 74, egRate3: 46, egRate4: 77, egLevel2: 26, egLevel3: 8, velocitySensitivity: 7, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 32, klsRightDepth: 7, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): high-ratio tine driver
            ],
            category: .keys
        ),

        /// E.PIANO 3 is a dark Wurly-style additive patch with no active FM branches.
        /// Algorithm 32 makes every operator a carrier, so the tone is built from layered partials rather than moving sidebands.
        /// The primary carrier stays full level, one secondary carrier reinforces the body, and the remaining tertiary carriers taper into a reedy upper spectrum.
        /// Slightly uneven detune and slower decay rates keep the sound rounded and vocal instead of glassy.
        DX7Preset(
            name: "E.PIANO 3",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate2: 54, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 86, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): dark fundamental body
                .init(outputLevel: 92, frequencyCoarse: 1, frequencyFine: 2, detune: 6, egRate2: 53, egRate3: 32, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP2 (carrier): close beating reed body
                .init(outputLevel: 85, frequencyCoarse: 2, detune: 8, egRate2: 55, egRate3: 31, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 82, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): mellow octave support
                .init(outputLevel: 82, frequencyCoarse: 3, frequencyFine: 1, detune: 5, egRate2: 57, egRate3: 30, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 1), // OP4 (carrier): soft nasal third partial
                .init(outputLevel: 79, frequencyCoarse: 4, detune: 9, egRate2: 58, egRate3: 30, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 79, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): quiet upper reed color
                .init(outputLevel: 76, frequencyCoarse: 6, detune: 6, egRate2: 60, egRate3: 29, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 78, velocitySensitivity: 1, keyboardRateScaling: 2), // OP6 (carrier): faint airy partial
            ],
            category: .keys
        ),

        /// E.PIANO 4 is a CP70-style acoustic-electric piano with a shared high hammer source.
        /// Algorithm 15 lets the upper side of the patch use OP6 as a common transient driver into OP5 and OP4, giving the attack one coordinated strike.
        /// OP1 keeps the low piano body stable while OP3 supplies the brighter string-like secondary carrier.
        /// The modulator decay rates are matched to the carriers closely enough that the hammer does not bloom louder after the initial hit.
        /// Moderate feedback on the shared high operator adds steel-like grain without turning the sustain into a bell.
        DX7Preset(
            name: "E.PIANO 4",
            algorithm: 14,
            feedback: 3,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate2: 64, egRate3: 42, egRate4: 76, egLevel1: 99, egLevel2: 96, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): fundamental piano body
                .init(outputLevel: 36, frequencyCoarse: 2, frequencyFine: 2, detune: 7, egRate2: 70, egRate3: 44, egRate4: 78, egLevel2: 32, egLevel3: 12, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 16, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1): low string harmonic warmth
                .init(outputLevel: 92, detune: 8, egRate2: 62, egRate3: 40, egRate4: 76, egLevel1: 99, egLevel2: 94, egLevel3: 80, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): bright CP-style string body
                .init(outputLevel: 38, frequencyCoarse: 2, detune: 8, egRate2: 68, egRate3: 42, egRate4: 78, egLevel2: 30, egLevel3: 11, velocitySensitivity: 5, keyboardRateScaling: 3, klsBreakPoint: 43, klsLeftDepth: 20, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP4 (modulator → OP3): upper harmonic brightener
                .init(outputLevel: 34, frequencyCoarse: 5, frequencyFine: 2, detune: 6, egRate2: 72, egRate3: 44, egRate4: 78, egLevel2: 28, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator → OP4): shared hammer color stage
                .init(outputLevel: 44, frequencyCoarse: 9, frequencyFine: 3, detune: 9, feedback: 3, egRate2: 74, egRate3: 46, egRate4: 78, egLevel2: 26, egLevel3: 9, velocitySensitivity: 7, keyboardRateScaling: 4, klsBreakPoint: 44, klsLeftDepth: 34, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5/OP4, feedback): shared percussive hammer source
            ],
            category: .keys
        ),

        /// E.PIANO 5 is a layered Suitcase voice that uses Algorithm 22 as a mostly additive layout.
        /// The five audible carriers create a broad body, octave, and upper shimmer while OP6 supplies one restrained shared brightness source.
        /// OP1 is the full-level anchor, OP2 is the secondary carrier, and OP3 through OP5 sit in tertiary ranges so the stack stays loud but not overloaded.
        /// The shared modulator keeps its FM shelf through sustain, which makes the chorus-like Suitcase sheen persist without a late decay swell.
        /// Light pitch modulation adds motion after the attack while preserving the dry FM core.
        DX7Preset(
            name: "E.PIANO 5",
            algorithm: 21,
            feedback: 2,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate2: 60, egRate3: 36, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 86, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): warm Suitcase fundamental
                .init(outputLevel: 92, frequencyCoarse: 1, frequencyFine: 3, detune: 6, egRate2: 61, egRate3: 35, egRate4: 74, egLevel1: 99, egLevel2: 94, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP2 (carrier): close secondary body
                .init(outputLevel: 84, frequencyCoarse: 2, detune: 8, egRate2: 62, egRate3: 34, egRate4: 74, egLevel1: 99, egLevel2: 93, egLevel3: 82, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): octave body layer
                .init(outputLevel: 80, frequencyCoarse: 3, frequencyFine: 1, detune: 5, egRate2: 64, egRate3: 33, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 2), // OP4 (carrier): soft upper shimmer
                .init(outputLevel: 76, frequencyCoarse: 4, frequencyFine: 2, detune: 9, egRate2: 66, egRate3: 34, egRate4: 74, egLevel1: 99, egLevel2: 92, egLevel3: 78, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): quiet bell-like top
                .init(outputLevel: 42, frequencyCoarse: 7, frequencyFine: 4, detune: 8, feedback: 2, egRate2: 66, egRate3: 39, egRate4: 76, egLevel2: 28, egLevel3: 12, velocitySensitivity: 5, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 26, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP1..OP5, feedback): shared Suitcase shimmer
            ],
            category: .keys,
            lfoSpeed: 34,
            lfoPMD: 2,
            lfoPMS: 2
        ),

        /// E.PIANO 6 is a clean Stage-style electric piano using the Algorithm 6 three-pair variant.
        /// Its topology separates fundamental, mid body, and tine into three independent paths like E.PIANO 1, but the modulator levels and feedback are lower.
        /// OP1 remains the dominant carrier, OP3 supplies a polished secondary body, and OP5 adds only a controlled tertiary tine.
        /// The nonzero modulator shelves preserve FM identity during held notes while keeping the overall tone smooth and studio-ready.
        DX7Preset(
            name: "E.PIANO 6",
            algorithm: 5,
            feedback: 1,
            operators: [
                .init(outputLevel: 99, detune: 7, egRate2: 56, egRate3: 34, egRate4: 72, egLevel1: 99, egLevel2: 94, egLevel3: 86, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): clean fundamental body
                .init(outputLevel: 32, frequencyFine: 2, detune: 7, egRate2: 62, egRate3: 36, egRate4: 74, egLevel2: 30, egLevel3: 13, velocitySensitivity: 2, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 14, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): subtle low bark
                .init(outputLevel: 92, detune: 8, egRate2: 58, egRate3: 33, egRate4: 72, egLevel1: 99, egLevel2: 93, egLevel3: 83, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): polished mid sustain
                .init(outputLevel: 34, frequencyCoarse: 2, detune: 8, egRate2: 64, egRate3: 35, egRate4: 74, egLevel2: 28, egLevel3: 12, velocitySensitivity: 3, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 16, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP4 (modulator → OP3): restrained hammer partial
                .init(outputLevel: 80, detune: 6, egRate2: 64, egRate3: 42, egRate4: 72, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): gentle tine sustain
                .init(outputLevel: 36, frequencyCoarse: 8, frequencyFine: 2, detune: 9, feedback: 1, egRate2: 70, egRate3: 44, egRate4: 74, egLevel2: 26, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 22, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 1), // OP6 (modulator → OP5, feedback): barely-there tine edge
            ],
            category: .keys,
            lfoSpeed: 32,
            lfoPMD: 1,
            lfoPMS: 2
        ),

        /// E.PIANO 7 is the driven-grit patch built around Algorithm 2's linear stack with feedback on OP2.
        /// OP2 directly modulates the full-level carrier, so the feedback produces audible bite at the point closest to the output instead of only adding distant fizz.
        /// The deeper operators feed the stack at progressively lower levels, creating compressed upper harmonics without overwhelming the fundamental.
        /// Matched decay rates and sustained FM shelves keep the gritty tone present during the note tail rather than only on the transient.
        /// Wide detune offsets create slow beating that suggests an overdriven stage piano without adding an external effect.
        DX7Preset(
            name: "E.PIANO 7",
            algorithm: 1,
            feedback: 5,
            operators: [
                .init(outputLevel: 99, detune: 5, egRate2: 60, egRate3: 45, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): driven fundamental
                .init(outputLevel: 42, frequencyCoarse: 1, frequencyFine: 4, detune: 9, feedback: 5, egRate2: 66, egRate3: 49, egRate4: 76, egLevel2: 32, egLevel3: 12, velocitySensitivity: 5, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 18, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1, feedback): close feedback grit
                .init(outputLevel: 36, frequencyCoarse: 2, frequencyFine: 1, detune: 5, egRate2: 70, egRate3: 50, egRate4: 76, egLevel2: 30, egLevel3: 11, velocitySensitivity: 4, keyboardRateScaling: 2), // OP3 (modulator → OP2): octave drive stage
                .init(outputLevel: 34, frequencyCoarse: 3, frequencyFine: 2, detune: 9, egRate2: 74, egRate3: 52, egRate4: 76, egLevel2: 28, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2), // OP4 (modulator → OP3): hard mid-harmonic pressure
                .init(outputLevel: 30, frequencyCoarse: 4, frequencyFine: 3, detune: 6, egRate2: 78, egRate3: 54, egRate4: 76, egLevel2: 26, egLevel3: 9, velocitySensitivity: 3, keyboardRateScaling: 3), // OP5 (modulator → OP4): upper crunch stage
                .init(outputLevel: 28, frequencyCoarse: 6, detune: 10, egRate2: 82, egRate3: 56, egRate4: 76, egLevel2: 24, egLevel3: 8, velocitySensitivity: 3, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 24, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5): distant high-harmonic grit
            ],
            category: .keys,
            lfoSpeed: 28,
            lfoPMD: 4,
            lfoPMS: 4
        ),

        /// E.PIANO 8 is a Dyno-bright voice built from Algorithm 12's split stack.
        /// OP1 stays as a standalone clean carrier while OP3 receives both a direct bright modulator and the OP6 → OP5 → OP4 stack.
        /// This lets the patch push treble bite into the secondary carrier without thinning the primary body.
        /// Right-side keyboard scaling on the direct and stacked modulators raises the FM index in the upper register for the classic bright top.
        /// Feedback on OP2 gives the direct branch extra edge while its sustained shelf keeps the brightness from disappearing too quickly.
        DX7Preset(
            name: "E.PIANO 8",
            algorithm: 11,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, detune: 6, egRate2: 61, egRate3: 42, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): standalone clean fundamental
                .init(outputLevel: 42, frequencyCoarse: 2, frequencyFine: 2, detune: 8, feedback: 4, egRate2: 68, egRate3: 44, egRate4: 77, egLevel2: 30, egLevel3: 12, velocitySensitivity: 6, keyboardRateScaling: 2, klsBreakPoint: 36, klsLeftDepth: 6, klsRightDepth: 15, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator → OP3, feedback): direct Dyno bite
                .init(outputLevel: 92, detune: 8, egRate2: 62, egRate3: 40, egRate4: 75, egLevel1: 99, egLevel2: 94, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): bright secondary tine body
                .init(outputLevel: 38, frequencyCoarse: 3, frequencyFine: 4, detune: 9, egRate2: 68, egRate3: 42, egRate4: 77, egLevel2: 28, egLevel3: 11, velocitySensitivity: 5, keyboardRateScaling: 2, klsBreakPoint: 36, klsLeftDepth: 4, klsRightDepth: 16, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator → OP3): stacked high-register index
                .init(outputLevel: 34, frequencyCoarse: 5, frequencyFine: 2, detune: 6, egRate2: 72, egRate3: 44, egRate4: 77, egLevel2: 26, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator → OP4): upper stack color
                .init(outputLevel: 30, frequencyCoarse: 9, frequencyFine: 1, detune: 10, egRate2: 76, egRate3: 46, egRate4: 77, egLevel2: 24, egLevel3: 8, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 36, klsLeftDepth: 4, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator → OP5): top-octave sheen
            ],
            category: .keys,
            lfoSpeed: 36,
            lfoPMD: 2,
            lfoPMS: 2
        ),

        /// E.PIANO 9 is a soft PF-style patch using Algorithm 28's hybrid additive-and-branched layout.
        /// OP1, OP4, and OP5 form the audible carriers, with OP1 carrying the center, OP4 adding the secondary octave color, and OP5 providing a quiet tertiary pad-like tine.
        /// The remaining operators apply gentle branch modulation at low levels so the sound blooms without becoming bell-heavy.
        /// A slow LFO adds mild pitch and amplitude motion for a swimming ensemble feel while preserving the dry carrier balance.
        /// The modulator shelves are deliberately higher than zero, keeping a little FM warmth in the sustain.
        DX7Preset(
            name: "E.PIANO 9",
            algorithm: 27,
            feedback: 2,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate2: 56, egRate3: 33, egRate4: 72, egLevel1: 99, egLevel2: 94, egLevel3: 86, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): mellow centered fundamental
                .init(outputLevel: 32, frequencyFine: 2, detune: 6, egRate2: 62, egRate3: 35, egRate4: 74, egLevel2: 30, egLevel3: 13, velocitySensitivity: 3, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 12, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator → OP1): gentle low bloom
                .init(outputLevel: 36, frequencyCoarse: 2, frequencyFine: 4, detune: 8, egRate2: 66, egRate3: 37, egRate4: 74, egLevel2: 28, egLevel3: 12, velocitySensitivity: 3, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 14, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 2), // OP3 (modulator → OP4): soft octave color
                .init(outputLevel: 92, frequencyCoarse: 2, detune: 8, egRate2: 60, egRate3: 34, egRate4: 72, egLevel1: 99, egLevel2: 93, egLevel3: 82, velocitySensitivity: 1, keyboardRateScaling: 1), // OP4 (carrier): warm secondary octave body
                .init(outputLevel: 80, frequencyCoarse: 1, frequencyFine: 6, detune: 5, feedback: 2, egRate2: 66, egRate3: 36, egRate4: 72, egLevel1: 99, egLevel2: 92, egLevel3: 80, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier, feedback): soft chorused tertiary tine
                .init(outputLevel: 34, frequencyCoarse: 6, frequencyFine: 3, detune: 9, egRate2: 72, egRate3: 38, egRate4: 74, egLevel2: 26, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 22, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 2), // OP6 (modulator → OP5): mellow upper branch shimmer
            ],
            category: .keys,
            lfoSpeed: 28,
            lfoPMD: 3,
            lfoAMD: 6,
            lfoWaveform: 0,
            lfoPMS: 3
        ),

        /// E.PIANO 10 is the DX-classic patch and keeps Algorithm 1 as a full serial stack from OP6 down to OP1.
        /// OP1 is the only audible carrier and stays at full level, while OP2 is the immediate brightness shaper that determines how much bell tone reaches the output.
        /// Deeper operators are progressively quieter, so the upper stack contributes glass and motion without overpowering the carrier.
        /// Feedback on OP6 energizes the top of the stack, giving the familiar crystalline FM attack while the sustained shelves keep the color present after the strike.
        /// The result is intentionally brighter and more synthetic than the Rhodes-style paired algorithms.
        DX7Preset(
            name: "E.PIANO 10",
            algorithm: 0,
            feedback: 5,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate2: 66, egRate3: 44, egRate4: 74, egLevel1: 99, egLevel2: 95, egLevel3: 84, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): dominant classic FM body
                .init(outputLevel: 42, frequencyCoarse: 2, frequencyFine: 1, detune: 8, egRate2: 72, egRate3: 48, egRate4: 76, egLevel2: 32, egLevel3: 12, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 16, klsRightDepth: 6, klsLeftCurve: 1, klsRightCurve: 2), // OP2 (modulator → OP1): immediate bell shaper
                .init(outputLevel: 38, frequencyCoarse: 3, frequencyFine: 2, detune: 6, egRate2: 76, egRate3: 50, egRate4: 76, egLevel2: 30, egLevel3: 11, velocitySensitivity: 4, keyboardRateScaling: 2), // OP3 (modulator → OP2): mid-stack glass color
                .init(outputLevel: 34, frequencyCoarse: 5, frequencyFine: 2, detune: 9, egRate2: 80, egRate3: 52, egRate4: 76, egLevel2: 28, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 3), // OP4 (modulator → OP3): high-ratio sparkle stage
                .init(outputLevel: 30, frequencyCoarse: 7, frequencyFine: 3, detune: 5, egRate2: 84, egRate3: 54, egRate4: 76, egLevel2: 26, egLevel3: 9, velocitySensitivity: 3, keyboardRateScaling: 3), // OP5 (modulator → OP4): upper harmonic coupler
                .init(outputLevel: 28, frequencyCoarse: 1, detune: 10, feedback: 5, egRate2: 88, egRate3: 56, egRate4: 76, egLevel2: 24, egLevel3: 8, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 26, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): self-modulating glass driver
            ],
            category: .keys
        ),

        /// Inharmonic tine bell with an electric-piano core, slow beating partials, and a long natural decay.
        /// Algorithm 7 combines OP2->OP1 for the struck fundamental with an inharmonic OP6->OP5->OP3 and OP4->OP3 bell branch.
        /// OP4 uses a 3.50 ratio and OP6 uses a high 7.x ratio so the overtones avoid simple octave locking while still reading as a keyed instrument.
        /// Feedback on OP6 roughens the bell onset, and a small pitch LFO adds shimmer after the attack without becoming vibrato-heavy.
        /// v3 plateau lift: bell carriers are raised to 88-93 level-2 and 74-82 level-3 plateaus for a longer audible core, while all four modulators are constrained to 42-48 output with 22-32 level-2 shimmer and no sustained modulation shelf.
        DX7Preset(
            name: "TINE BELL",
            algorithm: 6,
            feedback: 3,
            operators: [
                .init(outputLevel: 96, detune: 7, egRate2: 39, egRate3: 22, egRate4: 25, egLevel2: 93, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): electric-piano fundamental
                .init(outputLevel: 42, frequencyCoarse: 2, frequencyFine: 9, detune: 6, egRate2: 52, egRate3: 31, egRate4: 30, egLevel2: 32, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 9, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): soft tine color
                .init(outputLevel: 86, frequencyFine: 14, detune: 8, egRate2: 34, egRate3: 18, egRate4: 21, egLevel2: 88, egLevel3: 74, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): sustained bell partial body
                .init(outputLevel: 48, frequencyCoarse: 3, frequencyFine: 50, detune: 9, egRate2: 47, egRate3: 27, egRate4: 28, egLevel2: 28, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 12, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): 3.50-ratio bell sideband
                .init(outputLevel: 46, frequencyCoarse: 2, frequencyFine: 68, detune: 6, egRate2: 43, egRate3: 25, egRate4: 27, egLevel2: 26, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): slow-decay inharmonic index
                .init(outputLevel: 48, frequencyCoarse: 7, frequencyFine: 12, detune: 8, feedback: 3, egRate2: 55, egRate3: 34, egRate4: 33, egLevel2: 22, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 16, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): high bell shimmer
            ],
            category: .keys,
            lfoPMD: 3
        ),

        /// Pure crystalline bell with no electric-piano fundamental and no pitch-modulation movement.
        /// Algorithm index 4 keeps three parallel pairs so OP1, OP3, and OP5 can speak as independent bell partials rather than one stacked piano tone.
        /// Carrier ratios 1, 4, and 9 form the main partial set, while the modulators use 3, 4, and 7 with fine offsets for inharmonic shimmer.
        /// Slow carrier decay rates keep the ring long, and near-zero modulator sustain lets the glassy sidebands disappear into a clean tail.
        /// LFO pitch depth and pitch sensitivity are disabled so the bell stays still and transparent.
        DX7Preset(
            name: "GLASS BELL",
            algorithm: 4,
            feedback: 2,
            operators: [
                .init(outputLevel: 96, frequencyCoarse: 1, detune: 7, egRate2: 36, egRate3: 20, egRate4: 18, egLevel2: 92, egLevel3: 75, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): low glass fundamental partial
                .init(outputLevel: 42, frequencyCoarse: 3, frequencyFine: 5, detune: 6, egRate2: 50, egRate3: 32, egRate4: 28, egLevel2: 30, egLevel3: 2, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): low inharmonic glass index
                .init(outputLevel: 87, frequencyCoarse: 4, detune: 8, egRate2: 40, egRate3: 22, egRate4: 17, egLevel2: 90, egLevel3: 68, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): fourth-ratio crystalline partial
                .init(outputLevel: 46, frequencyCoarse: 4, frequencyFine: 10, detune: 8, egRate2: 53, egRate3: 34, egRate4: 29, egLevel2: 26, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): fine-offset shimmer
                .init(outputLevel: 73, frequencyCoarse: 9, detune: 9, egRate2: 44, egRate3: 24, egRate4: 16, egLevel2: 88, egLevel3: 60, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): high bell partial
                .init(outputLevel: 50, frequencyCoarse: 7, frequencyFine: 15, detune: 9, feedback: 2, egRate2: 56, egRate3: 36, egRate4: 30, egLevel2: 20, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): high inharmonic sparkle
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
        /// High-coarse modulators on OP6 and OP4 create inharmonic content that reads as cold and synthetic rather than acoustic.
        /// Carrier rate-2 values are fast for an immediate attack, with level-3 plateaus kept in the 60-72 range for a glassy hold.
        /// Strong sine LFO pitch modulation adds shimmer after the transient without using amplitude tremolo.
        DX7Preset(
            name: "ICY BELL",
            algorithm: 6,
            feedback: 3,
            operators: [
                .init(outputLevel: 97, frequencyCoarse: 1, detune: 7, egRate2: 68, egRate3: 30, egRate4: 32, egLevel2: 92, egLevel3: 72, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): clear icy fundamental
                .init(outputLevel: 42, frequencyCoarse: 2, frequencyFine: 8, detune: 6, egRate2: 80, egRate3: 48, egRate4: 45, egLevel2: 30, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): bright lower attack
                .init(outputLevel: 88, frequencyCoarse: 2, frequencyFine: 2, detune: 8, egRate2: 72, egRate3: 27, egRate4: 31, egLevel2: 90, egLevel3: 63, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): shimmering upper body
                .init(outputLevel: 50, frequencyCoarse: 7, frequencyFine: 6, detune: 9, egRate2: 84, egRate3: 54, egRate4: 48, egLevel2: 26, egLevel3: 1, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 47, klsLeftDepth: 0, klsRightDepth: 14, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): high inharmonic ice edge
                .init(outputLevel: 46, frequencyCoarse: 3, frequencyFine: 3, detune: 7, egRate2: 76, egRate3: 44, egRate4: 42, egLevel2: 24, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): intermediate shimmer index
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
        /// The modulators decay quickly enough to make the mallet speak without leaving a harsh FM sustain.
        /// Sine LFO amplitude modulation is intentionally strong, with carrier amp-mod sensitivity raised so the tremolo pulses like a vibraphone motor.
        /// v4 release: egRate4 raised to 55/60 (carrier/modulator) for a medium vibraphone decay — faster than glass bells, slower than piano.
        DX7Preset(
            name: "VIBES",
            algorithm: 4,
            feedback: 1,
            operators: [
                .init(outputLevel: 97, frequencyCoarse: 1, detune: 7, egRate2: 48, egRate3: 31, egRate4: 55, egLevel2: 92, egLevel3: 80, velocitySensitivity: 2, ampModSensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): primary vibraphone bar
                .init(outputLevel: 46, frequencyCoarse: 4, frequencyFine: 0, detune: 6, egRate2: 67, egRate3: 43, egRate4: 60, egLevel2: 28, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 8, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): rounded mallet index
                .init(outputLevel: 88, frequencyCoarse: 1, detune: 8, egRate2: 51, egRate3: 29, egRate4: 55, egLevel2: 90, egLevel3: 76, velocitySensitivity: 2, ampModSensitivity: 3, keyboardRateScaling: 1), // OP3 (carrier): secondary resonant bar
                .init(outputLevel: 48, frequencyCoarse: 4, frequencyFine: 2, detune: 8, egRate2: 70, egRate3: 46, egRate4: 60, egLevel2: 24, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): bell bar overtone
                .init(outputLevel: 76, frequencyCoarse: 1, detune: 9, egRate2: 54, egRate3: 27, egRate4: 55, egLevel2: 88, egLevel3: 72, velocitySensitivity: 1, ampModSensitivity: 3, keyboardRateScaling: 1), // OP5 (carrier): quiet tertiary bar layer
                .init(outputLevel: 42, frequencyCoarse: 4, frequencyFine: 4, detune: 9, feedback: 1, egRate2: 73, egRate3: 49, egRate4: 60, egLevel2: 20, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 48, klsLeftDepth: 0, klsRightDepth: 12, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): upper mallet brightness
            ],
            category: .keys,
            lfoSpeed: 38,
            lfoPMD: 0,
            lfoAMD: 65,
            lfoWaveform: 4
        ),

        /// Bright digital piano with fast hammer definition, clean sustain, and a narrow chorused spread between carriers.
        /// Algorithm 1 puts a complex OP6->OP5->OP4->OP3 stack beside the simpler OP2->OP1 pair for a crisp layered attack.
        /// OP1 gives the centered fundamental, OP3 is slightly detuned for width, and the upper stack decays quickly so brightness leaves before the body.
        /// Feedback on OP6 generates a fine digital edge; high modulator velocity makes hard playing open the attack without over-bright sustain.
        /// v3 plateau lift: the two carriers now sustain on 90-94 level-2 and 76-82 level-3 plateaus, while the hammer stack is lowered to 44-48 output with 20-32 level-2 transient energy and no lingering modulator sustain.
        /// v4 release: egRate4 raised to 75 across all operators for crisp staccato decay.
        DX7Preset(
            name: "DIGI PIANO",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 97, detune: 6, egRate2: 72, egRate3: 43, egRate4: 75, egLevel2: 94, egLevel3: 82, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): clean fundamental
                .init(outputLevel: 48, frequencyCoarse: 2, frequencyFine: 2, detune: 7, egRate2: 86, egRate3: 60, egRate4: 75, egLevel2: 32, egLevel3: 1, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 0, klsLeftDepth: 0, klsRightDepth: 7, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): bright hammer partial
                .init(outputLevel: 85, detune: 8, egRate2: 69, egRate3: 41, egRate4: 75, egLevel2: 90, egLevel3: 76, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): detuned digital body
                .init(outputLevel: 48, frequencyCoarse: 3, frequencyFine: 1, detune: 8, egRate2: 84, egRate3: 57, egRate4: 75, egLevel2: 29, egLevel3: 1, velocitySensitivity: 5, keyboardRateScaling: 3, klsBreakPoint: 0, klsLeftDepth: 0, klsRightDepth: 10, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): primary glass index
                .init(outputLevel: 44, frequencyCoarse: 2, frequencyFine: 7, detune: 6, egRate2: 90, egRate3: 66, egRate4: 75, egLevel2: 24, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator -> OP4): transient sharpening stage
                .init(outputLevel: 48, frequencyCoarse: 9, frequencyFine: 3, detune: 9, feedback: 4, egRate2: 92, egRate3: 74, egRate4: 75, egLevel2: 20, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 13, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): fine attack fizz
            ],
            category: .keys
        ),
    ]
}
