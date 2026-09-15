// DX7Envelope.swift
// M2DX-Core — DX7 4-rate/4-level envelope generator (Int32 Q16)

// MARK: - DX7 Envelope Generator

/// DX7 envelope generator using Int32 Q16 level representation.
/// level: 0 = silence, higher = louder.
/// Gain derived as: exp2LookupQ24(level - 14×(1<<24))
/// Called once per N=64 block via getsample(), not per-sample.
package struct DX7Envelope {
    /// EG state: -1=idle, 0..3 = stages (R1L1, R2L2, R3L3, R4L4)
    var ix: Int = -1
    var level: Int32 = 0
    var targetLevel: Int32 = 0
    var rising: Bool = false
    var inc: Int32 = 0
    var down: Bool = false  // true = key pressed, false = key released

    var rates: (Int, Int, Int, Int) = (99, 75, 50, 50)
    var levels: (Int, Int, Int, Int) = (99, 80, 70, 0)
    var outlevel: Int = 4064  // microsteps: scaleOutputLevel(OL) << 5
    // Keep attenuation separate from the running EG so crossing the silence floor
    // cannot finish an attack/decay/release early. Always <= 0; louder edits rebase.
    private var liveOutputOffset: Int = 0
    var rateScaling: Int = 0

    var srMultiplier: Int64 = 1 << 24  // Q24: (44100/sampleRate) × (1<<24)

    var isActive: Bool { ix >= 0 }

    mutating func setSampleRate(_ sr: Float) {
        srMultiplier = Int64(Double(44100.0) / Double(sr) * Double(1 << 24))
        recalcCurrentInc()
    }

    mutating func setRates(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        rates = (min(99, max(0, a)), min(99, max(0, b)),
                 min(99, max(0, c)), min(99, max(0, d)))
        recalcCurrentInc()
    }

    mutating func setLevels(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        let next = (min(99, max(0, a)), min(99, max(0, b)),
                    min(99, max(0, c)), min(99, max(0, d)))
        guard levels != next else { return }
        if ix == 3 && down {
            // Sustain holds L3. Move the held level by the L3 change only: a legato retarget
            // keeps the level of the previous key's KLS (DX7Voice.legatoTo), and that deviation
            // from the trajectory's L3 must survive an EG edit. L4-only edits leave it alone.
            let l3Delta = levelFor(next.2, output: referenceOutput)
                &- levelFor(levels.2, output: referenceOutput)
            level = max(16 << 16, level &+ l3Delta)
        }
        levels = next
        recalcTargetLevel()
    }

    /// Output the running trajectory was computed against; `liveOutputOffset` is applied on top.
    private var referenceOutput: Int { outlevel - liveOutputOffset }

    /// Configure the base level; sounding-operator edits use updateOutputLevel.
    mutating func setOutputLevel(_ ol: Int) {
        outlevel = scaleOutputLevel(ol) << 5
        liveOutputOffset = 0
    }

    /// Change the output offset of a running envelope without restarting its stage.
    /// The FM kernels ramp the resulting gain/attenuation over the next block.
    mutating func updateOutputLevel(_ microsteps: Int) {
        let delta = microsteps - outlevel
        guard delta != 0 else { return }
        outlevel = microsteps
        guard ix >= 0, ix < 4 else { liveOutputOffset = 0; return }

        liveOutputOffset += delta
        if liveOutputOffset > 0 {
            // A positive offset at the end of release would lift its silence floor.
            // Rebase upward instead, keeping the current stage and natural tail.
            // Sustain rises by its L3 difference (a floor-clamped L3 carries no offset), other
            // stages by the offset; either way the held level's deviation from the trajectory
            // (a legato retarget) is kept, so one OL step moves the output by one step.
            let rise = ix == 3 && down
                ? levelFor(levels.2, output: outlevel) &- levelFor(levels.2, output: referenceOutput)
                : Int32(liveOutputOffset << 16)
            // A legato note may retain a level from stronger KLS; do not add the boost on top
            // of it beyond the current note's full-scale EG level, and never lower it here.
            level = min(level &+ rise, max(level, levelFor(99, output: outlevel)))
            liveOutputOffset = 0
            recalcTargetLevel()
        }
    }

    /// KLS changes affect both the edited OL and the reference OL. Recompute their
    /// difference instead of carrying an offset through the keyboard's OL ceiling.
    mutating func updateKeyboardOutputLevel(_ microsteps: Int, reference: Int) {
        outlevel = microsteps
        liveOutputOffset = microsteps - reference
        recalcTargetLevel()
    }

    mutating func noteOn() {
        liveOutputOffset = 0
        level = 0
        down = true
        advance(0)
    }

    mutating func noteOff(held: Bool = false) {
        if held { return }
        if ix >= 0 {
            // The offset stays in force through the release: the trajectory keeps its full
            // length, so a muted note that is restored mid-release still has its tail.
            down = false
            advance(3)
        }
    }

    /// Process one block — returns level (Q16).
    @inline(__always)
    mutating func getsample() -> Int32 {
        guard ix >= 0 else { return 0 }

        if ix < 3 || (ix < 4 && !down) {
            if rising {
                // Attack
                let jumpTarget: Int32 = 1716
                if level < (jumpTarget << 16) {
                    level = jumpTarget << 16
                }
                // Wrapping narrowing matches the C reference's (int32_t) cast. At
                // standard rates the value fits in Int32 (no truncation); at very
                // low base sample rates `inc` inflates and a plain Int32(...) would
                // trap on the render thread instead of wrapping.
                let step = Int32(truncatingIfNeeded: ((Int64(17 << 24) - Int64(level)) >> 24) * Int64(inc))
                level = level &+ step
                if level >= targetLevel {
                    level = targetLevel
                    advance(ix + 1)
                }
            } else {
                // Decay/Release
                level = level &- inc
                if level <= targetLevel {
                    level = targetLevel
                    advance(ix + 1)
                }
            }
        }

        // No fixed 2 s wall-clock release kill (which truncated + clicked slow release tails,
        // and which neither the real DX7 nor the DEXED C twin have): the release runs to its
        // natural completion (advance(4) → ix = -1 at the L4 floor), bit-exactly matching the
        // DEXED reference EG trace. Voice slots for long releases are reclaimed by voice
        // stealing, not a wall-clock guillotine. (#92)
        return outputSample()
    }

    @inline(__always)
    private func levelFor(_ egLevel: Int, output: Int) -> Int32 {
        Int32(max(16, ((scaleOutputLevel(egLevel) >> 1) << 6) + output - 4256) << 16)
    }

    @inline(__always)
    private func outputSample() -> Int32 {
        guard liveOutputOffset != 0 else { return level }
        // The offset is only ever <= 0 here (louder edits rebase `level`), so this also
        // covers a sustain whose held level came from another key's KLS.
        return max(16 << 16, level &+ Int32(liveOutputOffset << 16))
    }

    private mutating func advance(_ newIx: Int) {
        ix = newIx
        guard ix < 4 else { ix = -1; return }

        let newLevel: Int
        switch ix {
        case 0: newLevel = levels.0
        case 1: newLevel = levels.1
        case 2: newLevel = levels.2
        case 3: newLevel = levels.3
        default: newLevel = 0
        }

        targetLevel = levelFor(newLevel, output: outlevel - liveOutputOffset)
        rising = targetLevel > level

        if targetLevel == level {
            // Stage 3 (release) must not auto-advance while key is held.
            // DX7 sustains at L3 level until key release, even when L3 == L4.
            if ix == 3 && down { return }
            advance(ix + 1)
            return
        }

        let rate: Int
        switch ix {
        case 0: rate = rates.0
        case 1: rate = rates.1
        case 2: rate = rates.2
        case 3: rate = rates.3
        default: rate = 0
        }

        var qrate = (rate * 41) >> 6
        qrate = min(63, qrate + rateScaling)
        let rawInc = (4 + (qrate & 3)) << (8 + (qrate >> 2))
        inc = Int32(truncatingIfNeeded: (Int64(rawInc) * srMultiplier) >> 24)
    }

    mutating func recalcCurrentInc() {
        guard ix >= 0, ix < 4 else { return }
        let rate: Int
        switch ix {
        case 0: rate = rates.0
        case 1: rate = rates.1
        case 2: rate = rates.2
        case 3: rate = rates.3
        default: rate = 0
        }
        var qrate = (rate * 41) >> 6
        qrate = min(63, qrate + rateScaling)
        let rawInc = (4 + (qrate & 3)) << (8 + (qrate >> 2))
        inc = Int32(truncatingIfNeeded: (Int64(rawInc) * srMultiplier) >> 24)
    }

    /// Recalculate targetLevel for current stage after outlevel changes.
    mutating func recalcTargetLevel() {
        guard ix >= 0, ix < 4 else { return }
        let newLevel: Int
        switch ix {
        case 0: newLevel = levels.0
        case 1: newLevel = levels.1
        case 2: newLevel = levels.2
        case 3: newLevel = levels.3
        default: newLevel = 0
        }
        targetLevel = levelFor(newLevel, output: outlevel - liveOutputOffset)
        rising = targetLevel > level
    }
}
