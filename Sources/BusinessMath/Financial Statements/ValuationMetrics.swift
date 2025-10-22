//
//  ValuationMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/21/25.
//

import Foundation
import Numerics

/// # Valuation Metrics
///
/// Market-based valuation ratios that combine financial statement data with market prices
/// to assess company valuation relative to fundamentals.
///
/// ## Ratio Categories
///
/// - **Price Ratios**: P/E, P/B, P/S - relate market price to financial metrics
/// - **Enterprise Value**: EV, EV/EBITDA, EV/Sales - capital-structure-neutral valuations
///
/// ## Usage
///
/// ```swift
/// let entity = Entity(name: "Acme Corp", ticker: "ACME")
/// let incomeStatement = try IncomeStatement(...)
/// let balanceSheet = try BalanceSheet(...)
///
/// // Market data (TimeSeries to support buybacks/issuances)
/// let marketPrice = TimeSeries(...) // Stock prices over time
/// let sharesOutstanding = TimeSeries(...) // Shares (changes with buybacks)
///
/// // Calculate P/E ratio
/// let pe = priceToEarnings(
///     incomeStatement: incomeStatement,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/E Ratio: \(pe[q1]!)x")
/// ```

// MARK: - Helper Functions

/// Market Capitalization - total market value of outstanding shares.
///
/// Market cap is the most basic measure of a company's size and value in the market.
/// It represents what the market believes the company is worth.
///
/// ## Formula
///
/// ```
/// Market Cap = Share Price x Shares Outstanding
/// ```
///
/// ## Size Classifications
///
/// - **Mega Cap**: > $200B
/// - **Large Cap**: $10B - $200B
/// - **Mid Cap**: $2B - $10B
/// - **Small Cap**: $300M - $2B
/// - **Micro Cap**: $50M - $300M
/// - **Nano Cap**: < $50M
///
/// ## Use Cases
///
/// - Company size classification
/// - Index eligibility (S&P 500, Russell 2000, etc.)
/// - Input for P/E, P/B, P/S ratios
/// - Input for enterprise value calculation
///
/// ## Example
///
/// ```swift
/// let price = TimeSeries(periods: quarters, values: [50.0, 52.0, 55.0, 58.0])
/// let shares = TimeSeries(periods: quarters, values: [100_000_000, 99_000_000, 98_000_000, 97_000_000])
///
/// let marketCap = marketCapitalization(
///     marketPrice: price,
///     sharesOutstanding: shares
/// )
/// ```
///
/// - Parameters:
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Number of shares outstanding (TimeSeries for buybacks/issuances)
/// - Returns: Time series of market capitalization values
public func marketCapitalization<T: Real>(
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	return marketPrice * sharesOutstanding
}

// MARK: - Price Ratios

/// Price-to-Earnings Ratio (P/E) - market price relative to earnings per share.
///
/// The P/E ratio is the most widely used valuation metric. It shows how much investors
/// are willing to pay for each dollar of earnings. Higher P/E suggests higher growth
/// expectations or lower risk.
///
/// ## Formula
///
/// ```
/// P/E = Market Price per Share / Earnings per Share
/// P/E = Market Capitalization / Net Income
///
/// EPS = Net Income / Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **< 10**: Undervalued or mature/declining business
/// - **10-20**: Fair value for stable companies
/// - **20-30**: Growth stock or strong competitive position
/// - **> 30**: High growth expectations or overvalued
/// - **Negative**: Company is unprofitable (P/E undefined)
///
/// ## Industry Variation
///
/// - **Tech/High Growth**: 30-50+ (growth expectations)
/// - **Financials**: 10-15 (mature, cyclical)
/// - **Utilities**: 15-20 (stable, regulated)
/// - **Consumer Staples**: 20-25 (defensive)
///
/// ## Diluted vs Basic
///
/// - **Basic P/E**: Uses basic shares outstanding
/// - **Diluted P/E**: Includes potential dilution from options, warrants, convertibles
///
/// ## Limitations
///
/// - Undefined for unprofitable companies
/// - Can be distorted by one-time items
/// - Doesn't account for growth (use PEG ratio)
/// - Affected by accounting policies
///
/// ## Example
///
/// ```swift
/// // Basic P/E
/// let pe = priceToEarnings(
///     incomeStatement: incomeStatement,
///     marketPrice: marketPrice,
///     sharesOutstanding: basicShares
/// )
///
/// // Diluted P/E
/// let dilutedPE = priceToEarnings(
///     incomeStatement: incomeStatement,
///     marketPrice: marketPrice,
///     sharesOutstanding: basicShares,
///     diluted: true,
///     dilutedShares: dilutedShares
/// )
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing net income
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Basic shares outstanding
///   - diluted: If true, use diluted shares for calculation
///   - dilutedShares: Diluted shares outstanding (required if diluted=true)
/// - Returns: Time series of P/E ratios
public func priceToEarnings<T: Real>(
	incomeStatement: IncomeStatement<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>,
	diluted: Bool = false,
	dilutedShares: TimeSeries<T>? = nil
) -> TimeSeries<T> {
	let shares = diluted ? (dilutedShares ?? sharesOutstanding) : sharesOutstanding
	let marketCap = marketCapitalization(marketPrice: marketPrice, sharesOutstanding: shares)
	let netIncome = incomeStatement.netIncome

	// P/E = Market Cap / Net Income
	return marketCap / netIncome
}

/// Price-to-Book Ratio (P/B) - market price relative to book value per share.
///
/// The P/B ratio compares market value to accounting book value (shareholders' equity).
/// It's useful for asset-heavy companies and identifying value stocks.
///
/// ## Formula
///
/// ```
/// P/B = Market Price per Share / Book Value per Share
/// P/B = Market Capitalization / Shareholders' Equity
///
/// Book Value per Share = Shareholders' Equity / Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **< 1.0**: Trading below book value (potential value, or distress)
/// - **1.0-3.0**: Fair value for asset-heavy businesses
/// - **3.0-10.0**: Premium for strong brands or intangibles
/// - **> 10.0**: Asset-light business or high growth
/// - **Negative**: Negative equity (insolvent)
///
/// ## Industry Variation
///
/// - **Banks**: 1.0-2.0 (book value very relevant)
/// - **Industrials**: 2.0-4.0 (significant fixed assets)
/// - **Software**: 10.0+ (intangible assets not on balance sheet)
/// - **Retail**: 3.0-6.0 (inventory and working capital)
///
/// ## When to Use
///
/// - Asset-heavy industries (banks, industrials, real estate)
/// - Value investing (finding companies trading below intrinsic value)
/// - Distressed situations (bankruptcy analysis)
///
/// ## Limitations
///
/// - Less relevant for asset-light businesses (tech, services)
/// - Book value affected by accounting policies
/// - Doesn't capture intangible value (brands, IP)
/// - Historical cost vs market value mismatch
///
/// ## Example
///
/// ```swift
/// let pb = priceToBook(
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/B: \(pb[q1]!)x")
/// ```
///
/// - Parameters:
///   - balanceSheet: Balance sheet containing shareholders' equity
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Shares outstanding
/// - Returns: Time series of P/B ratios
public func priceToBook<T: Real>(
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	let marketCap = marketCapitalization(marketPrice: marketPrice, sharesOutstanding: sharesOutstanding)
	let bookValue = balanceSheet.totalEquity

	// P/B = Market Cap / Book Value
	return marketCap / bookValue
}

/// Price-to-Sales Ratio (P/S) - market price relative to revenue per share.
///
/// The P/S ratio is useful for unprofitable companies or comparing growth companies.
/// Unlike P/E, it works for companies with negative earnings.
///
/// ## Formula
///
/// ```
/// P/S = Market Price per Share / Sales per Share
/// P/S = Market Capitalization / Revenue
///
/// Sales per Share = Revenue / Shares Outstanding
/// ```
///
/// ## Interpretation
///
/// - **< 1.0**: Potentially undervalued or distressed
/// - **1.0-3.0**: Fair value for mature companies
/// - **3.0-10.0**: Growth company or high margins
/// - **> 10.0**: High growth expectations or overvalued
///
/// ## Industry Variation
///
/// - **Retail**: 0.5-1.0 (low margins, commodity)
/// - **Software/SaaS**: 5.0-15.0 (high margins, recurring revenue)
/// - **Consumer Goods**: 1.0-3.0 (moderate margins)
/// - **Biotech**: 10.0+ (high R&D, no revenue yet)
///
/// ## When to Use
///
/// - Unprofitable companies (negative earnings)
/// - Early-stage growth companies
/// - Comparing companies with different margin structures
/// - Cyclical businesses (revenue more stable than earnings)
///
/// ## Advantages Over P/E
///
/// - Works for unprofitable companies
/// - Revenue harder to manipulate than earnings
/// - More stable (doesn't swing with profit margins)
///
/// ## Limitations
///
/// - Ignores profitability entirely
/// - Doesn't account for margin differences
/// - Can favor low-margin businesses
///
/// ## Example
///
/// ```swift
/// let ps = priceToSales(
///     incomeStatement: incomeStatement,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("P/S: \(ps[q1]!)x")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Shares outstanding
/// - Returns: Time series of P/S ratios
public func priceToSales<T: Real>(
	incomeStatement: IncomeStatement<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	let marketCap = marketCapitalization(marketPrice: marketPrice, sharesOutstanding: sharesOutstanding)
	let revenue = incomeStatement.totalRevenue

	// P/S = Market Cap / Revenue
	return marketCap / revenue
}

// MARK: - Enterprise Value

/// Enterprise Value (EV) - theoretical takeover price of a company.
///
/// Enterprise value represents the total cost to acquire a company, including
/// taking on its debt and subtracting its cash. It's capital-structure neutral,
/// making it better for comparing companies with different debt levels.
///
/// ## Formula
///
/// ```
/// EV = Market Capitalization + Interest-bearing Debt - Cash and Equivalents
/// ```
///
/// Where:
/// - Market Cap = Share Price × Shares Outstanding
/// - Debt = Interest-bearing debt only (excludes AP, accrued expenses)
/// - Cash = Cash + Marketable Securities
///
/// ## Interpretation
///
/// - **EV > Market Cap**: Company has net debt (typical)
/// - **EV < Market Cap**: Company has net cash (cash > debt)
/// - **EV ≈ Market Cap**: Company has balanced debt and cash
///
/// ## Why EV Matters
///
/// - **Capital-structure neutral**: Not affected by debt vs equity financing
/// - **Takeover price**: What acquirer would actually pay
/// - **Better for comparisons**: Companies with different leverage comparable
///
/// ## Real-world Example
///
/// ```
/// Company A: $10B market cap, $3B debt, $1B cash
/// EV = $10B + $3B - $1B = $12B
///
/// Company B: $10B market cap, $0 debt, $0 cash
/// EV = $10B + $0 - $0 = $10B
///
/// Same market cap, but Company A costs more to acquire (must pay off debt).
/// ```
///
/// ## Cash-rich Companies
///
/// Tech companies often have EV < Market Cap due to large cash reserves:
/// ```
/// Apple (example): $2.5T market cap, $100B debt, $200B cash
/// EV = $2.5T + $0.1T - $0.2T = $2.4T (less than market cap!)
/// ```
///
/// ## Example
///
/// ```swift
/// let ev = enterpriseValue(
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("EV: $\(ev[q1]!)")
/// ```
///
/// - Parameters:
///   - balanceSheet: Balance sheet containing debt and cash
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Shares outstanding
/// - Returns: Time series of enterprise value
public func enterpriseValue<T: Real>(
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	let marketCap = marketCapitalization(marketPrice: marketPrice, sharesOutstanding: sharesOutstanding)
	let debt = balanceSheet.interestBearingDebt
	let cash = balanceSheet.cashAndEquivalents

	// EV = Market Cap + Debt - Cash
	return marketCap + debt - cash
}

/// EV/EBITDA - enterprise value to EBITDA multiple.
///
/// The EV/EBITDA ratio is the most popular valuation multiple in M&A and
/// corporate finance. It's capital-structure neutral and excludes non-cash items.
///
/// ## Formula
///
/// ```
/// EV/EBITDA = Enterprise Value / EBITDA
///
/// Where:
/// EV = Market Cap + Debt - Cash
/// EBITDA = Earnings Before Interest, Taxes, Depreciation, Amortization
/// ```
///
/// ## Interpretation
///
/// - **< 7x**: Potentially undervalued
/// - **7x-12x**: Fair value for mature companies
/// - **12x-20x**: Growth company or strong market position
/// - **> 20x**: High growth or overvalued
///
/// ## Industry Benchmarks
///
/// - **Tech/Software**: 15x-25x (high growth, low capex)
/// - **Healthcare**: 12x-18x (defensive, stable)
/// - **Industrials**: 8x-12x (cyclical, capex-intensive)
/// - **Retail**: 6x-10x (low margins, competitive)
/// - **Energy/Utilities**: 8x-12x (regulated, capital-intensive)
///
/// ## Why EV/EBITDA is Popular
///
/// 1. **Capital-structure neutral**: Compares companies regardless of debt levels
/// 2. **Pre-tax**: Not affected by different tax rates or jurisdictions
/// 3. **Excludes D&A**: Removes non-cash charges, proxy for cash flow
/// 4. **M&A standard**: Most common metric in acquisition valuations
///
/// ## Advantages Over P/E
///
/// - Works for leveraged buyouts (LBOs)
/// - Not distorted by capital structure
/// - Better for international comparisons (tax differences)
/// - Closer to cash flow than net income
///
/// ## Limitations
///
/// - Ignores capex requirements (important for capital-intensive businesses)
/// - Can hide poor working capital management
/// - D&A may represent real economic cost
///
/// ## Example
///
/// ```swift
/// let evEbitda = evToEbitda(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("EV/EBITDA: \(evEbitda[q1]!)x")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing EBITDA
///   - balanceSheet: Balance sheet for EV calculation
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Shares outstanding
/// - Returns: Time series of EV/EBITDA multiples
public func evToEbitda<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	let ev = enterpriseValue(
		balanceSheet: balanceSheet,
		marketPrice: marketPrice,
		sharesOutstanding: sharesOutstanding
	)

	let ebitda = incomeStatement.ebitda

	// EV/EBITDA = Enterprise Value / EBITDA
	return ev / ebitda
}

/// EV/Sales - enterprise value to revenue multiple.
///
/// The EV/Sales ratio is useful for unprofitable companies or comparing businesses
/// with different margin structures. It's capital-structure neutral like EV/EBITDA.
///
/// ## Formula
///
/// ```
/// EV/Sales = Enterprise Value / Revenue
///
/// Where:
/// EV = Market Cap + Debt - Cash
/// ```
///
/// ## Interpretation
///
/// - **< 1.0x**: Potentially undervalued or distressed
/// - **1.0x-3.0x**: Fair value for mature companies
/// - **3.0x-10.0x**: Growth company or high margins
/// - **> 10.0x**: High growth expectations
///
/// ## Industry Benchmarks
///
/// - **SaaS/Cloud**: 5x-15x (high margins, recurring revenue)
/// - **Traditional Software**: 3x-8x (licenses, lower growth)
/// - **Consumer Goods**: 1x-3x (mature, moderate margins)
/// - **Retail**: 0.3x-1.0x (low margins, competitive)
/// - **Biotech**: 5x-20x (pre-revenue, pipeline value)
///
/// ## When to Use
///
/// - **Unprofitable companies**: Works when EBITDA is negative
/// - **Different margin profiles**: Compare high-margin vs low-margin businesses
/// - **Acquisition analysis**: Combined with margin assumptions
/// - **Early-stage growth**: Before profitability achieved
///
/// ## Relationship to EV/EBITDA
///
/// ```
/// EV/Sales = EV/EBITDA x (EBITDA / Sales)
/// EV/Sales = EV/EBITDA x EBITDA Margin
/// ```
///
/// High EV/Sales can be justified by high EBITDA margins.
///
/// ## Limitations
///
/// - Ignores profitability completely
/// - Can favor money-losing businesses
/// - Doesn't account for margin quality
/// - Less informative than EV/EBITDA for profitable companies
///
/// ## Example
///
/// ```swift
/// let evSales = evToSales(
///     incomeStatement: incomeStatement,
///     balanceSheet: balanceSheet,
///     marketPrice: marketPrice,
///     sharesOutstanding: sharesOutstanding
/// )
///
/// let q1 = Period.quarter(year: 2025, quarter: 1)
/// print("EV/Sales: \(evSales[q1]!)x")
/// ```
///
/// - Parameters:
///   - incomeStatement: Income statement containing revenue
///   - balanceSheet: Balance sheet for EV calculation
///   - marketPrice: Stock price per share over time
///   - sharesOutstanding: Shares outstanding
/// - Returns: Time series of EV/Sales multiples
public func evToSales<T: Real>(
	incomeStatement: IncomeStatement<T>,
	balanceSheet: BalanceSheet<T>,
	marketPrice: TimeSeries<T>,
	sharesOutstanding: TimeSeries<T>
) -> TimeSeries<T> {
	let ev = enterpriseValue(
		balanceSheet: balanceSheet,
		marketPrice: marketPrice,
		sharesOutstanding: sharesOutstanding
	)

	let revenue = incomeStatement.totalRevenue

	// EV/Sales = Enterprise Value / Revenue
	return ev / revenue
}
