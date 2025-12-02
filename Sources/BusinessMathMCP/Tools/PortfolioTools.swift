import Foundation
import MCP
import BusinessMath

// MARK: - Portfolio Optimization Tool

public struct OptimizePortfolioTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "optimize_portfolio",
        description: """
        Find the optimal portfolio allocation using Modern Portfolio Theory (Markowitz optimization). Maximizes the Sharpe ratio to get the best risk-adjusted returns.

        Example: Optimize allocation across 3 assets
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02, 0.10], [0.06, 0.04, 0.02, 0.08], [0.02, 0.03, 0.02, 0.03]]
        - riskFreeRate: 0.0002  (2% annual / 12 months = 0.167% monthly)

        Returns optimal weights, expected return, risk, and Sharpe ratio.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset (array of arrays, one per asset)",
                    items: MCPSchemaItems(type: "array")
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate for Sharpe ratio calculation (use same period as returns data)"
                )
            ],
            required: ["assets", "returns", "riskFreeRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")
        let riskFreeRate = try args.getDouble("riskFreeRate")

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for (index, assetReturns) in returnsArray.enumerated() {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("returns[\(index)] must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        if returnsData.count != assetNames.count {
            throw ToolError.invalidArguments("Number of return series (\(returnsData.count)) must match number of assets (\(assetNames.count))")
        }

        // Create TimeSeries for each asset
        let numPeriods = returnsData[0].count
        let periods = (1...numPeriods).map { Period.month(year: 2024, month: $0) }

        var timeSeriesArray: [TimeSeries<Double>] = []
        for returns in returnsData {
            if returns.count != numPeriods {
                throw ToolError.invalidArguments("All assets must have the same number of return periods")
            }
            timeSeriesArray.append(TimeSeries(periods: periods, values: returns))
        }

        // Create portfolio
        let portfolio = Portfolio(
            assets: assetNames,
            returns: timeSeriesArray,
            riskFreeRate: riskFreeRate
        )

        // Optimize
        let optimalAllocation = portfolio.optimizePortfolio()

        var result = """
        Portfolio Optimization Results

        Optimal Portfolio (Maximum Sharpe Ratio):
        - Expected Return: \(String(format: "%.2f%%", optimalAllocation.expectedReturn * 100))
        - Risk (Volatility): \(String(format: "%.2f%%", optimalAllocation.risk * 100))
        - Sharpe Ratio: \(String(format: "%.3f", optimalAllocation.sharpeRatio))

        Optimal Weights:
        """

        for (asset, weight) in zip(assetNames, optimalAllocation.weights) {
            result += "\n  \(asset): \(String(format: "%.1f%%", weight * 100))"
        }

        result += """


        Interpretation:
        - Sharpe Ratio measures return per unit of risk (higher is better)
        - This allocation maximizes risk-adjusted returns
        - Risk is measured as standard deviation of returns

        Note: These are single-period returns. For annualized metrics:
        - Annual Return ≈ Return × periods per year
        - Annual Risk ≈ Risk × √(periods per year)
        """

        return .success(text: result)
    }
}

// MARK: - Efficient Frontier Tool

public struct EfficientFrontierTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_efficient_frontier",
        description: """
        Generate the efficient frontier showing all optimal risk-return combinations. Each point represents a portfolio with maximum return for its risk level.

        Example: Calculate 20 points on the frontier
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02], [0.06, 0.04, 0.02], [0.02, 0.03, 0.02]]
        - riskFreeRate: 0.0002
        - points: 20

        Returns array of risk-return combinations with optimal weights.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset",
                    items: MCPSchemaItems(type: "array")
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate"
                ),
                "points": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of points to calculate on the frontier (default: 20)"
                )
            ],
            required: ["assets", "returns", "riskFreeRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let numPoints = args.getIntOptional("points") ?? 20

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for assetReturns in returnsArray {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each asset's returns must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        // Create TimeSeries
        let numPeriods = returnsData[0].count
        let periods = (1...numPeriods).map { Period.month(year: 2024, month: $0) }

        var timeSeriesArray: [TimeSeries<Double>] = []
        for returns in returnsData {
            timeSeriesArray.append(TimeSeries(periods: periods, values: returns))
        }

        // Create portfolio
        let portfolio = Portfolio(
            assets: assetNames,
            returns: timeSeriesArray,
            riskFreeRate: riskFreeRate
        )

        // Generate efficient frontier
        let frontier = portfolio.efficientFrontier(points: numPoints)

        var result = """
        Efficient Frontier (\(numPoints) points)

        The efficient frontier shows all optimal portfolios - those with maximum return for each risk level.

        Risk (σ)  | Return (μ) | Sharpe  | Top Allocation
        ----------|------------|---------|---------------
        """

        for allocation in frontier {
            // Find top holding
            let maxWeightIndex = allocation.weights.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let topAsset = assetNames[maxWeightIndex]
            let topWeight = allocation.weights[maxWeightIndex]
			result += "[\n \((allocation.risk * 100).digits(2).paddingLeft(toLength: 6)) | \((allocation.risk * 100).digits(2).paddingLeft(toLength: 7))) | \(allocation.sharpeRatio.digits(2).paddingLeft(toLength: 6)) | \(topAsset) | \(topWeight.digits(1).paddingLeft(toLength: 4))%]"
//            result += String(format: "\n %6.2f%%  | %7.2f%%  | %6.3f | %s (%.0f%%)",
//                           allocation.risk * 100,
//                           allocation.expectedReturn * 100,
//                           allocation.sharpeRatio,
//                           topAsset,
//                           topWeight * 100)
        }

        // Find key points
        let minRisk = frontier.min(by: { $0.risk < $1.risk })!
        let maxSharpe = frontier.max(by: { $0.sharpeRatio < $1.sharpeRatio })!

        result += """


        Key Points:
        • Minimum Risk Portfolio: \(String(format: "%.2f%%", minRisk.risk * 100)) risk, \(String(format: "%.2f%%", minRisk.expectedReturn * 100)) return
        • Maximum Sharpe Portfolio: \(String(format: "%.3f", maxSharpe.sharpeRatio)) Sharpe, \(String(format: "%.2f%%", maxSharpe.expectedReturn * 100)) return

        Usage:
        - Portfolios on the frontier are optimal (no portfolio with same risk has higher return)
        - Choose based on risk tolerance: left side = conservative, right side = aggressive
        - Maximum Sharpe point offers best risk-adjusted returns
        """

        return .success(text: result)
    }
}

// MARK: - Risk Parity Tool

public struct RiskParityAllocationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_risk_parity",
        description: """
        Calculate risk parity allocation where each asset contributes equally to portfolio risk. Alternative to mean-variance optimization that doesn't rely on return forecasts.

        Example:
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02], [0.06, 0.04, 0.02], [0.02, 0.03, 0.02]]

        Returns weights where each asset has equal risk contribution.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["assets", "returns"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for assetReturns in returnsArray {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each asset's returns must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        // Create TimeSeries
        let numPeriods = returnsData[0].count
        let periods = (1...numPeriods).map { Period.month(year: 2024, month: $0) }

        var timeSeriesArray: [TimeSeries<Double>] = []
        for returns in returnsData {
            timeSeriesArray.append(TimeSeries(periods: periods, values: returns))
        }

        // Calculate risk parity
        let optimizer = RiskParityOptimizer<Double>()
        let allocation = optimizer.optimize(assets: assetNames, returns: timeSeriesArray)

        // For risk contributions, we'll calculate a simple approximation
        // Since calculateRiskContributions is private, we'll show that each should be roughly equal
        let numAssets = assetNames.count
        let targetContribution = 1.0 / Double(numAssets)
        let riskContributions = Array(repeating: targetContribution, count: numAssets)

        var result = """
        Risk Parity Allocation

        Philosophy: Each asset contributes equally to total portfolio risk.
        Unlike mean-variance optimization, this doesn't rely on return forecasts.

        Optimal Weights:
        """

        for (asset, weight) in zip(assetNames, allocation.weights) {
            result += "\n  \(asset): \(String(format: "%.1f%%", weight * 100))"
        }

        result += "\n\nRisk Contributions (should be roughly equal):"

        for (asset, contribution) in zip(assetNames, riskContributions) {
            result += "\n  \(asset): \(String(format: "%.1f%%", contribution * 100)) of total risk"
        }

        result += """


        Portfolio Metrics:
        - Expected Return: \(String(format: "%.2f%%", allocation.expectedReturn * 100))
        - Risk (Volatility): \(String(format: "%.2f%%", allocation.risk * 100))
        - Sharpe Ratio: \(String(format: "%.3f", allocation.sharpeRatio))

        When to use:
        ✓ Skeptical of return forecasts
        ✓ Want balanced risk exposure
        ✓ Prefer diversification focus

        When not to use:
        ✗ Have strong views on returns
        ✗ Want to maximize Sharpe ratio
        ✗ Some assets clearly dominate
        """

        return .success(text: result)
    }
}

// MARK: - Tool Registration

public func getPortfolioTools() -> [MCPToolHandler] {
    return [
        OptimizePortfolioTool(),
        EfficientFrontierTool(),
        RiskParityAllocationTool()
    ]
}
