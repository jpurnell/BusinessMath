//
//  InverseNormalCDFDegenerateTests.swift
//  BusinessMath
//
//  What `inverseNormalCDF` returns when the scale is not a scale.
//

import Testing
import TestSupport
@testable import BusinessMath

/// `stdDev` at zero and below, pinned rather than left to arithmetic.
///
/// ``inverseNormalCDF(p:mean:stdDev:)`` is `mean + stdDev * standardNormalQuantile(p)`, and
/// the quantile is deliberately total over the extended reals — it returns ±infinity outside
/// `(0, 1)` rather than trapping. That totality is right, and it makes the scale the only
/// place an undefined answer can enter.
///
/// Two cases came out wrong, and only one of them announced itself:
///
/// - `stdDev: 0` at `p: 0` or `p: 1` evaluated `0 * (∓∞)`, which is NaN. A zero scale is a
///   point mass at `mean`; every quantile of it is `mean`, including the endpoints.
/// - `stdDev: -1` returned a *mirrored* quantile. Asked for the 90th percentile it answered
///   −1.2816, the 10th. Nothing in the result says so — the sign of the scale silently
///   reflects the distribution, and a caller who computed a scale rather than writing one
///   gets a confident wrong number.
///
/// The second is the one this library's fail-silent rule is about: NaN is loud, and a
/// plausible number from the wrong tail is not.
@Suite("Inverse normal CDF: degenerate scales")
struct InverseNormalCDFDegenerateTests {

	@Test("A zero scale is a point mass at the mean, at every p including the endpoints",
		  arguments: [0.0, 1e-12, 0.25, 0.5, 0.75, 1.0 - 1e-12, 1.0])
	func zeroScaleIsAPointMass(p: Double) {
		let value = inverseNormalCDF(p: p, mean: 5.0, stdDev: 0.0)
		#expect(identical(value, 5.0),
				"a zero scale at p = \(p) gave \(value); every quantile of a point mass is its location")
	}

	@Test("A negative scale is not a distribution, and says so rather than mirroring")
	func negativeScaleIsNotADistribution() {
		// The regression: this returned -1.2815515655446004, which is the 10th percentile
		// of N(0, 1) wearing the 90th percentile's name.
		let value = inverseNormalCDF(p: 0.9, mean: 0.0, stdDev: -1.0)
		#expect(value.isNaN,
				"a negative scale gave \(value); a mirrored quantile is a wrong answer with a plausible magnitude")
	}

	@Test("A NaN probability stays NaN whatever the scale",
		  arguments: [-1.0, 0.0, 1.0])
	func nanProbabilityPropagates(stdDev: Double) {
		// Including at `stdDev: 0`, where the point-mass shortcut must not answer `mean`
		// for a question that was never asked.
		let value = inverseNormalCDF(p: Double.nan, mean: 5.0, stdDev: stdDev)
		#expect(value.isNaN, "p = NaN at stdDev \(stdDev) gave \(value)")
	}

	@Test("A positive scale still behaves", arguments: [0.1, 1.0, 25.0])
	func positiveScaleUnchanged(stdDev: Double) {
		// The counterweight: the guards above must not have replaced the function.
		let value = inverseNormalCDF(p: 0.9, mean: 0.0, stdDev: stdDev)
		let expected = stdDev * 1.2815515655446004
		#expect(abs(value - expected) < 1e-12,
				"the 90th percentile at scale \(stdDev) gave \(value), not \(expected)")
	}
}
