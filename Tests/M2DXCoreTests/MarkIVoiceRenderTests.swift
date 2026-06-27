// MarkIVoiceRenderTests.swift
import Testing
@testable import M2DXCore

/// Build a 1-carrier Algorithm-1 DX7Voice for the Mark I render smoke test.
/// Construction mirrors `setupM2DXVoice(...)` in VoiceComparisonTests.swift:
/// a single full-level carrier at OP index 5, all others silent, alg 0,
/// note 60, vel 100, 44100 Hz.
func makeCarrierVoiceForMarkITest() -> DX7Voice {
    let carrier = fullOp(ol: 99, coarse: 1, fine: 0, detune: 7)
    let patch = buildPatch156(
        ops: [silentOp, silentOp, silentOp, silentOp, silentOp, carrier],
        algorithm: 0, feedback: 0
    )
    return setupM2DXVoice(patch: patch, midinote: 60, velocity7: 100, sampleRate: 44100)
}

@Suite("Mark I voice render")
struct MarkIVoiceRenderTests {
    @Test("engineMode .markI renders non-silent output for a carrier voice")
    func renders() {
        var v = makeCarrierVoiceForMarkITest()
        v.engineMode = .markI
        let out = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let b1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let b2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { out.deallocate(); b1.deallocate(); b2.deallocate() }
        out.initialize(repeating: 0, count: kBlockSize)
        v.updateGains()
        v.renderBlock(output: out, bus1: b1, bus2: b2, blockSize: kBlockSize)
        #expect((0..<kBlockSize).contains { out[$0] != 0 })
    }
}
