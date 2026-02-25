//
//  MultiStartOptimizerTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import TestSupport  // Cross-platform math functions
import Foundation
import Numerics
@testable import BusinessMath


/// Tests for MultiStartOptimizer (Phase 3.3)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("MultiStartOptimizer Tests")
struct MultiStartOptimizerTests {

    // MARK: - Initialization Tests

    @Test("MultiStartOptimizer initialization with base optimizer")
    func initializationWithBaseOptimizer() {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>()
        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 5
        )

        #expect(multiStart.numberOfStarts == 5)
    }

    @Test("MultiStartOptimizer initialization with custom starting points")
    func initializationWithCustomStartingPoints() {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>()
        let startingPoints = [0.0, 2.5, 5.0, 7.5, 10.0]

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            startingPoints: startingPoints
        )

        #expect(multiStart.numberOfStarts == 5)
    }

    // MARK: - Basic Multi-Start Tests

    @Test("MultiStartOptimizer finds global minimum")
    func findsGlobalMinimum() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 10
        )

        // Simpler multi-modal function: f(x) = (x-2)² + sin(5x)
        // Global minimum around x ≈ 2
        let result = try await multiStart.optimize(
            objective: { x in
                (x - 2.0) * (x - 2.0) + 0.5 * sin(5.0 * x)
            },
            constraints: [],
            initialGuess: 0.0,  // Will be ignored, using multiple starts
            bounds: (lower: -5.0, upper: 5.0)
        )

        // Should find a good solution
        #expect(abs(result.optimalValue - 2.0) < 1.0)
    }

    @Test("MultiStartOptimizer explores multiple local minima")
    func exploresMultipleLocalMinima() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 2000
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 10
        )

        // Function with two clear minima at x = ±√2
        let result = try await multiStart.optimize(
            objective: { x in
                (x * x - 2.0) * (x * x - 2.0)
            },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: -3.0, upper: 3.0)
        )

        // Should find one of the minima (both have same objective value)
        #expect(abs(result.objectiveValue) < 0.6)
    }

    // MARK: - Parallel Execution Tests - These tests may fail when run as part of a suite as they are forced to run sequentially
	@Test("MultiStartOptimizer runs optimizations in parallel", .onlyLocal)
    func runsInParallel() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            maxIterations: 50
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 4
        )

        let startTime = ContinuousClock.now

        _ = try await multiStart.optimize(
            objective: { x in
                // Simple quadratic - tests run in parallel
                return (x - 3.0) * (x - 3.0)
            },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: 0.0, upper: 10.0)
        )

        let elapsed = ContinuousClock.now - startTime

        // Parallel execution should complete in reasonable time
        // With 4 tasks running in parallel and limited iterations,
        // should complete quickly (< 1 second)
        #expect(elapsed < .seconds(1))
    }

    @Test("MultiStartOptimizer returns best result from all starts")
    func returnsBestResult() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 500
        )

        // Use specific starting points
        let startingPoints = [-10.0, -5.0, 0.0, 5.0, 10.0]
        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            startingPoints: startingPoints
        )

        let result = try await multiStart.optimize(
            objective: { x in (x - 7.0) * (x - 7.0) },
            constraints: [],
            initialGuess: 0.0,  // Ignored
            bounds: nil
        )

        // Should find minimum at x = 7 regardless of starting points
        #expect(abs(result.optimalValue - 7.0) < 0.5)
        #expect(abs(result.objectiveValue) < 0.25)
    }

    // MARK: - Progress Reporting Tests

    @Test("MultiStartOptimizer streams progress from all optimizers")
    func streamsProgressFromAllOptimizers() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 3
        )

        let collector = ProgressCollector<AsyncOptimizationProgress<Double>>()

        for try await progress in multiStart.optimizeWithProgress(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: 0.0, upper: 10.0)
        ) {
            collector.append(progress)
        }

        let progressUpdates = collector.getItems()

        // Should receive progress updates
        #expect(progressUpdates.count > 0)

        // Should have updates from multiple optimizers
        // (though we can't easily verify which optimizer they came from)
        #expect(progressUpdates.count >= 3)
    }

    // MARK: - Cancellation Tests

    @Test("MultiStartOptimizer respects cancellation")
    func respectsCancellation() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.001,  // Slow convergence
            maxIterations: 10000
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 5
        )

        let task = Task {
            try await multiStart.optimize(
                objective: { x in (x - 100.0) * (x - 100.0) },
                constraints: [],
                initialGuess: 0.0,
                bounds: (lower: 0.0, upper: 200.0)
            )
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(10))

        // Cancel the task
        task.cancel()

        // Should terminate without error
        _ = try? await task.value
    }

    // MARK: - Starting Point Generation Tests

    @Test("MultiStartOptimizer generates uniform starting points in bounds")
    func generatesUniformStartingPoints() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 10
        )

        // The optimizer should generate starting points within bounds
        let result = try await multiStart.optimize(
            objective: { x in x * x },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: -10.0, upper: 10.0)
        )

        // Should find minimum at x = 0
        #expect(abs(result.optimalValue) < 1.0)
    }

    @Test("MultiStartOptimizer with no bounds uses heuristic generation")
    func withNoBoundsUsesHeuristic() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 5
        )

        // Without bounds, should generate points around initialGuess
        let result = try await multiStart.optimize(
            objective: { x in (x - 3.0) * (x - 3.0) },
            constraints: [],
            initialGuess: 5.0,  // Use as center for generation
            bounds: nil
        )

        #expect(abs(result.optimalValue - 3.0) < 1.0)
    }

    // MARK: - Edge Cases

    @Test("MultiStartOptimizer with single start point")
    func withSingleStartPoint() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 1
        )

        let result = try await multiStart.optimize(
            objective: { x in (x - 2.0) * (x - 2.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Should still work with just one start
        #expect(abs(result.optimalValue - 2.0) < 0.5)
    }

    @Test("MultiStartOptimizer handles all optimizers failing")
    func handlesAllOptimizersFailing() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            maxIterations: 1  // Force early termination
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 3
        )

        let result = try await multiStart.optimize(
            objective: { x in (x - 100.0) * (x - 100.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Should still return a result (best attempt)
        #expect(result.iterations <= 1)
    }

    // MARK: - Real-World Scenario Tests

    @Test("MultiStartOptimizer finds global minimum of complex function")
    func findsGlobalMinimumOfComplexFunction() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            tolerance: 1e-4,
            maxIterations: 3000,
            momentum: 0.6
        )

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 30
        )

        // Multi-modal function with multiple local minima
        // f(x) = (x-1)² + 0.5sin(4x) has global minimum near x = 1
        let result = try await multiStart.optimize(
            objective: { x in
                (x - 1.0) * (x - 1.0) + 0.5 * sin(4.0 * x)
            },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: -3.0, upper: 5.0)
        )

        // Should find a good solution near the global minimum
        #expect(abs(result.optimalValue - 1.0) < 1.0)
        #expect(result.objectiveValue < 1.0)
    }

    @Test("MultiStartOptimizer with custom starting points strategy")
    func withCustomStartingPointsStrategy() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1
        )

        // Create grid of starting points
        let startingPoints = stride(from: 0.0, through: 10.0, by: 2.0).map { $0 }

        let multiStart = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            startingPoints: startingPoints
        )

        let result = try await multiStart.optimize(
            objective: { x in (x - 6.0) * (x - 6.0) },
            constraints: [],
            initialGuess: 0.0,  // Ignored
            bounds: nil
        )

        #expect(abs(result.optimalValue - 6.0) < 0.5)
    }

    // MARK: - Performance Tests

    @Test("MultiStartOptimizer performance scales with start points")
    func performanceScalesWithStartPoints() async throws {
        let baseOptimizer = AsyncGradientDescentOptimizer<Double>(
            learningRate: 0.1,
            maxIterations: 100
        )

        // Test with few starts
        let multiStart3 = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 3
        )

        let start3 = ContinuousClock.now
        _ = try await multiStart3.optimize(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: 0.0, upper: 10.0)
        )
        let time3 = ContinuousClock.now - start3

        // Test with more starts
        let multiStart9 = MultiStartOptimizer(
            baseOptimizer: baseOptimizer,
            numberOfStarts: 9
        )

        let start9 = ContinuousClock.now
        _ = try await multiStart9.optimize(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: (lower: 0.0, upper: 10.0)
        )
        let time9 = ContinuousClock.now - start9

        // 9 starts should not take 3× as long (due to parallelism)
        // Allow some overhead, but ensure it's reasonably parallel
        #expect(time9 < time3 * 2)
    }
}
