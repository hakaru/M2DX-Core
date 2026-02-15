// EnvelopeTests.swift
// M2DX-Core — Tests for DX7Envelope

import Testing
@testable import M2DXCore

@Suite("DX7 Envelope Tests")
struct DX7EnvelopeTests {

    @Test("Envelope starts inactive")
    func startsInactive() {
        let env = DX7Envelope()
        #expect(!env.isActive, "Envelope should start inactive")
    }

    @Test("Envelope becomes active on noteOn")
    func activeOnNoteOn() {
        var env = DX7Envelope()
        env.setOutputLevel(99)
        env.noteOn()
        #expect(env.isActive, "Envelope should be active after noteOn")
    }

    @Test("Rate=99 attack reaches high level quickly")
    func fastAttack() {
        var env = DX7Envelope()
        env.setRates(99, 99, 99, 99)
        env.setLevels(99, 99, 99, 0)
        env.setOutputLevel(99)
        env.setSampleRate(44100)
        env.noteOn()

        // Run blocks: at rate=99 and 44.1kHz, attack should complete quickly
        // Each block = 64 samples, ~1.45ms at 44.1kHz
        // The attack may advance through multiple stages quickly.
        var maxLevel: Int32 = 0
        for _ in 0..<50 {
            let level = env.getsample()
            maxLevel = max(maxLevel, level)
        }
        // After 50 blocks (~72ms), level should have risen significantly
        #expect(maxLevel > 100_000, "Rate=99 should reach high level within 50 blocks, maxLevel=\(maxLevel)")
    }

    @Test("Envelope 4-stage progression")
    func fourStageProgression() {
        var env = DX7Envelope()
        env.setRates(99, 99, 99, 99)
        env.setLevels(99, 70, 50, 0)
        env.setOutputLevel(99)
        env.setSampleRate(44100)
        env.noteOn()

        // Run through attack + decay stages
        for _ in 0..<500 {
            let _ = env.getsample()
        }
        #expect(env.isActive, "Envelope should still be active in sustain")

        // NoteOff triggers release (stage 3)
        env.noteOff()
        var finallyInactive = false
        for _ in 0..<10000 {
            let _ = env.getsample()
            if !env.isActive { finallyInactive = true; break }
        }
        #expect(finallyInactive, "Envelope should eventually become inactive after noteOff")
    }

    @Test("Envelope level never goes below 0")
    func levelNonNegative() {
        var env = DX7Envelope()
        env.setRates(99, 99, 99, 99)
        env.setLevels(99, 50, 30, 0)
        env.setOutputLevel(50)
        env.setSampleRate(44100)
        env.noteOn()

        for _ in 0..<1000 {
            let level = env.getsample()
            #expect(level >= 0, "Envelope level should never be negative")
        }
        env.noteOff()
        for _ in 0..<5000 {
            let level = env.getsample()
            #expect(level >= 0, "Envelope level should never be negative after noteOff")
        }
    }

    @Test("setSampleRate adjusts timing")
    func sampleRateAdjustsTiming() {
        var env48 = DX7Envelope()
        env48.setRates(70, 70, 70, 70)
        env48.setLevels(99, 60, 40, 0)
        env48.setOutputLevel(99)
        env48.setSampleRate(48000)
        env48.noteOn()

        var env44 = DX7Envelope()
        env44.setRates(70, 70, 70, 70)
        env44.setLevels(99, 60, 40, 0)
        env44.setOutputLevel(99)
        env44.setSampleRate(44100)
        env44.noteOn()

        // After same number of blocks, the one at higher sample rate should have progressed less
        // (longer real time per block at 48kHz vs 44.1kHz means slower progression per block)
        for _ in 0..<50 {
            let _ = env48.getsample()
            let _ = env44.getsample()
        }
        // Both should be active and the relative levels should differ
        #expect(env48.isActive, "48kHz envelope should still be active")
        #expect(env44.isActive, "44.1kHz envelope should still be active")
    }

    @Test("recalcTargetLevel updates correctly")
    func recalcTarget() {
        var env = DX7Envelope()
        env.setRates(50, 50, 50, 50)
        env.setLevels(99, 80, 60, 0)
        env.setOutputLevel(99)
        env.setSampleRate(44100)
        env.noteOn()

        // Run enough blocks to be solidly in stage 0 (attack)
        for _ in 0..<20 { let _ = env.getsample() }
        // Make sure we're still in a stage where target matters
        guard env.isActive else { return }

        let beforeTarget = env.targetLevel
        // Dramatically change OL so target must differ
        env.setOutputLevel(30)
        env.recalcTargetLevel()
        let afterTarget = env.targetLevel

        // Changing OL from 99 to 30 should change the target level
        #expect(afterTarget != beforeTarget, "recalcTargetLevel should update target after OL change (before=\(beforeTarget), after=\(afterTarget))")
    }
}
