import Foundation
import Numerics

/// ICC model types per Shrout & Fleiss (1979).
///
/// Specifies the statistical model used for computing the intraclass
/// correlation coefficient:
/// - ``oneWayRandom``: Each subject is rated by a different set of raters
///   randomly selected from a larger population (ICC(1,1)).
/// - ``twoWayRandom``: A random sample of raters rates every subject;
///   both subjects and raters are random effects (ICC(2,1)).
/// - ``twoWayMixed``: The specific raters in the study are the only raters
///   of interest; subjects are random, raters are fixed (ICC(3,1)).
public enum ICCModel: Sendable {
	/// One-way random effects model (ICC(1,1)).
	case oneWayRandom
	/// Two-way random effects model (ICC(2,1)).
	case twoWayRandom
	/// Two-way mixed effects model (ICC(3,1)).
	case twoWayMixed
}

/// ICC agreement type.
///
/// - ``absolute``: Measures whether raters assign the same absolute scores.
/// - ``consistency``: Measures whether raters are consistent in their
///   relative ordering (systematic differences between raters are ignored).
public enum ICCAgreement: Sendable {
	/// Absolute agreement among raters.
	case absolute
	/// Consistency (relative agreement) among raters.
	case consistency
}

/// Result of an intraclass correlation coefficient computation.
///
/// Contains the ICC estimate, a confidence interval, the F-statistic
/// used in the computation, and descriptive metadata.
public struct ICCResult<T: Real>: Sendable {
	/// The intraclass correlation coefficient estimate.
	public let icc: T
	/// Lower bound of the confidence interval.
	public let lowerBound: T
	/// Upper bound of the confidence interval.
	public let upperBound: T
	/// The F-statistic used in the ICC computation.
	public let fStatistic: T
	/// Degrees of freedom as (numerator df, denominator df).
	public let df: (Int, Int)
	/// Number of subjects (rows).
	public let subjects: Int
	/// Number of raters (columns).
	public let raters: Int
}

extension ICCResult: Equatable {
	public static func == (lhs: ICCResult, rhs: ICCResult) -> Bool {
		lhs.icc == rhs.icc &&
		lhs.lowerBound == rhs.lowerBound &&
		lhs.upperBound == rhs.upperBound &&
		lhs.fStatistic == rhs.fStatistic &&
		lhs.df.0 == rhs.df.0 && lhs.df.1 == rhs.df.1 &&
		lhs.subjects == rhs.subjects &&
		lhs.raters == rhs.raters
	}
}

/// Computes the intraclass correlation coefficient (ICC).
///
/// The ICC quantifies the degree of agreement or consistency among
/// multiple raters measuring the same set of subjects. This
/// implementation supports the three primary models defined by
/// Shrout & Fleiss (1979):
///
/// - **ICC(1,1)**: One-way random model — uses one-way ANOVA.
/// - **ICC(2,1)**: Two-way random, absolute agreement — uses two-way ANOVA.
/// - **ICC(3,1)**: Two-way mixed, consistency — uses two-way ANOVA.
///
/// A 95% confidence interval is computed using F-distribution quantiles.
///
/// - Parameters:
///   - ratings: Matrix where `ratings[i][j]` is the rating of subject `i`
///     by rater `j`. All rows must have the same length (balanced design).
///   - model: The ICC model type (see ``ICCModel``).
///   - agreement: The agreement type (see ``ICCAgreement``).
///   - confidence: Confidence level for the interval (default 0.95).
/// - Returns: An ``ICCResult`` containing the ICC estimate, confidence
///   interval, F-statistic, degrees of freedom, and metadata.
/// - Throws: `BusinessMathError.insufficientData` if fewer than 2 subjects
///   or fewer than 2 raters.
///   `BusinessMathError.mismatchedDimensions` if rows differ in length.
public func icc<T: Real>(
	_ ratings: [[T]],
	model: ICCModel,
	agreement: ICCAgreement,
	confidence: T = T(95) / T(100)
) throws -> ICCResult<T> {
	let n = ratings.count

	guard n >= 2 else {
		throw BusinessMathError.insufficientData(
			required: 2, actual: n,
			context: "ICC requires at least 2 subjects (rows)")
	}

	guard let firstRow = ratings.first, firstRow.count >= 2 else {
		let colCount = ratings.first?.count ?? 0
		throw BusinessMathError.insufficientData(
			required: 2, actual: colCount,
			context: "ICC requires at least 2 raters (columns)")
	}

	let k = firstRow.count

	// Validate balanced design
	for i in 1..<n {
		guard ratings[i].count == k else {
			throw BusinessMathError.mismatchedDimensions(
				message: "All rows must have the same number of columns",
				expected: "\(k)", actual: "\(ratings[i].count)")
		}
	}

	// Check degenerate case: all ratings identical → perfect agreement
	let firstValue = ratings[0][0]
	var allIdentical = true
	for row in ratings {
		for value in row {
			if value != firstValue {
				allIdentical = false
				break
			}
		}
		if !allIdentical { break }
	}

	if allIdentical {
		return ICCResult(
			icc: T(1),
			lowerBound: T(1),
			upperBound: T(1),
			fStatistic: T.zero,
			df: (n - 1, n * (k - 1)),
			subjects: n,
			raters: k
		)
	}

	switch model {
	case .oneWayRandom:
		return try computeICC1(ratings, n: n, k: k, confidence: confidence)
	case .twoWayRandom:
		return try computeICC2(ratings, n: n, k: k, agreement: agreement, confidence: confidence)
	case .twoWayMixed:
		return try computeICC3(ratings, n: n, k: k, agreement: agreement, confidence: confidence)
	}
}

// MARK: - ICC(1,1) One-Way Random

/// Computes ICC(1,1) using one-way ANOVA.
private func computeICC1<T: Real>(
	_ ratings: [[T]],
	n: Int,
	k: Int,
	confidence: T
) throws -> ICCResult<T> {
	// Treat each subject (row) as a group
	let anova = try oneWayANOVA(ratings)
	let msR = anova.msBetween  // MS between subjects
	let msW = anova.msWithin   // MS within subjects

	let kT = T(k)

	// ICC(1,1) = (MSr - MSw) / (MSr + (k-1)*MSw)
	let denominator = msR + (kT - T(1)) * msW
	let iccValue: T
	if denominator == T.zero {
		// All variation is zero — perfect agreement handled above,
		// this catches remaining edge cases
		iccValue = T(1)
	} else {
		iccValue = (msR - msW) / denominator
	}

	// F = MSr / MSw
	let df1 = n - 1
	let df2 = n * (k - 1)
	let fStat: T
	if msW == T.zero {
		// Degenerate case: zero within-group variance means perfect agreement
		return ICCResult(
			icc: iccValue,
			lowerBound: iccValue,
			upperBound: iccValue,
			fStatistic: T.zero,
			df: (df1, df2),
			subjects: n,
			raters: k
		)
	} else {
		fStat = msR / msW
	}

	// Confidence interval
	let alpha = T(1) - confidence
	let (lower, upper) = computeICC1CI(
		fStat: fStat, n: n, k: k, df1: df1, df2: df2, alpha: alpha
	)

	return ICCResult(
		icc: iccValue,
		lowerBound: lower,
		upperBound: upper,
		fStatistic: fStat,
		df: (df1, df2),
		subjects: n,
		raters: k
	)
}

/// Computes CI for ICC(1,1) using F-ratio transform.
private func computeICC1CI<T: Real>(
	fStat: T,
	n: Int,
	k: Int,
	df1: Int,
	df2: Int,
	alpha: T
) -> (T, T) {
	let kT = T(k)
	let halfAlpha = alpha / T(2)

	guard let fUpper = try? fQuantile(p: T(1) - halfAlpha, df1: df1, df2: df2),
		  let fLower = try? fQuantile(p: halfAlpha, df1: df1, df2: df2),
		  fUpper > T.zero, fLower > T.zero else {
		return (-T(1), T(1))
	}

	let fL = fStat / fUpper
	let fU = fStat / fLower

	let lower = (fL - T(1)) / (fL + kT - T(1))
	let upper = (fU - T(1)) / (fU + kT - T(1))

	return (lower, upper)
}

// MARK: - ICC(2,1) Two-Way Random

/// Computes ICC(2,1) using two-way ANOVA.
private func computeICC2<T: Real>(
	_ ratings: [[T]],
	n: Int,
	k: Int,
	agreement: ICCAgreement,
	confidence: T
) throws -> ICCResult<T> {
	let anova = try twoWayANOVA(ratings)
	let msR = anova.msSubjects
	let msC = anova.msRaters
	let msE = anova.msError

	let nT = T(n)
	let kT = T(k)

	let iccValue: T
	let df1 = n - 1
	let df2 = (n - 1) * (k - 1)

	switch agreement {
	case .absolute:
		// ICC(2,1) = (MSr - MSe) / (MSr + (k-1)*MSe + k*(MSc - MSe)/n)
		let denominator = msR + (kT - T(1)) * msE + kT * (msC - msE) / nT
		if denominator == T.zero {
			iccValue = T(1)
		} else {
			iccValue = (msR - msE) / denominator
		}
	case .consistency:
		// When called as twoWayRandom with consistency, use same formula
		// but without the rater effect term (effectively ICC(3,1))
		let denominator = msR + (kT - T(1)) * msE
		if denominator == T.zero {
			iccValue = T(1)
		} else {
			iccValue = (msR - msE) / denominator
		}
	}

	// F = MSr / MSe
	let fStat: T
	if msE == T.zero {
		// Degenerate case: zero residual error means perfect fit
		// Return ICC with CI = [iccValue, iccValue]
		return ICCResult(
			icc: iccValue,
			lowerBound: iccValue,
			upperBound: iccValue,
			fStatistic: T.zero,
			df: (df1, df2),
			subjects: n,
			raters: k
		)
	} else {
		fStat = msR / msE
	}

	// Confidence interval
	let alpha = T(1) - confidence
	let (lower, upper) = computeTwoWayCI(
		fStat: fStat, n: n, k: k, df1: df1, df2: df2,
		msR: msR, msC: msC, msE: msE,
		agreement: agreement, model: .twoWayRandom, alpha: alpha
	)

	return ICCResult(
		icc: iccValue,
		lowerBound: lower,
		upperBound: upper,
		fStatistic: fStat,
		df: (df1, df2),
		subjects: n,
		raters: k
	)
}

// MARK: - ICC(3,1) Two-Way Mixed

/// Computes ICC(3,1) using two-way ANOVA.
private func computeICC3<T: Real>(
	_ ratings: [[T]],
	n: Int,
	k: Int,
	agreement: ICCAgreement,
	confidence: T
) throws -> ICCResult<T> {
	let anova = try twoWayANOVA(ratings)
	let msR = anova.msSubjects
	let msC = anova.msRaters
	let msE = anova.msError

	let kT = T(k)

	// ICC(3,1) = (MSr - MSe) / (MSr + (k-1)*MSe)
	let denominator = msR + (kT - T(1)) * msE
	let iccValue: T
	if denominator == T.zero {
		iccValue = T(1)
	} else {
		iccValue = (msR - msE) / denominator
	}

	let df1 = n - 1
	let df2 = (n - 1) * (k - 1)

	// F = MSr / MSe
	let fStat: T
	if msE == T.zero {
		// Degenerate case: zero residual error means perfect consistency
		// Return ICC with CI = [iccValue, iccValue]
		return ICCResult(
			icc: iccValue,
			lowerBound: iccValue,
			upperBound: iccValue,
			fStatistic: T.zero,
			df: (df1, df2),
			subjects: n,
			raters: k
		)
	} else {
		fStat = msR / msE
	}

	// Confidence interval
	let alpha = T(1) - confidence
	let (lower, upper) = computeTwoWayCI(
		fStat: fStat, n: n, k: k, df1: df1, df2: df2,
		msR: msR, msC: msC, msE: msE,
		agreement: agreement, model: .twoWayMixed, alpha: alpha
	)

	return ICCResult(
		icc: iccValue,
		lowerBound: lower,
		upperBound: upper,
		fStatistic: fStat,
		df: (df1, df2),
		subjects: n,
		raters: k
	)
}

// MARK: - Two-Way CI Helper

/// Computes CI for ICC(2,1) and ICC(3,1) using F-ratio transform.
private func computeTwoWayCI<T: Real>(
	fStat: T,
	n: Int,
	k: Int,
	df1: Int,
	df2: Int,
	msR: T,
	msC: T,
	msE: T,
	agreement: ICCAgreement,
	model: ICCModel,
	alpha: T
) -> (T, T) {
	let kT = T(k)
	let halfAlpha = alpha / T(2)

	guard let fUpper = try? fQuantile(p: T(1) - halfAlpha, df1: df1, df2: df2),
		  let fLower = try? fQuantile(p: halfAlpha, df1: df1, df2: df2),
		  fUpper > T.zero, fLower > T.zero else {
		return (-T(1), T(1))
	}

	let fL = fStat / fUpper
	let fU = fStat / fLower

	switch (model, agreement) {
	case (.twoWayRandom, .absolute):
		// ICC(2,1) absolute CI: account for rater variance
		// b adjusts for systematic rater bias in the denominator
		guard msE > T.zero else {
			return (-T(1), T(1))
		}
		let b = kT * (msC - msE) / msE

		let aL = kT * fL
		let lower = (aL - T(1)) / (aL + kT - T(1) + b)
		let aU = kT * fU
		let upper = (aU - T(1)) / (aU + kT - T(1) + b)
		return (lower, upper)

	default:
		// ICC(3,1) and ICC(2,1) consistency use the same transform
		let lower = (fL - T(1)) / (fL + kT - T(1))
		let upper = (fU - T(1)) / (fU + kT - T(1))
		return (lower, upper)
	}
}
