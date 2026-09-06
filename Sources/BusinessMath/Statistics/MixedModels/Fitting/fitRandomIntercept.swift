import Foundation
import Numerics

/// Fit a random-intercept linear mixed-effects model via REML.
///
/// Estimates fixed effects (beta) and variance components (sigma_u², sigma_e²)
/// for the model:
/// ```
/// y_ij = x_ij' * beta + u_i + e_ij
/// ```
/// where u_i ~ N(0, sigma_u²) and e_ij ~ N(0, sigma_e²).
///
/// ## This delegates to ``fitGeneralLME(_:maxIterations:tolerance:)``
///
/// A random intercept is the general model with `Z = 1`, so that is what this builds and
/// passes along. It used to carry its own Fisher scoring on the profiled REML criterion,
/// about four hundred lines of it, and **that implementation computed ML rather than
/// REML**: its trace term was `(n_i − 1)/sigma_e² + 1/a_i`, which is `tr(V_i⁻¹)`, with
/// nothing subtracted for the `p` estimated fixed effects. The scoring routine was not
/// even passed the design matrix, so it could not have applied the correction.
///
/// Measured against statsmodels REML on the six designs in `mixedModels.json`, that cost
/// up to 23% on the random-effect variance and up to 83% on the residual variance. Its
/// fifteen tests all passed throughout, because every one of them asserted a property an
/// ML fit satisfies just as well as a REML fit.
///
/// The alternative was to add the projection term to a second REML implementation and
/// keep both. The coverage proposal names that failure mode directly — "a second
/// implementation that can disagree with the first. Generalise one and have the others
/// call it" — and this is the case it was describing. `fitGeneralLME` is checked against
/// statsmodels to about 1e-5; a duplicate would have to be checked again, and would
/// drift again.
///
/// The signature, the errors and the result type are unchanged.
///
/// - Parameters:
///   - model: The random intercept model specification.
///   - maxIterations: Maximum iterations (default 100).
///   - tolerance: Convergence tolerance (default 1e-8).
/// - Returns: A ``RandomInterceptResult`` with all estimates and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups
///   or total observations do not exceed the number of fixed-effects parameters.
///   `BusinessMathError.mismatchedDimensions` if X rows != y length != groups length.
public func fitRandomIntercept<T: Real>(
	_ model: RandomInterceptModel<T>,
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(100_000_000)
) throws -> RandomInterceptResult<T> where T: BinaryFloatingPoint {

	let y = model.response
	let grouping = model.grouping
	let N = y.count

	// Validated here rather than left to the general fitter so the messages name the
	// random-intercept model the caller actually used.
	guard model.fixedEffects.rows == N else {
		throw BusinessMathError.mismatchedDimensions(
			message: "X.rows must equal y.length",
			expected: "\(N)", actual: "\(model.fixedEffects.rows)")
	}
	guard grouping.groups.count == N else {
		throw BusinessMathError.mismatchedDimensions(
			message: "GroupingFactor length must equal y.length",
			expected: "\(N)", actual: "\(grouping.groups.count)")
	}
	guard grouping.groupCount >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: grouping.groupCount,
			context: "Random intercept model requires at least 2 groups")
	}

	let p = model.fixedEffects.columns
	guard N > p else {
		throw BusinessMathError.insufficientData(
			required: p + 1, actual: N,
			context: "Observations must exceed number of fixed-effects parameters")
	}

	// Z is a single column of ones: one random intercept per group.
	let intercepts = DenseMatrix<T>(rows: N, columns: 1, repeating: T(1))

	let general = try fitGeneralLME(
		GeneralLMEModel(
			fixedEffects: model.fixedEffects,
			randomEffectsDesign: intercepts,
			response: y,
			grouping: grouping,
			randomEffectsPerGroup: 1),
		maxIterations: maxIterations,
		tolerance: tolerance)

	let varianceRandom: T = general.gMatrix[0, 0]
	let varianceResidual: T = general.varianceResidual

	// The intraclass correlation: the share of total variance sitting between groups.
	// Zero when there is no between-group variance to speak of, which is a real answer
	// rather than a division to guard against — both components are non-negative and a
	// total of zero means a degenerate response.
	let total: T = varianceRandom + varianceResidual
	let icc: T = total > T.zero ? varianceRandom / total : T.zero

	// The general result carries one column of random effects per group; flatten it,
	// since a random-intercept model has exactly one.
	var blups = [T]()
	blups.reserveCapacity(general.randomEffects.rows)
	for g in 0..<general.randomEffects.rows {
		blups.append(general.randomEffects[g, 0])
	}

	return RandomInterceptResult(
		beta: general.beta,
		standardErrors: general.standardErrors,
		tStatistics: general.tStatistics,
		pValues: general.pValues,
		varianceRandom: varianceRandom,
		varianceResidual: varianceResidual,
		icc: icc,
		remlLogLikelihood: general.remlLogLikelihood,
		aic: general.aic,
		bic: general.bic,
		randomEffects: blups,
		residuals: general.residuals,
		marginalResiduals: general.marginalResiduals,
		fittedValues: general.fittedValues,
		observations: general.observations,
		groups: general.groups,
		fixedEffectsCount: general.fixedEffectsCount,
		iterations: general.iterations,
		converged: general.converged)
}

// The Fisher scoring machinery that used to live here — `GLSResult`, `olsEstimate`,
// `glsEstimate`, `FisherUpdate`, `fisherScoringUpdate` and `fixedEffectsSE`, about 370
// lines — is gone rather than left unreferenced. It was the implementation that computed
// ML while claiming REML, and dead code with a known defect in it is an invitation to
// call it again. `fitGeneralLME` does this work now, and is checked against statsmodels.
