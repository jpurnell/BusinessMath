//
//  FinancialsProvider.swift
//  BusinessMath
//
//  Created by Justin Purnell on 3/20/26.
//

import Foundation
import Numerics

// MARK: - FinancialsProvider

/// Protocol for providers that supply structured financial statement data.
///
/// Conforming types fetch typed financial statements — income statements, balance sheets,
/// and cash flow statements — from external data sources. The return types are the library's
/// own ``IncomeStatement``, ``BalanceSheet``, and ``CashFlowStatement`` structs, providing
/// compile-time type safety instead of untyped dictionaries.
///
/// ## Usage
///
/// ```swift
/// // Concrete providers live in the BusinessMathMarketData package
/// struct StubProvider: FinancialsProvider {
///     func fetchIncomeStatement(symbol: String, period: ReportingPeriod) async throws -> IncomeStatement<Double> {
///         try IncomeStatement<Double>.documentationFixture
///     }
///     func fetchBalanceSheet(symbol: String, period: ReportingPeriod) async throws -> BalanceSheet<Double> {
///         try BalanceSheet<Double>.documentationFixture
///     }
///     func fetchCashFlowStatement(symbol: String, period: ReportingPeriod) async throws -> CashFlowStatement<Double> {
///         try CashFlowStatement<Double>.documentationFixture
///     }
/// }
///
/// let provider: any FinancialsProvider = StubProvider()
///
/// Task {
///     let income = try await provider.fetchIncomeStatement(symbol: "AAPL", period: .annual)
///     let revenue = income.totalRevenue
///     print(revenue)
/// }
/// ```
///
/// ## Topics
///
/// ### Fetching Statements
/// - ``fetchIncomeStatement(symbol:period:)``
/// - ``fetchBalanceSheet(symbol:period:)``
/// - ``fetchCashFlowStatement(symbol:period:)``
public protocol FinancialsProvider: Sendable {
	/// Fetches an income statement for a given symbol.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol (e.g., "AAPL").
	///   - period: The reporting period (quarterly or annual).
	///
	/// - Returns: A typed ``IncomeStatement`` with revenue, expenses, and profitability metrics.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.noData`: If no data is available.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchIncomeStatement(
		symbol: String,
		period: ReportingPeriod
	) async throws -> IncomeStatement<Double>

	/// Fetches a balance sheet for a given symbol.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol (e.g., "AAPL").
	///   - period: The reporting period (quarterly or annual).
	///
	/// - Returns: A typed ``BalanceSheet`` with assets, liabilities, and equity.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.noData`: If no data is available.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchBalanceSheet(
		symbol: String,
		period: ReportingPeriod
	) async throws -> BalanceSheet<Double>

	/// Fetches a cash flow statement for a given symbol.
	///
	/// - Parameters:
	///   - symbol: The stock ticker symbol (e.g., "AAPL").
	///   - period: The reporting period (quarterly or annual).
	///
	/// - Returns: A typed ``CashFlowStatement`` with operating, investing, and financing flows.
	///
	/// - Throws:
	///   - `MarketDataError.invalidSymbol`: If the symbol is not found.
	///   - `MarketDataError.noData`: If no data is available.
	///   - `MarketDataError.networkError`: If the network request fails.
	func fetchCashFlowStatement(
		symbol: String,
		period: ReportingPeriod
	) async throws -> CashFlowStatement<Double>
}
