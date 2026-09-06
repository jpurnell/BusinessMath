//
//  SpreadsheetStatistics.swift
//  BusinessMath
//
//  The handful of descriptive and predictive functions a spreadsheet offers that this
//  package could compute but could not name.
//

import Foundation
import Numerics

// MARK: - Standardising

/// A value expressed in standard deviations from a mean — Excel's `STANDARDIZE`.
///
/// ```
/// (x − mean) / stdDev
/// ```
///
/// The z-score of a single observation against a distribution whose parameters are
/// already known, which is what distinguishes it from ``zScore(_:vs:)``: nothing is
/// estimated here.
///
/// - Parameters:
///   - x: The value.
///   - mean: The distribution's mean.
///   - stdDev: The distribution's standard deviation. Must be positive.
/// - Returns: How many standard deviations `x` sits from `mean`.
/// - Throws: `BusinessMathError.invalidInput` if `stdDev` is not positive.
public func standardize<T: Real>(_ x: T, mean: T, stdDev: T) throws -> T {
	guard stdDev > T.zero else {
		throw BusinessMathError.invalidInput(
			message: "Standard deviation must be positive to standardise against",
			value: "\(stdDev)", expectedRange: "(0, ∞)")
	}
	return (x - mean) / stdDev
}

// MARK: - Linear and exponential prediction

/// The value a least-squares line predicts at `x` — Excel's `TREND` and `FORECAST.LINEAR`.
///
/// The two Excel names compute the same thing from the same fit; `FORECAST.LINEAR` takes
/// its arguments in the other order, which is a binding's problem rather than this one's.
///
/// - Parameters:
///   - x: Where to predict.
///   - knownX: The observed independent values.
///   - knownY: The observed dependent values, in the same order.
/// - Returns: `intercept + slope · x`.
/// - Throws: `BusinessMathError` if the two arrays disagree in length or are too short
///   to fit a line.
public func linearForecast<T: Real>(at x: T, knownX: [T], knownY: [T]) throws -> T {
	let gradient: T = try slope(knownX, knownY)
	let offset: T = try intercept(knownX, knownY)
	return offset + gradient * x
}

/// The coefficients of a least-squares exponential fit — Excel's `LOGEST`.
///
/// Fits `y = b · mˣ` by regressing `ln y` on `x`, which turns the exponential into a
/// line: `ln y = ln b + x·ln m`. So the returned `base` is `exp(slope)` and the returned
/// `coefficient` is `exp(intercept)`.
///
/// **Every `y` must be positive.** The fit is performed in log space and a non-positive
/// observation has no logarithm — Excel reports `#NUM!` and this throws, rather than
/// dropping the point and fitting the rest, which would answer a question nobody asked.
///
/// - Parameters:
///   - knownX: The observed independent values.
///   - knownY: The observed dependent values. All must be positive.
/// - Returns: `base` is *m*, the factor per unit of `x`; `coefficient` is *b*, the value
///   at `x = 0`.
/// - Throws: `BusinessMathError.invalidInput` if any `y` is not positive, or the arrays
///   are mismatched or too short.
public func exponentialFit<T: Real>(knownX: [T], knownY: [T]) throws -> (base: T, coefficient: T) {
	guard knownX.count == knownY.count else {
		throw BusinessMathError.invalidInput(
			message: "Independent and dependent values must be paired",
			value: "\(knownX.count) x, \(knownY.count) y", expectedRange: "equal counts")
	}
	guard knownY.allSatisfy({ $0 > T.zero }) else {
		throw BusinessMathError.invalidInput(
			message: "An exponential fit is performed in log space, so every observation must be positive",
			value: "\(knownY.first(where: { $0 <= T.zero }).map { "\($0)" } ?? "a non-positive value")",
			expectedRange: "(0, ∞)")
	}

	let logged: [T] = knownY.map { T.log($0) }
	let gradient: T = try slope(knownX, logged)
	let offset: T = try intercept(knownX, logged)
	return (base: T.exp(gradient), coefficient: T.exp(offset))
}

/// The value a least-squares exponential fit predicts at `x` — Excel's `GROWTH`.
///
/// `b · mˣ`, with *m* and *b* from ``exponentialFit(knownX:knownY:)``.
///
/// - Throws: `BusinessMathError.invalidInput` under the same conditions as the fit.
public func exponentialForecast<T: Real>(at x: T, knownX: [T], knownY: [T]) throws -> T {
	let fit = try exponentialFit(knownX: knownX, knownY: knownY)
	return fit.coefficient * T.pow(fit.base, x)
}

// MARK: - Ranking

/// How a value ranks within a set — Excel's `RANK.EQ` and `RANK.AVG`.
public enum RankTieHandling: Sendable {
	/// Tied values all take the best rank of the group — Excel's `RANK.EQ`. Three values
	/// tied for second are all second, and the next is fifth.
	case highestOfTied
	/// Tied values share the average of the ranks they span — `RANK.AVG`. Three tied for
	/// second through fourth are all third.
	case averageOfTied
}

/// A value's rank within a set — Excel's `RANK.EQ` and `RANK.AVG`.
///
/// Ranks are one-based and, by default, **descending**: the largest value is rank 1,
/// which is Excel's default and the opposite of what "rank 1" suggests to most readers.
///
/// - Parameters:
///   - value: The value to rank. Must appear in `values`.
///   - values: The set to rank within.
///   - ascending: `false`, the default, makes the largest value rank 1.
///   - ties: How to rank equal values.
/// - Returns: The rank, fractional only when `ties` is ``RankTieHandling/averageOfTied``
///   and the value is tied.
/// - Throws: `BusinessMathError.invalidInput` if `values` is empty or does not contain
///   `value` — Excel reports `#N/A` for the latter, and answering anything would be a
///   guess.
public func rank<T: Real>(
	_ value: T,
	in values: [T],
	ascending: Bool = false,
	ties: RankTieHandling = .highestOfTied
) throws -> T {
	guard !values.isEmpty else {
		throw BusinessMathError.invalidInput(
			message: "Cannot rank within an empty set", value: "[]", expectedRange: "at least one value")
	}
	guard values.contains(where: { $0 == value }) else {
		throw BusinessMathError.invalidInput(
			message: "The value being ranked does not appear in the set",
			value: "\(value)", expectedRange: "a member of the set")
	}

	let better = values.filter { ascending ? $0 < value : $0 > value }.count
	let tied = values.filter { $0 == value }.count
	let best: T = T(better + 1)

	switch ties {
	case .highestOfTied:
		return best
	case .averageOfTied:
		// The tied group occupies ranks `best` through `best + tied − 1`; their mean is
		// the midpoint of that run.
		let span: T = T(tied - 1) / T(2)
		return best + span
	}
}

/// A value's position within a set as a proportion — Excel's `PERCENTRANK.INC`.
///
/// ```
/// (values strictly below) / (count − 1)
/// ```
///
/// Inclusive: the smallest value ranks 0 and the largest ranks 1. A value between two
/// observations is interpolated linearly between their ranks.
///
/// ## Three significant digits, and they are the spreadsheet's
///
/// A spreadsheet returns this to **three significant digits** unless asked for more:
/// 6/9 comes back as 0.667, not 0.6666666667. That is worth reproducing rather than
/// quietly improving on, because a binding returning the exact value would disagree with
/// the sheet it came from.
///
/// The rounding is to nearest, measured: 5/9 returns 0.556 and 6/9 returns 0.667, where
/// truncation would give 0.555 and 0.666. Microsoft's documentation says three
/// significant digits without saying which way a tie breaks, and the reference here is
/// LibreOffice rather than Excel — the two have already been found to disagree on
/// `ACCRINT`. If a real Excel value ever shows a truncation, this is the line to change,
/// and `significantDigits` already lets a caller opt out of the reduction entirely.
///
/// - Parameters:
///   - value: The value to locate.
///   - values: The set to locate it within. Needs at least two values.
///   - significantDigits: How many significant digits to keep. Excel's default is three.
/// - Returns: The proportion of the set at or below `value`, in `[0, 1]`.
/// - Throws: `BusinessMathError.invalidInput` for a set of fewer than two values, a
///   `value` outside their range, or fewer than one significant digit.
public func percentRank<T: Real & BinaryFloatingPoint>(
	_ value: T,
	in values: [T],
	significantDigits: Int = 3
) throws -> T {
	guard values.count >= 2 else {
		throw BusinessMathError.invalidInput(
			message: "Percent rank needs at least two values to rank between",
			value: "\(values.count) values", expectedRange: "[2, ∞)")
	}
	guard significantDigits >= 1 else {
		throw BusinessMathError.invalidInput(
			message: "Significant digits must be at least one",
			value: "\(significantDigits)", expectedRange: "[1, ∞)")
	}
	let sorted = values.sorted()
	guard let smallest = sorted.first, let largest = sorted.last,
		  value >= smallest, value <= largest else {
		throw BusinessMathError.invalidInput(
			message: "The value lies outside the set's range",
			value: "\(value)", expectedRange: "within the observed values")
	}

	let span: T = T(sorted.count - 1)
	var exact: T = T.zero
	if let index = sorted.firstIndex(where: { $0 == value }) {
		exact = T(index) / span
	} else {
		// Between two observations: interpolate between their ranks.
		guard let upper = sorted.firstIndex(where: { $0 > value }), upper > 0 else {
			return T.zero
		}
		let below = sorted[upper - 1]
		let above = sorted[upper]
		let within: T = (value - below) / (above - below)
		exact = (T(upper - 1) + within) / span
	}

	return Self_.rounded(exact, toSignificantDigits: significantDigits)
}

private enum Self_ {
	/// Rounds to nearest at a number of significant digits, as the spreadsheet does.
	static func rounded<T: Real & BinaryFloatingPoint>(_ value: T, toSignificantDigits digits: Int) -> T {
		guard value != T.zero, value.isFinite else { return value }
		let magnitude = Double(abs(value))
		let exponent = Foundation.floor(Foundation.log10(magnitude))
		let scale = Foundation.pow(10.0, Double(digits) - 1 - exponent)
		let scaled = Double(value) * scale
		return T(scaled.rounded(.toNearestOrAwayFromZero) / scale)
	}
}
