// ROM1AImportComparisonTests.swift
// M2DX-Core — End-to-end import-path verification using REAL DX7 ROM1A voices.
//
// The existing VoiceComparisonTests prove the FM engine is bit-exact to DEXED,
// but they (a) build the voice manually from the UNPACKED 156-byte layout and
// (b) set operator frequency directly from dx7ref — so they never exercise
// `DX7SysExParser` (the PACKED 128-byte .syx parser). This file closes that gap
// with two checks driven by the actual ROM1A BASS 1 / PIANO 1 packed voices:
//
//   A. Parser fidelity — DX7SysExParser(packed) must reproduce the canonical
//      VMEM→VCED unpacking field-for-field.
//   B. Engine fidelity on real data — setupM2DXVoice(canonical VCED) must render
//      bit-exact to dx7ref for these real (high-feedback, KLS-heavy) patches.
//
// Reported by a user: imported ROM1A BASS 1 / PIANO 1 sound distorted / different
// from the original DX7/Dexed (with the app Maximizer OFF). These tests determine
// whether the divergence lives in the engine/parser or higher up (app FX/gain).

import Testing
import Foundation
import Darwin
@testable import M2DXCore
import DX7Ref

// MARK: - Real ROM1A packed voices (VMEM, 128 bytes each, OP6 at bytes 0-16)

// Internal (not private) so the Mark I calibration suite can reuse the real
// ROM1A BASS 1 packed voice without duplicating the 128 bytes here.
let rom1aBass1Packed: [UInt8] = [
    0x5E, 0x38, 0x18, 0x37, 0x5D, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x39, 0x1C, 0x55, 0x12,
    0x00, 0x63, 0x00, 0x00, 0x00, 0x63, 0x00, 0x00, 0x00, 0x34, 0x4B, 0x00, 0x00, 0x3F, 0x0C, 0x3E,
    0x00, 0x00, 0x5A, 0x2A, 0x07, 0x37, 0x5A, 0x1E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3D, 0x14,
    0x5D, 0x0A, 0x00, 0x58, 0x60, 0x20, 0x1E, 0x4F, 0x41, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3E,
    0x0C, 0x63, 0x00, 0x00, 0x63, 0x14, 0x00, 0x00, 0x63, 0x00, 0x00, 0x00, 0x29, 0x00, 0x00, 0x00,
    0x3F, 0x00, 0x50, 0x00, 0x00, 0x5F, 0x3E, 0x11, 0x3A, 0x63, 0x5F, 0x20, 0x00, 0x24, 0x39, 0x0E,
    0x03, 0x3F, 0x00, 0x63, 0x00, 0x00, 0x5E, 0x43, 0x5F, 0x3C, 0x32, 0x32, 0x32, 0x32, 0x0F, 0x0F,
    0x23, 0x00, 0x00, 0x00, 0x30, 0x0C, 0x42, 0x41, 0x53, 0x53, 0x20, 0x20, 0x20, 0x20, 0x31, 0x20,
]

private let rom1aPiano1Packed: [UInt8] = [
    0x63, 0x00, 0x19, 0x00, 0x63, 0x4B, 0x00, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x35, 0x00, 0x52, 0x02,
    0x00, 0x51, 0x3A, 0x24, 0x27, 0x63, 0x0E, 0x00, 0x00, 0x30, 0x00, 0x42, 0x00, 0x35, 0x04, 0x5D,
    0x02, 0x3A, 0x51, 0x17, 0x16, 0x2D, 0x63, 0x4E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x45, 0x08,
    0x63, 0x02, 0x00, 0x51, 0x19, 0x19, 0x0E, 0x63, 0x63, 0x63, 0x00, 0x2F, 0x20, 0x4A, 0x03, 0x3D,
    0x00, 0x39, 0x06, 0x00, 0x63, 0x00, 0x19, 0x00, 0x63, 0x4B, 0x00, 0x00, 0x00, 0x00, 0x0D, 0x00,
    0x4D, 0x00, 0x57, 0x02, 0x00, 0x51, 0x19, 0x14, 0x30, 0x63, 0x52, 0x00, 0x00, 0x00, 0x55, 0x00,
    0x03, 0x2C, 0x08, 0x63, 0x02, 0x00, 0x5E, 0x43, 0x5F, 0x3C, 0x32, 0x32, 0x32, 0x32, 0x12, 0x0E,
    0x23, 0x00, 0x00, 0x00, 0x40, 0x18, 0x50, 0x49, 0x41, 0x4E, 0x4F, 0x20, 0x20, 0x20, 0x31, 0x20,
]

// MARK: - Helpers

/// Wrap a single 128-byte packed voice into a valid 4104-byte DX7 bulk dump so
/// it can be fed to `DX7SysExParser.parse`. The voice is replicated across all
/// 32 slots; presets[0] is the voice under test.
func bankFromVoice(_ v: [UInt8]) -> Data {
    var d = Data([0xF0, 0x43, 0x00, 0x09, 0x20, 0x00])
    for _ in 0..<32 { d.append(contentsOf: v) }
    var sum = 0
    for i in 6..<(6 + 4096) { sum = (sum + Int(d[i])) & 0x7F }
    d.append(UInt8((128 - sum) & 0x7F))
    d.append(0xF7)
    return d
}

/// Canonical DX7 VMEM(128) → VCED(156) unpack, preserving operator byte order
/// (VMEM position 0 = OP6 → VCED offset 0). Matches the layout that both
/// dx7ref_voice_init and setupM2DXVoice consume (op i → params i / opIdx i).
private func unpackVMEM(_ p: [UInt8]) -> [UInt8] {
    var v = [UInt8](repeating: 0, count: 156)
    for op in 0..<6 {
        let s = op * 17, off = op * 21
        for i in 0..<4 { v[off + i] = p[s + i] }          // R1-R4
        for i in 0..<4 { v[off + 4 + i] = p[s + 4 + i] }  // L1-L4
        v[off + 8] = p[s + 8]                              // break point
        v[off + 9] = p[s + 9]                              // left depth
        v[off + 10] = p[s + 10]                            // right depth
        v[off + 11] = p[s + 11] & 0x03                     // left curve
        v[off + 12] = (p[s + 11] >> 2) & 0x03              // right curve
        v[off + 13] = p[s + 12] & 0x07                     // rate scaling
        v[off + 14] = p[s + 13] & 0x03                     // AMS
        v[off + 15] = (p[s + 13] >> 2) & 0x07              // vel sensitivity
        v[off + 16] = p[s + 14]                            // output level
        v[off + 17] = p[s + 15] & 0x01                     // freq mode
        v[off + 18] = (p[s + 15] >> 1) & 0x1F              // coarse
        v[off + 19] = p[s + 16]                            // fine
        v[off + 20] = (p[s + 12] >> 3) & 0x0F              // detune
    }
    for i in 0..<4 { v[126 + i] = p[102 + i] }             // pitch EG rates
    for i in 0..<4 { v[130 + i] = p[106 + i] }             // pitch EG levels
    v[134] = p[110] & 0x1F                                 // algorithm
    v[135] = p[111] & 0x07                                 // feedback
    v[136] = (p[111] >> 3) & 0x01                          // osc key sync
    v[137] = p[112]; v[138] = p[113]; v[139] = p[114]; v[140] = p[115]  // LFO speed/delay/PMD/AMD
    v[141] = p[116] & 0x01                                 // LFO sync
    v[142] = (p[116] >> 1) & 0x07                          // LFO waveform
    v[143] = (p[116] >> 4) & 0x07                          // LFO PMS
    v[144] = p[117]                                        // transpose (raw 0-48)
    return v
}

// MARK: - Tests

// NOTE: dx7ref's frequency LUT is GLOBAL C state (dx7ref_freq_init mutates it).
// These tests render at multiple sample rates (44100 and 48000), so they must not
// run concurrently with each other — a 48 kHz freq_init mid-flight would corrupt a
// 44.1 kHz render. `.serialized` keeps this suite single-threaded. (The rest of the
// suite uses 44100 like VoiceComparisonTests, so cross-suite runs stay safe as long
// as the lone 48 kHz test restores 44100 before yielding — see deviceSampleRate48k.)
@Suite("ROM1A Import Path vs DEXED", .serialized)
struct ROM1AImportComparisonTests {

    // A. Parser fidelity: DX7SysExParser must reproduce the canonical unpack.
    private func assertParserMatchesCanonical(_ packed: [UInt8], _ label: String) {
        let canonical = unpackVMEM(packed)
        guard let bank = DX7SysExParser.parse(data: bankFromVoice(packed), bankName: "ROM1A") else {
            Issue.record("\(label): DX7SysExParser.parse returned nil"); return
        }
        let preset = bank.presets[0]

        // Parser stores operators reversed: operators[0]=OP1(VMEM pos 5) .. operators[5]=OP6(VMEM pos 0).
        // VMEM position `op` (canonical VCED offset op*21) == operators[5-op].
        for op in 0..<6 {
            let pre = preset.operators[5 - op]
            let off = op * 21
            #expect(pre.outputLevel == Int(canonical[off + 16]), "\(label) op@\(op): outputLevel")
            #expect(pre.frequencyCoarse == Int(canonical[off + 18]), "\(label) op@\(op): coarse")
            #expect(pre.frequencyFine == Int(canonical[off + 19]), "\(label) op@\(op): fine")
            #expect(pre.detune == Int(canonical[off + 20]), "\(label) op@\(op): detune")
            #expect(pre.frequencyMode == Int(canonical[off + 17]), "\(label) op@\(op): mode")
            #expect(pre.egRate1 == Int(canonical[off + 0]), "\(label) op@\(op): egR1")
            #expect(pre.egRate2 == Int(canonical[off + 1]), "\(label) op@\(op): egR2")
            #expect(pre.egRate3 == Int(canonical[off + 2]), "\(label) op@\(op): egR3")
            #expect(pre.egRate4 == Int(canonical[off + 3]), "\(label) op@\(op): egR4")
            #expect(pre.egLevel1 == Int(canonical[off + 4]), "\(label) op@\(op): egL1")
            #expect(pre.egLevel2 == Int(canonical[off + 5]), "\(label) op@\(op): egL2")
            #expect(pre.egLevel3 == Int(canonical[off + 6]), "\(label) op@\(op): egL3")
            #expect(pre.egLevel4 == Int(canonical[off + 7]), "\(label) op@\(op): egL4")
            #expect(pre.keyboardRateScaling == Int(canonical[off + 13]), "\(label) op@\(op): rateScaling")
            #expect(pre.ampModSensitivity == Int(canonical[off + 14]), "\(label) op@\(op): AMS")
            #expect(pre.velocitySensitivity == Int(canonical[off + 15]), "\(label) op@\(op): velSens")
            #expect(pre.klsBreakPoint == Int(canonical[off + 8]), "\(label) op@\(op): klsBreakPoint")
            #expect(pre.klsLeftDepth == Int(canonical[off + 9]), "\(label) op@\(op): klsLeftDepth")
            #expect(pre.klsRightDepth == Int(canonical[off + 10]), "\(label) op@\(op): klsRightDepth")
            #expect(pre.klsLeftCurve == Int(canonical[off + 11]), "\(label) op@\(op): klsLeftCurve")
            #expect(pre.klsRightCurve == Int(canonical[off + 12]), "\(label) op@\(op): klsRightCurve")
        }
        #expect(preset.algorithm == Int(canonical[134]), "\(label): algorithm")
        #expect(preset.feedback == Int(canonical[135]), "\(label): feedback")
        #expect(preset.transpose == Int(canonical[144]) - 24, "\(label): transpose")
    }

    @Test("BASS 1 parser output matches canonical VMEM unpack")
    func bass1ParserFidelity() { assertParserMatchesCanonical(rom1aBass1Packed, "BASS1") }

    @Test("PIANO 1 parser output matches canonical VMEM unpack")
    func piano1ParserFidelity() { assertParserMatchesCanonical(rom1aPiano1Packed, "PIANO1") }

    // B. Engine fidelity on real data: render the canonical VCED through the M2DX
    // voice and compare bit-exact to dx7ref. Transpose is neutralized (24) so the
    // harness — which does not apply transpose — compares operator structure only.
    private func renderMismatches(_ packed: [UInt8], midinote: UInt8, velocity7: Int,
                                  blocks: Int = 200, sampleRate: Float = 44100)
        -> (mismatches: Int, firstBlock: Int, firstSample: Int, refVal: Int32, m2dxVal: Int32) {
        var patch = unpackVMEM(packed)
        patch[144] = 24  // neutralize transpose for the harness comparison

        dx7ref_freq_init(Double(sampleRate))
        var refVoice = dx7ref_voice_t()
        patch.withUnsafeBufferPointer { ptr in
            dx7ref_voice_init(&refVoice, ptr.baseAddress!, Int32(midinote), Int32(velocity7), Double(sampleRate))
        }
        var m2dxVoice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: sampleRate)

        let refBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let m2dxBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { refBuf.deallocate(); m2dxBuf.deallocate(); bus1.deallocate(); bus2.deallocate() }

        var mismatches = 0, firstBlock = -1, firstSample = -1
        var firstRef: Int32 = 0, firstM2dx: Int32 = 0
        for block in 0..<blocks {
            refBuf.initialize(repeating: 0, count: kBlockSize)
            m2dxBuf.initialize(repeating: 0, count: kBlockSize)
            dx7ref_voice_render(&refVoice, refBuf)
            m2dxVoice.updateGains()
            m2dxVoice.renderBlock(output: m2dxBuf, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
            for s in 0..<kBlockSize where refBuf[s] != m2dxBuf[s] {
                mismatches += 1
                if firstBlock < 0 { firstBlock = block; firstSample = s; firstRef = refBuf[s]; firstM2dx = m2dxBuf[s] }
            }
        }
        return (mismatches, firstBlock, firstSample, firstRef, firstM2dx)
    }

    @Test("BASS 1 (alg16, fb7) renders bit-exact to DEXED")
    func bass1RenderMatch() {
        let r = renderMismatches(rom1aBass1Packed, midinote: 60, velocity7: 100)
        #expect(r.mismatches == 0,
            "BASS1: \(r.mismatches) mismatches, first block \(r.firstBlock) sample \(r.firstSample) ref=\(r.refVal) m2dx=\(r.m2dxVal)")
    }

    @Test("PIANO 1 (alg19, fb6) renders bit-exact to DEXED")
    func piano1RenderMatch() {
        let r = renderMismatches(rom1aPiano1Packed, midinote: 60, velocity7: 100)
        #expect(r.mismatches == 0,
            "PIANO1: \(r.mismatches) mismatches, first block \(r.firstBlock) sample \(r.firstSample) ref=\(r.refVal) m2dx=\(r.m2dxVal)")
    }

    // D. Note × velocity sweep — the user reports harsh FM at HIGH velocity and an
    // extreme volume drop BELOW note 60. The bit-exact proof above was only at
    // note 60 / vel 100. This sweep tests the exact reported conditions and also
    // reports the ref-vs-m2dx peak per cell, so a by-design level profile (peaks
    // match dexed) is distinguishable from a KLS/velocity bug (peaks diverge).
    private func sweepCell(_ packed: [UInt8], midinote: UInt8, velocity7: Int, blocks: Int = 120)
        -> (mismatches: Int, refPeak: Int32, m2dxPeak: Int32) {
        var patch = unpackVMEM(packed); patch[144] = 24
        dx7ref_freq_init(44100.0)
        var refVoice = dx7ref_voice_t()
        patch.withUnsafeBufferPointer { ptr in
            dx7ref_voice_init(&refVoice, ptr.baseAddress!, Int32(midinote), Int32(velocity7), 44100.0)
        }
        var m2dxVoice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: 44100)
        let refBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let m2dxBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { refBuf.deallocate(); m2dxBuf.deallocate(); bus1.deallocate(); bus2.deallocate() }
        var mism = 0; var rPeak: Int32 = 0; var mPeak: Int32 = 0
        for _ in 0..<blocks {
            refBuf.initialize(repeating: 0, count: kBlockSize)
            m2dxBuf.initialize(repeating: 0, count: kBlockSize)
            dx7ref_voice_render(&refVoice, refBuf)
            m2dxVoice.updateGains()
            m2dxVoice.renderBlock(output: m2dxBuf, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
            for s in 0..<kBlockSize {
                if refBuf[s] != m2dxBuf[s] { mism += 1 }
                rPeak = max(rPeak, abs(refBuf[s])); mPeak = max(mPeak, abs(m2dxBuf[s]))
            }
        }
        return (mism, rPeak, mPeak)
    }

    @Test("Note × velocity sweep stays bit-exact to DEXED (reported harsh conditions)")
    func noteVelocitySweep() {
        let voices: [(String, [UInt8])] = [("BASS1", rom1aBass1Packed), ("PIANO1", rom1aPiano1Packed)]
        let notes: [UInt8] = [24, 36, 48, 60, 72, 84, 96]
        let vels = [40, 80, 100, 127]
        for (label, packed) in voices {
            print("──── \(label): refPeak/m2dxPeak (normalized /2^28), mismatches ────")
            for note in notes {
                var row = "note \(note): "
                for vel in vels {
                    let c = sweepCell(packed, midinote: note, velocity7: vel)
                    let rn = Float(c.refPeak) / 268435456.0
                    let mn = Float(c.m2dxPeak) / 268435456.0
                    row += String(format: "v%d[r%.3f/m%.3f%@] ", vel, rn, mn, c.mismatches == 0 ? "" : " MISMATCH:\(c.mismatches)")
                    #expect(c.mismatches == 0, "\(label) note=\(note) vel=\(vel): \(c.mismatches) mismatches")
                }
                print(row)
            }
        }
    }

    // E. Production frequency path — the ONLY single-note path the bit-exact sweep
    // above does NOT exercise: setupM2DXVoice injects dx7ref's log-LUT frequency,
    // whereas production computes op.freq from baseFreq×ratio×detune (linear Hz) +
    // production detune = 2^((d-7)/1200). The user reports a SINGLE note distorts,
    // so this is the last untested engine component. A small freq delta causes
    // phase drift (growing mismatches) without adding harmonics, so we measure
    // perceptual divergence: first-block max-diff (phase-aligned at note-on), peak,
    // and RMS — not bit-exactness.
    private func setupProdFreqVoice(patch: [UInt8], midinote: UInt8, velocity7: Int, sampleRate: Float = 44100) -> DX7Voice {
        var voice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: sampleRate)
        let baseFreq = kMIDIFreqLUT[Int(midinote)]
        for opIdx in 0..<6 {
            let off = opIdx * 21
            let mode = Int(patch[off + 17]), coarse = Int(patch[off + 18])
            let fine = Int(patch[off + 19]), detune = Int(patch[off + 20])
            guard mode == 0 else { continue }   // BASS1/PIANO1 are all ratio mode
            voice.withOp(opIdx) { op in
                let coarseF: Float = coarse == 0 ? 0.5 : Float(coarse)
                op.ratio = coarseF * (1.0 + Float(fine) / 100.0)
                op.detune = powf(2.0, Float(detune - 7) / 1200.0)  // production detune model
                op.isFixedFreq = false
                op.noteOn(baseFreq: baseFreq)   // production freq: baseFreq×ratio×detune → updateFreq
            }
        }
        return voice
    }

    @Test("Production frequency path vs DEXED — perceptual divergence on single notes")
    func productionFreqPath() {
        let voices: [(String, [UInt8])] = [("BASS1", rom1aBass1Packed), ("PIANO1", rom1aPiano1Packed)]
        for (label, packed) in voices {
            for note: UInt8 in [36, 48, 60, 72] {
                for vel in [100, 127] {
                    var patch = unpackVMEM(packed); patch[144] = 24
                    dx7ref_freq_init(44100.0)
                    var refVoice = dx7ref_voice_t()
                    patch.withUnsafeBufferPointer { ptr in
                        dx7ref_voice_init(&refVoice, ptr.baseAddress!, Int32(note), Int32(vel), 44100.0)
                    }
                    var prod = setupProdFreqVoice(patch: patch, midinote: note, velocity7: vel, sampleRate: 44100)
                    let rb = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
                    let mb = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
                    let b1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
                    let b2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
                    defer { rb.deallocate(); mb.deallocate(); b1.deallocate(); b2.deallocate() }
                    var firstBlockMaxDiff: Int64 = 0
                    var refPeak: Int32 = 0, prodPeak: Int32 = 0
                    var sumSqRef: Double = 0, sumSqProd: Double = 0, n = 0
                    for block in 0..<200 {
                        rb.initialize(repeating: 0, count: kBlockSize)
                        mb.initialize(repeating: 0, count: kBlockSize)
                        dx7ref_voice_render(&refVoice, rb)
                        prod.updateGains()
                        prod.renderBlock(output: mb, bus1: b1, bus2: b2, blockSize: kBlockSize)
                        for s in 0..<kBlockSize {
                            if block == 0 { firstBlockMaxDiff = max(firstBlockMaxDiff, Int64(abs(rb[s] &- mb[s]))) }
                            refPeak = max(refPeak, abs(rb[s])); prodPeak = max(prodPeak, abs(mb[s]))
                            sumSqRef += Double(rb[s]) * Double(rb[s]); sumSqProd += Double(mb[s]) * Double(mb[s]); n += 1
                        }
                    }
                    let rmsRef = (sumSqRef / Double(n)).squareRoot() / 268435456.0
                    let rmsProd = (sumSqProd / Double(n)).squareRoot() / 268435456.0
                    let fbdNorm = Double(firstBlockMaxDiff) / 268435456.0
                    print(String(format: "🎚 %@ n%d v%d: firstBlkMaxDiff=%.5f refPeak=%.3f prodPeak=%.3f rmsRef=%.4f rmsProd=%.4f rmsΔ=%.1f%%",
                                 label, note, vel, fbdNorm, Float(refPeak)/268435456.0, Float(prodPeak)/268435456.0,
                                 rmsRef, rmsProd, abs(rmsRef - rmsProd) / max(rmsRef, 1e-9) * 100))
                }
            }
        }
    }

    // F. Device sample rate — the app runs at the hardware output SR (iOS prefers
    // 48000), but every proof above was at 44100. Verify bit-exactness at 48000 so
    // an SR-specific divergence cannot hide on the actual device.
    @Test("48 kHz (device SR): BASS1/PIANO1 stay bit-exact to DEXED")
    func deviceSampleRate48k() {
        let voices: [(String, [UInt8])] = [("BASS1", rom1aBass1Packed), ("PIANO1", rom1aPiano1Packed)]
        for (label, packed) in voices {
            for note: UInt8 in [36, 48, 60, 72] {
                for vel in [100, 127] {
                    let r = renderMismatches(packed, midinote: note, velocity7: vel, blocks: 120, sampleRate: 48000)
                    #expect(r.mismatches == 0,
                        "\(label)@48k note=\(note) vel=\(vel): \(r.mismatches) mismatches, first blk \(r.firstBlock) smp \(r.firstSample)")
                }
            }
        }
        dx7ref_freq_init(44100.0)  // restore the shared global LUT for any concurrent 44.1 kHz suite
    }

    // G. Full-engine render to WAV for DIRECT comparison against a real Dexed render
    // (removes the dx7ref proxy entirely). Renders BASS1 C4 through the production
    // SynthEngine path (parse → loadDX7Preset → noteOn(60) → 48 kHz) exactly as the
    // app does, and writes a 16-bit mono WAV to /tmp for spectral comparison.
    private func writeWAV(_ path: String, _ samples: [Float], sampleRate: Int) {
        func u32(_ v: UInt32) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)] }
        func u16(_ v: UInt16) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
        var d = Data()
        let n = samples.count
        d.append(contentsOf: Array("RIFF".utf8)); d.append(contentsOf: u32(UInt32(36 + n * 2)))
        d.append(contentsOf: Array("WAVE".utf8)); d.append(contentsOf: Array("fmt ".utf8))
        d.append(contentsOf: u32(16)); d.append(contentsOf: u16(1)); d.append(contentsOf: u16(1))
        d.append(contentsOf: u32(UInt32(sampleRate))); d.append(contentsOf: u32(UInt32(sampleRate * 2)))
        d.append(contentsOf: u16(2)); d.append(contentsOf: u16(16))
        d.append(contentsOf: Array("data".utf8)); d.append(contentsOf: u32(UInt32(n * 2)))
        for s in samples {
            let v = Int16(max(-32768, min(32767, Int((s * 32767).rounded()))))
            d.append(contentsOf: u16(UInt16(bitPattern: v)))
        }
        try? d.write(to: URL(fileURLWithPath: path))
    }

    private func renderEngineBASS1(note: UInt8, vel: Int) -> [Float] {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        engine.setMasterVolume(1.0)
        let bank = DX7SysExParser.parse(data: bankFromVoice(rom1aBass1Packed), bankName: "ROM1A")!
        engine.loadDX7Preset(bank.presets[0])
        let blk = 512
        var warmL = [Float](repeating: 0, count: blk), warmR = [Float](repeating: 0, count: blk)
        warmL.withUnsafeMutableBufferPointer { lp in warmR.withUnsafeMutableBufferPointer { rp in
            engine.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: blk)
        }}
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(vel) << 9))
        let total = 96000
        var out = [Float](repeating: 0, count: total)
        var rr = [Float](repeating: 0, count: total)
        out.withUnsafeMutableBufferPointer { op in rr.withUnsafeMutableBufferPointer { rp in
            var off = 0
            while off < total {
                let c = min(blk, total - off)
                engine.render(into: op.baseAddress! + off, bufferR: rp.baseAddress! + off, frameCount: c)
                off += c
            }
        }}
        return out
    }

    @Test("Render BASS1 to WAV: note 60 (as-app, octave low) and note 72 (pitch-matched to Dexed)")
    func renderBASS1ToWAV() {
        for vel in [100, 127] {
            let n60 = renderEngineBASS1(note: 60, vel: vel)   // app behavior: transpose-12 → C2
            writeWAV("/tmp/m2dx_bass1_v\(vel).wav", n60, sampleRate: 48000)
            let n72 = renderEngineBASS1(note: 72, vel: vel)   // +12 to cancel transpose → C3, matches Dexed pitch
            writeWAV("/tmp/m2dx_bass1_n72_v\(vel).wav", n72, sampleRate: 48000)
            let p60 = n60.map { abs($0) }.max() ?? 0, p72 = n72.map { abs($0) }.max() ?? 0
            print("🔊 BASS1 vel\(vel): note60 peak=\(String(format: "%.4f", p60)) (/tmp/m2dx_bass1_v\(vel).wav) | note72 peak=\(String(format: "%.4f", p72)) (/tmp/m2dx_bass1_n72_v\(vel).wav)")
        }
    }

    // H. Render the dx7ref REFERENCE itself to WAV, to settle whether dx7ref is
    // faithful to REAL Dexed. dx7ref ignores transpose (plays note 60 = C4 → carrier
    // 0.5x → C3, same pitch as the user's Dexed render). If dx7ref's harmonic profile
    // matches the real Dexed WAV, the reference is faithful and any M2DX divergence is
    // in the production loadDX7Preset path; if dx7ref is also richer than Dexed, the
    // reference (and the whole "bit-exact to DEXED" claim) is the wrong yardstick.
    @Test("Render dx7ref BASS1 C4 to WAV (reference yardstick)")
    func renderDx7refBASS1ToWAV() {
        for vel in [100, 127] {
            var patch = unpackVMEM(rom1aBass1Packed); patch[144] = 24  // transpose-neutral → note 60 = C4
            dx7ref_freq_init(48000.0)
            var rv = dx7ref_voice_t()
            patch.withUnsafeBufferPointer { p in
                dx7ref_voice_init(&rv, p.baseAddress!, 60, Int32(vel), 48000.0)
            }
            let total = 96000
            var out = [Float](repeating: 0, count: total)
            let buf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
            defer { buf.deallocate() }
            var off = 0
            while off < total {
                buf.initialize(repeating: 0, count: kBlockSize)
                dx7ref_voice_render(&rv, buf)
                let c = min(kBlockSize, total - off)
                for s in 0..<c { out[off + s] = Float(buf[s]) / 268435456.0 }
                off += kBlockSize
            }
            dx7ref_freq_init(44100.0)
            writeWAV("/tmp/dxref_bass1_v\(vel).wav", out, sampleRate: 48000)
            let peak = out.map { abs($0) }.max() ?? 0
            print("📐 dx7ref BASS1 C4 vel\(vel): peak=\(String(format: "%.4f", peak)) → /tmp/dxref_bass1_v\(vel).wav")
        }
    }

    // I. Patch-independent EG decay-time measurement. The rate→inc mapping is global,
    // so if a decay rate is too slow for BASS1's OP4 (R3=7) it is too slow for EVERY
    // patch using that rate. Measure the stage-2 (R3) decay time from L=99 → L3=0 for
    // a sweep of rate values. Real Dexed decayed BASS1's R3=7 modulator audibly within
    // ~0.7 s; if M2DX takes tens of seconds the EG mapping is systematically too slow.
    @Test("EG decay time per rate (L99→L3=0) — slow-rate plausibility")
    func egDecayTimePerRate() {
        let sr: Float = 48000
        let blockSec = Double(kBlockSize) / Double(sr)
        let maxBlocks = Int(180.0 / blockSec)
        print("EG stage-2 (R3) decay L=99→L3=0, block=\(kBlockSize) @48k:")
        for rate in [99, 80, 60, 50, 40, 30, 20, 15, 10, 7, 5, 3, 1] {
            var env = DX7Envelope()
            env.setSampleRate(sr)
            env.setOutputLevel(99)
            env.setLevels(99, 99, 0, 0)     // L1=L2=99 (stages 0,1 instant), L3=0 → stage 2 decays 99→0
            env.setRates(99, 99, rate, 50)  // R3 = rate under test
            env.noteOn()
            var blocks = 0
            while env.isActive && env.ix < 3 && blocks < maxBlocks {
                _ = env.getsample()
                blocks += 1
            }
            let t = Double(blocks) * blockSec
            let flag = blocks >= maxBlocks ? "  [>180s TIMEOUT]" : ""
            print(String(format: "  R3=%2d → %7.2f s  (%d blocks)%@", rate, t, blocks, flag))
        }
    }

    // C. Output level measurement: render the real voice and report the peak
    // per-voice sample, normalized by the engine's output scale (/2^28). The app
    // multiplies this by masterVolume(0.7) × pan(≤1) × slotGain(1). If the
    // NORMALIZED peak exceeds ~1.43 (= 1/0.7) the voice clips at the DAC even at
    // default master volume with the Maximizer OFF.
    private func measurePeak(_ packed: [UInt8], _ label: String, midinote: UInt8, velocity7: Int) {
        var patch = unpackVMEM(packed); patch[144] = 24
        dx7ref_freq_init(44100.0)  // setupM2DXVoice computes op.freq via dx7ref's freq LUT
        var voice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: 44100)
        let buf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { buf.deallocate(); bus1.deallocate(); bus2.deallocate() }
        var peak: Int32 = 0
        for _ in 0..<200 {
            buf.initialize(repeating: 0, count: kBlockSize)
            voice.updateGains()
            voice.renderBlock(output: buf, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
            for s in 0..<kBlockSize { peak = max(peak, abs(buf[s])) }
        }
        let twoP28: Float = 268435456.0
        let normalized = Float(peak) / twoP28          // masterVolume = 1.0
        let atDefault = normalized * 0.7               // default masterVolume
        print("📊 \(label) peakInt32=\(peak) normalized(/2^28)=\(normalized) ×master0.7=\(atDefault) clips@0.7=\(atDefault > 1.0)")
        // Report-only — record an Issue if it clips so it is visible in the run summary.
        if atDefault > 1.0 {
            Issue.record("\(label) CLIPS at default master volume: peak output = \(atDefault) (>1.0)")
        }
    }

    @Test("BASS 1 / PIANO 1 peak output level (clipping check)")
    func peakLevels() {
        measurePeak(rom1aBass1Packed, "BASS1", midinote: 60, velocity7: 100)
        measurePeak(rom1aBass1Packed, "BASS1-vel127", midinote: 36, velocity7: 127)
        measurePeak(rom1aPiano1Packed, "PIANO1", midinote: 60, velocity7: 100)
        measurePeak(rom1aPiano1Packed, "PIANO1-vel127", midinote: 72, velocity7: 127)
    }
}
