import Foundation
import Numerics

// MARK: - Result Types

/// Result of a pairwise post-hoc comparison.
public struct PairwiseComparison<T: Real>: Sendable, Equatable {
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
public struct PostHocResult<T: Real>: Sendable, Equatable {
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
private func studentizedRangeCDF<T: Real>(
	q: T, k: Int, df: Int
) -> T where T: BinaryFloatingPoint {
	guard q > T.zero else { return T.zero }
	guard k >= 2 else { return T(1) }

	// Integration bounds — z ∈ [-8, 8] covers >99.9999% of N(0,1)
	let lower: T = T(-8)
	let upper: T = T(8)

	// Composite Simpson's rule with 256 subintervals (must be even)
	let n = 256
	let h = (upper - lower) / T(n)

	// Standard normal PDF: φ(z) = exp(-z²/2) / sqrt(2π)
	let sqrtTwoPi = T.sqrt(T(2) * T.pi)

	func phi(_ z: T) -> T {
		T.exp(-z * z / T(2)) / sqrtTwoPi
	}

	// Standard normal CDF via the library function
	func bigPhi(_ z: T) -> T {
		normalCDF(x: z, mean: T.zero, stdDev: T(1))
	}

	// Integrand: φ(z) × [Φ(z + q) - Φ(z)]^{k-1}
	func integrand(_ z: T) -> T {
		let phiZ = phi(z)
		let diff = bigPhi(z + q) - bigPhi(z)
		guard diff > T.zero else { return T.zero }
		let kMinus1 = k - 1
		let powered = T.pow(diff, T(kMinus1))
		return phiZ * powered
	}

	// Simpson's rule: ∫ f dx ≈ (h/3) × [f(x₀) + 4f(x₁) + 2f(x₂) + 4f(x₃) + ... + f(xₙ)]
	var sum = integrand(lower) + integrand(upper)

	for i in 1..<n {
		let z = lower + T(i) * h
		let weight: T = (i % 2 == 0) ? T(2) : T(4)
		sum += weight * integrand(z)
	}

	let integral = sum * h / T(3)
	let result = T(k) * integral

	// Clamp to [0, 1]
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
				se = T.sqrt(mse / T(2) * (T(1) / ni + T(1) / nj))
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
