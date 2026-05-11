import Foundation
import Numerics

/// Result of a statistical power analysis.
///
/// Contains the computed power along with the parameters used in the analysis.
/// Power is the probability of correctly rejecting the null hypothesis when
/// the alternative hypothesis is true (i.e., detecting a real effect).
public struct PowerAnalysisResult<T: Real & Sendable>: Sendable, Equatable {
	/// Statistical power: probability of rejecting H0 when H1 is true, in [0, 1].
	public let power: T
	/// Significance level used in the analysis.
	public let alpha: T
	/// Effect size (Cohen's d for t-test, Cohen's f for ANOVA).
	public let effectSize: T
	/// Total sample size (per group for two-sample t-test and ANOVA).
	public let sampleSize: Int
	/// Non-centrality parameter used in the computation.
	public let noncentrality: T
}

/// Power of a one-sample or two-sample t-test.
///
/// Computes the probability of rejecting H0 given the true effect size,
/// sample size, and significance level.
///
/// The non-centrality parameter is computed as:
/// - One-sample: delta = d * sqrt(n)
/// - Two-sample: delta = d * sqrt(n / 2)
///
/// where d is Cohen's d (standardized mean difference).
///
/// - Parameters:
///   - effectSize: Cohen's d (standardized mean difference), must be >= 0.
///   - n: Sample size per group (> 1).
///   - alpha: Significance level (default 0.05), must be in (0, 1).
///   - tails: Number of tails, 1 or 2 (default 2).
///   - twoSample: Whether this is a two-sample test (default false).
/// - Returns: ``PowerAnalysisResult`` with computed power.
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` for invalid parameters.
public func tTestPower<T: Real & Sendable>(
	effectSize: T,
	n: Int,
	alpha: T = T(5) / T(100),
	tails: Int = 2,
	twoSample: Bool = false
) throws -> PowerAnalysisResult<T> {
	guard effectSize >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Effect size must be non-negative",
			value: "\(effectSize)", expectedRange: "[0, inf)")
	}
	guard n > 1 else {
		throw BusinessMathError.invalidInput(
			message: "Sample size must be greater than 1",
			value: "\(n)", expectedRange: "(1, inf)")
	}
	guard alpha > T.zero && alpha < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Significance level must be in (0, 1)",
			value: "\(alpha)", expectedRange: "(0, 1)")
	}
	guard tails == 1 || tails == 2 else {
		throw BusinessMathError.invalidInput(
			message: "Number of tails must be 1 or 2",
			value: "\(tails)", expectedRange: "{1, 2}")
	}

	// Degrees of freedom
	let df: Int
	let noncentrality: T

	if twoSample {
		df = 2 * (n - 1)
		noncentrality = effectSize * T.sqrt(T(n) / T(2))
	} else {
		df = n - 1
		noncentrality = effectSize * T.sqrt(T(n))
	}

	// Critical value from central t distribution
	let alphaPerTail = alpha / T(tails)
	let critValue = try tQuantile(p: T(1) - alphaPerTail, df: df)

	// Power = P(reject H0 | H1 true)
	// For one-tailed (upper): power = 1 - P(T <= critValue | df, delta)
	// For two-tailed: power = P(T > critValue | df, delta) + P(T < -critValue | df, delta)
	let power: T

	if tails == 1 {
		let pBelow = try nonCentralTCDF(t: critValue, df: df, delta: noncentrality)
		power = T(1) - pBelow
	} else {
		// Two-tailed: reject if |T| > critValue
		let pBelowUpper = try nonCentralTCDF(t: critValue, df: df, delta: noncentrality)
		let pBelowLower = try nonCentralTCDF(t: -critValue, df: df, delta: noncentrality)
		power = (T(1) - pBelowUpper) + pBelowLower
	}

	let clampedPower = min(max(power, T.zero), T(1))

	return PowerAnalysisResult(
		power: clampedPower,
		alpha: alpha,
		effectSize: effectSize,
		sampleSize: n,
		noncentrality: noncentrality
	)
}

/// Power of a one-way ANOVA F-test.
///
/// Computes the probability of detecting a difference among group means
/// given the effect size, number of groups, and sample size per group.
///
/// The non-centrality parameter is lambda = k * n * f^2
/// where k is the number of groups, n is the sample size per group,
/// and f is Cohen's f.
///
/// - Parameters:
///   - effectSize: Cohen's f (>= 0). Small = 0.10, Medium = 0.25, Large = 0.40.
///   - groups: Number of groups k (>= 2).
///   - nPerGroup: Sample size per group (>= 2).
///   - alpha: Significance level (default 0.05), must be in (0, 1).
/// - Returns: ``PowerAnalysisResult`` with computed power.
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` for invalid parameters.
public func anovaPower<T: Real & Sendable>(
	effectSize: T,
	groups: Int,
	nPerGroup: Int,
	alpha: T = T(5) / T(100)
) throws -> PowerAnalysisResult<T> {
	guard effectSize >= T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Effect size must be non-negative",
			value: "\(effectSize)", expectedRange: "[0, inf)")
	}
	guard groups >= 2 else {
		throw BusinessMathError.invalidInput(
			message: "Number of groups must be at least 2",
			value: "\(groups)", expectedRange: "[2, inf)")
	}
	guard nPerGroup >= 2 else {
		throw BusinessMathError.invalidInput(
			message: "Sample size per group must be at least 2",
			value: "\(nPerGroup)", expectedRange: "[2, inf)")
	}
	guard alpha > T.zero && alpha < T(1) else {
		throw BusinessMathError.invalidInput(
			message: "Significance level must be in (0, 1)",
			value: "\(alpha)", expectedRange: "(0, 1)")
	}

	let df1 = groups - 1
	let df2 = groups * (nPerGroup - 1)
	let lambda = T(groups) * T(nPerGroup) * effectSize * effectSize

	// Critical F value
	let critF = try fQuantile(p: T(1) - alpha, df1: df1, df2: df2)

	// Power = P(F > critF | df1, df2, lambda)
	//       = 1 - nonCentralFCDF(critF, df1, df2, lambda)
	let pBelow = try nonCentralFCDF(f: critF, df1: df1, df2: df2, lambda: lambda)
	let power = T(1) - pBelow

	let clampedPower = min(max(power, T.zero), T(1))

	return PowerAnalysisResult(
		power: clampedPower,
		alpha: alpha,
		effectSize: effectSize,
		sampleSize: nPerGroup,
		noncentrality: lambda
	)
}
