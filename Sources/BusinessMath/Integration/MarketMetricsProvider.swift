//
//  MarketMetricsProvider.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/20/26.
//

import Foundation

// MARK: - MarketMetricsProvider

/// Protocol for providers that supply current market metrics and ratios.
///
/// Conforming types fetch structured market metrics — P/E ratio, market cap,
/// EPS, beta, and more — from external data sources. Returns a typed
/// ``MarketMetrics`` struct instead of an untyped dictionary.
///
/// ## Usage
///
/// ```swift
/// let provider: any MarketMetricsProvider = AlphaVantageProvider(configuration: config)
/// let metrics = try await provider.fetchMetrics(symbol: "AAPL")
/// if let pe = metrics.priceToEarnings {
///     print("P/E: \(pe)")
/// }
/// ```
///
/// ## Topics
///
/// ### Fetching Metrics
/// - ``fetchMetrics(symbol:)``
public protocol MarketMetricsProvider: Sendable {
	/// Fetches current market metrics for a given symbol.
	///
	/// - Parameter symbol: The stock ticker symbol (e.g., "AAPL").
	///
	/// - Returns: A typed ``MarketMetrics`` with standard financial ratios and indicators.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.noData`: If no metrics are available.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchMetrics(symbol: String) async throws -> MarketMetrics
}
