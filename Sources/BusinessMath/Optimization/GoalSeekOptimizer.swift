//
//  GoalSeekOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 11/10/24.
//

import Foundation
import Numerics

// MARK: - GoalSeekOptimizer

/// An optimizer using the Goal Seek (Newton-Raphson root-finding) method.
///
/// `GoalSeekOptimizer` finds values where a function equals a target value (root-finding),
/// as opposed to finding minima/maxima (optimization). This is useful for breakeven analysis,
/// solving equations, and finding specific outcomes.
///
/// ## Algorithm
///
/// Goal Seek uses the Newton-Raphson method for root-finding:
///
/// ```
/// x_{n+1} = x_n - (f(x_n) - target) / f'(x_n)
/// ```
///
/// This iteratively finds x where f(x) = target.
///
/// ## Usage
///
/// ```swift
/// let optimizer = GoalSeekOptimizer<Double>(
///     target: 0.0,          // Find where function equals zero
///     tolerance: 0.0001,
///     maxIterations: 1000
/// )
///
/// // Find where profit(price) = 0 (breakeven)
/// let result = optimizer.optimize(
///     objective: profitFunction,
///     constraints: [],
///     initialValue: 0.30,
///     bounds: (0.0, 1.0)
/// )
///
/// print("Breakeven price: \(result.optimalValue)")
/// ```
///
/// ## Difference from NewtonRaphsonOptimizer
///
/// - **GoalSeekOptimizer**: Finds where f(x) = target (root-finding)
///   - Use for: breakeven analysis, solving equations, target values
///   - Example: Find price where profit = 0
///
/// - **NewtonRaphsonOptimizer**: Finds where f'(x) = 0 (optimization)
///   - Use for: maximizing/minimizing
///   - Example: Find price where profit is maximum
///
/// ## Convergence
///
/// Goal Seek converges quadratically when:
/// - The function is sufficiently smooth (differentiable)
/// - The initial guess is reasonably close to the root
/// - The derivative is non-zero near the root
///
/// The algorithm may fail if:
/// - The derivative is zero or near zero at any iteration
/// - The initial guess is too far from the root
/// - No root exists in the feasible region
public struct GoalSeekOptimizer<T>: Optimizer where T: Real & Sendable & Codable {

    // MARK: - Properties

    /// The target value that the objective function should equal.
    public let target: T

    /// Convergence tolerance.
    public let tolerance: T

    /// Maximum number of iterations.
    public let maxIterations: Int

    /// Step size for numerical derivatives.
    public let stepSize: T

    // MARK: - Initialization

    /// Creates a Goal Seek optimizer.
    ///
    /// - Parameters:
    ///   - target: The target value the function should equal. Defaults to 0.
    ///   - tolerance: Convergence tolerance. Defaults to 0.0001.
    ///   - maxIterations: Maximum number of iterations. Defaults to 1000.
    ///   - stepSize: Step size for numerical derivatives. Defaults to 0.0001.
    public init(
        target: T = 0,
        tolerance: T = 0.0001,
        maxIterations: Int = 1000,
        stepSize: T = 0.0001
    ) {
        self.target = target
        self.tolerance = tolerance
        self.maxIterations = maxIterations
        self.stepSize = stepSize
    }

    // MARK: - Optimization

    /// Finds a value where the objective function equals the target.
    ///
    /// - Parameters:
    ///   - objective: The objective function.
    ///   - constraints: Constraints that the solution must satisfy.
    ///   - initialValue: The starting value.
    ///   - bounds: Optional bounds (lower, upper).
    /// - Returns: The optimization result containing the root.
    public func optimize(
        objective: @escaping (T) -> T,
        constraints: [Constraint<T>],
        initialValue: T,
        bounds: (lower: T, upper: T)?
    ) -> OptimizationResult<T> {
        var x = initialValue
        var history: [IterationHistory<T>] = []
        var converged = false

        // Apply bounds to initial value
        if let bounds = bounds {
            x = clamp(x, lower: bounds.lower, upper: bounds.upper)
        }

        // Apply constraints to initial value
        x = projectToFeasibleRegion(x, constraints: constraints, bounds: bounds)

        for iteration in 0..<maxIterations {
            let fx = objective(x)
            let error = fx - target

            // Calculate derivative
            let derivative = numericalDerivative(objective, at: x)

            // Record history
            history.append(IterationHistory(
                iteration: iteration,
                value: x,
                objective: fx,
                gradient: derivative
            ))

            // Check convergence (function value near target)
            if abs(error) < tolerance {
                converged = true
                break
            }

            // Check for zero derivative
            let epsilon = tolerance / T(1000)
            guard abs(derivative) > epsilon else {
                // Derivative too small - cannot continue
                break
            }

            // Newton-Raphson update for root-finding
            // x_{n+1} = x_n - (f(x_n) - target) / f'(x_n)
            let step = error / derivative
            var xNew = x - step

            // Apply bounds
            if let bounds = bounds {
                xNew = clamp(xNew, lower: bounds.lower, upper: bounds.upper)
            }

            // Project to feasible region
            xNew = projectToFeasibleRegion(xNew, constraints: constraints, bounds: bounds)

            // Check if we're making progress
            let movement = abs(xNew - x)
            x = xNew

            // Check if step is very small (converged)
            if movement < tolerance {
                // Verify we're actually at the target
                let finalError = abs(objective(x) - target)
                converged = finalError < tolerance
                break
            }
        }

        return OptimizationResult(
            optimalValue: x,
            objectiveValue: objective(x),
            iterations: history.count,
            converged: converged,
            history: history
        )
    }

    // MARK: - Helper Methods

    /// Computes the numerical derivative using central differences.
    ///
    /// - Parameters:
    ///   - f: The function.
    ///   - x: The point at which to evaluate the derivative.
    /// - Returns: The approximate derivative.
    private func numericalDerivative(
        _ f: (T) -> T,
        at x: T
    ) -> T {
        let h = stepSize
        return (f(x + h) - f(x - h)) / (2 * h)
    }

    /// Clamps a value to be within bounds.
    private func clamp(_ value: T, lower: T, upper: T) -> T {
        return max(lower, min(upper, value))
    }

    /// Checks if all constraints are satisfied.
    private func allConstraintsSatisfied(
        _ value: T,
        constraints: [Constraint<T>]
    ) -> Bool {
        for constraint in constraints {
            if !constraint.isSatisfied(value) {
                return false
            }
        }
        return true
    }

    /// Projects a value to the nearest feasible point.
    private func projectToFeasibleRegion(
        _ value: T,
        constraints: [Constraint<T>],
        bounds: (lower: T, upper: T)?
    ) -> T {
        var x = value

        // First apply bounds
        if let bounds = bounds {
            x = clamp(x, lower: bounds.lower, upper: bounds.upper)
        }

        // Check if already feasible
        if allConstraintsSatisfied(x, constraints: constraints) {
            return x
        }

        // For each violated constraint, try to move to the boundary
        for constraint in constraints {
            if !constraint.isSatisfied(x) {
                // For simple constraints on the value itself (no function)
                if constraint.function == nil {
                    switch constraint.type {
                    case .greaterThan:
                        x = max(x, constraint.bound + tolerance)
                    case .greaterThanOrEqual:
                        x = max(x, constraint.bound)
                    case .lessThan:
                        x = min(x, constraint.bound - tolerance)
                    case .lessThanOrEqual:
                        x = min(x, constraint.bound)
                    case .equalTo:
                        x = constraint.bound
                    }
                }
            }
        }

        // Reapply bounds after constraint projection
        if let bounds = bounds {
            x = clamp(x, lower: bounds.lower, upper: bounds.upper)
        }

        return x
    }
}
