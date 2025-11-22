//
//  StatisticalTools.swift
//  BusinessMath MCP Server
//
//  Statistical analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all statistical analysis tools
public func getStatisticalTools() -> [any MCPToolHandler] {
    return [
        CalculateCorrelationTool(),
        LinearRegressionTool(),
        SpearmansCorrelationTool(),
        CalculateConfidenceIntervalTool(),
        CalculateCovarianceTool(),
        CalculateZScoreTool(),
        DescriptiveStatsExtendedTool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format a percentage (input is already in percentage form, e.g., 95.5 for 95.5%)
private func formatPercent(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals) + "%"
}

// MARK: - 1. Calculate Correlation (Pearson)

public struct CalculateCorrelationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_correlation",
        description: """
        Calculate Pearson correlation coefficient between two datasets.

        The correlation coefficient measures the linear relationship between two variables:
        • 1.0 = Perfect positive correlation
        • 0.0 = No linear correlation
        • -1.0 = Perfect negative correlation

        Supports both sample and population correlation.

        Example: Analyze relationship between advertising spend and revenue
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset (independent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset (dependent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "population": MCPSchemaProperty(
                    type: "string",
                    description: "Whether data represents 'sample' or 'population' (default: 'sample')",
                    enum: ["sample", "population"]
                )
            ],
            required: ["x", "y"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")
        let populationType = args.getStringOptional("population") ?? "sample"

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points to calculate correlation")
        }

        let population: Population = populationType == "population" ? .population : .sample
        let correlation = correlationCoefficient(x, y, population)

        // Interpret correlation strength
        let absCorr = abs(correlation)
        let strength = absCorr > 0.7 ? "Strong" :
                      absCorr > 0.4 ? "Moderate" :
                      absCorr > 0.2 ? "Weak" : "Very weak"
        let direction = correlation > 0 ? "positive" : "negative"

        let output = """
        Pearson Correlation Coefficient:
        • Correlation (r): \(formatNumber(correlation, decimals: 4))
        • Type: \(populationType == "population" ? "Population" : "Sample")
        • N: \(x.count) data points

        Interpretation:
        • Strength: \(strength) \(direction) correlation
        • R²: \(formatNumber(correlation * correlation, decimals: 4)) (\(formatPercent(correlation * correlation * 100))% of variance explained)

        \(correlation > 0 ? "✓ Positive relationship: as X increases, Y tends to increase" : "✗ Negative relationship: as X increases, Y tends to decrease")
        """

        return .success(text: output)
    }
}

// MARK: - 2. Linear Regression

public struct LinearRegressionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "linear_regression",
        description: """
        Perform linear regression analysis to model the relationship between variables.

        Fits the equation: y = mx + b (slope-intercept form)

        Returns:
        • Slope (m): Rate of change
        • Intercept (b): Y-value when x=0
        • R² (coefficient of determination): Goodness of fit (0-1)
        • Predictions for specified x values (optional)

        Example: Predict sales based on advertising spend
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "Independent variable (predictor)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Dependent variable (outcome)",
                    items: MCPSchemaItems(type: "number")
                ),
                "predictFor": MCPSchemaProperty(
                    type: "array",
                    description: "Optional: X values to generate predictions for",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points for regression")
        }

        // Calculate regression parameters
        let slope = try slope(x, y)
        let intercept = try intercept(x, y)
        let rSquared = rSquared(x, y, .sample)

        var output = """
        Linear Regression Analysis:

        Equation: y = \(formatNumber(slope, decimals: 4))x + \(formatNumber(intercept, decimals: 4))

        Parameters:
        • Slope (m): \(formatNumber(slope, decimals: 4))
        • Intercept (b): \(formatNumber(intercept, decimals: 4))
        • R² (goodness of fit): \(formatNumber(rSquared, decimals: 4)) (\(formatPercent(rSquared * 100))%)
        • N: \(x.count) data points

        Interpretation:
        • For each 1-unit increase in X, Y changes by \(formatNumber(slope, decimals: 4)) units
        • When X = 0, Y = \(formatNumber(intercept, decimals: 4))
        • The model explains \(formatPercent(rSquared * 100))% of the variance in Y
        """

        // Generate predictions if requested
        if let predictFor = try? args.getDoubleArray("predictFor") {
            output += "\n\nPredictions:"
            for xVal in predictFor {
                let prediction = intercept + slope * xVal
                output += "\n• X = \(formatNumber(xVal, decimals: 2)) → Y = \(formatNumber(prediction, decimals: 2))"
            }
        }

        return .success(text: output)
    }
}

// MARK: - 3. Spearman's Correlation

public struct SpearmansCorrelationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "spearmans_correlation",
        description: """
        Calculate Spearman's rank correlation coefficient (rho).

        A non-parametric measure of rank correlation that assesses monotonic relationships.
        Unlike Pearson, it works well with:
        • Non-linear monotonic relationships
        • Ordinal data
        • Data with outliers

        Values range from -1 to 1:
        • 1 = Perfect monotonic increase
        • 0 = No monotonic relationship
        • -1 = Perfect monotonic decrease

        Example: Analyze relationship between customer satisfaction rankings and sales
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 3 else {
            throw ToolError.invalidArguments("Need at least 3 data points for Spearman's correlation")
        }

        let rho = try spearmansRho(x, vs: y)

        let absRho = abs(rho)
        let strength = absRho > 0.7 ? "Strong" :
                      absRho > 0.4 ? "Moderate" :
                      absRho > 0.2 ? "Weak" : "Very weak"
        let direction = rho > 0 ? "positive" : "negative"

        let output = """
        Spearman's Rank Correlation Coefficient:
        • Spearman's rho (ρ): \(formatNumber(rho, decimals: 4))
        • N: \(x.count) data points

        Interpretation:
        • Strength: \(strength) \(direction) monotonic relationship
        • Type: Non-parametric (rank-based)

        \(rho > 0 ? "✓ Monotonic increase: higher ranks in X associate with higher ranks in Y" : "✗ Monotonic decrease: higher ranks in X associate with lower ranks in Y")

        Use Case:
        • Better than Pearson for non-linear monotonic relationships
        • Robust to outliers
        • Works with ordinal (ranked) data
        """

        return .success(text: output)
    }
}

// MARK: - 4. Calculate Confidence Interval

public struct CalculateConfidenceIntervalTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_confidence_interval",
        description: """
        Calculate confidence interval for a population parameter based on sample data.

        A confidence interval provides a range within which the true population parameter
        likely falls, with a specified level of confidence (e.g., 95%).

        Supports two modes:
        1. From raw data (automatically calculates mean and std dev)
        2. From summary statistics (mean, std dev, sample size)

        Example: Estimate the true average revenue with 95% confidence
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Sample data (use this OR use mean/stdDev/sampleSize)",
                    items: MCPSchemaItems(type: "number")
                ),
                "mean": MCPSchemaProperty(
                    type: "number",
                    description: "Sample mean (if not providing raw values)"
                ),
                "stdDev": MCPSchemaProperty(
                    type: "number",
                    description: "Sample standard deviation (if not providing raw values)"
                ),
                "sampleSize": MCPSchemaProperty(
                    type: "number",
                    description: "Sample size (if not providing raw values)"
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (e.g., 0.95 for 95% confidence, 0.90 for 90%, 0.99 for 99%). Default: 0.95"
                )
            ],
            required: []
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let confidenceLevel = args.getDoubleOptional("confidenceLevel") ?? 0.95

        guard confidenceLevel > 0 && confidenceLevel < 1 else {
            throw ToolError.invalidArguments("Confidence level must be between 0 and 1")
        }

        let meanValue: Double
        let stdDevValue: Double
        let n: Int

        // Check if using raw values or summary statistics
        if let values = try? args.getDoubleArray("values") {
            guard !values.isEmpty else {
                throw ToolError.invalidArguments("Values array cannot be empty")
            }
            meanValue = mean(values)
            stdDevValue = stdDev(values, .sample)
            n = values.count
        } else {
            // Use summary statistics
            meanValue = try args.getDouble("mean")
            stdDevValue = try args.getDouble("stdDev")
            n = try args.getInt("sampleSize")

            guard n > 0 else {
                throw ToolError.invalidArguments("Sample size must be positive")
            }
            guard stdDevValue >= 0 else {
                throw ToolError.invalidArguments("Standard deviation cannot be negative")
            }
        }

        // Calculate confidence interval
        let ci = confidenceInterval(ci: confidenceLevel, values: Array(repeating: meanValue, count: n))

        let marginOfError = (ci.high - ci.low) / 2

        let output = """
        Confidence Interval:

        \(formatPercent(confidenceLevel * 100))% Confidence Interval: [\(formatNumber(ci.low, decimals: 4)), \(formatNumber(ci.high, decimals: 4))]

        Sample Statistics:
        • Mean: \(formatNumber(meanValue, decimals: 4))
        • Standard Deviation: \(formatNumber(stdDevValue, decimals: 4))
        • Sample Size: \(n)

        Margin of Error:
        • ± \(formatNumber(marginOfError, decimals: 4))

        Interpretation:
        We are \(formatPercent(confidenceLevel * 100))% confident that the true population
        parameter falls within the interval [\(formatNumber(ci.low, decimals: 2)), \(formatNumber(ci.high, decimals: 2))].
        """

        return .success(text: output)
    }
}

// MARK: - 5. Calculate Covariance

public struct CalculateCovarianceTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_covariance",
        description: """
        Calculate covariance between two datasets.

        Covariance measures how much two variables change together:
        • Positive: Variables tend to move in the same direction
        • Negative: Variables tend to move in opposite directions
        • Zero: No linear relationship

        Unlike correlation, covariance is not standardized, so its magnitude
        depends on the scale of the variables.

        Supports both sample and population covariance.

        Example: Measure how revenue and costs vary together
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "population": MCPSchemaProperty(
                    type: "string",
                    description: "Whether data represents 'sample' or 'population' (default: 'sample')",
                    enum: ["sample", "population"]
                )
            ],
            required: ["x", "y"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")
        let populationType = args.getStringOptional("population") ?? "sample"

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points to calculate covariance")
        }

        let population: Population = populationType == "population" ? .population : .sample
        let cov = covariance(x, y, population)

        // Calculate correlation for context
        let corr = correlationCoefficient(x, y, population)

        let output = """
        Covariance Analysis:
        • Covariance: \(formatNumber(cov, decimals: 4))
        • Type: \(populationType == "population" ? "Population" : "Sample")
        • N: \(x.count) data points

        Related Metrics:
        • Correlation: \(formatNumber(corr, decimals: 4)) (standardized covariance)

        Interpretation:
        \(cov > 0 ? "✓ Positive covariance: variables tend to move together" : cov < 0 ? "✗ Negative covariance: variables tend to move in opposite directions" : "○ Zero covariance: no linear relationship")

        Note: Unlike correlation, covariance is not bounded and depends on
        the scale of the variables. Use correlation for standardized comparison.
        """

        return .success(text: output)
    }
}

// MARK: - 6. Calculate Z-Score (for correlation)

public struct CalculateZScoreTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_z_score",
        description: """
        Calculate z-score for testing correlation significance.

        The z-score quantifies how many standard deviations a correlation coefficient
        is from zero, helping determine if a correlation is statistically significant.

        Uses Spearman's rank correlation and Fisher's Z-transformation.

        Interpretation:
        • |z| > 2.576: Significant at 99% confidence level
        • |z| > 1.96: Significant at 95% confidence level
        • |z| > 1.645: Significant at 90% confidence level

        Example: Test if correlation between variables is statistically significant
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset (independent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset (dependent variable)",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 3 else {
            throw ToolError.invalidArguments("Need at least 3 data points for z-score calculation")
        }

        let z = try zScore(x, vs: y)
        let absZ = abs(z)

        let significance = absZ > 2.576 ? "Highly significant (99% confidence)" :
                          absZ > 1.96 ? "Significant (95% confidence)" :
                          absZ > 1.645 ? "Marginally significant (90% confidence)" :
                          "Not significant"

        let output = """
        Z-Score for Correlation Significance:

        • Z-Score: \(formatNumber(z, decimals: 4))
        • |Z-Score|: \(formatNumber(absZ, decimals: 4))
        • N: \(x.count) data points

        Significance:
        • Result: \(significance)

        Critical Values:
        • 90% confidence: |z| > 1.645 \(absZ > 1.645 ? "✓" : "✗")
        • 95% confidence: |z| > 1.96 \(absZ > 1.96 ? "✓" : "✗")
        • 99% confidence: |z| > 2.576 \(absZ > 2.576 ? "✓" : "✗")

        Interpretation:
        \(absZ > 1.96 ? "The correlation is statistically significant - unlikely to be due to chance." : "The correlation is not statistically significant at the 95% level.")
        """

        return .success(text: output)
    }
}

// MARK: - 7. Descriptive Statistics (Extended)

public struct DescriptiveStatsExtendedTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "descriptive_stats_extended",
        description: """
        Calculate comprehensive descriptive statistics for a dataset.

        Provides:
        • Central Tendency: mean, median
        • Dispersion: std dev, variance, range, min, max
        • Shape: skewness (asymmetry measure)
        • Percentiles: 25th, 50th, 75th (quartiles)
        • Interquartile Range (IQR)

        Skewness interpretation:
        • > 0: Right-skewed (long tail on right)
        • = 0: Symmetric
        • < 0: Left-skewed (long tail on left)

        Example: Comprehensive analysis of sales data distribution
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Dataset to analyze",
                    items: MCPSchemaItems(type: "number")
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

        let values = try args.getDoubleArray("values")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Values array cannot be empty")
        }

        // Use SimulationStatistics for comprehensive stats
        let stats = SimulationStatistics(values: values)
        let percentiles = try Percentiles(values: values)

        let range = stats.max - stats.min

        // Interpret skewness
        let skewnessInterpretation: String
        if abs(stats.skewness) < 0.5 {
            skewnessInterpretation = "Approximately symmetric"
        } else if stats.skewness > 0 {
            skewnessInterpretation = "Right-skewed (tail extends right)"
        } else {
            skewnessInterpretation = "Left-skewed (tail extends left)"
        }

        let output = """
        Comprehensive Descriptive Statistics:

        Central Tendency:
        • Mean: \(formatNumber(stats.mean, decimals: 4))
        • Median: \(formatNumber(stats.median, decimals: 4))

        Dispersion:
        • Standard Deviation: \(formatNumber(stats.stdDev, decimals: 4))
        • Variance: \(formatNumber(stats.variance, decimals: 4))
        • Range: \(formatNumber(range, decimals: 4))
        • Minimum: \(formatNumber(stats.min, decimals: 4))
        • Maximum: \(formatNumber(stats.max, decimals: 4))

        Distribution Shape:
        • Skewness: \(formatNumber(stats.skewness, decimals: 4)) (\(skewnessInterpretation))

        Percentiles (Quartiles):
        • Q1 (25th percentile): \(formatNumber(percentiles.p25, decimals: 4))
        • Q2 (50th percentile): \(formatNumber(percentiles.p50, decimals: 4))
        • Q3 (75th percentile): \(formatNumber(percentiles.p75, decimals: 4))
        • Interquartile Range (IQR): \(formatNumber(percentiles.interquartileRange, decimals: 4))

        Additional Percentiles:
        • 5th: \(formatNumber(percentiles.p5, decimals: 4))
        • 10th: \(formatNumber(percentiles.p10, decimals: 4))
        • 90th: \(formatNumber(percentiles.p90, decimals: 4))
        • 95th: \(formatNumber(percentiles.p95, decimals: 4))

        Sample Size:
        • N: \(values.count) observations

        Interpretation:
        \(abs(stats.mean - stats.median) < stats.stdDev * 0.1 ? "✓ Mean ≈ Median suggests symmetric distribution" : "✗ Mean ≠ Median suggests skewed distribution")
        """

        return .success(text: output)
    }
}
