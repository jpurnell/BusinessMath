//
//  PercentileParameterisable.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A distribution whose parameters can be recovered from what a modeller knows.
///
/// Conforming gives a type every `Psi*Alt` form at once. Frontline documents
/// twenty-eight of them and they are not twenty-eight distributions — they are the
/// distributions that already exist, parameterised by percentiles and moments instead
/// of by their canonical arguments. Implementing that twenty-eight times would produce
/// twenty-eight root-finds able to disagree about the same distribution.
///
/// ```swift
/// extension DistributionNormal: PercentileParameterisable {
///     public static var parameterNames: [String] { ["mean", "stdDev"] }
///     public static func make(parameters: [Double]) -> DistributionNormal? {
///         guard parameters[1] > 0 else { return nil }
///         return DistributionNormal(parameters[0], parameters[1])
///     }
/// }
///
/// let fitted = try DistributionNormal.fitting([
///     .quantile(p: 0.10, value: 5),
///     .quantile(p: 0.90, value: 15),
/// ])
/// ```
///
/// ## What a conformer supplies
///
/// Three things, none of them a solver: the parameter names in the order the solve
/// varies them, a way to build from a parameter vector, and — only if the
/// distribution has closed-form moments — how to answer a `.mean` or `.variance`
/// constraint. Everything else is inherited.
///
/// ## What the solve requires of `quantile`
///
/// It calls ``ContinuousDistribution/quantile(_:)`` directly and inherits that
/// protocol's requirement that the function be monotone in `p`. An alias table in
/// `quantile` would break this solve exactly as it breaks a quasi-random sequence,
/// and for the same reason: both assume the inverse CDF is the inverse CDF.
public protocol PercentileParameterisable: ContinuousDistribution {

	/// The canonical parameters, in the order ``make(parameters:)`` expects them and
	/// the order the solve varies them.
	///
	/// The names are what a `.parameter` constraint matches against, so they should be
	/// the names Frontline's signature uses — `loc`, `scale`, `shape`, `min`, `max`,
	/// `likely` — where the two agree on one.
	static var parameterNames: [String] { get }

	/// Builds a distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry, in that order.
	/// - Returns: The distribution, or `nil` if the parameters are outside the
	///   family's support. Returning `nil` rather than trapping is what lets the solve
	///   step into an invalid region and back out again, which it will do on the way to
	///   almost every answer.
	static func make(parameters: [T]) -> Self?

	/// Starting points for the solve, best first.
	///
	/// A poor guess costs iterations; a wrong one costs a root. Several are returned
	/// rather than one because the residual surface is smooth but not globally convex,
	/// and a fixed start fails on perfectly ordinary constraint sets.
	///
	/// The default derives a scale and location from the constraints themselves, which
	/// is better than a constant for every family and ideal for none. Override where
	/// the family suggests something sharper.
	static func initialGuesses(for constraints: [ParameterConstraint<T>]) -> [[T]]

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate parameter vector that produced `self`.
	/// - Returns: The value the constraint asks about — the quantile at `p`, the mean,
	///   the named parameter.
	/// - Throws: ``ParameterFitError/unsupportedConstraint(_:)`` for a constraint this
	///   family cannot evaluate.
	func realise(_ constraint: ParameterConstraint<T>, parameters: [T]) throws -> T
}

// MARK: - What every conformer gets for free

public extension PercentileParameterisable {

	/// The default witness for ``realise(_:parameters:)``.
	func realise(_ constraint: ParameterConstraint<T>, parameters: [T]) throws -> T {
		// recursion:safe — calls `defaultRealise`, a different method; an overriding
		// conformer replaces this witness entirely and calls `defaultRealise` itself.
		try defaultRealise(constraint, parameters: parameters)
	}

	/// Quantiles and named parameters, which every family can answer.
	///
	/// Moments are not included: a distribution with no closed-form mean cannot answer
	/// a `.mean` constraint, and integrating one silently would turn "this family does
	/// not support that" into a slow, approximate yes.
	///
	/// A conformer with closed forms overrides ``realise(_:parameters:)`` and defers
	/// here for everything else. It is a separate name precisely so that deferral is
	/// possible: calling `realise` from an override would be a recursion, not a
	/// fallthrough.
	func defaultRealise(_ constraint: ParameterConstraint<T>, parameters: [T]) throws -> T {
		switch constraint {
		case .quantile(let p, _):
			guard p > 0, p < 1 else {
				throw ParameterFitError.invalidConstraint("probability \(p) is not in (0, 1)")
			}
			return quantile(p)

		case .parameter(let name, _):
			guard let index = Self.parameterNames.firstIndex(of: name) else {
				let known = Self.parameterNames.joined(separator: ", ")
				throw ParameterFitError.invalidConstraint("no parameter named '\(name)'; has \(known)")
			}
			return parameters[index]

		case .mean:
			throw ParameterFitError.unsupportedConstraint("\(Self.self) has no closed-form mean")
		case .variance, .standardDeviation:
			throw ParameterFitError.unsupportedConstraint("\(Self.self) has no closed-form variance")
		}
	}

	/// The default witness for ``initialGuesses(for:)``.
	static func initialGuesses(for constraints: [ParameterConstraint<T>]) -> [[T]] {
		// recursion:safe — calls `defaultInitialGuesses`, a different method.
		defaultInitialGuesses(for: constraints)
	}

	/// A spread of starting points derived from the constraints.
	///
	/// Separate from the witness so a conformer that knows a closed-form start can put
	/// it first and still fall back to this.
	static func defaultInitialGuesses(for constraints: [ParameterConstraint<T>]) -> [[T]] {
		let count = parameterNames.count
		let anchor: T = Self.locationHint(from: constraints)
		let spread: T = Self.scaleHint(from: constraints)

		// One guess built from the constraints, then a geometric spread around it. The
		// multipliers are deliberately wide: a scale parameter can be wrong by orders
		// of magnitude and still converge, where being wrong in sign or region does not.
		let multipliers: [T] = [T(1), T(1) / T(4), T(4), T(1) / T(20), T(20)]
		return multipliers.map { multiplier -> [T] in
			(0..<count).map { index -> T in
				// The first parameter is treated as a location and the rest as scales.
				// Crude, and right often enough to be a better default than a constant.
				index == 0 ? anchor : spread * multiplier
			}
		}
	}

	/// A location suggested by the constraints — a stated mean, a median, or the
	/// midpoint of whatever values were given.
	static func locationHint(from constraints: [ParameterConstraint<T>]) -> T {
		for constraint in constraints {
			if case .mean(let value) = constraint { return value }
		}
		for constraint in constraints {
			if case .quantile(let p, let value) = constraint, p > T(4) / T(10), p < T(6) / T(10) {
				return value
			}
		}
		var total = T.zero
		var seen = 0
		for constraint in constraints {
			if case .quantile(_, let value) = constraint { total += value; seen += 1 }
		}
		guard seen > 0 else { return T.zero }
		return total / T(seen)
	}

	/// A scale suggested by the constraints — a stated deviation, or the spread of the
	/// quantile values given.
	static func scaleHint(from constraints: [ParameterConstraint<T>]) -> T {
		for constraint in constraints {
			if case .standardDeviation(let value) = constraint, value > 0 { return value }
			if case .variance(let value) = constraint, value > 0 { return T.sqrt(value) }
		}
		var lowest: T?
		var highest: T?
		for constraint in constraints {
			guard case .quantile(_, let value) = constraint else { continue }
			lowest = lowest.map { Swift.min($0, value) } ?? value
			highest = highest.map { Swift.max($0, value) } ?? value
		}
		if let lowest, let highest, highest > lowest {
			// Two quantiles a normal's 10th and 90th apart span about 2.56 standard
			// deviations, which is the right order for most families and exact for none.
			let span: T = highest - lowest
			return span / T(2)
		}
		return T(1)
	}

	/// Solves for the distribution matching the stated constraints.
	///
	/// - Parameter constraints: Exactly as many as the family has parameters.
	/// - Returns: The distribution satisfying them.
	/// - Throws: ``ParameterFitError``.
	static func fitting(_ constraints: [ParameterConstraint<T>]) throws -> Self {
		let count = parameterNames.count
		guard constraints.count == count else {
			throw constraints.count < count
				? ParameterFitError.underdetermined(constraints: constraints.count, parameters: count)
				: ParameterFitError.overdetermined(constraints: constraints.count, parameters: count)
		}
		try validate(constraints)

		// A start that fails to converge is worth trying the next one after. A
		// constraint this family cannot evaluate is not: every start will fail the
		// same way, and swallowing it turns "a Cauchy has no mean" into "the solve did
		// not converge" — an answer that sends the caller looking at their numbers
		// instead of at their constraint.
		var convergenceFailure: Error?
		for guess in initialGuesses(for: constraints) {
			do {
				return try solve(constraints, from: guess)
			} catch let error as ParameterFitError {
				switch error {
				case .unsupportedConstraint, .invalidConstraint:
					throw error
				case .noSolution, .underdetermined, .overdetermined:
					convergenceFailure = error
				}
			}
		}
		throw convergenceFailure ?? ParameterFitError.noSolution
	}

	/// Rejects constraints that are not well formed before any solving happens, so a
	/// bad probability reports as itself rather than as a failure to converge.
	static func validate(_ constraints: [ParameterConstraint<T>]) throws {
		for constraint in constraints {
			switch constraint {
			case .quantile(let p, _):
				guard p > 0, p < 1 else {
					throw ParameterFitError.invalidConstraint("probability \(p) is not in (0, 1)")
				}
			case .variance(let value):
				guard value > 0 else {
					throw ParameterFitError.invalidConstraint("variance \(value) is not positive")
				}
			case .standardDeviation(let value):
				guard value > 0 else {
					throw ParameterFitError.invalidConstraint("stdev \(value) is not positive")
				}
			case .parameter(let name, _):
				guard parameterNames.contains(name) else {
					let known = parameterNames.joined(separator: ", ")
					throw ParameterFitError.invalidConstraint("no parameter named '\(name)'; has \(known)")
				}
			case .mean:
				continue
			}
		}
		// Two constraints on the same probability are either redundant or
		// contradictory, and both make the Jacobian singular rather than the answer
		// wrong — a failure that would otherwise surface as `noSolution`.
		var probabilities: [T] = []
		for constraint in constraints {
			guard case .quantile(let p, _) = constraint else { continue }
			if probabilities.contains(p) {
				throw ParameterFitError.invalidConstraint("two constraints on the same quantile \(p)")
			}
			probabilities.append(p)
		}
	}

	/// The target value each constraint states.
	static func target(of constraint: ParameterConstraint<T>) -> T {
		switch constraint {
		case .quantile(_, let value): return value
		case .mean(let value): return value
		case .variance(let value): return value
		case .standardDeviation(let value): return value
		case .parameter(_, let value): return value
		}
	}
}
