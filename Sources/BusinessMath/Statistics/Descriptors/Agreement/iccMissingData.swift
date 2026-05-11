import Foundation
import Numerics

/// Result of an ICC computation using the EM algorithm for missing data.
///
/// Contains the ICC estimate along with the decomposed variance components,
/// convergence diagnostics, and descriptive metadata. Unlike ``ICCResult``,
/// this type reports variance components directly because the EM algorithm
/// estimates them as part of the mixed-effects model.
///
/// The model assumes:
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// ```
/// where `s_i` ~ N(0, sigma_s^2), `r_j` ~ N(0, sigma_r^2),
/// and `e_ij` ~ N(0, sigma_e^2).
public struct ICCMissingDataResult<T: Real>: Sendable, Equatable {
	/// The intraclass correlation coefficient estimate.
	public let icc: T
	/// Estimated between-subjects variance component (sigma_s^2).
	public let varianceSubjects: T
	/// Estimated between-raters variance component (sigma_r^2).
	public let varianceRaters: T
	/// Estimated residual error variance component (sigma_e^2).
	public let varianceError: T
	/// Estimated grand mean (mu).
	public let grandMean: T
	/// Number of EM iterations performed.
	public let iterations: Int
	/// Whether the EM algorithm converged within the iteration limit.
	public let converged: Bool
	/// Log-likelihood at the final parameter estimates.
	public let logLikelihood: T
	/// Number of subjects with at least one observed rating.
	public let subjects: Int
	/// Number of raters with at least one observed rating.
	public let raters: Int
	/// Total number of observed (non-nil) cells.
	public let observedCells: Int
}

/// Computes the intraclass correlation coefficient for data with missing values.
///
/// Uses an Expectation-Maximization (EM) algorithm with Iterative Conditional
/// Expectations (ICE) to estimate variance components from an incomplete
/// subjects-by-raters rating matrix. Missing values are represented as `nil`.
///
/// The underlying model is a two-way random/mixed effects model:
/// ```
/// x_ij = mu + s_i + r_j + e_ij
/// ```
///
/// Subjects or raters with zero observations are automatically excluded
/// from estimation.
///
/// ## ICC Formulas from Variance Components
///
/// | Model | Agreement | Formula |
/// |---|---|---|
/// | ICC(1,1) | absolute | sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2) |
/// | ICC(2,1) | absolute | sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2) |
/// | ICC(2,1) | consistency | sigma_s^2 / (sigma_s^2 + sigma_e^2) |
/// | ICC(3,1) | absolute | sigma_s^2 / (sigma_s^2 + sigma_e^2) |
/// | ICC(3,1) | consistency | sigma_s^2 / (sigma_s^2 + sigma_e^2) |
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the optional rating of
///     subject `i` by rater `j`. All rows must have the same length.
///     `nil` indicates a missing observation.
///   - model: The ICC model type (see ``ICCModel``).
///   - agreement: The agreement type (see ``ICCAgreement``).
///   - maxIterations: Maximum number of EM iterations (default 200).
///   - tolerance: Convergence threshold for relative log-likelihood
///     change (default 1e-8).
/// - Returns: An ``ICCMissingDataResult`` containing the ICC estimate,
///   variance components, convergence diagnostics, and metadata.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects
///   or raters have observed data, or if no observations exist.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
public func icc<T: Real>(
	_ ratings: [[T?]],
	model: ICCModel,
	agreement: ICCAgreement,
	maxIterations: Int = 200,
	tolerance: T = T(1) / T(100_000_000)
) throws -> ICCMissingDataResult<T> {

	// --- Validate dimensions ---

	let nRows = ratings.count
	guard nRows >= 1 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "ICC requires at least 2 subjects (rows)")
	}

	let kCols = ratings[0].count
	guard kCols >= 1 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: 0,
			context: "ICC requires at least 2 raters (columns)")
	}

	// Validate balanced design (all rows same length)
	for i in 1..<nRows {
		guard ratings[i].count == kCols else {
			throw BusinessMathError.mismatchedDimensions(
				message: "All rows must have the same number of columns",
				expected: "\(kCols)", actual: "\(ratings[i].count)")
		}
	}

	// --- Build observation mask and count observations ---

	// observed[i][j] == true if ratings[i][j] is non-nil
	var observed = [[Bool]](repeating: [Bool](repeating: false, count: kCols), count: nRows)
	// n_i = number of observed ratings for subject i
	var nObs = [Int](repeating: 0, count: nRows)
	// k_j = number of observed ratings for rater j
	var kObs = [Int](repeating: 0, count: kCols)
	var totalObs = 0

	for i in 0..<nRows {
		for j in 0..<kCols {
			if ratings[i][j] != nil {
				observed[i][j] = true
				nObs[i] += 1
				kObs[j] += 1
				totalObs += 1
			}
		}
	}

	guard totalObs > 0 else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "ICC requires at least some observed data")
	}

	// Identify subjects and raters with at least one observation
	let activeSubjects = (0..<nRows).filter { nObs[$0] > 0 }
	let activeRaters = (0..<kCols).filter { kObs[$0] > 0 }

	let n = activeSubjects.count
	let k = activeRaters.count

	guard n >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: n,
			context: "ICC requires at least 2 subjects with observed data")
	}

	guard k >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: k,
			context: "ICC requires at least 2 raters with observed data")
	}

	let nT = T(n)
	let kT = T(k)
	let totalObsT = T(totalObs)

	// --- Initialization ---

	// Grand mean of observed values
	var grandSum = T.zero
	for i in activeSubjects {
		for j in activeRaters {
			if let val = ratings[i][j] {
				grandSum += val
			}
		}
	}
	var mu = grandSum / totalObsT

	// Row means (subject means of observed values)
	var rowMeans = [T](repeating: T.zero, count: nRows)
	for i in activeSubjects {
		var rowSum = T.zero
		for j in activeRaters {
			if let val = ratings[i][j] {
				rowSum += val
			}
		}
		guard nObs[i] > 0 else { continue }
		rowMeans[i] = rowSum / T(nObs[i])
	}

	// Column means (rater means of observed values)
	var colMeans = [T](repeating: T.zero, count: kCols)
	for j in activeRaters {
		var colSum = T.zero
		for i in activeSubjects {
			if let val = ratings[i][j] {
				colSum += val
			}
		}
		guard kObs[j] > 0 else { continue }
		colMeans[j] = colSum / T(kObs[j])
	}

	// Initial variance of row means → sigma_s^2
	var varRowMeans = T.zero
	for i in activeSubjects {
		let diff = rowMeans[i] - mu
		varRowMeans += diff * diff
	}
	varRowMeans = varRowMeans / nT

	// Initial variance of col means → sigma_r^2
	var varColMeans = T.zero
	for j in activeRaters {
		let diff = colMeans[j] - mu
		varColMeans += diff * diff
	}
	varColMeans = varColMeans / kT

	// Initial residual variance → sigma_e^2
	var residualSS = T.zero
	for i in activeSubjects {
		for j in activeRaters {
			if let val = ratings[i][j] {
				let resid = val - rowMeans[i] - colMeans[j] + mu
				residualSS += resid * resid
			}
		}
	}
	var sigmaE2 = residualSS / totalObsT
	var sigmaS2 = max(varRowMeans, T.ulpOfOne)
	var sigmaR2 = max(varColMeans, T.ulpOfOne)
	sigmaE2 = max(sigmaE2, T.ulpOfOne)

	// --- EM Iteration ---

	var prevLL = computeLogLikelihood(
		ratings: ratings,
		activeSubjects: activeSubjects,
		activeRaters: activeRaters,
		observed: observed,
		mu: mu,
		sigmaS2: sigmaS2,
		sigmaR2: sigmaR2,
		sigmaE2: sigmaE2
	)

	var converged = false
	var iteration = 0

	for iter in 0..<maxIterations {
		iteration = iter + 1

		// ---- E-step: Iterative Conditional Expectations (ICE) ----

		var eS = [T](repeating: T.zero, count: nRows)
		var eR = [T](repeating: T.zero, count: kCols)

		// ICE: alternate updating E[s_i] and E[r_j] for several sweeps
		let iceSweeps = 10
		for _ in 0..<iceSweeps {
			// Update E[s_i | x_obs, theta]
			for i in activeSubjects {
				guard nObs[i] > 0 else { continue }
				let ni = T(nObs[i])
				// x_bar_i. - mu - r_bar_i.
				// where x_bar_i. is mean of observed x_ij for subject i
				// r_bar_i. is mean of E[r_j] for raters observed on subject i
				var sumX = T.zero
				var sumR = T.zero
				for j in activeRaters {
					if let val = ratings[i][j] {
						sumX += val
						sumR += eR[j]
					}
				}
				let xBarI = sumX / ni
				let rBarI = sumR / ni
				let shrinkage = sigmaS2 / (sigmaS2 + sigmaE2 / ni)
				eS[i] = shrinkage * (xBarI - mu - rBarI)
			}

			// Update E[r_j | x_obs, theta]
			for j in activeRaters {
				guard kObs[j] > 0 else { continue }
				let kj = T(kObs[j])
				var sumX = T.zero
				var sumS = T.zero
				for i in activeSubjects {
					if let val = ratings[i][j] {
						sumX += val
						sumS += eS[i]
					}
				}
				let xBarJ = sumX / kj
				let sBarJ = sumS / kj
				let shrinkage = sigmaR2 / (sigmaR2 + sigmaE2 / kj)
				eR[j] = shrinkage * (xBarJ - mu - sBarJ)
			}
		}

		// Second moments: E[s_i^2] and E[r_j^2]
		var eS2 = [T](repeating: T.zero, count: nRows)
		var eR2 = [T](repeating: T.zero, count: kCols)
		var varS = [T](repeating: T.zero, count: nRows)
		var varR = [T](repeating: T.zero, count: kCols)

		for i in activeSubjects {
			guard nObs[i] > 0 else { continue }
			let ni = T(nObs[i])
			// Var[s_i] = 1 / (1/sigma_s^2 + n_i/sigma_e^2)
			let precision = T(1) / sigmaS2 + ni / sigmaE2
			varS[i] = T(1) / precision
			eS2[i] = eS[i] * eS[i] + varS[i]
		}

		for j in activeRaters {
			guard kObs[j] > 0 else { continue }
			let kj = T(kObs[j])
			// Var[r_j] = 1 / (1/sigma_r^2 + k_j/sigma_e^2)
			let precision = T(1) / sigmaR2 + kj / sigmaE2
			varR[j] = T(1) / precision
			eR2[j] = eR[j] * eR[j] + varR[j]
		}

		// ---- M-step ----

		// Update mu
		var muSum = T.zero
		for i in activeSubjects {
			for j in activeRaters {
				if let val = ratings[i][j] {
					muSum += val - eS[i] - eR[j]
				}
			}
		}
		mu = muSum / totalObsT

		// Update sigma_s^2
		var sumES2 = T.zero
		for i in activeSubjects {
			sumES2 += eS2[i]
		}
		sigmaS2 = max(sumES2 / nT, T.ulpOfOne)

		// Update sigma_r^2
		var sumER2 = T.zero
		for j in activeRaters {
			sumER2 += eR2[j]
		}
		sigmaR2 = max(sumER2 / kT, T.ulpOfOne)

		// Update sigma_e^2
		var sumResid = T.zero
		for i in activeSubjects {
			for j in activeRaters {
				if let val = ratings[i][j] {
					let resid = val - mu - eS[i] - eR[j]
					sumResid += resid * resid + varS[i] + varR[j]
				}
			}
		}
		sigmaE2 = max(sumResid / totalObsT, T.ulpOfOne)

		// ---- Check convergence ----

		let currentLL = computeLogLikelihood(
			ratings: ratings,
			activeSubjects: activeSubjects,
			activeRaters: activeRaters,
			observed: observed,
			mu: mu,
			sigmaS2: sigmaS2,
			sigmaR2: sigmaR2,
			sigmaE2: sigmaE2
		)

		let llChange: T
		if prevLL == T.zero {
			llChange = abs(currentLL)
		} else {
			llChange = abs((currentLL - prevLL) / prevLL)
		}

		prevLL = currentLL

		if llChange < tolerance {
			converged = true
			break
		}
	}

	// --- Compute ICC from variance components ---

	// Threshold for reporting zero
	let zeroThreshold = T.ulpOfOne * T(10)
	let finalSigmaS2 = sigmaS2 < zeroThreshold ? T.zero : sigmaS2
	let finalSigmaR2 = sigmaR2 < zeroThreshold ? T.zero : sigmaR2
	let finalSigmaE2 = sigmaE2 < zeroThreshold ? T.zero : sigmaE2

	let iccValue: T
	switch (model, agreement) {
	case (.oneWayRandom, _):
		// ICC(1,1) = sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)
		let denom = finalSigmaS2 + finalSigmaR2 + finalSigmaE2
		iccValue = denom > T.zero ? finalSigmaS2 / denom : T.zero
	case (.twoWayRandom, .absolute):
		// ICC(2,1) absolute = sigma_s^2 / (sigma_s^2 + sigma_r^2 + sigma_e^2)
		let denom = finalSigmaS2 + finalSigmaR2 + finalSigmaE2
		iccValue = denom > T.zero ? finalSigmaS2 / denom : T.zero
	case (.twoWayRandom, .consistency):
		// ICC(2,1) consistency = sigma_s^2 / (sigma_s^2 + sigma_e^2)
		let denom = finalSigmaS2 + finalSigmaE2
		iccValue = denom > T.zero ? finalSigmaS2 / denom : T.zero
	case (.twoWayMixed, .absolute):
		// ICC(3,1) absolute = sigma_s^2 / (sigma_s^2 + sigma_e^2)
		let denom = finalSigmaS2 + finalSigmaE2
		iccValue = denom > T.zero ? finalSigmaS2 / denom : T.zero
	case (.twoWayMixed, .consistency):
		// ICC(3,1) consistency = sigma_s^2 / (sigma_s^2 + sigma_e^2)
		let denom = finalSigmaS2 + finalSigmaE2
		iccValue = denom > T.zero ? finalSigmaS2 / denom : T.zero
	}

	return ICCMissingDataResult(
		icc: iccValue,
		varianceSubjects: finalSigmaS2,
		varianceRaters: finalSigmaR2,
		varianceError: finalSigmaE2,
		grandMean: mu,
		iterations: iteration,
		converged: converged,
		logLikelihood: prevLL,
		subjects: n,
		raters: k,
		observedCells: totalObs
	)
}

// MARK: - Log-Likelihood Helper

/// Computes the log-likelihood for the independence-approximation model.
///
/// Uses the marginal likelihood where each observed rating x_ij has
/// variance sigma_s^2 + sigma_r^2 + sigma_e^2 and mean mu:
///
/// LL = -(N/2)*log(2*pi) - (N/2)*log(totalVar) - (1/2)*sum((x_ij - mu)^2 / totalVar)
private func computeLogLikelihood<T: Real>(
	ratings: [[T?]],
	activeSubjects: [Int],
	activeRaters: [Int],
	observed: [[Bool]],
	mu: T,
	sigmaS2: T,
	sigmaR2: T,
	sigmaE2: T
) -> T {
	let totalVar = sigmaS2 + sigmaR2 + sigmaE2
	guard totalVar > T.zero else { return -T.greatestFiniteMagnitude }

	var nObs = 0
	var sumSquared = T.zero

	for i in activeSubjects {
		for j in activeRaters {
			if observed[i][j], let val = ratings[i][j] {
				let diff = val - mu
				sumSquared += diff * diff
				nObs += 1
			}
		}
	}

	guard nObs > 0 else { return -T.greatestFiniteMagnitude }

	let nT = T(nObs)
	let twoPi = T(2) * T.pi
	let logLikelihood = -(nT / T(2)) * T.log(twoPi)
		- (nT / T(2)) * T.log(totalVar)
		- (T(1) / T(2)) * sumSquared / totalVar

	return logLikelihood
}
