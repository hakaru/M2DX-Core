// DX7Algorithms.swift
// M2DX-Core — DX7 32 algorithm connection pattern data

import Foundation

// MARK: - Algorithm Connection

/// Describes a modulation connection between operators
public struct AlgorithmConnection: Sendable, Equatable {
    /// Source operator (1-6, the modulator)
    public let from: Int
    /// Destination operator (1-6, the modulated)
    public let to: Int

    public init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
}

// MARK: - Algorithm Definition

/// Complete definition of a DX7 algorithm
public struct DX7AlgorithmDefinition: Sendable, Equatable, Identifiable {
    public var id: Int { number }

    /// Algorithm number (1-32)
    public let number: Int
    /// Carrier operator indices (1-6), output to audio
    public let carriers: [Int]
    /// Modulation connections
    public let connections: [AlgorithmConnection]
    /// Operator with feedback (1-6)
    public let feedbackOp: Int

    public init(number: Int, carriers: [Int], connections: [AlgorithmConnection], feedbackOp: Int) {
        self.number = number
        self.carriers = carriers
        self.connections = connections
        self.feedbackOp = feedbackOp
    }
}

// MARK: - All 32 Algorithms

/// Complete set of DX7 algorithm definitions
public enum DX7Algorithms {

    /// All 32 DX7 algorithm definitions
    public static let all: [DX7AlgorithmDefinition] = [
        // Algorithm 1: [6](fb)->5->4->3 | 2->1
        DX7AlgorithmDefinition(
            number: 1, carriers: [1, 3],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 4), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 2: 6->5->4->3 | [2](fb)->1
        DX7AlgorithmDefinition(
            number: 2, carriers: [1, 3],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 4), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 2
        ),
        // Algorithm 3: [6](fb)->5->4 | 3->2->1
        DX7AlgorithmDefinition(
            number: 3, carriers: [1, 4],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 4), .init(from: 3, to: 2), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 4: [6]->5->4 | 3->2->1
        DX7AlgorithmDefinition(
            number: 4, carriers: [1, 4],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 4), .init(from: 3, to: 2), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 5: [6](fb)->5 | 4->3 | 2->1
        DX7AlgorithmDefinition(
            number: 5, carriers: [1, 3, 5],
            connections: [.init(from: 6, to: 5), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 6: [6]->5 | 4->3 | 2->1
        DX7AlgorithmDefinition(
            number: 6, carriers: [1, 3, 5],
            connections: [.init(from: 6, to: 5), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 7: [6](fb)->5, {5+4}->3 | 2->1
        DX7AlgorithmDefinition(
            number: 7, carriers: [1, 3],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 3), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 8: 6->5, {5+[4](fb)}->3 | 2->1
        DX7AlgorithmDefinition(
            number: 8, carriers: [1, 3],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 3), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 4
        ),
        // Algorithm 9: 6->5, {5+4}->3 | [2](fb)->1
        DX7AlgorithmDefinition(
            number: 9, carriers: [1, 3],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 3), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 2
        ),
        // Algorithm 10: {6+5}->4 | [3](fb)->2->1
        DX7AlgorithmDefinition(
            number: 10, carriers: [1, 4],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 3, to: 2), .init(from: 2, to: 1)],
            feedbackOp: 3
        ),
        // Algorithm 11: {[6](fb)+5}->4 | 3->2->1
        DX7AlgorithmDefinition(
            number: 11, carriers: [1, 4],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 3, to: 2), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 12: {6+5+4}->3 | [2](fb)->1
        DX7AlgorithmDefinition(
            number: 12, carriers: [1, 3],
            connections: [.init(from: 6, to: 3), .init(from: 5, to: 3), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 2
        ),
        // Algorithm 13: {[6](fb)+5+4}->3 | 2->1
        DX7AlgorithmDefinition(
            number: 13, carriers: [1, 3],
            connections: [.init(from: 6, to: 3), .init(from: 5, to: 3), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 14: {[6](fb)+5}->4->3 | 2->1
        DX7AlgorithmDefinition(
            number: 14, carriers: [1, 3],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 15: {6+5}->4->3 | [2](fb)->1
        DX7AlgorithmDefinition(
            number: 15, carriers: [1, 3],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 2
        ),
        // Algorithm 16: [6](fb)->5, 4->3, {5+3+2}->1
        DX7AlgorithmDefinition(
            number: 16, carriers: [1],
            connections: [.init(from: 6, to: 5), .init(from: 4, to: 3), .init(from: 5, to: 1), .init(from: 3, to: 1), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 17: 6->5, 4->3, {5+3+[2](fb)}->1
        DX7AlgorithmDefinition(
            number: 17, carriers: [1],
            connections: [.init(from: 6, to: 5), .init(from: 4, to: 3), .init(from: 5, to: 1), .init(from: 3, to: 1), .init(from: 2, to: 1)],
            feedbackOp: 2
        ),
        // Algorithm 18: 6->5->4, {4+[3](fb)+2}->1
        DX7AlgorithmDefinition(
            number: 18, carriers: [1],
            connections: [.init(from: 6, to: 5), .init(from: 5, to: 4), .init(from: 4, to: 1), .init(from: 3, to: 1), .init(from: 2, to: 1)],
            feedbackOp: 3
        ),
        // Algorithm 19: [6](fb)->{5,4} | 3->2->1
        DX7AlgorithmDefinition(
            number: 19, carriers: [1, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4), .init(from: 3, to: 2), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 20: {6+5}->4 | [3](fb)->{2,1}
        DX7AlgorithmDefinition(
            number: 20, carriers: [1, 2, 4],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 3, to: 2), .init(from: 3, to: 1)],
            feedbackOp: 3
        ),
        // Algorithm 21: 6->{5,4} | [3](fb)->{2,1}
        DX7AlgorithmDefinition(
            number: 21, carriers: [1, 2, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4), .init(from: 3, to: 2), .init(from: 3, to: 1)],
            feedbackOp: 3
        ),
        // Algorithm 22: [6](fb)->{5,4,3} | 2->1
        DX7AlgorithmDefinition(
            number: 22, carriers: [1, 3, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4), .init(from: 6, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 6
        ),
        // Algorithm 23: [6](fb)->{5,4} | 3->2 | 1
        DX7AlgorithmDefinition(
            number: 23, carriers: [1, 2, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4), .init(from: 3, to: 2)],
            feedbackOp: 6
        ),
        // Algorithm 24: [6](fb)->{5,4,3} | 2 | 1
        DX7AlgorithmDefinition(
            number: 24, carriers: [1, 2, 3, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4), .init(from: 6, to: 3)],
            feedbackOp: 6
        ),
        // Algorithm 25: [6](fb)->{5,4} | 3 | 2 | 1
        DX7AlgorithmDefinition(
            number: 25, carriers: [1, 2, 3, 4, 5],
            connections: [.init(from: 6, to: 5), .init(from: 6, to: 4)],
            feedbackOp: 6
        ),
        // Algorithm 26: {[6](fb)+5}->4 | 3->2 | 1
        DX7AlgorithmDefinition(
            number: 26, carriers: [1, 2, 4],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 3, to: 2)],
            feedbackOp: 6
        ),
        // Algorithm 27: {6+5}->4 | [3](fb)->2 | 1
        DX7AlgorithmDefinition(
            number: 27, carriers: [1, 2, 4],
            connections: [.init(from: 6, to: 4), .init(from: 5, to: 4), .init(from: 3, to: 2)],
            feedbackOp: 3
        ),
        // Algorithm 28: 6 | [5](fb)->4->3 | 2->1
        DX7AlgorithmDefinition(
            number: 28, carriers: [1, 3, 6],
            connections: [.init(from: 5, to: 4), .init(from: 4, to: 3), .init(from: 2, to: 1)],
            feedbackOp: 5
        ),
        // Algorithm 29: [6](fb)->5 | 4->3 | 2 | 1
        DX7AlgorithmDefinition(
            number: 29, carriers: [1, 2, 3, 5],
            connections: [.init(from: 6, to: 5), .init(from: 4, to: 3)],
            feedbackOp: 6
        ),
        // Algorithm 30: 6 | [5](fb)->4->3 | 2 | 1
        DX7AlgorithmDefinition(
            number: 30, carriers: [1, 2, 3, 6],
            connections: [.init(from: 5, to: 4), .init(from: 4, to: 3)],
            feedbackOp: 5
        ),
        // Algorithm 31: [6](fb)->5 | 4 | 3 | 2 | 1
        DX7AlgorithmDefinition(
            number: 31, carriers: [1, 2, 3, 4, 5],
            connections: [.init(from: 6, to: 5)],
            feedbackOp: 6
        ),
        // Algorithm 32: [6](fb) | 5 | 4 | 3 | 2 | 1
        DX7AlgorithmDefinition(
            number: 32, carriers: [1, 2, 3, 4, 5, 6],
            connections: [],
            feedbackOp: 6
        ),
    ]

    /// Get algorithm definition by number (1-32)
    public static func definition(for number: Int) -> DX7AlgorithmDefinition? {
        guard number >= 1, number <= 32 else { return nil }
        return all[number - 1]
    }
}
