//
//  PeriodType.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// Represents the type of time period used in financial and analytical models.
///
/// `PeriodType` defines the granularity of time periods from milliseconds to years,
/// enabling precise conversion between different time scales. All conversions
/// account for leap years using 365.25 days per year.
///
/// ## Supported Period Types
///
/// **Sub-Daily Periods** (for high-frequency data analysis):
/// - ``millisecond``: Millisecond periods (0.001 seconds)
/// - ``second``: Second periods
/// - ``minute``: Minute periods (60 seconds)
/// - ``hourly``: Hourly periods (3600 seconds)
///
/// **Standard Periods** (for financial analysis):
/// - ``daily``: Single day periods (86,400 seconds)
/// - ``monthly``: Monthly periods (30.4375 days average)
/// - ``quarterly``: Quarterly periods (91.3125 days average)
/// - ``annual``: Annual periods (365.25 days accounting for leap years)
///
/// ## Usage Examples
///
/// ### Financial Analysis
/// ```swift
/// // Compare period types
/// let monthly = PeriodType.monthly
/// let quarterly = PeriodType.quarterly
/// if monthly < quarterly {
///     print("Monthly periods are shorter than quarterly")
/// }
///
/// // Convert 12 months to years
/// let years = PeriodType.monthly.convert(12.0, to: .annual)  // 1.0
///
/// // Convert daily production to monthly rate
/// let dailyBarrels = 1000.0
/// let daysInMonth = 31.0
/// let monthlyRate = PeriodType.daily.convert(dailyBarrels * daysInMonth, to: .monthly)
/// ```
///
/// ### High-Frequency Data Analysis
/// ```swift
/// // Sub-daily period ordering
/// let millisecond = PeriodType.millisecond
/// let second = PeriodType.second
/// if millisecond < second {
///     print("Milliseconds are finer granularity than seconds")
/// }
///
/// // Convert milliseconds to exact duration
/// let msPerSecond = PeriodType.second.millisecondsExact  // 1000.0
/// let msPerHour = PeriodType.hourly.millisecondsExact   // 3,600,000.0
///
/// // Convert hours to days
/// let hoursInDay = PeriodType.hourly.convert(24.0, to: .daily)  // 1.0
/// ```
///
/// ## Topics
///
/// ### Period Types
/// - ``daily``
/// - ``monthly``
/// - ``quarterly``
/// - ``annual``
///
/// ### Properties
/// - ``daysApproximate``
/// - ``monthsEquivalent``
///
/// ### Conversions
/// - ``convert(_:to:)``
public enum PeriodType: Int, Codable, Comparable, CaseIterable, Sendable {

	// MARK: - Cases

	/// Millisecond period type (0.001 seconds).
	case millisecond = 0

	/// Second period type (1 second).
	case second = 1

	/// Minute period type (60 seconds).
	case minute = 2

	/// Hourly period type (3600 seconds).
	case hourly = 3

	/// Daily period type (1 day).
	case daily = 4

	/// Monthly period type (average 30.4375 days).
	///
	/// Calculated as 365.25 days per year / 12 months per year.
	case monthly = 5

	/// Quarterly period type (average 91.3125 days).
	///
	/// Calculated as 365.25 days per year / 4 quarters per year.
	case quarterly = 6

	/// Annual period type (365.25 days).
	///
	/// Accounts for leap years by using 365.25 days per year.
	case annual = 7

	// MARK: - Computed Properties

	/// The approximate number of days in this period type.
	///
	/// Returns precise values accounting for leap years:
	/// - Daily: 1.0
	/// - Monthly: 30.4375 (365.25 / 12)
	/// - Quarterly: 91.3125 (365.25 / 4)
	/// - Annual: 365.25
	///
	/// - Returns: The number of days as a `Double`.
	///
	/// ## Example
	/// ```swift
	/// let daysPerMonth = PeriodType.monthly.daysApproximate
	/// print(daysPerMonth)  // 30.4375
	/// ```
	public var daysApproximate: Double {
		switch self {
		case .millisecond:
			return 1.0 / 86_400_000.0
		case .second:
			return 1.0 / 86_400.0
		case .minute:
			return 1.0 / 1_440.0
		case .hourly:
			return 1.0 / 24.0
		case .daily:
			return 1.0
		case .monthly:
			return 365.25 / 12.0  // 30.4375
		case .quarterly:
			return 365.25 / 4.0   // 91.3125
		case .annual:
			return 365.25
		}
	}

	/// The exact number of milliseconds in this period type.
	///
	/// Returns precise millisecond values for sub-daily periods:
	/// - Millisecond: 1
	/// - Second: 1,000
	/// - Minute: 60,000
	/// - Hourly: 3,600,000
	/// - Daily: 86,400,000
	/// - Monthly: ~2,628,000,000 (average)
	/// - Quarterly: ~7,884,000,000 (average)
	/// - Annual: ~31,536,000,000
	///
	/// - Returns: The number of milliseconds as a `Double`.
	///
	/// ## Example
	/// ```swift
	/// let msPerSecond = PeriodType.second.millisecondsExact
	/// print(msPerSecond)  // 1000.0
	/// ```
	public var millisecondsExact: Double {
		switch self {
		case .millisecond:
			return 1.0
		case .second:
			return 1_000.0
		case .minute:
			return 60_000.0
		case .hourly:
			return 3_600_000.0
		case .daily:
			return 86_400_000.0
		case .monthly:
			return 30.4375 * 86_400_000.0  // ~2,628,000,000
		case .quarterly:
			return 91.3125 * 86_400_000.0  // ~7,884,000,000
		case .annual:
			return 365.25 * 86_400_000.0   // ~31,536,000,000
		}
	}

	/// The number of months equivalent to this period type.
	///
	/// Returns:
	/// - Millisecond: ~3.80518e-10
	/// - Second: ~3.80518e-7
	/// - Minute: ~2.28311e-5
	/// - Hourly: ~0.00136986
	/// - Daily: ~0.03285 (1 / 30.4375)
	/// - Monthly: 1.0
	/// - Quarterly: 3.0
	/// - Annual: 12.0
	///
	/// - Returns: The number of months as a `Double`.
	///
	/// ## Example
	/// ```swift
	/// let monthsPerQuarter = PeriodType.quarterly.monthsEquivalent
	/// print(monthsPerQuarter)  // 3.0
	/// ```
	public var monthsEquivalent: Double {
		switch self {
		case .millisecond:
			return 1.0 / (365.25 / 12.0 * 86_400_000.0)
		case .second:
			return 1.0 / (365.25 / 12.0 * 86_400.0)
		case .minute:
			return 1.0 / (365.25 / 12.0 * 1_440.0)
		case .hourly:
			return 1.0 / (365.25 / 12.0 * 24.0)
		case .daily:
			return 1.0 / (365.25 / 12.0)  // ~0.03285
		case .monthly:
			return 1.0
		case .quarterly:
			return 3.0
		case .annual:
			return 12.0
		}
	}

	// MARK: - Conversion Methods

	/// Converts a count of periods from this type to another period type.
	///
	/// This method performs precise conversions between period types, maintaining
	/// full `Double` precision. All conversions account for leap years using
	/// 365.25 days per year.
	///
	/// - Parameters:
	///   - count: The number of periods of the current type to convert.
	///   - targetType: The period type to convert to.
	///
	/// - Returns: The equivalent number of periods in the target type.
	///
	/// - Note: Conversions maintain full precision. No rounding or truncation occurs.
	///
	/// ## Conversion Examples
	///
	/// ```swift
	/// // Convert years to months
	/// let months = PeriodType.annual.convert(1.0, to: .monthly)
	/// // Result: 12.0
	///
	/// // Convert days to months
	/// let monthlyRate = PeriodType.daily.convert(30.4375, to: .monthly)
	/// // Result: 1.0
	///
	/// // Convert months to years (fractional)
	/// let years = PeriodType.monthly.convert(18.0, to: .annual)
	/// // Result: 1.5
	/// ```
	///
	/// ## Real-World Example: Oil Production
	///
	/// ```swift
	/// // Producer makes 1000 barrels/day
	/// // January has 31 days, convert to monthly rate
	/// let dailyProduction = 1000.0
	/// let daysInJanuary = 31.0
	/// let januaryTotal = dailyProduction * daysInJanuary
	///
	/// // Convert to normalized monthly rate
	/// let monthlyRate = PeriodType.daily.convert(januaryTotal, to: .monthly)
	/// // Result: 31000 / 30.4375 ≈ 1018.52 barrels/month equivalent
	/// ```
	public func convert(_ count: Double, to targetType: PeriodType) -> Double {
		// If converting to the same type, return the original count
		if self == targetType {
			return count
		}

		// Convert to days first (common denominator)
		let totalDays = count * self.daysApproximate

		// Convert from days to target type
		return totalDays / targetType.daysApproximate
	}

	// MARK: - Comparable Conformance

	/// Compares two period types based on their duration.
	///
	/// Period types are ordered by their typical duration:
	/// `millisecond < second < minute < hourly < daily < monthly < quarterly < annual`
	///
	/// - Parameters:
	///   - lhs: The left-hand period type.
	///   - rhs: The right-hand period type.
	///
	/// - Returns: `true` if the left-hand period type is shorter than the right-hand type.
	///
	/// ## Example
	/// ```swift
	/// let periods: [PeriodType] = [.annual, .second, .daily, .quarterly, .millisecond]
	/// let sorted = periods.sorted()
	/// // Result: [.millisecond, .second, .daily, .quarterly, .annual]
	/// ```
	public static func < (lhs: PeriodType, rhs: PeriodType) -> Bool {
		// Natural ordering via raw values (0 = smallest, 7 = largest)
		return lhs.rawValue < rhs.rawValue
	}
}
