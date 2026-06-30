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

/// DX7 12-bit DAC companding (#75): pick an exponent by amplitude so small signals are
/// boosted to use more of the 12-bit range, quantize to 12-bit, then expand. exp ∈ {1,2,4,8}
/// keeps the compressed mantissa in ~(0.5, 1.0]. Small signals get a finer effective step
/// (1/(2048·exp)) — the companding that yields the vintage warmth/grit. RT-safe.
@inline(__always)
func dac12bitCompand(_ sample: Float) -> Float {
    let a = abs(sample)
    let exp: Float = a > 0.5 ? 1 : (a > 0.25 ? 2 : (a > 0.125 ? 4 : 8))
    let q = (sample * exp * 2048).rounded() / 2048
    return q / exp
}

/// #95: full-scale reference for per-voice DAC companding — the OPS single-operator
/// full scale (`mkiSin` max mantissa `8192 << 13` = 2^26). Per-voice raw OPS samples are
/// divided by this before `dac12bitCompand` so its (−1,1)-normalized exponent selector
/// (0.5/0.25/0.125) engages across the real dynamic range, then multiplied back.
/// Runtime-settable for calibration A/B tests (like `markIModScaleQ12`); default 2^26 =
/// unchanged shipping behavior. Read per-sample as an aligned Float (RT-safe on arm64/x86_64).
nonisolated(unsafe) var kMarkIDACFullScale: Float = 67108864   // 2^26

/// Mark I silence threshold (attenuation ABOVE this = inaudible). Opposite sense
/// to Modern's kGainThreshold. Do not alias the Modern constant.
let kMarkILevelThresh: UInt16 = UInt16(kMarkIEnvMax - 100)

/// Mark I OPS modulation scale, Q12 fixed-point (scale / 4096 = the multiplier):
/// the modulator output feeds the carrier phase scaled DOWN, which is what gives
/// the OPS its darker, warmer timbre. Default 512 = ÷8 — the bit-exact-parity
/// reference (`(v·512)>>12 == v>>3`, the value the dx7refmki C twin uses); the
/// app overrides it via `SynthEngine.setMarkIModDivisor`, which is calibrated
/// against real Dexed Mark I (BASS 1 / alg15, E.PIANO 1 / alg4). Q12 gives
/// meaningful 0.1-step ÷X resolution across ÷2…÷16. Only the FORWARD modulation
/// is scaled; the carrier DAC output (`<< 13`) and the feedback path are left
/// unscaled. Written by an aligned-Int32 store (atomic on arm64).
nonisolated(unsafe) var markIModScaleQ12: Int32 = 512

@inline(__always)
private func markIModScale(_ v: Int32) -> Int32 {
    Int32(truncatingIfNeeded: (Int64(v) &* Int64(markIModScaleQ12)) >> 12)
}

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
        let y = mkiSin(phase &+ markIModScale(input[i]), UInt16(truncatingIfNeeded: max(0, aAcc)))
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

// MARK: - Fused multi-operator feedback chains (Alg 6: 2-op, Alg 4: 3-op)

/// Heap-free params for the fused feedback chain (op0 + 1 or 2 followers).
struct MarkIChainParams {
    var phase: (Int32, Int32, Int32)
    var freq: (Int32, Int32, Int32)
    var levelIn: (Int32, Int32, Int32)
}

@inline(__always)
func computeFb2MkI(_ output: UnsafeMutablePointer<Int32>, _ p: inout MarkIChainParams,
                   atten01: UInt16, atten02: UInt16, fbBuf: inout (Int32, Int32), fbShift: Int) {
    let dA0 = attenRamp(atten01, atten02, kBlockSize); var a0 = Int32(atten01)
    let a1Target = markIAtten(p.levelIn.1)
    var ph0 = p.phase.0; var ph1 = p.phase.1
    var y0 = fbBuf.0; var y = fbBuf.1
    for i in 0..<kBlockSize {
        let scaledFb = (y0 &+ y) >> (fbShift + 1)
        a0 &+= dA0
        y0 = y
        y = mkiSin(ph0 &+ scaledFb, UInt16(truncatingIfNeeded: max(0, a0)))
        ph0 &+= p.freq.0
        y = mkiSin(ph1 &+ markIModScale(y), a1Target)
        ph1 &+= p.freq.1
        output[i] = y
    }
    p.phase.0 = ph0; p.phase.1 = ph1
    fbBuf = (y0, y)
}

@inline(__always)
func computeFb3MkI(_ output: UnsafeMutablePointer<Int32>, _ p: inout MarkIChainParams,
                   atten01: UInt16, atten02: UInt16, fbBuf: inout (Int32, Int32), fbShift: Int) {
    let dA0 = attenRamp(atten01, atten02, kBlockSize); var a0 = Int32(atten01)
    let a1 = markIAtten(p.levelIn.1); let a2 = markIAtten(p.levelIn.2)
    var ph0 = p.phase.0; var ph1 = p.phase.1; var ph2 = p.phase.2
    var y0 = fbBuf.0; var y = fbBuf.1
    for i in 0..<kBlockSize {
        let scaledFb = (y0 &+ y) >> (fbShift + 1)
        a0 &+= dA0
        y0 = y
        y = mkiSin(ph0 &+ scaledFb, UInt16(truncatingIfNeeded: max(0, a0))); ph0 &+= p.freq.0
        y = mkiSin(ph1 &+ markIModScale(y), a1); ph1 &+= p.freq.1
        y = mkiSin(ph2 &+ markIModScale(y), a2); ph2 &+= p.freq.2
        output[i] = y
    }
    p.phase.0 = ph0; p.phase.1 = ph1; p.phase.2 = ph2
    fbBuf = (y0, y)
}
