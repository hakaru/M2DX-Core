// PortamentoTests.swift
// #79: poly portamento — a new note glides from the previously played note's
// pitch to its target at a constant rate (cents/sec). OFF leaves every voice
// un-glided (the bit-identical render contract). The glide offset is inspected
// via SynthEngine.debugGlideOffsetCents.

import Testing
import Darwin
@testable import M2DXCore

@Suite("Portamento (#79)")
struct PortamentoTests {
    let sr: Float = 48000

    private func renderBlock(_ s: SynthEngine, frames: Int) {
        var l = [Float](repeating: 0, count: frames)
        var r = [Float](repeating: 0, count: frames)
        l.withUnsafeMutableBufferPointer { lp in r.withUnsafeMutableBufferPointer { rp in
            s.render(into: lp.baseAddress!, bufferR: rp.baseAddress!, frameCount: frames)
        }}
    }

    /// Engine with portamento configured and the snapshot warmed in before notes.
    private func engine(on: Bool, time: Float) -> SynthEngine {
        let s = SynthEngine()
        s.setSampleRate(sr)
        s.setPortamento(enabled: on, time: time)
        renderBlock(s, frames: 64)   // consume the portamento snapshot before notes
        return s
    }

    private func noteOn(_ s: SynthEngine, _ note: UInt8) {
        s.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(100) << 9))
    }

    @Test("Time→rate mapping is monotonic and within the documented range")
    func rateMapping() {
        let r0 = SynthEngine.portamentoRate(fromTime: 0)
        let rHalf = SynthEngine.portamentoRate(fromTime: 0.5)
        let r1 = SynthEngine.portamentoRate(fromTime: 1)
        #expect(r0 > rHalf && rHalf > r1)        // faster (higher c/s) at Time 0
        #expect(r0 > 10000 && r0 <= 24000)
        #expect(r1 >= 60 && r1 < 200)
    }

    @Test("a new note seeds a glide from the previous note's pitch")
    func seedFromPreviousNote() {
        let s = engine(on: true, time: 1)        // slow → minimal per-block advance
        noteOn(s, 60)
        renderBlock(s, frames: 64)               // voice 0; previous note = 60
        noteOn(s, 72)
        renderBlock(s, frames: 64)               // voice 1; seeded from 60 → -1200 cents
        let off = s.debugGlideOffsetCents(voice: 1)
        #expect(off < 0)                          // starts BELOW target (60 < 72)
        #expect(abs(off - (-1200)) < 5)           // ≈ -1200, minus one tiny slow step
    }

    @Test("the first note (no previous) does not glide")
    func firstNoteNoGlide() {
        let s = engine(on: true, time: 0.5)
        noteOn(s, 60)
        renderBlock(s, frames: 64)
        #expect(s.debugGlideOffsetCents(voice: 0) == 0)
    }

    @Test("portamento OFF leaves every voice un-glided (bit-identical contract)")
    func offNoGlide() {
        let s = engine(on: false, time: 0.5)
        noteOn(s, 60)
        renderBlock(s, frames: 64)
        noteOn(s, 72)
        renderBlock(s, frames: 64)
        #expect(s.debugGlideOffsetCents(voice: 0) == 0)
        #expect(s.debugGlideOffsetCents(voice: 1) == 0)
    }

    @Test("the glide converges exactly to the target")
    func convergence() {
        let s = engine(on: true, time: 0.3)
        noteOn(s, 60)
        renderBlock(s, frames: 64)
        noteOn(s, 72)
        // render-THEN-check: the first render drains + seeds voice 1, so the loop
        // body must run at least once before the offset is meaningful.
        var blocks = 0
        repeat {
            renderBlock(s, frames: 64)
            blocks += 1
        } while s.debugGlideOffsetCents(voice: 1) != 0 && blocks < 5000
        #expect(blocks > 1)                        // it actually took time to arrive
        #expect(s.debugGlideOffsetCents(voice: 1) == 0)
    }

    @Test("constant rate: a 2-octave glide takes ~2× the time of a 1-octave glide")
    func constantRateProportional() {
        func blocksToArrive(interval: UInt8) -> Int {
            let s = engine(on: true, time: 0.5)
            noteOn(s, 48)
            renderBlock(s, frames: 64)           // previous note = 48
            noteOn(s, 48 + interval)
            var blocks = 0
            repeat {                             // first render seeds voice 1
                renderBlock(s, frames: 64)
                blocks += 1
            } while s.debugGlideOffsetCents(voice: 1) != 0 && blocks < 100_000
            return blocks
        }
        let oneOct = blocksToArrive(interval: 12)
        let twoOct = blocksToArrive(interval: 24)
        #expect(oneOct > 10)                      // a real, measurable glide
        let ratio = Double(twoOct) / Double(oneOct)
        #expect(ratio > 1.8 && ratio < 2.2)
    }
}
