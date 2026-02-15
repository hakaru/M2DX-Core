// WaveformTests.swift
// M2DX-Core — Tests for DX7Voice renderBlock output correctness

import Testing
@testable import M2DXCore

@Suite("DX7 Voice Render Tests")
struct DX7VoiceRenderTests {

    /// Create a minimal voice with given algorithm, OL=99 on all ops, rate=99 attack
    func makeVoice(algorithm: Int, sampleRate: Float = 44100) -> DX7Voice {
        var voice = DX7Voice()
        voice.algorithm = algorithm
        voice.feedbackShiftValue = 16  // no feedback for pure tests
        voice.setSampleRate(sampleRate)
        for i in 0..<6 {
            voice.withOp(i) { op in
                op.setOutputLevel(99)
                op.env.setRates(99, 99, 99, 99)
                op.env.setLevels(99, 99, 99, 0)
                op.ratio = 1.0
                op.detune = 1.0
            }
        }
        return voice
    }

    @Test("Algorithm 32: all carriers produce non-zero output")
    func alg32AllCarriers() {
        var voice = makeVoice(algorithm: 31)
        voice.noteOn(60, velocity16: 0x7FFF)

        let output = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        // Warm up the envelope
        for _ in 0..<10 {
            voice.updateGains()
            output.initialize(repeating: 0, count: kBlockSize)
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
        }

        // Check that output is non-zero
        var hasNonZero = false
        for i in 0..<kBlockSize {
            if output[i] != 0 { hasNonZero = true; break }
        }
        #expect(hasNonZero, "Algorithm 32 (all carriers) should produce non-zero output")
    }

    @Test("Algorithm 1: serial FM produces non-zero output")
    func alg1SerialFM() {
        var voice = makeVoice(algorithm: 0)
        voice.noteOn(69, velocity16: 0x7FFF)  // A4 = 440 Hz

        let output = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        for _ in 0..<10 {
            voice.updateGains()
            output.initialize(repeating: 0, count: kBlockSize)
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
        }

        var maxAbs: Int32 = 0
        for i in 0..<kBlockSize {
            maxAbs = max(maxAbs, abs(output[i]))
        }
        #expect(maxAbs > 0, "Algorithm 1 should produce audible output, maxAbs=\(maxAbs)")
    }

    @Test("Silent voice produces zero output")
    func silentVoice() {
        var voice = DX7Voice()
        voice.algorithm = 0
        voice.setSampleRate(44100)
        // Don't call noteOn → voice.active = false

        let output = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        output.initialize(repeating: 42, count: kBlockSize)  // Fill with non-zero
        voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)

        // Inactive voice should not touch output
        for i in 0..<kBlockSize {
            #expect(output[i] == 42, "Inactive voice should not modify output buffer")
        }
    }

    @Test("NoteOff eventually silences voice")
    func noteOffSilences() {
        var voice = makeVoice(algorithm: 0)
        voice.noteOn(60, velocity16: 0x7FFF)

        let output = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        // Run a few blocks while active
        for _ in 0..<10 {
            voice.updateGains()
            output.initialize(repeating: 0, count: kBlockSize)
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
        }

        // Note off with levels[3]=0
        voice.noteOff()

        // Run many blocks until inactive
        var becameInactive = false
        for _ in 0..<5000 {
            voice.updateGains()
            voice.checkActive()
            output.initialize(repeating: 0, count: kBlockSize)
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
            if !voice.active { becameInactive = true; break }
        }
        #expect(becameInactive, "Voice should eventually become inactive after noteOff")
    }

    @Test("Feedback produces different output than no feedback")
    func feedbackEffect() {
        var voiceNoFb = makeVoice(algorithm: 0)
        voiceNoFb.feedbackShiftValue = 16  // disabled
        voiceNoFb.noteOn(60, velocity16: 0x7FFF)

        var voiceFb = makeVoice(algorithm: 0)
        voiceFb.feedbackShiftValue = 2  // strong feedback
        voiceFb.noteOn(60, velocity16: 0x7FFF)

        let outNoFb = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let outFb = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { outNoFb.deallocate(); outFb.deallocate(); bus1.deallocate(); bus2.deallocate() }

        for _ in 0..<10 {
            voiceNoFb.updateGains()
            voiceFb.updateGains()
            outNoFb.initialize(repeating: 0, count: kBlockSize)
            outFb.initialize(repeating: 0, count: kBlockSize)
            voiceNoFb.renderBlock(output: outNoFb, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
            voiceFb.renderBlock(output: outFb, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
        }

        var differ = false
        for i in 0..<kBlockSize {
            if outNoFb[i] != outFb[i] { differ = true; break }
        }
        #expect(differ, "Feedback should produce different waveform")
    }

    @Test("Algorithm 5: 3-carrier output non-zero")
    func alg5ThreeCarriers() {
        var voice = makeVoice(algorithm: 4)
        voice.noteOn(60, velocity16: 0x7FFF)

        let output = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus1 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        let bus2 = UnsafeMutablePointer<Int32>.allocate(capacity: kBlockSize)
        defer { output.deallocate(); bus1.deallocate(); bus2.deallocate() }

        for _ in 0..<10 {
            voice.updateGains()
            output.initialize(repeating: 0, count: kBlockSize)
            voice.renderBlock(output: output, bus1: bus1, bus2: bus2, blockSize: kBlockSize)
        }

        var maxAbs: Int32 = 0
        for i in 0..<kBlockSize { maxAbs = max(maxAbs, abs(output[i])) }
        #expect(maxAbs > 0, "Algorithm 5 should produce non-zero output")
    }

    @Test("Pitch bend changes frequency")
    func pitchBendChangesFreq() {
        var voice = makeVoice(algorithm: 31)
        voice.noteOn(69, velocity16: 0x7FFF)

        // Get frequency before pitch bend
        var freqBefore: Int32 = 0
        voice.withOp(0) { op in freqBefore = op.freq }

        voice.applyPitchBend(2.0)  // 1 octave up

        var freqAfter: Int32 = 0
        voice.withOp(0) { op in freqAfter = op.freq }

        #expect(freqAfter > freqBefore, "Pitch bend up should increase frequency")
        // Should roughly double
        let ratio = Float(freqAfter) / Float(freqBefore)
        #expect(abs(ratio - 2.0) < 0.1, "Pitch bend 2.0 should double freq, got ratio \(ratio)")
    }
}
