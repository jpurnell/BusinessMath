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
/// - ``millisecond``
/// - ``second``
/// - ``minute``
/// - ``hourly``
///
/// **Standard Periods** (for financial analysis):
/// - ``daily``
/// - ``monthly``
/// - ``quarterly``
/// - ``semiannual``
/// - ``annual``
///
/// **Irregular Periods**:
/// - ``custom`` — an arbitrary date range with no type-level duration.
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
/// - ``semiannual``
/// - ``annual``
/// - ``custom``
///
/// ### Properties
/// - ``granularityRank``
/// - ``isRegular``
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

	/// Semiannual period type (average 182.625 days).
	///
	/// Calculated as 365.25 days per year / 2 halves per year. Half 1 covers
	/// January through June; half 2 covers July through December.
	///
	/// - Note: The raw value (8) is deliberately *higher* than ``annual`` (7)
	///   so that raw values already written to disk stay valid. Ordering comes
	///   from ``granularityRank``, not the raw value.
	case semiannual = 8

	/// An arbitrary date range that does not sit on the granularity ladder.
	///
	/// Use this for irregular reporting periods — the odd-length stub a company
	/// emits when it changes reporting cadence (quarterly to semiannual) or moves
	/// its fiscal year-end.
	///
	/// A custom period's duration is a property of the *instance*, not the type.
	/// The type-level conversion tables (``daysApproximate``, ``millisecondsExact``,
	/// ``monthsEquivalent``) have no answer for this case and trap rather than
	/// return a fabricated scalar. Use ``Period/durationInDays``,
	/// ``Period/durationInMilliseconds``, or ``Period/durationInMonths`` instead.
	case custom = 9

	// MARK: - Ordering

	/// The position of this period type on the granularity ladder.
	///
	/// Ordering is expressed explicitly rather than being inferred from `rawValue`
	/// so that new cases can be appended (keeping raw values, and therefore persisted
	/// `Codable` payloads, stable) while still sorting in the right place.
	///
	/// The ladder runs
	/// `millisecond < second < minute < hourly < daily < monthly < quarterly < semiannual < annual`.
	///
	/// ``custom`` is not on the ladder. It is ranked last so that `Comparable`
	/// remains a total order, but comparing a custom range's granularity to a ladder
	/// rung is not meaningful — check ``isRegular`` first if that distinction matters.
	public var granularityRank: Int {
		switch self {
		case .millisecond: return 0
		case .second: return 1
		case .minute: return 2
		case .hourly: return 3
		case .daily: return 4
		case .monthly: return 5
		case .quarterly: return 6
		case .semiannual: return 7
		case .annual: return 8
		case .custom: return 9
		}
	}

	/// Whether this period type sits on the granularity ladder with a fixed,
	/// type-level duration.
	///
	/// `false` only for ``custom``. Regular types can answer ``daysApproximate``,
	/// ``millisecondsExact``, and ``monthsEquivalent``; a custom range cannot.
	///
	/// ## Example
	/// ```swift
	/// if periodType.isRegular {
	///     let days = periodType.daysApproximate
	/// }
	/// ```
	public var isRegular: Bool {
		return self != .custom
	}

	// MARK: - Computed Properties

	/// The approximate number of days in this period type.
	///
	/// Returns precise values accounting for leap years:
	/// - Daily: 1.0
	/// - Monthly: 30.4375 (365.25 / 12)
	/// - Quarterly: 91.3125 (365.25 / 4)
	/// - Annual: 365.25
	///
	/// - Semiannual: 182.625 (365.25 / 2)
	/// - Annual: 365.25
	///
	/// - Returns: The number of days as a `Double`.
	///
	/// - Precondition: `self` must be ``isRegular``. ``custom`` has no type-level
	///   duration; calling this on it is a programmer error and traps. Use
	///   ``Period/durationInDays`` for a value that is defined for every period.
	///
	/// ## Example
	/// ```swift
	/// let daysPerMonth = PeriodType.monthly.daysApproximate
	/// print(daysPerMonth)  // 30.4375
	/// ```
	public var daysApproximate: Double {
		switch self {
		case .millisecond:
			return 1.0 / 86_400_000.0 // fp-safety:disable — literal constant
		case .second:
			return 1.0 / 86_400.0 // fp-safety:disable — literal constant
		case .minute:
			return 1.0 / 1_440.0 // fp-safety:disable — literal constant
		case .hourly:
			return 1.0 / 24.0 // fp-safety:disable — literal constant
		case .daily:
			return 1.0
		case .monthly:
			return 365.25 / 12.0  // fp-safety:disable — literal constants
		case .quarterly:
			return 365.25 / 4.0   // fp-safety:disable — literal constants
		case .semiannual:
			return 365.25 / 2.0   // fp-safety:disable — literal constants
		case .annual:
			return 365.25
		case .custom:
			preconditionFailure(Self.irregularDurationMessage("daysApproximate", instanceAccessor: "Period.durationInDays"))
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
	/// - Semiannual: ~15,778,800,000 (average)
	/// - Annual: ~31,536,000,000
	///
	/// - Returns: The number of milliseconds as a `Double`.
	///
	/// - Precondition: `self` must be ``isRegular``. ``custom`` has no type-level
	///   duration; calling this on it is a programmer error and traps. Use
	///   ``Period/durationInMilliseconds`` instead.
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
		case .semiannual:
			return 182.625 * 86_400_000.0  // ~15,778,800,000
		case .annual:
			return 365.25 * 86_400_000.0   // ~31,536,000,000
		case .custom:
			preconditionFailure(Self.irregularDurationMessage("millisecondsExact", instanceAccessor: "Period.durationInMilliseconds"))
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
	/// - Semiannual: 6.0
	/// - Annual: 12.0
	///
	/// - Returns: The number of months as a `Double`.
	///
	/// - Precondition: `self` must be ``isRegular``. ``custom`` has no type-level
	///   duration; calling this on it is a programmer error and traps. Use
	///   ``Period/durationInMonths`` instead.
	///
	/// ## Example
	/// ```swift
	/// let monthsPerQuarter = PeriodType.quarterly.monthsEquivalent
	/// print(monthsPerQuarter)  // 3.0
	/// ```
	public var monthsEquivalent: Double {
		switch self {
		case .millisecond:
			return 1.0 / (365.25 / 12.0 * 86_400_000.0) // fp-safety:disable — literal constants
		case .second:
			return 1.0 / (365.25 / 12.0 * 86_400.0) // fp-safety:disable — literal constants
		case .minute:
			return 1.0 / (365.25 / 12.0 * 1_440.0) // fp-safety:disable — literal constants
		case .hourly:
			return 1.0 / (365.25 / 12.0 * 24.0) // fp-safety:disable — literal constants
		case .daily:
			return 1.0 / (365.25 / 12.0) // fp-safety:disable — literal constants
		case .monthly:
			return 1.0
		case .quarterly:
			return 3.0
		case .semiannual:
			return 6.0
		case .annual:
			return 12.0
		case .custom:
			preconditionFailure(Self.irregularDurationMessage("monthsEquivalent", instanceAccessor: "Period.durationInMonths"))
		}
	}

	// MARK: - Irregular Duration Diagnostics

	/// Builds the trap message used when a type-level duration is asked of ``custom``.
	///
	/// Refusing loudly is deliberate: an arbitrary date range has no duration that
	/// can be derived from its *type*, so any scalar returned here would be a
	/// fabrication. The message names the instance-level accessor that does work.
	private static func irregularDurationMessage(_ property: String, instanceAccessor: String) -> String {
		return """
			PeriodType.custom has no type-level \(property): an arbitrary date range's \
			duration is a property of the instance, not the type. Use \(instanceAccessor), \
			or guard on PeriodType.isRegular before reaching for the conversion tables.
			"""
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
	/// - Precondition: Both `self` and `targetType` must be ``isRegular``. Converting
	///   to or from ``custom`` is a programmer error and traps, because a custom range
	///   has no type-level duration to convert with.
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
		return totalDays / targetType.daysApproximate // fp-safety:disable — daysApproximate > 0 for all cases
	}

	// MARK: - Comparable Conformance

	/// Compares two period types based on their duration.
	///
	/// Period types are ordered by their typical duration:
	/// `millisecond < second < minute < hourly < daily < monthly < quarterly < semiannual < annual`
	///
	/// ``custom`` sorts after ``annual`` so the order stays total, but the comparison
	/// carries no granularity meaning for an arbitrary range.
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
		// Ordering is explicit (see granularityRank), NOT the raw value. Raw values are
		// append-only so that persisted Codable payloads keep decoding; semiannual was
		// added as 8 but belongs between quarterly (6) and annual (7).
		return lhs.granularityRank < rhs.granularityRank
	}
}
