//
//  MarketDataError.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation

// MARK: - MarketDataError

/// Errors that can occur during market data operations.
public enum MarketDataError: Error, Sendable {
	/// The network request failed.
	case networkError(Error)

	/// The response from the server was invalid or malformed.
	case invalidResponse

	/// The requested symbol was not found or is invalid.
	case invalidSymbol(String)

	/// Rate limit exceeded for the data provider.
	case rateLimited

	/// The date range is invalid (e.g., 'from' date is after 'to' date).
	case invalidDateRange

	/// No data available for the requested parameters.
	case noData

	/// Authentication or API key is missing or invalid.
	case authenticationRequired
}
