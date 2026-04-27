// DX7FactoryPresets.swift
// M2DX-Core — Factory preset library (hand-designed, original).
//
// Production presets are now defined directly in Swift across per-category
// files (KeysPresets.swift, BassPresets.swift, ...). No Yamaha factory ROM
// SysEx is bundled or referenced. The legacy SysEx loaders below remain as
// deprecated convenience helpers for users who want to load their own .syx
// banks at runtime.

import Foundation

/// DX7 factory presets, hand-designed in Swift.
public enum DX7FactoryPresets {

    /// INIT VOICE - default blank patch (algorithm 1, OP1 carrier only).
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

    /// All factory presets shipped with M2DX-Core.
    public static let all: [DX7Preset] = {
        var result = [initVoice]
        result.append(contentsOf: customPresets)
        return result
    }()

    /// Hand-designed factory presets aggregated from per-category batches.
    /// Each batch lives in its own file (KeysPresets.swift, BassPresets.swift, ...).
    public static let customPresets: [DX7Preset] = {
        var result: [DX7Preset] = []
        result.append(contentsOf: DX7Preset.keysBatch)
        result.append(contentsOf: DX7Preset.bassBatch)
        result.append(contentsOf: DX7Preset.brassBatch)
        result.append(contentsOf: DX7Preset.stringsBatch)
        result.append(contentsOf: DX7Preset.organBatch)
        result.append(contentsOf: DX7Preset.percussionBatch)
        result.append(contentsOf: DX7Preset.woodwindBatch)
        result.append(contentsOf: DX7Preset.otherBatch)
        return result
    }()

    @available(*, deprecated, message: "Yamaha factory ROM SysEx is no longer bundled. Use customPresets, or load your own .syx via DX7SysExParser.")
    public static let factoryROMs: [DX7Preset] = []

    /// Synthetic banks grouped by `PresetCategory`, derived from `customPresets`.
    /// Only categories that contain at least one preset appear in the bank list,
    /// so the UI grows automatically as new batches land. Bank index here is also
    /// what `selectPresetByBank(msb:lsb:program:)` uses for MIDI Bank Select MSB.
    public static let banks: [DX7SysExBank] = {
        let order: [PresetCategory] = [.keys, .bass, .brass, .strings,
                                       .organ, .percussion, .woodwind, .other]
        return order.compactMap { category in
            let presetsInCategory = customPresets.filter { $0.category == category }
            guard !presetsInCategory.isEmpty else { return nil }
            return DX7SysExBank(name: category.rawValue.uppercased(),
                                presets: presetsInCategory)
        }
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
