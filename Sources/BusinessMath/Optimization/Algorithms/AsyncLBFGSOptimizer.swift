//
//  AsyncLBFGSOptimizer.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation

// MARK: - L-BFGS Progress

/// Progress update during L-BFGS optimization
public struct LBFGSProgress: Sendable {
    /// Current iteration number
    public let iteration: Int

    /// Convergence metrics for this iteration
    public let metrics: ConvergenceMetrics

    /// Current position
    public let position: Double

    /// Current gradient
    public let gradient: Double

    /// Final result (only present on last update)
    public let result: OptimizationResult<Double>?

    public init(
        iteration: Int,
        metrics: ConvergenceMetrics,
        position: Double,
        gradient: Double,
        result: OptimizationResult<Double>? = nil
    ) {
        self.iteration = iteration
        self.metrics = metrics
        self.position = position
        self.gradient = gradient
        self.result = result
    }
}

// MARK: - Async L-BFGS Optimizer

/// L-BFGS (Limited-memory BFGS) optimizer with adaptive progress reporting
///
/// L-BFGS is a quasi-Newton method that approximates the inverse Hessian using
/// a limited history of gradient evaluations. It's particularly efficient for
/// large-scale optimization problems.
///
/// ## Algorithm Overview
///
/// 1. Maintain history of position differences (s) and gradient differences (y)
/// 2. Use two-loop recursion to compute search direction
/// 3. Perform line search to find step size
/// 4. Update position and gradient
/// 5. Update history buffers (limited to m most recent)
///
/// ## Features
///
/// - Integrated adaptive progress reporting via `ProgressStrategy`
/// - Optional convergence detection for early stopping
/// - Configurable memory size (typical: 5-20)
/// - AsyncSequence support for real-time progress monitoring
public struct AsyncLBFGSOptimizer {
    /// Number of previous iterations to store (typically 5-20)
    public let memorySize: Int

    /// Convergence tolerance for gradient norm
    public let tolerance: Double

    /// Maximum number of iterations
    public let maxIterations: Int

    /// Progress reporting strategy
    public let progressStrategy: (any ProgressStrategy)?

    /// Optional convergence detector for early stopping
    public let convergenceDetector: ConvergenceDetector?

    public init(
        memorySize: Int = 10,
        tolerance: Double = 1e-6,
        maxIterations: Int = 100,
        progressStrategy: (any ProgressStrategy)? = nil,
        convergenceDetector: ConvergenceDetector? = nil
    ) {
        self.memorySize = memorySize
        self.tolerance = tolerance
        self.maxIterations = maxIterations
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
        onProgress: @escaping @Sendable (LBFGSProgress) -> Void = { _ in }
    ) async throws -> OptimizationResult<Double> {
        var x = initialGuess
        var iteration = 0
        var previousObjective = objective(x)

        // History buffers for L-BFGS
        var sHistory: [Double] = [] // Position differences
        var yHistory: [Double] = [] // Gradient differences
        var previousGradient: Double? = nil

        var mutableStrategy = progressStrategy
        var mutableDetector = convergenceDetector

        while iteration < maxIterations {
            iteration += 1

            // Compute numerical gradient
            let h = 1e-8
            let gradient = (objective(x + h) - objective(x - h)) / (2.0 * h)

            // Compute search direction using L-BFGS two-loop recursion
            let searchDirection: Double
            if sHistory.isEmpty {
                // First iteration: use steepest descent
                searchDirection = -gradient
            } else {
                // L-BFGS two-loop recursion (simplified for 1D)
                searchDirection = computeSearchDirection(
                    gradient: gradient,
                    sHistory: sHistory,
                    yHistory: yHistory
                )
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

            // Update history
            if let prevGrad = previousGradient {
                let s = newX - x
                let y = gradient - prevGrad

                sHistory.append(s)
                yHistory.append(y)

                // Limit memory
                if sHistory.count > memorySize {
                    sHistory.removeFirst()
                    yHistory.removeFirst()
                }
            }

            previousGradient = gradient

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
                    let progress = LBFGSProgress(
                        iteration: iteration,
                        metrics: metrics,
                        position: newX,
                        gradient: gradient,
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
                    let finalProgress = LBFGSProgress(
                        iteration: iteration,
                        metrics: metrics,
                        position: newX,
                        gradient: gradient,
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
                let finalProgress = LBFGSProgress(
                    iteration: iteration,
                    metrics: metrics,
                    position: newX,
                    gradient: gradient,
                    result: result
                )
                onProgress(finalProgress)

                return result
            }

            // Update for next iteration
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
    ) -> AsyncThrowingStream<LBFGSProgress, Error> {
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

                    let finalProgress = LBFGSProgress(
                        iteration: result.iterations,
                        metrics: ConvergenceMetrics(
                            iteration: result.iterations,
                            objectiveValue: result.objectiveValue,
                            gradientNorm: abs(finalGradient),
                            stepSize: 0.0,
                            relativeChange: 0.0
                        ),
                        position: result.optimalValue,
                        gradient: finalGradient,
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

    /// Compute search direction using L-BFGS two-loop recursion
    /// Simplified for 1D case
    private func computeSearchDirection(
        gradient: Double,
        sHistory: [Double],
        yHistory: [Double]
    ) -> Double {
        guard !sHistory.isEmpty else {
            return -gradient
        }

        var q = gradient
        var alphas: [Double] = []

        // First loop (backward)
        for i in stride(from: sHistory.count - 1, through: 0, by: -1) {
            let s = sHistory[i]
            let y = yHistory[i]

            let rho = 1.0 / max(abs(s * y), 1e-10)
            let alpha = rho * s * q
            alphas.append(alpha)
            q = q - alpha * y
        }

        // Scale by approximate Hessian
        let lastS = sHistory.last!
        let lastY = yHistory.last!
        let gamma = (lastS * lastY) / max(abs(lastY * lastY), 1e-10)
        var r = gamma * q

        // Second loop (forward)
        alphas.reverse()
        for i in 0..<sHistory.count {
            let s = sHistory[i]
            let y = yHistory[i]

            let rho = 1.0 / max(abs(s * y), 1e-10)
            let beta = rho * y * r
            r = r + s * (alphas[i] - beta)
        }

        return -r
    }
}
