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
        /// Modulators run hot (56-70) at velocity sensitivity 6 so soft strokes stay a round
        /// wooden thump and hard strikes open the formant; modulator and carrier releases are
        /// matched (~42-46) so the bar rings down naturally for about a second with the wood
        /// color decaying in step, instead of being chopped off at noteOff.
        /// OP5 is a quiet 24th-partial carrier (the ~3 kHz mallet click of a real rosewood bar):
        /// it speaks in the strike and leaves a faint trace in the ring so the brightness fades
        /// with the note rather than vanishing at noteOff.
        DX7Preset(
            name: "MARIMBA",
            algorithm: 4,
            feedback: 0,
            operators: [
                .init(outputLevel: 98, detune: 7, egRate2: 78, egRate3: 38, egRate4: 42, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): primary body
                .init(outputLevel: 70, detune: 7, egRate2: 60, egRate3: 42, egRate4: 46, egLevel2: 38, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP2 (modulator → OP1): velocity-opened warm wood color
                .init(outputLevel: 86, detune: 7, egRate2: 78, egRate3: 38, egRate4: 42, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): upper body
                .init(outputLevel: 68, frequencyCoarse: 4, detune: 7, egRate2: 62, egRate3: 42, egRate4: 46, egLevel2: 34, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP4 (modulator → OP3): velocity-opened 4× wooden formant
                .init(outputLevel: 66, frequencyCoarse: 24, detune: 7, egRate2: 52, egRate3: 26, egRate4: 38, egLevel2: 88, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP5 (carrier): velocity-gated 24th-partial mallet click, rings faintly
                .init(outputLevel: 30, frequencyCoarse: 2, detune: 7, egRate2: 62, egRate3: 42, egRate4: 46, egLevel2: 30, egLevel3: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP6 (modulator → OP5): light color on the click partial
            ],
            category: .percussion
        ),

        /// Bright xylophone with crisp glassy attack and a tight-but-real ring (Alg 5).
        /// Higher modulator coarse ratios than MARIMBA (OP4 at 8×, OP6 at 4×) push strong upper
        /// partials into the tone, giving xylo its characteristic glassy edge.
        /// Slight inharmonic offset on OP4 (frequencyFine 5) breaks the strict octave alignment
        /// for the bell-like wood-with-metal-edge character of a real xylophone bar.
        /// Carrier and modulator releases are matched (~44-48) so the bar rings down over roughly
        /// a second with the metallic edge decaying in step — drier than marimba via the faster
        /// rate-2 strike segment, not via chopping the tail at noteOff.
        /// OP5 is a quiet 12th-partial carrier supplying the glassy ping of the strike and a fading
        /// trace of it in the ring; OP4 runs hot (74) at sensitivity 6 for the velocity-opened edge.
        DX7Preset(
            name: "XYLO",
            algorithm: 4,
            feedback: 0,
            operators: [
                .init(outputLevel: 97, detune: 7, egRate2: 80, egRate3: 40, egRate4: 44, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): bright fundamental
                .init(outputLevel: 68, detune: 7, egRate2: 64, egRate3: 44, egRate4: 48, egLevel2: 34, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP2 (modulator → OP1): velocity-opened fundamental color
                .init(outputLevel: 86, detune: 7, egRate2: 80, egRate3: 40, egRate4: 44, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): mid layer
                .init(outputLevel: 70, frequencyCoarse: 8, frequencyFine: 5, detune: 7, egRate2: 66, egRate3: 44, egRate4: 48, egLevel2: 26, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP4 (modulator → OP3): velocity-opened 8× metallic-wood edge
                .init(outputLevel: 54, frequencyCoarse: 12, detune: 7, egRate2: 52, egRate3: 24, egRate4: 37, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP5 (carrier): quiet 12th-partial glassy ping, rings faintly
                .init(outputLevel: 30, frequencyCoarse: 4, detune: 7, egRate2: 66, egRate3: 44, egRate4: 48, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP6 (modulator → OP5): light color on the ping partial
            ],
            category: .percussion
        ),

        /// Thumb piano (kalimba) with metal-tine pluck character and natural detune beat.
        /// Algorithm 5 (was 15): the original three-tine intent needs three real carriers, so
        /// OP1/OP3/OP5 are now independent sounding tines (detune 5/7/9 for the gentle beat)
        /// instead of OP5 being buried as a second-order modulator.
        /// Modulators OP2/OP4 run hot (62-68) at velocity sensitivity 6 so a firmer thumb stroke
        /// brightens the pluck; matched releases (~44-52) let the tine ring close to a second,
        /// keeping the kalimba duller than a xylophone but never choked at noteOff.
        /// OP5 is a quiet 12th-partial tine mode — the faint metallic ping of the tongue — with a
        /// slightly faster fade so the tail stays predominantly mellow.
        DX7Preset(
            name: "KALIMBA",
            algorithm: 4,
            feedback: 3,
            operators: [
                .init(outputLevel: 96, detune: 5, egRate2: 75, egRate3: 40, egRate4: 44, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP1 (carrier): primary tine
                .init(outputLevel: 68, frequencyCoarse: 2, frequencyFine: 4, detune: 7, egRate2: 62, egRate3: 44, egRate4: 48, egLevel2: 36, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP2 (modulator → OP1): velocity-opened inharmonic tine color
                .init(outputLevel: 86, detune: 7, egRate2: 75, egRate3: 40, egRate4: 44, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 2), // OP3 (carrier): second tine, slightly detuned
                .init(outputLevel: 62, frequencyCoarse: 3, detune: 7, egRate2: 62, egRate3: 44, egRate4: 48, egLevel2: 32, egLevel3: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP4 (modulator → OP3): velocity-opened metallic pluck
                .init(outputLevel: 54, frequencyCoarse: 12, detune: 9, egRate2: 52, egRate3: 25, egRate4: 37, egLevel2: 88, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP5 (carrier): velocity-gated 12th-partial tine ping, rings faintly
                .init(outputLevel: 24, frequencyCoarse: 2, frequencyFine: 8, detune: 7, feedback: 3, egRate2: 70, egRate3: 44, egRate4: 48, egLevel2: 20, egLevel3: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP6 (modulator → OP5, feedback): light inharmonic sheen on the ping
            ],
            category: .percussion,
            lfoPMD: 2
        ),
    ]
}
