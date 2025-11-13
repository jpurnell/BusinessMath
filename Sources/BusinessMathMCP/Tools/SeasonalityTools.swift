//
//  SeasonalityTools.swift
//  BusinessMath MCP Server
//
//  Seasonality analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all seasonality tools
public func getSeasonalityTools() -> [any MCPToolHandler] {
    return [
        CalculateSeasonalIndicesTool(),
        SeasonallyAdjustTool(),
        ApplySeasonalTool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format percentage
private func formatPercentage(_ value: Double, decimals: Int = 1) -> String {
    return ((value - 1.0) * 100).formatDecimal(decimals: decimals) + "%"
}

// MARK: - Calculate Seasonal Indices

//public struct CalculateSeasonalIndicesTool: MCPToolHandler, Sendable {
//    public let tool = MCPTool(
//        name: "calculate_seasonal_indices",
//        description: """
//        Calculate seasonal indices to quantify repeating patterns in time series data.
//
//        Seasonal indices show the typical pattern within each cycle. For example:
//        • Index = 1.2 means 20% above average
//        • Index = 1.0 means average
//        • Index = 0.8 means 20% below average
//
//        Use Cases:
//        • Identify seasonal patterns (holiday spikes, summer slumps)
//        • Forecast with seasonal adjustments
//        • Budget planning with seasonal factors
//        • Capacity planning for peak/off-peak periods
//
//        Example - Retail Sales:
//        Quarterly indices: [0.85, 0.95, 1.0, 1.20]
//        Interpretation: Q4 is 20% above average (holiday season)
//
//        Requirements:
//        • At least 2 complete cycles of data
//        • Regular periodicity (monthly, quarterly, etc.)
//        """,
//        inputSchema: MCPToolInputSchema(
//            properties: [
//                "values": MCPSchemaProperty(
//                    type: "array",
//                    description: "Array of time series values (at least 2 complete cycles required)",
//                    items: MCPSchemaProperty(type: "number", description: "Value")
//                ),
//                "periodicity": MCPSchemaProperty(
//                    type: "number",
//                    description: "Number of periods in one seasonal cycle (e.g., 4 for quarterly, 12 for monthly)"
//                )
//            ],
//            required: ["values", "periodicity"]
//        )
//    )
//
//    public init() {}
//
//    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
//        guard let args = arguments else {
//            throw ToolError.invalidArguments("Missing arguments")
//        }
//
//        let values = try args.getDoubleArray("values")
//        let periodicity = try args.getInt("periodicity")
//
//        guard periodicity >= 2 && periodicity <= 365 else {
//            throw ToolError.invalidArguments("Periodicity must be between 2 and 365")
//        }
//
//        guard values.count >= periodicity * 2 else {
//            throw ToolError.invalidArguments("Need at least \(periodicity * 2) values (2 complete cycles)")
//        }
//
//        // Create TimeSeries with monthly periods (generic enough for any periodicity)
//        let startYear = 2020
//        let periods = (0..<values.count).map { i -> Period in
//            let year = startYear + (i / 12)
//            let month = (i % 12) + 1
//            return Period.month(year, month)
//        }
//        let ts = TimeSeries<Double>(
//            periods: periods,
//            values: values,
//            metadata: TimeSeriesMetadata(name: "Data")
//        )
//
//        // Calculate seasonal indices
//        let indices: [Double] = try seasonalIndices(timeSeries: ts, periodsPerYear: periodicity)
//
//        // Find strongest/weakest seasons
//        let maxIndex = indices.max() ?? 1.0
//        let minIndex = indices.min() ?? 1.0
//        let maxSeason = indices.firstIndex(of: maxIndex) ?? 0
//        let minSeason = indices.firstIndex(of: minIndex) ?? 0
//
//        let output = """
//        Seasonal Indices Analysis
//
//        Data: \(values.count) values, Periodicity: \(periodicity)
//
//        Seasonal Indices (one complete cycle):
//        \(indices.enumerated().map { i, idx in
//            let pct = formatPercentage(idx)
//            let label = idx > 1.05 ? "⬆ Above avg" : idx < 0.95 ? "⬇ Below avg" : "≈ Average"
//            return "  Season \(i + 1): \(formatNumber(idx, decimals: 3)) (\(pct)) \(label)"
//        }.joined(separator: "\n"))
//
//        Key Insights:
//        • Strongest Season: Season \(maxSeason + 1) with index \(formatNumber(maxIndex, decimals: 3)) (\(formatPercentage(maxIndex)))
//        • Weakest Season: Season \(minSeason + 1) with index \(formatNumber(minIndex, decimals: 3)) (\(formatPercentage(minIndex)))
//        • Seasonal Range: \(formatNumber((maxIndex - minIndex) * 100))% variation
//
//        Interpretation:
//        • Indices are normalized to average 1.0
//        • Multiply by these indices to add seasonality to forecasts
//        • Divide by these indices to remove seasonality from data
//        • \(maxIndex / minIndex > 1.5 ? "Strong seasonal pattern detected" :
//             maxIndex / minIndex > 1.2 ? "Moderate seasonal pattern" :
//             "Weak seasonal pattern")
//
//        Use Cases:
//        • Apply to forecasts: Forecast × Seasonal Index
//        • Seasonally adjust data: Actual ÷ Seasonal Index
//        • Budget planning: Annual target × Seasonal Index per period
//        """
//
//        return .success(text: output)
//    }
//}

// MARK: - Seasonally Adjust

//public struct SeasonallyAdjustTool: MCPToolHandler, Sendable {
//    public let tool = MCPTool(
//        name: "seasonally_adjust_data",
//        description: """
//        Remove seasonal effects from time series to reveal underlying trend.
//
//        Seasonal adjustment removes predictable seasonal patterns, making it easier
//        to identify the true trend and compare periods fairly.
//
//        Formula: Adjusted Value = Original Value ÷ Seasonal Index
//
//        Use Cases:
//        • Trend analysis without seasonal noise
//        • Fair period-to-period comparisons
//        • Detect turning points earlier
//        • Performance evaluation (compare Q1 vs Q4 fairly)
//
//        Example - Monthly Sales:
//        Dec actual: $120K, Seasonal index: 1.20
//        Dec adjusted: $120K ÷ 1.20 = $100K
//        (Shows underlying business level without holiday boost)
//
//        Result: Time series with seasonality removed, showing true trend.
//        """,
//        inputSchema: MCPToolInputSchema(
//            properties: [
//                "values": MCPSchemaProperty(
//                    type: "array",
//                    description: "Array of time series values to adjust",
//                    items: MCPSchemaProperty(type: "number", description: "Value")
//                ),
//                "seasonalIndices": MCPSchemaProperty(
//                    type: "array",
//                    description: "Seasonal indices for one complete cycle (from calculate_seasonal_indices)",
//                    items: MCPSchemaProperty(type: "number", description: "Index")
//                )
//            ],
//            required: ["values", "seasonalIndices"]
//        )
//    )
//
//    public init() {}
//
//    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
//        guard let args = arguments else {
//            throw ToolError.invalidArguments("Missing arguments")
//        }
//
//        let values = try args.getDoubleArray("values")
//        let seasonalIndices = try args.getDoubleArray("seasonalIndices")
//
//        guard !seasonalIndices.isEmpty else {
//            throw ToolError.invalidArguments("Seasonal indices cannot be empty")
//        }
//
//        guard values.count >= seasonalIndices.count else {
//            throw ToolError.invalidArguments("Need at least one complete cycle of data")
//        }
//
//        // Adjust values by dividing by seasonal index
//        var adjustedValues: [Double] = []
//        for (i, value) in values.enumerated() {
//            let seasonIndex = i % seasonalIndices.count
//            let index = seasonalIndices[seasonIndex]
//            guard index != 0 else {
//                throw ToolError.invalidArguments("Seasonal index cannot be zero")
//            }
//            adjustedValues.append(value / index)
//        }
//
//        // Calculate trend in adjusted data
//        let adjustedAvg = adjustedValues.reduce(0.0, +) / Double(adjustedValues.count)
//        let originalAvg = values.reduce(0.0, +) / Double(values.count)
//
//        // Show sample of adjustments (first cycle + last cycle)
//        let periodicity = seasonalIndices.count
//        let firstCycle = min(periodicity, values.count)
//        let lastCycleStart = max(0, values.count - periodicity)
//
//        let output = """
//        Seasonally Adjusted Data
//
//        Original Data: \(values.count) values
//        Seasonal Cycle: \(periodicity) periods
//
//        First Cycle - Adjustment Example:
//        \((0..<firstCycle).map { i in
//            let orig = values[i]
//            let adj = adjustedValues[i]
//            let idx = seasonalIndices[i % periodicity]
//            let diff = ((adj - orig) / orig) * 100
//            return "  Period \(i + 1): \(formatNumber(orig)) → \(formatNumber(adj)) (index: \(formatNumber(idx, decimals: 2)), \(diff >= 0 ? "+" : "")\(formatNumber(diff, decimals: 1))%)"
//        }.joined(separator: "\n"))
//
//        \(values.count > periodicity ? """
//
//        Last Cycle - Recent Adjustments:
//        \((lastCycleStart..<values.count).map { i in
//            let orig = values[i]
//            let adj = adjustedValues[i]
//            let idx = seasonalIndices[i % periodicity]
//            let diff = ((adj - orig) / orig) * 100
//            return "  Period \(i + 1): \(formatNumber(orig)) → \(formatNumber(adj)) (index: \(formatNumber(idx, decimals: 2)), \(diff >= 0 ? "+" : "")\(formatNumber(diff, decimals: 1))%)"
//        }.joined(separator: "\n"))
//        """ : "")
//
//        Summary:
//        • Original Average: \(formatNumber(originalAvg))
//        • Adjusted Average: \(formatNumber(adjustedAvg))
//        • Seasonality Removed: Yes
//
//        Adjusted Values (all \(adjustedValues.count) values):
//        \(adjustedValues.prefix(10).enumerated().map { "  [\($0)]: \(formatNumber($1))" }.joined(separator: "\n"))
//        \(adjustedValues.count > 10 ? "  ... (\(adjustedValues.count - 10) more values)" : "")
//
//        Interpretation:
//        • Adjusted data shows underlying trend without seasonal effects
//        • Use for fair period-to-period comparisons
//        • Use for identifying true growth vs seasonal variation
//        • Note: Forecasts should add seasonality back using apply_seasonal
//
//        Use Cases:
//        • Compare Q1 performance to Q4 fairly
//        • Identify turning points in business trends
//        • Report "real" growth excluding seasonal effects
//        • Detect anomalies more easily
//        """
//
//        return .success(text: output)
//    }
//}

// MARK: - Apply Seasonal

public struct ApplySeasonalTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "apply_seasonal_pattern",
        description: """
        Add seasonal patterns to trend data or forecasts.

        This is the inverse of seasonal adjustment. Use it to add realistic
        seasonal variation to trend projections or deseasonalized data.

        Formula: Seasonalized Value = Trend × Seasonal Index

        Use Cases:
        • Add seasonality to trend-based forecasts
        • Reseasonalize adjusted data
        • Create realistic projections with seasonal patterns
        • Budget allocation by season

        Example - Annual Forecast:
        Annual target: $1,200K ($100K/month trend)
        Apply monthly indices to get realistic monthly targets:
        Jan: $100K × 0.85 = $85K (slow month)
        Dec: $100K × 1.30 = $130K (holiday season)

        Result: Forecasts that reflect realistic seasonal variation.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "trendValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of trend or deseasonalized values to apply seasonality to",
                    items: MCPSchemaItems(type: "array")
                ),
                "seasonalIndices": MCPSchemaProperty(
                    type: "array",
                    description: "Seasonal indices for one complete cycle",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["trendValues", "seasonalIndices"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let trendValues = try args.getDoubleArray("trendValues")
        let seasonalIndices = try args.getDoubleArray("seasonalIndices")

        guard !seasonalIndices.isEmpty else {
            throw ToolError.invalidArguments("Seasonal indices cannot be empty")
        }

        // Apply seasonality by multiplying by seasonal index
        var seasonalizedValues: [Double] = []
        for (i, trendValue) in trendValues.enumerated() {
            let seasonIndex = i % seasonalIndices.count
            let index = seasonalIndices[seasonIndex]
            seasonalizedValues.append(trendValue * index)
        }

        // Calculate summary statistics
        let trendAvg = trendValues.reduce(0.0, +) / Double(trendValues.count)
        let seasonalAvg = seasonalizedValues.reduce(0.0, +) / Double(seasonalizedValues.count)
        let periodicity = seasonalIndices.count

        // Show first complete cycle as example
        let firstCycle = min(periodicity, trendValues.count)

        let output = """
        Apply Seasonal Pattern

        Trend/Deseasonalized Data: \(trendValues.count) values
        Seasonal Cycle: \(periodicity) periods

        First Cycle - Seasonalization Example:
        \((0..<firstCycle).map { i in
            let trend = trendValues[i]
            let seasonal = seasonalizedValues[i]
            let idx = seasonalIndices[i % periodicity]
            let diff = ((seasonal - trend) / trend) * 100
            return "  Period \(i + 1): \(formatNumber(trend)) → \(formatNumber(seasonal)) (×\(formatNumber(idx, decimals: 2)), \(diff >= 0 ? "+" : "")\(formatNumber(diff, decimals: 1))%)"
        }.joined(separator: "\n"))

        Seasonalized Values (all \(seasonalizedValues.count) values):
        \(seasonalizedValues.prefix(12).enumerated().map { i, val in
            let idx = seasonalIndices[i % periodicity]
            return "  Period \(i + 1): \(formatNumber(val)) (index: \(formatNumber(idx, decimals: 2)))"
        }.joined(separator: "\n"))
        \(seasonalizedValues.count > 12 ? "  ... (\(seasonalizedValues.count - 12) more values)" : "")

        Summary:
        • Average Trend Value: \(formatNumber(trendAvg))
        • Average Seasonalized Value: \(formatNumber(seasonalAvg))
        • Seasonal Variation: \((seasonalIndices.max() ?? 1.0) / (seasonalIndices.min() ?? 1.0) > 1.3 ? "Strong" : "Moderate")

        Interpretation:
        • Added realistic seasonal variation to trend data
        • Seasonalized values reflect typical patterns
        • Use for realistic forecasts and budgets
        • Maintains overall trend while adding seasonal fluctuation

        Use Cases:
        • Convert trend forecast into realistic seasonal forecast
        • Reseasonalize adjusted data for reporting
        • Allocate annual budget across seasonal periods
        • Create realistic scenario projections
        """

        return .success(text: output)
    }
}
