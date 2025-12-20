//
//  extensionFormatted.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/19/25.
//

import Foundation

extension BinaryFloatingPoint {
	public func currency(_ decimals: Int = 2, _ currency: String = "usd") -> String {
		let code = currency.uppercased()
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
				// Use modern FormatStyle on newer OSes
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
	
	public func percent(_ decimals: Int = 2, _ significantDigitsRange: ClosedRange<Int> = (1...3), _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ signStrategy: NumberFormatStyleConfiguration.SignDisplayStrategy = .always(includingZero: false), _ grouping: NumberFormatStyleConfiguration.Grouping = .automatic, _ notation: NumberFormatStyleConfiguration.Notation = .automatic) -> String {
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			return value.formatted(
				.percent
					.precision(decimals != 2 ? .fractionLength(decimals) : .significantDigits(significantDigitsRange))
					.rounded(rule: roundingRule)
					.locale(locale)
					.sign(strategy: .always(includingZero: false))
					.grouping(grouping)
					.notation(notation)
					
			)
				
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
	
	public func number(_ decimals: Int = 2, _ roundingRule: FloatingPointRoundingRule = .toNearestOrAwayFromZero, _ locale: Locale = .autoupdatingCurrent, _ grouping: NumberFormatStyleConfiguration.Grouping = .automatic, _ notation: NumberFormatStyleConfiguration.Notation = .automatic) -> String {
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			return value.formatted(
				.number
					.precision(.fractionLength(decimals))
					.rounded(rule: roundingRule)
					.locale(locale)
					.grouping(grouping)
					.notation(notation)
			)
		} else {
			let formatter = NumberFormatter()
			formatter.numberStyle = .decimal
			formatter.maximumFractionDigits = decimals
			formatter.minimumFractionDigits = decimals
			return formatter.string(from: NSNumber(value: value)) ?? String(value)
		}
	}
}
