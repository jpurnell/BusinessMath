//
//  PenaltyConstrainedSolve.swift
//  BusinessMath
//
//  One constrained solve, shared by the five heuristics that each carried a copy of it.
//

import Foundation
import Numerics

// MARK: - Measuring infeasibility

/// How far a point sits outside a single constraint, in that constraint's own units.
///
/// `|h(x)|` for an equality and `max(0, g(x))` for an inequality, both zero at a feasible point.
///
/// - Parameters:
///   - constraint: The constraint to measure against.
///   - point: The point to measure.
/// - Returns: A non-negative amount; zero when the constraint holds.
internal func constraintViolation<V: VectorSpace>(
	of constraint: MultivariateConstraint<V>,
	at point: V
) -> V.Scalar where V.Scalar: Real {
	let value = constraint.evaluate(at: point)
	if constraint.isEquality {
		return value < V.Scalar.zero ? -value : value
	}
	return V.Scalar.maximum(V.Scalar.zero, value)
}

/// The largest violation over a set of constraints, which is what decides feasibility.
///
/// The maximum rather than the sum, because a point is feasible only when **every** constraint
/// holds. A sum lets a large miss on one constraint hide behind exact satisfaction of nine
/// others, and a sum in mixed units is not a quantity at all.
///
/// - Parameters:
///   - constraints: The constraints to measure against. Empty means feasible.
///   - point: The point to measure.
/// - Returns: Zero when every constraint holds, otherwise the worst miss.
internal func worstConstraintViolation<V: VectorSpace>(
	of constraints: [MultivariateConstraint<V>],
	at point: V
) -> V.Scalar where V.Scalar: Real {
	var worst = V.Scalar.zero
	for constraint in constraints {
		let amount = constraintViolation(of: constraint, at: point)
		if amount > worst { worst = amount }
	}
	return worst
}

// MARK: - Exact linear form

/// The exact `a` and `b` of a constraint that already knows them, as `a·x ≤ b` or `a·x = b`.
///
/// ``MultivariateConstraint`` stores the coefficients and right-hand side of its linear cases
/// verbatim. Recovering them by differentiating the closure that
/// ``MultivariateConstraint/function`` synthesises from those very numbers costs about 1e-10 of
/// accuracy and makes the answer depend on the point it was taken at — which is how
/// branch-and-bound came to prune feasible subtrees. Read them instead.
///
/// Signs follow ``MultivariateConstraint/function``: a `.greaterOrEqual` constraint `c·x ≥ r` is
/// the function `r − c·x`, so it is returned as `(−c, −r)`.
///
/// - Parameters:
///   - constraint: The constraint to read.
///   - dimension: The problem's dimension. Shorter coefficient vectors are padded with zeros and
///     longer ones truncated, matching what the synthesised closure does when it `zip`s against
///     the point.
/// - Returns: The exact form, or `nil` for `.equality` and `.inequality`, which carry only a
///   closure and have no linear form to read.
internal func exactLinearForm<V: VectorSpace>(
	of constraint: MultivariateConstraint<V>,
	dimension: Int
) -> (coefficients: [V.Scalar], rhs: V.Scalar)? where V.Scalar: Real {
	func sized(_ values: [V.Scalar], negated: Bool) -> [V.Scalar] {
		var result = [V.Scalar](repeating: V.Scalar.zero, count: dimension)
		for index in 0..<Swift.min(dimension, values.count) {
			result[index] = negated ? -values[index] : values[index]
		}
		return result
	}

	switch constraint {
	case .linearInequality(let coefficients, let rhs, let sense):
		switch sense {
		case .lessOrEqual, .equal:
			return (sized(coefficients, negated: false), rhs)
		case .greaterOrEqual:
			return (sized(coefficients, negated: true), -rhs)
		}
	case .linearEquality(let coefficients, let rhs):
		return (sized(coefficients, negated: false), rhs)
	case .equality, .inequality:
		return nil
	}
}

// MARK: - Feasibility restoration

/// Move a point onto the feasible set.
///
/// ## Why this exists alongside the augmented Lagrangian
///
/// The multipliers get the search to the boundary at a moderate weight, but a *search* only
/// resolves to its own tolerance. The population methods here are stochastic global searches
/// with no polishing step, and they finish near a surface rather than on it — measured on
/// `Σx = 6`, differential evolution reached 6.000041 and particle swarm 6.00075. Those are
/// perfectly good search outcomes and perfectly bad answers to "allocate exactly 6".
///
/// Landing on the constraint is a *correction*, not a search. Each step here moves the point
/// along the constraint's own normal by exactly the amount that zeroes it:
/// `x ← x − (g(x) / ‖∇g‖²) · ∇g`. For a linear constraint that is the closed-form nearest point
/// and lands in one step; for a smooth non-linear one it is Newton's method on `g(x) = 0` and
/// converges quadratically.
///
/// Cycling over the constraints repeatedly is projection onto convex sets: each step is exact
/// for its own constraint and may disturb another, and for convex sets the sequence converges to
/// the intersection. One pass suffices for a single constraint, which is the common case.
///
/// ## Where the normal comes from
///
/// In order of preference: the exact coefficients when the constraint carries them, then a
/// caller-supplied gradient, then central differences.
///
/// The last of those deserves a note, given that misplaced finite differences are what made
/// branch-and-bound prune feasible subtrees. The difference is who owns the information. There,
/// the caller had written `.linearInequality(coefficients: [3, 7], rhs: 21)` and the solver
/// reconstructed `[3, 7]` by differentiating a closure built out of `[3, 7]` — throwing away
/// what it had been given. Here the caller wrote `.equality { v in v[0] + v[1] - 1 }`, and a
/// closure is genuinely all there is. Differentiating it is the only option, and it is the right
/// one.
///
/// ## What it deliberately does not do
///
/// Restore optimality. This moves the point to the nearest feasible one, which is generally not
/// the constrained optimum — it trades some objective for feasibility. That is the correct
/// trade: feasibility is a requirement and optimality is a quality, and a threshold that is
/// *nearly* met is not met.
///
/// - Parameters:
///   - point: The infeasible point to move.
///   - constraints: The constraints to satisfy.
///   - tolerance: How close counts as on the set.
///   - rounds: How many times to cycle the constraints.
/// - Returns: The corrected point, or `nil` when the vector could not be rebuilt from its own
///   components.
/// - Complexity: O(rounds × constraints × dimension), with one extra constraint evaluation per
///   dimension for each constraint that has to be differentiated.
internal func restoreFeasibility<V: VectorSpace>(
	_ point: V,
	constraints: [MultivariateConstraint<V>],
	tolerance: V.Scalar,
	rounds: Int = 64
) -> V? where V.Scalar: Real {
	let dimension = point.toArray().count
	guard dimension > 0 else { return nil }

	// The exact normal, for the constraints that carry one. Read once rather than per round.
	var exactForms: [Int: (coefficients: [V.Scalar], rhs: V.Scalar)] = [:]
	for (index, constraint) in constraints.enumerated() {
		if let form = exactLinearForm(of: constraint, dimension: dimension) {
			exactForms[index] = form
		}
	}

	guard var current = V.fromArray(point.toArray()) else { return nil }

	/// The constraint's normal at a point: exact, caller-supplied, or differenced.
	func normal(_ index: Int, _ constraint: MultivariateConstraint<V>, at x: V) -> [V.Scalar] {
		if let form = exactForms[index] { return form.coefficients }
		if let gradient = constraint.explicitGradient { return gradient(x).toArray() }

		let step = V.Scalar.ulpOfOne.squareRoot()
		var derivative = [V.Scalar](repeating: V.Scalar.zero, count: dimension)
		let components = x.toArray()
		for axis in 0..<dimension {
			var forward = components
			var backward = components
			forward[axis] += step
			backward[axis] -= step
			guard let ahead = V.fromArray(forward), let behind = V.fromArray(backward) else { continue }
			let rise: V.Scalar = constraint.evaluate(at: ahead) - constraint.evaluate(at: behind)
			derivative[axis] = rise / (V.Scalar(2) * step)
		}
		return derivative
	}

	for _ in 0..<rounds {
		var worst = V.Scalar.zero

		for (index, constraint) in constraints.enumerated() {
			let residual = constraint.evaluate(at: current)
			let miss = constraint.isEquality
				? (residual < V.Scalar.zero ? -residual : residual)
				: V.Scalar.maximum(V.Scalar.zero, residual)
			if miss > worst { worst = miss }
			guard miss > tolerance else { continue }

			let direction = normal(index, constraint, at: current)
			var normSquared = V.Scalar.zero
			for value in direction { normSquared += value * value }

			// A constraint with no gradient here offers no direction to move along. Leaving the
			// point where it is beats moving it arbitrarily.
			guard normSquared > V.Scalar.zero else { continue }

			let stride: V.Scalar = residual / normSquared
			var moved = current.toArray()
			for axis in 0..<Swift.min(dimension, direction.count) {
				moved[axis] -= stride * direction[axis]
			}
			guard let next = V.fromArray(moved) else { continue }
			current = next
		}

		if worst <= tolerance { break }
	}

	return current
}

// MARK: - Configuration

/// What a constrained solve is allowed to do before it gives up.
internal struct PenaltySolveOptions<Scalar: Real> {
	/// How far outside the feasible set a point may sit and still be called feasible.
	///
	/// Numerical slack only. A threshold is a threshold — a minimum order quantity, a capital
	/// floor, a staffing level — so the tolerance exists to absorb floating-point error in
	/// evaluating the constraint, not to make a near-miss acceptable.
	var feasibilityTolerance: Scalar

	/// The penalty weight the first attempt uses.
	var initialWeight: Scalar

	/// What the weight is multiplied by after an attempt that finishes infeasible.
	var escalationFactor: Scalar

	/// The fraction of the previous violation this one must reach before the weight is left alone.
	///
	/// The multipliers are meant to close the gap; the weight is what compensates when they are
	/// closing it too slowly. A violation that fell to below this fraction of the last is
	/// progress, and the weight stays put — which is what keeps the objective visible next to the
	/// quadratic term.
	var sufficientDecrease: Scalar

	/// How many times the weight may be raised before the solve reports what it has.
	///
	/// Bounded because escalation is not guaranteed to succeed: conflicting constraints have no
	/// feasible point at any weight, and raising it forever would spend an unbounded budget
	/// discovering that.
	var maximumEscalations: Int

	/// - Parameters:
	///   - initialWeight: The penalty weight the first attempt uses.
	///   - feasibilityTolerance: Absolute, in the constraint's own units. Defaults to the square
	///     root of machine epsilon — about 1.5e-8 for `Double` — which is the conventional
	///     "numerically zero" for a quantity that came out of arithmetic rather than a literal.
	///     It is absolute rather than relative because a constraint has no natural scale of its
	///     own to be relative to; a model whose constraints are written in units of 10⁹ should
	///     relax it deliberately.
	///   - escalationFactor: What the weight is multiplied by when progress stalls.
	///   - sufficientDecrease: The share of the previous violation this one must reach for the
	///     weight to be left alone.
	///   - maximumEscalations: How many outer iterations the loop may run.
	init(
		initialWeight: Scalar,
		feasibilityTolerance: Scalar = Scalar.ulpOfOne.squareRoot(),
		escalationFactor: Scalar = Scalar(10),
		sufficientDecrease: Scalar = Scalar(1) / Scalar(4),
		maximumEscalations: Int = 12
	) {
		self.feasibilityTolerance = feasibilityTolerance
		self.initialWeight = initialWeight
		self.escalationFactor = escalationFactor
		self.sufficientDecrease = sufficientDecrease
		self.maximumEscalations = maximumEscalations
	}
}

// MARK: - The augmented Lagrangian

/// The augmented Lagrangian of a constrained problem at given multipliers and weight.
///
/// ```
/// L(x, λ, μ, w) = f(x)
///               + Σ equalities   [ λᵢ·hᵢ(x) + (w/2)·hᵢ(x)² ]
///               + Σ inequalities (1/2w)·[ max(0, μⱼ + w·gⱼ(x))² − μⱼ² ]
/// ```
///
/// ## Why not a plain penalty
///
/// A quadratic penalty `f(x) + w·Σ violation²` **cannot** return a feasible point, and that is
/// arithmetic rather than a defect in the search. For `min ‖x‖²` subject to `x₀ ≥ b` the
/// stationary point sits at `x₀ = bw/(1 + w)`: the only force pushing `x₀` toward the bound is
/// `w·(b − x₀)`, which must stay finite and non-zero at the solution, so `x₀` must stay strictly
/// inside. The boundary is reached only as `w → ∞`.
///
/// Raising `w` far enough is not a way out either. It closes the gap — `w = 10⁹` leaves a
/// violation of 3e-9 — but at that weight the penalty dwarfs the objective, and the search
/// optimises feasibility alone. Measured on `min 0.001‖x‖²` subject to `Σx = 6`, whose optimum
/// is 0.012 at (2, 2, 2): escalating to `w = 10¹⁰` returned (11.02, −1.34, −3.67), which sits on
/// the plane and is nowhere near optimal. One failure traded for another.
///
/// ## What the multiplier changes
///
/// At the solution the constraint exerts a force on the objective, and the Lagrange multiplier
/// **is** that force. The `λᵢ·hᵢ(x)` term supplies it directly, so the quadratic term no longer
/// has to manufacture it from an ever-growing weight — at convergence `hᵢ(x) = 0` and the
/// quadratic term contributes nothing. The boundary is reached with `w` moderate, and the
/// objective stays visible next to it.
///
/// The inequality form is the same statement written so that inactive constraints drop out: when
/// `μⱼ + w·gⱼ(x) ≤ 0` the `max` is zero and the term is the constant `−μⱼ²/2w`, so a constraint
/// that is slack contributes no gradient. With `μ = 0` throughout, the whole thing reduces to the
/// plain penalty, which is why the first outer iteration behaves exactly as before.
///
/// - Parameters:
///   - objective: The function being minimised.
///   - constraints: The constraints, in the order the multipliers are indexed.
///   - multipliers: One per constraint, in the same order. `λ` for equalities, `μ ≥ 0` for
///     inequalities.
///   - weight: The quadratic weight `w`, strictly positive.
/// - Returns: A function suitable for handing to an unconstrained minimiser.
internal func augmentedLagrangian<V: VectorSpace>(
	_ objective: @escaping @Sendable (V) -> V.Scalar,
	constraints: [MultivariateConstraint<V>],
	multipliers: [V.Scalar],
	weight: V.Scalar
) -> @Sendable (V) -> V.Scalar where V.Scalar: Real, V: Sendable, V.Scalar: Sendable {
	let half = V.Scalar(1) / V.Scalar(2)
	// Guarded once here rather than inside the returned closure: the solve only ever passes a
	// positive weight, and re-checking per evaluation would cost more than the guard is worth.
	let safeWeight = weight > V.Scalar.zero ? weight : V.Scalar(1)
	let reciprocalTwice = V.Scalar(1) / (V.Scalar(2) * safeWeight)

	return { point in
		var total = objective(point)
		for (index, constraint) in constraints.enumerated() {
			let multiplier = index < multipliers.count ? multipliers[index] : V.Scalar.zero
			let value = constraint.evaluate(at: point)

			if constraint.isEquality {
				let linear: V.Scalar = multiplier * value
				let quadratic: V.Scalar = half * safeWeight * value * value
				total += linear
				total += quadratic
			} else {
				let shifted: V.Scalar = multiplier + safeWeight * value
				let active: V.Scalar = V.Scalar.maximum(V.Scalar.zero, shifted)
				let gained: V.Scalar = active * active - multiplier * multiplier
				total += reciprocalTwice * gained
			}
		}
		return total
	}
}

/// The multiplier estimates for the next outer iteration.
///
/// `λᵢ ← λᵢ + w·hᵢ(x)` for an equality and `μⱼ ← max(0, μⱼ + w·gⱼ(x))` for an inequality — the
/// standard first-order update, which is a gradient ascent step on the dual. The `max` keeps `μ`
/// non-negative, which is what encodes "an inequality can only push one way".
///
/// - Parameters:
///   - multipliers: The current estimates, one per constraint.
///   - constraints: The constraints, in the same order.
///   - point: The point the inner solve reached.
///   - weight: The quadratic weight used for that solve.
/// - Returns: The updated estimates.
internal func updatedMultipliers<V: VectorSpace>(
	_ multipliers: [V.Scalar],
	constraints: [MultivariateConstraint<V>],
	at point: V,
	weight: V.Scalar
) -> [V.Scalar] where V.Scalar: Real {
	var updated = multipliers
	for (index, constraint) in constraints.enumerated() where index < updated.count {
		let value = constraint.evaluate(at: point)
		let step: V.Scalar = updated[index] + weight * value
		updated[index] = constraint.isEquality ? step : V.Scalar.maximum(V.Scalar.zero, step)
	}
	return updated
}

// MARK: - The solve

/// Minimise subject to constraints, and report honestly whether the answer satisfies them.
///
/// An augmented-Lagrangian outer loop: solve the unconstrained subproblem, update the
/// multipliers from how far the result missed, and repeat. See
/// ``augmentedLagrangian(_:constraints:multipliers:weight:)`` for why the multiplier is what
/// makes the boundary reachable at a moderate weight, and why simply raising the weight is not a
/// substitute.
///
/// ## Why the result is checked rather than assumed
///
/// This previously returned the inner search's own `converged` flag, which reports that the
/// search settled and says nothing about the constraints. An infeasible point came back
/// indistinguishable from a feasible one — carrying an objective value *below* anything
/// attainable, because violating the constraint is what made the objective small. A caller
/// comparing two designs would have preferred whichever broke its constraints hardest.
///
/// Feasibility is now decided by measurement. A solve that finishes outside the feasible set
/// reports ``TerminationReason/infeasible`` with the least-violating point it found, which is
/// deliberately not an error: conflicting bounds are usually a modelling mistake, and seeing
/// which constraint is missed and by how much is how a modeller finds it.
///
/// - Parameters:
///   - objective: The function to minimise, unpenalised.
///   - constraints: The constraints the answer must satisfy. An empty list is trivially feasible
///     and returns after one unconstrained solve.
///   - options: Tolerance, starting weight, and the escalation schedule.
///   - minimise: Runs one unconstrained minimisation of the supplied objective, returning the
///     point reached, the iterations taken, and whether its own search converged. Supplied by
///     each optimizer so the outer loop is shared without this file knowing about any of them.
/// - Returns: The best point found, with a termination reason that reflects the constraints and
///   a value that is the **unpenalised** objective at that point.
/// - Throws: Whatever `minimise` throws.
/// - Complexity: At most `maximumEscalations + 1` unconstrained solves, and exactly one when the
///   first already lands feasible.
internal func penaltyConstrainedSolve<V: VectorSpace>(
	objective: @escaping @Sendable (V) -> V.Scalar,
	constraints: [MultivariateConstraint<V>],
	options: PenaltySolveOptions<V.Scalar>,
	minimise: (_ subproblem: @escaping @Sendable (V) -> V.Scalar) throws -> (
		solution: V, iterations: Int, converged: Bool
	)
) rethrows -> MultivariateOptimizationResult<V>
where V.Scalar: Real, V: Sendable, V.Scalar: Sendable {

	var multipliers = [V.Scalar](repeating: V.Scalar.zero, count: constraints.count)
	var weight = options.initialWeight
	var totalIterations = 0
	var previousViolation = V.Scalar.infinity

	// The least-violating point seen across every outer iteration, which is what an infeasible
	// result reports. Tracked across all of them rather than taken from the last: a later
	// iteration searches a differently-conditioned surface and is not reliably the closest.
	var best: (solution: V, violation: V.Scalar, converged: Bool)? = nil

	for iteration in 0...options.maximumEscalations {
		let subproblem = augmentedLagrangian(
			objective, constraints: constraints, multipliers: multipliers, weight: weight
		)
		let outcome = try minimise(subproblem)
		totalIterations += outcome.iterations

		let violation = worstConstraintViolation(of: constraints, at: outcome.solution)
		if best == nil || violation < (best?.violation ?? violation) {
			best = (outcome.solution, violation, outcome.converged)
		}

		if violation <= options.feasibilityTolerance {
			return MultivariateOptimizationResult(
				solution: outcome.solution,
				value: objective(outcome.solution),
				iterations: totalIterations,
				terminationReason: outcome.converged ? .converged : .maxIterations,
				gradientNorm: V.Scalar.zero,
				history: nil,
				constraintViolation: violation
			)
		}

		// The search has done what a search can. If every constraint is linear, the nearest
		// feasible point is a closed form rather than something to iterate toward — so take it,
		// and only keep going if that still leaves the point outside.
		if let restored = restoreFeasibility(
			outcome.solution, constraints: constraints, tolerance: options.feasibilityTolerance
		) {
			let restoredViolation = worstConstraintViolation(of: constraints, at: restored)
			if restoredViolation < violation {
				best = (restored, restoredViolation, outcome.converged)
			}
			if restoredViolation <= options.feasibilityTolerance {
				return MultivariateOptimizationResult(
					solution: restored,
					value: objective(restored),
					iterations: totalIterations,
					terminationReason: outcome.converged ? .converged : .maxIterations,
					gradientNorm: V.Scalar.zero,
					history: nil,
					constraintViolation: restoredViolation
				)
			}
		}

		guard iteration < options.maximumEscalations else { break }

		multipliers = updatedMultipliers(
			multipliers, constraints: constraints, at: outcome.solution, weight: weight
		)

		// Raise the weight only when the multipliers are not doing the work. The standard rule:
		// if this iteration's violation did not fall to a useful fraction of the last, the dual
		// step is too slow and the quadratic term has to take up the slack. Raising it every
		// time instead is what produces the ill-conditioning the multipliers exist to avoid.
		let requiredProgress: V.Scalar = options.sufficientDecrease * previousViolation
		if violation > requiredProgress {
			weight *= options.escalationFactor
		}
		previousViolation = violation
	}

	guard let outcome = best else {
		// Unreachable: the loop runs at least once and assigns on its first pass. Written as a
		// value rather than a trap because a solver that crashes is worse than one that reports.
		let origin = V.zero
		return MultivariateOptimizationResult(
			solution: origin,
			value: objective(origin),
			iterations: totalIterations,
			terminationReason: .infeasible,
			gradientNorm: V.Scalar.zero,
			history: nil,
			constraintViolation: worstConstraintViolation(of: constraints, at: origin)
		)
	}

	return MultivariateOptimizationResult(
		solution: outcome.solution,
		value: objective(outcome.solution),
		iterations: totalIterations,
		terminationReason: .infeasible,
		gradientNorm: V.Scalar.zero,
		history: nil,
		constraintViolation: outcome.violation
	)
}
