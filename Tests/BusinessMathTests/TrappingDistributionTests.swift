//
//  TrappingDistributionTests.swift
//  BusinessMathTests
//
//  Phase 1 of the contaminated-input sweep: the trap class, in `Sources/BusinessMath/Simulation/`.
//
//  `Int(Double)` **traps** — it does not return a wrong answer — for a non-finite value and
//  equally for any finite value outside `Int`'s range (`Int.max ≈ 9.22e18`). A trap takes the
//  whole process down, not one call, so a single bad parameter ends an entire simulation run
//  rather than producing one unusable draw.
//
//  Four sites here, each reached from a public API with inputs that pass every guard already
//  present:
//
//    * `DistributionCumulativeDiscrete.init?(values:cumulative:)` — guarded `allSatisfy(isFinite)`,
//      which happily passes `1e300`.
//    * `DistributionNegativeBinomial.quantile(_:)` — `p = 1e-300` puts the loop ceiling at
//      1e301 with every input finite and the initialiser satisfied.
//    * `DistributionGeometric.quantile(_:)` — `q = -.infinity` makes `1 - q` infinite, which
//      passes the `complement > 0` guard; its two siblings both open with the `q > 0` guard
//      this one lacked.
//    * `triangularDistribution(low:high:base:_:)` — five guards precede the conversion and
//      none of them touched `uSeed`, the public fourth parameter.
//
//  Every test below pairs the contaminated call with a CLEAN control on the same distribution.
//  The controls pass before and after the change; they are what proves the suite discriminates
//  rather than merely failing.
//

import Foundation
import Testing

@testable import BusinessMath

@Suite("Simulation distributions refuse inputs that would trap")
struct TrappingDistributionTests {

	// MARK: - (a) DistributionCumulativeDiscrete

	/// `1e300` is finite, so the old `allSatisfy(isFinite)` admitted it and
	/// `Int($0.rounded())` took the process down.
	@Test("CumulativeDiscrete_HugeFiniteValues_ReturnNilRatherThanTrapping")
	func cumulativeDiscreteHugeFiniteValuesReturnNil() {
		let huge = DistributionCumulativeDiscrete(values: [1e300, 2e300], cumulative: [0.5, 1.0])
		#expect(huge == nil, "a value that cannot be rounded into an Int is refused, not converted")

		// Just past `Int.max` (9.22e18), mixed with an ordinary value — the magnitude half of
		// the guard, with nothing non-finite anywhere in the array.
		let pastIntMax = DistributionCumulativeDiscrete(values: [10.0, 1e19], cumulative: [0.4, 1.0])
		#expect(pastIntMax == nil, "1e19 exceeds Int.max and is refused")
	}

	/// Non-finite values were already refused; this pins that the widened guard did not
	/// lose the half that worked.
	@Test("CumulativeDiscrete_NonFiniteValues_ReturnNil")
	func cumulativeDiscreteNonFiniteValuesReturnNil() {
		let infinite = DistributionCumulativeDiscrete(values: [10.0, Double.infinity], cumulative: [0.4, 1.0])
		#expect(infinite == nil)

		let notANumber = DistributionCumulativeDiscrete(values: [Double.nan, 20.0], cumulative: [0.4, 1.0])
		#expect(notANumber == nil)
	}

	/// CLEAN CONTROL. Ordinary values that round to distinct integers still build, and
	/// still answer the way the DocC example says.
	@Test("CumulativeDiscrete_CleanValues_BuildAndAnswer")
	func cumulativeDiscreteCleanValuesBuildAndAnswer() throws {
		let built = DistributionCumulativeDiscrete(values: [10.4, 20.6, 50.0],
												   cumulative: [0.4, 0.75, 1.0])
		let distribution = try #require(built)
		#expect(distribution.values == [10, 21, 50], "each value rounds to the nearest integer")

		// The mass at the middle outcome is 0.75 − 0.4.
		let middleMass: Double = distribution.pmf(21)
		let expectedMass: Double = 0.75 - 0.4
		let massError: Double = abs(middleMass - expectedMass)
		#expect(massError < 1e-12, "pmf(21) = \(middleMass)")

		// The smallest stated value whose cumulative probability reaches 0.5 is the middle one.
		#expect(distribution.quantile(0.5) == 21)
	}

	// MARK: - (b) DistributionNegativeBinomial

	/// `p = 1e-300` satisfies `p > 0, p <= 1, p.isFinite`, so the initialiser hands back a
	/// distribution whose mean is 1e300 — and `Int(mean + 20 * deviation)` trapped before the
	/// accumulation loop ran a single step.
	@Test("NegativeBinomial_TinyProbability_QuantileDoesNotTrap")
	func negativeBinomialTinyProbabilityQuantileDoesNotTrap() throws {
		let distribution = try #require(DistributionNegativeBinomial(successes: 1, p: 1e-300))

		// P(X = 0) is p^s = 1e-300, so an argument below that is answered on the first step —
		// the loop never approaches the ceiling, and the ceiling is the only thing that trapped.
		#expect(distribution.quantile(1e-301) == 0)
	}

	/// The overflow half: `p = .leastNormalMagnitude` makes `mean + 20 * deviation` itself
	/// infinite, not merely out of `Int` range, so the bound has to survive a non-finite span.
	@Test("NegativeBinomial_SubnormalScaleProbability_QuantileDoesNotTrap")
	func negativeBinomialSubnormalScaleProbabilityQuantileDoesNotTrap() throws {
		let tiny: Double = .leastNormalMagnitude
		let distribution = try #require(DistributionNegativeBinomial(successes: 1, p: tiny))

		// P(X = 0) is `tiny` itself, which is above the argument, so the first step answers.
		#expect(distribution.quantile(1e-320) == 0)
	}

	/// CLEAN CONTROL. Negative binomial with `s = 3, p = 0.5`, whose mass function is exact
	/// in binary: P(0) = C(2,0)·0.5³ = 0.125, P(1) = C(3,1)·0.5⁴ = 0.1875,
	/// P(2) = C(4,2)·0.5⁵ = 0.1875. So F(0) = 0.125, F(1) = 0.3125, F(2) = 0.5.
	@Test("NegativeBinomial_CleanParameters_QuantilesUnchanged")
	func negativeBinomialCleanParametersQuantilesUnchanged() throws {
		let distribution = try #require(DistributionNegativeBinomial(successes: 3, p: 0.5))

		let atZero: Double = distribution.pmf(0)
		let zeroError: Double = abs(atZero - 0.125)
		#expect(zeroError < 1e-12, "pmf(0) = \(atZero)")

		let atOne: Double = distribution.pmf(1)
		let oneError: Double = abs(atOne - 0.1875)
		#expect(oneError < 1e-12, "pmf(1) = \(atOne)")

		// 0.2 sits between F(0) = 0.125 and F(1) = 0.3125; 0.4 between F(1) and F(2) = 0.5.
		#expect(distribution.quantile(0.2) == 1)
		#expect(distribution.quantile(0.4) == 2)
		#expect(distribution.quantile(0) == 0, "at or below zero the answer is the support minimum")
	}

	// MARK: - (c) DistributionGeometric

	/// `1 - (-.infinity)` is `+.infinity`, which passed the `complement > 0` guard; the
	/// division then produced `-.infinity` and `Int(_:)` took the process down. The answer the
	/// un-trapped arithmetic would have reached is 1, which is also what both siblings return
	/// for a non-positive argument.
	@Test("Geometric_NegativeInfinityQuantile_ReturnsSupportMinimum")
	func geometricNegativeInfinityQuantileReturnsSupportMinimum() {
		let distribution = DistributionGeometric(0.3)
		#expect(distribution.quantile(-Double.infinity) == 1)
		#expect(distribution.quantile(-1e300) == 1)
		#expect(distribution.quantile(0) == 1)
	}

	/// A `nan` argument fails `q > 0` — every comparison against `nan` is false — and lands on
	/// the same support minimum `DistributionNegativeBinomial` and `DistributionLogarithmic`
	/// give it.
	@Test("Geometric_NaNQuantile_ReturnsSupportMinimum")
	func geometricNaNQuantileReturnsSupportMinimum() {
		let distribution = DistributionGeometric(0.3)
		#expect(distribution.quantile(Double.nan) == 1)
	}

	/// CLEAN CONTROL. With p = 0.5, F(k) = 1 − 0.5^k: F(3) = 0.875 < 0.9 ≤ F(4) = 0.9375, so
	/// the 0.9 quantile is 4. Certainty is unreachable in finitely many trials, which the
	/// existing `Int.max` answer records.
	@Test("Geometric_CleanQuantiles_Unchanged")
	func geometricCleanQuantilesUnchanged() {
		let distribution = DistributionGeometric(0.5)
		#expect(distribution.quantile(0.9) == 4)
		#expect(distribution.quantile(0.5) == 1)
		#expect(distribution.quantile(1.0) == Int.max, "no finite trial count reaches certainty")

		let cdfAtFour: Double = distribution.cdf(4)
		let cdfError: Double = abs(cdfAtFour - 0.9375)
		#expect(cdfError < 1e-12, "cdf(4) = \(cdfAtFour)")
	}

	// MARK: - (d) triangularDistribution

	/// `uSeed` was the one parameter the validation block did not touch, and the only one that
	/// reaches `Int(uSeed * 1_000_000)`.
	@Test("Triangular_NonFiniteSeed_ReturnsNaNRatherThanTrapping")
	func triangularNonFiniteSeedReturnsNaN() {
		let notANumber: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, Double.nan)
		#expect(notANumber.isNaN, "got \(notANumber)")

		let positiveInfinity: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, Double.infinity)
		#expect(positiveInfinity.isNaN, "got \(positiveInfinity)")

		let negativeInfinity: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, -Double.infinity)
		#expect(negativeInfinity.isNaN, "got \(negativeInfinity)")
	}

	/// The magnitude half: finite, and `1e300 * 1_000_000` is far past `Int.max`.
	@Test("Triangular_HugeFiniteSeed_ReturnsNaNRatherThanTrapping")
	func triangularHugeFiniteSeedReturnsNaN() {
		let huge: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 1e300)
		#expect(huge.isNaN, "got \(huge)")

		// Just past `Int.max` once multiplied by a million.
		let pastIntMax: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 1e13)
		#expect(pastIntMax.isNaN, "got \(pastIntMax)")
	}

	/// The worse failure the widened guard also closes: a finite `uSeed` below zero did not
	/// trap, it returned a plausible number *outside* the support with nothing marking it wrong.
	@Test("Triangular_SeedOutsideUnitInterval_ReturnsNaNRatherThanAValueOutsideTheSupport")
	func triangularSeedOutsideUnitIntervalReturnsNaN() {
		let belowZero: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, -0.5)
		#expect(belowZero.isNaN, "a negative uniform used to yield a value below `low`; got \(belowZero)")

		let aboveOne: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 1.5)
		#expect(aboveOne.isNaN, "got \(aboveOne)")
	}

	/// CLEAN CONTROL. The midpoint seed of a symmetric triangle on [0, 1] is the mode, and the
	/// quarter seed of the symmetric triangle on [0, 10] is `√(0.25 · 10 · 5)` by the
	/// inverse-transform branch for `u < F(c)`.
	@Test("Triangular_CleanSeeds_Unchanged")
	func triangularCleanSeedsUnchanged() {
		let atMode: Double = triangularDistribution(low: 0.0, high: 1.0, base: 0.5, 0.5)
		#expect(atMode.isEqual(to: 0.5), "got \(atMode)")

		let atQuarter: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 0.25)
		// u = 0.25 < F(base) = 0.5, so the first branch applies: low + √(u · (high − low) · (base − low)).
		let underRoot: Double = 12.5
		let expectedQuarter: Double = underRoot.squareRoot()
		let quarterError: Double = abs(atQuarter - expectedQuarter)
		#expect(quarterError < 1e-12, "got \(atQuarter)")
		#expect(atQuarter >= 0.0, "a clean draw stays inside the support; got \(atQuarter)")
		#expect(atQuarter <= 10.0, "a clean draw stays inside the support; got \(atQuarter)")

		// The upper boundary seed is inside the documented domain and stays usable:
		// `(1 − u)` is zero, so the second branch returns `high` exactly.
		//
		// The lower boundary is deliberately NOT asserted here. `u == 0` fails the
		// `u > 0 && u < fc` condition and takes the *second* branch, returning
		// `high − √((high − low)(high − base))` = 2.9289… rather than `low`. That is a
		// separate defect in the same family — a condition that is correct while the value
		// it produces is wrong — and it is out of scope for this trap fix, so pinning it
		// either way would be writing down an answer nobody has decided.
		let atOne: Double = triangularDistribution(low: 0.0, high: 10.0, base: 5.0, 1.0)
		#expect(atOne.isEqual(to: 10.0), "got \(atOne)")
	}

	/// CLEAN CONTROL. The degenerate single-point case still returns the point, and the
	/// already-screened parameters still answer the way they did.
	@Test("Triangular_CleanBoundsValidation_Unchanged")
	func triangularCleanBoundsValidationUnchanged() {
		let singlePoint: Double = triangularDistribution(low: 3.0, high: 3.0, base: 3.0, 0.5)
		#expect(singlePoint.isEqual(to: 3.0), "got \(singlePoint)")

		let transposed: Double = triangularDistribution(low: 10.0, high: 5.0, base: 7.0, 0.5)
		#expect(transposed.isNaN)

		let modeOutside: Double = triangularDistribution(low: 5.0, high: 10.0, base: 3.0, 0.5)
		#expect(modeOutside.isNaN)
	}
}
