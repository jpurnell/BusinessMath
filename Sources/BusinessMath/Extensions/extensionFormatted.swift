//
//  extensionFormatted.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/19/25.
//

import Foundation

/// Number sign display options for formatting.
/// Controls how positive/negative signs are displayed for numbers and percentages.
public enum BMNumberSignDisplay {
	case automatic
	case never
	case always(includingZero: Bool)
}

/// Currency sign display options for formatting.
/// Controls how positive/negative signs are displayed for currency amounts, including accounting format with parentheses.
public enum BMCurrencySignDisplay {
	case automatic
	case never
	case always(showZero: Bool)
	case accounting
	case accountingAlways(showZero: Bool)
}

/// Number grouping options for formatting.
/// Controls whether thousands separators (e.g., commas in "1,234.56") are displayed.
public enum BMNumberGrouping {
	case automatic
	case never
}

/// Number notation style options for formatting.
/// Controls whether numbers use standard decimal, scientific (1.23e4), or compact (12.3K) notation.
public enum BMNumberNotation {
	case automatic
	case scientific
	case compactName
}

/// Currency presentation style options for formatting.
/// Controls how currency symbols/codes are displayed in formatted output.
public enum BMNumberPresentation {
	case narrow
	case standard
	case isoCode
	case fullName
}

extension BinaryFloatingPoint {

	/// Formats the number as currency with specified precision, currency code, and styling options.
	/// - Parameters:
	///   - decimals: Number of decimal places (default: 2)
	///   - currency: ISO 4217 currency code (default: "usd")
	///   - significantDigitsRange: Range of significant digits to display (default: 1...3)
	///   - signStrategy: How to display positive/negative amounts (default: .automatic)
	///   - roundingRule: Rounding rule to apply (default: .toNearestOrAwayFromZero)
	///   - locale: Locale for formatting (default: .autoupdatingCurrent)
	///   - grouping: Whether to use thousands separators (default: .automatic)
	///   - presentation: Currency presentation style - symbol, code, or name (default: .standard)
	/// - Returns: Formatted currency string (e.g., "$1,234.56")
	public func currency(_ decimals: Int = 2, _ currency: String = "usd", _ significantDigitsRange: ClosedRange<Int> = (1...3), signStrategy: BMCurrencySignDisplay = .automatic, _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ grouping: BMNumberGrouping = .automatic, _ presentation: BMNumberPresentation = .standard) -> String {
		let code = currency.uppercased()
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			var style = FloatingPointFormatStyle<Double>.Currency.currency(code: currency)
			style = style
				.precision(.fractionLength(decimals))
				.rounded(rule: roundingRule)
				.locale(locale)
			
			switch signStrategy {
				case .automatic:
					break
				case .never:
					style = style.sign(strategy: .never)
				case .always(let showZero):
					style = style.sign(strategy: .always(showZero: showZero))
				case .accounting:
					style = style.sign(strategy: .accounting)
				case .accountingAlways(let showZero):
					style = style.sign(strategy: .accountingAlways(showZero: showZero))
			}
			
			switch grouping {
				case .automatic:
					style = style.grouping(.automatic)
				case .never:
					style = style.grouping(.never)
			}
			
			switch presentation {
				case .narrow:
					style = style.presentation(.narrow)
				case .standard:
					style = style.presentation(.standard)
				case .isoCode:
					style = style.presentation(.isoCode)
				case .fullName:
					style = style.presentation(.fullName)
			}
			
			return value.formatted(
				.currency(code: code)
				.precision(.fractionLength(decimals))
				.rounded(rule: .toNearestOrAwayFromZero)
				.locale(Locale(identifier: "en_US"))			// For consistent formatting
				.sign(strategy: .accounting)
				.grouping(.automatic)
				.presentation(.standard))
		} else {
				// Fallback for older OSes (iOS 14, macOS 11, etc.)
			let formatter = NumberFormatter()
			formatter.numberStyle = .currency
			formatter.currencyCode = code
			formatter.maximumFractionDigits = decimals
			formatter.minimumFractionDigits = decimals
				// NumberFormatter has no direct “narrow” presentation; this is a reasonable approximation.
			return formatter.string(from: NSNumber(value: value)) ?? String(value)
		}
	}

	/// Formats the number as a percentage with specified precision and styling.
	/// - Parameters:
	///   - decimals: Number of decimal places (default: 2)
	///   - signStrategy: How to display positive/negative signs (default: .automatic)
	///   - significantDigitsRange: Range of significant digits (default: 1...3)
	///   - roundingRule: Rounding rule to apply (default: .toNearestOrAwayFromZero)
	///   - locale: Locale for formatting (default: .autoupdatingCurrent)
	///   - grouping: Whether to use thousands separators (default: .automatic)
	///   - notation: Notation style - decimal, scientific, or compact (default: .automatic)
	/// - Returns: Formatted percentage string (e.g., "12.50%")
	public func percent(_ decimals: Int = 2, _ signStrategy: BMNumberSignDisplay = .automatic, _ significantDigitsRange: ClosedRange<Int> = (1...3), _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ grouping: BMNumberGrouping = .automatic, _ notation: BMNumberNotation = .automatic) -> String {
		let value = Double(self)
		if value.isInfinite { return "∞" }
		if value.isNaN { return "NaN" }
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			var style = FloatingPointFormatStyle<Double>.Percent.percent
			style = style
				.precision(.fractionLength(decimals))
				.rounded(rule: roundingRule)
				.locale(locale)
			
			switch signStrategy {
				case .automatic:
					break
				case .never:
					style = style.sign(strategy: .never)
				case .always(let includingZero):
					style = style.sign(strategy: .always(includingZero: includingZero))
			}
			
			switch grouping {
				case .automatic:
					style = style.grouping(.automatic)
				case .never:
					style = style.grouping(.never)
			}
			
			switch notation {
				case .automatic:
					style = style.notation(.automatic)
				case .scientific:
					style = style.notation(.scientific)
				case .compactName:
					style = style.notation(.compactName)
			}
			
			return value.formatted(style)
		} else {
				// Fallback for older OSes (iOS 14, macOS 11, etc.)
			let formatter = NumberFormatter()
			formatter.numberStyle = .percent
			formatter.maximumFractionDigits = decimals
			formatter.minimumFractionDigits = decimals
				// NumberFormatter has no direct “narrow” presentation; this is a reasonable approximation.
			return formatter.string(from: NSNumber(value: value)) ?? String(value)
		}
	}

	/// Formats the number as a plain decimal number with specified precision and styling.
	/// - Parameters:
	///   - decimals: Number of decimal places (default: 2)
	///   - roundingRule: Rounding rule to apply (default: .toNearestOrAwayFromZero)
	///   - locale: Locale for formatting (default: .autoupdatingCurrent)
	///   - signStrategy: How to display positive/negative signs (default: .automatic)
	///   - grouping: Whether to use thousands separators (default: .automatic)
	///   - notation: Notation style - decimal, scientific, or compact (default: .automatic)
	/// - Returns: Formatted number string (e.g., "1,234.56")
	public func number(_ decimals: Int = 2, _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ signStrategy: BMNumberSignDisplay = .automatic, _ grouping: BMNumberGrouping = .automatic, _ notation: BMNumberNotation = .automatic) -> String {
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			var style = FloatingPointFormatStyle<Double>.number
			style = style
				.precision(.fractionLength(decimals))
				.rounded(rule: roundingRule)
				.locale(locale)
			
			switch signStrategy {
				case .automatic:
					break
				case .never:
					style = style.sign(strategy: .never)
				case .always(let includingZero):
					style = style.sign(strategy: .always(includingZero: includingZero))
			}
			
			switch grouping {
				case .automatic:
					style = style.grouping(.automatic)
				case .never:
					style = style.grouping(.never)
			}
			
			switch notation {
				case .automatic:
					style = style.notation(.automatic)
				case .scientific:
					style = style.notation(.scientific)
				case .compactName:
					style = style.notation(.compactName)
			}
			
			return value.formatted(style)
		} else {
			let formatter = NumberFormatter()
			formatter.numberStyle = .decimal
			formatter.maximumFractionDigits = decimals
			formatter.minimumFractionDigits = decimals
			return formatter.string(from: NSNumber(value: value)) ?? String(value)
		}
	}
}

extension Int {
	/// Formats the integer with right-aligned padding to achieve a fixed width.
	///
	/// Prepends spaces to the integer's string representation to ensure it occupies
	/// at least the specified width. Useful for aligning numbers in tables, reports,
	/// or columnar output.
	///
	/// - Parameter width: The minimum width of the resulting string (default: 1).
	///   If the integer's representation is already wider than this value, no padding
	///   is added and the full number is returned.
	///
	/// - Returns: A string representation of the integer, right-aligned and padded
	///   with leading spaces to achieve the specified width. If the integer's string
	///   representation exceeds the width, the full number is returned unmodified.
	///
	/// ## Examples
	///
	/// ```swift
	/// 42.width(5)      // "   42"  (3 leading spaces)
	/// 7.width(3)       // "  7"    (2 leading spaces)
	/// (-7).width(4)    // "  -7"   (2 leading spaces)
	/// 9.width()        // "9"      (default width of 1)
	/// 1000.width(3)    // "1000"   (no padding - number is wider than requested)
	/// ```
	///
	/// ## Use Cases
	///
	/// **Table Formatting:**
	/// ```swift
	/// print("Year: \(2024.width(4))")
	/// print("Year: \(2025.width(4))")
	/// // Output:
	/// // Year: 2024
	/// // Year: 2025
	/// ```
	///
	/// **Financial Reports:**
	/// ```swift
	/// let revenue = 1_234_567
	/// let expenses = 89_012
	/// print("Revenue:  $\(revenue.width(10))")
	/// print("Expenses: $\(expenses.width(10))")
	/// // Output:
	/// // Revenue:  $   1234567
	/// // Expenses: $     89012
	/// ```
	///
	/// **Mixed-Width Numbers:**
	/// ```swift
	/// [5, 42, 100, 1234].forEach { num in
	///     print("Value: \(num.width(4))")
	/// }
	/// // Output:
	/// // Value:    5
	/// // Value:   42
	/// // Value:  100
	/// // Value: 1234
	/// ```
	///
	/// - Note: Negative numbers include the minus sign in the width calculation.
	///   For example, `-123` requires 4 characters (minus sign + 3 digits).
	///
	/// - Note: This function never truncates numbers. If the integer exceeds the
	///   specified width, the full representation is returned.
	public func width(_ width: Int = 1) -> String {
		let numberString = String(self)
		let paddingNeeded = width - numberString.count
		let paddingCount = paddingNeeded > 0 ? paddingNeeded : 0
		let formattedString = String(repeating: " ", count: paddingCount) + numberString
		return formattedString
	}
}
