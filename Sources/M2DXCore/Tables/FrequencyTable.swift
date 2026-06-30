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
    // The LUT only spans ±12 semitones. Pitch EG (±48), RPN coarse tuning (±64),
    // and bend ranges above 12 can exceed that; fall back to a direct exp2 instead
    // of clamping to ±1 octave. All callers are block-rate, so powf is acceptable.
    if semitones > 12.0 || semitones < -12.0 {
        return powf(2.0, semitones / 12.0)
    }
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

// MARK: - DX7 LFO Speed → Hz (DEXED lfoSource table, 100 entries)

/// LFO frequency in Hz per DX7 speed param (0…99) — verbatim from DEXED/MSFA
/// `lfoSource[]` (asb2m10/dexed Source/msfa/lfo.cc). 0.0625 Hz at speed 0 up to
/// ~49.3 Hz at speed 99. #94
package let kLFOSpeedHz: [Float] = [
    0.062541, 0.125031, 0.312393, 0.437120, 0.624610,
    0.750694, 0.936330, 1.125302, 1.249609, 1.436782,
    1.560915, 1.752081, 1.875117, 2.062494, 2.247191,
    2.374451, 2.560492, 2.686728, 2.873976, 2.998950,
    3.188013, 3.369840, 3.500175, 3.682224, 3.812065,
    4.000800, 4.186202, 4.310716, 4.501260, 4.623209,
    4.814636, 4.930480, 5.121901, 5.315191, 5.434783,
    5.617346, 5.750431, 5.946717, 6.062811, 6.248438,
    6.431695, 6.564264, 6.749460, 6.868132, 7.052186,
    7.250580, 7.375719, 7.556294, 7.687577, 7.877738,
    7.993605, 8.181967, 8.372405, 8.504848, 8.685079,
    8.810573, 8.986341, 9.122423, 9.300595, 9.500285,
    9.607994, 9.798158, 9.950249, 10.117361, 11.251125,
    11.384335, 12.562814, 13.676149, 13.904338, 15.092062,
    16.366612, 16.638935, 17.869907, 19.193858, 19.425019,
    20.833333, 21.034918, 22.502250, 24.003841, 24.260068,
    25.746653, 27.173913, 27.578599, 29.052876, 30.693677,
    31.191516, 32.658393, 34.317090, 34.674064, 36.416606,
    38.197097, 38.550501, 40.387722, 40.749796, 42.625746,
    44.326241, 44.883303, 46.772685, 48.590865, 49.261084,
]

// MARK: - DX7 Pitch EG (DEXED pitchenv.cc)

/// Pitch EG level (0…99) → signed pitch, DEXED `pitchenv_tab` (int8). The EG `level_` is
/// `pitchenv_tab[level] << 19`; 1 unit ≈ 0.375 st (1<<24 = one octave). Non-linear: gentle
/// in the middle, steep at the extremes. Center is index 50 (= 0). #93
package let kPitchEnvTab: [Int] = [
    -128, -116, -104, -95, -85, -76, -68, -61, -56, -52, -49, -46, -43,
    -41, -39, -37, -35, -33, -32, -31, -30, -29, -28, -27, -26, -25,
    -24, -23, -22, -21, -20, -19, -18, -17, -16, -15, -14, -13, -12, -11, -10,
    -9, -8, -7, -6, -5, -4, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27,
    28, 29, 30, 31, 32, 33, 34, 35, 38, 40, 43, 46, 49, 53, 58, 65, 73,
    82, 92, 103, 115, 127,
]

/// Pitch EG rate (0…99) → increment multiplier, DEXED `pitchenv_rate`. The per-block
/// increment is `pitchenv_rate[rate] · unit`, with `unit = 64·(1<<24)/(21.3·Fs)`. #93
package let kPitchEnvRate: [Int] = [
    1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12,
    12, 13, 13, 14, 14, 15, 16, 16, 17, 18, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 30, 31, 33, 34, 36, 37, 38, 39, 41, 42, 44, 46, 47,
    49, 51, 53, 54, 56, 58, 60, 62, 64, 66, 68, 70, 72, 74, 76, 79, 82,
    85, 88, 91, 94, 98, 102, 106, 110, 115, 120, 125, 130, 135, 141, 147,
    153, 159, 165, 171, 178, 185, 193, 202, 211, 232, 243, 254, 255,
]
