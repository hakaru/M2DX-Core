// DX7SysExBankPublicInitTests.swift
// M2DX-Core — Verify DX7SysExBank exposes a public memberwise initializer.
//
// Deliberately uses a plain `import M2DXCore` (NOT @testable) so this file
// compiles against the public API surface only, exactly as an external
// package consumer would. @testable applies per import statement, so this
// file exercises public visibility even though sibling test files use
// @testable import.

import Testing
import M2DXCore

@Suite("DX7SysExBank Public Init Tests")
struct DX7SysExBankPublicInitTests {

    @Test("Public memberwise init is accessible from a plain import")
    func publicMemberwiseInit() {
        let bank = DX7SysExBank(name: "X", presets: [])
        #expect(bank.name == "X")
        #expect(bank.presets.isEmpty)
    }

    @Test("Public init preserves provided presets")
    func publicInitPreservesPresets() {
        let preset = DX7FactoryPresets.initVoice
        let bank = DX7SysExBank(name: "User Bank", presets: [preset])
        #expect(bank.name == "User Bank")
        #expect(bank.presets.count == 1)
        #expect(bank.presets[0] == preset)
    }
}
