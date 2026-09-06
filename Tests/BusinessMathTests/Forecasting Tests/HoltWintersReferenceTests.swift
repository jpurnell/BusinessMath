//
//  HoltWintersReferenceTests.swift
//  BusinessMath
//
//  An oracle for the Holt-Winters forecaster, which had none.
//
//  ## The oracle is the mathematics, not another implementation
//
//  statsmodels was tried first and rejected. Given the same data, the same smoothing
//  parameters and the same initial level, trend and seasonals, it and this recursion
//  disagree by about 0.5%. Both are self-consistent additive Holt-Winters; they differ in
//  how the initial state lines up with the first observation, and the literature carries
//  several conventions for that. Asserting against it would report a convention as a
//  defect — and the gap is small enough to look like a tolerance problem, which is worse
//  than an obvious mismatch.
//
//  What is used instead is stronger and needs no second implementation. Construct a
//  series that additive Holt-Winters **must** reproduce exactly — constant level, linear
//  trend, fixed seasonal, no noise — and the mathematics fixes the answer. Every residual
//  must be zero and every forecast must equal the continuation of the generating formula.
//  Nothing is estimated that is not exactly present in the data, so no convention enters.
//
//  This is §2.2 of the coverage proposal applied to a forecaster: where the mathematics
//  determines the answer, the mathematics is the better reference.
//
//  ## It found two defects
//
//  Both in the implementation as it stood, both now fixed in the same commit:
//
//  1. **The fitted value multiplied by the seasonal** in an otherwise wholly additive
//     model — `(level + trend) * seasonal` where `+` belongs. The seasonals here are
//     deviations about zero, not scaling factors, so a level of 150 and a seasonal of −10
//     gave a fitted value of −1500 instead of 140. On a noiseless series the model fits
//     perfectly and the residuals still came out in the hundreds. They feed the mean
//     squared error behind `predictWithConfidence`, so every interval rested on them.
//
//  2. **The forecast ignored where the training series ended**, indexing the seasonal
//     array from zero regardless. That is right only when the training length is a whole
//     number of cycles — which is true of this type's own documented example, and was
//     true of every case in `HoltWintersTests`. Train on 17 points instead of 16 and the
//     forecast came back phase-shifted, silently.
//
//  The second is the reason this file tests every residue of `n mod m` rather than one
//  convenient length. A fixture that only used tidy inputs would have agreed with the
//  broken code.
//
//  ## Exact recovery holds under two conditions, both found by measurement
//
//  The initialisation lands exactly on the representation the recursion converges to only
//  when the series has **no trend** and its length is **a whole number of cycles**. Both
//  were discovered by asserting exactness too broadly and watching which cases failed.
//
//  *No trend*, because `seasonal[i]` initialises to
//  `pattern[i] − mean(pattern) + slope·(i − (m−1)/2)`, and that trend-dependent term is
//  not of the form the exact representation needs.
//
//  *A whole number of cycles*, because otherwise the phases hold unequal counts. At
//  n = 17 with m = 4, phase 0 has five observations and the rest four, so the overall
//  mean is pulled off `base` and every seasonal inherits the offset. The first residual
//  came out at exactly 0.588 — arithmetic, not noise.
//
//  Away from those conditions it still converges, geometrically: the largest forecast
//  error on a quarterly trended series falls 1.68 → 0.33 → 0.025 → 6.7e-05 → 0.0 as the
//  series grows 24 → 48 → 96 → 200 → 400. So every fixture case is either exactly
//  initialised or long enough to have settled, and a separate test asserts the
//  convergence itself.
//
//  Asserting exactness where it does not hold would have meant asserting something untrue
//  of correct code — which is how a suite acquires tolerances that get quietly loosened
//  later, until they assert nothing.
//
//  Values from Tests/BusinessMathTests/Fixtures/holtWinters.json.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Holt-Winters against exact recovery")
struct HoltWintersReferenceTests {

	// MARK: - Fixture

	private struct Fixture: Decodable {
		let name: String
		let reference: String
		let note: String
		let cases: [Case]
	}

	private struct Case: Decodable {
		let name: String
		let note: String
		let kind: String
		let alpha: Double
		let beta: Double
		let gamma: Double
		let seasonalPeriods: Int
		let base: Double
		let slope: Double
		let pattern: [Double]
		let values: [Double]
		let horizon: Int
		let expectedForecast: [Double]
	}

	private static func loadFixture() throws -> Fixture {
		guard let url = Bundle.module.url(forResource: "holtWinters",
										  withExtension: "json",
										  subdirectory: "Fixtures")
			?? Bundle.module.url(forResource: "holtWinters", withExtension: "json") else {
			struct Missing: Error { let name: String }
			throw Missing(name: "holtWinters")
		}
		return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
	}

	private static func trained(_ entry: Case) throws -> HoltWintersModel<Double> {
		var model = HoltWintersModel<Double>(alpha: entry.alpha,
											 beta: entry.beta,
											 gamma: entry.gamma,
											 seasonalPeriods: entry.seasonalPeriods)
		try model.train(values: entry.values)
		return model
	}

	// MARK: - The fixture itself

	@Test("The fixture covers every phase the series can end on")
	func fixtureIsWellFormed() throws {
		let fixture = try Self.loadFixture()
		#expect(fixture.cases.count >= 8, "only \(fixture.cases.count) series")

		// The whole point of the second defect is that it only appears when the training
		// length is not a whole number of cycles. If the fixture ever drifts back to
		// tidy lengths only, it stops testing for it.
		let residues = Set(fixture.cases.map { $0.values.count % $0.seasonalPeriods })
		#expect(residues.count >= 3,
				"only \(residues.sorted()) covered for n mod m — the phase bug hides at the others")
		#expect(residues.contains(0), "the boundary case should be covered too")

		// And both signs of trend, since nothing in the algebra prefers a positive one.
		#expect(fixture.cases.contains { $0.slope > 0 })
		#expect(fixture.cases.contains { $0.slope < 0 })
		#expect(fixture.cases.contains { $0.slope == 0 })

		for entry in fixture.cases {
			#expect(entry.expectedForecast.count == entry.horizon)
			#expect(entry.values.count >= 2 * entry.seasonalPeriods)
		}
	}

	// MARK: - Exact recovery

	@Test("A noiseless series is forecast exactly")
	func forecastsRecoverTheGeneratingFormula() throws {
		let fixture = try Self.loadFixture()
		var compared = 0

		for entry in fixture.cases {
			let model = try Self.trained(entry)
			let forecast = model.predictValues(periods: entry.horizon)

			#expect(forecast.count == entry.horizon,
					"\(entry.name): got \(forecast.count) forecasts, expected \(entry.horizon)")
			guard forecast.count == entry.horizon else { continue }

			for (h, expected) in entry.expectedForecast.enumerated() {
				// The series is exactly representable by the model, so the only error
				// available is accumulated rounding through the recursion.
				let scale = Swift.max(abs(expected), 1.0)
				#expect(abs(forecast[h] - expected) < 1e-8 * scale,
						"\(entry.name) h=\(h + 1): got \(forecast[h]), the series continues at \(expected)")
				compared += 1
			}
		}
		#expect(compared >= 60, "only \(compared) forecast points compared")
	}

	@Test("The seasonal phase continues from where training stopped")
	func forecastPhaseIsCorrect() throws {
		// The second defect, isolated. Four series differing only in length, each one
		// point longer than the last, so their forecasts must be rotations of one
		// another. The broken code returned the same four numbers for all of them.
		let fixture = try Self.loadFixture()
		let family = fixture.cases
			.filter { $0.name.hasPrefix("levelOnly") }
			.sorted { $0.values.count < $1.values.count }
		#expect(family.count == 4, "expected the four levelOnly series, got \(family.count)")
		guard family.count == 4 else { return }

		var firstForecasts: [Double] = []
		for entry in family {
			let model = try Self.trained(entry)
			let forecast = model.predictValues(periods: 1)
			#expect(forecast.count == 1)
			guard let value = forecast.first else { continue }
			firstForecasts.append(value)

			// Each must match its own continuation, not the boundary case's.
			#expect(abs(value - entry.expectedForecast[0]) < 1e-8,
					"\(entry.name): first forecast \(value), series continues at \(entry.expectedForecast[0])")
		}

		// And they must genuinely differ from one another — the four phases of the cycle.
		// If a future change reintroduced a fixed index, every one of these would agree
		// and this is what would notice.
		let distinct = Set(firstForecasts.map { ($0 * 1e6).rounded() })
		#expect(distinct.count == 4,
				"the four phases produced \(distinct.count) distinct forecasts: \(firstForecasts)")
	}

	@Test("A perfectly fitted series leaves no residual")
	func residualsVanishOnAnExactFit() throws {
		// The first defect, isolated. These series are exactly representable, and the
		// initialisation happens to be exact for them too, so a correct implementation
		// leaves residuals at zero. The multiplicative fitted value produced residuals in
		// the hundreds while every other test kept passing.
		//
		let fixture = try Self.loadFixture()

		for entry in fixture.cases {
			let model = try Self.trained(entry)
			#expect(model.residuals.count == entry.values.count,
					"\(entry.name): \(model.residuals.count) residuals for \(entry.values.count) observations")

			let onBoundary = entry.values.count % entry.seasonalPeriods == 0
			if entry.slope == 0 && onBoundary {
				// Both conditions met: the initialisation is exactly the fixed point, so
				// every residual is zero from the very first observation. Not small —
				// zero.
				let worst = model.residuals.map { abs($0) }.max() ?? 0
				#expect(worst < 1e-8,
						"\(entry.name): largest residual \(worst) on a series fitted exactly from the start")
			} else {
				// Otherwise the initialisation is off the exact manifold, so the early
				// residuals are real and decay. What must be zero is the *end* of the
				// series, once the recursion has converged.
				let tail = model.residuals.suffix(entry.seasonalPeriods * 2)
				let worst = tail.map { abs($0) }.max() ?? 0
				#expect(worst < 1e-6,
						"\(entry.name): largest residual over the last two cycles was \(worst), so it has not converged")

				// And the decay must be real, not the series being too short to see.
				let early = model.residuals.prefix(entry.seasonalPeriods)
					.map { abs($0) }.max() ?? 0
				#expect(early > worst,
						"\(entry.name): residuals did not decay — early \(early), late \(worst)")
			}
		}
	}

	@Test("A trended series converges as it lengthens")
	func trendedSeriesConverge() throws {
		// The claim the fixture's long trended cases rest on, asserted directly rather
		// than assumed. If convergence ever stopped — a sign error in the trend update,
		// say — the long cases would fail with no indication of why, and this says why.
		let pattern = [6.0, -2.0, -8.0, 4.0]
		let base = 50.0, slope = 2.0

		var previous = Double.infinity
		for n in [24, 48, 96, 200] {
			var model = HoltWintersModel<Double>(alpha: 0.6, beta: 0.3, gamma: 0.4,
												 seasonalPeriods: 4)
			let values = (0..<n).map { base + slope * Double($0) + pattern[$0 % 4] }
			try model.train(values: values)
			let forecast = model.predictValues(periods: 4)
			let truth = (0..<4).map { base + slope * Double(n + $0) + pattern[(n + $0) % 4] }
			let worst = zip(forecast, truth).map { abs($0 - $1) }.max() ?? .infinity

			#expect(worst < previous,
					"n=\(n): error \(worst) did not improve on \(previous)")
			previous = worst
		}
		#expect(previous < 1e-3, "at n = 200 the error is still \(previous)")
	}

	@Test("Residuals scale with the data, not with its magnitude squared")
	func residualsAreAdditive() throws {
		// A second angle on the same defect, and the one that would catch it even if a
		// future series were not fitted exactly. Multiplying a level by a seasonal
		// deviation produces a residual on the order of level × seasonal; adding them
		// produces one on the order of the noise. Scaling the whole series by ten should
		// scale the residuals by ten — under the multiplicative form they would grow by
		// a hundred.
		let pattern = [10.0, -5.0, -10.0, 5.0]
		func series(_ scale: Double) -> [Double] {
			(0..<16).map { scale * (100.0 + pattern[$0 % 4]) + Double(($0 * 37) % 7) - 3 }
		}

		var small = HoltWintersModel<Double>(alpha: 0.5, beta: 0.1, gamma: 0.3, seasonalPeriods: 4)
		try small.train(values: series(1))
		var large = HoltWintersModel<Double>(alpha: 0.5, beta: 0.1, gamma: 0.3, seasonalPeriods: 4)
		try large.train(values: series(10))

		let smallWorst = small.residuals.map { abs($0) }.max() ?? 0
		let largeWorst = large.residuals.map { abs($0) }.max() ?? 0
		#expect(smallWorst > 0, "the noise term should leave some residual to measure")

		// The added noise does not scale, so the ratio is bounded above by ten rather
		// than equal to it — but a hundredfold growth would be unmistakable.
		let ratio = largeWorst / Swift.max(smallWorst, 1e-12)
		#expect(ratio < 20,
				"residuals grew \(ratio)× for a 10× series — that is the multiplicative form")
	}

	// MARK: - Structure

	@Test("Training rejects a series shorter than two cycles")
	func rejectsShortSeries() {
		var model = HoltWintersModel<Double>(alpha: 0.5, beta: 0.1, gamma: 0.1,
											 seasonalPeriods: 4)
		// Seven points cannot initialise a four-period seasonal from two cycles.
		#expect(throws: (any Error).self) {
			try model.train(values: [1, 2, 3, 4, 5, 6, 7])
		}
	}

	@Test("An untrained model forecasts nothing rather than guessing")
	func untrainedReturnsEmpty() {
		let model = HoltWintersModel<Double>(alpha: 0.5, beta: 0.1, gamma: 0.1,
											 seasonalPeriods: 4)
		#expect(model.predictValues(periods: 4).isEmpty,
				"an untrained model has no level to forecast from")
	}

	@Test("A zero horizon returns nothing")
	func zeroHorizon() throws {
		let fixture = try Self.loadFixture()
		guard let entry = fixture.cases.first else { return }
		let model = try Self.trained(entry)
		#expect(model.predictValues(periods: 0).isEmpty)
		#expect(model.predictValues(periods: -1).isEmpty)
	}
}
