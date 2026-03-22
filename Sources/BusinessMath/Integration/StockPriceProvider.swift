//
//  StockPriceProvider.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/20/26.
//

import Foundation
import Numerics

// MARK: - StockPriceProvider

/// Protocol for providers that supply historical stock/asset price data.
///
/// Conforming types fetch time series of closing prices from external data sources.
/// Not all market data providers supply stock prices — for example, FRED provides
/// economic indicators but not equity prices. By conforming only to `StockPriceProvider`,
/// a type signals that it supports price data without being forced to implement
/// financial statement or metrics methods.
///
/// ## Usage
///
/// ```swift
/// let provider: any StockPriceProvider = YahooFinanceProvider()
/// let prices = try await provider.fetchStockPrice(
///     symbol: "AAPL",
///     from: startDate,
///     to: endDate
/// )
/// ```
///
/// ## Protocol Composition
///
/// Combine with ``FinancialsProvider`` and ``MarketMetricsProvider`` for full coverage:
///
/// ```swift
/// typealias FullProvider = StockPriceProvider & FinancialsProvider & MarketMetricsProvider
/// ```
///
/// ## Topics
///
/// ### Fetching Prices
/// - ``fetchStockPrice(symbol:from:to:)``
public protocol StockPriceProvider: Sendable {
	/// Fetches historical stock prices for a given symbol.
	///
	/// Returns daily closing prices as a `TimeSeries<Double>` where each period
	/// represents a trading day.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol (e.g., "AAPL", "MSFT").
	///   - from: The start date for the data range.
	///   - to: The end date for the data range.
	///
	/// - Returns: A time series of daily closing prices.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.invalidDateRange`: If the date range is invalid.
	///   - `MarketDataError.networkError`: If the network request fails.
	///   - `MarketDataError.rateLimited`: If rate limits are exceeded.
	func fetchStockPrice(
		symbol: String,
		from: Date,
		to: Date
	) async throws -> TimeSeries<Double>
}
