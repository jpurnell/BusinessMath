//
//  CohortRetentionTests.swift
//  BusinessMath
//
//  The retention triangle, and the three ways a ragged table reads as a rectangular one.
//
//  - **Averaging down a column with every cohort in the denominator.** A cohort acquired
//    last month has no value at offset two; it has not got there. Counting it as a zero
//    drags the pooled curve down while leaving it monotone, smooth and plausible. On the
//    triangle below the naive figure at offset two is 0.17 where the answer is 0.50 —
//    a threefold error with nothing in its shape to give it away.
//  - **Dividing one pooled value by the one before it.** Those two values are computed
//    over different sets of cohorts, so the quotient compares one population against
//    another. Here it gives 0.667 where the like-for-like rate is 0.625.
//  - **Reading past the end of the window as churn.** Nobody has reached offset three, so
//    there is no retention there. Returning zero says every customer left.
//
//  The anchor is Kaplan-Meier. Where one cohort is observed for its whole life and nobody
//  is censored, the cohort curve and the product-limit estimate are the same function —
//  the table has nothing left to discard — and the area under it is the restricted mean.
//  Both are checked against the shipped estimator, and neither needs a fixture.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Cohort retention")
struct CohortRetentionTests {

	static func many(cohort: Int, lifetime: Int, isActive: Bool, count: Int) -> [CustomerTenure] {
		(0..<count).map { _ in
			CustomerTenure(cohort: cohort, lifetime: lifetime, isActive: isActive)
		}
	}

	/// Three cohorts, observation ending in period two, so the windows are 3, 2 and 1.
	///
	/// | cohort | offset 0 | offset 1 | offset 2 |
	/// |---|---|---|---|
	/// | 0 | 10 | 8 | 5 |
	/// | 1 | 10 | 7 | — |
	/// | 2 | 10 | — | — |
	static let ragged: [CustomerTenure] = {
		var all: [CustomerTenure] = []
		all += many(cohort: 0, lifetime: 1, isActive: false, count: 2)
		all += many(cohort: 0, lifetime: 2, isActive: false, count: 3)
		all += many(cohort: 0, lifetime: 3, isActive: true, count: 5)
		all += many(cohort: 1, lifetime: 1, isActive: false, count: 3)
		all += many(cohort: 1, lifetime: 2, isActive: true, count: 7)
		all += many(cohort: 2, lifetime: 1, isActive: true, count: 10)
		return all
	}()

	/// One cohort, everybody churned: lifetimes 1, 1, 2, 3, 3, 4, 5, 5.
	static let complete: [CustomerTenure] = {
		var all: [CustomerTenure] = []
		for lifetime in [1, 1, 2, 3, 3, 4, 5, 5] {
			all.append(CustomerTenure(cohort: 0, lifetime: lifetime, isActive: false))
		}
		return all
	}()

	// MARK: - The triangle

	@Test("Each cohort is observed for as long as its acquisition date allows")
	func windowsFollowFromAcquisition() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		#expect(table.observationEnd == 2)
		#expect(table.rows.count == 3)
		#expect(table.rows.map { $0.observedPeriods } == [3, 2, 1])
		#expect(table.rows.map { $0.size } == [10, 10, 10])
		#expect(table.rows[0].active == [10, 8, 5])
		#expect(table.rows[1].active == [10, 7])
		#expect(table.rows[2].active == [10])
		#expect(table.totalCustomers == 30)
	}

	@Test("A cell past a cohort's window is absent, not zero")
	func cellsPastTheWindowAreAbsent() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		let cell = try #require(table.retention(cohort: 0, offset: 2))
		#expect(Swift.abs(cell - 0.5) < 1e-12, "cohort 0 at offset 2 is \(cell)")
		#expect(table.retention(cohort: 1, offset: 2) == nil)
		#expect(table.retention(cohort: 2, offset: 1) == nil)
		#expect(table.retention(cohort: 9, offset: 0) == nil)
		#expect(table.retention(cohort: 0, offset: -1) == nil)
	}

	@Test("Retention within a cohort never rises")
	func retentionIsMonotone() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		for row in table.rows {
			#expect(Swift.abs(row.retention[0] - 1) < 1e-12, "cohort \(row.cohort) starts whole")
			for offset in 1..<row.retention.count {
				let earlier: Double = row.retention[offset - 1]
				let later: Double = row.retention[offset]
				#expect(later <= earlier, "cohort \(row.cohort): \(later) after \(earlier)")
			}
		}
	}

	// MARK: - Pooling

	@Test("Pooling counts only the cohorts that reached the offset")
	func poolingExcludesCohortsThatHaveNotGotThere() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		let first = try #require(table.pooledRetention(offset: 0))
		let second = try #require(table.pooledRetention(offset: 1))
		let third = try #require(table.pooledRetention(offset: 2))
		#expect(Swift.abs(first - 1) < 1e-12, "offset 0 is \(first)")
		// 15 of 20, over cohorts 0 and 1 — cohort 2 is not in the denominator.
		#expect(Swift.abs(second - 0.75) < 1e-12, "offset 1 is \(second)")
		// 5 of 10, cohort 0 alone. Counting all thirty gives 0.1667.
		#expect(Swift.abs(third - 0.5) < 1e-12, "offset 2 is \(third)")
		let naive: Double = 5.0 / 30.0
		let tripled: Double = naive * 3
		#expect(Swift.abs(third - tripled) < 1e-12,
				"the naive figure \(naive) is a third of the answer \(third)")
	}

	@Test("Past the longest window there is no retention to report")
	func pastTheWindowIsRefused() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		#expect(table.maximumObservedPeriods == 3)
		#expect(table.pooledRetention(offset: 3) == nil)
		#expect(table.pooledRetention(offset: -1) == nil)
		#expect(table.pooledCurve.count == 3)
	}

	@Test("Period retention uses the same cohorts at both ends")
	func periodRetentionIsLikeForLike() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		// Offset 0 to 1 spans cohorts 0 and 1: 15 of 20.
		let first = try #require(table.periodRetention(offset: 0))
		#expect(Swift.abs(first - 0.75) < 1e-12, "\(first)")
		// Offset 1 to 2 spans cohort 0 alone: 5 of 8.
		let second = try #require(table.periodRetention(offset: 1))
		#expect(Swift.abs(second - 0.625) < 1e-12, "\(second)")
		// The ratio of the two pooled values is a different, wrong number.
		let pooledLate = try #require(table.pooledRetention(offset: 2))
		let pooledEarly = try #require(table.pooledRetention(offset: 1))
		let quotient: Double = pooledLate / pooledEarly
		let twoThirds: Double = 2.0 / 3.0
		#expect(Swift.abs(quotient - twoThirds) < 1e-12,
				"the naive quotient is \(quotient), against the rate \(second)")
		// Nothing spans offsets 2 and 3.
		#expect(table.periodRetention(offset: 2) == nil)
	}

	@Test("Average lifetime is the area under the pooled curve, and stops at the window")
	func averageLifetimeIsTheArea() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		let area = try #require(table.averageLifetime(horizon: 3))
		#expect(Swift.abs(area - 2.25) < 1e-12, "1 + 0.75 + 0.5 = \(area)")
		#expect(table.averageLifetime(horizon: 4) == nil)
		#expect(table.averageLifetime(horizon: 0) == nil)
	}

	// MARK: - The Kaplan-Meier identity

	@Test("With one full cohort and no censoring, the curve is the product-limit estimate")
	func cohortCurveEqualsKaplanMeier() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.complete))
		let estimator = try #require(table.kaplanMeier)
		let curve = estimator.curve
		#expect(table.maximumObservedPeriods == 5)
		for offset in 0..<5 {
			let tabled = try #require(table.pooledRetention(offset: offset))
			let estimated: Double = curve.survival(at: Double(offset))
			#expect(Swift.abs(tabled - estimated) < 1e-12,
					"offset \(offset): \(tabled) against \(estimated)")
		}
	}

	@Test("And its area is the restricted mean survival time")
	func areaEqualsRestrictedMean() throws {
		let table = try #require(CohortRetention<Double>(tenures: Self.complete))
		let estimator = try #require(table.kaplanMeier)
		let area = try #require(table.averageLifetime(horizon: 5))
		let restricted = try #require(estimator.curve.restrictedMean(horizon: 5))
		#expect(Swift.abs(area - 3) < 1e-12, "the area is \(area)")
		#expect(Swift.abs(area - restricted) < 1e-12, "\(area) against \(restricted)")
	}

	@Test("The estimator and the table disagree once the triangle is ragged")
	func raggedTableDivergesFromTheEstimator() throws {
		// Not a defect in either: the table drops a cohort from a column all at once,
		// while the estimator keeps it in the risk set for as long as it was observed.
		let table = try #require(CohortRetention<Double>(tenures: Self.ragged))
		let estimator = try #require(table.kaplanMeier)
		let tabled = try #require(table.pooledRetention(offset: 2))
		let estimated: Double = estimator.curve.survival(at: 2)
		// The table sees cohort 0 alone: 5 of 10. The estimator has all thirty in the
		// risk set at t = 1 and fifteen at t = 2, and reports (25/30)(12/15) = 2/3.
		let twoThirds: Double = 2.0 / 3.0
		#expect(Swift.abs(tabled - 0.5) < 1e-12, "the table says \(tabled)")
		#expect(Swift.abs(estimated - twoThirds) < 1e-12, "the estimator says \(estimated)")
	}

	// MARK: - Refusals

	@Test("A cohort with no observed churn has no survival estimate")
	func noChurnHasNoEstimate() throws {
		let stillHere = Self.many(cohort: 0, lifetime: 1, isActive: true, count: 10)
		let table = try #require(CohortRetention<Double>(tenures: stillHere))
		let pooled = try #require(table.pooledRetention(offset: 0))
		#expect(Swift.abs(pooled - 1) < 1e-12, "\(pooled)")
		#expect(table.kaplanMeier == nil)
	}

	@Test("Tenures that do not describe a customer are refused")
	func malformedTenuresAreRefused() {
		#expect(CohortRetention<Double>(tenures: []) == nil)
		let neverActive = [CustomerTenure(cohort: 0, lifetime: 0, isActive: false)]
		#expect(CohortRetention<Double>(tenures: neverActive) == nil)
		let beforeTime = [CustomerTenure(cohort: -1, lifetime: 2, isActive: false)]
		#expect(CohortRetention<Double>(tenures: beforeTime) == nil)
	}
}
