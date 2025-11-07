//
//  CSVImporter.swift
//  BusinessMath
//
//  Created by Xcode on November 6, 2025.
//

import Foundation

/// CSV Import errors
public enum CSVImportError: Error, LocalizedError {
	case fileNotFound
	case invalidFormat(String)
	case missingColumn(String)
	case parsingError(row: Int, message: String)
	
	public var errorDescription: String? {
		switch self {
		case .fileNotFound:
			return "CSV file not found"
		case .invalidFormat(let message):
			return "Invalid CSV format: \(message)"
		case .missingColumn(let column):
			return "Missing required column: \(column)"
		case .parsingError(let row, let message):
			return "Error parsing row \(row): \(message)"
		}
	}
}

/// Imports time series data from CSV files
//public struct CSVImporter {
//	
//	public init() {}
//	
//	// MARK: - Configuration Types
//	
//	/// Configuration for standard (long-format) CSV import
//	public struct MappingConfig {
//		public let periodColumn: String
//		public let valueColumn: String
//		public let dateFormat: String?
//		public let delimiter: String
//		public let hasHeader: Bool
//		
//		public init(
//			periodColumn: String,
//			valueColumn: String,
//			dateFormat: String? = nil,
//			delimiter: String = ",",
//			hasHeader: Bool = true
//		) {
//			self.periodColumn = periodColumn
//			self.valueColumn = valueColumn
//			self.dateFormat = dateFormat
//			self.delimiter = delimiter
//			self.hasHeader = hasHeader
//		}
//	}
//	
//	/// Configuration for wide-format CSV import
//	/// (accounts as rows, periods as columns)
//	public struct WideFormatConfig {
//		public let accountColumn: String
//		public let periodColumns: [String]
//		public let delimiter: String
//		
//		public init(
//			accountColumn: String,
//			periodColumns: [String],
//			delimiter: String = ","
//		) {
//			self.accountColumn = accountColumn
//			self.periodColumns = periodColumns
//			self.delimiter = delimiter
//		}
//	}
//	
//	// MARK: - Import Methods
//	
//	/// Import a single time series from CSV
//	public func importTimeSeries(
//		from url: URL,
//		config: MappingConfig
//	) throws -> TimeSeries<Double> {
//		let content = try String(contentsOf: url, encoding: .utf8)
//		let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
//		
//		guard !lines.isEmpty else {
//			throw CSVImportError.invalidFormat("Empty file")
//		}
//		
//		var dataLines = lines
//		var headers: [String] = []
//		
//		if config.hasHeader {
//			let headerLine = dataLines.removeFirst()
//			headers = headerLine.components(separatedBy: config.delimiter)
//		}
//		
//		var periods: [Period] = []
//		var values: [Double] = []
//		
//		for (index, line) in dataLines.enumerated() {
//			let columns = line.components(separatedBy: config.delimiter)
//			
//			// Get column indices
//			let periodIndex: Int
//			let valueIndex: Int
//			
//			if config.hasHeader {
//				guard let pIdx = headers.firstIndex(of: config.periodColumn) else {
//					throw CSVImportError.missingColumn(config.periodColumn)
//				}
//				guard let vIdx = headers.firstIndex(of: config.valueColumn) else {
//					throw CSVImportError.missingColumn(config.valueColumn)
//				}
//				periodIndex = pIdx
//				valueIndex = vIdx
//			} else {
//				periodIndex = Int(config.periodColumn) ?? 0
//				valueIndex = Int(config.valueColumn) ?? 1
//			}
//			
//			guard periodIndex < columns.count && valueIndex < columns.count else {
//				continue
//			}
//			
//			// Parse period
//			let periodString = columns[periodIndex].trimmingCharacters(in: .whitespaces)
//			guard let period = parsePeriod(from: periodString, format: config.dateFormat) else {
//				continue
//			}
//			
//			// Parse value
//			let valueString = columns[valueIndex].trimmingCharacters(in: .whitespaces)
//			if valueString.isEmpty {
//				continue // Skip missing values
//			}
//			
//			guard let value = Double(valueString) else {
//				continue // Skip invalid values
//			}
//			
//			periods.append(period)
//			values.append(value)
//		}
//		
//		return TimeSeries(periods: periods, values: values)
//	}
//	
//	/// Import multiple time series from CSV (one column per series)
//	public func importMultipleTimeSeries(
//		from url: URL,
//		config: MappingConfig
//	) throws -> [String: TimeSeries<Double>] {
//		let content = try String(contentsOf: url, encoding: .utf8)
//		let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
//		
//		guard !lines.isEmpty else {
//			throw CSVImportError.invalidFormat("Empty file")
//		}
//		
//		var dataLines = lines
//		let headerLine = dataLines.removeFirst()
//		let headers = headerLine.components(separatedBy: config.delimiter)
//		
//		guard let periodIndex = headers.firstIndex(of: config.periodColumn) else {
//			throw CSVImportError.missingColumn(config.periodColumn)
//		}
//		
//		// Get all value column indices (everything except period column)
//		let valueColumns = headers.enumerated().filter { $0.offset != periodIndex }
//		
//		var result: [String: TimeSeries<Double>] = [:]
//		var seriesData: [String: (periods: [Period], values: [Double])] = [:]
//		
//		// Initialize storage for each series
//		for (_, columnName) in valueColumns {
//			seriesData[columnName] = (periods: [], values: [])
//		}
//		
//		// Parse data rows
//		for line in dataLines {
//			let columns = line.components(separatedBy: config.delimiter)
//			
//			guard periodIndex < columns.count else { continue }
//			
//			let periodString = columns[periodIndex].trimmingCharacters(in: .whitespaces)
//			guard let period = parsePeriod(from: periodString, format: config.dateFormat) else {
//				continue
//			}
//			
//			for (columnIndex, columnName) in valueColumns {
//				guard columnIndex < columns.count else { continue }
//				
//				let valueString = columns[columnIndex].trimmingCharacters(in: .whitespaces)
//				guard !valueString.isEmpty, let value = Double(valueString) else {
//					continue
//				}
//				
//				seriesData[columnName]?.periods.append(period)
//				seriesData[columnName]?.values.append(value)
//			}
//		}
//		
//		// Create TimeSeries objects
//		for (name, data) in seriesData {
//			if !data.periods.isEmpty {
//				result[name] = TimeSeries(periods: data.periods, values: data.values)
//			}
//		}
//		
//		return result
//	}
//	
//	/// Import wide-format CSV (accounts as rows, periods as columns)
//	public func importWideFormat(
//		from url: URL,
//		config: WideFormatConfig
//	) throws -> [String: TimeSeries<Double>] {
//		let content = try String(contentsOf: url, encoding: .utf8)
//		let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
//		
//		guard lines.count >= 2 else {
//			throw CSVImportError.invalidFormat("Need at least header and one data row")
//		}
//		
//		var dataLines = lines
//		let headerLine = dataLines.removeFirst()
//		let headers = headerLine.components(separatedBy: config.delimiter)
//		
//		// Find account column index
//		guard let accountIndex = headers.firstIndex(of: config.accountColumn) else {
//			throw CSVImportError.missingColumn(config.accountColumn)
//		}
//		
//		// Find period column indices
//		var periodIndices: [(index: Int, periodName: String)] = []
//		for periodColumn in config.periodColumns {
//			guard let index = headers.firstIndex(of: periodColumn) else {
//				throw CSVImportError.missingColumn(periodColumn)
//			}
//			periodIndices.append((index: index, periodName: periodColumn))
//		}
//		
//		// Parse periods from column names
//		let periods: [Period] = periodIndices.compactMap { item in
//			parsePeriod(from: item.periodName, format: nil)
//		}
//		
//		guard periods.count == config.periodColumns.count else {
//			throw CSVImportError.invalidFormat("Could not parse all period columns")
//		}
//		
//		var result: [String: TimeSeries<Double>] = [:]
//		
//		// Parse each data row (each row is an account)
//		for (rowIndex, line) in dataLines.enumerated() {
//			let columns = line.components(separatedBy: config.delimiter)
//			
//			guard accountIndex < columns.count else {
//				continue
//			}
//			
//			let accountName = columns[accountIndex].trimmingCharacters(in: .whitespaces)
//			
//			// Extract values for this account across all periods
//			var values: [Double] = []
//			for (index, _) in periodIndices {
//				guard index < columns.count else {
//					throw CSVImportError.parsingError(
//						row: rowIndex + 2, // +2 for header and 0-indexing
//						message: "Missing column at index \(index)"
//					)
//				}
//				
//				let valueString = columns[index].trimmingCharacters(in: .whitespaces)
//				guard let value = Double(valueString) else {
//					throw CSVImportError.parsingError(
//						row: rowIndex + 2,
//						message: "Invalid value '\(valueString)' for account '\(accountName)'"
//					)
//				}
//				
//				values.append(value)
//			}
//			
//			// Create time series for this account
//			result[accountName] = TimeSeries(periods: periods, values: values)
//		}
//		
//		return result
//	}
//	
//	// MARK: - Helper Methods
//	
//	private func parsePeriod(from string: String, format: String?) -> Period? {
//		// Try parsing as quarter (e.g., "2024-Q1")
//		if string.contains("Q") {
//			let parts = string.components(separatedBy: "-")
//			if parts.count == 2,
//			   let year = Int(parts[0]),
//			   let quarter = Int(parts[1].replacingOccurrences(of: "Q", with: "")) {
//				return .quarter(year: year, quarter: quarter)
//			}
//		}
//		
//		// Try parsing as date
//		let dateFormatter = DateFormatter()
//		if let format = format {
//			dateFormatter.dateFormat = format
//		} else {
//			dateFormatter.dateFormat = "yyyy-MM-dd"
//		}
//		
//		if let date = dateFormatter.date(from: string) {
//			return .day(date)
//		}
//		
//		// Try ISO8601
//		if #available(macOS 10.12, iOS 10.0, *) {
//			let isoFormatter = ISO8601DateFormatter()
//			if let date = isoFormatter.date(from: string) {
//				return .day(date)
//			}
//		}
//		
//		return nil
//	}
//}
