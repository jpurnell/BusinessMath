import Foundation
import Numerics

/// The largest halved step along `delta` that keeps the variance parameters admissible.
///
/// AI-REML computes a Newton-like direction from the average information matrix, and nothing in
/// that calculation knows the parameters are constrained. A full step can easily put the residual
/// variance at or below zero, or make `G` indefinite — both of which are not merely inaccurate
/// but *meaningless*, and would make the next iteration's Cholesky of `V_i` fail.
///
/// So the step is halved until the candidate is admissible, or twenty times, whichever comes
/// first. Twenty halvings is a factor of `2^-20`; a direction still infeasible there is not going
/// to become feasible, and the caller takes the tiny step and lets the convergence test stop it.
///
/// Note that the returned step is used even when no feasible candidate was found — this function
/// reports how far it got, it does not decide whether to move. The caller clamps `sigmaE2` at
/// `ulpOfOne` and repairs `G`'s diagonal afterwards, which is what makes that safe.
///
/// - Parameters:
///   - gArr: The current random-effects covariance.
///   - sigmaE2: The current residual variance.
///   - delta: The AI-REML direction: `delta[0]` for `sigmaE2`, then the upper triangle of `G`
///     in row-major order.
///   - r: Random effects per group.
/// - Returns: The step multiplier, `1` down to `2^-20`.
internal func generalFeasibleStep<T: Real & Sendable>(
	from gArr: [[T]], sigmaE2: T, delta: [T], r: Int
) -> T where T: BinaryFloatingPoint {
	var step = T(1)
	for _ in 0..<20 {
		let candE = sigmaE2 + step * delta[0]
		var candG = gArr
		var idx = 1
		for i in 0..<r {
			for j in i..<r {
				candG[i][j] = gArr[i][j] + step * delta[idx]
				candG[j][i] = candG[i][j]
				idx += 1
			}
		}

		let feasible = candE > T.ulpOfOne && generalIsPSD(candG, r: r)
		if feasible { break }
		step = step / T(2)
	}
	return step
}

/// The best linear unbiased predictors of the random effects, one vector per group.
///
/// `u_g = G Z_g' V_g^{-1} r_g`, where `r_g` are the **marginal** residuals — the response less
/// the fixed-effect fit only. That is what makes these predictions rather than estimates: each
/// group's deviation is shrunk toward zero by `G Z' V^{-1}`, and a group with few observations
/// or a large residual variance is shrunk further. A group mean would not be.
///
/// Computed per group because `V` is block diagonal: `V_g^{-1}` is a `n_g x n_g` solve, not an
/// `N x N` one.
///
/// - Parameters:
///   - zData: The random-effects design, by observation.
///   - marginalResiduals: `y - X beta`, by observation.
///   - r: Random effects per group.
///   - m: Group count.
///   - groupIdx: Row indices per group.
///   - gArr: The converged random-effects covariance.
///   - sigmaE2: The converged residual variance.
/// - Returns: One `r`-vector per group.
/// - Throws: From ``DenseMatrix/choleskySolve(_:)`` when a group's `V_g` is not positive
///   definite, which a positive `sigmaE2` and a PSD `G` together rule out.
internal func generalBLUPs<T: Real & Sendable>(
	zData: [[T]], marginalResiduals: [T],
	r: Int, m: Int, groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T
) throws -> [[T]] where T: BinaryFloatingPoint {
	var blups = Array(repeating: Array(repeating: T.zero, count: r), count: m)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var ri = Array(repeating: T.zero, count: nig)
		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			ri[localIdx] = marginalResiduals[obsIdx]
			for k in 0..<r {
				zi[localIdx][k] = zData[obsIdx][k]
			}
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)
		let viInvR = try viMat.choleskySolve(ri)

		// Z_g' V_g^{-1} r_g (r-vector)
		var ztViInvR = Array(repeating: T.zero, count: r)
		for j in 0..<nig {
			for k in 0..<r {
				ztViInvR[k] += zi[j][k] * viInvR[j]
			}
		}

		// G * (Z_g' V_g^{-1} r_g)
		for k in 0..<r {
			var val = T.zero
			for l in 0..<r {
				val += gArr[k][l] * ztViInvR[l]
			}
			blups[g][k] = val
		}
	}

	return blups
}

/// Refuses a model whose pieces do not describe the same problem.
///
/// Every way this fitter can decline a model, in one place. Separated from the estimator
/// because a 380-line procedure that begins with six guards reads as though the guards are part
/// of the arithmetic, and they are not — they are the contract, and the arithmetic below is
/// entitled to assume it.
///
/// - Parameters:
///   - model: The model to check.
///   - N: Observation count, taken from the response.
///   - p: Fixed-effect count.
///   - r: Random effects per group.
/// - Throws: `BusinessMathError.mismatchedDimensions` when the design matrices, grouping and
///   response disagree on `N` or `r`; `BusinessMathError.insufficientData` with fewer than two
///   groups, or when the fixed effects are not identified because `N <= p`.
///
/// - Note: The message strings are part of the contract — `GeneralLMETests` asserts them
///   verbatim — so they are reproduced here exactly as they were written inline. Rewording one
///   during this extraction broke four tests, which is the right outcome: an error message a
///   caller can match on is an interface, not a comment.
internal func validateGeneralLME<T: Real>(
	_ model: GeneralLMEModel<T>, N: Int, p: Int, r: Int
) throws where T: BinaryFloatingPoint {
	guard model.fixedEffects.rows == N else {
		throw BusinessMathError.mismatchedDimensions(
			message: "X.rows must equal y.length",
			expected: "\(N)", actual: "\(model.fixedEffects.rows)")
	}
	guard model.randomEffectsDesign.rows == N else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Z.rows must equal y.length",
			expected: "\(N)", actual: "\(model.randomEffectsDesign.rows)")
	}
	guard model.randomEffectsDesign.columns == r else {
		throw BusinessMathError.mismatchedDimensions(
			message: "Z.columns must equal randomEffectsPerGroup",
			expected: "\(r)", actual: "\(model.randomEffectsDesign.columns)")
	}
	guard model.grouping.groups.count == N else {
		throw BusinessMathError.mismatchedDimensions(
			message: "GroupingFactor length must equal y.length",
			expected: "\(N)", actual: "\(model.grouping.groups.count)")
	}
	guard model.grouping.groupCount >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: model.grouping.groupCount,
			context: "General LME model requires at least 2 groups")
	}
	guard N > p else {
		throw BusinessMathError.insufficientData(
			required: p + 1, actual: N,
			context: "Observations must exceed number of fixed-effects parameters")
	}
}

/// A starting value for the variance of one random slope, from between-group regressions.
///
/// Fits the OLS residuals on covariate `k` **within each group**, then takes the sample variance
/// of those per-group slopes. If the slope really does vary by group, that spread is what the
/// random-effects covariance has to explain, so it is where the search should begin.
///
/// The estimate is a starting value and nothing more — EM and then AI-REML move off it — so what
/// matters is that it is finite and positive. A group with one observation supports no slope and
/// is skipped; a group whose covariate does not vary makes the normal equation singular and
/// contributes a zero rather than an infinity; and a spread that comes out at zero falls back to
/// `0.1` rather than starting the search on a boundary it cannot leave.
///
/// - Parameters:
///   - zData: The random-effects design, by observation.
///   - residuals: OLS residuals, which is what the group slopes are fitted to.
///   - groupIdx: Row indices per group.
///   - column: Which random effect to estimate, `1 ..< r` — the intercept is handled separately
///     from the ANOVA decomposition.
///   - m: Group count.
/// - Returns: The between-group variance of the slope, or `0.1` where it is not positive.
internal func generalSlopeVarianceStart<T: Real>(
	zData: [[T]], residuals: [T], groupIdx: [[Int]], column k: Int, m: Int
) -> T where T: BinaryFloatingPoint {
	var groupCoeffs = Array(repeating: T.zero, count: m)
	var coeffGrandMean = T.zero
	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		guard nig > T(1) else { continue }
		var sumZ = T.zero
		var sumR = T.zero
		var sumZR = T.zero
		var sumZZ = T.zero
		for idx in indices {
			let z = zData[idx][k]
			let res = residuals[idx]
			sumZ += z
			sumR += res
			sumZR += z * res
			sumZZ += z * z
		}
		let denom = nig * sumZZ - sumZ * sumZ
		if absVal(denom) > T.ulpOfOne {
			groupCoeffs[g] = (nig * sumZR - sumZ * sumR) / denom
		}
		coeffGrandMean += groupCoeffs[g]
	}
	coeffGrandMean /= T(m)

	var coeffVar = T.zero
	for g in 0..<m {
		let diff = groupCoeffs[g] - coeffGrandMean
		coeffVar += diff * diff
	}
	if m > 1 { coeffVar /= T(m - 1) }
	return coeffVar > T.ulpOfOne ? coeffVar : T(1) / T(10)
}

/// Fit a general linear mixed-effects model via REML.
///
/// Estimates fixed effects (β) and the random-effects covariance matrix G
/// plus residual variance for the model:
/// ```
/// y = Xβ + Zu + ε
/// ```
/// where `u ~ N(0, G)` with G being r × r and `ε ~ N(0, σ²_e I)`.
///
/// Uses an EM warm-up followed by AI-REML (average information) scoring
/// for fast convergence. The algorithm:
/// 1. Initialize via OLS and method-of-moments
/// 2. EM warm-up (5 iterations) for stable initial estimates
/// 3. AI-REML scoring for remaining iterations
/// 4. Convergence checked on both log-likelihood and parameter changes
///
/// - Parameters:
///   - model: The general LME model specification.
///   - maxIterations: Maximum EM/scoring iterations (default 100).
///   - tolerance: Convergence tolerance (default 1e-8).
/// - Returns: A ``GeneralLMEResult`` with all estimates and diagnostics.
/// - Throws: `BusinessMathError.mismatchedDimensions` if X.rows, Z.rows, y.count,
///   or grouping lengths do not match, or if Z.columns != randomEffectsPerGroup.
///   `BusinessMathError.insufficientData` if fewer than 2 groups or N <= p.
public func fitGeneralLME<T: Real>(
	_ model: GeneralLMEModel<T>,
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(100_000_000)
) throws -> GeneralLMEResult<T> where T: BinaryFloatingPoint {

	let y = model.response
	let grouping = model.grouping
	let N = y.count
	let p = model.fixedEffects.columns
	let r = model.randomEffectsPerGroup

	try validateGeneralLME(model, N: N, p: p, r: r)


	// Extract X and Z as 2D arrays for fast inner-loop access
	var xData = Array(repeating: Array(repeating: T.zero, count: p), count: N)
	var zData = Array(repeating: Array(repeating: T.zero, count: r), count: N)
	for i in 0..<N {
		for j in 0..<p {
			xData[i][j] = model.fixedEffects[i, j]
		}
		for j in 0..<r {
			zData[i][j] = model.randomEffectsDesign[i, j]
		}
	}

	let m = grouping.groupCount
	let ni = grouping.groupSizes
	let groupIdx = grouping.groupIndices

	// --- Initialize variance components from method of moments ---
	// Method-of-moments starting values, shared with the other fitter: a one-way ANOVA
	// decomposition of the OLS residuals. What each model does with `msBetween` is where
	// they diverge, and that stays below.
	let start = try mixedModelStartingValues(
		xData: xData, y: y, groupIdx: groupIdx, N: N, p: p, m: m
	)
	// `start.beta` is not bound: both fitters re-estimate β by GLS on the first iteration,
	// so the OLS estimate exists only to produce the residuals the decomposition needs.
	let residOLS = start.residuals
	var sigmaE2 = start.sigmaE2
	let msBetween = start.msBetween
	let nBar = start.nBar

	// Initialize G as diagonal: G[0,0] from between-group variance,
	// G[k,k] from between-group covariate variation for k > 0
	var gArr = Array(repeating: Array(repeating: T.zero, count: r), count: r)

	// First diagonal: intercept-like variance
	let g00Init = msBetween > sigmaE2 ? (msBetween - sigmaE2) / nBar : T(1) / T(10)
	gArr[0][0] = T.maximum(g00Init, T(1) / T(10))

	// For higher random effects, estimate from between-group regressions.
	for k in 1..<r {
		gArr[k][k] = generalSlopeVarianceStart(
			zData: zData, residuals: residOLS, groupIdx: groupIdx, column: k, m: m
		)
	}

	// --- EM warm-up + AI-REML ---
	let emWarmup = 5
	var converged = false
	var iteration = 0
	var prevLogLik = -T.greatestFiniteMagnitude

	for iter in 0..<maxIterations {
		iteration = iter + 1

		let glsResult = try generalGLSEstimate(
			xData: xData, y: y, zData: zData,
			N: N, p: p, r: r, m: m,
			ni: ni, groupIdx: groupIdx,
			gArr: gArr, sigmaE2: sigmaE2)

		let logLik = glsResult.remlLogLik

		// Check log-likelihood convergence
		if iter > 0 {
			let absChange = absVal(logLik - prevLogLik)
			let relChange = absChange / T.maximum(absVal(prevLogLik), T(1))
			if relChange < tolerance || absChange < tolerance {
				converged = true
				prevLogLik = logLik
				break
			}
		}
		prevLogLik = logLik

		// Compute marginal residuals: r = y - X*beta
		let beta = glsResult.beta
		var resid = Array(repeating: T.zero, count: N)
		for i in 0..<N {
			var fitted = T.zero
			for j in 0..<p { fitted += xData[i][j] * beta[j] }
			resid[i] = y[i] - fitted
		}

		if iter < emWarmup {
			// EM update
			let emResult = try generalEMUpdate(
				resid: resid, zData: zData, m: m, r: r,
				ni: ni, groupIdx: groupIdx,
				gArr: gArr, sigmaE2: sigmaE2, N: N)

			sigmaE2 = T.maximum(emResult.sigmaE2, T.ulpOfOne)
			var newG = emResult.gArr
			// Ensure diagonal non-negative
			for k in 0..<r {
				newG[k][k] = T.maximum(newG[k][k], T.zero)
			}
			// Symmetrize
			for i in 0..<r {
				for j in (i + 1)..<r {
					let avg = (newG[i][j] + newG[j][i]) / T(2)
					newG[i][j] = avg
					newG[j][i] = avg
				}
			}
			// Ensure PSD by clamping off-diagonal if needed
			newG = generalEnsurePSD(newG, r: r)
			gArr = newG
		} else {
			// AI-REML update
			let aiResult = try generalAIREMLUpdate(
				resid: resid, xData: xData, zData: zData,
				m: m, r: r, ni: ni, groupIdx: groupIdx,
				gArr: gArr, sigmaE2: sigmaE2, N: N, p: p)

			let nTheta = aiResult.score.count
			// Solve AI * delta = score
			let aiMat = try DenseMatrix(aiResult.ai)
			var delta: [T]
			do {
				delta = try aiMat.choleskySolve(aiResult.score)
			} catch { // logging: AI matrix not positive definite — fall back to diagonal step
				delta = (0..<nTheta).map { i -> T in
					let diag = aiResult.ai[i][i]
					guard diag > T.ulpOfOne else { return T.zero }
					return aiResult.score[i] / diag
				}
			}

			let step = generalFeasibleStep(
				from: gArr, sigmaE2: sigmaE2, delta: delta, r: r)

			let newSigmaE2 = T.maximum(sigmaE2 + step * delta[0], T.ulpOfOne)
			var newG = gArr
			var idx = 1
			for i in 0..<r {
				for j in i..<r {
					newG[i][j] = gArr[i][j] + step * delta[idx]
					newG[j][i] = newG[i][j]
					idx += 1
				}
			}
			// Ensure diagonal non-negative
			for k in 0..<r {
				newG[k][k] = T.maximum(newG[k][k], T.zero)
			}
			newG = generalEnsurePSD(newG, r: r)

			// Check parameter convergence
			var allConverged = paramHasConverged(old: sigmaE2, new: newSigmaE2, tolerance: tolerance)
			for i in 0..<r {
				for j in i..<r {
					if !paramHasConverged(old: gArr[i][j], new: newG[i][j], tolerance: tolerance) {
						allConverged = false
					}
				}
			}

			sigmaE2 = newSigmaE2
			gArr = newG

			if allConverged {
				converged = true
				break
			}
		}
	}

	// --- Final estimates ---
	let final = try generalGLSEstimate(
		xData: xData, y: y, zData: zData,
		N: N, p: p, r: r, m: m,
		ni: ni, groupIdx: groupIdx,
		gArr: gArr, sigmaE2: sigmaE2)

	let beta = final.beta

	// Marginal residuals
	var marginalResid = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * beta[j] }
		marginalResid[i] = y[i] - fitted
	}

	let blups = try generalBLUPs(
		zData: zData, marginalResiduals: marginalResid,
		r: r, m: m, groupIdx: groupIdx,
		gArr: gArr, sigmaE2: sigmaE2)

	// Conditional residuals and fitted values
	var conditionalResid = Array(repeating: T.zero, count: N)
	var fittedValues = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		let g = grouping.groups[i]
		var xBeta = T.zero
		for j in 0..<p { xBeta += xData[i][j] * beta[j] }
		var randomPart = T.zero
		for k in 0..<r {
			randomPart += blups[g][k] * zData[i][k]
		}
		fittedValues[i] = xBeta + randomPart
		conditionalResid[i] = y[i] - fittedValues[i]
	}

	// Standard errors of fixed effects
	let seResult = try generalFixedEffectsSE(
		xData: xData, zData: zData,
		N: N, p: p, r: r, m: m,
		ni: ni, groupIdx: groupIdx,
		gArr: gArr, sigmaE2: sigmaE2)

	let tStats = (0..<p).map { j -> T in
		guard seResult[j] > T.zero else { return T.zero }
		return beta[j] / seResult[j]
	}

	let dfInt = N - p
	let pvals: [T] = try tStats.map { t -> T in
		guard dfInt > 0 else { return T(1) }
		let absT = absVal(t)
		let pOneSided: T = try tCDF(t: absT, df: dfInt)
		return T(2) * (T(1) - pOneSided)
	}

	// G matrix
	let gMatrix = try DenseMatrix(gArr)

	// BLUPs as DenseMatrix (m x r)
	let blupMatrix = try DenseMatrix(blups)

	// Information criteria
	// Variance parameters: sigmaE2 + r*(r+1)/2 unique G elements
	let nVarParams = 1 + r * (r + 1) / 2
	let nParams = T(p + nVarParams)
	let aic = T(-2) * final.remlLogLik + T(2) * nParams
	let bic = T(-2) * final.remlLogLik + nParams * T.log(T(N))

	return GeneralLMEResult(
		beta: beta,
		standardErrors: seResult,
		tStatistics: tStats,
		pValues: pvals,
		gMatrix: gMatrix,
		varianceResidual: sigmaE2,
		remlLogLikelihood: final.remlLogLik,
		aic: aic,
		bic: bic,
		randomEffects: blupMatrix,
		residuals: conditionalResid,
		marginalResiduals: marginalResid,
		fittedValues: fittedValues,
		observations: N,
		groups: m,
		fixedEffectsCount: p,
		randomEffectsPerGroup: r,
		iterations: iteration,
		converged: converged)
}

// MARK: - Internal Helpers

/// Build V_i = Z_i G Z_i' + sigmaE2 * I for a single group.
///
/// A small ridge is added to the diagonal to ensure numerical
/// positive definiteness even when G is near-singular.
private func generalBuildVi<T: Real & Sendable>(
	zi: [[T]], gArr: [[T]], sigmaE2: T, nig: Int, r: Int
) throws -> [[T]] where T: BinaryFloatingPoint {
	// Ridge proportional to sigmaE2 for scale-invariance
	let ridge = T.maximum(sigmaE2, T(1)) * T(1) / T(1_000_000)
	var vi = Array(repeating: Array(repeating: T.zero, count: nig), count: nig)
	for row in 0..<nig {
		for col in 0..<nig {
			// (Z_i G Z_i')[row,col] = sum_{a,b} z[row][a] * G[a][b] * z[col][b]
			var val = T.zero
			for a in 0..<r {
				for b in 0..<r {
					val += zi[row][a] * gArr[a][b] * zi[col][b]
				}
			}
			vi[row][col] = val
			if row == col {
				vi[row][col] += sigmaE2 + ridge
			}
		}
	}
	return vi
}

private struct GeneralGLSResult<T: Real & Sendable> {
	let beta: [T]
	let remlLogLik: T
}

/// OLS estimate: beta = (X'X)^{-1} X'y

/// GLS estimate of beta and REML log-likelihood for the general LME model.
private func generalGLSEstimate<T: Real & Sendable>(
	xData: [[T]], y: [T], zData: [[T]],
	N: Int, p: Int, r: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T
) throws -> GeneralGLSResult<T> where T: BinaryFloatingPoint {

	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var xtVinvY = Array(repeating: T.zero, count: p)
	var logDetV = T.zero

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		var yi = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			for k in 0..<r { zi[localIdx][k] = zData[obsIdx][k] }
			xiRows[localIdx] = xData[obsIdx]
			yi[localIdx] = y[obsIdx]
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)

		logDetV += try viMat.logDeterminant()

		let viInvY = try viMat.choleskySolve(yi)
		let xiMat = try DenseMatrix(xiRows)
		let viInvXi = try viMat.choleskySolve(xiMat)

		for localIdx in 0..<nig {
			for j in 0..<p {
				xtVinvY[j] += xiRows[localIdx][j] * viInvY[localIdx]
				for k in 0..<p {
					xtVinvX[j][k] += xiRows[localIdx][j] * viInvXi[localIdx, k]
				}
			}
		}
	}

	let xtVinvXMat = try DenseMatrix(xtVinvX)
	let beta = try xtVinvXMat.solve(xtVinvY)

	// Quadratic form: r' V^{-1} r
	var quadForm = T.zero
	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			for k in 0..<r { zi[localIdx][k] = zData[obsIdx][k] }
			var fitted = T.zero
			for j in 0..<p { fitted += xData[obsIdx][j] * beta[j] }
			ri[localIdx] = y[obsIdx] - fitted
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)
		let viInvR = try viMat.choleskySolve(ri)

		for localIdx in 0..<nig {
			quadForm += ri[localIdx] * viInvR[localIdx]
		}
	}

	// log|X'V^{-1}X|
	let logDetXtVinvX = try xtVinvXMat.logDeterminant()

	// REML log-likelihood
	let Nmp = T(N - p)
	let logLikBody: T = Nmp * T.log(T(2) * T.pi)
		+ logDetV
		+ logDetXtVinvX
		+ quadForm
	let logLik: T = T(-1) / T(2) * logLikBody

	return GeneralGLSResult(beta: beta, remlLogLik: logLik)
}

private struct GeneralEMResult<T: Real & Sendable> {
	let sigmaE2: T
	let gArr: [[T]]
}

/// EM update for variance components in the general LME model.
private func generalEMUpdate<T: Real & Sendable>(
	resid: [T], zData: [[T]], m: Int, r: Int,
	ni: [Int], groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T, N: Int
) throws -> GeneralEMResult<T> where T: BinaryFloatingPoint {

	var sumG = Array(repeating: Array(repeating: T.zero, count: r), count: r)
	var sumResidVar = T.zero

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			for k in 0..<r { zi[localIdx][k] = zData[obsIdx][k] }
			ri[localIdx] = resid[obsIdx]
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)
		let viInv = try viMat.choleskyInverse()
		let viInvR = try viMat.choleskySolve(ri)

		// Z_i' V_i^{-1} r_i (r-vector)
		var ztViInvR = Array(repeating: T.zero, count: r)
		for j in 0..<nig {
			for k in 0..<r {
				ztViInvR[k] += zi[j][k] * viInvR[j]
			}
		}

		// u_hat = G Z_i' V_i^{-1} r_i
		var uHat = Array(repeating: T.zero, count: r)
		for k in 0..<r {
			for l in 0..<r {
				uHat[k] += gArr[k][l] * ztViInvR[l]
			}
		}

		// Z_i' V_i^{-1} Z_i (r x r)
		var ztViInvZ = Array(repeating: Array(repeating: T.zero, count: r), count: r)
		for row in 0..<nig {
			for col in 0..<nig {
				let viInvRC = viInv[row, col]
				for a in 0..<r {
					for b in 0..<r {
						ztViInvZ[a][b] += zi[row][a] * viInvRC * zi[col][b]
					}
				}
			}
		}

		// G Z' V^{-1} Z G (r x r)
		var gZVZG = Array(repeating: Array(repeating: T.zero, count: r), count: r)
		for a in 0..<r {
			for b in 0..<r {
				for c in 0..<r {
					for d in 0..<r {
						gZVZG[a][b] += gArr[a][c] * ztViInvZ[c][d] * gArr[d][b]
					}
				}
			}
		}

		// E[u u'|y] = u_hat u_hat' + (G - G Z' V^{-1} Z G)
		for a in 0..<r {
			for b in 0..<r {
				sumG[a][b] += uHat[a] * uHat[b] + gArr[a][b] - gZVZG[a][b]
			}
		}

		// Residual variance contribution
		var ssResid = T.zero
		for (_, obsIdx) in indices.enumerated() {
			var zuHat = T.zero
			for k in 0..<r { zuHat += zData[obsIdx][k] * uHat[k] }
			let eHat = resid[obsIdx] - zuHat
			ssResid += eHat * eHat
		}
		var trViInv = T.zero
		for j in 0..<nig { trViInv += viInv[j, j] }
		sumResidVar += ssResid + sigmaE2 * (T(nig) - sigmaE2 * trViInv)
	}

	var newG = Array(repeating: Array(repeating: T.zero, count: r), count: r)
	for a in 0..<r {
		for b in 0..<r {
			newG[a][b] = sumG[a][b] / T(m)
		}
	}

	return GeneralEMResult(
		sigmaE2: sumResidVar / T(N),
		gArr: newG)
}

private struct GeneralAIREMLResult<T: Real & Sendable> {
	let score: [T]   // (1 + r*(r+1)/2) vector
	let ai: [[T]]    // (1 + r*(r+1)/2) x (1 + r*(r+1)/2) matrix
}

private struct GeneralGroupCache<T: Real & Sendable> {
	let viInv: DenseMatrix<T>
	let viInvR: [T]
	let viInvXi: DenseMatrix<T>
	let zi: [[T]]
	let ri: [T]
	let xiRows: [[T]]
}

/// AI-REML update for the general LME model.
///
/// Variance parameters are ordered: theta = (sigma_e², G[0,0], G[0,1], ..., G[0,r-1], G[1,1], G[1,2], ..., G[r-1,r-1])
/// i.e., sigma_e² first, then the upper triangle of G in row-major order.
private func generalAIREMLUpdate<T: Real & Sendable>(
	resid: [T], xData: [[T]], zData: [[T]],
	m: Int, r: Int, ni: [Int], groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T,
	N: Int, p: Int
) throws -> GeneralAIREMLResult<T> where T: BinaryFloatingPoint {

	// Number of variance parameters: 1 (sigma_e²) + r*(r+1)/2 (unique G elements)
	let nTheta = 1 + r * (r + 1) / 2

	// Build mapping from theta index to (i,j) in G
	// theta[0] = sigma_e²
	// theta[1..] = upper triangle of G: (0,0), (0,1), ..., (0,r-1), (1,1), (1,2), ...
	var gParamMap = [(Int, Int)]()
	for i in 0..<r {
		for j in i..<r {
			gParamMap.append((i, j))
		}
	}

	// First pass: compute X'V^{-1}X and group caches
	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var groupCaches = [GeneralGroupCache<T>]()

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			for k in 0..<r { zi[localIdx][k] = zData[obsIdx][k] }
			xiRows[localIdx] = xData[obsIdx]
			ri[localIdx] = resid[obsIdx]
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)
		let viInv = try viMat.choleskyInverse()
		let viInvR = try viMat.choleskySolve(ri)
		let xiMat = try DenseMatrix(xiRows)
		let viInvXi = try viMat.choleskySolve(xiMat)

		for localIdx in 0..<nig {
			for j in 0..<p {
				for k in 0..<p {
					xtVinvX[j][k] += xiRows[localIdx][j] * viInvXi[localIdx, k]
				}
			}
		}

		groupCaches.append(GeneralGroupCache(
			viInv: viInv, viInvR: viInvR, viInvXi: viInvXi,
			zi: zi, ri: ri, xiRows: xiRows))
	}

	// (X'V^{-1}X)^{-1}
	let xtVinvXMat = try DenseMatrix(xtVinvX)
	let xtVinvXInv = try xtVinvXMat.choleskyInverse()

	// Score and AI accumulators
	var score = Array(repeating: T.zero, count: nTheta)
	var ai = Array(repeating: Array(repeating: T.zero, count: nTheta), count: nTheta)

	// X'V^{-1}r, summed over EVERY group.
	//
	// The projection is P = V^{-1} - V^{-1}X(X'V^{-1}X)^{-1}X'V^{-1}, so
	//
	//     (Pr)_i = V_i^{-1}r_i - V_i^{-1}X_i (X'V^{-1}X)^{-1} · SUM_j X_j'V_j^{-1}r_j
	//
	// and that sum runs over all groups. This used to use only group i's own
	// X_i'V_i^{-1}r_i, which is a different quantity: `r` here is the GLS residual
	// y - Xbeta, so the true sum is zero by the normal equations and the correction
	// vanishes — while a per-group term does not. Subtracting it shrank `pR`, which
	// shrank r'P(dV)Pr, which made the score more negative and drove every variance
	// component down. Measured against statsmodels REML the random-effects covariance
	// came out 12-24% low, and the AI-REML phase moved *away* from the optimum the EM
	// warm-up had already reached.
	var globalXtViInvR = Array(repeating: T.zero, count: p)
	for g in 0..<m {
		let cache = groupCaches[g]
		for localIdx in 0..<groupIdx[g].count {
			for j in 0..<p {
				globalXtViInvR[j] += cache.xiRows[localIdx][j] * cache.viInvR[localIdx]
			}
		}
	}
	var globalCorrection = Array(repeating: T.zero, count: p)
	for j in 0..<p {
		for k in 0..<p {
			globalCorrection[j] += xtVinvXInv[j, k] * globalXtViInvR[k]
		}
	}

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count
		let cache = groupCaches[g]

		var viInvXCorr = Array(repeating: T.zero, count: nig)
		for localIdx in 0..<nig {
			for j in 0..<p {
				viInvXCorr[localIdx] += cache.viInvXi[localIdx, j] * globalCorrection[j]
			}
		}

		var pR = Array(repeating: T.zero, count: nig)
		for localIdx in 0..<nig {
			pR[localIdx] = cache.viInvR[localIdx] - viInvXCorr[localIdx]
		}

		// P_i matrix
		var pMat = Array(repeating: Array(repeating: T.zero, count: nig), count: nig)
		for row in 0..<nig {
			for col in 0..<nig {
				pMat[row][col] = cache.viInv[row, col]
				for j in 0..<p {
					for k in 0..<p {
						pMat[row][col] -= cache.viInvXi[row, j] * xtVinvXInv[j, k] * cache.viInvXi[col, k]
					}
				}
			}
		}

		// dV/dtheta derivatives and their products with P*r
		// dvPr[k] = (dV/dtheta_k) * P * r for each parameter
		var dvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: nTheta)

		// --- Parameter 0: sigma_e², dV/d(sigma_e²) = I ---
		var trPdV0 = T.zero
		for localIdx in 0..<nig { trPdV0 += pMat[localIdx][localIdx] }
		var rPdVPr0 = T.zero
		for localIdx in 0..<nig { rPdVPr0 += pR[localIdx] * pR[localIdx] }
		let score0term1: T = T(-1) / T(2) * trPdV0
		let score0term2: T = T(1) / T(2) * rPdVPr0
		score[0] += score0term1 + score0term2
		for localIdx in 0..<nig { dvPr[0][localIdx] = pR[localIdx] }

		// --- G parameters: dV/dG[a,b] = Z[:,a] Z[:,b]' + Z[:,b] Z[:,a]' (for a != b)
		//                    dV/dG[a,a] = Z[:,a] Z[:,a]'
		for paramIdx in 0..<gParamMap.count {
			let thetaIdx = paramIdx + 1
			let (a, b) = gParamMap[paramIdx]

			// tr(P * dV)
			var trPdV = T.zero
			for row in 0..<nig {
				for col in 0..<nig {
					if a == b {
						trPdV += pMat[row][col] * cache.zi[col][a] * cache.zi[row][a]
					} else {
						trPdV += pMat[row][col] * (cache.zi[col][a] * cache.zi[row][b]
							+ cache.zi[col][b] * cache.zi[row][a])
					}
				}
			}

			// dV * P * r
			if a == b {
				// dV/dG[a,a] * pR = z_a * (z_a' * pR)
				var zaTpR = T.zero
				for localIdx in 0..<nig { zaTpR += cache.zi[localIdx][a] * pR[localIdx] }
				for localIdx in 0..<nig {
					dvPr[thetaIdx][localIdx] = cache.zi[localIdx][a] * zaTpR
				}
			} else {
				// dV/dG[a,b] = z_a z_b' + z_b z_a'
				var zaTpR = T.zero
				var zbTpR = T.zero
				for localIdx in 0..<nig {
					zaTpR += cache.zi[localIdx][a] * pR[localIdx]
					zbTpR += cache.zi[localIdx][b] * pR[localIdx]
				}
				for localIdx in 0..<nig {
					dvPr[thetaIdx][localIdx] = cache.zi[localIdx][a] * zbTpR + cache.zi[localIdx][b] * zaTpR
				}
			}

			var rPdVPr = T.zero
			for localIdx in 0..<nig { rPdVPr += pR[localIdx] * dvPr[thetaIdx][localIdx] }
			let scoreTterm1: T = T(-1) / T(2) * trPdV
			let scoreTterm2: T = T(1) / T(2) * rPdVPr
			score[thetaIdx] += scoreTterm1 + scoreTterm2
		}

		// Average Information matrix
		var pDvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: nTheta)
		for k in 0..<nTheta {
			for row in 0..<nig {
				for col in 0..<nig {
					pDvPr[k][row] += pMat[row][col] * dvPr[k][col]
				}
			}
		}

		for j in 0..<nTheta {
			for k in j..<nTheta {
				var val = T.zero
				for localIdx in 0..<nig {
					val += dvPr[j][localIdx] * pDvPr[k][localIdx]
				}
				val = val / T(2)
				ai[j][k] += val
				if j != k { ai[k][j] += val }
			}
		}
	}

	return GeneralAIREMLResult(score: score, ai: ai)
}

/// Standard errors of fixed effects: sqrt(diag((X'V^{-1}X)^{-1}))
private func generalFixedEffectsSE<T: Real & Sendable>(
	xData: [[T]], zData: [[T]],
	N: Int, p: Int, r: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T
) throws -> [T] where T: BinaryFloatingPoint {

	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: r), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			for k in 0..<r { zi[localIdx][k] = zData[obsIdx][k] }
			xiRows[localIdx] = xData[obsIdx]
		}

		let viData = try generalBuildVi(zi: zi, gArr: gArr, sigmaE2: sigmaE2, nig: nig, r: r)
		let viMat = try DenseMatrix(viData)
		let xiMat = try DenseMatrix(xiRows)
		let viInvXi = try viMat.choleskySolve(xiMat)

		for localIdx in 0..<nig {
			for j in 0..<p {
				for k in 0..<p {
					xtVinvX[j][k] += xiRows[localIdx][j] * viInvXi[localIdx, k]
				}
			}
		}
	}

	let xtVinvXMat = try DenseMatrix(xtVinvX)
	let cov = try xtVinvXMat.choleskyInverse()

	return (0..<p).map { j in
		let v = cov[j, j]
		return v > T.zero ? T.sqrt(v) : T.zero
	}
}

// MARK: - PSD Helpers

/// Check if a symmetric matrix is positive semi-definite by attempting Cholesky
/// on a slightly regularized version.
private func generalIsPSD<T: Real & Sendable>(_ mat: [[T]], r: Int) -> Bool {
	// Check diagonal elements are non-negative
	for i in 0..<r {
		guard mat[i][i] >= T.zero else { return false }
	}
	// For 1x1, just check non-negative
	if r == 1 { return true }
	// For 2x2, check determinant
	if r == 2 {
		return mat[0][0] * mat[1][1] >= mat[0][1] * mat[1][0]
	}
	// General case: try Cholesky on regularized matrix
	var reg = mat
	for i in 0..<r { reg[i][i] += T.ulpOfOne }
	do {
		let m = try DenseMatrix(reg)
		_ = try m.cholesky()
		return true
	} catch { // logging: Cholesky failure means matrix is not positive semi-definite
		return false
	}
}

/// Ensure G is positive semi-definite.
///
/// For r <= 2, clamps off-diagonal elements. For larger r, attempts Cholesky
/// and if it fails, adds a small ridge to the diagonal until PSD.
private func generalEnsurePSD<T: Real & Sendable>(_ mat: [[T]], r: Int) -> [[T]] {
	var result = mat
	// First pass: clamp off-diagonal
	for i in 0..<r {
		for j in (i + 1)..<r {
			let maxCov = T.sqrt(T.maximum(result[i][i], T.zero) * T.maximum(result[j][j], T.zero))
			if absVal(result[i][j]) > maxCov {
				let clamped = result[i][j] > T.zero ? maxCov : -maxCov
				result[i][j] = clamped
				result[j][i] = clamped
			}
		}
	}
	// For r >= 3, off-diagonal clamping alone is insufficient.
	// Add a small ridge if not PSD.
	if r >= 3 {
		var ridge = T.ulpOfOne * T(100)
		for _ in 0..<30 {
			if generalIsPSD(result, r: r) { return result }
			for i in 0..<r {
				result[i][i] += ridge
			}
			ridge = ridge * T(10)
		}
	}
	return result
}
