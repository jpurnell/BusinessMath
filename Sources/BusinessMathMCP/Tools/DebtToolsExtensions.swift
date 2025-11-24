//
//  DebtToolsExtensions.swift
//  BusinessMath MCP Server
//
//  Extended debt and capital structure tools for BusinessMath MCP Server
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

private func formatPercent(_ value: Double, decimals: Int = 2) -> String {
    return formatNumber(value * 100, decimals: decimals) + "%"
}

// MARK: - Beta Levering

public struct BetaLeveringTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_beta_levering",
        description: """
        Calculate levered beta from unlevered beta.

        Levering the beta adjusts for the financial risk added by debt.
        Used in capital structure analysis and cost of equity calculations.

        Formula: Levered Beta = Unlevered Beta × [1 + (1 - Tax Rate) × (Debt / Equity)]

        Interpretation:
        • Levered Beta > Unlevered Beta (with debt)
        • Higher debt increases systematic risk (beta)
        • Used in CAPM to calculate cost of equity with leverage

        Use Cases:
        • Adjusting beta for capital structure changes
        • Cost of equity calculation for leveraged firms
        • Capital structure planning
        • Comparable company analysis

        Example: 1.0 unlevered beta, 40% tax, $2M debt, $3M equity = 1.4 levered beta
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "unleveredBeta": MCPSchemaProperty(
                    type: "number",
                    description: "Unlevered (asset) beta"
                ),
                "debtToEquityRatio": MCPSchemaProperty(
                    type: "number",
                    description: "Debt-to-equity ratio (D/E)"
                ),
                "taxRate": MCPSchemaProperty(
                    type: "number",
                    description: "Corporate tax rate as decimal (e.g., 0.25 for 25%)"
                )
            ],
            required: ["unleveredBeta", "debtToEquityRatio", "taxRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let unleveredBeta = try args.getDouble("unleveredBeta")
        let debtToEquity = try args.getDouble("debtToEquityRatio")
        let taxRate = try args.getDouble("taxRate")

        // Levered Beta = Unlevered Beta × [1 + (1 - Tax Rate) × D/E]
        let leveredBeta = unleveredBeta * (1 + (1 - taxRate) * debtToEquity)

        let riskIncrease = leveredBeta - unleveredBeta
        let percentIncrease = unleveredBeta > 0 ? (riskIncrease / unleveredBeta) * 100 : 0

        let output = """
        Beta Levering Analysis:

        Inputs:
        • Unlevered Beta: \(formatNumber(unleveredBeta, decimals: 3))
        • Debt-to-Equity Ratio: \(formatNumber(debtToEquity, decimals: 2))
        • Tax Rate: \(formatPercent(taxRate))

        Result:
        • Levered Beta: \(formatNumber(leveredBeta, decimals: 3))
        • Risk Increase: +\(formatNumber(riskIncrease, decimals: 3)) (\(formatNumber(percentIncrease, decimals: 1))%)

        Interpretation:
        Financial leverage increases systematic risk by \(formatNumber(percentIncrease, decimals: 1))%.
        The levered beta of \(formatNumber(leveredBeta, decimals: 2)) should be used in CAPM
        to calculate the cost of equity for this leveraged capital structure.

        Formula: βL = βU × [1 + (1 - Tc) × (D/E)]
        """

        return .success(text: output)
    }
}

// MARK: - Beta Unlevering

public struct BetaUnleveringTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_beta_unlevering",
        description: """
        Calculate unlevered beta from levered beta.

        Unlevering the beta removes the effect of financial leverage to isolate business risk.
        Used when comparing companies with different capital structures.

        Formula: Unlevered Beta = Levered Beta / [1 + (1 - Tax Rate) × (Debt / Equity)]

        Interpretation:
        • Unlevered Beta < Levered Beta (removes debt effect)
        • Represents pure business/operating risk
        • Useful for comparing companies across different leverage levels

        Use Cases:
        • Comparable company analysis
        • Removing leverage effects for comparison
        • Determining business risk
        • Asset beta estimation

        Example: 1.4 levered beta, 40% tax, $2M debt, $3M equity = 1.0 unlevered beta
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "leveredBeta": MCPSchemaProperty(
                    type: "number",
                    description: "Levered (equity) beta"
                ),
                "debtToEquityRatio": MCPSchemaProperty(
                    type: "number",
                    description: "Debt-to-equity ratio (D/E)"
                ),
                "taxRate": MCPSchemaProperty(
                    type: "number",
                    description: "Corporate tax rate as decimal (e.g., 0.25 for 25%)"
                )
            ],
            required: ["leveredBeta", "debtToEquityRatio", "taxRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let leveredBeta = try args.getDouble("leveredBeta")
        let debtToEquity = try args.getDouble("debtToEquityRatio")
        let taxRate = try args.getDouble("taxRate")

        // Unlevered Beta = Levered Beta / [1 + (1 - Tax Rate) × D/E]
        let denominator = 1 + (1 - taxRate) * debtToEquity
        guard denominator > 0 else {
            throw ToolError.invalidArguments("Invalid debt-to-equity ratio or tax rate")
        }

        let unleveredBeta = leveredBeta / denominator

        let riskReduction = leveredBeta - unleveredBeta
        let percentReduction = leveredBeta > 0 ? (riskReduction / leveredBeta) * 100 : 0

        let output = """
        Beta Unlevering Analysis:

        Inputs:
        • Levered Beta: \(formatNumber(leveredBeta, decimals: 3))
        • Debt-to-Equity Ratio: \(formatNumber(debtToEquity, decimals: 2))
        • Tax Rate: \(formatPercent(taxRate))

        Result:
        • Unlevered Beta: \(formatNumber(unleveredBeta, decimals: 3))
        • Risk Reduction: -\(formatNumber(riskReduction, decimals: 3)) (\(formatNumber(percentReduction, decimals: 1))%)

        Interpretation:
        Removing financial leverage reduces systematic risk by \(formatNumber(percentReduction, decimals: 1))%.
        The unlevered beta of \(formatNumber(unleveredBeta, decimals: 2)) represents pure business risk,
        independent of capital structure decisions.

        Use this for comparing companies with different leverage levels.

        Formula: βU = βL / [1 + (1 - Tc) × (D/E)]
        """

        return .success(text: output)
    }
}

// MARK: - Optimal Capital Structure

public struct OptimalCapitalStructureTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_capital_structure",
        description: """
        Find the optimal debt-to-equity ratio that minimizes WACC.

        The optimal capital structure balances tax benefits of debt against
        increased financial distress costs and higher cost of equity.

        This tool iterates through debt ratios to find the structure with minimum WACC.

        Assumptions:
        • Cost of debt increases with leverage
        • Cost of equity increases with leverage (via beta)
        • Tax shield provides debt benefit

        Interpretation:
        • Lower WACC = Higher firm value
        • Optimal D/E balances tax benefits vs. financial risk
        • Trade-off theory of capital structure

        Use Cases:
        • Capital structure planning
        • Firm valuation
        • Financing decisions
        • Strategic financial management

        Example: Testing D/E from 0 to 2.0 to find minimum WACC
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "unleveredBeta": MCPSchemaProperty(
                    type: "number",
                    description: "Unlevered beta (business risk)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate as decimal"
                ),
                "marketReturn": MCPSchemaProperty(
                    type: "number",
                    description: "Expected market return as decimal"
                ),
                "baseDebtCost": MCPSchemaProperty(
                    type: "number",
                    description: "Base cost of debt at low leverage as decimal"
                ),
                "taxRate": MCPSchemaProperty(
                    type: "number",
                    description: "Corporate tax rate as decimal"
                ),
                "firmValue": MCPSchemaProperty(
                    type: "number",
                    description: "Total firm value for calculating absolute amounts"
                )
            ],
            required: ["unleveredBeta", "riskFreeRate", "marketReturn", "baseDebtCost", "taxRate", "firmValue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let unleveredBeta = try args.getDouble("unleveredBeta")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let marketReturn = try args.getDouble("marketReturn")
        let baseDebtCost = try args.getDouble("baseDebtCost")
        let taxRate = try args.getDouble("taxRate")
        let firmValue = try args.getDouble("firmValue")

        // Test debt-to-equity ratios from 0 to 2.5 in 0.1 increments
        var optimalDE: Double = 0
        var minWACC: Double = Double.infinity
        var optimalResults: (costOfEquity: Double, costOfDebt: Double, equityWeight: Double, debtWeight: Double)? = nil

        for i in 0...25 {
            let de = Double(i) * 0.1

            // Calculate levered beta
            let leveredBeta = unleveredBeta * (1 + (1 - taxRate) * de)

            // Calculate cost of equity using CAPM
            let costOfEquity = riskFreeRate + leveredBeta * (marketReturn - riskFreeRate)

            // Cost of debt increases with leverage (simple linear model)
            let costOfDebt = baseDebtCost * (1 + de * 0.2)

            // Calculate weights
            let equityWeight = 1.0 / (1.0 + de)
            let debtWeight = de / (1.0 + de)

            // Calculate WACC
            let waccValue = (equityWeight * costOfEquity) + (debtWeight * costOfDebt * (1 - taxRate))

            if waccValue < minWACC {
                minWACC = waccValue
                optimalDE = de
                optimalResults = (costOfEquity, costOfDebt, equityWeight, debtWeight)
            }
        }

        guard let results = optimalResults else {
            throw ToolError.executionFailed("optimize_capital_structure", "Could not find optimal structure")
        }

        let optimalDebt = firmValue * results.debtWeight
        let optimalEquity = firmValue * results.equityWeight

        let output = """
        Optimal Capital Structure Analysis:

        Optimal Structure:
        • Debt-to-Equity Ratio: \(formatNumber(optimalDE, decimals: 2))
        • Debt Weight: \(formatPercent(results.debtWeight))
        • Equity Weight: \(formatPercent(results.equityWeight))

        For Firm Value of $\(formatNumber(firmValue, decimals: 0)):
        • Optimal Debt: $\(formatNumber(optimalDebt, decimals: 0))
        • Optimal Equity: $\(formatNumber(optimalEquity, decimals: 0))

        Cost Components:
        • Cost of Equity: \(formatPercent(results.costOfEquity))
        • Cost of Debt (before tax): \(formatPercent(results.costOfDebt))
        • After-Tax Cost of Debt: \(formatPercent(results.costOfDebt * (1 - taxRate)))

        Minimum WACC: \(formatPercent(minWACC))

        Interpretation:
        This capital structure minimizes the weighted average cost of capital,
        maximizing firm value by balancing the tax benefits of debt against
        the increased costs of financial distress and higher equity costs.

        Note: This is a simplified model. Real-world optimization should consider
        industry norms, financial flexibility, and specific business risks.
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns extended debt and capital structure tools
public func getExtendedDebtTools() -> [any MCPToolHandler] {
    return [
        BetaLeveringTool(),
        BetaUnleveringTool(),
        OptimalCapitalStructureTool()
    ]
}
