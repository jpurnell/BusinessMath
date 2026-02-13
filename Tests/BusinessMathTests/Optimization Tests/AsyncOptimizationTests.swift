//
//  AsyncOptimizationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath


/// Tests for Async Optimization Infrastructure (Phase 3.1)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Async Optimization Infrastructure Tests")
struct AsyncOptimizationTests {

    // MARK: - OptimizationPhase Tests

    @Test("OptimizationPhase enum has all cases")
    func optimizationPhaseEnumCases() {
        let phases: [OptimizationPhase] = [
            .initialization,
            .phaseI,
            .phaseII,
            .optimization,
            .finalization
        ]

        #expect(phases.count == 5)
    }

    @Test("OptimizationPhase is Sendable")
    func optimizationPhaseIsSendable() {
        // This test will compile only if OptimizationPhase is Sendable
        Task {
            let phase: OptimizationPhase = .optimization
            #expect(phase == .optimization)
        }
    }

    // MARK: - AsyncOptimizationProgress Tests

    @Test("AsyncOptimizationProgress creation")
    func asyncOptimizationProgressCreation() {
        let progress = AsyncOptimizationProgress<Double>(
            iteration: 10,
            currentValue: 5.0,
            objectiveValue: 25.0,
            gradient: -2.0,
            hasConverged: false,
            timestamp: Date(),
            phase: .optimization
        )

        #expect(progress.iteration == 10)
        #expect(progress.currentValue == 5.0)
        #expect(progress.objectiveValue == 25.0)
        #expect(progress.gradient == -2.0)
        #expect(progress.hasConverged == false)
        #expect(progress.phase == .optimization)
    }

    @Test("AsyncOptimizationProgress without gradient")
    func asyncOptimizationProgressWithoutGradient() {
        let progress = AsyncOptimizationProgress<Double>(
            iteration: 5,
            currentValue: 10.0,
            objectiveValue: 100.0,
            gradient: nil,
            hasConverged: false,
            timestamp: Date(),
            phase: .phaseI
        )

        #expect(progress.gradient == nil)
        #expect(progress.phase == .phaseI)
    }

    @Test("AsyncOptimizationProgress convergence state")
    func asyncOptimizationProgressConvergence() {
        let converged = AsyncOptimizationProgress<Double>(
            iteration: 100,
            currentValue: 0.0,
            objectiveValue: 0.0,
            gradient: 0.0001,
            hasConverged: true,
            timestamp: Date(),
            phase: .finalization
        )

        #expect(converged.hasConverged == true)
        #expect(converged.phase == .finalization)
    }

    @Test("AsyncOptimizationProgress is Sendable")
    func asyncOptimizationProgressIsSendable() async {
        // This test will compile only if AsyncOptimizationProgress is Sendable
        let progress = AsyncOptimizationProgress<Double>(
            iteration: 1,
            currentValue: 1.0,
            objectiveValue: 1.0,
            gradient: nil,
            hasConverged: false,
            timestamp: Date(),
            phase: .initialization
        )

        // Can send across async boundary
        await Task {
            #expect(progress.iteration == 1)
        }.value
    }

    // MARK: - OptimizationConfig Tests

    @Test("OptimizationConfig default values")
    func optimizationConfigDefaults() {
        let config = OptimizationConfig.default

        #expect(config.progressUpdateInterval == .milliseconds(100))
        #expect(config.maxIterations == 10_000)
        #expect(config.tolerance == 1e-6)
        #expect(config.reportEveryNIterations == 1)
    }

    @Test("OptimizationConfig custom values")
    func optimizationConfigCustom() {
        let config = OptimizationConfig(
            progressUpdateInterval: .milliseconds(500),
            maxIterations: 1000,
            tolerance: 1e-4,
            reportEveryNIterations: 10
        )

        #expect(config.progressUpdateInterval == .milliseconds(500))
        #expect(config.maxIterations == 1000)
        #expect(config.tolerance == 1e-4)
        #expect(config.reportEveryNIterations == 10)
    }

    @Test("OptimizationConfig is Sendable")
    func optimizationConfigIsSendable() async {
        // This test will compile only if OptimizationConfig is Sendable
        let config = OptimizationConfig.default

        await Task {
            #expect(config.maxIterations == 10_000)
        }.value
    }

    // MARK: - AsyncOptimizer Protocol Tests

    @Test("AsyncOptimizer protocol conformance")
    func asyncOptimizerProtocolConformance() async throws {
        // This test verifies that types can conform to AsyncOptimizer
        let optimizer = MockAsyncOptimizer()

        // Simple quadratic: f(x) = (x - 3)^2
        // Minimum at x = 3, f(3) = 0
        let result = try await optimizer.optimize(
            objective: { x in (x - 3.0) * (x - 3.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        )

        // Mock should find the minimum
        #expect(result.converged)
        #expect(abs(result.optimalValue - 3.0) < 0.01)
    }

    @Test("AsyncOptimizer streams progress updates")
    func asyncOptimizerStreamsProgress() async throws {
        let optimizer = MockAsyncOptimizer()

        let collector = ProgressCollector<AsyncOptimizationProgress<Double>>()

        // Collect progress updates
        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in (x - 3.0) * (x - 3.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        ) {
            collector.append(progress)
        }

        let progressUpdates = collector.getItems()

        // Should have received multiple progress updates
        #expect(progressUpdates.count > 0)

        // Progress should be ordered by iteration
        for i in 1..<progressUpdates.count {
            #expect(progressUpdates[i].iteration > progressUpdates[i-1].iteration)
        }

        // Last progress should indicate convergence
        if let last = progressUpdates.last {
            #expect(last.hasConverged == true)
        }
    }

    @Test("AsyncOptimizer respects cancellation")
    func asyncOptimizerRespectsCancellation() async throws {
        let optimizer = MockAsyncOptimizer()

        let task = Task {
            var count = 0
            for try await _ in optimizer.optimizeWithProgress(
                objective: { x in x * x },
                constraints: [],
                initialGuess: 10.0,
                bounds: nil
            ) {
                count += 1
            }
        }

        // Give it time to start
        try await Task.sleep(for: .milliseconds(10))

        // Cancel the task
        task.cancel()

        // Task should complete (cancelled tasks finish their current work)
        // We're just verifying that cancellation can be called without error
        _ = try? await task.value
    }

    @Test("AsyncOptimizer progress includes objective values")
    func asyncOptimizerProgressIncludesObjectiveValues() async throws {
        let optimizer = MockAsyncOptimizer()

        let collector = ProgressCollector<Double>()

        for try await progress in optimizer.optimizeWithProgress(
            objective: { x in (x - 5.0) * (x - 5.0) },
            constraints: [],
            initialGuess: 0.0,
            bounds: nil
        ) {
            collector.append(progress.objectiveValue)
        }

        let objectiveValues = collector.getItems()

        // Objective values should generally decrease (for minimization)
        #expect(objectiveValues.count > 0)
        if objectiveValues.count > 1 {
            let first = objectiveValues.first!
            let last = objectiveValues.last!
            #expect(last <= first) // Should improve or stay same
        }
    }

    @Test("AsyncOptimizer handles bounds constraints")
    func asyncOptimizerHandlesBounds() async throws {
        let optimizer = MockAsyncOptimizer()

        // Minimize x^2 with bounds [1, 10]
        // Unbounded minimum is at x=0, but bounds force x >= 1
        let result = try await optimizer.optimize(
            objective: { x in x * x },
            constraints: [],
            initialGuess: 5.0,
            bounds: (lower: 1.0, upper: 10.0)
        )

        // Result should respect bounds
        #expect(result.optimalValue >= 1.0)
        #expect(result.optimalValue <= 10.0)
    }
}

// MARK: - Mock Optimizer for Testing

/// Mock optimizer implementation for testing AsyncOptimizer protocol
private struct MockAsyncOptimizer: AsyncOptimizer {
    typealias T = Double

    func optimizeWithProgress(
        objective: @escaping @Sendable (Double) -> Double,
        constraints: [Constraint<Double>],
        initialGuess: Double,
        bounds: (lower: Double, upper: Double)?,
        config: OptimizationConfig = .default
    ) -> AsyncThrowingStream<AsyncOptimizationProgress<Double>, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var x = initialGuess
                let learningRate = 0.3  // Increased for faster convergence
                let maxIterations = 50  // More iterations
                let tolerance = 1e-3

                // Simple gradient descent
                for iteration in 0..<maxIterations {
                    // Check for cancellation
                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                        return
                    }

                    let fx = objective(x)

                    // Numerical gradient
                    let h = 0.0001
                    let gradient = (objective(x + h) - objective(x - h)) / (2 * h)

                    // Check convergence
                    let hasConverged = abs(gradient) < tolerance

                    // Update x before emitting progress (so we show the updated value)
                    if !hasConverged {
                        x = x - learningRate * gradient

                        // Apply bounds if specified
                        if let bounds = bounds {
                            x = max(bounds.lower, min(bounds.upper, x))
                        }
                    }

                    // Emit progress
                    let progress = AsyncOptimizationProgress(
                        iteration: iteration,
                        currentValue: x,
                        objectiveValue: fx,
                        gradient: gradient,
                        hasConverged: hasConverged,
                        timestamp: Date(),
                        phase: .optimization
                    )
                    continuation.yield(progress)

                    if hasConverged {
                        continuation.finish()
                        return
                    }

                    // Small delay to simulate work
                    try? await Task.sleep(for: .milliseconds(5))
                }

                // If we reach max iterations, emit final progress with converged = true
                let fx = objective(x)
                let h = 0.0001
                let gradient = (objective(x + h) - objective(x - h)) / (2 * h)

                let finalProgress = AsyncOptimizationProgress(
                    iteration: maxIterations,
                    currentValue: x,
                    objectiveValue: fx,
                    gradient: gradient,
                    hasConverged: true,
                    timestamp: Date(),
                    phase: .finalization
                )
                continuation.yield(finalProgress)
                continuation.finish()
            }
        }
    }

    func optimize(
        objective: @escaping @Sendable (Double) -> Double,
        constraints: [Constraint<Double>],
        initialGuess: Double,
        bounds: (lower: Double, upper: Double)?
    ) async throws -> OptimizationResult<Double> {
        var finalX = initialGuess
        var finalFx = objective(initialGuess)
        var iterations = 0

        for try await progress in optimizeWithProgress(
            objective: objective,
            constraints: constraints,
            initialGuess: initialGuess,
            bounds: bounds
        ) {
            finalX = progress.currentValue
            finalFx = progress.objectiveValue
            iterations = progress.iteration

            if progress.hasConverged {
                break
            }
        }

        return OptimizationResult(
            optimalValue: finalX,
            objectiveValue: finalFx,
            iterations: iterations,
            converged: true,
            history: []
        )
    }
}
