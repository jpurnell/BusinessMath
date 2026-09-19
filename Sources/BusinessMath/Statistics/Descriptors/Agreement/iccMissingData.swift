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
public struct ICCMissingDataResult<T: Real & Sendable>: Sendable, Equatable {
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
	/// Working log-likelihood at the final parameter estimates, under an independence
	/// approximation.
	///
	/// **Not the mixed model's log-likelihood.** It is computed as though every observed cell
	/// were an independent draw from `N(mu, sigma_s^2 + sigma_r^2 + sigma_e^2)` — the total
	/// variance is right, but the correlation that subjects and raters induce between cells,
	/// which is the entire model, is absent.
	///
	/// It serves as the EM's convergence criterion, where it works because it moves with the
	/// parameters, and it is reported here for diagnostics. Do not use it for a likelihood-ratio
	/// test or to compare models: the true marginal likelihood needs the `n·k × n·k` covariance
	/// `sigma_s^2 Z_s Z_s' + sigma_r^2 Z_r Z_r' + sigma_e^2 I` and its determinant, which the
	/// crossed design with missing cells has no closed form for.
	public let logLikelihood: T
	/// Number of subjects with at least one observed rating.
	public let subjects: Int
	/// Number of raters with at least one observed rating.
	public let raters: Int
	/// Total number of observed (non-nil) cells.
	public let observedCells: Int
}

/// The E-step: conditional means of the subject and rater effects, given the current parameters.
///
/// Crossed random effects are not conditionally independent of one another — `E[s_i]` depends on
/// the rater effects of the raters who scored subject `i`, and `E[r_j]` on the subject effects of
/// the subjects rater `j` scored. With missing cells there is no closed form for both at once, so
/// they are solved by **Iterative Conditional Expectations**: hold the raters fixed and update
/// the subjects, hold the subjects fixed and update the raters, and repeat.
///
/// Each update is the standard shrinkage estimator. For subject `i` with `n_i` observations,
///
/// ```
/// E[s_i] = (s² / (s² + e²/n_i)) · (x̄_i − mu − r̄_i)
/// ```
///
/// where the shrinkage factor pulls a subject with few ratings toward zero — which is the whole
/// reason a mixed model is used on incomplete data rather than a per-subject mean.
///
/// Ten sweeps, fixed. The alternation converges geometrically and the outer EM re-enters here
/// every iteration, so the inner loop does not need to be run to convergence itself.
///
/// - Parameters:
///   - ratings: The rating matrix, `nil` where absent.
///   - activeSubjects: Row indices with at least one observation.
///   - activeRaters: Column indices with at least one observation.
///   - subjectCounts: Observations per row.
///   - raterCounts: Observations per column.
///   - rows: Total row count, which sizes the returned arrays.
///   - columns: Total column count, likewise.
///   - mu: The current grand mean.
///   - sigmaS2: The current between-subjects variance.
///   - sigmaR2: The current between-raters variance.
///   - sigmaE2: The current residual variance.
/// - Returns: `E[s_i]` per row and `E[r_j]` per column, zero at inactive indices.
internal func conditionalEffects<T: Real>(
	ratings: [[T?]],
	activeSubjects: [Int],
	activeRaters: [Int],
	subjectCounts: [Int],
	raterCounts: [Int],
	rows: Int,
	columns: Int,
	mu: T,
	sigmaS2: T,
	sigmaR2: T,
	sigmaE2: T
) -> (subjects: [T], raters: [T]) {
	var eS = [T](repeating: T.zero, count: rows)
	var eR = [T](repeating: T.zero, count: columns)

	let iceSweeps = 10
	for _ in 0..<iceSweeps {
		for i in activeSubjects {
			guard subjectCounts[i] > 0 else { continue }
			let ni = T(subjectCounts[i])
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

		for j in activeRaters {
			guard raterCounts[j] > 0 else { continue }
			let kj = T(raterCounts[j])
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

	return (eS, eR)
}

/// The coefficient implied by a set of variance components, for each model and agreement type.
///
/// Separated out because it is the part that is *arithmetic on three numbers* — it can be
/// checked against a published table without running an EM, and a caller can apply it to
/// components obtained any other way.
///
/// | Model | Agreement | Formula |
/// |---|---|---|
/// | ICC(1,1) | either | `(s² − r²/k) / ((s² − r²/k) + r² + e²)` |
/// | ICC(2,1) | absolute | `s² / (s² + r² + e²)` |
/// | ICC(2,1) | consistency | `s² / (s² + e²)` |
/// | ICC(3,1) | either | `s² / (s² + e²)` |
///
/// ## The one-way row is not the two-way row
///
/// It used to be — `.oneWayRandom` carried the `.twoWayRandom, .absolute` line character for
/// character, so both models returned the same number. A one-way design has no separable rater
/// effect: rater variation is part of the noise a subject is measured against, so it comes out
/// of the *subject* term as well as sitting in the denominator. Writing the one-way
/// decomposition in two-way components,
///
/// ```
/// MSW = MSE + r²                       (within-subject MS, raters pooled into noise)
/// s²(one-way) = (MSR − MSW)/k = s² − r²/k
/// ```
///
/// On the ANOVA components of Shrout & Fleiss (1979) Table 1 that gives 0.16574 — their
/// published .17 — where the shared formula gave 0.28976, their ICC(2,1), overstating agreement
/// by three quarters.
///
/// The one-way subject term goes negative when raters vary more than subjects. That is the model
/// reporting no subject signal, and like every ANOVA variance estimate it is read as zero.
///
/// - Parameters:
///   - model: Which ICC model is being asked for.
///   - agreement: Absolute or consistency. Ignored for the one-way and mixed models, which have
///     one formula each.
///   - sigmaS2: The between-subjects variance component.
///   - sigmaR2: The between-raters variance component.
///   - sigmaE2: The residual variance component.
///   - raters: The number of raters with observed data, as a scalar.
/// - Returns: The coefficient, or zero where the components leave no variance to divide by.
internal func iccFromVarianceComponents<T: Real>(
	model: ICCModel,
	agreement: ICCAgreement,
	sigmaS2: T,
	sigmaR2: T,
	sigmaE2: T,
	raters: T
) -> T {
	switch (model, agreement) {
	case (.oneWayRandom, _):
		let raterShare: T = raters > T.zero ? sigmaR2 / raters : T.zero
		let oneWaySubjects: T = T.maximum(T.zero, sigmaS2 - raterShare)
		let denominator: T = oneWaySubjects + sigmaR2 + sigmaE2
		return denominator > T.zero ? oneWaySubjects / denominator : T.zero

	case (.twoWayRandom, .absolute):
		let denominator: T = sigmaS2 + sigmaR2 + sigmaE2
		return denominator > T.zero ? sigmaS2 / denominator : T.zero

	case (.twoWayRandom, .consistency), (.twoWayMixed, _):
		// The mixed model treats raters as fixed, so rater spread is never in the denominator;
		// two-way random with consistency asks the same question of random raters.
		let denominator: T = sigmaS2 + sigmaE2
		return denominator > T.zero ? sigmaS2 / denominator : T.zero
	}
}

/// Which cells of a rating matrix are present, and which subjects and raters are usable.
///
/// Separated from the estimator because it is the part that *refuses* — every way this function
/// can decline a matrix is here, in one place, rather than interleaved with the arithmetic that
/// assumes it succeeded.
///
/// A subject or rater with no observations at all is excluded rather than rejected: it
/// contributes nothing to any variance component, and dropping it is what lets a matrix with an
/// entirely absent column still be estimated from the rest.
///
/// - Parameter ratings: The subjects-by-raters matrix, `nil` where a rating is absent.
/// - Returns: The presence mask, per-subject and per-rater observation counts, the indices that
///   survive, and the total number of observed cells.
/// - Throws: `BusinessMathError.mismatchedDimensions` if rows differ in length, and
///   `BusinessMathError.insufficientData` when nothing is observed or fewer than two subjects or
///   raters have any data.
internal func ratingLayout<T>(
	of ratings: [[T?]]
) throws -> (
	observed: [[Bool]],
	subjectCounts: [Int],
	raterCounts: [Int],
	activeSubjects: [Int],
	activeRaters: [Int],
	totalObserved: Int
) {
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

	for i in 1..<nRows {
		guard ratings[i].count == kCols else {
			throw BusinessMathError.mismatchedDimensions(
				message: "All rows must have the same number of columns",
				expected: "\(kCols)", actual: "\(ratings[i].count)")
		}
	}

	var observed = [[Bool]](repeating: [Bool](repeating: false, count: kCols), count: nRows)
	var subjectCounts = [Int](repeating: 0, count: nRows)
	var raterCounts = [Int](repeating: 0, count: kCols)
	var totalObserved = 0

	for i in 0..<nRows {
		for j in 0..<kCols where ratings[i][j] != nil {
			observed[i][j] = true
			subjectCounts[i] += 1
			raterCounts[j] += 1
			totalObserved += 1
		}
	}

	guard totalObserved > 0 else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "ICC requires at least some observed data")
	}

	let activeSubjects = (0..<nRows).filter { subjectCounts[$0] > 0 }
	let activeRaters = (0..<kCols).filter { raterCounts[$0] > 0 }

	guard activeSubjects.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: activeSubjects.count,
			context: "ICC requires at least 2 subjects with observed data")
	}
	guard activeRaters.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: activeRaters.count,
			context: "ICC requires at least 2 raters with observed data")
	}

	return (observed, subjectCounts, raterCounts, activeSubjects, activeRaters, totalObserved)
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
/// | ICC(1,1) | either | (sigma_s^2 - sigma_r^2/k) / ((sigma_s^2 - sigma_r^2/k) + sigma_r^2 + sigma_e^2) |
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
///   - maxIterations: Maximum number of EM iterations (default 5000).
///
///     Measured on the Shrout & Fleiss (1979) matrix, six subjects by four raters: with one
///     cell removed the EM needs up to **668** iterations to settle, and with two removed up
///     to **1263**. The old default of 200 therefore expired on **18 of the 24** single-cell
///     deletions, returning `converged: false` alongside an estimate that was in fact very
///     nearly right — a result a caller who does not check the flag cannot distinguish from a
///     converged one.
///
///     This is EM being EM rather than anything wrong with the criterion. Convergence on the
///     variance components instead of on the likelihood was tried and is *slower* — 904 and
///     1597 on the same two cases — so the budget is the thing to raise.
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
	maxIterations: Int = 5_000,
	tolerance: T = T(1) / T(100_000_000)
) throws -> ICCMissingDataResult<T> {

	let layout = try ratingLayout(of: ratings)
	let nRows = ratings.count
	let kCols = ratings.first?.count ?? 0
	let observed = layout.observed
	let nObs = layout.subjectCounts
	let kObs = layout.raterCounts
	let totalObs = layout.totalObserved
	let activeSubjects = layout.activeSubjects
	let activeRaters = layout.activeRaters
	let n = activeSubjects.count
	let k = activeRaters.count
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

		let expectations = conditionalEffects(
			ratings: ratings,
			activeSubjects: activeSubjects,
			activeRaters: activeRaters,
			subjectCounts: nObs,
			raterCounts: kObs,
			rows: nRows,
			columns: kCols,
			mu: mu,
			sigmaS2: sigmaS2,
			sigmaR2: sigmaR2,
			sigmaE2: sigmaE2
		)
		let eS = expectations.subjects
		let eR = expectations.raters

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

	let iccValue = iccFromVarianceComponents(
		model: model,
		agreement: agreement,
		sigmaS2: finalSigmaS2,
		sigmaR2: finalSigmaR2,
		sigmaE2: finalSigmaE2,
		raters: kT
	)

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
	let halfN = nT / T(2)
	let term1 = -halfN * T.log(twoPi)
	let term2 = -halfN * T.log(totalVar)
	let term3 = -(T(1) / T(2)) * sumSquared / totalVar
	let logLikelihood = term1 + term2 + term3

	return logLikelihood
}
