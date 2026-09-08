//
//  SurvivalTests.swift
//  BusinessMath
//
//  Kaplan–Meier with right censoring, and the two-group log-rank test.
//
//  The strongest oracle here costs nothing: **with no censoring, Kaplan–Meier is the
//  empirical survival function.** Every subject's outcome is observed, so the estimator
//  has nothing to estimate and must reduce to counting — `S(t) = #{times > t} / n`,
//  exactly. Any error in the product-limit recursion, the risk set, or the tie handling
//  breaks that identity, and it needs no reference implementation to check against.
//
//  Censoring is where the estimator earns its name, so case B carries it, checked against
//  the product-limit formula and Greenwood's variance computed outside this library.
//
//  Churn is default with a different noun, and a subscription that has not cancelled yet
//  is censored rather than absent. Dropping those rows — the usual mistake — biases every
//  survival estimate downward, because the longest-lived subjects are exactly the ones
//  still running when the data was cut.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Survival analysis")
struct SurvivalTests {

	// MARK: - The identity that needs no reference

	@Test("Without censoring Kaplan-Meier is the empirical survival function")
	func reducesToEmpiricalWithoutCensoring() throws {
		let times: [Double] = [1, 2, 3, 4, 5, 6]
		let events = [Bool](repeating: true, count: 6)
		let estimate = try #require(KaplanMeier(times: times, events: events))
		let curve = estimate.curve

		var compared = 0
		for point in curve.points {
			let survived = times.filter { $0 > point.time }.count
			let empirical: Double = Double(survived) / Double(times.count)
			#expect(Swift.abs(point.survival - empirical) < 1e-12,
					"S(\(point.time)) = \(point.survival), counting gives \(empirical)")
			compared += 1
		}
		#expect(compared == 6, "only \(compared) of 6 event times were compared")
	}

	@Test("The risk set shrinks by one at each uncensored event")
	func riskSetCountsDown() throws {
		let times: [Double] = [1, 2, 3, 4, 5, 6]
		let events = [Bool](repeating: true, count: 6)
		let curve = try #require(KaplanMeier(times: times, events: events)).curve
		var expected = 6
		for point in curve.points {
			#expect(point.atRisk == expected, "at t=\(point.time) the risk set was \(point.atRisk)")
			#expect(point.events == 1, "one event per time here, got \(point.events)")
			expected -= 1
		}
	}

	// MARK: - Censoring, against the product-limit formula

	@Test("A censored sample matches the product-limit estimate and Greenwood's errors")
	func censoredSample() throws {
		// Two of the eight are censored inside the follow-up and two at the end. The
		// censored subjects leave the risk set without contributing an event, which is
		// the entire content of the estimator.
		let times: [Double] = [6, 7, 10, 15, 19, 25, 25, 28]
		let events: [Bool] = [true, false, true, true, false, true, false, false]
		let curve = try #require(KaplanMeier(times: times, events: events)).curve

		// Computed outside the library from the product-limit and Greenwood formulas.
		let reference: [(time: Double, survival: Double, error: Double)] = [
			(6, 0.8750000000, 0.1169267933),
			(10, 0.7291666667, 0.1649762364),
			(15, 0.5833333333, 0.1855609613),
			(25, 0.3888888889, 0.2012691215),
		]
		#expect(curve.points.count == reference.count,
				"expected \(reference.count) event times, got \(curve.points.count)")
		var compared = 0
		for (point, row) in zip(curve.points, reference) {
			#expect(Swift.abs(point.time - row.time) < 1e-12, "time \(point.time)")
			#expect(Swift.abs(point.survival - row.survival) < 1e-9,
					"S(\(row.time)) = \(point.survival), reference \(row.survival)")
			#expect(Swift.abs(point.standardError - row.error) < 1e-9,
					"se(\(row.time)) = \(point.standardError), reference \(row.error)")
			compared += 1
		}
		#expect(compared == 4, "only \(compared) of 4 points were compared")
	}

	@Test("Censored observations stay in the risk set until they leave it")
	func censoringDoesNotDropSubjects() throws {
		// The subject censored at 7 is still at risk at 6, so the first event divides by
		// eight rather than by the seven that survive it. Dropping censored rows would
		// give 6/7 here instead of 7/8, and would bias every later step too.
		let times: [Double] = [6, 7, 10, 15, 19, 25, 25, 28]
		let events: [Bool] = [true, false, true, true, false, true, false, false]
		let curve = try #require(KaplanMeier(times: times, events: events)).curve
		let first = try #require(curve.points.first)
		#expect(first.atRisk == 8, "the first risk set was \(first.atRisk), not the whole sample")
		#expect(Swift.abs(first.survival - 0.875) < 1e-12, "7/8, got \(first.survival)")
	}

	// MARK: - Summaries

	@Test("Median survival is the first time the curve reaches a half")
	func medianSurvival() throws {
		let plain = try #require(KaplanMeier(times: [1, 2, 3, 4, 5, 6],
											 events: [Bool](repeating: true, count: 6)))
		let median = try #require(plain.curve.medianSurvival)
		#expect(Swift.abs(median - 3) < 1e-12, "median \(median), expected 3")

		let censored = try #require(KaplanMeier(times: [6, 7, 10, 15, 19, 25, 25, 28],
												events: [true, false, true, true,
														 false, true, false, false]))
		let late = try #require(censored.curve.medianSurvival)
		#expect(Swift.abs(late - 25) < 1e-12, "median \(late), expected 25")
	}

	@Test("A curve that never reaches a half has no median, rather than its last time")
	func medianUndefined() throws {
		// Heavy censoring: the curve stops at 0.75 and there is no time at which half
		// the subjects have failed. Reporting the last observed time would be a
		// statement the data does not support.
		let curve = try #require(KaplanMeier(times: [5, 10, 15, 20],
											 events: [true, false, false, false])).curve
		#expect(curve.medianSurvival == nil, "got \(String(describing: curve.medianSurvival))")
	}

	@Test("Restricted mean survival is the area under the curve")
	func restrictedMean() throws {
		// Uncensored 1...6: S is 1 on [0,1), 5/6 on [1,2) and so on, so the area to
		// t = 6 is 1 + (5+4+3+2+1)/6 = 3.5 exactly.
		let curve = try #require(KaplanMeier(times: [1, 2, 3, 4, 5, 6],
											 events: [Bool](repeating: true, count: 6))).curve
		let area = try #require(curve.restrictedMean(horizon: 6))
		#expect(Swift.abs(area - 3.5) < 1e-12, "RMST \(area), expected 3.5")
		// A horizon before the first event is just the horizon: nobody has failed.
		let early = try #require(curve.restrictedMean(horizon: 0.5))
		#expect(Swift.abs(early - 0.5) < 1e-12, "RMST \(early), expected 0.5")
	}

	// MARK: - Log-rank

	@Test("The log-rank statistic matches a reference computation")
	func logRank() throws {
		let firstTimes: [Double] = [6, 7, 10, 15]
		let firstEvents: [Bool] = [true, true, true, false]
		let secondTimes: [Double] = [8, 12, 20, 25]
		let secondEvents: [Bool] = [true, true, false, true]
		let test = try #require(LogRankTest(firstTimes: firstTimes, firstEvents: firstEvents,
											secondTimes: secondTimes, secondEvents: secondEvents))
		#expect(Swift.abs(test.observed - 3.0) < 1e-12, "observed \(test.observed)")
		#expect(Swift.abs(test.expected - 1.9119047619) < 1e-9, "expected \(test.expected)")
		#expect(Swift.abs(test.variance - 1.1446201814) < 1e-9, "variance \(test.variance)")
		#expect(Swift.abs(test.statistic - 1.0343616742) < 1e-8, "χ² \(test.statistic)")
		#expect(test.degreesOfFreedom == 1)
		// One degree of freedom and χ² near one is nowhere near significant.
		#expect(test.pValue > 0.25 && test.pValue < 0.35, "p \(test.pValue)")
	}

	@Test("Two identical groups produce no evidence of a difference")
	func identicalGroups() throws {
		let times: [Double] = [4, 8, 12, 16, 20]
		let events = [Bool](repeating: true, count: 5)
		let test = try #require(LogRankTest(firstTimes: times, firstEvents: events,
											secondTimes: times, secondEvents: events))
		#expect(Swift.abs(test.statistic) < 1e-12, "χ² \(test.statistic) for identical groups")
		#expect(test.pValue > 0.99, "p \(test.pValue)")
	}

	@Test("Cleanly separated groups produce strong evidence")
	func separatedGroups() throws {
		// Every failure in the first group precedes every failure in the second.
		let test = try #require(LogRankTest(
			firstTimes: [1, 2, 3, 4, 5], firstEvents: [Bool](repeating: true, count: 5),
			secondTimes: [20, 21, 22, 23, 24], secondEvents: [Bool](repeating: true, count: 5)))
		#expect(test.statistic > 8, "χ² \(test.statistic) should be large")
		#expect(test.pValue < 0.01, "p \(test.pValue)")
	}

	// MARK: - Refusals

	@Test("Malformed survival data is refused")
	func refusals() {
		#expect(KaplanMeier(times: [1.0, 2.0], events: [true]) == nil)
		#expect(KaplanMeier<Double>(times: [], events: []) == nil)
		// A negative duration is not a duration.
		#expect(KaplanMeier(times: [1.0, -2.0], events: [true, true]) == nil)
		#expect(KaplanMeier(times: [1.0, Double.nan], events: [true, true]) == nil)
		// Every observation censored: nothing failed, so there is no survival curve to
		// estimate — only a statement that follow-up was too short.
		#expect(KaplanMeier(times: [1.0, 2.0, 3.0], events: [false, false, false]) == nil)
		#expect(LogRankTest(firstTimes: [1.0], firstEvents: [true],
							secondTimes: [], secondEvents: []) == nil)
	}
}
