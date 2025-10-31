//
//  CSVImportError.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - CSVImportError

/// Errors that can occur during CSV import operations.
public enum CSVImportError: Error, Sendable {
	/// The CSV format is invalid or cannot be parsed.
	case invalidFormat

	/// A required column is missing from the CSV.
	/// - Parameter column: The name of the missing column.
	case missingColumn(String)

	/// A date string cannot be parsed.
	/// - Parameter dateString: The invalid date string.
	case invalidDate(String)

	/// A value string cannot be converted to a number.
	/// - Parameter valueString: The invalid value string.
	case invalidValue(String)

	/// The file cannot be read.
	/// - Parameter url: The URL that failed to read.
	case fileReadError(URL)

	/// The CSV has no data rows.
	case noData

	/// The specified delimiter is not found in the header.
	case invalidDelimiter
}
