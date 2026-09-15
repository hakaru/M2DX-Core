import Foundation
import Testing
@testable import M2DXCore

@Suite("Live operator level round trips (M2DX #112)", .serialized)
struct LiveOutputLevelRoundTripTests {
    private func render(_ engine: SynthEngine, blocks: Int = 1) -> [Float] {
        let count = blocks * 64
        var l = [Float](repeating: 0, count: count), r = l
        l.withUnsafeMutableBufferPointer { lp in
            r.withUnsafeMutableBufferPointer { rp in
                engine.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: count)
            }
        }
        return l
    }

    private func rms(_ values: [Float]) -> Double {
        sqrt(values.reduce(0) { $0 + Double($1) * Double($1) } / Double(values.count))
    }

    private func setup(_ mode: FMEngine, ol: Int, l3: Int, depth: Int, curve: Int,
                       first: UInt8, second: UInt8, l4: Int = 0) -> SynthEngine {
        let engine = SynthEngine()
        engine.setSampleRate(48000)
        engine.setFMEngine(mode)
        engine.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
        let ops = (0..<6).map { i in
            i == 5 ? DX7OperatorPreset(outputLevel: ol, egRate1: 99, egRate2: 99, egRate3: 99,
                egRate4: 40, egLevel1: 99, egLevel2: 99, egLevel3: l3, egLevel4: l4,
                klsBreakPoint: 39, klsRightDepth: depth, klsRightCurve: curve)
                : DX7OperatorPreset(outputLevel: 0)
        }
        engine.loadDX7Preset(DX7Preset(name: "Review #112", algorithm: 31, feedback: 0,
                                      operators: ops, category: .other))
        _ = render(engine)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: first, data2: UInt32(100) << 9))
        _ = render(engine, blocks: 200)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: second, data2: UInt32(100) << 9))
        _ = render(engine, blocks: 20)
        return engine
    }

    @Test("OL0 must silence a held legato carrier", arguments: [FMEngine.modern, .markI])
    func muteAfterLegato(_ mode: FMEngine) {
        let edited = setup(mode, ol: 99, l3: 99, depth: 99, curve: 0, first: 36, second: 127)
        let control = setup(mode, ol: 99, l3: 99, depth: 99, curve: 0, first: 36, second: 127)
        edited.setOperatorDX7OutputLevel(0, level: 0)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let changed = render(edited, blocks: 64), original = render(control, blocks: 64)
        let ratio = rms(changed) / rms(original)
        #expect(ratio < 0.001)
    }

    @Test("L3 round trip must restore held legato level", arguments: [FMEngine.modern, .markI])
    func l3RoundTrip(_ mode: FMEngine) {
        let edited = setup(mode, ol: 99, l3: 90, depth: 60, curve: 0, first: 96, second: 36)
        let control = setup(mode, ol: 99, l3: 90, depth: 60, curve: 0, first: 96, second: 36)
        edited.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: 0, l4: 0)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        edited.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: 90, l4: 0)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let changed = rms(render(edited, blocks: 64)), original = rms(render(control, blocks: 64))
        let ratio = changed / original
        #expect(abs(ratio - 1) < 0.005)
    }

    @Test("OL raise and restore must preserve held legato level", arguments: [FMEngine.modern, .markI])
    func olRoundTrip(_ mode: FMEngine) {
        let edited = setup(mode, ol: 30, l3: 99, depth: 99, curve: 3, first: 127, second: 36)
        let control = setup(mode, ol: 30, l3: 99, depth: 99, curve: 3, first: 127, second: 36)
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        edited.setOperatorDX7OutputLevel(0, level: 30)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let ratio = rms(render(edited, blocks: 64)) / rms(render(control, blocks: 64))
        #expect(abs(ratio - 1) < 0.005)
    }

    @Test("repeated L3 and OL round trips cannot accumulate gain", arguments: [FMEngine.modern, .markI])
    func repeatedEdits(_ mode: FMEngine) {
        let edited = setup(mode, ol: 99, l3: 90, depth: 60, curve: 0, first: 96, second: 36)
        let control = setup(mode, ol: 99, l3: 90, depth: 60, curve: 0, first: 96, second: 36)
        for _ in 0..<32 {
            edited.setOperatorDX7OutputLevel(0, level: 0)
            edited.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: 0, l4: 0)
            _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
            edited.setOperatorDX7OutputLevel(0, level: 99)
            edited.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: 90, l4: 0)
            _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
            #expect(render(edited, blocks: 4) == render(control, blocks: 4))
        }
    }

    @Test("a restored OL has the original release, including nonzero L4",
          arguments: [FMEngine.modern, .markI], [0, 60, 99])
    func restoredRelease(_ mode: FMEngine, l4: Int) {
        let edited = setup(mode, ol: 30, l3: 99, depth: 99, curve: 3, first: 127, second: 36, l4: l4)
        let control = setup(mode, ol: 30, l3: 99, depth: 99, curve: 3, first: 127, second: 36, l4: l4)
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        edited.setOperatorDX7OutputLevel(0, level: 30)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        for s in [edited, control] {
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 127, data2: 0))
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
        }
        for _ in 0..<64 {
            #expect(render(edited, blocks: 8) == render(control, blocks: 8))
            #expect(edited.debugActiveVoiceCount == control.debugActiveVoiceCount)
        }
    }

    @Test("a legato note released under attenuation resumes its original tail",
          arguments: [FMEngine.modern, .markI], [0, 60])
    func mutedLegatoRelease(_ mode: FMEngine, ol: Int) {
        let edited = setup(mode, ol: 99, l3: 99, depth: 99, curve: 0, first: 36, second: 127)
        let control = setup(mode, ol: 99, l3: 99, depth: 99, curve: 0, first: 36, second: 127)
        edited.setOperatorDX7OutputLevel(0, level: ol)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        for s in [edited, control] {
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 127, data2: 0))
        }
        _ = render(edited, blocks: 40); _ = render(control, blocks: 40)
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        for _ in 0..<64 {
            #expect(render(edited, blocks: 8) == render(control, blocks: 8))
            #expect(edited.debugActiveVoiceCount == control.debugActiveVoiceCount)
        }
    }

    @Test("a saturated held OL edit still reaches the current key's release level",
          arguments: [FMEngine.modern, .markI])
    func saturatedReleaseTarget(_ mode: FMEngine) {
        let edited = setup(mode, ol: 99, l3: 99, depth: 99, curve: 3, first: 127, second: 36, l4: 60)
        let control = setup(mode, ol: 91, l3: 99, depth: 99, curve: 3, first: 127, second: 36, l4: 60)
        // Both OL values are at the old key's ceiling, so the held waveforms agree.
        #expect(render(edited, blocks: 8) == render(control, blocks: 8))
        edited.setOperatorDX7OutputLevel(0, level: 91)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        for s in [edited, control] {
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 127, data2: 0))
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
        }
        let identical = render(edited, blocks: 4096) == render(control, blocks: 4096)
        #expect(identical)
    }

    @Test("a partially attenuated legato release reaches the edited L4", arguments: [FMEngine.modern, .markI])
    func attenuatedReleaseTarget(_ mode: FMEngine) {
        let s = setup(mode, ol: 99, l3: 99, depth: 99, curve: 3, first: 72, second: 36, l4: 60)
        s.setOperatorDX7OutputLevel(0, level: 30)
        _ = render(s, blocks: 2)
        s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 72, data2: 0))
        s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
        var finalLevel: Int32 = 0
        for _ in 0..<20000 {
            _ = render(s)
            let op = s.monoVoiceForTesting.ops.0
            finalLevel = op.levelIn
            if !op.env.isActive { break }
        }
        // EG L4=60 and OL30, no KLS at note36: ((88 >> 1) << 6) + (58 << 5) - 4256.
        #expect(finalLevel == 416 << 16)
    }

    @Test("a flat reference release must not cut a non-flat edited release", arguments: [FMEngine.modern, .markI])
    func flatReferenceRelease(_ mode: FMEngine) {
        let s = setup(mode, ol: 99, l3: 60, depth: 99, curve: 3, first: 72, second: 36, l4: 60)
        s.setOperatorDX7OutputLevel(0, level: 30)
        _ = render(s, blocks: 2)
        s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 72, data2: 0))
        s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
        _ = render(s)
        #expect(s.monoVoiceForTesting.ops.0.env.isActive)
        #expect(s.monoVoiceForTesting.ops.0.levelIn > 416 << 16)
    }

    @Test("L4 edits during a rising release cannot leave audible gain outside OL control",
          arguments: [FMEngine.modern, .markI], [false, true])
    func risingReleaseLevelAutomation(_ mode: FMEngine, heldFloor: Bool) {
        let first: UInt8 = heldFloor ? 127 : 36
        let second: UInt8 = heldFloor ? 36 : 72
        let l3 = heldFloor ? 99 : 0
        let edited = setup(mode, ol: 99, l3: l3, depth: 99, curve: heldFloor ? 0 : 3,
                           first: first, second: second, l4: 99)
        let control = setup(mode, ol: 99, l3: l3, depth: 99, curve: heldFloor ? 0 : 3,
                            first: first, second: second, l4: 99)
        for s in [edited, control] {
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: first, data2: 0))
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: second, data2: 0))
            _ = render(s, blocks: 100)
            s.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: l3, l4: 97)
            _ = render(s)
        }
        let before = edited.monoVoiceForTesting.ops.0.levelIn
        #expect(before > 1700 << 16)
        edited.setOperatorDX7OutputLevel(0, level: 0)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        #expect(edited.monoVoiceForTesting.ops.0.levelIn < before - (1000 << 16))
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        #expect(render(edited, blocks: 64) == render(control, blocks: 64))
    }

    @Test("release L4 edits continue from the audible level and subsequent OL round trips restore it",
          arguments: [FMEngine.modern, .markI], [60, 98, 99])
    func releaseLevelAutomation(_ mode: FMEngine, l4: Int) {
        let edited = setup(mode, ol: 99, l3: 99, depth: 99, curve: 3, first: 72, second: 36)
        let control = setup(mode, ol: 99, l3: 99, depth: 99, curve: 3, first: 72, second: 36)
        for s in [edited, control] {
            s.setOperatorDX7OutputLevel(0, level: 30)
            _ = render(s, blocks: 2)
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 72, data2: 0))
            s.sendMIDI(MIDIEvent(kind: .noteOff, data1: 36, data2: 0))
            _ = render(s, blocks: 200)
            let before = s.monoVoiceForTesting.ops.0.levelIn
            s.setOperatorDX7EGLevels(0, l1: 99, l2: 99, l3: 0, l4: l4)
            _ = render(s)
            let op = s.monoVoiceForTesting.ops.0
            // The new L4 is still below the audible level at OL30. Continue at
            // R4 from that level; changing L3 during release cannot move its start.
            #expect(op.levelIn < before)
            #expect(before - op.levelIn <= op.env.inc)
            #expect(op.env.isActive)
            _ = render(s, blocks: 10)
            #expect(s.monoVoiceForTesting.ops.0.levelIn < op.levelIn)
        }
        // An L4 edit establishes a new trajectory at the audible level. OL-only
        // excursions must then preserve that trajectory, including clipping.
        edited.setOperatorDX7OutputLevel(0, level: 99)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        edited.setOperatorDX7OutputLevel(0, level: 30)
        _ = render(edited, blocks: 2); _ = render(control, blocks: 2)
        let identical = render(edited, blocks: 64) == render(control, blocks: 64)
        #expect(identical)
    }
}
