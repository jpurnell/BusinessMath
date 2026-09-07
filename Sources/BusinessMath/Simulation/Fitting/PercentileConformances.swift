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

// MARK: - The remaining Alt bases
//
// Each of these is the same three declarations again. Adding one costs about ten
// lines and yields a whole `Psi*Alt` form, which is the leverage the protocol exists
// for — and the reason implementing the 28 separately would have been the expensive
// mistake.
//
// Moment overrides are supplied only where the family has a closed form. Where it
// does not, the default throws `unsupportedConstraint`, which is the truth: several
// of these have no elementary mean, and integrating one silently would turn "this
// family cannot answer that" into a slow, approximate yes.

// MARK: PsiErfAlt

extension DistributionErf: PercentileParameterisable {

	/// The single inverse-scale parameter.
	public static var parameterNames: [String] { ["h"] }

	/// Builds from the inverse scale.
	///
	/// - Parameter parameters: One value, `h`.
	/// - Returns: The distribution, or `nil` for a non-positive `h`.
	public static func make(parameters: [Double]) -> DistributionErf? {
		guard parameters.count == 1 else { return nil }
		return DistributionErf(h: parameters[0])
	}

	/// The mean is zero and the deviation is `1/(h√2)`.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return 0
		case .standardDeviation: return standardDeviation
		case .variance: return standardDeviation * standardDeviation
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiHypSecantAlt

extension DistributionHypSecant: PercentileParameterisable {

	/// Location then scale.
	public static var parameterNames: [String] { ["loc", "scale"] }

	/// Builds from location and scale.
	///
	/// - Parameter parameters: `loc` then `scale`.
	/// - Returns: The distribution, or `nil` if the scale is not positive.
	public static func make(parameters: [Double]) -> DistributionHypSecant? {
		guard parameters.count == 2 else { return nil }
		return DistributionHypSecant(loc: parameters[0], scale: parameters[1])
	}
}

// MARK: PsiLevyAlt

extension DistributionLevy: PercentileParameterisable {

	/// Location then scale.
	public static var parameterNames: [String] { ["loc", "scale"] }

	/// Builds from location and scale.
	///
	/// - Parameter parameters: `loc` then `scale`.
	/// - Returns: The distribution, or `nil` if the scale is not positive.
	public static func make(parameters: [Double]) -> DistributionLevy? {
		guard parameters.count == 2 else { return nil }
		return DistributionLevy(location: parameters[0], scale: parameters[1])
	}

	// No moment overrides: a Lévy distribution has no finite mean. `PsiLevyAlt`'s
	// signature offers percentiles and a location, which is exactly why.
}

// MARK: PsiMaxExtremeAlt / PsiMinExtremeAlt

extension DistributionMaxExtreme: PercentileParameterisable {

	/// Location then scale.
	public static var parameterNames: [String] { ["loc", "scale"] }

	/// Builds from location and scale.
	///
	/// - Parameter parameters: `loc` then `scale`.
	/// - Returns: The distribution, or `nil` if the scale is not positive.
	public static func make(parameters: [Double]) -> DistributionMaxExtreme? {
		guard parameters.count == 2 else { return nil }
		return DistributionMaxExtreme(location: parameters[0], scale: parameters[1])
	}
}

extension DistributionMinExtreme: PercentileParameterisable {

	/// Location then scale.
	public static var parameterNames: [String] { ["loc", "scale"] }

	/// Builds from location and scale.
	///
	/// - Parameter parameters: `loc` then `scale`.
	/// - Returns: The distribution, or `nil` if the scale is not positive.
	public static func make(parameters: [Double]) -> DistributionMinExtreme? {
		guard parameters.count == 2 else { return nil }
		return DistributionMinExtreme(location: parameters[0], scale: parameters[1])
	}
}

// MARK: PsiPearson5Alt / PsiPearson6Alt

extension DistributionPearson5: PercentileParameterisable {

	/// Shape then scale.
	public static var parameterNames: [String] { ["shape", "scale"] }

	/// Builds from shape and scale.
	///
	/// - Parameter parameters: `shape` then `scale`.
	/// - Returns: The distribution, or `nil` if either is not positive.
	public static func make(parameters: [Double]) -> DistributionPearson5? {
		guard parameters.count == 2 else { return nil }
		return DistributionPearson5(alpha: parameters[0], beta: parameters[1])
	}
}

extension DistributionPearson6: PercentileParameterisable {

	/// Two shapes then a scale.
	public static var parameterNames: [String] { ["shape1", "shape2", "scale"] }

	/// Builds from two shapes and a scale.
	///
	/// - Parameter parameters: `shape1`, `shape2`, `scale`.
	/// - Returns: The distribution, or `nil` if any is not positive.
	public static func make(parameters: [Double]) -> DistributionPearson6? {
		guard parameters.count == 3 else { return nil }
		return DistributionPearson6(alpha1: parameters[0], alpha2: parameters[1], beta: parameters[2])
	}
}

// MARK: PsiPareto2Alt

extension DistributionPareto2: PercentileParameterisable {

	/// Scale then shape, matching the initialiser.
	public static var parameterNames: [String] { ["scale", "shape"] }

	/// Builds from scale and shape.
	///
	/// - Parameter parameters: `scale` then `shape`.
	/// - Returns: The distribution, or `nil` if either is not positive.
	public static func make(parameters: [Double]) -> DistributionPareto2? {
		guard parameters.count == 2 else { return nil }
		return DistributionPareto2(scale: parameters[0], shape: parameters[1])
	}

	/// The mean exists only above shape one; below it the solve must back out rather
	/// than accept an infinity as a residual.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return mean ?? .infinity
		case .variance: return variance ?? .infinity
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiTriangularAlt

extension DistributionTriangular: PercentileParameterisable {

	/// Minimum, maximum, then the mode — the initialiser's own order.
	public static var parameterNames: [String] { ["min", "max", "likely"] }

	/// Builds from the three points.
	///
	/// - Parameter parameters: `min`, `max`, `likely`.
	/// - Returns: The distribution, or `nil` unless `min < likely < max`.
	public static func make(parameters: [Double]) -> DistributionTriangular? {
		guard parameters.count == 3 else { return nil }
		let low = parameters[0], high = parameters[1], mode = parameters[2]
		guard low.isFinite, high.isFinite, mode.isFinite else { return nil }
		guard low < high, mode >= low, mode <= high else { return nil }
		return DistributionTriangular(low: low, high: high, base: mode)
	}

	/// Bounds outside the requested points, with the mode between them.
	///
	/// The inherited default treats the first parameter as a location and the rest as
	/// scales. For a bounded family that is not merely imprecise, it is invalid:
	/// `make` rejects the vector, the solve has no first point, and the fit comes back
	/// `.noSolution` for every input. Bounded families have to state their own start.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let bracket = Self.bracket(of: constraints)
		let mid: Double = (bracket.low + bracket.high) / 2
		let lower: Double = bracket.low
		let upper: Double = bracket.high
		return [[lower, upper, mid], [lower, upper, bracket.low], [lower, upper, bracket.high]]
	}

	/// The mean is the average of the three points.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean:
			let total: Double = parameters[0] + parameters[1] + parameters[2]
			return total / 3
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiUniformAlt

extension DistributionUniform: PercentileParameterisable {

	/// The two bounds.
	public static var parameterNames: [String] { ["min", "max"] }

	/// Builds from the two bounds.
	///
	/// - Parameter parameters: `min` then `max`.
	/// - Returns: The distribution, or `nil` if the range has no width.
	public static func make(parameters: [Double]) -> DistributionUniform? {
		guard parameters.count == 2 else { return nil }
		guard parameters[0].isFinite, parameters[1].isFinite else { return nil }
		guard parameters[1] > parameters[0] else { return nil }
		return DistributionUniform(parameters[0], parameters[1])
	}

	/// Mean and variance are elementary here.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean:
			let total: Double = parameters[0] + parameters[1]
			return total / 2
		case .variance:
			let span: Double = parameters[1] - parameters[0]
			return span * span / 12
		case .standardDeviation:
			let span: Double = parameters[1] - parameters[0]
			let variance: Double = span * span / 12
			return variance.squareRoot()
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiFatigueLifeAlt / PsiFrechetAlt / PsiLogLogisticAlt
//
// Three families that share a signature: shift, scale, shape.

extension DistributionFatigueLife: PercentileParameterisable {

	/// Location, scale, shape.
	public static var parameterNames: [String] { ["loc", "scale", "shape"] }

	/// Builds from location, scale and shape.
	///
	/// - Parameter parameters: `loc`, `scale`, `shape`.
	/// - Returns: The distribution, or `nil` if scale or shape is not positive.
	public static func make(parameters: [Double]) -> DistributionFatigueLife? {
		guard parameters.count == 3 else { return nil }
		return DistributionFatigueLife(location: parameters[0], scale: parameters[1], shape: parameters[2])
	}

	/// A shift below the data, then the data's own scale, then a unit shape.
	///
	/// The shift matters more than the other two: every one of these families has a
	/// hard lower bound at `loc`, so a start above the smallest requested percentile
	/// puts the solve outside the support before it takes a step.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let anchor: Double = Self.locationHint(from: constraints)
		let spread: Double = Self.scaleHint(from: constraints)
		let below: Double = anchor - spread
		let fallback: [[Double]] = Self.defaultInitialGuesses(for: constraints)
		return [[below, spread, 1], [0, spread, 1], [below, spread, 2]] + fallback
	}
}

extension DistributionFrechet: PercentileParameterisable {

	/// Location, scale, shape.
	public static var parameterNames: [String] { ["loc", "scale", "shape"] }

	/// Builds from location, scale and shape.
	///
	/// - Parameter parameters: `loc`, `scale`, `shape`.
	/// - Returns: The distribution, or `nil` if scale or shape is not positive.
	public static func make(parameters: [Double]) -> DistributionFrechet? {
		guard parameters.count == 3 else { return nil }
		return DistributionFrechet(location: parameters[0], scale: parameters[1], shape: parameters[2])
	}

	/// A shift below the data, then the data's own scale, then a unit shape.
	///
	/// The shift matters more than the other two: every one of these families has a
	/// hard lower bound at `loc`, so a start above the smallest requested percentile
	/// puts the solve outside the support before it takes a step.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let anchor: Double = Self.locationHint(from: constraints)
		let spread: Double = Self.scaleHint(from: constraints)
		let below: Double = anchor - spread
		let fallback: [[Double]] = Self.defaultInitialGuesses(for: constraints)
		return [[below, spread, 1], [0, spread, 1], [below, spread, 2]] + fallback
	}

	// No moment override: the Fréchet mean exists only for shape > 1 and the variance
	// only for shape > 2, so the default's refusal is the correct answer here.
}

extension DistributionLogLogistic: PercentileParameterisable {

	/// Location, scale, shape.
	public static var parameterNames: [String] { ["loc", "scale", "shape"] }

	/// Builds from location, scale and shape.
	///
	/// - Parameter parameters: `loc`, `scale`, `shape`.
	/// - Returns: The distribution, or `nil` if scale or shape is not positive.
	public static func make(parameters: [Double]) -> DistributionLogLogistic? {
		guard parameters.count == 3 else { return nil }
		return DistributionLogLogistic(location: parameters[0], scale: parameters[1], shape: parameters[2])
	}

	/// A shift below the data, then the data's own scale, then a unit shape.
	///
	/// The shift matters more than the other two: every one of these families has a
	/// hard lower bound at `loc`, so a start above the smallest requested percentile
	/// puts the solve outside the support before it takes a step.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let anchor: Double = Self.locationHint(from: constraints)
		let spread: Double = Self.scaleHint(from: constraints)
		let below: Double = anchor - spread
		let fallback: [[Double]] = Self.defaultInitialGuesses(for: constraints)
		return [[below, spread, 1], [0, spread, 1], [below, spread, 2]] + fallback
	}
}

// MARK: PsiPertAlt

extension DistributionPert: PercentileParameterisable {

	/// The three points. Lambda stays at the classical four; a PERT whose weight is
	/// also free is `DistributionBetaSubjective`, which has its own row.
	public static var parameterNames: [String] { ["min", "likely", "max"] }

	/// Builds from the three points.
	///
	/// - Parameter parameters: `min`, `likely`, `max`.
	/// - Returns: The distribution, or `nil` unless the points are ordered.
	public static func make(parameters: [Double]) -> DistributionPert? {
		guard parameters.count == 3 else { return nil }
		return DistributionPert(min: parameters[0], likely: parameters[1], max: parameters[2])
	}

	/// Bounds outside the requested points, with the mode between them.
	///
	/// Bounded like ``DistributionTriangular``, and unusable with the inherited default
	/// for the same reason — see the note there.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let bracket = Self.bracket(of: constraints)
		let mid: Double = (bracket.low + bracket.high) / 2
		let lower: Double = bracket.low
		let upper: Double = bracket.high
		return [[lower, mid, upper], [lower, bracket.low, upper], [lower, bracket.high, upper]]
	}

	/// The PERT mean is the classical `(min + 4·likely + max) / 6`.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return mean
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiBetaGenAlt

extension DistributionBetaGeneralised: PercentileParameterisable {

	/// Two shapes then the two bounds.
	public static var parameterNames: [String] { ["shape1", "shape2", "min", "max"] }

	/// Builds from two shapes and two bounds.
	///
	/// - Parameter parameters: `shape1`, `shape2`, `min`, `max`.
	/// - Returns: The distribution, or `nil` if a shape is not positive or the range has no width.
	public static func make(parameters: [Double]) -> DistributionBetaGeneralised? {
		guard parameters.count == 4 else { return nil }
		return DistributionBetaGeneralised(shape1: parameters[0], shape2: parameters[1],
										   min: parameters[2], max: parameters[3])
	}

	/// Shapes start at one — a flat beta — and the bounds bracket the requested points.
	///
	/// The default's spread is no use for the last two parameters, which are bounds
	/// rather than scales: a bound that starts inside the data makes every percentile
	/// above it unreachable, and the residual has no gradient pointing out.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let targets: [Double] = constraints.map { Self.target(of: $0) }
		let low: Double = targets.min() ?? 0
		let high: Double = targets.max() ?? 1
		let width: Double = high - low
		let pad: Double = width > 0 ? width : 1
		return [[1, 1, low - pad, high + pad], [2, 2, low - pad, high + pad], [1, 2, low - pad, high + pad]]
	}

	/// The mean is the beta mean mapped onto the range.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return mean
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}
}

// MARK: PsiInvNormalAlt
//
// Risk Solver's "inverse normal" is the Wald — the inverse Gaussian — not the
// inverse of the normal CDF. Reading it the other way would have produced a
// conformance that fitted the wrong family under a plausible-looking name.

extension DistributionInverseGaussian: PercentileParameterisable {

	/// Mean then the shape.
	public static var parameterNames: [String] { ["mu", "lambda"] }

	/// Builds from the mean and shape.
	///
	/// - Parameter parameters: `mu` then `lambda`.
	/// - Returns: The distribution, or `nil` if either is not positive.
	public static func make(parameters: [Double]) -> DistributionInverseGaussian? {
		guard parameters.count == 2 else { return nil }
		return DistributionInverseGaussian(mu: parameters[0], lambda: parameters[1])
	}

	/// Both parameters are strictly positive, so neither the default's location hint
	/// nor its narrower multipliers are safe starts; derive both from the data's scale.
	///
	/// - Parameter constraints: The constraints being fitted.
	/// - Returns: Starting vectors, best first.
	public static func initialGuesses(for constraints: [ParameterConstraint<Double>]) -> [[Double]] {
		let anchor: Double = Swift.abs(Self.locationHint(from: constraints))
		let spread: Double = Self.scaleHint(from: constraints)
		let mu: Double = anchor > 0 ? anchor : 1
		let lambda: Double = spread > 0 ? spread : 1
		return [[mu, lambda], [mu, mu], [mu, lambda * 10], [mu, lambda / 10]]
	}

	/// `mu` is the mean by construction and the variance is `mu³/lambda`.
	///
	/// - Parameters:
	///   - constraint: The constraint being evaluated.
	///   - parameters: The candidate vector.
	/// - Returns: The value the constraint asks about.
	/// - Throws: ``ParameterFitError`` for a constraint this family cannot answer.
	public func realise(_ constraint: ParameterConstraint<Double>, parameters: [Double]) throws -> Double {
		switch constraint {
		case .mean: return parameters[0]
		case .variance: return Self.waldVariance(parameters)
		case .standardDeviation: return Self.waldVariance(parameters).squareRoot()
		default: return try defaultRealise(constraint, parameters: parameters)
		}
	}

	/// The Wald variance, `mu³ / lambda`, bound in stages so the generic solver does
	/// not have to type-check a four-operator expression.
	///
	/// - Parameter parameters: `mu` then `lambda`.
	/// - Returns: The variance, or infinity if the shape has collapsed to zero.
	private static func waldVariance(_ parameters: [Double]) -> Double {
		let mu: Double = parameters[0]
		let lambda: Double = parameters[1]
		guard lambda != 0 else { return .infinity }
		let cubed: Double = mu * mu * mu
		return cubed / lambda
	}
}
