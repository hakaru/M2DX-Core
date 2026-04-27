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
        /// Feedback 7 on OP6 saturates the OP6→OP5→OP4→OP3 stack into a dense harmonic series
        /// that approximates a saw wave more than a sine. OP1 main carrier sits at full level
        /// with OP3 slightly detuned for natural mono-lead width.
        /// Velocity sensitivity 5 on OP6 makes harder playing brighter; carriers sustain at
        /// 80 plateau for held lead notes.
        /// Delayed sine LFO adds vibrato after the attack settles, characteristic of mono synth lead.
        DX7Preset(
            name: "LEAD SAW",
            algorithm: 0,
            feedback: 7,
            operators: [
                .init(outputLevel: 99, detune: 7, egRate1: 99, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 92, egLevel3: 80, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): saw fundamental
                .init(outputLevel: 48, detune: 7, egRate1: 99, egRate2: 75, egRate3: 55, egRate4: 52, egLevel1: 99, egLevel2: 32, egLevel3: 2, egLevel4: 0, velocitySensitivity: 3, keyboardRateScaling: 1), // OP2 (modulator → OP1): sub-harmonic edge
                .init(outputLevel: 76, detune: 9, egRate1: 99, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 90, egLevel3: 78, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): detuned secondary saw layer
                .init(outputLevel: 54, frequencyCoarse: 2, detune: 7, egRate1: 99, egRate2: 75, egRate3: 55, egRate4: 52, egLevel1: 99, egLevel2: 30, egLevel3: 2, egLevel4: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP4 (modulator → OP3): octave saw enhancement
                .init(outputLevel: 50, frequencyCoarse: 3, detune: 7, egRate1: 99, egRate2: 75, egRate3: 56, egRate4: 53, egLevel1: 99, egLevel2: 28, egLevel3: 1, egLevel4: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP5 (modulator → OP4): third harmonic sharpening
                .init(outputLevel: 56, detune: 9, feedback: 7, egRate1: 99, egRate2: 75, egRate3: 56, egRate4: 53, egLevel1: 99, egLevel2: 34, egLevel3: 0, egLevel4: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP6 (modulator → OP5, feedback 7): saw-saturating self-FM
            ],
            category: .other,
            lfoSpeed: 35,
            lfoDelay: 22,
            lfoPMD: 5,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Square-like FM lead emphasizing odd harmonics through deliberate ratio choice (Alg 1).
        /// OP3 at coarse 3 and modulators with coarse 3, 5 ratios push energy into odd partials
        /// (3rd, 5th) characteristic of square waves. OP6 feedback 4 adds a fizzy top.
        /// OP1 main carrier at full level; OP3 at OL 70 reinforces the third harmonic.
        /// Velocity sensitivity 5 on OP6 lets harder playing add brightness without changing
        /// the fundamental square-like character.
        DX7Preset(
            name: "LEAD SQR",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, detune: 7, egRate1: 99, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 92, egLevel3: 80, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP1 (carrier): square fundamental
                .init(outputLevel: 46, detune: 7, egRate1: 99, egRate2: 75, egRate3: 55, egRate4: 52, egLevel1: 99, egLevel2: 30, egLevel3: 2, egLevel4: 0, velocitySensitivity: 3, keyboardRateScaling: 1), // OP2 (modulator → OP1): low harmonic shaper
                .init(outputLevel: 70, frequencyCoarse: 3, detune: 9, egRate1: 99, egRate2: 70, egRate3: 50, egRate4: 50, egLevel1: 99, egLevel2: 90, egLevel3: 78, egLevel4: 0, velocitySensitivity: 2, keyboardRateScaling: 1), // OP3 (carrier): third-harmonic emphasis
                .init(outputLevel: 55, frequencyCoarse: 5, detune: 7, egRate1: 99, egRate2: 75, egRate3: 55, egRate4: 52, egLevel1: 99, egLevel2: 32, egLevel3: 2, egLevel4: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP4 (modulator → OP3): fifth-harmonic boost
                .init(outputLevel: 48, frequencyCoarse: 3, detune: 7, egRate1: 99, egRate2: 75, egRate3: 56, egRate4: 53, egLevel1: 99, egLevel2: 28, egLevel3: 1, egLevel4: 0, velocitySensitivity: 4, keyboardRateScaling: 2), // OP5 (modulator → OP4): third-partial pressure
                .init(outputLevel: 60, frequencyCoarse: 3, detune: 9, feedback: 4, egRate1: 99, egRate2: 75, egRate3: 56, egRate4: 53, egLevel1: 99, egLevel2: 32, egLevel3: 0, egLevel4: 0, velocitySensitivity: 5, keyboardRateScaling: 2), // OP6 (modulator → OP5, feedback): fizzy top with odd-harmonic feedback
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
