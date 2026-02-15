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
    var rateScaling: Int = 0

    var srMultiplier: Int64 = 1 << 24  // Q24: (44100/sampleRate) × (1<<24)

    var releaseBlockCount: Int = 0
    var releaseTimeoutBlocks: Int = 1378  // ~2s at 44.1kHz

    var isActive: Bool { ix >= 0 }

    mutating func setSampleRate(_ sr: Float) {
        srMultiplier = Int64(Double(44100.0) / Double(sr) * Double(1 << 24))
        releaseTimeoutBlocks = Int(sr * 2.0) / kBlockSize
        recalcCurrentInc()
    }

    mutating func setRates(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        rates = (min(99, max(0, a)), min(99, max(0, b)),
                 min(99, max(0, c)), min(99, max(0, d)))
        recalcCurrentInc()
    }

    mutating func setLevels(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
        levels = (min(99, max(0, a)), min(99, max(0, b)),
                  min(99, max(0, c)), min(99, max(0, d)))
    }

    mutating func setOutputLevel(_ ol: Int) {
        outlevel = scaleOutputLevel(ol) << 5
    }

    mutating func noteOn() {
        level = 0
        down = true
        releaseBlockCount = 0
        advance(0)
    }

    mutating func noteOff(held: Bool = false) {
        if held { return }
        if ix >= 0 {
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
                let step = Int32(((Int64(17 << 24) - Int64(level)) >> 24) * Int64(inc))
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

        if !down {
            releaseBlockCount += 1
            if releaseBlockCount >= releaseTimeoutBlocks {
                level = 0; ix = -1
            }
        }

        return level
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

        var actualLevel = ((scaleOutputLevel(newLevel) >> 1) << 6) + outlevel - 4256
        actualLevel = max(16, actualLevel)
        targetLevel = Int32(actualLevel << 16)
        rising = targetLevel > level

        if targetLevel == level {
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

        var qrate = min(63, (rate * 41) >> 6)
        qrate = min(63, qrate + rateScaling)
        let rawInc = (4 + (qrate & 3)) << (8 + (qrate >> 2))
        inc = Int32((Int64(rawInc) * srMultiplier) >> 24)
    }

    private mutating func recalcCurrentInc() {
        guard ix >= 0, ix < 4 else { return }
        let rate: Int
        switch ix {
        case 0: rate = rates.0
        case 1: rate = rates.1
        case 2: rate = rates.2
        case 3: rate = rates.3
        default: rate = 0
        }
        var qrate = min(63, (rate * 41) >> 6)
        qrate = min(63, qrate + rateScaling)
        let rawInc = (4 + (qrate & 3)) << (8 + (qrate >> 2))
        inc = Int32((Int64(rawInc) * srMultiplier) >> 24)
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
        var actualLevel = ((scaleOutputLevel(newLevel) >> 1) << 6) + outlevel - 4256
        actualLevel = max(16, actualLevel)
        targetLevel = Int32(actualLevel << 16)
        rising = targetLevel > level
    }
}
