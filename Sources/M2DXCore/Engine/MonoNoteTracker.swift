// #115: fixed-capacity, render-owned physical-key tracking. No allocation on MIDI input.

public enum MonoPortamentoMode: String, Codable, CaseIterable, Sendable {
    case fingered, fullTime
}

public struct MonoPerformanceSettings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var portamentoMode: MonoPortamentoMode
    public var glissando: Bool

    public init(enabled: Bool = false, portamentoMode: MonoPortamentoMode = .fingered,
                glissando: Bool = false) {
        self.enabled = enabled
        self.portamentoMode = portamentoMode
        self.glissando = glissando
    }
}

/// The MIDI lane currently merges channels. Reference counts balance duplicate pitches
/// from different sources without allocating a collection or inferring channel identity.
/// Sustain is deliberately NOT a physical key: releasing all keys resets the latch.
final class MonoNoteTracker {
    enum Change: Equatable { case none, attack(UInt8), legato(UInt8), release(UInt8) }
    enum Priority { case unset, high, low }
    private let counts: UnsafeMutablePointer<UInt16>
    private var lowBits: UInt64 = 0
    private var highBits: UInt64 = 0
    private(set) var priority: Priority = .unset
    private(set) var selected: UInt8?

    init() {
        counts = .allocate(capacity: 128)
        counts.initialize(repeating: 0, count: 128)
    }

    deinit { counts.deinitialize(count: 128); counts.deallocate() }

    func reset() {
        for i in 0..<128 { counts[i] = 0 }
        lowBits = 0; highBits = 0; priority = .unset; selected = nil
    }

    func press(_ note: UInt8) -> Change {
        guard note < 128 else { return .none }
        let i = Int(note)
        if counts[i] < .max { counts[i] += 1 }
        let mask = UInt64(1) << UInt64(i & 63)
        if i < 64 { lowBits |= mask } else { highBits |= mask }
        guard let previous = selected else {
            selected = note
            return .attack(note)
        }
        if priority == .unset, note != previous {
            priority = note > previous ? .high : .low
        }
        return selectWinner(previous: previous)
    }

    func release(_ note: UInt8) -> Change {
        guard note < 128, counts[Int(note)] > 0, let previous = selected else { return .none }
        counts[Int(note)] -= 1
        guard counts[Int(note)] == 0 else { return .none }
        let mask = UInt64(1) << UInt64(Int(note) & 63)
        if note < 64 { lowBits &= ~mask } else { highBits &= ~mask }
        if lowBits == 0, highBits == 0 {
            selected = nil; priority = .unset
            return .release(previous)
        }
        return selectWinner(previous: previous)
    }

    private func selectWinner(previous: UInt8) -> Change {
        let winner: UInt8
        if priority == .high {
            winner = highBits != 0 ? UInt8(127 - highBits.leadingZeroBitCount)
                : UInt8(63 - lowBits.leadingZeroBitCount)
        } else {
            winner = lowBits != 0 ? UInt8(lowBits.trailingZeroBitCount)
                : UInt8(64 + highBits.trailingZeroBitCount)
        }
        selected = winner
        return winner == previous ? .none : .legato(winner)
    }
}
