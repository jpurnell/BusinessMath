import Foundation
import Numerics

private func absVal<T: Real>(_ x: T) -> T {
	x < T.zero ? -x : x
}

/// Fit a random-intercept linear mixed-effects model via REML.
///
/// Estimates fixed effects (beta) and variance components (sigma_u², sigma_e²)
/// for the model:
/// ```
/// y_ij = x_ij' * beta + u_i + e_ij
/// ```
/// where u_i ~ N(0, sigma_u²) and e_ij ~ N(0, sigma_e²).
///
/// Uses Fisher scoring on the profiled REML criterion. The compound symmetry
/// structure of V_i = sigma_u² * J + sigma_e² * I admits closed-form inverse
/// (Sherman-Morrison), making each iteration O(N * p²) instead of O(N³).
///
/// - Parameters:
///   - model: The random intercept model specification.
///   - maxIterations: Maximum Fisher scoring iterations (default 100).
///   - tolerance: Relative convergence tolerance for REML log-likelihood (default 1e-8).
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

	// Validate dimensions
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

	var xData = Array(repeating: Array(repeating: T.zero, count: p), count: N)
	for i in 0..<N {
		for j in 0..<p {
			xData[i][j] = model.fixedEffects[i, j]
		}
	}

	let m = grouping.groupCount
	let ni = grouping.groupSizes
	let groupIdx = grouping.groupIndices

	// --- Initialize variance components from method of moments ---
	// OLS residuals for initialization
	let olsBeta = try olsEstimate(xData: xData, y: y, N: N, p: p)
	var residOLS = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * olsBeta[j] }
		residOLS[i] = y[i] - fitted
	}

	// One-way ANOVA decomposition of OLS residuals for init
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
	var sigmaU2 = msBetween > sigmaE2 ? (msBetween - sigmaE2) / nBar : T.zero

	// --- Fisher Scoring ---
	var converged = false
	var iteration = 0
	var prevLogLik = -T.greatestFiniteMagnitude

	for iter in 0..<maxIterations {
		iteration = iter + 1

		// Compute GLS beta and REML criterion
		let glsResult = try glsEstimate(
			xData: xData, y: y, N: N, p: p, m: m,
			ni: ni, groupIdx: groupIdx,
			sigmaU2: sigmaU2, sigmaE2: sigmaE2)

		let beta = glsResult.beta
		let logLik = glsResult.remlLogLik

		// Check log-likelihood convergence
		if iter > 0 {
			let relChange: T
			if absVal(prevLogLik) > T.zero {
				relChange = absVal(logLik - prevLogLik) / absVal(prevLogLik)
			} else {
				relChange = absVal(logLik - prevLogLik)
			}
			if relChange < tolerance {
				converged = true
				prevLogLik = logLik
				break
			}
		}
		prevLogLik = logLik

		// Compute residuals
		var resid = Array(repeating: T.zero, count: N)
		for i in 0..<N {
			var fitted = T.zero
			for j in 0..<p { fitted += xData[i][j] * beta[j] }
			resid[i] = y[i] - fitted
		}

		// Fisher scoring update
		let update = fisherScoringUpdate(
			resid: resid, m: m, ni: ni, groupIdx: groupIdx,
			sigmaU2: sigmaU2, sigmaE2: sigmaE2, N: N)

		var newSigmaE2 = sigmaE2 + update.deltaSigmaE2
		let newSigmaU2 = sigmaU2 + update.deltaSigmaU2

		// Step halving only for sigma_e² (must stay positive);
		// sigma_u² is clamped independently at the boundary.
		var halvings = 0
		while newSigmaE2 <= T.zero && halvings < 10 {
			let factor = T(1) / T(1 << (halvings + 1))
			newSigmaE2 = sigmaE2 + factor * update.deltaSigmaE2
			halvings += 1
		}

		let updatedE2 = T.maximum(newSigmaE2, T.ulpOfOne)
		let updatedU2 = T.maximum(newSigmaU2, T.zero)

		// Check parameter convergence (catches boundary cases where
		// log-likelihood oscillates but parameters have stabilized)
		let paramChangeE = absVal(updatedE2 - sigmaE2) / T.maximum(absVal(sigmaE2), T.ulpOfOne)
		let paramChangeU: T
		if updatedU2 == T.zero && sigmaU2 == T.zero {
			paramChangeU = T.zero
		} else {
			paramChangeU = absVal(updatedU2 - sigmaU2) / T.maximum(absVal(sigmaU2), T.ulpOfOne)
		}
		if paramChangeE < tolerance && paramChangeU < tolerance {
			sigmaE2 = updatedE2
			sigmaU2 = updatedU2
			converged = true
			break
		}

		sigmaE2 = updatedE2
		sigmaU2 = updatedU2
	}

	// --- Final estimates ---
	let final = try glsEstimate(
		xData: xData, y: y, N: N, p: p, m: m,
		ni: ni, groupIdx: groupIdx,
		sigmaU2: sigmaU2, sigmaE2: sigmaE2)

	let beta = final.beta

	// Residuals
	var marginalResid = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		var fitted = T.zero
		for j in 0..<p { fitted += xData[i][j] * beta[j] }
		marginalResid[i] = y[i] - fitted
	}

	// BLUPs: u_hat_i = (sigma_u² / a_i) * sum_j r_ij
	var blups = Array(repeating: T.zero, count: m)
	for g in 0..<m {
		let ai = sigmaE2 + T(ni[g]) * sigmaU2
		guard ai > T.zero else { continue }
		let sumResid = groupIdx[g].reduce(T.zero) { $0 + marginalResid[$1] }
		blups[g] = sigmaU2 * sumResid / ai
	}

	// Conditional residuals and fitted values
	var conditionalResid = Array(repeating: T.zero, count: N)
	var fittedValues = Array(repeating: T.zero, count: N)
	for i in 0..<N {
		let g = grouping.groups[i]
		var xBeta = T.zero
		for j in 0..<p { xBeta += xData[i][j] * beta[j] }
		fittedValues[i] = xBeta + blups[g]
		conditionalResid[i] = y[i] - fittedValues[i]
	}

	// Standard errors of fixed effects: SE = sqrt(diag((X'V^{-1}X)^{-1}))
	let seResult = try fixedEffectsSE(
		xData: xData, N: N, p: p, m: m,
		ni: ni, groupIdx: groupIdx,
		sigmaU2: sigmaU2, sigmaE2: sigmaE2)

	let tStats = (0..<p).map { j -> T in
		guard seResult[j] > T.zero else { return T.zero }
		return beta[j] / seResult[j]
	}

	// Approximate df via Satterthwaite (simplified: use N - p for now)
	let dfInt = N - p
	let pvals: [T] = try tStats.map { t -> T in
		guard dfInt > 0 else { return T(1) }
		let absT = absVal(t)
		let pOneSided: T = try tCDF(t: absT, df: dfInt)
		return T(2) * (T(1) - pOneSided)
	}

	// ICC
	let totalVar = sigmaU2 + sigmaE2
	let iccVal = totalVar > T.zero ? sigmaU2 / totalVar : T.zero

	// Information criteria
	let nParams = T(p + 2) // p fixed + sigma_u² + sigma_e²
	let aic = T(-2) * final.remlLogLik + T(2) * nParams
	let bic = T(-2) * final.remlLogLik + nParams * T.log(T(N))

	return RandomInterceptResult(
		beta: beta,
		standardErrors: seResult,
		tStatistics: tStats,
		pValues: pvals,
		varianceRandom: sigmaU2,
		varianceResidual: sigmaE2,
		icc: iccVal,
		remlLogLikelihood: final.remlLogLik,
		aic: aic,
		bic: bic,
		randomEffects: blups,
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

private struct GLSResult<T: Real & Sendable> {
	let beta: [T]
	let remlLogLik: T
}

/// OLS estimate: beta = (X'X)^{-1} X'y
private func olsEstimate<T: Real & Sendable>(
	xData: [[T]], y: [T], N: Int, p: Int
) throws -> [T] where T: BinaryFloatingPoint {
	// X'X
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

/// GLS estimate of beta and REML log-likelihood.
///
/// Uses the closed-form V_i^{-1} for compound symmetry:
/// V_i^{-1} = (1/sigmaE2) * [I - (sigmaU2 / (sigmaE2 + ni*sigmaU2)) * J]
private func glsEstimate<T: Real & Sendable>(
	xData: [[T]], y: [T], N: Int, p: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	sigmaU2: T, sigmaE2: T
) throws -> GLSResult<T> where T: BinaryFloatingPoint {

	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)
	var xtVinvY = Array(repeating: T.zero, count: p)
	var logDetV = T.zero

	let invE2 = T(1) / sigmaE2

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		let ai = sigmaE2 + nig * sigmaU2
		let wi = sigmaU2 / ai

		// log|V_i| = (ni - 1)*log(sigmaE2) + log(ai)
		logDetV += (nig - T(1)) * T.log(sigmaE2) + T.log(ai)

		// V_i^{-1} * x_row = (1/sigmaE2) * (x_row - wi * sum_j x_j)
		// First compute sum of x vectors in this group
		var xSum = Array(repeating: T.zero, count: p)
		var ySum = T.zero
		for idx in indices {
			for j in 0..<p { xSum[j] += xData[idx][j] }
			ySum += y[idx]
		}

		for idx in indices {
			// V_i^{-1} * x_row
			var vinvX = Array(repeating: T.zero, count: p)
			for j in 0..<p {
				vinvX[j] = invE2 * (xData[idx][j] - wi * xSum[j])
			}
			// V_i^{-1} * y_row
			let vinvY = invE2 * (y[idx] - wi * ySum)

			for j in 0..<p {
				xtVinvY[j] += xData[idx][j] * vinvY
				for k in 0..<p {
					xtVinvX[j][k] += xData[idx][j] * vinvX[k]
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
		let nig = T(indices.count)
		let ai = sigmaE2 + nig * sigmaU2
		let wi = sigmaU2 / ai

		var sumResid = T.zero
		var ssResid = T.zero
		for idx in indices {
			var fitted = T.zero
			for j in 0..<p { fitted += xData[idx][j] * beta[j] }
			let r = y[idx] - fitted
			ssResid += r * r
			sumResid += r
		}
		quadForm += invE2 * (ssResid - wi * sumResid * sumResid)
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

	return GLSResult(beta: beta, remlLogLik: logLik)
}

private struct FisherUpdate<T: Real & Sendable> {
	let deltaSigmaE2: T
	let deltaSigmaU2: T
}

/// Fisher scoring update for (sigma_e², sigma_u²).
private func fisherScoringUpdate<T: Real & Sendable>(
	resid: [T], m: Int, ni: [Int], groupIdx: [[Int]],
	sigmaU2: T, sigmaE2: T, N: Int
) -> FisherUpdate<T> where T: BinaryFloatingPoint {

	// Score vector and Fisher information for (sigma_e², sigma_u²)
	var scoreE = T.zero
	var scoreU = T.zero
	var I11 = T.zero  // d²l / d(sigmaE2)²
	var I12 = T.zero  // d²l / d(sigmaE2)d(sigmaU2)
	var I22 = T.zero  // d²l / d(sigmaU2)²

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		let ai = sigmaE2 + nig * sigmaU2
		let ai2 = ai * ai

		// Within-group SS
		let groupMean = indices.reduce(T.zero) { $0 + resid[$1] } / nig
		var ssWithin = T.zero
		for idx in indices {
			let diff = resid[idx] - groupMean
			ssWithin += diff * diff
		}
		let sumResid = indices.reduce(T.zero) { $0 + resid[$1] }

		// Score for sigma_e²:
		// S_e = -1/2 * [(ni-1)/sigmaE2 + 1/ai - ssWithin/sigmaE2² - sumResid²/ai²]
		let termA: T = (nig - T(1)) / sigmaE2
		let termB: T = T(1) / ai
		let sigmaE2sq: T = sigmaE2 * sigmaE2
		let termC: T = ssWithin / sigmaE2sq
		let termD: T = sumResid * sumResid / ai2
		let scoreEBody: T = termA + termB - termC - termD
		scoreE += T(-1) / T(2) * scoreEBody

		// Score for sigma_u²:
		// S_u = -1/2 * [ni/ai - ni² * rbar² / ai²]
		// where rbar = sumResid / ni
		let rbar: T = sumResid / nig
		let scoreUterm1: T = nig / ai
		let scoreUterm2: T = nig * nig * rbar * rbar / ai2
		scoreU += T(-1) / T(2) * (scoreUterm1 - scoreUterm2)

		// Fisher information entries
		let i11TermA: T = (nig - T(1)) / sigmaE2sq
		let i11TermB: T = T(1) / ai2
		I11 += T(1) / T(2) * (i11TermA + i11TermB)
		I22 += T(1) / T(2) * (nig * nig / ai2)
		I12 += T(1) / T(2) * (nig / ai2)
	}

	// Solve 2x2 system: [I11 I12; I12 I22] * [dE; dU] = [S_e; S_u]
	let det = I11 * I22 - I12 * I12
	guard absVal(det) > T.ulpOfOne else {
		return FisherUpdate(deltaSigmaE2: T.zero, deltaSigmaU2: T.zero)
	}

	let deltaE = (I22 * scoreE - I12 * scoreU) / det
	let deltaU = (I11 * scoreU - I12 * scoreE) / det

	return FisherUpdate(deltaSigmaE2: deltaE, deltaSigmaU2: deltaU)
}

/// Standard errors of fixed effects: sqrt(diag((X'V^{-1}X)^{-1}))
private func fixedEffectsSE<T: Real & Sendable>(
	xData: [[T]], N: Int, p: Int, m: Int,
	ni: [Int], groupIdx: [[Int]],
	sigmaU2: T, sigmaE2: T
) throws -> [T] where T: BinaryFloatingPoint {

	let invE2 = T(1) / sigmaE2
	var xtVinvX = Array(repeating: Array(repeating: T.zero, count: p), count: p)

	for g in 0..<m {
		let indices = groupIdx[g]
		let nig = T(indices.count)
		let ai = sigmaE2 + nig * sigmaU2
		let wi = sigmaU2 / ai

		var xSum = Array(repeating: T.zero, count: p)
		for idx in indices {
			for j in 0..<p { xSum[j] += xData[idx][j] }
		}

		for idx in indices {
			var vinvX = Array(repeating: T.zero, count: p)
			for j in 0..<p {
				vinvX[j] = invE2 * (xData[idx][j] - wi * xSum[j])
			}
			for j in 0..<p {
				for k in 0..<p {
					xtVinvX[j][k] += xData[idx][j] * vinvX[k]
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
