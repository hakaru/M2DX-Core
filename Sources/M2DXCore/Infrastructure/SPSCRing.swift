// SPSCRing.swift
// M2DX-Core — Lock-free SPSC FIFO ring buffer for real-time safe event transfer
// Uses Synchronization.Atomic (macOS 15+ / iOS 18+, no external dependencies).

import Synchronization

/// Lock-free SPSC (Single-Producer Single-Consumer) FIFO ring buffer.
///
/// Unlike `SnapshotRing` which returns only the latest value, this ring preserves
/// every pushed element in FIFO order — suitable for MIDI event queues where
/// all events must be processed.
///
/// - **Producer** (UI thread) calls `push(_:)` to enqueue an event.
/// - **Consumer** (render thread) calls `pop()` to dequeue the oldest event.
/// - Capacity is fixed at init (must be a power of 2).
///
/// Thread-safety: exactly one producer and one consumer. No locks, no CAS loops.
package final class SPSCRing<T>: @unchecked Sendable {
    private let storage: UnsafeMutablePointer<T>
    private let mask: Int
    private let capacity: Int
    private let _writeIndex = Atomic<Int>(0)
    private let _readIndex = Atomic<Int>(0)

    init(capacity: Int = 256) {
        precondition(capacity > 0 && (capacity & (capacity - 1)) == 0,
                     "SPSCRing capacity must be a power of 2")
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

    /// Push an event. Returns `false` if the ring is full (event dropped).
    @discardableResult
    func push(_ value: T) -> Bool {
        let w = _writeIndex.load(ordering: .relaxed)
        let r = _readIndex.load(ordering: .acquiring)

        if w - r >= capacity { return false }

        (storage + (w & mask)).initialize(to: value)
        _writeIndex.store(w + 1, ordering: .releasing)
        return true
    }

    // MARK: - Consumer (render thread)

    /// Pop the oldest event. Returns `nil` if the ring is empty.
    func pop() -> T? {
        let w = _writeIndex.load(ordering: .acquiring)
        let r = _readIndex.load(ordering: .relaxed)

        if r == w { return nil }

        let value = (storage + (r & mask)).move()
        _readIndex.store(r + 1, ordering: .releasing)
        return value
    }

    /// Number of unread events.
    var count: Int {
        let w = _writeIndex.load(ordering: .acquiring)
        let r = _readIndex.load(ordering: .relaxed)
        return w - r
    }

    /// Check if there are unread events without consuming them.
    var hasData: Bool { count > 0 }
}
