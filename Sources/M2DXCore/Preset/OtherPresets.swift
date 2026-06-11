// OtherPresets.swift
// M2DX-Core — Original hand-designed DX7-style miscellaneous presets (Apache 2.0).
//
// Every parameter value below was synthesized from FM theory + the explicit
// design-intent comments above each preset. No Yamaha factory ROM SysEx file
// was opened, parsed, or referenced while generating this batch. See NOTICE.

import Foundation

public extension DX7Preset {
    /// OTHER-category factory presets (Batch 8 of 8).
    static let otherBatch: [DX7Preset] = [
        /// Saw-like FM lead with maximum OP6 self-feedback for sideband cluster (Alg 1).
        /// Feedback 7 on the 1:1 OP6 saturates the OP6→OP5→OP4→OP3 stack into a dense harmonic
        /// series that approximates a saw wave; OP2 (1:1) adds the same edge to main carrier OP1.
        /// Modulator output levels sit in the audible 66–78 band and HOLD a sustain shelf
        /// (egLevel3 66–78) so the saw character lives in the held note, not just the attack.
        /// Velocity sensitivity 6 on every modulator gates the brightness: soft playing is a
        /// near-sine, hard playing unlocks the full saw cluster. Carriers (sens 2) hold an
        /// 88–90 sustain plateau so the lead stays loud while held.
        /// Delayed sine LFO adds vibrato after the attack settles, characteristic of mono synth lead.
        DX7Preset(
            name: "LEAD SAW",
            algorithm: 0,
            feedback: 7,
            operators: [
                .init(outputLevel: 94, detune: 7, egRate1: 99, egRate2: 70, egRate3: 40, egRate4: 50, egLevel1: 99, egLevel2: 95, egLevel3: 90, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): saw fundamental, 90 sustain plateau
                .init(outputLevel: 78, detune: 7, egRate1: 99, egRate2: 60, egRate3: 40, egRate4: 52, egLevel1: 99, egLevel2: 88, egLevel3: 78, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 1), // OP2 (modulator → OP1): 1:1 saw edge, velocity-gated, sustains
                .init(outputLevel: 71, detune: 9, egRate1: 99, egRate2: 70, egRate3: 40, egRate4: 50, egLevel1: 99, egLevel2: 93, egLevel3: 88, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary saw layer
                .init(outputLevel: 74, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 52, egLevel1: 99, egLevel2: 85, egLevel3: 74, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP4 (modulator → OP3): octave saw enhancement, velocity-gated
                .init(outputLevel: 66, frequencyCoarse: 3, detune: 7, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 53, egLevel1: 99, egLevel2: 82, egLevel3: 66, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP5 (modulator → OP4): third harmonic sharpening
                .init(outputLevel: 78, detune: 9, feedback: 7, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 53, egLevel1: 99, egLevel2: 86, egLevel3: 78, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP6 (modulator → OP5, preset feedback 7): saw-saturating self-FM
            ],
            category: .other,
            lfoSpeed: 35,
            lfoDelay: 22,
            lfoPMD: 5,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Square-like FM lead built on 1:2 carrier:modulator ratios for odd harmonics (Alg 1).
        /// Both carriers run at 1:1 with coarse-2 modulators directly above them — a 1:2 FM pair
        /// produces sidebands only at odd multiples of the fundamental, the square-wave recipe.
        /// The upper stack keeps even-multiple ratios (OP5/OP6 coarse 2) so cascaded sidebands
        /// stay on odd partials; preset feedback 4 on OP6 adds a fizzy top within that grid.
        /// Modulators hold a sustain shelf (egLevel3 68–78) so the hollow square character
        /// persists in the held note; velocity sensitivity 6 on all modulators gates brightness
        /// (soft = near-sine, hard = full square). Carriers sustain at an 88–90 plateau.
        DX7Preset(
            name: "LEAD SQR",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 93, detune: 7, egRate1: 99, egRate2: 70, egRate3: 40, egRate4: 50, egLevel1: 99, egLevel2: 95, egLevel3: 90, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): square fundamental, 90 sustain plateau
                .init(outputLevel: 78, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 60, egRate3: 40, egRate4: 52, egLevel1: 99, egLevel2: 88, egLevel3: 78, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 1), // OP2 (modulator → OP1, 1:2): odd-harmonic shaper, velocity-gated
                .init(outputLevel: 70, detune: 9, egRate1: 99, egRate2: 70, egRate3: 40, egRate4: 50, egLevel1: 99, egLevel2: 93, egLevel3: 88, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary square layer
                .init(outputLevel: 75, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 52, egLevel1: 99, egLevel2: 85, egLevel3: 74, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP4 (modulator → OP3, 1:2): odd-harmonic boost, velocity-gated
                .init(outputLevel: 64, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 53, egLevel1: 99, egLevel2: 82, egLevel3: 68, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP5 (modulator → OP4, even multiple): keeps cascade on odd partials
                .init(outputLevel: 72, frequencyCoarse: 2, detune: 9, feedback: 4, egRate1: 99, egRate2: 60, egRate3: 42, egRate4: 53, egLevel1: 99, egLevel2: 84, egLevel3: 72, egLevel4: 0, velocitySensitivity: 6, keyboardRateScaling: 2), // OP6 (modulator → OP5, preset feedback 4): fizzy top on the even-multiple grid
            ],
            category: .other,
            lfoSpeed: 35,
            lfoDelay: 22,
            lfoPMD: 5,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Pure single sine wave (debug / starting point) on Alg 32.
        /// Only OP1 outputs at full level; the other five carriers are silenced (output 0).
        /// All envelopes hold at 99 plateau so the held note is a steady sine reference tone.
        /// No feedback, no LFO, exact-center detune. Useful for verifying the engine signal path
        /// or as a baseline reference for level comparison against other presets.
        DX7Preset(
            name: "INIT SINE",
            algorithm: 31,
            feedback: 0,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, detune: 7, egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 70, egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0), // OP1 (carrier): pure sine output
                .init(outputLevel: 0, frequencyCoarse: 1, detune: 7), // OP2 (carrier, silent)
                .init(outputLevel: 0, frequencyCoarse: 1, detune: 7), // OP3 (carrier, silent)
                .init(outputLevel: 0, frequencyCoarse: 1, detune: 7), // OP4 (carrier, silent)
                .init(outputLevel: 0, frequencyCoarse: 1, detune: 7), // OP5 (carrier, silent)
                .init(outputLevel: 0, frequencyCoarse: 1, detune: 7), // OP6 (carrier, silent)
            ],
            category: .other
        ),

        /// Experimental sample-and-hold modulation patch (Alg 5).
        /// Three carriers OP1/OP3/OP5 at normal levels with three modulators driving moderate
        /// FM character. The S&H LFO (waveform 5) jitters pitch chaotically; ampModSensitivity 2
        /// on carriers + lfoAMD 18 means amplitude also jitters in the same random pattern.
        /// Sustain plateau 75 gives the random modulation time to evolve as the note holds.
        /// Useful as a sound-design starting point or demo of the engine's S&H LFO behavior.
        DX7Preset(
            name: "RANDOM",
            algorithm: 4,
            feedback: 2,
            operators: [
                .init(outputLevel: 95, detune: 7, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 88, egLevel3: 75, velocitySensitivity: 2, ampModSensitivity: 2), // OP1 (carrier): primary
                .init(outputLevel: 50, frequencyCoarse: 2, detune: 7, egRate2: 75, egRate3: 55, egLevel2: 30, egLevel3: 2, velocitySensitivity: 3), // OP2 (modulator → OP1): octave color
                .init(outputLevel: 80, detune: 9, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 86, egLevel3: 73, velocitySensitivity: 2, ampModSensitivity: 2), // OP3 (carrier): secondary detuned
                .init(outputLevel: 48, frequencyCoarse: 5, detune: 7, egRate2: 75, egRate3: 55, egLevel2: 28, egLevel3: 2, velocitySensitivity: 3), // OP4 (modulator → OP3): high inharmonic
                .init(outputLevel: 65, detune: 5, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 84, egLevel3: 70, velocitySensitivity: 2, ampModSensitivity: 2), // OP5 (carrier): tertiary
                .init(outputLevel: 45, frequencyCoarse: 3, detune: 7, feedback: 2, egRate2: 75, egRate3: 55, egLevel2: 30, egLevel3: 2, velocitySensitivity: 3), // OP6 (modulator → OP5, feedback): mid-stack drive
            ],
            category: .other,
            lfoSpeed: 32,
            lfoPMD: 28,
            lfoAMD: 18,
            lfoWaveform: 5,
            lfoPMS: 5
        ),
    ]
}
