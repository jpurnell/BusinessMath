//
//  BetaSmallShapeTests.swift
//  BusinessMath
//
//  Beta at shapes small enough that the gamma ratio underflows.
//

import Testing
import TestSupport
@testable import BusinessMath

/// Beta(α, β) at α, β well below 1, where the gamma-ratio construction breaks down.
///
/// `distributionBeta` draws `X ~ Gamma(α, 1)` and `Y ~ Gamma(β, 1)` and returns `X/(X+Y)`.
/// For a shape below 1, `gammaVariate` uses the boost `Gamma(α) = Gamma(α+1) · U^(1/α)` —
/// and at α = 0.001 that exponent is 1000, so `pow(u, 1000)` underflows to zero for all but
/// `u` within about 0.7% of 1. Both gammas underflow together and the ratio is 0/0.
///
/// A guard caught the 0/0 and returned the distribution mean, `α/(α+β)`. That is the wrong
/// kind of safe. Measured over 20,000 seeded draws at α = β = 0.001, it fired on **22.375%**
/// of them, each returning exactly 0.5 — and Beta(0.001, 0.001) is very nearly a coin flip
/// between 0 and 1, so 0.5 is close to the one value it never produces. NaN would at least
/// have been loud; a plausible number in the middle of the support is precisely what this
/// library's fail-silent rule forbids.
///
/// The fix keeps the same construction and moves it into logs, where the boost is a
/// multiplication rather than a `pow`: `log X = log Gamma(α+1) + log(u)/α` stays finite at
/// any α, and `X/(X+Y)` becomes `1/(1 + exp(log Y − log X))`, which saturates to 0 or 1
/// instead of underflowing to NaN.
@Suite("Beta at small shapes")
struct BetaSmallShapeTests {

	private static let drawCount = 20_000

	private static func draws(shape: Double) -> [Double] {
		(0..<drawCount).map { i in
			distributionBeta(alpha: shape, beta: shape, seed: UInt64(i) &+ 7)
		}
	}

	@Test("No draw is the fallback mean", arguments: [0.5, 0.1, 0.01, 0.001])
	func fallbackNeverFires(shape: Double) {
		// The degenerate branch returns α/(α+β), which for α == β is exactly 0.5. A genuine
		// draw hitting 0.5 bit-for-bit at these shapes has probability far below 1/20000, so
		// any occurrence is the fallback rather than a coincidence.
		let atTheMean = Self.draws(shape: shape).filter { $0 == 0.5 }.count
		#expect(atTheMean == 0,
				"\(atTheMean) of \(Self.drawCount) draws at shape \(shape) returned exactly 0.5, the degenerate fallback")
	}

	@Test("Every draw is a probability", arguments: [0.5, 0.1, 0.01, 0.001])
	func drawsStayInTheSupport(shape: Double) {
		let bad = Self.draws(shape: shape).filter { !($0 >= 0.0 && $0 <= 1.0) }.count
		#expect(bad == 0, "\(bad) draws at shape \(shape) were NaN or outside [0, 1]")
	}

	@Test("At tiny shapes the mass really is at the ends")
	func tinyShapesAreBimodal() {
		// The shape of the answer, not just its finiteness. Beta(0.001, 0.001) puts
		// essentially all of its mass within a whisker of 0 and 1; an implementation that
		// quietly returned the mean, or clamped, would fail this where the range check above
		// would not.
		let values = Self.draws(shape: 0.001)
		let atTheEnds = values.filter { $0 < 0.01 || $0 > 0.99 }.count
		let fraction = Double(atTheEnds) / Double(Self.drawCount)
		#expect(fraction > 0.9,
				"only \(fraction) of draws from Beta(0.001, 0.001) landed outside [0.01, 0.99]")

		// And both ends, not one: a sign error or a one-sided underflow would pile
		// everything on a single end and still pass the test above.
		let low = values.filter { $0 < 0.01 }.count
		let high = values.filter { $0 > 0.99 }.count
		#expect(low > Self.drawCount / 10, "only \(low) draws near 0")
		#expect(high > Self.drawCount / 10, "only \(high) draws near 1")
	}

	@Test("The mean is still the mean")
	func meanIsUnchanged() {
		// Beta(0.5, 0.5) is arcsine: mean 0.5, standard deviation 1/(2√2) ≈ 0.3536, so the
		// standard error at 20,000 draws is 0.0025. Four of those is 0.01.
		let values = Self.draws(shape: 0.5)
		let mean = values.reduce(0.0, +) / Double(Self.drawCount)
		#expect(abs(mean - 0.5) < 0.01,
				"Beta(0.5, 0.5) sample mean \(mean), four standard errors from 0.5 is 0.01")
	}
}
