// PresetReport.swift
// PresetLabKit — renders one preset per the spec protocol (48 kHz, v40/90/127,
// 4.0 s total, archetype noteOff), computes PresetMetrics, evaluates archetype
// targets and global hard gates, and serializes to JSON / markdown.

import Foundation
import M2DXCore

/// Per-velocity quick summary (full PresetMetrics come from the v90 render).
public struct VelocitySummary: Codable, Sendable {
    public let velocity: UInt8
    public let peakDBFS: Float
    public let rmsSustainDBFS: Float    // 0.5–1.0 s window
    public let attackMs: Float
    public let centroidAttackHz: Float  // 0–120 ms window
    public let nan: Bool
    public let clipped: Bool
    public let silent: Bool
}

public struct PresetReport: Codable, Sendable {
    public let presetName: String
    public let archetype: String        // Archetype rawValue ("unmapped" if unknown)
    public let baseNote: UInt8
    public let noteOffSeconds: Double
    public let metrics: PresetMetrics   // from the v90 render (+ velocity deltas)
    public let velocities: [VelocitySummary]
    public let violations: [String]         // archetype-target violations
    public let hardGateFailures: [String]   // nan/clip/silent at any velocity, hung voice

    public var passed: Bool { violations.isEmpty && hardGateFailures.isEmpty }

    // MARK: - Build

    /// Renders v40/90/127 at the preset's base note / archetype noteOff
    /// (4.0 s total, 48 kHz), computes metrics, and evaluates targets.
    /// Exempt (and unmapped) presets get violations == [] but hard gates
    /// are still checked.
    public static func build(preset: DX7Preset) -> PresetReport {
        let sr: Float = 48000
        let totalSeconds = 4.0
        let mapped = Archetype.forPresetName(preset.name)
        let arch = mapped ?? .exempt
        let note = Archetype.baseNote(for: preset.name)
        let off = arch.noteOffSeconds

        let r40 = HeadlessRenderer.render(preset: preset, note: note, velocity7: 40,
                                          noteOffSeconds: off, totalSeconds: totalSeconds,
                                          sampleRate: sr)
        let r90 = HeadlessRenderer.render(preset: preset, note: note, velocity7: 90,
                                          noteOffSeconds: off, totalSeconds: totalSeconds,
                                          sampleRate: sr)
        let r127 = HeadlessRenderer.render(preset: preset, note: note, velocity7: 127,
                                           noteOffSeconds: off, totalSeconds: totalSeconds,
                                           sampleRate: sr)

        // --- v90 metrics (spec windows: attack 0–120 ms, sustain 0.5–1.0 s) ---
        let x = r90.samples
        let attackWin = window(x, from: 0, to: 0.120, sr: sr)
        let sustainWin = window(x, from: 0.5, to: 1.0, sr: sr)
        let flags90 = Metrics.flags(x)

        // Velocity deltas from the v40/v127 attack windows.
        let a40 = window(r40.samples, from: 0, to: 0.120, sr: sr)
        let a127 = window(r127.samples, from: 0, to: 0.120, sr: sr)
        let c40 = Metrics.spectralCentroidHz(a40, sampleRate: sr)
        let c127 = Metrics.spectralCentroidHz(a127, sampleRate: sr)

        let releaseTail = Metrics.releaseTailMs(x, noteOffSample: r90.noteOffSample, sampleRate: sr)

        let metrics = PresetMetrics(
            attackMs: Metrics.attackMs(x, sampleRate: sr),
            velocityBrightnessDelta: c127 / max(c40, 1e-3),
            velocityLevelDeltaDB: Metrics.rmsDBFS(a127) - Metrics.rmsDBFS(a40),
            sparkleIndex: Metrics.sparkleIndex(attack: attackWin, sustain: sustainWin, sampleRate: sr),
            rmsSustainDBFS: Metrics.rmsDBFS(sustainWin),
            peakDBFS: Metrics.peakDBFS(x),
            releaseTailMs: releaseTail,
            rmsAt0_2: rmsAt(x, center: 0.2, sr: sr),
            rmsAt0_3: rmsAt(x, center: 0.3, sr: sr),
            rmsAt0_5: rmsAt(x, center: 0.5, sr: sr),
            rmsAt1_0: rmsAt(x, center: 1.0, sr: sr),
            rmsAt1_2: rmsAt(x, center: 1.2, sr: sr),
            rmsAt1_5: rmsAt(x, center: 1.5, sr: sr),
            rmsAt2_5: rmsAt(x, center: 2.5, sr: sr),
            lowBandFraction: lowBandFraction(sustainWin, sampleRate: sr),
            centroidAttackHz: Metrics.spectralCentroidHz(attackWin, sampleRate: sr),
            centroidSustainHz: Metrics.spectralCentroidHz(sustainWin, sampleRate: sr),
            nan: flags90.nan, clipped: flags90.clipped, silent: flags90.silent)

        // --- Per-velocity summaries ---
        let summaries = [(UInt8(40), r40), (UInt8(90), r90), (UInt8(127), r127)].map { v, r in
            let f = Metrics.flags(r.samples)
            return VelocitySummary(
                velocity: v,
                peakDBFS: Metrics.peakDBFS(r.samples),
                rmsSustainDBFS: Metrics.rmsDBFS(window(r.samples, from: 0.5, to: 1.0, sr: sr)),
                attackMs: Metrics.attackMs(r.samples, sampleRate: sr),
                centroidAttackHz: Metrics.spectralCentroidHz(window(r.samples, from: 0, to: 0.120, sr: sr), sampleRate: sr),
                nan: f.nan, clipped: f.clipped, silent: f.silent)
        }

        // --- Hard gates (apply to ALL presets, exempt included) ---
        var hardGates: [String] = []
        for s in summaries {
            if s.nan { hardGates.append("nan at v\(s.velocity)") }
            if s.clipped { hardGates.append("clipped at v\(s.velocity)") }
            if s.silent { hardGates.append("silent at v\(s.velocity)") }
        }
        // Hung voice: post-noteOff RMS must reach −60 dBFS. releaseTailMs returns
        // the full remaining window when −60 is never reached, so "≥ window − 1 ms"
        // detects non-decaying voices within the 4.0 s render; > 4000 ms is the
        // spec bound itself.
        let maxTailMs = Float(x.count - r90.noteOffSample) / sr * 1000
        if releaseTail > 4000 || releaseTail >= maxTailMs - 1 {
            hardGates.append("hung: releaseTail \(String(format: "%.0f", releaseTail))ms "
                + "(post-noteOff RMS never reached -60dBFS within render)")
        }

        let violations = (mapped == nil || arch == .exempt) ? [] : arch.violations(metrics)

        return PresetReport(
            presetName: preset.name,
            archetype: mapped?.rawValue ?? "unmapped",
            baseNote: note,
            noteOffSeconds: off,
            metrics: metrics,
            velocities: summaries,
            violations: violations,
            hardGateFailures: hardGates)
    }

    // MARK: - Markdown

    /// One row per preset: name, archetype, PASS/FAIL, violation count
    /// (archetype + hard gates), key numbers.
    public static func markdownTable(_ reports: [PresetReport]) -> String {
        var lines = [
            "| Preset | Archetype | Status | Violations | rmsSustain (dBFS) | attack (ms) | brightΔ | sparkle |",
            "|---|---|---|---|---|---|---|---|",
        ]
        for r in reports {
            let status = r.passed ? "PASS" : "FAIL"
            let count = r.violations.count + r.hardGateFailures.count
            lines.append("| \(r.presetName) | \(r.archetype) | \(status) | \(count) | "
                + String(format: "%.1f", r.metrics.rmsSustainDBFS) + " | "
                + String(format: "%.1f", r.metrics.attackMs) + " | "
                + String(format: "%.2f", r.metrics.velocityBrightnessDelta) + " | "
                + String(format: "%.2f", r.metrics.sparkleIndex) + " |")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Window helpers

    private static func window(_ x: [Float], from: Double, to: Double, sr: Float) -> ArraySlice<Float> {
        let lo = max(0, min(x.count, Int(from * Double(sr))))
        let hi = max(lo, min(x.count, Int(to * Double(sr))))
        return x[lo..<hi]
    }

    /// 100 ms-window RMS centered at `center` seconds (dBFS).
    private static func rmsAt(_ x: [Float], center: Double, sr: Float) -> Float {
        Metrics.rmsDBFS(window(x, from: center - 0.05, to: center + 0.05, sr: sr))
    }

    /// Share of spectral energy below `cutoffHz` in the given window (0…1).
    private static func lowBandFraction(_ s: ArraySlice<Float>, sampleRate: Float,
                                        cutoffHz: Float = 200) -> Float {
        guard !s.isEmpty else { return 0 }
        let (mags, hzPerBin) = Metrics.magnitudeSpectrum(s, sampleRate: sampleRate)
        var low: Float = 0, total: Float = 0
        for (i, m) in mags.enumerated() {
            let e = m * m
            total += e
            if Float(i) * hzPerBin < cutoffHz { low += e }
        }
        guard total > 1e-12 else { return 0 }
        return low / total
    }
}
