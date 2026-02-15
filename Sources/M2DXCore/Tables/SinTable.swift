// SinTable.swift
// M2DX-Core — Q24 sine lookup table (1024 entries, delta+value interleaved)
// Self-generated from mathematical definition. No external code referenced.

import Darwin

// MARK: - Q24 Sine Table

/// Q24 sine table: 2048 entries (1024 delta+value pairs interleaved).
/// Full-cycle table (not quarter-wave), value range ±2^24.
/// Generated using rotation matrix for numerical stability.
///
/// Layout: sinTab[2*i] = delta, sinTab[2*i+1] = value
/// where value[i] = sin(2π·i/1024) × 2^24
nonisolated(unsafe) let kSinTab: UnsafePointer<Int32> = {
    let count = 2048  // 1024 * 2 (delta + value interleaved)
    let buf = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    buf.initialize(repeating: 0, count: count)

    // Rotation matrix recursive sine generation:
    // [cos(θ+dθ)]   [cos(dθ) -sin(dθ)] [cos(θ)]
    // [sin(θ+dθ)] = [sin(dθ)  cos(dθ)] [sin(θ)]
    let dphase = 2.0 * Double.pi / 1024.0
    let c = Int64(Darwin.floor(Darwin.cos(dphase) * Double(1 << 30) + 0.5))
    let s = Int64(Darwin.floor(Darwin.sin(dphase) * Double(1 << 30) + 0.5))
    let rnd: Int64 = 1 << 29  // rounding constant
    var u: Int64 = 1 << 30    // cos(0) = 1.0 in Q30
    var v: Int64 = 0           // sin(0) = 0.0 in Q30

    for i in 0..<512 {
        // Q30 → Q24 with rounding
        let val = Int32((v + 32) >> 6)
        buf[(i << 1) + 1] = val                         // sin[0..511]
        buf[((i + 512) << 1) + 1] = -val                 // sin[512..1023] = -sin[0..511]

        // Rotation: [u', v'] = [u·c - v·s, u·s + v·c]
        let t = (u * s + v * c + rnd) >> 30
        u = (u * c - v * s + rnd) >> 30
        v = t
    }

    // Compute deltas: delta[i] = value[i+1] - value[i]
    for i in 0..<1023 {
        buf[i << 1] = buf[(i << 1) + 3] - buf[(i << 1) + 1]
    }
    buf[2046] = -buf[2047]  // Last delta wraps around

    return UnsafePointer(buf)
}()

// MARK: - Sin Lookup Function

/// Q24 sine lookup with 14-bit linear interpolation.
/// Input: Q24 phase (full cycle = 2^24 = 16777216).
/// Output: Q24 amplitude (range ±2^24).
@inline(__always)
package func sinLookupQ24(_ phase: Int32) -> Int32 {
    let lowbits = Int(phase) & ((1 << 14) - 1)     // 14-bit fraction for interpolation
    let phaseIdx = (Int(phase) >> 13) & 2046         // 10-bit index * 2 (interleaved)
    let dy = Int(kSinTab[phaseIdx])                  // delta
    let y0 = Int(kSinTab[phaseIdx + 1])              // base value
    return Int32(y0 + ((dy * lowbits) >> 14))        // linear interpolation
}
