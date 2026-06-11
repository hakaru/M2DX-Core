// Archetype.swift
// PresetLabKit — per-preset archetype mapping + target evaluation.
//
// Encodes the archetype target table from
// docs/superpowers/specs/2026-06-11-preset-quality-design.md §3.2 (M2DX repo).
// Targets are original engineering numbers from general acoustics/FM knowledge.

import Foundation

/// Sound-design archetype for a bundled factory preset.
public enum Archetype: String, CaseIterable, Sendable {
    case ep, bell, mallet, bass, brass, pad, organ, lead, wind, exempt

    // MARK: - Preset name → archetype (explicit table, spec §3.2)

    private static let table: [String: Archetype] = {
        var t: [String: Archetype] = [:]
        for i in 1...10 { t["E.PIANO \(i)"] = .ep }
        t["DIGI PIANO"] = .ep
        for n in ["TINE BELL", "GLASS BELL", "ICY BELL", "CHURCHBELL"] { t[n] = .bell }
        for n in ["VIBES", "MARIMBA", "XYLO", "KALIMBA"] { t[n] = .mallet }
        for n in ["FAT BASS", "SLAP BASS", "SUB BASS", "SYN BASS"] { t[n] = .bass }
        for n in ["BRASS", "TRUMPET", "TROMBONE"] { t[n] = .brass }
        for n in ["STRINGS", "PAD WARM", "PAD GLASS"] { t[n] = .pad }
        for n in ["ORGAN 1", "ORGAN 2", "ORGAN 3"] { t[n] = .organ }
        for n in ["LEAD SAW", "LEAD SQR"] { t[n] = .lead }
        for n in ["FLUTE", "OBOE"] { t[n] = .wind }
        for n in ["INIT VOICE", "INIT SINE", "RANDOM"] { t[n] = .exempt }
        return t
    }()

    /// Explicit mapping of factory preset names. Unknown name → nil.
    public static func forPresetName(_ name: String) -> Archetype? {
        table[name]
    }

    // MARK: - Render protocol (spec §3.1 / §3.2 Note column)

    /// Archetype-default base note (per-preset exceptions live in `baseNote(for:)`).
    public var baseNote: UInt8 {
        switch self {
        case .bass: return 36   // C2
        case .bell: return 72   // C5
        default:    return 60   // C4
        }
    }

    /// Base note for a specific preset. Handles the spec's per-PRESET exceptions
    /// (MARIMBA & TROMBONE at C3, FLUTE at C5); everything else uses the
    /// archetype default. Unknown names fall back to C4.
    public static func baseNote(for presetName: String) -> UInt8 {
        switch presetName {
        case "MARIMBA", "TROMBONE": return 48   // C3
        case "FLUTE":               return 72   // C5
        default:                    return forPresetName(presetName)?.baseNote ?? 60
        }
    }

    /// noteOff time: percussive archetypes (bell/mallet) get a short gate —
    /// the natural decay is the product; everything else sustains to 1.5 s.
    public var noteOffSeconds: Double {
        switch self {
        case .bell, .mallet: return 0.15
        default:             return 1.5
        }
    }

    // MARK: - Target evaluation (spec §3.2, one row per archetype)

    /// Returns one human-readable string per violated target.
    /// EXEMPT presets have no archetype targets (hard gates are applied
    /// globally in the report layer).
    public func violations(_ m: PresetMetrics) -> [String] {
        var v: [String] = []

        func f1(_ x: Float) -> String { String(format: "%.1f", x) }
        func f2(_ x: Float) -> String { String(format: "%.2f", x) }

        func attackIn(_ lo: Float, _ hi: Float) {
            if m.attackMs < lo || m.attackMs > hi {
                v.append("attack \(f1(m.attackMs))ms outside \(f1(lo))-\(f1(hi))ms")
            }
        }
        func attackAtMost(_ hi: Float) {
            if m.attackMs > hi { v.append("attack \(f1(m.attackMs))ms above \(f1(hi))ms") }
        }
        func brightAtLeast(_ lo: Float) {
            if m.velocityBrightnessDelta < lo {
                v.append("velBrightΔ \(f2(m.velocityBrightnessDelta)) below \(f2(lo))")
            }
        }
        func brightAtMost(_ hi: Float) {
            if m.velocityBrightnessDelta > hi {
                v.append("velBrightΔ \(f2(m.velocityBrightnessDelta)) above \(f2(hi))")
            }
        }
        func levelAtLeast(_ lo: Float) {
            if m.velocityLevelDeltaDB < lo {
                v.append("velLevelΔ \(f1(m.velocityLevelDeltaDB))dB below \(f1(lo))dB")
            }
        }
        func levelAtMost(_ hi: Float) {
            if m.velocityLevelDeltaDB > hi {
                v.append("velLevelΔ \(f1(m.velocityLevelDeltaDB))dB above \(f1(hi))dB")
            }
        }
        func sparkleAtLeast(_ lo: Float) {
            if m.sparkleIndex < lo { v.append("sparkle \(f2(m.sparkleIndex)) below \(f2(lo))") }
        }

        switch self {
        case .ep:
            attackIn(3, 20)
            brightAtLeast(1.4)
            levelAtLeast(6)
            sparkleAtLeast(2.0)
            // Sustain shelf: RMS@1.2s within −20..−6 dB relative to 0.3s.
            let rel = m.rmsAt1_2 - m.rmsAt0_3
            if rel < -20 || rel > -6 {
                v.append("RMS@1.2s \(f1(rel))dB rel 0.3s outside -20..-6dB")
            }

        case .bell:
            attackAtMost(10)
            brightAtLeast(1.2)
            levelAtLeast(4)
            sparkleAtLeast(2.5)
            // Monotonic decay gate: RMS@2.5s ≤ −18 dB relative to peak.
            let rel = m.rmsAt2_5 - m.peakDBFS
            if rel > -18 { v.append("RMS@2.5s \(f1(rel))dB rel peak above -18dB") }

        case .mallet:
            attackAtMost(8)
            brightAtLeast(1.2)
            levelAtLeast(4)
            if m.sparkleIndex < 1.5 || m.sparkleIndex > 3.0 {
                v.append("sparkle \(f2(m.sparkleIndex)) outside 1.5-3.0")
            }
            let rel = m.rmsAt1_0 - m.rmsAt0_2
            if rel > -15 { v.append("RMS@1.0s \(f1(rel))dB rel 0.2s above -15dB") }

        case .bass:
            attackAtMost(15)
            brightAtLeast(1.3)
            levelAtLeast(5)
            if m.lowBandFraction < 0.5 {
                v.append("lowBandFraction \(f2(m.lowBandFraction)) below 0.50")
            }

        case .brass:
            attackIn(30, 90)
            brightAtLeast(1.3)
            levelAtLeast(5)
            if m.centroidSustainHz < m.centroidAttackHz {
                v.append("centroidSustain \(f1(m.centroidSustainHz))Hz below "
                    + "centroidAttack \(f1(m.centroidAttackHz))Hz (no swell)")
            }

        case .pad:
            attackIn(80, 300)
            brightAtLeast(1.1)
            levelAtLeast(3)
            if m.releaseTailMs < 400 {
                v.append("releaseTail \(f1(m.releaseTailMs))ms below 400ms")
            }

        case .organ:
            attackAtMost(30)
            brightAtMost(1.15)
            levelAtMost(3)
            // Flat sustain: |RMS@1.5s − RMS@0.5s| ≤ 1.5 dB.
            let drift = abs(m.rmsAt1_5 - m.rmsAt0_5)
            if drift > 1.5 { v.append("sustain drift \(f1(drift))dB above 1.5dB") }

        case .lead:
            attackAtMost(20)
            brightAtLeast(1.2)
            levelAtLeast(4)
            // Sustain shelf sanity: the note must still be sounding.
            if m.rmsSustainDBFS < -40 {
                v.append("rmsSustain \(f1(m.rmsSustainDBFS))dBFS below -40dBFS")
            }

        case .wind:
            attackIn(20, 80)
            brightAtMost(1.3)
            levelAtMost(4)

        case .exempt:
            break   // hard gates are applied globally in PresetReport
        }
        return v
    }
}

// MARK: - PresetMetrics

/// Metric bundle for one preset (computed from the v90 render, with velocity
/// deltas derived from the v40/v127 attack windows). All dB values are dBFS;
/// the decay ladder entries are 100 ms-window RMS values centered at the
/// labeled time, except rmsAt1_5 which uses the trailing window [1.40, 1.50] s
/// (1.5 s is the noteOff instant for sustained archetypes).
public struct PresetMetrics: Codable, Sendable {
    public var attackMs: Float
    public var velocityBrightnessDelta: Float   // centroidAttack(v127)/centroidAttack(v40)
    public var velocityLevelDeltaDB: Float      // rmsAttack(v127) − rmsAttack(v40)
    public var sparkleIndex: Float
    public var rmsSustainDBFS: Float            // 0.5–1.0 s window
    public var peakDBFS: Float
    public var releaseTailMs: Float

    // Decay ladder (100 ms windows, dBFS; centered, except rmsAt1_5: trailing [1.40, 1.50] s)
    public var rmsAt0_2: Float
    public var rmsAt0_3: Float
    public var rmsAt0_5: Float
    public var rmsAt1_0: Float
    public var rmsAt1_2: Float
    public var rmsAt1_5: Float
    public var rmsAt2_5: Float

    public var lowBandFraction: Float           // <200 Hz energy share, sustain window
    public var centroidAttackHz: Float          // 0–120 ms window
    public var centroidSustainHz: Float         // 0.5–1.0 s window

    // Flags (from Metrics.flags over the full render)
    public var nan: Bool
    public var clipped: Bool
    public var silent: Bool

    public init(attackMs: Float, velocityBrightnessDelta: Float, velocityLevelDeltaDB: Float,
                sparkleIndex: Float, rmsSustainDBFS: Float, peakDBFS: Float, releaseTailMs: Float,
                rmsAt0_2: Float, rmsAt0_3: Float, rmsAt0_5: Float, rmsAt1_0: Float,
                rmsAt1_2: Float, rmsAt1_5: Float, rmsAt2_5: Float,
                lowBandFraction: Float, centroidAttackHz: Float, centroidSustainHz: Float,
                nan: Bool, clipped: Bool, silent: Bool) {
        self.attackMs = attackMs
        self.velocityBrightnessDelta = velocityBrightnessDelta
        self.velocityLevelDeltaDB = velocityLevelDeltaDB
        self.sparkleIndex = sparkleIndex
        self.rmsSustainDBFS = rmsSustainDBFS
        self.peakDBFS = peakDBFS
        self.releaseTailMs = releaseTailMs
        self.rmsAt0_2 = rmsAt0_2
        self.rmsAt0_3 = rmsAt0_3
        self.rmsAt0_5 = rmsAt0_5
        self.rmsAt1_0 = rmsAt1_0
        self.rmsAt1_2 = rmsAt1_2
        self.rmsAt1_5 = rmsAt1_5
        self.rmsAt2_5 = rmsAt2_5
        self.lowBandFraction = lowBandFraction
        self.centroidAttackHz = centroidAttackHz
        self.centroidSustainHz = centroidSustainHz
        self.nan = nan
        self.clipped = clipped
        self.silent = silent
    }

    /// All-passing EP-ish values for unit tests.
    public static func fixture() -> PresetMetrics {
        PresetMetrics(
            attackMs: 10,
            velocityBrightnessDelta: 1.6,
            velocityLevelDeltaDB: 8,
            sparkleIndex: 2.5,
            rmsSustainDBFS: -18,
            peakDBFS: -3,
            releaseTailMs: 250,
            rmsAt0_2: -13, rmsAt0_3: -14, rmsAt0_5: -16, rmsAt1_0: -21,
            rmsAt1_2: -23, rmsAt1_5: -26, rmsAt2_5: -45,
            lowBandFraction: 0.3,
            centroidAttackHz: 1800,
            centroidSustainHz: 900,
            nan: false, clipped: false, silent: false)
    }
}
