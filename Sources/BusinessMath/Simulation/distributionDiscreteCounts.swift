//
//  distributionDiscreteCounts.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Negative binomial

/// A negative binomial distribution: the number of **failures** before the `s`-th
/// success, in independent trials each succeeding with probability `p`.
///
/// The geometric distribution generalised from one success to `s` of them. It is also
/// the standard model for over-dispersed counts — data where the variance exceeds the
/// mean, which a Poisson cannot represent — because it arises as a Poisson whose own
/// rate is gamma-distributed.
///
/// Binds Risk Solver's `PsiNegBinomial(s, p)`, which is
/// `scipy.stats.nbinom(n: s, p: p)`.
///
/// ## The support starts at zero
///
/// This counts failures, so `0` is attainable — every one of the first `s` trials may
/// succeed. The convention that counts *trials* instead would start at `s`, and shifts
/// every quantile by that amount. ``DistributionGeometric`` in this package takes the
/// other convention and starts at 1, so the two are not the `s = 1` case of each other;
/// they differ by one.
///
/// ```
/// P(X = k) = C(k + s − 1, k) · p^s · (1 − p)^k
/// F(k)     = I(p; s, k + 1)        the regularized incomplete beta
/// ```
public struct DistributionNegativeBinomial: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The number of successes to wait for, Frontline's `s`. Positive.
	public let successes: Int

	/// The probability of success on each trial. In (0, 1].
	public let p: Double

	private let successesReal: Double

	/// Creates a negative binomial distribution.
	///
	/// - Parameters:
	///   - successes: How many successes to wait for. Must be positive.
	///   - p: The per-trial success probability, in (0, 1]. At `p = 1` every trial
	///     succeeds, so the distribution is degenerate at zero failures — a limiting
	///     case rather than an invalid one.
	/// - Returns: `nil` if `successes` is not positive, or `p` is outside (0, 1].
	public init?(successes: Int, p: Double) {
		guard successes > 0, p > 0, p <= 1, p.isFinite else { return nil }
		self.successes = successes
		self.p = p
		self.successesReal = Double(successes)
	}

	/// P(X = k), zero below the support.
	public func pmf(_ k: Int) -> Double {
		guard k >= 0 else { return 0 }
		// A deliberate IEEE comparison: p = 1 is the degenerate case the initialiser
		// admits, and one is exact in binary.
		if p.isEqual(to: 1) { return k == 0 ? 1 : 0 }
		// Log space throughout: the binomial coefficient overflows well before the
		// probability underflows, so forming it directly would lose ordinary cases.
		let count: Double = Double(k)
		let logCoefficient: Double = logCombination(k + successes - 1, c: k)
		let logSuccess: Double = successesReal * Foundation.log(p)
		let logFailure: Double = count * Foundation.log1p(-p)
		return Foundation.exp(logCoefficient + logSuccess + logFailure)
	}

	/// P(X ≤ k), zero below the support.
	public func cdf(_ k: Int) -> Double {
		guard k >= 0 else { return 0 }
		if p.isEqual(to: 1) { return 1 }
		// The identity that avoids summing the pmf: the cumulative negative binomial is
		// a regularized incomplete beta.
		let trials: Double = Double(k) + 1
		// `DiscreteDistribution` declares `cdf` non-throwing, so the error becomes NaN —
		// see ``DistributionErlang/quantile(_:)`` on why that rather than a substitute.
		do {
			let value = try regularizedIncompleteBeta(x: p, a: successesReal, b: trials)
			return Swift.min(value, 1)
		} catch { // logging: unreachable — p lies in (0,1] and both shapes are positive
			return .nan
		}
	}

	/// The smallest `k` for which `cdf(k) >= p`.
	///
	/// Monotone in the argument, as the protocol requires for quasi-random sampling.
	///
	/// - Parameter p: A probability. At or below zero the answer is zero.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 0 }
		if self.p.isEqual(to: 1) { return 0 }

		// Accumulate the mass rather than calling `cdf` per candidate, which would make
		// the search quadratic in the number of outcomes examined.
		var cumulative = 0.0
		var k = 0
		// The mean is s(1−p)/p and the standard deviation √(s(1−p))/p; twenty standard
		// deviations past the mean leaves nothing a Double can represent, and bounds the
		// loop for an argument at or above one.
		let mean: Double = successesReal * (1 - self.p) / self.p
		let deviation: Double = (successesReal * (1 - self.p)).squareRoot() / self.p
		let ceiling: Int = Int(mean + 20 * deviation) + 100

		while k <= ceiling {
			cumulative += pmf(k)
			if cumulative >= p { return k }
			k += 1
		}
		return ceiling
	}
}

// MARK: - Logarithmic

/// A logarithmic (log-series) distribution: a count on `1, 2, 3, …` with a long tail.
///
/// Fisher's model for species abundance, and the distribution that turns a Poisson into
/// a negative binomial when compounded. In business terms it fits counts that are
/// usually one and occasionally very large — claims per policy, purchases per customer.
///
/// Binds Risk Solver's `PsiLogarithmic(p)`, which is `scipy.stats.logser(p)`.
///
/// ## The support starts at one
///
/// There is no zero outcome — the pmf has `k` in a denominator. A binding that assumed
/// a zero-based support would be shifted by one everywhere.
///
/// ```
/// P(X = k) = −p^k / (k · ln(1 − p))      for k ≥ 1
/// ```
///
/// The name comes from the normalising constant: the series `Σ p^k/k` sums to
/// `−ln(1 − p)`, which is what makes the masses add to one.
public struct DistributionLogarithmic: DiscreteDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The shape parameter, in (0, 1). Larger values give a heavier tail.
	public let p: Double

	/// `−1/ln(1 − p)`, the normalising constant, formed once.
	private let normaliser: Double

	/// Creates a logarithmic distribution.
	///
	/// - Parameter p: The shape, strictly between zero and one. At `p = 0` all the mass
	///   would sit on one and the normaliser diverges; at `p = 1` the series does not
	///   converge. Both are refused rather than approximated.
	/// - Returns: `nil` unless `0 < p < 1`.
	public init?(p: Double) {
		guard p > 0, p < 1, p.isFinite else { return nil }
		self.p = p
		// `log1p` rather than `log(1 - p)`: for p close to one the subtraction discards
		// the digits that set the scale of the whole distribution.
		let logComplement: Double = Foundation.log1p(-p)
		// `ln(1 − p)` is strictly negative for any p in (0, 1), which the guard above
		// establishes. Taking the sign out first leaves a divisor whose positivity is
		// stated on the line before the division: −1/ln(1−p) is 1/|ln(1−p)|.
		let magnitude: Double = -logComplement
		guard magnitude > 0, magnitude.isFinite else { return nil }
		self.normaliser = 1 / magnitude
	}

	/// P(X = k), zero below the support.
	public func pmf(_ k: Int) -> Double {
		guard k >= 1 else { return 0 }
		// `k >= 1` was established above, so the divisor is at least one.
		let index: Double = Double(k)
		guard index > 0 else { return 0 }
		let power: Double = Foundation.pow(p, index)
		return normaliser * power / index
	}

	/// P(X ≤ k), zero below the support.
	///
	/// Summed, because the cumulative log-series has no elementary closed form — it is
	/// an incomplete beta in disguise, and summing the handful of terms that carry any
	/// mass is both simpler and more accurate here.
	public func cdf(_ k: Int) -> Double {
		guard k >= 1 else { return 0 }
		var total = 0.0
		for i in 1...k {
			total += pmf(i)
			if total >= 1 { return 1 }
		}
		return Swift.min(total, 1)
	}

	/// The smallest `k` for which `cdf(k) >= p`.
	///
	/// Monotone in the argument, as the protocol requires.
	///
	/// - Parameter p: A probability. At or below zero the answer is one, the lower bound
	///   of the support.
	public func quantile(_ p: Double) -> Int {
		guard p > 0 else { return 1 }
		var cumulative = 0.0
		var k = 1
		// The terms fall geometrically by a factor of `self.p`, so the accumulated mass
		// reaches one to within a Double's resolution in a bounded number of steps. The
		// bound is generous and only stops a runaway for an argument at or above one.
		while k < 100_000 {
			cumulative += pmf(k)
			if cumulative >= p { return k }
			k += 1
		}
		return k
	}
}
