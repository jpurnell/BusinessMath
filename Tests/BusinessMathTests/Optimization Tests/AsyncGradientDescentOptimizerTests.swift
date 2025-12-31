//
//  AsyncGradientDescentOptimizerTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tests for AsyncGradientDescentOptimizer (Phase 3.2)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("AsyncGradientDescentOptimizer Tests")
struct AsyncGradientDescentOptimizerTests {

    // MARK: - Initialization Tests

    @Test("AsyncGradientDescentOptimizer default initialization")
    func defaultInitialization() {
        let optimizer = AsyncGradientDescentOptimizer<Double>()

        #expect(optimizer.learningRate == 0.01)
        #expect(abs(optimizer.momentum - 0.797734375) < 0.0001)  // Default momentum value
        #expect(optimizer.useNesterov == false)
    }

    @Test("AsyncGradientDescentOptimizer custom initialization")
    func customInitialization() {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.05,
            tolerance: 1e-4,
            maxIterations: 500,
            momentum: 0.7,  // Valid momentum value (< 0.797734375)
            useNesterov: true,
            stepSize: 1e-5
        )

        #expect(optimizer.learningRate == 0.05)
        #expect(optimizer.momentum == 0.7)
        #expect(optimizer.useNesterov == true)
    }

    // MARK: - Basic Optimization Tests

    @Test("AsyncGradientDescentOptimizer minimizes simple quadratic")
    func minimizeSimpleQuadratic() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000
        )

        // Minimize f(x) = (x - 5)^2
        // Minimum at x = 5, f(5) = 0
        let result = try await optimizer.optimize(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Should find a solution reasonably close to the optimum
        #expect(abs(result.optimalValue - 5.0) < 1.0)
        #expect(abs(result.objectiveValue) < 1.0)
    }

    @Test("AsyncGradientDescentOptimizer respects bounds")
    func respectsBounds() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1
        )

        // Minimize f(x) = x^2 with bounds [2, 10]
        // Unbounded minimum at x=0, but bounds force x >= 2
        let result = try await optimizer.optimize(
            objective: { x in x * x },
            constraints: [],
            initialGuess: 5.0,
            bounds: (lower: 2.0, upper: 10.0)
        )

        #expect(result.optimalValue >= 2.0)
        #expect(result.optimalValue <= 10.0)
    }

    @Test("AsyncGradientDescentOptimizer with momentum")
    func withMomentum() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000,
            momentum: 0.5  // Moderate momentum
        )

        // Minimize simple quadratic f(x) = (x - 4)^2
        let result = try await optimizer.optimize(
            objective: { x in (x - 4.0) * (x - 4.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(abs(result.optimalValue - 4.0) < 0.3)
    }

    @Test("AsyncGradientDescentOptimizer with Nesterov acceleration")
    func withNesterov() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000,
            momentum: 0.5,
            useNesterov: true
        )

        // Minimize f(x) = (x - 3)^2
        let result = try await optimizer.optimize(
            objective: { x in (x - 3.0) * (x - 3.0) },
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        )

        #expect(abs(result.optimalValue - 3.0) < 0.1)
    }

    // MARK: - Progress Reporting Tests

    @Test("AsyncGradientDescentOptimizer streams progress updates")
    func streamsProgressUpdates() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000
        )

        var progressUpdates: [AsyncOptimizationProgress<Double>] = []

        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in (x - 2.0) * (x - 2.0) },
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) {
            progressUpdates.append(progress)
        }

        // Should have received multiple progress updates
        #expect(progressUpdates.count > 0)

        // Progress should be ordered by iteration
        for i in 1..<progressUpdates.count {
            #expect(progressUpdates[i].iteration >= progressUpdates[i-1].iteration)
        }

        // Objective value should decrease over time (generally)
        if progressUpdates.count > 1 {
            let first = progressUpdates.first!.objectiveValue
            let last = progressUpdates.last!.objectiveValue
            #expect(last < first)
        }
    }

    @Test("AsyncGradientDescentOptimizer progress includes gradients")
    func progressIncludesGradients() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1
        )

        var hasGradient = false

        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in x * x },
            constraints: [],
            initialGuess: 5.0,
            bounds: nil
        ) {
            if progress.gradient != nil {
                hasGradient = true
            }

            // Gradient should exist for most iterations
            if progress.iteration > 0 && !progress.hasConverged {
                #expect(progress.gradient != nil)
            }
        }

        #expect(hasGradient == true)
    }

    @Test("AsyncGradientDescentOptimizer respects cancellation")
    func respectsCancellation() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.001,  // Slow convergence
            maxIterations: 10000
        )

        let task = Task {
            var count = 0
            for try await _ in optimizer.optimizeWithProgress(
                objective: { x in x * x },
                constraints: [],
                initialGuess: 100.0,
                bounds: nil
            ) {
                count += 1
                if count >= 5 {
                    // Cancel after a few updates
                    return
                }
            }
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(10))

        // Cancel the task
        task.cancel()

        // Task should complete without crashing
        _ = try? await task.value
    }

    // MARK: - Optimization Config Tests

    @Test("AsyncGradientDescentOptimizer respects config")
    func respectsConfig() async throws {
        let config = OptimizationConfig(
            progressUpdateInterval: .milliseconds(10),
            maxIterations: 100,
            tolerance: 1e-4,
            reportEveryNIterations: 10
        )

        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: config.tolerance,
            maxIterations: config.maxIterations
        )

        var progressUpdates: [AsyncOptimizationProgress<Double>] = []

        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in x * x },
            constraints: [],
            initialGuess: 10.0,
            bounds: nil,
            config: config
        ) {
            progressUpdates.append(progress)
        }

        // Should respect maxIterations
        if let last = progressUpdates.last {
            #expect(last.iteration <= config.maxIterations)
        }
    }

    // MARK: - Convergence Tests

    @Test("AsyncGradientDescentOptimizer converges for convex function")
    func convergesForConvexFunction() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-6
        )

        // Minimize f(x) = (x-7)^2 + 3
        // Minimum at x = 7, f(7) = 3
        let result = try await optimizer.optimize(
            objective: { x in (x - 7.0) * (x - 7.0) + 3.0 },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 7.0) < 0.01)
        #expect(abs(result.objectiveValue - 3.0) < 0.01)
    }

    @Test("AsyncGradientDescentOptimizer handles plateau")
    func handlesPlateau() async throws {
        let optimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-5,
            maxIterations: 2000
        )

        // Simple quadratic: f(x) = (x - 2)^2 + 1
        // Minimum at x = 2, f(2) = 1
        let result = try await optimizer.optimize(
            objective: { x in (x - 2.0) * (x - 2.0) + 1.0 },
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        )

        // Should find the minimum
        #expect(abs(result.optimalValue - 2.0) < 0.2)
    }

    // MARK: - Comparison with Synchronous Version

    @Test("AsyncGradientDescentOptimizer matches synchronous version")
    func matchesSynchronousVersion() async throws {
        let asyncOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000,
            momentum: 0.5
        )

        let syncOptimizer = GradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000,
            momentum: 0.5
        )

        let objective: (Double) -> Double = { x in (x - 4.0) * (x - 4.0) }

        let asyncResult = try await asyncOptimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        let syncResult = syncOptimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Results should be reasonably similar
        #expect(abs(asyncResult.optimalValue - syncResult.optimalValue) < 0.5)
        #expect(abs(asyncResult.objectiveValue - syncResult.objectiveValue) < 0.25)
    }
}
