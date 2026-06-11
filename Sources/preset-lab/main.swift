// main.swift
// preset-lab — headless preset-quality harness CLI (dev tool, not shipped).
//
// Renders bundled factory presets via PresetLabKit, evaluates archetype
// targets (spec §3.2) plus global hard gates, and writes metrics.json /
// metrics.md (and optional per-velocity audition WAVs).
//
// Exit codes:
//   0  every non-exempt preset passes its targets and no hard-gate failures
//   1  any non-exempt preset has violations, or ANY preset (exempt included)
//      has a hard-gate failure (nan / clip / silent / hung voice)
//   2  usage or I/O error

import Foundation
import M2DXCore
import PresetLabKit

// MARK: - Usage / error helpers

let usage = """
usage: preset-lab [--preset <name>]... [--wav] [--out <dir>] [--format json|md]

  --preset <name>   evaluate only this preset (repeatable; default: all factory presets)
  --wav             write <out>/<preset-slug>-v{40,90,127}.wav audition files
  --out <dir>       output directory, created if missing (default: ./preset-lab-out)
  --format json|md  write only metrics.json or only metrics.md (default: both)
"""

func fail(_ message: String, showUsage: Bool = false) -> Never {
    var text = "error: \(message)\n"
    if showUsage { text += usage + "\n" }
    FileHandle.standardError.write(Data(text.utf8))
    exit(2)
}

// MARK: - Argument parsing (hand-rolled, no dependencies)

var requestedNames: [String] = []
var writeWAVs = false
var outPath = "./preset-lab-out"
var format: String?   // nil = write both json and md

var args = ArraySlice(CommandLine.arguments.dropFirst())
while let arg = args.popFirst() {
    switch arg {
    case "--preset":
        guard let value = args.popFirst() else { fail("--preset requires a value", showUsage: true) }
        requestedNames.append(value)
    case "--wav":
        writeWAVs = true
    case "--out":
        guard let value = args.popFirst() else { fail("--out requires a value", showUsage: true) }
        outPath = value
    case "--format":
        guard let value = args.popFirst() else { fail("--format requires a value", showUsage: true) }
        guard value == "json" || value == "md" else {
            fail("--format must be json or md (got \"\(value)\")", showUsage: true)
        }
        format = value
    case "--help", "-h":
        print(usage)
        exit(0)
    default:
        fail("unknown argument: \(arg)", showUsage: true)
    }
}

// MARK: - Preset selection

let allPresets = DX7FactoryPresets.all
let presets: [DX7Preset]
if requestedNames.isEmpty {
    presets = allPresets
} else {
    presets = requestedNames.map { name in
        guard let preset = allPresets.first(where: { $0.name == name }) else {
            fail("unknown preset \"\(name)\" — names must match DX7FactoryPresets.all exactly")
        }
        return preset
    }
}

// MARK: - Output directory

let outURL = URL(fileURLWithPath: outPath, isDirectory: true)
do {
    try FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
} catch {
    fail("cannot create output directory \(outPath): \(error)")
}

/// "E.PIANO 1" → "e-piano-1" (lowercased, non-alphanumerics collapsed to "-").
func slug(_ name: String) -> String {
    var out = ""
    var pendingDash = false
    for ch in name.lowercased() {
        if ch.isLetter || ch.isNumber {
            if pendingDash && !out.isEmpty { out.append("-") }
            pendingDash = false
            out.append(ch)
        } else {
            pendingDash = true
        }
    }
    return out.isEmpty ? "preset" : out
}

// MARK: - Render, evaluate, report

var reports: [PresetReport] = []
for preset in presets {
    let report = PresetReport.build(preset: preset)
    reports.append(report)

    if report.passed {
        print("\(preset.name): PASS")
    } else {
        let count = report.violations.count + report.hardGateFailures.count
        print("\(preset.name): FAIL \(count) violations")
        for violation in report.violations { print("    - \(violation)") }
        for gate in report.hardGateFailures { print("    - [hard gate] \(gate)") }
    }

    if writeWAVs {
        // Parallel render with the exact PresetReport protocol
        // (48 kHz, 4.0 s, archetype noteOff, v40/90/127).
        let archetype = Archetype.forPresetName(preset.name) ?? .exempt
        let note = Archetype.baseNote(for: preset.name)
        for velocity: UInt8 in [40, 90, 127] {
            let rendered = HeadlessRenderer.render(
                preset: preset, note: note, velocity7: velocity,
                noteOffSeconds: archetype.noteOffSeconds, totalSeconds: 4.0,
                sampleRate: 48000)
            let wavURL = outURL.appendingPathComponent("\(slug(preset.name))-v\(velocity).wav")
            do {
                try WAVWriter.writeMono16(samples: rendered.samples, sampleRate: 48000, to: wavURL)
            } catch {
                fail("cannot write \(wavURL.path): \(error)")
            }
        }
    }
}

// MARK: - metrics.json / metrics.md

if format == nil || format == "json" {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    // A broken preset can yield non-finite metrics; never crash the harness on encode.
    encoder.nonConformingFloatEncodingStrategy = .convertToString(
        positiveInfinity: "inf", negativeInfinity: "-inf", nan: "nan")
    do {
        let data = try encoder.encode(reports)
        try data.write(to: outURL.appendingPathComponent("metrics.json"))
    } catch {
        fail("cannot write metrics.json: \(error)")
    }
}
if format == nil || format == "md" {
    do {
        let markdown = PresetReport.markdownTable(reports)
        try Data(markdown.utf8).write(to: outURL.appendingPathComponent("metrics.md"))
    } catch {
        fail("cannot write metrics.md: \(error)")
    }
}

// MARK: - Summary + exit code

let nonExempt = reports.filter { $0.archetype != "exempt" && $0.archetype != "unmapped" }
let passing = nonExempt.filter(\.passed).count
print("\(passing)/\(nonExempt.count) non-exempt presets pass")

// Exempt/unmapped presets always have violations == [], so this first check is
// exactly "any non-exempt preset has target violations".
let anyViolations = reports.contains { !$0.violations.isEmpty }
let hardGateCount = reports.count { !$0.hardGateFailures.isEmpty }
if hardGateCount > 0 {
    print("hard-gate failures in \(hardGateCount) preset(s)")
}
exit(anyViolations || hardGateCount > 0 ? 1 : 0)
