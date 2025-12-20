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
	
	public func percent(_ decimals: Int = 2) -> String {
		let value = Double(self)
		
		if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
			return value.formatted(
				.percent
					.precision(decimals != 2 ? .fractionLength(decimals) : .significantDigits(1...3))
					.rounded(rule: .toNearestOrAwayFromZero)
					.locale(.autoupdatingCurrent)
					.sign(strategy: .always(includingZero: false))
					.grouping(.automatic)
					.notation(.automatic)
					
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
	
	func digits(_ digitCount: Int) -> String {
		String(format: "%.\(digitCount)f", Double(self))
	}
}
