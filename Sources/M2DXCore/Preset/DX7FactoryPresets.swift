// DX7FactoryPresets.swift
// M2DX-Core — Factory preset library loaded from SysEx bulk dumps

import Foundation

/// DX7 factory presets loaded from bundled SysEx files
public enum DX7FactoryPresets {

    /// INIT VOICE - default blank patch
    public static let initVoice = DX7Preset(
        name: "INIT VOICE", algorithm: 0, feedback: 0,
        operators: [
            DX7OperatorPreset(outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0, detune: 7,
                egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 99,
                egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0),
            DX7OperatorPreset(outputLevel: 0, frequencyCoarse: 1, frequencyFine: 0, detune: 7),
            DX7OperatorPreset(outputLevel: 0, frequencyCoarse: 1, frequencyFine: 0, detune: 7),
            DX7OperatorPreset(outputLevel: 0, frequencyCoarse: 1, frequencyFine: 0, detune: 7),
            DX7OperatorPreset(outputLevel: 0, frequencyCoarse: 1, frequencyFine: 0, detune: 7),
            DX7OperatorPreset(outputLevel: 0, frequencyCoarse: 1, frequencyFine: 0, detune: 7),
        ],
        category: .other
    )

    /// All factory presets
    public static let all: [DX7Preset] = {
        var result = [initVoice]
        result.append(contentsOf: factoryROMs)
        return result
    }()

    /// ROM1A through ROM4B (8 banks × 32 = 256 presets)
    public static let factoryROMs: [DX7Preset] = {
        let files = ["rom1a", "rom1b", "rom2a", "rom2b", "rom3a", "rom3b", "rom4a", "rom4b"]
        return loadBanks(files: files, subdirectory: "SysEx")
    }()

    /// Bank metadata for UI grouping
    public static let banks: [DX7SysExBank] = {
        let romFiles = ["rom1a", "rom1b", "rom2a", "rom2b", "rom3a", "rom3b", "rom4a", "rom4b"]
        return loadBankObjects(files: romFiles, subdirectory: "SysEx")
    }()

    private static func loadBanks(files: [String], subdirectory: String) -> [DX7Preset] {
        var presets: [DX7Preset] = []
        let bundle = Bundle.module
        for file in files {
            guard let url = bundle.url(forResource: file, withExtension: "syx", subdirectory: subdirectory) else {
                continue
            }
            if let bank = DX7SysExParser.parse(url: url, bankName: file) {
                presets.append(contentsOf: bank.presets)
            }
        }
        return presets
    }

    private static func loadBankObjects(files: [String], subdirectory: String) -> [DX7SysExBank] {
        var banks: [DX7SysExBank] = []
        let bundle = Bundle.module
        for file in files {
            guard let url = bundle.url(forResource: file, withExtension: "syx", subdirectory: subdirectory) else {
                continue
            }
            if let bank = DX7SysExParser.parse(url: url, bankName: file) {
                banks.append(bank)
            }
        }
        return banks
    }
}
