import Foundation
import Numerics

private func absVal<T: Real>(_ x: T) -> T {
	x < T.zero ? -x : x
}

/// Check whether a scalar parameter has converged using combined absolute + relative criteria.
private func paramHasConverged<T: Real>(old: T, new: T, tolerance: T) -> Bool {
	if new == T.zero && old == T.zero { return true }
	let absDiff = absVal(new - old)
	if absDiff < tolerance { return true }
	let relDiff = absDiff / T.maximum(absVal(old), T.ulpOfOne)
	return relDiff < tolerance
}

/// Fit a random intercept-and-slope linear mixed-effects model via REML.
///
/// Estimates fixed effects (beta) and the random-effects covariance matrix G
/// plus residual variance for the model:
/// ```
/// y_ij = x_ij' * beta + u_0i + u_1i * z_ij + e_ij
/// ```
/// where `[u_0i, u_1i]' ~ N(0, G)` with
/// `G = [[sigma_u0², sigma_u01], [sigma_u01, sigma_u1²]]`
/// and `e_ij ~ N(0, sigma_e²)`.
///
/// Uses Fisher scoring on the REML criterion. For each group i with n_i
/// observations, the marginal covariance is `V_i = Z_i G Z_i' + sigma_e² I`.
/// The Z_i matrix has columns `[1, z_ij]` for the random intercept and slope.
///
/// - Parameters:
///   - model: The random slope model specification.
///   - maxIterations: Maximum Fisher scoring iterations (default 100).
///   - tolerance: Relative convergence tolerance (default 1e-8).
/// - Returns: A ``RandomSlopeResult`` with all estimates and diagnostics.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups
///   or total observations do not exceed the number of fixed-effects parameters.
///   `BusinessMathError.mismatchedDimensions` if X rows != y length != groups length.
///   `BusinessMathError.invalidInput` if slopeColumn is out of range.
public func fitRandomSlope<T: Real>(
	_ model: RandomSlopeModel<T>,
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(100_000_000)
) throws -> RandomSlopeResult<T> where T: BinaryFloatingPoint {

	let y = model.response
	let grouping = model.grouping
	let N = y.count
	let p = model.fixedEffects.columns
	let slopeCol = model.slopeColumn

	// --- Validation ---
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

	// Extract X as 2D array for fast inner-loop access
	var xData = Array(repeating: Array(repeating: T.zero, count: p), count: N)
	for i in 0..<N {
		for j in 0..<p {
			xData[i][j] = model.fixedEffects[i, j]
		}
	}

	let m = grouping.groupCount
	let ni = grouping.groupSizes
	let groupIdx = grouping.groupIndices

	// Extract slope variable values for each observation
	var zSlope = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		zSlope[i] = xData[i][slopeCol]
	}

	// --- Initialize variance components from method of moments ---
	let olsBeta = try slopeOLSEstimate(xData: xData, y: y, N: N, p: p)
	var residOLS = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * olsBeta[j] }
		residOLS[i] = y[i] - fitted
	}

	// One-way ANOVA decomposition for initial sigma_e² and sigma_u0²
	var ssWithin = T.zero
	var ssBetween = T.zero
	let grandMeanResid = residOLS.reduce(T.zero, +) / T(N)
	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		let groupMean = indices.reduce(T.zero) { $0 + residOLS[$1] } / nig
		ssBetween += nig * (groupMean - grandMeanResid) * (groupMean - grandMeanResid)
		for idx in indices {
			let diff = residOLS[idx] - groupMean
			ssWithin += diff * diff
		}
	}

	let dfWithin = T(N - m)
	var sigmaE2 = dfWithin > T.zero ? ssWithin / dfWithin : T(1)
	sigmaE2 = T.maximum(sigmaE2, T.ulpOfOne)

	let msBetween = T(m - 1) > T.zero ? ssBetween / T(m - 1) : T.zero
	let nBar = T(N) / T(m)
	var g00 = msBetween > sigmaE2 ? (msBetween - sigmaE2) / nBar : T(1) / T(10)

	// Initialize slope variance from between-group slope variation
	var g11 = T(1) / T(10)
	var groupSlopes = Array(repeating: T.zero, count: m)
	var slopeGrandMean = T.zero
	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		guard nig > T(1) else { continue }
		// Simple within-group regression of residuals on z
		var sumZ = T.zero
		var sumR = T.zero
		var sumZR = T.zero
		var sumZZ = T.zero
		for idx in indices {
			let z = zSlope[idx]
			let r = residOLS[idx]
			sumZ += z
			sumR += r
			sumZR += z * r
			sumZZ += z * z
		}
		let denom = nig * sumZZ - sumZ * sumZ
		if absVal(denom) > T.ulpOfOne {
			groupSlopes[g] = (nig * sumZR - sumZ * sumR) / denom
		}
		slopeGrandMean += groupSlopes[g]
	}
	slopeGrandMean /= T(m)
	var slopeVar = T.zero
	for g in 0..<m {
		let diff = groupSlopes[g] - slopeGrandMean
		slopeVar += diff * diff
	}
	if m > 1 {
		slopeVar /= T(m - 1)
	}
	if slopeVar > T.ulpOfOne {
		g11 = slopeVar
	}

	// Initialize covariance as zero
	var g01 = T.zero

	// G matrix: [[g00, g01], [g01, g11]]
	// Variance parameter vector theta = (sigmaE2, g00, g11, g01) — 4 parameters

	// --- EM warm-up + AI-REML ---
	// Use a few EM iterations first to stabilize the variance estimates,
	// then switch to AI-REML for fast quadratic convergence.
	// EM guarantees monotone log-likelihood improvement, preventing the
	// aggressive AI-REML step from overshooting on poorly-conditioned data.
	let emWarmup = 5
	var converged = false
	var iteration = 0
	var prevLogLik = -T.greatestFiniteMagnitude

	for iter in 0..<maxIterations {
		iteration = iter + 1

		let glsResult = try slopeGLSEstimate(
			xData: xData, y: y, zSlope: zSlope, N: N, p: p, m: m,
			ni: ni, groupIdx: groupIdx,
			g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2)

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

		var newSigmaE2: T
		var newG00: T
		var newG11: T
		var newG01: T

		if iter < emWarmup {
			// EM update: monotone and stable, good for warm-up
			let emResult = try slopeEMUpdate(
				resid: resid, zSlope: zSlope, m: m, ni: ni, groupIdx: groupIdx,
				g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, N: N)

			newSigmaE2 = T.maximum(emResult.sigmaE2, T.ulpOfOne)
			newG00 = T.maximum(emResult.g00, T.zero)
			newG11 = T.maximum(emResult.g11, T.zero)
			newG01 = emResult.g01
		} else {
			// AI-REML update: compute score vector and average information matrix
			let aiResult = try slopeAIREMLUpdate(
				resid: resid, xData: xData, zSlope: zSlope,
				m: m, ni: ni, groupIdx: groupIdx,
				g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2,
				N: N, p: p)

			// Solve AI * delta = score for the Newton step
			let aiMat = try DenseMatrix(aiResult.ai)
			var delta: [T]
			do {
				delta = try aiMat.choleskySolve(aiResult.score)
			} catch {
				// silent: AI matrix may not be positive definite — fall back to diagonal step
				delta = (0..<4).map { i -> T in
					let diag = aiResult.ai[i][i]
					guard diag > T.ulpOfOne else { return T.zero }
					return aiResult.score[i] / diag
				}
			}

			// Step-halving for feasibility (no log-likelihood evaluation needed)
			var step = T(1)
			for _ in 0..<20 {
				let candE = sigmaE2 + step * delta[0]
				let candG00 = g00 + step * delta[1]
				let candG11 = g11 + step * delta[2]
				let candG01 = g01 + step * delta[3]

				let feasible = candE > T.ulpOfOne
					&& candG00 >= T.zero
					&& candG11 >= T.zero
					&& candG00 * candG11 >= candG01 * candG01

				if feasible { break }
				step = step / T(2)
			}

			newSigmaE2 = T.maximum(sigmaE2 + step * delta[0], T.ulpOfOne)
			newG00 = T.maximum(g00 + step * delta[1], T.zero)
			newG11 = T.maximum(g11 + step * delta[2], T.zero)
			newG01 = g01 + step * delta[3]
		}

		// Ensure G stays positive semi-definite
		let maxCov = T.sqrt(newG00 * newG11)
		if absVal(newG01) > maxCov {
			newG01 = newG01 > T.zero ? maxCov : -maxCov
		}

		// Check parameter convergence (relative + absolute).
		// For the covariance parameter, detect boundary convergence:
		// when |rho| = 1, g01 is determined by g00 and g11.
		let absTol = tolerance
		let paramConvergedE = paramHasConverged(old: sigmaE2, new: newSigmaE2, tolerance: absTol)
		let paramConverged00 = paramHasConverged(old: g00, new: newG00, tolerance: absTol)
		let paramConverged11 = paramHasConverged(old: g11, new: newG11, tolerance: absTol)

		let atCovBoundary: Bool
		if maxCov > T.ulpOfOne {
			let absRho = absVal(newG01) / maxCov
			atCovBoundary = absRho > T(1) - T(1) / T(1000)
		} else {
			atCovBoundary = true
		}
		let paramConverged01: Bool
		if atCovBoundary {
			paramConverged01 = paramConverged00 && paramConverged11
		} else {
			paramConverged01 = paramHasConverged(old: g01, new: newG01, tolerance: absTol)
		}

		sigmaE2 = newSigmaE2
		g00 = newG00
		g11 = newG11
		g01 = newG01

		if paramConvergedE && paramConverged00 && paramConverged11 && paramConverged01 {
			converged = true
			break
		}
	}

	// --- Final estimates ---
	let final = try slopeGLSEstimate(
		xData: xData, y: y, zSlope: zSlope, N: N, p: p, m: m,
		ni: ni, groupIdx: groupIdx,
		g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2)

	let beta = final.beta

	// Marginal residuals
	var marginalResid = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * beta[j] }
		marginalResid[i] = y[i] - fitted
	}

	// BLUPs: u_hat = G Z_i' V_i^{-1} r_i
	var blupIntercepts = Array(repeating: T.zero, count: m)
	var blupSlopes = Array(repeating: T.zero, count: m)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		// Build Z_i (nig x 2) and r_i (nig x 1)
		var ri = Array(repeating: T.zero, count: nig)
		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			ri[localIdx] = marginalResid[obsIdx]
			zi[localIdx][0] = T(1)          // intercept
			zi[localIdx][1] = zSlope[obsIdx] // slope variable
		}

		// V_i = Z_i G Z_i' + sigmaE2 * I (nig x nig)
		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
		let viMat = try DenseMatrix(viData)

		// V_i^{-1} r_i
		let viInvR = try viMat.choleskySolve(ri)

		// G Z_i' V_i^{-1} r_i
		// Z_i' V_i^{-1} r_i is a 2-vector
		var ztViInvR = [T.zero, T.zero]
		for j in 0..<nig {
			ztViInvR[0] += zi[j][0] * viInvR[j]
			ztViInvR[1] += zi[j][1] * viInvR[j]
		}

		// G * (Z_i' V_i^{-1} r_i)
		blupIntercepts[g] = g00 * ztViInvR[0] + g01 * ztViInvR[1]
		blupSlopes[g] = g01 * ztViInvR[0] + g11 * ztViInvR[1]
	}

	// Conditional residuals and fitted values
	var conditionalResid = Array(repeating: T.zero, count: N)
	var fittedValues = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		let g = grouping.groups[i]
		var xBeta = T.zero
		for j in 0..<p { xBeta += xData[i][j] * beta[j] }
		let randomPart = blupIntercepts[g] + blupSlopes[g] * zSlope[i]
		fittedValues[i] = xBeta + randomPart
		conditionalResid[i] = y[i] - fittedValues[i]
	}

	// Standard errors of fixed effects
	let seResult = try slopeFixedEffectsSE(
		xData: xData, zSlope: zSlope, N: N, p: p, m: m,
		ni: ni, groupIdx: groupIdx,
		g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2)

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

	// Correlation
	let denomCorr = T.sqrt(g00 * g11)
	let correlation: T
	if denomCorr > T.ulpOfOne {
		correlation = g01 / denomCorr
	} else {
		correlation = T.zero
	}

	// Information criteria
	// Variance parameters: sigmaE2 + 3 unique G elements = 4
	let nParams = T(p + 4)
	let aic = T(-2) * final.remlLogLik + T(2) * nParams
	let bic = T(-2) * final.remlLogLik + nParams * T.log(T(N))

	return RandomSlopeResult(
		beta: beta,
		standardErrors: seResult,
		tStatistics: tStats,
		pValues: pvals,
		varianceIntercept: g00,
		varianceSlope: g11,
		covarianceInterceptSlope: g01,
		correlationInterceptSlope: correlation,
		varianceResidual: sigmaE2,
		remlLogLikelihood: final.remlLogLik,
		aic: aic,
		bic: bic,
		randomIntercepts: blupIntercepts,
		randomSlopes: blupSlopes,
		residuals: conditionalResid,
		marginalResiduals: marginalResid,
		fittedValues: fittedValues,
		observations: N,
		groups: m,
		fixedEffectsCount: p,
		iterations: iteration,
		converged: converged)
}

// MARK: - Internal Helpers

/// Build V_i = Z_i G Z_i' + sigmaE2 * I for a single group.
private func buildVi<T: Real>(
	zi: [[T]], g00: T, g11: T, g01: T, sigmaE2: T, nig: Int
) throws -> [[T]] where T: BinaryFloatingPoint {
	// Z_i is nig x 2, G is 2x2
	// V_i = Z_i G Z_i' + sigmaE2 * I
	var vi = Array(repeating: Array(repeating: T.zero, count: nig), count: nig)
	for r in 0..<nig {
		for c in 0..<nig {
			// (Z_i G Z_i')[r,c] = sum over a,b of z[r][a] * G[a][b] * z[c][b]
			let z_r0 = zi[r][0]
			let z_r1 = zi[r][1]
			let z_c0 = zi[c][0]
			let z_c1 = zi[c][1]

			let val = z_r0 * (g00 * z_c0 + g01 * z_c1)
				+ z_r1 * (g01 * z_c0 + g11 * z_c1)
			vi[r][c] = val
			if r == c {
				vi[r][c] += sigmaE2
			}
		}
	}
	return vi
}

private struct SlopeGLSResult<T: Real> {
	let beta: [T]
	let remlLogLik: T
}

/// OLS estimate: beta = (X'X)^{-1} X'y
private func slopeOLSEstimate<T: Real>(
	xData: [[T]], y: [T], N: Int, p: Int
) throws -> [T] where T: BinaryFloatingPoint {
	var xtx = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var xty = Array(repeating: T.zero, count: p)
	for i in 0..<N {
		for j in 0..<p {
			xty[j] += xData[i][j] * y[i]
			for k in 0..<p {
				xtx[j][k] += xData[i][j] * xData[i][k]
			}
		}
	}
	let xtxMat = try DenseMatrix(xtx)
	return try xtxMat.solve(xty)
}

/// GLS estimate of beta and REML log-likelihood for the random slope model.
///
/// Builds per-group V_i = Z_i G Z_i' + sigma_e² I, inverts via Cholesky,
/// then computes beta = (X'V^{-1}X)^{-1} X'V^{-1}y and the REML criterion.
private func slopeGLSEstimate<T: Real>(
	xData: [[T]], y: [T], zSlope: [T], N: Int, p: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	g00: T, g11: T, g01: T, sigmaE2: T
) throws -> SlopeGLSResult<T> where T: BinaryFloatingPoint {

	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var xtVinvY = Array(repeating: T.zero, count: p)
	var logDetV = T.zero

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		// Build Z_i and extract x rows and y values for this group
		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		var yi = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			zi[localIdx][0] = T(1)
			zi[localIdx][1] = zSlope[obsIdx]
			xiRows[localIdx] = xData[obsIdx]
			yi[localIdx] = y[obsIdx]
		}

		// V_i = Z_i G Z_i' + sigmaE2 * I
		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
		let viMat = try DenseMatrix(viData)

		// log|V_i| via Cholesky
		logDetV += try viMat.logDeterminant()

		// V_i^{-1} X_i (solve V_i * W = X_i for each column of X_i)
		// V_i^{-1} y_i
		let viInvY = try viMat.choleskySolve(yi)

		// Build X_i as a matrix and solve
		let xiMat = try DenseMatrix(xiRows)
		let viInvXi = try viMat.choleskySolve(xiMat)

		// Accumulate X'V^{-1}X and X'V^{-1}y
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

		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			zi[localIdx][0] = T(1)
			zi[localIdx][1] = zSlope[obsIdx]
			var fitted = T.zero
			for j in 0..<p { fitted += xData[obsIdx][j] * beta[j] }
			ri[localIdx] = y[obsIdx] - fitted
		}

		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
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

	return SlopeGLSResult(beta: beta, remlLogLik: logLik)
}

private struct SlopeEMResult<T: Real> {
	let sigmaE2: T
	let g00: T
	let g11: T
	let g01: T
}

/// EM update for variance components in the random slope model.
///
/// Guarantees monotone log-likelihood improvement. Used for warm-up
/// iterations before switching to the faster AI-REML algorithm.
private func slopeEMUpdate<T: Real>(
	resid: [T], zSlope: [T], m: Int, ni: [Int], groupIdx: [[Int]],
	g00: T, g11: T, g01: T, sigmaE2: T, N: Int
) throws -> SlopeEMResult<T> where T: BinaryFloatingPoint {

	let gMat = [[g00, g01], [g01, g11]]
	var sumG = [[T.zero, T.zero], [T.zero, T.zero]]
	var sumResidVar = T.zero

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			zi[localIdx][0] = T(1)
			zi[localIdx][1] = zSlope[obsIdx]
			ri[localIdx] = resid[obsIdx]
		}

		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
		let viMat = try DenseMatrix(viData)
		let viInv = try viMat.choleskyInverse()
		let viInvR = try viMat.choleskySolve(ri)

		// Z_i' V_i^{-1} r_i (2-vector)
		var ztViInvR = [T.zero, T.zero]
		for j in 0..<nig {
			ztViInvR[0] += zi[j][0] * viInvR[j]
			ztViInvR[1] += zi[j][1] * viInvR[j]
		}

		// u_hat = G Z_i' V_i^{-1} r_i
		let uHat0 = gMat[0][0] * ztViInvR[0] + gMat[0][1] * ztViInvR[1]
		let uHat1 = gMat[1][0] * ztViInvR[0] + gMat[1][1] * ztViInvR[1]

		// Conditional covariance: Cov(u|y) = G - G Z_i' V_i^{-1} Z_i G
		var ztViInvZ = [[T.zero, T.zero], [T.zero, T.zero]]
		for r in 0..<nig {
			for c in 0..<nig {
				let viInvRC = viInv[r, c]
				ztViInvZ[0][0] += zi[r][0] * viInvRC * zi[c][0]
				ztViInvZ[0][1] += zi[r][0] * viInvRC * zi[c][1]
				ztViInvZ[1][0] += zi[r][1] * viInvRC * zi[c][0]
				ztViInvZ[1][1] += zi[r][1] * viInvRC * zi[c][1]
			}
		}

		// G Z' V^{-1} Z G
		var gZVZG = [[T.zero, T.zero], [T.zero, T.zero]]
		for r in 0..<2 {
			for c in 0..<2 {
				for a in 0..<2 {
					for b in 0..<2 {
						gZVZG[r][c] += gMat[r][a] * ztViInvZ[a][b] * gMat[b][c]
					}
				}
			}
		}

		// E[u u'|y] = u_hat u_hat' + (G - G Z' V^{-1} Z G)
		sumG[0][0] += uHat0 * uHat0 + gMat[0][0] - gZVZG[0][0]
		sumG[0][1] += uHat0 * uHat1 + gMat[0][1] - gZVZG[0][1]
		sumG[1][0] += uHat0 * uHat1 + gMat[0][1] - gZVZG[0][1]
		sumG[1][1] += uHat1 * uHat1 + gMat[1][1] - gZVZG[1][1]

		// Residual variance: sigma_e^2_new contribution
		var ssResid = T.zero
		for (_, obsIdx) in indices.enumerated() {
			let eHat = resid[obsIdx] - (uHat0 + uHat1 * zSlope[obsIdx])
			ssResid += eHat * eHat
		}
		var trViInv = T.zero
		for j in 0..<nig { trViInv += viInv[j, j] }
		sumResidVar += ssResid + sigmaE2 * (T(nig) - sigmaE2 * trViInv)
	}

	return SlopeEMResult(
		sigmaE2: sumResidVar / T(N),
		g00: sumG[0][0] / T(m),
		g11: sumG[1][1] / T(m),
		g01: sumG[0][1] / T(m))
}

private struct SlopeAIREMLResult<T: Real> {
	let score: [T]     // 4-vector: d(logLik)/d(sigmaE2, g00, g11, g01)
	let ai: [[T]]      // 4x4 average information matrix
}

private struct SlopeGroupCache<T: Real> {
	let viInv: DenseMatrix<T>
	let viInvR: [T]
	let viInvXi: DenseMatrix<T>
	let zi: [[T]]
	let ri: [T]
	let xiRows: [[T]]
}

/// Compute REML score vector and Average Information matrix for variance parameters.
///
/// The 4 variance parameters are ordered: theta = (sigma_e², g00, g11, g01).
///
/// The score for parameter theta_k is:
/// ```
/// S_k = -1/2 * sum_i [ tr(P_i dV_i/dtheta_k) - r_i' P_i (dV_i/dtheta_k) P_i r_i ]
/// ```
///
/// The average information is:
/// ```
/// AI[j,k] = 1/2 * r' P (dV/dtheta_j) P (dV/dtheta_k) P r
/// ```
///
/// where P = V^{-1} - V^{-1} X (X'V^{-1}X)^{-1} X' V^{-1}.
private func slopeAIREMLUpdate<T: Real>(
	resid: [T], xData: [[T]], zSlope: [T],
	m: Int, ni: [Int], groupIdx: [[Int]],
	g00: T, g11: T, g01: T, sigmaE2: T,
	N: Int, p: Int
) throws -> SlopeAIREMLResult<T> where T: BinaryFloatingPoint {

	// We need P_i r_i for each group, where P = V^{-1} - V^{-1} X (X'V^{-1}X)^{-1} X' V^{-1}
	// First pass: compute X'V^{-1}X and per-group V_i^{-1} r_i, V_i^{-1} X_i
	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)

	var groupCaches = [SlopeGroupCache<T>]()

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		var ri = Array(repeating: T.zero, count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			zi[localIdx][0] = T(1)
			zi[localIdx][1] = zSlope[obsIdx]
			xiRows[localIdx] = xData[obsIdx]
			ri[localIdx] = resid[obsIdx]
		}

		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
		let viMat = try DenseMatrix(viData)
		let viInv = try viMat.choleskyInverse()
		let viInvR = try viMat.choleskySolve(ri)
		let xiMat = try DenseMatrix(xiRows)
		let viInvXi = try viMat.choleskySolve(xiMat)

		// Accumulate X'V^{-1}X
		for localIdx in 0..<nig {
			for j in 0..<p {
				for k in 0..<p {
					xtVinvX[j][k] += xiRows[localIdx][j] * viInvXi[localIdx, k]
				}
			}
		}

		groupCaches.append(SlopeGroupCache(
			viInv: viInv, viInvR: viInvR, viInvXi: viInvXi,
			zi: zi, ri: ri, xiRows: xiRows))
	}

	// (X'V^{-1}X)^{-1}
	let xtVinvXMat = try DenseMatrix(xtVinvX)
	let xtVinvXInv = try xtVinvXMat.choleskyInverse()

	// Score and AI accumulators (4 parameters: sigmaE2, g00, g11, g01)
	var score = Array(repeating: T.zero, count: 4)
	var ai = Array(repeating: Array(repeating: T.zero, count: 4), count: 4)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count
		let cache = groupCaches[g]

		// Compute P_i r_i = V_i^{-1} r_i - V_i^{-1} X_i (X'V^{-1}X)^{-1} X_i' V_i^{-1} r_i
		// First: X_i' V_i^{-1} r_i (p-vector)
		var xiTviInvR = Array(repeating: T.zero, count: p)
		for localIdx in 0..<nig {
			for j in 0..<p {
				xiTviInvR[j] += cache.xiRows[localIdx][j] * cache.viInvR[localIdx]
			}
		}

		// (X'V^{-1}X)^{-1} X_i' V_i^{-1} r_i (p-vector)
		var correction = Array(repeating: T.zero, count: p)
		for j in 0..<p {
			for k in 0..<p {
				correction[j] += xtVinvXInv[j, k] * xiTviInvR[k]
			}
		}

		// V_i^{-1} X_i * correction (nig-vector)
		var viInvXCorr = Array(repeating: T.zero, count: nig)
		for localIdx in 0..<nig {
			for j in 0..<p {
				viInvXCorr[localIdx] += cache.viInvXi[localIdx, j] * correction[j]
			}
		}

		// P_i r_i
		var pR = Array(repeating: T.zero, count: nig)
		for localIdx in 0..<nig {
			pR[localIdx] = cache.viInvR[localIdx] - viInvXCorr[localIdx]
		}

		// Compute P_i itself: P_i = V_i^{-1} - V_i^{-1} X_i (X'V^{-1}X)^{-1} X_i' V_i^{-1}
		// We need tr(P_i dV_i/dtheta_k) for the score.
		// P_i = viInv - viInvXi * xtVinvXInv * viInvXi'
		var pMat = Array(repeating: Array(repeating: T.zero, count: nig), count: nig)
		for r in 0..<nig {
			for c in 0..<nig {
				pMat[r][c] = cache.viInv[r, c]
				// Subtract correction: sum_j,k viInvXi[r,j] * xtVinvXInv[j,k] * viInvXi[c,k]
				for j in 0..<p {
					for k in 0..<p {
						pMat[r][c] -= cache.viInvXi[r, j] * xtVinvXInv[j, k] * cache.viInvXi[c, k]
					}
				}
			}
		}

		// Derivatives of V_i w.r.t. each parameter:
		// dV_i/d(sigmaE2) = I_ni
		// dV_i/d(g00) = Z_i[:,0] Z_i[:,0]' (outer product of intercept column)
		// dV_i/d(g11) = Z_i[:,1] Z_i[:,1]' (outer product of slope column)
		// dV_i/d(g01) = Z_i[:,0] Z_i[:,1]' + Z_i[:,1] Z_i[:,0]' (symmetric cross)

		// For each derivative dV_k, compute:
		// (a) tr(P_i * dV_k) for the score
		// (b) dV_k * P_i * r_i for the AI matrix

		// dV * P * r vectors for each parameter
		var dvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: 4)

		// --- Parameter 0: sigmaE2, dV/d(sigmaE2) = I ---
		// tr(P * I) = tr(P)
		var trP = T.zero
		for localIdx in 0..<nig {
			trP += pMat[localIdx][localIdx]
		}
		// r' P dV P r for score: P*r is pR; dV = I so dV * P * r = P * r = pR
		var rPdVPr0 = T.zero
		for localIdx in 0..<nig {
			rPdVPr0 += pR[localIdx] * pR[localIdx]
		}
		let score0term1: T = T(-1) / T(2) * trP
		let score0term2: T = T(1) / T(2) * rPdVPr0
		score[0] += score0term1 + score0term2
		// dV[0] * P * r = I * pR = pR
		for localIdx in 0..<nig {
			dvPr[0][localIdx] = pR[localIdx]
		}

		// --- Parameter 1: g00, dV/d(g00) = z0 z0' ---
		var trPdV1 = T.zero
		for r in 0..<nig {
			for c in 0..<nig {
				trPdV1 += pMat[r][c] * cache.zi[c][0] * cache.zi[r][0]
			}
		}
		var rPdVPr1 = T.zero
		// dV1 * pR: (z0 z0') * pR
		var z0TpR = T.zero  // z0' * pR
		for localIdx in 0..<nig {
			z0TpR += cache.zi[localIdx][0] * pR[localIdx]
		}
		for localIdx in 0..<nig {
			dvPr[1][localIdx] = cache.zi[localIdx][0] * z0TpR
			rPdVPr1 += pR[localIdx] * dvPr[1][localIdx]
		}
		let score1term1: T = T(-1) / T(2) * trPdV1
		let score1term2: T = T(1) / T(2) * rPdVPr1
		score[1] += score1term1 + score1term2

		// --- Parameter 2: g11, dV/d(g11) = z1 z1' ---
		var trPdV2 = T.zero
		for r in 0..<nig {
			for c in 0..<nig {
				trPdV2 += pMat[r][c] * cache.zi[c][1] * cache.zi[r][1]
			}
		}
		var z1TpR = T.zero
		for localIdx in 0..<nig {
			z1TpR += cache.zi[localIdx][1] * pR[localIdx]
		}
		for localIdx in 0..<nig {
			dvPr[2][localIdx] = cache.zi[localIdx][1] * z1TpR
		}
		var rPdVPr2 = T.zero
		for localIdx in 0..<nig {
			rPdVPr2 += pR[localIdx] * dvPr[2][localIdx]
		}
		let score2term1: T = T(-1) / T(2) * trPdV2
		let score2term2: T = T(1) / T(2) * rPdVPr2
		score[2] += score2term1 + score2term2

		// --- Parameter 3: g01, dV/d(g01) = z0 z1' + z1 z0' ---
		var trPdV3 = T.zero
		for r in 0..<nig {
			for c in 0..<nig {
				trPdV3 += pMat[r][c] * (cache.zi[c][0] * cache.zi[r][1]
										 + cache.zi[c][1] * cache.zi[r][0])
			}
		}
		// dV3 * pR = (z0 z1' + z1 z0') * pR = z0 * (z1' pR) + z1 * (z0' pR)
		for localIdx in 0..<nig {
			dvPr[3][localIdx] = cache.zi[localIdx][0] * z1TpR + cache.zi[localIdx][1] * z0TpR
		}
		var rPdVPr3 = T.zero
		for localIdx in 0..<nig {
			rPdVPr3 += pR[localIdx] * dvPr[3][localIdx]
		}
		let score3term1: T = T(-1) / T(2) * trPdV3
		let score3term2: T = T(1) / T(2) * rPdVPr3
		score[3] += score3term1 + score3term2

		// --- Average Information matrix: AI[j,k] = 1/2 * (dV_j P r)' P (dV_k P r) ---
		// First compute P * (dV_k * P * r) for each k
		var pDvPr = Array(repeating: Array(repeating: T.zero, count: nig), count: 4)
		for k in 0..<4 {
			// P * dvPr[k] using P = viInv - viInvXi * xtVinvXInv * viInvXi'
			// But we already have pMat, so just multiply
			for r in 0..<nig {
				for c in 0..<nig {
					pDvPr[k][r] += pMat[r][c] * dvPr[k][c]
				}
			}
		}

		// AI[j,k] += 1/2 * dvPr[j]' * pDvPr[k]
		// But AI is symmetric so: AI[j,k] = 1/2 * r' P dVj P dVk P r
		// = 1/2 * (P dVj P r)' (dVk P r) ... actually let's use the
		// direct formula: 1/2 * dvPr[j]' * P * dvPr[k]
		for j in 0..<4 {
			for k in j..<4 {
				var val = T.zero
				for localIdx in 0..<nig {
					val += dvPr[j][localIdx] * pDvPr[k][localIdx]
				}
				val = val / T(2)
				ai[j][k] += val
				if j != k {
					ai[k][j] += val
				}
			}
		}
	}

	return SlopeAIREMLResult(score: score, ai: ai)
}

/// Standard errors of fixed effects: sqrt(diag((X'V^{-1}X)^{-1}))
private func slopeFixedEffectsSE<T: Real>(
	xData: [[T]], zSlope: [T], N: Int, p: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	g00: T, g11: T, g01: T, sigmaE2: T
) throws -> [T] where T: BinaryFloatingPoint {

	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = indices.count

		var zi = Array(repeating: Array(repeating: T.zero, count: 2), count: nig)
		var xiRows = Array(repeating: Array(repeating: T.zero, count: p), count: nig)
		for (localIdx, obsIdx) in indices.enumerated() {
			zi[localIdx][0] = T(1)
			zi[localIdx][1] = zSlope[obsIdx]
			xiRows[localIdx] = xData[obsIdx]
		}

		let viData = try buildVi(zi: zi, g00: g00, g11: g11, g01: g01, sigmaE2: sigmaE2, nig: nig)
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
