//
//  AsyncConjugateGradientOptimizer.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation

// MARK: - Conjugate Gradient Method

/// Method for computing the beta parameter in Conjugate Gradient
public enum ConjugateGradientMethod: Sendable {
    /// Fletcher-Reeves formula: β = ||g_k+1||² / ||g_k||²
    case fletcherReeves

    /// Polak-Ribière formula: β = g_k+1 · (g_k+1 - g_k) / ||g_k||²
    case polakRibiere

    /// Hestenes-Stiefel formula: β = g_k+1 · (g_k+1 - g_k) / d_k · (g_k+1 - g_k)
    case hestenesStiefel

    /// Dai-Yuan formula: β = ||g_k+1||² / d_k · (g_k+1 - g_k)
    case daiYuan
}

// MARK: - Conjugate Gradient Progress

/// Progress update during Conjugate Gradient optimization
public struct ConjugateGradientProgress: Sendable {
    /// Current iteration number
    public let iteration: Int

    /// Convergence metrics for this iteration
    public let metrics: ConvergenceMetrics

    /// Current conjugate search direction
    public let conjugateDirection: Double

    /// Beta parameter for this iteration
    public let beta: Double

    /// Final result (only present on last update)
    public let result: OptimizationResult<Double>?

    public init(
        iteration: Int,
        metrics: ConvergenceMetrics,
        conjugateDirection: Double,
        beta: Double,
        result: OptimizationResult<Double>? = nil
    ) {
        self.iteration = iteration
        self.metrics = metrics
        self.conjugateDirection = conjugateDirection
        self.beta = beta
        self.result = result
    }
}

// MARK: - Async Conjugate Gradient Optimizer

/// Conjugate Gradient optimizer with adaptive progress reporting
///
/// The Conjugate Gradient method is an iterative algorithm for solving unconstrained
/// optimization problems. It generates a sequence of conjugate search directions to
/// efficiently navigate the optimization landscape.
///
/// ## Algorithm Overview
///
/// 1. Compute gradient at current position
/// 2. Compute beta parameter using selected formula
/// 3. Update search direction: d_k+1 = -g_k+1 + β_k * d_k
/// 4. Perform line search along direction
/// 5. Update position
/// 6. Restart if configured
///
/// ## Features
///
/// - Four beta computation methods (Fletcher-Reeves, Polak-Ribière, Hestenes-Stiefel, Dai-Yuan)
/// - Optional automatic restart for improved convergence
/// - Integrated adaptive progress reporting via `ProgressStrategy`
/// - Optional convergence detection for early stopping
/// - AsyncSequence support for real-time progress monitoring
public struct AsyncConjugateGradientOptimizer {
    /// Method for computing beta parameter
    public let method: ConjugateGradientMethod

    /// Convergence tolerance for gradient norm
    public let tolerance: Double

    /// Maximum number of iterations
    public let maxIterations: Int

    /// Optional restart interval (nil = no automatic restart)
    public let restartInterval: Int?

    /// Progress reporting strategy
    public let progressStrategy: (any ProgressStrategy)?

    /// Optional convergence detector for early stopping
    public let convergenceDetector: ConvergenceDetector?

    public init(
        method: ConjugateGradientMethod = .fletcherReeves,
        tolerance: Double = 1e-6,
        maxIterations: Int = 100,
        restartInterval: Int? = nil,
        progressStrategy: (any ProgressStrategy)? = nil,
        convergenceDetector: ConvergenceDetector? = nil
    ) {
        self.method = method
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.restartInterval = restartInterval
        self.progressStrategy = progressStrategy
        self.convergenceDetector = convergenceDetector
    }

    /// Optimize without progress reporting
    public func optimize(
        objective: @escaping @Sendable (Double) -> Double,
        constraints: [Constraint<Double>],
        initialGuess: Double,
        bounds: (lower: Double, upper: Double)?
    ) async throws -> OptimizationResult<Double> {
        // Delegate to progress version without callback
        return try await optimizeWithProgress(
            objective: objective,
            constraints: constraints,
            initialGuess: initialGuess,
            bounds: bounds
        ) { _ in }
    }

    /// Optimize with progress callback
    public func optimizeWithProgress(
        objective: @escaping @Sendable (Double) -> Double,
        constraints: [Constraint<Double>],
        initialGuess: Double,
        bounds: (lower: Double, upper: Double)?,
        onProgress: @escaping @Sendable (ConjugateGradientProgress) -> Void = { _ in }
    ) async throws -> OptimizationResult<Double> {
        var x = initialGuess
        var iteration = 0
        var previousObjective = objective(x)

        // Conjugate gradient state
        var previousGradient: Double? = nil
        var searchDirection: Double = 0.0

        var mutableStrategy = progressStrategy
        var mutableDetector = convergenceDetector

        while iteration < maxIterations {
            iteration += 1

            // Compute numerical gradient
            let h = 1e-8
            let gradient = (objective(x + h) - objective(x - h)) / (2.0 * h)

            // Compute beta and update search direction
            let beta: Double
            if let prevGrad = previousGradient {
                // Check for restart
                let shouldRestart = restartInterval.map { iteration % $0 == 1 } ?? false

                if shouldRestart {
                    // Restart: use steepest descent
                    beta = 0.0
                    searchDirection = -gradient
                } else {
                    // Compute beta using selected method
                    beta = computeBeta(
                        currentGradient: gradient,
                        previousGradient: prevGrad,
                        searchDirection: searchDirection
                    )

                    // Update search direction: d_k+1 = -g_k+1 + β * d_k
                    searchDirection = -gradient + beta * searchDirection
                }
            } else {
                // First iteration: use steepest descent
                beta = 0.0
                searchDirection = -gradient
            }

            // Line search with backtracking
            var alpha = 1.0
            let c1 = 1e-4 // Armijo condition parameter
            let rho = 0.5 // Backtracking reduction factor

            var newX = x
            var newObjective = objective(newX)

            // Backtracking line search
            for _ in 0..<20 {
                newX = x + alpha * searchDirection
                newObjective = objective(newX)

                // Armijo condition
                if newObjective <= previousObjective + c1 * alpha * gradient * searchDirection {
                    break
                }

                alpha *= rho
            }

            // Compute metrics
            let relativeChange = abs((newObjective - previousObjective) / max(abs(previousObjective), 1e-10))

            let metrics = ConvergenceMetrics(
                iteration: iteration,
                objectiveValue: newObjective,
                gradientNorm: abs(gradient),
                stepSize: abs(alpha * searchDirection),
                relativeChange: relativeChange
            )

            // Update strategy
            if var strategy = mutableStrategy {
                strategy.update(with: metrics)

                if strategy.shouldReport(iteration: iteration) {
                    let progress = ConjugateGradientProgress(
                        iteration: iteration,
                        metrics: metrics,
                        conjugateDirection: searchDirection,
                        beta: beta,
                        result: nil
                    )
                    onProgress(progress)
                }

                mutableStrategy = strategy
            }

            // Check convergence detector
            if var detector = mutableDetector {
                detector.update(with: metrics)

                if detector.hasConverged {
                    let result = OptimizationResult(
                        optimalValue: newX,
                        objectiveValue: newObjective,
                        iterations: iteration,
                        converged: true,
                        history: []
                    )

                    // Send final progress
                    let finalProgress = ConjugateGradientProgress(
                        iteration: iteration,
                        metrics: metrics,
                        conjugateDirection: searchDirection,
                        beta: beta,
                        result: result
                    )
                    onProgress(finalProgress)

                    return result
                }

                mutableDetector = detector
            }

            // Check gradient-based convergence
            if abs(gradient) < tolerance {
                let result = OptimizationResult(
                    optimalValue: newX,
                    objectiveValue: newObjective,
                    iterations: iteration,
                    converged: true,
                    history: []
                )

                // Send final progress
                let finalProgress = ConjugateGradientProgress(
                    iteration: iteration,
                    metrics: metrics,
                    conjugateDirection: searchDirection,
                    beta: beta,
                    result: result
                )
                onProgress(finalProgress)

                return result
            }

            // Update for next iteration
            previousGradient = gradient
            x = newX
            previousObjective = newObjective

            // Check for Task cancellation
            if Task.isCancelled {
                break
            }
        }

        // Max iterations reached
        let finalObjective = objective(x)
        let result = OptimizationResult(
            optimalValue: x,
            objectiveValue: finalObjective,
            iterations: iteration,
            converged: false,
            history: []
        )

        return result
    }

    /// Optimize with AsyncSequence progress stream
    public func optimizeWithProgressStream(
        objective: @escaping @Sendable (Double) -> Double,
        constraints: [Constraint<Double>],
        initialGuess: Double,
        bounds: (lower: Double, upper: Double)?
    ) -> AsyncThrowingStream<ConjugateGradientProgress, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let result = try await optimizeWithProgress(
                        objective: objective,
                        constraints: constraints,
                        initialGuess: initialGuess,
                        bounds: bounds
                    ) { progress in
                        continuation.yield(progress)
                    }

                    // Send final result
                    let h = 1e-8
                    let finalGradient = (objective(result.optimalValue + h) - objective(result.optimalValue - h)) / (2.0 * h)

                    let finalProgress = ConjugateGradientProgress(
                        iteration: result.iterations,
                        metrics: ConvergenceMetrics(
                            iteration: result.iterations,
                            objectiveValue: result.objectiveValue,
                            gradientNorm: abs(finalGradient),
                            stepSize: 0.0,
                            relativeChange: 0.0
                        ),
                        conjugateDirection: 0.0,
                        beta: 0.0,
                        result: result
                    )
                    continuation.yield(finalProgress)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Compute beta parameter using selected method
    private func computeBeta(
        currentGradient: Double,
        previousGradient: Double,
        searchDirection: Double
    ) -> Double {
        let gradientDiff = currentGradient - previousGradient

        switch method {
        case .fletcherReeves:
            // β = ||g_k+1||² / ||g_k||²
            let numerator = currentGradient * currentGradient
            let denominator = max(abs(previousGradient * previousGradient), 1e-10)
            return numerator / denominator

        case .polakRibiere:
            // β = g_k+1 · (g_k+1 - g_k) / ||g_k||²
            let numerator = currentGradient * gradientDiff
            let denominator = max(abs(previousGradient * previousGradient), 1e-10)
            return max(0.0, numerator / denominator) // PR+ variant (non-negative)

        case .hestenesStiefel:
            // β = g_k+1 · (g_k+1 - g_k) / d_k · (g_k+1 - g_k)
            let numerator = currentGradient * gradientDiff
            let denominator = max(abs(searchDirection * gradientDiff), 1e-10)
            return numerator / denominator

        case .daiYuan:
            // β = ||g_k+1||² / d_k · (g_k+1 - g_k)
            let numerator = currentGradient * currentGradient
            let denominator = max(abs(searchDirection * gradientDiff), 1e-10)
            return numerator / denominator
        }
    }
}
