// FrequencyTable.swift
// M2DX-Core — MIDI note frequency, pitch bend, and tuning lookup tables
// Self-generated from mathematical definitions. No external code referenced.

import Darwin

// MARK: - MIDI Note Frequency LUT (128 entries)

/// Maps MIDI note number (0-127) to frequency in Hz.
/// Formula: 440 × 2^((note - 69) / 12)
nonisolated(unsafe) let kMIDIFreqLUT: UnsafePointer<Float> = {
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: 128)
    for i in 0..<128 {
        buf[i] = 440.0 * powf(2.0, (Float(i) - 69.0) / 12.0)
    }
    return UnsafePointer(buf)
}()

// MARK: - Pitch Bend LUT (1024 entries, ±2 semitones)

/// Maps index 0..<1024 to pitch bend factor for ±2 semitones.
/// Index 512 ≈ center (factor 1.0).
private let kPitchBendLUTSize = 1024
nonisolated(unsafe) let kPitchBendLUT: UnsafePointer<Float> = {
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: kPitchBendLUTSize)
    for i in 0..<kPitchBendLUTSize {
        let normalized = Float(i) / Float(kPitchBendLUTSize - 1)  // 0..1
        let semitones = (normalized * 2.0 - 1.0) * 2.0  // -2..+2
        buf[i] = powf(2.0, semitones / 12.0)
    }
    return UnsafePointer(buf)
}()

/// Look up pitch bend factor for ±2 semitone range with linear interpolation.
@inline(__always)
package func pitchBendFactor(_ semitones: Float) -> Float {
    let normalized = (semitones + 2.0) * 0.25  // 0..1
    let fIndex = normalized * Float(kPitchBendLUTSize - 1)
    let clamped = max(0, min(Float(kPitchBendLUTSize - 2), fIndex))
    let i = Int(clamped)
    let frac = clamped - Float(i)
    return kPitchBendLUT[i] + frac * (kPitchBendLUT[i + 1] - kPitchBendLUT[i])
}

// MARK: - Extended Pitch Bend LUT (4096 entries, ±12 semitones)

private let kPitchBendExtLUTSize = 4096
nonisolated(unsafe) let kPitchBendExtLUT: UnsafePointer<Float> = {
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: kPitchBendExtLUTSize)
    for i in 0..<kPitchBendExtLUTSize {
        let normalized = Float(i) / Float(kPitchBendExtLUTSize - 1)  // 0..1
        let semitones = (normalized * 2.0 - 1.0) * 12.0  // -12..+12
        buf[i] = powf(2.0, semitones / 12.0)
    }
    return UnsafePointer(buf)
}()

/// Look up pitch bend factor for ±12 semitone range.
@inline(__always)
package func pitchBendFactorExt(_ semitones: Float) -> Float {
    let normalized = (semitones + 12.0) / 24.0  // 0..1
    let fIndex = normalized * Float(kPitchBendExtLUTSize - 1)
    let clamped = max(0, min(Float(kPitchBendExtLUTSize - 2), fIndex))
    let i = Int(clamped)
    let frac = clamped - Float(i)
    return kPitchBendExtLUT[i] + frac * (kPitchBendExtLUT[i + 1] - kPitchBendExtLUT[i])
}

// MARK: - Master Tuning LUT (201 entries, -100..+100 cents)

nonisolated(unsafe) let kTuningLUT: UnsafePointer<Float> = {
    let buf = UnsafeMutablePointer<Float>.allocate(capacity: 201)
    for i in 0..<201 {
        let cents = Float(i - 100)  // -100..+100
        buf[i] = powf(2.0, cents / 1200.0)
    }
    return UnsafePointer(buf)
}()

// MARK: - DX7 PMS Depth Table (8 entries)

/// Pitch Mod Sensitivity: how much LFO affects pitch (in semitones at max PMD).
/// PMS 0 = no effect, PMS 7 = ±4 semitones.
package let kPMSDepth: [Float] = [0, 0.1, 0.2, 0.4, 0.7, 1.0, 2.0, 4.0]
