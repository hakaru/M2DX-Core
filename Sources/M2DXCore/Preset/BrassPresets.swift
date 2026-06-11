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
        /// Section brass on Algorithm 22: four parallel carriers (OP1/OP3/OP4/OP5 at ratios 1/1/2/3)
        /// with two 1:1 modulators — OP2 colors the lead voice (OP1) and OP6 (feedback 6) drives
        /// the upper section (OP3-OP5) with a shared sawtooth-like brass edge.
        /// Both modulators snap to a moderate egLevel1 (70-72), then bloom slowly (egRate2 32) up to
        /// a 97-99 shelf, so the spectrum keeps opening AFTER the amplitude onset — the section swell
        /// where the sustain is brighter than the attack.
        /// Carrier egRate1 56 places the amplitude attack near 47 ms (the 30-90 ms brass range);
        /// modulator velocitySensitivity 7 plus velocity-gated upper carriers (OP4/OP5 sens 4-5)
        /// open both brightness and level with harder playing.
        DX7Preset(
            name: "BRASS",
            algorithm: 21,
            feedback: 6,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0, detune: 5, feedback: 0, egRate1: 56, egRate2: 55, egRate3: 30, egRate4: 45, egLevel2: 93, egLevel3: 88, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 1, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): fundamental section voice, 30-90ms swelled attack
                .init(outputLevel: 84, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 85, egRate2: 32, egRate3: 25, egRate4: 50, egLevel1: 72, egLevel2: 99, egLevel3: 97, velocitySensitivity: 7, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): slow-rising 1:1 brass edge, high shelf for sustain brightness
                .init(outputLevel: 96, frequencyCoarse: 1, frequencyFine: 0, detune: 9, feedback: 0, egRate1: 56, egRate2: 55, egRate3: 30, egRate4: 45, egLevel2: 92, egLevel3: 87, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): detuned unison partner for ensemble width
                .init(outputLevel: 92, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 56, egRate2: 56, egRate3: 31, egRate4: 46, egLevel2: 92, egLevel3: 86, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (carrier): octave brass body
                .init(outputLevel: 84, frequencyCoarse: 3, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 56, egRate2: 57, egRate3: 31, egRate4: 46, egLevel2: 91, egLevel3: 85, velocitySensitivity: 5, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (carrier): upper harmonic section sheen
                .init(outputLevel: 82, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 6, egRate1: 85, egRate2: 32, egRate3: 25, egRate4: 52, egLevel1: 70, egLevel2: 99, egLevel3: 97, velocitySensitivity: 7, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP3/OP4/OP5, feedback): slow-rising shared section brightness
            ],
            category: .brass,
            lfoSpeed: 35,
            lfoPMD: 2,
            lfoPMS: 3
        ),

        /// Solo trumpet on Algorithm 1: OP1 carries the focused horn fundamental (egRate1 56 for a
        /// ~53 ms attack), OP3 the bright octave body. The 1:1 modulators OP2 and OP4 snap to a
        /// moderate egLevel1 (76-78), then bloom slowly (egRate2 32-33) up to a 96-99 shelf — the
        /// bell "opens up" into the sustain so the sustain centroid sits above the attack centroid.
        /// The OP6(feedback 6)->OP5->OP4 stack adds a sawtooth-flavored lip buzz that follows the
        /// same bloom contour so the buzz swells with the brightness instead of spiking.
        /// Modulator velocitySensitivity 6 gives the strong velocity-to-brightness response of a
        /// trumpet; a delayed sine pitch LFO supplies vibrato after the onset.
        DX7Preset(
            name: "TRUMPET",
            algorithm: 0,
            feedback: 6,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 56, egRate2: 60, egRate3: 32, egRate4: 50, egLevel2: 93, egLevel3: 88, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): focused trumpet fundamental, 30-90ms attack
                .init(outputLevel: 79, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 85, egRate2: 32, egRate3: 25, egRate4: 54, egLevel1: 78, egLevel2: 99, egLevel3: 97, velocitySensitivity: 6, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): slow-rising 1:1 lip edge, high sustain shelf
                .init(outputLevel: 90, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 56, egRate2: 60, egRate3: 32, egRate4: 48, egLevel2: 92, egLevel3: 87, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 44, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): bright octave brass body
                .init(outputLevel: 76, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 85, egRate2: 33, egRate3: 25, egRate4: 56, egLevel1: 76, egLevel2: 99, egLevel3: 96, velocitySensitivity: 6, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): slow-rising 1:1 octave bite
                .init(outputLevel: 55, frequencyCoarse: 3, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 85, egRate2: 33, egRate3: 26, egRate4: 57, egLevel1: 68, egLevel2: 97, egLevel3: 94, velocitySensitivity: 3, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 45, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (modulator -> OP4): harmonic pressure, follows the swell contour
                .init(outputLevel: 58, frequencyCoarse: 1, frequencyFine: 0, detune: 9, feedback: 6, egRate1: 85, egRate2: 34, egRate3: 26, egRate4: 58, egLevel1: 68, egLevel2: 96, egLevel3: 92, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 46, klsLeftDepth: 0, klsRightDepth: 4, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): sawtooth-flavored lip buzz source
            ],
            category: .brass,
            lfoSpeed: 42,
            lfoDelay: 30,
            lfoPMD: 8,
            lfoWaveform: 4,
            lfoPMS: 4
        ),

        /// Deep low brass on Algorithm 1, played an octave down (transpose -12).
        /// OP1 holds the broad trombone fundamental (egRate1 56, ~58 ms attack) and OP3 a
        /// velocity-gated octave body (sens 5) so soft notes stay dark; modulators OP2 and OP4 are
        /// 1:1, snapping to egLevel1 75-78 then blooming (egRate2 32-33) up to a 95-99 shelf so the
        /// bore brightness swells into the sustain without trumpet-like glare.
        /// The OP6(feedback 4)->OP5->OP4 branch stays darker and quieter than the trumpet patch —
        /// the buzz supports the bore resonance rather than dominating it.
        /// Modulator velocitySensitivity 6 opens the slide-brass edge with harder playing.
        DX7Preset(
            name: "TROMBONE",
            algorithm: 0,
            feedback: 4,
            operators: [
                .init(outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 56, egRate2: 55, egRate3: 27, egRate4: 45, egLevel2: 92, egLevel3: 87, velocitySensitivity: 2, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 40, klsLeftDepth: 0, klsRightDepth: 1, klsLeftCurve: 0, klsRightCurve: 3), // OP1 (carrier): broad low-brass fundamental, swelled 30-90ms attack
                .init(outputLevel: 78, frequencyCoarse: 1, frequencyFine: 0, detune: 7, feedback: 0, egRate1: 85, egRate2: 32, egRate3: 25, egRate4: 50, egLevel1: 78, egLevel2: 99, egLevel3: 96, velocitySensitivity: 6, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 39, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP2 (modulator -> OP1): slow-rising 1:1 bore color, high shelf
                .init(outputLevel: 92, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 56, egRate2: 55, egRate3: 28, egRate4: 46, egLevel2: 91, egLevel3: 86, velocitySensitivity: 5, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 41, klsLeftDepth: 0, klsRightDepth: 2, klsLeftCurve: 0, klsRightCurve: 3), // OP3 (carrier): low octave brass body
                .init(outputLevel: 72, frequencyCoarse: 2, frequencyFine: 0, detune: 8, feedback: 0, egRate1: 85, egRate2: 33, egRate3: 25, egRate4: 52, egLevel1: 75, egLevel2: 98, egLevel3: 95, velocitySensitivity: 6, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP4 (modulator -> OP3): slow-rising dark slide-brass edge
                .init(outputLevel: 48, frequencyCoarse: 2, frequencyFine: 0, detune: 6, feedback: 0, egRate1: 85, egRate2: 33, egRate3: 26, egRate4: 53, egLevel1: 66, egLevel2: 95, egLevel3: 92, velocitySensitivity: 3, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 42, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP5 (modulator -> OP4): subdued harmonic weight
                .init(outputLevel: 50, frequencyCoarse: 1, frequencyFine: 0, detune: 8, feedback: 4, egRate1: 85, egRate2: 34, egRate3: 26, egRate4: 54, egLevel1: 66, egLevel2: 95, egLevel3: 90, velocitySensitivity: 4, ampModSensitivity: 0, keyboardRateScaling: 1, klsBreakPoint: 43, klsLeftDepth: 0, klsRightDepth: 3, klsLeftCurve: 0, klsRightCurve: 3), // OP6 (modulator -> OP5, feedback): darker low-brass buzz
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
