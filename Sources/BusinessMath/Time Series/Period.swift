//
//  Period.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// A type-safe representation of a time period in financial models.
///
/// `Period` represents a specific span of time (day, month, quarter, or year)
/// anchored to the calendar. It provides precise start and end dates, supports
/// subdivision into smaller periods, and enables type-safe operations on time series data.
///
/// ## Creating Periods
///
/// Use factory methods to create periods:
///
/// ```swift
/// // Create specific periods
/// let today = Period.day(Date())
/// let jan2025 = Period.month(year: 2025, month: 1)
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// let year2025 = Period.year(2025)
///
/// // Subdivide into smaller periods
/// let months = year2025.months()  // Array of 12 monthly periods
/// let quarters = year2025.quarters()  // Array of 4 quarterly periods
/// let days = jan2025.days()  // Array of 31 daily periods
/// ```
///
/// ## Labels and Formatting
///
/// Periods have compact labels by default, with support for custom formatting:
///
/// ```swift
/// let period = Period.month(year: 2025, month: 1)
/// print(period.label)  // "2025-01"
///
/// let formatter = DateFormatter()
/// formatter.dateFormat = "MMMM yyyy"
/// print(period.formatted(using: formatter))  // "January 2025"
/// ```
///
/// ## Comparison and Sorting
///
/// Periods are ordered first by type (shorter before longer), then by date:
///
/// ```swift
/// let day = Period.day(someDate)
/// let month = Period.month(year: 2025, month: 1)
/// let quarter = Period.quarter(year: 2025, quarter: 1)
/// let year = Period.year(2025)
///
/// // All start on Jan 1, 2025, but ordered by type:
/// // day < month < quarter < year
/// ```
///
/// ## Fiscal Year Support
///
/// `Period` uses calendar years by default. For fiscal year support (e.g., Apple's
/// September 30 year-end), use `FiscalCalendar` to map calendar periods to fiscal periods.
///
/// ## Topics
///
/// ### Creating Periods
/// - ``day(_:)``
/// - ``month(year:month:)``
/// - ``quarter(year:quarter:)``
/// - ``year(_:)``
///
/// ### Properties
/// - ``type``
/// - ``date``
/// - ``startDate``
/// - ``endDate``
/// - ``label``
///
/// ### Formatting
/// - ``formatted(using:)``
///
/// ### Subdivision
/// - ``months()``
/// - ``quarters()``
/// - ``days()``
public struct Period: Hashable, Comparable, Codable, Sendable {

	// MARK: - Properties

	/// The type of this period (daily, monthly, quarterly, or annual).
	public let type: PeriodType

	/// The reference date for this period.
	///
	/// For daily periods, this is the specific day (at 00:00:00).
	/// For monthly/quarterly/annual periods, this is the first day of the period.
	public let date: Date

	// MARK: - Factory Methods

	/// Creates a daily period for the specified date.
	///
	/// The period represents a single day, from 00:00:00 to 23:59:59.
	///
	/// - Parameter date: The date for this period. Time components are normalized to start of day.
	///
	/// - Returns: A daily period.
	///
	/// ## Example
	/// ```swift
	/// let today = Period.day(Date())
	/// print(today.label)  // "2025-01-15"
	/// ```
	public static func day(_ date: Date) -> Period {
		let calendar = Calendar.current
		let startOfDay = calendar.startOfDay(for: date)
		return Period(type: .daily, date: startOfDay)
	}

	/// Creates a monthly period for the specified year and month.
	///
	/// - Parameters:
	///   - year: The year for this period.
	///   - month: The month (1-12). Precondition failure if outside valid range.
	///
	/// - Returns: A monthly period starting on the first day of the specified month.
	///
	/// - Precondition: `month` must be between 1 and 12 inclusive.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// print(jan.label)  // "2025-01"
	/// print(jan.days().count)  // 31
	/// ```
	public static func month(year: Int, month: Int) -> Period {
		precondition(month >= 1 && month <= 12, "Month must be between 1 and 12")

		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = 1

		let calendar = Calendar.current
		guard let date = calendar.date(from: components) else {
			fatalError("Unable to create date from components: year=\(year), month=\(month)")
		}

		return Period(type: .monthly, date: date)
	}

	/// Creates a quarterly period for the specified year and quarter.
	///
	/// Quarters are defined as:
	/// - Q1: January - March
	/// - Q2: April - June
	/// - Q3: July - September
	/// - Q4: October - December
	///
	/// - Parameters:
	///   - year: The year for this period.
	///   - quarter: The quarter (1-4). Precondition failure if outside valid range.
	///
	/// - Returns: A quarterly period starting on the first day of the quarter's first month.
	///
	/// - Precondition: `quarter` must be between 1 and 4 inclusive.
	///
	/// ## Example
	/// ```swift
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print(q1.label)  // "2025-Q1"
	/// print(q1.months().count)  // 3
	/// ```
	public static func quarter(year: Int, quarter: Int) -> Period {
		precondition(quarter >= 1 && quarter <= 4, "Quarter must be between 1 and 4")

		let month = (quarter - 1) * 3 + 1  // Q1=1, Q2=4, Q3=7, Q4=10
		return Period.month(year: year, month: month).asQuarterly()
	}

	/// Creates an annual period for the specified year.
	///
	/// The period starts on January 1 and ends on December 31 of the specified year.
	///
	/// - Parameter year: The year for this period.
	///
	/// - Returns: An annual period for the specified year.
	///
	/// ## Example
	/// ```swift
	/// let year2025 = Period.year(2025)
	/// print(year2025.label)  // "2025"
	/// print(year2025.days().count)  // 365 (or 366 for leap years)
	/// ```
	public static func year(_ year: Int) -> Period {
		return Period.month(year: year, month: 1).asAnnual()
	}

	// MARK: - Computed Properties

	/// The start date of this period (at 00:00:00).
	///
	/// - Daily: Start of the day
	/// - Monthly: First day of the month at 00:00:00
	/// - Quarterly: First day of the first month at 00:00:00
	/// - Annual: January 1 at 00:00:00
	public var startDate: Date {
		return date
	}

	/// The end date of this period (at 23:59:59).
	///
	/// - Daily: End of the day (23:59:59)
	/// - Monthly: Last moment of the last day of the month
	/// - Quarterly: Last moment of the last day of the third month
	/// - Annual: December 31 at 23:59:59
	public var endDate: Date {
		let calendar = Calendar.current

		switch type {
		case .daily:
			// End of day: 23:59:59
			var components = DateComponents()
			components.day = 1
			components.second = -1
			return calendar.date(byAdding: components, to: startDate)!

		case .monthly:
			// Start of next month, minus 1 second
			var components = DateComponents()
			components.month = 1
			let nextMonthStart = calendar.date(byAdding: components, to: startDate)!
			return calendar.date(byAdding: .second, value: -1, to: nextMonthStart)!

		case .quarterly:
			// Start of month after third month, minus 1 second
			var components = DateComponents()
			components.month = 3
			let nextQuarterStart = calendar.date(byAdding: components, to: startDate)!
			return calendar.date(byAdding: .second, value: -1, to: nextQuarterStart)!

		case .annual:
			// Start of next year, minus 1 second
			var components = DateComponents()
			components.year = 1
			let nextYearStart = calendar.date(byAdding: components, to: startDate)!
			return calendar.date(byAdding: .second, value: -1, to: nextYearStart)!
		}
	}

	/// A compact string label for this period.
	///
	/// Format:
	/// - Daily: "YYYY-MM-DD" (e.g., "2025-01-15")
	/// - Monthly: "YYYY-MM" (e.g., "2025-01")
	/// - Quarterly: "YYYY-QN" (e.g., "2025-Q1")
	/// - Annual: "YYYY" (e.g., "2025")
	///
	/// For custom formatting, use ``formatted(using:)``.
	public var label: String {
		let calendar = Calendar.current
		let components = calendar.dateComponents([.year, .month, .day], from: startDate)

		switch type {
		case .daily:
			return String(format: "%04d-%02d-%02d",
						  components.year!,
						  components.month!,
						  components.day!)

		case .monthly:
			return String(format: "%04d-%02d",
						  components.year!,
						  components.month!)

		case .quarterly:
			let quarter = (components.month! - 1) / 3 + 1
			return String(format: "%04d-Q%d",
						  components.year!,
						  quarter)

		case .annual:
			return String(format: "%04d", components.year!)
		}
	}

	// MARK: - Formatting

	/// Formats this period using a custom DateFormatter.
	///
	/// - Parameter formatter: The DateFormatter to use. The formatter will be applied
	///   to the period's `startDate`.
	///
	/// - Returns: A formatted string representation of this period.
	///
	/// ## Example
	/// ```swift
	/// let period = Period.month(year: 2025, month: 1)
	///
	/// let formatter = DateFormatter()
	/// formatter.dateFormat = "MMMM yyyy"
	/// print(period.formatted(using: formatter))  // "January 2025"
	/// ```
	public func formatted(using formatter: DateFormatter) -> String {
		return formatter.string(from: startDate)
	}

	// MARK: - Subdivision

	/// Returns an array of monthly periods that comprise this period.
	///
	/// - Daily: Returns empty array (cannot subdivide)
	/// - Monthly: Returns array containing only this period
	/// - Quarterly: Returns array of 3 monthly periods
	/// - Annual: Returns array of 12 monthly periods
	///
	/// ## Example
	/// ```swift
	/// let year = Period.year(2025)
	/// let months = year.months()  // [Jan, Feb, Mar, ..., Dec]
	/// print(months.count)  // 12
	/// ```
	public func months() -> [Period] {
		switch type {
		case .daily:
			return []  // Cannot subdivide daily period

		case .monthly:
			return [self]

		case .quarterly:
			let calendar = Calendar.current
			let startComponents = calendar.dateComponents([.year, .month], from: startDate)

			return (0..<3).map { offset in
				Period.month(year: startComponents.year!,
							 month: startComponents.month! + offset)
			}

		case .annual:
			let calendar = Calendar.current
			let year = calendar.component(.year, from: startDate)

			return (1...12).map { month in
				Period.month(year: year, month: month)
			}
		}
	}

	/// Returns an array of quarterly periods that comprise this period.
	///
	/// - Daily: Returns empty array (cannot subdivide)
	/// - Monthly: Returns empty array (cannot subdivide)
	/// - Quarterly: Returns array containing only this period
	/// - Annual: Returns array of 4 quarterly periods
	///
	/// ## Example
	/// ```swift
	/// let year = Period.year(2025)
	/// let quarters = year.quarters()  // [Q1, Q2, Q3, Q4]
	/// print(quarters.count)  // 4
	/// ```
	public func quarters() -> [Period] {
		switch type {
		case .daily, .monthly:
			return []  // Cannot subdivide to quarters

		case .quarterly:
			return [self]

		case .annual:
			let calendar = Calendar.current
			let year = calendar.component(.year, from: startDate)

			return (1...4).map { quarter in
				Period.quarter(year: year, quarter: quarter)
			}
		}
	}

	/// Returns an array of daily periods that comprise this period.
	///
	/// - Daily: Returns array containing only this period
	/// - Monthly: Returns array of daily periods (28-31 days depending on month)
	/// - Quarterly: Returns array of daily periods (90-92 days depending on months)
	/// - Annual: Returns array of daily periods (365-366 days depending on leap year)
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let days = jan.days()
	/// print(days.count)  // 31
	///
	/// let feb2024 = Period.month(year: 2024, month: 2)
	/// print(feb2024.days().count)  // 29 (leap year)
	/// ```
	public func days() -> [Period] {
		if type == .daily {
			return [self]
		}

		let calendar = Calendar.current
		var currentDate = startDate
		let end = endDate
		var days: [Period] = []

		while currentDate <= end {
			days.append(Period.day(currentDate))

			// Move to next day
			var components = DateComponents()
			components.day = 1
			guard let nextDate = calendar.date(byAdding: components, to: currentDate) else {
				break
			}
			currentDate = nextDate
		}

		return days
	}

	// MARK: - Comparable Conformance

	// MARK: - Period Advancement

	/// Returns the next period of the same type.
	///
	/// This method advances the period by one unit:
	/// - Daily periods advance by 1 day
	/// - Monthly periods advance by 1 month
	/// - Quarterly periods advance by 1 quarter (3 months)
	/// - Annual periods advance by 1 year
	///
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let feb = jan.next()  // Period.month(year: 2025, month: 2)
	///
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// let q2 = q1.next()  // Period.quarter(year: 2025, quarter: 2)
	/// ```
	public func next() -> Period {
		let calendar = Calendar.current

		switch type {
		case .daily:
			guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
				fatalError("Failed to advance day")
			}
			return Period.day(nextDate)

		case .monthly:
			guard let nextDate = calendar.date(byAdding: .month, value: 1, to: date) else {
				fatalError("Failed to advance month")
			}
			let components = calendar.dateComponents([.year, .month], from: nextDate)
			return Period.month(year: components.year!, month: components.month!)

		case .quarterly:
			guard let nextDate = calendar.date(byAdding: .month, value: 3, to: date) else {
				fatalError("Failed to advance quarter")
			}
			let components = calendar.dateComponents([.year, .month], from: nextDate)
			let month = components.month!
			let quarter = ((month - 1) / 3) + 1
			return Period.quarter(year: components.year!, quarter: quarter)

		case .annual:
			guard let nextDate = calendar.date(byAdding: .year, value: 1, to: date) else {
				fatalError("Failed to advance year")
			}
			let components = calendar.dateComponents([.year], from: nextDate)
			return Period.year(components.year!)
		}
	}

	// MARK: - Comparable Conformance

	/// Compares two periods.
	///
	/// Periods are ordered first by type (shorter periods before longer),
	/// then by start date within the same type.
	///
	/// Type ordering: daily < monthly < quarterly < annual
	///
	/// ## Example
	/// ```swift
	/// // All start on Jan 1, 2025, but ordered by type:
	/// let day = Period.day(someDate)
	/// let month = Period.month(year: 2025, month: 1)
	/// let quarter = Period.quarter(year: 2025, quarter: 1)
	/// let year = Period.year(2025)
	///
	/// // day < month < quarter < year
	/// ```
	public static func < (lhs: Period, rhs: Period) -> Bool {
		// First compare by type (shorter periods first)
		if lhs.type != rhs.type {
			return lhs.type < rhs.type
		}

		// Same type: compare by start date
		return lhs.startDate < rhs.startDate
	}

	// MARK: - Internal Helpers

	/// Internal initializer for creating periods from raw components.
	///
	/// - Parameters:
	///   - type: The period type.
	///   - date: The start date for this period.
	///
	/// - Note: This initializer is internal to allow extensions (like PeriodArithmetic)
	///   to create new periods while maintaining encapsulation.
	internal init(type: PeriodType, date: Date) {
		self.type = type
		self.date = date
	}

	/// Converts this period to a quarterly period (for internal use).
	private func asQuarterly() -> Period {
		return Period(type: .quarterly, date: self.date)
	}

	/// Converts this period to an annual period (for internal use).
	private func asAnnual() -> Period {
		return Period(type: .annual, date: self.date)
	}
}
