//
//  GradientDescentOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - GradientDescentOptimizer

/// An optimizer using gradient descent with optional momentum and Nesterov acceleration.
///
/// `GradientDescentOptimizer` finds local minima by iteratively moving in the
/// direction of steepest descent. It supports momentum to accelerate convergence
/// and dampen oscillations, with an optional Nesterov variant for improved convergence.
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
/// ## Usage
///
/// ```swift
/// // Standard gradient descent with momentum
/// let optimizer = GradientDescentOptimizer<Double>(
///     learningRate: 0.1,
///     tolerance: 0.001,
///     maxIterations: 1000,
///     momentum: 0.9
/// )
///
/// // Nesterov Accelerated Gradient
/// let nesterovOptimizer = GradientDescentOptimizer<Double>(
///     learningRate: 0.1,
///     tolerance: 0.001,
///     maxIterations: 1000,
///     momentum: 0.9,
///     useNesterov: true
/// )
///
/// // Minimize f(x) = x^2
/// let objective = { (x: Double) -> Double in
///     return x * x
/// }
///
/// let result = nesterovOptimizer.optimize(
///     objective: objective,
///     constraints: [],
///     initialGuess: 10.0,
///     bounds: nil
/// )
///
/// print(result.optimalValue)  // ≈ 0.0
/// ```
///
/// ## Learning Rate
///
/// The learning rate controls the step size:
/// - Too small: slow convergence
/// - Too large: oscillation or divergence
///
/// Typical values: 0.001 - 0.1
///
/// ## Momentum
///
/// Momentum helps accelerate convergence:
/// - 0.0: no momentum (standard gradient descent)
/// - 0.9: typical value for good acceleration
/// - 0.99: high momentum for slowly varying gradients
///
/// ## Nesterov Acceleration
///
/// Nesterov acceleration improves upon standard momentum by computing the gradient
/// at the "look-ahead" position (where momentum would take us) rather than the
/// current position. This often results in:
/// - Faster convergence
/// - Better handling of curvature
/// - More stable optimization in some cases
///
/// Nesterov is particularly effective for convex optimization problems.
public struct GradientDescentOptimizer<T>: Optimizer where T: Real & Sendable & Codable {

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

	/// Creates a gradient descent optimizer.
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
		momentum: T = T(797734375) / T(1000000000),
		useNesterov: Bool = false,
		stepSize: T = 0.0001
	) {
		// Check momentum bounds
		guard momentum >= 0 && momentum <= T(797734375) / T(1000000000) else {
//			print("Momentum must be in the range [0, 0.797734375). Setting to maximum value.")
			self.learningRate = learningRate
			self.tolerance = tolerance
			self.maxIterations = maxIterations
			self.momentum = T(797734375) / T(1000000000)
			self.useNesterov = useNesterov
			self.stepSize = stepSize
			return
		}

		self.learningRate = learningRate
		self.tolerance = tolerance
		self.maxIterations = maxIterations
		self.momentum = momentum
		self.useNesterov = useNesterov
		self.stepSize = stepSize
	}

	// MARK: - Optimization

	/// Optimizes an objective function using gradient descent.
	///
	/// - Parameters:
	///   - objective: The objective function to minimize.
	///   - constraints: Constraints that the solution must satisfy.
	///   - initialGuess: The starting value.
	///   - bounds: Optional bounds (lower, upper).
	/// - Returns: The optimization result.
	public func optimize(
		objective: @escaping @Sendable (T) -> T,
		constraints: [Constraint<T>],
		initialGuess: T,
		bounds: (lower: T, upper: T)?
	) -> OptimizationResult<T> {
		var x = initialGuess
		var velocity: T = 0
		var history: [IterationHistory<T>] = []
		var converged = false

		// Apply bounds to initial value
		if let bounds = bounds {
			x = clamp(x, lower: bounds.lower, upper: bounds.upper)
		}

		var previousObjective = objective(x)

		for iteration in 0..<maxIterations {
			let fx: T
			let gradient: T
			
			if useNesterov {
				// Nesterov: compute gradient at the "look-ahead" position
				let lookAhead = x + (momentum * velocity)
				fx = objective(x)  // Still evaluate objective at current position for history
				gradient = numericalGradient(objective, at: lookAhead)
			} else {
				// Standard: compute gradient at current position
				fx = objective(x)
				gradient = numericalGradient(objective, at: x)
			}

			// Record history
			history.append(IterationHistory(
				iteration: iteration,
				value: x,
				objective: fx,
				gradient: gradient
			))

			// Check convergence (gradient near zero)
			if abs(gradient) < tolerance {
				converged = true
				break
			}

			// Update velocity with momentum
			velocity = (momentum * velocity) - (learningRate * gradient)

			// Gradient descent update
			var xNew = x + velocity

			// Apply bounds
//			if let bounds = bounds {
			let xConstrained = clamp(xNew, lower: bounds?.lower ?? T(-1) * T.infinity, upper: bounds?.upper ?? T.infinity)
//			}

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
				var stepScale = tolerance * 5000  // Start at 0.5 for typical tolerance
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
			let currentObjective = objective(x)
			if iteration > 0 && currentObjective > previousObjective * 10 {
				// Likely diverging - stop
				break
			}
			previousObjective = currentObjective

			// Check if step is very small
			if abs(velocity) < tolerance {
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
