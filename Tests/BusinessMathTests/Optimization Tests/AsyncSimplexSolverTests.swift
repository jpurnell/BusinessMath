//
//  AsyncSimplexSolverTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for AsyncSimplexSolver (Phase 3.4)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("AsyncSimplexSolver Tests")
struct AsyncSimplexSolverTests {

    // MARK: - Initialization Tests

    @Test("AsyncSimplexSolver default initialization")
    func defaultInitialization() {
        let solver = AsyncSimplexSolver()

        #expect(solver.tolerance == 1e-10)
        #expect(solver.maxIterations == 10_000)
    }

    @Test("AsyncSimplexSolver custom initialization")
    func customInitialization() {
        let solver = AsyncSimplexSolver(tolerance: 1e-8, maxIterations: 5000)

        #expect(solver.tolerance == 1e-8)
        #expect(solver.maxIterations == 5000)
    }

    // MARK: - Basic Maximization Tests

    @Test("AsyncSimplexSolver simple 2D maximization")
    func simple2DMaximization() async throws {
        // Maximize 3x + 2y
        // Subject to: x + y ≤ 4
        //            2x + y ≤ 5
        //            x, y ≥ 0
        // Optimal: (1, 3) with value 9

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [3.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(abs(result.objectiveValue - 9.0) < 1e-6)
        #expect(abs(result.solution[0] - 1.0) < 1e-6)
        #expect(abs(result.solution[1] - 3.0) < 1e-6)
    }

    // MARK: - Basic Minimization Tests

    @Test("AsyncSimplexSolver simple 2D minimization")
    func simple2DMinimization() async throws {
        // Minimize 2x + 3y
        // Subject to: x + y ≥ 4
        //            2x + y ≥ 5
        //            x, y ≥ 0
        // Optimal: (4, 0) with value 8

        let solver = AsyncSimplexSolver()

        let result = try await solver.minimize(
            objective: [2.0, 3.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .greaterOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(abs(result.objectiveValue - 8.0) < 1e-6)
        #expect(abs(result.solution[0] - 4.0) < 1e-6)
        #expect(abs(result.solution[1] - 0.0) < 1e-6)
    }

    // MARK: - Constraint Type Tests

    @Test("AsyncSimplexSolver with equality constraints")
    func equalityConstraints() async throws {
        // Maximize x + 2y
        // Subject to: x + y = 3
        //            x, y ≥ 0
        // Optimal: (0, 3) with value 6

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [1.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .equal, rhs: 3.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(abs(result.objectiveValue - 6.0) < 1e-6)
        #expect(abs(result.solution[0] - 0.0) < 1e-6)
        #expect(abs(result.solution[1] - 3.0) < 1e-6)
    }

    @Test("AsyncSimplexSolver with mixed constraints")
    func mixedConstraints() async throws {
        // Maximize 3x + 4y
        // Subject to: x + 2y ≤ 8  (lessOrEqual)
        //            3x + 2y ≥ 6  (greaterOrEqual)
        //            x + y = 4    (equal)
        //            x, y ≥ 0

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [3.0, 4.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 8.0),
                SimplexConstraint(coefficients: [3.0, 2.0], relation: .greaterOrEqual, rhs: 6.0),
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .equal, rhs: 4.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(result.objectiveValue > 0)
    }

    // MARK: - Special Cases

    @Test("AsyncSimplexSolver unbounded problem")
    func unboundedProblem() async throws {
        // Maximize x + y
        // Subject to: -x + y ≤ 1
        //            x, y ≥ 0
        // Unbounded

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [-1.0, 1.0], relation: .lessOrEqual, rhs: 1.0)
            ]
        )

        #expect(result.status == .unbounded)
    }

    @Test("AsyncSimplexSolver infeasible problem")
    func infeasibleProblem() async throws {
        // Maximize x + y
        // Subject to: x + y ≤ 2
        //            x + y ≥ 3
        //            x, y ≥ 0
        // Infeasible

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 2.0),
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 3.0)
            ]
        )

        #expect(result.status == .infeasible)
    }

    // MARK: - Progress Reporting Tests

    @Test("AsyncSimplexSolver streams progress updates")
    func streamsProgressUpdates() async throws {
        let solver = AsyncSimplexSolver()

        let collector = ProgressCollector<SimplexProgress>()

        for try await progress in solver.maximizeWithProgress(
            objective: [3.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
            ]
        ) {
            collector.append(progress)
        }

        let progressUpdates = collector.getItems()

        // Should receive progress updates
        #expect(progressUpdates.count > 0)

        // First update should be initialization
        #expect(progressUpdates.first?.phase == .initialization)

        // Last update should be finalization
        #expect(progressUpdates.last?.phase == .finalization)

        // Should have some optimization updates
        let optimizationUpdates = progressUpdates.filter { $0.phase == .optimization }
        #expect(optimizationUpdates.count > 0)
    }

    @Test("AsyncSimplexSolver progress includes phase information")
    func progressIncludesPhaseInfo() async throws {
        let solver = AsyncSimplexSolver()

        var hasPhaseI = false
        var hasPhaseII = false

        for try await progress in solver.maximizeWithProgress(
            objective: [1.0, 1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual, rhs: 2.0)
            ]
        ) {
            if progress.currentPhase == "Phase I" {
                hasPhaseI = true
            }
            if progress.currentPhase == "Phase II" {
                hasPhaseII = true
            }
        }

        // Problems with artificial variables should have Phase I
        #expect(hasPhaseI)
        // Should always have Phase II
        #expect(hasPhaseII)
    }

    @Test("AsyncSimplexSolver progress reports objective value")
    func progressReportsObjectiveValue() async throws {
        let solver = AsyncSimplexSolver()

        var finalObjective: Double?

        for try await progress in solver.maximizeWithProgress(
            objective: [3.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
            ]
        ) {
            if progress.phase == .finalization {
                finalObjective = progress.currentObjectiveValue
            }
        }

        #expect(finalObjective != nil)
        #expect(abs(finalObjective! - 9.0) < 1e-6)
    }

    // MARK: - Cancellation Tests

    @Test("AsyncSimplexSolver respects cancellation")
    func respectsCancellation() async throws {
        let solver = AsyncSimplexSolver(maxIterations: 10000)

        let task = Task<Int, Error> {
            var count = 0
            for try await _ in solver.maximizeWithProgress(
                objective: [1.0, 1.0],
                subjectTo: [
                    SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 100.0)
                ]
            ) {
                count += 1
                if count >= 3 {
                    return count
                }
            }
            return count
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(10))

        // Cancel the task
        task.cancel()

        // Should terminate without crashing
        _ = try? await task.value
    }

    // MARK: - Comparison with Synchronous Version

    @Test("AsyncSimplexSolver matches synchronous SimplexSolver")
    func matchesSynchronousVersion() async throws {
        let asyncSolver = AsyncSimplexSolver()
        let syncSolver = SimplexSolver()

        let objective = [3.0, 2.0]
        let constraints = [
            SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
            SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
        ]

        let asyncResult = try await asyncSolver.maximize(
            objective: objective,
            subjectTo: constraints
        )

        let syncResult = try syncSolver.maximize(
            objective: objective,
            subjectTo: constraints
        )

        // Results should match
        #expect(asyncResult.status == syncResult.status)
        #expect(abs(asyncResult.objectiveValue - syncResult.objectiveValue) < 1e-6)
        #expect(asyncResult.solution.count == syncResult.solution.count)
        for i in 0..<asyncResult.solution.count {
            #expect(abs(asyncResult.solution[i] - syncResult.solution[i]) < 1e-6)
        }
    }

    // MARK: - Real-World Problems

    @Test("AsyncSimplexSolver production planning problem")
    func productionPlanningProblem() async throws {
        // Maximize profit: 40*chairs + 30*tables
        // Subject to: 1*chairs + 2*tables ≤ 40  (wood)
        //            2*chairs + 1*tables ≤ 50  (labor)
        //            chairs, tables ≥ 0

        let solver = AsyncSimplexSolver()

        let result = try await solver.maximize(
            objective: [40.0, 30.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 2.0], relation: .lessOrEqual, rhs: 40.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 50.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(result.objectiveValue > 0)
    }

    @Test("AsyncSimplexSolver diet problem")
    func dietProblem() async throws {
        // Minimize cost: 2*bread + 3*milk
        // Subject to: 4*bread + 3*milk ≥ 10  (calories)
        //            1*bread + 2*milk ≥ 5   (protein)
        //            bread, milk ≥ 0

        let solver = AsyncSimplexSolver()

        let result = try await solver.minimize(
            objective: [2.0, 3.0],
            subjectTo: [
                SimplexConstraint(coefficients: [4.0, 3.0], relation: .greaterOrEqual, rhs: 10.0),
                SimplexConstraint(coefficients: [1.0, 2.0], relation: .greaterOrEqual, rhs: 5.0)
            ]
        )

        #expect(result.status == .optimal)
        #expect(result.objectiveValue > 0)
    }

    // MARK: - Configuration Tests

    @Test("AsyncSimplexSolver respects config")
    func respectsConfig() async throws {
        let config = OptimizationConfig(
            progressUpdateInterval: .milliseconds(10),
            maxIterations: 100,
            tolerance: 1e-10,
            reportEveryNIterations: 5
        )

        let solver = AsyncSimplexSolver(
            tolerance: config.tolerance,
            maxIterations: config.maxIterations
        )

        let collector = ProgressCollector<SimplexProgress>()

        for try await progress in solver.maximizeWithProgress(
            objective: [3.0, 2.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual, rhs: 4.0),
                SimplexConstraint(coefficients: [2.0, 1.0], relation: .lessOrEqual, rhs: 5.0)
            ],
            config: config
        ) {
            collector.append(progress)
        }

        let progressUpdates = collector.getItems()

        // Should receive updates
        #expect(progressUpdates.count > 0)
    }
}
