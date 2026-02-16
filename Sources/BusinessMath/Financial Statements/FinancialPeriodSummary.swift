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

	/// Total revenue for the period.
	///
	/// Represents the top line—all income generated from business operations
	/// before any expenses are deducted.
	public let revenue: T

	/// Gross profit for the period.
	///
	/// Calculated as revenue minus cost of goods sold (COGS). Represents
	/// profit after direct production costs but before operating expenses.
	public let grossProfit: T

	/// Operating income (EBIT) for the period.
	///
	/// Earnings before interest and taxes. Represents profit from core
	/// business operations after all operating expenses but before financing costs.
	public let operatingIncome: T

	/// EBITDA (Earnings Before Interest, Taxes, Depreciation, and Amortization).
	///
	/// A proxy for operating cash generation, excluding non-cash charges
	/// and financing decisions. Widely used for company comparisons.
	public let ebitda: T

	/// Net income for the period.
	///
	/// The bottom line—profit after all expenses, interest, taxes,
	/// depreciation, and amortization. Available to shareholders.
	public let netIncome: T

	/// Gross profit margin as a percentage of revenue.
	///
	/// Calculated as `grossProfit / revenue`. Higher margins indicate
	/// better pricing power or lower production costs.
	///
	/// ## Interpretation
	/// - Higher is better
	/// - Typical range: 20%-80% depending on industry
	/// - Compares favorably across companies
	public let grossMargin: T

	/// Operating profit margin as a percentage of revenue.
	///
	/// Calculated as `operatingIncome / revenue`. Measures efficiency
	/// of core operations before financing and tax considerations.
	///
	/// ## Interpretation
	/// - Higher is better
	/// - Typical range: 5%-30% depending on industry
	/// - Indicates operational efficiency
	public let operatingMargin: T

	/// Net profit margin as a percentage of revenue.
	///
	/// Calculated as `netIncome / revenue`. The most comprehensive
	/// profitability measure, reflecting all aspects of the business.
	///
	/// ## Interpretation
	/// - Higher is better
	/// - Typical range: 5%-25% depending on industry
	/// - Includes impact of financing and tax strategies
	public let netMargin: T

	// MARK: - Balance Sheet Metrics

	/// Total assets at period end.
	///
	/// Sum of all assets—current and non-current—representing everything
	/// the company owns. Must equal `totalLiabilities + totalEquity`.
	public let totalAssets: T

	/// Current assets at period end.
	///
	/// Assets expected to be converted to cash within one year, including
	/// cash, accounts receivable, inventory, and short-term investments.
	public let currentAssets: T

	/// Total liabilities at period end.
	///
	/// Sum of all obligations—current and long-term—representing everything
	/// the company owes to creditors.
	public let totalLiabilities: T

	/// Current liabilities at period end.
	///
	/// Obligations due within one year, including accounts payable,
	/// short-term debt, accrued expenses, and current portion of long-term debt.
	public let currentLiabilities: T

	/// Total shareholders' equity at period end.
	///
	/// The residual interest in assets after deducting liabilities.
	/// Represents the shareholders' stake in the company.
	/// Calculated as `totalAssets - totalLiabilities`.
	public let totalEquity: T

	/// Working capital at period end.
	///
	/// Calculated as `currentAssets - currentLiabilities`. Measures short-term
	/// liquidity and operational efficiency. Positive working capital indicates
	/// the company can meet short-term obligations.
	///
	/// ## Interpretation
	/// - Positive: Can cover short-term liabilities
	/// - Negative: May face liquidity issues
	public let workingCapital: T

	/// Cash and cash equivalents at period end.
	///
	/// Most liquid assets, including currency, bank deposits, and
	/// highly liquid short-term investments. Critical for liquidity assessment.
	public let cash: T

	/// Interest-bearing debt at period end.
	///
	/// Total debt obligations, both current and long-term, that accrue interest.
	/// Excludes non-interest bearing liabilities like accounts payable.
	public let debt: T

	/// Net debt at period end.
	///
	/// Calculated as `debt - cash`. Represents debt after accounting for
	/// available cash to pay it down. Negative net debt means cash exceeds debt.
	///
	/// ## Interpretation
	/// - Positive: Company has more debt than cash
	/// - Negative: Company has more cash than debt (net cash position)
	public let netDebt: T

	// MARK: - Cash Flow Metrics (Optional)

	/// Cash flow from operating activities.
	///
	/// Cash generated or used by core business operations. A positive value
	/// indicates the business generates cash from operations.
	///
	/// - Note: Optional—only present if a ``CashFlowStatement`` was provided.
	public let operatingCashFlow: T?

	/// Cash flow from investing activities.
	///
	/// Cash used for (or generated from) investments in long-term assets
	/// like property, equipment, or acquisitions. Typically negative as
	/// companies invest in growth.
	///
	/// - Note: Optional—only present if a ``CashFlowStatement`` was provided.
	public let investingCashFlow: T?

	/// Cash flow from financing activities.
	///
	/// Cash from (or used for) transactions with shareholders and creditors,
	/// including debt issuance/repayment, dividends, and share buybacks.
	///
	/// - Note: Optional—only present if a ``CashFlowStatement`` was provided.
	public let financingCashFlow: T?

	/// Free cash flow for the period.
	///
	/// Cash available after capital expenditures. Calculated as
	/// `operatingCashFlow - capitalExpenditures`. Represents cash available
	/// for distribution to investors or debt repayment.
	///
	/// ## Interpretation
	/// - Positive: Company generates excess cash
	/// - Negative: Company consumes cash after investments
	///
	/// - Note: Optional—only present if a ``CashFlowStatement`` was provided.
	public let freeCashFlow: T?

	/// Net change in cash for the period.
	///
	/// Sum of operating, investing, and financing cash flows. Should equal
	/// the change in the cash balance on the balance sheet.
	///
	/// - Note: Optional—only present if a ``CashFlowStatement`` was provided.
	public let netCashFlow: T?

	// MARK: - Profitability Ratios

	/// Return on Assets (ROA).
	///
	/// Calculated as `netIncome / totalAssets`. Measures how efficiently
	/// the company uses its assets to generate profit.
	///
	/// ## Formula
	/// ```
	/// ROA = Net Income / Total Assets
	/// ```
	///
	/// ## Interpretation
	/// - Higher is better
	/// - Typical range: 5%-20% depending on industry
	/// - Compare to industry peers and historical performance
	///
	/// ## SeeAlso
	/// - ``returnOnAssets(incomeStatement:balanceSheet:)``
	public let roa: T

	/// Return on Equity (ROE).
	///
	/// Calculated as `netIncome / totalEquity`. Measures return generated
	/// on shareholders' equity. One of the most important profitability metrics.
	///
	/// ## Formula
	/// ```
	/// ROE = Net Income / Total Equity
	/// ```
	///
	/// ## Interpretation
	/// - Higher is better
	/// - Typical range: 10%-25% depending on industry
	/// - Can be decomposed using DuPont Analysis
	///
	/// ## SeeAlso
	/// - ``returnOnEquity(incomeStatement:balanceSheet:)``
	/// - ``dupontAnalysis(incomeStatement:balanceSheet:)``
	public let roe: T

	// MARK: - Liquidity Ratios

	/// Current ratio.
	///
	/// Calculated as `currentAssets / currentLiabilities`. Measures ability
	/// to pay short-term obligations with short-term assets.
	///
	/// ## Interpretation
	/// - > 1.0: Can cover current liabilities
	/// - < 1.0: May face liquidity challenges
	/// - Typical healthy range: 1.5 - 3.0
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/currentRatio``
	public let currentRatio: T

	/// Quick ratio (acid-test ratio).
	///
	/// Calculated as `(currentAssets - inventory) / currentLiabilities`.
	/// More conservative than current ratio, excluding inventory.
	///
	/// ## Interpretation
	/// - > 1.0: Good liquidity without relying on inventory sales
	/// - < 1.0: May struggle to meet short-term obligations
	/// - Typical healthy range: 1.0 - 2.0
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/quickRatio``
	public let quickRatio: T

	/// Cash ratio.
	///
	/// Calculated as `cash / currentLiabilities`. Most conservative
	/// liquidity measure, using only cash and cash equivalents.
	///
	/// ## Interpretation
	/// - Higher is better for liquidity
	/// - But too high may indicate inefficient cash use
	/// - Typical range: 0.2 - 0.5
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/cashRatio``
	public let cashRatio: T

	// MARK: - Leverage Ratios

	/// Debt-to-equity ratio.
	///
	/// Calculated as `totalDebt / totalEquity`. Measures financial leverage
	/// and capital structure. Higher values indicate more debt financing.
	///
	/// ## Interpretation
	/// - < 1.0: More equity than debt (conservative)
	/// - > 1.0: More debt than equity (aggressive)
	/// - Typical range: 0.3 - 2.0 depending on industry
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/debtToEquity``
	public let debtToEquityRatio: T

	/// Debt-to-assets ratio.
	///
	/// Calculated as `totalDebt / totalAssets`. Measures percentage of
	/// assets financed by debt.
	///
	/// ## Interpretation
	/// - < 0.5: Less than half of assets are debt-financed
	/// - > 0.5: More than half of assets are debt-financed
	/// - Higher values indicate greater financial risk
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/debtRatio``
	public let debtToAssetsRatio: T

	/// Equity ratio.
	///
	/// Calculated as `totalEquity / totalAssets`. Measures percentage of
	/// assets financed by shareholders' equity. Complement of debt ratio.
	///
	/// ## Interpretation
	/// - Higher is more conservative (less financial risk)
	/// - Typical range: 0.3 - 0.7
	/// - Should sum with debt-to-assets to approximately 1.0
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/equityRatio``
	public let equityRatio: T

	// MARK: - Efficiency Ratios (Optional)

	/// Asset turnover ratio.
	///
	/// Calculated as `revenue / totalAssets`. Measures how efficiently
	/// the company uses assets to generate revenue.
	///
	/// ## Interpretation
	/// - Higher is better (more revenue per dollar of assets)
	/// - Typical range: 0.5 - 2.0 depending on industry
	/// - Capital-intensive industries have lower ratios
	///
	/// - Note: Optional—calculated when data is available.
	///
	/// ## SeeAlso
	/// - ``assetTurnover(incomeStatement:balanceSheet:)``
	public let assetTurnoverRatio: T?

	/// Inventory turnover ratio.
	///
	/// Calculated as `COGS / averageInventory`. Measures how quickly
	/// inventory is sold and replaced.
	///
	/// ## Interpretation
	/// - Higher is generally better (faster inventory turnover)
	/// - Typical range: 4 - 12 times per year depending on industry
	/// - Too high may indicate stockouts; too low may indicate excess inventory
	///
	/// - Note: Optional—only available if inventory data exists.
	///
	/// ## SeeAlso
	/// - ``inventoryTurnover(incomeStatement:balanceSheet:)``
	public let inventoryTurnoverRatio: T?

	/// Receivables turnover ratio.
	///
	/// Calculated as `revenue / averageReceivables`. Measures how quickly
	/// the company collects payment from customers.
	///
	/// ## Interpretation
	/// - Higher is better (faster collection)
	/// - Typical range: 6 - 12 times per year depending on industry
	/// - Can be converted to days sales outstanding (DSO)
	///
	/// - Note: Optional—only available if receivables data exists.
	///
	/// ## SeeAlso
	/// - ``receivablesTurnover(incomeStatement:balanceSheet:)``
	public let receivablesTurnoverRatio: T?

	// MARK: - Credit Metrics

	/// Debt-to-EBITDA ratio.
	///
	/// Calculated as `totalDebt / EBITDA`. Measures leverage relative to
	/// earnings. Commonly used by lenders to assess creditworthiness.
	///
	/// ## Interpretation
	/// - < 3.0: Low leverage (good)
	/// - 3.0 - 5.0: Moderate leverage
	/// - > 5.0: High leverage (risky)
	///
	/// ## Note
	/// Used by rating agencies and lenders for credit analysis.
	public let debtToEBITDARatio: T

	/// Net debt-to-EBITDA ratio.
	///
	/// Calculated as `(debt - cash) / EBITDA`. Similar to debt-to-EBITDA
	/// but accounts for cash that could be used to pay down debt.
	///
	/// ## Interpretation
	/// - Lower values indicate stronger credit position
	/// - Can be negative if company has net cash position
	/// - More precise than gross debt-to-EBITDA
	public let netDebtToEBITDARatio: T

	/// Interest coverage ratio.
	///
	/// Calculated as `EBIT / interestExpense`. Measures ability to pay
	/// interest obligations from operating income.
	///
	/// ## Interpretation
	/// - < 1.5: High default risk
	/// - 1.5 - 2.5: Moderate risk
	/// - > 2.5: Comfortable coverage
	///
	/// - Note: Optional—only available if interest expense exists.
	///
	/// ## SeeAlso
	/// - ``interestCoverage(incomeStatement:)``
	public let interestCoverageRatio: T?

	// MARK: - Valuation Metrics (Optional)

	/// Market capitalization.
	///
	/// Calculated as `sharePrice × sharesOutstanding`. Total market value
	/// of all outstanding shares.
	///
	/// - Note: Optional—requires market data (stock price and shares outstanding).
	///
	/// ## SeeAlso
	/// - ``marketCapitalization(marketPrice:sharesOutstanding:)``
	public let marketCap: T?

	/// Enterprise value (EV).
	///
	/// Calculated as `marketCap + debt - cash`. Total value of the company
	/// including debt, often used for acquisition valuation.
	///
	/// - Note: Optional—requires market data.
	///
	/// ## SeeAlso
	/// - ``enterpriseValue(balanceSheet:marketPrice:sharesOutstanding:)``
	public let ev: T?

	/// Price-to-earnings (P/E) ratio.
	///
	/// Calculated as `marketCap / netIncome` or `sharePrice / EPS`.
	/// Measures how much investors pay per dollar of earnings.
	///
	/// ## Interpretation
	/// - Higher P/E suggests higher growth expectations
	/// - Typical range: 10 - 30 depending on industry
	/// - Compare to industry peers and historical average
	///
	/// - Note: Optional—requires market data. Only reported if positive.
	///
	/// ## SeeAlso
	/// - ``priceToEarnings(incomeStatement:marketPrice:sharesOutstanding:diluted:dilutedShares:)``
	public let peRatio: T?

	/// Price-to-book (P/B) ratio.
	///
	/// Calculated as `marketCap / totalEquity`. Measures market value
	/// relative to book value of equity.
	///
	/// ## Interpretation
	/// - < 1.0: Trading below book value
	/// - > 1.0: Market values company above accounting equity
	/// - Typical range: 1.0 - 5.0 depending on industry
	///
	/// - Note: Optional—requires market data.
	///
	/// ## SeeAlso
	/// - ``priceToBook(balanceSheet:marketPrice:sharesOutstanding:)``
	public let pbRatio: T?

	/// Price-to-sales (P/S) ratio.
	///
	/// Calculated as `marketCap / revenue`. Measures market value
	/// relative to revenue, useful for companies with low or negative earnings.
	///
	/// ## Interpretation
	/// - Lower is generally better (cheaper valuation)
	/// - Typical range: 0.5 - 5.0 depending on industry
	/// - Growth companies often have higher P/S ratios
	///
	/// - Note: Optional—requires market data.
	///
	/// ## SeeAlso
	/// - ``priceToSales(incomeStatement:marketPrice:sharesOutstanding:)``
	public let psRatio: T?

	/// Enterprise value-to-EBITDA ratio.
	///
	/// Calculated as `EV / EBITDA`. Common valuation metric that accounts
	/// for capital structure. Often used in M&A and comparable company analysis.
	///
	/// ## Interpretation
	/// - Lower suggests cheaper valuation
	/// - Typical range: 5 - 15 depending on industry
	/// - Compare to industry peers
	///
	/// - Note: Optional—requires market data.
	///
	/// ## SeeAlso
	/// - ``evToEbitda(incomeStatement:balanceSheet:marketPrice:sharesOutstanding:)``
	public let evToEBITDARatio: T?

	// MARK: - Operational Metrics (Optional)

	/// Company-specific operational metrics.
	///
	/// Optional custom metrics specific to the business model or industry,
	/// such as customer acquisition cost, monthly recurring revenue, or
	/// same-store sales growth.
	///
	/// - Note: Optional—only present if provided during initialization.
	///
	/// ## Example Usage
	/// ```swift
	/// struct SaaSMetrics<T: Real>: OperationalMetrics {
	///     let mrr: T
	///     let churnRate: T
	///     let ltv: T
	///     let cac: T
	/// }
	///
	/// let summary = try FinancialPeriodSummary(
	///     // ... standard parameters ...
	///     operationalMetrics: saasMetrics
	/// )
	/// ```
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
///
/// Provides stock price and shares outstanding data required for computing
/// valuation metrics like market cap, P/E ratio, and enterprise value.
///
/// ## Usage Example
/// ```swift
/// let periods = [Period.quarter(year: 2025, quarter: 1)]
/// let priceData = TimeSeries(periods: periods, values: [150.0])
/// let sharesData = TimeSeries(periods: periods, values: [1_000_000_000.0])
///
/// let marketData = MarketData(
///     price: priceData,
///     sharesOutstanding: sharesData
/// )
///
/// let summary = try FinancialPeriodSummary(
///     entity: entity,
///     period: periods[0],
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketData: marketData
/// )
///
/// // Now valuation metrics are available
/// print("Market Cap: $\(summary.marketCap ?? 0)")
/// print("P/E Ratio: \(summary.peRatio ?? 0)")
/// ```
///
/// ## SeeAlso
/// - ``FinancialPeriodSummary``
/// - ``marketCapitalization(marketPrice:sharesOutstanding:)``
/// - ``enterpriseValue(balanceSheet:marketPrice:sharesOutstanding:)``
public struct MarketData<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// Stock price time series.
	///
	/// The market price per share over time. Used to calculate market cap
	/// and valuation ratios.
	public let price: TimeSeries<T>

	/// Shares outstanding time series.
	///
	/// The number of shares outstanding over time. Combined with price
	/// to calculate market capitalization and per-share metrics.
	public let sharesOutstanding: TimeSeries<T>

	/// Creates market data with price and shares outstanding time series.
	///
	/// - Parameters:
	///   - price: Time series of stock prices
	///   - sharesOutstanding: Time series of shares outstanding
	///
	/// ## Usage Example
	/// ```swift
	/// let quarters = [
	///     Period.quarter(year: 2024, quarter: 1),
	///     Period.quarter(year: 2024, quarter: 2),
	///     Period.quarter(year: 2024, quarter: 3),
	///     Period.quarter(year: 2024, quarter: 4)
	/// ]
	///
	/// let prices = TimeSeries(periods: quarters, values: [145.0, 150.0, 155.0, 160.0])
	/// let shares = TimeSeries(periods: quarters, values: [1_000_000_000.0] * 4)
	///
	/// let marketData = MarketData(price: prices, sharesOutstanding: shares)
	/// ```
	public init(price: TimeSeries<T>, sharesOutstanding: TimeSeries<T>) {
		self.price = price
		self.sharesOutstanding = sharesOutstanding
	}
}
