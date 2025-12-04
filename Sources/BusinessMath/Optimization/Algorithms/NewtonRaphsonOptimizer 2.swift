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

		/// Optimizes a 1D objective using a safeguarded Newton–Raphson method with backtracking line search.
		///
		/// Improves robustness over a raw Newton step by:
		/// - Using central finite differences and reusing f(x) for f′′
		/// - Adapting the finite-difference step to the scale of x
		/// - Safeguarding curvature (falls back to gradient step when f″ is non-positive or too small)
		/// - Applying Armijo backtracking line search
		/// - Respecting bounds and simple value-based constraints via projection
		///
		/// - Parameters:
		///   - objective: The objective function f(x) to minimize.
		///   - constraints: Constraints the solution must satisfy. Simple value-based constraints
		///     (where `constraint.function == nil`) are projected to their boundary if violated.
		///   - initialValue: Starting point for the search.
		///   - bounds: Optional bounds (lower, upper); iterates are clamped into this interval.
		/// - Returns: An `OptimizationResult` with the best value found, its objective, iterations, convergence flag, and history.
		///
		/// - Important: Newton converges quickly near well-conditioned minima (f″ > 0). When curvature is
		///   non-positive or ill-conditioned, this method switches to a gradient step and uses a line search.
		///
		/// - Complexity: O(k · m), where k is the number of iterations and m the number of backtracking steps.
		///
		/// ## Usage Example
		/// ```swift
		/// let optimizer = NewtonRaphsonOptimizer<Double>(tolerance: 1e-8, maxIterations: 100, stepSize: 1e-4)
		/// let result = optimizer.optimize(
		///     objective: { x in (x - 5) * (x - 5) },
		///     constraints: [],
		///     initialValue: 0.0,
		///     bounds: nil
		/// )
		/// // result.optimalValue ≈ 5.0
		/// ```
		public func optimize(
			objective: @escaping (T) -> T,
			constraints: [Constraint<T>],
			initialValue: T,
			bounds: (lower: T, upper: T)?
		) -> OptimizationResult<T> {
			// Local helpers kept within function scope.
			func clamp(_ value: T, lower: T, upper: T) -> T {
				max(lower, min(upper, value))
			}

			func allConstraintsSatisfied(_ value: T, constraints: [Constraint<T>]) -> Bool {
				for c in constraints {
					if !c.isSatisfied(value) { return false }
				}
				return true
			}

			func projectToFeasibleRegion(
				_ value: T,
				constraints: [Constraint<T>],
				bounds: (lower: T, upper: T)?
			) -> T {
				var x = value
				if let b = bounds {
					x = clamp(x, lower: b.lower, upper: b.upper)
				}
				if allConstraintsSatisfied(x, constraints: constraints) {
					return x
				}
				for c in constraints where !c.isSatisfied(x) {
					if c.function == nil {
						switch c.type {
						case .greaterThan:
							x = max(x, c.bound + tolerance)
						case .greaterThanOrEqual:
							x = max(x, c.bound)
						case .lessThan:
							x = min(x, c.bound - tolerance)
						case .lessThanOrEqual:
							x = min(x, c.bound)
						case .equalTo:
							x = c.bound
						}
					}
				}
				if let b = bounds {
					x = clamp(x, lower: b.lower, upper: b.upper)
				}
				return x
			}

			func finiteDifferences(
				f: @escaping (T) -> T,
				at x: T,
				baseH: T
			) -> (fx: T, f1: T, f2: T) {
				// Adaptive central difference step based on x scale; avoids tiny literals.
				let h = max(baseH, baseH * (T(1) + abs(x)))
				let fx = f(x)
				let fph = f(x + h)
				let fmh = f(x - h)
				let f1 = (fph - fmh) / (T(2) * h)
				let f2 = (fph - T(2) * fx + fmh) / (h * h)
				return (fx, f1, f2)
			}

			// Initialize and project start to feasibility
			var x = initialValue
			if let b = bounds {
				x = clamp(x, lower: b.lower, upper: b.upper)
			}
			x = projectToFeasibleRegion(x, constraints: constraints, bounds: bounds)

			var history: [IterationHistory<T>] = []
			var converged = false

			// Line search parameters without float literals
			let c1: T = T(1) / T(10_000)         // 1e-4
			let backtrack: T = T(1) / T(2)       // 0.5
			let minLambda: T = tolerance / T(1_000)

			// Curvature safeguard tied to problem scales
			let curvatureEps = max(tolerance / T(1_000), stepSize / T(100))

			for iteration in 0..<maxIterations {
				let (fx, g, h2) = finiteDifferences(f: objective, at: x, baseH: stepSize)

				history.append(IterationHistory(iteration: iteration, value: x, objective: fx, gradient: g))

				// Converged if gradient is small
				if abs(g) <= tolerance {
					converged = true
					break
				}

				// Choose step "p" (to be subtracted): Newton if curvature is safe, else gradient
				let useNewton = h2 > curvatureEps
				let p = useNewton ? (g / h2) : g
				if abs(p) <= tolerance {
					converged = true
					break
				}

				// Backtracking Armijo line search on xNew = x - λ p
				var lambda: T = T(1)
				var accepted = false
				var xNew = x
				var fNew = fx

				// If g*p <= 0, force a descent-like step using gradient-scale
				let gp = g * p
				let effectiveP = gp > T(0) ? p : (g == T(0) ? T(0) : (g / T(10)))

				while lambda >= minLambda {
					let trial = x - lambda * effectiveP
					let projected = projectToFeasibleRegion(trial, constraints: constraints, bounds: bounds)

					if abs(projected - x) <= tolerance {
						xNew = projected
						fNew = objective(xNew)
						accepted = true
						break
					}

					let fTrial = objective(projected)
					if fTrial <= fx - c1 * lambda * g * effectiveP {
						xNew = projected
						fNew = fTrial
						accepted = true
						break
					}

					lambda *= backtrack
				}

				// If no acceptable step found, attempt a tiny feasibility/minimization move; otherwise stop
				if !accepted {
					let tiny = tolerance
					let direction: T = (g >= T(0)) ? T(1) : T(-1)
					let xTiny = projectToFeasibleRegion(x - tiny * direction, constraints: constraints, bounds: bounds)
					let fTiny = objective(xTiny)
					if fTiny < fx && abs(xTiny - x) > tolerance {
						x = xTiny
						continue
					}
					break
				}

				let movement = abs(xNew - x)
				let objChange = abs(fNew - fx)
				x = xNew

				if movement <= tolerance * (T(1) + abs(x)) { converged = true; break }
				if objChange <= tolerance * (T(1) + abs(fx)) { converged = true; break }
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
