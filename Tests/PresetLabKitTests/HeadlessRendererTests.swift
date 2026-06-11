import Foundation
import Testing
import M2DXCore
@testable import PresetLabKit

@Suite("Headless renderer")
struct HeadlessRendererTests {
    @Test("INIT SINE renders a non-silent C4 whose centroid is near 262Hz")
    func initSineRoundTrip() {
        let preset = DX7FactoryPresets.all.first { $0.name == "INIT SINE" }!
        let r = HeadlessRenderer.render(preset: preset, note: 60, velocity7: 90,
                                        noteOffSeconds: 1.5, totalSeconds: 3.0)
        let f = Metrics.flags(r.samples)
        #expect(!f.silent && !f.nan && !f.clipped)
        let c = Metrics.spectralCentroidHz(r.samples[24000..<(24000+8192)], sampleRate: 48000)
        #expect(c > 200 && c < 600, "pure sine at C4 ≈ 261.6Hz (centroid skews slightly up with noise floor)")
        #expect(r.noteOffSample == 72000)
    }

    @Test("WAV writer produces a parseable RIFF header")
    func wavHeader() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("t-\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try WAVWriter.writeMono16(samples: [0, 0.5, -0.5], sampleRate: 48000, to: url)
        let d = try Data(contentsOf: url)
        #expect(d.count == 44 + 6)
        #expect(String(data: d[0..<4], encoding: .ascii) == "RIFF")
        #expect(String(data: d[8..<12], encoding: .ascii) == "WAVE")
    }
}
