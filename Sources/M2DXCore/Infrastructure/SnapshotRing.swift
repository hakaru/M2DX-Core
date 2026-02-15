// SnapshotRing.swift
// M2DX-Core — Lock-free SPSC ring buffer for UI → audio thread snapshot transfer
// Uses Synchronization.Atomic (macOS 15+ / iOS 18+, no external dependencies).

import Synchronization

/// Lock-free SPSC (Single-Producer Single-Consumer) ring buffer
/// optimized for "latest value" semantics.
///
/// - **Producer** (UI thread) calls `pushLatest(_:)` to enqueue the newest snapshot.
/// - **Consumer** (render thread) calls `popLatest()` to retrieve only the most
///   recent snapshot, skipping any intermediate values.
/// - Capacity is fixed at init (must be a power of 2).
///
/// Thread-safety: exactly one producer and one consumer. No locks, no CAS loops.
/// Memory ordering: releasing store on writeIndex, acquiring load on readIndex.
package final class SnapshotRing<T>: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<T>
    private let mask: Int  // capacity - 1 (for fast modulo)
    private let capacity: Int
    private let _writeIndex = Atomic<Int>(0)
    private let _readIndex = Atomic<Int>(0)

    /// Create a ring buffer with the given capacity (must be a power of 2).
    init(capacity: Int = 128) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0,
                     "SnapshotRing capacity must be a power of 2")
        self.capacity = capacity
        self.mask = capacity - 1
        self.storage = .allocate(capacity: capacity)
    }

    deinit {
        let r = _readIndex.load(ordering: .relaxed)
        let w = _writeIndex.load(ordering: .relaxed)
        for i in r..<w {
            (storage + (i & mask)).deinitialize(count: 1)
        }
        storage.deallocate()
    }

    // MARK: - Producer (UI thread)

    /// Push a new snapshot. If the ring is full the value is dropped.
    func pushLatest(_ value: T) {
        let w = _writeIndex.load(ordering: .relaxed)
        let r = _readIndex.load(ordering: .acquiring)

        if w - r >= capacity { return }

        let slot = w & mask
        (storage + slot).initialize(to: value)
        _writeIndex.store(w + 1, ordering: .releasing)
    }

    // MARK: - Consumer (render thread)

    /// Pop only the latest snapshot, skipping all intermediate values.
    /// Returns `nil` if the ring is empty.
    func popLatest() -> T? {
        let w = _writeIndex.load(ordering: .acquiring)
        let r = _readIndex.load(ordering: .relaxed)

        if w == r { return nil }

        let latestIndex = w - 1
        for i in r..<latestIndex {
            (storage + (i & mask)).deinitialize(count: 1)
        }

        let latestSlot = latestIndex & mask
        let value = (storage + latestSlot).move()

        _readIndex.store(w, ordering: .releasing)

        return value
    }

    /// Check if there are unread snapshots without consuming them.
    var hasData: Bool {
        let w = _writeIndex.load(ordering: .acquiring)
        let r = _readIndex.load(ordering: .relaxed)
        return w != r
    }
}
