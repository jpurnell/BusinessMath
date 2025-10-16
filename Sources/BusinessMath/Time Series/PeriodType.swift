//
//  PeriodType.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

/// Represents the type of time period used in financial models.
///
/// `PeriodType` defines the granularity of time periods for financial analysis,
/// enabling precise conversion between different time scales. All conversions
/// account for leap years using 365.25 days per year.
///
/// ## Supported Period Types
///
/// - ``daily``: Single day periods
/// - ``monthly``: Monthly periods (30.4375 days average)
/// - ``quarterly``: Quarterly periods (91.3125 days average)
/// - ``annual``: Annual periods (365.25 days accounting for leap years)
///
/// ## Usage Example
///
/// ```swift
/// // Compare period types
/// let monthly = PeriodType.monthly
/// let quarterly = PeriodType.quarterly
/// if monthly < quarterly {
///     print("Monthly periods are shorter than quarterly")
/// }
///
/// // Convert between period types
/// let daysInYear = PeriodType.annual.daysApproximate  // 365.25
/// let monthsInQuarter = PeriodType.quarterly.monthsEquivalent  // 3.0
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
public enum PeriodType: String, Codable, Comparable, CaseIterable, Sendable {

	// MARK: - Cases

	/// Daily period type (1 day).
	case daily

	/// Monthly period type (average 30.4375 days).
	///
	/// Calculated as 365.25 days per year / 12 months per year.
	case monthly

	/// Quarterly period type (average 91.3125 days).
	///
	/// Calculated as 365.25 days per year / 4 quarters per year.
	case quarterly

	/// Annual period type (365.25 days).
	///
	/// Accounts for leap years by using 365.25 days per year.
	case annual

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

	/// The number of months equivalent to this period type.
	///
	/// Returns:
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
	/// `daily < monthly < quarterly < annual`
	///
	/// - Parameters:
	///   - lhs: The left-hand period type.
	///   - rhs: The right-hand period type.
	///
	/// - Returns: `true` if the left-hand period type is shorter than the right-hand type.
	///
	/// ## Example
	/// ```swift
	/// let periods: [PeriodType] = [.annual, .daily, .quarterly, .monthly]
	/// let sorted = periods.sorted()
	/// // Result: [.daily, .monthly, .quarterly, .annual]
	/// ```
	public static func < (lhs: PeriodType, rhs: PeriodType) -> Bool {
		// Define ordering based on duration
		let order: [PeriodType] = [.daily, .monthly, .quarterly, .annual]

		guard let lhsIndex = order.firstIndex(of: lhs),
		      let rhsIndex = order.firstIndex(of: rhs) else {
			return false
		}

		return lhsIndex < rhsIndex
	}
}
