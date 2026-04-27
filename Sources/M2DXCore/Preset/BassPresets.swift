// BassPresets.swift
// M2DX-Core — Original hand-designed DX7-style bass presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// BASS-category factory presets (Batch 2 of 8).
    static let bassBatch: [DX7Preset] = [
        /// Thick analog-modeled bass with a saturated two-carrier core and a controlled transient edge.
        /// Algorithm 1 lets OP1 carry the main body while OP3 adds a detuned parallel weight underneath the stacked modulation branch.
        /// OP2 adds low-ratio growl to OP1, while OP4, OP5, and self-feedback on OP6 build richer harmonic pressure into OP3.
        /// Left-side keyboard level scaling pulls modulation down in the low register so the bass stays heavy without turning muddy.
        DX7Preset(
            name: "FAT BASS",
            algorithm: 0,
            feedback: 6,
            operators: [
                .init(outputLevel: 98, egRate2: 30, egRate4: 40, egLevel2: 94, egLevel3: 78, velocitySensitivity: 1, keyboardRateScaling: 1), // OP1 (carrier): main saturated bass body
                .init(outputLevel: 50, egLevel2: 30, egLevel3: 0, velocitySensitivity: 2, klsBreakPoint: 38, klsLeftDepth: 4, klsLeftCurve: 1), // OP2 (modulator→OP1): low-ratio saturation index
                .init(outputLevel: 88, detune: 3, egRate2: 30, egRate4: 40, egLevel2: 94, egLevel3: 78, velocitySensitivity: 1, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary bass body
                .init(outputLevel: 45, frequencyCoarse: 2, egLevel2: 28, egLevel3: 0, klsBreakPoint: 38, klsLeftDepth: 4, klsLeftCurve: 1), // OP4 (modulator→OP3): octave growl into secondary body
                .init(outputLevel: 42, frequencyCoarse: 3, egLevel2: 26, egLevel3: 0, klsBreakPoint: 38, klsLeftDepth: 4, klsLeftCurve: 1), // OP5 (modulator→OP4): third-harmonic saturation stage
                .init(outputLevel: 48, feedback: 6, egLevel2: 32, egLevel3: 0, velocitySensitivity: 4, klsBreakPoint: 38, klsLeftDepth: 4, klsLeftCurve: 1), // OP6 (modulator→OP5): feedback thickener
            ],
            category: .bass
        ),

        /// Percussive slap-bass patch with a hard front edge, fast decay, and no sustained modulation shelf.
        /// Algorithm 15 layers fundamental, mid, and low-mid carrier energy so the attack reads as a thumb-pop rather than a single sine hit.
        /// OP2 and OP4 create short bark on OP1 and OP3, while OP6 feedback adds a sharper shared pop into the upper branch.
        /// High velocity sensitivity on OP6 makes hard playing brighter, and left-side KLS keeps low notes punchy instead of clangy.
        DX7Preset(
            name: "SLAP BASS",
            algorithm: 14,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, egRate2: 78, egRate3: 68, egRate4: 72, egLevel2: 90, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): main fundamental snap
                .init(outputLevel: 38, egRate2: 80, egRate3: 70, egLevel2: 28, egLevel3: 0), // OP2 (modulator→OP1): short low bark
                .init(outputLevel: 86, frequencyCoarse: 2, egRate2: 75, egRate3: 65, egRate4: 70, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): midrange slap body
                .init(outputLevel: 52, frequencyCoarse: 3, egRate2: 82, egRate3: 72, egLevel2: 34, egLevel3: 0, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP4 (modulator→OP3): bright thumb transient
                .init(outputLevel: 84, egRate2: 80, egRate3: 68, egRate4: 72, egLevel2: 88, egLevel3: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP5 (carrier): low-mid pop layer
                .init(outputLevel: 60, frequencyCoarse: 2, feedback: 5, egRate2: 85, egRate3: 75, egLevel2: 36, egLevel3: 0, velocitySensitivity: 7, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP6 (modulator→OP5): feedback-driven slap click
            ],
            category: .bass
        ),

        /// Deep clean sub-bass built from parallel sine carriers rather than a modulated stack.
        /// Algorithm 32 lets every operator speak as a carrier, so the patch stays stable under a kick and avoids sideband fizz.
        /// OP1 supplies the fundamental, OP2 reinforces the sub-octave, and OP3 adds just enough second harmonic for translation on small speakers.
        /// OP4, OP5, and OP6 are kept very low as faint upper partials, with transpose lowering the whole patch into a dedicated sub register.
        DX7Preset(
            name: "SUB BASS",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(egRate2: 40, egRate4: 40, egLevel2: 92, egLevel3: 85, velocitySensitivity: 1), // OP1 (carrier): fundamental sine weight
                .init(outputLevel: 75, frequencyCoarse: 0, egRate2: 40, egRate4: 40, egLevel2: 92, egLevel3: 85, velocitySensitivity: 1), // OP2 (carrier): sub-octave reinforcement
                .init(outputLevel: 35, frequencyCoarse: 2, egRate2: 38, egRate4: 38, egLevel2: 88, egLevel3: 80, velocitySensitivity: 1), // OP3 (carrier): quiet second harmonic
                .init(outputLevel: 12, frequencyCoarse: 3, egRate2: 35, egLevel2: 82, egLevel3: 70), // OP4 (carrier): faint third harmonic
                .init(outputLevel: 10, frequencyCoarse: 4, egRate2: 35, egLevel2: 80, egLevel3: 68), // OP5 (carrier): faint fourth harmonic
                .init(outputLevel: 8, frequencyCoarse: 5, egRate2: 35, egLevel2: 78, egLevel3: 65), // OP6 (carrier): faint upper partial
            ],
            category: .bass,
            transpose: -12
        ),

        /// Driving 80s synth bass with a fast envelope, slightly reedy edge, and enough body for repeated notes.
        /// Algorithm 1 uses OP1 for the centered punch and OP3 as a detuned second carrier, while the upper stack adds sharper harmonic motion.
        /// OP2 gives OP1 a tight low-ratio bite, and OP4, OP5, and OP6 push OP3 toward a more aggressive reed-like color.
        /// A small delayed pitch LFO adds motion after the transient while left-side KLS keeps the modulation controlled in the lowest notes.
        DX7Preset(
            name: "SYN BASS",
            algorithm: 0,
            feedback: 6,
            operators: [
                .init(outputLevel: 98, egRate2: 55, egRate3: 45, egRate4: 42, egLevel2: 92, egLevel3: 78, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): main punch body
                .init(outputLevel: 44, egRate2: 65, egLevel2: 30, egLevel3: 0, velocitySensitivity: 3, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP2 (modulator→OP1): fast low-ratio bite
                .init(outputLevel: 86, detune: 9, egRate2: 55, egRate3: 45, egRate4: 42, egLevel2: 92, egLevel3: 78, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary body
                .init(outputLevel: 50, frequencyCoarse: 2, egRate2: 60, egLevel2: 32, egLevel3: 0, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP4 (modulator→OP3): octave reed color
                .init(outputLevel: 46, frequencyCoarse: 3, egRate2: 58, egLevel2: 28, egLevel3: 0, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP5 (modulator→OP4): harmonic drive stage
                .init(outputLevel: 52, frequencyCoarse: 2, feedback: 6, egRate2: 62, egLevel2: 34, egLevel3: 0, velocitySensitivity: 5, klsBreakPoint: 40, klsLeftDepth: 5, klsLeftCurve: 1), // OP6 (modulator→OP5): feedback reed edge
            ],
            category: .bass,
            lfoSpeed: 28,
            lfoDelay: 28,
            lfoPMD: 4
        ),
    ]
}
