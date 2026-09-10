//
//  ETSParameterSearch.swift
//  BusinessMath
//
//  Step 3 of PROPOSAL_ets_fitting.md — searching for alpha, beta and gamma.
//
//  The objective is the in-sample sum of squared one-step-ahead residuals, which is the
//  standard for ETS (Hyndman). Excel does not publish its objective, so this is chosen on
//  the literature rather than to match, and no test in this tier asserts a number a
//  spreadsheet would produce.
//
//  The box `[0, 1]³` is held by reparameterisation rather than by penalty. A penalty
//  weight has no principled value here: the objective is a sum of squared residuals, so it
//  scales with the square of the series, and data in units of 1 and data in units of 10⁶
//  put objectives twelve orders apart. Parameterising the weight would hand the caller a
//  constant they have no basis to choose — on a fitter whose whole purpose is that a
//  caller should not have to supply constants like `alpha: 0.2`. Under the transform an
//  infeasible point cannot be proposed at all, so the box is a property of the
//  parameterisation instead of a number someone picked.
//

import Foundation
import Numerics

// MARK: - Objective

/// In-sample sum of squared one-step-ahead residuals for one Holt-Winters parameterisation.
///
/// Returns `.infinity` when the model cannot be trained on `values` at all — a point the
/// search must be able to see as hopeless without the whole search throwing.
///
/// - Parameters:
///   - values: The training observations.
///   - alpha: Level smoothing.
///   - beta: Trend smoothing.
///   - gamma: Seasonal smoothing.
///   - seasonLength: Cycle length; `1` for a non-seasonal fit.
/// - Returns: The residual sum of squares, or `.infinity` if it cannot be computed.
func etsSumSquaredResiduals<T: Real & Sendable & Codable & BinaryFloatingPoint>(
	values: [T],
	alpha: T,
	beta: T,
	gamma: T,
	seasonLength: Int
) -> Double {
	// `trainIfSufficient` rather than `train(values:)`: the model's only failure is a
	// length precondition, and an error here could only be caught and discarded — the
	// shape that hides real failures. Taking the fact as a value keeps the discard out of
	// the code entirely.
	var model = HoltWintersModel<T>(
		alpha: alpha, beta: beta, gamma: gamma, seasonalPeriods: seasonLength)
	guard model.trainIfSufficient(values: values) else { return Double.infinity }
	var sum = 0.0
	for residual in model.residuals {
		let scaled = Double(residual)
		sum += scaled * scaled
	}
	return sum.isFinite ? sum : Double.infinity
}

// MARK: - The reparameterisation

/// How far the unbounded search coordinate is allowed to travel before it is treated as
/// having saturated. `1 / (1 + e^{-30})` is already `1` to within `1e-13`.
let etsCoordinateLimit = 30.0

/// Maps an unbounded search coordinate into the feasible smoothing box via the logistic.
///
/// - Parameters:
///   - coordinate: A point in `ℝ`.
///   - lower: Lower edge of the feasible box.
///   - upper: Upper edge of the feasible box.
/// - Returns: A smoothing value in `(lower, upper)`.
func etsFeasibleParameter(_ coordinate: Double, lower: Double, upper: Double) -> Double {
	let span = upper - lower
	guard span > 0 else { return lower }
	let denominator = 1.0 + Foundation.exp(-coordinate)
	guard denominator > 0 else { return lower }
	let sigma = 1.0 / denominator
	return lower + span * sigma
}

/// The inverse of ``etsFeasibleParameter(_:lower:upper:)`` — a starting coordinate for a
/// smoothing value the caller already has in mind.
///
/// - Parameters:
///   - parameter: A smoothing value, clamped into the box before inversion.
///   - lower: Lower edge of the feasible box.
///   - upper: Upper edge of the feasible box.
/// - Returns: The coordinate in `ℝ` that maps to `parameter`.
func etsSearchCoordinate(_ parameter: Double, lower: Double, upper: Double) -> Double {
	let span = upper - lower
	guard span > 0 else { return 0 }
	let clamped = Swift.min(Swift.max(parameter, lower), upper)
	let offset = clamped - lower
	let unit = offset / span
	guard unit > 0 else { return -etsCoordinateLimit }
	let complement = 1.0 - unit
	guard complement > 0 else { return etsCoordinateLimit }
	let ratio = unit / complement
	return Foundation.log(ratio)
}

/// Snaps a smoothing value to the true `[0, 1]` boundary when the transform has saturated.
///
/// The feasible box is a hair inside `[0, 1]` because the logistic reaches its limits only
/// asymptotically. Left alone, a series whose optimum is `alpha = 1` would be reported as
/// `0.9999` — and that is not a curiosity kept in for completeness: **`alpha = 1` is the
/// optimum for a random walk**, where the best forecast of tomorrow is today's value and no
/// smoothing helps. Any series close to a random walk lands there, which is most financial
/// series, so the un-snapped answer would show up regularly and read to a reader comparing
/// against a spreadsheet like a rounding bug.
///
/// - Parameters:
///   - parameter: A smoothing value inside the feasible box.
///   - lower: Lower edge of the feasible box.
///   - upper: Upper edge of the feasible box.
/// - Returns: `0`, `1`, or `parameter` unchanged.
func etsSnappedToBoundary(_ parameter: Double, lower: Double, upper: Double) -> Double {
	let span = upper - lower
	guard span > 0 else { return parameter }
	let margin = span * 1e-6
	let upperGate = upper - margin
	if parameter >= upperGate { return 1.0 }
	let lowerGate = lower + margin
	if parameter <= lowerGate { return 0.0 }
	return parameter
}

// MARK: - The search

/// What the smoothing-parameter search found.
struct ETSParameterSearchResult: Sendable {
	/// Fitted level smoothing.
	let alpha: Double
	/// Fitted trend smoothing.
	let beta: Double
	/// Fitted seasonal smoothing; zero for a non-seasonal fit.
	let gamma: Double
	/// The in-sample residual sum of squares at the reported parameters.
	let objective: Double
	/// Whether the simplex that produced the answer met its tolerance.
	let converged: Bool
	/// How many times the objective was evaluated, scan and simplex together.
	let evaluations: Int
}

/// Searches for the smoothing parameters that minimise the in-sample residual sum of
/// squares.
///
/// A coarse deterministic scan seeds several Nelder-Mead restarts, which is what makes the
/// answer robust enough to beat a brute-force grid rather than merely to be a local
/// minimum near wherever the search happened to start. **Non-seasonal fits search two
/// parameters, not three**: with a cycle length of `1` gamma has nothing to smooth, and
/// searching it would wander over a flat dimension and report a meaningless value.
///
/// The whole search is deterministic — a coarse scan and a simplex from a fixed initial
/// geometry have no randomness in them — so a fit is reproducible by construction rather
/// than by seeding.
///
/// - Parameters:
///   - values: The training observations. Must be long enough to train on.
///   - seasonLength: Cycle length; `1` for a non-seasonal fit.
///   - config: Search bounds and budget.
/// - Returns: The best feasible parameters found, and what the search spent finding them.
func searchETSParameters<T: Real & Sendable & Codable & BinaryFloatingPoint>(
	values: [T],
	seasonLength: Int,
	config: ETSFitConfig
) -> ETSParameterSearchResult {

	let isSeasonal = seasonLength > 1
	let lower = config.lowerBound
	let upper = config.upperBound

	func clampedToBox(_ parameter: Double) -> Double {
		Swift.min(Swift.max(parameter, lower), upper)
	}

	func objective(alpha: Double, beta: Double, gamma: Double) -> Double {
		let a: T = T(alpha)
		let b: T = T(beta)
		let g: T = T(gamma)
		return etsSumSquaredResiduals(
			values: values, alpha: a, beta: b, gamma: g, seasonLength: seasonLength)
	}

	// The coarse scan. Seven values per searched dimension: 343 trainings for a seasonal
	// fit, 49 for a non-seasonal one, which is nothing beside the simplex runs that follow.
	let seeds: [Double] = [0.02, 0.2, 0.35, 0.5, 0.65, 0.8, 0.98]
	let gammaSeeds: [Double] = isSeasonal ? seeds : [0.0]

	var bestAlpha = clampedToBox(0.5)
	var bestBeta = clampedToBox(0.5)
	var bestGamma = isSeasonal ? clampedToBox(0.5) : 0.0
	var bestValue = objective(alpha: bestAlpha, beta: bestBeta, gamma: bestGamma)
	var evaluations = 1

	var scanned: [(alpha: Double, beta: Double, gamma: Double, value: Double)] = []
	scanned.reserveCapacity(seeds.count * seeds.count * gammaSeeds.count)
	for seedAlpha in seeds {
		let alpha = clampedToBox(seedAlpha)
		for seedBeta in seeds {
			let beta = clampedToBox(seedBeta)
			for seedGamma in gammaSeeds {
				let gamma = isSeasonal ? clampedToBox(seedGamma) : 0.0
				let value = objective(alpha: alpha, beta: beta, gamma: gamma)
				evaluations += 1
				scanned.append((alpha: alpha, beta: beta, gamma: gamma, value: value))
				if value < bestValue {
					bestValue = value
					bestAlpha = alpha
					bestBeta = beta
					bestGamma = gamma
				}
			}
		}
	}

	// The simplex, over the unbounded coordinates rather than over the parameters.
	let optimizer = NelderMead<VectorN<Double>>(
		config: NelderMeadConfig(tolerance: config.tolerance, maxIterations: config.maxIterations))

	let transformedObjective: (VectorN<Double>) -> Double = { vector in
		let coordinates = vector.toArray()
		guard coordinates.count >= 2 else { return Double.infinity }
		let alpha = etsFeasibleParameter(coordinates[0], lower: lower, upper: upper)
		let beta = etsFeasibleParameter(coordinates[1], lower: lower, upper: upper)
		var gamma = 0.0
		if isSeasonal, coordinates.count >= 3 {
			gamma = etsFeasibleParameter(coordinates[2], lower: lower, upper: upper)
		}
		return objective(alpha: alpha, beta: beta, gamma: gamma)
	}

	var converged = false
	let ranked = scanned.sorted { $0.value < $1.value }
	for start in ranked.prefix(4) {
		var coordinates: [Double] = [
			etsSearchCoordinate(start.alpha, lower: lower, upper: upper),
			etsSearchCoordinate(start.beta, lower: lower, upper: upper)
		]
		if isSeasonal {
			coordinates.append(etsSearchCoordinate(start.gamma, lower: lower, upper: upper))
		}
		let result = optimizer.optimizeDetailed(
			objective: transformedObjective, initialGuess: VectorN(coordinates))
		evaluations += result.evaluations
		let solution = result.solution.toArray()
		guard solution.count >= 2 else { continue }
		// `<=` rather than `<`: a restart that merely ties has still refined the coarse
		// scan point onto the continuum, and carries a convergence verdict the scan has
		// no way to produce. Ties are broken by the fixed restart order, so this stays
		// deterministic.
		guard result.value <= bestValue else { continue }
		bestValue = result.value
		bestAlpha = etsFeasibleParameter(solution[0], lower: lower, upper: upper)
		bestBeta = etsFeasibleParameter(solution[1], lower: lower, upper: upper)
		if isSeasonal, solution.count >= 3 {
			bestGamma = etsFeasibleParameter(solution[2], lower: lower, upper: upper)
		} else {
			bestGamma = 0.0
		}
		converged = result.converged
	}

	// Snap first, then re-measure, so the reported objective is the objective of the
	// parameters actually reported — and of the model the caller is handed.
	let snappedAlpha = etsSnappedToBoundary(bestAlpha, lower: lower, upper: upper)
	let snappedBeta = etsSnappedToBoundary(bestBeta, lower: lower, upper: upper)
	let snappedGamma = isSeasonal
		? etsSnappedToBoundary(bestGamma, lower: lower, upper: upper)
		: 0.0
	let finalObjective = objective(alpha: snappedAlpha, beta: snappedBeta, gamma: snappedGamma)
	evaluations += 1

	return ETSParameterSearchResult(
		alpha: snappedAlpha,
		beta: snappedBeta,
		gamma: snappedGamma,
		objective: finalObjective,
		converged: converged,
		evaluations: evaluations)
}
