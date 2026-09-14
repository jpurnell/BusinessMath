//
//  BondDayCountTests.swift
//  BusinessMathTests
//
//  Ten discounting sites built a year from a 365.25 constant applied to a seconds
//  interval. 365.25 is not a day-count convention; it is a leap-year fudge factor.
//

import Testing
import Foundation
@testable import BusinessMath

/// Every bond year fraction now comes from a stated ``DayCountConvention``.
///
/// Before this, `Bond`, `ZeroCouponBond` and `AmortizingBond` each carried the same
/// eight-line block converting `Date.timeIntervalSince` to years by dividing seconds by
/// `365.25 * 24 * 3600` — ten copies in one file, which the duplication checker had
/// already flagged as a 188-token clone.
///
/// Two things were wrong with it beyond the duplication. **365.25 is not a convention.**
/// ACT/365, ACT/360, 30/360 and ACT/ACT are conventions, each with a standard behind it;
/// 365.25 is an average year length, and no counterparty settles on it. And **measuring
/// in seconds is not measuring in days**: an interval in seconds silently absorbs
/// daylight-saving shifts, where a day count asks the calendar.
///
/// The convention is now a stored property, defaulted to ``DayCountConvention/actual365``
/// — the named standard closest to the old behaviour, so existing callers move by cents
/// rather than by dollars.
@Suite("Bond day-count conventions")
struct BondDayCountTests {

	/// A fixed instant, so these expectations do not depend on when the suite runs.
	private static let asOf = Date(timeIntervalSince1970: 1_700_000_000)

	private func bond(_ dayCount: DayCountConvention, years: Double) -> Bond<Double> {
		let maturity = Self.asOf.addingTimeInterval(years * 365.25 * 24 * 3600)
		return Bond<Double>(
			faceValue: 1000,
			couponRate: 0.05,
			maturityDate: maturity,
			paymentFrequency: .semiAnnual,
			issueDate: Self.asOf,
			dayCount: dayCount
		)
	}

	/// The default is a named standard, not the old average-year constant.
	@Test("A bond built without a day count uses ACT/365")
	func defaultIsActual365() {
		let implicit = bond(.actual365, years: 10)
		let explicitBond = Bond<Double>(
			faceValue: 1000,
			couponRate: 0.05,
			maturityDate: implicit.maturityDate,
			paymentFrequency: .semiAnnual,
			issueDate: Self.asOf
		)
		#expect(explicitBond.dayCount == .actual365, "default was \(explicitBond.dayCount)")
	}

	/// The property is load-bearing: change it and the price changes.
	///
	/// This is the assertion that would have caught a `dayCount` that was stored and then
	/// ignored — the shape of defect this roadmap has already found twice, where a
	/// statistic is recorded and never read.
	@Test("Changing the convention changes the price, by more than a rounding difference")
	func conventionIsLoadBearing() {
		let act365: Double = bond(.actual365, years: 10).price(yield: 0.05, asOf: Self.asOf)
		let act360: Double = bond(.actual360, years: 10).price(yield: 0.05, asOf: Self.asOf)
		let gap: Double = abs(act365 - act360)

		// ACT/360 counts the same days against a shorter year, so it reports more years
		// elapsed and discounts harder. On a ten-year par-coupon bond that is dollars.
		#expect(act360 < act365, "ACT/360 gave \(act360), ACT/365 gave \(act365)")
		#expect(gap > 1.0, "the two conventions differ by only \(gap)")
	}

	/// ACT/360 reports a longer year fraction than ACT/365 for the same two dates.
	///
	/// The ratio is exactly 365/360, which is the whole content of the two conventions
	/// and is worth asserting rather than describing.
	@Test("ACT/360 and ACT/365 year fractions stand in the ratio 365/360")
	func act360IsLongerByTheRatioOfTheirDenominators() {
		let maturity = Self.asOf.addingTimeInterval(10 * 365.25 * 24 * 3600)
		let byThreeSixtyFive: Double = DayCountConvention.actual365.yearFraction(from: Self.asOf, to: maturity)
		let byThreeSixty: Double = DayCountConvention.actual360.yearFraction(from: Self.asOf, to: maturity)

		let observed: Double = byThreeSixty / byThreeSixtyFive
		let expected: Double = 365.0 / 360.0
		#expect(abs(observed - expected) < 1e-12, "ratio was \(observed), not \(expected)")
	}

	/// The day count reaches every instrument in the file, not only `Bond`.
	@Test("Zero-coupon and amortizing bonds honour their day count too")
	func everyInstrumentHonoursIt() {
		let maturity = Self.asOf.addingTimeInterval(10 * 365.25 * 24 * 3600)

		let zero365 = ZeroCouponBond<Double>(faceValue: 1000, maturityDate: maturity,
											 issueDate: Self.asOf, dayCount: .actual365)
		let zero360 = ZeroCouponBond<Double>(faceValue: 1000, maturityDate: maturity,
											 issueDate: Self.asOf, dayCount: .actual360)
		let zeroA: Double = zero365.price(yield: 0.05, asOf: Self.asOf)
		let zeroB: Double = zero360.price(yield: 0.05, asOf: Self.asOf)
		#expect(zeroB < zeroA, "zero-coupon: \(zeroB) should discount harder than \(zeroA)")

		let schedule = [AmortizationPayment<Double>(date: maturity, principalAmount: 1000)]
		let amort365 = AmortizingBond<Double>(faceValue: 1000, couponRate: 0.05,
											  maturityDate: maturity, paymentFrequency: .semiAnnual,
											  issueDate: Self.asOf, amortizationSchedule: schedule,
											  dayCount: .actual365)
		let amort360 = AmortizingBond<Double>(faceValue: 1000, couponRate: 0.05,
											  maturityDate: maturity, paymentFrequency: .semiAnnual,
											  issueDate: Self.asOf, amortizationSchedule: schedule,
											  dayCount: .actual360)
		let amortA: Double = amort365.price(yield: 0.05, asOf: Self.asOf)
		let amortB: Double = amort360.price(yield: 0.05, asOf: Self.asOf)
		#expect(amortB < amortA, "amortizing: \(amortB) should discount harder than \(amortA)")
	}

	/// What the change cost existing callers, pinned so it cannot drift unnoticed.
	///
	/// Measured against the legacy block on a 5%-coupon semiannual bond priced at a 5%
	/// yield: the ten-year price moves from 984.7583 to 984.4520, **31 cents on a
	/// thousand**. The old bond tests pass through this change not because nothing moved
	/// but because their bands are a full dollar wide — which is worth knowing.
	@Test("The ACT/365 price of the reference ten-year bond is 984.45")
	func theMoveIsPinned() {
		let price: Double = bond(.actual365, years: 10).price(yield: 0.05, asOf: Self.asOf)
		#expect(abs(price - 984.4520185073686) < 1e-9, "price was \(price)")

		// The legacy 365.25 answer, for the record. The gap is the cost of the change.
		let legacy: Double = 984.7583259666203
		let move: Double = legacy - price
		#expect(move > 0.30 && move < 0.31, "the move was \(move)")
	}

	/// The four figures printed in `3.10-BondValuationGuide.md`, pinned.
	///
	/// A guide that quotes a price is making a claim the code has to keep. `doc-claims`
	/// catches a drift once it happens; this catches it with the reason attached.
	@Test("The bond guide's worked example prices correctly under all four conventions")
	func theGuideExampleIsPinned() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
		let today = Date(timeIntervalSince1970: 1_767_225_600)  // 2026-01-01T00:00:00Z
		let maturity = try #require(calendar.date(byAdding: .year, value: 5, to: today))

		func price(_ dayCount: DayCountConvention) -> Double {
			let bond = Bond(
				faceValue: 1000.0,
				couponRate: 0.06,
				maturityDate: maturity,
				paymentFrequency: .semiAnnual,
				issueDate: today,
				dayCount: dayCount
			)
			return bond.price(yield: 0.05, asOf: today)
		}

		#expect(abs(price(.actual365) - 1043.6613488627127) < 1e-9)
		#expect(abs(price(.thirty360) - 1043.7603196548555) < 1e-9)
		#expect(abs(price(.actual360) - 1040.5094238428337) < 1e-9)
		#expect(abs(price(.isdaActualActual) - 1043.7854912749935) < 1e-9)
	}

	/// 30/360 reproduces the closed-form textbook price, and that is not a coincidence.
	///
	/// The whole-period formula every textbook prints — ten half-year periods at 2.5% —
	/// *assumes* 30/360 without saying so, because assuming it is what makes "five years"
	/// mean exactly ten periods. Computing the closed form here rather than pasting its
	/// value makes this an identity the suite checks, not a number someone transcribed.
	@Test("Under 30/360 the price equals the closed-form whole-period valuation")
	func thirty360MatchesTheClosedForm() throws {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
		let today = Date(timeIntervalSince1970: 1_767_225_600)
		let maturity = try #require(calendar.date(byAdding: .year, value: 5, to: today))

		let bond = Bond(
			faceValue: 1000.0,
			couponRate: 0.06,
			maturityDate: maturity,
			paymentFrequency: .semiAnnual,
			issueDate: today,
			dayCount: .thirty360
		)
		let priced: Double = bond.price(yield: 0.05, asOf: today)

		// Σ 30/(1.025)^k for k in 1...10, plus 1000/(1.025)^10.
		let couponPerPeriod: Double = 30.0
		let periodicYield: Double = 0.025
		let periods: Int = 10
		var closedForm: Double = 0
		for k in 1...periods {
			let discount: Double = Foundation.pow(1.0 + periodicYield, Double(k))
			closedForm += couponPerPeriod / discount
		}
		let redemption: Double = Foundation.pow(1.0 + periodicYield, Double(periods))
		closedForm += 1000.0 / redemption

		#expect(abs(priced - closedForm) < 1e-9,
				"30/360 gave \(priced), the closed form gives \(closedForm)")
	}
}
