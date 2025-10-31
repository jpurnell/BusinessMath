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
/// where f'(x) is the first derivative and f''(x) is the second derivative.
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
/// Newton-Raphson converges quadratically near the minimum, but may:
/// - Diverge if started far from the minimum
/// - Fail if the second derivative is zero or near zero
/// - Jump over bounds if not carefully constrained
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

		for iteration in 0..<maxIterations {
			let fx = objective(x)
			let derivative = numericalFirstDerivative(objective, at: x)

			// Record history
			history.append(IterationHistory(
				iteration: iteration,
				value: x,
				objective: fx,
				gradient: derivative
			))

			// Check convergence (function value near zero - root finding)
			if abs(fx) < tolerance {
				converged = true
				break
			}

			// Newton-Raphson update for root finding
			// x_{n+1} = x_n - f(x_n) / f'(x_n)
			var step: T
			// Use a reasonable epsilon for checking if derivative is too small
			let epsilon = tolerance / 10000
			if abs(derivative) > epsilon {
				step = fx / derivative
			} else {
				// Derivative too small - can't proceed reliably
				break
			}

			var xNew = x - step

			// Apply bounds
			if let bounds = bounds {
				xNew = clamp(xNew, lower: bounds.lower, upper: bounds.upper)
			}

			// Check constraints
			var constraintsSatisfied = true
			for constraint in constraints {
				if !constraint.isSatisfied(xNew) {
					constraintsSatisfied = false
					break
				}
			}

			// If constraints violated, reduce step size
			if !constraintsSatisfied {
				var stepScale = tolerance * 5000  // Start at 0.5 for typical tolerance
				for _ in 0..<10 {
					xNew = x - step * stepScale
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

			x = xNew

			// Check if step is very small
			if abs(step) < tolerance {
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
}
