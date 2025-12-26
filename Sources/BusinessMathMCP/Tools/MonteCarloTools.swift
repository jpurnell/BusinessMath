//
//  MonteCarloTools.swift
//  BusinessMath MCP Server
//
//  Monte Carlo simulation tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all Monte Carlo simulation tools
public func getMonteCarloTools() -> [any MCPToolHandler] {
    return [
        CreateDistributionTool(),
        RunMonteCarloTool(),
        AnalyzeSimulationResultsTool(),
        CalculateValueAtRiskTool(),
        CalculateProbabilityTool(),
        SensitivityAnalysisTool(),
        TornadoAnalysisTool(),
        RunScenarioAnalysisTool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format a percentage (input is already in percentage form, e.g., 95.5 for 95.5%)

// MARK: - 1. Create Distribution

public struct CreateDistributionTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_distribution",
        description: """
        Create a probability distribution for Monte Carlo simulation.

        Supported distributions:
        • Normal (Gaussian): mean, stdDev - for continuous data with bell curve
        • Uniform: min, max - equal probability across range
        • Triangular: min, max, mode - for estimates with most likely value
        • Exponential: rate - for time between events
        • LogNormal: mean, stdDev - for multiplicative processes (e.g., stock prices)
        • Beta: alpha, beta - for probabilities/proportions (0-1)
        • Gamma: shape, scale - for waiting times
        • Weibull: shape, scale - for reliability/failure analysis
        • ChiSquared: degreesOfFreedom - for goodness-of-fit tests, variance estimation
        • F: df1, df2 - for ANOVA, comparing variances
        • T: degreesOfFreedom - for small-sample inference, confidence intervals
        • Pareto: scale, shape - for wealth distribution, 80/20 rule modeling
        • Logistic: mean, stdDev - for growth models, S-curves
        • Geometric: p - for discrete "time until first success" models
        • Rayleigh: mean - for magnitude modeling (wind speed, wave height)

        Returns distribution parameters and sample values for verification.

        Example: Create normal distribution for revenue uncertainty
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "type": MCPSchemaProperty(
                    type: "string",
                    description: "Distribution type",
                    enum: ["normal", "uniform", "triangular", "exponential", "lognormal", "beta", "gamma", "weibull", "chisquared", "f", "t", "pareto", "logistic", "geometric", "rayleigh"]
                ),
                "parameters": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Distribution parameters (varies by type):
                    • normal: {mean, stdDev}
                    • uniform: {min, max}
                    • triangular: {min, max, mode}
                    • exponential: {rate}
                    • lognormal: {mean, stdDev}
                    • beta: {alpha, beta}
                    • gamma: {shape, scale}
                    • weibull: {shape, scale}
                    • chisquared: {degreesOfFreedom}
                    • f: {df1, df2}
                    • t: {degreesOfFreedom}
                    • pareto: {scale, shape}
                    • logistic: {mean, stdDev}
                    • geometric: {p}
                    • rayleigh: {mean}
                    """
                ),
                "sampleSize": MCPSchemaProperty(
                    type: "number",
                    description: "Number of sample values to generate for verification (default: 10)"
                )
            ],
            required: ["type", "parameters"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let type = try args.getString("type")
        let sampleSize = args.getIntOptional("sampleSize") ?? 10

        guard let parametersDict = args["parameters"]?.value as? [String: Any] else {
            throw ToolError.invalidArguments("Missing or invalid parameters")
        }

        var samples: [Double] = []
        var distInfo: String = ""

        switch type {
        case "normal":
            guard let mean = parametersDict["mean"] as? Double,
                  let stdDev = parametersDict["stdDev"] as? Double else {
                throw ToolError.invalidArguments("Normal distribution requires 'mean' and 'stdDev'")
            }
            distInfo = "Normal(μ=\(formatNumber(mean, decimals: 2)), σ=\(formatNumber(stdDev, decimals: 2)))"
            let dist = DistributionNormal(mean, stdDev)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "uniform":
            guard let min = parametersDict["min"] as? Double,
                  let max = parametersDict["max"] as? Double else {
                throw ToolError.invalidArguments("Uniform distribution requires 'min' and 'max'")
            }
            distInfo = "Uniform(min=\(formatNumber(min, decimals: 2)), max=\(formatNumber(max, decimals: 2)))"
            let dist = DistributionUniform(min, max)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "triangular":
            guard let min = parametersDict["min"] as? Double,
                  let max = parametersDict["max"] as? Double,
                  let mode = parametersDict["mode"] as? Double else {
                throw ToolError.invalidArguments("Triangular distribution requires 'min', 'max', and 'mode'")
            }
            distInfo = "Triangular(min=\(formatNumber(min, decimals: 2)), mode=\(formatNumber(mode, decimals: 2)), max=\(formatNumber(max, decimals: 2)))"
            let dist = DistributionTriangular(low: min, high: max, base: mode)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "exponential":
            guard let rate = parametersDict["rate"] as? Double else {
                throw ToolError.invalidArguments("Exponential distribution requires 'rate'")
            }
            distInfo = "Exponential(λ=\(formatNumber(rate, decimals: 4)))"
            let dist = DistributionExponential(rate)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "lognormal":
            guard let mean = parametersDict["mean"] as? Double,
                  let stdDev = parametersDict["stdDev"] as? Double else {
                throw ToolError.invalidArguments("LogNormal distribution requires 'mean' and 'stdDev'")
            }
            distInfo = "LogNormal(μ=\(formatNumber(mean, decimals: 2)), σ=\(formatNumber(stdDev, decimals: 2)))"
            let dist = DistributionLogNormal(mean, stdDev)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "beta":
            guard let alpha = parametersDict["alpha"] as? Double,
                  let beta = parametersDict["beta"] as? Double else {
                throw ToolError.invalidArguments("Beta distribution requires 'alpha' and 'beta'")
            }
            distInfo = "Beta(α=\(formatNumber(alpha, decimals: 2)), β=\(formatNumber(beta, decimals: 2)))"
            let dist = DistributionBeta(alpha: alpha, beta: beta)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "gamma":
            guard let shape = parametersDict["shape"] as? Double,
                  let scale = parametersDict["scale"] as? Double else {
                throw ToolError.invalidArguments("Gamma distribution requires 'shape' and 'scale'")
            }
            distInfo = "Gamma(k=\(formatNumber(shape, decimals: 2)), θ=\(formatNumber(scale, decimals: 2)))"
            let dist = DistributionGamma(r: Int(shape), λ: 1.0 / scale)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "weibull":
            guard let shape = parametersDict["shape"] as? Double,
                  let scale = parametersDict["scale"] as? Double else {
                throw ToolError.invalidArguments("Weibull distribution requires 'shape' and 'scale'")
            }
            distInfo = "Weibull(k=\(formatNumber(shape, decimals: 2)), λ=\(formatNumber(scale, decimals: 2)))"
            let dist = DistributionWeibull(shape: shape, scale: scale)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "chisquared":
            guard let df = parametersDict["degreesOfFreedom"] as? Double else {
                throw ToolError.invalidArguments("Chi-Squared distribution requires 'degreesOfFreedom'")
            }
            distInfo = "Chi-Squared(df=\(formatNumber(df, decimals: 0)))"
            let dist = DistributionChiSquared(degreesOfFreedom: Int(df))
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "f":
            guard let df1 = parametersDict["df1"] as? Double,
                  let df2 = parametersDict["df2"] as? Double else {
                throw ToolError.invalidArguments("F distribution requires 'df1' and 'df2'")
            }
            distInfo = "F(df1=\(formatNumber(df1, decimals: 0)), df2=\(formatNumber(df2, decimals: 0)))"
            let dist = DistributionF(df1: Int(df1), df2: Int(df2))
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "t":
            guard let df = parametersDict["degreesOfFreedom"] as? Double else {
                throw ToolError.invalidArguments("T distribution requires 'degreesOfFreedom'")
            }
            distInfo = "T(df=\(formatNumber(df, decimals: 0)))"
            let dist = DistributionT(degreesOfFreedom: Int(df))
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "pareto":
            guard let scale = parametersDict["scale"] as? Double,
                  let shape = parametersDict["shape"] as? Double else {
                throw ToolError.invalidArguments("Pareto distribution requires 'scale' and 'shape'")
            }
            distInfo = "Pareto(xₘ=\(formatNumber(scale, decimals: 2)), α=\(formatNumber(shape, decimals: 2)))"
            let dist = DistributionPareto(scale: scale, shape: shape)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "logistic":
            guard let mean = parametersDict["mean"] as? Double,
                  let stdDev = parametersDict["stdDev"] as? Double else {
                throw ToolError.invalidArguments("Logistic distribution requires 'mean' and 'stdDev'")
            }
            distInfo = "Logistic(μ=\(formatNumber(mean, decimals: 2)), σ=\(formatNumber(stdDev, decimals: 2)))"
            let dist = DistributionLogistic(mean, stdDev)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        case "geometric":
            guard let p = parametersDict["p"] as? Double else {
                throw ToolError.invalidArguments("Geometric distribution requires 'p' (probability)")
            }
            distInfo = "Geometric(p=\(formatNumber(p, decimals: 4)))"
            let dist = DistributionGeometric(p)
            for _ in 0..<sampleSize {
                samples.append(Double(dist.next()))
            }

        case "rayleigh":
            guard let mean = parametersDict["mean"] as? Double else {
                throw ToolError.invalidArguments("Rayleigh distribution requires 'mean'")
            }
            distInfo = "Rayleigh(μ=\(formatNumber(mean, decimals: 2)))"
            let dist = DistributionRayleigh(mean: mean)
            for _ in 0..<sampleSize {
                samples.append(dist.next())
            }

        default:
            throw ToolError.invalidArguments("Unknown distribution type: \(type)")
        }

        let sampleMean = mean(samples)
        let sampleStdDev = stdDev(samples, .sample)

        var output = """
        Distribution Created: \(distInfo)

        Sample Statistics (\(sampleSize) samples):
        • Mean: \(formatNumber(sampleMean, decimals: 4))
        • Std Dev: \(formatNumber(sampleStdDev, decimals: 4))
        • Min: \(formatNumber(samples.min() ?? 0, decimals: 4))
        • Max: \(formatNumber(samples.max() ?? 0, decimals: 4))

        Sample Values:
        """

        for (i, sample) in samples.prefix(10).enumerated() {
            output += "\n  \(i + 1). \(formatNumber(sample, decimals: 4))"
        }

        output += """


        Use this distribution in Monte Carlo simulations with run_monte_carlo.
        """

        return .success(text: output)
    }
}

// MARK: - 2. Run Monte Carlo Simulation

public struct RunMonteCarloTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_monte_carlo",
        description: """
        Run a Monte Carlo simulation to model uncertainty and risk.

        This tool simulates thousands of scenarios by randomly sampling from
        probability distributions you define for uncertain inputs, then
        calculates an outcome for each scenario.

        REQUIRED STRUCTURE:
        {
          "inputs": [
            {
              "name": "Revenue",
              "distribution": "normal",
              "parameters": {"mean": 1000000, "stdDev": 200000}
            }
          ],
          "calculation": "{0}",
          "iterations": 10000
        }

        COMPLETE EXAMPLES:

        1. Simple Revenue Model:
        {
          "inputs": [{
            "name": "Revenue",
            "distribution": "normal",
            "parameters": {"mean": 1000000, "stdDev": 200000}
          }],
          "calculation": "{0}",
          "iterations": 10000
        }

        2. Profit Model (Revenue - Costs):
        {
          "inputs": [
            {
              "name": "Revenue",
              "distribution": "normal",
              "parameters": {"mean": 1000000, "stdDev": 200000}
            },
            {
              "name": "Costs",
              "distribution": "normal",
              "parameters": {"mean": 600000, "stdDev": 100000}
            }
          ],
          "calculation": "{0} - {1}",
          "iterations": 10000
        }

        Returns comprehensive statistics, percentiles, and risk metrics.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputs": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of uncertain input variables. Each object must have:
                    • name (string): Variable name (e.g., "Revenue", "Costs")
                    • distribution (string): "normal", "uniform", or "triangular"
                    • parameters (object): Distribution parameters
                      - normal: {mean: number, stdDev: number}
                      - uniform: {min: number, max: number}
                      - triangular: {min: number, max: number, mode: number}

                    Example:
                    [
                      {
                        "name": "Revenue",
                        "distribution": "normal",
                        "parameters": {"mean": 1000000, "stdDev": 200000}
                      },
                      {
                        "name": "Costs",
                        "distribution": "normal",
                        "parameters": {"mean": 600000, "stdDev": 100000}
                      }
                    ]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula combining inputs using {0}, {1}, {2}, etc.
                    Examples:
                    • Profit: "{0} - {1}" (Revenue - Costs)
                    • Margin: "({0} - {1}) / {0}" ((Revenue - Costs) / Revenue)
                    • Growth: "{0} * (1 + {1})" (Base * (1 + Rate))
                    """
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: "Number of simulation iterations (default: 10000, recommended: 1000-100000)"
                )
            ],
            required: ["inputs", "calculation"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Extract array of AnyCodable objects
        guard let inputsAnyCodable = args["inputs"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'inputs' array")
        }

        let calculation = try args.getString("calculation")
        let iterations = args.getIntOptional("iterations") ?? 10000

        guard iterations > 0 && iterations <= 1_000_000 else {
            throw ToolError.invalidArguments("Iterations must be between 1 and 1,000,000")
        }

        // Parse inputs and create distributions
        var simulationInputs: [SimulationInput] = []

        for (index, inputAnyCodable) in inputsAnyCodable.enumerated() {
            guard let inputDict = inputAnyCodable.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("inputs[\(index)] must be an object")
            }

            guard let name = inputDict["name"]?.value as? String,
                  let distType = inputDict["distribution"]?.value as? String,
                  let paramsAnyCodable = inputDict["parameters"]?.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each input must have 'name', 'distribution', and 'parameters'")
            }

            // Extract parameters as doubles
            var params: [String: Double] = [:]
            for (key, value) in paramsAnyCodable {
                if let doubleVal = value.value as? Double {
                    params[key] = doubleVal
                } else if let intVal = value.value as? Int {
                    params[key] = Double(intVal)
                } else {
                    throw ToolError.invalidArguments("Parameter '\(key)' must be a number")
                }
            }

            // Create SimulationInput directly based on distribution type
            let simInput: SimulationInput
            switch distType {
            case "normal":
                guard let mean = params["mean"], let stdDev = params["stdDev"] else {
                    throw ToolError.invalidArguments("Normal distribution requires 'mean' and 'stdDev'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionNormal(mean, stdDev))
            case "uniform":
                guard let min = params["min"], let max = params["max"] else {
                    throw ToolError.invalidArguments("Uniform distribution requires 'min' and 'max'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionUniform(min, max))
            case "triangular":
                guard let min = params["min"], let max = params["max"], let mode = params["mode"] else {
                    throw ToolError.invalidArguments("Triangular distribution requires 'min', 'max', and 'mode'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionTriangular(low: min, high: max, base: mode))
            default:
                throw ToolError.invalidArguments("Unsupported distribution type for simulation: \(distType). Supported: normal, uniform, triangular")
            }
            simulationInputs.append(simInput)
        }

        // Create and run simulation
        var simulation = MonteCarloSimulation(iterations: iterations) { inputs in
            // Evaluate calculation
            return evaluateCalculation(calculation, with: inputs)
        }

        for input in simulationInputs {
            simulation.addInput(input)
        }

        let results = try simulation.run()

        // Format output
        let inputNames = simulationInputs.map { $0.name }.joined(separator: ", ")

        let output = """
        Monte Carlo Simulation Results:

        Model:
        • Calculation: \(calculation)
        • Input Variables: \(inputNames)
        • Iterations: \(formatNumber(Double(iterations), decimals: 0))

        Outcome Statistics:
        • Mean: \(formatNumber(results.statistics.mean, decimals: 2))
        • Median: \(formatNumber(results.statistics.median, decimals: 2))
        • Std Dev: \(formatNumber(results.statistics.stdDev, decimals: 2))
        • Min: \(formatNumber(results.statistics.min, decimals: 2))
        • Max: \(formatNumber(results.statistics.max, decimals: 2))
        • Skewness: \(formatNumber(results.statistics.skewness, decimals: 3))

        Confidence Intervals:
        • 90% CI: [\(formatNumber(results.statistics.ci90.low, decimals: 2)), \(formatNumber(results.statistics.ci90.high, decimals: 2))]
        • 95% CI: [\(formatNumber(results.statistics.ci95.low, decimals: 2)), \(formatNumber(results.statistics.ci95.high, decimals: 2))]
        • 99% CI: [\(formatNumber(results.statistics.ci99.low, decimals: 2)), \(formatNumber(results.statistics.ci99.high, decimals: 2))]

        Percentiles:
        • 5th: \(formatNumber(results.percentiles.p5, decimals: 2))
        • 25th (Q1): \(formatNumber(results.percentiles.p25, decimals: 2))
        • 50th (Median): \(formatNumber(results.percentiles.p50, decimals: 2))
        • 75th (Q3): \(formatNumber(results.percentiles.p75, decimals: 2))
        • 95th: \(formatNumber(results.percentiles.p95, decimals: 2))

        Use analyze_simulation_results for additional analysis (probabilities, VaR, etc.)
        """

        return .success(text: output)
    }
}

// MARK: - 3. Analyze Simulation Results

public struct AnalyzeSimulationResultsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_simulation_results",
        description: """
        Perform detailed analysis on simulation outcome values.

        Provides comprehensive statistical analysis including:
        • Descriptive statistics
        • Percentile analysis
        • Probability calculations
        • Risk metrics
        • Distribution visualization (histogram data)

        Input the raw simulation outcome values from a Monte Carlo simulation.

        Example: Analyze profit/loss distribution from previous simulation
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Simulation outcome values to analyze",
                    items: MCPSchemaItems(type: "number")
                ),
                "label": MCPSchemaProperty(
                    type: "string",
                    description: "Optional label for the metric (e.g., 'Profit', 'NPV', 'Revenue')"
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
        let label = args.getStringOptional("label") ?? "Outcome"

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Values array cannot be empty")
        }

        let results = SimulationResults(values: values)

        // Generate histogram
        let histogram = results.histogram(bins: 20)
        let maxCount = histogram.map { $0.count }.max() ?? 1
		
		// Determine decimal places based on value magnitude
		let maxValue = histogram.map { $0.range.upperBound }.max() ?? 1.0
		let decimalPlaces: Int
		if maxValue > 1000 {
			decimalPlaces = 0
		} else if maxValue > 10 {
			decimalPlaces = 1
		} else {
			decimalPlaces = 2
		}

        var histogramText = "\n\nDistribution Histogram (20 bins):\n"
        for bin in histogram {
            let barLength = Int(Double(bin.count) / Double(maxCount) * 40)
            let bar = String(repeating: "█", count: barLength)
			let percentage = Double(bin.count) / Double(values.count)
			
			histogramText += "[\(bin.range.lowerBound.number(decimalPlaces).paddingLeft(toLength: 8)) - \(bin.range.upperBound.number(decimalPlaces).paddingLeft(toLength: 8))):  \(bar) \("\(bin.count)".paddingLeft(toLength: 4)) (\(percentage.percent(1)))\n"
        }

        let output = """
        Simulation Analysis: \(label)

        Sample Size: \(formatNumber(Double(values.count), decimals: 0)) iterations

        Central Tendency:
        • Mean: \(formatNumber(results.statistics.mean, decimals: 2))
        • Median: \(formatNumber(results.statistics.median, decimals: 2))

        Dispersion:
        • Std Dev: \(formatNumber(results.statistics.stdDev, decimals: 2))
        • Variance: \(formatNumber(results.statistics.variance, decimals: 2))
        • Range: \(formatNumber(results.statistics.max - results.statistics.min, decimals: 2))
        • Min: \(formatNumber(results.statistics.min, decimals: 2))
        • Max: \(formatNumber(results.statistics.max, decimals: 2))

        Distribution Shape:
        • Skewness: \(formatNumber(results.statistics.skewness, decimals: 3))
          \(abs(results.statistics.skewness) < 0.5 ? "(Approximately symmetric)" :
            results.statistics.skewness > 0 ? "(Right-skewed)" : "(Left-skewed)")

        Percentiles:
        • P5: \(formatNumber(results.percentiles.p5, decimals: 2))
        • P10: \(formatNumber(results.percentiles.p10, decimals: 2))
        • P25 (Q1): \(formatNumber(results.percentiles.p25, decimals: 2))
        • P50 (Median): \(formatNumber(results.percentiles.p50, decimals: 2))
        • P75 (Q3): \(formatNumber(results.percentiles.p75, decimals: 2))
        • P90: \(formatNumber(results.percentiles.p90, decimals: 2))
        • P95: \(formatNumber(results.percentiles.p95, decimals: 2))
        • P99: \(formatNumber(results.percentiles.p99, decimals: 2))

        Confidence Intervals:
        • 90%: [\(formatNumber(results.statistics.ci90.low, decimals: 2)), \(formatNumber(results.statistics.ci90.high, decimals: 2))]
        • 95%: [\(formatNumber(results.statistics.ci95.low, decimals: 2)), \(formatNumber(results.statistics.ci95.high, decimals: 2))]
        • 99%: [\(formatNumber(results.statistics.ci99.low, decimals: 2)), \(formatNumber(results.statistics.ci99.high, decimals: 2))]
        \(histogramText)
        """

        return .success(text: output)
    }
}

// MARK: - 4. Calculate Value at Risk (VaR)

public struct CalculateValueAtRiskTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_value_at_risk",
        description: """
        Calculate Value at Risk (VaR) from simulation results.

        VaR answers: "What is the maximum loss we expect with X% confidence?"

        For example, 95% VaR = -$100,000 means:
        "We are 95% confident that losses will not exceed $100,000"
        or equivalently:
        "There is a 5% chance of losing more than $100,000"

        Commonly used confidence levels:
        • 90% VaR (10th percentile for losses)
        • 95% VaR (5th percentile for losses)
        • 99% VaR (1st percentile for losses)

        Example: Determine worst-case portfolio loss with 95% confidence
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Simulation outcome values (e.g., profit/loss, returns)",
                    items: MCPSchemaItems(type: "number")
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (e.g., 0.95 for 95% VaR, 0.99 for 99% VaR). Default: 0.95"
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
        let confidenceLevel = args.getDoubleOptional("confidenceLevel") ?? 0.95

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Values array cannot be empty")
        }

        guard confidenceLevel > 0 && confidenceLevel < 1 else {
            throw ToolError.invalidArguments("Confidence level must be between 0 and 1")
        }

        let results = SimulationResults(values: values)

        // VaR is the percentile at (1 - confidence level)
        // For 95% confidence, we look at the 5th percentile
        let percentileLevel = 1.0 - confidenceLevel
        let sortedValues = values.sorted()
        let index = Int(percentileLevel * Double(values.count))
        let varValue = sortedValues[min(index, sortedValues.count - 1)]

        // Calculate conditional VaR (CVaR / Expected Shortfall)
        let worseValues = sortedValues.prefix(index + 1)
        let cvar = worseValues.isEmpty ? varValue : mean(Array(worseValues))

        // Probability of loss (negative outcome)
        let probLoss = results.probabilityBelow(0)

        let output = """
        Value at Risk (VaR) Analysis:

        VaR at \(confidenceLevel.percent())% Confidence:
        • VaR: \(formatNumber(varValue, decimals: 2))
        • Interpretation: With \(confidenceLevel.percent())% confidence, losses will not exceed \(formatNumber(abs(varValue), decimals: 2))
        • Or: There is a \((1 - confidenceLevel).percent())% chance of losses exceeding \(formatNumber(abs(varValue), decimals: 2))

        Conditional VaR (CVaR / Expected Shortfall):
        • CVaR: \(formatNumber(cvar, decimals: 2))
        • Average loss in worst \((1 - confidenceLevel).percent())% of cases

        Risk Metrics:
        • Probability of Loss (< 0): \(probLoss.percent())%
        • Mean Outcome: \(formatNumber(results.statistics.mean, decimals: 2))
        • Worst Case: \(formatNumber(results.statistics.min, decimals: 2))
        • Best Case: \(formatNumber(results.statistics.max, decimals: 2))

        Percentile Reference:
        • P5 (95% VaR): \(formatNumber(results.percentiles.p5, decimals: 2))
        • P10 (90% VaR): \(formatNumber(results.percentiles.p10, decimals: 2))
        • P25 (75% VaR): \(formatNumber(results.percentiles.p25, decimals: 2))
        • P50 (Median): \(formatNumber(results.percentiles.p50, decimals: 2))

        \(varValue < 0 ? "⚠️  VaR indicates risk of losses" : "✓ VaR is positive - low risk of losses")
        """

        return .success(text: output)
    }
}

// MARK: - 5. Calculate Probability

public struct CalculateProbabilityTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_probability",
        description: """
        Calculate probabilities from simulation results.

        Supports three types of probability calculations:
        • above: P(X > threshold) - probability of exceeding a value
        • below: P(X < threshold) - probability below a value
        • between: P(lower < X < upper) - probability within a range

        Example use cases:
        • P(Profit > $500,000) - probability of high profits
        • P(Loss < 0) - probability of loss
        • P($400,000 < Profit < $600,000) - probability of target range

        Returns probability as both decimal (0-1) and percentage (0-100%).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Simulation outcome values",
                    items: MCPSchemaItems(type: "number")
                ),
                "type": MCPSchemaProperty(
                    type: "string",
                    description: "Type of probability calculation",
                    enum: ["above", "below", "between"]
                ),
                "threshold": MCPSchemaProperty(
                    type: "number",
                    description: "Threshold value (for 'above' or 'below' types)"
                ),
                "lower": MCPSchemaProperty(
                    type: "number",
                    description: "Lower bound (for 'between' type)"
                ),
                "upper": MCPSchemaProperty(
                    type: "number",
                    description: "Upper bound (for 'between' type)"
                )
            ],
            required: ["values", "type"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")
        let probType = try args.getString("type")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Values array cannot be empty")
        }

        let results = SimulationResults(values: values)
        var probability: Double
        var description: String

        switch probType {
        case "above":
            let threshold = try args.getDouble("threshold")
            probability = results.probabilityAbove(threshold)
            description = "P(X > \(formatNumber(threshold, decimals: 2)))"

        case "below":
            let threshold = try args.getDouble("threshold")
            probability = results.probabilityBelow(threshold)
            description = "P(X < \(formatNumber(threshold, decimals: 2)))"

        case "between":
            let lower = try args.getDouble("lower")
            let upper = try args.getDouble("upper")
            probability = results.probabilityBetween(lower, upper)
            description = "P(\(formatNumber(lower, decimals: 2)) < X < \(formatNumber(upper, decimals: 2)))"

        default:
            throw ToolError.invalidArguments("Invalid probability type. Use 'above', 'below', or 'between'")
        }

        // Interpret probability
        let interpretation = probability > 0.75 ? "Very likely" :
                            probability > 0.50 ? "Likely" :
                            probability > 0.25 ? "Possible" :
                            probability > 0.10 ? "Unlikely" : "Very unlikely"

        let output = """
        Probability Calculation:

        Query: \(description)

        Result:
        • Probability: \(formatNumber(probability, decimals: 4)) (\(probability.percent())%)
        • Interpretation: \(interpretation)
        • Sample Size: \(formatNumber(Double(values.count), decimals: 0)) iterations

        Context:
        • Mean: \(formatNumber(results.statistics.mean, decimals: 2))
        • Median: \(formatNumber(results.statistics.median, decimals: 2))
        • Std Dev: \(formatNumber(results.statistics.stdDev, decimals: 2))

        Confidence:
        With \(values.count) simulations, the probability estimate has:
        • Standard error: ±\(sqrt(probability * (1 - probability) / Double(values.count)).percent())%
        """

        return .success(text: output)
    }
}

// MARK: - 6. Sensitivity Analysis

public struct SensitivityAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "sensitivity_analysis",
        description: """
        Perform single-variable sensitivity analysis.

        Tests how changes in one input variable affect the outcome by:
        1. Varying the input across a range (e.g., ±20%)
        2. Recalculating the outcome at each level
        3. Measuring the change in outcome

        Helps identify which variables have the most impact on results.

        REQUIRED STRUCTURE (Percent Change):
        {
          "baseValue": 1000000,
          "variableRange": {"percentChange": 20},
          "calculation": "{0} * 0.4",
          "variableName": "Revenue"
        }

        REQUIRED STRUCTURE (Explicit Range):
        {
          "baseValue": 1000000,
          "variableRange": {"min": 800000, "max": 1200000},
          "calculation": "{0} - 600000",
          "variableName": "Revenue"
        }

        Example: Test profit sensitivity to revenue changes (±30%)
        {
          "baseValue": 1000000,
          "variableRange": {"percentChange": 30},
          "calculation": "{0} - 600000",
          "variableName": "Revenue",
          "steps": 15
        }

        Returns sensitivity metrics and input-output table showing impact.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "baseValue": MCPSchemaProperty(
                    type: "number",
                    description: "Base (current) value of the input variable"
                ),
                "variableRange": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Range to test the variable. Use ONE of:
                    • {"percentChange": 20} - test ±20% from base value
                    • {"min": 80, "max": 120} - test explicit min/max range

                    Examples:
                    - {"percentChange": 25} tests 75% to 125% of base
                    - {"min": 500000, "max": 1500000} tests explicit range
                    """
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: "Formula using {0} to reference the variable. Example: \"{0} * 1.2 - 50000\""
                ),
                "steps": MCPSchemaProperty(
                    type: "number",
                    description: "Number of test points (default: 11). More steps = smoother analysis."
                ),
                "variableName": MCPSchemaProperty(
                    type: "string",
                    description: "Name of the variable being tested (optional, for display)"
                )
            ],
            required: ["baseValue", "variableRange", "calculation"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let baseValue = try args.getDouble("baseValue")
        let calculation = try args.getString("calculation")
        let steps = args.getIntOptional("steps") ?? 11
        let variableName = args.getStringOptional("variableName") ?? "Variable"

        guard let rangeDict = args["variableRange"]?.value as? [String: Any] else {
            throw ToolError.invalidArguments("Missing or invalid 'variableRange'")
        }

        // Determine range
        let minValue: Double
        let maxValue: Double

        if let percentChange = rangeDict["percentChange"] as? Double {
            let delta = baseValue * (percentChange / 100.0)
            minValue = baseValue - delta
            maxValue = baseValue + delta
        } else if let min = rangeDict["min"] as? Double,
                  let max = rangeDict["max"] as? Double {
            minValue = min
            maxValue = max
        } else {
            throw ToolError.invalidArguments("variableRange must specify either 'percentChange' or 'min' and 'max'")
        }

        // Generate test values
        let stepSize = (maxValue - minValue) / Double(steps - 1)
        var results: [(input: Double, output: Double)] = []

        for i in 0..<steps {
            let inputValue = minValue + Double(i) * stepSize
            let outputValue = evaluateCalculation(calculation, with: [inputValue])
            results.append((input: inputValue, output: outputValue))
        }

        // Calculate base output
        let baseOutput = evaluateCalculation(calculation, with: [baseValue])

        // Calculate sensitivity metrics
        let outputRange = results.map { $0.output }.max()! - results.map { $0.output }.min()!
        let inputRange = maxValue - minValue
        let sensitivity = outputRange / inputRange

        var output = """
        Sensitivity Analysis: \(variableName)

        Base Case:
        • Input: \(formatNumber(baseValue, decimals: 2))
        • Output: \(formatNumber(baseOutput, decimals: 2))

        Range Tested:
        • Min Input: \(formatNumber(minValue, decimals: 2))
        • Max Input: \(formatNumber(maxValue, decimals: 2))
        • Input Range: \(formatNumber(inputRange, decimals: 2))

        Output Response:
        • Min Output: \(formatNumber(results.map { $0.output }.min()!, decimals: 2))
        • Max Output: \(formatNumber(results.map { $0.output }.max()!, decimals: 2))
        • Output Range: \(formatNumber(outputRange, decimals: 2))

        Sensitivity:
        • Sensitivity Factor: \(formatNumber(sensitivity, decimals: 4))
        • Interpretation: 1 unit change in input → \(formatNumber(sensitivity, decimals: 2)) unit change in output

        Input-Output Table:
        """

        for result in results {
            let marker = abs(result.input - baseValue) < stepSize * 0.1 ? " ← Base" : ""
            output += "\n  \(formatNumber(result.input, decimals: 2)) → \(formatNumber(result.output, decimals: 2))\(marker)"
        }

        return .success(text: output)
    }
}

// MARK: - 7. Tornado Analysis

public struct TornadoAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "tornado_analysis",
        description: """
        Perform tornado (sensitivity) analysis across multiple variables.

        Tests each input variable independently by varying it while holding
        others constant, then ranks variables by their impact on the outcome.

        Creates a "tornado diagram" (visualized as text) showing which
        variables have the most influence on results.

        REQUIRED STRUCTURE:
        {
          "variables": [
            {"name": "Revenue", "baseValue": 1000000, "lowValue": 800000, "highValue": 1200000},
            {"name": "Costs", "baseValue": 600000, "lowValue": 500000, "highValue": 700000}
          ],
          "calculation": "{0} - {1}"
        }

        Example: Identify key profit drivers
        {
          "variables": [
            {"name": "Revenue", "baseValue": 1000000, "lowValue": 900000, "highValue": 1100000},
            {"name": "Operating Costs", "baseValue": 600000, "lowValue": 550000, "highValue": 650000},
            {"name": "Marketing Costs", "baseValue": 100000, "lowValue": 80000, "highValue": 120000}
          ],
          "calculation": "{0} - {1} - {2}"
        }

        Example: Project NPV sensitivity
        {
          "variables": [
            {"name": "Initial Investment", "baseValue": 500000, "lowValue": 450000, "highValue": 600000},
            {"name": "Annual Cash Flow", "baseValue": 150000, "lowValue": 120000, "highValue": 180000},
            {"name": "Discount Rate", "baseValue": 0.1, "lowValue": 0.08, "highValue": 0.12}
          ],
          "calculation": "{1} / {2} - {0}"
        }

        Returns ranked list showing which variables have the greatest impact.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "variables": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of variables to test. Each object must have:
                    • name (string): Variable name for display
                    • baseValue (number): Expected/current value
                    • lowValue (number): Pessimistic scenario value
                    • highValue (number): Optimistic scenario value

                    Example: [{"name": "Revenue", "baseValue": 1000000, "lowValue": 800000, "highValue": 1200000}]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: "Formula using {0}, {1}, {2}, etc. to reference variables in order. Example: \"{0} - {1} - {2}\" for Revenue - Cost1 - Cost2"
                )
            ],
            required: ["variables", "calculation"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        guard let variablesArray = args["variables"]?.value as? [[String: Any]] else {
            throw ToolError.invalidArguments("Missing or invalid 'variables' array")
        }

        let calculation = try args.getString("calculation")

        // Parse variables
        struct Variable {
            let name: String
            let baseValue: Double
            let lowValue: Double
            let highValue: Double
        }

        var variables: [Variable] = []
        for varDict in variablesArray {
            guard let name = varDict["name"] as? String,
                  let base = varDict["baseValue"] as? Double,
                  let low = varDict["lowValue"] as? Double,
                  let high = varDict["highValue"] as? Double else {
                throw ToolError.invalidArguments("Each variable must have 'name', 'baseValue', 'lowValue', and 'highValue'")
            }
            variables.append(Variable(name: name, baseValue: base, lowValue: low, highValue: high))
        }

        guard !variables.isEmpty else {
            throw ToolError.invalidArguments("Must provide at least one variable")
        }

        // Calculate base case
        let baseInputs = variables.map { $0.baseValue }
        let baseOutput = evaluateCalculation(calculation, with: baseInputs)

        // Test each variable
        struct Impact {
            let name: String
            let lowOutput: Double
            let highOutput: Double
            let range: Double
        }

        var impacts: [Impact] = []

        for (index, variable) in variables.enumerated() {
            // Test low value
            var lowInputs = baseInputs
            lowInputs[index] = variable.lowValue
            let lowOutput = evaluateCalculation(calculation, with: lowInputs)

            // Test high value
            var highInputs = baseInputs
            highInputs[index] = variable.highValue
            let highOutput = evaluateCalculation(calculation, with: highInputs)

            let range = abs(highOutput - lowOutput)
            impacts.append(Impact(name: variable.name, lowOutput: lowOutput, highOutput: highOutput, range: range))
        }

        // Sort by impact (range)
        impacts.sort { $0.range > $1.range }

        // Generate output
        var output = """
        Tornado Analysis:

        Base Case Output: \(formatNumber(baseOutput, decimals: 2))

        Variables Ranked by Impact:
        """

        let maxRange = impacts.first?.range ?? 1.0

        for (rank, impact) in impacts.enumerated() {
            let barLength = Int((impact.range / maxRange) * 30)
            let bar = String(repeating: "█", count: barLength)
            output += """

        \(rank + 1). \(impact.name)
           Low:  \(formatNumber(impact.lowOutput, decimals: 2))  \(bar)
           High: \(formatNumber(impact.highOutput, decimals: 2))
           Range: \(formatNumber(impact.range, decimals: 2)) (\((impact.range / baseOutput).percent())% of base)
        """
        }

        output += """


        Interpretation:
        • Variables at the top have the greatest impact on outcomes
        • Focus risk management and analysis efforts on top-ranked variables
        • Consider fixing or hedging high-impact variables if possible
        """

        return .success(text: output)
    }
}

// MARK: - Helper Functions

/// Create a distribution from type and parameters
private func createDistribution(type: String, parameters: [String: Double]) throws -> any DistributionRandom {
    switch type {
    case "normal":
        guard let mean = parameters["mean"], let stdDev = parameters["stdDev"] else {
            throw ToolError.invalidArguments("Normal distribution requires 'mean' and 'stdDev'")
        }
        return DistributionNormal(mean, stdDev)

    case "uniform":
        guard let min = parameters["min"], let max = parameters["max"] else {
            throw ToolError.invalidArguments("Uniform distribution requires 'min' and 'max'")
        }
        return DistributionUniform(min, max)

    case "triangular":
        guard let min = parameters["min"], let max = parameters["max"], let mode = parameters["mode"] else {
            throw ToolError.invalidArguments("Triangular distribution requires 'min', 'max', and 'mode'")
        }
        return DistributionTriangular(low: min, high: max, base: mode)

    default:
        throw ToolError.invalidArguments("Unsupported distribution type: \(type)")
    }
}

/// Evaluate a simple calculation string with input values
private func evaluateCalculation(_ calculation: String, with inputs: [Double]) -> Double {
    var formula = calculation

    // Replace input placeholders {0}, {1}, etc.
    for (index, value) in inputs.enumerated() {
        formula = formula.replacingOccurrences(of: "{\(index)}", with: "\(value)")
    }

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

// MARK: - 8. Scenario Analysis

public struct RunScenarioAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_scenario_analysis",
        description: """
        Run discrete scenario analysis to compare multiple "what-if" cases.

        Scenario analysis evaluates outcomes under different assumptions:
        • Base Case: Expected/most likely assumptions
        • Best Case: Optimistic assumptions
        • Worst Case: Pessimistic assumptions
        • Custom Cases: Any specific assumption sets

        Each scenario defines fixed values for all inputs, and the model
        calculates outcomes. Results are compared side-by-side.

        REQUIRED STRUCTURE:
        {
          "inputNames": ["Revenue", "Costs"],
          "calculation": "{0} - {1}",
          "scenarios": [
            {"name": "Base Case", "values": [1000000, 700000]},
            {"name": "Best Case", "values": [1200000, 600000]},
            {"name": "Worst Case", "values": [800000, 800000]}
          ],
          "iterations": 1000
        }

        Common Applications:
        • Revenue Planning: Compare conservative/aggressive growth scenarios
        • Project Evaluation: Best/worst/most likely outcomes
        • Strategic Planning: Evaluate different market conditions
        • Risk Assessment: Understand range of possible outcomes
        • Sensitivity Testing: How do key assumptions affect results?

        Examples:

        1. Profit Scenario Analysis:
        {
          "inputNames": ["Revenue", "Variable Costs", "Fixed Costs"],
          "calculation": "{0} - {1} - {2}",
          "scenarios": [
            {"name": "Base Case", "values": [1000000, 400000, 200000]},
            {"name": "High Growth", "values": [1500000, 600000, 200000]},
            {"name": "Recession", "values": [700000, 280000, 200000]}
          ],
          "iterations": 1000
        }

        2. NPV Scenario Analysis:
        {
          "inputNames": ["Initial Investment", "Annual Cash Flow", "Years"],
          "calculation": "{1} * {2} - {0}",
          "scenarios": [
            {"name": "Conservative", "values": [500000, 120000, 5]},
            {"name": "Moderate", "values": [500000, 150000, 7]},
            {"name": "Aggressive", "values": [500000, 180000, 10]}
          ],
          "iterations": 1000
        }

        Returns side-by-side comparison with statistics for each scenario.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputNames": MCPSchemaProperty(
                    type: "array",
                    description: "Names of input variables (in order, matching calculation placeholders)",
                    items: MCPSchemaItems(type: "string")
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula using {0}, {1}, {2}, etc. for inputs.
                    Examples:
                    • "{0} - {1}" - Revenue minus Costs
                    • "{0} * (1 - {1})" - Revenue × (1 - Cost Ratio)
                    • "({0} - {1}) / {0}" - Profit Margin
                    """
                ),
                "scenarios": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of scenarios. Each object must have:
                    • name (string): Scenario name (e.g., "Base Case", "Best Case")
                    • values (array of numbers): Values for each input (must match order of inputNames)

                    Example:
                    [
                      {"name": "Base Case", "values": [1000000, 700000]},
                      {"name": "Best Case", "values": [1200000, 600000]}
                    ]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: "Monte Carlo iterations per scenario (default: 1000). Use 1 for pure deterministic analysis."
                )
            ],
            required: ["inputNames", "calculation", "scenarios"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let inputNames = try args.getStringArray("inputNames")
        let calculation = try args.getString("calculation")
        let iterations = args.getIntOptional("iterations") ?? 1000

        guard let scenariosArray = args["scenarios"]?.value as? [[String: AnyCodable]] else {
            throw ToolError.invalidArguments("scenarios must be an array of objects")
        }

        guard !scenariosArray.isEmpty else {
            throw ToolError.invalidArguments("Must provide at least one scenario")
        }

        // Parse scenarios
        struct ScenarioConfig {
            let name: String
            let values: [Double]
        }

        var scenarioConfigs: [ScenarioConfig] = []
        for scenarioDict in scenariosArray {
            guard let name = scenarioDict["name"]?.value as? String else {
                throw ToolError.invalidArguments("Each scenario must have a 'name'")
            }

            guard let valuesArray = scenarioDict["values"]?.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each scenario must have a 'values' array")
            }

            var values: [Double] = []
            for value in valuesArray {
                if let doubleVal = value.value as? Double {
                    values.append(doubleVal)
                } else if let intVal = value.value as? Int {
                    values.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All scenario values must be numbers")
                }
            }

            if values.count != inputNames.count {
                throw ToolError.invalidArguments("Scenario '\(name)' has \(values.count) values but \(inputNames.count) inputs are defined")
            }

            scenarioConfigs.append(ScenarioConfig(name: name, values: values))
        }

        // Create scenario analysis
        let model: @Sendable ([Double]) -> Double = { inputs in
            evaluateCalculation(calculation, with: inputs)
        }

        var analysis = ScenarioAnalysis(
            inputNames: inputNames,
            model: model,
            iterations: iterations
        )

        // Add each scenario
        for config in scenarioConfigs {
            let scenario = Scenario(name: config.name) { scenarioConfig in
                for (index, inputName) in inputNames.enumerated() {
                    scenarioConfig.setValue(config.values[index], forInput: inputName)
                }
            }
            analysis.addScenario(scenario)
        }

        // Run analysis
        let results = try analysis.run()
        let comparison = ScenarioComparison(results: results)

        // Generate output
        var output = """
        Scenario Analysis Results

        Model:
        • Formula: \(calculation)
        • Inputs: \(inputNames.joined(separator: ", "))
        • Iterations per scenario: \(formatNumber(Double(iterations), decimals: 0))

        """

        // Summary table
        output += "\nScenario Comparison:\n"
        output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        output += "Scenario".paddingRight(toLength: 20) + " | Mean      | Median    | Std Dev   | P5        | P95\n"
        output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        for config in scenarioConfigs {
            if let scenarioResults = results[config.name] {
                let stats = scenarioResults.statistics
                let percentiles = scenarioResults.percentiles

                output += "\(config.name.paddingRight(toLength: 20)) | "
                output += "\(formatNumber(stats.mean, decimals: 0).paddingLeft(toLength: 9)) | "
                output += "\(formatNumber(stats.median, decimals: 0).paddingLeft(toLength: 9)) | "
                output += "\(formatNumber(stats.stdDev, decimals: 0).paddingLeft(toLength: 9)) | "
                output += "\(formatNumber(percentiles.p5, decimals: 0).paddingLeft(toLength: 9)) | "
                output += "\(formatNumber(percentiles.p95, decimals: 0))\n"
            }
        }

        output += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"

        // Best/Worst scenarios
        let bestByMean = comparison.bestScenario(by: .mean)
        let worstByMean = comparison.worstScenario(by: .mean)

        output += """


        Key Insights:
        • Best Scenario (by mean): \(bestByMean.name) - \(formatNumber(bestByMean.results.statistics.mean, decimals: 2))
        • Worst Scenario (by mean): \(worstByMean.name) - \(formatNumber(worstByMean.results.statistics.mean, decimals: 2))
        • Range: \(formatNumber(bestByMean.results.statistics.mean - worstByMean.results.statistics.mean, decimals: 2))

        Input Assumptions by Scenario:
        """

        for (scenarioIndex, config) in scenarioConfigs.enumerated() {
            output += "\n\n\(scenarioIndex + 1). \(config.name):"
            for (inputIndex, inputName) in inputNames.enumerated() {
                output += "\n   • \(inputName): \(formatNumber(config.values[inputIndex], decimals: 2))"
            }
        }

        output += """


        Interpretation:
        • Each scenario uses fixed assumptions for inputs
        • Compare outcomes to understand impact of different assumptions
        • Best/worst cases show potential range of outcomes
        • Use scenario planning for strategic decision-making

        Next Steps:
        • Identify which scenarios are most likely
        • Develop contingency plans for worst-case scenarios
        • Understand key drivers that distinguish scenarios
        """

        return .success(text: output)
    }
}
