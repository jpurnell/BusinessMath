//
//  LBFGSOptimizerTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Testing
@testable import BusinessMath

/// Tests for L-BFGS optimizer with adaptive progress
@Suite("L-BFGS Optimizer Tests")
struct LBFGSOptimizerTests {

    // MARK: - Basic Optimization Tests

    @Test("L-BFGS optimizes simple quadratic function")
    func simpleQuadratic() async throws {
        // f(x) = (x - 3)^2, minimum at x = 3
        let objective: (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 3.0) < 0.01)
        #expect(result.objectiveValue < 0.01)
    }

    @Test("L-BFGS optimizes Rosenbrock function")
    func rosenbrockFunction() async throws {
        // Rosenbrock: f(x,y) = (1-x)^2 + 100(y-x^2)^2
        // Represented as f(t) where t encodes both x and y
        // For 1D test: f(x) = (1-x)^2 + 100(2-x^2)^2, minimum near x ≈ 1
        let objective: (Double) -> Double = { x in
            let term1 = (1.0 - x) * (1.0 - x)
            let term2 = 100.0 * (2.0 - x * x) * (2.0 - x * x)
            return term1 + term2
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 10,
            tolerance: 1e-4,
            maxIterations: 200
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        // Should find a local minimum
        #expect(result.iterations > 10) // Not trivial
    }

    @Test("L-BFGS with tight tolerance")
    func tightTolerance() async throws {
        let objective: (Double) -> Double = { x in
            (x - 5.0) * (x - 5.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-10,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 5.0) < 1e-6)
    }

    // MARK: - Memory Size Tests

    @Test("L-BFGS with limited memory (m=3)")
    func limitedMemory() async throws {
        let objective: (Double) -> Double = { x in
            (x - 4.0) * (x - 4.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 3, // Very limited
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 4.0) < 0.01)
    }

    @Test("L-BFGS with larger memory (m=20)")
    func largerMemory() async throws {
        let objective: (Double) -> Double = { x in
            (x - 4.0) * (x - 4.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 20,
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 4.0) < 0.01)
        // Should converge faster with more memory
        #expect(result.iterations < 50)
    }

    // MARK: - Adaptive Progress Tests

    @Test("L-BFGS with fixed interval progress reporting")
    func fixedIntervalProgress() async throws {
        let objective: (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 5)
        )

        var progressUpdates: [Int] = []
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) { progress in
            progressUpdates.append(progress.iteration)
        }

        #expect(result.converged)
        #expect(progressUpdates.count > 0)

        // Verify fixed interval reporting
        if progressUpdates.count >= 2 {
            let interval = progressUpdates[1] - progressUpdates[0]
            #expect(interval == 5)
        }
    }

    @Test("L-BFGS with exponential backoff progress")
    func exponentialBackoffProgress() async throws {
        let objective: (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: ExponentialBackoffStrategy(
                initialInterval: 1,
                maxInterval: 50,
                backoffFactor: 2.0
            )
        )

        var progressUpdates: [Int] = []
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) { progress in
            progressUpdates.append(progress.iteration)
        }

        #expect(result.converged)
        #expect(progressUpdates.count > 0)
    }

    @Test("L-BFGS with convergence-based progress")
    func convergenceBasedProgress() async throws {
        let objective: (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: ConvergenceBasedStrategy(
                minInterval: 1,
                maxInterval: 20,
                convergenceThreshold: 0.01
            )
        )

        var metricsHistory: [ConvergenceMetrics] = []
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) { progress in
            metricsHistory.append(progress.metrics)
        }

        #expect(result.converged)
        #expect(metricsHistory.count > 0)

        // Verify metrics are reasonable
        if let lastMetrics = metricsHistory.last {
            #expect(lastMetrics.gradientNorm < 0.1)
        }
    }

    // MARK: - Convergence Detection Tests

    @Test("L-BFGS with convergence detector enables early stopping")
    func convergenceDetectorEarlyStopping() async throws {
        let objective: (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let detector = ConvergenceDetector(
            windowSize: 5,
            improvementThreshold: 0.001,
            gradientThreshold: 0.01
        )

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-10, // Very tight, but detector should stop earlier
            maxIterations: 1000,
            progressStrategy: FixedIntervalStrategy(interval: 1),
            convergenceDetector: detector
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        // Should stop before maxIterations due to detector
        #expect(result.iterations < 1000)
        #expect(result.iterations < 100) // Should be much faster
    }

    @Test("L-BFGS reports convergence metrics correctly")
    func convergenceMetricsCorrectness() async throws {
        let objective: (Double) -> Double = { x in
            (x - 1.0) * (x - 1.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 1)
        )

        var lastMetrics: ConvergenceMetrics?
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 5.0,
            bounds: nil
        ) { progress in
            lastMetrics = progress.metrics
        }

        #expect(result.converged)
        #expect(lastMetrics != nil)

        if let metrics = lastMetrics {
            // Near convergence, gradient should be small
            #expect(metrics.gradientNorm < 0.1)
            // Relative change should be small
            #expect(metrics.relativeChange < 0.1)
            // Step size should be positive
            #expect(metrics.stepSize >= 0)
        }
    }

    // MARK: - AsyncSequence Progress Stream Tests

    @Test("L-BFGS provides AsyncSequence of progress updates")
    func progressAsyncSequence() async throws {
        let objective: (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 5)
        )

        var progressUpdates: [LBFGSProgress] = []

        let stream = optimizer.optimizeWithProgressStream(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        )

        for try await progress in stream {
            progressUpdates.append(progress)
        }

        #expect(progressUpdates.count > 0)

        // Final update should have result
        if let last = progressUpdates.last {
            #expect(last.result != nil)
            #expect(last.result?.converged == true)
        }
    }

    // MARK: - Edge Cases

    @Test("L-BFGS handles already optimal initial guess")
    func alreadyOptimal() async throws {
        let objective: (Double) -> Double = { x in
            (x - 7.0) * (x - 7.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 7.0, // Already at optimum
            bounds: nil
        )

        #expect(result.converged)
        #expect(result.iterations < 10) // Should converge very quickly
        #expect(abs(result.optimalValue - 7.0) < 0.01)
    }

    @Test("L-BFGS handles difficult initial guess")
    func difficultInitialGuess() async throws {
        let objective: (Double) -> Double = { x in
            (x - 5.0) * (x - 5.0)
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 10,
            tolerance: 1e-6,
            maxIterations: 200
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 1000.0, // Very far from optimum
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 5.0) < 0.1)
    }

    @Test("L-BFGS respects max iterations")
    func respectsMaxIterations() async throws {
        // Difficult function with very tight tolerance
        let objective: (Double) -> Double = { x in
            let term1 = (1.0 - x) * (1.0 - x)
            let term2 = 100.0 * (2.0 - x * x) * (2.0 - x * x)
            return term1 + term2
        }

        let optimizer = AsyncLBFGSOptimizer(
            memorySize: 5,
            tolerance: 1e-15, // Impossibly tight
            maxIterations: 10 // Very few iterations
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Should not exceed max iterations
        #expect(result.iterations <= 10)
    }
}
