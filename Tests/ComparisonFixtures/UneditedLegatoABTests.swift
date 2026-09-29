// Opt-in cross-revision comparison fixture (M2DX #112).
// Copy this file into Tests/M2DXCoreTests in two independent Core checkouts,
// run `swift test -c release --filter UneditedLegatoABTests` in each, then
// compare the 48 UNEDITED CSV lines. Remove the copied files afterward.
// The hashes intentionally are not portable golden assertions (libm/toolchain
// differences); compare both revisions on the same machine and toolchain.
// 2026-09-29: v1.22.0 vs cc2650f + atomic host sample-rate publication:
// all 48 complete stereo sample streams were bit-identical.

import CryptoKit
import Foundation
import Testing
@testable import M2DXCore

@Suite("Unedited legato 1.22.0 comparison", .serialized)
struct UneditedLegatoABTests {
    @Test("render without editing across attack, sustain, legato retarget and release")
    func compare() {
        for mode in [FMEngine.modern, .markI] {
            for curve in 0...3 {
                for l4 in [0, 60, 99] {
                    for ol in [55, 99] {
                        let s = SynthEngine()
                        s.setSampleRate(48000)
                        s.setFMEngine(mode)
                        s.setMonoPerformance(enabled: true, portamentoMode: .fingered, glissando: false)
                        let ops = (0..<6).map { i in
                            i == 5 ? DX7OperatorPreset(outputLevel: ol, egRate1: 75, egRate2: 65, egRate3: 70,
                                egRate4: 45, egLevel1: 99, egLevel2: 90, egLevel3: 75, egLevel4: l4,
                                klsBreakPoint: 39, klsLeftDepth: 60, klsRightDepth: 60,
                                klsLeftCurve: curve, klsRightCurve: curve)
                                : DX7OperatorPreset(outputLevel: 0)
                        }
                        s.loadDX7Preset(DX7Preset(name: "Unedited", algorithm: 31, feedback: 0, operators: ops, category: .other))
                        var hash = SHA256()
                        var left = [Float](repeating: 0, count: 64), right = left
                        func render(_ blocks: Int) {
                            for _ in 0..<blocks {
                                left.withUnsafeMutableBufferPointer { l in
                                    right.withUnsafeMutableBufferPointer { r in
                                        s.render(into: l.baseAddress!, bufferR: r.baseAddress!, frameCount: 64)
                                    }
                                }
                                left.withUnsafeBytes { hash.update(data: $0) }
                                right.withUnsafeBytes { hash.update(data: $0) }
                            }
                        }
                        func on(_ note: UInt8) { s.sendMIDI(MIDIEvent(kind: .noteOn, data1: note, data2: UInt32(100) << 9)) }
                        func off(_ note: UInt8) { s.sendMIDI(MIDIEvent(kind: .noteOff, data1: note, data2: 0)) }
                        render(1)
                        on(36); render(1) // Retarget before L3 is reached.
                        on(96); render(1600)
                        on(72); render(80) // Retarget again while held at L3.
                        off(96); off(72); render(80) // Return to the first held key.
                        off(36); render(1600)
                        print("UNEDITED,\(mode),\(curve),\(l4),\(ol),\(hash.finalize())")
                    }
                }
            }
        }
    }
}
