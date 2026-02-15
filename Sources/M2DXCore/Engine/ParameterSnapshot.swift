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
public struct SlotConfig: Sendable {
    public var voiceStart: Int
    public var voiceCount: Int
    public var noteRangeLow: UInt8
    public var noteRangeHigh: UInt8
    public var midiChannel: UInt8
    public var enabled: Bool

    public init(voiceStart: Int = 0, voiceCount: Int = 16,
                noteRangeLow: UInt8 = 0, noteRangeHigh: UInt8 = 127,
                midiChannel: UInt8 = 0, enabled: Bool = true) {
        self.voiceStart = voiceStart
        self.voiceCount = voiceCount
        self.noteRangeLow = noteRangeLow
        self.noteRangeHigh = noteRangeHigh
        self.midiChannel = midiChannel
        self.enabled = enabled
    }
}

public let kMaxSlots = 8

// MARK: - Operator Snapshot

/// Per-operator parameters set from the UI thread
public struct OperatorSnapshot: Sendable {
    public var level: Float = 1.0
    public var ratio: Float = 1.0
    public var detune: Float = 1.0
    public var feedback: Float = 0.0
    public var egR0: Float = 99, egR1: Float = 75, egR2: Float = 50, egR3: Float = 50
    public var egL0: Float = 1.0, egL1: Float = 0.8, egL2: Float = 0.7, egL3: Float = 0.0

    // DX7 native values (0-99 range)
    public var dx7OutputLevel: Int = 99
    public var dx7EgR0: Int = 99, dx7EgR1: Int = 75, dx7EgR2: Int = 50, dx7EgR3: Int = 50
    public var dx7EgL0: Int = 99, dx7EgL1: Int = 80, dx7EgL2: Int = 70, dx7EgL3: Int = 0

    // Per-operator DX7 parameters
    public var velocitySensitivity: UInt8 = 0
    public var ampModSensitivity: UInt8 = 0
    public var keyboardRateScaling: UInt8 = 0
    public var klsBreakPoint: UInt8 = 39
    public var klsLeftDepth: UInt8 = 0
    public var klsRightDepth: UInt8 = 0
    public var klsLeftCurve: UInt8 = 0
    public var klsRightCurve: UInt8 = 0
    public var fixedFrequency: UInt8 = 0
    public var fixedFreqCoarse: UInt8 = 1
    public var fixedFreqFine: UInt8 = 0
    public init() {}
}

// MARK: - Slot Snapshot

/// Per-slot snapshot — contains all parameters specific to one timbre slot.
public struct SlotSnapshot: Sendable {
    public var ops: (OperatorSnapshot, OperatorSnapshot, OperatorSnapshot,
              OperatorSnapshot, OperatorSnapshot, OperatorSnapshot)
    public var algorithm: Int = 0

    // LFO Parameters
    public var lfoSpeed: UInt8 = 35
    public var lfoDelay: UInt8 = 0
    public var lfoPMD: UInt8 = 0
    public var lfoAMD: UInt8 = 0
    public var lfoSync: UInt8 = 1
    public var lfoWaveform: UInt8 = 0
    public var lfoPMS: UInt8 = 3

    // Pitch EG Parameters
    public var pitchEGR0: UInt8 = 99, pitchEGR1: UInt8 = 99, pitchEGR2: UInt8 = 99, pitchEGR3: UInt8 = 99
    public var pitchEGL0: UInt8 = 50, pitchEGL1: UInt8 = 50, pitchEGL2: UInt8 = 50, pitchEGL3: UInt8 = 50

    // Per-slot global
    public var transpose: Int8 = 0
    public var pitchBendRange: UInt8 = 2

    // Controller Mapping
    public var wheelPitch: UInt8 = 50, wheelAmp: UInt8 = 0, wheelEGBias: UInt8 = 0
    public var footPitch: UInt8 = 0, footAmp: UInt8 = 0, footEGBias: UInt8 = 0
    public var breathPitch: UInt8 = 0, breathAmp: UInt8 = 0, breathEGBias: UInt8 = 0
    public var aftertouchPitch: UInt8 = 0, aftertouchAmp: UInt8 = 0, aftertouchEGBias: UInt8 = 0

    public init() {
        ops = (OperatorSnapshot(), OperatorSnapshot(), OperatorSnapshot(),
               OperatorSnapshot(), OperatorSnapshot(), OperatorSnapshot())
    }
}

// MARK: - Synth Parameter Snapshot

/// All UI-controlled parameters bundled for atomic snapshot transfer.
/// Fixed-size tuples ensure no heap allocation — safe for audio-thread deinit.
public struct SynthParamSnapshot: Sendable {
    public var timbreMode: UInt8 = 0
    public var splitPoint: UInt8 = 60
    public var activeSlotCount: Int = 1

    public var slots: (SlotSnapshot, SlotSnapshot, SlotSnapshot, SlotSnapshot,
                SlotSnapshot, SlotSnapshot, SlotSnapshot, SlotSnapshot)
    public var slotConfigs: (SlotConfig, SlotConfig, SlotConfig, SlotConfig,
                      SlotConfig, SlotConfig, SlotConfig, SlotConfig)

    // Global
    public var masterVolume: Float = 0.7
    public var sampleRate: Float = 44100
    public var version: UInt64 = 0
    public var oversamplingMode: UInt8 = 0
    public var masterTuning: Int16 = 0

    public init() {
        slots = (SlotSnapshot(), SlotSnapshot(), SlotSnapshot(), SlotSnapshot(),
                 SlotSnapshot(), SlotSnapshot(), SlotSnapshot(), SlotSnapshot())
        slotConfigs = (SlotConfig(), SlotConfig(), SlotConfig(), SlotConfig(),
                       SlotConfig(), SlotConfig(), SlotConfig(), SlotConfig())
    }

    // MARK: - Fixed-size tuple subscript helpers

    public func slot(at i: Int) -> SlotSnapshot {
        switch i {
        case 0: return slots.0; case 1: return slots.1
        case 2: return slots.2; case 3: return slots.3
        case 4: return slots.4; case 5: return slots.5
        case 6: return slots.6; case 7: return slots.7
        default: return slots.0
        }
    }

    public mutating func setSlot(at i: Int, _ value: SlotSnapshot) {
        switch i {
        case 0: slots.0 = value; case 1: slots.1 = value
        case 2: slots.2 = value; case 3: slots.3 = value
        case 4: slots.4 = value; case 5: slots.5 = value
        case 6: slots.6 = value; case 7: slots.7 = value
        default: break
        }
    }

    public func config(at i: Int) -> SlotConfig {
        switch i {
        case 0: return slotConfigs.0; case 1: return slotConfigs.1
        case 2: return slotConfigs.2; case 3: return slotConfigs.3
        case 4: return slotConfigs.4; case 5: return slotConfigs.5
        case 6: return slotConfigs.6; case 7: return slotConfigs.7
        default: return slotConfigs.0
        }
    }

    public mutating func setConfig(at i: Int, _ value: SlotConfig) {
        switch i {
        case 0: slotConfigs.0 = value; case 1: slotConfigs.1 = value
        case 2: slotConfigs.2 = value; case 3: slotConfigs.3 = value
        case 4: slotConfigs.4 = value; case 5: slotConfigs.5 = value
        case 6: slotConfigs.6 = value; case 7: slotConfigs.7 = value
        default: break
        }
    }

    // MARK: - Slot 0 convenience accessors

    public var ops: (OperatorSnapshot, OperatorSnapshot, OperatorSnapshot,
              OperatorSnapshot, OperatorSnapshot, OperatorSnapshot) {
        get { slots.0.ops }
        set { slots.0.ops = newValue }
    }
    public var algorithm: Int {
        get { slots.0.algorithm }
        set { slots.0.algorithm = newValue }
    }
    public var lfoSpeed: UInt8 { get { slots.0.lfoSpeed } set { slots.0.lfoSpeed = newValue } }
    public var lfoDelay: UInt8 { get { slots.0.lfoDelay } set { slots.0.lfoDelay = newValue } }
    public var lfoPMD: UInt8 { get { slots.0.lfoPMD } set { slots.0.lfoPMD = newValue } }
    public var lfoAMD: UInt8 { get { slots.0.lfoAMD } set { slots.0.lfoAMD = newValue } }
    public var lfoSync: UInt8 { get { slots.0.lfoSync } set { slots.0.lfoSync = newValue } }
    public var lfoWaveform: UInt8 { get { slots.0.lfoWaveform } set { slots.0.lfoWaveform = newValue } }
    public var lfoPMS: UInt8 { get { slots.0.lfoPMS } set { slots.0.lfoPMS = newValue } }
    public var transpose: Int8 { get { slots.0.transpose } set { slots.0.transpose = newValue } }
    public var pitchBendRange: UInt8 { get { slots.0.pitchBendRange } set { slots.0.pitchBendRange = newValue } }
}
