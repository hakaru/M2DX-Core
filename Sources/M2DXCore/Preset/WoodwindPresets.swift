// WoodwindPresets.swift
// M2DX-Core — Original hand-designed DX7-style woodwind presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// WOODWIND-category factory presets (Batch 7 of 8).
    static let woodwindBatch: [DX7Preset] = [
        /// Soft breathy flute built on a single primary carrier with a quiet octave layer (Alg 1).
        /// Carrier egRate1 56-57 gives a ~34 ms breath-swell onset as air finds the aperture;
        /// velocitySensitivity is deliberately gentle everywhere (carrier 1/0, modulators 0-1)
        /// because flute dynamics barely change level (≤4 dB) or brightness with key velocity.
        /// OP2 supplies a small velocity-independent chiff burst (fast decay to a near-zero
        /// shelf); OP4-OP6 stack into OP3 at low output, since flute has almost no upper
        /// harmonic energy beyond the fundamental and a faint second partial.
        /// A delayed sine LFO with a very light amplitude-mod index adds subtle breath flutter
        /// without shifting the amplitude peak away from the onset.
        DX7Preset(
            name: "FLUTE",
            algorithm: 0,
            feedback: 0,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, detune: 7, egRate1: 57, egRate2: 60, egRate3: 30, egRate4: 38, egLevel1: 99, egLevel2: 92, egLevel3: 90, egLevel4: 0, velocitySensitivity: 1, ampModSensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 1, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): primary flute fundamental, 20-80ms breath swell
                .init(outputLevel: 42, frequencyCoarse: 1, detune: 7, egRate1: 90, egRate2: 62, egRate3: 50, egRate4: 45, egLevel1: 99, egLevel2: 38, egLevel3: 2, egLevel4: 0, velocitySensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator → OP1): velocity-independent breath chiff, fast decay
                .init(outputLevel: 60, frequencyCoarse: 2, detune: 7, egRate1: 56, egRate2: 60, egRate3: 30, egRate4: 38, egLevel1: 99, egLevel2: 91, egLevel3: 89, egLevel4: 0, velocitySensitivity: 0, ampModSensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): secondary octave color, very low level
                .init(outputLevel: 35, frequencyCoarse: 2, detune: 6, egRate1: 90, egRate2: 64, egRate3: 52, egRate4: 46, egLevel1: 99, egLevel2: 28, egLevel3: 1, egLevel4: 0, velocitySensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator → OP3): faint upper harmonic
                .init(outputLevel: 40, frequencyCoarse: 3, detune: 7, egRate1: 90, egRate2: 65, egRate3: 53, egRate4: 47, egLevel1: 99, egLevel2: 24, egLevel3: 1, egLevel4: 0, velocitySensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (modulator → OP4): second-stage harmonic damper
                .init(outputLevel: 35, frequencyCoarse: 1, detune: 8, egRate1: 90, egRate2: 66, egRate3: 55, egRate4: 48, egLevel1: 99, egLevel2: 20, egLevel3: 0, egLevel4: 0, velocitySensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator → OP5): root of stack, gentle noise source
            ],
            category: .woodwind,
            lfoSpeed: 38,
            lfoDelay: 28,
            lfoPMD: 6,
            lfoAMD: 2,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Reedy double-reed oboe built on Alg 1 with odd-harmonic carriers and a buzzing reed source.
        /// OP1 carries the fundamental; OP3 at coarse 3 boosts the prominent third partial that
        /// distinguishes a double reed from a flute or clarinet.
        /// Carrier egRate1 57 models the ~42 ms reed-speak onset; carrier velocitySensitivity 1
        /// and low modulator sensitivities (1-2) keep the velocity response wind-gentle — an oboe's
        /// tone stays remarkably stable across playing dynamics (≤4 dB level, ≤1.3x brightness).
        /// OP6 with feedback 5 at the base of the modulator chain provides the nasal buzzing reed;
        /// modulators OP4 (coarse 5) and OP5 (coarse 3) reinforce odd-harmonic spectral emphasis,
        /// and a delayed sine LFO adds the characteristic oboe pitch vibrato.
        DX7Preset(
            name: "OBOE",
            algorithm: 0,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, detune: 7, egRate1: 57, egRate2: 70, egRate3: 35, egRate4: 45, egLevel1: 99, egLevel2: 92, egLevel3: 86, egLevel4: 0, velocitySensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): oboe fundamental body, 20-80ms reed-speak onset
                .init(outputLevel: 42, frequencyCoarse: 1, detune: 7, egRate1: 90, egRate2: 72, egRate3: 56, egRate4: 50, egLevel1: 99, egLevel2: 36, egLevel3: 2, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator → OP1): reed edge, near-velocity-independent
                .init(outputLevel: 78, frequencyCoarse: 3, detune: 7, egRate1: 57, egRate2: 70, egRate3: 36, egRate4: 46, egLevel1: 99, egLevel2: 91, egLevel3: 84, egLevel4: 0, velocitySensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): odd-third-harmonic boost
                .init(outputLevel: 50, frequencyCoarse: 5, detune: 6, egRate1: 90, egRate2: 73, egRate3: 58, egRate4: 52, egLevel1: 99, egLevel2: 34, egLevel3: 1, egLevel4: 0, velocitySensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator → OP3): coarse 5 fifth-harmonic reed brightness
                .init(outputLevel: 46, frequencyCoarse: 3, detune: 8, egRate1: 90, egRate2: 74, egRate3: 59, egRate4: 53, egLevel1: 99, egLevel2: 32, egLevel3: 1, egLevel4: 0, velocitySensitivity: 1, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (modulator → OP4): odd third-partial pressure
                .init(outputLevel: 50, frequencyCoarse: 1, detune: 9, feedback: 5, egRate1: 90, egRate2: 75, egRate3: 62, egRate4: 55, egLevel1: 99, egLevel2: 38, egLevel3: 0, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator → OP5, feedback): buzzing reed source, gentle velocity tracking
            ],
            category: .woodwind,
            lfoSpeed: 40,
            lfoDelay: 25,
            lfoPMD: 7,
            lfoWaveform: 4,
            lfoPMS: 4
        ),
    ]
}
