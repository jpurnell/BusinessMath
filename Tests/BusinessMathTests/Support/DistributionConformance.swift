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
///   - count: Sample size. The 1% two-sided critical value is `1.63/√count`.
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

/// The 1% two-sided asymptotic critical value for a sample of `count`.
func kolmogorovSmirnovCriticalValue(count: Int) -> Double {
	1.63 / Double(count).squareRoot()
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
func assertConformance<D: ContinuousDistribution>(
	_ distribution: D,
	name: String,
	probabilities: [Double] = [1e-8, 1e-4, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 1 - 1e-4, 1 - 1e-8],
	roundTripTolerance: Double = 1e-9,
	samples: Int = 20_000,
	seed: UInt64 = 20_260_904,
	sourceLocation: SourceLocation = #_sourceLocation
) where D.T == Double {

	// 1. Round trip.
	for p in probabilities {
		let x = distribution.quantile(p)
		#expect(x.isFinite, "\(name): quantile(\(p)) is \(x)", sourceLocation: sourceLocation)
		guard x.isFinite else { continue }

		let back = distribution.cdf(x)
		let scale = Swift.max(abs(p), 1e-12)
		#expect(abs(back - p) / scale < roundTripTolerance,
			"\(name): cdf(quantile(\(p))) = \(back), off by \(abs(back - p))",
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
	#expect(statistic < critical,
		"\(name): KS statistic \(statistic) exceeds the 1% critical value \(critical)",
		sourceLocation: sourceLocation)
}
