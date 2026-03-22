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

/// A composed protocol requiring stock prices, financials, and market metrics.
///
/// `MarketDataProvider` is a typealias for types that conform to all three
/// split protocols: ``StockPriceProvider``, ``FinancialsProvider``, and
/// ``MarketMetricsProvider``. This follows the same pattern as Swift's
/// `Codable = Encodable & Decodable`.
///
/// Providers that only supply a subset of data (e.g., Yahoo Finance only
/// provides stock prices) should conform to the individual protocols instead.
///
/// ## Usage
///
/// ```swift
/// // A full-service provider conforming to all three
/// let provider: any MarketDataProvider = AlphaVantageProvider(config: config)
///
/// // Use any individual capability
/// let prices = try await provider.fetchStockPrice(symbol: "AAPL", from: start, to: end)
/// let income = try await provider.fetchIncomeStatement(symbol: "AAPL", period: .annual)
/// let metrics = try await provider.fetchMetrics(symbol: "AAPL")
/// ```
///
/// ## See Also
///
/// - ``StockPriceProvider``
/// - ``FinancialsProvider``
/// - ``MarketMetricsProvider``
public typealias MarketDataProvider = StockPriceProvider & FinancialsProvider & MarketMetricsProvider
