// Dx7refmkiSmokeTests.swift
import Testing
@testable import M2DXCore
import DX7Ref

@Suite("dx7refmki smoke")
struct Dx7refmkiSmokeTests {
    @Test("reference renders non-silent audio for INIT carrier") func renders() {
        var patch = [UInt8](repeating: 0, count: 156)
        // patch op i (bytes i*21..) maps directly to alg flag i (DEXED/dx7ref
        // convention). For Alg 1, the carrier reaching `output` is op index 5
        // (flags 0x14), so make THAT op an INIT carrier — bytes at offset 105.
        let off = 5 * 21
        // EG R1..R4 = 99 (instant attack/sustain), L1..L4 = 99 (full level).
        for i in 0..<4 { patch[off + i] = 99 }       // rates
        for i in 0..<4 { patch[off + 4 + i] = 99 }   // levels
        patch[off + 16] = 99  // output level
        patch[off + 18] = 1   // coarse
        patch[off + 20] = 7   // detune center
        patch[134] = 0; patch[135] = 0
        var v = dx7refmki_voice_t()
        dx7refmki_freq_init(48000)
        patch.withUnsafeBufferPointer { dx7refmki_voice_init(&v, $0.baseAddress!, 60, 100, 48000) }
        let buf = UnsafeMutablePointer<Int32>.allocate(capacity: 64); defer { buf.deallocate() }
        buf.initialize(repeating: 0, count: 64)
        dx7refmki_voice_render(&v, buf)
        #expect((0..<64).contains { buf[$0] != 0 })
    }
}
