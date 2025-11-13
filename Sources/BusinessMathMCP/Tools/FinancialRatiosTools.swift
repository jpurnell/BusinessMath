//
//  FinancialRatiosTools.swift
//  BusinessMath MCP Server
//
//  Financial ratio analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all financial ratio tools
public func getFinancialRatiosTools() -> [any MCPToolHandler] {
    return [
        AssetTurnoverTool(),
        CurrentRatioTool(),
        QuickRatioTool(),
        DebtToEquityTool(),
        InterestCoverageTool(),
        InventoryTurnoverTool(),
        ProfitMarginTool(),
        ROETool(),
        ROITool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format a ratio with interpretation
private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}

/// Format a percentage
private func formatPercent(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value * 100, decimals: decimals) + "%"
}

// MARK: - 1. Asset Turnover

public struct AssetTurnoverTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_asset_turnover",
        description: """
        Calculate the asset turnover ratio.

        Asset turnover measures how efficiently a company uses its assets to generate sales revenue.
        Higher ratios indicate better asset utilization.

        Formula: Asset Turnover = Net Sales / Average Total Assets

        Interpretation:
        • 2.0+ : Excellent asset efficiency (retail, food service)
        • 1.0-2.0 : Good efficiency (many industries)
        • 0.5-1.0 : Moderate efficiency (capital-intensive industries)
        • < 0.5 : Low efficiency or capital-intensive business

        Use Cases:
        • Operational efficiency analysis
        • Industry comparison
        • Asset utilization tracking
        • Capital allocation decisions

        Example: Company with $5M sales and $2M average assets has 2.5x turnover
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netSales": MCPSchemaProperty(
                    type: "number",
                    description: "Net sales or revenue for the period"
                ),
                "averageTotalAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Average total assets during the period (beginning + ending) / 2"
                )
            ],
            required: ["netSales", "averageTotalAssets"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netSales = try args.getDouble("netSales")
        let averageTotalAssets = try args.getDouble("averageTotalAssets")

        let ratio: Double = assetTurnover(netSales: netSales, averageTotalAssets: averageTotalAssets)

        let interpretation: String
        if ratio >= 2.0 {
            interpretation = "Excellent - Company efficiently converts assets into sales"
        } else if ratio >= 1.0 {
            interpretation = "Good - Healthy asset utilization"
        } else if ratio >= 0.5 {
            interpretation = "Moderate - May indicate capital-intensive operations"
        } else {
            interpretation = "Low - Consider reviewing asset utilization or business model"
        }

        let output = """
        Asset Turnover Ratio Analysis:

        Inputs:
        • Net Sales: $\(formatNumber(netSales, decimals: 0))
        • Average Total Assets: $\(formatNumber(averageTotalAssets, decimals: 0))

        Result:
        • Asset Turnover: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        This means the company generates $\(formatNumber(ratio)) in sales for every $1 of assets.
        """

        return .success(text: output)
    }
}

// MARK: - 2. Current Ratio

public struct CurrentRatioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_current_ratio",
        description: """
        Calculate the current ratio (liquidity ratio).

        Current ratio measures a company's ability to pay short-term obligations with short-term assets.

        Formula: Current Ratio = Current Assets / Current Liabilities

        Interpretation:
        • 2.0+ : Very strong liquidity position
        • 1.5-2.0 : Strong liquidity, comfortable buffer
        • 1.0-1.5 : Adequate liquidity for most industries
        • < 1.0 : Potential liquidity concerns

        Use Cases:
        • Credit analysis
        • Working capital management
        • Loan covenant compliance
        • Liquidity risk assessment

        Example: Company with $300K current assets and $200K current liabilities has 1.5 ratio
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total current assets (cash, receivables, inventory, etc.)"
                ),
                "currentLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total current liabilities (payables, short-term debt, etc.)"
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

        let currentAssets = try args.getDouble("currentAssets")
        let currentLiabilities = try args.getDouble("currentLiabilities")

        let ratio: Double = currentRatio(currentAssets: currentAssets, currentLiabilities: currentLiabilities)

        let interpretation: String
        if ratio >= 2.0 {
            interpretation = "Very Strong - Excellent liquidity cushion"
        } else if ratio >= 1.5 {
            interpretation = "Strong - Comfortable liquidity position"
        } else if ratio >= 1.0 {
            interpretation = "Adequate - Can meet short-term obligations"
        } else {
            interpretation = "Weak - Potential liquidity concerns, monitor closely"
        }

        let output = """
        Current Ratio Analysis:

        Inputs:
        • Current Assets: $\(formatNumber(currentAssets, decimals: 0))
        • Current Liabilities: $\(formatNumber(currentLiabilities, decimals: 0))

        Result:
        • Current Ratio: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        The company has $\(formatNumber(ratio)) in current assets for every $1 of current liabilities.
        """

        return .success(text: output)
    }
}

// MARK: - 3. Quick Ratio

public struct QuickRatioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_quick_ratio",
        description: """
        Calculate the quick ratio (acid-test ratio).

        Quick ratio measures ability to meet short-term obligations with most liquid assets,
        excluding inventory (which may be hard to liquidate quickly).

        Formula: Quick Ratio = (Current Assets - Inventory) / Current Liabilities

        Interpretation:
        • 1.5+ : Very strong liquidity
        • 1.0-1.5 : Strong liquidity position
        • 0.5-1.0 : Acceptable, but monitor
        • < 0.5 : Potential liquidity risk

        More conservative than current ratio - better for assessing true liquidity.

        Use Cases:
        • Conservative liquidity analysis
        • Credit evaluation
        • Industries with slow-moving inventory
        • Quick solvency assessment

        Example: $300K assets, $50K inventory, $200K liabilities = 1.25 ratio
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Total current assets"
                ),
                "inventory": MCPSchemaProperty(
                    type: "number",
                    description: "Total inventory value"
                ),
                "currentLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total current liabilities"
                )
            ],
            required: ["currentAssets", "inventory", "currentLiabilities"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let currentAssets = try args.getDouble("currentAssets")
        let inventory = try args.getDouble("inventory")
        let currentLiabilities = try args.getDouble("currentLiabilities")

        let ratio: Double = quickRatio(currentAssets: currentAssets, inventory: inventory, currentLiabilities: currentLiabilities)

        let liquidAssets = currentAssets - inventory

        let interpretation: String
        if ratio >= 1.5 {
            interpretation = "Very Strong - Excellent immediate liquidity"
        } else if ratio >= 1.0 {
            interpretation = "Strong - Can meet obligations without selling inventory"
        } else if ratio >= 0.5 {
            interpretation = "Acceptable - Monitor inventory turnover closely"
        } else {
            interpretation = "Weak - May struggle to meet obligations without selling inventory"
        }

        let output = """
        Quick Ratio (Acid-Test) Analysis:

        Inputs:
        • Current Assets: $\(formatNumber(currentAssets, decimals: 0))
        • Inventory: $\(formatNumber(inventory, decimals: 0))
        • Current Liabilities: $\(formatNumber(currentLiabilities, decimals: 0))

        Calculation:
        • Liquid Assets (excluding inventory): $\(formatNumber(liquidAssets, decimals: 0))

        Result:
        • Quick Ratio: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        The company has $\(formatNumber(ratio)) in liquid assets for every $1 of current liabilities.
        """

        return .success(text: output)
    }
}

// MARK: - 4. Debt to Equity

public struct DebtToEquityTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_debt_to_equity",
        description: """
        Calculate the debt to equity ratio (leverage ratio).

        Debt to equity measures the proportion of debt vs equity financing.
        Shows financial leverage and solvency risk.

        Formula: D/E = Total Liabilities / Shareholder Equity

        Interpretation:
        • < 0.5 : Conservative capital structure
        • 0.5-1.0 : Balanced capital structure
        • 1.0-2.0 : Moderate leverage (common in many industries)
        • > 2.0 : High leverage, higher financial risk

        Varies significantly by industry (e.g., utilities typically higher).

        Use Cases:
        • Capital structure analysis
        • Solvency assessment
        • Credit risk evaluation
        • Financing decisions

        Example: Company with $500K debt and $500K equity has 1.0 D/E ratio
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "totalLiabilities": MCPSchemaProperty(
                    type: "number",
                    description: "Total liabilities (short-term + long-term debt)"
                ),
                "shareholderEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Total shareholder equity (book value)"
                )
            ],
            required: ["totalLiabilities", "shareholderEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let totalLiabilities = try args.getDouble("totalLiabilities")
        let shareholderEquity = try args.getDouble("shareholderEquity")

        let ratio: Double = debtToEquity(totalLiabilities: totalLiabilities, shareholderEquity: shareholderEquity)

        let interpretation: String
        if ratio < 0.5 {
            interpretation = "Conservative - Low leverage, strong equity base"
        } else if ratio < 1.0 {
            interpretation = "Balanced - Healthy mix of debt and equity"
        } else if ratio < 2.0 {
            interpretation = "Moderate - Common leverage level, monitor debt service"
        } else {
            interpretation = "High - Significant leverage, higher financial risk"
        }

        let totalCapital = totalLiabilities + shareholderEquity
        let debtPercent = totalCapital > 0 ? (totalLiabilities / totalCapital) : 0
        let equityPercent = totalCapital > 0 ? (shareholderEquity / totalCapital) : 0

        let output = """
        Debt to Equity Ratio Analysis:

        Inputs:
        • Total Liabilities: $\(formatNumber(totalLiabilities, decimals: 0))
        • Shareholder Equity: $\(formatNumber(shareholderEquity, decimals: 0))
        • Total Capital: $\(formatNumber(totalCapital, decimals: 0))

        Result:
        • Debt to Equity Ratio: \(formatRatio(ratio))
        • Capital Structure: \(formatPercent(debtPercent)) debt, \(formatPercent(equityPercent)) equity
        • Interpretation: \(interpretation)

        The company has $\(formatNumber(ratio)) in liabilities for every $1 of equity.
        """

        return .success(text: output)
    }
}

// MARK: - 5. Interest Coverage

public struct InterestCoverageTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_interest_coverage",
        description: """
        Calculate the interest coverage ratio (times interest earned).

        Interest coverage measures ability to cover interest payments from operating earnings.
        Critical for debt service capacity assessment.

        Formula: Interest Coverage = EBIT / Interest Expense

        Interpretation:
        • 5.0+ : Very strong - Comfortable debt service capacity
        • 3.0-5.0 : Strong - Adequate coverage
        • 1.5-3.0 : Acceptable - Monitor closely
        • < 1.5 : Weak - Difficulty covering interest, potential default risk

        Use Cases:
        • Debt service capacity analysis
        • Credit rating assessment
        • Loan covenant compliance
        • Refinancing evaluation

        Example: Company with $500K EBIT and $100K interest has 5.0x coverage
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "earningsBeforeInterestAndTax": MCPSchemaProperty(
                    type: "number",
                    description: "EBIT - Earnings before interest and taxes (operating income)"
                ),
                "interestExpense": MCPSchemaProperty(
                    type: "number",
                    description: "Total interest expense for the period"
                )
            ],
            required: ["earningsBeforeInterestAndTax", "interestExpense"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ebit = try args.getDouble("earningsBeforeInterestAndTax")
        let interestExpense = try args.getDouble("interestExpense")

        let ratio: Double = interestCoverage(earningsBeforeInterestAndTax: ebit, interestExpense: interestExpense)

        let interpretation: String
        if ratio >= 5.0 {
            interpretation = "Very Strong - Excellent debt service capacity"
        } else if ratio >= 3.0 {
            interpretation = "Strong - Comfortable interest coverage"
        } else if ratio >= 1.5 {
            interpretation = "Acceptable - Can cover interest but limited cushion"
        } else if ratio >= 1.0 {
            interpretation = "Weak - Barely covering interest payments"
        } else {
            interpretation = "Critical - Cannot cover interest from operations"
        }

        let output = """
        Interest Coverage Ratio Analysis:

        Inputs:
        • EBIT (Operating Income): $\(formatNumber(ebit, decimals: 0))
        • Interest Expense: $\(formatNumber(interestExpense, decimals: 0))

        Result:
        • Interest Coverage: \(formatRatio(ratio))
        • Interpretation: \(interpretation)

        The company can cover its interest expense \(formatNumber(ratio)) times from operating earnings.
        """

        return .success(text: output)
    }
}

// MARK: - 6. Inventory Turnover

public struct InventoryTurnoverTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_inventory_turnover",
        description: """
        Calculate the inventory turnover ratio.

        Inventory turnover measures how many times inventory is sold and replaced over a period.
        Indicates inventory management efficiency.

        Formula: Inventory Turnover = Cost of Goods Sold / Average Inventory

        Interpretation (varies significantly by industry):
        • 10+ : Fast-moving (grocery, perishables)
        • 5-10 : Good turnover (retail, fashion)
        • 2-5 : Moderate (general merchandise)
        • < 2 : Slow-moving (luxury goods, specialized equipment)

        Days Inventory Outstanding = 365 / Turnover

        Use Cases:
        • Working capital management
        • Inventory optimization
        • Industry benchmarking
        • Operational efficiency tracking

        Example: $1M COGS with $200K average inventory = 5x turnover (73 days)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "costOfGoodsSold": MCPSchemaProperty(
                    type: "number",
                    description: "Total cost of goods sold for the period"
                ),
                "averageInventory": MCPSchemaProperty(
                    type: "number",
                    description: "Average inventory during period (beginning + ending) / 2"
                )
            ],
            required: ["costOfGoodsSold", "averageInventory"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let cogs = try args.getDouble("costOfGoodsSold")
        let averageInventory = try args.getDouble("averageInventory")

        let ratio: Double = inventoryTurnover(costOfGoodsSold: cogs, averageInventory: averageInventory)
        let daysInventory = ratio > 0 ? 365.0 / ratio : 0

        let interpretation: String
        if ratio >= 10.0 {
            interpretation = "Fast-Moving - Very efficient inventory management"
        } else if ratio >= 5.0 {
            interpretation = "Good - Healthy turnover rate"
        } else if ratio >= 2.0 {
            interpretation = "Moderate - Consider optimization opportunities"
        } else {
            interpretation = "Slow - Review inventory levels and product mix"
        }

        let output = """
        Inventory Turnover Analysis:

        Inputs:
        • Cost of Goods Sold: $\(formatNumber(cogs, decimals: 0))
        • Average Inventory: $\(formatNumber(averageInventory, decimals: 0))

        Result:
        • Inventory Turnover: \(formatRatio(ratio))
        • Days Inventory Outstanding: \(formatNumber(daysInventory, decimals: 1)) days
        • Interpretation: \(interpretation)

        The company sells and replaces its inventory \(formatNumber(ratio)) times per year,
        or holds inventory for an average of \(formatNumber(daysInventory, decimals: 0)) days.
        """

        return .success(text: output)
    }
}

// MARK: - 7. Profit Margin

public struct ProfitMarginTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_profit_margin",
        description: """
        Calculate the profit margin (net profit margin).

        Profit margin shows how much profit a company earns for every dollar of revenue.
        Key profitability and efficiency metric.

        Formula: Profit Margin = Net Income / Revenue

        Interpretation (varies by industry):
        • 20%+ : Excellent profitability (software, pharma)
        • 10-20% : Strong margins (many sectors)
        • 5-10% : Moderate margins (retail, wholesale)
        • < 5% : Thin margins (grocery, commodities)

        Use Cases:
        • Profitability analysis
        • Pricing strategy evaluation
        • Cost structure assessment
        • Industry comparison

        Example: Company with $200K net income on $1M revenue has 20% margin
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income (profit after all expenses and taxes)"
                ),
                "revenue": MCPSchemaProperty(
                    type: "number",
                    description: "Total revenue (sales)"
                )
            ],
            required: ["netIncome", "revenue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let revenue = try args.getDouble("revenue")

        let margin: Double = profitMargin(netIncome: netIncome, revenue: revenue)

        let interpretation: String
        if margin >= 0.20 {
            interpretation = "Excellent - High profitability"
        } else if margin >= 0.10 {
            interpretation = "Strong - Healthy profit margins"
        } else if margin >= 0.05 {
            interpretation = "Moderate - Acceptable but room for improvement"
        } else if margin >= 0 {
            interpretation = "Thin - Low profitability, review cost structure"
        } else {
            interpretation = "Negative - Company is operating at a loss"
        }

        let output = """
        Profit Margin Analysis:

        Inputs:
        • Revenue: $\(formatNumber(revenue, decimals: 0))
        • Net Income: $\(formatNumber(netIncome, decimals: 0))

        Result:
        • Profit Margin: \(formatPercent(margin))
        • Interpretation: \(interpretation)

        The company earns $\(formatNumber(margin)) in profit for every $1 of revenue,
        or \(formatNumber(margin * 100, decimals: 1)) cents per dollar.
        """

        return .success(text: output)
    }
}

// MARK: - 8. Return on Equity (ROE)

public struct ROETool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_roe",
        description: """
        Calculate Return on Equity (ROE).

        ROE measures how effectively management uses shareholders' equity to generate profits.
        Key metric for evaluating management performance and shareholder value creation.

        Formula: ROE = Net Income / Shareholder Equity

        Interpretation:
        • 20%+ : Excellent - High returns for shareholders
        • 15-20% : Strong - Above-average performance
        • 10-15% : Good - Acceptable returns
        • < 10% : Weak - May not meet shareholder expectations

        DuPont Analysis breaks ROE into: Profit Margin × Asset Turnover × Equity Multiplier

        Use Cases:
        • Shareholder value assessment
        • Management performance evaluation
        • Investment screening
        • Peer comparison

        Example: $500K net income on $2.5M equity = 20% ROE
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Net income for the period"
                ),
                "shareholderEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Average shareholder equity (book value)"
                )
            ],
            required: ["netIncome", "shareholderEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let netIncome = try args.getDouble("netIncome")
        let shareholderEquity = try args.getDouble("shareholderEquity")

        let roeValue: Double = roe(netIncome: netIncome, shareholderEquity: shareholderEquity)

        let interpretation: String
        if roeValue >= 0.20 {
            interpretation = "Excellent - High returns, strong shareholder value creation"
        } else if roeValue >= 0.15 {
            interpretation = "Strong - Above-average performance"
        } else if roeValue >= 0.10 {
            interpretation = "Good - Acceptable returns for shareholders"
        } else if roeValue >= 0 {
            interpretation = "Weak - Returns below typical shareholder expectations"
        } else {
            interpretation = "Negative - Company generating losses"
        }

        let output = """
        Return on Equity (ROE) Analysis:

        Inputs:
        • Net Income: $\(formatNumber(netIncome, decimals: 0))
        • Shareholder Equity: $\(formatNumber(shareholderEquity, decimals: 0))

        Result:
        • ROE: \(formatPercent(roeValue))
        • Interpretation: \(interpretation)

        The company generates $\(formatNumber(roeValue)) in profit for every $1 of shareholder equity,
        representing a \(formatNumber(roeValue * 100, decimals: 1))% return on invested capital.
        """

        return .success(text: output)
    }
}

// MARK: - 9. Return on Investment (ROI)

public struct ROITool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_roi",
        description: """
        Calculate Return on Investment (ROI).

        ROI measures the return generated on an investment relative to its cost.
        Universal metric for evaluating investment efficiency.

        Formula: ROI = Gain from Investment / Cost of Investment

        Can also be expressed as: (Gain - Cost) / Cost for percentage return.

        Interpretation:
        • 100%+ : Excellent - Investment more than doubled
        • 50-100% : Strong - Very good returns
        • 20-50% : Good - Solid returns
        • 0-20% : Modest - Positive but limited returns
        • < 0% : Loss - Investment lost value

        Use Cases:
        • Capital budgeting decisions
        • Marketing campaign evaluation
        • Equipment purchase analysis
        • Investment portfolio performance

        Example: $150K gain on $100K investment = 1.5 or 150% ROI
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "gainFromInvestment": MCPSchemaProperty(
                    type: "number",
                    description: "Total gain or return from the investment"
                ),
                "costOfInvestment": MCPSchemaProperty(
                    type: "number",
                    description: "Initial cost or amount invested"
                )
            ],
            required: ["gainFromInvestment", "costOfInvestment"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let gain = try args.getDouble("gainFromInvestment")
        let cost = try args.getDouble("costOfInvestment")

        let roiValue: Double = roi(gainFromInvestment: gain, costOfInvestment: cost)
        let netReturn = gain - cost
        let percentReturn = roiValue - 1.0

        let interpretation: String
        if roiValue >= 2.0 {
            interpretation = "Excellent - Investment more than doubled"
        } else if roiValue >= 1.5 {
            interpretation = "Strong - Very good returns achieved"
        } else if roiValue >= 1.2 {
            interpretation = "Good - Solid positive returns"
        } else if roiValue >= 1.0 {
            interpretation = "Modest - Positive but limited returns"
        } else {
            interpretation = "Loss - Investment did not return full principal"
        }

        let output = """
        Return on Investment (ROI) Analysis:

        Inputs:
        • Gain from Investment: $\(formatNumber(gain, decimals: 0))
        • Cost of Investment: $\(formatNumber(cost, decimals: 0))

        Calculation:
        • Net Return: $\(formatNumber(netReturn, decimals: 0))

        Result:
        • ROI: \(formatRatio(roiValue)) or \(formatPercent(percentReturn))
        • Interpretation: \(interpretation)

        The investment generated $\(formatNumber(roiValue)) for every $1 invested,
        representing a \(formatNumber(percentReturn * 100, decimals: 1))% return.
        """

        return .success(text: output)
    }
}
