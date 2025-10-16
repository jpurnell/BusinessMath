//
//  FiscalCalendarTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("FiscalCalendar Tests")
struct FiscalCalendarTests {

	// MARK: - MonthDay Tests

	@Test("MonthDay can be created with valid values")
	func monthDayCreation() {
		let md = MonthDay(month: 9, day: 30)
		#expect(md.month == 9)
		#expect(md.day == 30)
	}

	@Test("MonthDay December 31")
	func monthDayDecember31() {
		let md = MonthDay(month: 12, day: 31)
		#expect(md.month == 12)
		#expect(md.day == 31)
	}

	@Test("MonthDay February 28")
	func monthDayFebruary28() {
		let md = MonthDay(month: 2, day: 28)
		#expect(md.month == 2)
		#expect(md.day == 28)
	}

	@Test("MonthDay June 30")
	func monthDayJune30() {
		let md = MonthDay(month: 6, day: 30)
		#expect(md.month == 6)
		#expect(md.day == 30)
	}

	// Note: MonthDay uses preconditions for validation (month 1-12, day 1-31).
	// Invalid values will cause precondition failures during development.
	// These are not catchable errors and should be caught during testing.

	// MARK: - Standard Calendar

	@Test("Standard calendar has December 31 year-end")
	func standardCalendarYearEnd() {
		let standard = FiscalCalendar.standard
		#expect(standard.yearEnd.month == 12)
		#expect(standard.yearEnd.day == 31)
	}

	@Test("Standard calendar: fiscal year equals calendar year")
	func standardCalendarFiscalYear() {
		let standard = FiscalCalendar.standard

		// January 15, 2025 is in FY2025
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = standard.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	@Test("Standard calendar: December is in same fiscal year")
	func standardCalendarDecember() {
		let standard = FiscalCalendar.standard

		// December 15, 2025 is in FY2025
		var components = DateComponents()
		components.year = 2025
		components.month = 12
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = standard.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	// MARK: - Apple Fiscal Year (Sept 30 year-end)

	@Test("Apple fiscal calendar creation")
	func appleFiscalCalendar() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))
		#expect(apple.yearEnd.month == 9)
		#expect(apple.yearEnd.day == 30)
	}

	@Test("Apple fiscal year: October starts new fiscal year")
	func appleFiscalYearOctober() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// October 1, 2024 starts FY2025
		var components = DateComponents()
		components.year = 2024
		components.month = 10
		components.day = 1
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = apple.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	@Test("Apple fiscal year: September is in current calendar year's fiscal year")
	func appleFiscalYearSeptember() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// September 30, 2024 is end of FY2024
		var components = DateComponents()
		components.year = 2024
		components.month = 9
		components.day = 30
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = apple.fiscalYear(for: date)
		#expect(fy == 2024)
	}

	@Test("Apple fiscal year: January is in next fiscal year")
	func appleFiscalYearJanuary() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// January 15, 2025 is in FY2025 (which started Oct 1, 2024)
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = apple.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	// MARK: - Fiscal Quarters

	@Test("Standard calendar: Q1 is January-March")
	func standardCalendarQ1() {
		let standard = FiscalCalendar.standard

		// January 15 is Q1
		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let jan = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: jan) == 1)

		// March 31 is Q1
		components.month = 3
		components.day = 31
		let mar = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: mar) == 1)
	}

	@Test("Standard calendar: Q2 is April-June")
	func standardCalendarQ2() {
		let standard = FiscalCalendar.standard

		var components = DateComponents()
		components.year = 2025
		components.month = 4
		components.day = 1
		let calendar = Calendar.current
		let apr = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: apr) == 2)

		components.month = 6
		components.day = 30
		let jun = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: jun) == 2)
	}

	@Test("Standard calendar: Q3 is July-September")
	func standardCalendarQ3() {
		let standard = FiscalCalendar.standard

		var components = DateComponents()
		components.year = 2025
		components.month = 7
		components.day = 1
		let calendar = Calendar.current
		let jul = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: jul) == 3)

		components.month = 9
		components.day = 30
		let sep = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: sep) == 3)
	}

	@Test("Standard calendar: Q4 is October-December")
	func standardCalendarQ4() {
		let standard = FiscalCalendar.standard

		var components = DateComponents()
		components.year = 2025
		components.month = 10
		components.day = 1
		let calendar = Calendar.current
		let oct = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: oct) == 4)

		components.month = 12
		components.day = 31
		let dec = calendar.date(from: components)!
		#expect(standard.fiscalQuarter(for: dec) == 4)
	}

	@Test("Apple fiscal calendar: Q1 is October-December")
	func appleFiscalQ1() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2024
		components.month = 10
		components.day = 1
		let calendar = Calendar.current
		let oct = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: oct) == 1)

		components.month = 12
		components.day = 31
		let dec = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: dec) == 1)
	}

	@Test("Apple fiscal calendar: Q2 is January-March")
	func appleFiscalQ2() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let jan = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: jan) == 2)

		components.month = 3
		components.day = 31
		let mar = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: mar) == 2)
	}

	@Test("Apple fiscal calendar: Q3 is April-June")
	func appleFiscalQ3() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2025
		components.month = 4
		components.day = 15
		let calendar = Calendar.current
		let apr = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: apr) == 3)

		components.month = 6
		components.day = 30
		let jun = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: jun) == 3)
	}

	@Test("Apple fiscal calendar: Q4 is July-September")
	func appleFiscalQ4() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2025
		components.month = 7
		components.day = 15
		let calendar = Calendar.current
		let jul = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: jul) == 4)

		components.month = 9
		components.day = 30
		let sep = calendar.date(from: components)!
		#expect(apple.fiscalQuarter(for: sep) == 4)
	}

	// MARK: - Fiscal Months

	@Test("Standard calendar: fiscal month equals calendar month")
	func standardCalendarFiscalMonth() {
		let standard = FiscalCalendar.standard

		var components = DateComponents()
		components.year = 2025
		components.day = 15
		let calendar = Calendar.current

		for month in 1...12 {
			components.month = month
			let date = calendar.date(from: components)!
			let fiscalMonth = standard.fiscalMonth(for: date)
			#expect(fiscalMonth == month)
		}
	}

	@Test("Apple fiscal calendar: October is fiscal month 1")
	func appleFiscalMonth1() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2024
		components.month = 10
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fiscalMonth = apple.fiscalMonth(for: date)
		#expect(fiscalMonth == 1)
	}

	@Test("Apple fiscal calendar: September is fiscal month 12")
	func appleFiscalMonth12() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2025
		components.month = 9
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fiscalMonth = apple.fiscalMonth(for: date)
		#expect(fiscalMonth == 12)
	}

	@Test("Apple fiscal calendar: January is fiscal month 4")
	func appleFiscalMonth4() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2025
		components.month = 1
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fiscalMonth = apple.fiscalMonth(for: date)
		#expect(fiscalMonth == 4)
	}

	// MARK: - Period Integration

	@Test("Standard calendar: period in fiscal year matches calendar period")
	func standardCalendarPeriodInFiscalYear() {
		let standard = FiscalCalendar.standard

		let jan = Period.month(year: 2025, month: 1)
		let fiscalPeriod = standard.periodInFiscalYear(jan)
		#expect(fiscalPeriod == 1)

		let dec = Period.month(year: 2025, month: 12)
		let fiscalPeriod12 = standard.periodInFiscalYear(dec)
		#expect(fiscalPeriod12 == 12)
	}

	@Test("Apple fiscal calendar: calendar January is fiscal period 4")
	func appleFiscalCalendarPeriodInFiscalYear() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		let jan = Period.month(year: 2025, month: 1)
		let fiscalPeriod = apple.periodInFiscalYear(jan)
		#expect(fiscalPeriod == 4)
	}

	@Test("Apple fiscal calendar: calendar October is fiscal period 1")
	func appleFiscalCalendarOctoberIsPeriod1() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		let oct = Period.month(year: 2024, month: 10)
		let fiscalPeriod = apple.periodInFiscalYear(oct)
		#expect(fiscalPeriod == 1)
	}

	@Test("Standard calendar: quarterly periods")
	func standardCalendarQuarterlyPeriods() {
		let standard = FiscalCalendar.standard

		let q1 = Period.quarter(year: 2025, quarter: 1)
		#expect(standard.periodInFiscalYear(q1) == 1)

		let q2 = Period.quarter(year: 2025, quarter: 2)
		#expect(standard.periodInFiscalYear(q2) == 2)

		let q3 = Period.quarter(year: 2025, quarter: 3)
		#expect(standard.periodInFiscalYear(q3) == 3)

		let q4 = Period.quarter(year: 2025, quarter: 4)
		#expect(standard.periodInFiscalYear(q4) == 4)
	}

	@Test("Apple fiscal calendar: calendar Q1 is fiscal Q2")
	func appleFiscalCalendarQuarterMapping() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// Calendar Q1 (Jan-Mar) is fiscal Q2
		let calQ1 = Period.quarter(year: 2025, quarter: 1)
		#expect(apple.periodInFiscalYear(calQ1) == 2)

		// Calendar Q2 (Apr-Jun) is fiscal Q3
		let calQ2 = Period.quarter(year: 2025, quarter: 2)
		#expect(apple.periodInFiscalYear(calQ2) == 3)

		// Calendar Q3 (Jul-Sep) is fiscal Q4
		let calQ3 = Period.quarter(year: 2025, quarter: 3)
		#expect(apple.periodInFiscalYear(calQ3) == 4)

		// Calendar Q4 (Oct-Dec) is fiscal Q1 (of next FY)
		let calQ4 = Period.quarter(year: 2024, quarter: 4)
		#expect(apple.periodInFiscalYear(calQ4) == 1)
	}

	@Test("Annual periods always map to fiscal period 1")
	func annualPeriodMapping() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		let year2025 = Period.year(2025)
		let fiscalPeriod = apple.periodInFiscalYear(year2025)
		#expect(fiscalPeriod == 1)
	}

	// MARK: - Other Common Fiscal Year-Ends

	@Test("June 30 fiscal year-end (Australian government)")
	func june30FiscalYear() {
		let june30 = FiscalCalendar(yearEnd: MonthDay(month: 6, day: 30))

		// July 1, 2024 starts FY2025
		var components = DateComponents()
		components.year = 2024
		components.month = 7
		components.day = 1
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = june30.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	@Test("March 31 fiscal year-end (UK government)")
	func march31FiscalYear() {
		let march31 = FiscalCalendar(yearEnd: MonthDay(month: 3, day: 31))

		// April 1, 2024 starts FY2025
		var components = DateComponents()
		components.year = 2024
		components.month = 4
		components.day = 1
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = march31.fiscalYear(for: date)
		#expect(fy == 2025)
	}

	// MARK: - Edge Cases

	@Test("Leap year February 29 handling")
	func leapYearFeb29() {
		let standard = FiscalCalendar.standard

		// Feb 29, 2024 (leap year)
		var components = DateComponents()
		components.year = 2024
		components.month = 2
		components.day = 29
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let fy = standard.fiscalYear(for: date)
		#expect(fy == 2024)

		let fq = standard.fiscalQuarter(for: date)
		#expect(fq == 1)

		let fm = standard.fiscalMonth(for: date)
		#expect(fm == 2)
	}

	@Test("Year-end boundary: exact year-end date")
	func yearEndBoundary() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// September 30, 2024 at 23:59:59 should be FY2024
		var components = DateComponents()
		components.year = 2024
		components.month = 9
		components.day = 30
		components.hour = 23
		components.minute = 59
		components.second = 59
		let calendar = Calendar.current
		let endDate = calendar.date(from: components)!

		let fy = apple.fiscalYear(for: endDate)
		#expect(fy == 2024)
	}

	@Test("Year-end boundary: day after year-end")
	func dayAfterYearEnd() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		// October 1, 2024 at 00:00:00 should be FY2025
		var components = DateComponents()
		components.year = 2024
		components.month = 10
		components.day = 1
		components.hour = 0
		components.minute = 0
		components.second = 0
		let calendar = Calendar.current
		let nextDate = calendar.date(from: components)!

		let fy = apple.fiscalYear(for: nextDate)
		#expect(fy == 2025)
	}

	@Test("Daily periods map to correct fiscal month")
	func dailyPeriodFiscalMonth() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		var components = DateComponents()
		components.year = 2024
		components.month = 10
		components.day = 15
		let calendar = Calendar.current
		let date = calendar.date(from: components)!

		let day = Period.day(date)
		let fiscalPeriod = apple.periodInFiscalYear(day)
		#expect(fiscalPeriod == 1)
	}

	// MARK: - Codable

	@Test("FiscalCalendar can be encoded to JSON")
	func encodingToJSON() throws {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))
		let encoder = JSONEncoder()
		let data = try encoder.encode(apple)

		#expect(data.count > 0)
	}

	@Test("FiscalCalendar can be decoded from JSON")
	func decodingFromJSON() throws {
		let json = """
		{
			"yearEnd": {
				"month": 9,
				"day": 30
			}
		}
		""".data(using: .utf8)!

		let decoder = JSONDecoder()
		let fiscalCal = try decoder.decode(FiscalCalendar.self, from: json)

		#expect(fiscalCal.yearEnd.month == 9)
		#expect(fiscalCal.yearEnd.day == 30)
	}

	@Test("FiscalCalendar round-trip encoding")
	func codableRoundTrip() throws {
		let original = FiscalCalendar(yearEnd: MonthDay(month: 6, day: 30))
		let encoder = JSONEncoder()
		let decoder = JSONDecoder()

		let encoded = try encoder.encode(original)
		let decoded = try decoder.decode(FiscalCalendar.self, from: encoded)

		#expect(decoded.yearEnd.month == original.yearEnd.month)
		#expect(decoded.yearEnd.day == original.yearEnd.day)
	}

	// MARK: - Equatable

	@Test("FiscalCalendars with same year-end are equal")
	func equalityWithSameYearEnd() {
		let apple1 = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))
		let apple2 = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

		#expect(apple1 == apple2)
	}

	@Test("FiscalCalendars with different year-ends are not equal")
	func inequalityWithDifferentYearEnds() {
		let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))
		let standard = FiscalCalendar.standard

		#expect(apple != standard)
	}
}
