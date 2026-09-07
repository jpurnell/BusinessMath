//
//  ParameterConstraint.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Something a modeller knows about a distribution, stated as a constraint on it.
///
/// Risk Solver's `*Alt` forms exist because a modeller rarely knows a distribution's
/// canonical parameters. They know that the 10th percentile is 5 and the 90th is 15,
/// or that the mean is 100 and the standard deviation 12. Twenty-eight `Psi*Alt`
/// functions are that idea applied to twenty-eight distributions, and they are all the
/// same problem: **given as many constraints as the distribution has parameters, find
/// the parameters.**
///
/// ```swift
/// // "The 10th percentile is 5 and the 90th is 15." Solve for μ and σ.
/// let forecast = try DistributionNormal.fitting([
///     .quantile(p: 0.10, value: 5),
///     .quantile(p: 0.90, value: 15),
/// ])
/// ```
public enum ParameterConstraint<T: Real & Sendable>: Sendable, Equatable {

	/// `Q(p) = value` — "the *p*th percentile is *value*".
	case quantile(p: T, value: T)

	/// The distribution's mean.
	case mean(T)

	/// The distribution's variance.
	case variance(T)

	/// The distribution's standard deviation.
	///
	/// Not merely `variance` squared as far as a caller is concerned: modellers state
	/// one or the other, and converting on their behalf loses the wording they used
	/// when the fit fails and the message has to say which constraint could not be met.
	case standardDeviation(T)

	/// A canonical parameter, given directly by name — `loc`, `scale`, `shape`,
	/// `min`, `max`, `likely`.
	///
	/// Frontline's `*Alt` signatures mix these freely with percentiles, which is why
	/// this is a constraint rather than a separate code path: `PsiTriangularAlt` can
	/// be told a `min` and two percentiles, and the solve should not care which is
	/// which.
	case parameter(name: String, value: T)

	/// A short description of this constraint, so a failure names the constraint that
	/// could not be met rather than an index into an array.
	public var label: String {
		switch self {
		case .quantile(let p, let value): return "Q(\(p)) = \(value)"
		case .mean(let value): return "mean = \(value)"
		case .variance(let value): return "variance = \(value)"
		case .standardDeviation(let value): return "stdev = \(value)"
		case .parameter(let name, let value): return "\(name) = \(value)"
		}
	}
}

/// Why a set of constraints could not be turned into a distribution.
public enum ParameterFitError: Error, Sendable, Equatable {

	/// Fewer constraints than parameters: infinitely many distributions satisfy them.
	///
	/// Not resolved by picking one. Which of the infinitely many a caller wanted is
	/// information they did not supply, and inventing it is how a fit returns a
	/// confident wrong answer.
	case underdetermined(constraints: Int, parameters: Int)

	/// More constraints than parameters: in general no distribution satisfies them all.
	///
	/// A least-squares compromise would be a different question — "which distribution
	/// is closest" — and one Frontline's `*Alt` forms do not ask.
	case overdetermined(constraints: Int, parameters: Int)

	/// The distribution does not know how to evaluate this kind of constraint.
	///
	/// A distribution with no closed-form mean cannot answer a ``ParameterConstraint``
	/// of `.mean`, and saying so is better than integrating one silently.
	case unsupportedConstraint(String)

	/// The constraint is not well formed — a probability outside (0, 1), a negative
	/// variance, a parameter name the distribution does not have.
	case invalidConstraint(String)

	/// The solve did not converge from any starting point tried.
	case noSolution
}
