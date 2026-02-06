//
//  AsyncGradientDescentOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation
import Numerics

// MARK: - AsyncGradientDescentOptimizer

/// An asynchronous optimizer using gradient descent with optional momentum and Nesterov acceleration.
///
/// `AsyncGradientDescentOptimizer` is the async/await version of ``GradientDescentOptimizer``,
/// providing real-time progress updates and task cancellation support while finding local
/// minima through iterative gradient descent.
///
/// ## Algorithm
///
/// Basic gradient descent:
/// ```
/// x_{n+1} = x_n - α ∇f(x_n)
/// ```
///
/// With momentum:
/// ```
/// v_{n+1} = β v_n + ∇f(x_n)
/// x_{n+1} = x_n - α v_{n+1}
/// ```
///
/// With Nesterov Accelerated Gradient (NAG):
/// ```
/// x̃ = x_n + β v_n
/// v_{n+1} = β v_n - α ∇f(x̃)
/// x_{n+1} = x_n + v_{n+1}
/// ```
///
/// where:
/// - α is the learning rate
/// - β is the momentum coefficient (0 ≤ β < 1)
/// - ∇f is the gradient
/// - x̃ is the "look-ahead" position
///
/// ## Usage Example
///
/// ```swift
/// let optimizer = AsyncGradientDescentOptimizer<Double>(
///     learningRate: 0.1,
///     tolerance: 0.001,
///     maxIterations: 1000,
///     momentum: 0.9
/// )
///
/// // Stream progress updates
/// for try await progress in optimizer.optimizeWithProgress(
///     objective: { x in x * x },
///     constraints: [],
///     initialGuess: 10.0,
///     bounds: nil
/// ) {
///     print("Iteration \(progress.iteration): x = \(progress.currentValue), f(x) = \(progress.objectiveValue)")
///     if progress.hasConverged {
///         print("Converged!")
///         break
///     }
/// }
///
/// // Or get final result directly
/// let result = try await optimizer.optimize(
///     objective: { x in x * x },
///     constraints: [],
///     initialGuess: 10.0,
///     bounds: nil
/// )
/// print("Optimal value: \(result.optimalValue)")
/// ```
///
/// ## Progress Reporting
///
/// Unlike the synchronous version, this optimizer emits ``AsyncOptimizationProgress``
/// updates via ``optimizeWithProgress(objective:constraints:initialGuess:bounds:config:)``,
/// allowing UI updates and monitoring during long-running optimizations.
///
/// ## Task Cancellation
///
/// The optimizer checks `Task.isCancelled` at each iteration and terminates gracefully
/// when cancelled, throwing a `CancellationError`.
///
/// ## See Also
/// - ``GradientDescentOptimizer`` - Synchronous version
/// - ``AsyncOptimizer`` - Protocol conformance
/// - ``AsyncOptimizationProgress`` - Progress update type
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct AsyncGradientDescentOptimizer<T>: Sendable, AsyncOptimizer where T: Real & Sendable & Codable {

    // MARK: - Properties

    /// The learning rate (step size multiplier).
    public let learningRate: T

    /// Convergence tolerance.
    public let tolerance: T

    /// Maximum number of iterations.
    public let maxIterations: Int

    /// Momentum coefficient (0 ≤ momentum < 1).
    public let momentum: T

    /// Whether to use Nesterov Accelerated Gradient.
    public let useNesterov: Bool

    /// Step size for numerical gradient.
    public let stepSize: T

    // MARK: - Initialization

    /// Creates an async gradient descent optimizer.
    ///
    /// - Parameters:
    ///   - learningRate: The learning rate. Defaults to 0.01.
    ///   - tolerance: Convergence tolerance. Defaults to 0.0001.
    ///   - maxIterations: Maximum number of iterations. Defaults to 1000.
    ///   - momentum: Momentum coefficient. Defaults to 0.9.
    ///   - useNesterov: Whether to use Nesterov Accelerated Gradient. Defaults to false.
    ///   - stepSize: Step size for numerical gradient. Defaults to 0.0001.
    public init(
        learningRate: T = 0.01,
        tolerance: T = 0.0001,
        maxIterations: Int = 1000,
        momentum: T = T(797734375) / T(1000000000),  // Default: 0.797734375
        useNesterov: Bool = false,
        stepSize: T = 0.0001
    ) {
        // Check momentum bounds (clamp to valid range)
        let maxMomentum = T(797734375) / T(1000000000)
        let clampedMomentum = max(T(0), min(momentum, maxMomentum))

        self.learningRate = learningRate
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.momentum = clampedMomentum
        self.useNesterov = useNesterov
        self.stepSize = stepSize
    }

    // MARK: - AsyncOptimizer Protocol

    /// Performs optimization with real-time progress updates.
    ///
    /// This method returns an `AsyncThrowingStream` that emits progress updates
    /// as optimization proceeds. Updates are emitted based on the configuration
    /// parameters (time interval and iteration frequency).
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize. Must be `@Sendable` for
    ///                safe concurrent access.
    ///   - constraints: Array of constraints that the solution must satisfy.
    ///   - initialGuess: Starting point for the optimization.
    ///   - bounds: Optional lower and upper bounds for the parameter value.
    ///   - config: Configuration for progress reporting. Uses default if not specified.
    ///
    /// - Returns: An async stream of progress updates. The stream completes when
    ///            optimization finishes or throws if an error occurs.
    ///
    /// ## Usage Example
    /// ```swift
    /// let optimizer = AsyncGradientDescentOptimizer<Double>()
    ///
    /// for try await progress in optimizer.optimizeWithProgress(
    ///     objective: { x in (x - 5.0) * (x - 5.0) },
    ///     constraints: [],
    ///     initialGuess: 0.0,
    ///     bounds: nil
    /// ) {
    ///     print("Iteration \(progress.iteration): x = \(progress.currentValue)")
    ///     updateUI(with: progress)  // Update progress bar, chart, etc.
    /// }
    /// ```
    public func optimizeWithProgress(
        objective: @escaping @Sendable (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,
        bounds: (lower: T, upper: T)?,
        config: OptimizationConfig = .default
    ) -> AsyncThrowingStream<AsyncOptimizationProgress<T>, Error> {
        AsyncThrowingStream { continuation in
            Task { @Sendable in
                var x = initialGuess
                var velocity: T = 0
                let converged = false

                // Apply bounds to initial value
                if let bounds = bounds {
                    x = clamp(x, lower: bounds.lower, upper: bounds.upper)
                }

                var previousObjective = objective(x)
                var lastReportTime = ContinuousClock.now

                // Emit initial progress
                let initialProgress = AsyncOptimizationProgress(
                    iteration: 0,
                    currentValue: x,
                    objectiveValue: previousObjective,
                    gradient: nil,
                    hasConverged: false,
                    timestamp: Date(),
                    phase: .initialization
                )
                continuation.yield(initialProgress)

                for iteration in 0..<maxIterations {
                    // Check for cancellation
                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                        return
                    }

                    let gradient: T

                    if useNesterov {
                        // Nesterov: compute gradient at the "look-ahead" position
                        let lookAhead = x + (momentum * velocity)
                        gradient = numericalGradient(objective, at: lookAhead)
                    } else {
                        // Standard: compute gradient at current position
                        gradient = numericalGradient(objective, at: x)
                    }

                    let currentObjective = objective(x)

                    // Determine if we should report progress
                    let now = ContinuousClock.now
                    let timeSinceLastReport = now - lastReportTime
                    let shouldReportByTime = timeSinceLastReport >= config.progressUpdateInterval
                    let shouldReportByIteration = (iteration + 1) % config.reportEveryNIterations == 0

                    if shouldReportByTime || shouldReportByIteration {
                        let progress = AsyncOptimizationProgress(
                            iteration: iteration + 1,
                            currentValue: x,
                            objectiveValue: currentObjective,
                            gradient: gradient,
                            hasConverged: false,
                            timestamp: Date(),
                            phase: .optimization
                        )
                        continuation.yield(progress)
                        lastReportTime = now
                    }

                    // Check convergence (gradient near zero)
                    if abs(gradient) < tolerance {
                        // Emit final progress with converged = true
                        let finalProgress = AsyncOptimizationProgress(
                            iteration: iteration + 1,
                            currentValue: x,
                            objectiveValue: currentObjective,
                            gradient: gradient,
                            hasConverged: true,
                            timestamp: Date(),
                            phase: .finalization
                        )
                        continuation.yield(finalProgress)
                        continuation.finish()
                        return
                    }

                    // Update velocity with momentum
                    velocity = (momentum * velocity) - (learningRate * gradient)

                    // Gradient descent update
                    var xNew = x + velocity

                    // Apply bounds
                    let xConstrained = clamp(
                        xNew,
                        lower: bounds?.lower ?? T(-1) * T.infinity,
                        upper: bounds?.upper ?? T.infinity
                    )

                    // Check constraints
                    var constraintsSatisfied = true
                    for constraint in constraints {
                        if !constraint.isSatisfied(xConstrained) {
                            constraintsSatisfied = false
                            break
                        }
                    }

                    // If constraints violated, reduce step and try again
                    if !constraintsSatisfied {
                        var stepScale = tolerance * 5000
                        for _ in 0..<10 {
                            xNew = x - learningRate * velocity * stepScale
                            if let bounds = bounds {
                                xNew = clamp(xNew, lower: bounds.lower, upper: bounds.upper)
                            }

                            constraintsSatisfied = true
                            for constraint in constraints {
                                if !constraint.isSatisfied(xNew) {
                                    constraintsSatisfied = false
                                    break
                                }
                            }

                            if constraintsSatisfied {
                                break
                            }

                            stepScale = stepScale / 2
                        }
                    }

                    x = xConstrained

                    // Check if objective is increasing (potential divergence)
                    if iteration > 0 && currentObjective > previousObjective * 10 {
                        // Likely diverging - emit final progress and stop
                        let finalProgress = AsyncOptimizationProgress(
                            iteration: iteration + 1,
                            currentValue: x,
                            objectiveValue: currentObjective,
                            gradient: gradient,
                            hasConverged: false,
                            timestamp: Date(),
                            phase: .finalization
                        )
                        continuation.yield(finalProgress)
                        continuation.finish()
                        return
                    }
                    previousObjective = currentObjective

                    // Check if step is very small (converged)
                    if abs(velocity) < tolerance {
                        let finalProgress = AsyncOptimizationProgress(
                            iteration: iteration + 1,
                            currentValue: x,
                            objectiveValue: objective(x),
                            gradient: gradient,
                            hasConverged: true,
                            timestamp: Date(),
                            phase: .finalization
                        )
                        continuation.yield(finalProgress)
                        continuation.finish()
                        return
                    }

                    // Small delay to allow cancellation checks
                    try? await Task.sleep(for: .microseconds(1))
                }

                // Reached max iterations
                let finalProgress = AsyncOptimizationProgress(
                    iteration: maxIterations,
                    currentValue: x,
                    objectiveValue: objective(x),
                    gradient: numericalGradient(objective, at: x),
                    hasConverged: converged,
                    timestamp: Date(),
                    phase: .finalization
                )
                continuation.yield(finalProgress)
                continuation.finish()
            }
        }
    }

    /// Performs optimization and returns the final result.
    ///
    /// This convenience method runs the optimization to completion without
    /// streaming progress updates. For progress monitoring, use
    /// ``optimizeWithProgress(objective:constraints:initialGuess:bounds:config:)`` instead.
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize. Must be `@Sendable` for
    ///                safe concurrent access.
    ///   - constraints: Array of constraints that the solution must satisfy.
    ///   - initialGuess: Starting point for the optimization.
    ///   - bounds: Optional lower and upper bounds for the parameter value.
    ///
    /// - Returns: The optimization result containing the optimal value, objective
    ///            function value, iteration count, and convergence status.
    ///
    /// - Throws: Errors from the objective function evaluation or `CancellationError`
    ///           if the task is cancelled.
    ///
    /// ## Usage Example
    /// ```swift
    /// let optimizer = AsyncGradientDescentOptimizer<Double>()
    ///
    /// let result = try await optimizer.optimize(
    ///     objective: { x in x * x },
    ///     constraints: [],
    ///     initialGuess: 10.0,
    ///     bounds: nil
    /// )
    ///
    /// print("Optimal x: \(result.optimalValue)")
    /// print("Optimal f(x): \(result.objectiveValue)")
    /// ```
    public func optimize(
        objective: @escaping @Sendable (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,
        bounds: (lower: T, upper: T)?
    ) async throws -> OptimizationResult<T> {
        var finalX = initialGuess
        var finalFx = objective(initialGuess)
        var iterations = 0
        var converged = false

        for try await progress in optimizeWithProgress(
            objective: objective,
            constraints: constraints,
            initialGuess: initialGuess,
            bounds: bounds
        ) {
            finalX = progress.currentValue
            finalFx = progress.objectiveValue
            iterations = progress.iteration
            converged = progress.hasConverged

            if progress.hasConverged {
                break
            }
        }

        return OptimizationResult(
            optimalValue: finalX,
            objectiveValue: finalFx,
            iterations: iterations,
            converged: converged,
            history: []
        )
    }

    // MARK: - Helper Methods

    /// Computes the numerical gradient using central differences.
    ///
    /// - Parameters:
    ///   - f: The function.
    ///   - x: The point at which to evaluate the gradient.
    /// - Returns: The approximate gradient.
    private func numericalGradient(
        _ f: (T) -> T,
        at x: T
    ) -> T {
        let h = stepSize
        return (f(x + h) - f(x - h)) / (2 * h)
    }

    /// Clamps a value to be within bounds.
    ///
    /// - Parameters:
    ///   - value: The value to clamp.
    ///   - lower: The lower bound.
    ///   - upper: The upper bound.
    /// - Returns: The clamped value.
    private func clamp(_ value: T, lower: T, upper: T) -> T {
        return max(lower, min(upper, value))
    }
}
