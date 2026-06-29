// MarkIDivisorABTests.swift
// M2DX-Core — INVESTIGATION harness for the Mark I forward-modulation divisor
// recalibration (audit markI-ops-dac finding 2; see docs/mark-i-recalibration-plan.md).
//
// This is NOT a pass/fail test. It renders the two patches the Mark I divisor was
// originally calibrated against — ROM1A "BASS 1" (alg 15) and factory "E.PIANO 1"
// (alg 4, has feedback) — through the full production SynthEngine at several Mark I
// forward-mod divisors plus the Modern engine as the brightness reference, then:
//   • prints raw peak + sustain spectral centroid (the brightness number), and
//   • writes a PEAK-NORMALIZED (−3 dBFS) WAV per variant to /tmp/m2dx-marki-ab/ so an
//     A/B listen compares TIMBRE, not loudness (loudness is a separate finding-1 axis,
//     reported via the raw peak).
//
// Run: `swift test --filter renderMarkIDivisorAB`  (clean-room: no GPL Dexed consulted).

import Testing
import Foundation
@testable import M2DXCore

@Suite("Mark I divisor A/B (investigation — writes WAVs, no assertions)")
struct MarkIDivisorABTests {

    private let sampleRate: Float = 48000
    private let total = 144000          // 3.0 s at 48 kHz

    /// Render a preset through the full SynthEngine at a chosen engine + Mark I divisor.
    private func render(_ preset: DX7Preset, engine: FMEngine, divisor: Double?,
                        note: UInt8, vel: Int) -> [Float] {
        let synth = SynthEngine()
        synth.setSampleRate(sampleRate)
        synth.setMasterVolume(1.0)
        synth.setFMEngine(engine)
        if let d = divisor { synth.setMarkIModDivisor(d) }
        synth.loadDX7Preset(preset)

        let blk = 512
        var wL = [Float](repeating: 0, count: blk), wR = [Float](repeating: 0, count: blk)
        wL.withUnsafeMutableBufferPointer { lp in wR.withUnsafeMutableBufferPointer { rp in
            synth.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        synth.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(vel) << 9))

        var out = [Float](repeating: 0, count: total)
        var rr = [Float](repeating: 0, count: total)
        out.withUnsafeMutableBufferPointer { op in rr.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                synth.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return out
    }

    /// Spectral centroid (Hz) over `range` via a coarse 40 Hz-grid DFT (lower = darker).
    private func centroid(_ samples: [Float], over range: Range<Int>) -> Double {
        let sr = Double(sampleRate)
        let n = range.count
        var numer = 0.0, denom = 0.0, f = 40.0
        while f < 10000.0 {
            var re = 0.0, im = 0.0
            let w = 2.0 * Double.pi * f / sr
            for i in range {
                let s = Double(samples[i]); let p = w * Double(i - range.lowerBound)
                re += s * cos(p); im -= s * sin(p)
            }
            let mag2 = (re * re + im * im) / Double(n * n)
            numer += f * mag2; denom += mag2; f += 40.0
        }
        return denom > 0 ? numer / denom : 0
    }

    /// Minimal 16-bit mono PCM WAV writer (avoids a PresetLabKit test-target dependency).
    private func writeWAV(_ samples: [Float], sampleRate: Int, to url: URL) throws {
        var data = Data()
        func le32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        func le16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
        let dataSize = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); le32(UInt32(36 + dataSize))
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8)); le32(16); le16(1); le16(1)
        le32(UInt32(sampleRate)); le32(UInt32(sampleRate * 2)); le16(2); le16(16)
        data.append(contentsOf: Array("data".utf8)); le32(UInt32(dataSize))
        for s in samples {
            let c = max(-1.0, min(1.0, s))
            le16(UInt16(bitPattern: Int16(c * 32767.0)))
        }
        try data.write(to: url)
    }

    @Test("Render Mark I divisor A/B WAVs (BASS 1 + E.PIANO 1)")
    func renderMarkIDivisorAB() throws {
        let dir = URL(fileURLWithPath: "/tmp/m2dx-marki-ab")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let bass1 = DX7SysExParser.parse(data: bankFromVoice(rom1aBass1Packed), bankName: "ROM1A")!.presets[0]
        let epiano1 = DX7FactoryPresets.all[11]   // ROM1A E.PIANO 1 (alg 4, feedback)
        let patches: [(name: String, preset: DX7Preset)] = [("bass1", bass1), ("epiano1", epiano1)]

        // Modern = the brightness reference; Mark I at four divisors bracketing the
        // audit-faithful ÷4 … the bit-parity ÷8.
        let variants: [(name: String, engine: FMEngine, divisor: Double?)] = [
            ("modern",   .modern, nil),
            ("mki_div4", .markI,  4.0),
            ("mki_div5", .markI,  5.0),
            ("mki_div6", .markI,  6.0),
            ("mki_div8", .markI,  8.0),
        ]

        let note: UInt8 = 60, vel = 100
        let sustain = 19200..<43200    // 0.4 .. 0.9 s, same window as MarkICalibrationTests
        let targetPeak: Float = 0.707  // −3 dBFS after normalization

        print("── Mark I divisor A/B (note 60, vel 100, peak-normalized to −3 dBFS) ──")
        for (pname, preset) in patches {
            for v in variants {
                let raw = render(preset, engine: v.engine, divisor: v.divisor, note: note, vel: vel)
                let peak = raw.map { abs($0) }.max() ?? 0
                let cent = centroid(raw, over: sustain)
                let g = peak > 1e-9 ? targetPeak / peak : 1
                let norm = raw.map { $0 * g }
                let url = dir.appendingPathComponent("\(pname)_\(v.name).wav")
                try writeWAV(norm, sampleRate: Int(sampleRate), to: url)
                let q12 = v.divisor != nil ? " Q12=\(Int((4096.0 / v.divisor!).rounded()))" : ""
                let pp = pname.padding(toLength: 8, withPad: " ", startingAt: 0)
                let vv = v.name.padding(toLength: 9, withPad: " ", startingAt: 0)
                print("  \(pp) \(vv) centroid=\(Int(cent.rounded())) Hz  rawPeak=\(String(format: "%.4f", peak))\(q12)  → \(url.path)")
            }
        }
        print("── A/B WAVs in \(dir.path) — listen Modern vs ÷4/÷5/÷6/÷8 ──")
    }
}
