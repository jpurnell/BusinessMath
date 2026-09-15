//
//  DEAModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
@testable import BusinessMath

// MARK: - Input Validation Tests

@Suite("DEA Input Validation")
struct DEAInputValidationTests {

    let solver = DEASolver()

    // MARK: - Insufficient DMUs

    @Test("Empty DMU array throws insufficientDMUs")
    func emptyDMUArray() throws {
        // `DEAError` is not `Equatable`, so the case and its payload are matched by hand.
        #expect {
            _ = try solver.solve(dmus: [])
        } throws: { error in
            guard case let DEAError.insufficientDMUs(count) = error else { return false }
            return count == 0
        }
    }

    @Test("Single DMU throws insufficientDMUs")
    func singleDMU() throws {
        let dmu = DMU(name: "A", inputs: [1.0], outputs: [1.0])
        #expect {
            _ = try solver.solve(dmus: [dmu])
        } throws: { error in
            guard case let DEAError.insufficientDMUs(count) = error else { return false }
            return count == 1
        }
    }

    // MARK: - Non-Positive Values

    @Test("Zero input value throws nonPositiveValues")
    func zeroInput() throws {
        let dmus = [
            DMU(name: "A", inputs: [0.0, 5.0], outputs: [1.0]),
            DMU(name: "B", inputs: [3.0, 3.0], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.nonPositiveValues(dmu, dimension) = error else { return false }
            return dmu == "A" && dimension == "input[0]"
        }
    }

    @Test("Negative input value throws nonPositiveValues")
    func negativeInput() throws {
        let dmus = [
            DMU(name: "A", inputs: [-1.0, 5.0], outputs: [1.0]),
            DMU(name: "B", inputs: [3.0, 3.0], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.nonPositiveValues(dmu, dimension) = error else { return false }
            return dmu == "A" && dimension == "input[0]"
        }
    }

    @Test("Zero output value throws nonPositiveValues")
    func zeroOutput() throws {
        let dmus = [
            DMU(name: "A", inputs: [2.0], outputs: [0.0]),
            DMU(name: "B", inputs: [3.0], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.nonPositiveValues(dmu, dimension) = error else { return false }
            return dmu == "A" && dimension == "output[0]"
        }
    }

    @Test("Negative output value throws nonPositiveValues")
    func negativeOutput() throws {
        let dmus = [
            DMU(name: "A", inputs: [2.0], outputs: [-1.0]),
            DMU(name: "B", inputs: [3.0], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.nonPositiveValues(dmu, dimension) = error else { return false }
            return dmu == "A" && dimension == "output[0]"
        }
    }

    // MARK: - Dimension Mismatches

    @Test("Mismatched input dimensions throws dimensionMismatch")
    func mismatchedInputDimensions() throws {
        let dmus = [
            DMU(name: "A", inputs: [2.0, 5.0], outputs: [1.0]),
            DMU(name: "B", inputs: [3.0], outputs: [2.0])
        ]
        // The mismatch names the DMU that disagreed and both widths.
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.dimensionMismatch(expected, actual, dmu) = error else { return false }
            return expected == 2 && actual == 1 && dmu == "B"
        }
    }

    @Test("Mismatched output dimensions throws dimensionMismatch")
    func mismatchedOutputDimensions() throws {
        let dmus = [
            DMU(name: "A", inputs: [2.0], outputs: [1.0, 4.0]),
            DMU(name: "B", inputs: [3.0], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.dimensionMismatch(expected, actual, dmu) = error else { return false }
            return expected == 2 && actual == 1 && dmu == "B"
        }
    }

    // MARK: - Empty Dimensions

    @Test("Empty inputs throws emptyDimension")
    func emptyInputs() throws {
        let dmus = [
            DMU(name: "A", inputs: [], outputs: [1.0]),
            DMU(name: "B", inputs: [], outputs: [2.0])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.emptyDimension(description) = error else { return false }
            return description == "No input dimensions specified"
        }
    }

    @Test("Empty outputs throws emptyDimension")
    func emptyOutputs() throws {
        let dmus = [
            DMU(name: "A", inputs: [2.0], outputs: []),
            DMU(name: "B", inputs: [3.0], outputs: [])
        ]
        #expect {
            _ = try solver.solve(dmus: dmus)
        } throws: { error in
            guard case let DEAError.emptyDimension(description) = error else { return false }
            return description == "No output dimensions specified"
        }
    }
}

// MARK: - DMU Type Tests

@Suite("DMU Type")
struct DMUTypeTests {

    @Test("DMU stores name, inputs, and outputs")
    func dmuCreation() {
        let dmu = DMU(name: "TestUnit", inputs: [1.0, 2.0], outputs: [3.0, 4.0])
        #expect(dmu.name == "TestUnit")
        #expect(identical(dmu.inputs, [1.0, 2.0]))
        #expect(identical(dmu.outputs, [3.0, 4.0]))
    }

    @Test("DMU conforms to Sendable")
    func dmuSendable() {
        let dmu = DMU(name: "A", inputs: [1.0], outputs: [1.0])
        let sendable: any Sendable = dmu
        #expect(sendable is DMU)
    }
}

// MARK: - Result Type Tests

@Suite("DEA Result Types")
struct DEAResultTypeTests {

    @Test("DMUScore isEfficient for score of 1.0")
    func efficientScore() {
        let score = DMUScore(
            name: "A",
            efficiency: 1.0,
            rawScore: 1.0,
            referenceSet: []
        )
        #expect(score.isEfficient)
    }

    @Test("DMUScore not efficient for score below 1.0")
    func inefficientScore() {
        let score = DMUScore(
            name: "D",
            efficiency: 0.632,
            rawScore: 0.632,
            referenceSet: []
        )
        #expect(!score.isEfficient)
    }

    @Test("DMUScore isEfficient handles floating point near 1.0")
    func nearOneEfficiency() {
        let score = DMUScore(
            name: "X",
            efficiency: 1.0 - 1e-8,
            rawScore: 1.0 - 1e-8,
            referenceSet: []
        )
        #expect(score.isEfficient)
    }

    @Test("DEAResult separates efficient and inefficient DMUs")
    func resultPartitioning() {
        let result = DEAResult(
            scores: [
                DMUScore(name: "A", efficiency: 1.0, rawScore: 1.0, referenceSet: []),
                DMUScore(name: "B", efficiency: 0.8, rawScore: 0.8, referenceSet: []),
                DMUScore(name: "C", efficiency: 1.0, rawScore: 1.0, referenceSet: [])
            ],
            model: .ccr,
            orientation: .inputOriented,
            totalIterations: 30
        )
        #expect(result.efficientDMUs == ["A", "C"])
        #expect(result.inefficientDMUs == ["B"])
    }
}
