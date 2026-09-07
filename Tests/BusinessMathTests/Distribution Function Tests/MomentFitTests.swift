//
//  MomentFitTests.swift
//  BusinessMath
//
//  A moment fit that does not reproduce the moments is not a moment fit.
//
//  That sentence is the whole oracle, and it needs no reference implementation. The
//  Johnson system's four parameters are in one-to-one correspondence with the first
//  four moments, so a correct fit returns them exactly — which is why the system is
//  used here rather than a Cornish–Fisher expansion, the simpler and far more common
//  choice, which matches them only asymptotically.
//
//  The moments are checked twice by different routes, because they fail differently:
//
//  - **Through the quantile**, by quadrature over `Q(Φ(z))·φ(z)`. This exercises the
//    assembled distribution — shape solve, affine map, reflection — and is accurate
//    enough to hold to a tight bound.
//  - **Through a sample**, by drawing several hundred thousand values and computing
//    the sample moments. Looser, and the only one of the two that would notice a
//    sampler wired to a different distribution from the one described.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Fitting a distribution to four moments")
struct MomentFitTests {

	private struct Target: Sendable {
		let name: String
		let mean: Double
		let standardDeviation: Double
		let skewness: Double
		let kurtosis: Double
		let expectedFamily: JohnsonFamily
	}

	/// Targets spread across the (β₁, β₂) plane so every branch is exercised, and the
	/// family each one selects is asserted rather than assumed.
	private static let targets: [Target] = [
		Target(name: "normal", mean: 0, standardDeviation: 1,
			   skewness: 0, kurtosis: 3, expectedFamily: .normal),
		Target(name: "symmetricFatTails", mean: 100, standardDeviation: 15,
			   skewness: 0, kurtosis: 6, expectedFamily: .unbounded),
		Target(name: "rightSkewedFatTails", mean: 100, standardDeviation: 25,
			   skewness: 1.2, kurtosis: 6.0, expectedFamily: .unbounded),
		Target(name: "leftSkewedFatTails", mean: 40, standardDeviation: 8,
			   skewness: -1.2, kurtosis: 6.0, expectedFamily: .unbounded),
		Target(name: "mildlySkewed", mean: 5, standardDeviation: 1.5,
			   skewness: 0.4, kurtosis: 3.6, expectedFamily: .unbounded),
		Target(name: "symmetricThinTails", mean: 0, standardDeviation: 1,
			   skewness: 0, kurtosis: 2.2, expectedFamily: .bounded),
		Target(name: "skewedThinTails", mean: 12, standardDeviation: 3,
			   skewness: 0.5, kurtosis: 2.9, expectedFamily: .bounded),
		Target(name: "negativeSkewThinTails", mean: 12, standardDeviation: 3,
			   skewness: -0.5, kurtosis: 2.9, expectedFamily: .bounded),
	]

	private static func build(_ target: Target) throws -> DistributionMomentFit {
		try DistributionMomentFit(mean: target.mean,
								  standardDeviation: target.standardDeviation,
								  skewness: target.skewness,
								  kurtosis: target.kurtosis)
	}

	/// Moments of the fitted distribution by quadrature over its own quantile.
	///
	/// `E[Xᵏ] = ∫ Q(Φ(z))ᵏ φ(z) dz`, Simpson over `z`. Goes through the public
	/// quantile, so it sees the shape solve, the affine map and the reflection —
	/// everything the internal moment formulas do not cover.
	private static func momentsByQuadrature(_ distribution: DistributionMomentFit)
	-> (mean: Double, standardDeviation: Double, skewness: Double, kurtosis: Double) {
		let lower: Double = -11
		let upper: Double = 11
		let steps = 20_000
		let h: Double = (upper - lower) / Double(steps)
		let normaliser: Double = (2 * Double.pi).squareRoot()

		var raw = [Double](repeating: 0, count: 5)
		for step in 0...steps {
			let z: Double = lower + Double(step) * h
			let density: Double = Foundation.exp(-z * z / 2) / normaliser
			let weight: Double
			if step == 0 || step == steps { weight = 1 }
			else if step % 2 == 1 { weight = 4 }
			else { weight = 2 }

			let p: Double = normalCDF(x: z, mean: 0, stdDev: 1)
			guard p > 0, p < 1 else { continue }
			let x = distribution.quantile(p)
			guard x.isFinite else { continue }
			var powered = 1.0
			for order in 1...4 {
				powered *= x
				raw[order] += weight * density * powered
			}
		}
		for order in 1...4 { raw[order] *= h / 3 }

		let m1 = raw[1], m2 = raw[2], m3 = raw[3], m4 = raw[4]
		let variance: Double = m2 - m1 * m1
		let sigma: Double = variance.squareRoot()
		let third: Double = m3 - 3 * m1 * m2 + 2 * m1 * m1 * m1
		let fourthA: Double = m4 - 4 * m1 * m3
		let fourthB: Double = 6 * m1 * m1 * m2 - 3 * m1 * m1 * m1 * m1
		let fourth: Double = fourthA + fourthB
		return (mean: m1, standardDeviation: sigma,
				skewness: third / (variance * sigma),
				kurtosis: fourth / (variance * variance))
	}

	// MARK: - The property the routine is named for

	@Test("The fitted distribution has the moments that were asked for")
	func momentsAreReproduced() throws {
		for target in Self.targets {
			let fitted = try Self.build(target)
			let got = Self.momentsByQuadrature(fitted)

			let meanScale = Swift.max(1.0, abs(target.mean))
			#expect(abs(got.mean - target.mean) < 1e-6 * meanScale,
					"\(target.name): mean \(got.mean), asked for \(target.mean)")
			#expect(abs(got.standardDeviation - target.standardDeviation) < 1e-6 * target.standardDeviation,
					"\(target.name): sd \(got.standardDeviation), asked for \(target.standardDeviation)")
			// Skewness and kurtosis come from the shape solve, whose convergence bound
			// is 1e-10 on the residual; the quadrature adds a little on top.
			#expect(abs(got.skewness - target.skewness) < 1e-5,
					"\(target.name): skewness \(got.skewness), asked for \(target.skewness)")
			#expect(abs(got.kurtosis - target.kurtosis) < 1e-4,
					"\(target.name): kurtosis \(got.kurtosis), asked for \(target.kurtosis)")
		}
	}

	@Test("The reported moments are the requested ones, not a recomputation")
	func reportedMomentsAreTheRequestedOnes() throws {
		for target in Self.targets {
			let fitted = try Self.build(target)
			#expect(fitted.mean == target.mean)
			#expect(fitted.standardDeviation == target.standardDeviation)
			#expect(fitted.skewness == target.skewness)
			#expect(fitted.kurtosis == target.kurtosis)
		}
	}

	// MARK: - Family selection

	@Test("The moments select the family, and the lognormal line is where it turns")
	func familySelectionFollowsTheMoments() throws {
		for target in Self.targets {
			let fitted = try Self.build(target)
			#expect(fitted.family == target.expectedFamily,
					"\(target.name): selected \(fitted.family), expected \(target.expectedFamily)")
		}

		// Straddling the line rather than trusting the table: at a fixed skewness, a
		// kurtosis just above the lognormal line must give the unbounded member and
		// just below must give the bounded one. That is the whole selection rule, and
		// it is checkable without knowing where the line is.
		let skew = 0.8
		let line = DistributionMomentFit.lognormalLineKurtosis(skewness: skew)
		#expect(line > skew * skew + 1, "the lognormal line is below the possible region")

		let above = try DistributionMomentFit(mean: 0, standardDeviation: 1,
											  skewness: skew, kurtosis: line + 0.25)
		#expect(above.family == .unbounded, "above the line gave \(above.family)")

		let below = try DistributionMomentFit(mean: 0, standardDeviation: 1,
											  skewness: skew, kurtosis: line - 0.25)
		#expect(below.family == .bounded, "below the line gave \(below.family)")
	}

	@Test("A lognormal's own moments select the lognormal")
	func lognormalMomentsSelectLognormal() throws {
		// Constructed from the closed forms rather than looked up: for σ² = 0.25,
		// ω = exp(σ²), skewness = (ω + 2)√(ω − 1) and kurtosis = ω⁴ + 2ω³ + 3ω² − 3.
		let sigmaSquared = 0.25
		let omega: Double = Foundation.exp(sigmaSquared)
		let skew: Double = (omega + 2) * (omega - 1).squareRoot()
		let squared: Double = omega * omega
		let kurt: Double = squared * squared + 2 * squared * omega + 3 * squared - 3

		let fitted = try DistributionMomentFit(mean: 10, standardDeviation: 3,
											   skewness: skew, kurtosis: kurt)
		#expect(fitted.family == .lognormal, "selected \(fitted.family)")
		let got = Self.momentsByQuadrature(fitted)
		#expect(abs(got.skewness - skew) < 1e-5, "skewness \(got.skewness), asked for \(skew)")
		#expect(abs(got.kurtosis - kurt) < 1e-3, "kurtosis \(got.kurtosis), asked for \(kurt)")
	}

	// MARK: - Sampling

	@Test("A large sample has the requested moments")
	func sampleHasTheRequestedMoments() throws {
		// The check the quadrature cannot make: that draws actually follow the
		// distribution described. A sampler wired to a different member would pass
		// every test above.
		for target in Self.targets where target.kurtosis < 7 {
			let fitted = try Self.build(target)
			var generator = DeterministicRNG(seed: 48_401)
			let count = 400_000
			var draws = [Double]()
			draws.reserveCapacity(count)
			for _ in 0..<count { draws.append(fitted.next(using: &generator)) }

			let sampleMean: Double = draws.reduce(0, +) / Double(count)
			var second = 0.0, third = 0.0, fourth = 0.0
			for value in draws {
				let d: Double = value - sampleMean
				let d2: Double = d * d
				second += d2
				third += d2 * d
				fourth += d2 * d2
			}
			second /= Double(count)
			third /= Double(count)
			fourth /= Double(count)
			let sigma: Double = second.squareRoot()

			#expect(abs(sampleMean - target.mean) < 0.02 * Swift.max(1.0, abs(target.mean)) + 0.05 * target.standardDeviation,
					"\(target.name): sample mean \(sampleMean), asked for \(target.mean)")
			#expect(abs(sigma - target.standardDeviation) < 0.05 * target.standardDeviation,
					"\(target.name): sample sd \(sigma), asked for \(target.standardDeviation)")
			// Sampling error on a third and fourth moment is large — roughly √(6/n)
			// and √(24/n) for a normal and worse for heavy tails — so these bounds are
			// what 400,000 draws can actually support, not what would look impressive.
			#expect(abs(third / (second * sigma) - target.skewness) < 0.08,
					"\(target.name): sample skewness \(third / (second * sigma)), asked for \(target.skewness)")
			#expect(abs(fourth / (second * second) - target.kurtosis) < 0.5,
					"\(target.name): sample kurtosis \(fourth / (second * second)), asked for \(target.kurtosis)")
		}
	}

	// MARK: - The distribution contract

	@Test("The quantile is monotone and the CDF inverts it")
	func quantileAndCDFAreInverse() throws {
		for target in Self.targets {
			let fitted = try Self.build(target)
			var previous = -Double.infinity
			for step in 1..<200 {
				let p: Double = Double(step) / 200
				let x = fitted.quantile(p)
				#expect(x >= previous, "\(target.name): quantile fell from \(previous) to \(x) at p=\(p)")
				previous = x
				#expect(x.isFinite, "\(target.name): quantile(\(p)) is not finite")
				#expect(abs(fitted.cdf(x) - p) < 1e-8,
						"\(target.name): cdf(quantile(\(p))) = \(fitted.cdf(x))")
			}
		}
	}

	@Test("Reflection is exact: negating the skewness mirrors the distribution")
	func reflectionIsExact() throws {
		// The fit is performed for non-negative skewness and mirrored afterwards. If
		// that mirror were not exact, a left-skewed request would silently get a
		// slightly different shape from its right-skewed twin.
		let right = try DistributionMomentFit(mean: 0, standardDeviation: 1,
											  skewness: 1.1, kurtosis: 5.0)
		let left = try DistributionMomentFit(mean: 0, standardDeviation: 1,
											 skewness: -1.1, kurtosis: 5.0)
		for step in 1..<100 {
			let p: Double = Double(step) / 100
			#expect(abs(left.quantile(p) + right.quantile(1 - p)) < 1e-9,
					"at p=\(p): left \(left.quantile(p)), −right(1−p) \(-right.quantile(1 - p))")
		}
	}

	// MARK: - Refusals

	@Test("Moments no distribution can have are refused")
	func impossibleMomentsAreRefused() {
		// β₂ > β₁ + 1 follows from Var[(X − μ)²] ≥ 0 and holds for every distribution
		// with four moments. Below it there is nothing to fit, and returning the
		// nearest feasible shape would answer a question nobody asked.
		#expect(throws: MomentFitError.impossibleMoments(skewness: 2, kurtosis: 4)) {
			_ = try DistributionMomentFit(mean: 0, standardDeviation: 1, skewness: 2, kurtosis: 4)
		}
		#expect(throws: MomentFitError.impossibleMoments(skewness: 0, kurtosis: 1)) {
			_ = try DistributionMomentFit(mean: 0, standardDeviation: 1, skewness: 0, kurtosis: 1)
		}
		// Exactly on the boundary is the two-point distribution, which has no density.
		#expect(throws: MomentFitError.impossibleMoments(skewness: 0, kurtosis: 1)) {
			_ = try DistributionMomentFit(mean: 0, standardDeviation: 1, skewness: 0, kurtosis: 1)
		}
		#expect(throws: MomentFitError.nonPositiveStandardDeviation) {
			_ = try DistributionMomentFit(mean: 0, standardDeviation: 0, skewness: 0, kurtosis: 3)
		}
		#expect(throws: MomentFitError.nonFiniteMoment) {
			_ = try DistributionMomentFit(mean: .nan, standardDeviation: 1, skewness: 0, kurtosis: 3)
		}
	}

	@Test("Excess kurtosis passed by mistake is caught rather than fitted")
	func excessKurtosisIsNotSilentlyAccepted() {
		// `kurtosis` is E[(X−μ)⁴]/σ⁴, which is 3 for a normal, and many tools report
		// excess kurtosis instead. Passing 0.0 — a normal's excess — asks for the
		// impossible and must say so rather than fitting something.
		#expect(throws: MomentFitError.impossibleMoments(skewness: 0, kurtosis: 0)) {
			_ = try DistributionMomentFit(mean: 0, standardDeviation: 1, skewness: 0, kurtosis: 0)
		}
	}
}
