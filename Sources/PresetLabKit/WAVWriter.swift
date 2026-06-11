// WAVWriter.swift
// PresetLabKit — minimal mono 16-bit PCM WAV writer for audition files.

import Foundation

public enum WAVWriter {
    public static func writeMono16(samples: [Float], sampleRate: Int, to url: URL) throws {
        var d = Data()
        func le32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataLen = UInt32(samples.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); le32(36 + dataLen)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); le32(16); le16(1); le16(1)
        le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        d.append(contentsOf: Array("data".utf8)); le32(dataLen)
        for s in samples { le16(UInt16(bitPattern: Int16(max(-1, min(1, s)) * 32767))) }
        try d.write(to: url)
    }
}
