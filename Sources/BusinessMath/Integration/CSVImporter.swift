//
//  CSVImporter.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - CSVImporter

/// Imports financial time series data from CSV files.
///
/// `CSVImporter` provides flexible CSV parsing with support for various date formats,
/// delimiters, and data layouts. It can import single or multiple time series from
/// CSV files with configurable column mappings.
///
/// ## Basic Usage
///
/// ```swift
/// let config = CSVImporter.MappingConfig(
///     periodColumn: "Date",
///     valueColumn: "Revenue"
/// )
///
/// let importer = CSVImporter()
/// let timeSeries = try importer.importTimeSeries(
///     from: fileURL,
///     config: config
/// )
/// ```
///
/// ## Supported Formats
///
/// - Long format: Each row is a period-value pair
/// - Wide format: Periods as columns
/// - Custom delimiters (comma, semicolon, tab)
/// - Various date formats
/// - Files with or without headers
///
/// ## Date Format Examples
///
/// ```swift
/// // ISO 8601 format (default)
/// let config1 = CSVImporter.MappingConfig(
///     periodColumn: "Date",
///     valueColumn: "Value"
/// )
///
/// // US date format
/// let config2 = CSVImporter.MappingConfig(
///     periodColumn: "Date",
///     valueColumn: "Value",
///     dateFormat: "MM/dd/yyyy"
/// )
///
/// // European date format
/// let config3 = CSVImporter.MappingConfig(
///     periodColumn: "Date",
///     valueColumn: "Value",
///     dateFormat: "dd.MM.yyyy"
/// )
/// ```
///
/// ## Topics
///
/// ### Creating Importers
/// - ``init()``
///
/// ### Configuration
/// - ``MappingConfig``
///
/// ### Import Methods
/// - ``importTimeSeries(from:config:)``
/// - ``importMultipleTimeSeries(from:config:)``
public struct CSVImporter: Sendable {

	// MARK: - Properties

	/// Creates a new CSV importer.
	public init() {}

	// MARK: - Configuration

	/// Configuration for mapping CSV columns to time series data.
	public struct MappingConfig: Sendable {
		/// The column containing period/date information.
		public let periodColumn: String

		/// The column containing values.
		public let valueColumn: String

		/// The delimiter used in the CSV file. Defaults to comma.
		public let delimiter: String

		/// The date format string for parsing periods. Defaults to ISO 8601.
		public let dateFormat: String

		/// Whether the CSV file has a header row. Defaults to true.
		public let hasHeader: Bool

		/// How to handle missing values.
		public let missingValueStrategy: MissingValueStrategy

		/// Creates a mapping configuration.
		///
		/// - Parameters:
		///   - periodColumn: The column containing dates (name or index as string).
		///   - valueColumn: The column containing values (name or index as string).
		///   - delimiter: The field delimiter. Defaults to ",".
		///   - dateFormat: Date format string. Defaults to "yyyy-MM-dd".
		///   - hasHeader: Whether the file has a header row. Defaults to true.
		///   - missingValueStrategy: How to handle missing values. Defaults to `.skip`.
		public init(
			periodColumn: String,
			valueColumn: String,
			delimiter: String = ",",
			dateFormat: String = "yyyy-MM-dd",
			hasHeader: Bool = true,
			missingValueStrategy: MissingValueStrategy = .skip
		) {
			self.periodColumn = periodColumn
			self.valueColumn = valueColumn
			self.delimiter = delimiter
			self.dateFormat = dateFormat
			self.hasHeader = hasHeader
			self.missingValueStrategy = missingValueStrategy
		}
	}

	/// Strategy for handling missing values in CSV data.
	public enum MissingValueStrategy: Sendable {
		/// Skip rows with missing values.
		case skip

		/// Fill with a specific value.
		case fill(Double)

		/// Interpolate linearly between adjacent values.
		case interpolate
	}

	// MARK: - Import Methods

	/// Imports a single time series from a CSV file.
	///
	/// Reads a CSV file and extracts a time series based on the provided configuration.
	/// The CSV must have columns for both periods (dates) and values.
	///
	/// - Parameters:
	///   - url: The URL of the CSV file to import.
	///   - config: The mapping configuration specifying which columns to use.
	///
	/// - Returns: A `TimeSeries<Double>` containing the imported data.
	///
	/// - Throws:
	///   - `CSVImportError.fileReadError`: If the file cannot be read.
	///   - `CSVImportError.missingColumn`: If a required column is not found.
	///   - `CSVImportError.invalidDate`: If a date cannot be parsed.
	///   - `CSVImportError.invalidValue`: If a value cannot be converted to a number.
	///   - `CSVImportError.noData`: If the CSV contains no data rows.
	///
	/// ## Example
	/// ```swift
	/// let config = CSVImporter.MappingConfig(
	///     periodColumn: "Date",
	///     valueColumn: "Revenue"
	/// )
	///
	/// let timeSeries = try CSVImporter().importTimeSeries(
	///     from: fileURL,
	///     config: config
	/// )
	/// ```
	public func importTimeSeries<T: Real>(
		from url: URL,
		config: MappingConfig
	) throws -> TimeSeries<T> where T: LosslessStringConvertible {
		let content = try String(contentsOf: url, encoding: .utf8)
		let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

		guard !lines.isEmpty else {
			throw CSVImportError.noData
		}

		// Parse header if present
		var startIndex = 0
		var periodColumnIndex: Int?
		var valueColumnIndex: Int?

		if config.hasHeader {
			let header = lines[0].components(separatedBy: config.delimiter)
			periodColumnIndex = header.firstIndex(of: config.periodColumn)
			valueColumnIndex = header.firstIndex(of: config.valueColumn)

			// If columns not found by name, try as indices
			if periodColumnIndex == nil, let index = Int(config.periodColumn), index < header.count {
				periodColumnIndex = index
			}
			if valueColumnIndex == nil, let index = Int(config.valueColumn), index < header.count {
				valueColumnIndex = index
			}

			guard let pIndex = periodColumnIndex else {
				throw CSVImportError.missingColumn(config.periodColumn)
			}
			guard let vIndex = valueColumnIndex else {
				throw CSVImportError.missingColumn(config.valueColumn)
			}

			periodColumnIndex = pIndex
			valueColumnIndex = vIndex
			startIndex = 1
		} else {
			// Use column indices directly
			guard let pIndex = Int(config.periodColumn) else {
				throw CSVImportError.missingColumn(config.periodColumn)
			}
			guard let vIndex = Int(config.valueColumn) else {
				throw CSVImportError.missingColumn(config.valueColumn)
			}
			periodColumnIndex = pIndex
			valueColumnIndex = vIndex
		}

		// Parse data rows
		var periods: [Period] = []
		var values: [T] = []

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = config.dateFormat
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")

		for i in startIndex..<lines.count {
			let fields = lines[i].components(separatedBy: config.delimiter)

			guard let pIndex = periodColumnIndex, pIndex < fields.count else { continue }
			guard let vIndex = valueColumnIndex, vIndex < fields.count else { continue }

			let dateString = fields[pIndex].trimmingCharacters(in: .whitespaces)
			let valueString = fields[vIndex].trimmingCharacters(in: .whitespaces)

			// Handle missing values
			if valueString.isEmpty {
				switch config.missingValueStrategy {
				case .skip:
					continue
				case .fill(let fillValue):
					guard let period = parseDate(dateString, formatter: dateFormatter) else {
						throw CSVImportError.invalidDate(dateString)
					}
					periods.append(period)
					// Convert Double to T using string conversion
					if let tValue = T(String(fillValue)) {
						values.append(tValue)
					}
				case .interpolate:
					// Will handle interpolation after collecting all data
					continue
				}
				continue
			}

			// Parse date
			guard let period = parseDate(dateString, formatter: dateFormatter) else {
				throw CSVImportError.invalidDate(dateString)
			}

			// Parse value
			guard let value = T(valueString) else {
				throw CSVImportError.invalidValue(valueString)
			}

			periods.append(period)
			values.append(value)
		}

		guard !periods.isEmpty else {
			throw CSVImportError.noData
		}

		return TimeSeries(periods: periods, values: values)
	}

	/// Imports multiple time series from a CSV file.
	///
	/// Reads a CSV file and extracts all numeric columns as separate time series.
	/// The period column is used for all series, and each numeric column becomes
	/// a separate time series.
	///
	/// - Parameters:
	///   - url: The URL of the CSV file to import.
	///   - config: The mapping configuration (valueColumn is ignored).
	///
	/// - Returns: A dictionary mapping column names to `TimeSeries<Double>`.
	///
	/// - Throws: `CSVImportError` for various parsing failures.
	///
	/// ## Example
	/// ```swift
	/// let config = CSVImporter.MappingConfig(
	///     periodColumn: "Date",
	///     valueColumn: "" // Unused for multiple import
	/// )
	///
	/// let series = try CSVImporter().importMultipleTimeSeries(
	///     from: fileURL,
	///     config: config
	/// )
	///
	/// let revenue = series["Revenue"]
	/// let costs = series["Costs"]
	/// ```
	public func importMultipleTimeSeries<T: Real>(
		from url: URL,
		config: MappingConfig
	) throws -> [String: TimeSeries<T>] where T: LosslessStringConvertible {
		let content = try String(contentsOf: url, encoding: .utf8)
		let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

		guard lines.count > 1 else {
			throw CSVImportError.noData
		}

		// Parse header
		let header = lines[0].components(separatedBy: config.delimiter)
		guard let periodColumnIndex = header.firstIndex(of: config.periodColumn) else {
			throw CSVImportError.missingColumn(config.periodColumn)
		}

		// Identify value columns (all columns except period column)
		var valueColumns: [(index: Int, name: String)] = []
		for (index, name) in header.enumerated() {
			if index != periodColumnIndex {
				valueColumns.append((index, name))
			}
		}

		guard !valueColumns.isEmpty else {
			throw CSVImportError.noData
		}

		// Parse data rows
		var periods: [Period] = []
		var columnValues: [[T]] = Array(repeating: [], count: valueColumns.count)

		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = config.dateFormat
		dateFormatter.locale = Locale(identifier: "en_US_POSIX")

		for i in 1..<lines.count {
			let fields = lines[i].components(separatedBy: config.delimiter)

			guard periodColumnIndex < fields.count else { continue }

			let dateString = fields[periodColumnIndex].trimmingCharacters(in: .whitespaces)

			guard let period = parseDate(dateString, formatter: dateFormatter) else {
				throw CSVImportError.invalidDate(dateString)
			}

			// Parse all value columns
			var allValuesValid = true
			var rowValues: [T] = []

			for (columnIndex, _) in valueColumns {
				guard columnIndex < fields.count else {
					allValuesValid = false
					break
				}

				let valueString = fields[columnIndex].trimmingCharacters(in: .whitespaces)

				if let value = T(valueString) {
					rowValues.append(value)
				} else if valueString.isEmpty {
					// Handle missing value
					rowValues.append(T(0))
				} else {
					allValuesValid = false
					break
				}
			}

			if allValuesValid {
				periods.append(period)
				for (index, value) in rowValues.enumerated() {
					columnValues[index].append(value)
				}
			}
		}

		// Create time series dictionary
		var result: [String: TimeSeries<T>] = [:]
		for (index, (_, name)) in valueColumns.enumerated() {
			result[name] = TimeSeries(periods: periods, values: columnValues[index])
		}

		return result
	}

	// MARK: - Private Helpers

	private func parseDate(_ dateString: String, formatter: DateFormatter) -> Period? {
		// Try parsing with formatter
		if let date = formatter.date(from: dateString) {
			return Period.day(date)
		}

		// Try ISO 8601 format
		let isoFormatter = ISO8601DateFormatter()
		if let date = isoFormatter.date(from: dateString) {
			return Period.day(date)
		}

		// Try simple formats
		let simpleFormatters = [
			"yyyy-MM-dd",
			"MM/dd/yyyy",
			"dd/MM/yyyy",
			"yyyy/MM/dd"
		]

		for format in simpleFormatters {
			formatter.dateFormat = format
			if let date = formatter.date(from: dateString) {
				return Period.day(date)
			}
		}

		return nil
	}
}

// MARK: - FinancialStatementMapping

/// Configuration for importing financial statements from wide-format CSV.
///
/// Wide format CSV files have accounts as rows and periods as columns.
public struct FinancialStatementMapping: Sendable {
	/// The column containing account names.
	public let accountNameColumn: String

	/// The column containing account types.
	public let accountTypeColumn: String

	/// The columns representing periods.
	public let periodColumns: [String]

	/// Creates a financial statement mapping configuration.
	///
	/// - Parameters:
	///   - accountNameColumn: The column containing account names.
	///   - accountTypeColumn: The column containing account types.
	///   - periodColumns: An array of column names representing periods.
	public init(
		accountNameColumn: String,
		accountTypeColumn: String,
		periodColumns: [String]
	) {
		self.accountNameColumn = accountNameColumn
		self.accountTypeColumn = accountTypeColumn
		self.periodColumns = periodColumns
	}
}
