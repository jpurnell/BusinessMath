import Foundation
import Numerics

// MARK: - Valuation Metrics

/// Market-based valuation ratios that relate market price to financial metrics.
///
/// These ratios require external market data (stock price, shares outstanding) and are used
/// to compare companies, identify over/undervaluation, and make investment decisions.

// MARK: - Price Multiples

/// Price-to-Earnings (P/E) Ratio - market valuation relative to earnings.
///
/// The P/E ratio measures how much investors are willing to pay per dollar of earnings.
/// Higher P/E ratios typically indicate growth expectations or market optimism.
///
/// ## Formula
///
/// ```
/// P/E Ratio = Market Price per Share / Earnings per Share
/// EPS = Net Income / Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **High P/E (>25)**: Growth stock, high expectations, potentially overvalued
/// - **Medium P/E (15-25)**: Fairly valued, market average
/// - **Low P/E (<15)**: Value stock, low expectations, potentially undervalued
/// - **Negative P/E**: Company is unprofitable (ratio not meaningful)
///
/// ## Industry Variation
///
/// - **Technology**: Often 30-50x (high growth expectations)
/// - **Utilities**: Typically 12-18x (stable, mature)
/// - **Banks**: Usually 10-15x (cyclical)
///
/// ## Limitations
///
/// - Meaningless for unprofitable companies
/// - Can be distorted by one-time charges or gains
/// - Doesn't account for growth rate (use PEG ratio for growth-adjusted)
/// - Affected by accounting policies
///
/// ## Example
///
/// ```swift
/// let pe = priceToEarnings(
///     incomeStatement: incomeStatement,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/E Ratio: \(pe[q1]!)")  // e.g., "P/E Ratio: 18.5"
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of P/E ratios
public func priceToEarnings<T: Real>(
	incomeStatement: IncomeStatement<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let netIncome = incomeStatement.netIncome
	let sharesTimeSeries = TimeSeries(
		periods: netIncome.periods,
		values: netIncome.periods.map { _ in sharesOutstanding }
	)
	let eps = netIncome / sharesTimeSeries
	return marketPrice / eps
}

/// Price-to-Book (P/B) Ratio - market value relative to book value.
///
/// The P/B ratio compares a company's market capitalization to its book value (shareholders' equity).
/// Used to identify value stocks and assess whether a stock is trading above or below its accounting value.
///
/// ## Formula
///
/// ```
/// P/B Ratio = Market Price per Share / Book Value per Share
/// Book Value per Share = Shareholders' Equity / Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **P/B > 3**: Premium valuation (strong brand, high ROIC)
/// - **P/B = 1-3**: Fairly valued
/// - **P/B < 1**: Trading below book value (value opportunity or distressed)
/// - **P/B < 0.5**: Deep value or potential bankruptcy
///
/// ## When to Use
///
/// - **Best for**: Banks, insurance, manufacturing (asset-heavy businesses)
/// - **Less useful for**: Tech, services (asset-light, intangible value)
/// - **Value investing**: Identify stocks trading below book value
///
/// ## Limitations
///
/// - Book value based on historical cost (not market value)
/// - Doesn't capture intangible assets (brand, patents, goodwill)
/// - Affected by accounting policies (depreciation methods)
/// - Can be negative if company has negative equity
///
/// ## Example
///
/// ```swift
/// let pb = priceToBook(
///     balanceSheet: balanceSheet,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// if pb[q1]! < 1.0 {
///     print("Stock trading below book value - potential value opportunity")
/// }
/// ```
///
/// - Parameters:
///   - balanceSheet: The company's balance sheet
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of P/B ratios
public func priceToBook<T: Real>(
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let bookValue = balanceSheet.totalEquity
	let sharesTimeSeries = TimeSeries(
		periods: bookValue.periods,
		values: bookValue.periods.map { _ in sharesOutstanding }
	)
	let bookValuePerShare = bookValue / sharesTimeSeries
	return marketPrice / bookValuePerShare
}

/// Price-to-Sales (P/S) Ratio - market capitalization relative to revenue.
///
/// The P/S ratio measures how much investors are willing to pay per dollar of revenue.
/// Useful for valuing unprofitable companies or comparing companies with different margins.
///
/// ## Formula
///
/// ```
/// P/S Ratio = Market Capitalization / Revenue
/// Market Cap = Stock Price × Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **P/S > 10**: Very expensive (high-growth SaaS, tech)
/// - **P/S = 2-10**: Normal for growth companies
/// - **P/S < 2**: Cheap (mature or struggling companies)
/// - **P/S < 0.5**: Very cheap (value opportunity or trouble)
///
/// ## When to Use
///
/// - **Unprofitable companies**: P/E is meaningless when earnings are negative
/// - **Early-stage growth**: Revenue exists but no profits yet
/// - **Revenue quality**: Compare margins across companies in same industry
///
/// ## Advantages
///
/// - Always positive (revenue rarely negative)
/// - Less volatile than earnings
/// - Harder to manipulate than earnings
/// - Good for comparing similar companies
///
/// ## Limitations
///
/// - Ignores profitability (high revenue doesn't mean profitable)
/// - Doesn't account for different business models
/// - Industry-specific (SaaS has higher P/S than retail)
///
/// ## Example
///
/// ```swift
/// let ps = priceToSales(
///     incomeStatement: incomeStatement,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/S Ratio: \(ps[q1]!)")  // e.g., "P/S Ratio: 5.2"
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of P/S ratios
public func priceToSales<T: Real>(
	incomeStatement: IncomeStatement<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let totalRevenue = incomeStatement.totalRevenue
	let sharesTimeSeries = TimeSeries(
		periods: marketPrice.periods,
		values: marketPrice.periods.map { _ in sharesOutstanding }
	)
	let marketCap = marketPrice * sharesTimeSeries
	return marketCap / totalRevenue
}

// MARK: - Enterprise Value Multiples

/// Enterprise Value (EV) - total value of the company to all stakeholders.
///
/// Enterprise value represents what it would cost to acquire the entire company, accounting for
/// both equity value and debt, minus cash that could be used to pay down debt.
///
/// ## Formula
///
/// ```
/// Enterprise Value = Market Capitalization + Total Debt - Cash
/// Market Cap = Stock Price × Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **EV > Market Cap**: Company has net debt (debt > cash)
/// - **EV = Market Cap**: Company has no net debt (debt = cash)
/// - **EV < Market Cap**: Company has net cash (cash > debt)
///
/// ## Why It Matters
///
/// EV is capital-structure-neutral, making it better than market cap for:
/// - Comparing companies with different debt levels
/// - M&A analysis (represents true acquisition cost)
/// - Valuation multiples (EV/EBITDA, EV/Sales)
///
/// ## Components
///
/// - **Market Cap**: Value to equity holders
/// - **+ Total Debt**: Acquirer must repay or assume debt
/// - **- Cash**: Can be used to pay down debt immediately
///
/// ## Example
///
/// ```swift
/// let ev = enterpriseValue(
///     balanceSheet: balanceSheet,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("Enterprise Value: $\(ev[q1]! / 1_000_000)M")
/// ```
///
/// - Parameters:
///   - balanceSheet: The company's balance sheet
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of enterprise values
public func enterpriseValue<T: Real>(
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let sharesTimeSeries = TimeSeries(
		periods: marketPrice.periods,
		values: marketPrice.periods.map { _ in sharesOutstanding }
	)
	let marketCap = marketPrice * sharesTimeSeries

	// Find interest-bearing debt (excludes operating liabilities like accounts payable)
	let debtAccounts = balanceSheet.liabilityAccounts.filter {
		$0.name.localizedCaseInsensitiveContains("Debt") ||
		$0.name.localizedCaseInsensitiveContains("Borrowing") ||
		$0.name.localizedCaseInsensitiveContains("Bond") ||
		$0.name.localizedCaseInsensitiveContains("Note") ||
		($0.metadata?.category == "Long-Term" && !$0.name.localizedCaseInsensitiveContains("Deferred"))
	}

	let debt: TimeSeries<T>
	if !debtAccounts.isEmpty {
		// Manually aggregate debt accounts by summing their time series
		debt = debtAccounts.dropFirst().reduce(debtAccounts[0].timeSeries) { $0 + $1.timeSeries }
	} else {
		let zero = T(0)
		let periods = marketCap.periods
		let zeroValues = periods.map { _ in zero }
		debt = TimeSeries(periods: periods, values: zeroValues)
	}

	// Find cash and cash equivalents
	let cashAccounts = balanceSheet.assetAccounts.filter {
		$0.metadata?.category == "Current" && (
			$0.name.localizedCaseInsensitiveContains("Cash") ||
			$0.name.localizedCaseInsensitiveContains("Cash Equivalent") ||
			$0.name.localizedCaseInsensitiveContains("Marketable Securities")
		)
	}

	let cash: TimeSeries<T>
	if !cashAccounts.isEmpty {
		// Manually aggregate cash accounts by summing their time series
		cash = cashAccounts.dropFirst().reduce(cashAccounts[0].timeSeries) { $0 + $1.timeSeries }
	} else {
		let zero = T(0)
		let periods = marketCap.periods
		let zeroValues = periods.map { _ in zero }
		cash = TimeSeries(periods: periods, values: zeroValues)
	}

	// EV = Market Cap + Debt - Cash
	return marketCap + debt - cash
}

/// EV/EBITDA Multiple - enterprise value to earnings before interest, taxes, depreciation, and amortization.
///
/// EV/EBITDA is considered one of the best valuation metrics because it's capital-structure-neutral
/// and excludes non-cash charges, allowing clean comparison across companies with different
/// debt levels and accounting policies.
///
/// ## Formula
///
/// ```
/// EV/EBITDA = Enterprise Value / EBITDA
/// EBITDA = Operating Income + Depreciation + Amortization
/// ```
///
/// ## Interpretation
///
/// - **EV/EBITDA > 15**: Expensive (high growth or market leader)
/// - **EV/EBITDA = 8-15**: Fair value (typical range)
/// - **EV/EBITDA < 8**: Cheap (value opportunity or challenged business)
/// - **EV/EBITDA < 5**: Very cheap (distressed or turnaround)
///
/// ## Why Superior to P/E
///
/// - **Capital-structure-neutral**: Unaffected by leverage
/// - **Pre-tax**: Ignores different tax situations
/// - **Excludes non-cash**: Focuses on cash generation
/// - **Better for M&A**: Represents cost to acquire cash flow
///
/// ## Industry Benchmarks
///
/// - **Technology/SaaS**: 15-25x
/// - **Consumer goods**: 10-15x
/// - **Manufacturing**: 8-12x
/// - **Mature/cyclical**: 5-8x
///
/// ## Limitations
///
/// - Ignores capex requirements (use EV/FCF for capex-intensive)
/// - EBITDA can be manipulated
/// - Doesn't work for financial companies
///
/// ## Example
///
/// ```swift
/// let evEbitda = evToEbitda(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("EV/EBITDA: \(evEbitda[q1]!)x")  // e.g., "EV/EBITDA: 12.3x"
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - balanceSheet: The company's balance sheet
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of EV/EBITDA multiples
public func evToEbitda<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let ev = enterpriseValue(
		balanceSheet: balanceSheet,
		marketPrice: marketPrice,
		sharesOutstanding: sharesOutstanding
	)

	// EBITDA = Operating Income + D&A
	let operatingIncome = incomeStatement.operatingIncome

	// Find depreciation and amortization
	let daAccounts = incomeStatement.expenseAccounts.filter {
		$0.metadata?.category == "Non-Cash" &&
		($0.name.localizedCaseInsensitiveContains("Depreciation") ||
		 $0.name.localizedCaseInsensitiveContains("Amortization"))
	}

	let da: TimeSeries<T>
	if !daAccounts.isEmpty {
		// Manually aggregate D&A accounts by summing their time series
		da = daAccounts.dropFirst().reduce(daAccounts[0].timeSeries) { $0 + $1.timeSeries }
	} else {
		let zero = T(0)
		let periods = operatingIncome.periods
		let zeroValues = periods.map { _ in zero }
		da = TimeSeries(periods: periods, values: zeroValues)
	}

	let ebitda = operatingIncome + da
	return ev / ebitda
}

/// EV/Sales Multiple - enterprise value to revenue.
///
/// Similar to P/S but uses enterprise value instead of market cap, making it capital-structure-neutral.
/// Useful for comparing companies with different debt levels or valuing unprofitable companies.
///
/// ## Formula
///
/// ```
/// EV/Sales = Enterprise Value / Revenue
/// ```
///
/// ## Interpretation
///
/// - **EV/Sales > 5**: Premium valuation (high margins, growth)
/// - **EV/Sales = 2-5**: Normal for growth companies
/// - **EV/Sales < 2**: Cheap or low-margin business
/// - **EV/Sales < 0.5**: Very cheap (distressed or mature)
///
/// ## Advantages over P/S
///
/// - Capital-structure-neutral (accounts for debt)
/// - Better for M&A comparisons
/// - More accurate for leveraged companies
///
/// ## When to Use
///
/// - Unprofitable companies (can't use EV/EBITDA)
/// - Comparing companies with different leverage
/// - M&A analysis
/// - High-growth tech companies
///
/// ## Example
///
/// ```swift
/// let evSales = evToSales(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: stockPriceTimeSeries,
///     sharesOutstanding: 1_000_000
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("EV/Sales: \(evSales[q1]!)x")  // e.g., "EV/Sales: 3.2x"
/// ```
///
/// - Parameters:
///   - incomeStatement: The company's income statement
///   - balanceSheet: The company's balance sheet
///   - marketPrice: Time series of market price per share
///   - sharesOutstanding: Number of shares outstanding (assumed constant)
/// - Returns: Time series of EV/Sales multiples
public func evToSales<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: T
) -> TimeSeries<T> {
	let ev = enterpriseValue(
		balanceSheet: balanceSheet,
		marketPrice: marketPrice,
		sharesOutstanding: sharesOutstanding
	)
	let totalRevenue = incomeStatement.totalRevenue
	return ev / totalRevenue
}
