//
//  Concentration.swift
//  BusinessMath
//

import Foundation
import Numerics

/// One vertex of a Lorenz curve.
public struct LorenzPoint<T: Real & Sendable>: Sendable {

	/// The cumulative share of the population, from the smallest value upward.
	public let population: T

	/// The cumulative share of the total they hold.
	public let share: T

	/// Creates a point.
	///
	/// - Parameters:
	///   - population: Cumulative population share.
	///   - share: Cumulative share of the total.
	public init(population: T, share: T) {
		self.population = population
		self.share = share
	}
}

/// How unevenly a total is distributed: Gini, Lorenz, and top shares.
///
/// ```swift
/// let revenue: [Double] = [50, 25, 12, 6, 3, 2, 1, 1]
/// if let concentration = Concentration(values: revenue) {
///     print(concentration.gini)                        // 0.62
///     print(concentration.topShare(fraction: 0.25) ?? 0)  // 0.75
/// }
/// ```
///
/// ## Domain-neutral, and the reason it is worth saying
///
/// The same three numbers answer "how concentrated is our revenue in a few accounts",
/// "how concentrated is this loan book", and "how unequal are these incomes". They are
/// filed in `Statistics/` rather than under marketing because a credit team should not
/// have to import a marketing module to ask the second question.
///
/// ## Which Gini this is
///
/// The **sample** coefficient, which for `n` observations ranges over `[0, (n − 1)/n]`
/// rather than `[0, 1]`. One unit holding everything out of five gives 0.8, not 1.0.
/// That is not an approximation to be corrected: with a finite sample the most unequal
/// arrangement genuinely is `(n − 1)/n`, and reporting 1.0 would claim a concentration
/// the data cannot exhibit. Multiply by `n/(n − 1)` for the population form if a
/// comparison demands it, and say so where the number is published.
public struct Concentration<T: Real & Sendable & BinaryFloatingPoint>: Sendable {

	/// The values, sorted ascending — the order every calculation here needs.
	public let sortedValues: [T]

	/// Their sum.
	public let total: T

	/// Creates a measure, or `nil` when there is nothing to measure.
	///
	/// - Parameter values: Non-negative, finite quantities — incomes, revenues,
	///   balances. At least one must be positive.
	/// - Returns: `nil` for empty input, a negative or non-finite value, or a total of
	///   zero. Negatives are refused rather than tolerated because they can push the
	///   Lorenz curve above the diagonal, where the Gini stops meaning what it says; a
	///   total of zero is refused because the coefficient is relative to the mean, and
	///   a distribution of nothing has no concentration rather than a concentration of
	///   zero.
	public init?(values: [T]) {
		guard !values.isEmpty else { return nil }
		guard values.allSatisfy({ $0.isFinite && $0 >= T.zero }) else { return nil }
		let sum = values.reduce(T.zero, +)
		guard sum > T.zero else { return nil }
		self.sortedValues = values.sorted()
		self.total = sum
	}

	/// The Lorenz curve: cumulative share of the total against cumulative share of the
	/// population, taken from the smallest value upward.
	///
	/// The diagonal is perfect equality; the further the curve sags below it, the more
	/// concentrated the distribution.
	public var lorenzCurve: [LorenzPoint<T>] {
		let count: T = T(sortedValues.count)
		var running: T = T.zero
		var points: [LorenzPoint<T>] = []
		points.reserveCapacity(sortedValues.count)
		for (index, value) in sortedValues.enumerated() {
			running += value
			let population: T = T(index + 1) / count
			let share: T = running / total
			points.append(LorenzPoint(population: population, share: share))
		}
		return points
	}

	/// The Gini coefficient, as twice the area between the Lorenz curve and the
	/// diagonal.
	///
	/// Computed from the sorted values in one pass rather than from the `O(n²)` pairwise
	/// definition. The two are the same number — `ConcentrationTests` checks exactly
	/// that, computing the pairwise form independently — and this one is the reason the
	/// type sorts on construction.
	public var gini: T {
		let n: T = T(sortedValues.count)
		guard sortedValues.count > 1 else { return T.zero }
		// Σ (2i − n − 1)·xᵢ over one-based i, divided by n·Σx. The weights run from
		// −(n−1) at the smallest value to +(n−1) at the largest and sum to zero, which
		// is why an equal distribution gives exactly zero rather than a rounding of it.
		var weighted: T = T.zero
		for (index, value) in sortedValues.enumerated() {
			let position: T = T(2 * (index + 1))
			let weight: T = position - n - 1
			weighted += weight * value
		}
		let denominator: T = n * total
		guard denominator > T.zero else { return T.zero }
		return weighted / denominator
	}

	/// The share of the total held by the highest-valued `fraction` of the population.
	///
	/// The "eighty-twenty" question, asked properly: the count is rounded to the nearest
	/// whole observation and never falls below one, since a fraction of a unit holds no
	/// determinate share.
	///
	/// - Parameter fraction: A share of the population, in `(0, 1]`.
	/// - Returns: The share of the total they hold, or `nil` for a fraction outside that
	///   interval.
	public func topShare(fraction: T) -> T? {
		guard fraction > T.zero, fraction <= T(1) else { return nil }
		let count: T = T(sortedValues.count)
		let scaled: T = fraction * count
		let rounded = Int(scaled.rounded())
		let taken = Swift.min(Swift.max(rounded, 1), sortedValues.count)
		var held: T = T.zero
		for value in sortedValues.suffix(taken) { held += value }
		return held / total
	}

	/// The Pareto ratio: the share held by the top fifth.
	///
	/// Named because it is asked so often, and because "the 80/20 rule" is a claim about
	/// this number rather than a law — it is 0.8 only when the distribution happens to
	/// make it so, and reporting the measured value is the point.
	public var paretoShare: T? {
		topShare(fraction: T(1) / T(5))
	}
}
