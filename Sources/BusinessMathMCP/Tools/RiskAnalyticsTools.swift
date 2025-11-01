import Foundation
import MCP
import BusinessMath

// MARK: - Stress Test Tool

public struct StressTestTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_stress_test",
        description: """
        Run stress tests on financial metrics using pre-defined or custom scenarios. Evaluates how business performs under adverse conditions like recession, financial crisis, or supply shocks.

        Example: Test baseline metrics against recession
        - scenario: "recession" (options: "recession", "crisis", "supplyShock", "custom")
        - baseRevenue: 10000000
        - baseCosts: 7000000
        - baseNPV: 5000000
        - customShocks: {"Revenue": -0.20, "COGS": 0.15} (only for custom scenario)

        Returns stressed values and impact analysis.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "scenario": MCPSchemaProperty(
                    type: "string",
                    description: "Stress scenario to apply",
                    enum: ["recession", "crisis", "supplyShock", "custom"]
                ),
                "baseRevenue": MCPSchemaProperty(
                    type: "number",
                    description: "Baseline revenue"
                ),
                "baseCosts": MCPSchemaProperty(
                    type: "number",
                    description: "Baseline costs/COGS"
                ),
                "baseNPV": MCPSchemaProperty(
                    type: "number",
                    description: "Baseline NPV or profit"
                ),
                "customShocks": MCPSchemaProperty(
                    type: "object",
                    description: "Custom shocks as percent changes (e.g., {\"Revenue\": -0.20, \"COGS\": 0.10}) - only used if scenario is 'custom'"
                )
            ],
            required: ["scenario", "baseRevenue", "baseCosts", "baseNPV"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let scenarioName = try args.getString("scenario")
        let baseRevenue = try args.getDouble("baseRevenue")
        let baseCosts = try args.getDouble("baseCosts")
        let baseNPV = try args.getDouble("baseNPV")

        // Define scenario shocks
        let shocks: (revenue: Double, costs: Double, description: String)
        switch scenarioName {
        case "recession":
            shocks = (revenue: -0.15, costs: 0.05, description: "Moderate economic downturn")
        case "crisis":
            shocks = (revenue: -0.30, costs: 0.10, description: "Severe financial crisis (2008-style)")
        case "supplyShock":
            shocks = (revenue: -0.05, costs: 0.25, description: "Major supply chain disruption")
        case "custom":
            // Parse custom shocks
            guard let customShocksValue = args["customShocks"],
                  let customShocksDict = customShocksValue.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("customShocks required for custom scenario")
            }
            let revenueShock = (customShocksDict["Revenue"]?.value as? Double) ?? 0.0
            let costsShock = (customShocksDict["COGS"]?.value as? Double) ?? (customShocksDict["Costs"]?.value as? Double) ?? 0.0
            shocks = (revenue: revenueShock, costs: costsShock, description: "Custom scenario")
        default:
            throw ToolError.invalidArguments("Invalid scenario: \(scenarioName)")
        }

        // Apply shocks
        let stressedRevenue = baseRevenue * (1 + shocks.revenue)
        let stressedCosts = baseCosts * (1 + shocks.costs)
        let stressedNPV = stressedRevenue - stressedCosts  // Simplified

        let revenueImpact = stressedRevenue - baseRevenue
        let costsImpact = stressedCosts - baseCosts
        let npvImpact = stressedNPV - baseNPV
        let npvImpactPercent = (npvImpact / baseNPV) * 100

        let result = """
        Stress Test Results

        Scenario: \(scenarioName.uppercased())
        Description: \(shocks.description)

        Baseline Metrics:
        - Revenue: $\(String(format: "%.0f", baseRevenue))
        - Costs: $\(String(format: "%.0f", baseCosts))
        - NPV/Profit: $\(String(format: "%.0f", baseNPV))

        Applied Shocks:
        - Revenue: \(String(format: "%+.0f%%", shocks.revenue * 100))
        - Costs: \(String(format: "%+.0f%%", shocks.costs * 100))

        Stressed Metrics:
        - Revenue: $\(String(format: "%.0f", stressedRevenue)) (\(String(format: "%+.0f", revenueImpact)))
        - Costs: $\(String(format: "%.0f", stressedCosts)) (\(String(format: "%+.0f", costsImpact)))
        - NPV/Profit: $\(String(format: "%.0f", stressedNPV)) (\(String(format: "%+.0f", npvImpact)))

        Impact Analysis:
        - NPV Impact: \(String(format: "%+.0f%%", npvImpactPercent))
        - \(stressedNPV > 0 ? "Project remains viable" : "⚠️ Project becomes unprofitable")
        - \(abs(npvImpactPercent) > 50 ? "⚠️ HIGH SENSITIVITY - material risk" : "Moderate sensitivity")

        Risk Assessment:
        \(abs(npvImpactPercent) < 20 ? "✓ Low risk - project resilient to this scenario" :
          abs(npvImpactPercent) < 50 ? "⚠ Moderate risk - monitor key assumptions" :
          "⚠️ High risk - consider contingency planning")

        Recommendations:
        \(stressedNPV < 0 ? "• Develop mitigation strategies\n• Increase cash reserves\n• Consider hedging strategies" :
          "• Monitor early warning indicators\n• Maintain operational flexibility\n• Regular stress test updates")
        """

        return .success(text: result)
    }
}

// MARK: - Value at Risk Tool

public struct ValueAtRiskTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_value_at_risk",
        description: """
        Calculate Value at Risk (VaR) and Conditional VaR (CVaR) from historical returns. VaR measures maximum expected loss at a confidence level.

        Example: Calculate 95% VaR for portfolio
        - returns: [0.08, 0.05, -0.02, 0.10, -0.01, 0.07, 0.04, ...]  (historical returns)
        - portfolioValue: 1000000
        - confidenceLevel: 0.95 (95% confidence)

        Returns VaR, CVaR, and interpretation.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns as decimal values (e.g., 0.08 for 8%)",
                    items: MCPSchemaItems(type: "number")
                ),
                "portfolioValue": MCPSchemaProperty(
                    type: "number",
                    description: "Current portfolio value"
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (e.g., 0.95 for 95%, 0.99 for 99%)"
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate for Sharpe/Sortino calculations (default: 0)"
                )
            ],
            required: ["returns", "portfolioValue", "confidenceLevel"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let returns = try args.getDoubleArray("returns")
        let portfolioValue = try args.getDouble("portfolioValue")
        let confidenceLevel = try args.getDouble("confidenceLevel")
        let riskFreeRate = args.getDoubleOptional("riskFreeRate") ?? 0.0

        // Create TimeSeries
        let periods = (1...returns.count).map { Period.day(Date().addingTimeInterval(Double($0) * 86400)) }
        let timeSeries = TimeSeries(periods: periods, values: returns)

        // Calculate risk metrics
        let riskMetrics = ComprehensiveRiskMetrics(
            returns: timeSeries,
            riskFreeRate: riskFreeRate
        )

        // Get VaR and CVaR based on confidence level
        let var95 = riskMetrics.var95
        let var99 = riskMetrics.var99
        let cvar95 = riskMetrics.cvar95

        let var95Loss = abs(var95) * portfolioValue
        let var99Loss = abs(var99) * portfolioValue
        let cvarLoss = abs(cvar95) * portfolioValue

        let result = """
        Value at Risk (VaR) Analysis

        Portfolio: $\(String(format: "%.0f", portfolioValue))
        Historical Periods: \(returns.count)
        Confidence Level: \(String(format: "%.0f%%", confidenceLevel * 100))

        VaR Metrics:
        • 95% VaR: \(String(format: "%.2f%%", var95 * 100))
          → Maximum loss: $\(String(format: "%.0f", var95Loss))
          → Interpretation: 95% confident loss won't exceed this

        • 99% VaR: \(String(format: "%.2f%%", var99 * 100))
          → Maximum loss: $\(String(format: "%.0f", var99Loss))
          → Interpretation: 99% confident loss won't exceed this

        • CVaR (95%): \(String(format: "%.2f%%", cvar95 * 100))
          → Expected loss in worst 5%: $\(String(format: "%.0f", cvarLoss))
          → Interpretation: Average loss when in the tail

        Additional Risk Metrics:
        • Maximum Drawdown: \(String(format: "%.2f%%", riskMetrics.maxDrawdown * 100))
        • Sharpe Ratio: \(String(format: "%.3f", riskMetrics.sharpeRatio))
        • Sortino Ratio: \(String(format: "%.3f", riskMetrics.sortinoRatio))
        • Tail Risk Ratio: \(String(format: "%.3f", riskMetrics.tailRisk))
        • Skewness: \(String(format: "%.3f", riskMetrics.skewness))
        • Kurtosis: \(String(format: "%.3f", riskMetrics.kurtosis))

        Risk Profile Assessment:
        \(riskMetrics.maxDrawdown < 0.10 ? "✓ Low risk - small drawdowns" :
          riskMetrics.maxDrawdown < 0.20 ? "⚠ Moderate risk - manageable drawdowns" :
          "⚠️ High risk - significant drawdowns observed")

        \(riskMetrics.skewness < -0.5 ? "⚠️ Negative skew - rare large losses possible" :
          riskMetrics.skewness > 0.5 ? "✓ Positive skew - rare large gains possible" :
          "Roughly symmetric return distribution")

        \(riskMetrics.kurtosis > 1.0 ? "⚠️ Fat tails - more extreme events than normal distribution" :
          "Normal tail behavior")

        Risk Management Recommendations:
        • Set stop-loss at 95% VaR: $\(String(format: "%.0f", var95Loss))
        • Reserve for tail events: $\(String(format: "%.0f", cvarLoss))
        • Monitor drawdown limit: \(String(format: "%.0f%%", riskMetrics.maxDrawdown * 100))
        • \(riskMetrics.tailRisk > 1.3 ? "Consider tail risk hedging" : "Tail risk manageable")
        """

        return .success(text: result)
    }
}

// MARK: - Risk Aggregation Tool

public struct AggregateRiskTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "aggregate_portfolio_risk",
        description: """
        Aggregate VaR across multiple portfolios accounting for correlations. Reveals diversification benefits from imperfect correlations.

        Example: Combine 3 portfolio VaRs
        - portfolioVaRs: [100000, 150000, 200000]
        - portfolioNames: ["Equities", "Fixed Income", "Alternatives"]
        - correlations: [[1.0, 0.6, 0.4], [0.6, 1.0, 0.5], [0.4, 0.5, 1.0]]
        - weights: [0.4, 0.3, 0.3] (optional, for component VaR)

        Returns aggregated VaR, diversification benefit, and marginal VaR.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "portfolioVaRs": MCPSchemaProperty(
                    type: "array",
                    description: "Individual portfolio VaRs",
                    items: MCPSchemaItems(type: "number")
                ),
                "portfolioNames": MCPSchemaProperty(
                    type: "array",
                    description: "Names of portfolios (optional)",
                    items: MCPSchemaItems(type: "string")
                ),
                "correlations": MCPSchemaProperty(
                    type: "array",
                    description: "Correlation matrix (NxN array of arrays)",
                    items: MCPSchemaItems(type: "array")
                ),
                "weights": MCPSchemaProperty(
                    type: "array",
                    description: "Portfolio weights for component VaR (optional, sums to 1.0)",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["portfolioVaRs", "correlations"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let portfolioVaRs = try args.getDoubleArray("portfolioVaRs")

        // Parse correlation matrix
        guard let correlationsValue = args["correlations"],
              let correlationsArray = correlationsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("correlations must be an array of arrays")
        }

        var correlations: [[Double]] = []
        for rowValue in correlationsArray {
            guard let rowArray = rowValue.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each correlation row must be an array")
            }

            var row: [Double] = []
            for cellValue in rowArray {
                if let doubleVal = cellValue.value as? Double {
                    row.append(doubleVal)
                } else if let intVal = cellValue.value as? Int {
                    row.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("Correlation values must be numbers")
                }
            }
            correlations.append(row)
        }

        // Get optional names and weights
        let names = try? args.getStringArray("portfolioNames")
        let portfolioNames = names ?? (1...portfolioVaRs.count).map { "Portfolio \($0)" }

        // Aggregate VaR
        let aggregatedVaR = RiskAggregator<Double>.aggregateVaR(
            individualVaRs: portfolioVaRs,
            correlations: correlations
        )

        let simpleSum = portfolioVaRs.reduce(0, +)
        let diversificationBenefit = simpleSum - aggregatedVaR
        let diversificationPercent = (diversificationBenefit / simpleSum) * 100

        var result = """
        Portfolio Risk Aggregation

        Individual Portfolio VaRs:
        """

        for (i, varValue) in portfolioVaRs.enumerated() {
            result += "\n  \(portfolioNames[i]): $\(String(format: "%.0f", varValue))"
        }

        result += """


        Aggregation Results:
        • Simple Sum: $\(String(format: "%.0f", simpleSum))
        • Aggregated VaR: $\(String(format: "%.0f", aggregatedVaR))
        • Diversification Benefit: $\(String(format: "%.0f", diversificationBenefit)) (\(String(format: "%.1f%%", diversificationPercent)))

        Interpretation:
        Due to imperfect correlations, the combined portfolio risk is
        $\(String(format: "%.0f", diversificationBenefit)) LESS than the simple sum.
        This is a \(String(format: "%.1f%%", diversificationPercent)) reduction in risk from diversification.

        Marginal VaR (Risk Contribution):
        """

        for i in 0..<portfolioVaRs.count {
            let marginalVaR = RiskAggregator<Double>.marginalVaR(
                entity: i,
                individualVaRs: portfolioVaRs,
                correlations: correlations
            )
            let contribution = (marginalVaR / aggregatedVaR) * 100

            result += "\n  \(portfolioNames[i]):"
            result += "\n    Individual VaR: $\(String(format: "%.0f", portfolioVaRs[i]))"
            result += "\n    Marginal VaR: $\(String(format: "%.0f", marginalVaR))"
            result += "\n    Contribution: \(String(format: "%.1f%%", contribution)) of total risk"
        }

        // Component VaR if weights provided
        if let weightsArray = try? args.getDoubleArray("weights") {
            result += "\n\nComponent VaR (Weighted Contributions):"

            let componentVaRs = RiskAggregator<Double>.componentVaR(
                individualVaRs: portfolioVaRs,
                weights: weightsArray,
                correlations: correlations
            )

            for i in 0..<portfolioVaRs.count {
                result += "\n  \(portfolioNames[i]): $\(String(format: "%.0f", componentVaRs[i])) (weight: \(String(format: "%.1f%%", weightsArray[i] * 100)))"
            }

            let totalComponent = componentVaRs.reduce(0, +)
            result += "\n\n  Sum of components: $\(String(format: "%.0f", totalComponent))"
            result += "\n  (Should equal aggregated VaR: $\(String(format: "%.0f", aggregatedVaR)))"
        }

        result += """


        Key Insights:
        • Lower correlation = higher diversification benefit
        • Marginal VaR shows incremental risk contribution
        • Use this to identify risk concentrations
        • \(diversificationPercent > 20 ? "Strong" : diversificationPercent > 10 ? "Moderate" : "Limited") diversification achieved
        """

        return .success(text: result)
    }
}

// MARK: - Comprehensive Risk Metrics Tool

public struct ComprehensiveRiskMetricsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_comprehensive_risk",
        description: """
        Calculate a complete risk profile including VaR, CVaR, Sharpe ratio, Sortino ratio, drawdown, and tail statistics. One-stop analysis for portfolio risk.

        Example:
        - returns: [0.08, 0.05, -0.02, 0.10, -0.01, ...]  (historical returns)
        - riskFreeRate: 0.02 (2% annual, adjust for period)

        Returns complete risk metrics with interpretations.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns",
                    items: MCPSchemaItems(type: "number")
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate (same period as returns)"
                )
            ],
            required: ["returns", "riskFreeRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let returns = try args.getDoubleArray("returns")
        let riskFreeRate = try args.getDouble("riskFreeRate")

        // Create TimeSeries
        let periods = (1...returns.count).map { Period.day(Date().addingTimeInterval(Double($0) * 86400)) }
        let timeSeries = TimeSeries(periods: periods, values: returns)

        // Calculate comprehensive metrics
        let metrics = ComprehensiveRiskMetrics(
            returns: timeSeries,
            riskFreeRate: riskFreeRate
        )

        var result = """
        Comprehensive Risk Metrics

        Value at Risk:
        • VaR (95%): \(String(format: "%.2f%%", metrics.var95 * 100))
        • VaR (99%): \(String(format: "%.2f%%", metrics.var99 * 100))
        • CVaR (95%): \(String(format: "%.2f%%", metrics.cvar95 * 100))

        Drawdown Analysis:
        • Maximum Drawdown: \(String(format: "%.2f%%", metrics.maxDrawdown * 100))
        • Risk Level: \(metrics.maxDrawdown < 0.10 ? "Low" : metrics.maxDrawdown < 0.20 ? "Moderate" : "High")

        Risk-Adjusted Returns:
        • Sharpe Ratio: \(String(format: "%.3f", metrics.sharpeRatio))
          → Return per unit of total volatility
          → \(metrics.sharpeRatio > 1.0 ? "Excellent" : metrics.sharpeRatio > 0.5 ? "Good" : "Poor") risk-adjusted performance

        • Sortino Ratio: \(String(format: "%.3f", metrics.sortinoRatio))
          → Return per unit of downside volatility
          → \(metrics.sortinoRatio > metrics.sharpeRatio ? "Limited downside with upside potential" : "Symmetric risk profile")

        Tail Statistics:
        • Tail Risk Ratio: \(String(format: "%.3f", metrics.tailRisk))
          → CVaR / VaR ratio
          → \(metrics.tailRisk > 1.3 ? "High tail risk" : "Normal tail risk")

        • Skewness: \(String(format: "%.3f", metrics.skewness))
          \(metrics.skewness < -0.5 ? "→ Negative skew: more frequent small gains, rare large losses\n  → ⚠️ Fat left tail risk" :
            metrics.skewness > 0.5 ? "→ Positive skew: more frequent small losses, rare large gains\n  → Favorable asymmetry" :
            "→ Roughly symmetric distribution")

        • Excess Kurtosis: \(String(format: "%.3f", metrics.kurtosis))
          \(metrics.kurtosis > 1.0 ? "→ Fat tails: more extreme events than normal distribution\n  → ⚠️ Higher probability of large moves" :
            "→ Normal tail behavior")

        Overall Risk Assessment:
        """

        // Risk score
        var riskScore = 0
        if abs(metrics.var95) > 0.03 { riskScore += 1 }
        if metrics.maxDrawdown > 0.20 { riskScore += 1 }
        if metrics.sharpeRatio < 0.5 { riskScore += 1 }
        if metrics.tailRisk > 1.3 { riskScore += 1 }
        if metrics.skewness < -0.5 { riskScore += 1 }
        if metrics.kurtosis > 1.0 { riskScore += 1 }

        result += """

        Risk Score: \(riskScore)/6
        \(riskScore <= 2 ? "✓ Low Risk Profile - Well-balanced portfolio" :
          riskScore <= 4 ? "⚠ Moderate Risk Profile - Monitor key metrics" :
          "⚠️ High Risk Profile - Consider risk reduction strategies")

        Key Recommendations:
        \(metrics.maxDrawdown > 0.20 ? "• Reduce position sizes to limit drawdowns\n" : "")
        \(metrics.sharpeRatio < 0.5 ? "• Review strategy - returns don't justify risk\n" : "")
        \(metrics.tailRisk > 1.3 ? "• Consider tail risk hedging\n" : "")
        \(metrics.skewness < -0.5 ? "• Beware of rare large losses\n" : "")
        \(metrics.kurtosis > 1.0 ? "• Expect more extreme events than normal\n" : "")
        \(riskScore <= 2 ? "• Maintain current risk management practices\n" : "")
        """

        return .success(text: result)
    }
}

// MARK: - Tool Registration

public func getRiskAnalyticsTools() -> [MCPToolHandler] {
    return [
        StressTestTool(),
        ValueAtRiskTool(),
        AggregateRiskTool(),
        ComprehensiveRiskMetricsTool()
    ]
}
