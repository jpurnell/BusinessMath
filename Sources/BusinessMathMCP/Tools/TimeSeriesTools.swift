import Foundation
import MCP
import BusinessMath

// MARK: - Create Time Series Tool

public struct CreateTimeSeriesTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_time_series",
        description: """
        Create a time series from periods and values for analysis.

        Supports annual, quarterly, monthly, and daily time periods.
        Use for analyzing trends, growth, seasonality, and forecasting.

        REQUIRED STRUCTURE:
        {
          "data": [
            {"period": {"year": 2023, "type": "annual"}, "value": 100000},
            {"period": {"year": 2024, "type": "annual"}, "value": 120000}
          ]
        }

        EXAMPLES:

        1. Annual Revenue:
        {
          "data": [
            {"period": {"year": 2021, "type": "annual"}, "value": 1000000},
            {"period": {"year": 2022, "type": "annual"}, "value": 1200000},
            {"period": {"year": 2023, "type": "annual"}, "value": 1450000}
          ],
          "name": "Annual Revenue",
          "unit": "USD"
        }

        2. Quarterly Sales:
        {
          "data": [
            {"period": {"year": 2024, "month": 1, "type": "quarterly"}, "value": 250000},
            {"period": {"year": 2024, "month": 4, "type": "quarterly"}, "value": 280000},
            {"period": {"year": 2024, "month": 7, "type": "quarterly"}, "value": 310000},
            {"period": {"year": 2024, "month": 10, "type": "quarterly"}, "value": 350000}
          ],
          "name": "Q1-Q4 2024 Sales",
          "unit": "USD"
        }

        3. Monthly Revenue:
        {
          "data": [
            {"period": {"year": 2024, "month": 1, "type": "monthly"}, "value": 85000},
            {"period": {"year": 2024, "month": 2, "type": "monthly"}, "value": 92000},
            {"period": {"year": 2024, "month": 3, "type": "monthly"}, "value": 88000}
          ]
        }

        Period types: "annual", "quarterly", "monthly", "daily"
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of time series data points. Each object must have:
                    • period (object): Time period with fields:
                      - year (number): Required for all types
                      - month (number): Required for quarterly/monthly/daily (1-12)
                      - day (number): Required for daily only (1-31)
                      - type (string): "annual", "quarterly", "monthly", or "daily"
                    • value (number): Numeric value for this period

                    Example: [{"period": {"year": 2024, "month": 1, "type": "monthly"}, "value": 100000}]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "name": MCPSchemaProperty(
                    type: "string",
                    description: "Name of the time series (optional)"
                ),
                "description": MCPSchemaProperty(
                    type: "string",
                    description: "Description of the time series (optional)"
                ),
                "unit": MCPSchemaProperty(
                    type: "string",
                    description: "Unit of measurement, e.g., 'USD', 'units', 'customers' (optional)"
                )
            ],
            required: ["data"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let timeSeriesData = try args.getTimeSeries("data")
        let name = args.getStringOptional("name")
        let description = args.getStringOptional("description")
        let unit = args.getStringOptional("unit")

        // Create new time series with updated metadata if provided
        let ts: TimeSeries<Double>
        if name != nil || description != nil || unit != nil {
            let newMetadata = TimeSeriesMetadata(
                name: name ?? timeSeriesData.metadata.name,
                description: description ?? timeSeriesData.metadata.description,
                unit: unit ?? timeSeriesData.metadata.unit
            )
            ts = TimeSeries(
                periods: timeSeriesData.periods,
                values: timeSeriesData.valuesArray,
                metadata: newMetadata
            )
        } else {
            ts = timeSeriesData
        }

        let dataPoints = ts.count
        let firstPeriod = ts.periods.first?.label ?? "N/A"
        let lastPeriod = ts.periods.last?.label ?? "N/A"

        let result = """
        Time Series Created:
        • Name: \(name ?? "Unnamed")
        • Description: \(description ?? "No description")
        • Unit: \(unit ?? "No unit")
        • Data Points: \(dataPoints)
        • Period Range: \(firstPeriod) to \(lastPeriod)
        """

        return .success(text: result)
    }
}

// MARK: - Calculate Growth Rate Tool

public struct CalculateGrowthRateTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_growth_rate",
        description: "Calculate the growth rate between two values",
        inputSchema: MCPToolInputSchema(
            properties: [
                "oldValue": MCPSchemaProperty(
                    type: "number",
                    description: "The starting value"
                ),
                "newValue": MCPSchemaProperty(
                    type: "number",
                    description: "The ending value"
                )
            ],
            required: ["oldValue", "newValue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let oldValue = try args.getDouble("oldValue")
        let newValue = try args.getDouble("newValue")

        let growth = growthRate(from: oldValue, to: newValue)
        let change = newValue - oldValue

        let result = """
        Growth Rate Analysis:
        • Starting Value: \(oldValue.formatDecimal())
        • Ending Value: \(newValue.formatDecimal())
        • Absolute Change: \(change.formatDecimal())
        • Growth Rate: \(growth.formatPercentage())
        """

        return .success(text: result)
    }
}

// MARK: - Calculate CAGR Tool

public struct CalculateCAGRTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cagr",
        description: "Calculate the Compound Annual Growth Rate (CAGR) between two values over a period",
        inputSchema: MCPToolInputSchema(
            properties: [
                "beginningValue": MCPSchemaProperty(
                    type: "number",
                    description: "The starting value"
                ),
                "endingValue": MCPSchemaProperty(
                    type: "number",
                    description: "The ending value"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods (years)"
                )
            ],
            required: ["beginningValue", "endingValue", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let beginningValue = try args.getDouble("beginningValue")
        let endingValue = try args.getDouble("endingValue")
        let periods = try args.getInt("periods")

        let cagrValue = cagr(
            beginningValue: beginningValue,
            endingValue: endingValue,
            years: Double(periods)
        )

        let totalGrowth = growthRate(from: beginningValue, to: endingValue)

        let result = """
        Compound Annual Growth Rate (CAGR):
        • Beginning Value: \(beginningValue.formatDecimal())
        • Ending Value: \(endingValue.formatDecimal())
        • Number of Periods: \(periods)
        • Total Growth: \(totalGrowth.formatPercentage())
        • CAGR: \(cagrValue.formatPercentage())
        """

        return .success(text: result)
    }
}

// MARK: - Time Series Statistics Tool

public struct TimeSeriesStatisticsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "time_series_statistics",
        description: "Calculate descriptive statistics for a time series (mean, median, std dev, min, max)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["data"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let values = ts.valuesArray

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Time series cannot be empty")
        }

        let meanValue = mean(values)
        let medianValue = median(values)
        let stdDevValue = stdDev(values, .sample)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0

        let result = """
        Time Series Statistics:
        • Data Points: \(values.count)
        • Mean: \(meanValue.formatDecimal())
        • Median: \(medianValue.formatDecimal())
        • Std Deviation: \(stdDevValue.formatDecimal())
        • Minimum: \(minValue.formatDecimal())
        • Maximum: \(maxValue.formatDecimal())
        • Range: \((maxValue - minValue).formatDecimal())
        """

        return .success(text: result)
    }
}

// MARK: - Moving Average Tool

public struct MovingAverageTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_moving_average",
        description: "Calculate a moving average for a time series",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                ),
                "window": MCPSchemaProperty(
                    type: "number",
                    description: "The window size for the moving average"
                )
            ],
            required: ["data", "window"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let window = try args.getInt("window")

        guard window > 0 else {
            throw ToolError.invalidArguments("Window size must be positive")
        }

        let ma = ts.movingAverage(window: window)

        var maDetails = ""
        let maPeriodsAndValues = zip(ma.periods, ma.valuesArray)
        for (index, (period, value)) in maPeriodsAndValues.prefix(10).enumerated() {
            maDetails += "\n  \(period.label): \(value.formatDecimal())"
            if index == 9 && ma.count > 10 {
                maDetails += "\n  ... (\(ma.count - 10) more)"
            }
        }

        let result = """
        Moving Average Calculation:
        • Original Data Points: \(ts.count)
        • Window Size: \(window)
        • Moving Average Points: \(ma.count)
        • First \(min(10, ma.count)) Values:\(maDetails)
        """

        return .success(text: result)
    }
}

// MARK: - Time Series Aggregation Tool

public struct TimeSeriesAggregationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "aggregate_time_series",
        description: "Aggregate time series data (sum, mean, min, max)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Aggregation method",
                    enum: ["sum", "mean", "min", "max"]
                )
            ],
            required: ["data", "method"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let method = try args.getString("method")

        guard ts.count > 0 else {
            throw ToolError.invalidArguments("Time series cannot be empty")
        }

        let values = ts.valuesArray
        let aggregatedValue: Double
        switch method {
        case "sum":
            aggregatedValue = values.reduce(0, +)
        case "mean":
            aggregatedValue = mean(values)
        case "min":
            aggregatedValue = values.min() ?? 0
        case "max":
            aggregatedValue = values.max() ?? 0
        default:
            throw ToolError.invalidArguments("Invalid aggregation method: \(method)")
        }

        let result = """
        Time Series Aggregation:
        • Data Points: \(ts.count)
        • Method: \(method.uppercased())
        • Result: \(aggregatedValue.formatDecimal())
        """

        return .success(text: result)
    }
}

/// Get all Time Series tools
public func getTimeSeriesTools() -> [any MCPToolHandler] {
    return [
        CreateTimeSeriesTool(),
        CalculateGrowthRateTool(),
        CalculateCAGRTool(),
        TimeSeriesStatisticsTool(),
        MovingAverageTool(),
        TimeSeriesAggregationTool()
    ]
}
