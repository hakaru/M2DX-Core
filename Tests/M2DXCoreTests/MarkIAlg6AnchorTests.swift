// MarkIAlg6AnchorTests.swift
// M2DX-Core — regression for the Alg 6 Mark I feedback-op ramp anchor (#85).
//
// Independent oracle: in the Mark I fused feedback path the feedback op
// (ops.0 / OP6 position) ramps its attenuation atten1→atten2 across the block,
// so its inter-block ramp anchor (markIGainOut) MUST carry ITS OWN attenuation
// — not the follower's (ops.1 / OP5). This expectation is derived from the
// per-op ramp contract in DX7Voice's render switch (each op stores its own
// atten2 as markIGainOut), NOT from the Swift/C dx7refmki twin — so it catches
// the bug both reference twins shared (clobbering OP6's anchor with OP5's atten).

import Testing
@testable import M2DXCore

@Suite("Mark I Alg 6 feedback-op ramp anchor (#85)")
struct MarkIAlg6AnchorTests {
    @Test("Alg 6 fb-op keeps its own attenuation as the ramp anchor (not the follower's)")
    func fbOpAnchorIsOwnAttenuation() {
        // ops.0 = feedback op (OP6 position), ops.1 = follower (OP5). Distinct
        // output levels so their Mark I attenuations differ and the bug shows.
        let patch = buildPatch156(
            ops: [fullOp(ol: 99), fullOp(ol: 30), silentOp, silentOp, silentOp, silentOp],
            algorithm: 5, feedback: 7
        )
        var v = setupM2DXVoice(patch: patch, midinote: 60, velocity7: 100)
        v.engineMode = .markI

        let out = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let b1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let b2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { out.deallocate(); b1.deallocate(); b2.deallocate() }
        out.initialize(repeating: 0, count: kBlockSize)
        b1.initialize(repeating: 0, count: kBlockSize)
        b2.initialize(repeating: 0, count: kBlockSize)

        // Settle to the flat sustain so levelIn is stable block-to-block; then the
        // anchor written this block equals markIAtten(levelIn) read after it.
        for _ in 0..<8 {
            v.updateGains()
            v.renderBlock(output: out, bus1: b1, bus2: b2, blockSize: kBlockSize)
        }

        let ownAtten = markIAtten(v.ops.0.levelIn)       // OP6's own attenuation — the correct anchor
        let followerAtten = markIAtten(v.ops.1.levelIn)  // OP5's attenuation — what the bug wrote

        // Preconditions: fused feedback path active, and the two ops truly differ
        // (else the assertion would be vacuous).
        #expect(v.feedbackShiftValue < 16)
        #expect(ownAtten != followerAtten)

        // Contract: the feedback op's ramp anchor is ITS OWN attenuation.
        // Pre-fix (DX7Voice.swift:544): markIGainOut == followerAtten → FAILS.
        // Post-fix (line removed): markIGainOut == ownAtten → PASSES.
        #expect(v.ops.0.markIGainOut == ownAtten)
    }
}
