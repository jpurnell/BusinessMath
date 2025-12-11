//
//  Constraint.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Constraint Type

/// Represents a constraint on an optimization problem.
///
/// Constraints restrict the feasible region of an optimization problem.
/// They come in two forms:
/// - **Equality constraints**: h(x) = 0
/// - **Inequality constraints**: g(x) ≤ 0
///
/// ## Mathematical Background
///
/// In constrained optimization, we solve:
/// ```
/// minimize f(x)
/// subject to: hᵢ(x) = 0  (equality constraints)
///            gⱼ(x) ≤ 0  (inequality constraints)
/// ```
///
/// ## Usage Examples
///
/// ### Equality Constraint
/// ```swift
/// // Budget constraint: weights must sum to 1
/// let budget: MultivariateConstraint<VectorN<Double>> = .equality { weights in
///     weights.sum() - 1.0
/// }
/// ```
///
/// ### Inequality Constraint
/// ```swift
/// // No short-selling: first weight must be non-negative
/// let noShortSell: MultivariateConstraint<VectorN<Double>> = .inequality { weights in
///     -weights[0]  // -w[0] ≤ 0  →  w[0] ≥ 0
/// }
/// ```
///
/// ### With Explicit Gradient
/// ```swift
/// // Budget constraint with analytical gradient
/// let budget: MultivariateConstraint<VectorN<Double>> = .equality(
///     function: { weights in weights.sum() - 1.0 },
///     gradient: { weights in VectorN<Double>(repeating: 1.0, count: weights.dimension) }
/// )
/// ```
///
/// ## Performance Notes
///
/// - If you don't provide a gradient, it will be computed numerically using finite differences
/// - Providing analytical gradients improves performance and accuracy
/// - Numerical gradients are computed lazily when needed
public enum MultivariateConstraint<V: VectorSpace>: @unchecked Sendable where V.Scalar: Real {
	/// Equality constraint: h(x) = 0
	///
	/// The constraint is satisfied when h(x) returns exactly 0.
	///
	/// - Parameters:
	///   - function: Constraint function h: V → ℝ where h(x) = 0 at feasible points
	///   - gradient: Optional gradient ∇h: V → V. If nil, computed numerically.
	case equality(
		function: (V) -> V.Scalar,
		gradient: ((V) -> V)?
	)

	/// Inequality constraint: g(x) ≤ 0
	///
	/// The constraint is satisfied when g(x) returns a negative or zero value.
	///
	/// - Parameters:
	///   - function: Constraint function g: V → ℝ where g(x) ≤ 0 at feasible points
	///   - gradient: Optional gradient ∇g: V → V. If nil, computed numerically.
	case inequality(
		function: (V) -> V.Scalar,
		gradient: ((V) -> V)?
	)

	// MARK: - Convenience Initializers

	/// Create an equality constraint with only a function (gradient computed numerically)
	public static func equality(_ function: @escaping (V) -> V.Scalar) -> MultivariateConstraint<V> where V.Scalar: Real {
		.equality(function: function, gradient: nil)
	}

	/// Create an inequality constraint with only a function (gradient computed numerically)
	public static func inequality(_ function: @escaping (V) -> V.Scalar) -> MultivariateConstraint<V> where V.Scalar: Real {
		.inequality(function: function, gradient: nil)
	}

	// MARK: - Accessors

	/// The constraint function h(x) or g(x)
	public var function: (V) -> V.Scalar {
		switch self {
		case .equality(let f, _): return f
		case .inequality(let f, _): return f
		}
	}

	/// The constraint gradient ∇h(x) or ∇g(x), if provided
	public var explicitGradient: ((V) -> V)? {
		switch self {
		case .equality(_, let g): return g
		case .inequality(_, let g): return g
		}
	}

	/// Get the gradient at a point, computing numerically if needed
	///
	/// - Parameter point: Point at which to evaluate gradient
	/// - Returns: Gradient vector ∇h(x) or ∇g(x)
	/// - Throws: `OptimizationError` if numerical gradient computation fails
	public func gradient(at point: V) throws -> V {
		if let explicitGrad = explicitGradient {
			return explicitGrad(point)
		} else {
			// Compute numerical gradient
			return try numericalGradient(function, at: point)
		}
	}

	/// Evaluate the constraint at a point
	///
	/// - Parameter point: Point at which to evaluate constraint
	/// - Returns: h(x) for equality or g(x) for inequality
	public func evaluate(at point: V) -> V.Scalar {
		function(point)
	}

	/// Check if the constraint is satisfied at a point
	///
	/// - Parameters:
	///   - point: Point to check
	///   - tolerance: Numerical tolerance for equality constraints
	/// - Returns: True if constraint is satisfied
	public func isSatisfied(at point: V, tolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000)) -> Bool {
		let value = evaluate(at: point)

		switch self {
		case .equality:
			// Equality: |h(x)| ≤ tolerance
			return abs(value) <= tolerance
		case .inequality:
			// Inequality: g(x) ≤ tolerance
			return value <= tolerance
		}
	}

	/// Check if the constraint is an equality constraint
	public var isEquality: Bool {
		if case .equality = self { return true }
		return false
	}

	/// Check if the constraint is an inequality constraint
	public var isInequality: Bool {
		if case .inequality = self { return true }
		return false
	}
}

// MARK: - Common Constraints for Portfolio Optimization

public extension MultivariateConstraint where V == VectorN<Double> {

	/// Budget constraint: weights must sum to 1
	///
	/// Enforces Σwᵢ = 1, the standard portfolio budget constraint.
	///
	/// ## Example
	/// ```swift
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ]
	/// let result = optimizer.minimize(objective, from: initial, subjectTo: constraints)
	/// ```
	static var budgetConstraint: MultivariateConstraint<VectorN<Double>> {
		.equality(
			function: { weights in weights.sum - 1.0 },
			gradient: { weights in VectorN<Double>(repeating: 1.0, count: weights.dimension) }
		)
	}

	/// Non-negativity constraints: all weights must be non-negative (long-only)
	///
	/// Enforces wᵢ ≥ 0 for all i, preventing short-selling.
	///
	/// ## Example
	/// ```swift
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ] + .nonNegativity(dimension: 5)
	/// ```
	///
	/// - Parameter dimension: Number of assets (vector dimension)
	/// - Returns: Array of inequality constraints, one per component
	static func nonNegativity(dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		(0..<dimension).map { i in
			.inequality(
				function: { weights in -weights[i] },  // -wᵢ ≤ 0  →  wᵢ ≥ 0
				gradient: { weights in
					// Gradient is -eᵢ (basis vector)
					var grad = [Double](repeating: Double(0), count: weights.dimension)
					grad[i] = Double(-1)
					return VectorN<Double>(grad)
				}
			)
		}
	}

	/// Position limit constraints: each weight must not exceed a maximum
	///
	/// Enforces wᵢ ≤ maxWeight for all i, limiting concentration risk.
	///
	/// ## Example
	/// ```swift
	/// // No single position can exceed 40% of portfolio
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ] + .positionLimit(0.4, dimension: 5)
	/// ```
	///
	/// - Parameters:
	///   - maxWeight: Maximum weight for any single asset
	///   - dimension: Number of assets (vector dimension)
	/// - Returns: Array of inequality constraints, one per component
	static func positionLimit(_ maxWeight: Double, dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		(0..<dimension).map { i in
			.inequality(
				function: { weights in weights[i] - maxWeight },  // wᵢ ≤ max
				gradient: { weights in
					// Gradient is eᵢ (basis vector)
					var grad = [Double](repeating: Double(0), count: weights.dimension)
					grad[i] = Double(1)
					return VectorN<Double>(grad)
				}
			)
		}
	}

	/// Position minimum constraints: each weight must be at least a minimum
	///
	/// Enforces wᵢ ≥ minWeight for all i, requiring minimum allocation.
	///
	/// ## Example
	/// ```swift
	/// // Each position must be at least 10% of portfolio
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ] + .positionMinimum(0.1, dimension: 5)
	/// ```
	///
	/// - Parameters:
	///   - minWeight: Minimum weight for any single asset
	///   - dimension: Number of assets (vector dimension)
	/// - Returns: Array of inequality constraints, one per component
	static func positionMinimum(_ minWeight: Double, dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		(0..<dimension).map { i in
			.inequality(
				function: { weights in minWeight - weights[i] },  // wᵢ ≥ min  →  min - wᵢ ≤ 0
				gradient: { weights in
					// Gradient is -eᵢ (basis vector)
					var grad = [Double](repeating: Double(0), count: weights.dimension)
					grad[i] = Double(-1)
					return VectorN<Double>(grad)
				}
			)
		}
	}

	/// Box constraints: each weight must be within [min, max]
	///
	/// Combines position minimum and maximum constraints.
	///
	/// ## Example
	/// ```swift
	/// // Each position must be between 10% and 40%
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ] + .boxConstraints(min: 0.1, max: 0.4, dimension: 5)
	/// ```
	///
	/// - Parameters:
	///   - min: Minimum weight for any single asset
	///   - max: Maximum weight for any single asset
	///   - dimension: Number of assets (vector dimension)
	/// - Returns: Array of inequality constraints (2 per component)
	static func boxConstraints(min: Double, max: Double, dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		positionMinimum(min, dimension: dimension) + positionLimit(max, dimension: dimension)
	}

	/// Target return constraint: portfolio return must equal target
	///
	/// Enforces μᵀw = targetReturn, where μ is expected returns vector.
	///
	/// ## Example
	/// ```swift
	/// // Portfolio must have expected return of 10%
	/// let expectedReturns = VectorN<Double>([0.08, 0.10, 0.12])
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint,
	///     .targetReturn(expectedReturns, target: 0.10)
	/// ]
	/// ```
	///
	/// - Parameters:
	///   - expectedReturns: Expected return for each asset
	///   - target: Target portfolio return
	/// - Returns: Equality constraint
	static func targetReturn(_ expectedReturns: VectorN<Double>, target: Double) -> MultivariateConstraint<VectorN<Double>> {
		.equality(
			function: { weights in
				expectedReturns.dot(weights) - target
			},
			gradient: { _ in expectedReturns }
		)
	}

	/// Leverage constraint: sum of absolute weights must not exceed limit
	///
	/// Enforces Σ|wᵢ| ≤ maxLeverage. Note: This is non-smooth and may cause issues
	/// with gradient-based methods. Consider using long/short position limits instead.
	///
	/// ## Example
	/// ```swift
	/// // Total leverage (long + short) cannot exceed 150%
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint,
	///     .leverageLimit(1.5, dimension: 5)
	/// ]
	/// ```
	///
	/// - Parameters:
	///   - maxLeverage: Maximum total leverage
	///   - dimension: Number of assets (vector dimension)
	/// - Returns: Inequality constraint
	///
	/// - Warning: This constraint uses absolute values which are non-differentiable at zero.
	///   Numerical gradient computation may be unstable near zero weights.
	static func leverageLimit(_ maxLeverage: Double, dimension: Int) -> MultivariateConstraint<VectorN<Double>> {
		.inequality(
			function: { weights in
				// Σ|wᵢ| - maxLeverage ≤ 0
				let totalLeverage = weights.toArray().reduce(Double(0)) { $0 + abs($1) }
				return totalLeverage - maxLeverage
			},
			gradient: nil  // Use numerical gradient (abs is non-smooth)
		)
	}
}

// MARK: - Constraint Validation Utilities

public extension Array where Element == MultivariateConstraint<VectorN<Double>> {

	/// Check if all constraints are satisfied at a point
	///
	/// - Parameters:
	///   - point: Point to check
	///   - tolerance: Numerical tolerance
	/// - Returns: True if all constraints are satisfied
	func allSatisfied(at point: VectorN<Double>, tolerance: Double = 1e-6) -> Bool {
		allSatisfy { $0.isSatisfied(at: point, tolerance: tolerance) }
	}

	/// Get the constraint violations at a point
	///
	/// - Parameter point: Point to check
	/// - Returns: Array of violation values (0 if satisfied, positive if violated)
	func violations(at point: VectorN<Double>) -> [Double] {
		map { constraint in
			let value = constraint.evaluate(at: point)
			switch constraint {
			case .equality:
				return abs(value)  // |h(x)|
			case .inequality:
				return Swift.max(0, value)  // max(0, g(x))
			}
		}
	}

	/// Get the maximum constraint violation at a point
	///
	/// - Parameter point: Point to check
	/// - Returns: Maximum violation (0 if all satisfied)
	func maxViolation(at point: VectorN<Double>) -> Double {
		violations(at: point).max() ?? 0.0
	}
}
