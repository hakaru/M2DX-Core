// AlgorithmTests.swift
// M2DX-Core — Tests for DX7 algorithm flag routing

import Testing
@testable import M2DXCore

@Suite("Algorithm Constants Tests")
struct AlgorithmConstantsTests {

    @Test("32 algorithms defined")
    func count() {
        #expect(kAlgorithmFlags.count == 32, "Should have 32 algorithms")
    }

    @Test("Block size is 64")
    func blockSize() {
        #expect(kBlockSize == 64)
    }

    @Test("Number of operators is 6")
    func numOps() {
        #expect(kNumOperators == 6)
    }
}

@Suite("Algorithm Carrier Count Tests")
struct AlgorithmCarrierCountTests {

    /// Count carriers (operators that output to bus 0 = the main output)
    func countCarriers(_ alg: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> Int {
        var count = 0
        let flags = [alg.0, alg.1, alg.2, alg.3, alg.4, alg.5]
        for f in flags {
            let outbus = Int(f & 3)
            if outbus == 0 { count += 1 }
        }
        return count
    }

    @Test("Algorithm 1: 2 carriers")
    func alg1Carriers() {
        let n = countCarriers(kAlgorithmFlags[0])
        #expect(n == 2, "Algorithm 1 should have 2 carriers, got \(n)")
    }

    @Test("Algorithm 5: 3 carriers")
    func alg5Carriers() {
        let n = countCarriers(kAlgorithmFlags[4])
        #expect(n == 3, "Algorithm 5 should have 3 carriers, got \(n)")
    }

    @Test("Algorithm 32: 6 carriers (all)")
    func alg32Carriers() {
        let n = countCarriers(kAlgorithmFlags[31])
        #expect(n == 6, "Algorithm 32 should have 6 carriers, got \(n)")
    }

    @Test("DX7 algorithm carrier counts (bus0 output)")
    func allCarrierCounts() {
        // Carrier count = operators with outbus==0 (direct main output).
        // Note: DX7 "carrier" concept differs from flag bus0 count for algs 16-18
        // which route through bus2. These values are the actual flag-based counts.
        let expected = [2, 2, 2, 2, 3, 3, 2, 2, 2, 2,
                        2, 2, 2, 2, 2, 1, 1, 1, 3, 3,
                        4, 4, 4, 5, 5, 3, 3, 3, 4, 4,
                        5, 6]
        for i in 0..<32 {
            let n = countCarriers(kAlgorithmFlags[i])
            #expect(n == expected[i], "Algorithm \(i+1) should have \(expected[i]) bus0 outputs, got \(n)")
        }
    }
}

@Suite("Algorithm Feedback Tests")
struct AlgorithmFeedbackTests {

    /// Count operators with feedback flag (0xC0)
    func countFeedbackOps(_ alg: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)) -> Int {
        var count = 0
        let flags = [alg.0, alg.1, alg.2, alg.3, alg.4, alg.5]
        for f in flags {
            if (f & 0xC0) == 0xC0 { count += 1 }
        }
        return count
    }

    @Test("Each algorithm has exactly 1 feedback operator")
    func oneFeedbackPerAlgorithm() {
        for i in 0..<32 {
            let n = countFeedbackOps(kAlgorithmFlags[i])
            #expect(n == 1, "Algorithm \(i+1) should have 1 feedback op, got \(n)")
        }
    }

    @Test("Algorithm 1 feedback on OP6 (index 0)")
    func alg1FeedbackOp() {
        let flags = kAlgorithmFlags[0]
        #expect((flags.0 & 0xC0) == 0xC0, "Algorithm 1 feedback should be on OP6")
    }

    @Test("Algorithm 4 feedback on OP6 (index 0)")
    func alg4FeedbackOp() {
        let flags = kAlgorithmFlags[3]
        #expect((flags.0 & 0xC0) == 0xC0, "Algorithm 4 feedback should be on OP6")
    }
}

@Suite("Algorithm Bus Routing Tests")
struct AlgorithmBusRoutingTests {

    @Test("Algorithm 1: serial chain OP6→OP5→OP4→OP3 + OP2→OP1")
    func alg1Routing() {
        let alg = kAlgorithmFlags[0]
        // OP6 (index 0): feedback + out to bus1
        #expect((alg.0 & 0x03) == 1, "OP6 should output to bus1")
        // OP5 (index 1): in from bus1, out to bus1
        #expect((alg.1 & 0x30) >> 4 == 1, "OP5 should read from bus1")
        // OP1 (index 5): should output to main (bus 0)
        #expect((alg.5 & 0x03) == 0, "OP1 should output to main bus")
    }

    @Test("All operators in each algorithm have valid bus assignments")
    func validBusAssignments() {
        for i in 0..<32 {
            let flags = [kAlgorithmFlags[i].0, kAlgorithmFlags[i].1, kAlgorithmFlags[i].2,
                         kAlgorithmFlags[i].3, kAlgorithmFlags[i].4, kAlgorithmFlags[i].5]
            for (opIdx, f) in flags.enumerated() {
                let outbus = f & 0x03
                let inbus = (f >> 4) & 0x03
                #expect(outbus <= 2, "Alg \(i+1) OP\(6-opIdx) outbus invalid: \(outbus)")
                #expect(inbus <= 2, "Alg \(i+1) OP\(6-opIdx) inbus invalid: \(inbus)")
            }
        }
    }
}
