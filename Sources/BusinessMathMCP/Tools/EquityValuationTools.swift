//
//  EquityValuationTools.swift
//  BusinessMath MCP Server
//
//  MCP tools for equity (stock) valuation models
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all equity valuation tools
public func getEquityValuationTools() -> [any MCPToolHandler] {
    return [
        FCFEModelTool(),
        GordonGrowthModelTool(),
        TwoStageDDMTool(),
        EnterpriseValueBridgeTool(),
        ResidualIncomeModelTool()
    ]
}

// MARK: - FCFE Model Tool

public struct FCFEModelTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_equity_fcfe",
        description: """
        Value equity using Free Cash Flow to Equity (FCFE) Model.

        FCFE represents the cash available to equity holders after all expenses,
        reinvestment, and debt obligations. This is the most comprehensive
        approach to equity valuation.

        Formula: Equity Value = PV(FCFE₁, FCFE₂, ..., FCFEₙ + Terminal Value)

        When to Use:
        • Companies with predictable cash flows
        • Capital-intensive businesses
        • When dividends don't reflect true cash generation
        • Companies with changing capital structure

        Advantages:
        • Not affected by dividend policy
        • Captures full cash generation potential
        • Considers reinvestment needs

        Example: Tech company with $50M FCFE growing 15% for 5 years,
        then 4% perpetually, 10% cost of equity = $625M equity value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentFCFE": MCPSchemaProperty(
                    type: "number",
                    description: "Current year Free Cash Flow to Equity"
                ),
                "highGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Expected high growth rate (as decimal, e.g., 0.15 for 15%)"
                ),
                "highGrowthPeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of high growth years"
                ),
                "terminalGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Perpetual growth rate after high growth phase (as decimal)"
                ),
                "costOfEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Required return/discount rate (as decimal)"
                )
            ],
            required: ["currentFCFE", "highGrowthRate", "highGrowthPeriods",
                      "terminalGrowthRate", "costOfEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let currentFCFE = try args.getDouble("currentFCFE")
        let highGrowthRate = try args.getDouble("highGrowthRate")
        let highGrowthPeriods = try args.getInt("highGrowthPeriods")
        let terminalGrowthRate = try args.getDouble("terminalGrowthRate")
        let costOfEquity = try args.getDouble("costOfEquity")

        // Calculate present value of high growth period cash flows
        var pvHighGrowth = 0.0
        var fcfe = currentFCFE
        for t in 1...highGrowthPeriods {
            fcfe = fcfe * (1 + highGrowthRate)
            let discountFactor = pow(1 + costOfEquity, Double(t))
            pvHighGrowth += fcfe / discountFactor
        }

        // Calculate terminal value using Gordon Growth Model
        let terminalFCFE = fcfe * (1 + terminalGrowthRate)
        let terminalValue = terminalFCFE / (costOfEquity - terminalGrowthRate)
        let pvTerminalValue = terminalValue / pow(1 + costOfEquity, Double(highGrowthPeriods))

        // Total equity value
        let equityValue = pvHighGrowth + pvTerminalValue

        // Calculate value per share if shares provided
        let sharesOutstanding = try? args.getDouble("sharesOutstanding")

        var result = """
        FCFE Valuation Results
        ======================

        Inputs:
          Current FCFE: \(formatCurrency(currentFCFE))
          High Growth Rate: \(formatPercent(highGrowthRate))
          High Growth Period: \(highGrowthPeriods) years
          Terminal Growth Rate: \(formatPercent(terminalGrowthRate))
          Cost of Equity: \(formatPercent(costOfEquity))

        Valuation:
          Total Equity Value: \(formatCurrency(equityValue))
        """

        if let shares = sharesOutstanding {
            let valuePerShare = equityValue / shares
            result += """

              Shares Outstanding: \(formatNumber(shares, decimals: 0))
              Value Per Share: \(formatCurrency(valuePerShare, decimals: 2))
            """
        }

        result += """


        Interpretation:
        • FCFE model values equity based on distributable cash flows
        • High growth phase captures expansion period
        • Terminal value represents perpetual mature phase
        • Cost of equity reflects risk-adjusted required return
        """

        return .success(text: result)
    }
}

// MARK: - Gordon Growth Model Tool

public struct GordonGrowthModelTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_equity_gordon_growth",
        description: """
        Value equity using Gordon Growth Model (Constant Growth DDM).

        The Gordon Growth Model values a stock based on expected dividends
        growing at a constant rate forever. Best for mature, stable companies.

        Formula: Value = D₁ / (r - g)
        Where: D₁ = next year's dividend, r = required return, g = growth rate

        When to Use:
        • Mature companies with stable dividends
        • Utilities, consumer staples, REITs
        • Companies with predictable payout policies
        • Growth rate < required return

        Limitations:
        • Requires stable dividend growth
        • Not suitable for high-growth companies
        • Growth rate must be less than discount rate
        • Ignores non-dividend cash flows

        Example: Utility paying $2.50 dividend, 4% growth, 9% required return
        = $52.50 per share.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dividendPerShare": MCPSchemaProperty(
                    type: "number",
                    description: "Current annual dividend per share"
                ),
                "growthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Expected constant dividend growth rate (as decimal)"
                ),
                "requiredReturn": MCPSchemaProperty(
                    type: "number",
                    description: "Required return/cost of equity (as decimal)"
                )
            ],
            required: ["dividendPerShare", "growthRate", "requiredReturn"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dividend = try args.getDouble("dividendPerShare")
        let growthRate = try args.getDouble("growthRate")
        let requiredReturn = try args.getDouble("requiredReturn")

        // Validate: growth rate must be less than required return
        guard growthRate < requiredReturn else {
            throw ToolError.invalidArguments(
                "Growth rate (\(formatPercent(growthRate))) must be less than required return (\(formatPercent(requiredReturn)))"
            )
        }

        let model = GordonGrowthModel(
            dividendPerShare: dividend,
            growthRate: growthRate,
            requiredReturn: requiredReturn
        )

        let valuePerShare = model.valuePerShare()
        let nextDividend = dividend * (1 + growthRate)
        let dividendYield = dividend / valuePerShare

        let result = """
        Gordon Growth Model Results
        ============================

        Inputs:
          Current Dividend: \(formatCurrency(dividend, decimals: 2))/share
          Growth Rate: \(formatPercent(growthRate))
          Required Return: \(formatPercent(requiredReturn))

        Valuation:
          Next Year Dividend (D₁): \(formatCurrency(nextDividend, decimals: 2))
          Intrinsic Value: \(formatCurrency(valuePerShare, decimals: 2))/share
          Current Dividend Yield: \(formatPercent(dividendYield))

        Interpretation:
        • Value = D₁ / (r - g) = \(formatCurrency(nextDividend, decimals: 2)) / (\(formatPercent(requiredReturn)) - \(formatPercent(growthRate)))
        • Model assumes perpetual constant growth
        • Best for mature, stable dividend payers
        • Compare to market price to assess value
        """

        return .success(text: result)
    }
}

// MARK: - Two-Stage DDM Tool

public struct TwoStageDDMTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_equity_two_stage_ddm",
        description: """
        Value equity using Two-Stage Dividend Discount Model.

        Models companies transitioning from high growth to stable maturity.
        Uses high growth rate for initial periods, then stable perpetual growth.

        When to Use:
        • Growth companies transitioning to maturity
        • Tech companies maturing their business
        • Companies with predictable lifecycle
        • When single growth rate is unrealistic

        Advantages:
        • More realistic than constant growth
        • Captures transition period
        • Flexible growth assumptions

        Example: Tech stock, $1.00 dividend, 20% growth for 5 years,
        then 5% forever, 12% required return = $19.24 per share.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentDividend": MCPSchemaProperty(
                    type: "number",
                    description: "Current annual dividend per share"
                ),
                "highGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "High growth rate for initial period (as decimal)"
                ),
                "highGrowthPeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of high growth years"
                ),
                "stableGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Perpetual stable growth rate (as decimal)"
                ),
                "requiredReturn": MCPSchemaProperty(
                    type: "number",
                    description: "Required return/cost of equity (as decimal)"
                )
            ],
            required: ["currentDividend", "highGrowthRate", "highGrowthPeriods",
                      "stableGrowthRate", "requiredReturn"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let currentDividend = try args.getDouble("currentDividend")
        let highGrowthRate = try args.getDouble("highGrowthRate")
        let highGrowthPeriods = try args.getInt("highGrowthPeriods")
        let stableGrowthRate = try args.getDouble("stableGrowthRate")
        let requiredReturn = try args.getDouble("requiredReturn")

        let model = TwoStageDDM(
            currentDividend: currentDividend,
            highGrowthRate: highGrowthRate,
            highGrowthPeriods: highGrowthPeriods,
            stableGrowthRate: stableGrowthRate,
            requiredReturn: requiredReturn
        )

        let valuePerShare = model.valuePerShare()

        let result = """
        Two-Stage DDM Results
        =====================

        Inputs:
          Current Dividend: \(formatCurrency(currentDividend, decimals: 2))/share
          High Growth Rate: \(formatPercent(highGrowthRate))
          High Growth Period: \(highGrowthPeriods) years
          Stable Growth Rate: \(formatPercent(stableGrowthRate))
          Required Return: \(formatPercent(requiredReturn))

        Valuation:
          Intrinsic Value: \(formatCurrency(valuePerShare, decimals: 2))/share

        Interpretation:
        • Phase 1: \(highGrowthPeriods) years of \(formatPercent(highGrowthRate)) growth
        • Phase 2: Perpetual \(formatPercent(stableGrowthRate)) growth
        • Model captures transition from growth to maturity
        • Suitable for companies with predictable lifecycle
        """

        return .success(text: result)
    }
}

// MARK: - Enterprise Value Bridge Tool

public struct EnterpriseValueBridgeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_equity_ev_bridge",
        description: """
        Calculate equity value from enterprise value.

        Bridges from firm value (EV) to equity value by adjusting for
        capital structure. Essential for comparing valuations across
        companies with different leverage.

        Formula: Equity Value = EV - Net Debt + Non-Operating Assets
        Where: Net Debt = Debt - Cash

        When to Use:
        • Starting from EV/EBITDA or EV/Sales multiples
        • Comparing companies with different capital structures
        • LBO/M&A analysis
        • Capital structure changes

        Example: $500M EV, $100M debt, $20M cash, $30M investments
        = $450M equity value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "enterpriseValue": MCPSchemaProperty(
                    type: "number",
                    description: "Enterprise value (value of entire firm)"
                ),
                "totalDebt": MCPSchemaProperty(
                    type: "number",
                    description: "Total debt (short-term + long-term)"
                ),
                "cash": MCPSchemaProperty(
                    type: "number",
                    description: "Cash and cash equivalents"
                ),
                "nonOperatingAssets": MCPSchemaProperty(
                    type: "number",
                    description: "Non-operating assets (investments, etc.) (default: 0.0)"
                ),
                "minorityInterest": MCPSchemaProperty(
                    type: "number",
                    description: "Minority interest to subtract (default: 0.0)"
                ),
                "preferredStock": MCPSchemaProperty(
                    type: "number",
                    description: "Preferred stock value to subtract (default: 0.0)"
                ),
                "sharesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Shares outstanding (optional for per-share value)"
                )
            ],
            required: ["enterpriseValue", "totalDebt", "cash"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let enterpriseValue = try args.getDouble("enterpriseValue")
        let totalDebt = try args.getDouble("totalDebt")
        let cash = try args.getDouble("cash")
        let nonOperatingAssets = (try? args.getDouble("nonOperatingAssets")) ?? 0.0
        let minorityInterest = (try? args.getDouble("minorityInterest")) ?? 0.0
        let preferredStock = (try? args.getDouble("preferredStock")) ?? 0.0

        let bridge = EnterpriseValueBridge(
            enterpriseValue: enterpriseValue,
            totalDebt: totalDebt,
            cash: cash,
            nonOperatingAssets: nonOperatingAssets,
            minorityInterest: minorityInterest,
            preferredStock: preferredStock
        )

        let breakdown = bridge.breakdown()
        let equityValue = bridge.equityValue()

        var result = """
        Enterprise Value Bridge
        =======================

        Enterprise Value          \(formatCurrency(enterpriseValue))
        Less: Total Debt          (\(formatCurrency(totalDebt)))
        Add: Cash                 \(formatCurrency(cash))
        """

        if nonOperatingAssets > 0 {
            result += "\nAdd: Non-Operating Assets \(formatCurrency(nonOperatingAssets))"
        }
        if minorityInterest > 0 {
            result += "\nLess: Minority Interest   (\(formatCurrency(minorityInterest)))"
        }

        result += """

                                  ─────────────────
        Equity Value              \(formatCurrency(equityValue))
        """

        if let shares = try? args.getDouble("sharesOutstanding") {
            let valuePerShare = equityValue / shares
            result += """


            Per Share Value:
              Shares Outstanding: \(formatNumber(shares, decimals: 0))
              Value Per Share: \(formatCurrency(valuePerShare, decimals: 2))
            """
        }

        result += """


        Breakdown:
          Net Debt: \(formatCurrency(breakdown.netDebt))
          Non-Operating Assets: \(formatCurrency(breakdown.nonOperatingAssets))
          Minority Interest: \(formatCurrency(breakdown.minorityInterest))
          Preferred Stock: \(formatCurrency(breakdown.preferredStock))

        Interpretation:
        • EV represents value to all investors (debt + equity)
        • Subtract net debt to isolate equity value
        • Add back non-operating assets owned by equity
        • Essential for cross-company comparisons
        """

        return .success(text: result)
    }
}

// MARK: - Residual Income Model Tool

public struct ResidualIncomeModelTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "value_equity_residual_income",
        description: """
        Value equity using Residual Income Model.

        Values equity based on book value plus present value of excess returns
        (returns above cost of equity). Best for financial institutions and
        companies where book value is meaningful.

        Formula: Value = Book Value + PV(Residual Income)
        Where: RI = Net Income - (Book Value × Cost of Equity)

        When to Use:
        • Financial institutions (banks, insurance)
        • Companies with meaningful book values
        • Negative free cash flow companies
        • Asset-heavy businesses

        Advantages:
        • Doesn't require positive cash flows
        • Uses accounting data directly
        • Captures value creation above cost of capital

        Example: $1,000 book value, $150 net income, 12% cost of equity,
        5% RI growth = $1,250 equity value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "currentBookValue": MCPSchemaProperty(
                    type: "number",
                    description: "Current book value of equity"
                ),
                "netIncome": MCPSchemaProperty(
                    type: "number",
                    description: "Expected net income for next year"
                ),
                "futureBookValue": MCPSchemaProperty(
                    type: "number",
                    description: "Expected book value for next year"
                ),
                "costOfEquity": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of equity/required return (as decimal)"
                ),
                "terminalGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Expected perpetual growth rate of residual income (as decimal)"
                ),
                "sharesOutstanding": MCPSchemaProperty(
                    type: "number",
                    description: "Shares outstanding (optional for per-share value)"
                )
            ],
            required: ["currentBookValue", "netIncome", "futureBookValue",
                      "costOfEquity", "terminalGrowthRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let currentBookValue = try args.getDouble("currentBookValue")
        let netIncomeValue = try args.getDouble("netIncome")
        let futureBookValue = try args.getDouble("futureBookValue")
        let costOfEquity = try args.getDouble("costOfEquity")
        let terminalGrowthRate = try args.getDouble("terminalGrowthRate")

        // Create single-period time series for the model
        let periods = [Period.year(2024)]
        let netIncome = TimeSeries(periods: periods, values: [netIncomeValue])
        let bookValue = TimeSeries(periods: periods, values: [futureBookValue])

        let model = ResidualIncomeModel(
            currentBookValue: currentBookValue,
            netIncome: netIncome,
            bookValue: bookValue,
            costOfEquity: costOfEquity,
            terminalGrowthRate: terminalGrowthRate
        )

        let equityValue = model.equityValue()
        let residualIncomeValue = model.residualIncome().valuesArray.first ?? 0.0
        let pvRI = equityValue - currentBookValue

        var result = """
        Residual Income Model Results
        ==============================

        Inputs:
          Current Book Value: \(formatCurrency(currentBookValue))
          Net Income: \(formatCurrency(netIncomeValue))
          Future Book Value: \(formatCurrency(futureBookValue))
          Cost of Equity: \(formatPercent(costOfEquity))
          Terminal Growth Rate: \(formatPercent(terminalGrowthRate))

        Calculation:
          Normal Return: \(formatCurrency(currentBookValue * costOfEquity))
          Net Income: \(formatCurrency(netIncomeValue))
          Residual Income: \(formatCurrency(residualIncomeValue))

        Valuation:
          Current Book Value: \(formatCurrency(currentBookValue))
          PV(Residual Income): \(formatCurrency(pvRI))
                              ─────────────────
          Equity Value: \(formatCurrency(equityValue))
        """

        if let shares = try? args.getDouble("sharesOutstanding") {
            let valuePerShare = equityValue / shares
            let bookValuePerShare = currentBookValue / shares
            let priceToBook = valuePerShare / bookValuePerShare

            result += """


            Per Share Analysis:
              Shares Outstanding: \(formatNumber(shares, decimals: 0))
              Book Value/Share: \(formatCurrency(bookValuePerShare, decimals: 2))
              Intrinsic Value/Share: \(formatCurrency(valuePerShare, decimals: 2))
              Implied P/B Ratio: \(formatRatio(priceToBook))
            """
        }

        result += """


        Interpretation:
        • RI = \(formatCurrency(netIncomeValue)) - (\(formatCurrency(currentBookValue)) × \(formatPercent(costOfEquity)))
        • Positive RI means returns exceed cost of capital
        • Model values excess returns above normal return
        • Best for asset-heavy or financial companies
        """

        return .success(text: result)
    }
}

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatCurrency(_ value: Double, decimals: Int = 0) -> String {
    if abs(value) >= 1_000_000_000 {
        return "$" + formatNumber(value / 1_000_000_000, decimals: 2) + "B"
    } else if abs(value) >= 1_000_000 {
        return "$" + formatNumber(value / 1_000_000, decimals: 2) + "M"
    } else if abs(value) >= 1_000 {
        return "$" + formatNumber(value / 1_000, decimals: 1) + "K"
    } else {
        return "$" + formatNumber(value, decimals: decimals)
    }
}

private func formatRatio(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value, decimals: decimals) + "x"
}

private func formatPercent(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value * 100, decimals: decimals) + "%"
}
