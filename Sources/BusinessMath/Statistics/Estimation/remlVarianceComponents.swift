import Foundation
import Numerics

/// Result of restricted maximum likelihood (REML) variance component estimation.
///
/// Contains the estimated between-group and within-group variance components,
/// the GLS fixed intercept, convergence diagnostics, and the restricted
/// log-likelihood at convergence.
///
/// ## Model
///
/// The one-way random-effects model is:
///
/// y_ij = mu + u_i + e_ij
///
/// where u_i ~ N(0, sigma_u^2) and e_ij ~ N(0, sigma_e^2).
///
/// ## Example
///
/// ```swift
/// let groups: [[Double]] = [
///     [10.0, 11.0, 10.5],
///     [20.0, 21.0, 20.5],
///     [15.0, 16.0, 15.5]
/// ]
/// let result = try remlVarianceComponents(groups)
/// print(result.varianceBetween)  // sigma_u^2
/// print(result.varianceWithin)   // sigma_e^2
/// ```
public struct REMLResult<T: Real & Sendable>: Sendable, Equatable {
	/// Between-group variance component (sigma_u^2).
	public let varianceBetween: T

	/// Within-group variance component (sigma_e^2).
	public let varianceWithin: T

	/// Total variance (between + within).
	public let varianceTotal: T

	/// GLS estimate of the fixed intercept (mu).
	public let fixedIntercept: T

	/// Number of iterations performed.
	public let iterations: Int

	/// Whether the algorithm converged within the iteration limit.
	public let converged: Bool

	/// Restricted log-likelihood at convergence.
	public let restrictedLogLikelihood: T
}

/// Estimates variance components using restricted maximum likelihood (REML).
///
/// Fits a one-way random-effects model y_ij = mu + u_i + e_ij using
/// iterative GLS (IGLS), which is equivalent to REML for normal data.
/// The within-group variance (sigma_e^2) is estimated exactly as
/// SS_within / (N - n), and sigma_u^2 is refined iteratively via GLS.
///
/// - Parameters:
///   - groups: Array of groups, where each group is an array of observations.
///     Requires at least 2 groups and total observations exceeding the number
///     of groups (for within-group degrees of freedom).
///   - maxIterations: Maximum number of iterations (default 100).
///   - tolerance: Convergence tolerance on relative parameter change (default 1e-8).
/// - Returns: A ``REMLResult`` containing estimated variance components,
///   fixed intercept, and convergence diagnostics.
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)``
///   if fewer than 2 groups or insufficient within-group degrees of freedom.
public func remlVarianceComponents<T: Real>(
	_ groups: [[T]],
	maxIterations: Int = 100,
	tolerance: T = T(1) / T(100_000_000)
) throws -> REMLResult<T> {

	// --- Validation ---
	guard groups.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: groups.count,
			context: "REML variance components requires at least 2 groups")
	}

	for (i, group) in groups.enumerated() {
		guard !group.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1, actual: 0,
				context: "Group \(i) is empty")
		}
	}

	let n = groups.count
	let groupSizes = groups.map { $0.count }
	let totalN = groupSizes.reduce(0, +)

	guard totalN > n else {
		throw BusinessMathError.insufficientData(
			required: n + 1, actual: totalN,
			context: "REML requires total observations > number of groups for within-group df")
	}

	// --- Precompute group statistics ---
	let groupMeans: [T] = groups.map { group in
		group.reduce(T.zero, +) / T(group.count)
	}

	// Within-group sum of squares per group: S_i = sum_j (y_ij - y_bar_i)^2
	let withinSS: [T] = groups.enumerated().map { (i, group) in
		group.reduce(T.zero) { acc, val in
			let diff = val - groupMeans[i]
			return acc + diff * diff
		}
	}

	let mi: [T] = groupSizes.map { T($0) }
	let eps = T.ulpOfOne

	// --- REML estimate of sigma_e^2 ---
	// For the one-way random effects model, the REML estimate of sigma_e^2
	// is exactly the pooled within-group variance (MS_within).
	// This is exact and requires no iteration.
	let pooledWithinSS = withinSS.reduce(T.zero, +)
	let sigmaE2 = T.maximum(pooledWithinSS / T(totalN - n), eps)

	// --- Initialise sigma_u^2 from method of moments ---
	let grandMean = groups.flatMap { $0 }.reduce(T.zero, +) / T(totalN)

	var ssBetween = T.zero
	for i in 0..<n {
		let diff = groupMeans[i] - grandMean
		ssBetween += mi[i] * diff * diff
	}
	let msBetween = ssBetween / T(n - 1)

	// Harmonic mean of group sizes
	let sumInverses = mi.reduce(T.zero) { $0 + T(1) / $1 }
	let nHarmonic = T(n) / sumInverses

	var sigmaU2: T
	if msBetween > sigmaE2, nHarmonic > T.zero {
		sigmaU2 = (msBetween - sigmaE2) / nHarmonic
	} else {
		sigmaU2 = T.zero
	}

	// --- Iterative GLS for sigma_u^2 ---
	// With sigma_e^2 fixed, iterate:
	// 1. Compute weights a_i = sigma_e^2 + m_i * sigma_u^2
	// 2. GLS estimate of mu: mu_hat = sum(m_i * y_bar_i / a_i) / sum(m_i / a_i)
	// 3. Weighted residual SS: Q = sum(m_i * r_i^2 / a_i) where r_i = y_bar_i - mu_hat
	// 4. REML update: sigma_u^2 = max(0, [Q - (n-1)] / P) where
	//    P = sum(m_i/a_i) - sum(m_i^2/a_i^2) / sum(m_i/a_i)
	//
	// This follows from setting the score equation for sigma_u^2 to zero.
	var converged = false
	var iteration = 0

	for iter in 0..<maxIterations {
		iteration = iter + 1

		let prevU2 = sigmaU2

		// a_i = sigma_e^2 + m_i * sigma_u^2
		let ai: [T] = mi.map { sigmaE2 + $0 * sigmaU2 }

		// GLS estimate of mu
		var sumMiOverA = T.zero
		var sumMiYbarOverA = T.zero
		for i in 0..<n {
			sumMiOverA += mi[i] / ai[i]
			sumMiYbarOverA += mi[i] * groupMeans[i] / ai[i]
		}

		guard sumMiOverA > T.zero else {
			break
		}
		let muHat = sumMiYbarOverA / sumMiOverA

		// Weighted residual quadratic form
		var qForm = T.zero
		for i in 0..<n {
			let ri = groupMeans[i] - muHat
			qForm += mi[i] * ri * ri / ai[i]
		}

		// Trace-like quantity for the REML update
		var sumMi2OverA2 = T.zero
		for i in 0..<n {
			sumMi2OverA2 += mi[i] * mi[i] / (ai[i] * ai[i])
		}

		let pDenom = sumMiOverA - sumMi2OverA2 / sumMiOverA

		guard pDenom > T.zero else {
			break
		}

		// REML update: new sigma_u^2 from score equation
		let newSigmaU2 = T.maximum(T.zero, sigmaU2 + (qForm - T(n - 1)) / pDenom)

		sigmaU2 = newSigmaU2

		// Check convergence
		let absDU2 = (sigmaU2 > prevU2) ? (sigmaU2 - prevU2) : (prevU2 - sigmaU2)
		let denom = T.maximum(T.maximum(sigmaU2, prevU2), T(1))
		let paramChange = absDU2 / denom

		if paramChange < tolerance {
			converged = true
			break
		}
	}

	// --- Final GLS mu ---
	let piVal = T.pi
	let finalAi: [T] = mi.map { sigmaE2 + $0 * sigmaU2 }
	var finalSumMiYbarOverA = T.zero
	var finalSumMiOverA = T.zero
	for i in 0..<n {
		finalSumMiYbarOverA += mi[i] * groupMeans[i] / finalAi[i]
		finalSumMiOverA += mi[i] / finalAi[i]
	}
	let finalMu: T
	if finalSumMiOverA > T.zero {
		finalMu = finalSumMiYbarOverA / finalSumMiOverA
	} else {
		finalMu = grandMean
	}

	let finalLogLik = computeREML(
		sigmaE2: sigmaE2, sigmaU2: sigmaU2, mi: mi, withinSS: withinSS,
		groupMeans: groupMeans, n: n, totalN: totalN, piVal: piVal
	)

	return REMLResult(
		varianceBetween: sigmaU2,
		varianceWithin: sigmaE2,
		varianceTotal: sigmaU2 + sigmaE2,
		fixedIntercept: finalMu,
		iterations: iteration,
		converged: converged,
		restrictedLogLikelihood: finalLogLik
	)
}

// MARK: - Restricted log-likelihood

/// Computes the restricted log-likelihood for a one-way random-effects model.
///
/// l_R = -(1/2) * [sum_i (m_i-1)*log(sigma_e^2) + sum_i log(a_i)
///        + log(sum_i m_i/a_i) + sum_i S_i/sigma_e^2
///        + sum_i m_i*r_i^2/a_i + (N-1)*log(2*pi)]
///
/// - Parameters:
///   - sigmaE2: Within-group variance (sigma_e^2).
///   - sigmaU2: Between-group variance (sigma_u^2).
///   - mi: Array of group sizes as Real values.
///   - withinSS: Within-group sum of squares per group.
///   - groupMeans: Mean of each group.
///   - n: Number of groups.
///   - totalN: Total number of observations.
///   - piVal: The value of pi.
/// - Returns: Restricted log-likelihood value.
private func computeREML<T: Real>(
	sigmaE2: T,
	sigmaU2: T,
	mi: [T],
	withinSS: [T],
	groupMeans: [T],
	n: Int,
	totalN: Int,
	piVal: T
) -> T {
	let two = T(2)
	let half = T(1) / two

	let ai: [T] = mi.map { sigmaE2 + $0 * sigmaU2 }

	// GLS estimate of mu
	var sumMiDbarOverA = T.zero
	var sumMiOverA = T.zero
	for i in 0..<n {
		sumMiDbarOverA += mi[i] * groupMeans[i] / ai[i]
		sumMiOverA += mi[i] / ai[i]
	}

	guard sumMiOverA > T.zero else {
		return -T.greatestFiniteMagnitude
	}
	let muHat = sumMiDbarOverA / sumMiOverA

	var logLik = T.zero
	let logSigmaE2 = T.log(sigmaE2)

	for i in 0..<n {
		let miVal = mi[i]
		logLik -= half * (miVal - T(1)) * logSigmaE2
		logLik -= half * T.log(ai[i])
		let ri = groupMeans[i] - muHat
		logLik -= half * withinSS[i] / sigmaE2
		logLik -= half * miVal * ri * ri / ai[i]
	}

	logLik -= half * T.log(sumMiOverA)
	logLik -= half * T(totalN - 1) * T.log(two * piVal)

	return logLik
}
