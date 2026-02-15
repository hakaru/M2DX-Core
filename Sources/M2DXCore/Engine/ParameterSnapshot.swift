// ParameterSnapshot.swift
// M2DX-Core — Parameter snapshot structures for UI → audio thread transfer

// MARK: - Timbre Mode

/// Multi-timbral mode determining how polyphony voices are distributed across slots.
public enum TimbreMode: UInt8, Sendable, CaseIterable {
    case single = 0
    case dual = 1
    case split = 2
    case tx816 = 3

    public var slotCount: Int {
        switch self {
        case .single: return 1
        case .dual, .split: return 2
        case .tx816: return 8
        }
    }
}

/// Configuration for a single timbre slot.
package struct SlotConfig {
    var voiceStart: Int = 0
    var voiceCount: Int = 16
    var noteRangeLow: UInt8 = 0
    var noteRangeHigh: UInt8 = 127
    var midiChannel: UInt8 = 0
    var enabled: Bool = true
}

package let kMaxSlots = 8

// MARK: - Operator Snapshot

/// Per-operator parameters set from the UI thread
package struct OperatorSnapshot {
    var level: Float = 1.0
    var ratio: Float = 1.0
    var detune: Float = 1.0
    var feedback: Float = 0.0
    var egR0: Float = 99, egR1: Float = 75, egR2: Float = 50, egR3: Float = 50
    var egL0: Float = 1.0, egL1: Float = 0.8, egL2: Float = 0.7, egL3: Float = 0.0

    // DX7 native values (0-99 range)
    var dx7OutputLevel: Int = 99
    var dx7EgR0: Int = 99, dx7EgR1: Int = 75, dx7EgR2: Int = 50, dx7EgR3: Int = 50
    var dx7EgL0: Int = 99, dx7EgL1: Int = 80, dx7EgL2: Int = 70, dx7EgL3: Int = 0

    // Per-operator DX7 parameters
    var velocitySensitivity: UInt8 = 0
    var ampModSensitivity: UInt8 = 0
    var keyboardRateScaling: UInt8 = 0
    var klsBreakPoint: UInt8 = 39
    var klsLeftDepth: UInt8 = 0
    var klsRightDepth: UInt8 = 0
    var klsLeftCurve: UInt8 = 0
    var klsRightCurve: UInt8 = 0
    var fixedFrequency: UInt8 = 0
    var fixedFreqCoarse: UInt8 = 1
    var fixedFreqFine: UInt8 = 0
}

// MARK: - Slot Snapshot

/// Per-slot snapshot — contains all parameters specific to one timbre slot.
package struct SlotSnapshot {
    var ops: (OperatorSnapshot, OperatorSnapshot, OperatorSnapshot,
              OperatorSnapshot, OperatorSnapshot, OperatorSnapshot)
    var algorithm: Int = 0

    // LFO Parameters
    var lfoSpeed: UInt8 = 35
    var lfoDelay: UInt8 = 0
    var lfoPMD: UInt8 = 0
    var lfoAMD: UInt8 = 0
    var lfoSync: UInt8 = 1
    var lfoWaveform: UInt8 = 0
    var lfoPMS: UInt8 = 3

    // Pitch EG Parameters
    var pitchEGR0: UInt8 = 99, pitchEGR1: UInt8 = 99, pitchEGR2: UInt8 = 99, pitchEGR3: UInt8 = 99
    var pitchEGL0: UInt8 = 50, pitchEGL1: UInt8 = 50, pitchEGL2: UInt8 = 50, pitchEGL3: UInt8 = 50

    // Per-slot global
    var transpose: Int8 = 0
    var pitchBendRange: UInt8 = 2

    // Controller Mapping
    var wheelPitch: UInt8 = 50, wheelAmp: UInt8 = 0, wheelEGBias: UInt8 = 0
    var footPitch: UInt8 = 0, footAmp: UInt8 = 0, footEGBias: UInt8 = 0
    var breathPitch: UInt8 = 0, breathAmp: UInt8 = 0, breathEGBias: UInt8 = 0
    var aftertouchPitch: UInt8 = 0, aftertouchAmp: UInt8 = 0, aftertouchEGBias: UInt8 = 0

    init() {
        ops = (OperatorSnapshot(), OperatorSnapshot(), OperatorSnapshot(),
               OperatorSnapshot(), OperatorSnapshot(), OperatorSnapshot())
    }
}

// MARK: - Synth Parameter Snapshot

/// All UI-controlled parameters bundled for atomic snapshot transfer
package struct SynthParamSnapshot {
    var timbreMode: UInt8 = 0
    var splitPoint: UInt8 = 60
    var slots: [SlotSnapshot] = [SlotSnapshot()]
    var slotConfigs: [SlotConfig] = [SlotConfig()]

    // Global
    var masterVolume: Float = 0.7
    var sampleRate: Float = 44100
    var version: UInt64 = 0
    var oversamplingMode: UInt8 = 0
    var masterTuning: Int16 = 0

    // Slot 0 convenience accessors
    var ops: (OperatorSnapshot, OperatorSnapshot, OperatorSnapshot,
              OperatorSnapshot, OperatorSnapshot, OperatorSnapshot) {
        get { slots[0].ops }
        set { slots[0].ops = newValue }
    }
    var algorithm: Int {
        get { slots[0].algorithm }
        set { slots[0].algorithm = newValue }
    }
    var lfoSpeed: UInt8 { get { slots[0].lfoSpeed } set { slots[0].lfoSpeed = newValue } }
    var lfoDelay: UInt8 { get { slots[0].lfoDelay } set { slots[0].lfoDelay = newValue } }
    var lfoPMD: UInt8 { get { slots[0].lfoPMD } set { slots[0].lfoPMD = newValue } }
    var lfoAMD: UInt8 { get { slots[0].lfoAMD } set { slots[0].lfoAMD = newValue } }
    var lfoSync: UInt8 { get { slots[0].lfoSync } set { slots[0].lfoSync = newValue } }
    var lfoWaveform: UInt8 { get { slots[0].lfoWaveform } set { slots[0].lfoWaveform = newValue } }
    var lfoPMS: UInt8 { get { slots[0].lfoPMS } set { slots[0].lfoPMS = newValue } }
    var transpose: Int8 { get { slots[0].transpose } set { slots[0].transpose = newValue } }
    var pitchBendRange: UInt8 { get { slots[0].pitchBendRange } set { slots[0].pitchBendRange = newValue } }
}
