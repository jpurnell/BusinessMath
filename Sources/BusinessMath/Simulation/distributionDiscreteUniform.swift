//
//  distributionDiscreteUniform.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A uniform distribution over an explicit list of values.
///
/// Binds Risk Solver's `PsiDisUniform({x₁..xₙ})`.
///
/// ```swift
/// if let die = DistributionDiscreteUniform(values: [1, 2, 3, 4, 5, 6]) {
///     var rng = DeterministicRNG(seed: 42)
///     print(die.next(using: &rng))
/// }
/// ```
///
/// ## Uniform over the list, not over the distinct values
///
/// Duplicates are kept. `[1, 1, 2, 4]` draws `1` half the time, not a quarter of the
/// time, because repeating an entry is how a spreadsheet states a heavier weight
/// without leaving the uniform form. Collapsing duplicates would silently change the
/// distribution into a different one that still looked plausible — the failure mode
/// this library's fail-silent rule exists to prevent.
///
/// Where weights are stated explicitly rather than by repetition, use
/// ``DistributionDiscrete``, which this type otherwise mirrors: ``pmf(_:)``,
/// ``cdf(_:)`` and ``quantile(_:)`` address **positions** in `values`, while
/// ``next(using:)`` returns the value.
///
/// - SeeAlso: ``DistributionDiscrete``
public struct DistributionDiscreteUniform: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The outcomes, in the order supplied, duplicates included.
	public let values: [Double]

	/// Creates a uniform distribution over `values`.
	///
	/// - Parameter values: The outcomes. Must be non-empty and all finite.
	/// - Returns: `nil` if the list is empty or holds a non-finite value.
	public init?(values: [Double]) {
		guard !values.isEmpty else { return nil }
		guard values.allSatisfy({ $0.isFinite }) else { return nil }
		self.values = values
		// Non-zero because the list is non-empty, guarded on the line above.
		self.inverseCount = 1 / Double(values.count)
		self.count = Double(values.count)
	}

	/// The number of entries as a `Double`, formed once.
	private let count: Double

	/// `1/count`, which is the mass on each entry. Formed in the initialiser, beside
	/// the guard that proves the list non-empty.
	private let inverseCount: Double

	/// The number of entries, counting duplicates separately.
	public var outcomeCount: Int { values.count }

	/// The outcome at `index`, or `nil` outside the support.
	public func valueAt(_ index: Int) -> Double? {
		guard index >= 0, index < values.count else { return nil }
		return values[index]
	}

	/// `1/n` inside the support, zero outside it.
	///
	/// - Parameter k: A **position in ``values``**, not a value.
	public func pmf(_ k: Int) -> Double {
		guard k >= 0, k < values.count else { return 0 }
		return inverseCount
	}

	/// The probability that the drawn position is at or before `k`.
	///
	/// - Parameter k: A **position in ``values``**, not a value.
	public func cdf(_ k: Int) -> Double {
		guard k >= 0 else { return 0 }
		guard k < values.count - 1 else { return 1 }
		let reached: Double = Double(k + 1)
		return reached * inverseCount
	}

	/// The smallest position whose cumulative probability reaches `p`.
	///
	/// Monotone in `p`, so quasi-random sampling can invert through it.
	///
	/// - Parameter p: A probability. At or below zero gives the first position; at or
	///   above one gives the last.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 0 }
		guard p < 1 else { return values.count - 1 }
		let scaled: Double = p * count
		let index = Int(scaled.rounded(.up)) - 1
		return Swift.min(Swift.max(index, 0), values.count - 1)
	}

	/// Draws a value uniformly from the list.
	///
	/// Returns the **value**, not its position. Overrides the protocol's default, which
	/// would return the position cast to `Double`.
	///
	/// - Parameter generator: The random source; seed it for a reproducible stream.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		let uniform = Double.openUnitRandom(using: &generator)
		return values[quantile(uniform)]
	}

	/// Draws a value from the system random source.
	///
	/// Follows the same law as ``next(using:)``; prefer the seeded form where the
	/// result must be reproducible.
	public func next() -> Double {
		var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; use next(using:) for reproducibility
		return next(using: &generator)
	}
}
