//
//  MetalogDistributionTests.swift
//  BusinessMath
//
//  The metalog certifies itself, twice over.
//
//  With as many terms as fitted points the quantile function passes through **every
//  one of them exactly**. That is not a tolerance anyone chose — it is what an
//  exactly-determined linear system means — so it is the sharpest possible oracle and
//  it needs no reference implementation.
//
//  The second self-check is feasibility. A linear combination of the basis functions
//  is a distribution only if it increases in `p`, and least squares does not enforce
//  that. A metalog with too many terms for its data routinely doubles back, which is
//  not a distribution at all; the initialiser must refuse rather than return
//  something that samples happily and is wrong.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Metalog distribution")
struct MetalogDistributionTests {

	// MARK: - The exactness the family exists for

	@Test("With one term per point, every fitted point comes back exactly")
	func exactFitReproducesEveryPoint() throws {
		let sets: [(name: String, p: [Double], x: [Double])] = [
			("threePoint", [0.1, 0.5, 0.9], [15, 40, 100]),
			("fourPoint", [0.05, 0.25, 0.75, 0.95], [2.0, 8.0, 22.0, 61.0]),
			("fivePoint", [0.05, 0.25, 0.5, 0.75, 0.95], [10, 22, 30, 41, 78]),
			("negativeValues", [0.1, 0.5, 0.9], [-90, -30, -5]),
			("straddlingZero", [0.1, 0.25, 0.5, 0.75, 0.9], [-40, -12, 3, 25, 70]),
		]
		for entry in sets {
			let fitted = try DistributionMetalog(fittingProbabilities: entry.p, values: entry.x)
			#expect(fitted.terms == entry.p.count,
					"\(entry.name): fitted \(fitted.terms) terms for \(entry.p.count) points")
			for (index, probability) in entry.p.enumerated() {
				let scale = Swift.max(1.0, abs(entry.x[index]))
				// Exact, not close: an exactly-determined system has one solution and
				// the quantile is that solution evaluated at the same probability.
				#expect(abs(fitted.quantile(probability) - entry.x[index]) < 1e-8 * scale,
						"\(entry.name) at p=\(probability): \(fitted.quantile(probability)), fitted \(entry.x[index])")
			}
		}
	}

	@Test("Two terms give the logistic distribution exactly")
	func twoTermsIsTheLogistic() throws {
		// The smallest metalog is a known family, which is worth pinning because it
		// is the one point where the basis can be checked against something with an
		// independent closed form: Q(p) = μ + s·ln(p/(1−p)).
		let location = 12.0, scale = 3.0
		let fitted = try DistributionMetalog(coefficients: [location, scale])
		for p in [0.01, 0.1, 0.3, 0.5, 0.7, 0.9, 0.99] {
			let logistic: Double = location + scale * Foundation.log(p / (1 - p))
			#expect(abs(fitted.quantile(p) - logistic) < 1e-10,
					"at p=\(p): metalog \(fitted.quantile(p)), logistic \(logistic)")
		}
		// And the median is the location, with no skew term present to move it.
		#expect(abs(fitted.quantile(0.5) - location) < 1e-12)
	}

	// MARK: - Feasibility

	@Test("A fit that does not increase is refused, not returned")
	func infeasibleFitsAreRefused() {
		// Coefficients whose quantile function turns back. Sampling from this would
		// produce values in the wrong order for the probabilities that generated
		// them, and every moment computed from it would be meaningless — but nothing
		// about the arithmetic would fail.
		#expect(throws: MetalogError.infeasible) {
			_ = try DistributionMetalog(coefficients: [0, -1])
		}
		#expect(throws: MetalogError.infeasible) {
			_ = try DistributionMetalog(coefficients: [0, 1, 0, -50])
		}
	}

	@Test("Feasibility is checked near the ends, where a metalog actually turns back")
	func feasibilityChecksTheTails() throws {
		// `M(y) = −0.001·ln(y/(1−y)) + 10·(y − 0.5)`, whose derivative is
		// `−0.001/(y(1−y)) + 10`. That is positive wherever `y(1−y) > 1e-4`, so the
		// function increases across the whole of a 1,000-point uniform grid — whose
		// closest approach to an end is y = 0.001, where y(1−y) ≈ 1e-3 — and reverses
		// below roughly y = 1e-4.
		//
		// This is the shape a tail-blind feasibility check waves through: monotone
		// everywhere anyone looked, and not a distribution. Sampling would eventually
		// land in the reversed region and return values in the wrong order for the
		// probabilities that produced them.
		let reversesOnlyInTheTail: [Double] = [0, -0.001, 0, 10]

		// Established rather than assumed: monotone on the uniform grid …
		var previous = -Double.infinity
		var monotoneOnCoarseGrid = true
		for step in 1..<1_000 {
			let y: Double = Double(step) / 1_000
			let value = DistributionMetalog.evaluate(coefficients: reversesOnlyInTheTail, at: y)
			if value < previous { monotoneOnCoarseGrid = false }
			previous = value
		}
		#expect(monotoneOnCoarseGrid,
				"the fixture is not monotone on the coarse grid, so it does not test the refinement")

		// … and not monotone once the tail is included.
		let deepTail = DistributionMetalog.evaluate(coefficients: reversesOnlyInTheTail, at: 1e-6)
		let shallowTail = DistributionMetalog.evaluate(coefficients: reversesOnlyInTheTail, at: 1e-4)
		#expect(deepTail > shallowTail,
				"the fixture does not reverse in the tail either, so it tests nothing")

		// Therefore it must be refused.
		#expect(throws: MetalogError.infeasible) {
			_ = try DistributionMetalog(coefficients: reversesOnlyInTheTail)
		}
	}

	@Test("The feasibility check and the initialiser always agree")
	func feasibilityCheckMatchesTheInitialiser() {
		// Whatever the check decides, the initialiser must do — otherwise a caller
		// could ask whether a fit is usable and get a different answer from trying.
		let candidates: [[Double]] = [
			[0, 1], [0, -1], [5, 2, 0, 1], [0, 1, 0, -50], [0, -0.001, 0, 10],
			[10, 3, 1, 2], [0, 1, 5, 0], [0, 1, -5, 0], [1, 0.5, 0, 0.2, 0.1],
		]
		for coefficients in candidates {
			let feasible = DistributionMetalog.isFeasible(coefficients: coefficients, boundedness: .unbounded)
			let built = try? DistributionMetalog(coefficients: coefficients)
			#expect((built != nil) == feasible,
					"\(coefficients): isFeasible says \(feasible) but the initialiser \(built == nil ? "threw" : "succeeded")")
		}
	}

	// MARK: - Bounded variants

	@Test("Bounded variants keep their bounds and still reproduce their points")
	func boundedVariantsRespectTheirBounds() throws {
		let probabilities: [Double] = [0.1, 0.5, 0.9]

		// Semi-bounded below: a cost that cannot go negative.
		let cost = try DistributionMetalog(fittingProbabilities: probabilities,
										   values: [120, 200, 450],
										   boundedness: .boundedBelow(lower: 0))
		for (index, p) in probabilities.enumerated() {
			let expected: [Double] = [120, 200, 450]
			#expect(abs(cost.quantile(p) - expected[index]) < 1e-6 * expected[index],
					"boundedBelow at p=\(p): \(cost.quantile(p))")
		}
		for p in [1e-9, 1e-5, 0.001, 0.5, 0.999, 1 - 1e-9] {
			#expect(cost.quantile(p) > 0, "boundedBelow produced \(cost.quantile(p)) at p=\(p)")
		}

		// Bounded both ways: a market share.
		let share = try DistributionMetalog(fittingProbabilities: probabilities,
											values: [0.05, 0.18, 0.42],
											boundedness: .bounded(lower: 0, upper: 1))
		for (index, p) in probabilities.enumerated() {
			let expected: [Double] = [0.05, 0.18, 0.42]
			#expect(abs(share.quantile(p) - expected[index]) < 1e-6,
					"bounded at p=\(p): \(share.quantile(p))")
		}
		for p in [1e-9, 0.001, 0.5, 0.999, 1 - 1e-9] {
			let value = share.quantile(p)
			#expect(value > 0 && value < 1, "bounded produced \(value) at p=\(p)")
		}
	}

	@Test("A value outside the declared bounds is refused")
	func valuesOutsideBoundsAreRefused() {
		#expect(throws: MetalogError.valueOutsideBounds) {
			_ = try DistributionMetalog(fittingProbabilities: [0.1, 0.5, 0.9],
										values: [-5, 200, 450],
										boundedness: .boundedBelow(lower: 0))
		}
		#expect(throws: MetalogError.valueOutsideBounds) {
			_ = try DistributionMetalog(fittingProbabilities: [0.1, 0.5, 0.9],
										values: [0.05, 0.18, 1.4],
										boundedness: .bounded(lower: 0, upper: 1))
		}
	}

	// MARK: - The distribution contract

	@Test("The quantile is monotone and the CDF inverts it")
	func quantileAndCDFAreInverse() throws {
		let fitted = try DistributionMetalog(fittingProbabilities: [0.05, 0.25, 0.5, 0.75, 0.95],
											 values: [10, 22, 30, 41, 78])
		var previous = -Double.infinity
		for step in 1..<300 {
			let p: Double = Double(step) / 300
			let x = fitted.quantile(p)
			#expect(x >= previous, "quantile fell from \(previous) to \(x) at p=\(p)")
			previous = x
			// The CDF has no closed form and bisects, so the tolerance is the
			// bisection's, not the algebra's.
			#expect(abs(fitted.cdf(x) - p) < 1e-7,
					"cdf(quantile(\(p))) = \(fitted.cdf(x))")
		}
	}

	@Test("Fewer terms than points is a least-squares fit that still increases")
	func underdeterminedFitsAreLeastSquares() throws {
		// Nine noisy points, four terms: no longer exact, and that is the point —
		// this is the mode to use when the quantiles come from data rather than from
		// elicitation. What must survive is feasibility.
		let probabilities: [Double] = (1...9).map { Double($0) / 10 }
		let values: [Double] = [8.4, 14.1, 19.6, 24.2, 30.5, 36.1, 43.8, 54.0, 71.2]
		let fitted = try DistributionMetalog(fittingProbabilities: probabilities,
											 values: values, terms: 4)
		#expect(fitted.terms == 4)

		var previous = -Double.infinity
		for step in 1..<200 {
			let p: Double = Double(step) / 200
			let x = fitted.quantile(p)
			#expect(x >= previous, "least-squares fit is not monotone at p=\(p)")
			previous = x
		}
		// Close to the data without interpolating it, which is what least squares
		// buys and what an exact fit to noisy points would not.
		for (index, p) in probabilities.enumerated() {
			#expect(abs(fitted.quantile(p) - values[index]) < 3.0,
					"at p=\(p): fitted \(fitted.quantile(p)), data \(values[index])")
		}
	}

	@Test("Sampling follows the fitted quantiles")
	func samplingFollowsTheFit() throws {
		let fitted = try DistributionMetalog(fittingProbabilities: [0.05, 0.25, 0.5, 0.75, 0.95],
											 values: [10, 22, 30, 41, 78])
		var generator = DeterministicRNG(seed: 47_301)
		var draws: [Double] = []
		draws.reserveCapacity(200_000)
		for _ in 0..<200_000 { draws.append(fitted.next(using: &generator)) }
		draws.sort()

		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let empirical = quantile(sorted: draws, p: p)
			let exact = fitted.quantile(p)
			#expect(abs(empirical - exact) / abs(exact) < 0.03,
					"at p=\(p): sampled \(empirical), fitted \(exact)")
		}
	}

	// MARK: - Refusals

	@Test("Arguments that cannot determine a metalog are refused by name")
	func invalidArgumentsAreRefused() {
		#expect(throws: MetalogError.dimensionMismatch) {
			_ = try DistributionMetalog(fittingProbabilities: [0.1, 0.5], values: [1, 2, 3])
		}
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(fittingProbabilities: [0.0, 0.5, 0.9], values: [1, 2, 3])
		}
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(fittingProbabilities: [1.0, 0.5, 0.9], values: [1, 2, 3])
		}
		// Repeated probabilities make two rows of the design identical, so the fit is
		// singular rather than merely ill-conditioned.
		#expect(throws: MetalogError.invalidProbability) {
			_ = try DistributionMetalog(fittingProbabilities: [0.5, 0.5, 0.9], values: [1, 2, 3])
		}
		// More terms than data is underdetermined: infinitely many exact fits exist.
		#expect(throws: MetalogError.insufficientData(pairs: 3, terms: 5)) {
			_ = try DistributionMetalog(fittingProbabilities: [0.1, 0.5, 0.9], values: [1, 2, 3], terms: 5)
		}
	}
}
