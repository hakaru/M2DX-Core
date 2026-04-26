// SnapshotRing.swift
// M2DX-Core — Lock-free SPSC triple buffer for UI → audio thread snapshot transfer
// Uses Synchronization.Atomic (macOS 15+ / iOS 18+, no external dependencies).

import Synchronization

/// Lock-free SPSC (Single-Producer Single-Consumer) **triple buffer** with
/// true latest-value semantics.
///
/// - **Producer** (UI thread) calls `pushLatest(_:)` to publish the newest snapshot.
///   When the producer outpaces the consumer, older unpublished values are
///   discarded — the consumer always sees the most recent value on its next pop.
/// - **Consumer** (render thread) calls `popLatest()` to retrieve the most recent
///   published snapshot, or `nil` if no new value has been published since the
///   last pop.
///
/// Three storage slots are pre-allocated and seeded with `initial` at init time;
/// subsequent pushes are pure assignments (no memory init on the hot path).
///
/// Thread-safety: exactly one producer and one consumer.
/// Memory ordering: producer publishes via release on `exchange`; consumer
/// acquires via the same exchange / load.
package final class SnapshotRing<T>: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<T>

    /// Encoded state: bits 0..1 = currently-published slot index (0, 1, or 2),
    /// bit 2 = FRESH flag (set by producer on publish, cleared by consumer on read).
    private let _state = Atomic<Int>(0)

    private static var SLOT_MASK: Int { 0x3 }
    private static var FRESH_FLAG: Int { 0x4 }

    /// Producer-private — slot the producer is currently filling.
    private var writerSlot: Int = 1
    /// Consumer-private — slot the consumer last read from.
    private var readerSlot: Int = 2

    /// Seed all three storage slots with `initial` so subsequent pushes can use
    /// plain assignment instead of `initialize(to:)`.
    init(initial: T) {
        self.storage = .allocate(capacity: 3)
        for i in 0..<3 { (storage + i).initialize(to: initial) }
        // Initial state: pending = slot 0, NOT FRESH. Writer owns 1, reader owns 2.
        _state.store(0, ordering: .relaxed)
    }

    deinit {
        for i in 0..<3 { (storage + i).deinitialize(count: 1) }
        storage.deallocate()
    }

    // MARK: - Producer (UI thread)

    /// Publish the latest snapshot. Always succeeds; older unconsumed values are
    /// discarded automatically (latest-value semantics).
    func pushLatest(_ value: T) {
        // Plain assignment into our private slot (already initialized at init).
        (storage + writerSlot).pointee = value
        // Atomically publish: swap our slot index (with FRESH set) into _state and
        // take ownership of whatever slot was previously published.
        let newState = writerSlot | Self.FRESH_FLAG
        let oldState = _state.exchange(newState, ordering: .acquiringAndReleasing)
        writerSlot = oldState & Self.SLOT_MASK
    }

    // MARK: - Consumer (render thread)

    /// Returns the latest published snapshot, or `nil` if no new value has been
    /// published since the last call.
    func popLatest() -> T? {
        // Cheap pre-check: if FRESH is clear, no new data — avoid the exchange.
        let cur = _state.load(ordering: .acquiring)
        if (cur & Self.FRESH_FLAG) == 0 { return nil }
        // Take ownership of the published slot, give up our reader slot, clear FRESH.
        let oldState = _state.exchange(readerSlot, ordering: .acquiringAndReleasing)
        readerSlot = oldState & Self.SLOT_MASK
        return (storage + readerSlot).pointee
    }

    /// Whether new data has been published since the last `popLatest()`.
    var hasData: Bool {
        return (_state.load(ordering: .acquiring) & Self.FRESH_FLAG) != 0
    }
}
