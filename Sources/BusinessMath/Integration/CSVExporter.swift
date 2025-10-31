//
//  CSVExporter.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - CSVExportError

/// Errors that can occur during CSV export operations.
public enum CSVExportError: Error, Sendable {
	/// The file cannot be written.
	case fileWriteError(URL)

	/// The time series has no data to export.
	case noData

	/// Periods are inconsistent across time series.
	case inconsistentPeriods
}

// MARK: - CSVExporter

/// Exports financial time series data to CSV files.
///
/// `CSVExporter` provides flexible CSV writing with support for various layouts,
/// number formatting, and both single and multiple time series export.
///
/// ## Basic Usage
///
/// ```swift
/// let timeSeries = TimeSeries(periods: periods, values: values)
///
/// let config = CSVExporter.ExportConfig(layout: .long)
/// let exporter = CSVExporter()
///
/// try exporter.exportTimeSeries(
///     timeSeries,
///     to: fileURL,
///     config: config
/// )
/// ```
///
/// ## Long vs Wide Format
///
/// - **Long format**: Each row is a period-value pair
///   ```
///   Period,Value
///   2024-Q1,100000
///   2024-Q2,110000
///   ```
///
/// - **Wide format**: Periods as columns
///   ```
///   2024-Q1,2024-Q2,2024-Q3
///   100000,110000,120000
///   ```
///
/// ## Topics
///
/// ### Creating Exporters
/// - ``init()``
///
/// ### Configuration
/// - ``ExportConfig``
///
/// ### Export Methods
/// - ``exportTimeSeries(_:to:config:)``
/// - ``exportMultipleTimeSeries(_:to:config:)``
public struct CSVExporter: Sendable {

	// MARK: - Properties

	/// Creates a new CSV exporter.
	public init() {}

	// MARK: - Configuration

	/// Configuration for CSV export formatting and layout.
	public struct ExportConfig: Sendable {
		/// The layout format for the CSV file.
		public let layout: Layout

		/// The delimiter to use between fields. Defaults to comma.
		public let delimiter: String

		/// Whether to include a header row. Defaults to true.
		public let includeHeader: Bool

		/// Optional number formatter for custom value formatting.
		public let numberFormat: NumberFormatter?

		/// The layout format for CSV export.
		public enum Layout: Sendable {
			/// Long format: one row per period-value pair.
			case long

			/// Wide format: periods as columns.
			case wide
		}

		/// Creates an export configuration.
		///
		/// - Parameters:
		///   - layout: The layout format. Defaults to `.long`.
		///   - delimiter: The field delimiter. Defaults to ",".
		///   - includeHeader: Whether to include a header row. Defaults to true.
		///   - numberFormat: Optional number formatter for custom formatting.
		public init(
			layout: Layout = .long,
			delimiter: String = ",",
			includeHeader: Bool = true,
			numberFormat: NumberFormatter? = nil
		) {
			self.layout = layout
			self.delimiter = delimiter
			self.includeHeader = includeHeader
			self.numberFormat = numberFormat
		}
	}

	// MARK: - Export Methods

	/// Exports a single time series to a CSV file.
	///
	/// Writes the time series to a CSV file with the specified configuration.
	/// The output format (long or wide) is determined by the configuration.
	///
	/// - Parameters:
	///   - timeSeries: The time series to export.
	///   - url: The destination URL for the CSV file.
	///   - config: The export configuration. Defaults to long format.
	///
	/// - Throws:
	///   - `CSVExportError.noData`: If the time series is empty.
	///   - `CSVExportError.fileWriteError`: If the file cannot be written.
	///
	/// ## Example
	/// ```swift
	/// let timeSeries = TimeSeries(periods: periods, values: values)
	///
	/// try CSVExporter().exportTimeSeries(
	///     timeSeries,
	///     to: fileURL,
	///     config: CSVExporter.ExportConfig(layout: .long)
	/// )
	/// ```
	public func exportTimeSeries<T: Real>(
		_ timeSeries: TimeSeries<T>,
		to url: URL,
		config: ExportConfig = ExportConfig()
	) throws where T: LosslessStringConvertible {
		guard !timeSeries.periods.isEmpty else {
			throw CSVExportError.noData
		}

		var lines: [String] = []

		switch config.layout {
		case .long:
			// Long format: Period,Value
			if config.includeHeader {
				lines.append("Period\(config.delimiter)Value")
			}

			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate]

			for period in timeSeries.periods {
				if let value = timeSeries[period] {
					let valueString = formatValue(value, formatter: config.numberFormat)
					let dateString = dateFormatter.string(from: period.startDate)
					lines.append("\(dateString)\(config.delimiter)\(valueString)")
				}
			}

		case .wide:
			// Wide format: periods as columns
			let dateFormatter = ISO8601DateFormatter()
			dateFormatter.formatOptions = [.withFullDate]

			if config.includeHeader {
				let header = timeSeries.periods.map { dateFormatter.string(from: $0.startDate) }.joined(separator: config.delimiter)
				lines.append(header)
			}

			let values = timeSeries.periods.compactMap { timeSeries[$0] }
			let valueStrings = values.map { formatValue($0, formatter: config.numberFormat) }
			lines.append(valueStrings.joined(separator: config.delimiter))
		}

		let content = lines.joined(separator: "\n")

		do {
			try content.write(to: url, atomically: true, encoding: .utf8)
		} catch {
			throw CSVExportError.fileWriteError(url)
		}
	}

	/// Exports multiple time series to a CSV file.
	///
	/// Writes multiple time series to a single CSV file with periods as the first
	/// column and each series as subsequent columns.
	///
	/// - Parameters:
	///   - series: A dictionary mapping series names to time series.
	///   - url: The destination URL for the CSV file.
	///   - config: The export configuration. Layout is ignored for multiple series.
	///
	/// - Throws:
	///   - `CSVExportError.noData`: If no series are provided.
	///   - `CSVExportError.inconsistentPeriods`: If series have different periods.
	///   - `CSVExportError.fileWriteError`: If the file cannot be written.
	///
	/// ## Example
	/// ```swift
	/// let series = [
	///     "Revenue": revenueTimeSeries,
	///     "Costs": costsTimeSeries
	/// ]
	///
	/// try CSVExporter().exportMultipleTimeSeries(
	///     series,
	///     to: fileURL
	/// )
	/// ```
	public func exportMultipleTimeSeries<T: Real>(
		_ series: [String: TimeSeries<T>],
		to url: URL,
		config: ExportConfig = ExportConfig()
	) throws where T: LosslessStringConvertible {
		guard !series.isEmpty else {
			throw CSVExportError.noData
		}

		// Get all periods from first series
		guard let firstSeries = series.values.first else {
			throw CSVExportError.noData
		}

		let periods = firstSeries.periods

		guard !periods.isEmpty else {
			throw CSVExportError.noData
		}

		// Verify all series have the same periods
		for (_, ts) in series {
			guard ts.periods == periods else {
				throw CSVExportError.inconsistentPeriods
			}
		}

		var lines: [String] = []

		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withFullDate]

		// Header: Period,Series1,Series2,...
		if config.includeHeader {
			let seriesNames = series.keys.sorted()
			let header = ["Period"] + seriesNames
			lines.append(header.joined(separator: config.delimiter))
		}

		// Data rows
		for period in periods {
			let dateString = dateFormatter.string(from: period.startDate)
			var row: [String] = [dateString]

			let seriesNames = series.keys.sorted()
			for name in seriesNames {
				if let ts = series[name], let value = ts[period] {
					let valueString = formatValue(value, formatter: config.numberFormat)
					row.append(valueString)
				} else {
					row.append("")  // Missing value
				}
			}

			lines.append(row.joined(separator: config.delimiter))
		}

		let content = lines.joined(separator: "\n")

		do {
			try content.write(to: url, atomically: true, encoding: .utf8)
		} catch {
			throw CSVExportError.fileWriteError(url)
		}
	}

	// MARK: - Private Helpers

	private func formatValue<T: Real>(_ value: T, formatter: NumberFormatter?) -> String where T: LosslessStringConvertible {
		if let formatter = formatter {
			// Try to format using the provided formatter
			if let doubleValue = Double(String(value)) {
				if let formatted = formatter.string(from: NSNumber(value: doubleValue)) {
					return formatted
				}
			}
		}

		// Default: convert to string
		return String(value)
	}
}
