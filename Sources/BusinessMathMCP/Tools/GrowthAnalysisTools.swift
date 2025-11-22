//
//  GrowthAnalysisTools.swift
//  BusinessMath MCP Server
//
//  Growth rate calculation and projection tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all growth analysis tools
public func getGrowthAnalysisTools() -> [any MCPToolHandler] {
    return [
        GrowthRateTool(),
        ApplyGrowthTool()
    ]
}

// MARK: - Helper Functions

/// Format a rate as percentage
private func formatRate(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

/// Format currency
private func formatCurrency(_ value: Double, decimals: Int = 2) -> String {
    let formatted = abs(value).formatDecimal(decimals: decimals)
    return value >= 0 ? "$\(formatted)" : "-$\(formatted)"
}

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

// MARK: - Growth Rate

public struct GrowthRateTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_growth_rate",
        description: """
        Calculate simple period-over-period growth rate between two values.

        The growth rate represents the percentage change from an initial value to a final value.

        Formula: Growth Rate = (To - From) / From

        This is the simplest form of growth calculation, showing the total percentage
        change without considering time periods or compounding effects.

        Use Cases:
        • Quarter-over-quarter revenue growth
        • Year-over-year sales comparison
        • Price appreciation/depreciation
        • Performance metric changes
        • Budget vs actual variance
        • Market share changes

        Example 1 - Revenue Growth:
        Q1 Revenue: $1,000,000
        Q2 Revenue: $1,150,000
        Growth Rate: 15% increase

        Example 2 - Cost Reduction:
        Previous: $500,000
        Current: $425,000
        Growth Rate: -15% (15% reduction)

        Example 3 - Customer Growth:
        Last Year: 10,000 customers
        This Year: 12,500 customers
        Growth Rate: 25% increase

        When to Use:
        • Comparing two specific points in time
        • Simple percentage change calculation
        • No need for annualization or compounding
        • Quick performance snapshots

        When to Use CAGR Instead:
        • Multi-period growth over years
        • Comparing growth across different time frames
        • Need for annualized rate
        • Smoothing volatile period-to-period changes

        Business Applications:
        • Financial reporting: Show period changes
        • Sales analysis: Track performance trends
        • KPI tracking: Monitor key metrics
        • Benchmarking: Compare against industry standards
        • Forecasting: Project future values based on historical growth
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "fromValue": MCPSchemaProperty(
                    type: "number",
                    description: "Initial (starting) value"
                ),
                "toValue": MCPSchemaProperty(
                    type: "number",
                    description: "Final (ending) value"
                ),
                "metricName": MCPSchemaProperty(
                    type: "string",
                    description: "Optional name for the metric (e.g., 'Revenue', 'Customers', 'Sales')"
                )
            ],
            required: ["fromValue", "toValue"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let fromValue = try args.getDouble("fromValue")
        let toValue = try args.getDouble("toValue")
        let metricName = args.getStringOptional("metricName") ?? "Value"

        // Calculate growth rate
        let growth = growthRate(from: fromValue, to: toValue)

        // Handle edge cases
        if fromValue == 0 {
            let output = """
            Growth Rate Analysis: \(metricName)

            Initial Value: \(formatCurrency(fromValue))
            Final Value: \(formatCurrency(toValue))

            Result: Cannot calculate growth rate

            Explanation:
            Growth rate is undefined when starting from zero. You cannot calculate
            a percentage change from a base of zero.

            Alternative Analysis:
            • Absolute change: \(formatCurrency(toValue - fromValue))
            • If starting from zero, consider:
              - Using absolute values instead of percentages
              - Different baseline for comparison
              - Count-based metrics if applicable
            """
            return .success(text: output)
        }

        if growth.isInfinite {
            let output = """
            Growth Rate Analysis: \(metricName)

            Initial Value: \(formatCurrency(fromValue))
            Final Value: \(formatCurrency(toValue))

            Result: Infinite growth rate

            This occurs in exceptional cases and typically indicates a data error.
            """
            return .success(text: output)
        }

        // Calculate absolute change
        let absoluteChange = toValue - fromValue

        // Interpretation
        let direction: String
        let interpretation: String
        let recommendation: String

        if growth > 0.50 {
            direction = "Strong Growth"
            interpretation = "Exceptional positive performance - over 50% increase"
            recommendation = "Investigate drivers of success for replication. Verify sustainability."
        } else if growth > 0.20 {
            direction = "Significant Growth"
            interpretation = "Strong positive performance - substantial increase"
            recommendation = "Solid growth trajectory. Monitor for consistency and scalability."
        } else if growth > 0.10 {
            direction = "Healthy Growth"
            interpretation = "Good positive performance - healthy increase"
            recommendation = "Positive trend. Continue current strategies."
        } else if growth > 0 {
            direction = "Modest Growth"
            interpretation = "Slight positive performance - moderate increase"
            recommendation = "Positive but modest. Consider opportunities for acceleration."
        } else if growth == 0 {
            direction = "No Change"
            interpretation = "Flat performance - no growth or decline"
            recommendation = "Stagnation may indicate market maturity or strategic issues."
        } else if growth > -0.10 {
            direction = "Slight Decline"
            interpretation = "Small negative performance - minor decrease"
            recommendation = "Monitor closely. May be temporary or early warning sign."
        } else if growth > -0.20 {
            direction = "Moderate Decline"
            interpretation = "Concerning negative performance - significant decrease"
            recommendation = "Requires attention. Investigate root causes and corrective actions."
        } else if growth > -0.50 {
            direction = "Significant Decline"
            interpretation = "Serious negative performance - major decrease"
            recommendation = "Urgent action needed. Major issues require immediate intervention."
        } else {
            direction = "Severe Decline"
            interpretation = "Critical negative performance - catastrophic decrease"
            recommendation = "Crisis situation. Emergency measures required."
        }

        // Calculate what value would be needed for various growth targets
        let tenPercentTarget = fromValue * 1.10
        let twentyPercentTarget = fromValue * 1.20

        let output = """
        Growth Rate Analysis: \(metricName)

        Values:
        • Initial (From): \(formatCurrency(fromValue))
        • Final (To): \(formatCurrency(toValue))
        • Absolute Change: \(formatCurrency(absoluteChange))

        Result:
        • Growth Rate: \(formatRate(growth))

        Assessment: \(direction)

        Interpretation:
        \(interpretation)

        Context:
        \(growth >= 0 ? """
        • For every $1.00 initially, you now have $\(formatNumber(1.0 + growth, decimals: 2))
        • \(metricName) increased by \(formatNumber(absoluteChange))
        • This represents a \(formatRate(abs(growth))) improvement
        """ : """
        • For every $1.00 initially, you now have $\(formatNumber(1.0 + growth, decimals: 2))
        • \(metricName) decreased by \(formatNumber(abs(absoluteChange)))
        • This represents a \(formatRate(abs(growth))) reduction
        """)

        Benchmark Targets:
        • 10% growth would require: \(formatCurrency(tenPercentTarget)) (gap: \(formatCurrency(tenPercentTarget - toValue)))
        • 20% growth would require: \(formatCurrency(twentyPercentTarget)) (gap: \(formatCurrency(twentyPercentTarget - toValue)))

        Recommendation:
        \(recommendation)

        Note: This is a SIMPLE growth rate for one period.
        • Does not account for compounding across multiple periods
        • For multi-year growth, consider using CAGR (Compound Annual Growth Rate)
        • For projections, consider using growth projection tools with compounding
        """

        return .success(text: output)
    }
}

// MARK: - Apply Growth

public struct ApplyGrowthTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "apply_growth_projection",
        description: """
        Project future values by applying a growth rate with specified compounding frequency.

        This tool generates a complete projection series showing how a value grows over time
        given an annual growth rate and compounding frequency.

        Formulas:

        Discrete Compounding:
        Value = Base × (1 + r/n)^(n×t)

        Continuous Compounding:
        Value = Base × e^(r×t)

        Where:
        • r = annual growth rate
        • n = compounding periods per year
        • t = time in years

        Compounding Frequencies:
        • Annual: Compounds once per year (simplest)
        • Semiannual: Compounds twice per year
        • Quarterly: Compounds 4 times per year
        • Monthly: Compounds 12 times per year (common for loans, savings)
        • Daily: Compounds 365 times per year (bank accounts)
        • Continuous: Infinite compounding (theoretical maximum, uses e^rt)

        Use Cases:
        • Revenue projections with assumed growth rate
        • Investment growth forecasting
        • Population growth modeling
        • Inflation-adjusted future values
        • Market size projections
        • Customer base growth forecasting
        • Technology adoption curves

        Example 1 - Revenue Projection:
        Current Revenue: $1,000,000
        Growth Rate: 15% annual
        Periods: 5 years
        Compounding: Annual
        Result: $1M, $1.15M, $1.32M, $1.52M, $1.75M, $2.01M

        Example 2 - Investment Growth:
        Principal: $10,000
        Return: 7% annual
        Periods: 10 years
        Compounding: Monthly
        Result: More than $20,000 (higher than annual due to monthly compounding)

        Example 3 - Customer Growth:
        Current Customers: 5,000
        Growth Rate: 25% annual
        Periods: 3 years
        Result: 5K → 6.25K → 7.81K → 9.77K

        Impact of Compounding Frequency:
        $1,000 at 12% for 1 year:
        • Annual: $1,120.00
        • Quarterly: $1,125.51
        • Monthly: $1,126.83
        • Daily: $1,127.47
        • Continuous: $1,127.50

        Higher frequency = Higher final value (but diminishing returns)

        When to Use:
        • Need detailed period-by-period projection
        • Understanding compounding effects
        • Creating financial forecasts
        • Scenario planning
        • Sensitivity analysis with different growth rates
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "baseValue": MCPSchemaProperty(
                    type: "number",
                    description: "Starting value at time 0 (current value)"
                ),
                "annualGrowthRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual growth rate as decimal (e.g., 0.15 for 15% growth)"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to project (interpretation depends on compounding frequency)"
                ),
                "compounding": MCPSchemaProperty(
                    type: "string",
                    description: "Compounding frequency: 'annual', 'semiannual', 'quarterly', 'monthly', 'daily', or 'continuous' (default: 'annual')"
                ),
                "metricName": MCPSchemaProperty(
                    type: "string",
                    description: "Optional name for the metric being projected (e.g., 'Revenue', 'Customers')"
                )
            ],
            required: ["baseValue", "annualGrowthRate", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let baseValue = try args.getDouble("baseValue")
        let annualRate = try args.getDouble("annualGrowthRate")
        let periods = try args.getInt("periods")
        let compoundingStr = args.getStringOptional("compounding") ?? "annual"
        let metricName = args.getStringOptional("metricName") ?? "Value"

        // Validate periods
        guard periods > 0 && periods <= 100 else {
            throw ToolError.invalidArguments("Periods must be between 1 and 100")
        }

        // Parse compounding frequency
        let compounding: CompoundingFrequency
        switch compoundingStr.lowercased() {
        case "annual": compounding = .annual
        case "semiannual": compounding = .semiannual
        case "quarterly": compounding = .quarterly
        case "monthly": compounding = .monthly
        case "daily": compounding = .daily
        case "continuous": compounding = .continuous
        default:
            throw ToolError.invalidArguments("Invalid compounding frequency. Use: annual, semiannual, quarterly, monthly, daily, or continuous")
        }

        // Apply growth
        let projection = applyGrowth(
            baseValue: baseValue,
            rate: annualRate,
            periods: periods,
            compounding: compounding
        )

        // Calculate summary statistics
        let finalValue = projection.last ?? baseValue
        let totalGrowth = (finalValue - baseValue) / baseValue
        let averageValue = projection.reduce(0.0, +) / Double(projection.count)

        // Calculate effective rate (what the growth actually works out to per period)
        let effectiveRate: Double
        let periodsPerYearCount: Double
        switch compounding {
        case .continuous:
            effectiveRate = annualRate
            periodsPerYearCount = Double.infinity
        case .annual:
            periodsPerYearCount = 1.0
            effectiveRate = annualRate
        case .semiannual:
            periodsPerYearCount = 2.0
            effectiveRate = annualRate / periodsPerYearCount
        case .quarterly:
            periodsPerYearCount = 4.0
            effectiveRate = annualRate / periodsPerYearCount
        case .monthly:
            periodsPerYearCount = 12.0
            effectiveRate = annualRate / periodsPerYearCount
        case .daily:
            periodsPerYearCount = 365.0
            effectiveRate = annualRate / periodsPerYearCount
        }

        // Format projection table (show first few, middle, and last few if long)
        let projectionTable: String
        if projection.count <= 12 {
            projectionTable = projection.enumerated().map { period, value in
                let growth = period == 0 ? 0.0 : (value - projection[period - 1]) / projection[period - 1]
                return "  Period \(period): \(formatCurrency(value))\(period > 0 ? " (+\(formatRate(growth)))" : "")"
            }.joined(separator: "\n")
        } else {
            let first5 = projection.prefix(6).enumerated().map { period, value in
                let growth = period == 0 ? 0.0 : (value - projection[period - 1]) / projection[period - 1]
                return "  Period \(period): \(formatCurrency(value))\(period > 0 ? " (+\(formatRate(growth)))" : "")"
            }.joined(separator: "\n")

            let last5 = projection.suffix(5).enumerated().map { idx, value in
                let period = projection.count - 5 + idx
                let growth = (value - projection[period - 1]) / projection[period - 1]
                return "  Period \(period): \(formatCurrency(value)) (+\(formatRate(growth)))"
            }.joined(separator: "\n")

            projectionTable = first5 + "\n  ...\n" + last5
        }

        // Time interpretation based on compounding
        let timeInterpretation: String
        switch compounding {
        case .annual:
            timeInterpretation = "\(periods) years"
        case .semiannual:
            timeInterpretation = "\(periods) half-years (\(Double(periods) / 2.0) years)"
        case .quarterly:
            timeInterpretation = "\(periods) quarters (\(Double(periods) / 4.0) years)"
        case .monthly:
            timeInterpretation = "\(periods) months (\(Double(periods) / 12.0) years)"
        case .daily:
            timeInterpretation = "\(periods) days (\(Double(periods) / 365.0) years)"
        case .continuous:
            timeInterpretation = "\(periods) years (continuous compounding)"
        }

        // Compare with other compounding frequencies
        let comparisonValues: [String: Double] = [
            "Annual": applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .annual).last ?? 0,
            "Quarterly": applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .quarterly).last ?? 0,
            "Monthly": applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .monthly).last ?? 0,
            "Daily": applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .daily).last ?? 0,
            "Continuous": applyGrowth(baseValue: baseValue, rate: annualRate, periods: periods, compounding: .continuous).last ?? 0
        ]

        let output = """
        Growth Projection: \(metricName)

        Input Parameters:
        • Base Value: \(formatCurrency(baseValue))
        • Annual Growth Rate: \(formatRate(annualRate))
        • Projection Periods: \(periods) (\(timeInterpretation))
        • Compounding: \(compoundingStr.capitalized) (\(compounding == .continuous ? "∞" : "\(compounding.periodsPerYear)") periods/year)
        • Effective Rate per Period: \(formatRate(effectiveRate))

        Projection Results:
        \(projectionTable)

        Summary:
        • Starting Value: \(formatCurrency(baseValue))
        • Final Value: \(formatCurrency(finalValue))
        • Total Growth: \(formatRate(totalGrowth)) (\(formatCurrency(finalValue - baseValue)))
        • Average Value: \(formatCurrency(averageValue))
        • Growth Multiple: \(formatNumber(finalValue / baseValue, decimals: 2))x

        Compounding Frequency Comparison (Final Values):
        • Annual: \(formatCurrency(comparisonValues["Annual"]!))
        • Quarterly: \(formatCurrency(comparisonValues["Quarterly"]!))
        • Monthly: \(formatCurrency(comparisonValues["Monthly"]!))
        • Daily: \(formatCurrency(comparisonValues["Daily"]!))
        • Continuous: \(formatCurrency(comparisonValues["Continuous"]!))
        • Difference (Monthly vs Annual): \(formatCurrency(comparisonValues["Monthly"]! - comparisonValues["Annual"]!))

        Interpretation:
        \(annualRate > 0 ? """
        At \(formatRate(annualRate)) annual growth with \(compoundingStr) compounding:
        • \(metricName) grows from \(formatCurrency(baseValue)) to \(formatCurrency(finalValue))
        • This represents \(formatNumber((finalValue / baseValue), decimals: 2))x multiplication
        • Each period adds approximately \(formatRate(effectiveRate)) (adjusted for compounding)
        • More frequent compounding increases final value
        """ : annualRate < 0 ? """
        At \(formatRate(annualRate)) annual decline with \(compoundingStr) compounding:
        • \(metricName) decreases from \(formatCurrency(baseValue)) to \(formatCurrency(finalValue))
        • This represents \(formatRate(totalGrowth)) total decline
        • Compounding accelerates the decline
        • Final value is \(formatNumber((finalValue / baseValue) * 100, decimals: 1))% of original
        """ : """
        Zero growth rate:
        • \(metricName) remains constant at \(formatCurrency(baseValue))
        • No change over time
        • Compounding has no effect at 0% growth
        """)

        Use Cases:
        • Financial forecasting and planning
        • Scenario analysis with different growth assumptions
        • Understanding compounding effects over time
        • Creating pro-forma projections
        • Sensitivity analysis
        """

        return .success(text: output)
    }
}
