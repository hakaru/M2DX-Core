// DX7SysExParser.swift
// M2DX-Core — Parse DX7 32-voice bulk dump SysEx (.syx) files

import Foundation

// MARK: - SysEx Bank

public struct DX7SysExBank: Sendable {
    public let name: String
    public let presets: [DX7Preset]

    /// Public memberwise initializer — lets apps compose banks from non-SysEx
    /// sources (e.g. user-saved custom presets) alongside parsed .syx banks.
    public init(name: String, presets: [DX7Preset]) {
        self.name = name
        self.presets = presets
    }
}

// MARK: - Parser

/// Parses DX7 32-voice bulk dump SysEx data (4104 bytes)
/// Format: F0 43 00 09 20 00 [128×32 voice data] checksum F7
public enum DX7SysExParser {

    private static let bulkDumpSize = 4104
    private static let headerSize = 6
    private static let packedVoiceSize = 128
    private static let voicesPerBank = 32

    public static func parse(url: URL, bankName: String, category: PresetCategory = .other) -> DX7SysExBank? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data: data, bankName: bankName, category: category)
    }

    public static func parse(data rawData: Data, bankName: String, category: PresetCategory = .other) -> DX7SysExBank? {
        // A Data slice keeps its parent's index space (nonzero startIndex), but the
        // logic below indexes and sub-slices with absolute offsets. Normalize to a
        // zero-based buffer so a sliced bank parses instead of trapping on data[0].
        let data = rawData.startIndex == 0 ? rawData : Data(rawData)
        guard data.count == bulkDumpSize else { return nil }
        guard data[0] == 0xF0, data[1] == 0x43, data[data.count - 1] == 0xF7 else { return nil }
        // Identify a 32-voice bulk dump: format 0x09, byte count 0x20 0x00 (4096).
        guard data[3] == 0x09, data[4] == 0x20, data[5] == 0x00 else { return nil }
        // Validate the 7-bit two's-complement checksum over the 4096 voice bytes.
        var checkSum = 0
        for i in headerSize..<(headerSize + voicesPerBank * packedVoiceSize) {
            checkSum = (checkSum + Int(data[i])) & 0x7F
        }
        guard ((128 - checkSum) & 0x7F) == Int(data[bulkDumpSize - 2] & 0x7F) else { return nil }

        var presets: [DX7Preset] = []
        presets.reserveCapacity(voicesPerBank)

        for i in 0..<voicesPerBank {
            let offset = headerSize + i * packedVoiceSize
            let voiceData = data.subdata(in: offset..<(offset + packedVoiceSize))
            let preset = parsePackedVoice(voiceData, category: category)
            presets.append(preset)
        }

        return DX7SysExBank(name: bankName, presets: presets)
    }

    private static func parsePackedVoice(_ data: Data, category: PresetCategory) -> DX7Preset {
        let bytes = [UInt8](data)

        var ops: [DX7OperatorPreset] = []
        ops.reserveCapacity(6)
        for rawIdx in 0..<6 {
            let opOffset = rawIdx * 17
            let op = parsePackedOperator(bytes, offset: opOffset)
            ops.append(op)
        }
        ops.reverse()

        // SysEx VMEM order is OP6..OP1; after reverse(), ops[5] = OP6 (always carries feedback).
        let voiceFB = Int(bytes[111] & 0x07)
        var op6 = ops[5]
        op6.feedback = voiceFB
        ops[5] = op6

        let algorithm = Int(bytes[110] & 0x1F)
        let feedback = voiceFB

        let pegR1 = Int(bytes[102]), pegR2 = Int(bytes[103])
        let pegR3 = Int(bytes[104]), pegR4 = Int(bytes[105])
        let pegL1 = Int(bytes[106]), pegL2 = Int(bytes[107])
        let pegL3 = Int(bytes[108]), pegL4 = Int(bytes[109])

        let lfoSpeed = Int(bytes[112]), lfoDelay = Int(bytes[113])
        let lfoPMD = Int(bytes[114]), lfoAMD = Int(bytes[115])
        let lfoPacked = bytes[116]
        let lfoSync = Int(lfoPacked & 0x01)
        let lfoWaveform = Int((lfoPacked >> 1) & 0x07)
        let lfoPMS = Int((lfoPacked >> 4) & 0x07)

        let transposeRaw = Int(bytes[117])
        let transpose = transposeRaw - 24

        let nameBytes = bytes[118..<128]
        let name = String(nameBytes.map { Character(UnicodeScalar($0 & 0x7F)) }).trimmingCharacters(in: .whitespaces)

        return DX7Preset(
            name: name, algorithm: algorithm, feedback: feedback,
            operators: ops, category: category,
            lfoSpeed: lfoSpeed, lfoDelay: lfoDelay,
            lfoPMD: lfoPMD, lfoAMD: lfoAMD,
            lfoSync: lfoSync, lfoWaveform: lfoWaveform, lfoPMS: lfoPMS,
            pitchEGR1: pegR1, pitchEGR2: pegR2, pitchEGR3: pegR3, pitchEGR4: pegR4,
            pitchEGL1: pegL1, pitchEGL2: pegL2, pitchEGL3: pegL3, pitchEGL4: pegL4,
            transpose: transpose
        )
    }

    private static func parsePackedOperator(_ bytes: [UInt8], offset: Int) -> DX7OperatorPreset {
        let b = bytes
        // Clamp fields whose DX7 range is 0-99 — a malformed dump can carry raw
        // 100-255 bytes here, and the load path only saturates to 0-255.
        func c99(_ v: UInt8) -> Int { min(99, Int(v)) }
        return DX7OperatorPreset(
            outputLevel: c99(b[offset + 14]),
            frequencyCoarse: Int((b[offset + 15] >> 1) & 0x1F),
            frequencyFine: c99(b[offset + 16]),
            detune: Int((b[offset + 12] >> 3) & 0x0F),
            feedback: 0,
            egRate1: c99(b[offset + 0]), egRate2: c99(b[offset + 1]),
            egRate3: c99(b[offset + 2]), egRate4: c99(b[offset + 3]),
            egLevel1: c99(b[offset + 4]), egLevel2: c99(b[offset + 5]),
            egLevel3: c99(b[offset + 6]), egLevel4: c99(b[offset + 7]),
            velocitySensitivity: Int((b[offset + 13] >> 2) & 0x07),
            ampModSensitivity: Int(b[offset + 13] & 0x03),
            keyboardRateScaling: Int(b[offset + 12] & 0x07),
            klsBreakPoint: c99(b[offset + 8]),
            klsLeftDepth: c99(b[offset + 9]),
            klsRightDepth: c99(b[offset + 10]),
            klsLeftCurve: Int(b[offset + 11] & 0x03),
            klsRightCurve: Int((b[offset + 11] >> 2) & 0x03),
            frequencyMode: Int(b[offset + 15] & 0x01)
        )
    }
}
