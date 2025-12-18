//
//  TimeSeries.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - TimeSeriesMetadata

/// Metadata describing a time series.
///
/// Metadata provides descriptive information about a time series, including
/// its name, description, and unit of measurement.
///
/// ## Example
/// ```swift
/// let metadata = TimeSeriesMetadata(
///     name: "Monthly Revenue",
///     description: "Revenue by month for FY2025",
///     unit: "USD"
/// )
/// ```
public struct TimeSeriesMetadata: Codable, Equatable, Sendable {

	/// The name of the time series.
	public var name: String

	/// An optional description of the time series.
	public var description: String?

	/// The unit of measurement (e.g., "USD", "barrels", "units").
	public var unit: String?

	/// Creates metadata with the specified properties.
	///
	/// - Parameters:
	///   - name: The name of the time series. Defaults to an empty string.
	///   - description: An optional description. Defaults to nil.
	///   - unit: The unit of measurement. Defaults to nil.
	public init(name: String = "", description: String? = nil, unit: String? = nil) {
		self.name = name
		self.description = description
		self.unit = unit
	}
}

// MARK: - TimeSeries

/// A time series containing values indexed by periods.
///
/// `TimeSeries` associates numeric values with time periods, enabling temporal
/// data analysis. The generic type parameter `T` must conform to `Real`, allowing
/// use with `Double`, `Float`, or other numeric types.
///
/// Periods are always stored in chronologically sorted order, regardless of the
/// order in which they are provided during initialization.
///
/// ## Creating Time Series
///
/// ```swift
/// // From arrays (automatically sorted chronologically)
/// let periods = [
///     Period.month(year: 2025, month: 1),
///     Period.month(year: 2025, month: 2),
///     Period.month(year: 2025, month: 3)
/// ]
/// let values: [Double] = [100_000, 120_000, 150_000]
/// let ts = TimeSeries(periods: periods, values: values)
///
/// // From dictionary (automatically sorted chronologically)
/// let data = [
///     Period.month(year: 2025, month: 1): 100_000.0,
///     Period.month(year: 2025, month: 2): 120_000.0
/// ]
/// let ts2 = TimeSeries(data: data)
///
/// // With metadata
/// let metadata = TimeSeriesMetadata(name: "Revenue", unit: "USD")
/// let ts3 = TimeSeries(periods: periods, values: values, metadata: metadata)
/// ```
///
/// ## Accessing Values
///
/// ```swift
/// let jan = Period.month(year: 2025, month: 1)
/// let value = ts[jan]  // Optional<Double>
/// let valueOrDefault = ts[jan, default: 0.0]  // Double
/// ```
///
/// ## Iteration
///
/// ```swift
/// // Iterate over values
/// for value in ts {
///     print(value)
/// }
///
/// // Use standard Sequence operations
/// let total = ts.reduce(0.0, +)
/// let doubled = ts.map { $0 * 2.0 }
/// ```
public struct TimeSeries<T: Real & Sendable>: Sequence, Sendable {

	// MARK: - Properties

	/// The periods in this time series, in chronologically sorted order.
	public let periods: [Period]

	/// The values indexed by period.
	private let values: [Period: T]

	/// Metadata describing this time series.
	public let metadata: TimeSeriesMetadata

	/// Optional labels for each period (for display/debugging purposes).
	public let labels: [Period: String]?

	// MARK: - Initialization

	/// Creates a time series from parallel arrays of periods and values.
	///
	/// If duplicate periods are provided, the last value for each period is kept.
	/// Periods are automatically sorted in ascending chronological order.
	///
	/// - Parameters:
	///   - periods: The periods for this time series.
	///   - values: The values corresponding to each period.
	///   - metadata: Optional metadata describing the time series.
	///
	/// - Precondition: `periods.count == values.count`
	///
	/// ## Example
	/// ```swift
	/// let periods = [
	///     Period.month(year: 2025, month: 1),
	///     Period.month(year: 2025, month: 2)
	/// ]
	/// let values: [Double] = [100.0, 200.0]
	/// let ts = TimeSeries(periods: periods, values: values)
	/// ```
	public init(periods: [Period], values: [T], metadata: TimeSeriesMetadata = TimeSeriesMetadata(), labels: [String]? = nil) {
		precondition(periods.count == values.count,
					 "periods and values arrays must have the same count")

		if let labels = labels {
			precondition(labels.count == periods.count,
						 "labels array must have the same count as periods and values")
		}

		// Build dictionary, handling duplicates by keeping last value
		// Reserve capacity to avoid reallocation during insertion
		var valueDict: [Period: T] = [:]
		valueDict.reserveCapacity(periods.count)

		var labelDict: [Period: String]?
		if let labels = labels {
			labelDict = [:]
			labelDict?.reserveCapacity(periods.count)
		}

		for (index, (period, value)) in Swift.zip(periods, values).enumerated() {
			valueDict[period] = value
			if let labels = labels {
				labelDict?[period] = labels[index]
			}
		}

		// Sort periods chronologically
		self.periods = valueDict.keys.sorted()
		self.values = valueDict
		self.metadata = metadata
		self.labels = labelDict
	}

	/// Creates a time series from a dictionary of period-value pairs.
	///
	/// Periods are sorted in ascending order (type-first, then chronological).
	///
	/// - Parameters:
	///   - data: A dictionary mapping periods to values.
	///   - metadata: Optional metadata describing the time series.
	///
	/// ## Example
	/// ```swift
	/// let data = [
	///     Period.month(year: 2025, month: 1): 100.0,
	///     Period.month(year: 2025, month: 2): 200.0
	/// ]
	/// let ts = TimeSeries(data: data)
	/// ```
	public init(data: [Period: T], metadata: TimeSeriesMetadata = TimeSeriesMetadata(), labels: [Period: String]? = nil) {
		self.periods = data.keys.sorted()
		self.values = data
		self.metadata = metadata
		self.labels = labels
	}

	// MARK: - Subscript Access

	/// Returns the value for the specified period, or nil if not present.
	///
	/// - Parameter period: The period to look up.
	/// - Returns: The value for the period, or nil if not found.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// if let value = ts[jan] {
	///     print("January: \\(value)")
	/// }
	/// ```
	public subscript(period: Period) -> T? {
		return values[period]
	}

	/// Returns the value for the specified period, or a default value if not present.
	///
	/// - Parameters:
	///   - period: The period to look up.
	///   - default: The default value to return if the period is not found.
	/// - Returns: The value for the period, or the default value.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let value = ts[jan, default: 0.0]  // Never nil
	/// ```
	public subscript(period: Period, default defaultValue: T) -> T {
		return values[period] ?? defaultValue
	}

	/// Returns the label for the specified period, if one exists.
	///
	/// - Parameter period: The period to look up.
	/// - Returns: The label for the period, or nil if not found.
	///
	/// ## Example
	/// ```swift
	/// if let label = ts.label(for: jan) {
	///     print("Label: \(label)")
	/// }
	/// ```
	public func label(for period: Period) -> String? {
		return labels?[period]
	}

	// MARK: - Computed Properties

	/// Returns all values in the order of the periods array.
	///
	/// ## Example
	/// ```swift
	/// let values = ts.valuesArray  // [100.0, 200.0, 300.0]
	/// ```
	public var valuesArray: [T] {
		return periods.compactMap { values[$0] }
	}

	/// The number of periods in this time series.
	public var count: Int {
		return periods.count
	}

	/// The first value in this time series, or nil if empty.
	public var first: T? {
		return periods.first.flatMap { values[$0] }
	}

	/// The last value in this time series, or nil if empty.
	public var last: T? {
		return periods.last.flatMap { values[$0] }
	}

	/// Returns true if the time series contains no periods.
	public var isEmpty: Bool {
		return periods.isEmpty
	}

	// MARK: - Range Extraction

	/// Extracts a subset of the time series between two periods (inclusive).
	///
	/// The returned time series includes both the start and end periods, as well
	/// as all periods between them that exist in the original time series.
	///
	/// - Parameters:
	///   - from: The starting period (inclusive).
	///   - to: The ending period (inclusive).
	/// - Returns: A new time series containing only the specified range.
	///
	/// ## Example
	/// ```swift
	/// let jan = Period.month(year: 2025, month: 1)
	/// let mar = Period.month(year: 2025, month: 3)
	/// let subset = ts.range(from: jan, to: mar)  // Jan, Feb, Mar
	/// ```
	public func range(from start: Period, to end: Period) -> TimeSeries<T> {
		let filteredPeriods = periods.filter { period in
			period >= start && period <= end
		}

		let filteredValues = filteredPeriods.compactMap { values[$0] }

		return TimeSeries(
			periods: filteredPeriods,
			values: filteredValues,
			metadata: metadata
		)
	}

	// MARK: - Sequence Conformance

	/// An iterator over the values in the time series.
	public struct Iterator: IteratorProtocol {
		private var periodIterator: Array<Period>.Iterator
		private let values: [Period: T]

		fileprivate init(periods: [Period], values: [Period: T]) {
			self.periodIterator = periods.makeIterator()
			self.values = values
		}

		public mutating func next() -> T? {
			guard let period = periodIterator.next() else {
				return nil
			}
			return values[period]
		}
	}

	/// Returns an iterator over the values in this time series.
	public func makeIterator() -> Iterator {
		return Iterator(periods: periods, values: values)
	}
}

// MARK: - Codable Conformance

extension TimeSeries: Codable where T: Codable {

	private enum CodingKeys: String, CodingKey {
		case periods
		case values
		case metadata
	}

	/// Encodes this time series to an encoder.
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(periods, forKey: .periods)
		try container.encode(valuesArray, forKey: .values)
		try container.encode(metadata, forKey: .metadata)
	}

	/// Decodes a time series from a decoder.
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let periods = try container.decode([Period].self, forKey: .periods)
		let valuesArray = try container.decode([T].self, forKey: .values)
		let metadata = try container.decode(TimeSeriesMetadata.self, forKey: .metadata)

		self.init(periods: periods, values: valuesArray, metadata: metadata)
	}
}
