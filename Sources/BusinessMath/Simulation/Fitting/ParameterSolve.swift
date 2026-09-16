//
//  ParameterSolve.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - The solve

public extension PercentileParameterisable {

	/// One damped Newton solve from one starting point.
	///
	/// The residual is a *vector* — one entry per constraint, each the difference
	/// between what the constraint asks for and what the candidate distribution gives —
	/// and this drives that vector to zero. It does **not** minimise its norm.
	///
	/// That distinction matters and is easy to get wrong, because the package already
	/// has good minimisers. Minimising `‖r‖²` squares the condition number of the
	/// problem: a fit that Newton solves to machine precision can leave a minimiser
	/// stalled in a flat basin, and the flatness is an artefact of the squaring rather
	/// than anything about the distribution. Newton on `r` itself is both faster and
	/// better conditioned when the Jacobian is available, and here it is — numerically,
	/// but the residual is cheap.
	///
	/// - Parameters:
	///   - constraints: The constraints, already validated and counted.
	///   - start: The initial parameter vector.
	/// - Returns: The fitted distribution.
	/// - Throws: ``ParameterFitError/noSolution`` if this start does not converge, or
	///   the error a constraint raises if the family cannot evaluate it.
	static func solve(_ constraints: [ParameterConstraint<T>], from start: [T]) throws -> Self {
		let count = parameterNames.count
		var parameters = start

		/// The residual vector at a candidate, or `nil` where the candidate is outside
		/// the family's support — which the solve treats as a step to back out of
		/// rather than as a failure.
		func residual(_ candidate: [T]) throws -> [T]? {
			guard let distribution = make(parameters: candidate) else { return nil }
			var out = [T](repeating: T.zero, count: constraints.count)
			for (index, constraint) in constraints.enumerated() {
				let realised = try distribution.realise(constraint, parameters: candidate)
				guard realised.isFinite else { return nil }
				let wanted: T = target(of: constraint)
				out[index] = realised - wanted
			}
			return out
		}

		/// The scale each residual is judged against, so a constraint stated in
		/// millions and one stated in percent are held to the same relative accuracy.
		let scales: [T] = constraints.map { constraint -> T in
			let wanted: T = target(of: constraint)
			let magnitude: T = wanted < 0 ? -wanted : wanted
			return Swift.max(magnitude, T(1))
		}

		func converged(_ residuals: [T]) -> Bool {
			for (index, value) in residuals.enumerated() {
				let magnitude: T = value < 0 ? -value : value
				let bound: T = scales[index] / T(1_000_000_000)
				if magnitude > bound { return false }
			}
			return true
		}

		func total(_ residuals: [T]) -> T {
			var sum = T.zero
			for value in residuals { sum += value < 0 ? -value : value }
			return sum
		}

		guard var current = try residual(parameters) else { throw ParameterFitError.noSolution }

		for _ in 0..<200 {
			if converged(current) {
				guard let fitted = make(parameters: parameters) else { throw ParameterFitError.noSolution }
				return fitted
			}

			// Numerical Jacobian, one column per parameter. The step is relative to the
			// parameter it perturbs, because a scale of 1e6 and a shape of 0.5 cannot
			// share an absolute step without one of them being pure rounding.
			var jacobian = [[T]](repeating: [T](repeating: T.zero, count: count), count: constraints.count)
			var usable = true
			for column in 0..<count {
				let magnitude: T = parameters[column] < 0 ? -parameters[column] : parameters[column]
				let base: T = Swift.max(magnitude, T(1))
				let step: T = base / T(1_000_000)
				var moved = parameters
				moved[column] += step
				guard let shifted = try residual(moved) else { usable = false; break }
				for row in 0..<constraints.count {
					let difference: T = shifted[row] - current[row]
					jacobian[row][column] = difference / step
				}
			}
			guard usable else { break }

			guard let delta = Self.solveLinear(jacobian, current) else { break }

			// Damped. An undamped Newton step from a plausible start routinely lands
			// outside the family's support — a negative scale, a shape below one — and
			// backtracking is what turns that from a failure into an iteration.
			var damping = T(1)
			var accepted = false
			for _ in 0..<30 {
				var trial = parameters
				for index in 0..<count {
					let move: T = damping * delta[index]
					trial[index] -= move
				}
				if let candidate = try residual(trial), total(candidate) < total(current) {
					parameters = trial
					current = candidate
					accepted = true
					break
				}
				damping /= T(2)
			}
			guard accepted else { break }
		}

		if converged(current), let fitted = make(parameters: parameters) { return fitted }
		throw ParameterFitError.noSolution
	}

	/// Solves `A x = b` by Gaussian elimination with partial pivoting.
	///
	/// Small and dense — `k` is at most four across every `*Alt` form Frontline documents —
	/// so there is nothing to gain from the package's factorisations, and they would need a
	/// `DenseMatrix` built and torn down at every Newton step.
	///
	/// The elimination itself is `gaussianSolve(_:_:options:)`, shared with four other
	/// callers. What stays here is the **fixed `1e-12` threshold**, which is deliberate:
	/// these systems are at most 4×4 over a known parameter range, so their scale is not in
	/// doubt and a constant cutoff says what is meant more directly than a scale-relative
	/// one would.
	///
	/// - Returns: The solution, or `nil` if the matrix is singular to working
	///   precision, which is the solve's signal that this start is going nowhere.
	static func solveLinear(_ matrix: [[T]], _ rightHandSide: [T]) -> [T]? {
		let options = GaussianSolveOptions<T>(
			criterion: .absolute(T(1) / T(1_000_000_000_000))
		)
		return gaussianSolve(matrix, rightHandSide, options: options)
	}
}
