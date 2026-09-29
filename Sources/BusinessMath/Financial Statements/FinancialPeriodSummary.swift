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
/// let cashFlowStatement = try CashFlowStatement<Double>.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
/// let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc")
/// let q1 = Period.quarter(year: 2025, quarter: 1)
///
/// let prices = TimeSeries(periods: Period.documentationQuarters, values: [145.0, 150, 155, 160])
/// let shares = TimeSeries(periods: Period.documentationQuarters, values: Array(repeating: 1_000_000_000.0, count: 4))
/// let marketData = MarketData(price: prices, sharesOutstanding: shares)
///
/// let operationalMetrics = OperationalMetrics(
///     entity: entity,
///     period: q1,
///     metrics: ["mrr": 250_000.0, "churnRate": 0.02]
/// )
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
///
/// // Ratios whose divisor can legitimately be zero are optional. A company with no
/// // equity has no debt-to-equity ratio — that is not a ratio of zero, which would
/// // read as "unlevered" for the most levered balance sheet there is.
/// if let leverage = summary.debtToEquityRatio {
///     print("Debt/Equity: \(leverage)x")
/// } else {
///     print("Debt/Equity: not applicable (no equity)")
/// }
/// ```
///
/// ## Periods the statements do not cover
///
/// The initialiser ``init(entity:period:incomeStatement:balanceSheet:cashFlowStatement:marketData:operationalMetrics:)``
/// **throws** for a period its statements have no figures at. It does not return a summary
/// of zeros: a zero revenue, a zero asset base and a zero equity balance are readings, and
/// downstream they are readings that rank and threshold.
///
/// ## Source compatibility
///
/// Widening ``currentRatio``, ``quickRatio``, ``cashRatio``, ``debtToEquityRatio``,
/// ``debtToAssetsRatio`` and ``equityRatio`` from `T` to `T?` is **source-breaking**, and it
/// is taken here because the window for it is open and closing. The repository is on an
/// active pre-release line, and SPM excludes pre-releases from `from:` version ranges, so a
/// break reaches only callers who name an alpha exactly. Once 3.0.0 goes final the same
/// change would reach every consumer on `swift package update`, and the six fields would
/// have to keep reporting `0` for a ratio that does not exist.
///
/// Every existing call site already spelled the initialiser `try`, so making it actually
/// throw is not a break at all — only a promise the signature had been making since it was
/// written.
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
	///
	/// ## No Revenue
	///
	/// `nan` when revenue is zero: there is no denominator, so there is no margin.
	/// Zero would read as an exact breakeven, which is a measurement, not an absence.
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
	///
	/// ## No Revenue
	///
	/// `nan` when revenue is zero: there is no denominator, so there is no margin.
	/// Zero would read as an exact breakeven, which is a measurement, not an absence.
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
	///
	/// ## No Revenue
	///
	/// `nan` when revenue is zero: there is no denominator, so there is no margin.
	/// Zero would read as an exact breakeven, which is a measurement, not an absence.
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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is **not defined**, not that it is zero and not that the data
	/// is missing. ``BalanceSheet/currentRatio`` omits periods with no current liabilities,
	/// because there is nothing to cover — so a debt-free company reports `nil` here for a
	/// period its balance sheet fully covers. Recording that as `0` said the strongest
	/// short-term position was the weakest, and failed every minimum-coverage threshold.
	///
	/// A period the statements do not cover never reaches this property: the initialiser
	/// throws instead.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/currentRatio``
	public let currentRatio: T?

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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is not defined — no current liabilities, so nothing to cover.
	/// A period the statements do not cover throws from the initialiser instead.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/quickRatio``
	public let quickRatio: T?

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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is not defined — no current liabilities, so nothing to cover.
	/// A period the statements do not cover throws from the initialiser instead.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/cashRatio``
	public let cashRatio: T?

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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is not defined. ``BalanceSheet/debtToEquity`` omits periods
	/// with no equity, where leverage is unbounded rather than zero — a company financed
	/// entirely by debt is the last one that should read as unlevered, which is what the
	/// `0` recorded here previously said.
	///
	/// A period the statements do not cover throws from the initialiser instead.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/debtToEquity``
	public let debtToEquityRatio: T?

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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is not defined — no assets, so no composition to take a
	/// proportion of. A period the statements do not cover throws from the initialiser.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/debtRatio``
	public let debtToAssetsRatio: T?

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
	/// ## Undefined Periods
	///
	/// `nil` means the ratio is not defined — no assets, so no composition to take a
	/// proportion of. A period the statements do not cover throws from the initialiser.
	///
	/// ## SeeAlso
	/// - ``BalanceSheet/equityRatio``
	public let equityRatio: T?

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
	///
	/// ## No EBITDA
	///
	/// `nan` when EBITDA is zero. A leverage of `0.0x` reads as the strongest credit
	/// on every lender's scale, and a company with no earnings is the weakest.
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
	///
	/// ## No EBITDA
	///
	/// `nan` when EBITDA is zero. A leverage of `0.0x` reads as the strongest credit
	/// on every lender's scale, and a company with no earnings is the weakest.
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
	/// let entity = Entity.documentationFixture
	/// let q1 = Period.documentationQuarters[0]
	/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
	/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
	///
	/// // Industry metrics travel as a named dictionary, not a bespoke type
	/// let saasMetrics = OperationalMetrics(
	///     entity: entity,
	///     period: q1,
	///     metrics: ["mrr": 250_000.0, "churnRate": 0.02, "ltv": 12_500.0, "cac": 1_800.0]
	/// )
	///
	/// let summary = try FinancialPeriodSummary(
	///     entity: entity,
	///     period: q1,
	///     incomeStatement: incomeStatement,
	///     balanceSheet: balanceSheet,
	///     operationalMetrics: saasMetrics
	/// )
	/// ```
	public let operationalMetrics: OperationalMetrics<T>?

	/// Create a comprehensive financial summary for a period.
	///
	/// Every figure in the summary is read at `period`. A period the supplied statements do
	/// not cover has no figures, so no summary is built for it — see
	/// ``FinancialPeriodSummary`` for why a summary of zeros was worse than no summary.
	///
	/// - Parameters:
	///   - entity: The company this summary describes.
	///   - period: The period to summarise. Must be covered by both statements.
	///   - incomeStatement: Income statement covering `period`.
	///   - balanceSheet: Balance sheet covering `period`.
	///   - cashFlowStatement: Optional cash flow statement; its five figures stay `nil`
	///     when it is absent, and when it is present but does not cover `period`.
	///   - marketData: Optional price and share-count series for the valuation metrics.
	///   - operationalMetrics: Optional company-specific metrics, stored as supplied.
	///
	/// - Throws: ``BusinessMathError/missingData(account:period:)`` when either statement
	///   has no figure for `period`. The error names the first account that was missing.
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
		//
		// Each of these was `?? T(0)`, which answered a lookup outside the statements with a
		// measured zero. See `requiredFigure` below for what the caller was being told.
		self.revenue = try requiredFigure(incomeStatement.totalRevenue, at: period, account: "totalRevenue")
		self.grossProfit = try requiredFigure(incomeStatement.grossProfit, at: period, account: "grossProfit")
		self.operatingIncome = try requiredFigure(incomeStatement.operatingIncome, at: period, account: "operatingIncome")
		self.ebitda = try requiredFigure(incomeStatement.ebitda, at: period, account: "ebitda")
		self.netIncome = try requiredFigure(incomeStatement.netIncome, at: period, account: "netIncome")

		// Margins
		//
		// Revenue is the denominator of all three, so a period with no revenue has no margin.
		// The caller would otherwise have been told `0` — "this business ran at exactly
		// breakeven" — which a peer table ranks mid-pack rather than skips. Contract §3.1:
		// a value that cannot be computed and has nowhere else to go is `nan`.
		//
		// The test is `== T(0)` rather than the `!= T(0)` it replaced because every
		// comparison against `nan` is false. `!=` answered *true* for a contaminated
		// revenue and divided through, which happened to be right; `==` answers *false* for
		// it and divides through for the same reason, which is right on purpose.
		if revenue == T(0) {
			self.grossMargin = T.nan
			self.operatingMargin = T.nan
			self.netMargin = T.nan
		} else {
			self.grossMargin = grossProfit / revenue
			self.operatingMargin = operatingIncome / revenue
			self.netMargin = netIncome / revenue
		}

		// Balance Sheet
		self.totalAssets = try requiredFigure(balanceSheet.totalAssets, at: period, account: "totalAssets")
		self.currentAssets = try requiredFigure(balanceSheet.currentAssets, at: period, account: "currentAssets")
		self.totalLiabilities = try requiredFigure(balanceSheet.totalLiabilities, at: period, account: "totalLiabilities")
		self.currentLiabilities = try requiredFigure(balanceSheet.currentLiabilities, at: period, account: "currentLiabilities")
		self.totalEquity = try requiredFigure(balanceSheet.totalEquity, at: period, account: "totalEquity")
		self.workingCapital = currentAssets - currentLiabilities
		self.cash = try requiredFigure(balanceSheet.cashAndEquivalents, at: period, account: "cashAndEquivalents")
		self.debt = try requiredFigure(balanceSheet.interestBearingDebt, at: period, account: "interestBearingDebt")
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
		//
		// Both series are `netIncome / averageTimeSeries(balance)`, and `/` on a `TimeSeries`
		// keeps the periods present in both operands — it does not drop a zero divisor, which
		// comes back as an infinity and is a legitimate reading (contract §3.6). So `nil` here
		// means the period is uncovered, the same condition the roll-ups above throw on, and
		// the same answer is owed: a return on assets of `0` says the assets earned nothing.
		let roaSeries = returnOnAssets(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		let roeSeries = returnOnEquity(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		self.roa = try requiredFigure(roaSeries, at: period, account: "returnOnAssets")
		self.roe = try requiredFigure(roeSeries, at: period, account: "returnOnEquity")

		// Liquidity and Leverage Ratios
		//
		// These six are the one place in this initialiser where `nil` is an *answer*.
		// `BalanceSheet.ratio(_:over:)` deliberately omits every period whose divisor is
		// exactly zero, so a company with no current liabilities has no current ratio, and a
		// company with no equity has no debt-to-equity ratio — at a period its balance sheet
		// fully covers. The caller would otherwise have been told `0`: no coverage at all for
		// the strongest short-term position on the books, and unlevered for the most levered.
		//
		// An uncovered period cannot reach here — the roll-ups above have already thrown —
		// so `nil` below carries exactly one meaning, which is why widening these six to `T?`
		// is not the blanket nil-to-throw that would have rejected the debt-free company.
		self.currentRatio = balanceSheet.currentRatio[period]
		self.quickRatio = balanceSheet.quickRatio[period]
		self.cashRatio = balanceSheet.cashRatio[period]
		self.debtToEquityRatio = balanceSheet.debtToEquity[period]
		self.debtToAssetsRatio = balanceSheet.debtRatio[period]
		self.equityRatio = balanceSheet.equityRatio[period]

		// Efficiency Ratios (optional - may not have required accounts)
		let assetTurnoverSeries = assetTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet)
		self.assetTurnoverRatio = assetTurnoverSeries[period]

		// silent: inventory turnover is optional — missing accounts yield nil
		if let invTurnoverSeries = try? inventoryTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet) {
			self.inventoryTurnoverRatio = invTurnoverSeries[period]
		} else {
			self.inventoryTurnoverRatio = nil
		}

		// silent: receivables turnover is optional — missing accounts yield nil
		if let recTurnoverSeries = try? receivablesTurnover(incomeStatement: incomeStatement, balanceSheet: balanceSheet) {
			self.receivablesTurnoverRatio = recTurnoverSeries[period]
		} else {
			self.receivablesTurnoverRatio = nil
		}

		// Credit Metrics
		//
		// Same shape as the margins, and the fallback pointed the same way: a company with no
		// EBITDA was reported at a leverage of `0.0x`, which every lender's scale reads as the
		// *best* credit in the book. It is the worst — there are no earnings to service the
		// debt with. `nan` says so; contract §3.1.
		if ebitda == T(0) {
			self.debtToEBITDARatio = T.nan
			self.netDebtToEBITDARatio = T.nan
		} else {
			self.debtToEBITDARatio = debt / ebitda
			self.netDebtToEBITDARatio = netDebt / ebitda
		}

		// silent: interest coverage is optional — missing interest expense yields nil
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

			// Only set P/E ratio if positive (negative P/E is meaningless)
			if let peValue = peSeries[period], peValue > T(0) {
				self.peRatio = peValue
			} else {
				self.peRatio = nil
			}

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

// MARK: - Required period lookups

/// Reads one statement figure at a period, or refuses to answer at all.
///
/// `TimeSeries` returns `nil` for a period it holds no value at, and the `?? T(0)` this
/// replaces answered that lookup with a **measured zero** — revenue of nothing, assets of
/// nothing, a balance sheet that balances because both sides are empty. None of those is a
/// missing reading; each is a reading, and downstream each one ranks and thresholds. The
/// measured case: `altmanZScore` scored a solvent, profitable company **0.00 — the distress
/// zone, in its own documentation** — for a quarter one step outside the statements it was
/// handed.
///
/// Without this guard the caller is told twenty figures, any number of them fabricated, with
/// nothing in the value, the type or the documentation to say which. Contract §3.7: narrow
/// the domain, do not fabricate the observation.
///
/// - Parameters:
///   - series: The statement series to read.
///   - period: The period being summarised.
///   - account: Name of the figure, for the error message.
/// - Returns: The value the series holds at `period`.
/// - Throws: ``BusinessMathError/missingData(account:period:)`` when there is none.
private func requiredFigure<T: Real & Sendable>(
	_ series: TimeSeries<T>,
	at period: Period,
	account: String
) throws -> T {
	guard let figure = series[period] else {
		throw BusinessMathError.missingData(account: account, period: period.label)
	}
	return figure
}

// MARK: - Market Data

/// Market data for valuation calculations.
///
/// Provides stock price and shares outstanding data required for computing
/// valuation metrics like market cap, P/E ratio, and enterprise value.
///
/// ## Usage Example
/// ```swift
/// let sharesOutstanding = TimeSeries(periods: Period.documentationQuarters, values: [1000, 1000, 1000, 1000])
/// let entity = Entity.documentationFixture
/// let balanceSheet = try BalanceSheet<Double>.documentationFixture
/// let incomeStatement = try IncomeStatement<Double>.documentationFixture
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
	/// let sharesOutstanding = TimeSeries(periods: Period.documentationQuarters, values: [1000, 1000, 1000, 1000])
	/// let periods = Period.documentationQuarters
	/// let quarters = [
	///     Period.quarter(year: 2024, quarter: 1),
	///     Period.quarter(year: 2024, quarter: 2),
	///     Period.quarter(year: 2024, quarter: 3),
	///     Period.quarter(year: 2024, quarter: 4)
	/// ]
	///
	/// let prices = TimeSeries(periods: quarters, values: [145.0, 150.0, 155.0, 160.0])
	/// let shares = TimeSeries(periods: quarters, values: Array(repeating: 1_000_000_000.0, count: 4))
	///
	/// let marketData = MarketData(price: prices, sharesOutstanding: shares)
	/// ```
	public init(price: TimeSeries<T>, sharesOutstanding: TimeSeries<T>) {
		self.price = price
		self.sharesOutstanding = sharesOutstanding
	}
}
