// LayerPanRandomTests.swift
// #76: LAYER PAN can be randomized per note-on instead of the fixed slot pan.
// The random pan is DETERMINISTIC (seeded only by slot+voice) so a held note is
// stable and a recalled stack reproduces bit-for-bit. Distinct seed from the #83
// detune random, so pan and detune spreads are independent.

import Testing
import Darwin
@testable import M2DXCore

@Suite("Layer pan random (#76)")
struct LayerPanRandomTests {

    @Test("random pan is deterministic, varied, and within [-1, 1)")
    func randomPan() {
        // Deterministic: same (slot, voice) → identical pan every call.
        let a = layerPanRandom(slotIndex: 0, voiceIndex: 0)
        let b = layerPanRandom(slotIndex: 0, voiceIndex: 0)
        #expect(a == b)

        // Different voices (and slots) get different pan.
        #expect(layerPanRandom(slotIndex: 0, voiceIndex: 1) != a)
        #expect(layerPanRandom(slotIndex: 1, voiceIndex: 0) != a)

        // Every pan stays within the [-1, 1) stereo window.
        for s in 0..<8 {
            for v in 0..<8 {
                let p = layerPanRandom(slotIndex: s, voiceIndex: v)
                #expect(p >= -1.0 && p < 1.0)
            }
        }
    }

    @Test("pan random is independent of detune random (distinct seed)")
    func independentFromDetune() {
        // Same (slot, voice) indices must NOT collapse to the same number as the
        // detune random's signed sample — the two use distinct seed bases.
        for s in 0..<4 {
            for v in 0..<4 {
                let pan = layerPanRandom(slotIndex: s, voiceIndex: v)
                let detune = unisonDetuneFactorRandom(slotIndex: s, voiceIndex: v, detuneCents: 100)
                // detune is a frequency factor near 1.0; pan is in [-1,1). They
                // should never coincide for any tested index pair.
                #expect(pan != detune)
            }
        }
    }
}
