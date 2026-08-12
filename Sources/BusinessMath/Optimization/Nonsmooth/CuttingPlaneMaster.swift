//
//  CuttingPlaneMaster.swift
//  BusinessMath
//
//  See project/plans/proposals/NonsmoothOptimization.md
//

import Foundation
import Numerics

/// The outcome of a cutting-plane solve.
///
/// Carries the optimality gap alongside the answer, so a run that exhausted its rounds
/// reports how far it got rather than returning a number that looks like a solution.
public struct CuttingPlaneResult<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {
	/// Best point found.
	public let solution: V

	/// Objective value at ``solution``.
	public let objectiveValue: Double

	/// `objectiveValue − lowerBound`. At or below the tolerance the answer is certified
	/// optimal, because the piecewise-linear model is a global under-estimator of a
	/// convex objective.
	public let optimalityGap: Double

	/// Whether the gap closed within the round budget *and* nothing disproved convexity.
	public let converged: Bool

	/// Whether ``optimalityGap`` is a bound rather than a number.
	///
	/// The gap is a certificate only while every cut under-estimates the objective, which
	/// holds for a convex function and need not otherwise. When the solve observes the
	/// model rising above the objective at a point it has evaluated — a proof that some
	/// cut is not an under-estimator, and therefore that the objective is not convex —
	/// this is `false` and the gap means nothing.
	///
	/// The solve still returns the best point it found. It simply stops claiming the
	/// point is optimal, which is the difference between a result and an assertion.
	public let isCertified: Bool

	/// Rounds performed.
	public let iterations: Int
}

/// Minimises a convex objective that need not be differentiable.
///
/// Builds a piecewise-linear lower model from cuts taken at successive iterates —
/// `model(x) = maxₖ [f(xₖ) + gₖ·(x − xₖ)]` — minimises that model over a trust region,
/// and repeats. Because every cut under-estimates a convex `f`, the model's minimum is a
/// lower bound on the true one, and the gap between it and the best point seen is a
/// certificate rather than a guess.
///
/// This exists because a gradient method cannot solve a problem whose optimum is a kink.
/// The step it takes is sized by the gradient, and at a kink the gradient does not shrink
/// as the iterate approaches — so it oscillates across the corner instead of settling.
/// The newsvendor model is the everyday example: `max(0, demand − quantity)` puts the
/// optimum exactly on the corner.
///
/// ## Subgradients from an opaque objective
///
/// Cuts need a subgradient, and the caller's objective is a closure. A central difference
/// at a kink returns roughly the midpoint of the subdifferential, and for a convex
/// function the subdifferential is a convex set — so the midpoint lies inside it and the
/// resulting cut is a valid under-estimator. That is why no gradient sampling appears
/// here: it is needed for nonconvex objectives, and this type detects those rather than
/// attempting them.
///
/// ## When the objective is not convex
///
/// The method assumes convexity, and an assumption a caller cannot see is the kind this
/// library has spent a release removing — so it is checked rather than trusted. A convex
/// objective is bounded below by its own cuts, so the model can never exceed it; each
/// round already computes both numbers at the candidate, and the model coming out higher
/// is a *proof* that some cut is not an under-estimator. The solve then keeps searching,
/// because the model still points somewhere useful, but returns
/// ``CuttingPlaneResult/isCertified`` as `false` and never reports `converged`. Every
/// non-smooth objective this library builds — worst-case maxima, `abs` and `max(0, ·)`
/// penalties, L1 norms, expected newsvendor profit — is convex, so the common path is
/// unaffected; `optimize` nonetheless accepts arbitrary closures, and a nonconvex one
/// receives an honest answer instead of a confident wrong one.
///
/// - Note: The trust region is what keeps plain Kelley cutting-plane stable. Without it
///   the model's minimiser can jump far from the incumbent on early rounds, when the
///   model is a poor description of the function.
public struct CuttingPlaneMaster<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {

	/// Maximum rounds before reporting the gap unclosed.
	public let maxRounds: Int

	/// Gap at which the incumbent is certified optimal.
	public let tolerance: Double

	/// Initial trust-region half-width, in the units of the decision variables.
	public let initialTrustRegion: Double

	/// Creates a cutting-plane solver.
	///
	/// - Parameters:
	///   - maxRounds: Round budget. Exhausting it reports `converged: false` and a gap.
	///   - tolerance: Gap at which the answer is certified.
	///   - initialTrustRegion: Starting half-width of the box the master may move within.
	public init(maxRounds: Int = 100, tolerance: Double = 1e-6, initialTrustRegion: Double = 100.0) {
		self.maxRounds = maxRounds
		self.tolerance = tolerance
		self.initialTrustRegion = initialTrustRegion
	}

	/// Minimises `objective` subject to linear constraints.
	///
	/// - Parameters:
	///   - objective: The function to minimise. Assumed convex; a nonconvex objective
	///     produces cuts that are not valid under-estimators and the gap means nothing.
	///   - start: Initial point.
	///   - constraints: Caller constraints, linearised about `start`.
	/// - Returns: The best point found, with its optimality gap.
	/// - Throws: `OptimizationError` if the problem cannot be set up or the objective is
	///   not finite at the starting point.
	public func minimize(
		_ objective: @escaping @Sendable (V) -> Double,
		from start: V,
		subjectTo constraints: [MultivariateConstraint<V>]
	) throws -> CuttingPlaneResult<V> {

		let dimension = start.toArray().count
		guard dimension > 0 else {
			throw OptimizationError.invalidInput(message: "Start point has zero dimensions")
		}

		let startValue = objective(start)
		guard startValue.isFinite else {
			throw OptimizationError.nonFiniteValue(message: "Objective is not finite at the start point")
		}

		// Caller constraints, linearised once. A nonlinear constraint is out of scope for
		// this master — it would need its own cuts — so it is refused rather than
		// silently linearised and enforced somewhere other than where it was written.
		var linearConstraints: [(coefficients: [Double], constant: Double, isEquality: Bool)] = []
		for constraint in constraints {
			let evaluate: (V) -> Double = { point in constraint.evaluate(at: point) }
			guard let model = try? validateLinearModel(evaluate, dimension: dimension, at: start),
				  model.coefficients.count == dimension else {
				throw OptimizationError.invalidInput(
					message: "CuttingPlaneMaster handles linear constraints; one of the supplied constraints is not linear"
				)
			}
			linearConstraints.append((model.coefficients, model.constant, constraint.isEquality))
		}

		var centre = start.toArray()
		var incumbent = centre
		var incumbentValue = startValue
		var trustRegion = initialTrustRegion
		var cuts: [(value: Double, slope: [Double], point: [Double])] = []
		var lowerBound = -Double.infinity
		var rounds = 0
		var isCertified = true

		// How far the model must rise above the objective before non-convexity is
		// declared rather than attributed to the finite-difference slopes the cuts are
		// built from. Scaled by the objective's own magnitude, because a fixed threshold
		// would fire on a large objective and never on a small one.
		let convexityMargin = Swift.max(tolerance, abs(startValue) * 1e-6)

		for _ in 0..<maxRounds {
			rounds += 1

			guard let centrePoint = V.fromArray(centre) else {
				throw OptimizationError.invalidInput(message: "Failed to rebuild the iterate")
			}
			let centreValue = objective(centrePoint)
			let slope = try Self.subgradient(objective, at: centrePoint, dimension: dimension)
			cuts.append((centreValue, slope, centre))

			guard let solved = try solveMaster(
				cuts: cuts,
				linearConstraints: linearConstraints,
				centre: centre,
				trustRegion: trustRegion,
				dimension: dimension
			) else {
				// The master became infeasible, which at this point means the trust
				// region has collapsed against the constraints. Shrinking further cannot
				// help, so stop and report what the model proved.
				break
			}

			lowerBound = Swift.max(lowerBound, solved.modelValue)

			guard let candidatePoint = V.fromArray(solved.point) else {
				throw OptimizationError.invalidInput(message: "Failed to rebuild the candidate")
			}
			let candidateValue = objective(candidatePoint)

			// A convex objective is bounded below by its own cuts, so the model can never
			// exceed it. Observing otherwise at a point already evaluated is a proof that
			// some cut is not an under-estimator, and therefore that the objective is not
			// convex. Costs nothing: both numbers are already in hand.
			//
			// Once seen, the lower bound is no longer a bound and the gap is no longer a
			// certificate. The search continues — the model still points somewhere useful
			// — but the result stops claiming optimality.
			let modelExcess = solved.modelValue - candidateValue
			if modelExcess > convexityMargin {
				isCertified = false
			}

			if candidateValue < incumbentValue {
				incumbent = solved.point
				incumbentValue = candidateValue
			}

			// The gap the model can prove. Because every cut under-estimates a convex
			// objective, this bounds the distance from the incumbent to the true optimum.
			// Certifying is the moment the assumption actually gets used, so it is also
			// where the assumption is tested. Checking only points the master chose is
			// not enough: when a cut is flat the master has no reason to move at all, and
			// a flat cut is precisely what a non-convex local maximum produces. The probe
			// looks where the model claims there is nothing to find.
			var gap = incumbentValue - lowerBound
			if gap <= tolerance && isCertified {
				if let witness = Self.convexityWitness(
					objective,
					cuts: cuts,
					about: incumbent,
					radius: Swift.max(trustRegion, 1),
					dimension: dimension,
					margin: convexityMargin
				) {
					isCertified = false
					if witness.value < incumbentValue {
						incumbent = witness.point
						incumbentValue = witness.value
					}
					lowerBound = -Double.infinity
					gap = Double.infinity
				}
			}

			if gap <= tolerance && isCertified {
				guard let solution = V.fromArray(incumbent) else {
					throw OptimizationError.invalidInput(message: "Failed to rebuild the solution")
				}
				return CuttingPlaneResult(
					solution: solution,
					objectiveValue: incumbentValue,
					optimalityGap: Swift.max(0, gap),
					converged: true,
					isCertified: isCertified,
					iterations: rounds
				)
			}

			// A candidate no better than the incumbent means the model is still a poor
			// description here, so tighten the region it is trusted over. Otherwise
			// follow the candidate.
			if candidateValue < centreValue {
				centre = solved.point
			} else {
				trustRegion = trustRegion / 2
				centre = incumbent
			}
		}

		guard let solution = V.fromArray(incumbent) else {
			throw OptimizationError.invalidInput(message: "Failed to rebuild the solution")
		}
		let finalGap = incumbentValue - lowerBound
		return CuttingPlaneResult(
			solution: solution,
			objectiveValue: incumbentValue,
			optimalityGap: finalGap.isFinite ? Swift.max(0, finalGap) : Double.infinity,
			converged: false,
			isCertified: isCertified,
			iterations: rounds
		)
	}

	// MARK: - The master problem

	/// Minimises the piecewise-linear model over the trust region and the caller's
	/// constraints, as a linear program.
	private func solveMaster(
		cuts: [(value: Double, slope: [Double], point: [Double])],
		linearConstraints: [(coefficients: [Double], constant: Double, isEquality: Bool)],
		centre: [Double],
		trustRegion: Double,
		dimension: Int
	) throws -> (point: [Double], modelValue: Double)? {

		// Columns: [x₀⁺, x₀⁻, …, t⁺, t⁻]. Both the decision variables and the model value
		// are free, and the simplex method assumes non-negative columns, so each is
		// carried as a difference of two.
		let positiveEpigraph = 2 * dimension
		let negativeEpigraph = positiveEpigraph + 1
		let variableCount = negativeEpigraph + 1

		var rows: [SimplexConstraint] = []

		// t ≥ f(xₖ) + gₖ·(x − xₖ)  ⟺  gₖ·x − t ≤ gₖ·xₖ − f(xₖ)
		for cut in cuts {
			var row = [Double](repeating: 0, count: variableCount)
			var rhs = -cut.value
			for i in 0..<dimension {
				row[i] = cut.slope[i]
				row[dimension + i] = -cut.slope[i]
				rhs += cut.slope[i] * cut.point[i]
			}
			row[positiveEpigraph] = -1
			row[negativeEpigraph] = 1
			rows.append(SimplexConstraint(coefficients: row, relation: .lessOrEqual, rhs: rhs))
		}

		// Caller constraints: g(x) ≤ 0 or h(x) = 0, linearised.
		for constraint in linearConstraints {
			var row = [Double](repeating: 0, count: variableCount)
			for i in 0..<dimension {
				row[i] = constraint.coefficients[i]
				row[dimension + i] = -constraint.coefficients[i]
			}
			let relation: ConstraintRelation = constraint.isEquality ? .equal : .lessOrEqual
			rows.append(SimplexConstraint(coefficients: row, relation: relation, rhs: -constraint.constant))
		}

		// Trust region, as a box about the centre.
		for i in 0..<dimension {
			var upper = [Double](repeating: 0, count: variableCount)
			upper[i] = 1
			upper[dimension + i] = -1
			rows.append(SimplexConstraint(coefficients: upper, relation: .lessOrEqual, rhs: centre[i] + trustRegion))

			var lower = [Double](repeating: 0, count: variableCount)
			lower[i] = -1
			lower[dimension + i] = 1
			rows.append(SimplexConstraint(coefficients: lower, relation: .lessOrEqual, rhs: trustRegion - centre[i]))
		}

		var objectiveCoefficients = [Double](repeating: 0, count: variableCount)
		objectiveCoefficients[positiveEpigraph] = 1
		objectiveCoefficients[negativeEpigraph] = -1

		// Cut coefficients come from finite differences, so the master is solved to the
		// accuracy those carry rather than to the solver's default.
		let solver = SimplexSolver(tolerance: Self.masterTolerance)
		let solved = try solver.minimize(objective: objectiveCoefficients, subjectTo: rows)

		guard solved.status == .optimal, solved.solution.count >= variableCount else { return nil }

		var point: [Double] = []
		point.reserveCapacity(dimension)
		for i in 0..<dimension {
			point.append(solved.solution[i] - solved.solution[dimension + i])
		}
		let modelValue = solved.solution[positiveEpigraph] - solved.solution[negativeEpigraph]
		return (point, modelValue)
	}

	// MARK: - Cuts

	/// Accuracy the master is solved to, matching what finite-difference cut
	/// coefficients actually carry. Solving tighter than the data asks Phase I to drive
	/// residuals below the input noise, which reports a feasible program infeasible.
	private static var masterTolerance: Double { 1e-7 }

	/// Looks for a point where the model rises above the objective, which disproves
	/// convexity.
	///
	/// Returns the offending point and its value, or `nil` if none was found. Finding one
	/// is conclusive; finding none is not a proof of convexity, only an absence of
	/// evidence against it — the probe is a fixed pattern, not a search.
	///
	/// Probes sit on the coordinate axes about the incumbent at two radii, which is
	/// deterministic and costs `4n` evaluations once, at the point of certifying. On the
	/// double well `(x² − 1)²` certified from the origin, the flat cut puts the model at
	/// `1` while `f(±1) = 0`, and the probe lands on it.
	private static func convexityWitness(
		_ objective: @Sendable (V) -> Double,
		cuts: [(value: Double, slope: [Double], point: [Double])],
		about centre: [Double],
		radius: Double,
		dimension: Int,
		margin: Double
	) -> (point: [Double], value: Double)? {

		/// The piecewise-linear model, evaluated directly rather than through the LP.
		func model(at point: [Double]) -> Double {
			var highest = -Double.infinity
			for cut in cuts {
				var value = cut.value
				for i in 0..<dimension {
					value += cut.slope[i] * (point[i] - cut.point[i])
				}
				highest = Swift.max(highest, value)
			}
			return highest
		}

		for i in 0..<dimension {
			for offset in [radius, -radius, radius / 2, -radius / 2] {
				var probe = centre
				probe[i] += offset
				guard let probePoint = V.fromArray(probe) else { continue }

				let actual = objective(probePoint)
				guard actual.isFinite else { continue }

				if model(at: probe) - actual > margin {
					return (probe, actual)
				}
			}
		}

		return nil
	}

	/// A subgradient of `objective` at `point`, by central differences.
	///
	/// For a convex function the subdifferential at a kink is a convex set, and a central
	/// difference straddling the kink returns a value inside it. The resulting cut is
	/// therefore a valid under-estimator, which is all the model requires.
	private static func subgradient(
		_ objective: @Sendable (V) -> Double,
		at point: V,
		dimension: Int
	) throws -> [Double] {
		let components = point.toArray()
		let step = 1e-6
		var slope: [Double] = []
		slope.reserveCapacity(dimension)

		for i in 0..<dimension {
			var forward = components
			var backward = components
			forward[i] += step
			backward[i] -= step

			guard let forwardPoint = V.fromArray(forward), let backwardPoint = V.fromArray(backward) else {
				throw OptimizationError.invalidInput(message: "Failed to build a perturbed point")
			}
			let rise = objective(forwardPoint) - objective(backwardPoint)
			guard rise.isFinite else {
				throw OptimizationError.nonFiniteValue(message: "Objective is not finite near the iterate")
			}
			slope.append(rise / (2 * step))
		}

		return slope
	}
}
