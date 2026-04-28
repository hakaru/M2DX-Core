// KeysPresets.swift
// M2DX-Core — Original hand-designed DX7-style key presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// KEYS-category factory presets (Batch 1 of 8).
    static let keysBatch: [DX7Preset] = [
        /// Warm Rhodes-like electric piano with a rounded fundamental, woody mid body, and a short metallic tine.
        /// Algorithm 5 keeps three independent modulator-carrier pairs, so OP6->OP5 can add tine without hardening the whole patch.
        /// OP2->OP1 supplies low body, OP4->OP3 supplies the struck bar, and OP6 feedback adds a controlled noisy edge to the high-ratio tine.
        /// Velocity sensitivity is concentrated on the modulators, while negative-left KLS reduces modulation in the bass to keep low notes clean.
        /// Carriers hold 88-92 level-2 and 72-80 level-3 plateaus while modulators stay in low transient ranges with near-zero sustain for a clear held body.
        /// Release egRate4 is set to 72/75 (carrier/modulator) so staccato playing decays cleanly instead of ringing.
        DX7Preset(
            name: "E.PIANO",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 97, detune: 6, egRate2: 58, egRate3: 37, egRate4: 72, egLevel2: 92, egLevel3: 80, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): warm fundamental sustain
                .init(outputLevel: 42, frequencyFine: 3, egRate2: 70, egRate3: 45, egRate4: 75, egLevel2: 30, egLevel3: 2, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 18, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP2 (modulator -> OP1): soft low-ratio bark
                .init(outputLevel: 88, detune: 8, egRate2: 62, egRate3: 34, egRate4: 72, egLevel2: 90, egLevel3: 78, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): midrange tine body
                .init(outputLevel: 46, frequencyCoarse: 2, detune: 8, egRate2: 76, egRate3: 49, egRate4: 75, egLevel2: 27, egLevel3: 1, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 24, klsRightDepth: 0, klsLeftCurve: 1, klsRightCurve: 0), // OP4 (modulator -> OP3): velocity-opened hammer overtone
                .init(outputLevel: 75, detune: 7, egRate2: 71, egRate3: 52, egRate4: 72, egLevel2: 88, egLevel3: 72, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): short metallic tine carrier
                .init(outputLevel: 52, frequencyCoarse: 8, frequencyFine: 6, detune: 9, feedback: 3, egRate2: 83, egRate3: 68, egRate4: 75, egLevel2: 24, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 31, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): bright tine attack
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
