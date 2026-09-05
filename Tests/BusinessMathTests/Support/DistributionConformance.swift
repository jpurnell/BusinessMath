//
//  DistributionConformance.swift
//  BusinessMathTests
//
//  The shared battery every ContinuousDistribution is checked with. Written once so
//  that 33 distributions are verified the same way rather than 33 ways.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

// MARK: - Kolmogorov–Smirnov

/// The Kolmogorov–Smirnov statistic of a seeded sample against the distribution's own CDF.
///
/// `D = sup |F_n(x) − F(x)|`, computed exactly from the sorted sample rather than on
/// a grid. Both one-sided gaps are taken at each order statistic, because the
/// empirical CDF is a step function and the supremum can fall on either side of a step.
///
/// **Assert the statistic, never an individual draw.** A specific draw pins an
/// implementation detail of the sampler; the statistic tests the only thing that
/// actually matters, which is that the samples follow the stated law. A sampler
/// rewritten from rejection to inverse transform should keep this test green and
/// would break any assertion about a particular value.
///
/// - Parameters:
///   - distribution: The distribution to sample and to test against.
///   - seed: Fixed, so a failure is reproducible.
///   - count: Sample size. Read the result against
///     ``kolmogorovSmirnovCriticalValue(count:significance:)``.
/// - Returns: The KS statistic.
func kolmogorovSmirnovStatistic<D: ContinuousDistribution>(
	_ distribution: D,
	seed: UInt64,
	count: Int
) -> Double where D.T == Double {
	var generator = Xoshiro256StarStar(seed: seed)
	var sample = (0..<count).map { _ in distribution.next(using: &generator) }
	sample.sort()

	let n = Double(count)
	var supremum = 0.0
	for (index, value) in sample.enumerated() {
		let theoretical = distribution.cdf(value)
		let below = Double(index) / n
		let above = Double(index + 1) / n
		supremum = Swift.max(supremum, abs(theoretical - below))
		supremum = Swift.max(supremum, abs(above - theoretical))
	}
	return supremum
}

/// The asymptotic critical value of the Kolmogorov–Smirnov statistic.
///
/// Derived, not quoted. The tables give 1.63 for the 1% level and it would be shorter
/// to write that down, but a bare 1.63 is a number no reader can check and no reader
/// can adjust — asking for a 0.1% test would mean finding another table.
///
/// Kolmogorov's limiting distribution of `√n·D` is
///
/// ```
/// Q(λ) = 2 · Σ_{k≥1} (−1)^(k−1) · exp(−2k²λ²)
/// ```
///
/// so the critical value is the λ at which `Q(λ)` equals the significance level,
/// divided by `√n`. The series alternates and its terms fall off as `exp(−2k²λ²)`, so
/// a handful of terms is exact to machine precision for any λ worth testing, and `Q`
/// is monotone decreasing — which makes bisection sufficient and certain.
///
/// - Parameters:
///   - count: The sample size.
///   - significance: The test level. Defaults to 1%.
/// - Returns: The value of `D` above which the sample is rejected.
func kolmogorovSmirnovCriticalValue(count: Int, significance: Double = 0.01) -> Double {
	/// Q(λ), the probability that √n·D exceeds λ in the limit.
	func exceedanceProbability(_ lambda: Double) -> Double {
		guard lambda > 0 else { return 1 }
		var total = 0.0
		var k = 1
		while k <= 100 {
			let exponent = -2 * Double(k * k) * lambda * lambda
			let term = Double.exp(exponent)
			total += (k % 2 == 1 ? term : -term)
			// The next term is smaller by at least exp(-2λ²); once one is negligible
			// against the running total, every later one is too.
			if term < Double.ulpOfOne * Swift.max(total, Double.ulpOfOne) { break }
			k += 1
		}
		return 2 * total
	}

	// Q is monotone decreasing from 1 at λ = 0. Bracket, then bisect to full precision.
	var low = 0.0
	var high = 1.0
	while exceedanceProbability(high) > significance, high < 100 { high *= 2 }

	for _ in 0..<bisectionStepsToFullPrecision(of: Double.self) {
		let middle = low + (high - low) / 2
		if middle <= low || middle >= high { break }
		if exceedanceProbability(middle) > significance { low = middle } else { high = middle }
	}

	let lambda = low + (high - low) / 2
	return lambda / Double(count).squareRoot()
}

/// The critical value of a χ² statistic, derived from the gamma quantile.
///
/// χ²(ν) is Gamma(shape ν/2, scale 2), so its upper-tail critical value is
/// `2·P⁻¹(1 − α, ν/2)` — the same inverse incomplete gamma the library ships, which is
/// itself checked against SciPy in `SpecialFunctionsTests`. Nothing is quoted from a
/// table, and changing the level is a parameter rather than a lookup.
///
/// - Parameters:
///   - degreesOfFreedom: The statistic's degrees of freedom.
///   - significance: The test level. Defaults to 1%.
/// - Returns: The value above which the sample is rejected.
func chiSquareCriticalValue(degreesOfFreedom: Int, significance: Double = 0.01) throws -> Double {
	let shape = Double(degreesOfFreedom) / 2
	let unitScale = try inverseRegularizedLowerIncompleteGamma(p: 1 - significance, a: shape)
	return 2 * unitScale
}

// MARK: - The battery

/// Runs the standard conformance battery against a ``ContinuousDistribution``.
///
/// Four properties, each catching a distinct class of error:
///
/// | Check | Catches |
/// |---|---|
/// | Round trip | a quantile that inverts a *different* CDF — the classic parameterisation slip |
/// | Monotonicity | a branch taken in the wrong order, or a sign error in one tail |
/// | Endpoint safety | a quantile that returns NaN rather than a finite value or a documented infinity |
/// | KS statistic | a sampler that draws from something other than the stated law |
///
/// Reference-value comparison is deliberately *not* here. That needs a fixture and
/// belongs in the distribution's own test file, where the SciPy parameterisation
/// conversion can be read next to the assertion.
///
/// - Parameters:
///   - distribution: The distribution under test.
///   - name: Used in failure messages.
///   - probabilities: Where to test the round trip. Should include both tails.
///   - roundTripTolerance: Relative tolerance for `quantile(cdf(x)) == x`. Relax it
///     for a root-found quantile, and say why at the call site.
///   - samples: KS sample size.
///   - seed: KS seed.
@discardableResult
func assertConformance<D: ContinuousDistribution>(
	_ distribution: D,
	name: String,
	probabilities: [Double] = [1e-8, 1e-4, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1 - 1e-4, 1 - 1e-8],
	roundTripTolerance: Double = 1e-9,
	samples: Int = 20_000,
	seed: UInt64 = 20_260_904,
	sourceLocation: SourceLocation = #_sourceLocation
) -> ConformanceReport where D.T == Double {

	// 1. Round trip.
	for p in probabilities {
		let x = distribution.quantile(p)
		#expect(x.isFinite, "\(name): quantile(\(p)) is \(x)", sourceLocation: sourceLocation)
		guard x.isFinite else { continue }

		let back = distribution.cdf(x)
		let scale = Swift.max(abs(p), 1e-12)

		// The floor is the conditioning of the round trip, not slack. Moving the
		// returned quantile by a single ulp moves the CDF by this much, so no
		// implementation can close the loop tighter — and for a support that sits
		// away from the origin, one ulp of x can be large relative to a tail
		// probability. A Uniform on [−3, 7] at p = 1e-8 returns x ≈ −2.9999999,
		// where ulp(x)/span is already 4e-17.
		let ulpSensitivity = abs(distribution.cdf(x.nextUp) - distribution.cdf(x.nextDown))
		let allowed = Swift.max(roundTripTolerance * scale, 4 * ulpSensitivity)

		#expect(abs(back - p) < allowed,
			"\(name): cdf(quantile(\(p))) = \(back), off by \(abs(back - p)) against an allowance of \(allowed)",
			sourceLocation: sourceLocation)
	}

	// 2. Monotonicity of the quantile, and of the CDF at the points it maps to.
	var previousX = -Double.infinity
	var previousP = -Double.infinity
	for p in probabilities.sorted() {
		let x = distribution.quantile(p)
		guard x.isFinite else { continue }
		#expect(x >= previousX,
			"\(name): quantile decreased at p = \(p): \(x) after \(previousX)",
			sourceLocation: sourceLocation)

		let cumulative = distribution.cdf(x)
		#expect(cumulative >= previousP - 1e-12,
			"\(name): cdf decreased at x = \(x)", sourceLocation: sourceLocation)
		#expect(cumulative >= 0 && cumulative <= 1,
			"\(name): cdf(\(x)) = \(cumulative) is not a probability",
			sourceLocation: sourceLocation)
		previousX = x
		previousP = cumulative
	}

	// 3. Endpoint safety. An infinity here is a legitimate answer for an unbounded
	//    support; a NaN never is, because it propagates silently.
	for p in [1e-15, 1 - 1e-15] {
		let x = distribution.quantile(p)
		#expect(!x.isNaN, "\(name): quantile(\(p)) is NaN", sourceLocation: sourceLocation)
	}

	// 4. The sampler follows the law — the statistic, never a draw.
	let statistic = kolmogorovSmirnovStatistic(distribution, seed: seed, count: samples)
	let critical = kolmogorovSmirnovCriticalValue(count: samples)

	return ConformanceReport(name: name, kolmogorovSmirnov: statistic, criticalValue: critical)
}

/// What ``assertConformance(_:name:probabilities:roundTripTolerance:samples:seed:sourceLocation:)``
/// found, returned so the calling test can state its own expectation rather than
/// delegating every assertion out of its body.
struct ConformanceReport: Sendable {
	let name: String
	let kolmogorovSmirnov: Double
	let criticalValue: Double

	/// Whether the sampled distribution matched its own CDF.
	var samplerMatchesCDF: Bool { kolmogorovSmirnov < criticalValue }

	var description: String {
		"\(name): KS \(kolmogorovSmirnov) against a 1% critical value of \(criticalValue)"
	}
}

// MARK: - Goodness of fit, for the discrete side

/// Pearson's χ² statistic for a seeded sample against a ``DiscreteDistribution``'s pmf.
///
/// The discrete analogue of ``kolmogorovSmirnovStatistic(_:seed:count:)``, and it
/// exists for the same reason: **assert the statistic, never a cell**. A per-cell
/// tolerance has to be picked by hand, and a hand-picked bound is either so loose it
/// catches nothing or so tight it fails on an unlucky seed — a Geometric(0.3) sample
/// of 60,000 puts the k = 2 cell 3.7σ out often enough to matter. One statistic with
/// a published critical value replaces that guesswork.
///
/// Outcomes at or above `cells` are pooled into a final bucket, so the returned
/// statistic covers the whole support and the degrees of freedom are `cells - 1`.
///
/// - Parameters:
///   - distribution: The distribution to sample and to test against.
///   - support: The outcomes to give their own cell. Everything else is pooled.
///   - seed: Fixed, so a failure is reproducible.
///   - count: Sample size.
/// - Returns: The χ² statistic, and the degrees of freedom to read it against.
func chiSquareGoodnessOfFit<D: DiscreteDistribution>(
	_ distribution: D,
	support: [Int],
	seed: UInt64,
	count: Int
) -> (statistic: Double, degreesOfFreedom: Int) where D.T == Double {
	var generator = Xoshiro256StarStar(seed: seed)
	var observed = [Int: Int]()
	var pooledObserved = 0

	let cells = Set(support)
	for _ in 0..<count {
		let outcome = Int(distribution.next(using: &generator))
		if cells.contains(outcome) {
			observed[outcome, default: 0] += 1
		} else {
			pooledObserved += 1
		}
	}

	var statistic = 0.0
	var pooledExpected = 1.0
	for outcome in support {
		let expected = distribution.pmf(outcome) * Double(count)
		pooledExpected -= distribution.pmf(outcome)
		guard expected > 0 else { continue }
		let residual = Double(observed[outcome, default: 0]) - expected
		statistic += residual * residual / expected
	}

	let pooled = pooledExpected * Double(count)
	if pooled > 0 {
		let residual = Double(pooledObserved) - pooled
		statistic += residual * residual / pooled
	}

	return (statistic, support.count)
}
