// StringsPresets.swift
// M2DX-Core — Original hand-designed DX7-style strings & pad presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// STRINGS-category factory presets (Batch 4 of 8).
    static let stringsBatch: [DX7Preset] = [
        /// Ensemble string pad built from four parallel carriers for a wide unison wash.
        /// Algorithm 29 leaves OP1, OP2, OP3, and OP5 as independent carriers, while OP4->OP3 and OP6->OP5 add bow-like harmonic pressure.
        /// Detune spread across the carrier set creates slow beating without relying on sampled ensemble motion.
        /// OP6 feedback and velocity sensitivity make harder playing open the bow edge on the OP5 branch.
        /// Slow carrier attack and release values keep the tone swelling and fading like a sustained string section.
        DX7Preset(
            name: "STRINGS",
            algorithm: 28,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 40, egRate3: 34, egRate4: 42, egLevel1: 99, egLevel2: 92, egLevel3: 90, velocitySensitivity: 1, keyboardRateScaling: 1), // OP1 (carrier): centered ensemble fundamental
                .init(outputLevel: 94, frequencyCoarse: 1, detune: 9, egRate1: 99, egRate2: 40, egRate3: 32, egRate4: 42, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP2 (carrier): positive-detuned ensemble layer
                .init(outputLevel: 95, frequencyCoarse: 1, detune: 5, egRate1: 99, egRate2: 40, egRate3: 33, egRate4: 42, egLevel1: 99, egLevel2: 92, egLevel3: 89, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): negative-detuned bowed body
                .init(outputLevel: 48, frequencyCoarse: 2, detune: 6, egRate1: 99, egRate2: 48, egRate3: 42, egRate4: 46, egLevel1: 99, egLevel2: 30, egLevel3: 2, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 45, klsLeftDepth: 8, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP4 (modulator -> OP3): bowed second-harmonic sheen
                .init(outputLevel: 92, frequencyCoarse: 1, detune: 8, egRate1: 99, egRate2: 40, egRate3: 31, egRate4: 42, egLevel1: 99, egLevel2: 90, egLevel3: 86, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): wide outer ensemble layer
                .init(outputLevel: 52, frequencyCoarse: 2, detune: 8, feedback: 5, egRate1: 99, egRate2: 50, egRate3: 44, egRate4: 48, egLevel1: 99, egLevel2: 26, egLevel3: 1, velocitySensitivity: 4, keyboardRateScaling: 2, klsBreakPoint: 46, klsLeftDepth: 10, klsRightDepth: 12, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): velocity-driven bow pressure
            ],
            category: .strings,
            lfoSpeed: 40,
            lfoDelay: 18,
            lfoPMD: 5,
            lfoWaveform: 4,
            lfoPMS: 3
        ),

        /// Warm analog-style pad with three parallel FM pairs blended into a steady sustained body.
        /// Algorithm 5 separates OP2->OP1, OP4->OP3, and OP6->OP5 so each branch can contribute a different harmonic color.
        /// The carrier detunes create chorus-like width, while the modulators use low to mid ratios for rounded formant movement.
        /// Modulator sustain is nearly removed so the attack blooms brighter and then settles into a smooth carrier plateau.
        /// Triangle LFO pitch and amplitude motion add slow pad movement without turning the sound into obvious vibrato.
        DX7Preset(
            name: "PAD WARM",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 33, egRate3: 24, egRate4: 38, egLevel1: 99, egLevel2: 92, egLevel3: 92, velocitySensitivity: 1, ampModSensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): centered warm pad body
                .init(outputLevel: 44, frequencyCoarse: 1, detune: 6, egRate1: 99, egRate2: 42, egRate3: 34, egRate4: 42, egLevel1: 99, egLevel2: 32, egLevel3: 2, velocitySensitivity: 3, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 6, klsRightDepth: 8, klsLeftCurve: 1, klsRightCurve: 3), // OP2 (modulator -> OP1): warm low-ratio formant
                .init(outputLevel: 95, frequencyCoarse: 1, detune: 9, egRate1: 99, egRate2: 33, egRate3: 24, egRate4: 38, egLevel1: 99, egLevel2: 92, egLevel3: 90, velocitySensitivity: 1, ampModSensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): lightly detuned chorus layer
                .init(outputLevel: 42, frequencyCoarse: 2, detune: 6, egRate1: 99, egRate2: 44, egRate3: 36, egRate4: 43, egLevel1: 99, egLevel2: 28, egLevel3: 1, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 45, klsLeftDepth: 7, klsRightDepth: 10, klsLeftCurve: 1, klsRightCurve: 3), // OP4 (modulator -> OP3): octave warmth and vowel color
                .init(outputLevel: 92, frequencyCoarse: 1, detune: 5, egRate1: 99, egRate2: 33, egRate3: 23, egRate4: 38, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, ampModSensitivity: 2, keyboardRateScaling: 1), // OP5 (carrier): wide upper pad layer
                .init(outputLevel: 40, frequencyCoarse: 3, detune: 8, feedback: 3, egRate1: 99, egRate2: 46, egRate3: 38, egRate4: 44, egLevel1: 99, egLevel2: 24, egLevel3: 0, velocitySensitivity: 3, keyboardRateScaling: 2, klsBreakPoint: 47, klsLeftDepth: 8, klsRightDepth: 12, klsLeftCurve: 1, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): soft upper formant haze
            ],
            category: .strings,
            lfoSpeed: 32,
            lfoPMD: 3,
            lfoAMD: 8,
            lfoWaveform: 0,
            lfoPMS: 3
        ),

        /// Glassy additive pad made from six parallel carriers rather than a modulated FM stack.
        /// Algorithm 32 lets each operator speak as a harmonic partial, creating a clear shimmering tone with no feedback grit.
        /// OP1 carries the fundamental, while OP2 through OP6 add progressively quieter octave and upper-partial energy.
        /// Alternating detunes spread the partials into a wide, gently beating glass texture.
        /// Slow attack, high sustain plateaus, and sine LFO pitch motion keep the sound floating and transparent.
        DX7Preset(
            name: "PAD GLASS",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(outputLevel: 96, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP1 (carrier): glass fundamental
                .init(outputLevel: 70, frequencyCoarse: 2, detune: 9, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP2 (carrier): octave shimmer
                .init(outputLevel: 48, frequencyCoarse: 3, detune: 5, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): fifth-like upper partial
                .init(outputLevel: 38, frequencyCoarse: 4, detune: 9, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP4 (carrier): second-octave glass partial
                .init(outputLevel: 32, frequencyCoarse: 5, detune: 5, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP5 (carrier): high fifth shimmer
                .init(outputLevel: 24, frequencyCoarse: 8, detune: 9, egRate1: 99, egRate2: 35, egRate3: 28, egRate4: 40, egLevel1: 99, egLevel2: 91, egLevel3: 88, velocitySensitivity: 1, keyboardRateScaling: 1), // OP6 (carrier): airy high partial
            ],
            category: .strings,
            lfoSpeed: 38,
            lfoPMD: 4,
            lfoWaveform: 4,
            lfoPMS: 4
        ),
    ]
}
