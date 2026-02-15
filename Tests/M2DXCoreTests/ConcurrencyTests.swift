// ConcurrencyTests.swift
// M2DX-Core — Tests for SnapshotRing, SPSCRing, and SynthEngine thread safety

import Testing
import Foundation
@testable import M2DXCore

@Suite("SnapshotRing Tests")
struct SnapshotRingTests {

    @Test("Basic push and pop")
    func basicPushPop() {
        let ring = SnapshotRing<Int>(capacity: 4)
        ring.pushLatest(42)
        let value = ring.popLatest()
        #expect(value == 42, "Should pop 42")
    }

    @Test("Pop returns nil when empty")
    func popEmpty() {
        let ring = SnapshotRing<Int>(capacity: 4)
        let value = ring.popLatest()
        #expect(value == nil, "Empty ring should return nil")
    }

    @Test("hasData reports correctly")
    func hasDataFlag() {
        let ring = SnapshotRing<Int>(capacity: 4)
        #expect(!ring.hasData, "Empty ring should not have data")
        ring.pushLatest(1)
        #expect(ring.hasData, "Ring with data should report hasData")
        let _ = ring.popLatest()
        #expect(!ring.hasData, "After pop, ring should be empty")
    }

    @Test("popLatest skips intermediate values")
    func popLatestSkipsIntermediate() {
        let ring = SnapshotRing<Int>(capacity: 8)
        ring.pushLatest(1)
        ring.pushLatest(2)
        ring.pushLatest(3)
        let value = ring.popLatest()
        #expect(value == 3, "popLatest should return most recent value, got \(String(describing: value))")
    }

    @Test("Full ring drops oldest on push")
    func fullRingDrops() {
        let ring = SnapshotRing<Int>(capacity: 4)
        ring.pushLatest(1)
        ring.pushLatest(2)
        ring.pushLatest(3)
        ring.pushLatest(4)
        // Ring is now full, next push should be dropped
        ring.pushLatest(5)
        let value = ring.popLatest()
        // Should get 4 (last successfully pushed), not 5 (dropped)
        #expect(value == 4, "Full ring should drop new push, got \(String(describing: value))")
    }

    @Test("Sequential push/pop cycle")
    func sequentialCycle() {
        let ring = SnapshotRing<Int>(capacity: 16)
        for i in 0..<100 {
            ring.pushLatest(i)
            let v = ring.popLatest()
            #expect(v == i, "Should get \(i), got \(String(describing: v))")
        }
    }

    @Test("Concurrent producer/consumer stress test")
    func concurrentStressTest() async {
        let ring = SnapshotRing<Int>(capacity: 128)
        let iterations = 100_000

        // Producer task
        let producer = Task {
            for i in 0..<iterations {
                ring.pushLatest(i)
            }
        }

        // Consumer task
        var lastSeen = -1
        var popCount = 0
        let consumer = Task {
            var local_lastSeen = -1
            var local_popCount = 0
            while local_popCount < iterations {
                if let v = ring.popLatest() {
                    // Values should be monotonically increasing (we skip intermediate)
                    #expect(v > local_lastSeen, "Values should increase: saw \(v) after \(local_lastSeen)")
                    local_lastSeen = v
                    local_popCount += 1
                } else {
                    // Yield to let producer catch up
                    try? await Task.sleep(for: .microseconds(1))
                    // Safety valve: if producer is done and ring is empty, we're done
                    if Task.isCancelled { break }
                }
            }
            return (local_lastSeen, local_popCount)
        }

        await producer.value

        // Give consumer time to drain, then cancel
        try? await Task.sleep(for: .milliseconds(100))
        consumer.cancel()
        let result = await consumer.value
        lastSeen = result.0
        popCount = result.1

        #expect(popCount > 0, "Consumer should have read at least some values")
        #expect(lastSeen >= 0, "Should have seen valid values")
    }
}

@Suite("SPSCRing Tests")
struct SPSCRingTests {

    @Test("Basic push and pop FIFO order")
    func basicFIFO() {
        let ring = SPSCRing<Int>(capacity: 8)
        ring.push(1)
        ring.push(2)
        ring.push(3)
        #expect(ring.pop() == 1)
        #expect(ring.pop() == 2)
        #expect(ring.pop() == 3)
    }

    @Test("Pop returns nil when empty")
    func popEmpty() {
        let ring = SPSCRing<Int>(capacity: 4)
        #expect(ring.pop() == nil)
    }

    @Test("hasData and count report correctly")
    func hasDataAndCount() {
        let ring = SPSCRing<Int>(capacity: 4)
        #expect(!ring.hasData)
        #expect(ring.count == 0)
        ring.push(10)
        ring.push(20)
        #expect(ring.hasData)
        #expect(ring.count == 2)
        let _ = ring.pop()
        #expect(ring.count == 1)
        let _ = ring.pop()
        #expect(!ring.hasData)
        #expect(ring.count == 0)
    }

    @Test("Full ring drops new push")
    func fullRingDrops() {
        let ring = SPSCRing<Int>(capacity: 4)
        #expect(ring.push(1) == true)
        #expect(ring.push(2) == true)
        #expect(ring.push(3) == true)
        #expect(ring.push(4) == true)
        #expect(ring.push(5) == false, "Full ring should reject push")
        #expect(ring.count == 4)
        // Existing values preserved in FIFO order
        #expect(ring.pop() == 1)
        #expect(ring.pop() == 2)
        #expect(ring.pop() == 3)
        #expect(ring.pop() == 4)
    }

    @Test("Sequential push/pop cycle preserves all values")
    func sequentialCycle() {
        let ring = SPSCRing<Int>(capacity: 16)
        for i in 0..<100 {
            ring.push(i)
            let v = ring.pop()
            #expect(v == i, "Should get \(i), got \(String(describing: v))")
        }
    }

    @Test("Wraps around correctly beyond capacity")
    func wrapAround() {
        let ring = SPSCRing<Int>(capacity: 4)
        // Fill and drain multiple times to wrap around
        for batch in 0..<10 {
            for i in 0..<4 {
                ring.push(batch * 4 + i)
            }
            for i in 0..<4 {
                let expected = batch * 4 + i
                let v = ring.pop()
                #expect(v == expected, "Wrap batch \(batch): expected \(expected), got \(String(describing: v))")
            }
        }
    }

    @Test("Concurrent producer/consumer stress test")
    func concurrentStressTest() async {
        let ring = SPSCRing<Int>(capacity: 256)
        let iterations = 100_000

        let producer = Task {
            for i in 0..<iterations {
                while !ring.push(i) {
                    // Ring full, yield and retry
                    try? await Task.sleep(for: .microseconds(1))
                }
            }
        }

        let consumer = Task {
            var nextExpected = 0
            while nextExpected < iterations {
                if let v = ring.pop() {
                    #expect(v == nextExpected, "FIFO order: expected \(nextExpected), got \(v)")
                    nextExpected += 1
                } else {
                    try? await Task.sleep(for: .microseconds(1))
                    if Task.isCancelled { break }
                }
            }
            return nextExpected
        }

        await producer.value

        // Give consumer time to drain
        try? await Task.sleep(for: .milliseconds(200))
        consumer.cancel()
        let consumed = await consumer.value
        #expect(consumed == iterations, "All \(iterations) events should be consumed, got \(consumed)")
    }
}

@Suite("SynthEngine NoteOn/Off Tests")
struct SynthEngineNoteTests {

    @Test("SynthEngine initializes without crash")
    func initDoesNotCrash() {
        let engine = SynthEngine()
        #expect(engine != nil)
    }

    @Test("Render produces zero output with no notes")
    func silentRender() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }
        bufL.initialize(repeating: 0, count: frameCount)
        bufR.initialize(repeating: 0, count: frameCount)

        engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)

        var maxAbs: Float = 0
        for i in 0..<frameCount {
            maxAbs = max(maxAbs, abs(bufL[i]))
            maxAbs = max(maxAbs, abs(bufR[i]))
        }
        #expect(maxAbs < 0.0001, "No notes should produce silence")
    }

    @Test("NoteOn produces audible output")
    func noteOnProducesOutput() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(0)
        engine.setMasterVolume(0.7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
            engine.setOperatorRatio(i, ratio: 1.0)
        }

        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))

        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        // Render a few blocks for envelope to ramp up
        for _ in 0..<5 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }

        var maxAbs: Float = 0
        for i in 0..<frameCount {
            maxAbs = max(maxAbs, abs(bufL[i]))
        }
        #expect(maxAbs > 0.01, "NoteOn should produce audible output, maxAbs=\(maxAbs)")
    }

    @Test("NoteOff eventually silences output")
    func noteOffSilences() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(31)  // All carriers
        engine.setMasterVolume(0.7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
        }

        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))

        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        // Render while note is on
        for _ in 0..<5 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }

        // Note off
        engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: 60, data2: 0))

        // Render until silent
        var becameSilent = false
        for _ in 0..<200 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
            var maxAbs: Float = 0
            for i in 0..<frameCount { maxAbs = max(maxAbs, abs(bufL[i])) }
            if maxAbs < 0.0001 { becameSilent = true; break }
        }
        #expect(becameSilent, "Output should eventually become silent after noteOff")
    }

    @Test("Rapid noteOn/Off does not crash")
    func rapidNoteOnOff() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(0)
        engine.setMasterVolume(0.7)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
        }

        let frameCount = 64
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        for i in 0..<1000 {
            let note = UInt8(36 + (i % 49))
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(0x7F00)))
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
            engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: note, data2: 0))
        }
        // If we get here without crash, test passes
    }

    @Test("Output is clipped to [-1, 1]")
    func outputClipped() {
        let engine = SynthEngine()
        engine.setSampleRate(44100)
        engine.setAlgorithm(31)
        engine.setMasterVolume(1.0)
        for i in 0..<6 {
            engine.setOperatorDX7OutputLevel(i, level: 99)
            engine.setOperatorDX7EGRates(i, r1: 99, r2: 99, r3: 99, r4: 99)
            engine.setOperatorDX7EGLevels(i, l1: 99, l2: 99, l3: 99, l4: 0)
        }

        // Play many notes at once to force clipping
        for note in UInt8(36)...UInt8(72) {
            engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(0x7F00)))
        }

        let frameCount = 512
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer { bufL.deallocate(); bufR.deallocate() }

        for _ in 0..<10 {
            bufL.initialize(repeating: 0, count: frameCount)
            bufR.initialize(repeating: 0, count: frameCount)
            engine.render(into: bufL, bufferR: bufR, frameCount: frameCount)
        }

        for i in 0..<frameCount {
            #expect(bufL[i] >= -1.0 && bufL[i] <= 1.0, "Output L[\(i)] = \(bufL[i]) out of range")
            #expect(bufR[i] >= -1.0 && bufR[i] <= 1.0, "Output R[\(i)] = \(bufR[i]) out of range")
        }
    }
}
