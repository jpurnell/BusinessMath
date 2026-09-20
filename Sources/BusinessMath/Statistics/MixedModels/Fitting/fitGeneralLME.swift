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
///   - tolerance: Convergence tolerance (default 1e-9).
///
///     Raised from 1e-8 alongside the AI matrix's projection fix. `paramHasConverged`
///     tests the **change in the parameters**, not the gradient, and a correct information
///     matrix is larger than the truncated one it replaced, so `AI^-1 score` is smaller and
///     a step-size test trips sooner. At 1e-8 the hardest reference design stopped at nine
///     iterations with a remaining Newton step of 1.9e-05; one more iteration takes that to
///     2.2e-06 and its fixed effects from 1.3e-06 away from statsmodels to 6.0e-08.
///
///     1e-9 rather than anything tighter, measured across the six reference designs:
///
///     | tolerance | near-degenerate design | hardest design |
///     |---|---|---|
///     | 1e-8  | 14 iterations, converged | 9 — stops early |
///     | 5e-9  | 15 iterations, converged | 9 — stops early |
///     | 1e-9  | 15 iterations, converged | 10 |
///     | 5e-10 | 16 iterations, converged | 10 |
///     | 1e-10 | **100 iterations, does not converge** | 10 |
///
///     `randomIntercept_smallVariance` has its tau^2 on the zero boundary, where a
///     relative change test cannot be satisfied however long it runs: below 5e-10 the fit
///     exhausts the iteration budget and reports failure on a model it had been fitting
///     correctly. 1e-9 buys the extra iteration where it is needed and stays two steps
///     clear of that cliff. Nothing gets closer to stationarity beyond this point either —
///     the gradient plateaus near 1.3e-06.
/// - Returns: A ``GeneralLMEResult`` with all estimates and diagnostics.
/// - Throws: `BusinessMathError.mismatchedDimensions` if X.rows, Z.rows, y.count,
///   or grouping lengths do not match, or if Z.columns != randomEffectsPerGroup.
///   `BusinessMathError.insufficientData` if fewer than 2 groups or N <= p.
public func fitGeneralLME<T: Real>(
	_ model: GeneralLMEModel<T>,
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(1_000_000_000)
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
				m: m, r: r, groupIdx: groupIdx,
				gArr: gArr, sigmaE2: sigmaE2, p: p)

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

internal struct GeneralEMResult<T: Real & Sendable> {
	let sigmaE2: T
	let gArr: [[T]]
}

/// EM update for the variance components of the general LME model.
///
/// One M-step of the EM algorithm, which is what the fitter uses to warm up before AI-REML
/// takes over. With `V_i = Z_i G Z_i' + sigma_e^2 I` and the BLUP
/// `u_i = G Z_i' V_i^-1 r_i`, the conditional second moments are
///
///     E[u_i u_i' | y] = u_i u_i' + (G - G Z_i'V_i^-1 Z_i G)
///     E[e_i' e_i | y] = ||r_i - Z_i u_i||^2 + sigma_e^2 (n_i - sigma_e^2 tr(V_i^-1))
///
/// and the update is their averages: `G` over the `m` groups, `sigma_e^2` over all `N`
/// observations. The second term of each is the conditional *variance* — the part that
/// distinguishes an EM step from simply plugging the BLUPs in, and the part a naive
/// implementation drops.
///
/// Every quantity here is block diagonal by group, so accumulating per group is exact —
/// unlike ``generalAIREMLUpdate(resid:xData:zData:m:r:groupIdx:gArr:sigmaE2:p:)``, whose
/// information matrix needs the whole projection. See `GeneralAIREMLOracleTests` for the
/// dense check of both.
///
/// - Parameters:
///   - resid: The GLS residual `y - X beta`, by observation.
///   - zData: The random-effects design, by observation.
///   - m: Group count.
///   - r: Random effects per group.
///   - ni: Observation count per group.
///   - groupIdx: Row indices per group.
///   - gArr: The current random-effects covariance.
///   - sigmaE2: The current residual variance.
///   - N: Total observations.
/// - Returns: The updated residual variance and random-effects covariance.
/// - Throws: From ``DenseMatrix/choleskyInverse()`` and ``DenseMatrix/choleskySolve(_:)``
///   when a group's `V_g` is not positive definite.
internal func generalEMUpdate<T: Real & Sendable>(
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

		let uHat = generalGroupBLUP(zi: zi, viInvR: viInvR, gArr: gArr, nig: nig, r: r)
		let ztViInvZ = generalZtViInvZ(zi: zi, viInv: viInv, nig: nig, r: r)
		let gZVZG = generalSandwich(gArr, ztViInvZ, r: r)

		// E[u u'|y] = u_hat u_hat' + (G - G Z' V^{-1} Z G)
		//
		// Written in this order rather than as `uHat outer product + posterior` because the
		// original association is left to right and regrouping it moves the last bit.
		for a in 0..<r {
			for b in 0..<r {
				sumG[a][b] += uHat[a] * uHat[b] + gArr[a][b] - gZVZG[a][b]
			}
		}

		let ssResid = generalGroupResidualSumOfSquares(
			zData: zData, resid: resid, indices: indices, uHat: uHat, r: r)
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

/// One group's BLUP, `u = G Z_i' V_i^-1 r_i`.
///
/// - Parameters:
///   - zi: The group's random-effects design rows.
///   - viInvR: `V_i^-1 r_i`, already solved.
///   - gArr: The current random-effects covariance.
///   - nig: The group's observation count.
///   - r: Random effects per group.
/// - Returns: The `r`-vector of predicted random effects.
private func generalGroupBLUP<T: Real & Sendable>(
	zi: [[T]], viInvR: [T], gArr: [[T]], nig: Int, r: Int
) -> [T] where T: BinaryFloatingPoint {
	var ztViInvR = Array(repeating: T.zero, count: r)
	for j in 0..<nig {
		for k in 0..<r {
			ztViInvR[k] += zi[j][k] * viInvR[j]
		}
	}

	var uHat = Array(repeating: T.zero, count: r)
	for k in 0..<r {
		for l in 0..<r {
			uHat[k] += gArr[k][l] * ztViInvR[l]
		}
	}
	return uHat
}

/// `Z_i' V_i^-1 Z_i`, the information one group carries about the random effects.
///
/// - Parameters:
///   - zi: The group's random-effects design rows.
///   - viInv: The group's inverted marginal covariance.
///   - nig: The group's observation count.
///   - r: Random effects per group.
/// - Returns: The `r x r` result.
private func generalZtViInvZ<T: Real & Sendable>(
	zi: [[T]], viInv: DenseMatrix<T>, nig: Int, r: Int
) -> [[T]] where T: BinaryFloatingPoint {
	var out = Array(repeating: Array(repeating: T.zero, count: r), count: r)
	for row in 0..<nig {
		for col in 0..<nig {
			let viInvRC = viInv[row, col]
			for a in 0..<r {
				for b in 0..<r {
					out[a][b] += zi[row][a] * viInvRC * zi[col][b]
				}
			}
		}
	}
	return out
}

/// `G M G` for a symmetric `r x r` middle.
///
/// - Parameters:
///   - gArr: The outer matrix.
///   - middle: The matrix between the two copies of it.
///   - r: The dimension.
/// - Returns: The `r x r` product.
private func generalSandwich<T: Real & Sendable>(
	_ gArr: [[T]], _ middle: [[T]], r: Int
) -> [[T]] where T: BinaryFloatingPoint {
	var out = Array(repeating: Array(repeating: T.zero, count: r), count: r)
	for a in 0..<r {
		for b in 0..<r {
			for c in 0..<r {
				for d in 0..<r {
					out[a][b] += gArr[a][c] * middle[c][d] * gArr[d][b]
				}
			}
		}
	}
	return out
}

/// `||r_i - Z_i u_i||^2` for one group.
///
/// - Parameters:
///   - zData: The random-effects design, by observation.
///   - resid: The GLS residual, by observation.
///   - indices: The group's row indices.
///   - uHat: The group's BLUP.
///   - r: Random effects per group.
/// - Returns: The sum of squared conditional residuals.
private func generalGroupResidualSumOfSquares<T: Real & Sendable>(
	zData: [[T]], resid: [T], indices: [Int], uHat: [T], r: Int
) -> T where T: BinaryFloatingPoint {
	var ssResid = T.zero
	for (_, obsIdx) in indices.enumerated() {
		var zuHat = T.zero
		for k in 0..<r { zuHat += zData[obsIdx][k] * uHat[k] }
		let eHat = resid[obsIdx] - zuHat
		ssResid += eHat * eHat
	}
	return ssResid
}

internal struct GeneralAIREMLResult<T: Real & Sendable> {
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

/// The per-group factorisations the AI-REML passes share, and `X'V^-1 X` alongside them.
///
/// - Parameters:
///   - resid: The GLS residual `y - X beta`, by observation.
///   - xData: The fixed-effects design, by observation.
///   - zData: The random-effects design, by observation.
///   - m: Group count.
///   - r: Random effects per group.
///   - p: Fixed-effect count.
///   - groupIdx: Row indices per group.
///   - gArr: The current random-effects covariance.
///   - sigmaE2: The current residual variance.
/// - Returns: One cache per group, and the accumulated `X'V^-1 X`.
/// - Throws: From ``DenseMatrix/choleskyInverse()`` and ``DenseMatrix/choleskySolve(_:)``
///   when a group's `V_g` is not positive definite.
private func generalAIREMLCaches<T: Real & Sendable>(
	resid: [T], xData: [[T]], zData: [[T]],
	m: Int, r: Int, p: Int, groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T
) throws -> (caches: [GeneralGroupCache<T>], xtVinvX: [[T]]) where T: BinaryFloatingPoint {
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
	return (groupCaches, xtVinvX)
}

/// The projection's correction term, `(X'V^-1 X)^-1 SUM_g X_g'V_g^-1 r_g`.
///
/// The sum runs over every group. Using group `i`'s own `X_i'V_i^-1 r_i` in its place is a
/// different quantity: `r` is the GLS residual, so the true sum is zero by the normal
/// equations and the correction vanishes, while a per-group term does not. Subtracting one
/// shrank `pR`, shrank `r'P(dV)Pr`, made the score more negative and drove every variance
/// component down — measured against statsmodels REML the random-effects covariance came
/// out 12-24% low, and the AI-REML phase moved *away* from the optimum the EM warm-up had
/// already reached.
///
/// - Parameters:
///   - caches: The per-group factorisations.
///   - groupIdx: Row indices per group.
///   - m: Group count.
///   - p: Fixed-effect count.
///   - xtVinvXInv: `(X'V^-1 X)^-1`.
/// - Returns: The `p`-vector the per-group projection subtracts.
private func generalAIREMLProjectionCorrection<T: Real & Sendable>(
	caches: [GeneralGroupCache<T>], groupIdx: [[Int]], m: Int, p: Int,
	xtVinvXInv: DenseMatrix<T>
) -> [T] where T: BinaryFloatingPoint {
	var globalXtViInvR = Array(repeating: T.zero, count: p)
	for g in 0..<m {
		let cache = caches[g]
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
	return globalCorrection
}

/// `(P r)_i` for one group: `V_i^-1 r_i` less the group's share of the global correction.
///
/// - Parameters:
///   - cache: The group's factorisations.
///   - nig: The group's observation count.
///   - p: Fixed-effect count.
///   - globalCorrection: From ``generalAIREMLProjectionCorrection(caches:groupIdx:m:p:xtVinvXInv:)``.
/// - Returns: The group's block of `P r`.
private func generalProjectedResidual<T: Real & Sendable>(
	cache: GeneralGroupCache<T>, nig: Int, p: Int, globalCorrection: [T]
) -> [T] where T: BinaryFloatingPoint {
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
	return pR
}

/// The diagonal block `P_ii` of the projection.
///
/// This is the whole of `P` that the traces need: every `dV_k` is block diagonal by group,
/// so `tr(P dV_k)` sees only the diagonal blocks. It is **not** all the information matrix
/// needs — see ``generalInformationContribution(cache:dvPr:nig:p:nTheta:)``.
///
/// - Parameters:
///   - cache: The group's factorisations.
///   - nig: The group's observation count.
///   - p: Fixed-effect count.
///   - xtVinvXInv: `(X'V^-1 X)^-1`.
/// - Returns: The `nig x nig` block.
private func generalProjectionBlock<T: Real & Sendable>(
	cache: GeneralGroupCache<T>, nig: Int, p: Int, xtVinvXInv: DenseMatrix<T>
) -> [[T]] where T: BinaryFloatingPoint {
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
	return pMat
}

/// `(dV/dtheta_k) P r` for every variance parameter, within one group.
///
/// `dV/d(sigma_e^2)` is the identity, so its product is `P r` itself. The `G` derivatives
/// are rank one or two in the group's `Z` columns, so each is formed from a scalar
/// `z_a' P r` rather than by building the matrix.
///
/// - Parameters:
///   - cache: The group's factorisations.
///   - pR: The group's block of `P r`.
///   - nig: The group's observation count.
///   - nTheta: The variance-parameter count.
///   - gParamMap: Theta index to `(i, j)` in `G`, offset by one for `sigma_e^2`.
/// - Returns: One `nig`-vector per parameter.
private func generalDerivativeTimesProjected<T: Real & Sendable>(
	cache: GeneralGroupCache<T>, pR: [T], nig: Int, nTheta: Int, gParamMap: [(Int, Int)]
) -> [[T]] where T: BinaryFloatingPoint {
	var dvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: nTheta)
	for localIdx in 0..<nig { dvPr[0][localIdx] = pR[localIdx] }

	for paramIdx in 0..<gParamMap.count {
		let thetaIdx = paramIdx + 1
		let (a, b) = gParamMap[paramIdx]
		if a == b {
			var zaTpR = T.zero
			for localIdx in 0..<nig { zaTpR += cache.zi[localIdx][a] * pR[localIdx] }
			for localIdx in 0..<nig {
				dvPr[thetaIdx][localIdx] = cache.zi[localIdx][a] * zaTpR
			}
		} else {
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
	}
	return dvPr
}

/// `tr(P dV/dtheta_k)` for every variance parameter, within one group.
///
/// - Parameters:
///   - pMat: The group's diagonal block of `P`.
///   - cache: The group's factorisations.
///   - nig: The group's observation count.
///   - nTheta: The variance-parameter count.
///   - gParamMap: Theta index to `(i, j)` in `G`, offset by one for `sigma_e^2`.
/// - Returns: One trace per parameter.
private func generalProjectionTraces<T: Real & Sendable>(
	pMat: [[T]], cache: GeneralGroupCache<T>, nig: Int, nTheta: Int, gParamMap: [(Int, Int)]
) -> [T] where T: BinaryFloatingPoint {
	var traces = Array(repeating: T.zero, count: nTheta)
	for localIdx in 0..<nig { traces[0] += pMat[localIdx][localIdx] }

	for paramIdx in 0..<gParamMap.count {
		let thetaIdx = paramIdx + 1
		let (a, b) = gParamMap[paramIdx]
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
		traces[thetaIdx] = trPdV
	}
	return traces
}

/// One group's two contributions to the Average Information matrix.
///
/// `AI[j][k] = 1/2 (dV_j P r)' P (dV_k P r)`. Unlike the trace and the score's quadratic
/// form, this sandwiches a vector between two `P`s, so it needs the whole `P` and not only
/// its diagonal blocks. Expanding `P = V^-1 - V^-1 X (X'V^-1 X)^-1 X'V^-1` splits it into a
/// part that accumulates by group and a part that cannot:
///
///     a_j' P a_k = SUM_i a_j,i' V_i^-1 a_k,i
///                  - (SUM_i X_i'V_i^-1 a_j,i)' (X'V^-1X)^-1 (SUM_l X_l'V_l^-1 a_k,l)
///
/// This returns both sums for one group; the second is finished once every group has been
/// seen, by ``generalAssembleInformation(aiDirect:xtViInvDvPr:xtVinvXInv:nTheta:p:)``.
/// Building it from group `i`'s own `X_i'V_i^-1 a_j,i` instead truncates `P` to its diagonal
/// blocks; measured against a dense `N x N` projection that understated the information by
/// up to 13.5% on the six reference designs, making every AI-REML step correspondingly too
/// large. It is the projection error `pR` had, surviving in the one place the cancellation
/// that rescues `pR` does not reach: `Pr` is orthogonal to `X` by the normal equations, so
/// its global correction vanishes; `dV_k P r` is not, so this one does not.
///
/// - Parameters:
///   - cache: The group's factorisations.
///   - dvPr: `(dV/dtheta_k) P r` per parameter, for this group.
///   - nig: The group's observation count.
///   - p: Fixed-effect count.
///   - nTheta: The variance-parameter count.
/// - Returns: The group's `a_j' V_i^-1 a_k` block, and its `X_i'V_i^-1 a_k` rows.
private func generalInformationContribution<T: Real & Sendable>(
	cache: GeneralGroupCache<T>, dvPr: [[T]], nig: Int, p: Int, nTheta: Int
) -> (direct: [[T]], projected: [[T]]) where T: BinaryFloatingPoint {
	var viInvDvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: nTheta)
	for k in 0..<nTheta {
		for row in 0..<nig {
			var total = T.zero
			for col in 0..<nig { total += cache.viInv[row, col] * dvPr[k][col] }
			viInvDvPr[k][row] = total
		}
	}

	var projected = Array(repeating: Array(repeating: T.zero, count: p), count: nTheta)
	for k in 0..<nTheta {
		for localIdx in 0..<nig {
			let weight: T = viInvDvPr[k][localIdx]
			for j in 0..<p {
				projected[k][j] += cache.xiRows[localIdx][j] * weight
			}
		}
	}

	var direct = Array(repeating: Array(repeating: T.zero, count: nTheta), count: nTheta)
	for j in 0..<nTheta {
		for k in j..<nTheta {
			var val = T.zero
			for localIdx in 0..<nig {
				val += dvPr[j][localIdx] * viInvDvPr[k][localIdx]
			}
			direct[j][k] = val
			if j != k { direct[k][j] = val }
		}
	}
	return (direct, projected)
}

/// The Average Information matrix, once every group has contributed.
///
/// - Parameters:
///   - aiDirect: `SUM_i a_j,i' V_i^-1 a_k,i`, accumulated over groups.
///   - xtViInvDvPr: `SUM_i X_i'V_i^-1 a_k,i`, accumulated over groups.
///   - xtVinvXInv: `(X'V^-1 X)^-1`.
///   - nTheta: The variance-parameter count.
///   - p: Fixed-effect count.
/// - Returns: The symmetric `nTheta x nTheta` information matrix.
private func generalAssembleInformation<T: Real & Sendable>(
	aiDirect: [[T]], xtViInvDvPr: [[T]], xtVinvXInv: DenseMatrix<T>, nTheta: Int, p: Int
) -> [[T]] where T: BinaryFloatingPoint {
	var ai = Array(repeating: Array(repeating: T.zero, count: nTheta), count: nTheta)
	for j in 0..<nTheta {
		for k in j..<nTheta {
			var correction = T.zero
			for a in 0..<p {
				for b in 0..<p {
					let left: T = xtViInvDvPr[j][a] * xtVinvXInv[a, b]
					correction += left * xtViInvDvPr[k][b]
				}
			}
			let combined: T = aiDirect[j][k] - correction
			let value: T = combined / T(2)
			ai[j][k] = value
			if j != k { ai[k][j] = value }
		}
	}
	return ai
}

/// AI-REML update for the general LME model.
///
/// Returns the REML score and the Average Information matrix at the supplied variance
/// parameters, which the caller combines into a Newton-like step.
///
/// With `P = V^-1 - V^-1 X (X'V^-1 X)^-1 X'V^-1` the two quantities are
///
///     score[k] = -1/2 tr(P dV_k) + 1/2 r' P dV_k P r
///     ai[j][k] =  1/2 (dV_j P r)' P (dV_k P r)
///
/// Variance parameters are ordered: theta = (sigma_e², G[0,0], G[0,1], ..., G[0,r-1], G[1,1], G[1,2], ..., G[r-1,r-1])
/// i.e., sigma_e² first, then the upper triangle of G in row-major order.
///
/// `V` is block diagonal by group and every `dV_k` is too, so the trace and the score's
/// quadratic form both decompose into a sum over groups. `P` itself does **not** decompose:
/// its off-diagonal block is `-V_i^-1 X_i (X'V^-1 X)^-1 X_j'V_j^-1`, which is nonzero. Any
/// quantity that sandwiches a vector between two `P`s therefore needs the whole matrix, not
/// the diagonal blocks — which is why the information matrix is finished after the group
/// loop and the score is not. See `GeneralAIREMLOracleTests` for the dense check of both.
///
/// - Parameters:
///   - resid: The GLS residual `y - X beta`, by observation.
///   - xData: The fixed-effects design, by observation.
///   - zData: The random-effects design, by observation.
///   - m: Group count.
///   - r: Random effects per group.
///   - groupIdx: Row indices per group.
///   - gArr: The current random-effects covariance.
///   - sigmaE2: The current residual variance.
///   - p: Fixed-effect count.
/// - Returns: The score vector and Average Information matrix, both of dimension
///   `1 + r*(r+1)/2`.
/// - Throws: From ``DenseMatrix/choleskyInverse()`` and ``DenseMatrix/choleskySolve(_:)``
///   when a group's `V_g` or `X'V^-1 X` is not positive definite.
internal func generalAIREMLUpdate<T: Real & Sendable>(
	resid: [T], xData: [[T]], zData: [[T]],
	m: Int, r: Int, groupIdx: [[Int]],
	gArr: [[T]], sigmaE2: T, p: Int
) throws -> GeneralAIREMLResult<T> where T: BinaryFloatingPoint {

	let nTheta = 1 + r * (r + 1) / 2

	// theta[0] = sigma_e²; theta[1...] = upper triangle of G, row-major.
	var gParamMap = [(Int, Int)]()
	for i in 0..<r {
		for j in i..<r {
			gParamMap.append((i, j))
		}
	}

	let (groupCaches, xtVinvX) = try generalAIREMLCaches(
		resid: resid, xData: xData, zData: zData,
		m: m, r: r, p: p, groupIdx: groupIdx, gArr: gArr, sigmaE2: sigmaE2)

	let xtVinvXMat = try DenseMatrix(xtVinvX)
	let xtVinvXInv = try xtVinvXMat.choleskyInverse()

	let globalCorrection = generalAIREMLProjectionCorrection(
		caches: groupCaches, groupIdx: groupIdx, m: m, p: p, xtVinvXInv: xtVinvXInv)

	var score = Array(repeating: T.zero, count: nTheta)
	// The information's two halves: what each group contributes on its own, and the sums
	// its cross-group term is built from. Both are finished after the loop.
	var aiDirect = Array(repeating: Array(repeating: T.zero, count: nTheta), count: nTheta)
	var xtViInvDvPr = Array(repeating: Array(repeating: T.zero, count: p), count: nTheta)

	for g in 0..<m {
		let nig = groupIdx[g].count
		let cache = groupCaches[g]

		let pR = generalProjectedResidual(
			cache: cache, nig: nig, p: p, globalCorrection: globalCorrection)
		let pMat = generalProjectionBlock(
			cache: cache, nig: nig, p: p, xtVinvXInv: xtVinvXInv)
		let dvPr = generalDerivativeTimesProjected(
			cache: cache, pR: pR, nig: nig, nTheta: nTheta, gParamMap: gParamMap)
		let traces = generalProjectionTraces(
			pMat: pMat, cache: cache, nig: nig, nTheta: nTheta, gParamMap: gParamMap)

		for k in 0..<nTheta {
			var rPdVPr = T.zero
			for localIdx in 0..<nig { rPdVPr += pR[localIdx] * dvPr[k][localIdx] }
			let traceTerm: T = T(-1) / T(2) * traces[k]
			let quadraticTerm: T = T(1) / T(2) * rPdVPr
			score[k] += traceTerm + quadraticTerm
		}

		let contribution = generalInformationContribution(
			cache: cache, dvPr: dvPr, nig: nig, p: p, nTheta: nTheta)
		for j in 0..<nTheta {
			for k in 0..<nTheta {
				aiDirect[j][k] += contribution.direct[j][k]
			}
		}
		for k in 0..<nTheta {
			for j in 0..<p {
				xtViInvDvPr[k][j] += contribution.projected[k][j]
			}
		}
	}

	let ai = generalAssembleInformation(
		aiDirect: aiDirect, xtViInvDvPr: xtViInvDvPr,
		xtVinvXInv: xtVinvXInv, nTheta: nTheta, p: p)

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
