//
//  PercentileFittingCoverageTests.swift
//  BusinessMath
//
//  The second batch of `PercentileParameterisable` conformers — the sixteen families
//  behind the remaining `Psi*Alt` rows.
//
//  Same oracle as `PercentileFittingTests`, and deliberately the same helper rather
//  than a copy of it: build a distribution with known parameters, hand its own
//  quantiles back as constraints, and require the recovered distribution to reproduce
//  them across the whole range. A conformance that compiles proves nothing — the
//  question these answer is whether the solve actually converges for the family, and
//  for several of them the honest answer needed a wider tolerance rather than a
//  quieter test.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Fitting the remaining Alt families to percentiles")
struct PercentileFittingCoverageTests {

	/// Shorthand for the shared oracle.
	@discardableResult
	private static func check<D: PercentileParameterisable>(
		_ original: D, at probabilities: [Double], tolerance: Double = 1e-6, _ label: String
	) -> Int where D.T == Double {
		PercentileFittingTests.roundTrip(original, at: probabilities, tolerance: tolerance, label)
	}

	// MARK: - One parameter

	@Test("PsiErfAlt: the error-function family is recovered from one percentile")
	func errorFunction() {
		var fitted = 0
		for h in [0.5, 1.0, 2.5, 10.0] {
			guard let original = DistributionErf(h: h) else {
				Issue.record("erf(h: \(h)) would not build")
				continue
			}
			if Self.check(original, at: [0.75], "erf(h: \(h))") > 0 { fitted += 1 }
		}
		#expect(fitted == 4, "only \(fitted) of 4 erf fits round-tripped")
	}

	// MARK: - Two parameters, location and scale

	@Test("PsiHypSecantAlt, PsiMaxExtremeAlt and PsiMinExtremeAlt round-trip")
	func locationScaleFamilies() {
		var fitted = 0
		for (loc, scale) in [(0.0, 1.0), (25.0, 4.0), (-8.0, 0.5)] {
			if let d = DistributionHypSecant(loc: loc, scale: scale) {
				if Self.check(d, at: [0.1, 0.9], "hypSecant(\(loc), \(scale))") > 0 { fitted += 1 }
			}
			if let d = DistributionMaxExtreme(location: loc, scale: scale) {
				if Self.check(d, at: [0.1, 0.9], "maxExtreme(\(loc), \(scale))") > 0 { fitted += 1 }
			}
			if let d = DistributionMinExtreme(location: loc, scale: scale) {
				if Self.check(d, at: [0.1, 0.9], "minExtreme(\(loc), \(scale))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 9, "only \(fitted) of 9 location-scale fits round-tripped")
	}

	@Test("PsiUniformAlt is recovered exactly, since its quantile is linear")
	func uniform() {
		var fitted = 0
		for (low, high) in [(0.0, 1.0), (-5.0, 5.0), (100.0, 250.0)] {
			let d = DistributionUniform(low, high)
			if Self.check(d, at: [0.25, 0.75], "uniform(\(low), \(high))") > 0 { fitted += 1 }
		}
		#expect(fitted == 3, "only \(fitted) of 3 uniform fits round-tripped")
	}

	// MARK: - Two parameters, both positive

	@Test("PsiPearson5Alt, PsiPareto2Alt and PsiInvNormalAlt round-trip")
	func positiveParameterFamilies() {
		var fitted = 0
		for (a, b) in [(2.0, 1.0), (4.0, 3.0), (7.5, 0.5)] {
			if let d = DistributionPearson5(alpha: a, beta: b) {
				if Self.check(d, at: [0.25, 0.75], tolerance: 1e-5, "pearson5(\(a), \(b))") > 0 { fitted += 1 }
			}
			if let d = DistributionPareto2(scale: b, shape: a) {
				if Self.check(d, at: [0.25, 0.75], tolerance: 1e-5, "pareto2(\(b), \(a))") > 0 { fitted += 1 }
			}
			if let d = DistributionInverseGaussian(mu: a, lambda: b) {
				if Self.check(d, at: [0.25, 0.75], tolerance: 1e-4, "inverseGaussian(\(a), \(b))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 9, "only \(fitted) of 9 positive-parameter fits round-tripped")
	}

	// MARK: - Two parameters, heavy tailed

	@Test("PsiLevyAlt round-trips despite having no mean")
	func levy() {
		// The check points reach p=0.99, where a Lévy quantile is roughly six thousand
		// scale units out. The tolerance is relative, so this still pins the shape.
		var fitted = 0
		for (loc, scale) in [(0.0, 1.0), (3.0, 2.0)] {
			if let d = DistributionLevy(location: loc, scale: scale) {
				if Self.check(d, at: [0.25, 0.75], tolerance: 1e-4, "levy(\(loc), \(scale))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 2, "only \(fitted) of 2 Lévy fits round-tripped")
	}

	// MARK: - Three parameters

	@Test("PsiTriangularAlt and PsiPertAlt round-trip from three percentiles")
	func boundedThreePointFamilies() {
		// The tolerance here is looser than the rest of the file, and the reason is a
		// property of the family rather than of the solve. A triangular quantile is two
		// square-root branches meeting at the mode, so where a constraint lands on the
		// mode exactly the Jacobian column is one-sided. For `(-2, 0, 8)` the mode is
		// the 0.2 quantile — one of the three points below — and only a fifth of the
		// mass lies beneath it, so `min` is weakly identified: the solve matches all
		// three constraints to 1e-9 while `min` itself is out by about 4e-5, which
		// shows up in the far lower tail. `symmetricTriangularIsRecoveredExactly`
		// pins the well-conditioned case so this allowance cannot hide a real
		// regression in the solve.
		var fitted = 0
		for (low, mode, high) in [(0.0, 0.5, 1.0), (10.0, 40.0, 50.0), (-2.0, 0.0, 8.0)] {
			let t = DistributionTriangular(low: low, high: high, base: mode)
			if Self.check(t, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
						  "triangular(\(low), \(mode), \(high))") > 0 { fitted += 1 }
			if let p = DistributionPert(min: low, likely: mode, max: high) {
				if Self.check(p, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
							  "pert(\(low), \(mode), \(high))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 6, "only \(fitted) of 6 three-point fits round-tripped")
	}

	@Test("A symmetric triangular is recovered to solver precision")
	func symmetricTriangularIsRecoveredExactly() {
		// Same family, well-conditioned: the mode is central, so both branches carry
		// comparable mass and both bounds are pinned by the data. If the allowance in
		// `boundedThreePointFamilies` ever starts covering a genuine solver defect,
		// this is the test that notices.
		let original = DistributionTriangular(low: 0, high: 10, base: 5)
		let compared = Self.check(original, at: [0.1, 0.5, 0.9], tolerance: 1e-8,
								  "triangular(0, 5, 10)")
		#expect(compared == PercentileFittingTests.checkPoints.count,
				"the symmetric triangular was compared at \(compared) points")
	}

	@Test("PsiFatigueLifeAlt, PsiFrechetAlt and PsiLogLogisticAlt round-trip")
	func shiftScaleShapeFamilies() {
		var fitted = 0
		for (loc, scale, shape) in [(0.0, 1.0, 2.0), (5.0, 2.0, 3.0)] {
			if let d = DistributionFatigueLife(location: loc, scale: scale, shape: shape) {
				if Self.check(d, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
							  "fatigueLife(\(loc), \(scale), \(shape))") > 0 { fitted += 1 }
			}
			if let d = DistributionFrechet(location: loc, scale: scale, shape: shape) {
				if Self.check(d, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
							  "frechet(\(loc), \(scale), \(shape))") > 0 { fitted += 1 }
			}
			if let d = DistributionLogLogistic(location: loc, scale: scale, shape: shape) {
				if Self.check(d, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
							  "logLogistic(\(loc), \(scale), \(shape))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 6, "only \(fitted) of 6 shift-scale-shape fits round-tripped")
	}

	// MARK: - Three parameters, all positive

	@Test("PsiPearson6Alt round-trips from three percentiles")
	func pearson6() {
		var fitted = 0
		for (a1, a2, beta) in [(2.0, 3.0, 1.0), (4.0, 5.0, 2.0)] {
			if let d = DistributionPearson6(alpha1: a1, alpha2: a2, beta: beta) {
				if Self.check(d, at: [0.2, 0.5, 0.8], tolerance: 1e-4,
							  "pearson6(\(a1), \(a2), \(beta))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 2, "only \(fitted) of 2 Pearson 6 fits round-tripped")
	}

	// MARK: - Four parameters

	@Test("PsiBetaGenAlt round-trips from four percentiles")
	func betaGeneralised() {
		var fitted = 0
		for (s1, s2, low, high) in [(2.0, 3.0, 0.0, 1.0), (1.5, 1.5, 10.0, 20.0)] {
			if let d = DistributionBetaGeneralised(shape1: s1, shape2: s2, min: low, max: high) {
				if Self.check(d, at: [0.1, 0.3, 0.7, 0.9], tolerance: 1e-3,
							  "betaGeneralised(\(s1), \(s2), \(low), \(high))") > 0 { fitted += 1 }
			}
		}
		#expect(fitted == 2, "only \(fitted) of 2 generalised beta fits round-tripped")
	}

	// MARK: - PsiTriangGen

	@Test("A generalised triangular hits the two percentiles and the mode it was given")
	func generalisedTriangular() throws {
		var built = 0
		let cases: [(low: (p: Double, value: Double), mode: Double, high: (p: Double, value: Double))] = [
			((0.1, 12), 20, (0.9, 35)),
			((0.05, 0), 1, (0.95, 4)),
			((0.25, -5), 0, (0.75, 8)),
		]
		for row in cases {
			let t = try DistributionTriangular.generalised(lowerPercentile: row.low,
														   mode: row.mode,
														   upperPercentile: row.high)
			let atLow: Double = t.quantile(row.low.p)
			let atHigh: Double = t.quantile(row.high.p)
			let lowScale: Double = Swift.max(1, Swift.abs(row.low.value))
			let highScale: Double = Swift.max(1, Swift.abs(row.high.value))
			#expect(Swift.abs(atLow - row.low.value) < lowScale * 1e-8,
					"Q(\(row.low.p)) came back \(atLow), asked for \(row.low.value)")
			#expect(Swift.abs(atHigh - row.high.value) < highScale * 1e-8,
					"Q(\(row.high.p)) came back \(atHigh), asked for \(row.high.value)")
			// The mode was pinned, not fitted, so it must come back exactly.
			#expect(Swift.abs(t.base - row.mode) < 1e-9, "the mode moved to \(t.base)")
			#expect(t.low < row.low.value, "the lower bound \(t.low) is not below the data")
			#expect(t.high > row.high.value, "the upper bound \(t.high) is not above the data")
			built += 1
		}
		#expect(built == cases.count, "only \(built) of \(cases.count) were built")
	}

	@Test("A generalised triangular refuses statements that cannot describe one")
	func generalisedTriangularRefuses() {
		// A mode outside the stated range does not make the solve hard, it makes the
		// bounds unidentifiable: both percentiles fall on one side of the peak and
		// every sufficiently wide pair of bounds fits as well as any other.
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionTriangular.generalised(lowerPercentile: (0.1, 12), mode: 50,
													   upperPercentile: (0.9, 35))
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionTriangular.generalised(lowerPercentile: (0.9, 12), mode: 20,
													   upperPercentile: (0.1, 35))
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionTriangular.generalised(lowerPercentile: (0.0, 12), mode: 20,
													   upperPercentile: (0.9, 35))
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionTriangular.generalised(lowerPercentile: (0.1, 40), mode: 20,
													   upperPercentile: (0.9, 35))
		}
	}

	// MARK: - What the constraint vocabulary reaches

	@Test("A stated mean is honoured where the family has one in closed form")
	func momentConstraints() throws {
		let uniform = try DistributionUniform.fitting([.mean(5), .standardDeviation(2)])
		let width: Double = uniform.max - uniform.min
		let recoveredMean: Double = (uniform.min + uniform.max) / 2
		let recoveredSD: Double = width / (12.0).squareRoot()
		#expect(abs(recoveredMean - 5) < 1e-8, "uniform mean came back \(recoveredMean)")
		#expect(abs(recoveredSD - 2) < 1e-8, "uniform deviation came back \(recoveredSD)")
	}

	@Test("A family with no closed-form moment refuses rather than approximating")
	func unsupportedMoment() {
		// Lévy has no mean at any parameter value. The contract says a family that
		// cannot answer must throw; returning an integrated estimate would make the
		// refusal invisible and the answer wrong.
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionLevy.fitting([.mean(3), .quantile(p: 0.5, value: 4)])
		}
	}
}
