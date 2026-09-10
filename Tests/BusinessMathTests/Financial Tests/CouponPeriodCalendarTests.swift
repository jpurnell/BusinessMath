//
//  CouponPeriodCalendarTests.swift
//  BusinessMathTests
//
//  The coupon grid against Microsoft's own worked example, with the dates built in
//  UTC rather than in the machine's time zone.
//
//  That distinction is the whole point of this file. `ExcelBondFunctionTests` builds
//  its dates with `Calendar.current`, and the coupon walk *also* used
//  `Calendar.current` — so the two agreed with each other in every zone and the
//  defect was invisible from inside this package. It surfaced the moment a caller
//  handed in UTC midnights, which is what a spreadsheet's date serials decode to.
//
//  See the note on `cachedCalendar` in DayCountConvention.swift: this is the same
//  root cause at a fifth site, and the same fix.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("The coupon grid is zone-independent")
struct CouponPeriodCalendarTests {

	/// A date at UTC midnight — what an Excel serial decodes to, and what any caller
	/// speaking in calendar dates rather than instants will hand in.
	static func utc(_ y: Int, _ m: Int, _ d: Int) -> Date {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		var components = DateComponents()
		components.year = y; components.month = m; components.day = d
		guard let date = calendar.date(from: components) else {
			preconditionFailure("\(y)-\(m)-\(d) is not a date")
		}
		return date
	}

	static func day(of date: Date) -> DateComponents {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		return calendar.dateComponents([.year, .month, .day], from: date)
	}

	// Microsoft's worked example for all six COUP* functions: settlement
	// 25 January 2011, maturity 15 November 2011, semi-annual, actual/actual.
	//
	// The grid runs back from maturity — 15 Nov 2011, 15 May 2011, 15 Nov 2010 — so
	// settlement sits in the middle period, and the published answers are
	// A = 71, E = 181, DSC = 110, N = 2.

	@Test("The coupon dates fall on the fifteenth, in any zone")
	func couponDatesLandOnTheScheduledDay() throws {
		let period = try CouponPeriod<Double>(
			settlement: Self.utc(2011, 1, 25), maturity: Self.utc(2011, 11, 15),
			frequency: .semiAnnual, basis: .actualActual)

		let previous = Self.day(of: period.previousCouponDate)
		#expect(previous.year == 2010)
		#expect(previous.month == 11)
		#expect(previous.day == 15)

		let next = Self.day(of: period.nextCouponDate)
		#expect(next.year == 2011)
		#expect(next.month == 5)
		#expect(next.day == 15)
	}

	@Test("A, DSC, E and N match Microsoft's published example")
	func theFourQuantitiesMatchExcel() throws {
		let period = try CouponPeriod<Double>(
			settlement: Self.utc(2011, 1, 25), maturity: Self.utc(2011, 11, 15),
			frequency: .semiAnnual, basis: .actualActual)

		#expect(period.daysAccrued == 71)          // COUPDAYBS
		#expect(period.daysInPeriod == 181)        // COUPDAYS
		#expect(period.daysToNextCoupon == 110)    // COUPDAYSNC
		#expect(period.couponsRemaining == 2)      // COUPNUM
	}

	@Test("On 30/360 the accrued and remaining days still fill the nominal period")
	func thirty360DayCountsFillThePeriod() throws {
		let period = try CouponPeriod<Double>(
			settlement: Self.utc(2011, 1, 25), maturity: Self.utc(2011, 11, 15),
			frequency: .semiAnnual, basis: .thirty360)

		#expect(period.daysAccrued == 70)
		#expect(period.daysToNextCoupon == 110)
		#expect(period.daysInPeriod == 180)
		#expect(period.accruedFraction + period.remainingFraction == 1)
	}

	/// The regression this file exists for, stated as a property rather than a value.
	///
	/// The same bond, described by instants an hour apart inside the same UTC day,
	/// must produce the same grid. Under `Calendar.current` it did not — but only in a
	/// zone that changes offset during the year. Wall-clock month arithmetic
	/// round-trips to the correct instant whenever the UTC offset is stable, however
	/// large it is, so the defect was invisible in Tokyo and Niue and visible in New
	/// York. `BondClockZoneInvarianceTests` sweeps that directly.
	@Test("The grid does not move with the time of day")
	func theGridIsIndependentOfTheHour() throws {
		let maturity = Self.utc(2011, 11, 15)
		let settlement = Self.utc(2011, 1, 25)

		let atMidnight = try CouponPeriod<Double>(
			settlement: settlement, maturity: maturity,
			frequency: .semiAnnual, basis: .thirty360)
		let atNoon = try CouponPeriod<Double>(
			settlement: settlement.addingTimeInterval(12 * 3600),
			maturity: maturity.addingTimeInterval(12 * 3600),
			frequency: .semiAnnual, basis: .thirty360)

		#expect(atMidnight.couponsRemaining == atNoon.couponsRemaining)
		#expect(Self.day(of: atMidnight.nextCouponDate).day == Self.day(of: atNoon.nextCouponDate).day)
		#expect(Self.day(of: atMidnight.previousCouponDate).day
			== Self.day(of: atNoon.previousCouponDate).day)
	}

	/// `ACCRINT`'s quasi-coupon grid is walked by the same kind of loop in a different
	/// file, so it needs its own pin: Microsoft's example, in UTC.
	///
	/// A 10% bond on 1,000 par, issued 1 March 2008, first interest 31 August 2008,
	/// settling 1 May 2008, semi-annual, 30/360. Two months of a six-month period at
	/// 50 a coupon is 16.6667 — the published answer, and what the documented formula
	/// gives independently of it.
	@Test("ACCRINT's grid is zone-independent too")
	func accruedInterestMatchesExcelInUTC() throws {
		let accrued: Double = try accruedInterest(
			issue: Self.utc(2008, 3, 1),
			firstInterest: Self.utc(2008, 8, 31),
			settlement: Self.utc(2008, 5, 1),
			rate: 0.10, par: 1000, frequency: .semiAnnual, basis: .thirty360)

		#expect(abs(accrued - 16.666666666666668) < 1e-9)
	}
}
