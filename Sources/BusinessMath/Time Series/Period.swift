//
//  Period.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

// MARK: - Calendar Cache

/// A cached Calendar instance to avoid repeated Calendar.current calls.
///
/// Creating Calendar instances is expensive. This cached instance significantly
/// improves performance for operations that require calendar calculations,
/// such as period creation and date computations.
private let cachedCalendar = Calendar.current

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
/// ## Irregular Periods
///
/// Not every reporting period sits on the granularity ladder. When a company
/// switches from quarterly to semiannual reporting, or moves its fiscal year-end,
/// it emits one odd-length period at the boundary. Use ``custom(start:end:)`` for
/// those. A custom period knows its own interval, but it cannot be stepped with
/// ``next()`` or ``advanced(by:)`` and it has no type-level duration.
///
/// ## Topics
///
/// ### Creating Periods
/// - ``day(_:)``
/// - ``month(year:month:)``
/// - ``quarter(year:quarter:)``
/// - ``semiannual(year:half:)``
/// - ``year(_:)``
/// - ``custom(start:end:)``
///
/// ### Properties
/// - ``type``
/// - ``date``
/// - ``startDate``
/// - ``endDate``
/// - ``label``
///
/// ### Durations
/// - ``durationInDays``
/// - ``durationInMonths``
/// - ``durationInMilliseconds``
///
/// ### Formatting
/// - ``formatted(using:)``
///
/// ### Subdivision
/// - ``months()``
/// - ``quarters()``
/// - ``semiannuals()``
/// - ``days()``
public struct Period: Hashable, Comparable, Codable, Sendable {

	// MARK: - Properties

	/// The type of this period (daily, monthly, quarterly, semiannual, annual, or custom).
	public let type: PeriodType

	/// The reference date for this period.
	///
	/// For daily periods, this is the specific day (at 00:00:00).
	/// For monthly/quarterly/semiannual/annual periods, this is the first day of the period.
	/// For custom periods, this is the start instant exactly as supplied.
	public let date: Date

	/// The explicitly stored end instant, present only for ``PeriodType/custom`` periods.
	///
	/// Ladder periods leave this `nil` and derive ``endDate`` from `type` + `date`,
	/// which is what keeps their encoded form identical to the pre-`custom` format.
	internal let explicitEnd: Date?

	// MARK: - Factory Methods

	/// Creates a millisecond period for the specified time.
	///
	/// - Parameters:
	///   - year: The year.
	///   - month: The month (1-12).
	///   - day: The day of month.
	///   - hour: The hour (0-23).
	///   - minute: The minute (0-59).
	///   - second: The second (0-59).
	///   - millisecond: The millisecond (0-999).
	///
	/// - Returns: A millisecond period.
	public static func millisecond(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, millisecond: Int) -> Period {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.hour = hour
		components.minute = minute
		components.second = second
		components.nanosecond = millisecond * 1_000_000

		guard let date = cachedCalendar.date(from: components) else {
			preconditionFailure("Unable to create date from millisecond components")
		}

		return Period(type: .millisecond, date: date)
	}

	/// Creates a second period for the specified time.
	///
	/// - Parameters:
	///   - year: The year.
	///   - month: The month (1-12).
	///   - day: The day of month.
	///   - hour: The hour (0-23).
	///   - minute: The minute (0-59).
	///   - second: The second (0-59).
	///
	/// - Returns: A second period.
	public static func second(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Period {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.hour = hour
		components.minute = minute
		components.second = second

		guard let date = cachedCalendar.date(from: components) else {
			preconditionFailure("Unable to create date from second components")
		}

		return Period(type: .second, date: date)
	}

	/// Creates a minute period for the specified time.
	///
	/// - Parameters:
	///   - year: The year.
	///   - month: The month (1-12).
	///   - day: The day of month.
	///   - hour: The hour (0-23).
	///   - minute: The minute (0-59).
	///
	/// - Returns: A minute period.
	public static func minute(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Period {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.hour = hour
		components.minute = minute
		components.second = 0

		guard let date = cachedCalendar.date(from: components) else {
			preconditionFailure("Unable to create date from minute components")
		}

		return Period(type: .minute, date: date)
	}

	/// Creates an hourly period for the specified time.
	///
	/// - Parameters:
	///   - year: The year.
	///   - month: The month (1-12).
	///   - day: The day of month.
	///   - hour: The hour (0-23).
	///
	/// - Returns: An hourly period.
	public static func hour(year: Int, month: Int, day: Int, hour: Int) -> Period {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		components.hour = hour
		components.minute = 0
		components.second = 0

		guard let date = cachedCalendar.date(from: components) else {
			preconditionFailure("Unable to create date from hour components")
		}

		return Period(type: .hourly, date: date)
	}

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
		let startOfDay = cachedCalendar.startOfDay(for: date)
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
		guard month >= 1, month <= 12 else {
			preconditionFailure("Month must be between 1 and 12")
		}

		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = 1

		guard let date = cachedCalendar.date(from: components) else {
			preconditionFailure("Unable to create date from components: year=\(year), month=\(month)")
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
		guard quarter >= 1, quarter <= 4 else {
			preconditionFailure("Quarter must be between 1 and 4")
		}

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

	/// Creates a semiannual period for the specified year and half.
	///
	/// Halves are defined as:
	/// - H1: January - June
	/// - H2: July - December
	///
	/// Semiannual reporting is the cadence US public companies would move to if
	/// quarterly reporting requirements were relaxed.
	///
	/// - Parameters:
	///   - year: The year for this period.
	///   - half: The half (1-2). Precondition failure if outside valid range.
	///
	/// - Returns: A semiannual period starting on the first day of the half's first month.
	///
	/// - Precondition: `half` must be 1 or 2.
	///
	/// ## Example
	/// ```swift
	/// let h1 = Period.semiannual(year: 2025, half: 1)
	/// print(h1.label)              // "2025-H1"
	/// print(h1.months().count)     // 6
	/// print(h1.quarters().count)   // 2
	/// ```
	public static func semiannual(year: Int, half: Int) -> Period {
		guard half >= 1, half <= 2 else {
			preconditionFailure("Half must be 1 or 2")
		}

		let month = (half - 1) * 6 + 1  // H1=1, H2=7
		return Period.month(year: year, month: month).asSemiannual()
	}

	/// Creates a period covering an arbitrary date range.
	///
	/// Use this for irregular reporting periods that no granularity rung can express:
	/// the odd-length stub emitted when a company switches from quarterly to
	/// semiannual reporting mid-year, or when it moves its fiscal year-end.
	///
	/// The interval is stored verbatim. `end` becomes the period's ``endDate`` —
	/// that is, it is the last instant *included* in the period, matching how
	/// ``endDate`` behaves for every other period type.
	///
	/// - Parameters:
	///   - start: The first instant of the period.
	///   - end: The last instant of the period. Must not precede `start`.
	///
	/// - Returns: A custom period spanning `start` through `end`.
	///
	/// - Precondition: `end >= start`.
	///
	/// - Note: A custom period cannot be stepped. ``next()`` and ``advanced(by:)``
	///   trap on it, ``distance(to:)`` throws, and it cannot appear in a ``PeriodRange``.
	///   Use ``nextIfSteppable()`` / ``advancedIfSteppable(by:)`` when the type is not
	///   known statically.
	///
	/// ## Example
	/// ```swift
	/// // A company moving from quarterly to semiannual reporting emits a
	/// // five-month stub between its last quarter and its first half.
	/// let stub = Period.custom(start: aprilFirst, end: augustThirtyFirst)
	/// print(stub.durationInDays)   // 152.0
	/// print(stub.months())         // [] — a stub is not divisible on the ladder
	/// ```
	public static func custom(start: Date, end: Date) -> Period {
		guard end >= start else {
			preconditionFailure("Custom period end (\(end)) must not precede its start (\(start))")
		}
		return Period(type: .custom, date: start, explicitEnd: end)
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
	/// - Semiannual: Last moment of the last day of the sixth month
	/// - Annual: December 31 at 23:59:59
	/// - Custom: the end instant supplied to ``custom(start:end:)``, verbatim
	public var endDate: Date {
		let calendar = cachedCalendar

		// A custom period carries its own end; nothing about its type implies one.
		if let explicitEnd {
			return explicitEnd
		}

		switch type {
		case .millisecond:
			// End of millisecond: next millisecond minus 1 nanosecond
			guard let nextMillisecond = calendar.date(byAdding: .nanosecond, value: 1_000_000, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .nanosecond, value: -1, to: nextMillisecond) ?? startDate

		case .second:
			// End of second: next second minus 1 nanosecond
			guard let nextSecond = calendar.date(byAdding: .second, value: 1, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .nanosecond, value: -1, to: nextSecond) ?? startDate

		case .minute:
			// End of minute: next minute minus 1 nanosecond
			guard let nextMinute = calendar.date(byAdding: .minute, value: 1, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .nanosecond, value: -1, to: nextMinute) ?? startDate

		case .hourly:
			// End of hour: next hour minus 1 nanosecond
			guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .nanosecond, value: -1, to: nextHour) ?? startDate

		case .daily:
			// End of day: 23:59:59
			var components = DateComponents()
			components.day = 1
			components.second = -1
			return calendar.date(byAdding: components, to: startDate) ?? startDate

		case .monthly:
			// Start of next month, minus 1 second
			var components = DateComponents()
			components.month = 1
			guard let nextMonthStart = calendar.date(byAdding: components, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .second, value: -1, to: nextMonthStart) ?? startDate

		case .quarterly:
			// Start of month after third month, minus 1 second
			var components = DateComponents()
			components.month = 3
			guard let nextQuarterStart = calendar.date(byAdding: components, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .second, value: -1, to: nextQuarterStart) ?? startDate

		case .semiannual:
			// Start of month after sixth month, minus 1 second
			var components = DateComponents()
			components.month = 6
			guard let nextHalfStart = calendar.date(byAdding: components, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .second, value: -1, to: nextHalfStart) ?? startDate

		case .custom:
			// Unreachable in practice: `custom(start:end:)` always stores an explicit
			// end, and decoding rejects a custom period without one. A zero-length
			// range is the only non-fabricated fallback.
			return startDate

		case .annual:
			// Start of next year, minus 1 second
			var components = DateComponents()
			components.year = 1
			guard let nextYearStart = calendar.date(byAdding: components, to: startDate) else {
				return startDate
			}
			return calendar.date(byAdding: .second, value: -1, to: nextYearStart) ?? startDate
		}
	}

	/// A compact string label for this period.
	///
	/// Format:
	/// - Daily: "YYYY-MM-DD" (e.g., "2025-01-15")
	/// - Monthly: "YYYY-MM" (e.g., "2025-01")
	/// - Quarterly: "YYYY-QN" (e.g., "2025-Q1")
	/// - Semiannual: "YYYY-HN" (e.g., "2025-H1")
	/// - Annual: "YYYY" (e.g., "2025")
	/// - Custom: "YYYY-MM-DD/YYYY-MM-DD" (e.g., "2025-04-01/2025-08-31")
	///
	/// For custom formatting, use ``formatted(using:)``.
	public var label: String {
		let calendar = cachedCalendar
		let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: startDate)

		switch type {
		case .millisecond:
			let yearStr = String(components.year ?? 0).paddingLeft(toLength: 4, withPad: "0")
			let monthStr = String(components.month ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let dayStr = String(components.day ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let hourStr = String(components.hour ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let minuteStr = String(components.minute ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let secondStr = String(components.second ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let msStr = String((components.nanosecond ?? 0) / 1_000_000).paddingLeft(toLength: 3, withPad: "0")
			return "\(yearStr)-\(monthStr)-\(dayStr)T\(hourStr):\(minuteStr):\(secondStr).\(msStr)"

		case .second:
			let yearStr = String(components.year ?? 0).paddingLeft(toLength: 4, withPad: "0")
			let monthStr = String(components.month ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let dayStr = String(components.day ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let hourStr = String(components.hour ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let minuteStr = String(components.minute ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let secondStr = String(components.second ?? 0).paddingLeft(toLength: 2, withPad: "0")
			return "\(yearStr)-\(monthStr)-\(dayStr)T\(hourStr):\(minuteStr):\(secondStr)"

		case .minute:
			let yearStr = String(components.year ?? 0).paddingLeft(toLength: 4, withPad: "0")
			let monthStr = String(components.month ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let dayStr = String(components.day ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let hourStr = String(components.hour ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let minuteStr = String(components.minute ?? 0).paddingLeft(toLength: 2, withPad: "0")
			return "\(yearStr)-\(monthStr)-\(dayStr)T\(hourStr):\(minuteStr)"

		case .hourly:
			let yearStr = String(components.year ?? 0).paddingLeft(toLength: 4, withPad: "0")
			let monthStr = String(components.month ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let dayStr = String(components.day ?? 0).paddingLeft(toLength: 2, withPad: "0")
			let hourStr = String(components.hour ?? 0).paddingLeft(toLength: 2, withPad: "0")
			return "\(yearStr)-\(monthStr)-\(dayStr)T\(hourStr)"

		case .daily:
			let yearStr = String(year).padding(toLength: 4, withPad: "0", startingAt: 0)
			let monthStr = String(month).paddingLeft(toLength: 2, withPad: "0")
			let dayStr = String(day).paddingLeft(toLength: 2, withPad: "0")
			return "\(yearStr)-\(monthStr)-\(dayStr)"

		case .monthly:
			let yearStr = String(year).paddingLeft(toLength: 4, withPad: "0")
			let monthStr = String(month).paddingLeft(toLength: 2, withPad: "0")
			return "\(yearStr)-\(monthStr)"

		case .quarterly:
			let yearStr = String(year).paddingLeft(toLength: 4, withPad: "0")
			let quarter = ((components.month ?? 1) - 1) / 3 + 1
			let quarterStr = String(quarter).paddingLeft(toLength: 2, withPad: "Q")
			return "\(yearStr)-\(quarterStr)"

		case .semiannual:
			let yearStr = String(year).paddingLeft(toLength: 4, withPad: "0")
			let half = ((components.month ?? 1) - 1) / 6 + 1
			let halfStr = String(half).paddingLeft(toLength: 2, withPad: "H")
			return "\(yearStr)-\(halfStr)"

		case .annual:
			return String(components.year ?? 0)

		case .custom:
			// ISO 8601 interval notation, so the label is unambiguous about being a range.
			return "\(Period.isoDayString(for: startDate))/\(Period.isoDayString(for: endDate))"
		}
	}

	/// Renders a date as `YYYY-MM-DD` using the cached calendar.
	private static func isoDayString(for date: Date) -> String {
		let components = cachedCalendar.dateComponents([.year, .month, .day], from: date)
		let yearStr = String(components.year ?? 0).paddingLeft(toLength: 4, withPad: "0")
		let monthStr = String(components.month ?? 0).paddingLeft(toLength: 2, withPad: "0")
		let dayStr = String(components.day ?? 0).paddingLeft(toLength: 2, withPad: "0")
		return "\(yearStr)-\(monthStr)-\(dayStr)"
	}
	
	var description: String {
		return label
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
	/// - Semiannual: Returns array of 6 monthly periods
	/// - Annual: Returns array of 12 monthly periods
	/// - Custom: Returns empty array (an arbitrary range is not divisible on the ladder)
	///
	/// ## Example
	/// ```swift
	/// let year = Period.year(2025)
	/// let months = year.months()  // [Jan, Feb, Mar, ..., Dec]
	/// print(months.count)  // 12
	/// ```
	public func months() -> [Period] {
		switch type {
		case .millisecond, .second, .minute, .hourly, .daily:
			return []  // Cannot subdivide sub-daily or daily periods to months

		case .custom:
			// An arbitrary range need not begin or end on a month boundary, so there is
			// no honest set of whole months to return. Use `days()` for its real extent.
			return []

		case .monthly:
			return [self]

		case .quarterly:
			let calendar = cachedCalendar
			let startComponents = calendar.dateComponents([.year, .month], from: startDate)

			return (0..<3).map { offset in
				Period.month(year: startComponents.year ?? 0,
							 month: (startComponents.month ?? 1) + offset)
			}

		case .semiannual:
			let calendar = cachedCalendar
			let startComponents = calendar.dateComponents([.year, .month], from: startDate)

			return (0..<6).map { offset in
				Period.month(year: startComponents.year ?? 0,
							 month: (startComponents.month ?? 1) + offset)
			}

		case .annual:
			let calendar = cachedCalendar
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
	/// - Semiannual: Returns array of 2 quarterly periods
	/// - Annual: Returns array of 4 quarterly periods
	/// - Custom: Returns empty array (an arbitrary range is not divisible on the ladder)
	///
	/// ## Example
	/// ```swift
	/// let year = Period.year(2025)
	/// let quarters = year.quarters()  // [Q1, Q2, Q3, Q4]
	/// print(quarters.count)  // 4
	/// ```
	public func quarters() -> [Period] {
		switch type {
		case .millisecond, .second, .minute, .hourly, .daily, .monthly:
			return []  // Cannot subdivide to quarters

		case .custom:
			return []  // An arbitrary range has no whole-quarter decomposition

		case .quarterly:
			return [self]

		case .semiannual:
			let calendar = cachedCalendar
			let components = calendar.dateComponents([.year, .month], from: startDate)
			let year = components.year ?? 0
			let firstQuarter = ((components.month ?? 1) - 1) / 3 + 1

			return (0..<2).map { offset in
				Period.quarter(year: year, quarter: firstQuarter + offset)
			}

		case .annual:
			let calendar = cachedCalendar
			let year = calendar.component(.year, from: startDate)

			return (1...4).map { quarter in
				Period.quarter(year: year, quarter: quarter)
			}
		}
	}

	/// Returns an array of semiannual periods that comprise this period.
	///
	/// - Semiannual: Returns array containing only this period
	/// - Annual: Returns array of 2 semiannual periods (H1, H2)
	/// - Everything else: Returns empty array (cannot subdivide to halves)
	///
	/// ## Example
	/// ```swift
	/// let year = Period.year(2025)
	/// let halves = year.semiannuals()  // [2025-H1, 2025-H2]
	/// print(halves.count)  // 2
	/// ```
	public func semiannuals() -> [Period] {
		switch type {
		case .millisecond, .second, .minute, .hourly, .daily, .monthly, .quarterly, .custom:
			return []  // Cannot subdivide to halves

		case .semiannual:
			return [self]

		case .annual:
			let calendar = cachedCalendar
			let year = calendar.component(.year, from: startDate)

			return (1...2).map { half in
				Period.semiannual(year: year, half: half)
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

		let calendar = cachedCalendar
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

	/// Returns an array of hourly periods that comprise this period.
	///
	/// - Returns: Array of hourly periods, or empty array if period cannot be subdivided.
	///
	/// ## Example
	/// ```swift
	/// let day = Period.day(Date())
	/// let hours = day.hours()
	/// print(hours.count)  // 24
	/// ```
	public func hours() -> [Period] {
		switch type {
		case .millisecond, .second, .minute:
			return []  // Cannot subdivide sub-hourly periods into hours
		case .hourly:
			return [self]
		case .daily, .monthly, .quarterly, .semiannual, .annual, .custom:
			// Generate hourly periods
			let calendar = cachedCalendar
			var currentDate = startDate
			let end = endDate
			var hours: [Period] = []

			while currentDate < end {
				let components = calendar.dateComponents([.year, .month, .day, .hour], from: currentDate)
				hours.append(Period.hour(
					year: components.year ?? 0,
					month: components.month ?? 1,
					day: components.day ?? 1,
					hour: components.hour ?? 0
				))

				// Move to next hour
				var nextComponents = DateComponents()
				nextComponents.hour = 1
				guard let nextDate = calendar.date(byAdding: nextComponents, to: currentDate) else {
					break
				}
				currentDate = nextDate
			}

			return hours
		}
	}

	/// Returns an array of minute periods that comprise this period.
	///
	/// - Returns: Array of minute periods, or empty array if period cannot be subdivided.
	///
	/// ## Example
	/// ```swift
	/// let hour = Period.hour(year: 2025, month: 1, day: 29, hour: 14)
	/// let minutes = hour.minutes()
	/// print(minutes.count)  // 60
	/// ```
	public func minutes() -> [Period] {
		switch type {
		case .millisecond, .second:
			return []  // Cannot subdivide sub-minute periods into minutes
		case .minute:
			return [self]
		case .hourly, .daily, .monthly, .quarterly, .semiannual, .annual, .custom:
			// Generate minute periods
			let calendar = cachedCalendar
			var currentDate = startDate
			let end = endDate
			var minutes: [Period] = []

			while currentDate < end {
				let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: currentDate)
				minutes.append(Period.minute(
					year: components.year ?? 0,
					month: components.month ?? 1,
					day: components.day ?? 1,
					hour: components.hour ?? 0,
					minute: components.minute ?? 0
				))

				// Move to next minute
				var nextComponents = DateComponents()
				nextComponents.minute = 1
				guard let nextDate = calendar.date(byAdding: nextComponents, to: currentDate) else {
					break
				}
				currentDate = nextDate
			}

			return minutes
		}
	}

	/// Returns an array of second periods that comprise this period.
	///
	/// - Returns: Array of second periods, or empty array if period cannot be subdivided.
	///
	/// ## Example
	/// ```swift
	/// let minute = Period.minute(year: 2025, month: 1, day: 29, hour: 14, minute: 30)
	/// let seconds = minute.seconds()
	/// print(seconds.count)  // 60
	/// ```
	public func seconds() -> [Period] {
		switch type {
		case .millisecond:
			return []  // Cannot subdivide milliseconds into seconds
		case .second:
			return [self]
		case .minute, .hourly, .daily, .monthly, .quarterly, .semiannual, .annual, .custom:
			// Generate second periods
			let calendar = cachedCalendar
			var currentDate = startDate
			let end = endDate
			var seconds: [Period] = []

			while currentDate < end {
				let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: currentDate)
				seconds.append(Period.second(
					year: components.year ?? 0,
					month: components.month ?? 1,
					day: components.day ?? 1,
					hour: components.hour ?? 0,
					minute: components.minute ?? 0,
					second: components.second ?? 0
				))

				// Move to next second
				var nextComponents = DateComponents()
				nextComponents.second = 1
				guard let nextDate = calendar.date(byAdding: nextComponents, to: currentDate) else {
					break
				}
				currentDate = nextDate
			}

			return seconds
		}
	}

	/// Returns an array of millisecond periods that comprise this period.
	///
	/// - Returns: Array of millisecond periods, or empty array if period cannot be subdivided.
	///
	/// ## Example
	/// ```swift
	/// let second = Period.second(year: 2025, month: 1, day: 29, hour: 14, minute: 30, second: 45)
	/// let milliseconds = second.milliseconds()
	/// print(milliseconds.count)  // 1000
	/// ```
	public func milliseconds() -> [Period] {
		switch type {
		case .millisecond:
			return [self]
		case .second, .minute, .hourly, .daily, .monthly, .quarterly, .semiannual, .annual, .custom:
			// Generate millisecond periods
			let calendar = cachedCalendar
			var currentDate = startDate
			let end = endDate
			var milliseconds: [Period] = []

			while currentDate < end {
				let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: currentDate)
				let ms = (components.nanosecond ?? 0) / 1_000_000
				milliseconds.append(Period.millisecond(
					year: components.year ?? 0,
					month: components.month ?? 1,
					day: components.day ?? 1,
					hour: components.hour ?? 0,
					minute: components.minute ?? 0,
					second: components.second ?? 0,
					millisecond: ms
				))

				// Move to next millisecond
				var nextComponents = DateComponents()
				nextComponents.nanosecond = 1_000_000
				guard let nextDate = calendar.date(byAdding: nextComponents, to: currentDate) else {
					break
				}
				currentDate = nextDate
			}

			return milliseconds
		}
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
		let calendar = cachedCalendar

		switch type {
		case .millisecond:
			guard let nextDate = calendar.date(byAdding: .nanosecond, value: 1_000_000, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: nextDate)
			return Period.millisecond(
				year: components.year ?? 0,
				month: components.month ?? 1,
				day: components.day ?? 1,
				hour: components.hour ?? 0,
				minute: components.minute ?? 0,
				second: components.second ?? 0,
				millisecond: (components.nanosecond ?? 0) / 1_000_000
			)

		case .second:
			guard let nextDate = calendar.date(byAdding: .second, value: 1, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: nextDate)
			return Period.second(
				year: components.year ?? 0,
				month: components.month ?? 1,
				day: components.day ?? 1,
				hour: components.hour ?? 0,
				minute: components.minute ?? 0,
				second: components.second ?? 0
			)

		case .minute:
			guard let nextDate = calendar.date(byAdding: .minute, value: 1, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: nextDate)
			return Period.minute(
				year: components.year ?? 0,
				month: components.month ?? 1,
				day: components.day ?? 1,
				hour: components.hour ?? 0,
				minute: components.minute ?? 0
			)

		case .hourly:
			guard let nextDate = calendar.date(byAdding: .hour, value: 1, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month, .day, .hour], from: nextDate)
			return Period.hour(
				year: components.year ?? 0,
				month: components.month ?? 1,
				day: components.day ?? 1,
				hour: components.hour ?? 0
			)

		case .daily:
			guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else {
				return self
			}
			return Period.day(nextDate)

		case .monthly:
			guard let nextDate = calendar.date(byAdding: .month, value: 1, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month], from: nextDate)
			return Period.month(year: components.year ?? 0, month: components.month ?? 1)

		case .quarterly:
			guard let nextDate = calendar.date(byAdding: .month, value: 3, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month], from: nextDate)
			let month = components.month ?? 1
			let quarter = ((month - 1) / 3) + 1
			return Period.quarter(year: components.year ?? 0, quarter: quarter)

		case .semiannual:
			guard let nextDate = calendar.date(byAdding: .month, value: 6, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year, .month], from: nextDate)
			let month = components.month ?? 1
			let half = ((month - 1) / 6) + 1
			return Period.semiannual(year: components.year ?? 0, half: half)

		case .annual:
			guard let nextDate = calendar.date(byAdding: .year, value: 1, to: date) else {
				return self
			}
			let components = calendar.dateComponents([.year], from: nextDate)
			return Period.year(components.year ?? 0)

		case .custom:
			preconditionFailure(Period.notSteppableMessage("next()", alternative: "nextIfSteppable()"))
		}
	}

	/// The next period of the same type, or `nil` when this period cannot be stepped.
	///
	/// Identical to ``next()`` for every rung of the granularity ladder. Returns `nil`
	/// for ``PeriodType/custom``, because an arbitrary range has no defined successor:
	/// nothing about "April 1 through August 31" says where the following stub begins.
	///
	/// Use this instead of ``next()`` whenever the period's type is not known statically.
	///
	/// ## Example
	/// ```swift
	/// guard let following = period.nextIfSteppable() else {
	///     // A transition stub — the caller has to supply the next boundary itself.
	///     return
	/// }
	/// ```
	public func nextIfSteppable() -> Period? {
		guard type.isRegular else { return nil }
		return next()
	}

	/// The message used when a stepping operation is attempted on an arbitrary range.
	fileprivate static func notSteppableMessage(_ operation: String, alternative: String) -> String {
		return """
			Period.custom cannot be stepped with \(operation): an arbitrary date range has no \
			defined successor or predecessor. Use \(alternative), which returns nil, or build \
			the next period explicitly with Period.custom(start:end:).
			"""
	}

	// MARK: - Comparable Conformance

	/// Compares two periods.
	///
	/// Periods are ordered first by type (shorter periods before longer),
	/// then by start date, then by end date within the same type.
	///
	/// The end-date tie-break only ever fires for ``PeriodType/custom`` periods —
	/// every other type derives its end from its type and start date, so equal
	/// type and start already imply equal end. Without it, two distinct custom
	/// ranges sharing a start would compare as neither less nor greater while
	/// still being unequal, which breaks sorting and `Set`/`Dictionary` ordering
	/// assumptions.
	///
	/// Type ordering: daily < monthly < quarterly < semiannual < annual < custom
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
		if lhs.startDate != rhs.startDate {
			return lhs.startDate < rhs.startDate
		}

		// Same type and start: only custom periods can still differ, by their end.
		return lhs.endDate < rhs.endDate
	}

	// MARK: - Internal Helpers

	/// Internal initializer for creating periods from raw components.
	///
	/// - Parameters:
	///   - type: The period type.
	///   - date: The start date for this period.
	///   - explicitEnd: An explicit end instant. Supply this only for
	///     ``PeriodType/custom``; ladder types derive their end from type + date.
	///
	/// - Note: This initializer is internal to allow extensions (like PeriodArithmetic)
	///   to create new periods while maintaining encapsulation.
	internal init(type: PeriodType, date: Date, explicitEnd: Date? = nil) {
		self.type = type
		self.date = date
		self.explicitEnd = explicitEnd
	}

	/// Converts this period to a quarterly period (for internal use).
	private func asQuarterly() -> Period {
		return Period(type: .quarterly, date: self.date)
	}

	/// Converts this period to a semiannual period (for internal use).
	private func asSemiannual() -> Period {
		return Period(type: .semiannual, date: self.date)
	}

	/// Converts this period to an annual period (for internal use).
	private func asAnnual() -> Period {
		return Period(type: .annual, date: self.date)
	}
}

// MARK: - Codable

extension Period {

	/// Coding keys for `Period`.
	///
	/// `type` and `date` match the keys the compiler synthesized before ``PeriodType/custom``
	/// existed. `end` is new and optional, which is what makes the format
	/// backward compatible in both directions.
	private enum CodingKeys: String, CodingKey {
		case type
		case date
		case end
	}

	/// Decodes a period, tolerating payloads written before custom ranges existed.
	///
	/// A payload without an `end` key is a ladder period, exactly as previously
	/// persisted: its end is derived from `type` + `date` at read time. A payload
	/// with an `end` key carries an explicit interval.
	///
	/// - Throws: `DecodingError.dataCorrupted` if a ``PeriodType/custom`` period
	///   arrives without an `end`, or with an `end` that precedes its start. Both
	///   are unrecoverable — there is no defensible value to substitute.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let decodedType = try container.decode(PeriodType.self, forKey: .type)
		let decodedDate = try container.decode(Date.self, forKey: .date)
		let decodedEnd = try container.decodeIfPresent(Date.self, forKey: .end)

		if decodedType == .custom {
			guard let decodedEnd else {
				throw DecodingError.dataCorruptedError(
					forKey: .end,
					in: container,
					debugDescription: "A custom period requires an explicit end date; none was present."
				)
			}
			guard decodedEnd >= decodedDate else {
				throw DecodingError.dataCorruptedError(
					forKey: .end,
					in: container,
					debugDescription: "A custom period's end (\(decodedEnd)) must not precede its start (\(decodedDate))."
				)
			}
		}

		// A stray `end` on a ladder type is ignored rather than honored: the type
		// already determines the end, and trusting the payload would let two encodings
		// of the same quarter disagree.
		self.init(type: decodedType, date: decodedDate, explicitEnd: decodedType == .custom ? decodedEnd : nil)
	}

	/// Encodes a period.
	///
	/// Ladder periods emit only `type` and `date`, byte-identical to the format
	/// produced before custom ranges existed, so older readers keep working.
	/// Custom periods add an `end` key.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(type, forKey: .type)
		try container.encode(date, forKey: .date)
		try container.encodeIfPresent(explicitEnd, forKey: .end)
	}
}

// MARK: - Instance Durations

extension Period {

	/// The length of this period in days.
	///
	/// For every rung of the granularity ladder this is the type-level approximation
	/// (``PeriodType/daysApproximate``), so a monthly period reports 30.4375 days
	/// regardless of which month it is — the same normalized figure the conversion
	/// tables have always used.
	///
	/// For ``PeriodType/custom`` it is the *actual* elapsed time of the stored
	/// interval, because an arbitrary range has no type to consult.
	///
	/// ## Example
	/// ```swift
	/// Period.quarter(year: 2025, quarter: 1).durationInDays   // 91.3125 (type average)
	/// Period.custom(start: apr1, end: aug31).durationInDays   // 152.0 (actual)
	/// ```
	public var durationInDays: Double {
		guard type.isRegular else {
			return endDate.timeIntervalSince(startDate) / 86_400.0 // fp-safety:disable — literal constant
		}
		return type.daysApproximate
	}

	/// The length of this period in milliseconds.
	///
	/// Type-level for ladder periods (``PeriodType/millisecondsExact``); the actual
	/// interval for ``PeriodType/custom``.
	public var durationInMilliseconds: Double {
		guard type.isRegular else {
			return endDate.timeIntervalSince(startDate) * 1_000.0
		}
		return type.millisecondsExact
	}

	/// The length of this period in months.
	///
	/// Type-level for ladder periods (``PeriodType/monthsEquivalent``). For
	/// ``PeriodType/custom`` the actual interval is converted at the standard
	/// 365.25/12 days per month, so the result is generally fractional.
	public var durationInMonths: Double {
		guard type.isRegular else {
			let averageDaysPerMonth = 365.25 / 12.0 // fp-safety:disable — literal constants
			return durationInDays / averageDaysPerMonth // fp-safety:disable — divisor is a positive constant
		}
		return type.monthsEquivalent
	}
}

// MARK: - Convenience Properties

/// Calendar components of a period.
///
/// - Important: Every property in this extension describes the period's **start
///   date**. That is unambiguous for ladder periods, whose start determines the
///   whole span. For ``PeriodType/custom`` it is only a description of where the
///   range begins: a stub running April 1 to August 31 reports `quarter == 2` and
///   `half == 1` even though it spills into Q3 and H2. Use ``Period/startDate``,
///   ``Period/endDate``, and ``Period/durationInDays`` when the extent matters.
extension Period {
	/// The year in which this period starts.
	///
	/// ## Example
	/// ```swift
	/// let q1 = Period.quarter(year: 2025, quarter: 1)
	/// print(q1.year)  // 2025
	/// ```
	public var year: Int {
		let calendar = cachedCalendar
		return calendar.component(.year, from: startDate)
	}

	/// The half of the year in which this period starts (1-2).
	///
	/// - H1: January - June (months 1-6)
	/// - H2: July - December (months 7-12)
	///
	/// ## Example
	/// ```swift
	/// let oct = Period.month(year: 2025, month: 10)
	/// print(oct.half)  // 2
	/// ```
	public var half: Int {
		let calendar = cachedCalendar
		let month = calendar.component(.month, from: startDate)
		return ((month - 1) / 6) + 1
	}

	/// The quarter in which this period starts (1-4).
	///
	/// Returns the quarter based on the month:
	/// - Q1: January - March (months 1-3)
	/// - Q2: April - June (months 4-6)
	/// - Q3: July - September (months 7-9)
	/// - Q4: October - December (months 10-12)
	///
	/// ## Example
	/// ```swift
	/// let oct = Period.month(year: 2025, month: 10)
	/// print(oct.quarter)  // 4
	/// ```
	public var quarter: Int {
		let calendar = cachedCalendar
		let month = calendar.component(.month, from: startDate)
		return ((month - 1) / 3) + 1
	}

	/// The month component of this period (1-12).
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// print(jan.month)  // 1
	/// ```
	public var month: Int {
		let calendar = cachedCalendar
		return calendar.component(.month, from: startDate)
	}

	/// The day component of this period (1-31).
	///
	/// ## Example
	/// ```swift
	/// let today = Period.day(Date())
	/// print(today.day)  // Day of month
	/// ```
	public var day: Int {
		let calendar = cachedCalendar
		return calendar.component(.day, from: startDate)
	}
}
