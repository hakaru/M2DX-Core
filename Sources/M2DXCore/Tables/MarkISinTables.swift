// MarkISinTables.swift
// M2DX-Core — DX7 OPS-chip log-sine + exp tables (Mark I engine).
// Clean-room from public OPS math; see DX7MarkI_PROVENANCE.md. Not from GPL EngineMkI.cpp.
import Darwin

/// Log-sine first-quadrant table, 1024 entries. Index folding + a sign bit
/// produce the other quadrants in `mkiSin`. Read-only after init.
let kSinLogLUT: [UInt16] = {
    var t = [UInt16](repeating: 0, count: 1024)
    for i in 0..<1024 {
        let x = Darwin.sin(((0.5 + Double(i)) / 1024.0) * Double.pi / 2.0)
        t[i] = UInt16((-1024.0 * Darwin.log2(x)).rounded())
    }
    return t
}()

/// Exponential table, 1024 entries. Read-only after init.
let kSinExpLUT: [UInt16] = {
    var t = [UInt16](repeating: 0, count: 1024)
    for i in 0..<1024 {
        t[i] = UInt16(((Darwin.pow(2.0, Double(i) / 1024.0) - 1.0) * 4096.0).rounded())
    }
    return t
}()

/// Force both tables to materialize off the audio thread before first Mark I render.
func markIPrewarm() { _ = kSinLogLUT[0]; _ = kSinExpLUT[0] }
