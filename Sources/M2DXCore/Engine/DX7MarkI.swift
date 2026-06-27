// DX7MarkI.swift
// M2DX-Core — Mark I OPS-chip FM path. Clean-room; see DX7MarkI_PROVENANCE.md.
import Darwin

let kMarkIEnvMax: Int32 = 1 << 14            // ENV_MAX
private let kSinLogMask: UInt32 = 1023
private let kNegBit: UInt16 = 0x8000

/// Log-sine with quadrant folding. phi: top 10 bits of the Q24 phase.
@inline(__always)
private func markISinLog(_ phi: UInt32) -> UInt16 {
    let index = UInt16(phi & kSinLogMask)
    switch phi & (1024 * 3) {
    case 0:               return kSinLogLUT[Int(index)]
    case 1024:            return kSinLogLUT[Int(index ^ UInt16(kSinLogMask))]
    case 1024 * 2:        return kSinLogLUT[Int(index)] | kNegBit
    default:              return kSinLogLUT[Int(index ^ UInt16(kSinLogMask))] | kNegBit
    }
}

/// OPS operator: log-add the attenuation, then exponentiate by shift. Returns Q24-ish.
@inline(__always)
func mkiSin(_ phase: Int32, _ atten: UInt16) -> Int32 {
    let phi = UInt32(bitPattern: phase) >> 12        // top bits, unsigned (no signed shift)
    var expVal = markISinLog(phi) &+ atten
    let signed = (expVal & kNegBit) != 0
    expVal &= ~kNegBit
    let mantissa = Int32(4096) &+ Int32(kSinExpLUT[Int((expVal & 0x3FF) ^ 0x3FF)])
    let shift = Int(expVal >> 10)
    let result = shift >= 31 ? 0 : (mantissa >> shift)   // clamp: Swift traps on >=bitwidth
    return signed ? ((-result - 1) << 13) : (result << 13)
}

/// EG level (Q24, the same value Modern feeds to exp2) → Mark I log attenuation.
/// Larger return value = MORE attenuation = quieter (opposite sense to Modern gain).
@inline(__always)
func markIAtten(_ levelIn: Int32) -> UInt16 {
    let raw = Int32(kMarkIEnvMax) &- (levelIn >> 14)
    let clamped = max(0, min(kMarkIEnvMax, raw))
    return clamped == 0 ? UInt16(kMarkIEnvMax - 1) : UInt16(clamped)
}

/// Mark I silence threshold (attenuation ABOVE this = inaudible). Opposite sense
/// to Modern's kGainThreshold. Do not alias the Modern constant.
let kMarkILevelThresh: UInt16 = UInt16(kMarkIEnvMax - 100)

// MARK: - Single-input FM kernels (mod / pure / fb)

@inline(__always)
private func attenRamp(_ a1: UInt16, _ a2: UInt16, _ n: Int) -> Int32 {
    // Interpolate attenuation across the block, mirroring the Modern dgain shift.
    let d = Int32(a2) - Int32(a1)
    return (n == kBlockSize) ? ((d + Int32(n >> 1)) >> kLgBlockSize) : (d / Int32(n))
}

@inline(__always)
func computeModMkI(_ output: UnsafeMutablePointer<Int32>, _ input: UnsafePointer<Int32>,
                   phase0: Int32, freq: Int32, atten1: UInt16, atten2: UInt16, add: Bool, n: Int) {
    let dA = attenRamp(atten1, atten2, n); var aAcc = Int32(atten1); var phase = phase0
    for i in 0..<n {
        aAcc &+= dA
        let y = mkiSin(phase &+ input[i], UInt16(truncatingIfNeeded: max(0, aAcc)))
        output[i] = add ? (output[i] &+ y) : y
        phase &+= freq
    }
}

@inline(__always)
func computePureMkI(_ output: UnsafeMutablePointer<Int32>,
                    phase0: Int32, freq: Int32, atten1: UInt16, atten2: UInt16, add: Bool, n: Int) {
    let dA = attenRamp(atten1, atten2, n); var aAcc = Int32(atten1); var phase = phase0
    for i in 0..<n {
        aAcc &+= dA
        let y = mkiSin(phase, UInt16(truncatingIfNeeded: max(0, aAcc)))
        output[i] = add ? (output[i] &+ y) : y
        phase &+= freq
    }
}

@inline(__always)
func computeFbMkI(_ output: UnsafeMutablePointer<Int32>, phase0: Int32, freq: Int32,
                  atten1: UInt16, atten2: UInt16, fbBuf: inout (Int32, Int32),
                  fbShift: Int, add: Bool, n: Int) {
    let dA = attenRamp(atten1, atten2, n); var aAcc = Int32(atten1); var phase = phase0
    var y0 = fbBuf.0; var y = fbBuf.1
    for i in 0..<n {
        aAcc &+= dA
        let scaledFb = (y0 &+ y) >> (fbShift + 1)
        y0 = y
        y = mkiSin(phase &+ scaledFb, UInt16(truncatingIfNeeded: max(0, aAcc)))
        output[i] = add ? (output[i] &+ y) : y
        phase &+= freq
    }
    fbBuf = (y0, y)
}
