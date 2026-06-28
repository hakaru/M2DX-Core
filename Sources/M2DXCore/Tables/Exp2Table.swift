// Exp2Table.swift
// M2DX-Core — Q30 exp2 lookup table (1024 entries, delta+value interleaved)
// exp2 values self-generated (2^x); Q30 interpolation matches DEXED parity (Apache-2.0); see NOTICE.

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
    let lowbits = Int32(x) & ((1 << 14) - 1)         // 14-bit fraction
    let xIdx = Int((x >> 13) & 2046)                  // 10-bit index * 2 (interleaved)
    let dy = kExp2Tab[xIdx]                            // delta (Int32)
    let y0 = kExp2Tab[xIdx + 1]                        // base value (Q30, Int32)
    // DEXED uses 32-bit int arithmetic; the interpolation below matches its
    // wrapping multiply/add exactly. The shift<=0 branch additionally *saturates*
    // (Int32(clamping:)) rather than reproducing the reference's signed-overflow
    // wrap — a deliberate, safer deviation. That branch is unreachable for in-spec
    // levels (x stays <= ~3<<24, i.e. shift >= 3), so it never affects DEXED parity.
    let interpol = (dy &* lowbits) >> 14               // Int32 wrapping multiply
    let y = Int(y0 &+ interpol)                        // Int32 wrapping add, then widen
    let shift = 6 - (Int(x) >> 24)                    // integer part determines octave shift
    if shift >= 31 { return 0 }
    if shift <= 0 { return Int32(clamping: y << (-shift)) }  // saturating (see note above)
    return Int32(y >> shift)                           // Q30 → Q24 with octave adjustment
}
