//
//  ConjugateGradientOptimizerTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Testing
@testable import BusinessMath

/// Tests for Conjugate Gradient optimizer with adaptive progress
@Suite("Conjugate Gradient Optimizer Tests")
struct ConjugateGradientOptimizerTests {

    // MARK: - Basic Optimization Tests

    @Test("Conjugate Gradient optimizes simple quadratic function")
    func simpleQuadratic() async throws {
        // f(x) = (x - 4)^2, minimum at x = 4
        let objective: @Sendable (Double) -> Double = { x in
            (x - 4.0) * (x - 4.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
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
        #expect(result.objectiveValue < 0.01)
    }

    @Test("Conjugate Gradient optimizes steep quadratic")
    func steepQuadratic() async throws {
        // f(x) = 10(x - 2)^2, minimum at x = 2
        let objective: @Sendable  (Double) -> Double = { x in
            10.0 * (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 2.0) < 0.01)
    }

    // MARK: - CG Method Variants Tests

    @Test("Fletcher-Reeves method")
    func fletcherReevesMethod() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
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
    }

    @Test("Polak-Ribière method")
    func polakRibiereMethod() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
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
    }

    @Test("Hestenes-Stiefel method")
    func hestenesStiefelMethod() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .hestenesStiefel,
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
    }

    @Test("Dai-Yuan method")
    func daiYuanMethod() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .daiYuan,
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
    }

    // MARK: - Restart Tests

    @Test("Conjugate Gradient with automatic restart")
    func automaticRestart() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 5.0) * (x - 5.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-6,
            maxIterations: 100,
            restartInterval: 10 // Restart every 10 iterations
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 5.0) < 0.01)
    }

    @Test("Conjugate Gradient without restart")
    func noRestart() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 5.0) * (x - 5.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-6,
            maxIterations: 100,
            restartInterval: nil // No automatic restart
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 5.0) < 0.01)
    }

    // MARK: - Adaptive Progress Tests

    @Test("Conjugate Gradient with fixed interval progress")
    func fixedIntervalProgress() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 5)
        )

        let collector = ProgressCollector<Int>()
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) { progress in
            collector.append(progress.iteration)
        }

        #expect(result.converged)
        let progressUpdates = collector.getItems()
        #expect(progressUpdates.count > 0)
    }

    @Test("Conjugate Gradient with exponential backoff progress")
    func exponentialBackoffProgress() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: ExponentialBackoffStrategy(
                initialInterval: 1,
                maxInterval: 50,
                backoffFactor: 2.0
            )
        )

        let collector = ProgressCollector<ConjugateGradientProgress>()
        let _ = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 10.0,
            bounds: nil
        ) { progress in
            collector.append(progress)
        }

        let progressUpdates = collector.getItems()
        #expect(progressUpdates.count > 0)

        // Verify progress contains conjugate gradient info
        if let first = progressUpdates.first {
            #expect(first.conjugateDirection != 0.0 || first.iteration == 1)
        }
    }

    @Test("Conjugate Gradient reports beta parameter correctly")
    func betaParameterReporting() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 1.0) * (x - 1.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 1)
        )

        let betaCollector = ProgressCollector<Double>()
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 5.0,
            bounds: nil
        ) { progress in
            betaCollector.append(progress.beta)
        }

        #expect(result.converged)

        let betaValues = betaCollector.getItems()
        // Beta should be 0 for first iteration, non-zero for subsequent
        if betaValues.count >= 2 {
            #expect(betaValues[0] == 0.0) // First iteration
            // Later iterations may have non-zero beta
        }
    }

    // MARK: - Convergence Detection Tests

    @Test("Conjugate Gradient with convergence detector")
    func convergenceDetector() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 3.0) * (x - 3.0)
        }

        let detector = ConvergenceDetector(
            windowSize: 5,
            improvementThreshold: 0.001,
            gradientThreshold: 0.01
        )

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-10, // Very tight
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
        // Should stop before maxIterations
        #expect(result.iterations < 1000)
        #expect(result.iterations < 100)
    }

    @Test("Conjugate Gradient convergence metrics accuracy")
    func convergenceMetricsAccuracy() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 1.0) * (x - 1.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 1)
        )

        let metricsCollector = ProgressCollector<ConvergenceMetrics>()
        let result = try await optimizer.optimizeWithProgress(
            objective: objective,
            constraints: [],
            initialGuess: 5.0,
            bounds: nil
        ) { progress in
            metricsCollector.append(progress.metrics)
        }

        #expect(result.converged)

        let allMetrics = metricsCollector.getItems()
        #expect(allMetrics.count > 0)

        if let lastMetrics = allMetrics.last {
            // Near convergence
            #expect(lastMetrics.gradientNorm < 0.1)
            #expect(lastMetrics.relativeChange < 0.1)
        }
    }

    // MARK: - AsyncSequence Tests

    @Test("Conjugate Gradient provides AsyncSequence progress stream")
    func progressAsyncSequence() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 2.0) * (x - 2.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-6,
            maxIterations: 100,
            progressStrategy: FixedIntervalStrategy(interval: 5)
        )

        var progressUpdates: [ConjugateGradientProgress] = []

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

    @Test("Conjugate Gradient handles already optimal initial guess")
    func alreadyOptimal() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 6.0) * (x - 6.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-6,
            maxIterations: 100
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 6.0, // Already at optimum
            bounds: nil
        )

        #expect(result.converged)
        #expect(result.iterations < 10)
        #expect(abs(result.optimalValue - 6.0) < 0.01)
    }

    @Test("Conjugate Gradient handles difficult initial guess")
    func difficultInitialGuess() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 5.0) * (x - 5.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
            tolerance: 1e-6,
            maxIterations: 200
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 1000.0, // Very far
            bounds: nil
        )

        #expect(result.converged)
        #expect(abs(result.optimalValue - 5.0) < 0.1)
    }

    @Test("Conjugate Gradient respects max iterations")
    func respectsMaxIterations() async throws {
        // Difficult function with tight tolerance
        let objective: @Sendable (Double) -> Double = { x in
            let term1 = (1.0 - x) * (1.0 - x)
            let term2 = 100.0 * (2.0 - x * x) * (2.0 - x * x)
            return term1 + term2
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .fletcherReeves,
            tolerance: 1e-15, // Impossibly tight
            maxIterations: 10
        )

        let result = try await optimizer.optimize(
            objective: objective,
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        #expect(result.iterations <= 10)
    }

    @Test("Conjugate Gradient with tight tolerance")
    func tightTolerance() async throws {
        let objective: @Sendable (Double) -> Double = { x in
            (x - 7.0) * (x - 7.0)
        }

        let optimizer = AsyncConjugateGradientOptimizer(
            method: .polakRibiere,
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
        #expect(abs(result.optimalValue - 7.0) < 1e-6)
    }
}
