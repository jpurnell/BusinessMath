//
//  AsyncDEASolverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
@testable import BusinessMath

// MARK: - Reference Data

/// Minimal 3-DMU dataset for async parity checks.
/// DEA correctness is validated in the synchronous test suites.
private let parityDMUs: [DMU] = [
    DMU(name: "A", inputs: [2], outputs: [1]),
    DMU(name: "B", inputs: [3], outputs: [2]),
    DMU(name: "C", inputs: [5], outputs: [4])
]

// MARK: - Correctness: Async Matches Synchronous

@Suite("AsyncDEA Correctness")
struct AsyncDEACorrectnessTests {

    @Test("CCR input-oriented async results match synchronous solver",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func ccrInputOrientedMatchesSynchronous() async throws {
        let syncSolver = DEASolver()
        let syncResult = try syncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let asyncSolver = AsyncDEASolver()
        let asyncResult = try await asyncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        #expect(asyncResult.scores.count == syncResult.scores.count)
        #expect(asyncResult.model == syncResult.model)
        #expect(asyncResult.orientation == syncResult.orientation)

        let syncSorted = syncResult.scores.sorted { $0.name < $1.name }
        let asyncSorted = asyncResult.scores.sorted { $0.name < $1.name }

        for (sync, asyncScore) in zip(syncSorted, asyncSorted) {
            #expect(sync.name == asyncScore.name)
            #expect(
                abs(sync.efficiency - asyncScore.efficiency) < 1e-10,
                "Efficiency mismatch for DMU \(sync.name): sync=\(sync.efficiency), async=\(asyncScore.efficiency)"
            )
            #expect(
                abs(sync.rawScore - asyncScore.rawScore) < 1e-10,
                "RawScore mismatch for DMU \(sync.name)"
            )
        }
    }

    @Test("BCC input-oriented async results match synchronous solver",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func bccInputOrientedMatchesSynchronous() async throws {
        let syncSolver = DEASolver()
        let syncResult = try syncSolver.solve(
            dmus: parityDMUs,
            model: .bcc,
            orientation: .inputOriented
        )

        let asyncSolver = AsyncDEASolver()
        let asyncResult = try await asyncSolver.solve(
            dmus: parityDMUs,
            model: .bcc,
            orientation: .inputOriented
        )

        #expect(asyncResult.scores.count == syncResult.scores.count)

        let syncSorted = syncResult.scores.sorted { $0.name < $1.name }
        let asyncSorted = asyncResult.scores.sorted { $0.name < $1.name }

        for (sync, asyncScore) in zip(syncSorted, asyncSorted) {
            #expect(sync.name == asyncScore.name)
            #expect(
                abs(sync.efficiency - asyncScore.efficiency) < 1e-10,
                "BCC efficiency mismatch for DMU \(sync.name)"
            )
        }
    }

    @Test("Output-oriented async results match synchronous solver",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func outputOrientedMatchesSynchronous() async throws {
        let syncSolver = DEASolver()
        let syncResult = try syncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        let asyncSolver = AsyncDEASolver()
        let asyncResult = try await asyncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .outputOriented
        )

        #expect(asyncResult.scores.count == syncResult.scores.count)

        let syncSorted = syncResult.scores.sorted { $0.name < $1.name }
        let asyncSorted = asyncResult.scores.sorted { $0.name < $1.name }

        for (sync, asyncScore) in zip(syncSorted, asyncSorted) {
            #expect(sync.name == asyncScore.name)
            #expect(
                abs(sync.efficiency - asyncScore.efficiency) < 1e-10,
                "Output-oriented efficiency mismatch for DMU \(sync.name)"
            )
            #expect(
                abs(sync.rawScore - asyncScore.rawScore) < 1e-10,
                "Output-oriented rawScore mismatch for DMU \(sync.name)"
            )
        }
    }
}

// MARK: - Concurrency Determinism

@Suite("AsyncDEA Concurrency Determinism")
struct AsyncDEAConcurrencyDeterminismTests {

    @Test("maxConcurrency 1, 2, and 4 produce identical scores",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func concurrencyLevelsProduceIdenticalResults() async throws {
        let solver1 = AsyncDEASolver(maxConcurrency: 1)
        let solver2 = AsyncDEASolver(maxConcurrency: 2)
        let solver4 = AsyncDEASolver(maxConcurrency: 4)

        let result1 = try await solver1.solve(dmus: parityDMUs, model: .ccr)
        let result2 = try await solver2.solve(dmus: parityDMUs, model: .ccr)
        let result4 = try await solver4.solve(dmus: parityDMUs, model: .ccr)

        let sorted1 = result1.scores.sorted { $0.name < $1.name }
        let sorted2 = result2.scores.sorted { $0.name < $1.name }
        let sorted4 = result4.scores.sorted { $0.name < $1.name }

        for i in 0..<sorted1.count {
            #expect(sorted1[i].name == sorted2[i].name)
            #expect(sorted1[i].name == sorted4[i].name)
            #expect(
                abs(sorted1[i].efficiency - sorted2[i].efficiency) < 1e-10,
                "Concurrency 1 vs 2 mismatch for DMU \(sorted1[i].name)"
            )
            #expect(
                abs(sorted1[i].efficiency - sorted4[i].efficiency) < 1e-10,
                "Concurrency 1 vs 4 mismatch for DMU \(sorted1[i].name)"
            )
        }
    }
}

// MARK: - Input Validation

@Suite("AsyncDEA Input Validation")
struct AsyncDEAInputValidationTests {

    @Test("Fewer than 2 DMUs throws insufficientDMUs")
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func insufficientDMUs() async {
        let solver = AsyncDEASolver()
        let singleDMU = [DMU(name: "Only", inputs: [1], outputs: [1])]

        await #expect(throws: DEAError.self) {
            _ = try await solver.solve(dmus: singleDMU)
        }
    }

    @Test("Non-positive input values throw nonPositiveValues")
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func nonPositiveInputValues() async {
        let solver = AsyncDEASolver()
        let dmus = [
            DMU(name: "A", inputs: [1, 2], outputs: [3]),
            DMU(name: "B", inputs: [0, 2], outputs: [3])
        ]

        await #expect(throws: DEAError.self) {
            _ = try await solver.solve(dmus: dmus)
        }
    }

    @Test("Non-positive output values throw nonPositiveValues")
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func nonPositiveOutputValues() async {
        let solver = AsyncDEASolver()
        let dmus = [
            DMU(name: "A", inputs: [1, 2], outputs: [3]),
            DMU(name: "B", inputs: [1, 2], outputs: [-1])
        ]

        await #expect(throws: DEAError.self) {
            _ = try await solver.solve(dmus: dmus)
        }
    }

    @Test("Empty DMU array throws insufficientDMUs")
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func emptyDMUArray() async {
        let solver = AsyncDEASolver()

        await #expect(throws: DEAError.self) {
            _ = try await solver.solve(dmus: [])
        }
    }
}

// MARK: - Moderate Scale

@Suite("AsyncDEA Scale Tests")
struct AsyncDEAScaleTests {

    @Test("50 DMUs with 3 inputs / 3 outputs — all scores in (0, 1]",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func fiftyDMUsModerateScale() async throws {
        var dmus: [DMU] = []
        for i in 0..<50 {
            let seed = Double(i + 1)
            let inputs = [
                seed + 1.0,
                seed * 0.5 + 2.0,
                seed * 0.3 + 3.0
            ]
            let outputs = [
                seed * 0.2 + 0.5,
                seed * 0.1 + 1.0,
                seed * 0.15 + 0.8
            ]
            dmus.append(DMU(name: "DMU_\(i)", inputs: inputs, outputs: outputs))
        }

        let solver = AsyncDEASolver()
        let result = try await solver.solve(dmus: dmus, model: .ccr)

        #expect(result.scores.count == 50)
        for score in result.scores {
            #expect(
                score.efficiency > 0,
                "Score must be > 0 for DMU \(score.name)"
            )
            #expect(
                score.efficiency <= 1.0 + 1e-6,
                "Score must be <= 1.0 for DMU \(score.name)"
            )
        }
    }
}

// MARK: - Sequential Equivalence

@Suite("AsyncDEA Sequential Equivalence")
struct AsyncDEASequentialEquivalenceTests {

    @Test("maxConcurrency = 1 produces correct results (sequential fallback)",
          .timeLimit(.minutes(2)))
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func maxConcurrencyOneEquivalentToSequential() async throws {
        let syncSolver = DEASolver()
        let syncResult = try syncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        let asyncSolver = AsyncDEASolver(maxConcurrency: 1)
        let asyncResult = try await asyncSolver.solve(
            dmus: parityDMUs,
            model: .ccr,
            orientation: .inputOriented
        )

        #expect(asyncResult.scores.count == syncResult.scores.count)

        let syncSorted = syncResult.scores.sorted { $0.name < $1.name }
        let asyncSorted = asyncResult.scores.sorted { $0.name < $1.name }

        for (sync, asyncScore) in zip(syncSorted, asyncSorted) {
            #expect(sync.name == asyncScore.name)
            #expect(
                abs(sync.efficiency - asyncScore.efficiency) < 1e-10,
                "Sequential async mismatch for DMU \(sync.name)"
            )
        }
    }
}
