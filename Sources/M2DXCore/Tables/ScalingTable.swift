// ScalingTable.swift
// M2DX-Core — Velocity, KLS, OutputLevel, AMS, and EG rate scaling tables
// Tables/algorithms derived from MSFA/Dexed (Apache-2.0); see NOTICE.

import Darwin

// MARK: - Velocity Data Table (64 entries)

/// Maps 7-bit velocity >> 1 to internal scaling value.
/// Zero-point is 239 (vel ≈ 100). Below 239 = attenuation, above = boost.
/// Derived from DX7 OPS chip characteristics (Ken Shirriff's documentation).
package let kVelocityData: [UInt8] = [
    0, 70, 86, 97, 106, 114, 121, 126,
    132, 138, 142, 148, 152, 156, 160, 163,
    166, 170, 173, 174, 178, 181, 184, 186,
    189, 190, 194, 196, 198, 200, 202, 205,
    206, 209, 211, 214, 216, 218, 220, 222,
    224, 225, 227, 229, 230, 232, 233, 235,
    237, 238, 240, 241, 242, 243, 244, 246,
    246, 248, 249, 250, 251, 252, 253, 254
]

/// Velocity sensitivity: OL-point reduction at minimum velocity.
/// sens=0: no effect, sens=7: up to ~14 OL points reduction.
package let kVelSensOLReduction: [Int] = [0, 2, 4, 6, 8, 10, 12, 14]

/// Scale velocity — returns offset in microsteps (signed).
/// Positive = louder (reduce attenuation), Negative = quieter.
@inline(__always)
package func scaleVelocity(_ velocity16: UInt16, sens: Int) -> Int {
    guard sens > 0 else { return 0 }
    let vel7 = Int(min(127, velocity16 >> 9))
    let velIdx = min(63, vel7 >> 1)
    let velValue = Int(kVelocityData[velIdx]) - 239
    return ((min(sens, 7) * velValue + 7) >> 3) << 4
}

// MARK: - Output Level Scaling

/// Level lookup for OL < 20: nonlinear compression.
/// OL >= 20 uses (28 + OL).
private let kLevelLut: [Int] = [
    0, 5, 9, 13, 17, 20, 23, 25, 27, 29,
    31, 33, 35, 37, 39, 41, 42, 43, 45, 46
]

/// Scale output level: maps DX7 OL (0-99) to internal level (0-127).
@inline(__always)
package func scaleOutputLevel(_ ol: Int) -> Int {
    ol >= 20 ? 28 + ol : kLevelLut[max(0, min(19, ol))]
}

// MARK: - Keyboard Level Scaling (KLS)

/// Exponential KLS curve table (33 entries) — verbatim from MSFA/Dexed dx7note.cc
/// `exp_scale_data`. Indexed by the keyboard-distance group, clamped to its last entry.
package let kExpScaleData: [Int] = [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 14, 16, 19, 23, 27, 33,
    39, 47, 56, 66, 80, 94, 110, 126, 142, 158, 174, 190, 206, 222, 238, 250
]

/// One side of the DX7 keyboard level-scaling curve (Dexed `ScaleCurve`).
/// `curve`: 0 = −LIN, 1 = −EXP, 2 = +EXP, 3 = +LIN. The −curves (0/1) attenuate away
/// from the breakpoint (negative result); the +curves (2/3) boost (positive result).
@inline(__always)
package func scaleCurve(group: Int, depth: Int, curve: UInt8) -> Int {
    var scale: Int
    if curve == 0 || curve == 3 {            // linear
        scale = (group * depth * 329) >> 12
    } else {                                  // exponential
        let rawExp = kExpScaleData[min(group, kExpScaleData.count - 1)]
        scale = (rawExp * depth * 329) >> 15
    }
    if curve < 2 { scale = -scale }
    return scale
}

/// Keyboard Level Scaling — returns the signed output-level offset for `note`
/// (Dexed `ScaleLevel`). The breakpoint hinge sits at note = breakPoint + 17. The
/// result is NOT pre-clamped to ±127; the caller clamps the summed output level.
@inline(__always)
package func scaleKeyboardLevel(
    _ note: UInt8, breakPoint: UInt8,
    leftDepth: UInt8, rightDepth: UInt8,
    leftCurve: UInt8, rightCurve: UInt8
) -> Int {
    let offset = Int(note) - Int(breakPoint) - 17
    if offset >= 0 {
        return scaleCurve(group: (offset + 1) / 3, depth: Int(rightDepth), curve: rightCurve)
    } else {
        return scaleCurve(group: -(offset - 1) / 3, depth: Int(leftDepth), curve: leftCurve)
    }
}

// MARK: - AMS Depth Table (4 entries, Q24)

/// Amp Mod Sensitivity depth values in Q24.
/// AMS 0 = no effect, AMS 3 = full modulation.
/// Normalized to 1<<24: {0, 0.259, 0.427, 1.0}
package let kAMSDepthQ24: [Int32] = [0, 4_342_338, 7_171_437, 16_777_216]

// MARK: - Keyboard Rate Scaling

/// Rate scaling value added to raw rate before qrate conversion.
/// Matches DEXED ScaleRate(): x = clamp(note/3 - 7, 0, 31), result = (sensitivity * x) >> 3
@inline(__always)
package func keyboardRateScaling(note: UInt8, scaling: UInt8) -> Int {
    guard scaling > 0 else { return 0 }
    let x = min(31, max(0, Int(note) / 3 - 7))
    return (Int(scaling) * x) >> 3
}

// MARK: - Feedback Shift

/// Feedback shift: fb=0 → 16 (disabled), fb=1 → 7, fb=2 → 6, ..., fb=7 → 1
@inline(__always)
package func feedbackShift(_ fb: Int) -> Int {
    fb != 0 ? 8 - fb : 16
}

// MARK: - Fixed Frequency

/// Convert DX7 fixed frequency coarse + fine to Hz.
/// DX7 selects the decade (1/10/100/1000 Hz) from the low 2 bits of coarse and
/// treats fine as a base-10 mantissa exponent: freq = 10^((coarse & 3) + fine/100).
@inline(__always)
package func fixedFreqHz(coarse: UInt8, fine: UInt8) -> Float {
    return powf(10.0, Float(Int(coarse) & 3) + Float(fine) / 100.0)
}

// MARK: - Operator Detune (frequency-dependent, DEXED dx7note.cc)

/// DX7 operator detune as a per-note frequency multiplier (DEXED `dx7ref_osc_freq`).
/// In the Q24 log2 domain DEXED does `logfreq += (0.0209·exp(-0.396·log2 freq)/7)·logfreq·c`
/// with `c = detune − 7` (−7…+7), giving ~±17 cents in the bass down to ~±3.5 cents in the
/// treble — NOT the pitch-independent constant ±7c M2DX used before. #96
@inline(__always)
package func dexedDetuneFactor(_ freq: Float, detuneCents: Float) -> Float {
    guard detuneCents != 0, freq > 0 else { return 1.0 }
    let lf = log2f(freq)                                  // = logfreq / (1<<24)
    let detuneRatio = 0.0209 * expf(-0.396 * lf) / 7.0
    return exp2f(detuneRatio * lf * detuneCents)
}

// MARK: - Unison Detune

/// Symmetric unison detune factor for voice `index` of `count`, spread to ±`detuneCents`.
/// Voice 0 → -detuneCents, voice count-1 → +detuneCents; count==1 → 1.0 (no detune).
@inline(__always)
package func unisonDetuneFactor(index i: Int, count n: Int, detuneCents d: Float) -> Float {
    guard n > 1 else { return 1.0 }
    let cents = (2.0 * Float(i) / Float(n - 1) - 1.0) * d
    return exp2(cents / 1200.0)
}

/// Random (#83) detune factor for unison `voiceIndex` of slot `slotIndex`, spread
/// within ±`detuneCents`. Deterministic — seeded ONLY by (slot, voice) via one
/// SplitMix64 step — so a held note's spread is stable and a recalled stack
/// reproduces bit-for-bit. RT-safe (no heap / lock / `Float.random`).
@inline(__always)
package func unisonDetuneFactorRandom(slotIndex: Int, voiceIndex: Int, detuneCents d: Float) -> Float {
    guard d != 0 else { return 1.0 }
    var z = UInt64(0xA0761D6478BD642F)
        ^ (UInt64(bitPattern: Int64(slotIndex)) &* 0x9E3779B97F4A7C15)
        ^ (UInt64(bitPattern: Int64(voiceIndex)) &* 0xD1B54A32D192ED03)
    z = z &+ 0x9E3779B97F4A7C15                          // SplitMix64 step
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    z = z ^ (z >> 31)
    let signed = Float(Int32(bitPattern: UInt32(truncatingIfNeeded: z))) / Float(0x80000000)  // [-1,1)
    return exp2((signed * d) / 1200.0)
}

/// Voice-stack (#89-detune) random detune factor for stack `copyIndex` of a given
/// `noteOnIndex`, spread within ±`detuneCents`. Re-rolls every note-on (the engine
/// advances `noteOnIndex` per note-on) for a live, analog feel — deliberately NOT
/// recall-reproducible. Same SplitMix64 hash family as `unisonDetuneFactorRandom`
/// with a distinct base seed so it is independent of unison/pan randoms. RT-safe.
@inline(__always)
package func voiceStackDetuneFactorRandom(noteOnIndex: UInt64, copyIndex: Int, detuneCents d: Float) -> Float {
    guard d != 0 else { return 1.0 }
    var z = UInt64(0x9E3779B185EBCA87)                          // distinct base seed
        ^ (noteOnIndex &* 0x9E3779B97F4A7C15)
        ^ (UInt64(bitPattern: Int64(copyIndex)) &* 0xD1B54A32D192ED03)
    z = z &+ 0x9E3779B97F4A7C15                                  // SplitMix64 step
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    z = z ^ (z >> 31)
    let signed = Float(Int32(bitPattern: UInt32(truncatingIfNeeded: z))) / Float(0x80000000)  // [-1,1)
    return exp2((signed * d) / 1200.0)
}

/// Voice-stack (#89-detune) loudness compensation. Detuning decorrelates the N stacked
/// copies: at 0 cents they are phase-locked and sum coherently (∝ N → 1/N keeps unity);
/// past `kVoiceStackDecorrelationCents` they sum incoherently (∝ √N → 1/√N). Crossfades
/// the exponent 1.0 → 0.5 so 0 cents reproduces the legacy 1/N exactly. RT-safe.
@inline(__always)
package func voiceStackGainFactor(multiplier n: Int, detuneCents d: Float) -> Float {
    let nn = max(1, n)
    guard nn > 1 else { return 1.0 }
    let c = min(1.0, max(0, d) / kVoiceStackDecorrelationCents)   // 0…1
    let p = 1.0 - 0.5 * c                                         // 1.0 → 0.5
    return powf(Float(nn), -p)
}

/// Random (#76) pan in [-1, 1) for unison `voiceIndex` of slot `slotIndex`.
/// Deterministic per (slot, voice) — same family as `unisonDetuneFactorRandom`
/// but a distinct seed base so pan and detune randoms are independent. RT-safe.
@inline(__always)
package func layerPanRandom(slotIndex: Int, voiceIndex: Int) -> Float {
    var z = UInt64(0x2545F4914F6CDD1D)                  // distinct base from detune
        ^ (UInt64(bitPattern: Int64(slotIndex)) &* 0x9E3779B97F4A7C15)
        ^ (UInt64(bitPattern: Int64(voiceIndex)) &* 0xD1B54A32D192ED03)
    z = z &+ 0x9E3779B97F4A7C15                          // SplitMix64 step
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    z = z ^ (z >> 31)
    return Float(Int32(bitPattern: UInt32(truncatingIfNeeded: z))) / Float(0x80000000)  // [-1,1)
}
