// BrassPresets.swift
// M2DX-Core — Original hand-designed DX7-style brass presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// BRASS-category factory presets (Batch 3 of 8).
    static let brassBatch: [DX7Preset] = [
        /// Big section brass built from five parallel carriers, each holding a strong plateau for ensemble weight.
        /// Algorithm 22 lets OP1 through OP5 act as independent brass voices while OP6 applies a shared low-ratio brightness index to the whole section.
        /// The carrier coarse ratios spread across 1, 2, 3, 4, and 5 with small detune offsets, creating width without relying on sampled chorus.
        /// OP6 uses moderate feedback and velocity sensitivity so harder playing opens the section brightness while sustained notes settle into a broad brass body.
        DX7Preset(
            name: "BRASS",
            algorithm: 21,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0, detune: 5, feedback: 0, egRate1: 99, egRate2: 58, egRate3: 34, egRate4: 42, egLevel2: 91, egLevel3: 80, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 1, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): fundamental section voice
                .init(outputLevel: 97, frequencyCoarse: 2, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 99, egRate2: 57, egRate3: 33, egRate4: 42, egLevel2: 91, egLevel3: 81, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (carrier): octave brass body
                .init(outputLevel: 96, frequencyCoarse: 3, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 99, egRate2: 59, egRate3: 32, egRate4: 43, egLevel2: 90, egLevel3: 79, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): upper harmonic section voice
                .init(outputLevel: 96, frequencyCoarse: 4, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 99, egRate2: 60, egRate3: 31, egRate4: 44, egLevel2: 89, egLevel3: 77, velocitySensitivity: 1, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (carrier): bright ensemble partial
                .init(outputLevel: 95, frequencyCoarse: 5, frequencyFine: 0, detune: 9, feedback: 0, egRate1: 99, egRate2: 61, egRate3: 30, egRate4: 45, egLevel2: 88, egLevel3: 75, velocitySensitivity: 1, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 5, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (carrier): high brass sheen layer
                .init(outputLevel: 52, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 4, egRate1: 99, egRate2: 63, egRate3: 48, egRate4: 52, egLevel2: 32, egLevel3: 1, velocitySensitivity: 5, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 4, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP1..OP5, feedback): shared brass brightness
            ],
            category: .brass,
            lfoSpeed: 35,
            lfoPMD: 2,
            lfoPMS: 3
        ),

        /// Solo trumpet with a focused main carrier, a bright secondary carrier, and a compact stacked buzz branch.
        /// Algorithm 1 keeps OP1 as the centered horn body while OP3 carries the sharper octave-colored brass tone.
        /// OP6 feedback drives the OP6->OP5->OP4->OP3 stack, producing lip buzz that responds strongly to velocity without leaving a heavy sustained modulator shelf.
        /// A delayed sine pitch LFO provides clear trumpet vibrato after the attack, while the carrier plateaus keep held notes full and stable.
        DX7Preset(
            name: "TRUMPET",
            algorithm: 0,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 99, egRate2: 74, egRate3: 38, egRate4: 49, egLevel2: 92, egLevel3: 80, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): focused trumpet fundamental
                .init(outputLevel: 48, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 99, egRate2: 76, egRate3: 58, egRate4: 54, egLevel2: 30, egLevel3: 1, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 42, klsLeftDepth: 3, klsRightDepth: 5, klsLeftCurve: 1, klsRightCurve: 3), // OP2 (modulator -> OP1): tight low-ratio lip edge
                .init(outputLevel: 96, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 99, egRate2: 73, egRate3: 36, egRate4: 48, egLevel2: 92, egLevel3: 80, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): bright octave brass body
                .init(outputLevel: 54, frequencyCoarse: 2, frequencyFine: 4, detune: 8, feedback: 0, egRate1: 99, egRate2: 77, egRate3: 62, egRate4: 56, egLevel2: 32, egLevel3: 1, velocitySensitivity: 5, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 45, klsLeftDepth: 2, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP4 (modulator -> OP3): bright trumpet bite
                .init(outputLevel: 46, frequencyCoarse: 3, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 99, egRate2: 78, egRate3: 64, egRate4: 57, egLevel2: 28, egLevel3: 1, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 45, klsLeftDepth: 2, klsRightDepth: 7, klsLeftCurve: 1, klsRightCurve: 3), // OP5 (modulator -> OP4): compact harmonic pressure
                .init(outputLevel: 56, frequencyCoarse: 1, frequencyFine: 0, detune: 9, feedback: 5, egRate1: 99, egRate2: 78, egRate3: 66, egRate4: 58, egLevel2: 34, egLevel3: 0, velocitySensitivity: 6, ampModSensitivity: 0, keyboardRateScaling: 3, klsBreakPoint: 46, klsLeftDepth: 4, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): velocity-driven trumpet buzz
            ],
            category: .brass,
            lfoSpeed: 42,
            lfoDelay: 30,
            lfoPMD: 8,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Deep low brass with a slower swell, darker stacked modulation, and a lowered playing register.
        /// Algorithm 1 uses OP1 for the broad trombone fundamental and OP3 for a restrained octave body that thickens the tone without becoming trumpet-bright.
        /// The OP6 feedback branch is kept lower than the trumpet patch, so the buzz supports the bore resonance rather than dominating the sound.
        /// Slow carrier rate-2 values and high level-3 plateaus create a rounded sustaining brass tone, with delayed pitch modulation adding gentle natural movement.
        DX7Preset(
            name: "TROMBONE",
            algorithm: 0,
            feedback: 3,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 99, egRate2: 48, egRate3: 27, egRate4: 39, egLevel2: 90, egLevel3: 78, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 0, klsRightDepth: 1, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): broad low-brass fundamental
                .init(outputLevel: 42, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 99, egRate2: 51, egRate3: 42, egRate4: 47, egLevel2: 28, egLevel3: 2, velocitySensitivity: 3, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 39, klsLeftDepth: 3, klsRightDepth: 2, klsLeftCurve: 1, klsRightCurve: 3), // OP2 (modulator -> OP1): mellow bore color
                .init(outputLevel: 95, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 99, egRate2: 48, egRate3: 28, egRate4: 40, egLevel2: 90, egLevel3: 78, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): low octave brass body
                .init(outputLevel: 45, frequencyCoarse: 1, frequencyFine: 8, detune: 8, feedback: 0, egRate1: 99, egRate2: 50, egRate3: 43, egRate4: 48, egLevel2: 30, egLevel3: 1, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 42, klsLeftDepth: 3, klsRightDepth: 4, klsLeftCurve: 1, klsRightCurve: 3), // OP4 (modulator -> OP3): dark slide-brass edge
                .init(outputLevel: 40, frequencyCoarse: 2, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 99, egRate2: 52, egRate3: 44, egRate4: 49, egLevel2: 26, egLevel3: 1, velocitySensitivity: 3, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 42, klsLeftDepth: 4, klsRightDepth: 3, klsLeftCurve: 1, klsRightCurve: 3), // OP5 (modulator -> OP4): subdued harmonic weight
                .init(outputLevel: 47, frequencyCoarse: 1, frequencyFine: 0, detune: 8, feedback: 3, egRate1: 99, egRate2: 52, egRate3: 46, egRate4: 50, egLevel2: 32, egLevel3: 0, velocitySensitivity: 5, ampModSensitivity: 0, keyboardRateScaling: 2, klsBreakPoint: 43, klsLeftDepth: 5, klsRightDepth: 5, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): darker low-brass buzz
            ],
            category: .brass,
            lfoSpeed: 28,
            lfoDelay: 35,
            lfoPMD: 4,
            lfoPMS: 3,
            transpose: -12
        ),
    ]
}
