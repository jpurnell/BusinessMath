//
//  FiscalCalendar.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

// MARK: - MonthDay

/// A simple representation of a month and day within a year.
///
/// `MonthDay` is used to specify fiscal year-end dates without a specific year.
/// For example, Apple's fiscal year ends on September 30, represented as `MonthDay(month: 9, day: 30)`.
///
/// ## Example
/// ```swift
/// let sept30 = MonthDay(month: 9, day: 30)  // Apple's fiscal year-end
/// let dec31 = MonthDay(month: 12, day: 31)  // Calendar year-end
/// let june30 = MonthDay(month: 6, day: 30)  // Australian government FY
/// ```
public struct MonthDay: Codable, Equatable, Hashable, Sendable {

	/// The month (1-12).
	public let month: Int

	/// The day of the month (1-31).
	public let day: Int

	/// Creates a month-day representation.
	///
	/// - Parameters:
	///   - month: The month (1-12).
	///   - day: The day (1-31).
	///
	/// - Precondition: `month` must be between 1 and 12 inclusive.
	/// - Precondition: `day` must be between 1 and 31 inclusive.
	///
	/// ## Example
	/// ```swift
	/// let yearEnd = MonthDay(month: 9, day: 30)  // September 30
	/// ```
	public init(month: Int, day: Int) {
		precondition(month >= 1 && month <= 12, "Month must be between 1 and 12")
		precondition(day >= 1 && day <= 31, "Day must be between 1 and 31")
		self.month = month
		self.day = day
	}
}

// MARK: - FiscalCalendar

/// A fiscal calendar that maps calendar dates to fiscal periods.
///
/// Many organizations use fiscal years that don't align with calendar years. For example:
/// - Apple: Fiscal year ends September 30 (FY2025 runs Oct 1, 2024 - Sep 30, 2025)
/// - Australian Government: Fiscal year ends June 30
/// - UK Government: Fiscal year ends March 31
///
/// `FiscalCalendar` provides methods to convert calendar dates and periods to their
/// fiscal equivalents.
///
/// ## Creating Fiscal Calendars
///
/// ```swift
/// // Standard calendar year (Dec 31 year-end)
/// let standard = FiscalCalendar.standard
///
/// // Apple fiscal year (Sep 30 year-end)
/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
///
/// // Australian government (Jun 30 year-end)
/// let australia = FiscalCalendar(yearEnd: try MonthDay(month: 6, day: 30))
/// ```
///
/// ## Using Fiscal Calendars
///
/// ```swift
/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
///
/// // January 15, 2025 is in Apple's FY2025
/// let jan2025 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
/// let fiscalYear = apple.fiscalYear(for: jan2025)  // 2025
/// let fiscalQuarter = apple.fiscalQuarter(for: jan2025)  // Q2 (Jan-Mar is Q2 for Apple)
/// let fiscalMonth = apple.fiscalMonth(for: jan2025)  // Month 4 (Oct=1, Jan=4)
///
/// // Map calendar periods to fiscal periods
/// let jan = Period.month(year: 2025, month: 1)
/// let fiscalPeriod = apple.periodInFiscalYear(jan)  // 4
/// ```
public struct FiscalCalendar: Codable, Equatable, Sendable {

	/// The year-end date (month and day).
	///
	/// For example, Apple's fiscal year ends on September 30, so `yearEnd` would be
	/// `MonthDay(month: 9, day: 30)`.
	public let yearEnd: MonthDay

	// MARK: - Initialization

	/// Creates a fiscal calendar with the specified year-end.
	///
	/// - Parameter yearEnd: The month and day on which the fiscal year ends.
	///
	/// ## Example
	/// ```swift
	/// // Apple's fiscal year ends September 30
	/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
	/// ```
	public init(yearEnd: MonthDay) {
		self.yearEnd = yearEnd
	}

	/// The standard calendar year fiscal calendar (December 31 year-end).
	///
	/// For organizations that use calendar years, the fiscal year equals the calendar year.
	///
	/// ## Example
	/// ```swift
	/// let standard = FiscalCalendar.standard
	/// print(standard.yearEnd.month)  // 12
	/// print(standard.yearEnd.day)    // 31
	/// ```
	public static let standard = FiscalCalendar(yearEnd: MonthDay(month: 12, day: 31))

	// MARK: - Fiscal Year Calculations

	/// Returns the fiscal year for the given date.
	///
	/// The fiscal year is determined by comparing the date to the year-end:
	/// - If the date is after the year-end in the same calendar year, it's in the next fiscal year
	/// - Otherwise, it's in the current fiscal year
	///
	/// For Apple (Sept 30 year-end):
	/// - October 1, 2024 through September 30, 2025 is FY2025
	/// - October 1, 2025 through September 30, 2026 is FY2026
	///
	/// - Parameter date: The date to evaluate.
	/// - Returns: The fiscal year number.
	///
	/// ## Example
	/// ```swift
	/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
	/// let jan2025 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
	/// let fy = apple.fiscalYear(for: jan2025)  // 2025 (part of FY2025)
	/// ```
	public func fiscalYear(for date: Date) -> Int {
		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: date)
		let calendarYear = components.year!
		let month = components.month!
		let day = components.day!

		// If we're after the year-end in the same calendar year, we're in the next fiscal year
		if month > yearEnd.month || (month == yearEnd.month && day > yearEnd.day) {
			return calendarYear + 1
		}

		return calendarYear
	}

	/// Returns the fiscal quarter (1-4) for the given date.
	///
	/// Fiscal quarters are 3-month periods starting from the beginning of the fiscal year.
	/// The first fiscal quarter (Q1) starts the day after the previous fiscal year-end.
	///
	/// For Apple (Sept 30 year-end):
	/// - Q1: October - December
	/// - Q2: January - March
	/// - Q3: April - June
	/// - Q4: July - September
	///
	/// - Parameter date: The date to evaluate.
	/// - Returns: The fiscal quarter (1-4).
	///
	/// ## Example
	/// ```swift
	/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
	/// let jan2025 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
	/// let fq = apple.fiscalQuarter(for: jan2025)  // 2 (Jan-Mar is Q2)
	/// ```
	public func fiscalQuarter(for date: Date) -> Int {
		let fiscalMonth = self.fiscalMonth(for: date)
		return (fiscalMonth - 1) / 3 + 1
	}

	/// Returns the fiscal month (1-12) for the given date.
	///
	/// Fiscal month 1 starts the day after the previous fiscal year-end.
	/// For example, with a September 30 year-end, fiscal month 1 is October.
	///
	/// For Apple (Sept 30 year-end):
	/// - Fiscal Month 1 = October
	/// - Fiscal Month 4 = January
	/// - Fiscal Month 12 = September
	///
	/// - Parameter date: The date to evaluate.
	/// - Returns: The fiscal month (1-12).
	///
	/// ## Example
	/// ```swift
	/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
	/// let jan2025 = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 15))!
	/// let fm = apple.fiscalMonth(for: jan2025)  // 4 (January is fiscal month 4)
	/// ```
	public func fiscalMonth(for date: Date) -> Int {
		let calendar = Calendar.current
		let components = calendar.dateComponents([.month], from: date)
		let calendarMonth = components.month!

		// Calculate fiscal month offset
		// If year-end is Dec 31, fiscal month 1 = Jan (calendar month 1)
		// If year-end is Sep 30, fiscal month 1 = Oct (calendar month 10)
		let fiscalYearStartMonth = yearEnd.month + 1

		// Adjust calendar month relative to fiscal year start
		var fiscalMonth = calendarMonth - fiscalYearStartMonth + 1
		if fiscalMonth <= 0 {
			fiscalMonth += 12
		}

		return fiscalMonth
	}

	// MARK: - Period Integration

	/// Returns the fiscal period number for the given calendar period.
	///
	/// This maps a calendar period to its position within the fiscal year:
	/// - Monthly periods map to fiscal months (1-12)
	/// - Quarterly periods map to fiscal quarters (1-4)
	/// - Annual periods always map to 1
	/// - Daily periods map to their fiscal month
	///
	/// - Parameter period: The calendar period to map.
	/// - Returns: The fiscal period number.
	///
	/// ## Example
	/// ```swift
	/// let apple = FiscalCalendar(yearEnd: try MonthDay(month: 9, day: 30))
	///
	/// // Calendar January is fiscal month 4
	/// let jan = Period.month(year: 2025, month: 1)
	/// let fiscalPeriod = apple.periodInFiscalYear(jan)  // 4
	///
	/// // Calendar Q1 (Jan-Mar) is fiscal Q2
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// let fiscalQuarter = apple.periodInFiscalYear(q1)  // 2
	/// ```
	public func periodInFiscalYear(_ period: Period) -> Int {
		switch period.type {
		case .daily:
			return fiscalMonth(for: period.startDate)

		case .monthly:
			return fiscalMonth(for: period.startDate)

		case .quarterly:
			return fiscalQuarter(for: period.startDate)

		case .annual:
			return 1  // Annual periods always map to period 1
		}
	}
}
