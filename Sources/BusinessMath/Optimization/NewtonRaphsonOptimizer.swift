//
//  NewtonRaphsonOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - NewtonRaphsonOptimizer

/// An optimizer using the Newton-Raphson method.
///
/// `NewtonRaphsonOptimizer` finds local minima of smooth functions using
/// second-order information (the Hessian). It converges quadratically near
/// the minimum but requires the objective function to be twice differentiable.
///
/// ## Algorithm
///
/// The Newton-Raphson method for minimization iterates:
///
/// ```
/// x_{n+1} = x_n - f'(x_n) / f''(x_n)
/// ```
///
/// where f'(x) is the first derivative (gradient) and f''(x) is the second
/// derivative (Hessian for 1D). This finds points where f'(x) = 0, which are
/// candidates for local minima or maxima.
///
/// ## Usage
///
/// ```swift
/// let optimizer = NewtonRaphsonOptimizer<Double>(
///     tolerance: 0.001,
///     maxIterations: 100
/// )
///
/// // Minimize f(x) = (x - 5)^2
/// let objective = { (x: Double) -> Double in
///     return (x - 5.0) * (x - 5.0)
/// }
///
/// let result = optimizer.optimize(
///     objective: objective,
///     constraints: [],
///     initialValue: 0.0,
///     bounds: nil
/// )
///
/// print(result.optimalValue)  // ≈ 5.0
/// ```
///
/// ## Numerical Derivatives
///
/// This implementation uses finite differences to approximate derivatives:
/// - First derivative: f'(x) ≈ (f(x+h) - f(x-h)) / (2h)
/// - Second derivative: f''(x) ≈ (f(x+h) - 2f(x) + f(x-h)) / h²
///
/// ## Convergence
///
/// Newton-Raphson converges quadratically near a local minimum when:
/// - The function is sufficiently smooth (twice differentiable)
/// - The initial point is close enough to the minimum
/// - The second derivative (Hessian) is positive and bounded away from zero
///
/// The algorithm may:
/// - Diverge if started far from the minimum
/// - Fail if the second derivative is zero or near zero (inflection point)
/// - Find saddle points or maxima instead of minima if f''(x) < 0
/// - Require projection when constraints are active
///
/// For constrained optimization, the algorithm projects iterates to the feasible
/// region and may converge to boundary points where the constraint is active.
public struct NewtonRaphsonOptimizer<T>: Optimizer where T: Real & Sendable & Codable {

	// MARK: - Properties

	/// Convergence tolerance.
	public let tolerance: T

	/// Maximum number of iterations.
	public let maxIterations: Int

	/// Step size for numerical derivatives.
	public let stepSize: T

	// MARK: - Initialization

	/// Creates a Newton-Raphson optimizer.
	///
	/// - Parameters:
	///   - tolerance: Convergence tolerance. Defaults to 0.0001.
	///   - maxIterations: Maximum number of iterations. Defaults to 100.
	///   - stepSize: Step size for numerical derivatives. Defaults to 0.0001.
	public init(
		tolerance: T = 0.0001,
		maxIterations: Int = 100,
		stepSize: T = 0.0001
	) {
		self.tolerance = tolerance
		self.maxIterations = maxIterations
		self.stepSize = stepSize
	}

	// MARK: - Optimization

	/// Optimizes an objective function using Newton-Raphson method.
	///
	/// - Parameters:
	///   - objective: The objective function to minimize.
	///   - constraints: Constraints that the solution must satisfy.
	///   - initialValue: The starting value.
	///   - bounds: Optional bounds (lower, upper).
	/// - Returns: The optimization result.
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
			let firstDerivative = numericalFirstDerivative(objective, at: x)
			let secondDerivative = numericalSecondDerivative(objective, at: x)

			// Record history
			history.append(IterationHistory(
				iteration: iteration,
				value: x,
				objective: fx,
				gradient: firstDerivative
			))

			// Check convergence (gradient near zero - optimization)
			if abs(firstDerivative) < tolerance {
				converged = true
				break
			}

			// Newton-Raphson update for optimization
			// x_{n+1} = x_n - f'(x_n) / f''(x_n)
			var step: T
			// Use a reasonable epsilon for checking if second derivative is too small
			let epsilon = tolerance / 1000
			if abs(secondDerivative) > epsilon {
				step = firstDerivative / secondDerivative
			} else {
				// Second derivative too small or negative - use gradient descent step
				// This handles cases where Newton's method would fail
				step = firstDerivative * stepSize * 10
			}

			var xNew = x - step

			// Apply bounds
			if let bounds = bounds {
				xNew = clamp(xNew, lower: bounds.lower, upper: bounds.upper)
			}

			// Project to feasible region (respecting constraints)
			xNew = projectToFeasibleRegion(xNew, constraints: constraints, bounds: bounds)

			// If projection didn't work or we're at a constraint boundary,
			// check if we're at a constrained minimum
			if !allConstraintsSatisfied(xNew, constraints: constraints) {
				// If we can't satisfy constraints, try to find feasible point
				// by moving along the gradient toward feasibility
				xNew = findFeasiblePoint(
					from: x,
					constraints: constraints,
					bounds: bounds,
					objective: objective
				)
			}

			// Check if we're making progress
			let movement = abs(xNew - x)
			x = xNew

			// Check if step is very small (converged)
			if movement < tolerance {
				converged = true
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

	/// Computes the numerical first derivative using central differences.
	///
	/// - Parameters:
	///   - f: The function.
	///   - x: The point at which to evaluate the derivative.
	/// - Returns: The approximate first derivative.
	private func numericalFirstDerivative(
		_ f: (T) -> T,
		at x: T
	) -> T {
		let h = stepSize
		return (f(x + h) - f(x - h)) / (2 * h)
	}

	/// Computes the numerical second derivative using finite differences.
	///
	/// - Parameters:
	///   - f: The function.
	///   - x: The point at which to evaluate the derivative.
	/// - Returns: The approximate second derivative.
	private func numericalSecondDerivative(
		_ f: (T) -> T,
		at x: T
	) -> T {
		let h = stepSize
		return (f(x + h) - 2 * f(x) + f(x - h)) / (h * h)
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

	/// Checks if all constraints are satisfied.
	///
	/// - Parameters:
	///   - value: The value to check.
	///   - constraints: The constraints to check.
	/// - Returns: True if all constraints are satisfied.
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
	///
	/// This method attempts to find the nearest point that satisfies all constraints.
	/// For simple bound constraints, it clamps the value. For more complex constraints,
	/// it may need to search.
	///
	/// - Parameters:
	///   - value: The value to project.
	///   - constraints: The constraints to satisfy.
	///   - bounds: Optional bounds.
	/// - Returns: A feasible value that satisfies constraints.
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

	/// Finds a feasible point when projection fails.
	///
	/// This method searches for a point that satisfies constraints by moving
	/// in the direction that improves feasibility while considering the objective.
	///
	/// - Parameters:
	///   - start: The starting value.
	///   - constraints: The constraints to satisfy.
	///   - bounds: Optional bounds.
	///   - objective: The objective function.
	/// - Returns: A feasible value.
	private func findFeasiblePoint(
		from start: T,
		constraints: [Constraint<T>],
		bounds: (lower: T, upper: T)?,
		objective: @escaping (T) -> T
	) -> T {
		let x = start

		// Try small steps in both directions to find feasible region
		let directions: [T] = [1, -1]
		let stepSizes: [T] = [
			stepSize * 10,
			stepSize * 100,
			stepSize * 1000
		]

		for stepMagnitude in stepSizes {
			for direction in directions {
				let candidate = x + direction * stepMagnitude

				var feasibleCandidate = candidate
				if let bounds = bounds {
					feasibleCandidate = clamp(candidate, lower: bounds.lower, upper: bounds.upper)
				}

				if allConstraintsSatisfied(feasibleCandidate, constraints: constraints) {
					return feasibleCandidate
				}
			}
		}

		// If no feasible point found, return the projected point
		return projectToFeasibleRegion(x, constraints: constraints, bounds: bounds)
	}
}
