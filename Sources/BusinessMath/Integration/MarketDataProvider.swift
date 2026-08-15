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
	// LIVE: public API enum case for financial statement type selection
	case income

	/// Balance sheet.
	// LIVE: public API enum case for financial statement type selection
	case balance

	/// Cash flow statement.
	// LIVE: public API enum case for financial statement type selection
	case cashFlow
}

// MARK: - ReportingPeriod

/// The reporting period for financial data.
public enum ReportingPeriod: String, Sendable {
	/// Quarterly reporting period.
	// LIVE: public API enum case for reporting period selection
	case quarterly

	/// Annual reporting period.
	// LIVE: public API enum case for reporting period selection
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
/// // A full-service provider conforming to all three.
/// // Concrete providers live in the BusinessMathMarketData package.
/// struct StubProvider: MarketDataProvider {
///     func fetchStockPrice(symbol: String, from: Date, to: Date) async throws -> TimeSeries<Double> {
///         TimeSeries(periods: Period.documentationQuarters, values: [45.0, 47, 49, 51])
///     }
///     func fetchIncomeStatement(symbol: String, period: ReportingPeriod) async throws -> IncomeStatement<Double> {
///         try IncomeStatement<Double>.documentationFixture
///     }
///     func fetchBalanceSheet(symbol: String, period: ReportingPeriod) async throws -> BalanceSheet<Double> {
///         try BalanceSheet<Double>.documentationFixture
///     }
///     func fetchCashFlowStatement(symbol: String, period: ReportingPeriod) async throws -> CashFlowStatement<Double> {
///         try CashFlowStatement<Double>.documentationFixture
///     }
///     func fetchMetrics(symbol: String) async throws -> MarketMetrics {
///         MarketMetrics(symbol: symbol, asOf: Date(), priceToEarnings: 28.4)
///     }
/// }
///
/// let provider: any MarketDataProvider = StubProvider()
/// let start = Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1)) ?? Date()
/// let end = Calendar.current.date(from: DateComponents(year: 2025, month: 12, day: 31)) ?? Date()
///
/// Task {
///     // Use any individual capability
///     let prices = try await provider.fetchStockPrice(symbol: "AAPL", from: start, to: end)
///     let income = try await provider.fetchIncomeStatement(symbol: "AAPL", period: .annual)
///     let metrics = try await provider.fetchMetrics(symbol: "AAPL")
///     print(prices, income.totalRevenue, metrics.symbol)
/// }
/// ```
///
/// ## See Also
///
/// - ``StockPriceProvider``
/// - ``FinancialsProvider``
/// - ``MarketMetricsProvider``
public typealias MarketDataProvider = StockPriceProvider & FinancialsProvider & MarketMetricsProvider
