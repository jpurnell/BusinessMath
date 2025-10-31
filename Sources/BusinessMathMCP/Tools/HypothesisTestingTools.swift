//
//  HypothesisTestingTools.swift
//  BusinessMath MCP Server
//
//  Statistical hypothesis testing and inference tools
//

import Foundation
import BusinessMath
import MCP

// MARK: - Tool 1: Hypothesis T-Test

public struct HypothesisTTestTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "hypothesis_t_test",
        description: """
        Perform a t-test to compare means and determine statistical significance.

        Supports:
        - **Two-sample t-test**: Compare means between two independent groups (e.g., A/B testing, before/after comparison)
        - **One-sample t-test**: Test if a sample mean differs from a known population mean

        REQUIRED STRUCTURE:
        {
          "sample1": [85.0, 90.0, 88.0, 92.0, 87.0],
          "sample2": [78.0, 82.0, 80.0, 79.0, 81.0],
          "alpha": 0.05
        }

        OR for one-sample test:
        {
          "sample1": [95.0, 102.0, 98.0, 104.0, 97.0],
          "populationMean": 100.0,
          "alpha": 0.05
        }

        **Examples:**

        1. Compare sales between two stores:
        {
          "sample1": [1200, 1350, 1180, 1420, 1290],
          "sample2": [980, 1050, 1120, 970, 1040],
          "alpha": 0.05
        }

        2. Test if average customer spend = $50:
        {
          "sample1": [48.5, 52.3, 49.1, 51.8, 47.9],
          "populationMean": 50.0,
          "alpha": 0.05
        }

        Returns t-statistic, p-value, degrees of freedom, and significance conclusion.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "sample1": MCPSchemaProperty(
                    type: "array",
                    description: """
                    First sample data (required). Array of numbers.
                    Example: [85.0, 90.0, 88.0, 92.0, 87.0]
                    """,
                    items: MCPSchemaItems(type: "number")
                ),
                "sample2": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Second sample data (optional, for two-sample test). Array of numbers.
                    Omit this for one-sample test.
                    Example: [78.0, 82.0, 80.0, 79.0, 81.0]
                    """,
                    items: MCPSchemaItems(type: "number")
                ),
                "populationMean": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Known population mean (optional, for one-sample test). Number.
                    Example: 100.0
                    """
                ),
                "alpha": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Significance level (default: 0.05 for 95% confidence). Common values: 0.01, 0.05, 0.10.
                    Example: 0.05
                    """
                )
            ],
            required: ["sample1"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Extract sample1 (required)
        guard let sample1AnyCodable = args["sample1"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'sample1' array")
        }

        var sample1: [Double] = []
        for item in sample1AnyCodable {
            if let doubleVal = item.value as? Double {
                sample1.append(doubleVal)
            } else if let intVal = item.value as? Int {
                sample1.append(Double(intVal))
            } else {
                throw ToolError.invalidArguments("sample1 must contain only numbers")
            }
        }

        guard sample1.count >= 2 else {
            throw ToolError.invalidArguments("sample1 must contain at least 2 values")
        }

        let alpha = args.getDoubleOptional("alpha") ?? 0.05

        // Check if this is a two-sample or one-sample test
        if let sample2AnyCodable = args["sample2"]?.value as? [AnyCodable] {
            // Two-sample t-test
            var sample2: [Double] = []
            for item in sample2AnyCodable {
                if let doubleVal = item.value as? Double {
                    sample2.append(doubleVal)
                } else if let intVal = item.value as? Int {
                    sample2.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("sample2 must contain only numbers")
                }
            }

            guard sample2.count >= 2 else {
                throw ToolError.invalidArguments("sample2 must contain at least 2 values")
            }

            // Calculate two-sample t-test
            let mean1 = sample1.reduce(0, +) / Double(sample1.count)
            let mean2 = sample2.reduce(0, +) / Double(sample2.count)

            let var1 = sample1.map { pow($0 - mean1, 2) }.reduce(0, +) / Double(sample1.count - 1)
            let var2 = sample2.map { pow($0 - mean2, 2) }.reduce(0, +) / Double(sample2.count - 1)

            let n1 = Double(sample1.count)
            let n2 = Double(sample2.count)

            let pooledStdError = sqrt(var1/n1 + var2/n2)
            let tStatistic = (mean1 - mean2) / pooledStdError

            let df = n1 + n2 - 2

            // Simplified p-value estimation (using normal approximation for large samples)
            let pValue = 2.0 * (1.0 - normSDist(zScore: abs(tStatistic)))

            let isSignificant = pValue < alpha

            let result = """
            ## Two-Sample T-Test Results

            **Sample 1:**
            - Size: \(Int(n1))
            - Mean: \(mean1.formatDecimal())
            - Std Dev: \(sqrt(var1).formatDecimal())

            **Sample 2:**
            - Size: \(Int(n2))
            - Mean: \(mean2.formatDecimal())
            - Std Dev: \(sqrt(var2).formatDecimal())

            **Test Statistics:**
            - T-statistic: \(tStatistic.formatDecimal(decimals: 4))
            - Degrees of Freedom: \(Int(df))
            - P-value: \(pValue.formatDecimal(decimals: 4))
            - Significance Level (α): \(alpha)

            **Conclusion:**
            \(isSignificant ? "✓" : "✗") The difference between means is \(isSignificant ? "" : "NOT ")statistically significant at α = \(alpha)

            **Interpretation:**
            - Mean Difference: \((mean1 - mean2).formatDecimal())
            - \(isSignificant ? "The two groups have significantly different means." : "There is insufficient evidence that the two groups differ.")
            """

            return MCPToolCallResult.success(text: result)

        } else if let populationMean = args.getDoubleOptional("populationMean") {
            // One-sample t-test
            let sampleMean = sample1.reduce(0, +) / Double(sample1.count)
            let variance = sample1.map { pow($0 - sampleMean, 2) }.reduce(0, +) / Double(sample1.count - 1)
            let stdDev = sqrt(variance)
            let n = Double(sample1.count)

            let tStatistic = (sampleMean - populationMean) / (stdDev / sqrt(n))
            let df = n - 1

            // Simplified p-value estimation
            let pValue = 2.0 * (1.0 - normSDist(zScore: abs(tStatistic)))

            let isSignificant = pValue < alpha

            let result = """
            ## One-Sample T-Test Results

            **Sample:**
            - Size: \(Int(n))
            - Mean: \(sampleMean.formatDecimal())
            - Std Dev: \(stdDev.formatDecimal())

            **Population:**
            - Hypothesized Mean: \(populationMean.formatDecimal())

            **Test Statistics:**
            - T-statistic: \(tStatistic.formatDecimal(decimals: 4))
            - Degrees of Freedom: \(Int(df))
            - P-value: \(pValue.formatDecimal(decimals: 4))
            - Significance Level (α): \(alpha)

            **Conclusion:**
            \(isSignificant ? "✓" : "✗") The sample mean is \(isSignificant ? "" : "NOT ")significantly different from the population mean at α = \(alpha)

            **Interpretation:**
            - Difference: \((sampleMean - populationMean).formatDecimal())
            - \(isSignificant ? "The sample appears to come from a different population." : "The sample is consistent with the hypothesized population mean.")
            """

            return MCPToolCallResult.success(text: result)

        } else {
            throw ToolError.invalidArguments("Must provide either 'sample2' (two-sample test) or 'populationMean' (one-sample test)")
        }
    }
}

// MARK: - Tool 2: Chi-Square Test

public struct HypothesisChiSquareTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "hypothesis_chi_square",
        description: """
        Perform chi-square test for independence or goodness-of-fit.

        Tests whether observed categorical data differs significantly from expected distributions.

        REQUIRED STRUCTURE:
        {
          "observed": [45, 35, 20],
          "expected": [40, 40, 20],
          "alpha": 0.05
        }

        **Examples:**

        1. Test product preference across regions:
        {
          "observed": [120, 80, 95, 105],
          "expected": [100, 100, 100, 100],
          "alpha": 0.05
        }

        2. Test if survey responses match population:
        {
          "observed": [65, 25, 10],
          "expected": [60, 30, 10],
          "alpha": 0.05
        }

        Returns chi-square statistic, degrees of freedom, p-value, and significance conclusion.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "observed": MCPSchemaProperty(
                    type: "array",
                    description: "Observed frequencies for each category. Array of numbers. Example: [45, 35, 20]",
                    items: MCPSchemaItems(type: "number")
                ),
                "expected": MCPSchemaProperty(
                    type: "array",
                    description: "Expected frequencies for each category. Must be same length as observed. Example: [40, 40, 20]",
                    items: MCPSchemaItems(type: "number")
                ),
                "alpha": MCPSchemaProperty(
                    type: "number",
                    description: "Significance level (default: 0.05). Example: 0.05"
                )
            ],
            required: ["observed", "expected"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Extract observed and expected arrays
        guard let observedAnyCodable = args["observed"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'observed' array")
        }

        guard let expectedAnyCodable = args["expected"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'expected' array")
        }

        var observed: [Double] = []
        for item in observedAnyCodable {
            if let doubleVal = item.value as? Double {
                observed.append(doubleVal)
            } else if let intVal = item.value as? Int {
                observed.append(Double(intVal))
            } else {
                throw ToolError.invalidArguments("observed must contain only numbers")
            }
        }

        var expected: [Double] = []
        for item in expectedAnyCodable {
            if let doubleVal = item.value as? Double {
                expected.append(doubleVal)
            } else if let intVal = item.value as? Int {
                expected.append(Double(intVal))
            } else {
                throw ToolError.invalidArguments("expected must contain only numbers")
            }
        }

        guard observed.count == expected.count else {
            throw ToolError.invalidArguments("observed and expected arrays must have the same length")
        }

        guard observed.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 categories")
        }

        let alpha = args.getDoubleOptional("alpha") ?? 0.05

        // Calculate chi-square statistic
        var chiSquare = 0.0
        for i in 0..<observed.count {
            guard expected[i] > 0 else {
                throw ToolError.invalidArguments("Expected frequencies must be greater than 0")
            }
            chiSquare += pow(observed[i] - expected[i], 2) / expected[i]
        }

        let df = observed.count - 1

        // Simplified critical value lookup (approximate)
        let criticalValues: [Int: Double] = [
            1: 3.841, 2: 5.991, 3: 7.815, 4: 9.488, 5: 11.070,
            6: 12.592, 7: 14.067, 8: 15.507, 9: 16.919, 10: 18.307
        ]

        let criticalValue = criticalValues[df] ?? 18.307
        let isSignificant = chiSquare > criticalValue

        // Rough p-value estimation (for reporting only)
        let pValueEstimate = isSignificant ? "< 0.05" : "> 0.05"

        var categoryDetails = ""
        for i in 0..<observed.count {
            let contribution = pow(observed[i] - expected[i], 2) / expected[i]
            categoryDetails += "\n  Category \(i+1): Observed=\(observed[i].formatDecimal(decimals: 0)), Expected=\(expected[i].formatDecimal(decimals: 0)), Contribution=\(contribution.formatDecimal(decimals: 2))"
        }

        let result = """
        ## Chi-Square Test Results

        **Data:**
        - Number of Categories: \(observed.count)
        - Total Observed: \(observed.reduce(0, +).formatDecimal(decimals: 0))
        - Total Expected: \(expected.reduce(0, +).formatDecimal(decimals: 0))

        **Category Breakdown:**\(categoryDetails)

        **Test Statistics:**
        - Chi-Square Statistic: \(chiSquare.formatDecimal(decimals: 3))
        - Degrees of Freedom: \(df)
        - Critical Value (α=\(alpha)): \(criticalValue.formatDecimal(decimals: 3))
        - P-value: \(pValueEstimate)

        **Conclusion:**
        \(isSignificant ? "✓" : "✗") The observed distribution is \(isSignificant ? "" : "NOT ")significantly different from expected at α = \(alpha)

        **Interpretation:**
        \(isSignificant ? "The observed frequencies deviate significantly from what was expected." : "The observed frequencies are consistent with the expected distribution.")
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 3: Calculate Sample Size

public struct CalculateSampleSizeTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_sample_size",
        description: """
        Calculate required sample size for statistical significance.

        Determines how many observations are needed for a study to achieve desired confidence and margin of error.

        REQUIRED STRUCTURE:
        {
          "confidence": 0.95,
          "marginOfError": 0.05,
          "proportion": 0.5,
          "populationSize": 10000
        }

        **Parameters:**
        - **confidence**: Confidence level (e.g., 0.95 for 95%)
        - **marginOfError**: Acceptable error (e.g., 0.05 for ±5%)
        - **proportion**: Expected proportion (use 0.5 for worst-case/maximum sample size)
        - **populationSize**: Total population size (use large number like 1000000 for infinite population)

        **Examples:**

        1. Survey with 95% confidence, 5% margin of error:
        {
          "confidence": 0.95,
          "marginOfError": 0.05,
          "proportion": 0.5,
          "populationSize": 10000
        }

        2. Customer satisfaction study (expect 70% satisfaction):
        {
          "confidence": 0.99,
          "marginOfError": 0.03,
          "proportion": 0.70,
          "populationSize": 50000
        }

        Returns required sample size and related parameters.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "confidence": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (0-1). Common values: 0.90 (90%), 0.95 (95%), 0.99 (99%). Example: 0.95"
                ),
                "marginOfError": MCPSchemaProperty(
                    type: "number",
                    description: "Margin of error (0-1). Common values: 0.03 (±3%), 0.05 (±5%), 0.10 (±10%). Example: 0.05"
                ),
                "proportion": MCPSchemaProperty(
                    type: "number",
                    description: "Expected proportion (0-1). Use 0.5 for maximum/conservative estimate. Example: 0.5"
                ),
                "populationSize": MCPSchemaProperty(
                    type: "number",
                    description: "Total population size. Use large number (1000000+) for infinite population. Example: 10000"
                )
            ],
            required: ["confidence", "marginOfError", "proportion", "populationSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let confidence = try args.getDouble("confidence")
        let marginOfError = try args.getDouble("marginOfError")
        let proportion = try args.getDouble("proportion")
        let populationSize = try args.getDouble("populationSize")

        guard confidence > 0 && confidence < 1 else {
            throw ToolError.invalidArguments("confidence must be between 0 and 1")
        }

        guard marginOfError > 0 && marginOfError < 1 else {
            throw ToolError.invalidArguments("marginOfError must be between 0 and 1")
        }

        guard proportion >= 0 && proportion <= 1 else {
            throw ToolError.invalidArguments("proportion must be between 0 and 1")
        }

        guard populationSize > 0 else {
            throw ToolError.invalidArguments("populationSize must be positive")
        }

        let requiredSize: Double = sampleSize(ci: confidence, proportion: proportion, n: populationSize, error: marginOfError)

        let responseRate = requiredSize / populationSize
        let isLargePopulation = populationSize > 100000

        let result = """
        ## Sample Size Calculation

        **Study Parameters:**
        - Confidence Level: \((confidence * 100).formatDecimal(decimals: 0))%
        - Margin of Error: ±\((marginOfError * 100).formatDecimal(decimals: 1))%
        - Expected Proportion: \((proportion * 100).formatDecimal(decimals: 0))%
        - Population Size: \(populationSize.formatDecimal(decimals: 0))

        **Results:**
        - **Required Sample Size: \(Int(requiredSize.rounded(.up)))**
        - Response Rate Needed: \((responseRate * 100).formatDecimal(decimals: 2))%

        **Interpretation:**
        You need to collect \(Int(requiredSize.rounded(.up))) responses to achieve \((confidence * 100).formatDecimal(decimals: 0))% confidence with ±\((marginOfError * 100).formatDecimal(decimals: 1))% margin of error.

        **Practical Guidance:**
        \(isLargePopulation ? "• Large population - sample size primarily depends on confidence and margin of error" : "• Smaller population - you may need to sample a significant portion")
        • If actual proportion differs significantly from \((proportion * 100).formatDecimal(decimals: 0))%, recalculate with updated estimate
        • Consider adding 10-20% buffer for non-responses or invalid data
        • Recommended target: \(Int((requiredSize * 1.15).rounded(.up))) (with 15% buffer)
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 4: Calculate Margin of Error

public struct CalculateMarginOfErrorTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_margin_of_error",
        description: """
        Calculate margin of error for confidence intervals.

        Determines the ± range around a sample statistic at a given confidence level.

        REQUIRED STRUCTURE:
        {
          "confidence": 0.95,
          "standardDeviation": 2.5,
          "sampleSize": 100
        }

        **Examples:**

        1. Calculate margin of error for survey results:
        {
          "confidence": 0.95,
          "standardDeviation": 15.0,
          "sampleSize": 250
        }

        2. Quality control measurements:
        {
          "confidence": 0.99,
          "standardDeviation": 0.5,
          "sampleSize": 50
        }

        Returns margin of error and confidence interval bounds.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "confidence": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (0-1). Common: 0.90, 0.95, 0.99. Example: 0.95"
                ),
                "standardDeviation": MCPSchemaProperty(
                    type: "number",
                    description: "Standard deviation of the sample. Example: 2.5"
                ),
                "sampleSize": MCPSchemaProperty(
                    type: "number",
                    description: "Sample size (number of observations). Example: 100"
                )
            ],
            required: ["confidence", "standardDeviation", "sampleSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let confidenceLevel = try args.getDouble("confidence")
        let stdDev = try args.getDouble("standardDeviation")
        let n = try args.getDouble("sampleSize")

        guard confidenceLevel > 0 && confidenceLevel < 1 else {
            throw ToolError.invalidArguments("confidence must be between 0 and 1")
        }

        guard stdDev > 0 else {
            throw ToolError.invalidArguments("standardDeviation must be positive")
        }

        guard n > 0 else {
            throw ToolError.invalidArguments("sampleSize must be positive")
        }

        let alpha = 1.0 - confidenceLevel
        let ci = confidence(alpha: alpha, stdev: stdDev, sampleSize: Int(n))

        let marginOfError = ci.high
        let lowerBound = -marginOfError
        let upperBound = marginOfError

        let result = """
        ## Margin of Error Calculation

        **Input Parameters:**
        - Confidence Level: \((confidenceLevel * 100).formatDecimal(decimals: 0))%
        - Standard Deviation: \(stdDev.formatDecimal())
        - Sample Size: \(Int(n))

        **Results:**
        - **Margin of Error: ±\(marginOfError.formatDecimal())**

        **Confidence Interval:**
        If the sample mean is M, the true population mean is likely between:
        - Lower Bound: M - \(marginOfError.formatDecimal()) = M + (\(lowerBound.formatDecimal()))
        - Upper Bound: M + \(marginOfError.formatDecimal())

        **Interpretation:**
        With \((confidenceLevel * 100).formatDecimal(decimals: 0))% confidence, the true population parameter falls within ±\(marginOfError.formatDecimal()) of your sample statistic.

        **To Reduce Margin of Error:**
        • Increase sample size (n)
        • Accept lower confidence level
        • Reduce population variability (if possible through better measurement)
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 5: AB Test Analysis

public struct ABTestAnalysisTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "ab_test_analysis",
        description: """
        Complete A/B test analysis with statistical significance testing.

        Compares conversion rates between two variants and determines if the difference is statistically significant.

        REQUIRED STRUCTURE:
        {
          "variantA": {
            "observations": 1000,
            "conversions": 85
          },
          "variantB": {
            "observations": 1000,
            "conversions": 110
          },
          "alpha": 0.05
        }

        **Examples:**

        1. Website button color test:
        {
          "variantA": {
            "name": "Blue Button",
            "observations": 2500,
            "conversions": 312
          },
          "variantB": {
            "name": "Green Button",
            "observations": 2500,
            "conversions": 356
          },
          "alpha": 0.05
        }

        2. Email subject line test:
        {
          "variantA": {
            "observations": 5000,
            "conversions": 850
          },
          "variantB": {
            "observations": 5000,
            "conversions": 920
          },
          "alpha": 0.05
        }

        Returns conversion rates, statistical significance, and recommendations.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "variantA": MCPSchemaProperty(
                    type: "object",
                    description: """
                    First variant data. Object with 'observations' (total views/visits) and 'conversions' (successful outcomes).
                    Optional 'name' field for labeling.
                    Example: {"name": "Control", "observations": 1000, "conversions": 85}
                    """
                ),
                "variantB": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Second variant data. Object with 'observations' and 'conversions'.
                    Example: {"name": "Treatment", "observations": 1000, "conversions": 110}
                    """
                ),
                "alpha": MCPSchemaProperty(
                    type: "number",
                    description: "Significance level (default: 0.05). Example: 0.05"
                )
            ],
            required: ["variantA", "variantB"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Extract variant A
        guard let variantADict = args["variantA"]?.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'variantA' object")
        }

        let nameA = (variantADict["name"]?.value as? String) ?? "Variant A"

        guard let obsAValue = variantADict["observations"]?.value,
              let convAValue = variantADict["conversions"]?.value else {
            throw ToolError.invalidArguments("variantA must have 'observations' and 'conversions'")
        }

        let obsA = (obsAValue as? Int) ?? Int((obsAValue as? Double) ?? 0)
        let convA = (convAValue as? Int) ?? Int((convAValue as? Double) ?? 0)

        // Extract variant B
        guard let variantBDict = args["variantB"]?.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'variantB' object")
        }

        let nameB = (variantBDict["name"]?.value as? String) ?? "Variant B"

        guard let obsBValue = variantBDict["observations"]?.value,
              let convBValue = variantBDict["conversions"]?.value else {
            throw ToolError.invalidArguments("variantB must have 'observations' and 'conversions'")
        }

        let obsB = (obsBValue as? Int) ?? Int((obsBValue as? Double) ?? 0)
        let convB = (convBValue as? Int) ?? Int((convBValue as? Double) ?? 0)

        guard obsA > 0 && obsB > 0 else {
            throw ToolError.invalidArguments("observations must be positive")
        }

        guard convA <= obsA && convB <= obsB else {
            throw ToolError.invalidArguments("conversions cannot exceed observations")
        }

        let alpha = args.getDoubleOptional("alpha") ?? 0.05

        // Calculate conversion rates
        let rateA = Double(convA) / Double(obsA)
        let rateB = Double(convB) / Double(obsB)

        // Calculate p-value using existing function
        let pValueResult: Double = pValue(obsA: obsA, convA: convA, obsB: obsB, convB: convB)

        let isSignificant = pValueResult >= (1.0 - alpha)
        let lift = ((rateB - rateA) / rateA) * 100.0
        let absoluteDiff = (rateB - rateA) * 100.0

        let winner = rateB > rateA ? nameB : nameA
        let loser = rateB > rateA ? nameA : nameB

        let result = """
        ## A/B Test Analysis Results

        **\(nameA) (Control):**
        - Observations: \(obsA)
        - Conversions: \(convA)
        - Conversion Rate: \((rateA * 100).formatDecimal(decimals: 2))%

        **\(nameB) (Treatment):**
        - Observations: \(obsB)
        - Conversions: \(convB)
        - Conversion Rate: \((rateB * 100).formatDecimal(decimals: 2))%

        **Performance Comparison:**
        - Absolute Difference: \(absoluteDiff.formatDecimal(decimals: 2)) percentage points
        - Relative Lift: \(lift.formatDecimal(decimals: 1))%
        - Winner: **\(winner)**

        **Statistical Significance:**
        - P-Value: \(pValueResult.formatDecimal(decimals: 4))
        - Significance Level (α): \(alpha)
        - Result: \(isSignificant ? "✓ SIGNIFICANT" : "✗ NOT SIGNIFICANT")

        **Conclusion:**
        \(isSignificant ? "✓ The difference IS statistically significant at α = \(alpha)." : "✗ The difference is NOT statistically significant at α = \(alpha).")

        **Recommendation:**
        \(isSignificant ? "• Implement \(winner) - it performs significantly better than \(loser)\n• Expected improvement: \(abs(lift).formatDecimal(decimals: 1))%" : "• Continue testing - need more data to detect a significant difference\n• Consider increasing sample size or testing a more impactful change")
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 6: Calculate P-Value

public struct CalculatePValueTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_p_value",
        description: """
        Calculate p-value from test statistic (z-score or t-statistic).

        Converts a test statistic into a probability value for hypothesis testing.

        REQUIRED STRUCTURE:
        {
          "testStatistic": 2.45,
          "testType": "two-tailed"
        }

        **Parameters:**
        - **testStatistic**: The calculated z-score or t-statistic
        - **testType**: "two-tailed" (default), "left-tailed", or "right-tailed"

        **Examples:**

        1. Two-tailed test (most common):
        {
          "testStatistic": 1.96,
          "testType": "two-tailed"
        }

        2. Right-tailed test (testing if greater than):
        {
          "testStatistic": 2.33,
          "testType": "right-tailed"
        }

        Returns p-value and interpretation for hypothesis testing.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "testStatistic": MCPSchemaProperty(
                    type: "number",
                    description: "Test statistic value (z-score or t-statistic). Example: 2.45"
                ),
                "testType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of test: 'two-tailed', 'left-tailed', or 'right-tailed'. Default: 'two-tailed'"
                )
            ],
            required: ["testStatistic"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let testStat = try args.getDouble("testStatistic")
        let testType = args.getStringOptional("testType") ?? "two-tailed"

        guard ["two-tailed", "left-tailed", "right-tailed"].contains(testType) else {
            throw ToolError.invalidArguments("testType must be 'two-tailed', 'left-tailed', or 'right-tailed'")
        }

        // Calculate p-value using normal distribution
        let standardNormalProb = normSDist(zScore: abs(testStat))

        let pValue: Double
        switch testType {
        case "two-tailed":
            pValue = 2.0 * (1.0 - standardNormalProb)
        case "right-tailed":
            pValue = 1.0 - standardNormalProb
        case "left-tailed":
            pValue = 1.0 - standardNormalProb  // For negative test statistics
        default:
            pValue = 2.0 * (1.0 - standardNormalProb)
        }

        let sig01 = pValue < 0.01
        let sig05 = pValue < 0.05
        let sig10 = pValue < 0.10

        let significance = sig01 ? "Highly Significant (p < 0.01)" :
                          sig05 ? "Significant (p < 0.05)" :
                          sig10 ? "Marginally Significant (p < 0.10)" :
                          "Not Significant (p ≥ 0.10)"

        let result = """
        ## P-Value Calculation

        **Input:**
        - Test Statistic: \(testStat.formatDecimal(decimals: 4))
        - Test Type: \(testType)

        **Result:**
        - **P-Value: \(pValue.formatDecimal(decimals: 4))**

        **Significance Assessment:**
        \(sig01 ? "✓✓✓" : sig05 ? "✓✓" : sig10 ? "✓" : "✗") \(significance)

        **Interpretation:**
        \(sig05 ? "The result is statistically significant. You can reject the null hypothesis." : "The result is not statistically significant. Insufficient evidence to reject the null hypothesis.")

        **Significance Thresholds:**
        - p < 0.01: \(sig01 ? "✓" : "✗") Highly significant (99% confidence)
        - p < 0.05: \(sig05 ? "✓" : "✗") Significant (95% confidence)
        - p < 0.10: \(sig10 ? "✓" : "✗") Marginally significant (90% confidence)

        **Note:** This calculation uses the standard normal (z) distribution, which is appropriate for:
        • Large sample sizes (n > 30)
        • Z-tests
        • Approximations of t-tests with large df
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Get All Hypothesis Testing Tools

public func getHypothesisTestingTools() -> [any MCPToolHandler] {
    return [
        HypothesisTTestTool(),
        HypothesisChiSquareTool(),
        CalculateSampleSizeTool(),
        CalculateMarginOfErrorTool(),
        ABTestAnalysisTool(),
        CalculatePValueTool()
    ]
}
