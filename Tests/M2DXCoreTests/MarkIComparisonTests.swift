// MarkIComparisonTests.swift
// M2DX-Core — Mark I (OPS-chip) voice parity tests: Swift `renderBlockMarkI`
// vs the clean-room C reference `dx7refmki`. Same harness shape as
// VoiceComparisonTests.compareVoices, but built on the Mark I twins:
//   * M2DX voice via setupM2DXVoice(...) + voice.engineMode = .markI
//   * reference via dx7refmki_voice_init / dx7refmki_voice_render
// Asserts 0 sample mismatches across algorithms / notes / velocities.

import Testing
import Darwin
@testable import M2DXCore
import DX7Ref

@Suite("Mark I Voice-Level Waveform Comparison")
struct MarkIComparisonTests {

    /// Compare the dx7refmki C reference and the M2DX Mark I voice output for a
    /// given patch, note, and velocity. Mirrors VoiceWaveformComparisonTests.compareVoices.
    /// Returns (mismatches, firstMismatchBlock, firstMismatchSample, refValue, m2dxValue).
    func compareMarkIVoices(
        patch: [UInt8], midinote: UInt8, velocity7: Int,
        blocks: Int = 200, sampleRate: Float = 44100
    ) -> (mismatches: Int, firstBlock: Int, firstSample: Int, refVal: Int32, m2dxVal: Int32) {
        // Setup dx7refmki reference voice.
        // setupM2DXVoice computes operator frequencies through dx7ref_freq_lookup,
        // so the dx7ref frequency LUT must be initialized too (dx7refmki keeps its
        // own LUT, built from identical math — see dx7refmki.c init_freq_lut).
        dx7ref_freq_init(Double(sampleRate))
        dx7refmki_freq_init(Double(sampleRate))
        var refVoice = dx7refmki_voice_t()
        patch.withUnsafeBufferPointer { ptr in
            dx7refmki_voice_init(&refVoice, ptr.baseAddress!, Int32(midinote), Int32(velocity7), Double(sampleRate))
        }

        // Setup M2DX voice and switch to the Mark I engine
        var m2dxVoice = setupM2DXVoice(patch: patch, midinote: midinote, velocity7: velocity7, sampleRate: sampleRate)
        m2dxVoice.engineMode = .markI

        let refBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let m2dxBuf = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { refBuf.deallocate(); m2dxBuf.deallocate(); bus1.deallocate(); bus2.deallocate() }

        var mismatches = 0
        var firstBlock = -1
        var firstSample = -1
        var firstRefVal: Int32 = 0
        var firstM2dxVal: Int32 = 0

        for block in 0..<blocks {
            // Zero both buffers
            refBuf.initialize(repeating: 0, count: kBlockSize)
            m2dxBuf.initialize(repeating: 0, count: kBlockSize)

            // Render dx7refmki reference
            dx7refmki_voice_render(&refVoice, refBuf)

            // Render M2DX (Mark I)
            m2dxVoice.updateGains()
            m2dxVoice.renderBlock(output: m2dxBuf, bus1: bus1, bus2: bus2, blockSize: kBlockSize)

            // Compare sample by sample
            for s in 0..<kBlockSize {
                if refBuf[s] != m2dxBuf[s] {
                    mismatches += 1
                    if firstBlock < 0 {
                        firstBlock = block
                        firstSample = s
                        firstRefVal = refBuf[s]
                        firstM2dxVal = m2dxBuf[s]
                    }
                }
            }
        }

        return (mismatches, firstBlock, firstSample, firstRefVal, firstM2dxVal)
    }

    // MARK: - Patch builders for the covered algorithms

    /// INIT-style voice: single carrier (Algorithm 1 / index 0), carrier at op
    /// index 5 (reaches `output`), all other ops silent.
    private func initPatch() -> [UInt8] {
        let carrier = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7)
        return buildPatch156(
            ops: [silentOp, silentOp, silentOp, silentOp, silentOp, carrier],
            algorithm: 0, feedback: 0
        )
    }

    /// Algorithm 5 (index 4): 3 carrier-modulator pairs, no feedback.
    private func alg5Patch() -> [UInt8] {
        let carrier = fullOp(ol: 90, coarse: 1)
        let modulator = fullOp(ol: 80, coarse: 2)
        return buildPatch156(
            ops: [carrier, modulator, carrier, modulator, carrier, modulator],
            algorithm: 4, feedback: 0
        )
    }

    /// Algorithm 32 (index 31): all six carriers, max feedback on OP6.
    private func alg32Patch() -> [UInt8] {
        let op = fullOp(ol: 80, coarse: 1)
        return buildPatch156(
            ops: [op, op, op, op, op, op],
            algorithm: 31, feedback: 7
        )
    }

    /// Algorithm 4 (index 3): fused 3-op feedback chain (OP6→OP5→OP4) + a
    /// separate OP3→OP2→OP1 carrier stack. Feedback enabled.
    private func alg4Patch() -> [UInt8] {
        let op = fullOp(ol: 85, coarse: 1)
        let carrier = fullOp(ol: 99, coarse: 1)
        // patch op order is [OP1, OP2, OP3, OP4, OP5, OP6]; feedback op is OP6.
        return buildPatch156(
            ops: [carrier, op, op, op, op, op],
            algorithm: 3, feedback: 6
        )
    }

    /// Algorithm 6 (index 5): fused 2-op feedback chain (OP6→OP5) + the rest.
    /// Feedback enabled.
    private func alg6Patch() -> [UInt8] {
        let op = fullOp(ol: 85, coarse: 1)
        let carrier = fullOp(ol: 99, coarse: 1)
        return buildPatch156(
            ops: [carrier, op, op, op, op, op],
            algorithm: 5, feedback: 6
        )
    }

    /// Run the full note × velocity sweep for one named patch and assert parity.
    private func sweep(name: String, patch: [UInt8]) {
        let notes: [UInt8] = [36, 60, 84]
        let velocities = [64, 100, 127]
        for note in notes {
            for vel in velocities {
                let result = compareMarkIVoices(patch: patch, midinote: note, velocity7: vel, blocks: 200)
                let msg = "\(name) note=\(note) vel=\(vel): \(result.mismatches) mismatches, "
                    + "first at block \(result.firstBlock) sample \(result.firstSample) "
                    + "ref=\(result.refVal) m2dx=\(result.m2dxVal)"
                #expect(result.mismatches == 0, "\(msg)")
            }
        }
    }

    // MARK: - Tests (one suite member per algorithm)

    @Test("INIT (single carrier) Mark I parity")
    func initParity() { sweep(name: "INIT", patch: initPatch()) }

    @Test("Algorithm 5 Mark I parity (3 carrier pairs)")
    func alg5Parity() { sweep(name: "Alg5", patch: alg5Patch()) }

    @Test("Algorithm 32 Mark I parity (all carriers, max feedback)")
    func alg32Parity() { sweep(name: "Alg32", patch: alg32Patch()) }

    @Test("Algorithm 4 Mark I parity (fused 3-op feedback)")
    func alg4Parity() { sweep(name: "Alg4", patch: alg4Patch()) }

    @Test("Algorithm 6 Mark I parity (fused 2-op feedback)")
    func alg6Parity() { sweep(name: "Alg6", patch: alg6Patch()) }
}
