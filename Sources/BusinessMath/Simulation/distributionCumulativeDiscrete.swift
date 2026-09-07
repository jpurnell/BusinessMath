//
//  distributionCumulativeDiscrete.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A discrete distribution given by a cumulative curve.
///
/// The discrete sibling of ``DistributionCumul``. Both take `(value, cumulative
/// probability)` pairs; this one puts the mass *at* the stated values instead of
/// spreading it between them.
///
/// Binds Risk Solver's `PsiCumulD(min, max, {x₁..xₙ}, {p₁..pₙ})`.
///
/// ```swift
/// // "40% chance of 10 or less, 75% of 20 or less, certainly 50 or less."
/// if let outcome = DistributionCumulativeDiscrete(values: [10, 20, 50],
///                                                 cumulative: [0.4, 0.75, 1.0]) {
///     print(outcome.pmf(20))        // 0.35
///     print(outcome.quantile(0.5))  // 20
/// }
/// ```
///
/// ## Why this is not `DistributionCumul`
///
/// The difference is where the mass sits, and it changes every answer. Given the same
/// pairs, the continuous version can return 14.3; this one returns only 10, 20 or 50.
/// Neither is a better model of the other's data — a quantity that genuinely takes
/// three values should not be interpolated, and one that varies continuously should
/// not be rounded to three.
///
/// ## The support and the contract
///
/// ``DiscreteDistribution`` requires a `quantile` that is monotone non-decreasing in
/// `p` and defined for every probability, because quasi-random sampling calls it
/// directly. This returns the smallest stated value whose cumulative probability
/// reaches `p`, which satisfies that by construction: the values increase and the
/// cumulative probabilities do not decrease.
public struct DistributionCumulativeDiscrete: DiscreteDistribution, Sendable {

	/// The numeric type used for probabilities.
	public typealias T = Double

	/// The values the distribution can take, strictly increasing.
	public let values: [Int]

	/// The cumulative probability at each value, non-decreasing and ending at 1.
	public let cumulative: [Double]

	/// Creates a discrete distribution from a cumulative curve.
	///
	/// - Parameters:
	///   - values: The outcomes, strictly increasing.
	///   - cumulative: `P(X ≤ value)` at each, non-decreasing, all in `(0, 1]`, with
	///     the last exactly 1.
	/// - Returns: `nil` unless the two arrays are the same non-empty length, the values
	///   strictly increase, the probabilities do not decrease, and the last is 1. A
	///   curve not reaching 1 is missing mass, and normalising it on the caller's
	///   behalf would be inventing an outcome they did not state.
	public init?(values: [Int], cumulative: [Double]) {
		guard !values.isEmpty, values.count == cumulative.count else { return nil }
		guard cumulative.allSatisfy({ $0 > 0 && $0 <= 1 }) else { return nil }
		guard zip(values, values.dropFirst()).allSatisfy({ $0 < $1 }) else { return nil }
		guard zip(cumulative, cumulative.dropFirst()).allSatisfy({ $0 <= $1 }) else { return nil }
		guard let last = cumulative.last, abs(last - 1) < 1e-12 else { return nil }
		self.values = values
		self.cumulative = cumulative
	}

	/// Creates one from `Double` values, rounding each to the nearest integer.
	///
	/// - Parameters:
	///   - doubleValues: The outcomes.
	///   - cumulative: `P(X ≤ value)` at each.
	/// - Returns: `nil` under the same conditions as the primary initialiser, or if
	///   two values round to the same integer — which would silently merge two
	///   outcomes the caller stated separately.
	public init?(values doubleValues: [Double], cumulative: [Double]) {
		guard doubleValues.allSatisfy({ $0.isFinite }) else { return nil }
		let rounded = doubleValues.map { Int($0.rounded()) }
		guard Set(rounded).count == rounded.count else { return nil }
		self.init(values: rounded, cumulative: cumulative)
	}

	/// The probability of exactly `k`.
	///
	/// - Parameter k: Any integer; zero outside the stated values.
	/// - Returns: A probability in [0, 1].
	public func pmf(_ k: Int) -> Double {
		guard let index = values.firstIndex(of: k) else { return 0 }
		let below: Double = index == 0 ? 0 : cumulative[index - 1]
		return cumulative[index] - below
	}

	/// The probability of `k` or less.
	///
	/// - Parameter k: Any integer, inside the support or not.
	/// - Returns: A probability in [0, 1], non-decreasing in `k`.
	public func cdf(_ k: Int) -> Double {
		guard let first = values.first, k >= first else { return 0 }
		var answer = 0.0
		for (index, value) in values.enumerated() where value <= k {
			answer = cumulative[index]
		}
		return answer
	}

	/// The smallest value whose cumulative probability reaches `p`.
	///
	/// - Parameter p: A probability. Values at or below zero return the smallest
	///   outcome; at or above one, the largest.
	/// - Returns: The quantile, monotone non-decreasing in `p`.
	public func quantile(_ p: Double) -> Int {
		guard let first = values.first, let last = values.last else { return 0 }
		guard p > 0 else { return first }
		guard p < 1 else { return last }
		for (index, probability) in cumulative.enumerated() where probability >= p {
			return values[index]
		}
		return last
	}

	/// The mean, `Σ value·P(value)`.
	public var mean: Double {
		var total = 0.0
		for value in values {
			let probability: Double = pmf(value)
			total += Double(value) * probability
		}
		return total
	}
}
