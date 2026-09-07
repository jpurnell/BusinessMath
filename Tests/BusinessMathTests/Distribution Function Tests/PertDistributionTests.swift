//
//  PertDistributionTests.swift
//  BusinessMath
//
//  PERT, against SciPy and against its own algebra.
//
//  Two oracles, because they catch different things.
//
//  **SciPy.** PERT is a Beta on `[min, max]`, so `scipy.stats.beta(α, β, loc, scale)`
//  is the whole distribution once the shapes are known. Comparing quantiles against
//  it checks the scaling and the underlying Beta at once.
//
//  **The closed forms.** The shapes themselves come from a re-parameterisation, and
//  SciPy cannot check that — it would be checking my α against my α. The mean has an
//  independent expression, `(min + λ·likely + max)/(λ + 2)`, and the mode has a
//  defining property: it is where the density peaks. Both are asserted directly.
//
//  The `λ = 4` is the whole of what makes this PERT rather than an arbitrary Beta, so
//  the test that matters most is that the mean lands four-sixths of the way from the
//  midpoint toward the mode — not at the midpoint, and not at the mode.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("PERT distribution")
struct PertDistributionTests {

	// MARK: - Against SciPy

	@Test("Quantiles match a scaled Beta computed by SciPy")
	func quantilesMatchScipy() throws {
		// scipy.stats.beta(1.666666666666667, 4.333333333333335, loc=4, scale=12)
		let pert = try #require(DistributionPert(min: 4, likely: 6, max: 16))
		let reference: [(Double, Double)] = [
			(0.05, 4.5807664766),
			(0.25, 5.7260892357),
			(0.50, 7.0234477257),
			(0.75, 8.6441106691),
			(0.90, 10.2232185130),
			(0.95, 11.1517447229),
		]
		for (p, expected) in reference {
			let got = pert.quantile(p)
			#expect(abs(got - expected) < 1e-7,
					"q(\(p)) = \(got), SciPy \(expected)")
		}
		#expect(abs(pert.cdf(6) - 0.3038955735) < 1e-7, "cdf(6) = \(pert.cdf(6))")
	}

	@Test("The derived Beta shapes match the closed form")
	func shapesMatchTheClosedForm() throws {
		let pert = try #require(DistributionPert(min: 4, likely: 6, max: 16))
		#expect(abs(pert.alpha - 1.666666666666667) < 1e-12, "alpha \(pert.alpha)")
		#expect(abs(pert.betaShape - 4.333333333333335) < 1e-12, "beta \(pert.betaShape)")
	}

	// MARK: - What makes it PERT

	@Test("The mean is four-sixths of the way from the midpoint toward the mode")
	func meanIsWeightedTowardTheMode() throws {
		// This is the whole content of λ = 4, and the property that separates PERT
		// from a triangular or from any other Beta over the same range.
		for (lo, mode, hi) in [(4.0, 6.0, 16.0), (0.0, 1.0, 10.0), (-5.0, 2.0, 3.0)] {
			let pert = try #require(DistributionPert(min: lo, likely: mode, max: hi))
			let expected: Double = (lo + 4 * mode + hi) / 6
			#expect(abs(pert.mean - expected) < 1e-12,
					"(\(lo), \(mode), \(hi)): mean \(pert.mean), formula \(expected)")

			// And it is strictly between the midpoint and the mode whenever the two
			// differ — pulled toward the mode, but not all the way to it.
			let midpoint: Double = (lo + hi) / 2
			if abs(mode - midpoint) > 1e-9 {
				let lower = Swift.min(midpoint, mode), upper = Swift.max(midpoint, mode)
				#expect(pert.mean > lower && pert.mean < upper,
						"mean \(pert.mean) is not between midpoint \(midpoint) and mode \(mode)")
			}
		}
	}

	@Test("The mode is where the density actually peaks")
	func modeIsTheDensityPeak() throws {
		// The re-parameterisation exists to put the peak at the stated `likely`. Found
		// by differencing the CDF rather than asserting the algebra, so this checks the
		// distribution rather than the formula that built it.
		let pert = try #require(DistributionPert(min: 4, likely: 6, max: 16))
		let step = 0.02
		var bestX = 0.0
		var bestDensity = -Double.infinity
		var x = 4.2
		while x < 15.8 {
			let density: Double = pert.cdf(x + step) - pert.cdf(x - step)
			if density > bestDensity { bestDensity = density; bestX = x }
			x += step
		}
		#expect(abs(bestX - 6) < 0.15, "density peaks at \(bestX), mode is 6")
	}

	@Test("A symmetric estimate gives a symmetric distribution")
	func symmetricEstimateIsSymmetric() throws {
		// Where the mode is central the general shape formula is 0/0. Its limit is the
		// symmetric Beta(λ/2 + 1, λ/2 + 1) = Beta(3, 3), implemented as that limit
		// rather than special-cased — so this checks the algebra reaches the right
		// place, not that someone remembered to write an `if`.
		let pert = try #require(DistributionPert(min: 0, likely: 5, max: 10))
		#expect(abs(pert.alpha - 3) < 1e-9, "alpha \(pert.alpha)")
		#expect(abs(pert.betaShape - 3) < 1e-9, "beta \(pert.betaShape)")
		#expect(abs(pert.mean - 5) < 1e-12)
		// scipy.stats.beta(3, 3, loc=0, scale=10).ppf(0.25)
		#expect(abs(pert.quantile(0.25) - 3.5943616479) < 1e-7, "q(0.25) = \(pert.quantile(0.25))")
		// And symmetric about the mode at every probability.
		for p in [0.05, 0.1, 0.25, 0.4] {
			let below: Double = 5 - pert.quantile(p)
			let above: Double = pert.quantile(1 - p) - 5
			#expect(abs(below - above) < 1e-7, "at p=\(p): \(below) below, \(above) above")
		}
	}

	@Test("Nearly-symmetric estimates approach the symmetric one continuously")
	func theSymmetricBranchIsALimit() throws {
		// If the 0/0 branch were a discontinuity the distribution would jump for an
		// arbitrarily small change in the estimate.
		let reference = try #require(DistributionPert(min: 0, likely: 5, max: 10))
		for nudge in [1e-6, 1e-8, 1e-10] {
			let skewed = try #require(DistributionPert(min: 0, likely: 5 + nudge, max: 10))
			for p in [0.1, 0.5, 0.9] {
				let gap = abs(skewed.quantile(p) - reference.quantile(p))
				#expect(gap < 1e-3,
						"a \(nudge) change in the mode moved q(\(p)) by \(gap)")
			}
		}
	}

	// MARK: - The distribution contract

	@Test("The quantile is monotone, bounded by the estimate, and inverts the CDF")
	func quantileAndCDFAreInverse() throws {
		for (lo, mode, hi) in [(4.0, 6.0, 16.0), (0.0, 9.0, 10.0), (-20.0, -19.0, 5.0)] {
			let pert = try #require(DistributionPert(min: lo, likely: mode, max: hi))
			var previous = -Double.infinity
			for step in 1..<200 {
				let p: Double = Double(step) / 200
				let x = pert.quantile(p)
				#expect(x >= previous, "quantile fell from \(previous) to \(x) at p=\(p)")
				previous = x
				// A three-point estimate states bounds, and a draw outside them would
				// contradict the estimate that produced the distribution.
				#expect(x >= lo && x <= hi, "q(\(p)) = \(x) outside [\(lo), \(hi)]")
				#expect(abs(pert.cdf(x) - p) < 1e-6, "cdf(quantile(\(p))) = \(pert.cdf(x))")
			}
			#expect(pert.cdf(lo - 1) == 0)
			#expect(pert.cdf(hi + 1) == 1)
		}
	}

	@Test("Sampling follows the distribution")
	func samplingFollowsTheDistribution() throws {
		let pert = try #require(DistributionPert(min: 4, likely: 6, max: 16))
		var generator = DeterministicRNG(seed: 51_101)
		var draws: [Double] = []
		draws.reserveCapacity(200_000)
		for _ in 0..<200_000 { draws.append(pert.next(using: &generator)) }
		draws.sort()
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let empirical = quantile(sorted: draws, p: p)
			let exact = pert.quantile(p)
			#expect(abs(empirical - exact) < 0.02 * exact,
					"at p=\(p): sampled \(empirical), exact \(exact)")
		}
		let sampleMean: Double = draws.reduce(0, +) / Double(draws.count)
		#expect(abs(sampleMean - pert.mean) < 0.02, "sampled mean \(sampleMean), exact \(pert.mean)")
	}

	// MARK: - Refusals

	@Test("An estimate that is not three ordered points is refused")
	func invalidEstimatesAreRefused() {
		// A mode on a bound makes the Beta shapes diverge. Refused rather than nudged:
		// the distribution a nudge would produce is not the one that was asked for.
		#expect(DistributionPert(min: 4, likely: 4, max: 16) == nil, "mode on the lower bound accepted")
		#expect(DistributionPert(min: 4, likely: 16, max: 16) == nil, "mode on the upper bound accepted")
		#expect(DistributionPert(min: 16, likely: 6, max: 4) == nil, "reversed order accepted")
		#expect(DistributionPert(min: 4, likely: 6, max: 16, lambda: 0) == nil)
		#expect(DistributionPert(min: 4, likely: 6, max: 16, lambda: -1) == nil)
		#expect(DistributionPert(min: .nan, likely: 6, max: 16) == nil)
		#expect(DistributionPert(min: 4, likely: 6, max: .infinity) == nil)
	}
}
