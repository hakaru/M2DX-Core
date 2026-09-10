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

/// The MIDI lane currently merges channels, so a pitch is either held or not (a 128-bit set).
/// A duplicate note-on for a held pitch does not stack, and a single note-off always releases
/// the pitch (#124) — the same as Poly, where one note-off releases every voice on that pitch.
/// This keeps a dropped note-off recoverable by pressing and releasing the key once more.
/// Trade-off: when two sources hold the same pitch, the first note-off releases it.
/// Sustain is deliberately NOT a physical key: releasing all keys resets the latch.
final class MonoNoteTracker {
    enum Change: Equatable { case none, attack(UInt8), legato(UInt8), release(UInt8) }
    enum Priority { case unset, high, low }
    private var lowBits: UInt64 = 0
    private var highBits: UInt64 = 0
    private(set) var priority: Priority = .unset
    private(set) var selected: UInt8?

    func reset() {
        lowBits = 0; highBits = 0; priority = .unset; selected = nil
    }

    func press(_ note: UInt8) -> Change {
        guard note < 128 else { return .none }
        let mask = UInt64(1) << UInt64(note & 63)
        if note < 64 { lowBits |= mask } else { highBits |= mask }
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
        guard note < 128, let previous = selected else { return .none }
        let mask = UInt64(1) << UInt64(note & 63)
        if note < 64 {
            guard lowBits & mask != 0 else { return .none }
            lowBits &= ~mask
        } else {
            guard highBits & mask != 0 else { return .none }
            highBits &= ~mask
        }
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
