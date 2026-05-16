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
	// LIVE: public API enum case for consumer error handling
	case networkError(Error)

	/// The response from the server was invalid or malformed.
	// LIVE: public API enum case for consumer error handling
	case invalidResponse

	/// The requested symbol was not found or is invalid.
	// LIVE: public API enum case for consumer error handling
	case invalidSymbol(String)

	/// Rate limit exceeded for the data provider.
	// LIVE: public API enum case for consumer error handling
	case rateLimited

	/// The date range is invalid (e.g., 'from' date is after 'to' date).
	// LIVE: public API enum case for consumer error handling
	case invalidDateRange

	/// No data available for the requested parameters.
	// LIVE: public API enum case for consumer error handling
	case noData

	/// Authentication or API key is missing or invalid.
	// LIVE: public API enum case for consumer error handling
	case authenticationRequired

	/// A configuration parameter is invalid (e.g., negative timeout, zero max requests).
	// LIVE: public API enum case for consumer error handling
	case configurationError(String)
}
