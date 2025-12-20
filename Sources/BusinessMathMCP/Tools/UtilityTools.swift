//
//  UtilityTools.swift
//  BusinessMath MCP Server
//
//  Utility tools for time series, templates, and reporting for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}


// MARK: - Rolling Window Calculations

public struct RollingSumTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_rolling_sum",
        description: """
        Calculate the rolling/moving sum of values over a specified window.

        Rolling sum calculates the sum of values within a moving window,
        useful for smoothing data and identifying trends.

        Use Cases:
        • Revenue trend analysis
        • Moving totals calculation
        • Smoothing volatile data
        • Detecting cumulative patterns

        Example: 3-month rolling sum of monthly sales
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Array of numeric values"
                ),
                "windowSize": MCPSchemaProperty(
                    type: "number",
                    description: "Size of the rolling window"
                )
            ],
            required: ["values", "windowSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let valuesAnyCodable = args["values"]?.value as? [Any] else {
            throw ToolError.invalidArguments("Values must be an array")
        }

        let values: [Double] = try valuesAnyCodable.map { val in
            if let doubleVal = val as? Double {
                return doubleVal
            } else if let intVal = val as? Int {
                return Double(intVal)
            } else {
                throw ToolError.invalidArguments("All values must be numbers")
            }
        }

        let windowSize = try args.getInt("windowSize")

        guard windowSize > 0 && windowSize <= values.count else {
            throw ToolError.invalidArguments("Window size must be between 1 and array length")
        }

        var rollingSums: [Double] = []
        for i in 0...(values.count - windowSize) {
            let windowValues = Array(values[i..<(i + windowSize)])
            let sum = windowValues.reduce(0, +)
            rollingSums.append(sum)
        }

        let results = rollingSums.enumerated().map { index, sum in
            "Period \(index + windowSize): \(formatNumber(sum, decimals: 2))"
        }.joined(separator: "\n")

        let output = """
        Rolling Sum Analysis:

        Window Size: \(windowSize) periods
        Input Values: \(values.count) data points
        Output Values: \(rollingSums.count) rolling sums

        Rolling Sums:
        \(results)

        Note: Each value represents the sum of the previous \(windowSize) periods.
        """

        return .success(text: output)
    }
}

public struct RollingMinTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_rolling_min",
        description: """
        Calculate the rolling/moving minimum over a specified window.

        Rolling minimum identifies the lowest value within each moving window,
        useful for risk assessment and floor analysis.

        Use Cases:
        • Identifying support levels
        • Risk floor analysis
        • Minimum performance tracking
        • Downside pattern detection

        Example: 6-month rolling minimum of stock prices
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Array of numeric values"
                ),
                "windowSize": MCPSchemaProperty(
                    type: "number",
                    description: "Size of the rolling window"
                )
            ],
            required: ["values", "windowSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let valuesAnyCodable = args["values"]?.value as? [Any] else {
            throw ToolError.invalidArguments("Values must be an array")
        }

        let values: [Double] = try valuesAnyCodable.map { val in
            if let doubleVal = val as? Double {
                return doubleVal
            } else if let intVal = val as? Int {
                return Double(intVal)
            } else {
                throw ToolError.invalidArguments("All values must be numbers")
            }
        }

        let windowSize = try args.getInt("windowSize")

        guard windowSize > 0 && windowSize <= values.count else {
            throw ToolError.invalidArguments("Window size must be between 1 and array length")
        }

        var rollingMins: [Double] = []
        for i in 0...(values.count - windowSize) {
            let windowValues = Array(values[i..<(i + windowSize)])
            if let minVal = windowValues.min() {
                rollingMins.append(minVal)
            }
        }

        let results = rollingMins.enumerated().map { index, minVal in
            "Period \(index + windowSize): \(formatNumber(minVal, decimals: 2))"
        }.joined(separator: "\n")

        let output = """
        Rolling Minimum Analysis:

        Window Size: \(windowSize) periods
        Input Values: \(values.count) data points
        Output Values: \(rollingMins.count) rolling minimums

        Rolling Minimums:
        \(results)

        Note: Each value represents the minimum within the previous \(windowSize) periods.
        """

        return .success(text: output)
    }
}

public struct RollingMaxTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_rolling_max",
        description: """
        Calculate the rolling/moving maximum over a specified window.

        Rolling maximum identifies the highest value within each moving window,
        useful for peak analysis and ceiling identification.

        Use Cases:
        • Identifying resistance levels
        • Peak performance tracking
        • Upside pattern detection
        • Historical high analysis

        Example: 12-month rolling maximum of revenue
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Array of numeric values"
                ),
                "windowSize": MCPSchemaProperty(
                    type: "number",
                    description: "Size of the rolling window"
                )
            ],
            required: ["values", "windowSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let valuesAnyCodable = args["values"]?.value as? [Any] else {
            throw ToolError.invalidArguments("Values must be an array")
        }

        let values: [Double] = try valuesAnyCodable.map { val in
            if let doubleVal = val as? Double {
                return doubleVal
            } else if let intVal = val as? Int {
                return Double(intVal)
            } else {
                throw ToolError.invalidArguments("All values must be numbers")
            }
        }

        let windowSize = try args.getInt("windowSize")

        guard windowSize > 0 && windowSize <= values.count else {
            throw ToolError.invalidArguments("Window size must be between 1 and array length")
        }

        var rollingMaxs: [Double] = []
        for i in 0...(values.count - windowSize) {
            let windowValues = Array(values[i..<(i + windowSize)])
            if let maxVal = windowValues.max() {
                rollingMaxs.append(maxVal)
            }
        }

        let results = rollingMaxs.enumerated().map { index, maxVal in
            "Period \(index + windowSize): \(formatNumber(maxVal, decimals: 2))"
        }.joined(separator: "\n")

        let output = """
        Rolling Maximum Analysis:

        Window Size: \(windowSize) periods
        Input Values: \(values.count) data points
        Output Values: \(rollingMaxs.count) rolling maximums

        Rolling Maximums:
        \(results)

        Note: Each value represents the maximum within the previous \(windowSize) periods.
        """

        return .success(text: output)
    }
}

public struct PercentChangeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_percent_change",
        description: """
        Calculate the period-over-period percentage change.

        Percent change measures the relative change between consecutive periods,
        essential for growth analysis and trend identification.

        Formula: % Change = (New Value - Old Value) / Old Value × 100%

        Use Cases:
        • Growth rate calculation
        • Performance comparison
        • Trend analysis
        • Period-over-period variance

        Example: Month-over-month revenue growth
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Array of numeric values in chronological order"
                )
            ],
            required: ["values"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let valuesAnyCodable = args["values"]?.value as? [Any] else {
            throw ToolError.invalidArguments("Values must be an array")
        }

        let values: [Double] = try valuesAnyCodable.map { val in
            if let doubleVal = val as? Double {
                return doubleVal
            } else if let intVal = val as? Int {
                return Double(intVal)
            } else {
                throw ToolError.invalidArguments("All values must be numbers")
            }
        }

        guard values.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 values to calculate percent change")
        }

        var percentChanges: [String] = []
        for i in 1..<values.count {
            let oldValue = values[i - 1]
            let newValue = values[i]

            if oldValue == 0 {
                percentChanges.append("Period \(i) to \(i + 1): N/A (division by zero)")
            } else {
                let change = (newValue - oldValue) / oldValue
                let sign = change >= 0 ? "+" : ""
                percentChanges.append("Period \(i) to \(i + 1): \(sign)\(change.percent())")
            }
        }

        let results = percentChanges.joined(separator: "\n")

        // Calculate average change
        let validChanges = (1..<values.count).compactMap { i -> Double? in
            let oldValue = values[i - 1]
            guard oldValue != 0 else { return nil }
            return (values[i] - oldValue) / oldValue
        }

        let avgChange = validChanges.isEmpty ? 0 : validChanges.reduce(0, +) / Double(validChanges.count)

        let output = """
        Percent Change Analysis:

        Input Values: \(values.count) data points
        Period-over-Period Changes: \(percentChanges.count) calculations

        Changes:
        \(results)

        Summary:
        • Average Change: \(avgChange.percent())
        • Number of Increases: \(validChanges.filter { $0 > 0 }.count)
        • Number of Decreases: \(validChanges.filter { $0 < 0 }.count)
        """

        return .success(text: output)
    }
}

// MARK: - TTM Metrics

public struct TTMMetricsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_ttm_metrics",
        description: """
        Calculate Trailing Twelve Months (TTM) metrics.

        TTM metrics aggregate the most recent 12 months of data, providing
        a current view that eliminates seasonal variations.

        Use Cases:
        • Current performance assessment
        • Eliminating seasonality
        • Up-to-date financial metrics
        • Investment analysis

        Example: TTM revenue from monthly data
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "monthlyValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of monthly values (must have at least 12)"
                ),
                "metricName": MCPSchemaProperty(
                    type: "string",
                    description: "Name of the metric (e.g., 'Revenue', 'EBITDA')"
                )
            ],
            required: ["monthlyValues", "metricName"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let valuesAnyCodable = args["monthlyValues"]?.value as? [Any] else {
            throw ToolError.invalidArguments("Monthly values must be an array")
        }

        let values: [Double] = try valuesAnyCodable.map { val in
            if let doubleVal = val as? Double {
                return doubleVal
            } else if let intVal = val as? Int {
                return Double(intVal)
            } else {
                throw ToolError.invalidArguments("All values must be numbers")
            }
        }

        let metricName = try args.getString("metricName")

        guard values.count >= 12 else {
            throw ToolError.invalidArguments("Need at least 12 months of data for TTM calculation")
        }

        // Calculate TTM (last 12 months)
        let last12Months = Array(values.suffix(12))
        let ttmValue = last12Months.reduce(0, +)

        // Calculate prior 12 months for comparison
        let priorTTM = values.count >= 24 ? Array(values[(values.count - 24)..<(values.count - 12)]).reduce(0, +) : nil

        var comparison = ""
        if let prior = priorTTM {
            let yoyGrowth = (ttmValue - prior) / prior
            comparison = """

            Year-over-Year Comparison:
            • Prior TTM: $\(formatNumber(prior, decimals: 0))
            • Current TTM: $\(formatNumber(ttmValue, decimals: 0))
            • YoY Growth: \(yoyGrowth.percent())
            """
        }

        let avgMonthly = ttmValue / 12.0

        let output = """
        Trailing Twelve Months (TTM) Analysis:

        Metric: \(metricName)
        Period: Most recent 12 months

        TTM \(metricName): $\(formatNumber(ttmValue, decimals: 0))
        Average Monthly: $\(formatNumber(avgMonthly, decimals: 0))
        \(comparison)

        Note: TTM metrics provide the most current view of performance
        and eliminate seasonal fluctuations.
        """

        return .success(text: output)
    }
}

// MARK: - Budget vs Actual

public struct BudgetVsActualTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_budget_vs_actual",
        description: """
        Calculate and compare projected vs actual results.

        Variance analysis identifies differences between budgeted and actual performance,
        essential for financial control and management accountability.

        Metrics:
        • Variance = Actual - Budget
        • Variance % = (Actual - Budget) / Budget
        • Favorable/Unfavorable assessment

        Use Cases:
        • Performance management
        • Budget control
        • Management reporting
        • Financial planning

        Example: Comparing actual Q1 revenue to budget
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "budgeted": MCPSchemaProperty(
                    type: "number",
                    description: "Budgeted/planned amount"
                ),
                "actual": MCPSchemaProperty(
                    type: "number",
                    description: "Actual amount"
                ),
                "metricName": MCPSchemaProperty(
                    type: "string",
                    description: "Name of the metric"
                ),
                "isRevenueType": MCPSchemaProperty(
                    type: "boolean",
                    description: "True for revenue/income (higher is better), false for expenses (lower is better)"
                )
            ],
            required: ["budgeted", "actual", "metricName", "isRevenueType"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let budgeted = try args.getDouble("budgeted")
        let actual = try args.getDouble("actual")
        let metricName = try args.getString("metricName")
        let isRevenueType = try args.getBool("isRevenueType")

        let variance = actual - budgeted
        let variancePercent = budgeted != 0 ? variance / budgeted : 0

        // Determine if variance is favorable or unfavorable
        let isFavorable: Bool
        if isRevenueType {
            isFavorable = variance > 0 // Revenue: higher is better
        } else {
            isFavorable = variance < 0 // Expense: lower is better
        }

        let status = isFavorable ? "✓ Favorable" : "✗ Unfavorable"
        let sign = variance >= 0 ? "+" : ""

        let interpretation: String
        let absVariancePercent = abs(variancePercent)
        if absVariancePercent < 0.05 {
            interpretation = "Minimal variance - on track with budget"
        } else if absVariancePercent < 0.10 {
            interpretation = "Minor variance - acceptable deviation"
        } else if absVariancePercent < 0.20 {
            interpretation = "Moderate variance - requires attention"
        } else {
            interpretation = "Significant variance - needs investigation"
        }

        let output = """
        Budget vs Actual Analysis:

        Metric: \(metricName)
        Type: \(isRevenueType ? "Revenue/Income" : "Expense/Cost")

        Performance:
        • Budgeted: $\(formatNumber(budgeted, decimals: 0))
        • Actual: $\(formatNumber(actual, decimals: 0))
        • Variance: \(sign)$\(formatNumber(abs(variance), decimals: 0))
        • Variance %: \(sign)\(abs(variancePercent).percent())

        Assessment:
        • Status: \(status)
        • Interpretation: \(interpretation)

        Note: \(isFavorable ? "Performance exceeded expectations" : "Performance fell short of budget")
        """

        return .success(text: output)
    }
}

// MARK: - Tool Registration

/// Returns all utility tools
public func getUtilityTools() -> [any MCPToolHandler] {
    return [
        RollingSumTool(),
        RollingMinTool(),
        RollingMaxTool(),
        PercentChangeTool(),
        TTMMetricsTool(),
        BudgetVsActualTool()
    ]
}
