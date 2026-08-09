//
//  ProjectionResultsPercentileTests.swift
//  BusinessMath
//
//  Pins ``ProjectionResults/percentile(_:)`` to the exact empirical quantile.
//

import Foundation
import Testing
@testable import BusinessMath

/// `ProjectionResults.percentile(_:)` used to snap its argument to the nearest
/// of five stored summary percentiles: anything in `(0.15, 0.375]` returned p25
/// verbatim, anything in `(0.375, 0.625]` returned p50 verbatim, and so on. So
/// `percentile(0.30)` was p25 and `percentile(0.40)` was the median. It now
/// computes the R-7 quantile of the retained sample, like every other
/// percentile in the library.
@Suite("Projection Results Percentile Accuracy")
struct ProjectionResultsPercentileTests {

	private func results(iterations: Int = 20_000) -> (ProjectionResults<Double>, [Period]) {
		let driver = ProbabilisticDriver<Double>.normal(name: "Sales", mean: 1000.0, stdDev: 100.0)
		let periods = Period.year(2025).quarters()
		let projection = DriverProjection(driver: driver, periods: periods)
		return (projection.projectMonteCarlo(iterations: iterations), periods)
	}

	@Test("percentile(_:) equals the R-7 quantile of the retained sample")
	func matchesCanonicalQuantile() {
		let (res, periods) = results()
		for p in [0.01, 0.05, 0.10, 0.30, 0.40, 0.50, 0.60, 0.90, 0.95, 0.99] {
			let series = res.percentile(p)
			for period in periods {
				let expected = res.percentiles[period]!.percentile(p)
				#expect(series[period]! == expected,
						"ProjectionResults.percentile(\(p)) is not the empirical quantile")
			}
		}
	}

	@Test("percentile(0.30) is no longer p25 and percentile(0.40) is no longer the median")
	func noLongerSnapsToSummaryPercentiles() {
		// The defect this pins: with a continuous driver the 30th percentile
		// lies strictly between p25 and p50, and the 40th strictly between p25
		// and p50 as well — neither can equal a summary percentile.
		let (res, periods) = results()
		for period in periods {
			let pctiles = res.percentiles[period]!
			let p30 = res.percentile(0.30)[period]!
			let p40 = res.percentile(0.40)[period]!

			#expect(p30 != pctiles.p25, "percentile(0.30) still snaps to p25")
			#expect(p30 > pctiles.p25 && p30 < pctiles.p50)

			#expect(p40 != pctiles.p50, "percentile(0.40) still snaps to p50")
			#expect(p40 > pctiles.p25 && p40 < pctiles.p50)
		}
	}

	@Test("percentile(_:) is monotone non-decreasing in p")
	func monotoneInP() {
		let (res, periods) = results(iterations: 5_000)
		for period in periods {
			var previous = -Double.infinity
			for i in 0...100 {
				let value = res.percentile(Double(i) / 100.0)[period]!
				#expect(value >= previous, "percentile is not monotone at p = \(Double(i) / 100.0)")
				previous = value
			}
		}
	}

	@Test("The five summary percentiles are still exactly reproduced")
	func summaryPercentilesStillAgree() {
		// p5/p25/p50/p75/p95 remain a documented part of the API; asking for
		// them by probability must return exactly the stored value.
		let (res, periods) = results()
		for period in periods {
			let pctiles = res.percentiles[period]!
			#expect(res.percentile(0.05)[period]! == pctiles.p5)
			#expect(res.percentile(0.25)[period]! == pctiles.p25)
			#expect(res.percentile(0.50)[period]! == pctiles.p50)
			#expect(res.percentile(0.75)[period]! == pctiles.p75)
			#expect(res.percentile(0.95)[period]! == pctiles.p95)
			#expect(res.median()[period]! == pctiles.p50)
		}
	}

	@Test("p outside [0, 1] clamps to the sample extremes")
	func clampsOutOfRange() {
		let (res, periods) = results(iterations: 2_000)
		for period in periods {
			let pctiles = res.percentiles[period]!
			#expect(res.percentile(-1.0)[period]! == pctiles.min)
			#expect(res.percentile(2.0)[period]! == pctiles.max)
		}
	}
}
