import Foundation
import Numerics

/// Fit a random intercept-and-slope linear mixed-effects model via REML.
///
/// Estimates fixed effects (beta) and the random-effects covariance matrix G plus residual
/// variance for the model:
/// ```
/// y_ij = x_ij' * beta + u_0i + u_1i * z_ij + e_ij
/// ```
/// where `(u_0i, u_1i) ~ N(0, G)` with `G` a 2x2 covariance and `e_ij ~ N(0, sigma_e²)`.
///
/// ## This delegates to ``fitGeneralLME(_:maxIterations:tolerance:)``
///
/// A random intercept and slope is the general model with `Z = [1, z]`, so that is what
/// this builds and passes along. It used to carry its own REML fit — roughly nine hundred
/// lines of EM warm-up, AI-REML scoring, per-group `V_i` assembly and standard errors —
/// running the same algorithm as `fitGeneralLME` against a 2x2 covariance instead of an
/// `r x r` one.
///
/// **This is the second time this directory has made that trade.**
/// ``fitRandomIntercept(_:maxIterations:tolerance:)`` carried its own Fisher scoring until
/// it was found to be computing ML while documenting REML — up to 23% out on the
/// random-effect variance and 83% on the residual variance against statsmodels, with all
/// fifteen of its tests passing throughout, because every one asserted a property an ML fit
/// satisfies just as well. The fix was to delete the implementation and delegate. The
/// coverage proposal states the rule this follows: *a second implementation that can
/// disagree with the first — generalise one and have the others call it.*
///
/// Nothing here was known to be wrong. The two agreed, measured on the suite's own fixture,
/// to eleven significant figures on the variance components and to the last bit on beta,
/// both converging in twelve iterations. That is the argument for delegating rather than
/// against it: two implementations that agree today are two that can disagree tomorrow, and
/// only one of them is checked against statsmodels.
///
/// The signature, the validation, the errors and the result type are unchanged.
///
/// - Parameters:
///   - model: The random slope model specification.
///   - maxIterations: Maximum iterations (default 100).
///   - tolerance: Convergence tolerance on the variance components (default 1e-9).
///
///     Must track ``fitGeneralLME(_:maxIterations:tolerance:)``, which this passes it
///     straight to: a wrapper left on the old 1e-8 stops the shared loop an iteration
///     earlier than calling the general fitter directly, and the two return different
///     numbers for the same model. See that function for why the value is 1e-9.
/// - Returns: A ``RandomSlopeResult`` with fixed effects, the 2x2 covariance, BLUPs and fit
///   statistics.
/// - Throws: ``BusinessMathError/mismatchedDimensions(message:expected:actual:)`` when the
///   design, response and grouping disagree on length;
///   ``BusinessMathError/insufficientData(required:actual:context:)`` with fewer than two
///   groups or too few observations for the fixed effects;
///   ``BusinessMathError/invalidInput(message:value:expectedRange:)`` when `slopeColumn` is
///   not a column of the design.
public func fitRandomSlope<T: Real>(
	_ model: RandomSlopeModel<T>,
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(1_000_000_000)
) throws -> RandomSlopeResult<T> where T: BinaryFloatingPoint {

	let y = model.response
	let grouping = model.grouping
	let N = y.count
	let p = model.fixedEffects.columns
	let slopeCol = model.slopeColumn

	// --- Validation ---
	//
	// Kept here rather than delegated. `fitGeneralLME` cannot raise the `slopeColumn`
	// error, and its messages name a design matrix `Z` the caller never supplied — so the
	// diagnostics stay in the vocabulary of the model that was actually asked for.
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
			context: "Random slope model requires at least 2 groups")
	}
	guard N > p else {
		throw BusinessMathError.insufficientData(
			required: p + 1, actual: N,
			context: "Observations must exceed number of fixed-effects parameters")
	}
	guard slopeCol >= 0 && slopeCol < p else {
		throw BusinessMathError.invalidInput(
			message: "slopeColumn must be in [0, \(p - 1)]",
			value: "\(slopeCol)",
			expectedRange: "0 ..< \(p)")
	}

	// Z = [1, z]: a random intercept and a random slope on the nominated column.
	var zRows = Array(repeating: Array(repeating: T.zero, count: 2), count: N)
	for i in 0..<N {
		zRows[i][0] = T(1)
		zRows[i][1] = model.fixedEffects[i, slopeCol]
	}
	let z = try DenseMatrix(zRows)

	let general = try fitGeneralLME(
		GeneralLMEModel(
			fixedEffects: model.fixedEffects,
			randomEffectsDesign: z,
			response: y,
			grouping: grouping,
			randomEffectsPerGroup: 2),
		maxIterations: maxIterations,
		tolerance: tolerance)

	let varianceIntercept: T = general.gMatrix[0, 0]
	let varianceSlope: T = general.gMatrix[1, 1]
	let covariance: T = general.gMatrix[0, 1]

	// The correlation between the two random effects. Zero when either variance is zero —
	// a degenerate G rather than a division to guard against, and a real answer: an effect
	// with no variance cannot correlate with anything.
	let varianceProduct: T = varianceIntercept * varianceSlope
	let correlation: T = varianceProduct > T.zero
		? covariance / T.sqrt(varianceProduct)
		: T.zero

	// The general result carries one row of random effects per group, two columns wide.
	var randomIntercepts = [T]()
	var randomSlopes = [T]()
	randomIntercepts.reserveCapacity(general.randomEffects.rows)
	randomSlopes.reserveCapacity(general.randomEffects.rows)
	for g in 0..<general.randomEffects.rows {
		randomIntercepts.append(general.randomEffects[g, 0])
		randomSlopes.append(general.randomEffects[g, 1])
	}

	return RandomSlopeResult(
		beta: general.beta,
		standardErrors: general.standardErrors,
		tStatistics: general.tStatistics,
		pValues: general.pValues,
		varianceIntercept: varianceIntercept,
		varianceSlope: varianceSlope,
		covarianceInterceptSlope: covariance,
		correlationInterceptSlope: correlation,
		varianceResidual: general.varianceResidual,
		remlLogLikelihood: general.remlLogLikelihood,
		aic: general.aic,
		bic: general.bic,
		randomIntercepts: randomIntercepts,
		randomSlopes: randomSlopes,
		residuals: general.residuals,
		marginalResiduals: general.marginalResiduals,
		fittedValues: general.fittedValues,
		observations: general.observations,
		groups: general.groups,
		fixedEffectsCount: general.fixedEffectsCount,
		iterations: general.iterations,
		converged: general.converged)
}

// The REML machinery that used to live here — `buildVi`, `slopeGroupDesign`,
// `slopeGLSEstimate`, `slopeEMUpdate`, `slopeAIREMLUpdate` and `slopeFixedEffectsSE`, about
// nine hundred lines — is gone rather than left unreferenced. It ran the same algorithm as
// `fitGeneralLME` against a 2x2 covariance, including its own copy of the projection fix
// for the statsmodels discrepancy. Two copies of a correction is one that can be made
// twice and applied once.
