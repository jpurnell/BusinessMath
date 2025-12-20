//
//  AdvancedRatioTools.swift
//  BusinessMath MCP Server
//
//  Advanced ratio analysis tools (DuPont, Piotroski) for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}


// MARK: - DuPont 3-Way Analysis

public struct DuPont3WayTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_dupont_3way",
        description: """
        Perform DuPont 3-Way Analysis to decompose ROE.

        DuPont analysis breaks down ROE into three components to identify drivers of profitability.

        Formula: ROE = Net Profit Margin × Asset Turnover × Equity Multiplier
        Where:
        • Net Profit Margin = Net Income / Sales
        • Asset Turnover = Sales / Total Assets
        • Equity Multiplier = Total Assets / Shareholder Equity

        Use Cases:
        • Understanding ROE drivers
        • Performance attribution
        • Identifying improvement areas
        • Strategic planning

        Example: 10% margin × 1.5 turnover × 2.0 multiplier = 30% ROE
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income"
                ),
                "sales": MCPSchemaProperty(
                    type: "number",
                    description: "Total sales/revenue"
                ),
                "totalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total assets"
                ),
                "shareholderEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Shareholder equity"
                )
            ],
            required: ["netIncome", "sales", "totalAssets", "shareholderEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let sales = try args.getDouble("sales")
        let totalAssets = try args.getDouble("totalAssets")
        let equity = try args.getDouble("shareholderEquity")

        guard sales > 0 && totalAssets > 0 && equity > 0 else {
            throw ToolError.invalidArguments("Sales, assets, and equity must be positive")
        }

        // Calculate components
        let profitMargin = netIncome / sales
        let assetTurnover = sales / totalAssets
        let equityMultiplier = totalAssets / equity

        // Calculate ROE
        let roeValue = profitMargin * assetTurnover * equityMultiplier

        // Direct calculation for verification
        let roeDirect = netIncome / equity

        let output = """
        DuPont 3-Way ROE Analysis:

        ROE Components:
        • Net Profit Margin: \(profitMargin.percent())
          → Profitability: How much profit per dollar of sales

        • Asset Turnover: \(formatRatio(assetTurnover))
          → Efficiency: How well assets generate sales

        • Equity Multiplier: \(formatRatio(equityMultiplier))
          → Leverage: Financial leverage employed

        ROE Calculation:
        \(profitMargin.percent()) × \(formatNumber(assetTurnover, decimals: 2)) × \(formatNumber(equityMultiplier, decimals: 2)) = \(roeValue.percent())

        Direct ROE (verification): \(roeDirect.percent())

        Key Insights:
        • Improving any component increases ROE
        • High ROE from leverage (equity multiplier) increases financial risk
        • Sustainable ROE comes from strong margins and efficiency

        Inputs:
        • Net Income: $\(formatNumber(netIncome, decimals: 0))
        • Sales: $\(formatNumber(sales, decimals: 0))
        • Total Assets: $\(formatNumber(totalAssets, decimals: 0))
        • Shareholder Equity: $\(formatNumber(equity, decimals: 0))
        """

        return .success(text: output)
    }
}

// MARK: - DuPont 5-Way Analysis

public struct DuPont5WayTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_dupont_5way",
        description: """
        Perform DuPont 5-Way Analysis to decompose ROE with additional detail.

        Extended DuPont analysis breaks ROE into five components for deeper insight.

        Formula: ROE = Tax Burden × Interest Burden × EBIT Margin × Asset Turnover × Equity Multiplier
        Where:
        • Tax Burden = Net Income / EBT
        • Interest Burden = EBT / EBIT
        • EBIT Margin = EBIT / Sales
        • Asset Turnover = Sales / Total Assets
        • Equity Multiplier = Total Assets / Equity

        Use Cases:
        • Detailed performance analysis
        • Identifying specific leverage points
        • Tax efficiency evaluation
        • Debt impact assessment

        Example: 0.75 tax × 0.90 interest × 0.15 EBIT margin × 1.5 turnover × 2.0 multiplier = 30% ROE
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income"
                ),
                "ebt": MCPSchemaProperty(
                    type: "number",
                    description: "Earnings before tax (EBT)"
                ),
                "ebit": MCPSchemaProperty(
                    type: "number",
                    description: "Earnings before interest and tax (EBIT)"
                ),
                "sales": MCPSchemaProperty(
                    type: "number",
                    description: "Total sales/revenue"
                ),
                "totalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total assets"
                ),
                "shareholderEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Shareholder equity"
                )
            ],
            required: ["netIncome", "ebt", "ebit", "sales", "totalAssets", "shareholderEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let ebt = try args.getDouble("ebt")
        let ebit = try args.getDouble("ebit")
        let sales = try args.getDouble("sales")
        let totalAssets = try args.getDouble("totalAssets")
        let equity = try args.getDouble("shareholderEquity")

        guard ebt > 0 && ebit > 0 && sales > 0 && totalAssets > 0 && equity > 0 else {
            throw ToolError.invalidArguments("All financial metrics must be positive")
        }

        // Calculate components
        let taxBurden = netIncome / ebt
        let interestBurden = ebt / ebit
        let ebitMargin = ebit / sales
        let assetTurnover = sales / totalAssets
        let equityMultiplier = totalAssets / equity

        // Calculate ROE
        let roeValue = taxBurden * interestBurden * ebitMargin * assetTurnover * equityMultiplier

        // Direct calculation for verification
        let roeDirect = netIncome / equity

        // Implied tax rate
        let taxRate = 1.0 - taxBurden

        let output = """
        DuPont 5-Way ROE Analysis:

        ROE Components:
        1. Tax Burden: \(formatNumber(taxBurden, decimals: 3))
           → Tax Efficiency: \(taxRate.percent()) effective tax rate

        2. Interest Burden: \(formatNumber(interestBurden, decimals: 3))
           → Debt Cost: Impact of interest expense on profitability

        3. EBIT Margin: \(ebitMargin.percent())
           → Operating Profitability: Profit from operations

        4. Asset Turnover: \(formatRatio(assetTurnover))
           → Asset Efficiency: Sales generation per dollar of assets

        5. Equity Multiplier: \(formatRatio(equityMultiplier))
           → Financial Leverage: Degree of leverage employed

        ROE Calculation:
        \(formatNumber(taxBurden, decimals: 2)) × \(formatNumber(interestBurden, decimals: 2)) × \(formatNumber(ebitMargin, decimals: 2)) × \(formatNumber(assetTurnover, decimals: 2)) × \(formatNumber(equityMultiplier, decimals: 2)) = \(roeValue.percent())

        Direct ROE (verification): \(roeDirect.percent())

        Key Insights:
        • Tax burden < 1.0 shows tax impact (lower = higher taxes)
        • Interest burden < 1.0 shows debt cost (lower = more debt)
        • Focus improvement on lowest-performing components

        Inputs:
        • Net Income: $\(formatNumber(netIncome, decimals: 0))
        • EBT: $\(formatNumber(ebt, decimals: 0))
        • EBIT: $\(formatNumber(ebit, decimals: 0))
        • Sales: $\(formatNumber(sales, decimals: 0))
        • Total Assets: $\(formatNumber(totalAssets, decimals: 0))
        • Shareholder Equity: $\(formatNumber(equity, decimals: 0))
        """

        return .success(text: output)
    }
}

// MARK: - Piotroski F-Score

public struct PiotroskiFScoreTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_piotroski_f_score",
        description: """
        Calculate the Piotroski F-Score for fundamental strength assessment.

        The F-Score is a 9-point scale (0-9) based on profitability, leverage, liquidity,
        and operating efficiency. Used to identify financially strong companies.

        Scoring Criteria (1 point each):
        Profitability:
        1. Positive net income
        2. Positive operating cash flow
        3. Increasing ROA
        4. Operating cash flow > net income (quality of earnings)

        Leverage/Liquidity:
        5. Decreasing long-term debt
        6. Increasing current ratio
        7. No new shares issued

        Operating Efficiency:
        8. Increasing gross margin
        9. Increasing asset turnover

        Interpretation:
        • 8-9 : Strong - Financially healthy
        • 5-7 : Moderate - Mixed signals
        • 0-4 : Weak - Potential issues

        Use Cases:
        • Value investing screening
        • Fundamental analysis
        • Financial health assessment
        • Investment filtering

        Example: Company scoring 7 points shows good fundamentals
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Current year net income"
                ),
                "operatingCashFlow": MCPSchemaProperty(
                    type: "number",
                    description: "Current year operating cash flow"
                ),
                "roaCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year ROA"
                ),
                "roaPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year ROA"
                ),
                "longTermDebtCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year long-term debt"
                ),
                "longTermDebtPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year long-term debt"
                ),
                "currentRatioCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year current ratio"
                ),
                "currentRatioPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year current ratio"
                ),
                "sharesCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year shares outstanding"
                ),
                "sharesPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year shares outstanding"
                ),
                "grossMarginCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year gross margin ratio"
                ),
                "grossMarginPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year gross margin ratio"
                ),
                "assetTurnoverCurrent": MCPSchemaProperty(
                    type: "number",
                    description: "Current year asset turnover"
                ),
                "assetTurnoverPrior": MCPSchemaProperty(
                    type: "number",
                    description: "Prior year asset turnover"
                )
            ],
            required: [
                "netIncome", "operatingCashFlow", "roaCurrent", "roaPrior",
                "longTermDebtCurrent", "longTermDebtPrior", "currentRatioCurrent", "currentRatioPrior",
                "sharesCurrent", "sharesPrior", "grossMarginCurrent", "grossMarginPrior",
                "assetTurnoverCurrent", "assetTurnoverPrior"
            ]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let ocf = try args.getDouble("operatingCashFlow")
        let roaCurrent = try args.getDouble("roaCurrent")
        let roaPrior = try args.getDouble("roaPrior")
        let debtCurrent = try args.getDouble("longTermDebtCurrent")
        let debtPrior = try args.getDouble("longTermDebtPrior")
        let crCurrent = try args.getDouble("currentRatioCurrent")
        let crPrior = try args.getDouble("currentRatioPrior")
        let sharesCurrent = try args.getDouble("sharesCurrent")
        let sharesPrior = try args.getDouble("sharesPrior")
        let gmCurrent = try args.getDouble("grossMarginCurrent")
        let gmPrior = try args.getDouble("grossMarginPrior")
        let atCurrent = try args.getDouble("assetTurnoverCurrent")
        let atPrior = try args.getDouble("assetTurnoverPrior")

        var score = 0
        var details: [String] = []

        // 1. Positive net income
        if netIncome > 0 {
            score += 1
            details.append("✓ Positive net income (+1)")
        } else {
            details.append("✗ Negative net income (0)")
        }

        // 2. Positive operating cash flow
        if ocf > 0 {
            score += 1
            details.append("✓ Positive operating cash flow (+1)")
        } else {
            details.append("✗ Negative operating cash flow (0)")
        }

        // 3. Increasing ROA
        if roaCurrent > roaPrior {
            score += 1
            details.append("✓ ROA increased (+1)")
        } else {
            details.append("✗ ROA did not increase (0)")
        }

        // 4. Quality of earnings (OCF > NI)
        if ocf > netIncome {
            score += 1
            details.append("✓ Cash flow > net income (quality earnings) (+1)")
        } else {
            details.append("✗ Cash flow ≤ net income (0)")
        }

        // 5. Decreasing leverage
        if debtCurrent < debtPrior {
            score += 1
            details.append("✓ Long-term debt decreased (+1)")
        } else {
            details.append("✗ Long-term debt increased or unchanged (0)")
        }

        // 6. Increasing current ratio
        if crCurrent > crPrior {
            score += 1
            details.append("✓ Current ratio improved (+1)")
        } else {
            details.append("✗ Current ratio did not improve (0)")
        }

        // 7. No new shares issued
        if sharesCurrent <= sharesPrior {
            score += 1
            details.append("✓ No new shares issued (no dilution) (+1)")
        } else {
            details.append("✗ New shares issued (dilution) (0)")
        }

        // 8. Increasing gross margin
        if gmCurrent > gmPrior {
            score += 1
            details.append("✓ Gross margin improved (+1)")
        } else {
            details.append("✗ Gross margin did not improve (0)")
        }

        // 9. Increasing asset turnover
        if atCurrent > atPrior {
            score += 1
            details.append("✓ Asset turnover improved (+1)")
        } else {
            details.append("✗ Asset turnover did not improve (0)")
        }

        let interpretation: String
        let recommendation: String

        if score >= 8 {
            interpretation = "Strong - Financially healthy company"
            recommendation = "Excellent fundamental strength, good investment candidate"
        } else if score >= 5 {
            interpretation = "Moderate - Mixed financial signals"
            recommendation = "Some strengths, but also areas of concern. Further analysis recommended"
        } else {
            interpretation = "Weak - Potential fundamental issues"
            recommendation = "Significant concerns. Carefully evaluate before investing"
        }

        let detailsText = details.joined(separator: "\n")

        let output = """
        Piotroski F-Score Analysis:

        F-Score: \(score) / 9
        Interpretation: \(interpretation)
        Recommendation: \(recommendation)

        Detailed Scoring:
        \(detailsText)

        Score Ranges:
        • 8-9 points: Strong fundamentals
        • 5-7 points: Moderate strength
        • 0-4 points: Weak fundamentals

        Note: The F-Score is most effective for screening value stocks
        and identifying financially distressed companies to avoid.
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns all advanced ratio analysis tools
public func getAdvancedRatioTools() -> [any MCPToolHandler] {
    return [
        DuPont3WayTool(),
        DuPont5WayTool(),
        PiotroskiFScoreTool()
    ]
}
