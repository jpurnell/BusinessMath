//
//  InequalityOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Inequality Optimizer

/// Optimizer for problems with both equality and inequality constraints.
///
/// Solves optimization problems of the form:
/// ```
/// minimize f(x)
/// subject to: hᵢ(x) = 0  (equality constraints)
///            gⱼ(x) ≤ 0  (inequality constraints)
/// ```
///
/// ## Method
///
/// Uses an **augmented Lagrangian** (Powell–Hestenes–Rockafellar) with multiplier
/// estimates for *both* constraint kinds:
///
/// ```
/// L(x,λ,μ,ρ) = f(x) + Σᵢ[λᵢhᵢ(x) + (ρ/2)hᵢ(x)²]
///                   + (1/2ρ)Σⱼ[max(0, μⱼ + ρgⱼ(x))² − μⱼ²]
/// ```
///
/// with `λᵢ ← λᵢ + ρhᵢ(x)` and `μⱼ ← max(0, μⱼ + ρgⱼ(x))` between outer iterations.
/// Because the multipliers absorb the constraint forces, the penalty ρ stays
/// bounded and the inner subproblem stays well conditioned. A pure quadratic
/// penalty (μ ≡ 0) is only accurate to O(1/ρ) at an active inequality, so it must
/// drive ρ → ∞ — and long before that the inner minimisation becomes unsolvable.
///
/// The outer loop follows the LANCELOT schedule (Nocedal & Wright, *Numerical
/// Optimization* 2e, Framework 17.3 / Algorithm 17.4): a decreasing inner gradient
/// tolerance ωₖ paired with a constraint-violation tolerance ηₖ. Final accuracy is
/// asserted by the **outer** test — both the KKT stationarity residual and the
/// constraint violation must clear the configured tolerances.
///
/// ## Scaling
///
/// The problem is solved in equilibrated coordinates: the variables are divided by
/// the magnitude of the initial guess, and the objective and each constraint by
/// their own gradient magnitude there. Dividing a constraint by a positive constant
/// is a restatement, not a relaxation — it leaves the feasible set and the optimum
/// untouched — but it makes every tolerance below dimensionless, so `1e-6` means
/// "six digits" rather than "one millionth of whatever unit the caller chose".
/// Multipliers are unscaled on the way out, so a reported shadow price belongs to
/// the constraint the caller wrote.
///
/// ## Usage Example
/// ```swift
/// let optimizer = InequalityOptimizer<VectorN<Double>>()
///
/// // Portfolio optimization: minimize variance, Σw=1, w≥0
/// let result = try optimizer.minimize(
///     portfolioVariance,
///     from: VectorN([0.33, 0.33, 0.34]),
///     subjectTo: [
///         .budgetConstraint,  // Σw = 1
///     ] + .nonNegativity(dimension: 3)  // w ≥ 0
/// )
/// ```
public struct InequalityOptimizer<V: VectorSpace> where V.Scalar: Real {

	/// Convergence tolerance for constraint satisfaction.
	///
	/// Judged on the **equilibrated** constraint, so it reads as a relative
	/// tolerance: a residual small compared with the magnitude of the constraint
	/// the caller wrote, not small compared with the number 1.
	public let constraintTolerance: V.Scalar

	/// Convergence tolerance for the KKT stationarity residual.
	///
	/// This is the final target ω\* of the decreasing inner tolerance sequence, and
	/// it is checked by the outer loop against the gradient of the augmented
	/// Lagrangian — the stationarity half of the KKT conditions. Like
	/// ``constraintTolerance`` it applies in equilibrated coordinates.
	public let gradientTolerance: V.Scalar

	/// Maximum number of outer iterations
	public let maxIterations: Int

	/// Maximum number of inner iterations per outer iteration
	public let maxInnerIterations: Int

	/// Initial penalty parameter
	public let initialPenalty: V.Scalar

	/// Penalty increase factor
	public let penaltyIncrease: V.Scalar

	/// Creates an inequality optimizer with specified parameters.
	public init(
		constraintTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		gradientTolerance: V.Scalar = V.Scalar(1) / V.Scalar(1_000_000),
		maxIterations: Int = 100,
		maxInnerIterations: Int = 1000,
		initialPenalty: V.Scalar = V.Scalar(10),
		penaltyIncrease: V.Scalar = V.Scalar(10)
	) {
		self.constraintTolerance = constraintTolerance
		self.gradientTolerance = gradientTolerance
		self.maxIterations = maxIterations
		self.maxInnerIterations = maxInnerIterations
		self.initialPenalty = initialPenalty
		self.penaltyIncrease = penaltyIncrease
	}

	// MARK: - Public API

	/// Minimize an objective function subject to equality and inequality constraints.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point
	///   - constraints: Array of equality and/or inequality constraints
	/// - Returns: Optimization result with solution and Lagrange multipliers
	/// - Throws: `OptimizationError` if optimization fails
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		guard !constraints.isEmpty else {
			throw OptimizationError.invalidInput(
				message: "No constraints provided. Use unconstrained optimizer instead."
			)
		}

		// Separate constraints
		let equalityConstraints = constraints.filter { $0.isEquality }
		let inequalityConstraints = constraints.filter { $0.isInequality }

		return try optimizeWithQuadraticPenalty(
			objective: objective,
			initialGuess: initialGuess,
			equalityConstraints: equalityConstraints,
			inequalityConstraints: inequalityConstraints
		)
	}

	/// Maximize an objective function subject to constraints.
	public func maximize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {
		let result = try minimize({ -objective($0) }, from: initialGuess, subjectTo: constraints)
		return result.negated()
	}

	// MARK: - Augmented Lagrangian

	private func optimizeWithQuadraticPenalty(
		objective: @escaping @Sendable (V) -> V.Scalar,
		initialGuess: V,
		equalityConstraints: [MultivariateConstraint<V>],
		inequalityConstraints: [MultivariateConstraint<V>]
	) throws -> ConstrainedOptimizationResult<V> {

		let zero = V.Scalar(0)
		let one = V.Scalar(1)
		let two = V.Scalar(2)

		// MARK: Equilibration
		//
		// Solve in coordinates where the variables, the objective and every
		// constraint are O(1) at the starting point. Dividing an inequality
		// g(x) ≤ 0 by a positive constant leaves the feasible set exactly as it
		// was, and the same is true of an equality — this is a restatement of the
		// model, not a relaxation of it. What it buys is that the tolerances below
		// stop depending on the units the caller happened to write the model in.
		let xScale = Self.magnitudeScale(of: initialGuess)
		let fScale = Self.functionScale(objective, at: initialGuess, variableScale: xScale)
		let eqScales = equalityConstraints.map {
			Self.functionScale(Self.evaluator(for: $0), at: initialGuess, variableScale: xScale)
		}
		let ineqScales = inequalityConstraints.map {
			Self.functionScale(Self.evaluator(for: $0), at: initialGuess, variableScale: xScale)
		}

		let scaledObjective: @Sendable (V) -> V.Scalar = { point in
			objective(xScale * point) / fScale
		}
		let scaledEqualities: [@Sendable (V) -> V.Scalar] = zip(equalityConstraints, eqScales).map { pair in
			let (constraint, scale) = pair
			return { point in constraint.evaluate(at: xScale * point) / scale }
		}
		let scaledInequalities: [@Sendable (V) -> V.Scalar] = zip(inequalityConstraints, ineqScales).map { pair in
			let (constraint, scale) = pair
			return { point in constraint.evaluate(at: xScale * point) / scale }
		}

		guard let scaledStart = V.fromArray(initialGuess.toArray().map { $0 / xScale }) else {
			throw OptimizationError.invalidInput(message: "Failed to rescale the initial guess")
		}

		// MARK: LANCELOT schedule
		//
		// ωₖ is the inner gradient target, ηₖ the constraint-violation target. Both
		// start loose and tighten only as the method earns it: a fixed ωₖ of 1e-6
		// against an augmented Lagrangian whose gradient carries ρ is unreachable by
		// construction once ρ has grown, and the inner solve then burns its whole
		// iteration budget on every outer step. Clamping at the configured
		// tolerances stops the schedule chasing accuracy the caller never asked for.
		var rho = Swift.max(one, initialPenalty)
		var omega = Swift.max(gradientTolerance, one / rho)
		var eta = Swift.max(constraintTolerance, one / V.Scalar.pow(rho, one / V.Scalar(10)))

		var lambdaEq = [V.Scalar](repeating: zero, count: equalityConstraints.count)
		var muIneq = [V.Scalar](repeating: zero, count: inequalityConstraints.count)
		var scaledX = scaledStart
		var history: [(Int, V, V.Scalar, V.Scalar)] = []
		var outerIterations = 0

		for outerIter in 0..<maxIterations {
			outerIterations = outerIter + 1

			// Immutable snapshots for the Sendable closure
			let lambdaSnapshot = lambdaEq
			let muSnapshot = muIneq
			let rhoSnapshot = rho

			let augmentedLagrangian: @Sendable (V) -> V.Scalar = { point in
				var value = scaledObjective(point)

				// Equality: λᵢhᵢ(x) + (ρ/2)hᵢ(x)²
				for (i, h) in scaledEqualities.enumerated() {
					let hValue = h(point)
					value = value + lambdaSnapshot[i] * hValue + (rhoSnapshot / two) * hValue * hValue
				}

				// Inequality: (1/2ρ)[max(0, μⱼ + ρgⱼ(x))² − μⱼ²]
				//
				// With μ = 0 this is the plain (ρ/2)max(0, g)² penalty. With μ > 0 the
				// kink sits at g = −μ/ρ, strictly inside the feasible region, so an
				// active constraint is approached from the smooth side instead of
				// being pinned against a ridge the finite-difference gradient
				// straddles.
				for (j, g) in scaledInequalities.enumerated() {
					let shifted = muSnapshot[j] + rhoSnapshot * g(point)
					let active = Swift.max(zero, shifted)
					value = value + (active * active - muSnapshot[j] * muSnapshot[j]) / (two * rhoSnapshot)
				}

				return value
			}

			let innerOptimizer = MultivariateNewtonRaphson<V>(
				maxIterations: maxInnerIterations,
				tolerance: omega,
				useLineSearch: true,
				recordHistory: false
			)

			let innerResult = try innerOptimizer.minimizeBFGS(
				function: augmentedLagrangian,
				gradient: { point in try numericalGradient(augmentedLagrangian, at: point) },
				initialGuess: scaledX
			)
			scaledX = innerResult.solution

			// First-order multiplier estimates at the new iterate. These are exactly
			// what the update below banks, so computing them once here lets the
			// convergence test judge the same multipliers the method carries forward.
			let eqEstimates: [V.Scalar] = zip(lambdaEq, scaledEqualities).map { pair in
				let (lambda, h) = pair
				return lambda + rho * h(scaledX)
			}
			let ineqEstimates: [V.Scalar] = zip(muIneq, scaledInequalities).map { pair in
				let (mu, g) = pair
				let shifted: V.Scalar = mu + rho * g(scaledX)
				return Swift.max(zero, shifted)
			}

			let stationarity = try Self.kktResidual(
				at: scaledX,
				objective: scaledObjective,
				equalities: scaledEqualities,
				inequalities: scaledInequalities,
				equalityMultipliers: eqEstimates,
				inequalityMultipliers: ineqEstimates
			)

			// Violation in equilibrated units drives the schedule; the caller is told
			// the violation of the constraint they actually wrote.
			let scaledViolation = Self.maxViolation(
				equalities: scaledEqualities.map { $0(scaledX) },
				inequalities: scaledInequalities.map { $0(scaledX) }
			)

			let complementarity = Self.complementarityResidual(
				inequalityValues: scaledInequalities.map { $0(scaledX) },
				multipliers: ineqEstimates
			)

			let x = xScale * scaledX
			let objValue = objective(x)
			let violation = Self.maxViolation(
				equalities: equalityConstraints.map { $0.evaluate(at: x) },
				inequalities: inequalityConstraints.map { $0.evaluate(at: x) }
			)
			history.append((outerIter, x, objValue, violation))

			// The outer test is the whole KKT system: primal feasibility, stationarity
			// of the Lagrangian, *and* complementary slackness. All three are needed,
			// and the third is not decoration. Stationarity here is measured against
			// the first-order multiplier estimates recomputed just above, and those
			// are exactly the multipliers for which the residual equals ∇L_A — so it
			// falls to ~0 whenever the inner solve converges, whatever the iterate.
			// On its own it therefore certifies "the inner BFGS finished", not "this
			// is a KKT point", and the method would stop at the second outer iteration
			// with the penalty method's O(1/ρ) offset still in the answer. Requiring
			// complementarity keeps ρ climbing until an inactive constraint actually
			// carries no price, which is what drives that offset out.
			if scaledViolation <= constraintTolerance
				&& stationarity <= gradientTolerance
				&& complementarity <= constraintTolerance {
				return ConstrainedOptimizationResult(
					solution: x,
					objectiveValue: objValue,
					lagrangeMultipliers: Self.unscaled(lambdaEq, objectiveScale: fScale, constraintScales: eqScales),
					iterations: outerIterations,
					converged: true,
					history: history,
					constraintViolation: violation
				)
			}

			if scaledViolation <= eta {
				// Good enough on feasibility: bank it in the multipliers and ask for
				// more accuracy next time, leaving ρ where it is. This is what keeps
				// the inner subproblem conditioned.
				lambdaEq = eqEstimates
				muIneq = ineqEstimates
				eta = Swift.max(constraintTolerance, eta / V.Scalar.pow(rho, V.Scalar(9) / V.Scalar(10)))
				omega = Swift.max(gradientTolerance, omega / rho)
			} else {
				// Feasibility is not improving fast enough: lean harder on the penalty
				// and reset both targets to what the new ρ can support. The escalation
				// is capped: ρ multiplies tenfold per outer step, so a caller passing a
				// four-digit iteration budget drives it past the representable range in
				// a few hundred steps, at which point the penalty term ρh² evaluates to
				// infinity and the finite-difference gradient throws. Failing to
				// converge is a result the caller can act on; a non-finite value raised
				// several layers down is not.
				let escalated: V.Scalar = rho * penaltyIncrease
				rho = Swift.min(escalated, Self.maximumPenalty)
				eta = Swift.max(constraintTolerance, one / V.Scalar.pow(rho, one / V.Scalar(10)))
				omega = Swift.max(gradientTolerance, one / rho)
			}
		}

		// Did not converge
		let finalX = xScale * scaledX
		let finalObjValue = objective(finalX)
		let finalViolation = Self.maxViolation(
			equalities: equalityConstraints.map { $0.evaluate(at: finalX) },
			inequalities: inequalityConstraints.map { $0.evaluate(at: finalX) }
		)

		return ConstrainedOptimizationResult(
			solution: finalX,
			objectiveValue: finalObjValue,
			lagrangeMultipliers: Self.unscaled(lambdaEq, objectiveScale: fScale, constraintScales: eqScales),
			iterations: outerIterations,
			converged: false,
			history: history,
			constraintViolation: finalViolation
		)
	}

	// MARK: - Equilibration Helpers

	/// Wraps a constraint's evaluation as a plain function.
	private static func evaluator(for constraint: MultivariateConstraint<V>) -> @Sendable (V) -> V.Scalar {
		{ point in constraint.evaluate(at: point) }
	}

	/// The characteristic magnitude of a point: the largest component, or 1 when the
	/// point is the origin and offers no scale of its own.
	private static func magnitudeScale(of point: V) -> V.Scalar {
		let largest = point.toArray().reduce(V.Scalar(0)) { Swift.max($0, abs($1)) }
		guard largest.isFinite, largest > V.Scalar(0) else { return V.Scalar(1) }
		return largest
	}

	/// The characteristic magnitude of a function over the region of interest.
	///
	/// Taken from the gradient rather than the value, because it is the gradient that
	/// the inner solver's step lengths and tolerances are measured against: dividing
	/// by `‖∇f(x₀)‖∞ · xScale` leaves the scaled function with an O(1) gradient in
	/// scaled coordinates. Falls back to the function value where the gradient
	/// vanishes or cannot be taken, and to 1 where neither is usable.
	private static func functionScale(
		_ function: @escaping @Sendable (V) -> V.Scalar,
		at point: V,
		variableScale: V.Scalar
	) -> V.Scalar {
		// A step proportional to the variables themselves — an absolute 1e-6 probe
		// against components of 1e6 is differencing in the noise.
		let epsilon = variableScale / V.Scalar(1_000_000)
		if let gradient = try? numericalGradient(function, at: point, epsilon: epsilon) {
			let largest = gradient.toArray().reduce(V.Scalar(0)) { Swift.max($0, abs($1)) }
			let scale = largest * variableScale
			if scale.isFinite && scale > V.Scalar(0) { return scale }
		}
		let value = abs(function(point))
		if value.isFinite && value > V.Scalar(0) { return value }
		return V.Scalar(1)
	}

	/// The first-order KKT residual `‖∇f + Σλᵢ∇hᵢ + Σμⱼ∇gⱼ‖` at `point`.
	///
	/// The objective and each constraint are differentiated separately and combined
	/// analytically, rather than differencing the augmented Lagrangian as one
	/// composite. The composite carries a `max(0, ·)` whose kink sits at
	/// `g = −μ/ρ`, which is the constraint boundary itself whenever the multiplier
	/// is zero — a weakly active bound, where the constraint holds with equality and
	/// still costs nothing. A central difference straddling that kink reports a
	/// spurious `ρh/4` per such constraint: on `minimize x² + y², x, y ≥ 0` from a
	/// feasible start it reads 3.54e-6 at the exact solution and stays there, which
	/// no absolute tolerance of 1e-6 can ever clear. Every term differenced here is
	/// smooth at the solution, so the residual goes to zero when the KKT conditions
	/// actually hold.
	private static func kktResidual(
		at point: V,
		objective: @Sendable (V) -> V.Scalar,
		equalities: [@Sendable (V) -> V.Scalar],
		inequalities: [@Sendable (V) -> V.Scalar],
		equalityMultipliers: [V.Scalar],
		inequalityMultipliers: [V.Scalar]
	) throws -> V.Scalar {
		var residual = try numericalGradient(objective, at: point)

		for (i, h) in equalities.enumerated() {
			let gradient = try numericalGradient(h, at: point)
			residual = residual + (equalityMultipliers[i] * gradient)
		}

		// An inactive inequality carries a zero multiplier, so it drops out of the
		// sum without a special case — complementary slackness by construction.
		for (j, g) in inequalities.enumerated() {
			let gradient = try numericalGradient(g, at: point)
			residual = residual + (inequalityMultipliers[j] * gradient)
		}

		return residual.norm
	}

	/// The largest penalty weight worth applying, derived rather than chosen.
	///
	/// Past `1/ulpOfOne` the penalty term is so much larger than the objective that
	/// adding the objective to it changes nothing a `Scalar` can represent, so
	/// further escalation buys no feasibility and only degrades the conditioning of
	/// the inner subproblem. It also sits far below the point where `ρh²` would
	/// overflow, which is what makes the cap safe as well as useful.
	private static var maximumPenalty: V.Scalar {
		V.Scalar(1) / V.Scalar.ulpOfOne
	}

	/// The complementary-slackness residual `maxⱼ min(−gⱼ(x), μⱼ)`, relative to the
	/// multiplier scale.
	///
	/// At a KKT point every inequality is either active, so its slack `−g` is zero,
	/// or unpriced, so its multiplier `μ` is zero; the elementwise minimum is zero
	/// either way, and a weakly active constraint — active with a zero multiplier —
	/// satisfies it on both counts. A strictly interior constraint still carrying a
	/// positive price fails it, which is the case a stationarity test built from the
	/// same multipliers cannot see: the residual it forms is `∇L_A`, which the inner
	/// solve has already driven to zero. Both arguments are non-negative at a
	/// feasible point, so clamping the running maximum at zero costs nothing and
	/// keeps an infeasible iterate — judged separately — from reading as a negative
	/// residual here.
	///
	/// The worst element is reported relative to the largest multiplier in play,
	/// for the same reason every other tolerance in this type is applied in
	/// equilibrated coordinates: a model whose multipliers are naturally large would
	/// otherwise be held to a stricter standard than an identical model written in
	/// different units. Judged absolutely, this test is also punishing in exactly
	/// the case a reformulation is most likely to produce — an epigraph lift turns
	/// one non-smooth term into one inequality per sample, and requiring every
	/// inactive sample's price to reach an absolute floor makes the outer loop pay
	/// for constraints that were never binding.
	private static func complementarityResidual(
		inequalityValues: [V.Scalar],
		multipliers: [V.Scalar]
	) -> V.Scalar {
		let largestMultiplier = multipliers.reduce(V.Scalar(0)) { Swift.max($0, abs($1)) }
		let multiplierScale = Swift.max(V.Scalar(1), largestMultiplier)

		let worstElement = zip(inequalityValues, multipliers).reduce(V.Scalar(0)) { worst, pair in
			let (constraintValue, multiplier) = pair
			let slack = -constraintValue
			return Swift.max(worst, Swift.min(slack, multiplier))
		}

		return worstElement / multiplierScale
	}

	/// The largest constraint violation: `|h|` for equalities, `max(0, g)` for inequalities.
	private static func maxViolation(equalities: [V.Scalar], inequalities: [V.Scalar]) -> V.Scalar {
		let equalityWorst = equalities.reduce(V.Scalar(0)) { Swift.max($0, abs($1)) }
		let inequalityWorst = inequalities.reduce(V.Scalar(0)) { Swift.max($0, $1) }
		return Swift.max(equalityWorst, inequalityWorst)
	}

	/// Returns multipliers in the caller's units.
	///
	/// The solve happens on `f/fScale` and `h/hScale`, so a multiplier found there is
	/// `hScale/fScale` times the one belonging to the constraint as written. A shadow
	/// price that silently carries the solver's convenience scaling is worse than a
	/// failure, because nothing about the number looks unusual.
	private static func unscaled(
		_ multipliers: [V.Scalar],
		objectiveScale: V.Scalar,
		constraintScales: [V.Scalar]
	) -> [V.Scalar] {
		zip(multipliers, constraintScales).map { $0 * objectiveScale / $1 }
	}
}

// MARK: - MultivariateOptimizer Protocol Conformance

extension InequalityOptimizer: MultivariateOptimizer {
	/// Minimize an objective function subject to constraints (protocol method).
	///
	/// This method implements the ``MultivariateOptimizer`` protocol by delegating to the
	/// specialized ``minimize(_:from:subjectTo:)`` method and converting the result type.
	///
	/// - Parameters:
	///   - objective: Function to minimize f: V → ℝ
	///   - initialGuess: Starting point for optimization
	///   - constraints: Array of constraints. Accepts both equality and inequality constraints.
	/// - Returns: Optimization result (base protocol type)
	/// - Throws: ``OptimizationError`` if no constraints provided or optimization fails
	///
	/// - Note: For access to Lagrange multipliers, use the specialized
	///   ``minimize(_:from:subjectTo:)`` method which returns ``ConstrainedOptimizationResult``.
	public func minimize(
		_ objective: @escaping @Sendable (V) -> V.Scalar,
		from initialGuess: V,
		constraints: [MultivariateConstraint<V>] = []
	) throws -> MultivariateOptimizationResult<V> {
		// InequalityOptimizer accepts both equality and inequality constraints
		// No constraint type validation needed

		// Delegate to specialized method
		let result = try minimize(objective, from: initialGuess, subjectTo: constraints)

		// Convert to protocol result type (discards Lagrange multipliers)
		return MultivariateOptimizationResult(
			solution: result.solution,
			value: result.objectiveValue,
			iterations: result.iterations,
			converged: result.converged,
			gradientNorm: V.Scalar(0),  // Not tracked for inequality optimizers
			history: nil  // History format incompatible (constraint violation vs gradient norm)
		)
	}
}
