//
//  ReparameterisedDistributionTests.swift
//  BusinessMath
//
//  The four shallow re-parameterisations, against SciPy.
//
//  `PsiBetaGen`, `PsiBetaSubj`, `PsiErf` and `PsiPareto2` add no new mathematics —
//  each is a family that already exists, wearing different parameters. That makes the
//  reference easy and the risk specific: the danger is not that the distribution is
//  wrong but that the *translation* is, and a translation error produces a perfectly
//  well-behaved distribution that is simply not the one asked for.
//
//  So every test here checks the translated parameters against an independent
//  computation, not just that the result is a valid distribution.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Re-parameterised distributions")
struct ReparameterisedDistributionTests {

	// MARK: - PsiBetaGen

	@Test("A generalised Beta is a scaled Beta, matching SciPy")
	func generalisedBetaMatchesScipy() throws {
		// scipy.stats.beta(2, 3, loc=10, scale=20)
		let scaled = try #require(DistributionBetaGeneralised(shape1: 2, shape2: 3, min: 10, max: 30))
		#expect(abs(scaled.quantile(0.25) - 14.860441675122) < 1e-9, "q(0.25) = \(scaled.quantile(0.25))")
		#expect(abs(scaled.quantile(0.90) - 23.590788325564) < 1e-9, "q(0.90) = \(scaled.quantile(0.90))")
		#expect(abs(scaled.cdf(15) - 0.261718750000) < 1e-9, "cdf(15) = \(scaled.cdf(15))")
		// mean = min + (max − min)·α/(α+β) = 10 + 20·0.4 = 18
		#expect(abs(scaled.mean - 18) < 1e-12, "mean \(scaled.mean)")
	}

	@Test("A generalised Beta over the unit interval is the plain Beta")
	func unitIntervalIsThePlainBeta() throws {
		// The affine map is the whole of the difference, so on [0, 1] it must vanish
		// entirely — a scaling that leaves a residue would show up here and nowhere
		// else in the suite.
		let scaled = try #require(DistributionBetaGeneralised(shape1: 2.5, shape2: 1.5, min: 0, max: 1))
		let plain = DistributionBeta(alpha: 2.5, beta: 1.5)
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			#expect(abs(scaled.quantile(p) - plain.quantile(p)) < 1e-12,
					"at p=\(p): scaled \(scaled.quantile(p)), plain \(plain.quantile(p))")
		}
	}

	// MARK: - PsiBetaSubj

	@Test("A subjective Beta honours the stated mean, not a derived one")
	func subjectiveBetaHonoursItsMean() throws {
		// min 0, likely 3, mean 4, max 10 gives alpha 1.6, beta 2.4 — computed
		// independently from the closed form rather than read off the implementation.
		let subjective = try #require(DistributionBetaSubjective(min: 0, likely: 3, mean: 4, max: 10))
		#expect(abs(subjective.shape1 - 1.6) < 1e-9, "alpha \(subjective.shape1)")
		#expect(abs(subjective.shape2 - 2.4) < 1e-9, "beta \(subjective.shape2)")
		#expect(abs(subjective.quantile(0.25) - 2.234171032830) < 1e-9)
		#expect(abs(subjective.quantile(0.90) - 7.107159771878) < 1e-9)
	}

	@Test("The stated mean is the distribution's actual mean")
	func statedMeanIsTheRealMean() throws {
		// The point of the family: PERT derives its mean from the estimate, this one
		// is told. Verified by integrating the quantile rather than by re-deriving the
		// shapes, so it checks the distribution and not the algebra that built it.
		let subjective = try #require(DistributionBetaSubjective(min: 0, likely: 3, mean: 4, max: 10))
		var total = 0.0
		let steps = 20_000
		for step in 0..<steps {
			let p: Double = (Double(step) + 0.5) / Double(steps)
			total += subjective.quantile(p)
		}
		let integrated: Double = total / Double(steps)
		#expect(abs(integrated - 4) < 1e-3, "integrated mean \(integrated), stated 4")
	}

	@Test("A mean and a mode that cannot belong to one Beta are refused")
	func contradictoryEstimatesAreRefused() {
		// Not every combination describes a Beta. A mean equal to the mode makes the
		// shape formula 0/0, and a mean outside the range describes nothing at all.
		// Refused rather than clamped: the nearest Beta that does exist answers a
		// question nobody asked.
		#expect(DistributionBetaSubjective(min: 0, likely: 3, mean: 3, max: 10) == nil, "mean == mode accepted")
		#expect(DistributionBetaSubjective(min: 0, likely: 3, mean: 0, max: 10) == nil, "mean on the bound accepted")
		#expect(DistributionBetaSubjective(min: 0, likely: 3, mean: 11, max: 10) == nil, "mean outside the range accepted")
		#expect(DistributionBetaSubjective(min: 0, likely: 0, mean: 4, max: 10) == nil, "mode on the bound accepted")
	}

	// MARK: - PsiErf

	@Test("The error-function distribution is a normal with sigma = 1/(h√2)")
	func erfIsANormal() throws {
		for (h, expectedSigma) in [(0.5, 1.414213562373), (1.0, 0.707106781187), (2.5, 0.282842712475)] {
			let erf = try #require(DistributionErf(h: h))
			#expect(abs(erf.standardDeviation - expectedSigma) < 1e-9,
					"h=\(h): sigma \(erf.standardDeviation), expected \(expectedSigma)")
			// Against SciPy's norm(0, sigma).
			let normal = DistributionNormal(0, expectedSigma)
			for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
				#expect(abs(erf.quantile(p) - normal.quantile(p)) < 1e-9,
						"h=\(h) at p=\(p)")
			}
		}
	}

	@Test("h is an inverse scale: larger h is narrower")
	func hIsAnInverseScale() throws {
		// The one thing about this family that catches people out, and the reason the
		// doc comment says it twice.
		let narrow = try #require(DistributionErf(h: 5))
		let wide = try #require(DistributionErf(h: 0.2))
		#expect(narrow.standardDeviation < wide.standardDeviation,
				"h=5 gave \(narrow.standardDeviation), h=0.2 gave \(wide.standardDeviation)")
		#expect(narrow.quantile(0.9) < wide.quantile(0.9))
		#expect(DistributionErf(h: 0) == nil)
		#expect(DistributionErf(h: -1) == nil)
	}

	// MARK: - PsiPareto2

	@Test("Pareto Type II matches scipy.stats.lomax")
	func paretoTwoMatchesLomax() throws {
		let first = try #require(DistributionPareto2(scale: 1, shape: 2))
		#expect(abs(first.quantile(0.25) - 0.154700538379) < 1e-10, "q(0.25) = \(first.quantile(0.25))")
		#expect(abs(first.quantile(0.90) - 2.162277660168) < 1e-10, "q(0.90) = \(first.quantile(0.90))")
		#expect(abs(first.cdf(2) - 0.888888888889) < 1e-10, "cdf(2) = \(first.cdf(2))")

		let second = try #require(DistributionPareto2(scale: 3, shape: 1.5))
		#expect(abs(second.quantile(0.25) - 0.634241185664) < 1e-10)
		#expect(abs(second.quantile(0.90) - 10.924766500838) < 1e-9)
		#expect(abs(second.cdf(2) - 0.535241998455) < 1e-10)
	}

	@Test("Its support starts at zero, which is the point of Type II")
	func supportStartsAtZero() throws {
		// The ordinary Pareto starts at its scale. Type II starts at zero and keeps the
		// tail, which is what makes it usable for a quantity that can be arbitrarily
		// small.
		let lomax = try #require(DistributionPareto2(scale: 3, shape: 1.5))
		#expect(lomax.cdf(0) == 0)
		#expect(lomax.cdf(-1) == 0)
		#expect(lomax.quantile(1e-9) > 0, "the quantile at a tiny p is \(lomax.quantile(1e-9))")
		#expect(lomax.quantile(1e-9) < 1e-6, "the support does not reach down to zero")

		let ordinary = DistributionPareto(scale: 3, shape: 1.5)
		// The ordinary one cannot go below its scale; this one can.
		#expect(lomax.quantile(0.01) < ordinary.quantile(0.01))
	}

	@Test("Moments that do not exist are reported as nil, not as infinity")
	func nonexistentMomentsAreNil() throws {
		// An infinity propagates silently into a risk measure; a nil does not.
		let heavy = try #require(DistributionPareto2(scale: 1, shape: 0.5))
		#expect(heavy.mean == nil, "a shape below 1 reported a mean of \(String(describing: heavy.mean))")
		#expect(heavy.variance == nil)

		// Between 1 and 2 the mean exists and the variance does not — the boundary the
		// two guards straddle, so the mean is asserted to its value rather than merely
		// to being present.
		let middling = try #require(DistributionPareto2(scale: 1, shape: 1.5))
		let middlingMean = try #require(middling.mean)
		#expect(abs(middlingMean - 2) < 1e-12, "b/(q−1) = 1/0.5 = 2, got \(middlingMean)")
		#expect(middling.variance == nil, "a shape below 2 reported a variance")

		// And just above 2 the variance appears, with the value the closed form gives:
		// b²q / ((q−1)²(q−2)) = 4·3 / (4·1) = 3.
		let heavier = try #require(DistributionPareto2(scale: 2, shape: 3))
		let heavierVariance = try #require(heavier.variance)
		#expect(abs(heavierVariance - 3) < 1e-12, "variance \(heavierVariance), formula 3")

		let light = try #require(DistributionPareto2(scale: 3, shape: 1.5))
		let mean = try #require(light.mean)
		#expect(abs(mean - 6) < 1e-12, "mean \(mean)")
	}

	@Test("The tails are computed without cancellation")
	func tailsAvoidCancellation() throws {
		// `1 − (1 + x/b)^-q` and `(1 − p)^(−1/q) − 1` are both small differences of
		// numbers near one at the ends, which is where `log1p`/`expm1` earn their place.
		// A naive form returns exactly zero here; the round trip catches that.
		let lomax = try #require(DistributionPareto2(scale: 3, shape: 1.5))
		for p in [1e-12, 1e-9, 1e-6] {
			let x = lomax.quantile(p)
			#expect(x > 0, "q(\(p)) collapsed to \(x)")
			#expect(abs(lomax.cdf(x) - p) / p < 1e-6, "cdf(quantile(\(p))) = \(lomax.cdf(x))")
		}
		for x in [1e-12, 1e-9, 1e-6] {
			let p = lomax.cdf(x)
			#expect(p > 0, "cdf(\(x)) collapsed to \(p)")
		}
	}

	// MARK: - The contract, for all four

	@Test("All four are monotone and invert their own CDFs")
	func allFourSatisfyTheContract() throws {
		let pareto = try #require(DistributionPareto2(scale: 2, shape: 2.5))
		let erf = try #require(DistributionErf(h: 1.5))
		let generalised = try #require(DistributionBetaGeneralised(shape1: 2, shape2: 3, min: 10, max: 30))
		let subjective = try #require(DistributionBetaSubjective(min: 0, likely: 3, mean: 4, max: 10))

		func check(_ quantile: (Double) -> Double, _ cdf: (Double) -> Double, _ label: String) {
			var previous = -Double.infinity
			for step in 1..<200 {
				let p: Double = Double(step) / 200
				let x = quantile(p)
				#expect(x >= previous, "\(label): quantile fell from \(previous) to \(x) at p=\(p)")
				previous = x
				#expect(x.isFinite, "\(label): q(\(p)) is not finite")
				#expect(abs(cdf(x) - p) < 1e-7, "\(label): cdf(quantile(\(p))) = \(cdf(x))")
			}
		}
		check(pareto.quantile, pareto.cdf, "pareto2")
		check(erf.quantile, erf.cdf, "erf")
		check(generalised.quantile, generalised.cdf, "betaGen")
		check(subjective.quantile, subjective.cdf, "betaSubj")
	}
}
