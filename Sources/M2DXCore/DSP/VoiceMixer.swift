// VoiceMixer.swift
// M2DX-Core — vDSP-based voice mixing, gain, and clipping

import Accelerate

// MARK: - Voice Mixer

/// Utility functions for mixing DX7 voice output using vDSP.
package enum VoiceMixer {

    /// Convert Int32 block buffer to Float and accumulate with gain.
    /// blockBuf: Q24 Int32 voice output
    /// dst: Float accumulation buffer
    /// scratch: caller-managed Float buffer (>= count), avoids heap allocation on the audio thread
    /// gain: scaling factor (includes volume, pan, Q24→Float conversion)
    @inline(__always)
    static func accumulateVoice(
        blockBuf: UnsafePointer<Int32>,
        dst: UnsafeMutablePointer<Float>,
        scratch: UnsafeMutablePointer<Float>,
        count: Int,
        gain: Float
    ) {
        // Convert Int32 → Float using caller-provided scratch buffer
        vDSP_vflt32(blockBuf, 1, scratch, 1, vDSP_Length(count))

        // Scale and accumulate: dst[i] += scratch[i] * gain
        var g = gain
        vDSP_vsma(scratch, 1, &g, dst, 1, dst, 1, vDSP_Length(count))
    }

    /// Apply master gain to buffer in-place.
    @inline(__always)
    static func applyGain(
        buffer: UnsafeMutablePointer<Float>,
        count: Int,
        gain: Float
    ) {
        var g = gain
        vDSP_vsmul(buffer, 1, &g, buffer, 1, vDSP_Length(count))
    }

    /// Hard clip buffer to [-1, 1] range in-place.
    @inline(__always)
    static func hardClip(
        buffer: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        var lo: Float = -1.0
        var hi: Float = 1.0
        vDSP_vclip(buffer, 1, &lo, &hi, buffer, 1, vDSP_Length(count))
    }
}
