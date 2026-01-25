//
//  MultiStartOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation
import Numerics

// MARK: - MultiStartOptimizer

/// A meta-optimizer that runs multiple optimizations in parallel from different starting points.
///
/// `MultiStartOptimizer` addresses a fundamental challenge in optimization: finding the
/// global minimum when multiple local minima exist. By launching parallel optimization
/// attempts from different starting points, it explores the search space more thoroughly
/// and returns the best solution found.
///
/// ## Algorithm
///
/// 1. Generate N starting points (either user-provided or auto-generated)
/// 2. Launch N parallel optimization tasks using `withTaskGroup`
/// 3. Each task runs the base optimizer from its starting point
/// 4. Collect all results and return the best one (lowest objective value)
///
/// ## Usage Example
///
/// ```swift
/// // Create base optimizer
/// let gradientDescent = AsyncGradientDescentOptimizer<Double>(
///     learningRate: 0.1,
///     tolerance: 1e-6
/// )
///
/// // Wrap in multi-start
/// let multiStart = MultiStartOptimizer(
///     baseOptimizer: gradientDescent,
///     numberOfStarts: 10
/// )
///
/// // Find global minimum of multi-modal function
/// let result = try await multiStart.optimize(
///     objective: { x in x * x * x * x - 4.0 * x * x },  // Has multiple minima
///     constraints: [],
///     initialGuess: 0.0,
///     bounds: (lower: -5.0, upper: 5.0)
/// )
///
/// print("Global minimum: x = \(result.optimalValue)")
/// ```
///
/// ## Parallel Execution
///
/// MultiStartOptimizer uses Swift's structured concurrency (`TaskGroup`) to run all
/// optimizations in parallel. This provides:
/// - Automatic parallelism based on available CPU cores
/// - Proper task cancellation propagation
/// - Memory-safe concurrent execution
///
/// ## Starting Point Generation
///
/// If bounds are provided, starting points are uniformly distributed:
/// ```
/// x_i = lower + (upper - lower) * i / (N - 1)  for i = 0, 1, ..., N-1
/// ```
///
/// If no bounds, starting points are generated around `initialGuess`:
/// ```
/// x_i = initialGuess + scale * randn()
/// ```
///
/// Alternatively, provide custom starting points:
/// ```swift
/// let customStarts = [0.0, 2.5, 5.0, 7.5, 10.0]
/// let multiStart = MultiStartOptimizer(
///     baseOptimizer: optimizer,
///     startingPoints: customStarts
/// )
/// ```
///
/// ## See Also
/// - ``AsyncOptimizer`` - Protocol for async optimizers
/// - ``AsyncGradientDescentOptimizer`` - Common base optimizer
/// - ``OptimizationResult`` - Result type
@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
public struct MultiStartOptimizer<BaseOptimizer: AsyncOptimizer>: AsyncOptimizer {
    public typealias T = BaseOptimizer.T

    // MARK: - Properties

    /// The base optimizer to run from each starting point.
    public let baseOptimizer: BaseOptimizer

    /// The number of parallel optimization attempts.
    public let numberOfStarts: Int

    /// Optional custom starting points. If nil, points are auto-generated.
    public let customStartingPoints: [T]?

    // MARK: - Initialization

    /// Creates a multi-start optimizer with a specified number of starts.
    ///
    /// Starting points will be auto-generated within bounds (if provided) or
    /// around the initial guess.
    ///
    /// - Parameters:
    ///   - baseOptimizer: The optimizer to run from each starting point.
    ///   - numberOfStarts: Number of parallel optimization attempts.
    public init(
        baseOptimizer: BaseOptimizer,
        numberOfStarts: Int
    ) {
        self.baseOptimizer = baseOptimizer
        self.numberOfStarts = numberOfStarts
        self.customStartingPoints = nil
    }

    /// Creates a multi-start optimizer with custom starting points.
    ///
    /// - Parameters:
    ///   - baseOptimizer: The optimizer to run from each starting point.
    ///   - startingPoints: Specific starting points to use.
    public init(
        baseOptimizer: BaseOptimizer,
        startingPoints: [T]
    ) {
        self.baseOptimizer = baseOptimizer
        self.numberOfStarts = startingPoints.count
        self.customStartingPoints = startingPoints
    }

    // MARK: - AsyncOptimizer Protocol

    /// Performs multi-start optimization with progress updates.
    ///
    /// This method launches multiple optimizations in parallel and streams progress
    /// updates from all of them. Progress updates are interleaved from different
    /// optimizers as they execute concurrently.
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize.
    ///   - constraints: Constraints that solutions must satisfy.
    ///   - initialGuess: Center point for auto-generated starts (if no bounds).
    ///   - bounds: Search space bounds. If provided, starting points are uniformly
    ///             distributed within bounds.
    ///   - config: Configuration for progress reporting.
    ///
    /// - Returns: An async stream of progress updates from all optimizers.
    ///
    /// ## Usage Example
    /// ```swift
    /// let multiStart = MultiStartOptimizer(
    ///     baseOptimizer: AsyncGradientDescentOptimizer<Double>(),
    ///     numberOfStarts: 5
    /// )
    ///
    /// for try await progress in multiStart.optimizeWithProgress(
    ///     objective: { x in (x - 5.0) * (x - 5.0) },
    ///     constraints: [],
    ///     initialGuess: 0.0,
    ///     bounds: (lower: 0.0, upper: 10.0)
    /// ) {
    ///     print("Progress: iteration \(progress.iteration), f(x) = \(progress.objectiveValue)")
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
                // Generate starting points
                let startingPoints = generateStartingPoints(
                    initialGuess: initialGuess,
                    bounds: bounds
                )

                // Launch parallel optimizations
                await withThrowingTaskGroup(of: Void.self) { group in
                    for start in startingPoints {
                        group.addTask { @Sendable in
                            // Stream progress from this optimizer
                            for try await progress in self.baseOptimizer.optimizeWithProgress(
                                objective: objective,
                                constraints: constraints,
                                initialGuess: start,
                                bounds: bounds,
                                config: config
                            ) {
                                continuation.yield(progress)

                                if Task.isCancelled {
                                    return
                                }
                            }
                        }
                    }

                    // Wait for all tasks to complete
                    do {
                        for try await _ in group {
                            if Task.isCancelled {
                                continuation.finish(throwing: CancellationError())
                                return
                            }
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }

                continuation.finish()
            }
        }
    }

    /// Performs multi-start optimization and returns the best result.
    ///
    /// This method launches multiple optimizations in parallel and returns the result
    /// with the lowest objective function value.
    ///
    /// - Parameters:
    ///   - objective: The objective function to minimize.
    ///   - constraints: Constraints that solutions must satisfy.
    ///   - initialGuess: Center point for auto-generated starts (if no bounds).
    ///   - bounds: Search space bounds.
    ///
    /// - Returns: The best optimization result found across all starting points.
    ///
    /// - Throws: Errors from the base optimizer or `CancellationError` if cancelled.
    ///
    /// ## Usage Example
    /// ```swift
    /// let multiStart = MultiStartOptimizer(
    ///     baseOptimizer: AsyncGradientDescentOptimizer<Double>(),
    ///     numberOfStarts: 10
    /// )
    ///
    /// let result = try await multiStart.optimize(
    ///     objective: { x in x * x * x * x - 4.0 * x * x },
    ///     constraints: [],
    ///     initialGuess: 0.0,
    ///     bounds: (lower: -5.0, upper: 5.0)
    /// )
    ///
    /// print("Global minimum: \(result.optimalValue)")
    /// ```
    public func optimize(
        objective: @escaping @Sendable (T) -> T,
        constraints: [Constraint<T>],
        initialGuess: T,
        bounds: (lower: T, upper: T)?
    ) async throws -> OptimizationResult<T> {
        // Generate starting points
        let startingPoints = generateStartingPoints(
            initialGuess: initialGuess,
            bounds: bounds
        )

        // Launch parallel optimizations and collect results
        let results = await withTaskGroup(of: OptimizationResult<T>?.self) { group in
            for start in startingPoints {
                group.addTask {
                    do {
                        return try await self.baseOptimizer.optimize(
                            objective: objective,
                            constraints: constraints,
                            initialGuess: start,
                            bounds: bounds
                        )
                    } catch {
                        return nil
                    }
                }
            }

            var collected: [OptimizationResult<T>] = []
            for await result in group {
                if let result = result {
                    collected.append(result)
                }

                if Task.isCancelled {
                    break
                }
            }
            return collected
        }

        // Find best result (lowest objective value)
        guard let bestResult = results.min(by: { $0.objectiveValue < $1.objectiveValue }) else {
            // All optimizations failed - return a default result
            return OptimizationResult(
                optimalValue: initialGuess,
                objectiveValue: objective(initialGuess),
                iterations: 0,
                converged: false,
                history: []
            )
        }

        return bestResult
    }

    // MARK: - Helper Methods

    /// Generates starting points for multi-start optimization.
    ///
    /// - Parameters:
    ///   - initialGuess: Center point for generation (used if no bounds).
    ///   - bounds: Optional bounds for uniform distribution.
    ///
    /// - Returns: Array of starting points.
    private func generateStartingPoints(
        initialGuess: T,
        bounds: (lower: T, upper: T)?
    ) -> [T] {
        // Use custom starting points if provided
        if let custom = customStartingPoints {
            return custom
        }

        // Single start case
        if numberOfStarts == 1 {
            return [initialGuess]
        }

        // Generate starting points
        if let bounds = bounds {
            // Uniformly distribute within bounds
            let range = bounds.upper - bounds.lower
            return (0..<numberOfStarts).map { i in
                let fraction = T(i) / T(numberOfStarts - 1)
                return bounds.lower + range * fraction
            }
        } else {
            // Generate points around initial guess
            // Use a heuristic scale based on initial guess magnitude
            let one = T(1)
            let scale = max(one, abs(initialGuess))

            return (0..<numberOfStarts).map { i in
                // Create evenly spaced points around initial guess
                let iVal = T(i)
                let nMinusOne = T(numberOfStarts - 1)
                let nVal = T(numberOfStarts)
                let half = nMinusOne / T(2)
                let offset = (iVal - half) * scale / nVal
                return initialGuess + offset
            }
        }
    }
}
