//
//  PeriodArithmetic.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation

// MARK: - Period Error

/// Errors that can occur during period operations.
public enum PeriodError: Error, Equatable {
	/// Attempted to calculate distance between periods of different types.
	///
	/// - Parameters:
	///   - from: The type of the source period.
	///   - to: The type of the target period.
	case typeMismatch(from: PeriodType, to: PeriodType)
}

extension PeriodError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .typeMismatch(let from, let to):
			return "Cannot calculate distance between periods of different types: \(from) and \(to)"
		}
	}
}

// MARK: - Calendar Cache

/// A cached Calendar instance to avoid repeated Calendar.current calls.
///
/// Creating Calendar instances is expensive. This cached instance significantly
/// improves performance for operations that require calendar calculations,
/// such as period arithmetic and projections.
private let cachedCalendar = Calendar.current

// MARK: - Distance and Arithmetic Operations

/// Extends `Period` to support arithmetic operations and distance calculations.
///
/// This extension makes periods work with standard Swift arithmetic:
/// - Add/subtract periods: `period + 3`, `period - 2`
/// - Calculate distance: `try period1.distance(to: period2)`
/// - Create ranges: `period1...period2`
///
/// ## Examples
///
/// ```swift
/// let jan = Period.month(year: 2025, month: 1)
/// let apr = jan + 3  // April 2025
/// let distance = try jan.distance(to: apr)  // 3
/// let range = jan...apr  // [Jan, Feb, Mar, Apr]
/// ```
extension Period {

	/// Returns the distance from this period to another period of the same type.
	///
	/// The distance is measured in the natural units of the period type:
	/// - Daily periods: number of days
	/// - Monthly periods: number of months
	/// - Quarterly periods: number of quarters
	/// - Annual periods: number of years
	///
	/// - Parameter other: The target period. Must be the same type as this period.
	/// - Returns: The number of periods between this period and `other`.
	///   Positive if `other` is later, negative if earlier.
	/// - Throws: `PeriodError.typeMismatch` if the periods have different types.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let apr = Period.month(year: 2025, month: 4)
	/// let distance = try jan.distance(to: apr)  // 3
	///
	/// let quarter = Period.quarter(year: 2025, quarter: 1)
	/// // This will throw PeriodError.typeMismatch
	/// let badDistance = try jan.distance(to: quarter)
	/// ```
	public func distance(to other: Period) throws -> Int {
		guard self.type == other.type else {
			throw PeriodError.typeMismatch(from: self.type, to: other.type)
		}

		switch type {
		case .daily:
			// Distance in days
			let components = cachedCalendar.dateComponents([.day], from: self.startDate, to: other.startDate)
			return components.day ?? 0

		case .monthly:
			// Distance in months
			let components = cachedCalendar.dateComponents([.month], from: self.startDate, to: other.startDate)
			return components.month ?? 0

		case .quarterly:
			// Distance in quarters (3-month increments)
			let components = cachedCalendar.dateComponents([.month], from: self.startDate, to: other.startDate)
			let months = components.month ?? 0
			return months / 3

		case .annual:
			// Distance in years
			let components = cachedCalendar.dateComponents([.year], from: self.startDate, to: other.startDate)
			return components.year ?? 0
		}
	}

	/// Returns a period that is the specified number of periods away from this period.
	///
	/// This method is the foundation for period arithmetic. It advances (or retreats)
	/// by the specified number of periods while preserving the period type.
	///
	/// - Parameter n: The number of periods to advance. Can be negative to go backward.
	/// - Returns: A new period advanced by `n` periods.
	///
	/// ## Examples
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let apr = jan.advanced(by: 3)  // April 2025
	/// let oct = jan.advanced(by: -3)  // October 2024
	/// ```
	public func advanced(by n: Int) -> Period {
		var components = DateComponents()

		switch type {
		case .daily:
			components.day = n

		case .monthly:
			components.month = n

		case .quarterly:
			// Each quarter is 3 months
			components.month = n * 3

		case .annual:
			components.year = n
		}

		guard let newDate = cachedCalendar.date(byAdding: components, to: self.startDate) else {
			fatalError("Unable to advance period \(self) by \(n)")
		}

		// Preserve the period type
		return Period(type: self.type, date: newDate)
	}

}

// MARK: - Custom Range Support

/// Since `distance(to:)` throws and we can't conform to Strideable with a throwing method,
/// we provide a custom sequence for iterating over period ranges.
public struct PeriodRange: Sequence {
	private let start: Period
	private let end: Period

	init(start: Period, end: Period) {
		precondition(start.type == end.type, "Cannot create range between periods of different types")
		self.start = start
		self.end = end
	}

	public func makeIterator() -> PeriodRangeIterator {
		return PeriodRangeIterator(start: start, end: end)
	}
}

public struct PeriodRangeIterator: IteratorProtocol {
	private var current: Period
	private let end: Period
	private var finished: Bool = false

	init(start: Period, end: Period) {
		self.current = start
		self.end = end
	}

	public mutating func next() -> Period? {
		guard !finished else { return nil }

		let result = current

		if current == end {
			finished = true
		} else {
			current = current.advanced(by: 1)
		}

		return result
	}
}

extension Period {
	/// Creates a range from this period to another period.
	///
	/// - Parameter end: The ending period (inclusive). Must be the same type as this period.
	/// - Returns: A sequence of periods from this period to `end`.
	///
	/// - Precondition: Both periods must be of the same type.
	public static func ... (lhs: Period, rhs: Period) -> PeriodRange {
		return PeriodRange(start: lhs, end: rhs)
	}
}

// MARK: - Arithmetic Operators

extension Period {

	/// Adds a specified number of periods to this period.
	///
	/// - Parameters:
	///   - lhs: The starting period.
	///   - rhs: The number of periods to add.
	/// - Returns: A new period advanced by the specified count.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let apr = jan + 3  // April 2025
	/// ```
	public static func + (lhs: Period, rhs: Int) -> Period {
		return lhs.advanced(by: rhs)
	}

	/// Subtracts a specified number of periods from this period.
	///
	/// - Parameters:
	///   - lhs: The starting period.
	///   - rhs: The number of periods to subtract.
	/// - Returns: A new period moved back by the specified count.
	///
	/// ## Example
	/// ```swift
	/// let apr = Period.month(year: 2025, month: 4)
	/// let jan = apr - 3  // January 2025
	/// ```
	public static func - (lhs: Period, rhs: Int) -> Period {
		return lhs.advanced(by: -rhs)
	}
}
