//
//  MarketDataProvider.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - FinancialStatementType

/// The type of financial statement to retrieve.
public enum FinancialStatementType: String, Sendable {
	/// Income statement (profit and loss).
	case income

	/// Balance sheet.
	case balance

	/// Cash flow statement.
	case cashFlow
}

// MARK: - ReportingPeriod

/// The reporting period for financial data.
public enum ReportingPeriod: String, Sendable {
	/// Quarterly reporting period.
	case quarterly

	/// Annual reporting period.
	case annual
}

// MARK: - MarketDataProvider

/// Protocol for fetching financial market data from external sources.
///
/// `MarketDataProvider` defines an interface for retrieving stock prices,
/// financial statements, and market metrics from various data sources.
/// Implementations can connect to different APIs like Yahoo Finance,
/// Alpha Vantage, or other financial data providers.
///
/// ## Basic Usage
///
/// ```swift
/// let provider = YahooFinanceProvider()
///
/// // Fetch stock prices
/// let prices = try await provider.fetchStockPrice(
///     symbol: "AAPL",
///     from: startDate,
///     to: endDate
/// )
///
/// // Fetch financial statements
/// let financials = try await provider.fetchFinancials(
///     symbol: "AAPL",
///     statement: .income,
///     period: .quarterly
/// )
///
/// // Fetch market metrics
/// let metrics = try await provider.fetchMetrics(symbol: "AAPL")
/// print("P/E Ratio: \\(metrics["pe"] ?? 0)")
/// ```
///
/// ## Topics
///
/// ### Fetching Data
/// - ``fetchStockPrice(symbol:from:to:)``
/// - ``fetchFinancials(symbol:statement:period:)``
/// - ``fetchMetrics(symbol:)``
public protocol MarketDataProvider {
	/// Fetches historical stock prices for a given symbol.
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

	/// Fetches financial statement data for a given symbol.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol.
	///   - statement: The type of financial statement to retrieve.
	///   - period: The reporting period (quarterly or annual).
	///
	/// - Returns: A dictionary containing financial data fields.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.noData`: If no data is available.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchFinancials(
		symbol: String,
		statement: FinancialStatementType,
		period: ReportingPeriod
	) async throws -> [String: Any]

	/// Fetches current market metrics for a given symbol.
	///
	/// - Parameter symbol: The stock ticker symbol.
	///
	/// - Returns: A dictionary of metric names to values (e.g., "pe", "marketCap").
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchMetrics(symbol: String) async throws -> [String: Double]
}
