//
//  PercentileConformances.swift
//  BusinessMath
//

import Foundation
import Numerics

// Every conformance here is the same three declarations: the parameter names, a way
// to build from a vector, and — where the family has closed forms — its moments.
// None of them contains a solver, which is the point.
//
// Frontline names twenty-eight `Psi*Alt` forms. These are the ones whose base
// distribution exists at 2.14.0; the rest arrive with their base.

// MARK: - Normal — PsiNormalAlt

extension DistributionNormal: PercentileParameterisable {

	/// `mean` and `stdDev`, matching the initialiser's order.
	public static var parameterNames: [String] { ["mean", "stdDev"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionNormal? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0].isFinite, parameters[1] > 0, parameters[1].isFinite else { return nil }
		return DistributionNormal(parameters[0], parameters[1])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return mean
		case .variance: return stdDev * stdDev
		case .standardDeviation: return stdDev
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}

	/// A normal is fixed by two quantiles in closed form, so the first guess is the
	/// answer and the solve confirms it in one step.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		var guesses: [[Double]] = []
		let quantiles = constraints.compactMap { constraint -> (Double, Double)? in
			guard case .quantile(let p, let value) = constraint else { return nil }
			return (p, value)
		}
		if quantiles.count == 2 {
			let first = quantiles[0], second = quantiles[1]
			let z1: Double = inverseNormalCDF(p: first.0, mean: 0, stdDev: 1)
			let z2: Double = inverseNormalCDF(p: second.0, mean: 0, stdDev: 1)
			let deltaZ: Double = z2 - z1
			if abs(deltaZ) > 1e-12 {
				let deltaX: Double = second.1 - first.1
				let sigma: Double = deltaX / deltaZ
				if sigma > 0 {
					let mu: Double = first.1 - sigma * z1
					guesses.append([mu, sigma])
				}
			}
		}
		guesses.append(contentsOf: defaultInitialGuesses(for: constraints))
		return guesses
	}
}

// MARK: - Lognormal — PsiLogNormalAlt

extension DistributionLogNormal: PercentileParameterisable {

	/// The parameters are those of the **log**, which is the parameterisation every
	/// reference uses and the one the initialiser takes.
	public static var parameterNames: [String] { ["logMean", "logStdDev"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionLogNormal? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0].isFinite, parameters[1] > 0, parameters[1].isFinite else { return nil }
		return DistributionLogNormal(parameters[0], parameters[1])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean:
			// exp(μ + σ²/2) — not exp(μ), which is the median. Reading one for the
			// other is the most common way to under-budget a right-skewed quantity.
			let variance: Double = stdDev * stdDev
			let exponent: Double = mean + variance / 2
			return Foundation.exp(exponent)
		case .variance:
			let variance: Double = stdDev * stdDev
			let growth: Double = Foundation.expm1(variance)
			let scale: Double = 2 * mean + variance
            return growth * Foundation.exp(scale)
		case .standardDeviation:
			let variance: Double = stdDev * stdDev
			let growth: Double = Foundation.expm1(variance)
			let scale: Double = 2 * mean + variance
			let total: Double = growth * Foundation.exp(scale)
			return total.squareRoot()
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: - Exponential — PsiExponentialAlt

extension DistributionExponential: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["rate"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionExponential? {
		guard parameters.count == 1, parameters[0] > 0, parameters[0].isFinite else { return nil }
		return DistributionExponential(parameters[0])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return 1 / λ
		case .variance: return 1 / (λ * λ)
		case .standardDeviation: return 1 / λ
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: - Weibull — PsiWeibullAlt

extension DistributionWeibull: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["shape", "scale"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionWeibull? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0] > 0, parameters[0].isFinite else { return nil }
		guard parameters[1] > 0, parameters[1].isFinite else { return nil }
		return DistributionWeibull(shape: parameters[0], scale: parameters[1])
	}
}

// MARK: - Logistic — PsiLogisticAlt

extension DistributionLogistic: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["mean", "stdDev"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionLogistic? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0].isFinite, parameters[1] > 0, parameters[1].isFinite else { return nil }
		return DistributionLogistic(parameters[0], parameters[1])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return mean
		case .standardDeviation: return stdDev
		case .variance: return stdDev * stdDev
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: - Laplace — PsiLaplaceAlt

extension DistributionLaplace: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["location", "scale"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionLaplace? {
		guard parameters.count == 2 else { return nil }
		return DistributionLaplace(location: parameters[0], scale: parameters[1])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return location
		case .variance: return 2 * scale * scale
		case .standardDeviation:
			let variance: Double = 2 * scale * scale
			return variance.squareRoot()
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: - Cauchy — PsiCauchyAlt

extension DistributionCauchy: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["location", "scale"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionCauchy? {
		guard parameters.count == 2 else { return nil }
		return DistributionCauchy(location: parameters[0], scale: parameters[1])
	}

	// No moment overrides, deliberately: a Cauchy has no mean and no variance. The
	// default throws `unsupportedConstraint`, which is the truth rather than a
	// limitation — `PsiCauchyAlt`'s signature offers only percentile pairs, for
	// exactly this reason.
}

// MARK: - Pareto — PsiParetoAlt

extension DistributionPareto: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["scale", "shape"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionPareto? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0] > 0, parameters[0].isFinite else { return nil }
		guard parameters[1] > 0, parameters[1].isFinite else { return nil }
		return DistributionPareto(scale: parameters[0], shape: parameters[1])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean:
			// Finite only for shape > 1, and a fit that steps below it must back out
			// rather than accept an infinity as a residual.
			guard shape > 1 else { return .infinity }
			// `shape > 1` on the line above is exactly what makes this positive.
			let excess: Double = shape - 1
			guard excess > 0 else { return .infinity }
			let numerator: Double = shape * scale
			return numerator / excess
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: - Rayleigh — PsiRayleighAlt

extension DistributionRayleigh: PercentileParameterisable {

	/// The canonical parameters, in the order ``make(parameters:)`` takes them.
	public static var parameterNames: [String] { ["scale"] }

	/// Builds the distribution from a parameter vector.
	///
	/// - Parameter parameters: One value per ``parameterNames`` entry.
	/// - Returns: The distribution, or `nil` if the parameters fall outside the
	///   family's support — which the solve reads as a step to back out of.
	public static func make(parameters: [Double]) -> DistributionRayleigh? {
		guard parameters.count == 1, parameters[0] > 0, parameters[0].isFinite else { return nil }
		return DistributionRayleigh(scale: parameters[0])
	}

	/// What this distribution says about a constraint, for the residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector that produced `self`.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean:
			let half: Double = Double.pi / 2
			return scale * half.squareRoot()
		case .variance:
			let factor: Double = (4 - Double.pi) / 2
			return factor * scale * scale
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}
