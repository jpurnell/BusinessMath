//
//  extensionFormatted.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/19/25.
//

import Foundation

public enum BMNumberSignDisplay {
	case automatic
	case never
	case always(includingZero: Bool)
}

public enum BMCurrencySignDisplay {
	case automatic
	case never
	case always(showZero: Bool)
	case accounting
	case accountingAlways(showZero: Bool)
}

public enum BMNumberGrouping {
	case automatic
	case never
}

public enum BMNumberNotation {
	case automatic
	case scientific
	case compactName
}

public enum BMNumberPresentation {
	case narrow
	case standard
	case isoCode
	case fullName
}

extension BinaryFloatingPoint {

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
			
			return value.formatted(style)
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
	
	public func percent(_ decimals: Int = 2, _ signStrategy: BMNumberSignDisplay = .automatic, _ significantDigitsRange: ClosedRange<Int> = (1...3), _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ grouping: BMNumberGrouping = .automatic, _ notation: BMNumberNotation = .automatic) -> String {
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			var style = FloatingPointFormatStyle<Double>.Percent.percent
			style = style
				.precision(decimals != 2 ? .fractionLength(decimals) : .significantDigits(significantDigitsRange))
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
