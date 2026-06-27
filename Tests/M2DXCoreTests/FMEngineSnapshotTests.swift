// FMEngineSnapshotTests.swift
import Testing
@testable import M2DXCore

@Suite("FMEngine snapshot")
struct FMEngineSnapshotTests {
    @Test("setFMEngine writes the snapshot field and bumps version")
    func setter() {
        let e = SynthEngine()
        e.setFMEngine(.markI)
        #expect(e.debugShadowFMEngine == FMEngine.markI.rawValue)
    }
    @Test("default engine is modern") func defaultModern() {
        #expect(SynthEngine().debugShadowFMEngine == FMEngine.modern.rawValue)
    }
}
