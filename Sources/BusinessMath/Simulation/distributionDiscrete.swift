//
//  distributionDiscrete.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A distribution over an explicit list of values, each with its own probability.
///
/// Binds Risk Solver's `PsiDiscrete({x₁..xₙ}, {p₁..pₙ})`, which is how a spreadsheet
/// states a distribution it has no name for: a scenario table, a fitted empirical
/// distribution, a set of expert judgements.
///
/// ```swift
/// if let scenario = DistributionDiscrete(values: [0.9, 1.0, 1.4],
///                                        weights: [0.25, 0.5, 0.25]) {
///     var rng = DeterministicRNG(seed: 42)
///     let multiplier = scenario.next(using: &rng)   // one of 0.9, 1.0 or 1.4
///     print(multiplier)
/// }
/// ```
///
/// ## Indices, not values, in the protocol methods
///
/// ``DiscreteDistribution`` describes outcomes as `Int`, which fits a Poisson count or
/// a number of successes but not an arbitrary list of `Double`s. So ``pmf(_:)``,
/// ``cdf(_:)`` and ``quantile(_:)`` here take and return **positions in `values`**,
/// while ``next(using:)`` returns the **value itself**, which is what a caller drawing
/// from the distribution wants. ``valueAt(_:)`` converts when you need it explicitly.
///
/// ## Two algorithms, deliberately
///
/// ``next(using:)`` draws through an alias table in O(1). ``quantile(_:)`` inverts the
/// cumulative sum in O(n) and stays **monotone**.
///
/// They are not interchangeable, and the difference is the reason for both. An alias
/// table is not monotone in its uniform: it partitions [0,1) into columns and then
/// chooses within a column, so nearby uniforms can land on distant outcomes. Under a
/// Latin hypercube or Sobol sequence that destroys the equidistribution the sequence
/// exists to provide — you would get the right distribution with none of the variance
/// reduction, and nothing would report the loss. So the alias table is confined to
/// ``next(using:)``, where speed is free and no such structure is at stake, and
/// quasi-random sampling goes through ``quantile(_:)``, which is monotone.
///
/// - SeeAlso: ``AliasTable``, ``meanDiscrete(_:)``, ``varianceDiscrete(_:)``
public struct DistributionDiscrete: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The outcomes, in the order supplied.
	public let values: [Double]

	/// The probability of each outcome, normalised to sum to one.
	public let probabilities: [Double]

	/// Running sums of ``probabilities``, so ``cdf(_:)`` and ``quantile(_:)`` need not
	/// re-add the prefix on every call. The last entry is exactly `1`.
	private let cumulative: [Double]

	/// The O(1) sampler backing ``next(using:)``. Never used by ``quantile(_:)`` — see
	/// the note above on monotonicity.
	private let alias: AliasTable

	/// Creates a discrete distribution over `values`, weighted by `weights`.
	///
	/// - Parameters:
	///   - values: The outcomes. Must be non-empty and all finite.
	///   - weights: A weight per outcome, in the same order. Need **not** sum to one —
	///     they are normalised — but each must be finite and non-negative, and their
	///     total must be positive.
	/// - Returns: `nil` if the two arrays differ in length, if either is empty, if any
	///   weight is negative or non-finite, if any value is non-finite, or if the
	///   weights sum to zero. Each of those describes no distribution at all, so the
	///   type refuses to exist rather than inventing an interpretation.
	public init?(values: [Double], weights: [Double]) {
		guard !values.isEmpty, values.count == weights.count else { return nil }
		guard values.allSatisfy({ $0.isFinite }) else { return nil }
		guard weights.allSatisfy({ $0 >= 0 && $0.isFinite }) else { return nil }

		let total = weights.reduce(0, +)
		guard total > 0, total.isFinite else { return nil }

		guard let table = AliasTable(weights: weights) else { return nil }

		self.values = values
		self.alias = table
		let normalised = weights.map { $0 / total }
		self.probabilities = normalised

		var running = 0.0
		var sums: [Double] = []
		sums.reserveCapacity(normalised.count)
		for p in normalised {
			running += p
			sums.append(running)
		}
		// Pin the last entry. Floating-point addition of the normalised weights lands
		// a few ulps either side of one, and `quantile` must not be able to fall off
		// the end for a uniform arbitrarily close to 1.
		sums[sums.count - 1] = 1.0
		self.cumulative = sums
	}

	/// The number of distinct outcomes.
	public var outcomeCount: Int { values.count }

	/// The outcome at `index`, or `nil` if the index is outside the support.
	public func valueAt(_ index: Int) -> Double? {
		guard index >= 0, index < values.count else { return nil }
		return values[index]
	}

	/// The probability of the outcome at `index`, zero outside the support.
	///
	/// - Parameter k: A **position in ``values``**, not a value. See the note on the
	///   type about why the protocol's `Int` means an index here.
	public func pmf(_ k: Int) -> Double {
		guard k >= 0, k < probabilities.count else { return 0 }
		return probabilities[k]
	}

	/// The probability that the drawn outcome is at a position at or before `k`.
	///
	/// - Parameter k: A **position in ``values``**, not a value.
	public func cdf(_ k: Int) -> Double {
		guard k >= 0 else { return 0 }
		guard k < cumulative.count else { return 1 }
		return cumulative[k]
	}

	/// The smallest index whose cumulative probability reaches `p`.
	///
	/// Monotone in `p`, which is what lets Latin hypercube and Sobol sampling invert
	/// through it. Deliberately does **not** use the alias table.
	///
	/// - Parameter p: A probability. At or below zero gives the first index; at or
	///   above one gives the last.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 0 }
		for (index, bound) in cumulative.enumerated() where p <= bound {
			return index
		}
		return cumulative.count - 1
	}

	/// Draws an outcome, in O(1), through the alias table.
	///
	/// Returns the **value**, not its index. Overrides the protocol's inverse-transform
	/// default, which would return the index cast to `Double`.
	///
	/// - Parameter generator: The random source; seed it for a reproducible stream.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		let index = alias.next(using: &generator)
		return values[index]
	}

	/// Draws an outcome from the system random source.
	///
	/// Follows the same law as ``next(using:)`` and differs only in where the
	/// randomness comes from. Prefer the seeded form wherever the result must be
	/// reproducible.
	public func next() -> Double {
		var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; use next(using:) for reproducibility
		return next(using: &generator)
	}
}
