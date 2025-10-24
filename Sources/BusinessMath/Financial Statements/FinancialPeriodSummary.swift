//
//  FinancialPeriodSummary.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/23/25.
//

import Foundation
import Numerics

/// Comprehensive financial summary for a single period.
///
/// `FinancialPeriodSummary` provides a "one-pager" view of a company's financial position
/// and performance for a specific period. This is the data structure layer - presentation
/// is handled separately by SwiftUI views, CLI formatters, or chart renderers.
///
/// ## Example Usage
///
/// ```swift
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc")
/// let q1 = Period.quarter(year: 2025, quarter: 1)
///
/// let summary = try FinancialPeriodSummary(
///     entity: entity,
///     period: q1,
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     cashFlowStatement: cashFlowStatement,  // Optional
///     marketData: marketData,                 // Optional
///     operationalMetrics: operationalMetrics  // Optional
/// )
///
/// // Access specific metrics
/// print("Revenue: $\(summary.revenue)")
/// print("ROE: \(summary.roe * 100)%")
/// print("Debt/Equity: \(summary.debtToEquityRatio)x")
/// ```
public struct FinancialPeriodSummary<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// The entity this summary belongs to
	public let entity: Entity

	/// The period covered by this summary
	public let period: Period

	// MARK: - Income Statement Metrics

	public let revenue: T
	public let grossProfit: T
	public let operatingIncome: T
	public let ebitda: T
	public let netIncome: T
	public let grossMargin: T
	public let operatingMargin: T
	public let netMargin: T

	// MARK: - Balance Sheet Metrics

	public let totalAssets: T
	public let currentAssets: T
	public let totalLiabilities: T
	public let currentLiabilities: T
	public let totalEquity: T
	public let workingCapital: T
	public let cash: T
	public let debt: T
	public let netDebt: T

	// MARK: - Cash Flow Metrics (Optional)

	public let operatingCashFlow: T?
	public let investingCashFlow: T?
	public let financingCashFlow: T?
	public let freeCashFlow: T?
	public let netCashFlow: T?

	// MARK: - Profitability Ratios

	public let roa: T
	public let roe: T

	// MARK: - Liquidity Ratios

	public let currentRatio: T
	public let quickRatio: T
	public let cashRatio: T

	// MARK: - Leverage Ratios

	public let debtToEquityRatio: T
	public let debtToAssetsRatio: T
	public let equityRatio: T

	// MARK: - Efficiency Ratios (Optional)

	public let assetTurnoverRatio: T?
	public let inventoryTurnoverRatio: T?
	public let receivablesTurnoverRatio: T?

	// MARK: - Credit Metrics

	public let debtToEBITDARatio: T
	public let netDebtToEBITDARatio: T
	public let interestCoverageRatio: T?

	// MARK: - Valuation Metrics (Optional)

	public let marketCap: T?
	public let ev: T?
	public let peRatio: T?
	public let pbRatio: T?
	public let psRatio: T?
	public let evToEBITDARatio: T?

	// MARK: - Operational Metrics (Optional)

	public let operationalMetrics: OperationalMetrics<T>?

	/// Create a comprehensive financial summary for a period.
	public init(
		entity: Entity,
		period: Period,
		incomeStatement: IncomeStatement<T>,
		balanceSheet: BalanceSheet<T>,
		cashFlowStatement: CashFlowStatement<T>? = nil,
		marketData: MarketData<T>? = nil,
		operationalMetrics: OperationalMetrics<T>? = nil
	) throws {
		self.entity = entity
		self.period = period
		self.operationalMetrics = operationalMetrics

		// Income Statement
		self.revenue = incomeStatement.totalRevenue[period] ?? T(0)
		self.grossProfit = incomeStatement.grossProfit[period] ?? T(0)
		self.operatingIncome = incomeStatement.operatingIncome[period] ?? T(0)
		self.ebitda = incomeStatement.ebitda[period] ?? T(0)
		self.netIncome = incomeStatement.netIncome[period] ?? T(0)

		// Margins
		if revenue != T(0) {
			self.grossMargin = grossProfit / revenue
			self.operatingMargin = operatingIncome / revenue
			self.netMargin = netIncome / revenue
		} else {
			self.grossMargin = T(0)
			self.operatingMargin = T(0)
			self.netMargin = T(0)
		}

		// Balance Sheet
		self.totalAssets = balanceSheet.totalAssets[period] ?? T(0)
		self.currentAssets = balanceSheet.currentAssets[period] ?? T(0)
		self.totalLiabilities = balanceSheet.totalLiabilities[period] ?? T(0)
		self.currentLiabilities = balanceSheet.currentLiabilities[period] ?? T(0)
		self.totalEquity = balanceSheet.totalEquity[period] ?? T(0)
		self.workingCapital = currentAssets - currentLiabilities
		self.cash = balanceSheet.cashAndEquivalents[period] ?? T(0)
		self.debt = balanceSheet.interestBearingDebt[period] ?? T(0)
		self.netDebt = debt - cash

		// Cash Flow Statement (optional)
		if let cfs = cashFlowStatement {
			self.operatingCashFlow = cfs.operatingCashFlow[period]
			self.investingCashFlow = cfs.investingCashFlow[period]
			self.financingCashFlow = cfs.financingCashFlow[period]
			self.freeCashFlow = cfs.freeCashFlow[period]
			self.netCashFlow = cfs.netCashFlow[period]
		} else {
			self.operatingCashFlow = nil
			self.investingCashFlow = nil
			self.financingCashFlow = nil
			self.freeCashFlow = nil
			self.netCashFlow = nil
		}

		// Profitability Ratios
		let roaSeries = returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		let roeSeries = returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		self.roa = roaSeries[period] ?? T(0)
		self.roe = roeSeries[period] ?? T(0)

		// Liquidity Ratios
		self.currentRatio = balanceSheet.currentRatio[period] ?? T(0)
		self.quickRatio = balanceSheet.quickRatio[period] ?? T(0)
		self.cashRatio = balanceSheet.cashRatio[period] ?? T(0)

		// Leverage Ratios
		self.debtToEquityRatio = balanceSheet.debtToEquity[period] ?? T(0)
		self.debtToAssetsRatio = balanceSheet.debtRatio[period] ?? T(0)
		self.equityRatio = balanceSheet.equityRatio[period] ?? T(0)

		// Efficiency Ratios (optional - may not have required accounts)
		let assetTurnoverSeries = assetTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		self.assetTurnoverRatio = assetTurnoverSeries[period]

		if let invTurnoverSeries = try? inventoryTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet) {
			self.inventoryTurnoverRatio = invTurnoverSeries[period]
		} else {
			self.inventoryTurnoverRatio = nil
		}

		if let recTurnoverSeries = try? receivablesTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet) {
			self.receivablesTurnoverRatio = recTurnoverSeries[period]
		} else {
			self.receivablesTurnoverRatio = nil
		}

		// Credit Metrics
		if ebitda != T(0) {
			self.debtToEBITDARatio = debt / ebitda
			self.netDebtToEBITDARatio = netDebt / ebitda
		} else {
			self.debtToEBITDARatio = T(0)
			self.netDebtToEBITDARatio = T(0)
		}

		if let coverageSeries = try? interestCoverage(incomeStatement: incomeStatement) {
			self.interestCoverageRatio = coverageSeries[period]
		} else {
			self.interestCoverageRatio = nil
		}

		// Valuation Metrics (optional - requires market data)
		if let market = marketData {
			let marketCapSeries = marketCapitalization(
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)
			let evSeries = enterpriseValue(
				balanceSheet: balanceSheet,
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)
			let peSeries = priceToEarnings(
				incomeStatement: incomeStatement,
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)
			let pbSeries = priceToBook(
				balanceSheet: balanceSheet,
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)
			let psSeries = priceToSales(
				incomeStatement: incomeStatement,
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)
			let evEbitdaSeries = evToEbitda(
				incomeStatement: incomeStatement,
				balanceSheet: balanceSheet,
				marketPrice: market.price,
				sharesOutstanding: market.sharesOutstanding
			)

			// Assign values
			self.marketCap = marketCapSeries[period]
			self.ev = evSeries[period]

			let peValue = peSeries[period]
			self.peRatio = (peValue != nil && peValue! > T(0)) ? peValue : nil

			self.pbRatio = pbSeries[period]
			self.psRatio = psSeries[period]
			self.evToEBITDARatio = evEbitdaSeries[period]
		} else {
			self.marketCap = nil
			self.ev = nil
			self.peRatio = nil
			self.pbRatio = nil
			self.psRatio = nil
			self.evToEBITDARatio = nil
		}
	}
}

// MARK: - Market Data

/// Market data for valuation calculations.
public struct MarketData<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// Stock price time series
	public let price: TimeSeries<T>

	/// Shares outstanding time series
	public let sharesOutstanding: TimeSeries<T>

	public init(price: TimeSeries<T>, sharesOutstanding: TimeSeries<T>) {
		self.price = price
		self.sharesOutstanding = sharesOutstanding
	}
}
