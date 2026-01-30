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
        let npvImpactPercent = npvImpact / baseNPV

        let result = """
        Stress Test Results

        Scenario: \(scenarioName.uppercased())
        Description: \(shocks.description)

        Baseline Metrics:
        - Revenue: \(baseRevenue.currency(0))
        - Costs: \(baseCosts.currency(0))
        - NPV/Profit: \(baseNPV.currency(0))

        Applied Shocks:
        - Revenue: \(shocks.revenue.percent(0, .always(includingZero: true)))
        - Costs: \(shocks.costs.percent(0,.always(includingZero: true)))

        Stressed Metrics:
        - Revenue: \(stressedRevenue.currency(0)) (\(revenueImpact.number(0,.toNearestOrAwayFromZero,.autoupdatingCurrent,.always(includingZero: true)))
        - Costs: \(stressedCosts.currency(0)) (\(costsImpact.number(0,.toNearestOrAwayFromZero,.autoupdatingCurrent,.always(includingZero: true)))
        - NPV/Profit: \(stressedNPV.currency(0)) (\(npvImpact.number(0,.toNearestOrAwayFromZero,.autoupdatingCurrent,.always(includingZero: true))))

        Impact Analysis:
        - NPV Impact: \(npvImpactPercent.percent(0))
        - \(stressedNPV > 0 ? "Project remains viable" : "⚠️ Project becomes unprofitable")
        - \(abs(npvImpactPercent) > 0.50 ? "⚠️ HIGH SENSITIVITY - material risk" : "Moderate sensitivity")

        Risk Assessment:
        \(abs(npvImpactPercent) < 0.20 ? "✓ Low risk - project resilient to this scenario" :
          abs(npvImpactPercent) < 0.50 ? "⚠ Moderate risk - monitor key assumptions" :
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

        Portfolio: \(portfolioValue.currency(0))
        Historical Periods: \(returns.count)
        Confidence Level: \(confidenceLevel.percent(0))

        VaR Metrics:
        • 95% VaR: \(var95.percent())
          → Maximum loss: \(var95Loss.currency(0))
          → Interpretation: 95% confident loss won't exceed this

        • 99% VaR: \(var99.percent())
          → Maximum loss: \(var99Loss.currency(0))
          → Interpretation: 99% confident loss won't exceed this

        • CVaR (95%): \(cvar95.percent())
          → Expected loss in worst 5%: \(cvarLoss.currency(0))
          → Interpretation: Average loss when in the tail

        Additional Risk Metrics:
        • Maximum Drawdown: \(riskMetrics.maxDrawdown.percent(2))
        • Sharpe Ratio: \(riskMetrics.sharpeRatio.number(3))
        • Sortino Ratio: \(riskMetrics.sortinoRatio.number(3))
        • Tail Risk Ratio: \(riskMetrics.tailRisk.number(3))
        • Skewness: \(riskMetrics.skewness.number(3))
        • Kurtosis: \(riskMetrics.kurtosis.number(3))

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
        • Set stop-loss at 95% VaR: \(var95Loss.currency(0))
        • Reserve for tail events: \(cvarLoss.currency(0))
        • Monitor drawdown limit: \(riskMetrics.maxDrawdown.percent(1))
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
        let diversificationPercent = (diversificationBenefit / simpleSum)

        var result = """
        Portfolio Risk Aggregation

        Individual Portfolio VaRs:
        """

        for (i, varValue) in portfolioVaRs.enumerated() {
			result += "\n  \(portfolioNames[i]): \(varValue.currency(0))"
        }

        result += """


        Aggregation Results:
        • Simple Sum: \(simpleSum.currency(0))
        • Aggregated VaR: \(aggregatedVaR.currency(1))
        • Diversification Benefit: \(diversificationBenefit.currency(0)) (\(diversificationPercent.percent(1)))

        Interpretation:
        Due to imperfect correlations, the combined portfolio risk is
        \(diversificationBenefit.currency()) LESS than the simple sum.
        This is a \(diversificationPercent.percent(1)) reduction in risk from diversification.

        Marginal VaR (Risk Contribution):
        """

        for i in 0..<portfolioVaRs.count {
            let marginalVaR = RiskAggregator<Double>.marginalVaR(
                entity: i,
                individualVaRs: portfolioVaRs,
                correlations: correlations
            )
            let contribution = (marginalVaR / aggregatedVaR)

            result += "\n  \(portfolioNames[i]):"
			result += "\n    Individual VaR: \(portfolioVaRs[i].currency(0))"
			result += "\n    Marginal VaR: \(marginalVaR.currency(0))"
			result += "\n    Contribution: \(contribution.percent(1)) of total risk"
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
				result += "\n  \(portfolioNames[i]): \(componentVaRs[i].currency(0)) (weight: \(weightsArray[i].percent(1)))"
            }

            let totalComponent = componentVaRs.reduce(0, +)
			result += "\n\n  Sum of components: \(totalComponent.currency(0))"
			result += "\n  (Should equal aggregated VaR: \(aggregatedVaR.currency(0)))"
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
        • VaR (95%): \(metrics.var95.percent())
        • VaR (99%): \(metrics.var99.percent())
        • CVaR (95%): \(metrics.cvar95.percent())

        Drawdown Analysis:
        • Maximum Drawdown: \(metrics.maxDrawdown.percent())
        • Risk Level: \(metrics.maxDrawdown < 0.10 ? "Low" : metrics.maxDrawdown < 0.20 ? "Moderate" : "High")

        Risk-Adjusted Returns:
        • Sharpe Ratio: \(metrics.sharpeRatio.number(3))
          → Return per unit of total volatility
          → \(metrics.sharpeRatio > 1.0 ? "Excellent" : metrics.sharpeRatio > 0.5 ? "Good" : "Poor") risk-adjusted performance

        • Sortino Ratio: \(metrics.sortinoRatio.number(3))
          → Return per unit of downside volatility
          → \(metrics.sortinoRatio > metrics.sharpeRatio ? "Limited downside with upside potential" : "Symmetric risk profile")

        Tail Statistics:
        • Tail Risk Ratio: \(metrics.tailRisk.number(3))
          → CVaR / VaR ratio
          → \(metrics.tailRisk > 1.3 ? "High tail risk" : "Normal tail risk")

        • Skewness: \(metrics.skewness.number(3))
          \(metrics.skewness < -0.5 ? "→ Negative skew: more frequent small gains, rare large losses\n  → ⚠️ Fat left tail risk" :
            metrics.skewness > 0.5 ? "→ Positive skew: more frequent small losses, rare large gains\n  → Favorable asymmetry" :
            "→ Roughly symmetric distribution")

        • Excess Kurtosis: \(metrics.kurtosis.number(3))
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
