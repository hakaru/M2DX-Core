// DX7Preset.swift
// M2DX-Core — DX7 preset data model with parameter conversion

import Foundation

// MARK: - Preset Category

public enum PresetCategory: String, Codable, CaseIterable, Sendable {
    case keys, bass, brass, strings, organ, percussion, woodwind, other
}

// MARK: - DX7 Operator Preset

public struct DX7OperatorPreset: Codable, Sendable, Equatable {
    public let outputLevel: Int
    public let frequencyCoarse: Int
    public let frequencyFine: Int
    public let detune: Int
    public var feedback: Int
    public let egRate1: Int, egRate2: Int, egRate3: Int, egRate4: Int
    public let egLevel1: Int, egLevel2: Int, egLevel3: Int, egLevel4: Int
    public var velocitySensitivity: Int
    public var ampModSensitivity: Int
    public var keyboardRateScaling: Int
    public var klsBreakPoint: Int
    public var klsLeftDepth: Int
    public var klsRightDepth: Int
    public var klsLeftCurve: Int
    public var klsRightCurve: Int
    public var frequencyMode: Int
    public var waveform: Int

    public init(
        outputLevel: Int = 99, frequencyCoarse: Int = 1, frequencyFine: Int = 0,
        detune: Int = 7, feedback: Int = 0,
        egRate1: Int = 99, egRate2: Int = 99, egRate3: Int = 99, egRate4: Int = 99,
        egLevel1: Int = 99, egLevel2: Int = 99, egLevel3: Int = 99, egLevel4: Int = 0,
        velocitySensitivity: Int = 0, ampModSensitivity: Int = 0,
        keyboardRateScaling: Int = 0, klsBreakPoint: Int = 39,
        klsLeftDepth: Int = 0, klsRightDepth: Int = 0,
        klsLeftCurve: Int = 0, klsRightCurve: Int = 0,
        frequencyMode: Int = 0, waveform: Int = 0
    ) {
        self.outputLevel = outputLevel
        self.frequencyCoarse = frequencyCoarse
        self.frequencyFine = frequencyFine
        self.detune = detune
        self.feedback = feedback
        self.egRate1 = egRate1; self.egRate2 = egRate2
        self.egRate3 = egRate3; self.egRate4 = egRate4
        self.egLevel1 = egLevel1; self.egLevel2 = egLevel2
        self.egLevel3 = egLevel3; self.egLevel4 = egLevel4
        self.velocitySensitivity = velocitySensitivity
        self.ampModSensitivity = ampModSensitivity
        self.keyboardRateScaling = keyboardRateScaling
        self.klsBreakPoint = klsBreakPoint
        self.klsLeftDepth = klsLeftDepth; self.klsRightDepth = klsRightDepth
        self.klsLeftCurve = klsLeftCurve; self.klsRightCurve = klsRightCurve
        self.frequencyMode = frequencyMode
        self.waveform = waveform
    }

    enum CodingKeys: String, CodingKey {
        case outputLevel, frequencyCoarse, frequencyFine, detune, feedback
        case egRate1, egRate2, egRate3, egRate4
        case egLevel1, egLevel2, egLevel3, egLevel4
        case velocitySensitivity, ampModSensitivity, keyboardRateScaling
        case klsBreakPoint, klsLeftDepth, klsRightDepth, klsLeftCurve, klsRightCurve
        case frequencyMode, waveform
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        outputLevel = try c.decode(Int.self, forKey: .outputLevel)
        frequencyCoarse = try c.decode(Int.self, forKey: .frequencyCoarse)
        frequencyFine = try c.decode(Int.self, forKey: .frequencyFine)
        detune = try c.decode(Int.self, forKey: .detune)
        feedback = try c.decode(Int.self, forKey: .feedback)
        egRate1 = try c.decode(Int.self, forKey: .egRate1)
        egRate2 = try c.decode(Int.self, forKey: .egRate2)
        egRate3 = try c.decode(Int.self, forKey: .egRate3)
        egRate4 = try c.decode(Int.self, forKey: .egRate4)
        egLevel1 = try c.decode(Int.self, forKey: .egLevel1)
        egLevel2 = try c.decode(Int.self, forKey: .egLevel2)
        egLevel3 = try c.decode(Int.self, forKey: .egLevel3)
        egLevel4 = try c.decode(Int.self, forKey: .egLevel4)
        velocitySensitivity = try c.decodeIfPresent(Int.self, forKey: .velocitySensitivity) ?? 0
        ampModSensitivity = try c.decodeIfPresent(Int.self, forKey: .ampModSensitivity) ?? 0
        keyboardRateScaling = try c.decodeIfPresent(Int.self, forKey: .keyboardRateScaling) ?? 0
        klsBreakPoint = try c.decodeIfPresent(Int.self, forKey: .klsBreakPoint) ?? 39
        klsLeftDepth = try c.decodeIfPresent(Int.self, forKey: .klsLeftDepth) ?? 0
        klsRightDepth = try c.decodeIfPresent(Int.self, forKey: .klsRightDepth) ?? 0
        klsLeftCurve = try c.decodeIfPresent(Int.self, forKey: .klsLeftCurve) ?? 0
        klsRightCurve = try c.decodeIfPresent(Int.self, forKey: .klsRightCurve) ?? 0
        frequencyMode = try c.decodeIfPresent(Int.self, forKey: .frequencyMode) ?? 0
        waveform = try c.decodeIfPresent(Int.self, forKey: .waveform) ?? 0
    }
}

// MARK: - DX7 Preset

public struct DX7Preset: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let name: String
    public let algorithm: Int
    public let feedback: Int
    public let operators: [DX7OperatorPreset]
    public let category: PresetCategory
    public var lfoSpeed: Int, lfoDelay: Int
    public var lfoPMD: Int, lfoAMD: Int
    public var lfoSync: Int, lfoWaveform: Int, lfoPMS: Int
    public var pitchEGR1: Int, pitchEGR2: Int, pitchEGR3: Int, pitchEGR4: Int
    public var pitchEGL1: Int, pitchEGL2: Int, pitchEGL3: Int, pitchEGL4: Int
    public var transpose: Int

    public init(
        id: UUID = UUID(), name: String, algorithm: Int, feedback: Int,
        operators: [DX7OperatorPreset], category: PresetCategory,
        lfoSpeed: Int = 35, lfoDelay: Int = 0,
        lfoPMD: Int = 0, lfoAMD: Int = 0,
        lfoSync: Int = 1, lfoWaveform: Int = 0, lfoPMS: Int = 3,
        pitchEGR1: Int = 99, pitchEGR2: Int = 99, pitchEGR3: Int = 99, pitchEGR4: Int = 99,
        pitchEGL1: Int = 50, pitchEGL2: Int = 50, pitchEGL3: Int = 50, pitchEGL4: Int = 50,
        transpose: Int = 0
    ) {
        self.id = id; self.name = name; self.algorithm = algorithm; self.feedback = feedback
        self.operators = operators; self.category = category
        self.lfoSpeed = lfoSpeed; self.lfoDelay = lfoDelay
        self.lfoPMD = lfoPMD; self.lfoAMD = lfoAMD
        self.lfoSync = lfoSync; self.lfoWaveform = lfoWaveform; self.lfoPMS = lfoPMS
        self.pitchEGR1 = pitchEGR1; self.pitchEGR2 = pitchEGR2
        self.pitchEGR3 = pitchEGR3; self.pitchEGR4 = pitchEGR4
        self.pitchEGL1 = pitchEGL1; self.pitchEGL2 = pitchEGL2
        self.pitchEGL3 = pitchEGL3; self.pitchEGL4 = pitchEGL4
        self.transpose = transpose
    }

    enum CodingKeys: String, CodingKey {
        case id, name, algorithm, feedback, operators, category
        case lfoSpeed, lfoDelay, lfoPMD, lfoAMD, lfoSync, lfoWaveform, lfoPMS
        case pitchEGR1, pitchEGR2, pitchEGR3, pitchEGR4
        case pitchEGL1, pitchEGL2, pitchEGL3, pitchEGL4
        case transpose
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        algorithm = try c.decode(Int.self, forKey: .algorithm)
        feedback = try c.decode(Int.self, forKey: .feedback)
        operators = try c.decode([DX7OperatorPreset].self, forKey: .operators)
        category = try c.decode(PresetCategory.self, forKey: .category)
        lfoSpeed = try c.decodeIfPresent(Int.self, forKey: .lfoSpeed) ?? 35
        lfoDelay = try c.decodeIfPresent(Int.self, forKey: .lfoDelay) ?? 0
        lfoPMD = try c.decodeIfPresent(Int.self, forKey: .lfoPMD) ?? 0
        lfoAMD = try c.decodeIfPresent(Int.self, forKey: .lfoAMD) ?? 0
        lfoSync = try c.decodeIfPresent(Int.self, forKey: .lfoSync) ?? 1
        lfoWaveform = try c.decodeIfPresent(Int.self, forKey: .lfoWaveform) ?? 0
        lfoPMS = try c.decodeIfPresent(Int.self, forKey: .lfoPMS) ?? 3
        pitchEGR1 = try c.decodeIfPresent(Int.self, forKey: .pitchEGR1) ?? 99
        pitchEGR2 = try c.decodeIfPresent(Int.self, forKey: .pitchEGR2) ?? 99
        pitchEGR3 = try c.decodeIfPresent(Int.self, forKey: .pitchEGR3) ?? 99
        pitchEGR4 = try c.decodeIfPresent(Int.self, forKey: .pitchEGR4) ?? 99
        pitchEGL1 = try c.decodeIfPresent(Int.self, forKey: .pitchEGL1) ?? 50
        pitchEGL2 = try c.decodeIfPresent(Int.self, forKey: .pitchEGL2) ?? 50
        pitchEGL3 = try c.decodeIfPresent(Int.self, forKey: .pitchEGL3) ?? 50
        pitchEGL4 = try c.decodeIfPresent(Int.self, forKey: .pitchEGL4) ?? 50
        transpose = try c.decodeIfPresent(Int.self, forKey: .transpose) ?? 0
    }
}

// MARK: - DX7 → Parameter Conversion

extension DX7OperatorPreset {
    /// Convert DX7 frequency coarse + fine to ratio
    public var frequencyRatio: Float {
        let coarse: Float = frequencyCoarse == 0 ? 0.5 : Float(frequencyCoarse)
        return coarse * (1.0 + Float(frequencyFine) / 100.0)
    }

    /// Convert DX7 detune (0-14, 7=center) to cents offset
    public var detuneCents: Float { Float(detune - 7) }
}
