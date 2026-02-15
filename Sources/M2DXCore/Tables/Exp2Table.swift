// Exp2Table.swift
// M2DX-Core — Q30 exp2 lookup table (1024 entries, delta+value interleaved)
// Self-generated from mathematical definition. No external code referenced.

import Darwin

// MARK: - Q30 Exp2 Table

/// Q30 exp2 table: 2048 entries (1024 delta+value pairs interleaved).
/// exp2Tab[2*i+1] = 2^(i/1024) × 2^30
/// exp2Tab[2*i] = delta to next entry
///
/// Used for converting log-domain levels to linear gain.
nonisolated(unsafe) let kExp2Tab: UnsafePointer<Int32> = {
    let count = 2048  // 1024 * 2 (delta + value interleaved)
    let buf = UnsafeMutablePointer<Int32>.allocate(capacity: count)
    buf.initialize(repeating: 0, count: count)

    let inc = Darwin.exp2(1.0 / 1024.0)  // 2^(1/1024)
    var y = Double(1 << 30)               // 1.0 in Q30

    for i in 0..<1024 {
        buf[(i << 1) + 1] = Int32(Darwin.floor(y + 0.5))
        y *= inc
    }

    // Compute deltas
    for i in 0..<1023 {
        buf[i << 1] = buf[(i << 1) + 3] - buf[(i << 1) + 1]
    }
    // Last delta: wraps to next octave (2^31 - last_value)
    buf[2046] = Int32(bitPattern: UInt32(1 << 31) &- UInt32(bitPattern: buf[2047]))

    return UnsafePointer(buf)
}()

// MARK: - Exp2 Lookup Function

/// Q24 log level → Q24 amplitude conversion via exp2.
/// Input: x = level in doublings (Q24). Larger x = louder.
///   x = 0 → output ≈ 2^24 (1.0)
///   x = 1<<24 → output ≈ 2^25 (2.0)
///   x = -(1<<24) → output ≈ 2^23 (0.5)
///
/// Typical usage: gain = exp2LookupQ24(egLevel - 14*(1<<24))
@inline(__always)
package func exp2LookupQ24(_ x: Int32) -> Int32 {
    let lowbits = Int(x) & ((1 << 14) - 1)          // 14-bit fraction
    let xIdx = (Int(x) >> 13) & 2046                 // 10-bit index * 2 (interleaved)
    let dy = Int(kExp2Tab[xIdx])                      // delta
    let y0 = Int(kExp2Tab[xIdx + 1])                  // base value (Q30)
    let y = y0 + ((dy * lowbits) >> 14)               // linear interpolation (Q30)
    let shift = 6 - (Int(x) >> 24)                    // integer part determines octave shift
    if shift >= 31 { return 0 }
    if shift <= 0 { return Int32(clamping: y << (-shift)) }
    return Int32(y >> shift)                           // Q30 → Q24 with octave adjustment
}
