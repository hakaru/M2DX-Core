// ModWheelTests.swift
// M2DX-Core — mod wheel pitch assignment drives LFO vibrato depth, not static pitch offset

import Testing
import Darwin
@testable import M2DXCore

@Suite("Mod Wheel Pitch Modulation")
struct ModWheelTests {

    // Helper: render N blocks of `blockSize` frames each, collecting per-block OP freqs.
    // opIndex 5 = OP1 (the carrier in algorithm 0 / Alg1 DX7 numbering).
    private func renderBlocks(
        engine: SynthEngine,
        blocks: Int,
        blockSize: Int,
        opIndex: Int
    ) -> [Float] {
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        defer { bufL.deallocate(); bufR.deallocate() }

        var freqs: [Float] = []
        freqs.reserveCapacity(blocks)
        for _ in 0..<blocks {
            engine.render(into: bufL, bufferR: bufR, frameCount: blockSize)
            let f = engine.activeVoiceOperatorFreqs(opIndex)
            if let first = f.first { freqs.append(first) }
        }
        return freqs
    }

    @Test("Mod wheel adds vibrato (oscillating pitch), not a static upward bend")
    func modWheelAddsVibrato() {
        // Build a patch: one carrier (OP1 = operators[0] → internal opIdx 5), all others silent.
        // lfoPMD = 0 so that ONLY the mod wheel contributes to pitch modulation.
        // lfoPMS = 7 (maximum PMS depth scale), lfoSpeed = 50 (fast LFO so 1s covers many cycles).
        // lfoWaveform = 0 (triangle, symmetric −1…+1 so we get both positive and negative swings).
        // lfoDelay = 0 so modulation starts immediately.
        let carrierOp = DX7OperatorPreset(
            outputLevel: 99, frequencyCoarse: 1, frequencyFine: 0,
            detune: 7, feedback: 0,
            egRate1: 99, egRate2: 99, egRate3: 99, egRate4: 99,
            egLevel1: 99, egLevel2: 99, egLevel3: 99, egLevel4: 0,
            velocitySensitivity: 0, ampModSensitivity: 0,
            keyboardRateScaling: 0
        )
        let silentOp = DX7OperatorPreset(outputLevel: 0)

        let preset = DX7Preset(
            name: "ModWheelTest",
            algorithm: 0,           // Alg1: OP1 is the only output carrier
            feedback: 0,
            operators: [
                carrierOp,          // operators[0] = OP1 (carrier, opIdx 5)
                silentOp,           // operators[1] = OP2 (opIdx 4)
                silentOp,           // operators[2] = OP3 (opIdx 3)
                silentOp,           // operators[3] = OP4 (opIdx 2)
                silentOp,           // operators[4] = OP5 (opIdx 1)
                silentOp,           // operators[5] = OP6 (opIdx 0)
            ],
            category: .other,
            lfoSpeed: 50,           // fast — many cycles per second
            lfoDelay: 0,
            lfoPMD: 0,              // NO preset-level pitch mod depth — only wheel drives it
            lfoAMD: 0,
            lfoSync: 0,             // free-running LFO (don't reset on note-on)
            lfoWaveform: 0,         // triangle: −1…+1
            lfoPMS: 7,              // max PMS so we get large vibrato depth
            pitchEGR1: 99, pitchEGR2: 99, pitchEGR3: 99, pitchEGR4: 99,
            pitchEGL1: 50, pitchEGL2: 50, pitchEGL3: 50, pitchEGL4: 50
        )

        let engine = SynthEngine()
        engine.setSampleRate(48000)

        // Load preset (also resets wheelPitch to default 50 and modWheelDepth to 0)
        engine.loadDX7Preset(preset)

        // Set max wheel pitch sensitivity AFTER load so it isn't overwritten by load's reset
        engine.setWheelPitch(99)

        // Warm-up: render a few blocks with no note to let the snapshot propagate
        let warmupBlocks = 10
        let blockSize = 256
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: blockSize)
        defer { bufL.deallocate(); bufR.deallocate() }
        for _ in 0..<warmupBlocks {
            engine.render(into: bufL, bufferR: bufR, frameCount: blockSize)
        }

        // ── Step 1: establish base frequency with mod wheel at 0 ──────────────────
        // Ensure modWheelDepth is at zero (default after engine init)
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 1, data2: 0))
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))

        // Render a block to let the note settle
        engine.render(into: bufL, bufferR: bufR, frameCount: blockSize)

        #expect(engine.activeVoiceCount == 1, "expected exactly one active voice")

        let baseFreqs = engine.activeVoiceOperatorFreqs(5)  // opIdx 5 = OP1
        #expect(!baseFreqs.isEmpty, "no active OP1 frequency found")
        let baseFreq = baseFreqs.first!

        // ── Step 2: push max mod wheel, render ~1 second in 256-frame blocks ──────
        // LFO speed 50 → ~14 Hz (0.06 * exp(50 * 0.0693) ≈ 14 Hz), so 1s ≈ 14 full cycles.
        // Triangle wave oscillates −1…+1. After the fix, lfoCurrentValue × controller depth
        // drives pitch, giving both upward and downward frequency swings.
        // Before the fix, the constant controllerPitch offset only pushes frequency UP.
        engine.sendMIDI(MIDIEvent(kind: .controlChange, data1: 1, data2: UInt32.max))

        let renderBlocks = 187  // ≈ 187 × 256 / 48000 ≈ 1.0 s
        var freqs: [Float] = []
        freqs.reserveCapacity(renderBlocks)
        for _ in 0..<renderBlocks {
            engine.render(into: bufL, bufferR: bufR, frameCount: blockSize)
            let f = engine.activeVoiceOperatorFreqs(5)
            if let first = f.first { freqs.append(first) }
        }

        #expect(!freqs.isEmpty, "no frequencies collected during mod-wheel render")

        let minFreq = freqs.min()!
        let maxFreq = freqs.max()!

        // RED test (before fix): controllerPitch is a constant positive offset, so ALL
        // sampled frequencies will be ≥ baseFreq. The minimum will never dip below base.
        //
        // GREEN (after fix): the LFO triangle is multiplied by (controllerPitchMod × pmsDepth),
        // giving a bipolar modulation. During the negative half of the triangle wave,
        // pitch dips BELOW base by at least 0.1% (well within the ±semitone range at PMS=7).
        #expect(
            minFreq < baseFreq * 0.999,
            "mod wheel must produce vibrato (pitch dips below base); got min=\(minFreq) Hz vs base=\(baseFreq) Hz — RED means wheel only bends up (static offset bug)"
        )

        // Also confirm the wheel does drive pitch upward (basic sanity)
        #expect(
            maxFreq > baseFreq * 1.001,
            "mod wheel should also raise pitch above base; got max=\(maxFreq) Hz vs base=\(baseFreq) Hz"
        )
    }
}
