//
//  NormalSkewTests.swift
//  BusinessMath
//
//  PsiNormalSkew.
//
//  Frontline's page gives no formula, but it does give two statements that are exact
//  rather than descriptive, and those are the oracles here:
//
//  - `a` and `b` are the −3σ and +3σ points. So at skew zero this must *be* a normal
//    with mean (a+b)/2 and standard deviation (b−a)/6 — checkable against
//    `DistributionNormal` at every quantile, with no tolerance for interpretation.
//  - The bounds are the same as Myerson's, with the tail fixed. So `Q` at the tail
//    probability must return `a` back, and at one minus it, `b`.
//
//  Neither depends on the one thing the documentation leaves open — how `c` maps to
//  the shape — so both hold whatever that mapping turns out to be. The tests that do
//  depend on it are marked, and assert the direction the page states rather than a
//  magnitude it does not.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Normal skew")
struct NormalSkewTests {

	// MARK: - What the bounds mean

	@Test("At zero skew this is exactly a normal with the bounds at three sigma")
	func zeroSkewIsNormal() throws {
		var checked = 0
		for (low, high) in [(20.0, 80.0), (-10.0, 10.0), (0.0, 1.0), (1000.0, 1250.0)] {
			let skewed = try #require(DistributionMyerson.normalSkew(lowerBound: low,
																	 upperBound: high, skew: 0))
			let centre: Double = (low + high) / 2
			let range: Double = high - low
			let sigma: Double = range / 6
			let plain = DistributionNormal(centre, sigma)
			for p in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99, 0.999] {
				let got: Double = skewed.quantile(p)
				let wanted: Double = plain.quantile(p)
				let scale: Double = Swift.max(1, Swift.abs(wanted))
				let gap: Double = Swift.abs(got - wanted)
				#expect(gap < scale * 1e-9,
						"(\(low), \(high)) at p=\(p): skew \(got), normal \(wanted)")
			}
			checked += 1
		}
		#expect(checked == 4, "only \(checked) of 4 bound pairs were checked")
	}

	@Test("The bounds come back at the tail probability, whatever the skew")
	func boundsRoundTrip() throws {
		// This holds for every skew: the median moves, the two stated points do not.
		let coverage: Double = DistributionMyerson.threeSigmaCoverage
		let tail: Double = (1 - coverage) / 2
		var checked = 0
		for skew in [-0.8, -0.4, 0.0, 0.3, 0.75] {
			let d = try #require(DistributionMyerson.normalSkew(lowerBound: 20,
															   upperBound: 80, skew: skew))
			let atLow: Double = d.quantile(tail)
			let atHigh: Double = d.quantile(1 - tail)
			#expect(Swift.abs(atLow - 20) < 1e-7, "skew \(skew): lower bound came back \(atLow)")
			#expect(Swift.abs(atHigh - 80) < 1e-7, "skew \(skew): upper bound came back \(atHigh)")
			checked += 1
		}
		#expect(checked == 5, "only \(checked) of 5 skews were checked")
	}

	@Test("The coverage is the three-sigma rule, and matches the constant Frontline quotes")
	func coverageIsThreeSigma() {
		let coverage: Double = DistributionMyerson.threeSigmaCoverage
		let tail: Double = 1 - coverage
		// Frontline states 0.002699796146511. The normal CDF gives 0.00269979606...,
		// so the two agree to nine figures and part company after. Asserting the
		// looser agreement records the discrepancy rather than hiding it; the tighter
		// assertion below pins what this library actually computes.
		#expect(Swift.abs(tail - 0.002699796146511) < 1e-9,
				"the quoted tail and the computed one differ by more than nine figures: \(tail)")
		let twoPhi: Double = 2 * normalCDF(x: -3, mean: 0, stdDev: 1)
		#expect(Swift.abs(tail - twoPhi) < 1e-15, "the tail is not 2Φ(−3): \(tail)")
	}

	@Test("The symmetric scale is a sixth of the range")
	func symmetricScale() throws {
		let sigma = try #require(DistributionMyerson.normalSkewSymmetricScale(lowerBound: 20,
																			 upperBound: 80))
		#expect(Swift.abs(sigma - 10) < 1e-12, "σ came out \(sigma)")
		#expect(DistributionMyerson.normalSkewSymmetricScale(lowerBound: 80, upperBound: 20) == nil)
	}

	// MARK: - The direction of the skew

	@Test("A positive skew leans left and a negative one leans right")
	func skewDirection() throws {
		// Frontline: "skewed either to the left with a positive skew parameter or to
		// the right with a negative skew parameter." A left-skewed distribution has
		// its long tail below, so its mean sits below its median. That is the
		// statement being checked, and it is the direction only — the page gives no
		// magnitude to check against.
		let median: Double = 50
		var checked = 0
		for skew in [0.3, 0.6, 0.85] {
			let d = try #require(DistributionMyerson.normalSkew(lowerBound: 20,
															   upperBound: 80, skew: skew))
			let centre: Double = d.quantile(0.5)
			#expect(centre > median, "skew \(skew) put the median at \(centre), not above 50")
			let average: Double = Self.meanByQuantile(d)
			#expect(average < centre,
					"skew \(skew): mean \(average) is not below median \(centre), so it is not left-skewed")
			checked += 1
		}
		for skew in [-0.3, -0.6, -0.85] {
			let d = try #require(DistributionMyerson.normalSkew(lowerBound: 20,
															   upperBound: 80, skew: skew))
			let centre: Double = d.quantile(0.5)
			#expect(centre < median, "skew \(skew) put the median at \(centre), not below 50")
			let average: Double = Self.meanByQuantile(d)
			#expect(average > centre,
					"skew \(skew): mean \(average) is not above median \(centre), so it is not right-skewed")
			checked += 1
		}
		#expect(checked == 6, "only \(checked) of 6 skews were checked")
	}

	@Test("Sign symmetry: mirroring the skew mirrors the distribution")
	func mirrorSymmetry() throws {
		// A structural consequence of placing the median linearly, and the sharpest
		// test of that reading available without a number from Frontline: reflecting
		// the skew about zero must reflect the whole distribution about the midpoint.
		let low: Double = 20
		let high: Double = 80
		let midpoint: Double = (low + high) / 2
		let positive = try #require(DistributionMyerson.normalSkew(lowerBound: low,
																   upperBound: high, skew: 0.5))
		let negative = try #require(DistributionMyerson.normalSkew(lowerBound: low,
																   upperBound: high, skew: -0.5))
		var compared = 0
		for p in [0.01, 0.1, 0.3, 0.5, 0.7, 0.9, 0.99] {
			let right: Double = positive.quantile(p)
			let left: Double = negative.quantile(1 - p)
			let mirrored: Double = 2 * midpoint - left
			#expect(Swift.abs(right - mirrored) < 1e-8,
					"at p=\(p): +0.5 gives \(right), mirrored −0.5 gives \(mirrored)")
			compared += 1
		}
		#expect(compared == 7, "only \(compared) quantiles were compared")
	}

	@Test("The quantile is monotone across the whole range")
	func quantileIsMonotone() throws {
		var checked = 0
		for skew in [-0.9, -0.5, 0.0, 0.5, 0.9] {
			let d = try #require(DistributionMyerson.normalSkew(lowerBound: 0,
															   upperBound: 100, skew: skew))
			var previous: Double = -.infinity
			for step in 1..<500 {
				let p: Double = Double(step) / 500
				let value: Double = d.quantile(p)
				#expect(value > previous, "skew \(skew): quantile fell at p=\(p)")
				previous = value
			}
			checked += 1
		}
		#expect(checked == 5, "only \(checked) of 5 skews were checked")
	}

	// MARK: - The inferred mapping, pinned in one place

	@Test("The median mapping is the documented one, at values a reference can check")
	func medianMappingIsPinned() throws {
		// The single step Frontline's page does not state, written out as a table so
		// that checking it against Risk Solver is reading one column. Each row is
		// midpoint + c·(b−a)/2.
		let cases: [(low: Double, high: Double, skew: Double, median: Double)] = [
			(0, 60, 0.0, 30),
			(0, 60, 0.5, 45),
			(0, 60, -0.5, 15),
			(0, 100, 0.25, 62.5),
			(20, 80, 0.4, 62),
			(-30, 30, -0.75, -22.5),
			(1000, 1250, 0.2, 1150),
		]
		var checked = 0
		for row in cases {
			let median = try #require(DistributionMyerson.normalSkewMedian(lowerBound: row.low,
																		   upperBound: row.high,
																		   skew: row.skew))
			#expect(Swift.abs(median - row.median) < 1e-9,
					"(\(row.low), \(row.high), \(row.skew)): median \(median), expected \(row.median)")
			// And the distribution's own median must be the same number, which is what
			// ties the mapping to the thing that gets sampled.
			let d = try #require(DistributionMyerson.normalSkew(lowerBound: row.low,
																upperBound: row.high,
																skew: row.skew))
			#expect(Swift.abs(d.quantile(0.5) - row.median) < 1e-7,
					"Q(0.5) is \(d.quantile(0.5)), not the mapped median \(row.median)")
			checked += 1
		}
		#expect(checked == cases.count, "only \(checked) of \(cases.count) rows were checked")
	}

	@Test("The mapping is what distinguishes it from a per-sigma alternative")
	func mappingIsDistinguishableFromPerSigma() throws {
		// If the skew shifted the median by c standard deviations rather than by c
		// half-ranges, PsiNormalSkew(0, 60, 0.5) would have its median at 35 rather
		// than 45. This records the discriminating case so that if a reference value
		// ever arrives, the check is one line and the consequence is one function.
		let median = try #require(DistributionMyerson.normalSkewMedian(lowerBound: 0,
																	   upperBound: 60, skew: 0.5))
		let sigma: Double = 10
		let perSigmaAlternative: Double = 30 + 0.5 * sigma
		#expect(Swift.abs(median - 45) < 1e-12, "the half-range map gives \(median)")
		#expect(Swift.abs(median - perSigmaAlternative) > 9,
				"the two readings are meant to be far apart, not \(median) versus \(perSigmaAlternative)")
	}

	@Test("The mapping refuses what the factory refuses")
	func mappingRefusals() {
		#expect(DistributionMyerson.normalSkewMedian(lowerBound: 60, upperBound: 20, skew: 0) == nil)
		#expect(DistributionMyerson.normalSkewMedian(lowerBound: 0, upperBound: 60, skew: 1) == nil)
		#expect(DistributionMyerson.normalSkewMedian(lowerBound: 0, upperBound: 60, skew: -1) == nil)
		#expect(DistributionMyerson.normalSkewMedian(lowerBound: 0, upperBound: 60, skew: .nan) == nil)
	}

	// MARK: - Refusals

	@Test("Bounds and skew outside their stated ranges are refused")
	func refusals() {
		#expect(DistributionMyerson.normalSkew(lowerBound: 80, upperBound: 20, skew: 0) == nil)
		#expect(DistributionMyerson.normalSkew(lowerBound: 50, upperBound: 50, skew: 0) == nil)
		// The range is open, and it has to be: at ±1 the median reaches a bound and
		// one arm of the Myerson collapses to zero width.
		#expect(DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: 1) == nil)
		#expect(DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: -1) == nil)
		#expect(DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: 1.5) == nil)
		#expect(DistributionMyerson.normalSkew(lowerBound: 20, upperBound: .infinity, skew: 0) == nil)
		#expect(DistributionMyerson.normalSkew(lowerBound: 20, upperBound: 80, skew: .nan) == nil)
	}

	// MARK: - Helpers

	/// The mean, by integrating the quantile over the unit interval.
	///
	/// `E[X] = ∫₀¹ Q(u) du`. Integrating in `u` keeps the range finite whatever the
	/// tails do, which matters here because the support is unbounded on both sides.
	private static func meanByQuantile(_ d: DistributionMyerson) -> Double {
		let steps = 20_000
		let h: Double = 1 / Double(steps)
		var total: Double = 0
		for index in 0..<steps {
			let half: Double = h / 2
			let offset: Double = Double(index) * h
			let u: Double = offset + half
			total += d.quantile(u)
		}
		return total * h
	}
}
