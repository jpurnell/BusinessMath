//
//  ValuationCalculatorsTools.swift
//  BusinessMath MCP Server
//
//  Financial valuation calculator tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all valuation calculator tools
public func getValuationCalculatorsTools() -> [any MCPToolHandler] {
    return [
        EarningsPerShareTool(),
        BookValuePerShareTool(),
        PriceToEarningsTool(),
        PriceToBookTool(),
        PriceToSalesTool(),
        MarketCapTool(),
        EnterpriseValueTool(),
        EVToEBITDATool(),
        EVToSalesTool(),
        WorkingCapitalTool(),
        DebtToAssetsTool(),
        FreeCashFlowTool()
    ]
}

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}


// MARK: - Per-Share Metrics

public struct EarningsPerShareTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_earnings_per_share",
        description: """
        Calculate Earnings Per Share (EPS).

        EPS shows how much profit a company generates for each share of stock.
        It's the most commonly cited metric in earnings reports and a key input for P/E ratios.

        Formula: EPS = Net Income / Shares Outstanding

        Interpretation:
        • Higher EPS = More profitable per share
        • Growing EPS = Company growing profits
        • Negative EPS = Company unprofitable

        Use Cases:
        • Profitability per share analysis
        • P/E ratio calculation input
        • Earnings growth tracking
        • Peer comparison

        Example: $5M net income, 1M shares = $5.00 EPS
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income (profit after all expenses and taxes)"
                ),
                "sharesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Number of shares outstanding"
                )
            ],
            required: ["netIncome", "sharesOutstanding"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let shares = try args.getDouble("sharesOutstanding")

        guard shares > 0 else {
            throw ToolError.invalidArguments("Shares outstanding must be positive")
        }

        let eps = netIncome / shares

        let output = """
        Earnings Per Share (EPS):

        Inputs:
        • Net Income: \(netIncome.currency())
        • Shares Outstanding: \(formatNumber(shares, decimals: 0))

        Result:
        • EPS: \(eps.currency())

        Each share generated \(eps.currency()) in profit.
        """

        return .success(text: output)
    }
}

public struct BookValuePerShareTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_book_value_per_share",
        description: """
        Calculate Book Value Per Share (BVPS).

        Book value per share represents the net asset value backing each share.
        It's what shareholders would theoretically receive per share if the company liquidated.

        Formula: BVPS = Total Equity / Shares Outstanding

        Interpretation:
        • Price > BVPS: Market values company above asset value (growth expectations)
        • Price < BVPS: Potential value opportunity or distressed situation
        • Price = BVPS: Trading at book value

        Use Cases:
        • Asset-based valuation
        • P/B ratio calculation input
        • Value investing screening
        • Banking/financial company analysis

        Example: $50M equity, 10M shares = $5.00 BVPS
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "totalEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Total shareholder equity (book value)"
                ),
                "sharesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Number of shares outstanding"
                )
            ],
            required: ["totalEquity", "sharesOutstanding"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let equity = try args.getDouble("totalEquity")
        let shares = try args.getDouble("sharesOutstanding")

        guard shares > 0 else {
            throw ToolError.invalidArguments("Shares outstanding must be positive")
        }

        let bvps = equity / shares

        let output = """
        Book Value Per Share (BVPS):

        Inputs:
        • Total Equity: \(equity.currency())
        • Shares Outstanding: \(formatNumber(shares, decimals: 0))

        Result:
        • BVPS: \(bvps.currency())

        Each share is backed by \(bvps.currency()) in net assets.
        """

        return .success(text: output)
    }
}

// MARK: - Valuation Ratios

public struct PriceToEarningsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_price_to_earnings",
        description: """
        Calculate Price-to-Earnings Ratio (P/E).

        P/E is the most widely used valuation metric, showing how much investors pay for $1 of earnings.

        Formula: P/E = Market Price per Share / Earnings per Share
                Or: P/E = Market Cap / Net Income

        Interpretation:
        • < 10x: Undervalued or mature business
        • 10-20x: Fair value for stable companies
        • 20-30x: Growth stock or strong position
        • > 30x: High growth expectations
        • Negative: Company unprofitable

        Industry Benchmarks:
        • Tech/Growth: 30-50x
        • Consumer: 20-25x
        • Financials: 10-15x
        • Utilities: 15-20x

        Example: $50 stock price, $2.50 EPS = 20x P/E
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "marketPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current market price per share"
                ),
                "earningsPerShare": MCPSchemaProperty(
                    type: "number",
                    description: "Earnings per share (EPS)"
                )
            ],
            required: ["marketPrice", "earningsPerShare"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let price = try args.getDouble("marketPrice")
        let eps = try args.getDouble("earningsPerShare")

        guard eps != 0 else {
            return .success(text: "P/E Ratio: Undefined (company has zero earnings)")
        }

        guard eps > 0 else {
            return .success(text: "P/E Ratio: Negative (company is unprofitable with EPS of \(eps.currency()))")
        }

        let pe = price / eps

        let interpretation: String
        if pe < 10 {
            interpretation = "Low - Potentially undervalued or mature/declining business"
        } else if pe < 20 {
            interpretation = "Moderate - Fair valuation for stable company"
        } else if pe < 30 {
            interpretation = "Elevated - Growth stock or strong competitive position"
        } else {
            interpretation = "High - Strong growth expectations or potentially overvalued"
        }

        let output = """
        Price-to-Earnings (P/E) Ratio:

        Inputs:
        • Market Price: \(price.currency())
        • Earnings Per Share: \(eps.currency())

        Result:
        • P/E Ratio: \(formatRatio(pe))
        • Interpretation: \(interpretation)

        Investors pay \(pe.currency()) for every $1 of annual earnings.
        """

        return .success(text: output)
    }
}

public struct PriceToBookTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_price_to_book",
        description: """
        Calculate Price-to-Book Ratio (P/B).

        P/B compares market value to book value (net assets).

        Formula: P/B = Market Price per Share / Book Value per Share
                Or: P/B = Market Cap / Total Equity

        Interpretation:
        • < 1.0x: Trading below book value (potential value)
        • 1.0-3.0x: Reasonable for most companies
        • > 3.0x: Premium for intangible value
        • > 10x: High for asset-light businesses (tech, services)

        Most useful for:
        • Asset-heavy industries (banks, real estate, manufacturing)
        • Value investing strategies
        • Companies with significant tangible assets

        Example: $25 price, $10 book value = 2.5x P/B
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "marketPrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current market price per share"
                ),
                "bookValuePerShare": MCPSchemaProperty(
                    type: "number",
                    description: "Book value per share"
                )
            ],
            required: ["marketPrice", "bookValuePerShare"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let price = try args.getDouble("marketPrice")
        let bvps = try args.getDouble("bookValuePerShare")

        guard bvps > 0 else {
            throw ToolError.invalidArguments("Book value per share must be positive")
        }

        let pb = price / bvps

        let interpretation: String
        if pb < 1.0 {
            interpretation = "Below Book - Trading at discount to net assets"
        } else if pb < 3.0 {
            interpretation = "Moderate - Reasonable premium to book value"
        } else if pb < 5.0 {
            interpretation = "Elevated - Significant premium for intangibles"
        } else {
            interpretation = "High - Very asset-light or growth business"
        }

        let output = """
        Price-to-Book (P/B) Ratio:

        Inputs:
        • Market Price: \(price.currency())
        • Book Value Per Share: \(bvps.currency())

        Result:
        • P/B Ratio: \(formatRatio(pb))
        • Interpretation: \(interpretation)

        Market values the company at \(formatRatio(pb)) its net asset value.
        """

        return .success(text: output)
    }
}

public struct PriceToSalesTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_price_to_sales",
        description: """
        Calculate Price-to-Sales Ratio (P/S).

        P/S measures market value relative to revenue. Useful when companies are unprofitable.

        Formula: P/S = Market Cap / Total Revenue
                Or: P/S = Price per Share / Sales per Share

        Interpretation:
        • < 1.0x: Potentially undervalued
        • 1.0-2.0x: Reasonable for many industries
        • 2.0-5.0x: Premium valuation
        • > 5.0x: High growth expectations (tech, biotech)

        Advantages:
        • Works for unprofitable companies
        • Hard to manipulate revenue vs earnings
        • Good for early-stage/high-growth companies

        Example: $100M market cap, $50M revenue = 2.0x P/S
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "marketCap": MCPSchemaProperty(
                    type: "number",
                    description: "Market capitalization"
                ),
                "totalRevenue": MCPSchemaProperty(
                    type: "number",
                    description: "Total revenue (sales)"
                )
            ],
            required: ["marketCap", "totalRevenue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let marketCap = try args.getDouble("marketCap")
        let revenue = try args.getDouble("totalRevenue")

        guard revenue > 0 else {
            throw ToolError.invalidArguments("Revenue must be positive")
        }

        let ps = marketCap / revenue

        let interpretation: String
        if ps < 1.0 {
            interpretation = "Low - Potentially undervalued relative to sales"
        } else if ps < 2.0 {
            interpretation = "Moderate - Reasonable valuation"
        } else if ps < 5.0 {
            interpretation = "Elevated - Premium for growth or margins"
        } else {
            interpretation = "High - Very high growth expectations"
        }

        let output = """
        Price-to-Sales (P/S) Ratio:

        Inputs:
        • Market Capitalization: \(marketCap.currency())
        • Total Revenue: \(revenue.currency())

        Result:
        • P/S Ratio: \(formatRatio(ps))
        • Interpretation: \(interpretation)

        Market values the company at \(formatRatio(ps)) its annual revenue.
        """

        return .success(text: output)
    }
}

// MARK: - Market Value Metrics

public struct MarketCapTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_market_cap",
        description: """
        Calculate Market Capitalization.

        Market cap is the total market value of all outstanding shares.

        Formula: Market Cap = Share Price × Shares Outstanding

        Size Classifications:
        • Mega Cap: > $200B
        • Large Cap: $10B - $200B
        • Mid Cap: $2B - $10B
        • Small Cap: $300M - $2B
        • Micro Cap: $50M - $300M
        • Nano Cap: < $50M

        Use Cases:
        • Company size classification
        • Index eligibility (S&P 500, Russell 2000)
        • Portfolio allocation decisions
        • Risk assessment

        Example: $50 stock, 10M shares = $500M market cap (Small Cap)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "sharePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Current share price"
                ),
                "sharesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Number of shares outstanding"
                )
            ],
            required: ["sharePrice", "sharesOutstanding"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let price = try args.getDouble("sharePrice")
        let shares = try args.getDouble("sharesOutstanding")

        let marketCap = price * shares

        let classification: String
        if marketCap >= 200_000_000_000 {
            classification = "Mega Cap (> $200B)"
        } else if marketCap >= 10_000_000_000 {
            classification = "Large Cap ($10B - $200B)"
        } else if marketCap >= 2_000_000_000 {
            classification = "Mid Cap ($2B - $10B)"
        } else if marketCap >= 300_000_000 {
            classification = "Small Cap ($300M - $2B)"
        } else if marketCap >= 50_000_000 {
            classification = "Micro Cap ($50M - $300M)"
        } else {
            classification = "Nano Cap (< $50M)"
        }

        let output = """
        Market Capitalization:

        Inputs:
        • Share Price: \(price.currency())
        • Shares Outstanding: \(formatNumber(shares, decimals: 0))

        Result:
        • Market Cap: \(marketCap.currency())
        • Classification: \(classification)
        """

        return .success(text: output)
    }
}

public struct EnterpriseValueTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_enterprise_value",
        description: """
        Calculate Enterprise Value (EV).

        EV represents the total value of a business, including debt.
        It's capital-structure-neutral, making it better for comparing companies with different leverage.

        Formula: EV = Market Cap + Total Debt - Cash & Equivalents

        Why add debt? Acquirer must pay off debt
        Why subtract cash? Cash reduces net cost to acquire

        Use Cases:
        • M&A valuations
        • Comparing companies with different capital structures
        • Input for EV/EBITDA, EV/Sales ratios
        • True economic value assessment

        Example: $500M market cap, $100M debt, $50M cash = $550M EV
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "marketCap": MCPSchemaProperty(
                    type: "number",
                    description: "Market capitalization"
                ),
                "totalDebt": MCPSchemaProperty(
                    type: "number",
                    description: "Total debt (short-term + long-term)"
                ),
                "cashAndEquivalents": MCPSchemaProperty(
                    type: "number",
                    description: "Cash and cash equivalents"
                )
            ],
            required: ["marketCap", "totalDebt", "cashAndEquivalents"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let marketCap = try args.getDouble("marketCap")
        let debt = try args.getDouble("totalDebt")
        let cash = try args.getDouble("cashAndEquivalents")

        let ev = marketCap + debt - cash

        let output = """
        Enterprise Value (EV):

        Inputs:
        • Market Capitalization: \(marketCap.currency())
        • Total Debt: \(debt.currency())
        • Cash & Equivalents: \(cash.currency())

        Calculation:
        • EV = Market Cap + Debt - Cash
        • EV = \(marketCap.currency()) + \(debt.currency()) - \(cash.currency())

        Result:
        • Enterprise Value: \(ev.currency())

        This represents the total cost to acquire the company including debt obligations.
        """

        return .success(text: output)
    }
}

public struct EVToEBITDATool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_ev_to_ebitda",
        description: """
        Calculate EV/EBITDA ratio.

        EV/EBITDA is a capital-structure-neutral valuation metric comparing total enterprise value
        to earnings before interest, taxes, depreciation, and amortization.

        Formula: EV/EBITDA = Enterprise Value / EBITDA

        Interpretation:
        • < 8x: Potentially undervalued
        • 8-12x: Fair value for many industries
        • 12-15x: Premium valuation
        • > 15x: High growth expectations or overvalued

        Advantages over P/E:
        • Ignores capital structure differences
        • Ignores depreciation policy differences
        • Better for comparing leveraged companies
        • Widely used in M&A and private equity

        Example: $550M EV, $50M EBITDA = 11x EV/EBITDA
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "enterpriseValue": MCPSchemaProperty(
                    type: "number",
                    description: "Enterprise value"
                ),
                "ebitda": MCPSchemaProperty(
                    type: "number",
                    description: "EBITDA (Earnings before interest, taxes, depreciation, amortization)"
                )
            ],
            required: ["enterpriseValue", "ebitda"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ev = try args.getDouble("enterpriseValue")
        let ebitda = try args.getDouble("ebitda")

        guard ebitda != 0 else {
            return .success(text: "EV/EBITDA: Undefined (EBITDA is zero)")
        }

        guard ebitda > 0 else {
            return .success(text: "EV/EBITDA: Negative (company has negative EBITDA of \(ebitda.currency()))")
        }

        let ratio = ev / ebitda

        let interpretation: String
        if ratio < 8 {
            interpretation = "Low - Potentially undervalued"
        } else if ratio < 12 {
            interpretation = "Moderate - Fair valuation"
        } else if ratio < 15 {
            interpretation = "Elevated - Premium valuation"
        } else {
            interpretation = "High - Strong growth expectations"
        }

        let output = """
        EV/EBITDA Ratio:

        Inputs:
        • Enterprise Value: \(ev.currency())
        • EBITDA: \(ebitda.currency())

        Result:
        • EV/EBITDA: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        The company trades at \(formatRatio(ratio)) its EBITDA.
        """

        return .success(text: output)
    }
}

public struct EVToSalesTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_ev_to_sales",
        description: """
        Calculate EV/Sales ratio.

        EV/Sales is a capital-structure-neutral valuation metric relative to revenue.
        Useful for unprofitable or pre-profit companies.

        Formula: EV/Sales = Enterprise Value / Total Revenue

        Interpretation:
        • < 1.0x: Potentially undervalued
        • 1.0-2.0x: Fair value for many industries
        • 2.0-5.0x: Premium valuation
        • > 5.0x: Very high growth expectations

        Advantages:
        • Works for unprofitable companies
        • Capital-structure-neutral
        • Hard to manipulate revenue
        • Good for early-stage companies

        Example: $550M EV, $250M revenue = 2.2x EV/Sales
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "enterpriseValue": MCPSchemaProperty(
                    type: "number",
                    description: "Enterprise value"
                ),
                "totalRevenue": MCPSchemaProperty(
                    type: "number",
                    description: "Total revenue (sales)"
                )
            ],
            required: ["enterpriseValue", "totalRevenue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ev = try args.getDouble("enterpriseValue")
        let revenue = try args.getDouble("totalRevenue")

        guard revenue > 0 else {
            throw ToolError.invalidArguments("Revenue must be positive")
        }

        let ratio = ev / revenue

        let interpretation: String
        if ratio < 1.0 {
            interpretation = "Low - Potentially undervalued"
        } else if ratio < 2.0 {
            interpretation = "Moderate - Fair valuation"
        } else if ratio < 5.0 {
            interpretation = "Elevated - Premium for growth/margins"
        } else {
            interpretation = "High - Very high growth expectations"
        }

        let output = """
        EV/Sales Ratio:

        Inputs:
        • Enterprise Value: \(ev.currency())
        • Total Revenue: \(revenue.currency())

        Result:
        • EV/Sales: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        The company trades at \(formatRatio(ratio)) its annual revenue.
        """

        return .success(text: output)
    }
}

// MARK: - Financial Health Metrics

public struct WorkingCapitalTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_working_capital",
        description: """
        Calculate Working Capital.

        Working capital measures short-term financial health and operational efficiency.

        Formula: Working Capital = Current Assets - Current Liabilities

        Interpretation:
        • Positive: Company can cover short-term obligations
        • Negative: Potential liquidity concerns
        • Growing: Improving liquidity position
        • Shrinking: Deteriorating liquidity

        Use Cases:
        • Liquidity assessment
        • Operational efficiency tracking
        • Cash flow forecasting
        • Credit analysis

        Example: $500K current assets, $300K current liabilities = $200K working capital
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total current assets"
                ),
                "currentLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total current liabilities"
                )
            ],
            required: ["currentAssets", "currentLiabilities"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assets = try args.getDouble("currentAssets")
        let liabilities = try args.getDouble("currentLiabilities")

        let workingCapital = assets - liabilities
        let currentRatio = liabilities > 0 ? assets / liabilities : 0

        let interpretation: String
        if workingCapital > 0 {
            interpretation = "Positive - Company can cover short-term obligations"
        } else if workingCapital == 0 {
            interpretation = "Zero - Current assets exactly equal current liabilities"
        } else {
            interpretation = "Negative - Potential liquidity concerns"
        }

        let output = """
        Working Capital:

        Inputs:
        • Current Assets: \(assets.currency())
        • Current Liabilities: \(liabilities.currency())

        Result:
        • Working Capital: \(workingCapital.currency())
        • Current Ratio: \(formatRatio(currentRatio))
        • Interpretation: \(interpretation)

        The company has \((abs(workingCapital)).currency()) \(workingCapital >= 0 ? "excess" : "shortage in") short-term liquidity.
        """

        return .success(text: output)
    }
}

public struct DebtToAssetsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_debt_to_assets",
        description: """
        Calculate Debt-to-Assets Ratio.

        Shows what proportion of assets are financed by debt.

        Formula: Debt/Assets = Total Debt / Total Assets

        Interpretation:
        • < 0.30: Conservative leverage
        • 0.30-0.50: Moderate leverage
        • 0.50-0.70: High leverage
        • > 0.70: Very high leverage risk

        Use Cases:
        • Financial risk assessment
        • Leverage analysis
        • Credit evaluation
        • Bankruptcy prediction

        Example: $300K debt, $1M assets = 30% debt ratio
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "totalDebt": MCPSchemaProperty(
                    type: "number",
                    description: "Total debt (short-term + long-term)"
                ),
                "totalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total assets"
                )
            ],
            required: ["totalDebt", "totalAssets"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let debt = try args.getDouble("totalDebt")
        let assets = try args.getDouble("totalAssets")

        guard assets > 0 else {
            throw ToolError.invalidArguments("Total assets must be positive")
        }

        let ratio = debt / assets

        let interpretation: String
        if ratio < 0.30 {
            interpretation = "Conservative - Low financial risk"
        } else if ratio < 0.50 {
            interpretation = "Moderate - Balanced leverage"
        } else if ratio < 0.70 {
            interpretation = "High - Significant financial risk"
        } else {
            interpretation = "Very High - Elevated bankruptcy risk"
        }

        let output = """
        Debt-to-Assets Ratio:

        Inputs:
        • Total Debt: \(debt.currency())
        • Total Assets: \(assets.currency())

        Result:
        • Debt/Assets: \(ratio.percent())
        • Interpretation: \(interpretation)

        \(ratio.percent()) of assets are financed by debt.
        """

        return .success(text: output)
    }
}

public struct FreeCashFlowTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_free_cash_flow",
        description: """
        Calculate Free Cash Flow (FCF).

        FCF is cash available after maintaining/expanding asset base.
        It's the truest measure of a company's ability to generate shareholder value.

        Formula: FCF = Operating Cash Flow - Capital Expenditures

        Interpretation:
        • Positive FCF: Can pay dividends, buy back stock, pay debt
        • Negative FCF: Must raise capital or use reserves
        • Growing FCF: Improving cash generation
        • FCF > Net Income: High quality earnings

        Use Cases:
        • Valuation (DCF analysis)
        • Dividend sustainability
        • Share buyback capacity
        • True profitability assessment

        Example: $100M operating CF, $30M capex = $70M FCF
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "operatingCashFlow": MCPSchemaProperty(
                    type: "number",
                    description: "Cash flow from operating activities"
                ),
                "capitalExpenditures": MCPSchemaProperty(
                    type: "number",
                    description: "Capital expenditures (capex)"
                )
            ],
            required: ["operatingCashFlow", "capitalExpenditures"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ocf = try args.getDouble("operatingCashFlow")
        let capex = try args.getDouble("capitalExpenditures")

        let fcf = ocf - capex

        let interpretation: String
        if fcf > 0 {
            interpretation = "Positive - Company generating excess cash"
        } else {
            interpretation = "Negative - Company consuming more cash than generating"
        }

        let output = """
        Free Cash Flow (FCF):

        Inputs:
        • Operating Cash Flow: \(ocf.currency())
        • Capital Expenditures: \(capex.currency())

        Calculation:
        • FCF = Operating CF - Capex
        • FCF = \(ocf.currency()) - \(capex.currency())

        Result:
        • Free Cash Flow: \(fcf.currency())
        • Interpretation: \(interpretation)

        The company generated \(fcf.currency()) in free cash available for shareholders.
        """

        return .success(text: output)
    }
}
