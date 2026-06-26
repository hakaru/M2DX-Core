// LayerTests.swift — TX816 layer mode: routing, partition, per-slot level/pan
import Testing
import Darwin
@testable import M2DXCore

@MainActor
@Suite("TX816 Layer")
struct LayerTests {

    private func makeEngine() -> SynthEngine {
        let e = SynthEngine()
        e.setSampleRate(48000)
        return e
    }
    private func render(_ e: SynthEngine, _ n: Int = 64) {
        let l = UnsafeMutablePointer<Float>.allocate(capacity: n)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: n)
        defer { l.deallocate(); r.deallocate() }
        e.render(into: l, bufferR: r, frameCount: n)
    }

    @Test("layer mode routes a note to every enabled slot")
    func layerRoutesToAllEnabledSlots() {
        let e = makeEngine()
        e.setTimbreMode(.layer)
        e.setSlotEnabled(0, enabled: true)
        e.setSlotEnabled(1, enabled: true)
        e.setSlotEnabled(2, enabled: true)
        for i in 3..<8 { e.setSlotEnabled(i, enabled: false) }
        render(e) // apply snapshot
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        render(e)
        #expect(Set(e.activeVoiceSlotIds()) == [0, 1, 2], "one note → one voice in each of the 3 enabled slots")
    }

    @Test("setLayerPartition enables P slots, sets unison U, layer mode")
    func partitionSetsSlotsAndUnison() {
        let e = makeEngine()
        e.setLayerPartition(parts: 4, unison: 2, detuneCents: 6)
        render(e)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        render(e)
        // 4 distinct slots, 8 total voices (4 parts × 2 unison)
        #expect(Set(e.activeVoiceSlotIds()) == [0, 1, 2, 3])
        #expect(e.activeVoiceCount == 8)
    }

    /// RED→GREEN regression for the seed fix: setLayerPartition raises
    /// activeSlotCount from the engine default (.single = 1) up to kMaxSlots and
    /// enables the first P slots. Without seeding those newly-activated slots with
    /// slot 0's patch (parity with setTimbreMode), slots 1..P-1 would render a
    /// default SlotSnapshot (every operator ratio = 1.0 → all operator frequencies
    /// equal the base note frequency) instead of slot 0's distinctive patch.
    ///
    /// We load a distinctive patch (FAT BASS — non-1.0 operator coarse ratios)
    /// into slot 0 on a FRESH engine still at activeSlotCount = 1, partition to
    /// 4 parts × 1 unison, then assert every active voice across slots 0..3 shares
    /// slot 0's per-operator frequency set. Pre-fix, slots 1..3 carry default
    /// ratios and this fails.
    @Test("setLayerPartition seeds layered slots with slot 0's patch")
    func partitionSeedsSlotZeroPatch() {
        let e = makeEngine()
        // Distinctive patch with non-default operator ratios (coarse 2/3/9 etc.).
        let fatBass = DX7FactoryPresets.all.first { $0.name == "FAT BASS" }
        #expect(fatBass != nil, "expected FAT BASS factory preset")
        e.loadDX7Preset(fatBass!, slotIdx: 0)   // engine still at activeSlotCount = 1
        e.setLayerPartition(parts: 4, unison: 1, detuneCents: 0)
        render(e) // apply snapshot
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        render(e)

        #expect(Set(e.activeVoiceSlotIds()) == [0, 1, 2, 3])
        #expect(e.activeVoiceCount == 4)

        // Every active voice (one per slot) must carry slot 0's operators. Each
        // operator's frequency, summed across all 4 active voices, must equal
        // 4× slot 0's value — i.e. all four slots resolve to the SAME patch. With
        // unseeded default slots, modulator operators would collapse to the base
        // frequency and break this equality for ≥1 operator index.
        for opIdx in 0..<6 {
            let freqs = e.activeVoiceOperatorFreqs(opIdx)
            #expect(freqs.count == 4, "op \(opIdx): expected 4 active voices")
            guard let ref = freqs.first else { continue }
            #expect(ref > 0, "op \(opIdx): reference frequency should be non-zero")
            for f in freqs {
                #expect(abs(f - ref) < 1e-3,
                        "op \(opIdx): all layered slots must share slot 0's frequency (got \(f) vs \(ref))")
            }
        }
    }

    /// Re-partitioning while already at activeSlotCount = kMaxSlots must NOT
    /// re-clobber already-loaded slot patches. The `kMaxSlots > prev` guard skips
    /// the seed loop on the second call, so a patch loaded into slot 1 after the
    /// first partition survives the second partition.
    @Test("re-partition at activeSlotCount = 8 does not clobber loaded slots")
    func repartitionDoesNotClobberLoadedSlots() {
        let e = makeEngine()
        e.setLayerPartition(parts: 4, unison: 1, detuneCents: 0) // activeSlotCount → 8
        // Load a distinctive patch into slot 1 (now within activeSlotCount).
        let fatBass = DX7FactoryPresets.all.first { $0.name == "FAT BASS" }!
        e.loadDX7Preset(fatBass, slotIdx: 1)
        // Re-partition: prev == kMaxSlots, so the seed loop is skipped and slot 1
        // keeps its FAT BASS patch instead of being overwritten with slot 0.
        e.setLayerPartition(parts: 2, unison: 1, detuneCents: 0)
        render(e)
        e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
        render(e)
        // 2 parts → slots 0 and 1 active.
        #expect(Set(e.activeVoiceSlotIds()) == [0, 1])
        // Slot 1 carries FAT BASS (distinctive ratios), slot 0 is INIT-like, so at
        // least one operator's frequency differs between the two voices — proving
        // the re-partition did not flatten slot 1 onto slot 0.
        var anyDiff = false
        for opIdx in 0..<6 {
            let freqs = e.activeVoiceOperatorFreqs(opIdx)
            if freqs.count == 2, abs(freqs[0] - freqs[1]) > 1e-3 { anyDiff = true }
        }
        #expect(anyDiff, "re-partition must preserve slot 1's distinct patch")
    }

    @Test("setSlotLevel scales a slot's rendered output")
    func slotLevelScalesOutput() {
        func peak(gain: Float) -> Float {
            let e = makeEngine()
            // Load a clearly audible factory patch into slot 0 so `full` is
            // comfortably non-zero, then balance the layer to a single part so
            // layer auto-gain = 1/sqrt(1) = 1 and doesn't perturb the ratio.
            let fatBass = DX7FactoryPresets.all.first { $0.name == "FAT BASS" }!
            e.loadDX7Preset(fatBass, slotIdx: 0)
            e.setLayerPartition(parts: 1, unison: 1)
            e.setSlotLevel(0, gain: gain)
            let n = 256
            let l = UnsafeMutablePointer<Float>.allocate(capacity: n)
            let r = UnsafeMutablePointer<Float>.allocate(capacity: n)
            defer { l.deallocate(); r.deallocate() }
            e.render(into: l, bufferR: r, frameCount: n)   // apply
            e.sendMIDI(MIDIEvent(kind: .noteOn, data1: 60, data2: UInt32(0x7F00)))
            var pk: Float = 0
            for _ in 0..<8 {
                e.render(into: l, bufferR: r, frameCount: n)
                for i in 0..<n { pk = max(pk, abs(l[i])) }
            }
            return pk
        }
        let full = peak(gain: 1.0), half = peak(gain: 0.5)
        #expect(half < full * 0.6 && half > full * 0.4, "gain 0.5 → ~half peak (\(half) vs \(full))")
    }
}
