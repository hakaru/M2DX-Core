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
        DX7Preset(
            name: "E.PIANO 1",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 87, detune: 6, egRate2: 58, egRate3: 37, egRate4: 43, egLevel2: 82, egLevel3: 45, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): warm fundamental sustain
                .init(outputLevel: 55, frequencyFine: 3, egRate2: 70, egRate3: 45, egRate4: 51, egLevel2: 56, egLevel3: 12, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 41, klsLeftDepth: 18, klsLeftCurve: 1), // OP2 (modulator -> OP1): soft low-ratio bark
                .init(outputLevel: 78, detune: 8, egRate2: 62, egRate3: 34, egRate4: 46, egLevel2: 74, egLevel3: 33, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): midrange tine body
                .init(outputLevel: 63, frequencyCoarse: 2, detune: 8, egRate2: 76, egRate3: 49, egRate4: 55, egLevel2: 47, egLevel3: 10, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 24, klsLeftCurve: 1), // OP4 (modulator -> OP3): velocity-opened hammer overtone
                .init(outputLevel: 61, detune: 7, egRate2: 71, egRate3: 52, egRate4: 58, egLevel2: 39, egLevel3: 8, velocitySensitivity: 1, keyboardRateScaling: 2), // OP5 (carrier): short metallic tine carrier
                .init(outputLevel: 72, frequencyCoarse: 8, frequencyFine: 6, detune: 9, feedback: 3, egRate2: 83, egRate3: 68, egRate4: 62, egLevel2: 34, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 3, klsBreakPoint: 44, klsLeftDepth: 31, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): bright tine attack
            ],
            category: .keys
        ),

        /// Dark Wurlitzer-style electric piano with less glass, slower release, and stronger reed/body emphasis.
        /// Algorithm 5 again separates the three pairs, but the modulator levels are lower so the tone compresses rather than sparkles.
        /// OP4->OP3 carries most of the growl, OP2->OP1 fills the fundamental, and OP6->OP5 is deliberately restrained for a muted bite.
        /// Longer carrier releases and gentler tine velocity keep the tail warm, while left-side KLS prevents bass mud.
        DX7Preset(
            name: "E.PIANO 2",
            algorithm: 4,
            feedback: 2,
            operators: [
                .init(outputLevel: 90, detune: 7, egRate2: 47, egRate3: 28, egRate4: 34, egLevel2: 86, egLevel3: 52, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): darker fundamental body
                .init(outputLevel: 42, frequencyFine: 1, detune: 6, egRate2: 58, egRate3: 34, egRate4: 39, egLevel2: 50, egLevel3: 18, velocitySensitivity: 3, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 14, klsLeftCurve: 1), // OP2 (modulator -> OP1): mild reed asymmetry
                .init(outputLevel: 85, frequencyFine: 1, detune: 8, egRate2: 50, egRate3: 30, egRate4: 36, egLevel2: 79, egLevel3: 48, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): warm mid body
                .init(outputLevel: 54, frequencyCoarse: 2, frequencyFine: 4, detune: 7, egRate2: 62, egRate3: 39, egRate4: 42, egLevel2: 59, egLevel3: 24, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 42, klsLeftDepth: 18, klsLeftCurve: 1), // OP4 (modulator -> OP3): body-forward bark
                .init(outputLevel: 49, detune: 6, egRate2: 57, egRate3: 38, egRate4: 41, egLevel2: 44, egLevel3: 17, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): subdued tine carrier
                .init(outputLevel: 48, frequencyCoarse: 5, frequencyFine: 8, detune: 8, feedback: 2, egRate2: 74, egRate3: 51, egRate4: 45, egLevel2: 25, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 44, klsLeftDepth: 22, klsLeftCurve: 1), // OP6 (modulator -> OP5, feedback): soft attack grit
            ],
            category: .keys
        ),

        /// Bright digital piano with fast hammer definition, clean sustain, and a narrow chorused spread between carriers.
        /// Algorithm 1 puts a complex OP6->OP5->OP4->OP3 stack beside the simpler OP2->OP1 pair for a crisp layered attack.
        /// OP1 gives the centered fundamental, OP3 is slightly detuned for width, and the upper stack decays quickly so brightness leaves before the body.
        /// Feedback on OP6 generates a fine digital edge; high modulator velocity makes hard playing open the attack without over-bright sustain.
        DX7Preset(
            name: "DIGI PIANO",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 86, detune: 6, egRate2: 72, egRate3: 43, egRate4: 57, egLevel2: 78, egLevel3: 35, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): clean fundamental
                .init(outputLevel: 57, frequencyCoarse: 2, frequencyFine: 2, detune: 7, egRate2: 86, egRate3: 60, egRate4: 65, egLevel2: 44, egLevel3: 4, velocitySensitivity: 4, keyboardRateScaling: 3, klsRightDepth: 7, klsRightCurve: 3), // OP2 (modulator -> OP1): bright hammer partial
                .init(outputLevel: 82, detune: 8, egRate2: 69, egRate3: 41, egRate4: 55, egLevel2: 73, egLevel3: 30, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): detuned digital body
                .init(outputLevel: 64, frequencyCoarse: 3, frequencyFine: 1, detune: 8, egRate2: 84, egRate3: 57, egRate4: 63, egLevel2: 42, egLevel3: 3, velocitySensitivity: 5, keyboardRateScaling: 3, klsRightDepth: 10, klsRightCurve: 3), // OP4 (modulator -> OP3): primary glass index
                .init(outputLevel: 49, frequencyCoarse: 2, frequencyFine: 7, detune: 6, egRate2: 90, egRate3: 66, egRate4: 70, egLevel2: 31, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3), // OP5 (modulator -> OP4): transient sharpening stage
                .init(outputLevel: 54, frequencyCoarse: 9, frequencyFine: 3, detune: 9, feedback: 4, egRate2: 92, egRate3: 74, egRate4: 72, egLevel2: 24, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4, klsBreakPoint: 46, klsRightDepth: 13, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): fine attack fizz
            ],
            category: .keys
        ),

        /// Clavichord-like plucked key with a dry snap, nasal midrange, and treble-forward bite.
        /// Algorithm 15 lets OP6 strike both OP5 directly and the OP4->OP3 branch, so one velocity-sensitive source drives two attack colors.
        /// OP2->OP1 adds the string body, OP4->OP3 gives the hollow clav formant, and OP5 adds a short upper pluck.
        /// Positive-right KLS on the bright modulators leans the attack toward the treble, with modest OP6 feedback for string scrape.
        DX7Preset(
            name: "CLAVI",
            algorithm: 14,
            feedback: 2,
            operators: [
                .init(outputLevel: 78, detune: 7, egRate2: 84, egRate3: 72, egRate4: 70, egLevel2: 42, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 3), // OP1 (carrier): short string body
                .init(outputLevel: 61, frequencyCoarse: 2, frequencyFine: 5, detune: 6, egRate2: 91, egRate3: 78, egRate4: 75, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4, klsBreakPoint: 47, klsRightDepth: 22, klsRightCurve: 3), // OP2 (modulator -> OP1): nasal pluck index
                .init(outputLevel: 74, frequencyFine: 2, detune: 8, egRate2: 86, egRate3: 74, egRate4: 71, egLevel2: 35, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 3), // OP3 (carrier): hollow clav mid
                .init(outputLevel: 66, frequencyCoarse: 3, frequencyFine: 3, detune: 7, egRate2: 93, egRate3: 81, egRate4: 78, egLevel2: 24, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4, klsBreakPoint: 48, klsRightDepth: 26, klsRightCurve: 3), // OP4 (modulator -> OP3): hard pick formant
                .init(outputLevel: 64, frequencyCoarse: 2, detune: 9, egRate2: 88, egRate3: 76, egRate4: 73, egLevel2: 30, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 4, klsRightDepth: 12, klsRightCurve: 3), // OP5 (carrier): upper pluck carrier
                .init(outputLevel: 70, frequencyCoarse: 5, frequencyFine: 11, detune: 8, feedback: 2, egRate2: 96, egRate3: 85, egRate4: 80, egLevel2: 18, egLevel3: 0, velocitySensitivity: 7, keyboardRateScaling: 5, klsBreakPoint: 49, klsRightDepth: 31, klsRightCurve: 3), // OP6 (modulator -> OP5/OP4, feedback): shared velocity snap
            ],
            category: .keys
        ),

        /// Harpsichord-style plucked keys with three crisp string pairs, low velocity response, and almost no sustained body.
        /// Algorithm 5 gives independent OP2->OP1, OP4->OP3, and OP6->OP5 pairs for separate string courses rather than one thick stack.
        /// OP3 is slightly detuned to imitate a second string, while OP6 feedback adds a small plectrum edge without turning noisy.
        /// Fast decay and short release on every pair make the sound speak immediately and then clear out.
        DX7Preset(
            name: "HARPSI",
            algorithm: 4,
            feedback: 1,
            operators: [
                .init(outputLevel: 80, detune: 7, egRate2: 91, egRate3: 82, egRate4: 76, egLevel2: 34, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 4), // OP1 (carrier): main plucked string
                .init(outputLevel: 70, frequencyCoarse: 2, frequencyFine: 1, detune: 7, egRate2: 96, egRate3: 87, egRate4: 80, egLevel2: 19, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 5, klsRightDepth: 11, klsRightCurve: 3), // OP2 (modulator -> OP1): quill brightness
                .init(outputLevel: 76, frequencyFine: 1, detune: 9, egRate2: 89, egRate3: 80, egRate4: 75, egLevel2: 31, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 4), // OP3 (carrier): detuned second string
                .init(outputLevel: 67, frequencyCoarse: 3, detune: 6, egRate2: 95, egRate3: 86, egRate4: 79, egLevel2: 16, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 5, klsRightDepth: 13, klsRightCurve: 3), // OP4 (modulator -> OP3): narrow metallic pluck
                .init(outputLevel: 62, frequencyCoarse: 2, detune: 8, egRate2: 92, egRate3: 83, egRate4: 77, egLevel2: 25, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 4), // OP5 (carrier): upper octave string course
                .init(outputLevel: 64, frequencyCoarse: 5, frequencyFine: 7, detune: 7, feedback: 1, egRate2: 97, egRate3: 89, egRate4: 81, egLevel2: 14, egLevel3: 0, velocitySensitivity: 1, keyboardRateScaling: 5, klsRightDepth: 15, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): crisp plectrum edge
            ],
            category: .keys
        ),

        /// Inharmonic tine bell with an electric-piano core, slow beating partials, and a long natural decay.
        /// Algorithm 7 combines OP2->OP1 for the struck fundamental with an inharmonic OP6->OP5->OP3 and OP4->OP3 bell branch.
        /// OP4 uses a 3.50 ratio and OP6 uses a high 7.x ratio so the overtones avoid simple octave locking while still reading as a keyed instrument.
        /// Feedback on OP6 roughens the bell onset, and a small pitch LFO adds shimmer after the attack without becoming vibrato-heavy.
        DX7Preset(
            name: "TINE BELL",
            algorithm: 6,
            feedback: 3,
            operators: [
                .init(outputLevel: 78, detune: 7, egRate2: 39, egRate3: 22, egRate4: 25, egLevel2: 72, egLevel3: 34, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): electric-piano fundamental
                .init(outputLevel: 47, frequencyCoarse: 2, frequencyFine: 9, detune: 6, egRate2: 52, egRate3: 31, egRate4: 30, egLevel2: 54, egLevel3: 9, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 43, klsRightDepth: 9, klsRightCurve: 3), // OP2 (modulator -> OP1): soft tine color
                .init(outputLevel: 82, frequencyFine: 14, detune: 8, egRate2: 34, egRate3: 18, egRate4: 21, egLevel2: 66, egLevel3: 26, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): sustained bell partial body
                .init(outputLevel: 58, frequencyCoarse: 3, frequencyFine: 50, detune: 9, egRate2: 47, egRate3: 27, egRate4: 28, egLevel2: 45, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 46, klsRightDepth: 12, klsRightCurve: 3), // OP4 (modulator -> OP3): 3.50-ratio bell sideband
                .init(outputLevel: 54, frequencyCoarse: 2, frequencyFine: 68, detune: 6, egRate2: 43, egRate3: 25, egRate4: 27, egLevel2: 40, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 2), // OP5 (modulator -> OP3): slow-decay inharmonic index
                .init(outputLevel: 46, frequencyCoarse: 7, frequencyFine: 12, detune: 8, feedback: 3, egRate2: 55, egRate3: 34, egRate4: 33, egLevel2: 32, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3, klsBreakPoint: 48, klsRightDepth: 16, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): high bell shimmer
            ],
            category: .keys,
            lfoPMD: 3
        ),
    ]
}
