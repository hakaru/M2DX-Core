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
        /// Thick analog-modeled bass: two carriers (OP1 body + OP3 detuned weight) with all
        /// brightness pushed into a velocity-gated attack burst so the sustain stays low and dark.
        /// OP2 is the main growl modulator — its EG shelf spans the first ~120 ms then closes
        /// before the sustain window, and velocity sensitivity 7 makes hard hits much brighter.
        /// Carrier velocity sensitivity 3 gives the soft→hard level swing; the OP6→OP5→OP4 stack
        /// adds a short feedback-thickened transient that is also velocity-gated to keep soft notes round.
        DX7Preset(
            name: "FAT BASS",
            algorithm: 0,
            feedback: 6,
            operators: [
                .init(outputLevel: 98, egRate2: 30, egRate4: 40, egLevel2: 94, egLevel3: 78, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): main saturated bass body
                .init(outputLevel: 82, egRate2: 62, egRate3: 48, egLevel2: 38, egLevel3: 0, velocitySensitivity: 7), // OP2 (modulator→OP1): velocity-gated growl burst, closes before sustain
                .init(outputLevel: 88, detune: 3, egRate2: 30, egRate4: 40, egLevel2: 94, egLevel3: 78, velocitySensitivity: 3, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary bass body
                .init(outputLevel: 45, frequencyCoarse: 2, egRate3: 52, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5), // OP4 (modulator→OP3): octave growl, velocity-gated
                .init(outputLevel: 42, frequencyCoarse: 3, egRate3: 52, egLevel2: 26, egLevel3: 0, velocitySensitivity: 5), // OP5 (modulator→OP4): third-harmonic transient stage
                .init(outputLevel: 48, feedback: 6, egRate3: 52, egLevel2: 32, egLevel3: 0, velocitySensitivity: 5), // OP6 (modulator→OP5): feedback thickener, attack only
            ],
            category: .bass
        ),

        /// Percussive slap bass: a hard velocity-gated front edge over a tight low body that
        /// keeps sounding while the key is held. Algorithm 5 gives three true carrier/modulator
        /// pairs — OP1 fundamental, OP3 octave punch, OP5 detuned low thickener — so the sustain
        /// is pure sub-200 Hz carrier energy once the modulator bursts close (~0.3 s).
        /// OP2 and OP4 supply the bark on the two main carriers; OP6 (feedback op, ratio 9)
        /// is the slap click itself — velocity sensitivity 7 so hard pops get the bright snap.
        DX7Preset(
            name: "SLAP BASS",
            algorithm: 4,
            feedback: 5,
            operators: [
                .init(outputLevel: 98, egRate2: 55, egRate3: 38, egRate4: 72, egLevel2: 90, egLevel3: 70, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): fundamental snap into held body
                .init(outputLevel: 78, egRate2: 62, egRate3: 50, egLevel2: 38, egLevel3: 0, velocitySensitivity: 6), // OP2 (modulator→OP1): short low bark, velocity-gated
                .init(outputLevel: 86, frequencyCoarse: 2, egRate2: 55, egRate3: 40, egRate4: 70, egLevel2: 88, egLevel3: 60, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): octave slap punch
                .init(outputLevel: 72, frequencyCoarse: 3, egRate2: 64, egRate3: 52, egLevel2: 34, egLevel3: 0, velocitySensitivity: 6), // OP4 (modulator→OP3): bright thumb transient
                .init(outputLevel: 84, detune: 9, egRate2: 55, egRate3: 40, egRate4: 72, egLevel2: 86, egLevel3: 62, velocitySensitivity: 2, keyboardRateScaling: 1), // OP5 (carrier): detuned low-mid pop layer
                .init(outputLevel: 80, frequencyCoarse: 9, egRate2: 60, egRate3: 52, egLevel2: 36, egLevel3: 0, velocitySensitivity: 7), // OP6 (modulator→OP5, feedback op): slap click
            ],
            category: .bass
        ),

        /// Deep clean sub-bass built from parallel sine carriers rather than a modulated stack.
        /// Algorithm 32 lets every operator speak as a carrier, so the patch stays stable under
        /// a kick and avoids sideband fizz. OP1 supplies the fundamental, OP2 the sub-octave,
        /// OP3 a quiet second harmonic for small-speaker translation. Velocity sensitivity 2 on
        /// the body carriers gives a real soft→hard level swing, and OP4 is a velocity-gated
        /// sixth-harmonic "knock" (≈196 Hz at C1) that brightens hard hits in the attack only —
        /// it still sits below 200 Hz and closes fast, so the sub character is untouched.
        DX7Preset(
            name: "SUB BASS",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(egRate2: 40, egRate4: 40, egLevel2: 92, egLevel3: 85, velocitySensitivity: 2), // OP1 (carrier): fundamental sine weight
                .init(outputLevel: 75, frequencyCoarse: 0, egRate2: 40, egRate4: 40, egLevel2: 92, egLevel3: 85, velocitySensitivity: 2), // OP2 (carrier): sub-octave reinforcement
                .init(outputLevel: 35, frequencyCoarse: 2, egRate2: 38, egRate4: 38, egLevel2: 88, egLevel3: 80, velocitySensitivity: 2), // OP3 (carrier): quiet second harmonic
                .init(outputLevel: 82, frequencyCoarse: 6, egRate2: 58, egRate3: 50, egLevel2: 38, egLevel3: 0, velocitySensitivity: 7), // OP4 (carrier): velocity-gated attack knock (≈196 Hz at C1)
                .init(outputLevel: 10, frequencyCoarse: 4, egRate2: 35, egLevel2: 80, egLevel3: 68), // OP5 (carrier): faint fourth harmonic
                .init(outputLevel: 8, frequencyCoarse: 5, egRate2: 35, egLevel2: 78, egLevel3: 65), // OP6 (carrier): faint upper partial
            ],
            category: .bass,
            transpose: -12
        ),

        /// Driving 80s synth bass with a fast envelope, a velocity-gated reedy bite, and a dark
        /// held body. Algorithm 1 uses OP1 for the centered punch and OP3 as a detuned second
        /// carrier; OP2 is the main bite modulator — its burst spans the attack window, closes
        /// before the sustain, and velocity sensitivity 7 makes hard notes cut while soft notes
        /// stay round. Carrier velocity sensitivity 3 gives a wide soft→hard level swing.
        /// The OP6→OP5→OP4 stack adds a gated reed-edge transient on top, and a
        /// small delayed pitch LFO adds motion after the transient.
        DX7Preset(
            name: "SYN BASS",
            algorithm: 0,
            feedback: 6,
            operators: [
                .init(outputLevel: 98, egRate2: 55, egRate3: 45, egRate4: 42, egLevel2: 92, egLevel3: 78, velocitySensitivity: 3, keyboardRateScaling: 1), // OP1 (carrier): main punch body
                .init(outputLevel: 80, egRate2: 62, egRate3: 48, egLevel2: 38, egLevel3: 0, velocitySensitivity: 7), // OP2 (modulator→OP1): velocity-gated reedy bite burst
                .init(outputLevel: 86, detune: 9, egRate2: 55, egRate3: 45, egRate4: 42, egLevel2: 92, egLevel3: 78, velocitySensitivity: 3, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary body
                .init(outputLevel: 50, frequencyCoarse: 2, egRate2: 60, egRate3: 52, egLevel2: 32, egLevel3: 0, velocitySensitivity: 5), // OP4 (modulator→OP3): octave reed color, gated
                .init(outputLevel: 46, frequencyCoarse: 3, egRate2: 58, egRate3: 52, egLevel2: 28, egLevel3: 0, velocitySensitivity: 5), // OP5 (modulator→OP4): harmonic drive stage, gated
                .init(outputLevel: 52, frequencyCoarse: 2, feedback: 6, egRate2: 62, egRate3: 52, egLevel2: 34, egLevel3: 0, velocitySensitivity: 5), // OP6 (modulator→OP5): feedback reed edge, gated
            ],
            category: .bass,
            lfoSpeed: 28,
            lfoDelay: 28,
            lfoPMD: 4
        ),
    ]
}
