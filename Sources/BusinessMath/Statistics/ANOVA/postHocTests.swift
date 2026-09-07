import Foundation
import Numerics

// MARK: - Result Types

/// Result of a pairwise post-hoc comparison.
public struct PairwiseComparison<T: Real & Sendable>: Sendable, Equatable {
	/// Index of the first group.
	public let groupA: Int
	/// Index of the second group.
	public let groupB: Int
	/// Difference in group means (mean_A - mean_B).
	public let meanDifference: T
	/// The test statistic (t, F, or q depending on method).
	public let testStatistic: T
	/// The p-value for this comparison.
	public let pValue: T
	/// Whether the difference is significant at the given alpha level.
	public let isSignificant: Bool
}

/// Result of a post-hoc analysis.
public struct PostHocResult<T: Real & Sendable>: Sendable, Equatable {
	/// The method used.
	public let method: String
	/// All pairwise comparisons.
	public let comparisons: [PairwiseComparison<T>]
	/// Family-wise alpha level used.
	public let alpha: T
	/// MSE (mean squared error) from the ANOVA.
	public let mse: T
	/// Degrees of freedom for error.
	public let dfError: Int
}

// MARK: - Shared Validation

/// Validates inputs common to all post-hoc tests.
///
/// - Parameters:
///   - groups: The groups to compare.
///   - anova: The ANOVA result.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups.
private func validatePostHocInputs<T: Real>(
	_ groups: [[T]], anova: OneWayANOVAResult<T>
) throws {
	guard groups.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: groups.count,
			context: "Post-hoc tests require at least 2 groups")
	}

	for (i, group) in groups.enumerated() {
		guard !group.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1, actual: 0,
				context: "Group \(i) is empty")
		}
	}

	guard anova.dfWithin > 0 else {
		throw BusinessMathError.insufficientData(
			required: 1, actual: 0,
			context: "Error degrees of freedom must be positive")
	}
}

/// Computes group means for each group.
private func groupMeans<T: Real>(_ groups: [[T]]) -> [T] {
	groups.map { group in
		group.reduce(T.zero, +) / T(group.count)
	}
}

// MARK: - Bonferroni Post-Hoc Test

/// Bonferroni post-hoc test following one-way ANOVA.
///
/// Performs pairwise t-tests using pooled MSE from ANOVA, then applies
/// the Bonferroni correction (multiply p-values by number of comparisons).
/// Conservative but simple.
///
/// - Parameters:
///   - groups: The same groups passed to one-way ANOVA.
///   - anova: The result from ``oneWayANOVA(_:)``.
///   - alpha: Family-wise significance level (default 0.05).
/// - Returns: ``PostHocResult`` with all pairwise comparisons.
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)`` if fewer than 2 groups
///           or any group is empty.
public func bonferroniPostHoc<T: Real>(
	_ groups: [[T]], anova: OneWayANOVAResult<T>, alpha: T = T(5) / T(100)
) throws -> PostHocResult<T> {
	try validatePostHocInputs(groups, anova: anova)

	let k = groups.count
	let numComparisons = k * (k - 1) / 2
	let means = groupMeans(groups)
	let mse = anova.msWithin
	var comparisons: [PairwiseComparison<T>] = []

	for i in 0..<k {
		for j in (i + 1)..<k {
			let meanDiff = means[i] - means[j]
			let ni = T(groups[i].count)
			let nj = T(groups[j].count)

			let se = T.sqrt(mse * (T(1) / ni + T(1) / nj))
			guard se > T.zero else {
				// MSE is zero — all values identical within groups
				comparisons.append(PairwiseComparison(
					groupA: i, groupB: j,
					meanDifference: meanDiff,
					testStatistic: T.zero,
					pValue: T(1),
					isSignificant: false))
				continue
			}

			let tStat = meanDiff / se
			let absTStat = tStat < T.zero ? -tStat : tStat
			let rawP = T(2) * (T(1) - (try tCDF(t: absTStat, df: anova.dfWithin)))
			let adjustedP = min(rawP * T(numComparisons), T(1))

			comparisons.append(PairwiseComparison(
				groupA: i, groupB: j,
				meanDifference: meanDiff,
				testStatistic: tStat,
				pValue: adjustedP,
				isSignificant: adjustedP < alpha))
		}
	}

	return PostHocResult(
		method: "Bonferroni",
		comparisons: comparisons,
		alpha: alpha,
		mse: mse,
		dfError: anova.dfWithin)
}

// MARK: - Scheffé Post-Hoc Test

/// Scheffé post-hoc test following one-way ANOVA.
///
/// Uses the F-distribution for all pairwise comparisons. More conservative
/// than Bonferroni for pairwise tests but valid for any linear contrast.
/// The critical value is `(k-1) × F_crit(α, k-1, N-k)`.
///
/// - Parameters:
///   - groups: The same groups passed to one-way ANOVA.
///   - anova: The result from ``oneWayANOVA(_:)``.
///   - alpha: Family-wise significance level (default 0.05).
/// - Returns: ``PostHocResult`` with all pairwise comparisons.
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)`` if fewer than 2 groups
///           or any group is empty.
public func scheffePostHoc<T: Real>(
	_ groups: [[T]], anova: OneWayANOVAResult<T>, alpha: T = T(5) / T(100)
) throws -> PostHocResult<T> {
	try validatePostHocInputs(groups, anova: anova)

	let k = groups.count
	let kMinus1 = k - 1
	let means = groupMeans(groups)
	let mse = anova.msWithin
	var comparisons: [PairwiseComparison<T>] = []

	for i in 0..<k {
		for j in (i + 1)..<k {
			let meanDiff = means[i] - means[j]
			let ni = T(groups[i].count)
			let nj = T(groups[j].count)

			let seSquared = mse * (T(1) / ni + T(1) / nj)
			guard seSquared > T.zero else {
				comparisons.append(PairwiseComparison(
					groupA: i, groupB: j,
					meanDifference: meanDiff,
					testStatistic: T.zero,
					pValue: T(1),
					isSignificant: false))
				continue
			}

			let fStat = (meanDiff * meanDiff) / (seSquared * T(kMinus1))
			let p = T(1) - (try fCDF(f: fStat, df1: kMinus1, df2: anova.dfWithin))

			comparisons.append(PairwiseComparison(
				groupA: i, groupB: j,
				meanDifference: meanDiff,
				testStatistic: fStat,
				pValue: p,
				isSignificant: p < alpha))
		}
	}

	return PostHocResult(
		method: "Scheffé",
		comparisons: comparisons,
		alpha: alpha,
		mse: mse,
		dfError: anova.dfWithin)
}

// MARK: - Tukey HSD Post-Hoc Test

/// Approximate CDF of the studentized range distribution.
///
/// Uses composite Simpson's rule numerical integration of:
/// `P(Q ≤ q | k) ≈ k × ∫ φ(z) × [Φ(z + q) - Φ(z)]^{k-1} dz`
///
/// This is the large-sample (ν → ∞) approximation using the normal
/// distribution. Accurate for df ≥ 20 and provides a reasonable
/// approximation for smaller df.
///
/// - Parameters:
///   - q: The studentized range statistic (must be positive).
///   - k: Number of groups being compared.
///   - df: Error degrees of freedom from ANOVA.
/// - Returns: Probability P(Q ≤ q) in [0, 1].
/// P(W ≤ x) for the range of `k` independent standard normals.
///
/// This is the studentized range with **infinite** error degrees of freedom: the
/// spread of `k` draws measured against a standard deviation known exactly rather
/// than estimated. It is the inner half of ``studentizedRangeCDF(q:k:df:)``.
///
///     P(W ≤ x) = k ∫ φ(z) · [Φ(z + x) − Φ(z)]^(k−1) dz
///
/// - Parameters:
///   - x: The range, in standard deviations. Non-positive returns zero.
///   - k: The number of groups being compared, at least two.
/// - Returns: The probability, in `[0, 1]`.
private func normalRangeCDF<T: Real>(x: T, k: Int) -> T where T: BinaryFloatingPoint {
	guard x > T.zero else { return T.zero }
	guard k >= 2 else { return T(1) }

	// z ∈ [-8, 8] covers everything a standard normal contributes to six decimals.
	let lower: T = T(-8)
	let upper: T = T(8)
	let steps = 256
	let width: T = upper - lower
	let h: T = width / T(steps)
	let sqrtTwoPi: T = T.sqrt(T(2) * T.pi)
	let exponent: T = T(k - 1)

	func integrand(_ z: T) -> T {
		let upperTail: T = normalCDF(x: z + x, mean: T.zero, stdDev: T(1))
		let lowerTail: T = normalCDF(x: z, mean: T.zero, stdDev: T(1))
		let spread: T = upperTail - lowerTail
		guard spread > T.zero else { return T.zero }
		let density: T = T.exp(-z * z / T(2)) / sqrtTwoPi
		return density * T.pow(spread, exponent)
	}

	var sum: T = integrand(lower) + integrand(upper)
	for i in 1..<steps {
		let z: T = lower + T(i) * h
		let weight: T = (i % 2 == 0) ? T(2) : T(4)
		sum += weight * integrand(z)
	}
	let integral: T = sum * h / T(3)
	let result: T = T(k) * integral

	if result < T.zero { return T.zero }
	if result > T(1) { return T(1) }
	return result
}

/// P(Q ≤ q) for the studentized range with `k` groups and `df` error degrees of
/// freedom.
///
/// The studentized range is the spread of `k` normal means divided by an
/// *estimated* standard deviation, and that estimate is what the degrees of
/// freedom describe. Writing `S` for the estimate and `σ` for the truth,
/// `S/σ = √(χ²_ν/ν)`, so the distribution is the normal range rescaled by an
/// independent chi variable and its CDF carries an outer integral:
///
///     P(Q ≤ q) = ∫₀^∞ f_ν(s) · P(W ≤ q·s) ds
///
/// where `f_ν` is the density of `s = √(χ²_ν/ν)`.
///
/// **That outer integral was missing.** The implementation took `df` and never
/// referred to it, returning `P(W ≤ q)` — the ν = ∞ answer, in which the standard
/// deviation is known rather than estimated. A distribution with no estimation
/// error is too narrow, so its tails are too thin and every p-value came out too
/// small. Measured against SciPy on a three-group design with 24 error degrees of
/// freedom, a comparison at p = 0.0027 was reported as p = 0.0005, and on an
/// unbalanced design p = 0.0554 was reported as 0.0431 — across α, so a pair that
/// is not significant was called significant.
///
/// Anti-conservative is the one direction this must not fail in: Tukey exists to
/// hold the family-wise error rate at α, and the error grew with the number of
/// groups, which is exactly when the correction is most needed. With two groups
/// the studentized range *is* the t distribution, and the two disagreed by a
/// factor of 428.
///
/// - Parameters:
///   - q: The studentized range statistic. Non-positive returns zero.
///   - k: The number of groups, at least two.
///   - df: Error degrees of freedom. Non-positive is treated as ν = ∞.
/// - Returns: The probability, in `[0, 1]`.
private func studentizedRangeCDF<T: Real>(
	q: T, k: Int, df: Int
) -> T where T: BinaryFloatingPoint {
	guard q > T.zero else { return T.zero }
	guard k >= 2 else { return T(1) }
	// No degrees of freedom to speak of, or so many that the estimate is the
	// truth: the chi factor concentrates at one and the outer integral is a
	// formality costing accuracy rather than adding it.
	guard df >= 1, df < 25_000 else { return normalRangeCDF(x: q, k: k) }

	let nu: T = T(df)
	let halfNu: T = nu / T(2)

	// log f_ν(s) = (ν/2)·log ν − lgamma(ν/2) − (ν/2 − 1)·log 2 + (ν−1)·log s − ν·s²/2
	// Built in logs because ν^(ν/2) overflows well before ν reaches a size anyone
	// would call large.
	let logNuTerm: T = halfNu * T.log(nu)
	let logGammaTerm: T = T.logGamma(halfNu)
	let logTwoTerm: T = (halfNu - T(1)) * T.log(T(2))
	let logNormaliser: T = logNuTerm - logGammaTerm - logTwoTerm
	let exponent: T = nu - T(1)

	func chiDensity(_ s: T) -> T {
		guard s > T.zero else { return T.zero }
		let logPower: T = exponent * T.log(s)
		let quadratic: T = nu * s * s / T(2)
		let logDensity: T = logNormaliser + logPower - quadratic
		guard logDensity > T(-700) else { return T.zero }
		return T.exp(logDensity)
	}

	// s concentrates at 1 with standard deviation about 1/√(2ν). Twelve of those
	// either side reaches past any contribution that could show at six decimals,
	// and the lower end is clamped at zero because s cannot be negative.
	let spread: T = T(12) / T.sqrt(T(2) * nu)
	var sLower: T = T(1) - spread
	if sLower < T.zero { sLower = T.zero }
	let sUpper: T = T(1) + spread

	let steps = 256
	let range: T = sUpper - sLower
	let h: T = range / T(steps)

	func integrand(_ s: T) -> T {
		let density: T = chiDensity(s)
		guard density > T.zero else { return T.zero }
		let scaled: T = q * s
		return density * normalRangeCDF(x: scaled, k: k)
	}

	var sum: T = integrand(sLower) + integrand(sUpper)
	for i in 1..<steps {
		let s: T = sLower + T(i) * h
		let weight: T = (i % 2 == 0) ? T(2) : T(4)
		sum += weight * integrand(s)
	}
	let result: T = sum * h / T(3)

	if result < T.zero { return T.zero }
	if result > T(1) { return T(1) }
	return result
}

/// Tukey HSD (Honest Significant Difference) post-hoc test.
///
/// Uses the studentized range distribution for pairwise comparisons.
/// The Tukey-Kramer modification handles unbalanced designs.
/// For balanced designs, uses `SE = √(MSE / n)`.
/// For unbalanced designs, uses `SE = √(MSE/2 × (1/n_i + 1/n_j))`.
///
/// - Parameters:
///   - groups: The same groups passed to one-way ANOVA.
///   - anova: The result from ``oneWayANOVA(_:)``.
///   - alpha: Family-wise significance level (default 0.05).
/// - Returns: ``PostHocResult`` with all pairwise comparisons.
/// - Throws: ``BusinessMathError/insufficientData(required:actual:context:)`` if fewer than 2 groups
///           or any group is empty.
public func tukeyHSD<T: Real>(
	_ groups: [[T]], anova: OneWayANOVAResult<T>, alpha: T = T(5) / T(100)
) throws -> PostHocResult<T> where T: BinaryFloatingPoint {
	try validatePostHocInputs(groups, anova: anova)

	let k = groups.count
	let means = groupMeans(groups)
	let mse = anova.msWithin
	var comparisons: [PairwiseComparison<T>] = []

	// Determine if design is balanced (all groups same size)
	let sizes = groups.map(\.count)
	let isBalanced = sizes.allSatisfy { $0 == sizes[0] }

	for i in 0..<k {
		for j in (i + 1)..<k {
			let meanDiff = means[i] - means[j]
			let absMeanDiff = meanDiff < T.zero ? -meanDiff : meanDiff

			let se: T
			if isBalanced {
				// Balanced: SE = sqrt(MSE / n)
				se = T.sqrt(mse / T(sizes[0]))
			} else {
				// Tukey-Kramer: SE = sqrt(MSE/2 × (1/n_i + 1/n_j))
				let ni = T(groups[i].count)
				let nj = T(groups[j].count)
				let halfMSE = mse / T(2)
				let recipSum = T(1) / ni + T(1) / nj
				se = T.sqrt(halfMSE * recipSum)
			}

			guard se > T.zero else {
				comparisons.append(PairwiseComparison(
					groupA: i, groupB: j,
					meanDifference: meanDiff,
					testStatistic: T.zero,
					pValue: T(1),
					isSignificant: false))
				continue
			}

			let qStat = absMeanDiff / se
			let cdfValue = studentizedRangeCDF(q: qStat, k: k, df: anova.dfWithin)
			let p = T(1) - cdfValue

			// Clamp p to [0, 1]
			let clampedP: T
			if p < T.zero {
				clampedP = T.zero
			} else if p > T(1) {
				clampedP = T(1)
			} else {
				clampedP = p
			}

			comparisons.append(PairwiseComparison(
				groupA: i, groupB: j,
				meanDifference: meanDiff,
				testStatistic: qStat,
				pValue: clampedP,
				isSignificant: clampedP < alpha))
		}
	}

	return PostHocResult(
		method: "Tukey HSD",
		comparisons: comparisons,
		alpha: alpha,
		mse: mse,
		dfError: anova.dfWithin)
}
