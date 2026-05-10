import Foundation
import Numerics

/// Result of a one-way analysis of variance.
public struct OneWayANOVAResult<T: Real>: Sendable, Equatable {
	/// Sum of squares between groups.
	public let ssBetween: T
	/// Sum of squares within groups.
	public let ssWithin: T
	/// Total sum of squares.
	public let ssTotal: T
	/// Mean square between groups (ssBetween / dfBetween).
	public let msBetween: T
	/// Mean square within groups (ssWithin / dfWithin).
	public let msWithin: T
	/// F-statistic (msBetween / msWithin).
	public let fStatistic: T
	/// p-value from the F-distribution (probability of observing this F or larger under H₀).
	public let pValue: T
	/// Degrees of freedom between groups (k - 1).
	public let dfBetween: Int
	/// Degrees of freedom within groups (N - k).
	public let dfWithin: Int
	/// Number of groups.
	public let groupCount: Int
	/// Total number of observations across all groups.
	public let totalCount: Int
}

/// One-way analysis of variance (ANOVA).
///
/// Tests whether the means of k independent groups are all equal against the
/// alternative that at least one group mean differs from the others.
///
/// - Parameter groups: Array of groups, where each group is an array of observations.
///   Groups may have different sizes (unbalanced design supported).
/// - Returns: ANOVA table with SS, MS, F-statistic, and p-value.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 groups
///           or any group is empty.
///           `BusinessMathError.divisionByZero` if all within-group variance is zero
///           and dfWithin > 0 won't trigger this (only if all groups have size 1).
public func oneWayANOVA<T: Real>(_ groups: [[T]]) throws -> OneWayANOVAResult<T> {
	guard groups.count >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: groups.count,
			context: "One-way ANOVA requires at least 2 groups")
	}

	for (i, group) in groups.enumerated() {
		guard !group.isEmpty else {
			throw BusinessMathError.insufficientData(
				required: 1, actual: 0,
				context: "Group \(i) is empty")
		}
	}

	let k = groups.count
	let groupSizes = groups.map { $0.count }
	let totalN = groupSizes.reduce(0, +)

	guard totalN > k else {
		throw BusinessMathError.insufficientData(
			required: k + 1, actual: totalN,
			context: "Need more observations than groups for within-group df > 0")
	}

	// Compute group means
	let groupMeans: [T] = groups.map { group in
		group.reduce(T.zero, +) / T(group.count)
	}

	// Grand mean
	let grandTotal = groups.flatMap { $0 }.reduce(T.zero, +)
	let grandMean = grandTotal / T(totalN)

	// SS Between: Σ n_i × (mean_i - grand_mean)²
	var ssBetween = T.zero
	for i in 0..<k {
		let diff = groupMeans[i] - grandMean
		ssBetween += T(groupSizes[i]) * diff * diff
	}

	// SS Within: Σ Σ (x_ij - mean_i)²
	var ssWithin = T.zero
	for i in 0..<k {
		for x in groups[i] {
			let diff = x - groupMeans[i]
			ssWithin += diff * diff
		}
	}

	let ssTotal = ssBetween + ssWithin
	let dfBetween = k - 1
	let dfWithin = totalN - k

	let msBetween = ssBetween / T(dfBetween)
	let msWithin = ssWithin / T(dfWithin)

	let f: T
	let p: T

	if msWithin == T.zero {
		f = T.zero
		p = T(1)
	} else {
		f = msBetween / msWithin
		p = T(1) - (try fCDF(f: f, df1: dfBetween, df2: dfWithin))
	}

	return OneWayANOVAResult(
		ssBetween: ssBetween,
		ssWithin: ssWithin,
		ssTotal: ssTotal,
		msBetween: msBetween,
		msWithin: msWithin,
		fStatistic: f,
		pValue: p,
		dfBetween: dfBetween,
		dfWithin: dfWithin,
		groupCount: k,
		totalCount: totalN
	)
}
