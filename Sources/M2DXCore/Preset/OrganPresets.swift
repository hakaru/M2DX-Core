// OrganPresets.swift
// M2DX-Core — Original hand-designed DX7-style organ presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// ORGAN-category factory presets (Batch 5 of 8).
    static let organBatch: [DX7Preset] = [
        /// Full drawbar tonewheel organ using pure additive synthesis (Alg 32).
        /// All six operators are carriers; the coarse ratios 1, 2, 3, 4, 6, 8 mimic the classic
        /// Hammond drawbar layout (8', 4', 2 2/3', 2', 1 3/5', 1') for a balanced tonewheel sound.
        /// Per-operator detune (5/7/9/5/9/7) adds gentle ensemble warmth without external chorus.
        /// Square envelope on every carrier — instant attack, full sustain, fast release — captures
        /// the mechanical key contact of a real organ.
        DX7Preset(
            name: "ORGAN 1",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 5, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP1 (carrier): 8' fundamental
                .init(outputLevel: 88, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP2 (carrier): 4' octave drawbar
                .init(outputLevel: 75, frequencyCoarse: 3, detune: 9, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP3 (carrier): 2 2/3' quint (3rd harmonic)
                .init(outputLevel: 70, frequencyCoarse: 4, detune: 5, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP4 (carrier): 2' super-octave
                .init(outputLevel: 55, frequencyCoarse: 6, detune: 9, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP5 (carrier): 1 3/5' tierce (6th harmonic)
                .init(outputLevel: 50, frequencyCoarse: 8, detune: 7, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP6 (carrier): 1' larigot
            ],
            category: .organ
        ),

        /// Drawbar organ with Hammond-style percussion key click on attack (Alg 1).
        /// OP1 and OP3 are sustained carriers (fundamental + octave drawbars); the OP6→OP5→OP4→OP3
        /// modulator stack is held at low static index for a subtle reedy color.
        /// OP6 carries feedback 5 and an EG that fades from peak to zero in tens of milliseconds —
        /// this generates the short broadband burst on note-on that produces the "click" character.
        /// Velocity sensitivity 4 on OP6 means harder playing brightens the click, like a real
        /// Hammond with full-percussion drawbar enabled.
        DX7Preset(
            name: "ORGAN 2",
            algorithm: 0,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 93, egLevel4: 0, velocitySensitivity: 2), // OP1 (carrier): fundamental
                .init(outputLevel: 35, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 90, egRate3: 80, egRate4: 75, egLevel1: 99, egLevel2: 25, egLevel3: 18, egLevel4: 0, velocitySensitivity: 1), // OP2 (modulator → OP1): subtle harmonic color
                .init(outputLevel: 78, frequencyCoarse: 2, detune: 5, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 75, egLevel1: 99, egLevel2: 95, egLevel3: 93, egLevel4: 0, velocitySensitivity: 2), // OP3 (carrier): 4' octave drawbar
                .init(outputLevel: 22, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 90, egRate3: 80, egRate4: 75, egLevel1: 99, egLevel2: 18, egLevel3: 15, egLevel4: 0), // OP4 (modulator → OP3): static depth
                .init(outputLevel: 18, frequencyCoarse: 2, detune: 9, egRate1: 99, egRate2: 90, egRate3: 80, egRate4: 75, egLevel1: 99, egLevel2: 14, egLevel3: 12, egLevel4: 0), // OP5 (modulator → OP4): mid-stack stability
                .init(outputLevel: 50, frequencyCoarse: 1, detune: 7, feedback: 5, egRate1: 99, egRate2: 80, egRate3: 70, egRate4: 75, egLevel1: 99, egLevel2: 35, egLevel3: 0, egLevel4: 0, velocitySensitivity: 4), // OP6 (modulator → OP5, feedback): tonewheel leakage / key click burst
            ],
            category: .organ
        ),

        /// Pipe / church organ with dramatic upper partials and cathedral register (Alg 32).
        /// All six operators are carriers, but the drawbar weighting is shifted toward higher
        /// harmonics (1, 2, 4, 6, 8, 12) to approximate the principal and mixture stops of
        /// a pipe organ rather than a Hammond drawbar set.
        /// Slightly slowed attack (egRate1 60) models the brief mechanical lag of air filling
        /// the pipes after a key is pressed; relaxed release (egRate4 55) lets the sound decay
        /// like residual air in the windchest.
        /// Transpose -12 lowers the entire patch one octave into the cathedral register.
        DX7Preset(
            name: "ORGAN 3",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 5, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP1 (carrier): principal 8' pipe fundamental
                .init(outputLevel: 92, frequencyCoarse: 2, detune: 9, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP2 (carrier): octave 4'
                .init(outputLevel: 80, frequencyCoarse: 4, detune: 5, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP3 (carrier): super-octave 2'
                .init(outputLevel: 65, frequencyCoarse: 6, detune: 9, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP4 (carrier): twelfth (1 1/3')
                .init(outputLevel: 50, frequencyCoarse: 8, detune: 5, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP5 (carrier): fifteenth (1')
                .init(outputLevel: 38, frequencyCoarse: 12, detune: 9, egRate1: 60, egRate2: 99, egRate3: 99, egRate4: 55, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP6 (carrier): high mixture stop
            ],
            category: .organ,
            transpose: -12
        ),
    ]
}
