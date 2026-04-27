// PercussionPresets.swift
// M2DX-Core — Original hand-designed DX7-style percussion presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// PERCUSSION-category factory presets (Batch 6 of 8).
    static let percussionBatch: [DX7Preset] = [
        /// Warm wooden marimba with three parallel modulator-carrier pairs (Alg 5).
        /// Each pair gives an independent layer of the mallet sound: primary body (OP2→OP1),
        /// 4×-ratio wooden formant (OP4→OP3), and a softer ambience layer (OP6→OP5).
        /// Modulators carry just enough index to produce the hollow wood character without
        /// the metallic edge of a vibraphone, and velocity sensitivity 4-5 on the modulators
        /// lets harder strikes add brightness like a real mallet attack.
        DX7Preset(
            name: "MARIMBA",
            algorithm: 4,
            feedback: 0,
            operators: [
                .init(outputLevel: 98, detune: 7, egRate2: 78, egRate3: 70, egRate4: 78, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 3), // OP1 (carrier): primary body
                .init(outputLevel: 38, detune: 7, egRate2: 78, egRate3: 72, egRate4: 80, egLevel2: 30, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3), // OP2 (modulator → OP1): warm wood color
                .init(outputLevel: 86, detune: 7, egRate2: 78, egRate3: 70, egRate4: 78, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 3), // OP3 (carrier): upper body
                .init(outputLevel: 50, frequencyCoarse: 4, detune: 7, egRate2: 75, egRate3: 70, egRate4: 80, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 3), // OP4 (modulator → OP3): 4× wooden formant
                .init(outputLevel: 70, detune: 7, egRate2: 78, egRate3: 70, egRate4: 78, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 3), // OP5 (carrier): ambience layer
                .init(outputLevel: 42, frequencyCoarse: 2, detune: 7, egRate2: 75, egRate3: 70, egRate4: 80, egLevel2: 24, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 3), // OP6 (modulator → OP5): 2× harmonic tint
            ],
            category: .percussion
        ),

        /// Bright xylophone with crisp glassy attack and fast decay (Alg 5).
        /// Higher modulator coarse ratios than MARIMBA (OP4 at 8×, OP6 at 4×) push strong upper
        /// partials into the tone, giving xylo its characteristic glassy edge.
        /// Faster egRate3 shortens the decay further than marimba so the sound is drier and tighter.
        /// Slight inharmonic offset on OP4 (frequencyFine 5) breaks the strict octave alignment
        /// for the bell-like wood-with-metal-edge character of a real xylophone bar.
        DX7Preset(
            name: "XYLO",
            algorithm: 4,
            feedback: 0,
            operators: [
                .init(outputLevel: 97, detune: 7, egRate2: 80, egRate3: 80, egRate4: 82, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 4), // OP1 (carrier): bright fundamental
                .init(outputLevel: 40, detune: 7, egRate2: 80, egRate3: 80, egRate4: 82, egLevel2: 30, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4), // OP2 (modulator → OP1): fundamental color
                .init(outputLevel: 86, detune: 7, egRate2: 80, egRate3: 80, egRate4: 82, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 4), // OP3 (carrier): mid layer
                .init(outputLevel: 55, frequencyCoarse: 8, frequencyFine: 5, detune: 7, egRate2: 78, egRate3: 80, egRate4: 82, egLevel2: 26, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 4), // OP4 (modulator → OP3): 8× metallic-wood edge
                .init(outputLevel: 70, detune: 7, egRate2: 80, egRate3: 80, egRate4: 82, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 4), // OP5 (carrier): brightness layer
                .init(outputLevel: 52, frequencyCoarse: 4, detune: 7, egRate2: 78, egRate3: 80, egRate4: 82, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 4), // OP6 (modulator → OP5): 4× upper brilliance
            ],
            category: .percussion
        ),

        /// Thumb piano (kalimba) with metal-tine pluck character and natural detune beat (Alg 15).
        /// OP6 fans out to both the OP5 and the OP4→OP3 branches, giving a shared metallic attack
        /// transient that colors two simultaneous resonator voices.
        /// Three carriers OP1/OP3/OP5 detuned 5/7/9 produce the gentle natural beat between adjacent tines.
        /// OP6 feedback 3 and a slightly inharmonic OP6 ratio (coarse 2 fine 8) give the metal-tine
        /// shimmer; medium decay (egRate3 65) leaves a longer ring than marimba.
        DX7Preset(
            name: "KALIMBA",
            algorithm: 14,
            feedback: 3,
            operators: [
                .init(outputLevel: 96, detune: 5, egRate2: 75, egRate3: 65, egRate4: 75, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): primary tine
                .init(outputLevel: 44, frequencyCoarse: 2, frequencyFine: 4, detune: 7, egRate2: 75, egRate3: 68, egRate4: 75, egLevel2: 28, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP2 (modulator → OP1): inharmonic tine color
                .init(outputLevel: 86, detune: 7, egRate2: 75, egRate3: 65, egRate4: 75, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): second tine, slightly detuned
                .init(outputLevel: 40, frequencyCoarse: 3, detune: 7, egRate2: 75, egRate3: 68, egRate4: 75, egLevel2: 26, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP4 (modulator → OP3): metallic attack
                .init(outputLevel: 76, detune: 9, egRate2: 75, egRate3: 65, egRate4: 75, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP5 (carrier): third tine, most detuned
                .init(outputLevel: 48, frequencyCoarse: 2, frequencyFine: 8, detune: 7, feedback: 3, egRate2: 75, egRate3: 68, egRate4: 75, egLevel2: 34, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP6 (modulator → OP5/OP4 branch, feedback): shared metal pluck
            ],
            category: .percussion,
            lfoPMD: 2
        ),
    ]
}
