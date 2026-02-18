// ScalingTable.swift
// M2DX-Core — Velocity, KLS, OutputLevel, AMS, and EG rate scaling tables
// Self-generated from DX7 published specifications. No external code referenced.

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

/// Exponential KLS curve table (32 entries).
/// Approximates DX7 OPS chip non-linear scaling.
package let kNlsTable: [Int] = [
    0,  0,  0,  1,  2,  4,  6,  9,
    13, 17, 22, 28, 34, 41, 49, 58,
    68, 79, 90, 103, 116, 131, 146, 163,
    181, 200, 220, 241, 264, 288, 313, 339
]

/// Keyboard Level Scaling — returns offset (signed).
/// Negative curves → positive offset (more attenuation).
/// Positive curves → negative offset (boost).
@inline(__always)
package func scaleKeyboardLevel(
    _ note: UInt8, breakPoint: UInt8,
    leftDepth: UInt8, rightDepth: UInt8,
    leftCurve: UInt8, rightCurve: UInt8
) -> Int {
    let bp = Int(breakPoint) + 21
    let diff = Int(note) - bp
    if diff == 0 { return 0 }

    let distance: Int, depth: Int, curve: UInt8
    if diff < 0 {
        distance = -diff; depth = Int(leftDepth); curve = leftCurve
    } else {
        distance = diff; depth = Int(rightDepth); curve = rightCurve
    }
    guard depth > 0 else { return 0 }

    let group = min(31, (distance + 1) / 3)
    let isLinear = (curve == 0 || curve == 3)
    let isNegative = curve < 2

    let scale: Int
    if isLinear {
        scale = (group * depth * 329 + 2048) >> 12
    } else {
        let nlsValue = kNlsTable[group]
        scale = (nlsValue * depth + 1024) >> 11
    }
    let capped = min(127, scale)
    return isNegative ? capped : -capped
}

// MARK: - AMS Depth Table (4 entries, Q24)

/// Amp Mod Sensitivity depth values in Q24.
/// AMS 0 = no effect, AMS 3 = full modulation.
/// Normalized to 1<<24: {0, 0.259, 0.427, 1.0}
package let kAMSDepthQ24: [Int32] = [0, 4_342_338, 7_171_437, 16_777_216]

// MARK: - Keyboard Rate Scaling

/// Rate scaling value added to raw rate before qrate conversion.
/// Matches DEXED msfa ScaleRate(): x = clamp(note/3 - 7, 0, 31), result = (sensitivity * x) >> 3
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
@inline(__always)
package func fixedFreqHz(coarse: UInt8, fine: UInt8) -> Float {
    let base = powf(10.0, Float(coarse) / 10.0)
    return base * (1.0 + Float(fine) / 100.0)
}
