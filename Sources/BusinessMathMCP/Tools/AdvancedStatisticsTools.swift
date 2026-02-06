//
//  AdvancedStatisticsTools.swift
//  BusinessMath MCP Server
//
//  Advanced statistical, probability, and analysis tools
//

import Foundation
import BusinessMath
import MCP

// MARK: - PROBABILITY DISTRIBUTION TOOLS

// MARK: - Tool 1: Binomial Probability

public struct BinomialProbabilityTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "binomial_probability",
        description: """
        Calculate the binomial probability mass function (PMF) - the probability of getting exactly k successes in n independent Bernoulli trials.

        REQUIRED STRUCTURE:
        {
          "n": 10,
          "k": 3,
          "p": 0.5
        }

        **Parameters:**
        - n: Number of trials (integer ≥ 0)
        - k: Number of successes (integer, 0 ≤ k ≤ n)
        - p: Probability of success on each trial (0 ≤ p ≤ 1)

        **Example 1: Coin flips**
        {
          "n": 10,
          "k": 6,
          "p": 0.5
        }
        Returns: Probability of getting exactly 6 heads in 10 fair coin flips

        **Example 2: Quality control**
        {
          "n": 100,
          "k": 5,
          "p": 0.03
        }
        Returns: Probability of exactly 5 defective items in a batch of 100 (3% defect rate)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "n": MCPSchemaProperty(type: "number", description: "Number of trials"),
                "k": MCPSchemaProperty(type: "number", description: "Number of successes"),
                "p": MCPSchemaProperty(type: "number", description: "Probability of success (0-1)")
            ],
            required: ["n", "k", "p"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let n = try args.getInt("n")
        let k = try args.getInt("k")
        let p = try args.getDouble("p")

        guard n >= 0 else {
            throw ToolError.invalidArguments("n must be non-negative")
        }
        guard k >= 0, k <= n else {
            throw ToolError.invalidArguments("k must be between 0 and n")
        }
        guard p >= 0.0, p <= 1.0 else {
            throw ToolError.invalidArguments("p must be between 0 and 1")
        }

        let probability: Double = binomialPMF(n: n, k: k, p: p)
        let percentage = (probability * 100).formatDecimal(decimals: 4)

        let result = """
        ## Binomial Probability Result

        **Parameters:**
        - Trials (n): \(n)
        - Successes (k): \(k)
        - Success probability (p): \(p.formatDecimal(decimals: 4))

        **Result:**
        - Probability: \(probability.formatDecimal(decimals: 6))
        - Percentage: \(percentage)%

        **Interpretation:**
        The probability of getting exactly \(k) successes in \(n) trials is \(percentage)%.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 2: Poisson Probability

public struct PoissonProbabilityTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "poisson_probability",
        description: """
        Calculate the Poisson probability - the probability of observing exactly x events in a fixed interval when events occur at a constant average rate.

        REQUIRED STRUCTURE:
        {
          "x": 3,
          "mu": 2.5
        }

        **Parameters:**
        - x: Number of events (integer ≥ 0)
        - mu: Average rate (λ or μ, must be > 0)

        **Example 1: Customer arrivals**
        {
          "x": 5,
          "mu": 3.2
        }
        Returns: Probability of exactly 5 customers arriving per hour when average is 3.2

        **Example 2: Website hits**
        {
          "x": 10,
          "mu": 8.5
        }
        Returns: Probability of exactly 10 page views per minute when average is 8.5
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(type: "number", description: "Number of events"),
                "mu": MCPSchemaProperty(type: "number", description: "Average rate (λ or μ)")
            ],
            required: ["x", "mu"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getInt("x")
        let mu = try args.getDouble("mu")

        guard x >= 0 else {
            throw ToolError.invalidArguments("x must be non-negative")
        }
        guard mu > 0.0 else {
            throw ToolError.invalidArguments("mu must be positive")
        }

        let probability: Double = poisson(x, µ: mu)
        let percentage = (probability * 100).formatDecimal(decimals: 4)

        let result = """
        ## Poisson Probability Result

        **Parameters:**
        - Events (x): \(x)
        - Average rate (μ): \(mu.formatDecimal(decimals: 2))

        **Result:**
        - Probability: \(probability.formatDecimal(decimals: 6))
        - Percentage: \(percentage)%

        **Interpretation:**
        The probability of observing exactly \(x) events when the average rate is \(mu.formatDecimal(decimals: 2)) is \(percentage)%.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 3: Exponential Distribution

public struct ExponentialDistributionTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "exponential_distribution",
        description: """
        Calculate the exponential distribution PDF - models the time between events in a Poisson process.

        REQUIRED STRUCTURE:
        {
          "x": 2.0,
          "lambda": 0.5
        }

        **Parameters:**
        - x: Time or distance value (must be ≥ 0)
        - lambda: Rate parameter (λ, must be > 0)

        **Example 1: Wait time**
        {
          "x": 5.0,
          "lambda": 0.2
        }
        Returns: Probability density at 5 minutes when average wait time is 1/0.2 = 5 minutes

        **Example 2: Equipment failure**
        {
          "x": 10.0,
          "lambda": 0.1
        }
        Returns: PDF at 10 hours for equipment with failure rate λ=0.1
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(type: "number", description: "Value at which to evaluate PDF"),
                "lambda": MCPSchemaProperty(type: "number", description: "Rate parameter (λ)")
            ],
            required: ["x", "lambda"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDouble("x")
        let lambda = try args.getDouble("lambda")

        guard x >= 0.0 else {
            throw ToolError.invalidArguments("x must be non-negative")
        }
        guard lambda > 0.0 else {
            throw ToolError.invalidArguments("lambda must be positive")
        }

        let pdf: Double = exponentialPDF(x, λ: lambda)
        let meanTime = 1.0 / lambda

        let result = """
        ## Exponential Distribution Result

        **Parameters:**
        - Value (x): \(x.formatDecimal(decimals: 2))
        - Rate (λ): \(lambda.formatDecimal(decimals: 4))
        - Mean time: \(meanTime.formatDecimal(decimals: 2))

        **Result:**
        - Probability density: \(pdf.formatDecimal(decimals: 6))

        **Interpretation:**
        The exponential distribution models the time between events.
        With rate λ=\(lambda.formatDecimal(decimals: 4)), the average time between events is \(meanTime.formatDecimal(decimals: 2)) units.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 4: Hypergeometric Probability

public struct HypergeometricProbabilityTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "hypergeometric_probability",
        description: """
        Calculate the hypergeometric probability - probability of x successes in n draws without replacement from a finite population.

        REQUIRED STRUCTURE:
        {
          "total": 52,
          "successes_in_population": 4,
          "sample_size": 5,
          "successes_in_sample": 2
        }

        **Parameters:**
        - total: Total population size
        - successes_in_population: Number of success states in population
        - sample_size: Number of draws
        - successes_in_sample: Number of observed successes

        **Example 1: Drawing cards**
        {
          "total": 52,
          "successes_in_population": 4,
          "sample_size": 5,
          "successes_in_sample": 2
        }
        Returns: Probability of drawing exactly 2 aces in 5 cards from a 52-card deck

        **Example 2: Quality inspection**
        {
          "total": 100,
          "successes_in_population": 10,
          "sample_size": 20,
          "successes_in_sample": 3
        }
        Returns: Probability of finding 3 defective items when sampling 20 from 100 (10 defective)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "total": MCPSchemaProperty(type: "number", description: "Total population size"),
                "successes_in_population": MCPSchemaProperty(type: "number", description: "Number of success states in population"),
                "sample_size": MCPSchemaProperty(type: "number", description: "Number of draws"),
                "successes_in_sample": MCPSchemaProperty(type: "number", description: "Number of observed successes")
            ],
            required: ["total", "successes_in_population", "sample_size", "successes_in_sample"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let total = try args.getInt("total")
        let r = try args.getInt("successes_in_population")
        let n = try args.getInt("sample_size")
        let x = try args.getInt("successes_in_sample")

        guard total > 0, r >= 0, n >= 0, x >= 0 else {
            throw ToolError.invalidArguments("All parameters must be non-negative (total must be positive)")
        }
        guard r <= total, n <= total, x <= n, x <= r else {
            throw ToolError.invalidArguments("Invalid parameter combinations")
        }

        let probability: Double = hypergeometric(total: total, r: r, n: n, x: x)
        let percentage = (probability * 100).formatDecimal(decimals: 4)

        let result = """
        ## Hypergeometric Probability Result

        **Parameters:**
        - Population size: \(total)
        - Successes in population: \(r)
        - Sample size: \(n)
        - Successes in sample: \(x)

        **Result:**
        - Probability: \(probability.formatDecimal(decimals: 6))
        - Percentage: \(percentage)%

        **Interpretation:**
        The probability of getting exactly \(x) successes in a sample of \(n) drawn from a population of \(total) (containing \(r) successes) is \(percentage)%.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 5: Log-Normal Distribution

public struct LogNormalDistributionTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "lognormal_distribution",
        description: """
        Calculate the log-normal distribution PDF - models data that follows a normal distribution after logarithmic transformation.

        REQUIRED STRUCTURE:
        {
          "x": 1.5,
          "mean": 0.0,
          "stddev": 1.0
        }

        **Parameters:**
        - x: Value at which to evaluate PDF (must be > 0)
        - mean: Mean of underlying normal distribution (default: 0.0)
        - stddev: Standard deviation of underlying normal (default: 1.0)

        **Example 1: Stock prices**
        {
          "x": 100.0,
          "mean": 4.6,
          "stddev": 0.5
        }
        Returns: PDF at $100 for stock price modeled as log-normal

        **Example 2: Income distribution**
        {
          "x": 50000,
          "mean": 10.8,
          "stddev": 0.4
        }
        Returns: PDF for income level using log-normal model
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(type: "number", description: "Value (must be positive)"),
                "mean": MCPSchemaProperty(type: "number", description: "Mean of ln(x) (default: 0.0)"),
                "stddev": MCPSchemaProperty(type: "number", description: "Std dev of ln(x) (default: 1.0)")
            ],
            required: ["x"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDouble("x")
        let mean = args.getDoubleOptional("mean") ?? 0.0
        let stddev = args.getDoubleOptional("stddev") ?? 1.0

        guard x > 0.0 else {
            throw ToolError.invalidArguments("x must be positive for log-normal distribution")
        }
        guard stddev > 0.0 else {
            throw ToolError.invalidArguments("stddev must be positive")
        }

        let pdf: Double = logNormalPDF(x, mean: mean, stdDev: stddev)

        let result = """
        ## Log-Normal Distribution Result

        **Parameters:**
        - Value (x): \(x.formatDecimal(decimals: 2))
        - Mean of ln(x): \(mean.formatDecimal(decimals: 2))
        - Std dev of ln(x): \(stddev.formatDecimal(decimals: 2))

        **Result:**
        - Probability density: \(pdf.formatDecimal(decimals: 6))

        **Interpretation:**
        The log-normal distribution is commonly used in finance and environmental science.
        This distribution models variables whose logarithm is normally distributed.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - COMBINATORICS TOOLS

// MARK: - Tool 6: Calculate Combinations

public struct CalculateCombinationsTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_combinations",
        description: """
        Calculate combinations (n choose r) - the number of ways to choose r items from n items without regard to order.

        REQUIRED STRUCTURE:
        {
          "n": 10,
          "r": 3
        }

        **Formula:** C(n,r) = n! / (r! × (n-r)!)

        **Example 1: Lottery**
        {
          "n": 49,
          "r": 6
        }
        Returns: Number of possible 6-number combinations from 49 numbers

        **Example 2: Committee selection**
        {
          "n": 20,
          "r": 5
        }
        Returns: Ways to select a 5-person committee from 20 people
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "n": MCPSchemaProperty(type: "number", description: "Total number of items"),
                "r": MCPSchemaProperty(type: "number", description: "Number of items to choose")
            ],
            required: ["n", "r"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let n = try args.getInt("n")
        let r = try args.getInt("r")

        guard n >= 0, r >= 0 else {
            throw ToolError.invalidArguments("n and r must be non-negative")
        }
        guard r <= n else {
            throw ToolError.invalidArguments("r cannot be greater than n")
        }

        let combinations = combination(n, c: r)

        let result = """
        ## Combinations Result

        **Parameters:**
        - Total items (n): \(n)
        - Items to choose (r): \(r)

        **Result:**
        - C(\(n),\(r)) = \(combinations)

        **Interpretation:**
        There are \(combinations) different ways to choose \(r) items from \(n) items when order doesn't matter.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 7: Calculate Permutations

public struct CalculatePermutationsTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_permutations",
        description: """
        Calculate permutations (n P r) - the number of ways to arrange r items from n items where order matters.

        REQUIRED STRUCTURE:
        {
          "n": 10,
          "r": 3
        }

        **Formula:** P(n,r) = n! / (n-r)!

        **Example 1: Race positions**
        {
          "n": 8,
          "r": 3
        }
        Returns: Number of ways 8 runners can finish in top 3 positions

        **Example 2: Password arrangements**
        {
          "n": 10,
          "r": 4
        }
        Returns: Number of 4-digit arrangements from 10 digits
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "n": MCPSchemaProperty(type: "number", description: "Total number of items"),
                "r": MCPSchemaProperty(type: "number", description: "Number of items to arrange")
            ],
            required: ["n", "r"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let n = try args.getInt("n")
        let r = try args.getInt("r")

        guard n >= 0, r >= 0 else {
            throw ToolError.invalidArguments("n and r must be non-negative")
        }
        guard r <= n else {
            throw ToolError.invalidArguments("r cannot be greater than n")
        }

        let permutations = permutation(n, p: r)

        let result = """
        ## Permutations Result

        **Parameters:**
        - Total items (n): \(n)
        - Items to arrange (r): \(r)

        **Result:**
        - P(\(n),\(r)) = \(permutations)

        **Interpretation:**
        There are \(permutations) different ways to arrange \(r) items from \(n) items when order matters.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 8: Calculate Factorial

public struct CalculateFactorialTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "calculate_factorial",
        description: """
        Calculate the factorial of a number (n!) - the product of all positive integers less than or equal to n.

        REQUIRED STRUCTURE:
        {
          "n": 5
        }

        **Formula:** n! = n × (n-1) × (n-2) × ... × 2 × 1
        **Special case:** 0! = 1

        **Example 1: Basic factorial**
        {
          "n": 5
        }
        Returns: 5! = 120

        **Example 2: Arrangements**
        {
          "n": 10
        }
        Returns: 10! = 3,628,800 (ways to arrange 10 items)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "n": MCPSchemaProperty(type: "number", description: "Non-negative integer")
            ],
            required: ["n"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let n = try args.getInt("n")

        guard n >= 0 else {
            throw ToolError.invalidArguments("n must be non-negative")
        }
        guard n <= 20 else {
            throw ToolError.invalidArguments("n must be ≤ 20 to avoid integer overflow")
        }

        let fact = factorial(n)

        let result = """
        ## Factorial Result

        **Parameter:**
        - n = \(n)

        **Result:**
        - \(n)! = \(fact)

        **Interpretation:**
        The factorial \(n)! represents the number of ways to arrange \(n) distinct items in order.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - STATISTICAL MEANS TOOLS

// MARK: - Tool 9: Geometric Mean

public struct GeometricMeanTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "geometric_mean",
        description: """
        Calculate the geometric mean - the nth root of the product of n numbers. Useful for growth rates and ratios.

        REQUIRED STRUCTURE:
        {
          "values": [2.0, 8.0, 16.0]
        }

        **Formula:** GM = (x₁ × x₂ × ... × xₙ)^(1/n)

        **Example 1: Growth rates**
        {
          "values": [1.05, 1.08, 1.03, 1.07]
        }
        Returns: Average compound growth rate

        **Example 2: Investment returns**
        {
          "values": [1.10, 0.95, 1.15, 1.05]
        }
        Returns: Geometric average return
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(type: "array", description: "Array of positive numbers")
            ],
            required: ["values"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("values array cannot be empty")
        }
        guard values.allSatisfy({ $0 > 0 }) else {
            throw ToolError.invalidArguments("All values must be positive for geometric mean")
        }

        let mean: Double = geometricMean(values)

        let result = """
        ## Geometric Mean Result

        **Input Values:** [\(values.map { $0.formatDecimal(decimals: 4) }.joined(separator: ", "))]
        **Count:** \(values.count)

        **Result:**
        - Geometric Mean: \(mean.formatDecimal(decimals: 6))

        **Interpretation:**
        The geometric mean is ideal for averaging growth rates and ratios.
        It's always ≤ the arithmetic mean for positive numbers.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 10: Harmonic Mean

public struct HarmonicMeanTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "harmonic_mean",
        description: """
        Calculate the harmonic mean - useful for averaging rates and ratios. The reciprocal of the arithmetic mean of reciprocals.

        REQUIRED STRUCTURE:
        {
          "values": [60.0, 40.0, 48.0]
        }

        **Formula:** HM = n / (1/x₁ + 1/x₂ + ... + 1/xₙ)

        **Example 1: Average speed**
        {
          "values": [60.0, 40.0]
        }
        Returns: Average speed for round trip with different speeds each way

        **Example 2: Price-earnings ratios**
        {
          "values": [15.0, 20.0, 18.0]
        }
        Returns: Harmonic mean of P/E ratios
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(type: "array", description: "Array of positive numbers")
            ],
            required: ["values"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("values array cannot be empty")
        }
        guard values.allSatisfy({ $0 > 0 }) else {
            throw ToolError.invalidArguments("All values must be positive for harmonic mean")
        }

        let mean: Double = harmonicMean(values)

        let result = """
        ## Harmonic Mean Result

        **Input Values:** [\(values.map { $0.formatDecimal(decimals: 4) }.joined(separator: ", "))]
        **Count:** \(values.count)

        **Result:**
        - Harmonic Mean: \(mean.formatDecimal(decimals: 6))

        **Interpretation:**
        The harmonic mean is ideal for averaging rates and ratios.
        It's always ≤ the geometric mean for positive numbers.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - Tool 11: Weighted Average

public struct WeightedAverageTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "weighted_average",
        description: """
        Calculate the weighted average (weighted mean) - average where each value has a different weight or importance.

        REQUIRED STRUCTURE:
        {
          "values": [85.0, 90.0, 78.0],
          "weights": [0.3, 0.5, 0.2]
        }

        **Formula:** x̄ᵥᵥ = Σ(wᵢ × xᵢ) / Σwᵢ

        **Example 1: Course grade**
        {
          "values": [85.0, 92.0, 78.0],
          "weights": [0.3, 0.5, 0.2]
        }
        Returns: Final grade with midterm 30%, final 50%, homework 20%

        **Example 2: Portfolio return**
        {
          "values": [0.08, 0.12, 0.06],
          "weights": [50000, 30000, 20000]
        }
        Returns: Portfolio-weighted return
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(type: "array", description: "Array of values to average"),
                "weights": MCPSchemaProperty(type: "array", description: "Array of weights (same length as values)")
            ],
            required: ["values", "weights"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")
        let weights = try args.getDoubleArray("weights")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("values array cannot be empty")
        }
        guard values.count == weights.count else {
            throw ToolError.invalidArguments("values and weights must have the same length")
        }
        guard weights.allSatisfy({ $0 >= 0 }) else {
            throw ToolError.invalidArguments("All weights must be non-negative")
        }

        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else {
            throw ToolError.invalidArguments("Sum of weights must be positive")
        }

        let mean: Double = weightedAverage(values, weights: weights)

        // Calculate normalized weights for display
        let normalizedWeights = weights.map { ($0 / totalWeight * 100).formatDecimal(decimals: 2) }

        let result = """
        ## Weighted Average Result

        **Input Data:**
        - Values: [\(values.map { $0.formatDecimal(decimals: 2) }.joined(separator: ", "))]
        - Weights: [\(weights.map { $0.formatDecimal(decimals: 2) }.joined(separator: ", "))]
        - Normalized weights: [\(normalizedWeights.map { $0 + "%" }.joined(separator: ", "))]

        **Result:**
        - Weighted Average: \(mean.formatDecimal(decimals: 4))

        **Interpretation:**
        The weighted average accounts for the relative importance of each value.
        """

        return MCPToolCallResult.success(text: result)
    }
}

// MARK: - ANALYSIS TOOLS

// MARK: - Tool 12: Goal Seek

/// Evaluate a simple calculation string with an input value
private func evaluateCalculation(_ calculation: String, with input: Double) -> Double {
    let formula = calculation.replacingOccurrences(of: "{0}", with: "\(input)")

    // Use NSExpression to evaluate
    let expression = NSExpression(format: formula)
    if let result = expression.expressionValue(with: nil, context: nil) as? Double {
        return result
    } else if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
        return result.doubleValue
    }

    // Fallback: return 0 if evaluation fails
    return 0.0
}

public struct GoalSeekTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "goal_seek",
        description: """
        Find the input value that produces a target output using root-finding.

        Goal seeking answers "what-if" questions in reverse:
        • Instead of: "If revenue is $800K, what is profit?"
        • Ask: "What revenue do I need to achieve $200K profit?"

        Uses Newton-Raphson method to iteratively find the solution.

        REQUIRED STRUCTURE:
        {
          "calculation": "{0} * 1.15 - 600000",
          "target": 200000,
          "initialGuess": 800000
        }

        Common Applications:
        • Revenue Planning: What sales do we need for target profit?
        • Pricing: What price achieves target margin?
        • Growth Planning: What growth rate reaches revenue target?
        • Break-even Analysis: What volume covers all costs?
        • Financial Modeling: Find key drivers for target metrics

        Examples:

        1. Revenue Goal Seeking:
        {
          "calculation": "{0} * 0.4",
          "target": 400000,
          "initialGuess": 900000,
          "description": "What revenue achieves $400K profit (40% margin)?"
        }

        2. Growth Rate Calculation:
        {
          "calculation": "800000 * (1 + {0})",
          "target": 1000000,
          "initialGuess": 0.2,
          "description": "What growth rate grows $800K to $1M?"
        }

        3. Pricing for Target Margin:
        {
          "calculation": "({0} - 50) * 10000",
          "target": 250000,
          "initialGuess": 75,
          "description": "What price per unit achieves $250K profit?"
        }

        Returns the input value that achieves the target, along with verification.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula using {0} for the variable to find.
                    Examples:
                    • "{0} * 1.15 - 600000" - revenue with 15% growth minus costs
                    • "({0} - 50) * 10000" - (price - cost) × quantity
                    • "{0} * {0} + 2 * {0}" - polynomial expressions
                    """
                ),
                "target": MCPSchemaProperty(
                    type: "number",
                    description: "Target output value to achieve"
                ),
                "initialGuess": MCPSchemaProperty(
                    type: "number",
                    description: "Starting guess for the input value (affects convergence speed)"
                ),
                "tolerance": MCPSchemaProperty(
                    type: "number",
                    description: "Acceptable error tolerance (default: 0.000001)"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum iterations before giving up (default: 1000)"
                ),
                "description": MCPSchemaProperty(
                    type: "string",
                    description: "Optional description of what you're solving for (for display)"
                )
            ],
            required: ["calculation", "target", "initialGuess"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let calculation = try args.getString("calculation")
        let target = try args.getDouble("target")
        let initialGuess = try args.getDouble("initialGuess")
        let tolerance = args.getDoubleOptional("tolerance") ?? 0.000001
        let maxIterations = args.getIntOptional("maxIterations") ?? 1000
        let description = args.getStringOptional("description")

        // Define the function: f(x) = calculation(x) - target
        // We want to find x where f(x) = 0
        let function: @Sendable (Double) -> Double = { input in
            let result = evaluateCalculation(calculation, with: input)
            return result - target
        }

        // Use goalSeek to find the solution
        let solution: Double
        do {
            solution = try goalSeek(
                function: function,
                target: 0.0,
                guess: initialGuess,
                tolerance: tolerance,
                maxIterations: maxIterations
            )
        } catch {
            return .error(message: """
                Goal Seek Failed

                Could not find a solution within \(maxIterations) iterations.

                Possible reasons:
                • No solution exists for this target
                • Initial guess is too far from solution
                • Formula has discontinuities or is non-smooth

                Suggestions:
                • Try a different initial guess
                • Increase maxIterations
                • Check if target is achievable
                • Simplify the calculation formula

                Error: \(error.localizedDescription)
                """)
        }

        // Verify the solution
        let actualOutput = evaluateCalculation(calculation, with: solution)
        let error = abs(actualOutput - target)
        let errorPercent = target != 0 ? (error / abs(target)) * 100 : 0

        var output = """
        Goal Seek Result
        """

        if let desc = description {
            output += "\n\nQuestion: \(desc)"
        }

        output += """


        Solution Found:
        • Input Value: \(solution.formatDecimal(decimals: 6))
        • Achieves Output: \(actualOutput.formatDecimal(decimals: 6))
        • Target Output: \(target.formatDecimal(decimals: 6))
        • Error: \(error.formatDecimal(decimals: 8)) (\(errorPercent.formatDecimal(decimals: 6))%)

        Verification:
        • Formula: \(calculation)
        • When {0} = \(solution.formatDecimal(decimals: 6))
        • Result = \(actualOutput.formatDecimal(decimals: 6))

        Convergence:
        • Initial Guess: \(initialGuess.formatDecimal(decimals: 2))
        • Solution converged within tolerance \((tolerance * 100).formatDecimal(decimals: 6))%
        • \(error < tolerance ? "✓ Solution verified" : "⚠️ Solution may need refinement")

        Usage:
        Use this input value (\(solution.formatDecimal(decimals: 2))) to achieve your target of \(target.formatDecimal(decimals: 2)).
        """

        return .success(text: output)
    }
}

// MARK: - Tool 13: Data Table

public struct DataTableTool: MCPToolHandler {
    public let tool = MCPTool(
        name: "data_table",
        description: """
        Generate a data table showing how output varies with one or two input variables. Similar to Excel's Data Table feature.

        REQUIRED STRUCTURE (1-variable):
        {
          "formula_type": "loan_payment",
          "fixed_params": {
            "principal": 100000,
            "years": 30
          },
          "variable_param": "rate",
          "variable_values": [0.03, 0.035, 0.04, 0.045, 0.05]
        }

        REQUIRED STRUCTURE (2-variable):
        {
          "formula_type": "loan_payment",
          "fixed_params": {
            "principal": 100000
          },
          "variable1_param": "rate",
          "variable1_values": [0.03, 0.04, 0.05],
          "variable2_param": "years",
          "variable2_values": [15, 20, 25, 30]
        }

        **Supported formula types:**
        - "loan_payment": Monthly loan payment
        - "future_value": FV with compound interest
        - "compound_growth": Value after compound growth

        **Example 1: Loan payment sensitivity**
        {
          "formula_type": "loan_payment",
          "fixed_params": {"principal": 200000, "years": 30},
          "variable_param": "rate",
          "variable_values": [0.03, 0.04, 0.05, 0.06]
        }
        Returns: Monthly payment for different interest rates

        **Example 2: Investment growth table**
        {
          "formula_type": "future_value",
          "fixed_params": {"principal": 10000, "years": 10},
          "variable_param": "rate",
          "variable_values": [0.05, 0.07, 0.09, 0.11]
        }
        Returns: Future value at different growth rates
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "formula_type": MCPSchemaProperty(type: "string", description: "Type of calculation"),
                "fixed_params": MCPSchemaProperty(type: "object", description: "Fixed parameters"),
                "variable_param": MCPSchemaProperty(type: "string", description: "Name of variable parameter"),
                "variable_values": MCPSchemaProperty(type: "array", description: "Array of values to test"),
                "variable1_param": MCPSchemaProperty(type: "string", description: "Name of first variable (2-var only)"),
                "variable1_values": MCPSchemaProperty(type: "array", description: "Values for var1 (2-var only)"),
                "variable2_param": MCPSchemaProperty(type: "string", description: "Name of second variable (2-var only)"),
                "variable2_values": MCPSchemaProperty(type: "array", description: "Values for var2 (2-var only)")
            ],
            required: ["formula_type", "fixed_params"]
        )
    )

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let formulaType = try args.getString("formula_type")

        // Check if 1-variable or 2-variable table
        let is2Variable = args.hasKey("variable1_param") && args.hasKey("variable2_param")

        if is2Variable {
            // 2-variable data table
            return try await execute2VariableTable(args: args, formulaType: formulaType)
        } else {
            // 1-variable data table
            return try await execute1VariableTable(args: args, formulaType: formulaType)
        }
    }

    private func execute1VariableTable(args: [String: AnyCodable], formulaType: String) async throws -> MCPToolCallResult {
        let variableParam = try args.getString("variable_param")
        let variableValues = try args.getDoubleArray("variable_values")

        guard !variableValues.isEmpty else {
            throw ToolError.invalidArguments("variable_values cannot be empty")
        }

        var tableRows: [String] = []
        tableRows.append("| \(variableParam) | Result |")
        tableRows.append("|-------------|--------|")

        for value in variableValues {
            let result = try calculateFormula(type: formulaType, args: args, variable1: (variableParam, value))
            tableRows.append("| \(value.formatDecimal(decimals: 4)) | \(result.formatDecimal(decimals: 2)) |")
        }

        let table = tableRows.joined(separator: "\n")

        let resultText = """
        ## Data Table Result (1-Variable)

        **Formula:** \(formulaType)
        **Variable:** \(variableParam)

        \(table)

        **Interpretation:**
        This table shows how the output varies as \(variableParam) changes.
        """

        return MCPToolCallResult.success(text: resultText)
    }

    private func execute2VariableTable(args: [String: AnyCodable], formulaType: String) async throws -> MCPToolCallResult {
        let variable1Param = try args.getString("variable1_param")
        let variable1Values = try args.getDoubleArray("variable1_values")
        let variable2Param = try args.getString("variable2_param")
        let variable2Values = try args.getDoubleArray("variable2_values")

        guard !variable1Values.isEmpty, !variable2Values.isEmpty else {
            throw ToolError.invalidArguments("variable values cannot be empty")
        }

        var tableRows: [String] = []

        // Header row
        var header = "| \(variable1Param) \\ \(variable2Param) |"
        for val2 in variable2Values {
            header += " \(val2.formatDecimal(decimals: 2)) |"
        }
        tableRows.append(header)

        // Separator
        var separator = "|"
        for _ in 0...variable2Values.count {
            separator += "--------|"
        }
        tableRows.append(separator)

        // Data rows
        for val1 in variable1Values {
            var row = "| \(val1.formatDecimal(decimals: 4)) |"
            for val2 in variable2Values {
                let result = try calculateFormula(
                    type: formulaType,
                    args: args,
                    variable1: (variable1Param, val1),
                    variable2: (variable2Param, val2)
                )
                row += " \(result.formatDecimal(decimals: 2)) |"
            }
            tableRows.append(row)
        }

        let table = tableRows.joined(separator: "\n")

        let resultText = """
        ## Data Table Result (2-Variable)

        **Formula:** \(formulaType)
        **Variables:** \(variable1Param), \(variable2Param)

        \(table)

        **Interpretation:**
        This table shows how the output varies with both \(variable1Param) (rows) and \(variable2Param) (columns).
        """

        return MCPToolCallResult.success(text: resultText)
    }

    private func calculateFormula(
        type: String,
        args: [String: AnyCodable],
        variable1: (String, Double),
        variable2: (String, Double)? = nil
    ) throws -> Double {
        switch type {
        case "loan_payment":
            // Get parameters
            let principal = variable1.0 == "principal" ? variable1.1 :
                            variable2?.0 == "principal" ? variable2!.1 :
                            try args.getDoubleFromObject("fixed_params", key: "principal")

            let rate = variable1.0 == "rate" ? variable1.1 :
                       variable2?.0 == "rate" ? variable2!.1 :
                       try args.getDoubleFromObject("fixed_params", key: "rate")

            let years = variable1.0 == "years" ? variable1.1 :
                        variable2?.0 == "years" ? variable2!.1 :
                        try args.getDoubleFromObject("fixed_params", key: "years")

            // Calculate monthly payment
            let monthlyRate = rate / 12.0
            let numPayments = years * 12.0
            let payment = principal * (monthlyRate * pow(1 + monthlyRate, numPayments)) /
                         (pow(1 + monthlyRate, numPayments) - 1)
            return payment

        case "future_value", "compound_growth":
            let principal = variable1.0 == "principal" ? variable1.1 :
                            variable2?.0 == "principal" ? variable2!.1 :
                            try args.getDoubleFromObject("fixed_params", key: "principal")

            let rate = variable1.0 == "rate" ? variable1.1 :
                       variable2?.0 == "rate" ? variable2!.1 :
                       try args.getDoubleFromObject("fixed_params", key: "rate")

            let years = variable1.0 == "years" ? variable1.1 :
                        variable2?.0 == "years" ? variable2!.1 :
                        try args.getDoubleFromObject("fixed_params", key: "years")

            // FV = PV * (1 + r)^t
            return principal * pow(1 + rate, years)

        default:
            throw ToolError.invalidArguments("Unsupported formula_type: \(type)")
        }
    }
}

// MARK: - Export All Advanced Statistics Tools

public func getAdvancedStatisticsTools() -> [any MCPToolHandler] {
    return [
        // Probability distributions
        BinomialProbabilityTool(),
        PoissonProbabilityTool(),
        ExponentialDistributionTool(),
        HypergeometricProbabilityTool(),
        LogNormalDistributionTool(),

        // Combinatorics
        CalculateCombinationsTool(),
        CalculatePermutationsTool(),
        CalculateFactorialTool(),

        // Statistical means
        GeometricMeanTool(),
        HarmonicMeanTool(),
        WeightedAverageTool(),

        // Analysis tools
        GoalSeekTool(),
        DataTableTool()
    ]
}
