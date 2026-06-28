// UnisonDetuneRandomTests.swift
// #83: LAYER/unison DETUNE can spread voices RANDOMLY instead of the even
// linear pattern. The random spread is DETERMINISTIC (seeded only by slot+voice)
// so a held note is stable and a recalled stack reproduces bit-for-bit.

import Testing
import Darwin
@testable import M2DXCore

@Suite("Unison detune random (#83)")
struct UnisonDetuneRandomTests {

    @Test("random spread is deterministic, varied, and within ±detune")
    func randomSpread() {
        let d: Float = 10.0   // cents

        // Deterministic: same (slot, voice) → identical factor every call.
        let a = unisonDetuneFactorRandom(slotIndex: 0, voiceIndex: 0, detuneCents: d)
        let b = unisonDetuneFactorRandom(slotIndex: 0, voiceIndex: 0, detuneCents: d)
        #expect(a == b)

        // Different voices (and slots) get different spread.
        #expect(unisonDetuneFactorRandom(slotIndex: 0, voiceIndex: 1, detuneCents: d) != a)
        #expect(unisonDetuneFactorRandom(slotIndex: 1, voiceIndex: 0, detuneCents: d) != a)

        // Every voice stays within the ±d cents window [exp2(-d/1200), exp2(+d/1200)).
        let lo = exp2(-d / 1200.0), hi = exp2(d / 1200.0)
        for v in 0..<8 {
            let f = unisonDetuneFactorRandom(slotIndex: 2, voiceIndex: v, detuneCents: d)
            #expect(f >= lo && f < hi)
        }

        // Not the mechanical even pattern (at least one voice differs from even).
        let evenV1 = unisonDetuneFactor(index: 1, count: 8, detuneCents: d)
        let randV1 = unisonDetuneFactorRandom(slotIndex: 0, voiceIndex: 1, detuneCents: d)
        #expect(evenV1 != randV1)

        // d == 0 → exactly 1.0 (no detune), both modes.
        #expect(unisonDetuneFactorRandom(slotIndex: 0, voiceIndex: 3, detuneCents: 0) == 1.0)
    }
}
