//
//  JumpDiffusionUniformTransformTests.swift
//  BusinessMathTests
//
//  `JumpDiffusion` simulated 20.7% more jumps than the intensity it was given.
//
//  The step turns its normal draw into a uniform and feeds that to `poissonInverseCDF`, so
//  the transform has to actually be the normal CDF. It was a private Abramowitz & Stegun
//  approximation living in the file, and it was not merely less accurate than `erf` — it was
//  **wrong**.
//
//  A&S 7.1.26 approximates `erf(x)` using `t = 1 / (1 + p·x)` *and* `exp(-x²)` at the same
//  argument. Since `Φ(x) = (1 + erf(x / √2)) / 2`, both halves must take `x / √2`. The local
//  copy put `absX` in the polynomial and `absX² / 2` in the exponential, so the two disagreed
//  by a factor of √2:
//
//  | x | true Φ(x) | as written | error |
//  |---|---|---|---|
//  | 0.25 | 0.598706326 | 0.626677195 | 2.80e-02 |
//  | 0.50 | 0.691462461 | 0.728327668 | **3.69e-02** |
//  | 1.00 | 0.841344746 | 0.870328641 | 2.90e-02 |
//
//  Nearly four points of probability. The same approximation applied consistently errs by
//  6.9e-08, so the inconsistency cost a factor of 532,000.
//
//  `BlackScholesModel` records having moved off its own copy of this approximation for a
//  smaller reason — 6.25e-04 on an index-scale option. This file kept one.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Jump diffusion draws jumps at the intensity it was given")
struct JumpDiffusionUniformTransformTests {

	private static let drift = 0.05
	private static let vol = 0.25
	private static let jumpMean = 0.0
	private static let jumpVol = 0.10
	private static let dt = 1.0 / 12.0

	/// The smooth part of a step, using the same jump-compensated drift the model uses. Any
	/// departure from it is a jump, which is how a jump is counted here without reaching into
	/// the private machinery.
	private static func smoothStep(from start: Double, z: Double, intensity: Double) -> Double {
		let k = exp(jumpMean + jumpVol * jumpVol / 2.0) - 1.0
		let adjustedDrift = drift - intensity * k
		let driftTerm = (adjustedDrift - vol * vol / 2.0) * dt
		let diffusionTerm = vol * dt.squareRoot() * z
		return start * exp(driftTerm + diffusionTerm)
	}

	/// The fraction of steps that jump, over an evenly spaced grid of standard-normal
	/// quantiles. The grid is deterministic, so this number carries no sampling noise — the
	/// only error is grid discretisation.
	private static func observedJumpFraction(intensity: Double, gridPoints: Int = 4000) -> Double {
		let model = JumpDiffusion(name: "T", drift: drift, volatility: vol,
								  jumpIntensity: intensity, jumpMean: jumpMean,
								  jumpVolatility: jumpVol)
		var jumped = 0
		for i in 1..<gridPoints {
			let z: Double = inverseNormalCDF(p: Double(i) / Double(gridPoints))
			let actual = model.step(from: 100.0, dt: dt, normalDraws: z)
			let smooth = smoothStep(from: 100.0, z: z, intensity: intensity)
			if abs(actual - smooth) > 1e-9 { jumped += 1 }
		}
		return Double(jumped) / Double(gridPoints - 1)
	}

	/// Feeding evenly spaced quantiles through a correct normal CDF returns an evenly spaced
	/// uniform, so the share of steps carrying at least one jump is `1 - exp(-λ·dt)`.
	///
	/// Measured at λ = 2: **0.18530 before, 0.15354 after**, against an expected 0.15352 — a
	/// relative error of 20.7% reduced to 0.013%. The 1% bound below is two orders of
	/// magnitude tighter than the defect and two orders looser than the residual.
	@Test("JumpFrequency_MatchesIntensity", arguments: [0.5, 2.0, 5.0])
	func jumpFrequencyMatchesIntensity(intensity: Double) {
		let observed = Self.observedJumpFraction(intensity: intensity)
		let expected = 1.0 - exp(-intensity * Self.dt)
		let relativeError = abs(observed - expected) / expected
		#expect(relativeError < 0.01,
				"λ=\(intensity): observed \(observed) against P(N>=1) = \(expected), off by \(relativeError)")
	}

	/// The single step whose value moved, and the ones that did not.
	///
	/// At `z = 1.0` the biased transform returned 0.870 where the true CDF returns 0.841, and
	/// those two land on opposite sides of a Poisson jump-count boundary — so that step gained
	/// a jump it should not have had, a 3.6% move in one month.
	@Test("StepValues_OnlyTheBiasedOneMoved") func stepValuesOnlyTheBiasedOneMoved() {
		let model = JumpDiffusion(name: "T", drift: Self.drift, volatility: Self.vol,
								  jumpIntensity: 2.0, jumpMean: Self.jumpMean,
								  jumpVolatility: Self.jumpVol)
		func step(_ z: Double) -> Double { model.step(from: 100.0, dt: Self.dt, normalDraws: z) }

		// Unchanged by the fix, to the bit.
		#expect(step(-2.0).isEqual(to: 86.62250879068587))
		#expect(step(-1.0).isEqual(to: 93.10505527295685))
		#expect(step(-0.5).isEqual(to: 96.52604555193429))
		#expect(step(0.0).isEqual(to: 100.07273442433984))
		#expect(step(0.5).isEqual(to: 103.74974047575878))
		#expect(step(2.0).isEqual(to: 118.08705424178127))

		// The one that moved: 103.86511859790379 before.
		#expect(step(1.0).isEqual(to: 107.56185199401587),
				"this step carried a jump the intensity did not call for")
	}

	/// The transform now round-trips: a quantile in, the same probability out.
	///
	/// **This one passes against the unfixed source too.** It exercises the package's
	/// `normalCDF(x:)`, which was always correct — the defect was that `JumpDiffusion` did not
	/// call it. The test is here to pin the property the fix now depends on, not to catch the
	/// bug; the three `JumpFrequency_MatchesIntensity` cases are what fail without the fix.
	@Test("NormalCDF_RoundTripsQuantiles") func normalCDFRoundTripsQuantiles() {
		var worst = 0.0
		for i in 1...199 {
			let p = Double(i) / 200.0
			let z: Double = inverseNormalCDF(p: p)
			worst = Swift.max(worst, abs(normalCDF(x: z) - p))
		}
		#expect(worst < 1e-12, "round-trip error was \(worst)")
	}
}
