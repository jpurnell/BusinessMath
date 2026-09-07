//
//  MyersonDistributionTests.swift
//  BusinessMath
//
//  The Myerson distribution certifies itself.
//
//  It exists to turn a three-point elicitation — low, most likely, high, at a stated
//  confidence — into something samplable, and the family is constructed so those
//  three numbers come back *exactly*. That is an oracle needing no reference
//  implementation: §2.2 of the coverage proposal, where the formula is the reference.
//
//  The rest is the ordinary distribution contract — a CDF in [0, 1] that never
//  decreases, a quantile monotone in `p`, and the two inverse to each other — plus
//  the one property specific to this family: a symmetric elicitation must produce a
//  normal distribution, because that is the limit of the general formula rather than
//  a case anyone chose.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Myerson distribution")
struct MyersonDistributionTests {

	/// Elicitations spanning the shapes a three-point estimate can take.
	private static let cases: [(name: String, low: Double, mode: Double, high: Double, probability: Double)] = [
		("rightSkewed", 80, 100, 150, 0.90),
		("stronglyRightSkewed", 10, 12, 60, 0.90),
		("leftSkewed", 20, 90, 100, 0.90),
		("symmetric", 50, 100, 150, 0.90),
		("tightConfidence", 80, 100, 150, 0.98),
		("looseConfidence", 80, 100, 150, 0.50),
		("negativeRange", -200, -50, -10, 0.90),
		("straddlingZero", -30, 5, 120, 0.90),
	]

	private static func build(_ entry: (name: String, low: Double, mode: Double, high: Double, probability: Double)) -> DistributionMyerson? {
		DistributionMyerson(low: entry.low, mode: entry.mode, high: entry.high, probability: entry.probability)
	}

	// MARK: - The property the family exists for

	@Test("The three elicited points come back exactly")
	func elicitedPointsAreReproduced() throws {
		for entry in Self.cases {
			let distribution = try #require(Self.build(entry), "\(entry.name) failed to build")
			let tail: Double = (1 - entry.probability) / 2

			// Not fitted — reproduced. A moment-matched alternative would be close;
			// this is exact, and that exactness is the reason to choose the family.
			let lowScale = Swift.max(1.0, abs(entry.low))
			#expect(abs(distribution.quantile(tail) - entry.low) < 1e-9 * lowScale,
					"\(entry.name): quantile(\(tail)) = \(distribution.quantile(tail)), elicited low \(entry.low)")

			let modeScale = Swift.max(1.0, abs(entry.mode))
			#expect(abs(distribution.quantile(0.5) - entry.mode) < 1e-9 * modeScale,
					"\(entry.name): the mode is not the median — quantile(0.5) = \(distribution.quantile(0.5))")

			let highScale = Swift.max(1.0, abs(entry.high))
			#expect(abs(distribution.quantile(1 - tail) - entry.high) < 1e-9 * highScale,
					"\(entry.name): quantile(\(1 - tail)) = \(distribution.quantile(1 - tail)), elicited high \(entry.high)")
		}
	}

	@Test("The stated confidence is the probability of landing between low and high")
	func confidenceMeansWhatItSays() throws {
		for entry in Self.cases {
			let distribution = try #require(Self.build(entry))
			// The other half of the elicitation: not just that the endpoints are
			// returned, but that the mass between them is the confidence asked for.
			let inside: Double = distribution.cdf(entry.high) - distribution.cdf(entry.low)
			#expect(abs(inside - entry.probability) < 1e-9,
					"\(entry.name): \(inside) of the mass lies between low and high, not \(entry.probability)")
		}
	}

	// MARK: - The symmetric limit

	@Test("A symmetric elicitation is exactly normal")
	func symmetricElicitationIsNormal() throws {
		// Equal arms make the general formula 0/0, and its limit is a normal with
		// standard deviation (high − low)/(2z). Checked against the package's own
		// normal rather than asserted, so the limit is verified and not merely
		// implemented.
		let low = 50.0, mode = 100.0, high = 150.0, probability = 0.90
        let distribution = try #require(DistributionMyerson(low: low, mode: mode, high: high, probability: probability))

		let z: Double = inverseNormalCDF(p: 1 - (1 - probability) / 2, mean: 0, stdDev: 1)
		let sigma: Double = (high - low) / (2 * z)

		for p in [0.01, 0.1, 0.25, 0.5, 0.75, 0.9, 0.99] {
			let expected: Double = inverseNormalCDF(p: p, mean: mode, stdDev: sigma)
			#expect(abs(distribution.quantile(p) - expected) < 1e-9,
					"at p=\(p): Myerson \(distribution.quantile(p)), normal \(expected)")
		}
		for x in [40.0, 75.0, 100.0, 125.0, 175.0] {
			let expected: Double = normalCDF(x: x, mean: mode, stdDev: sigma)
			#expect(abs(distribution.cdf(x) - expected) < 1e-9,
					"at x=\(x): Myerson \(distribution.cdf(x)), normal \(expected)")
		}
	}

	@Test("Nearly-symmetric elicitations approach the symmetric one continuously")
	func theSymmetricBranchIsALimitNotAJump() throws {
		// The implementation switches branches at |b − 1| < 1e-9. If that switch were
		// a discontinuity the distribution would jump for an arbitrarily small change
		// in the elicitation, which would be a defect the exactness tests cannot see.
		let mode = 100.0
		let reference = try #require(DistributionMyerson(low: 50, mode: mode, high: 150))
		for nudge in [1e-6, 1e-7, 1e-8] {
			let skewed = try #require(DistributionMyerson(low: 50, mode: mode, high: 150 + nudge))
			for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
				let gap = abs(skewed.quantile(p) - reference.quantile(p))
				#expect(gap < 1e-3,
						"a \(nudge) change in `high` moved quantile(\(p)) by \(gap) — the branch switch is a jump")
			}
		}
	}

	// MARK: - The distribution contract

	@Test("The quantile is monotone and the CDF inverts it")
	func quantileAndCDFAreInverse() throws {
		for entry in Self.cases {
			let distribution = try #require(Self.build(entry))
			var previous = -Double.infinity
			for step in 1..<200 {
				let p: Double = Double(step) / 200
				let x = distribution.quantile(p)
				// Monotone in p — required outright by the protocol, because
				// quasi-random sampling calls `quantile` directly.
				#expect(x >= previous, "\(entry.name): quantile fell from \(previous) to \(x) at p=\(p)")
				previous = x
				#expect(x.isFinite, "\(entry.name): quantile(\(p)) is not finite")

				// Round trip. The tolerance is on the probability rather than the
				// value because the two are related by the density, which is tiny in
				// the tails — an exact probability there can correspond to a wide
				// range of x.
				#expect(abs(distribution.cdf(x) - p) < 1e-9,
						"\(entry.name): cdf(quantile(\(p))) = \(distribution.cdf(x))")
			}
		}
	}

	@Test("The CDF is bounded, non-decreasing, and defined outside the support")
	func cdfIsWellFormed() throws {
		for entry in Self.cases {
			let distribution = try #require(Self.build(entry))
			let span: Double = entry.high - entry.low
			var previous = -Double.infinity
			for step in -50...150 {
				let x: Double = entry.low + span * Double(step) / 50
				let value = distribution.cdf(x)
				#expect(value >= 0 && value <= 1, "\(entry.name): cdf(\(x)) = \(value)")
				#expect(value >= previous - 1e-12,
						"\(entry.name): cdf fell from \(previous) to \(value) at x=\(x)")
				previous = value
			}
			// Far outside, in both directions, including the bounded end where the
			// solve has no answer and 0 or 1 is the only correct reply.
			#expect(distribution.cdf(-1e12) >= 0)
			#expect(distribution.cdf(1e12) <= 1)
			#expect(distribution.cdf(.infinity) == 1)
			#expect(distribution.cdf(-.infinity) == 0)
		}
	}

	@Test("Sampling reproduces the elicited quantiles")
	func samplingFollowsTheDistribution() throws {
		let distribution = try #require(DistributionMyerson(low: 80, mode: 100, high: 150))
		var generator = DeterministicRNG(seed: 45_101)
		var draws: [Double] = []
		draws.reserveCapacity(200_000)
		for _ in 0..<200_000 { draws.append(distribution.next(using: &generator)) }
		draws.sort()

		// The sampler is inverse transform over `quantile`, so this checks the
		// plumbing rather than the mathematics — but a sampler wired to the wrong
		// distribution is exactly the failure a formula test cannot see.
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let empirical = quantile(sorted: draws, p: p)
			let exact = distribution.quantile(p)
			let scale = Swift.max(1.0, abs(exact))
			#expect(abs(empirical - exact) < 0.02 * scale,
					"at p=\(p): sampled \(empirical), exact \(exact)")
		}
	}

	// MARK: - Refusals

	@Test("An elicitation that is not a three-point estimate is refused")
	func invalidElicitationsAreRefused() {
		// A collapsed arm says the median is also a confidence bound, which this
		// family cannot represent. Refused rather than widened, because inventing a
		// width answers a question nobody asked.
		#expect(DistributionMyerson(low: 100, mode: 100, high: 150) == nil, "low == mode accepted")
		#expect(DistributionMyerson(low: 80, mode: 150, high: 150) == nil, "mode == high accepted")
		#expect(DistributionMyerson(low: 150, mode: 100, high: 80) == nil, "reversed order accepted")
		#expect(DistributionMyerson(low: 80, mode: 100, high: 150, probability: 0) == nil)
		#expect(DistributionMyerson(low: 80, mode: 100, high: 150, probability: 1) == nil)
		#expect(DistributionMyerson(low: 80, mode: 100, high: 150, probability: 1.5) == nil)
		#expect(DistributionMyerson(low: .nan, mode: 100, high: 150) == nil)
		#expect(DistributionMyerson(low: 80, mode: 100, high: .infinity) == nil)
	}
}
