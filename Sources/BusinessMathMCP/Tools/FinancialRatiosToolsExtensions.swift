//
//  FinancialRatiosToolsExtensions.swift
//  BusinessMath MCP Server
//
//  Additional financial ratio analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions (reuse from main file)

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}

private func formatPercent(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value * 100, decimals: decimals) + "%"
}

// MARK: - 10. Return on Assets (ROA)

public struct ROATool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_return_on_assets",
        description: """
        Calculate Return on Assets (ROA).

        ROA measures how effectively a company uses its assets to generate profit.
        Indicates management efficiency in deploying assets.

        Formula: ROA = Net Income / Total Assets

        Interpretation:
        • 10%+ : Excellent - Very efficient asset utilization
        • 5-10% : Good - Solid asset efficiency
        • 2-5% : Moderate - Acceptable for capital-intensive industries
        • < 2% : Low - Assets may be underutilized

        Use Cases:
        • Asset efficiency analysis
        • Operational performance evaluation
        • Industry comparison
        • Investment screening

        Example: $200K net income on $2M total assets = 10% ROA
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income for the period"
                ),
                "totalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total assets (average or ending balance)"
                )
            ],
            required: ["netIncome", "totalAssets"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let totalAssets = try args.getDouble("totalAssets")

        guard totalAssets > 0 else {
            throw ToolError.invalidArguments("Total assets must be positive")
        }

        let roaValue: Double = netIncome / totalAssets

        let interpretation: String
        if roaValue >= 0.10 {
            interpretation = "Excellent - Very efficient asset utilization"
        } else if roaValue >= 0.05 {
            interpretation = "Good - Solid asset efficiency"
        } else if roaValue >= 0.02 {
            interpretation = "Moderate - Acceptable for capital-intensive industries"
        } else if roaValue >= 0 {
            interpretation = "Low - Assets may be underutilized"
        } else {
            interpretation = "Negative - Company generating losses"
        }

        let output = """
        Return on Assets (ROA) Analysis:

        Inputs:
        • Net Income: $\(formatNumber(netIncome, decimals: 0))
        • Total Assets: $\(formatNumber(totalAssets, decimals: 0))

        Result:
        • ROA: \(formatPercent(roaValue))
        • Interpretation: \(interpretation)

        The company generates $\(formatNumber(roaValue)) in profit for every $1 of assets,
        representing a \(formatNumber(roaValue * 100, decimals: 1))% return on assets.
        """

        return .success(text: output)
    }
}

// MARK: - 11. Return on Invested Capital (ROIC)

public struct ROICTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_return_on_invested_capital",
        description: """
        Calculate Return on Invested Capital (ROIC).

        ROIC measures how efficiently a company generates returns from its invested capital
        (both equity and debt). Key metric for evaluating capital allocation decisions.

        Formula: ROIC = NOPAT / Invested Capital
        Where NOPAT = Net Operating Profit After Tax
        Invested Capital = Equity + Debt - Cash

        Interpretation:
        • 15%+ : Excellent - Strong value creation
        • 10-15% : Good - Above cost of capital for most companies
        • 5-10% : Moderate - May be below WACC
        • < 5% : Weak - Destroying shareholder value

        Use Cases:
        • Capital allocation efficiency
        • Value creation assessment
        • Investment screening
        • Comparing companies across industries

        Example: $1.5M NOPAT on $10M invested capital = 15% ROIC
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "nopat": MCPSchemaProperty(
                    type: "number",
                    description: "Net Operating Profit After Tax (EBIT × (1 - tax rate))"
                ),
                "investedCapital": MCPSchemaProperty(
                    type: "number",
                    description: "Total invested capital (equity + debt - excess cash)"
                )
            ],
            required: ["nopat", "investedCapital"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let nopat = try args.getDouble("nopat")
        let investedCapital = try args.getDouble("investedCapital")

        guard investedCapital > 0 else {
            throw ToolError.invalidArguments("Invested capital must be positive")
        }

        let roicValue = nopat / investedCapital

        let interpretation: String
        if roicValue >= 0.15 {
            interpretation = "Excellent - Strong value creation, well above typical WACC"
        } else if roicValue >= 0.10 {
            interpretation = "Good - Above cost of capital, creating value"
        } else if roicValue >= 0.05 {
            interpretation = "Moderate - May be below WACC, limited value creation"
        } else if roicValue >= 0 {
            interpretation = "Weak - Likely destroying shareholder value"
        } else {
            interpretation = "Negative - Operating losses, destroying value"
        }

        let output = """
        Return on Invested Capital (ROIC) Analysis:

        Inputs:
        • NOPAT (Net Operating Profit After Tax): $\(formatNumber(nopat, decimals: 0))
        • Invested Capital: $\(formatNumber(investedCapital, decimals: 0))

        Result:
        • ROIC: \(formatPercent(roicValue))
        • Interpretation: \(interpretation)

        The company generates $\(formatNumber(roicValue)) in after-tax operating profit
        for every $1 of invested capital (\(formatNumber(roicValue * 100, decimals: 1))% return).

        Note: Compare ROIC to WACC. ROIC > WACC indicates value creation.
        """

        return .success(text: output)
    }
}

// MARK: - 12. Receivables Turnover

public struct ReceivablesTurnoverTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_receivables_turnover",
        description: """
        Calculate the receivables turnover ratio.

        Receivables turnover measures how efficiently a company collects its accounts receivable.
        Higher ratios indicate faster collection and better liquidity.

        Formula: Receivables Turnover = Net Credit Sales / Average Accounts Receivable

        Interpretation:
        • 12+ : Excellent - Very efficient collections (~30 days)
        • 8-12 : Good - Healthy collection period (30-45 days)
        • 4-8 : Moderate - Standard terms (45-90 days)
        • < 4 : Slow - Collection issues (>90 days)

        Days Sales Outstanding (DSO) = 365 / Receivables Turnover

        Use Cases:
        • Collection efficiency analysis
        • Credit policy evaluation
        • Cash flow forecasting
        • Working capital management

        Example: $2.4M sales with $200K average receivables = 12x turnover (30 days DSO)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netCreditSales": MCPSchemaProperty(
                    type: "number",
                    description: "Net credit sales for the period (or total sales if not separated)"
                ),
                "averageAccountsReceivable": MCPSchemaProperty(
                    type: "number",
                    description: "Average accounts receivable during period"
                )
            ],
            required: ["netCreditSales", "averageAccountsReceivable"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let sales = try args.getDouble("netCreditSales")
        let avgReceivables = try args.getDouble("averageAccountsReceivable")

        guard avgReceivables > 0 else {
            throw ToolError.invalidArguments("Average accounts receivable must be positive")
        }

        let turnover = sales / avgReceivables
        let dso = 365.0 / turnover

        let interpretation: String
        if turnover >= 12.0 {
            interpretation = "Excellent - Very efficient collections, strong credit management"
        } else if turnover >= 8.0 {
            interpretation = "Good - Healthy collection period"
        } else if turnover >= 4.0 {
            interpretation = "Moderate - Standard payment terms"
        } else {
            interpretation = "Slow - Review collection practices and credit policies"
        }

        let output = """
        Receivables Turnover Analysis:

        Inputs:
        • Net Credit Sales: $\(formatNumber(sales, decimals: 0))
        • Average Accounts Receivable: $\(formatNumber(avgReceivables, decimals: 0))

        Result:
        • Receivables Turnover: \(formatRatio(turnover))
        • Days Sales Outstanding (DSO): \(formatNumber(dso, decimals: 1)) days
        • Interpretation: \(interpretation)

        The company collects its receivables \(formatNumber(turnover)) times per year,
        or takes an average of \(formatNumber(dso, decimals: 0)) days to collect payment.
        """

        return .success(text: output)
    }
}

// MARK: - 13. Cash Ratio

public struct CashRatioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cash_ratio",
        description: """
        Calculate the cash ratio (most conservative liquidity ratio).

        Cash ratio measures ability to pay current liabilities using only cash and cash equivalents.
        Most stringent liquidity test.

        Formula: Cash Ratio = (Cash + Cash Equivalents) / Current Liabilities

        Interpretation:
        • 0.5+ : Very Strong - Can pay half of liabilities immediately
        • 0.3-0.5 : Strong - Healthy cash reserves
        • 0.1-0.3 : Adequate - Typical for most businesses
        • < 0.1 : Low - Limited immediate liquidity

        Use Cases:
        • Conservative credit analysis
        • Financial stress testing
        • Distressed company evaluation
        • Extreme liquidity assessment

        Example: $150K cash with $300K current liabilities = 0.5 cash ratio
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "cashAndEquivalents": MCPSchemaProperty(
                    type: "number",
                    description: "Cash and cash equivalents (highly liquid assets)"
                ),
                "currentLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total current liabilities"
                )
            ],
            required: ["cashAndEquivalents", "currentLiabilities"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let cash = try args.getDouble("cashAndEquivalents")
        let currentLiabilities = try args.getDouble("currentLiabilities")

        guard currentLiabilities > 0 else {
            throw ToolError.invalidArguments("Current liabilities must be positive")
        }

        let ratio = cash / currentLiabilities

        let interpretation: String
        if ratio >= 0.5 {
            interpretation = "Very Strong - Excellent immediate liquidity"
        } else if ratio >= 0.3 {
            interpretation = "Strong - Healthy cash reserves"
        } else if ratio >= 0.1 {
            interpretation = "Adequate - Typical for most businesses"
        } else {
            interpretation = "Low - Limited immediate liquidity, may need credit lines"
        }

        let coveragePercent = ratio * 100

        let output = """
        Cash Ratio Analysis:

        Inputs:
        • Cash and Cash Equivalents: $\(formatNumber(cash, decimals: 0))
        • Current Liabilities: $\(formatNumber(currentLiabilities, decimals: 0))

        Result:
        • Cash Ratio: \(formatRatio(ratio))
        • Coverage: \(formatNumber(coveragePercent, decimals: 1))% of current liabilities
        • Interpretation: \(interpretation)

        The company can immediately pay \(formatNumber(coveragePercent, decimals: 0))% of current liabilities
        using only cash and cash equivalents.

        Note: This is the most conservative liquidity measure, excluding receivables and inventory.
        """

        return .success(text: output)
    }
}

// MARK: - 14. Debt Ratio

public struct DebtRatioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_debt_ratio",
        description: """
        Calculate the debt ratio.

        Debt ratio measures the proportion of a company's assets financed by debt.
        Higher ratios indicate more leverage and financial risk.

        Formula: Debt Ratio = Total Debt / Total Assets

        Interpretation:
        • < 0.3 : Conservative - Low leverage, strong equity base
        • 0.3-0.5 : Moderate - Balanced capital structure
        • 0.5-0.7 : High - Significant leverage
        • > 0.7 : Very High - Heavy reliance on debt

        Use Cases:
        • Solvency assessment
        • Credit risk evaluation
        • Capital structure analysis
        • Loan approval decisions

        Example: $3M total debt and $10M total assets = 0.30 or 30% debt ratio
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

        let totalDebt = try args.getDouble("totalDebt")
        let totalAssets = try args.getDouble("totalAssets")

        guard totalAssets > 0 else {
            throw ToolError.invalidArguments("Total assets must be positive")
        }

        let ratio = totalDebt / totalAssets
        let equityRatio = 1.0 - ratio

        let interpretation: String
        if ratio < 0.3 {
            interpretation = "Conservative - Low leverage, strong equity base"
        } else if ratio < 0.5 {
            interpretation = "Moderate - Balanced capital structure"
        } else if ratio < 0.7 {
            interpretation = "High - Significant leverage, monitor debt service"
        } else {
            interpretation = "Very High - Heavy reliance on debt, elevated financial risk"
        }

        let output = """
        Debt Ratio Analysis:

        Inputs:
        • Total Debt: $\(formatNumber(totalDebt, decimals: 0))
        • Total Assets: $\(formatNumber(totalAssets, decimals: 0))

        Result:
        • Debt Ratio: \(formatPercent(ratio))
        • Equity Ratio: \(formatPercent(equityRatio))
        • Interpretation: \(interpretation)

        \(formatNumber(ratio * 100, decimals: 1))% of the company's assets are financed by debt,
        while \(formatNumber(equityRatio * 100, decimals: 1))% are financed by equity.
        """

        return .success(text: output)
    }
}

// MARK: - Extended Financial Ratios Tools Registration

/// Returns extended financial ratio tools
public func getExtendedFinancialRatiosTools() -> [any MCPToolHandler] {
    return [
        ROATool(),
        ROICTool(),
        ReceivablesTurnoverTool(),
        CashRatioTool(),
        DebtRatioTool(),
        DaysInventoryOutstandingTool(),
        DaysSalesOutstandingTool(),
        DaysPayableOutstandingTool(),
        CashConversionCycleTool(),
        DuPont3WayTool(),
        DuPont5WayTool(),
        PiotroskiFScoreTool()
    ]
}
