//
//  AsyncDEASolverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-01.
//

import Testing
import TestSupport
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
          .timeLimit(testHangGuard))
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
          .timeLimit(testHangGuard))
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
          .timeLimit(testHangGuard))
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
          .timeLimit(testHangGuard))
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
    func insufficientDMUs() async throws {
        let solver = AsyncDEASolver()
        let singleDMU = [DMU(name: "Only", inputs: [1], outputs: [1])]

        await #expect(throws: DEAError.self) {
            _ = try await solver.solve(dmus: singleDMU)
        }
    }

    @Test("Non-positive input values throw nonPositiveValues")
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    func nonPositiveInputValues() async throws {
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
    func nonPositiveOutputValues() async throws {
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
    func emptyDMUArray() async throws {
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
          .timeLimit(testHangGuard))
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
          .timeLimit(testHangGuard))
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

/// Async and sync agreement across **every** model, not just the ones someone
/// remembered to list.
///
/// The existing equivalence tests cover `.ccr` and `.bcc` by hand. When
/// `.superEfficiency` and `.sbm` were added to ``DEAModelType`` the list was not
/// extended, and `solveSingleDMU` — the async path's per-DMU entry point —
/// special-cased SBM and fell through to the standard LP for everything else.
/// A super-efficiency request therefore returned ordinary DEA with every score
/// capped at 1.0: no error, no warning, and output indistinguishable from a
/// correct standard solve.
///
/// It was found downstream, by a consumer whose own equivalence test compared
/// the two paths. A unit scoring 1.875 synchronously came back 1.0.
///
/// These tests are written against the model *space* rather than a remembered
/// list, so a future model case cannot be added without one of them failing.
@Suite("Async/sync model parity")
struct AsyncSyncModelParityTests {

    /// A spread with a clearly super-efficient unit: `cheap` dominates on input
    /// at equal output, so removing it from its own reference set must leave it
    /// scoring above 1.
    private var dmus: [DMU] {
        [
            DMU(name: "cheap", inputs: [2], outputs: [5]),
            DMU(name: "mid", inputs: [4], outputs: [5]),
            DMU(name: "dear", inputs: [6], outputs: [5]),
            DMU(name: "odd", inputs: [3], outputs: [4])
        ]
    }

    /// Every model this package offers, listed so that adding a case to
    /// ``DEAModelType`` without adding it here leaves the enumeration visibly
    /// incomplete next to the type.
    private static let everyModel: [DEAModelType] = [
        .ccr,
        .bcc,
        .superEfficiency(base: .ccr),
        .superEfficiency(base: .bcc),
        .sbm(returnsToScale: .constant),
        .sbm(returnsToScale: .variable)
    ]

    @Test("Async matches sync for every model", arguments: everyModel)
    func asyncMatchesSync(model: DEAModelType) async throws {
        let sync = try DEASolver().solve(dmus: dmus, model: model)
        let async = try await AsyncDEASolver(maxConcurrency: 4).solve(dmus: dmus, model: model)

        #expect(async.scores.count == sync.scores.count)
        for (a, s) in zip(async.scores, sync.scores) {
            #expect(a.name == s.name)
            #expect(a.superEfficiencyInfeasible == s.superEfficiencyInfeasible,
                    "\(model): \(a.name) disagrees on feasibility")
            guard a.efficiency.isFinite, s.efficiency.isFinite else { continue }
            #expect(abs(a.efficiency - s.efficiency) < 1e-9,
                    "\(model): \(a.name) async \(a.efficiency) vs sync \(s.efficiency)")
        }
    }

    /// The property that distinguishes super-efficiency from every other model,
    /// and precisely what capping destroys. Equivalence alone would not have
    /// caught this had both paths been wrong in the same way.
    @Test("Super-efficiency exceeds 1 on both paths", arguments: [DEABaseModel.ccr, .bcc])
    func superEfficiencyExceedsOneOnBothPaths(base: DEABaseModel) async throws {
        let model = DEAModelType.superEfficiency(base: base)

        let sync = try DEASolver().solve(dmus: dmus, model: model)
        let syncCheap = try #require(sync.scores.first { $0.name == "cheap" })
        #expect(syncCheap.efficiency > 1.0, "sync capped a super-efficient unit")

        let async = try await AsyncDEASolver(maxConcurrency: 4).solve(dmus: dmus, model: model)
        let asyncCheap = try #require(async.scores.first { $0.name == "cheap" })
        #expect(asyncCheap.efficiency > 1.0, "async capped a super-efficient unit")
    }

    /// Concurrency level must not change the answer for any model — the async
    /// parity tests previously checked this for `.ccr` alone.
    @Test("Concurrency level does not change results", arguments: everyModel)
    func concurrencyLevelIrrelevant(model: DEAModelType) async throws {
        let one = try await AsyncDEASolver(maxConcurrency: 1).solve(dmus: dmus, model: model)
        let many = try await AsyncDEASolver(maxConcurrency: 8).solve(dmus: dmus, model: model)

        for (a, b) in zip(one.scores, many.scores) {
            #expect(a.name == b.name)
            guard a.efficiency.isFinite, b.efficiency.isFinite else { continue }
            #expect(abs(a.efficiency - b.efficiency) < 1e-9, "\(model): \(a.name) diverged")
        }
    }
}
