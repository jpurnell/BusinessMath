//
//  PercentileFittingTests.swift
//  BusinessMath
//
//  The fitting capability, against the distributions themselves.
//
//  §6 of the completeness proposal names the oracle this work needs, and it is the
//  same self-certifying shape the whole audit ran on:
//
//  > For a distribution with known parameters, compute its true quantiles at p₁…p_k,
//  > feed those back as constraints, and require the recovered parameters to match
//  > the originals.
//
//  That tests the solver against the distribution rather than against a table. It
//  needs no fixture, it works for every conformer without a new one, and it fails
//  loudly when a Jacobian is wrong — which is the failure mode a comparison against
//  stored numbers would report as a tolerance problem.
//
//  The round trip is run through `quantile` rather than through the parameters, since
//  a distribution can be exactly right with parameters that differ from the ones it
//  was built from — `PsiUniformAlt` and any family with a redundant parameterisation
//  will do that legitimately.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Fitting a distribution to percentiles")
struct PercentileFittingTests {

	/// Probabilities to check a recovered distribution against — the ends included,
	/// because a fit that matches at the two stated points and diverges between them
	/// is the failure a two-point check cannot see.
	static let checkPoints: [Double] = [0.01, 0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95, 0.99]

	/// Asserts that fitting `original`'s own quantiles recovers `original`.
	///
	/// - Returns: How many probabilities were compared. Returned rather than discarded
	///   so a caller can insist the comparison happened: a helper that silently stopped
	///   comparing would leave every test calling it green and empty.
	@discardableResult
	static func roundTrip<D: PercentileParameterisable>(
		_ original: D, at probabilities: [Double], tolerance: Double = 1e-6, _ label: String
	) -> Int where D.T == Double {
		let constraints = probabilities.map { p in
			ParameterConstraint<Double>.quantile(p: p, value: original.quantile(p))
		}
		do {
			let recovered = try D.fitting(constraints)
			var compared = 0
			for p in checkPoints {
				let wanted = original.quantile(p)
				let got = recovered.quantile(p)
				let scale = Swift.max(1.0, abs(wanted))
				let gap = abs(got - wanted)
				let bound: Double = tolerance * scale
				#expect(gap < bound,
						"\(label) at p=\(p): recovered \(got), original \(wanted)")
				compared += 1
			}
			return compared
		} catch {
			Issue.record("\(label): fitting failed with \(error)")
			return 0
		}
	}

	// MARK: - One parameter

	@Test("A one-parameter family is recovered from one percentile")
	func singleParameterFamilies() {
		var families = 0
		for rate in [0.25, 1.0, 3.5, 40.0] {
			let compared = Self.roundTrip(DistributionExponential(rate), at: [0.5],
										  "exponential(rate: \(rate))")
			if compared > 0 { families += 1 }
		}
		for scale in [0.5, 1.0, 12.0] {
			let compared = Self.roundTrip(DistributionRayleigh(scale: scale), at: [0.75],
										  "rayleigh(scale: \(scale))")
			if compared > 0 { families += 1 }
		}
		#expect(families == 7, "only \(families) of 7 one-parameter fits round-tripped")
	}

	// MARK: - Two parameters

	@Test("A two-parameter family is recovered from two percentiles")
	func twoParameterFamilies() {
		var families = 0
		for (mean, sd) in [(0.0, 1.0), (100.0, 15.0), (-40.0, 2.5)] {
			Self.roundTrip(DistributionNormal(mean, sd), at: [0.1, 0.9], "normal(\(mean), \(sd))")
		}
		for (logMean, logSD) in [(0.0, 0.5), (2.0, 0.25), (-1.0, 1.0)] {
			Self.roundTrip(DistributionLogNormal(logMean, logSD), at: [0.1, 0.9],
						   "lognormal(\(logMean), \(logSD))")
		}
		for (shape, scale) in [(1.5, 2.0), (3.0, 10.0), (0.8, 0.5)] {
			Self.roundTrip(DistributionWeibull(shape: shape, scale: scale), at: [0.25, 0.75],
						   "weibull(\(shape), \(scale))")
		}
		for (mean, sd) in [(0.0, 1.0), (12.0, 3.0)] {
			Self.roundTrip(DistributionLogistic(mean, sd), at: [0.2, 0.8], "logistic(\(mean), \(sd))")
		}
		for (scale, shape) in [(1.0, 2.5), (5.0, 1.5)] {
			let compared = Self.roundTrip(DistributionPareto(scale: scale, shape: shape),
										  at: [0.3, 0.8], "pareto(\(scale), \(shape))")
			if compared > 0 { families += 1 }
		}
		#expect(families == 2, "only \(families) of 2 Pareto fits round-tripped")
	}

	@Test("Families with no moments are still fitted from percentiles")
	func momentlessFamiliesFitFromQuantiles() throws {
		// A Cauchy has no mean and no variance, which is why `PsiCauchyAlt` offers
		// only percentile pairs. The fit must work anyway — the solve never needs a
		// moment unless a constraint asks for one.
		for (location, scale) in [(0.0, 1.0), (7.0, 0.5)] {
			let original = try #require(DistributionCauchy(location: location, scale: scale))
			Self.roundTrip(original, at: [0.25, 0.75], "cauchy(\(location), \(scale))")
		}
		for (location, scale) in [(0.0, 1.0), (-3.0, 2.0)] {
			let original = try #require(DistributionLaplace(location: location, scale: scale))
			Self.roundTrip(original, at: [0.1, 0.9], "laplace(\(location), \(scale))")
		}
	}

	@Test("The choice of which two percentiles are stated does not change the answer")
	func theStatedPercentilesDoNotMatter() {
		var pairs = 0
		// A two-parameter family is determined by *any* two distinct quantiles. If the
		// recovered distribution depended on which two were chosen, the solve would be
		// finding a local root rather than the root.
		let original = DistributionNormal(100, 15)
		for pair in [[0.01, 0.99], [0.1, 0.9], [0.25, 0.75], [0.4, 0.6], [0.05, 0.5]] {
			let compared = Self.roundTrip(original, at: pair, "normal(100, 15) via \(pair)")
			if compared > 0 { pairs += 1 }
		}
		#expect(pairs == 5, "only \(pairs) of 5 percentile pairs recovered the distribution")
	}

	// MARK: - Moment and named-parameter constraints

	@Test("Moments can stand in for percentiles")
	func momentConstraintsAreAccepted() throws {
		// `PsiNormalAlt` accepts "percentile and mean" and "percentile and stdev" as
		// well as two percentiles, so the solve has to mix constraint kinds freely.
		let original = DistributionNormal(50, 8)
		let byMean = try DistributionNormal.fitting([
			.mean(50),
			.quantile(p: 0.9, value: original.quantile(0.9)),
		])
		#expect(abs(byMean.mean - 50) < 1e-8, "mean came back \(byMean.mean)")
		#expect(abs(byMean.stdDev - 8) < 1e-6, "stdDev came back \(byMean.stdDev)")

		let byDeviation = try DistributionNormal.fitting([
			.standardDeviation(8),
			.quantile(p: 0.1, value: original.quantile(0.1)),
		])
		#expect(abs(byDeviation.mean - 50) < 1e-6)
		#expect(abs(byDeviation.stdDev - 8) < 1e-8)
	}

	@Test("A named parameter can be given directly alongside a percentile")
	func namedParameterConstraintsAreAccepted() throws {
		// The mixing `PsiTriangularAlt` and `PsiUniformAlt` require: some arguments are
		// native parameters, some are percentiles, and the solve should not care which.
		let original = DistributionNormal(20, 4)
		let fitted = try DistributionNormal.fitting([
			.parameter(name: "mean", value: 20),
			.quantile(p: 0.95, value: original.quantile(0.95)),
		])
		#expect(abs(fitted.mean - 20) < 1e-9)
		#expect(abs(fitted.stdDev - 4) < 1e-6, "stdDev came back \(fitted.stdDev)")
	}

	@Test("A lognormal's mean constraint is its mean, not its median")
	func lognormalMeanIsNotItsMedian() throws {
		// exp(μ + σ²/2), not exp(μ). Getting this wrong would still fit *something* —
		// the solve would converge on a distribution whose median is the stated mean —
		// so it is worth a test that names the difference.
		let fitted = try DistributionLogNormal.fitting([
			.mean(10),
			.quantile(p: 0.5, value: 8),
		])
		// The median is what was stated as a quantile.
		#expect(abs(fitted.quantile(0.5) - 8) < 1e-6, "median \(fitted.quantile(0.5))")
		// And the mean exceeds it, as a right-skewed distribution's must.
		let variance: Double = fitted.logStdDev * fitted.logStdDev
        let realisedMean: Double = Foundation.exp(fitted.logMean + variance / 2)
		#expect(abs(realisedMean - 10) < 1e-6, "mean \(realisedMean)")
		#expect(realisedMean > fitted.quantile(0.5))
	}

	// MARK: - Refusals

	@Test("A constraint count that cannot determine the family is refused by name")
	func wrongConstraintCountsAreRefused() {
		#expect(throws: ParameterFitError.underdetermined(constraints: 1, parameters: 2)) {
			_ = try DistributionNormal.fitting([.quantile(p: 0.5, value: 1)])
		}
		#expect(throws: ParameterFitError.overdetermined(constraints: 3, parameters: 2)) {
			_ = try DistributionNormal.fitting([
				.quantile(p: 0.1, value: 1), .quantile(p: 0.5, value: 2), .quantile(p: 0.9, value: 3),
			])
		}
	}

	@Test("Malformed constraints report themselves rather than failing to converge")
	func malformedConstraintsAreRefused() {
		// Each of these would otherwise surface as `noSolution` after two hundred
		// iterations, which tells a caller nothing about what they got wrong.
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionNormal.fitting([
				.quantile(p: 0, value: 1), .quantile(p: 0.9, value: 3),
			])
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionNormal.fitting([
				.quantile(p: 0.5, value: 1), .quantile(p: 0.5, value: 3),
			])
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionNormal.fitting([
				.standardDeviation(-1), .quantile(p: 0.9, value: 3),
			])
		}
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionNormal.fitting([
				.parameter(name: "lambda", value: 1), .quantile(p: 0.9, value: 3),
			])
		}
	}

	@Test("A family with no closed-form moment says so instead of inventing one")
	func unsupportedMomentsAreReported() throws {
		// A Cauchy has no mean. Answering a `.mean` constraint would mean integrating
		// something that does not converge.
		//
		// The error must be the *specific* one. `fitting` tries several starting
		// points, and an earlier version collected every failure into `noSolution` —
		// so this arrived as "the solve did not converge", which sends a caller to
		// look at their numbers instead of at their constraint. Asserting only
		// `ParameterFitError.self` passed either way, which is how the swallowing
		// survived being tested.
		var caught: ParameterFitError?
		do {
			_ = try DistributionCauchy.fitting([.mean(0), .quantile(p: 0.75, value: 1)])
		} catch let error as ParameterFitError {
			caught = error
		}
		let reported = try #require(caught, "no error was thrown at all")
		guard case .unsupportedConstraint(let detail) = reported else {
			Issue.record("expected .unsupportedConstraint, got \(reported)")
			return
		}
		#expect(detail.contains("mean"), "the message does not name the constraint: \(detail)")
	}

	@Test("Constraints no distribution in the family satisfies do not converge on one")
	func impossibleConstraintsFail() {
		// A quantile function increases in p, so a lower percentile above a higher one
		// describes nothing. The fit must fail rather than return whichever
		// distribution the solve wandered into.
		#expect(throws: ParameterFitError.self) {
			_ = try DistributionNormal.fitting([
				.quantile(p: 0.1, value: 100), .quantile(p: 0.9, value: 5),
			])
		}
	}
}
