//
//  YahooFinanceProvider.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - YahooFinanceProvider

/// Fetches market data from Yahoo Finance.
///
/// `YahooFinanceProvider` implements the `MarketDataProvider` protocol
/// to retrieve historical stock prices and market data from Yahoo Finance's
/// public APIs.
///
/// ## Basic Usage
///
/// ```swift
/// let provider = YahooFinanceProvider()
///
/// let prices = try await provider.fetchStockPrice(
///     symbol: "AAPL",
///     from: Date(timeIntervalSince1970: 1640995200),
///     to: Date(timeIntervalSince1970: 1672531200)
/// )
///
/// print("Fetched \\(prices.periods.count) days of data")
/// ```
///
/// ## Rate Limiting
///
/// Yahoo Finance has rate limits. Be mindful of making too many requests
/// in a short period. Consider implementing caching or request throttling
/// for production use.
///
/// ## Topics
///
/// ### Creating Providers
/// - ``init(session:)``
///
/// ### Fetching Data
/// - ``fetchStockPrice(symbol:from:to:)``
/// - ``fetchFinancials(symbol:statement:period:)``
/// - ``fetchMetrics(symbol:)``
public struct YahooFinanceProvider: MarketDataProvider {

	// MARK: - Properties

	/// The URL session to use for network requests.
	private let session: URLSession

	// MARK: - Initialization

	/// Creates a new Yahoo Finance provider.
	///
	/// - Parameter session: The URL session to use. Defaults to `.shared`.
	public init(session: URLSession = .shared) {
		self.session = session
	}

	// MARK: - MarketDataProvider

	/// Fetches historical stock prices from Yahoo Finance.
	///
	/// Downloads historical daily closing prices for the specified symbol
	/// and date range from Yahoo Finance's CSV download API.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol (e.g., "AAPL").
	///   - from: The start date for the data range.
	///   - to: The end date for the data range.
	///
	/// - Returns: A time series of daily closing prices.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.invalidDateRange`: If from > to.
	///   - `MarketDataError.networkError`: If the request fails.
	///   - `MarketDataError.invalidResponse`: If the CSV cannot be parsed.
	///
	/// ## Example
	/// ```swift
	/// let provider = YahooFinanceProvider()
	/// let prices = try await provider.fetchStockPrice(
	///     symbol: "AAPL",
	///     from: Date(timeIntervalSince1970: 1609459200),
	///     to: Date(timeIntervalSince1970: 1640995200)
	/// )
	/// ```
	public func fetchStockPrice(
		symbol: String,
		from: Date,
		to: Date
	) async throws -> TimeSeries<Double> {
		// Validate date range
		guard from <= to else {
			throw MarketDataError.invalidDateRange
		}

		// Build URL
		guard let url = buildStockPriceURL(symbol: symbol, from: from, to: to) else {
			throw MarketDataError.invalidSymbol(symbol)
		}

		// Fetch data
		let (data, response) = try await session.data(from: url)

		// Check HTTP response
		guard let httpResponse = response as? HTTPURLResponse else {
			throw MarketDataError.invalidResponse
		}

		// Handle HTTP errors
		switch httpResponse.statusCode {
		case 200:
			break
		case 404:
			throw MarketDataError.invalidSymbol(symbol)
		case 429:
			throw MarketDataError.rateLimited
		default:
			throw MarketDataError.invalidResponse
		}

		// Parse CSV
		guard let csvString = String(data: data, encoding: .utf8) else {
			throw MarketDataError.invalidResponse
		}

		return try parseStockPriceCSV(csvString)
	}

	/// Fetches financial statement data.
	///
	/// **Note**: This is a placeholder implementation. Yahoo Finance does not
	/// provide a simple API for financial statements. Consider using other
	/// providers like Alpha Vantage or Financial Modeling Prep for this data.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol.
	///   - statement: The type of financial statement.
	///   - period: The reporting period.
	///
	/// - Returns: A dictionary containing financial data.
	///
	/// - Throws: `MarketDataError.noData` - not implemented.
	public func fetchFinancials(
		symbol: String,
		statement: FinancialStatementType,
		period: ReportingPeriod
	) async throws -> [String: Any] {
		// Yahoo Finance doesn't provide a straightforward API for financial statements
		// This would require screen scraping or using a different provider
		throw MarketDataError.noData
	}

	/// Fetches current market metrics.
	///
	/// **Note**: This is a placeholder implementation. Yahoo Finance does not
	/// provide a simple API for market metrics. Consider using other providers
	/// like Alpha Vantage or Financial Modeling Prep for this data.
	///
	/// - Parameter symbol: The stock ticker symbol.
	///
	/// - Returns: A dictionary of metric names to values.
	///
	/// - Throws: `MarketDataError.noData` - not implemented.
	public func fetchMetrics(symbol: String) async throws -> [String: Double] {
		// Yahoo Finance doesn't provide a straightforward API for metrics
		// This would require screen scraping or using a different provider
		throw MarketDataError.noData
	}

	// MARK: - Private Helpers

	/// Builds the Yahoo Finance URL for historical stock prices.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol.
	///   - from: The start date.
	///   - to: The end date.
	///
	/// - Returns: A URL for downloading CSV data, or nil if construction fails.
	private func buildStockPriceURL(symbol: String, from: Date, to: Date) -> URL? {
		let period1 = Int(from.timeIntervalSince1970)
		let period2 = Int(to.timeIntervalSince1970)

		var components = URLComponents()
		components.scheme = "https"
		components.host = "query1.finance.yahoo.com"
		components.path = "/v7/finance/download/\(symbol)"
		components.queryItems = [
			URLQueryItem(name: "period1", value: "\(period1)"),
			URLQueryItem(name: "period2", value: "\(period2)"),
			URLQueryItem(name: "interval", value: "1d"),
			URLQueryItem(name: "events", value: "history"),
			URLQueryItem(name: "includeAdjustedClose", value: "true")
		]

		return components.url
	}

	/// Parses Yahoo Finance CSV data into a time series.
	///
	/// Expected CSV format:
	/// ```
	/// Date,Open,High,Low,Close,Adj Close,Volume
	/// 2024-01-02,185.00,186.50,184.00,185.64,185.64,50000000
	/// ```
	///
	/// - Parameter csv: The CSV string to parse.
	///
	/// - Returns: A time series of closing prices.
	///
	/// - Throws: `MarketDataError.invalidResponse` if parsing fails.
	private func parseStockPriceCSV(_ csv: String) throws -> TimeSeries<Double> {
		let lines = csv.components(separatedBy: .newlines)

		guard lines.count > 1 else {
			throw MarketDataError.invalidResponse
		}

		var periods: [Period] = []
		var values: [Double] = []

		let dateFormatter = ISO8601DateFormatter()
		dateFormatter.formatOptions = [.withFullDate]

		// Skip header row
		for line in lines.dropFirst() {
			guard !line.isEmpty else { continue }

			let columns = line.components(separatedBy: ",")
			guard columns.count >= 5 else { continue }

			// Parse date (column 0)
			guard let date = dateFormatter.date(from: columns[0]) else {
				continue
			}

			// Parse close price (column 4)
			guard let close = Double(columns[4]) else {
				continue
			}

			periods.append(Period.day(date))
			values.append(close)
		}

		guard !periods.isEmpty else {
			throw MarketDataError.noData
		}

		return TimeSeries(periods: periods, values: values)
	}
}
