//
//  DistributionHyperGeometric.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A hypergeometric distribution: the number of successes in `draws` items taken
/// **without replacement** from a finite population.
///
/// Sampling without replacement is the whole point. Each draw changes what remains, so
/// unlike a binomial the trials are not independent, and the distinction matters
/// whenever the sample is a material fraction of the population.
///
/// Binds Risk Solver's `PsiHyperGeo(n, D, M)`.
///
/// ```swift
/// // Ten horses, four of them diseased; draw three.
/// if let diseased = DistributionHyperGeometric(draws: 3, successes: 4, population: 10) {
///     print(diseased.pmf(2))   // 0.3 — exactly two diseased in the sample
/// }
/// ```
///
/// ## The parameterisation, and a contradiction in the reference
///
/// Frontline documents `PsiHyperGeo(n, D, M)` as
///
/// > a discrete distribution of the number of **successes** in n successive trials
/// > drawn without replacement from a finite population of size M, when it is known
/// > that there are exactly **D failures** in the population.
///
/// Those two clauses cannot both be true: the distribution counts successes, and then
/// `D` is called the count of failures. **This type reads `D` as the number of
/// successes** — the marked category, the one being counted — for three reasons:
///
/// 1. The coverage work list already set this precedent for `PsiCauchy` and
///    `PsiLaplace`, where Frontline's prose likewise contradicts its signature: the
///    signature is authoritative.
/// 2. Standard notation pairs a population `M` with `D` for *defectives*, which are
///    what gets counted, not the complement.
/// 3. The row's stated reference is `scipy.stats.hypergeom`, whose corresponding
///    argument is successes-in-population. Binding to a reference and then inverting
///    one of its arguments would make every cross-check meaningless.
///
/// If Frontline's prose is ever shown to be literal rather than a slip, the correction
/// is a single substitution of `M - D` for `D` at the boundary.
///
/// ## Support
///
/// Not simply `0...draws`. At most `min(draws, successes)` successes can appear, and if
/// the population holds fewer failures than there are spare draws then some successes
/// are forced: the lower edge is `max(0, draws - (population - successes))`.
///
/// - SeeAlso: ``hypergeometric(total:r:n:x:)``
public struct DistributionHyperGeometric: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The number of items drawn, without replacement. Frontline's `n`.
	public let draws: Int

	/// The number of successes present in the population. Frontline's `D` — see the
	/// note above on why this is successes and not failures.
	public let successes: Int

	/// The size of the finite population. Frontline's `M`.
	public let population: Int

	/// The smallest number of successes that can occur.
	public let supportLowerBound: Int

	/// The largest number of successes that can occur.
	public let supportUpperBound: Int

	/// Creates a hypergeometric distribution.
	///
	/// - Parameters:
	///   - draws: Items drawn without replacement. Must be in `0...population`.
	///   - successes: Successes present in the population. Must be in `0...population`.
	///   - population: Total population size. Must be positive.
	/// - Returns: `nil` if any count is negative, if `draws` or `successes` exceeds
	///   `population`, or if the population is empty. These are contradictions rather
	///   than edge cases — you cannot draw eleven items from ten — so they are refused
	///   at construction instead of producing a distribution that quietly means
	///   something else.
	public init?(draws: Int, successes: Int, population: Int) {
		guard population > 0 else { return nil }
		guard draws >= 0, successes >= 0 else { return nil }
		guard draws <= population, successes <= population else { return nil }

		self.draws = draws
		self.successes = successes
		self.population = population

		let failures: Int = population - successes
		let forced: Int = draws - failures
		self.supportLowerBound = Swift.max(0, forced)
		self.supportUpperBound = Swift.min(draws, successes)
	}

	/// P(X = k) = C(D, k)·C(M−D, n−k) / C(M, n), zero outside the support.
	public func pmf(_ k: Int) -> Double {
		guard k >= supportLowerBound, k <= supportUpperBound else { return 0 }
		return hypergeometric(total: population, r: successes, n: draws, x: k)
	}

	/// P(X ≤ k).
	///
	/// Summed from the lower edge of the support. There is no closed form — the
	/// cumulative hypergeometric is a hypergeometric function — and the support spans
	/// at most `draws + 1` outcomes, so the sum is the direct route.
	public func cdf(_ k: Int) -> Double {
		guard k >= supportLowerBound else { return 0 }
		guard k < supportUpperBound else { return 1 }
		var total = 0.0
		for i in supportLowerBound...k { total += pmf(i) }
		return Swift.min(total, 1.0)
	}

	/// The smallest `k` for which `cdf(k) >= p`.
	///
	/// Monotone in `p`, as the protocol requires for quasi-random sampling.
	///
	/// - Parameter p: A probability. At or below zero gives the lower edge of the
	///   support; at or above one gives the upper edge.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return supportLowerBound }
		var cumulative = 0.0
		for k in supportLowerBound...supportUpperBound {
			cumulative += pmf(k)
			if cumulative >= p { return k }
		}
		return supportUpperBound
	}
}
