//
//  Constraint.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Constraint Sense

/// Specifies the sense (direction) of a linear constraint
///
/// Used with explicit linear constraints to write constraints in natural mathematical form:
/// - `.lessOrEqual`: c·x ≤ b
/// - `.greaterOrEqual`: c·x ≥ b
/// - `.equal`: c·x = b
public enum ConstraintSense: Sendable {
	case lessOrEqual    // c·x ≤ b
	case greaterOrEqual // c·x ≥ b
	case equal          // c·x = b
}

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
public enum MultivariateConstraint<V: VectorSpace>: Sendable where V.Scalar: Real, V: Sendable {
	/// Equality constraint: h(x) = 0
	///
	/// The constraint is satisfied when h(x) returns exactly 0.
	///
	/// - Parameters:
	///   - function: Constraint function h: V → ℝ where h(x) = 0 at feasible points
	///   - gradient: Optional gradient ∇h: V → V. If nil, computed numerically.
	case equality(
		function: @Sendable (V) -> V.Scalar,
		gradient: (@Sendable (V) -> V)?
	)

	/// Inequality constraint: g(x) ≤ 0
	///
	/// The constraint is satisfied when g(x) returns a negative or zero value.
	///
	///  - Parameters:
	///   - function: Constraint function g: V → ℝ where g(x) ≤ 0 at feasible points
	///   - gradient: Optional gradient ∇g: V → V. If nil, computed numerically.
	case inequality(
		function: @Sendable (V) -> V.Scalar,
		gradient: (@Sendable (V) -> V)?
	)

	/// Explicit linear inequality constraint: c·x {≤, ≥, =} rhs
	///
	/// Represents a linear constraint in natural mathematical form.
	/// The constraint is automatically converted to canonical form g(x) ≤ 0 when needed.
	///
	/// ## Example
	/// ```swift
	/// // x ≥ 0 (natural form - no inversion!)
	/// .linearInequality(coefficients: [1.0], rhs: 0.0, sense: .greaterOrEqual)
	///
	/// // x + y ≤ 10 (budget constraint)
	/// .linearInequality(coefficients: [1.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
	/// ```
	///
	/// - Parameters:
	///   - coefficients: Linear coefficients [c₁, c₂, ..., cₙ]
	///   - rhs: Right-hand side value b
	///   - sense: Constraint direction (.lessOrEqual, .greaterOrEqual, or .equal)
	case linearInequality(
		coefficients: [V.Scalar],
		rhs: V.Scalar,
		sense: ConstraintSense
	)

	/// Explicit linear equality constraint: c·x = rhs
	///
	/// Represents a linear equality constraint.
	///
	/// ## Example
	/// ```swift
	/// // x = 5 (fixed variable)
	/// .linearEquality(coefficients: [1.0], rhs: 5.0)
	///
	/// // x - y = 0 (balance constraint)
	/// .linearEquality(coefficients: [1.0, -1.0], rhs: 0.0)
	/// ```
	///
	/// - Parameters:
	///   - coefficients: Linear coefficients [c₁, c₂, ..., cₙ]
	///   - rhs: Right-hand side value b
	case linearEquality(
		coefficients: [V.Scalar],
		rhs: V.Scalar
	)

	// MARK: - Convenience Initializers

	/// Create an equality constraint with only a function (gradient computed numerically)
	public static func equality(_ function: @escaping @Sendable (V) -> V.Scalar) -> MultivariateConstraint<V> where V.Scalar: Real {
		.equality(function: function, gradient: nil)
	}

	/// Create an inequality constraint with only a function (gradient computed numerically)
	public static func inequality(_ function: @escaping @Sendable (V) -> V.Scalar) -> MultivariateConstraint<V> where V.Scalar: Real {
		.inequality(function: function, gradient: nil)
	}

	// MARK: - Accessors

	/// The constraint function h(x) or g(x)
	public var function: @Sendable (V) -> V.Scalar {
		switch self {
		case .equality(let f, _):
			return f
		case .inequality(let f, _):
			return f
		case .linearInequality(let coeffs, let rhs, let sense):
			// Convert to function: c·x - rhs (with appropriate sign)
			return { point in
				let components = point.toArray()
				let dotProduct = zip(coeffs, components).reduce(V.Scalar.zero) { acc, pair in
					acc + pair.0 * pair.1
				}
				switch sense {
				case .lessOrEqual:
					return dotProduct - rhs  // c·x - b ≤ 0
				case .greaterOrEqual:
					return rhs - dotProduct  // -c·x + b ≤ 0
				case .equal:
					return dotProduct - rhs  // c·x - b = 0
				}
			}
		case .linearEquality(let coeffs, let rhs):
			// Convert to function: c·x - rhs = 0
			return { point in
				let components = point.toArray()
				let dotProduct = zip(coeffs, components).reduce(V.Scalar.zero) { acc, pair in
					acc + pair.0 * pair.1
				}
				return dotProduct - rhs
			}
		}
	}

	/// The constraint gradient ∇h(x) or ∇g(x), if provided
	public var explicitGradient: (@Sendable (V) -> V)? {
		switch self {
		case .equality(_, let g):
			return g
		case .inequality(_, let g):
			return g
		case .linearInequality(let coeffs, _, let sense):
			// Gradient is constant for linear constraints
			return { _ in
				let gradCoeffs: [V.Scalar]
				switch sense {
				case .lessOrEqual, .equal:
					gradCoeffs = coeffs  // ∇(c·x) = c
				case .greaterOrEqual:
					gradCoeffs = coeffs.map { -$0 }  // ∇(-c·x) = -c
				}
				return V.fromArray(gradCoeffs)!
			}
		case .linearEquality(let coeffs, _):
			// Gradient is constant: ∇(c·x) = c
			return { _ in V.fromArray(coeffs)! }
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
		case .equality, .linearEquality:
			// Equality: |h(x)| ≤ tolerance
			return abs(value) <= tolerance
		case .inequality:
			// Inequality: g(x) ≤ tolerance
			return value <= tolerance
		case .linearInequality(_, _, let sense):
			// Linear inequality in canonical form
			switch sense {
			case .lessOrEqual, .greaterOrEqual:
				return value <= tolerance
			case .equal:
				return abs(value) <= tolerance
			}
		}
	}

	/// Check if the constraint is an equality constraint
	public var isEquality: Bool {
		switch self {
		case .equality, .linearEquality:
			return true
		case .linearInequality(_, _, let sense):
			return sense == .equal
		case .inequality:
			return false
		}
	}

	/// Check if the constraint is an inequality constraint
	public var isInequality: Bool {
		switch self {
		case .inequality:
			return true
		case .linearInequality(_, _, let sense):
			return sense != .equal
		case .equality, .linearEquality:
			return false
		}
	}

	/// Convert linear constraint to canonical form g(x) ≤ 0
	///
	/// This method converts natural-form linear constraints to the canonical form
	/// used by solvers: g(x) ≤ 0 for inequalities or h(x) = 0 for equalities.
	///
	/// ## Conversion Rules
	/// - `c·x ≤ b` → `c·x - b ≤ 0` (coefficients unchanged, constant = -b)
	/// - `c·x ≥ b` → `-c·x + b ≤ 0` (coefficients negated, constant = b)
	/// - `c·x = b` → `c·x - b = 0` (coefficients unchanged, constant = -b)
	///
	/// ## Example
	/// ```swift
	/// // x ≥ 0 (natural form)
	/// let constraint = MultivariateConstraint<VectorN<Double>>.linearInequality(
	///     coefficients: [1.0], rhs: 0.0, sense: .greaterOrEqual
	/// )
	/// let canonical = constraint.toCanonicalForm()
	/// // Result: coefficients = [-1.0], constant = 0.0 (represents -x ≤ 0)
	/// ```
	///
	/// - Returns: Tuple of (coefficients, constant, isEquality) in canonical form
	/// - Throws: If constraint is not a linear constraint
	public func toCanonicalForm() -> (coefficients: [V.Scalar], constant: V.Scalar, isEquality: Bool) {
		switch self {
		case .linearInequality(let coeffs, let rhs, let sense):
			switch sense {
			case .lessOrEqual:
				// c·x ≤ b  →  c·x - b ≤ 0
				return (coefficients: coeffs, constant: -rhs, isEquality: false)
			case .greaterOrEqual:
				// c·x ≥ b  →  -c·x + b ≤ 0
				let negatedCoeffs = coeffs.map { -$0 }
				return (coefficients: negatedCoeffs, constant: rhs, isEquality: false)
			case .equal:
				// c·x = b  →  c·x - b = 0
				return (coefficients: coeffs, constant: -rhs, isEquality: true)
			}
		case .linearEquality(let coeffs, let rhs):
			// c·x = b  →  c·x - b = 0
			return (coefficients: coeffs, constant: -rhs, isEquality: true)
		case .equality, .inequality:
			fatalError("toCanonicalForm() is only supported for linear constraints. Use validateLinearModel() first to extract coefficients from closures.")
		}
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

	/// Non-negativity constraints using explicit linear form: xᵢ ≥ 0
	///
	/// Enforces wᵢ ≥ 0 for all i, preventing short-selling.
	/// Uses natural-form linear constraints (not inverted!).
	///
	/// ## Example
	/// ```swift
	/// let constraints: [MultivariateConstraint<VectorN<Double>>] = [
	///     .budgetConstraint
	/// ] + .nonNegativity(dimension: 5)
	/// ```
	///
	/// - Parameter dimension: Number of assets (vector dimension)
	/// - Returns: Array of linear inequality constraints, one per component
	static func nonNegativity(dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		(0..<dimension).map { i in
			var coeffs = [Double](repeating: 0.0, count: dimension)
			coeffs[i] = 1.0  // xᵢ (not -xᵢ!)
			return .linearInequality(
				coefficients: coeffs,
				rhs: 0.0,
				sense: .greaterOrEqual  // xᵢ ≥ 0 (natural form!)
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

	// MARK: - Linear Constraint Factory Methods

	/// Budget constraint using explicit linear form: Σxᵢ ≤ total
	///
	/// Creates a single linear inequality constraint in natural form.
	///
	/// ## Example
	/// ```swift
	/// // x + y + z ≤ 100 (total budget)
	/// let constraint = MultivariateConstraint<VectorN<Double>>.budget(
	///     total: 100.0,
	///     dimension: 3
	/// )
	/// ```
	///
	/// - Parameters:
	///   - total: Total budget (right-hand side)
	///   - dimension: Number of variables
	/// - Returns: Single linear inequality constraint
	static func budget(total: Double, dimension: Int) -> MultivariateConstraint<VectorN<Double>> {
		.linearInequality(
			coefficients: Array(repeating: 1.0, count: dimension),
			rhs: total,
			sense: .lessOrEqual
		)
	}

	/// Box constraints using explicit linear form: lower ≤ xᵢ ≤ upper
	///
	/// Creates array of linear inequality constraints for variable bounds.
	///
	/// ## Example
	/// ```swift
	/// // -5 ≤ x ≤ 10, -5 ≤ y ≤ 10
	/// let constraints = MultivariateConstraint<VectorN<Double>>.box(
	///     lower: -5.0,
	///     upper: 10.0,
	///     dimension: 2
	/// )
	/// ```
	///
	/// - Parameters:
	///   - lower: Lower bound for all variables
	///   - upper: Upper bound for all variables
	///   - dimension: Number of variables
	/// - Returns: Array of 2×dimension linear inequality constraints
	static func box(lower: Double, upper: Double, dimension: Int) -> [MultivariateConstraint<VectorN<Double>>] {
		var constraints: [MultivariateConstraint<VectorN<Double>>] = []

		for i in 0..<dimension {
			var coeffs = [Double](repeating: 0.0, count: dimension)
			coeffs[i] = 1.0

			// Lower bound: xᵢ ≥ lower
			constraints.append(.linearInequality(
				coefficients: coeffs,
				rhs: lower,
				sense: .greaterOrEqual
			))

			// Upper bound: xᵢ ≤ upper
			constraints.append(.linearInequality(
				coefficients: coeffs,
				rhs: upper,
				sense: .lessOrEqual
			))
		}

		return constraints
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
			case .equality, .linearEquality:
				return abs(value)  // |h(x)|
			case .inequality:
				return Swift.max(0, value)  // max(0, g(x))
			case .linearInequality(_, _, let sense):
				switch sense {
				case .lessOrEqual, .greaterOrEqual:
					return Swift.max(0, value)  // max(0, g(x))
				case .equal:
					return abs(value)  // |h(x)|
				}
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
