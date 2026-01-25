//
//  AsyncOptimization.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation
import Numerics

// MARK: - Optimization Phase

/// Represents the current phase of an optimization algorithm.
///
/// Optimization algorithms may proceed through multiple phases:
/// - **Initialization**: Setting up the problem and initial state
/// - **Phase I**: Finding a feasible solution (used in two-phase methods like Simplex)
/// - **Phase II**: Optimizing the objective function from a feasible starting point
/// - **Optimization**: Main optimization loop (single-phase methods)
/// - **Finalization**: Post-processing and result compilation
///
/// ## Usage Example
/// ```swift
/// let phase: OptimizationPhase = .optimization
/// switch phase {
/// case .initialization:
///     print("Setting up...")
/// case .optimization:
///     print("Optimizing...")
/// case .finalization:
///     print("Finalizing results...")
/// default:
///     break
/// }
/// ```
///
/// ## See Also
/// - ``AsyncOptimizationProgress``
/// - ``AsyncOptimizer``
public enum OptimizationPhase: Sendable, Equatable, Hashable {
    /// Initial setup phase before optimization begins.
    case initialization

    /// Phase I of two-phase optimization (finding feasible solution).
    case phaseI

    /// Phase II of two-phase optimization (optimizing objective).
    case phaseII

    /// Main optimization phase for single-phase algorithms.
    case optimization

    /// Final phase for result compilation and cleanup.
    case finalization
}

// MARK: - Optimization Progress

/// Progress information emitted during asynchronous optimization.
///
/// This type captures a snapshot of the optimization state at a specific iteration,
/// allowing consumers to monitor long-running optimizations in real-time.
///
/// - Parameters:
///   - T: The numeric type used for optimization values. Must conform to `Real` for
///        mathematical operations and `Sendable` for safe concurrent access.
///
/// ## Usage Example
/// ```swift
/// let progress = AsyncOptimizationProgress<Double>(
///     iteration: 42,
///     currentValue: 3.14,
///     objectiveValue: 0.001,
///     gradient: -0.0001,
///     hasConverged: false,
///     timestamp: Date(),
///     phase: .optimization
/// )
///
/// print("Iteration \(progress.iteration): f(x) = \(progress.objectiveValue)")
/// ```
///
/// ## Real-Time Monitoring
/// Progress updates are emitted through `AsyncThrowingStream` during optimization:
/// ```swift
/// for try await progress in optimizer.optimizeWithProgress(...) {
///     print("Iteration \(progress.iteration): \(progress.objectiveValue)")
///     if progress.hasConverged {
///         print("Converged!")
///         break
///     }
/// }
/// ```
///
/// ## See Also
/// - ``AsyncOptimizer``
/// - ``OptimizationPhase``
/// - ``OptimizationConfig``
public struct AsyncOptimizationProgress<T: Real & Sendable>: Sendable {
    /// The current iteration number (zero-indexed).
    public let iteration: Int

    /// The current parameter value being evaluated.
    public let currentValue: T

    /// The objective function value at the current parameter.
    ///
    /// For minimization problems, this value should decrease over iterations.
    /// For maximization problems, this value should increase.
    public let objectiveValue: T

    /// The gradient at the current point, if available.
    ///
    /// Gradient-free methods (like Nelder-Mead) may not provide this value.
    /// Two-phase methods may not compute gradients during Phase I.
    public let gradient: T?

    /// Whether the optimization has converged to a solution.
    ///
    /// Convergence is determined by the algorithm's specific criteria,
    /// typically based on gradient magnitude or function value change.
    public let hasConverged: Bool

    /// The timestamp when this progress update was created.
    public let timestamp: Date

    /// The current phase of the optimization algorithm.
    public let phase: OptimizationPhase

    /// Creates a new optimization progress snapshot.
    ///
    /// - Parameters:
    ///   - iteration: The current iteration number (zero-indexed).
    ///   - currentValue: The current parameter value being evaluated.
    ///   - objectiveValue: The objective function value at the current parameter.
    ///   - gradient: The gradient at the current point, if available.
    ///   - hasConverged: Whether the optimization has converged.
    ///   - timestamp: The timestamp when this progress update was created.
    ///   - phase: The current phase of the optimization algorithm.
    public init(
        iteration: Int,
        currentValue: T,
        objectiveValue: T,
        gradient: T?,
        hasConverged: Bool,
        timestamp: Date,
        phase: OptimizationPhase
    ) {
        self.iteration = iteration
        self.currentValue = currentValue
        self.objectiveValue = objectiveValue
        self.gradient = gradient
        self.hasConverged = hasConverged
        self.timestamp = timestamp
        self.phase = phase
    }
}

// MARK: - Async Optimizer Protocol

/// Protocol for asynchronous optimization algorithms.
///
/// This protocol defines the interface for optimizers that support async/await,
/// progress streaming, and task cancellation. Conforming types can solve
/// optimization problems while reporting real-time progress updates.
///
/// - Parameters:
///   - T: The numeric type used for optimization. Must conform to `Real` for
///        mathematical operations, `Sendable` for safe concurrent access, and
///        `Codable` for result serialization.
///
/// ## Usage Example
/// ```swift
/// struct MyOptimizer: AsyncOptimizer {
///     typealias T = Double
///
///     func optimizeWithProgress(
///         objective: @escaping @Sendable (Double) -> Double,
///         constraints: [Constraint<Double>],
///         initialGuess: Double,
///         bounds: (lower: Double, upper: Double)?
///     ) -> AsyncThrowingStream<AsyncOptimizationProgress<Double>, Error> {
///         // Implementation...
///     }
///
///     func optimize(...) async throws -> OptimizationResult<Double> {
///         // Implementation...
///     }
/// }
/// ```
///
/// ## Real-Time Progress Monitoring
/// The `optimizeWithProgress` method returns an `AsyncThrowingStream` that emits
/// progress updates during optimization:
/// ```swift
/// let optimizer = AsyncGradientDescentOptimizer<Double>()
///
/// for try await progress in optimizer.optimizeWithProgress(...) {
///     print("Iteration \(progress.iteration): f(x) = \(progress.objectiveValue)")
///     if progress.hasConverged {
///         print("Converged!")
///         break
///     }
/// }
/// ```
///
/// ## Task Cancellation
/// Implementations should check `Task.isCancelled` periodically and terminate
/// gracefully when cancelled:
/// ```swift
/// for iteration in 0..<maxIterations {
///     if Task.isCancelled {
///         continuation.finish(throwing: CancellationError())
///         return
///     }
///     // ... optimization logic ...
/// }
/// ```
///
/// ## See Also
/// - ``AsyncOptimizationProgress``
/// - ``OptimizationConfig``
/// - ``OptimizationPhase``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public protocol AsyncOptimizer: Sendable {
    /// The numeric type used for optimization values.
    associatedtype T: Real & Sendable & Codable

    /// Performs optimization with real-time progress updates.
    ///
    /// This method returns an `AsyncThrowingStream` that emits progress updates
    /// as the optimization proceeds. Consumers can monitor convergence, track
    /// objective values, and visualize the optimization trajectory.
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize. Must be `@Sendable` for
    ///                safe concurrent access.
    ///   - constraints: Array of constraints that the solution must satisfy.
    ///   - initialGuess: Starting point for the optimization.
    ///   - bounds: Optional lower and upper bounds for the parameter value.
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
    /// }
    /// ```
    func optimizeWithProgress(
        objective: @escaping @Sendable (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,
        bounds: (lower: T, upper: T)?,
        config: OptimizationConfig
    ) -> AsyncThrowingStream<AsyncOptimizationProgress<T>, Error>

    /// Performs optimization and returns the final result.
    ///
    /// This is a convenience method that runs the optimization to completion
    /// without streaming progress updates. For progress monitoring, use
    /// ``optimizeWithProgress(objective:constraints:initialGuess:bounds:)`` instead.
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize. Must be `@Sendable` for
    ///                safe concurrent access.
    ///   - constraints: Array of constraints that the solution must satisfy.
    ///   - initialGuess: Starting point for the optimization.
    ///   - bounds: Optional lower and upper bounds for the parameter value.
    ///
    /// - Returns: The optimization result containing the optimal value, objective
    ///            function value, iteration count, and success status.
    ///
    /// - Throws: Errors from the objective function evaluation or optimization
    ///           algorithm. Also throws `CancellationError` if the task is cancelled.
    ///
    /// ## Usage Example
    /// ```swift
    /// let optimizer = AsyncGradientDescentOptimizer<Double>()
    ///
    /// let result = try await optimizer.optimize(
    ///     objective: { x in (x - 5.0) * (x - 5.0) },
    ///     constraints: [],
    ///     initialGuess: 0.0,
    ///     bounds: nil
    /// )
    ///
    /// print("Optimal x: \(result.x)")
    /// print("Optimal f(x): \(result.fx)")
    /// ```
    func optimize(
        objective: @escaping @Sendable (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,
        bounds: (lower: T, upper: T)?
    ) async throws -> OptimizationResult<T>
}

// MARK: - Optimization Configuration

/// Configuration parameters for asynchronous optimization algorithms.
///
/// This type controls how often progress updates are emitted, convergence criteria,
/// and iteration limits for async optimizers.
///
/// ## Usage Example
/// ```swift
/// // Use default configuration
/// let config = OptimizationConfig.default
///
/// // Customize for specific needs
/// let customConfig = OptimizationConfig(
///     progressUpdateInterval: .milliseconds(500),
///     maxIterations: 1000,
///     tolerance: 1e-4,
///     reportEveryNIterations: 10
/// )
/// ```
///
/// ## Progress Reporting
/// The `progressUpdateInterval` controls the minimum time between progress emissions,
/// while `reportEveryNIterations` controls the frequency based on iteration count.
/// Progress is emitted when either condition is met.
///
/// ## Convergence Criteria
/// The `tolerance` parameter defines the convergence threshold. The specific
/// interpretation depends on the algorithm:
/// - **Gradient descent**: Maximum gradient magnitude
/// - **Simplex**: Relative change in objective function
/// - **Newton methods**: Step size magnitude
///
/// ## See Also
/// - ``AsyncOptimizer``
/// - ``AsyncOptimizationProgress``
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct OptimizationConfig: Sendable {
    /// Minimum time interval between progress updates.
    ///
    /// Progress will not be emitted more frequently than this interval,
    /// even if `reportEveryNIterations` would suggest more frequent updates.
    public let progressUpdateInterval: Duration

    /// Maximum number of iterations before termination.
    ///
    /// If the algorithm does not converge within this many iterations,
    /// it will terminate and return the best solution found.
    public let maxIterations: Int

    /// Convergence tolerance threshold.
    ///
    /// The specific interpretation depends on the optimization algorithm.
    /// Common interpretations:
    /// - Gradient magnitude: `||∇f(x)|| < tolerance`
    /// - Function change: `|f(x_{k+1}) - f(x_k)| < tolerance`
    /// - Parameter change: `||x_{k+1} - x_k|| < tolerance`
    public let tolerance: Double

    /// Report progress every N iterations.
    ///
    /// In addition to the time-based `progressUpdateInterval`, progress
    /// will be emitted every N iterations regardless of time elapsed.
    /// Set to 1 to report every iteration.
    public let reportEveryNIterations: Int

    /// Default configuration for general-purpose optimization.
    ///
    /// - Progress updates: Every 100ms
    /// - Max iterations: 10,000
    /// - Tolerance: 1e-6
    /// - Report frequency: Every iteration
    public static let `default` = OptimizationConfig(
        progressUpdateInterval: .milliseconds(100),
        maxIterations: 10_000,
        tolerance: 1e-6,
        reportEveryNIterations: 1
    )

    /// Creates a new optimization configuration.
    ///
    /// - Parameters:
    ///   - progressUpdateInterval: Minimum time interval between progress updates.
    ///   - maxIterations: Maximum number of iterations before termination.
    ///   - tolerance: Convergence tolerance threshold.
    ///   - reportEveryNIterations: Report progress every N iterations.
    public init(
        progressUpdateInterval: Duration,
        maxIterations: Int,
        tolerance: Double,
        reportEveryNIterations: Int
    ) {
        self.progressUpdateInterval = progressUpdateInterval
        self.maxIterations = maxIterations
        self.tolerance = tolerance
        self.reportEveryNIterations = reportEveryNIterations
    }
}
