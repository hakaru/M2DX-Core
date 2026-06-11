// HeadlessRenderer.swift
// PresetLabKit — renders a single note of a DX7 preset offline (no audio device).
//
// Single-threaded sequential sendMIDI → render is safe: the same thread acts as
// both producer and consumer of the engine's SPSC ring (same pattern as AUv3).

import M2DXCore
import Foundation

public struct RenderedNote {
    public let samples: [Float]      // mono mix (L+R)/2
    public let sampleRate: Float
    public let noteOffSample: Int
}

public enum HeadlessRenderer {
    public static func render(preset: DX7Preset, note: UInt8, velocity7: UInt8,
                              noteOffSeconds: Double, totalSeconds: Double,
                              sampleRate: Float = 48000) -> RenderedNote {
        let engine = SynthEngine()
        engine.setSampleRate(sampleRate)
        engine.loadDX7Preset(preset)
        engine.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(velocity7) << 9))

        let total = Int(totalSeconds * Double(sampleRate))
        let offAt = Int(noteOffSeconds * Double(sampleRate))
        let block = 256
        var mono = [Float](); mono.reserveCapacity(total)
        let l = UnsafeMutablePointer<Float>.allocate(capacity: block)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: block)
        defer { l.deallocate(); r.deallocate() }

        var rendered = 0
        var offSent = false
        while rendered < total {
            if !offSent && rendered >= offAt {
                engine.sendMIDI(MIDIEvent(kind: .noteOff, data1: note, data2: 0))
                offSent = true
            }
            let n = min(block, total - rendered)
            engine.render(into: l, bufferR: r, frameCount: n)
            for i in 0..<n { mono.append((l[i] + r[i]) * 0.5) }
            rendered += n
        }
        return RenderedNote(samples: mono, sampleRate: sampleRate, noteOffSample: offAt)
    }
}
