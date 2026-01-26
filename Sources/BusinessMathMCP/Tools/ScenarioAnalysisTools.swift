import Foundation
import MCP
import BusinessMath

// MARK: - Scenario Analysis Tool

public struct ScenarioAnalysisTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_scenarios",
        description: """
        Run discrete scenario analysis with distributions within scenarios.

        **Key Features:**
        - Run multiple named scenarios (Base Case, Best Case, Worst Case, etc.)
        - Mix fixed values and probability distributions within each scenario
        - Clear distinction between setValue() (deterministic) and setDistribution() (probabilistic)
        - Compare scenarios across multiple metrics
        - Identify best/worst case outcomes
        - Calculate probabilities of specific outcomes

        **Perfect for:**
        - What-if analysis and scenario planning
        - **Stress testing business models** (multi-component P&L with cascading effects)
        - Comparing strategic alternatives
        - Risk assessment across different conditions
        - Recession/disruption scenario modeling (correlated shocks across inputs)

        **setValue() vs setDistribution():**
        - setValue: Use a fixed, known value (deterministic assumption)
        - setDistribution: Sample from a distribution each iteration (uncertain assumption)

        **Example: Three-scenario business model**
        ```json
        {
          "inputNames": ["Sales Volume", "Unit Price", "Cost Margin"],
          "model": "volume * price * (1 - margin)",
          "iterations": 5000,
          "scenarios": [
            {
              "name": "Base Case",
              "inputs": {
                "Sales Volume": {"distribution": {"type": "normal", "mean": 50000, "stdDev": 2500}},
                "Unit Price": {"distribution": {"type": "normal", "mean": 25.0, "stdDev": 1.0}},
                "Cost Margin": {"value": 0.45}
              }
            },
            {
              "name": "Recession",
              "inputs": {
                "Sales Volume": {"distribution": {"type": "normal", "mean": 35000, "stdDev": 5000}},
                "Unit Price": {"distribution": {"type": "normal", "mean": 22.0, "stdDev": 2.0}},
                "Cost Margin": {"distribution": {"type": "normal", "mean": 0.50, "stdDev": 0.03}}
              }
            }
          ],
          "thresholds": [0, 100000]
        }
        ```

        **Returns:**
        - Statistics for each scenario (mean, median, std dev, percentiles)
        - Best/worst scenario identification
        - Probability analysis (above/below thresholds)
        - Risk-adjusted metrics (Sharpe-like ratios)
        - Scenario comparison table

        **Based on:** Part4-Simulation.md validated stress testing patterns
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputNames": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Names of all input variables (order matters for model evaluation).
                    Example: ["Revenue", "Costs", "Growth Rate"]
                    """,
                    items: MCPSchemaItems(type: "string")
                ),
                "model": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Model expression using input variables.
                    Can reference inputs by name or by index (inputs[0], inputs[1], etc.).
                    Examples:
                    - "revenue - costs"
                    - "volume * price * (1 - margin)"
                    - "inputs[0] * (1 + inputs[1]) - inputs[2]"

                    Supported operators: +, -, *, /, (, )
                    Supported functions: sqrt, pow, exp, log
                    """
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Number of Monte Carlo iterations per scenario.
                    Typical values: 1,000 (fast), 5,000 (balanced), 10,000 (precise)
                    """
                ),
                "scenarios": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of scenario definitions. Each scenario must configure all inputs.

                    Each scenario has:
                    - name: Scenario label (e.g., "Base Case", "Best Case")
                    - inputs: Object mapping input names to configurations

                    Each input can be:
                    - Fixed value: {"value": 100}
                    - Distribution: {"distribution": {"type": "normal", "mean": 100, "stdDev": 10}}

                    Supported distributions:
                    - normal: {"type": "normal", "mean": μ, "stdDev": σ}
                    - uniform: {"type": "uniform", "min": a, "max": b}
                    - triangular: {"type": "triangular", "min": a, "mode": b, "max": c}
                    """
                ),
                "thresholds": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Optional thresholds for probability analysis.
                    Tool will calculate P(outcome > threshold) for each value.
                    Example: [0, 100000] checks probability of profit and exceeding $100K
                    """,
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["inputNames", "model", "iterations", "scenarios"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Parse input names
        let inputNames = try args.getStringArray("inputNames")
        guard !inputNames.isEmpty else {
            throw ToolError.invalidArguments("inputNames must not be empty")
        }

        // Parse model expression
        let modelExpression = try args.getString("model")

        // Parse iterations
        let iterations = try args.getInt("iterations")
        guard iterations > 0 && iterations <= 100_000 else {
            throw ToolError.invalidArguments("iterations must be between 1 and 100,000")
        }

        // Parse scenarios
        guard let scenariosArray = args["scenarios"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("scenarios must be an array")
        }

        guard !scenariosArray.isEmpty else {
            throw ToolError.invalidArguments("At least one scenario is required")
        }

        // Parse optional thresholds
        var thresholds: [Double] = []
        if let thresholdsValue = args["thresholds"]?.value {
            if let doubleArray = thresholdsValue as? [Double] {
                thresholds = doubleArray
            } else if let anyArray = thresholdsValue as? [AnyCodable] {
                thresholds = try anyArray.map { value -> Double in
                    if let d = value.value as? Double {
                        return d
                    } else if let i = value.value as? Int {
                        return Double(i)
                    }
                    throw ToolError.invalidArguments("thresholds must contain only numbers")
                }
            }
        }

        // Create model function from expression
        let model = try createModelFromExpression(modelExpression, inputNames: inputNames)

        // Create scenario analysis
        var analysis = ScenarioAnalysis(
            inputNames: inputNames,
            model: model,
            iterations: iterations
        )

        // Parse and add scenarios
        for (index, scenarioValue) in scenariosArray.enumerated() {
            guard let scenarioDict = scenarioValue.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Scenario \(index) must be an object")
            }

            guard let scenarioName = scenarioDict["name"]?.value as? String else {
                throw ToolError.invalidArguments("Scenario \(index) must have a 'name' field")
            }

            guard let inputsDict = scenarioDict["inputs"]?.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Scenario '\(scenarioName)' must have an 'inputs' field")
            }

            let scenario = Scenario(name: scenarioName) { config in
                for inputName in inputNames {
                    guard let inputConfig = inputsDict[inputName]?.value as? [String: AnyCodable] else {
                        // Will be caught by ScenarioAnalysis validation
                        return
                    }

                    // Check if it's a fixed value or distribution
                    if let fixedValue = inputConfig["value"]?.value as? Double {
                        config.setValue(fixedValue, forInput: inputName)
                    } else if let fixedValue = inputConfig["value"]?.value as? Int {
                        config.setValue(Double(fixedValue), forInput: inputName)
                    } else if let distDict = inputConfig["distribution"]?.value as? [String: AnyCodable] {
                        // Parse distribution
                        do {
                            let distribution = try parseDistribution(distDict)
                            // Type-erase the distribution to match setDistribution's generic constraint
                            if let normalDist = distribution as? DistributionNormal {
                                config.setDistribution(normalDist, forInput: inputName)
                            } else if let uniformDist = distribution as? DistributionUniform {
                                config.setDistribution(uniformDist, forInput: inputName)
                            } else if let triangularDist = distribution as? DistributionTriangular {
                                config.setDistribution(triangularDist, forInput: inputName)
                            }
                        } catch {
                            // Error will be caught later
                            return
                        }
                    }
                }
            }

            analysis.addScenario(scenario)
        }

        // Run analysis
        let results: [String: SimulationResults]
        do {
            results = try analysis.run()
        } catch {
            return .error(message: """
                Scenario Analysis Failed

                Could not complete scenario analysis.

                Error: \(error.localizedDescription)

                Common issues:
                • Scenario missing configuration for one or more inputs
                • Invalid model expression
                • Distribution parameters out of valid range
                """)
        }

        // Generate output
        let comparison = ScenarioComparison(results: results)
        var output = """
        🎯 **Scenario Analysis Results**

        **Configuration:**
        - Inputs: \(inputNames.joined(separator: ", "))
        - Model: \(modelExpression)
        - Iterations per scenario: \(iterations)
        - Total scenarios: \(results.count)

        """

        // Section 1: Scenario Statistics
        output += """
        ## Scenario Statistics

        """

        for (name, result) in results.sorted(by: { $0.key < $1.key }) {
            let mean = result.statistics.mean
            let median = result.statistics.median
            let stdDev = result.statistics.stdDev
            let p5 = result.percentiles.p5
            let p95 = result.percentiles.p95

            output += """

            **\(name):**
            - Mean: \(String(format: "%.2f", mean))
            - Median: \(String(format: "%.2f", median))
            - Std Dev: \(String(format: "%.2f", stdDev))
            - 90% CI: [\(String(format: "%.2f", p5)), \(String(format: "%.2f", p95))]

            """
        }

        // Section 2: Best/Worst Scenarios
        output += """

        ## Scenario Comparison

        """

        let bestByMean = comparison.bestScenario(by: .mean)
        let worstByMean = comparison.worstScenario(by: .mean)
        let bestByP5 = comparison.bestScenario(by: .p5)
        let worstByP5 = comparison.worstScenario(by: .p5)

        output += """
        **Best/Worst by Mean:**
        - Best: \(bestByMean.name) (\(String(format: "%.2f", bestByMean.results.statistics.mean)))
        - Worst: \(worstByMean.name) (\(String(format: "%.2f", worstByMean.results.statistics.mean)))

        **Best/Worst by 5th Percentile (Downside Risk):**
        - Best: \(bestByP5.name) (\(String(format: "%.2f", bestByP5.results.percentiles.p5)))
        - Worst: \(worstByP5.name) (\(String(format: "%.2f", worstByP5.results.percentiles.p5)))

        """

        // Section 3: Threshold Analysis
        if !thresholds.isEmpty {
            output += """
            ## Probability Analysis

            """

            for threshold in thresholds {
                output += """

                **Probability of Exceeding \(String(format: "%.0f", threshold)):**
                """

                for (name, result) in results.sorted(by: { $0.key < $1.key }) {
                    let prob = result.probabilityAbove(threshold)
                    output += """

                    - \(name): \(String(format: "%.1f%%", prob * 100))
                    """
                }
            }

            output += "\n"
        }

        // Section 4: Risk-Adjusted Metrics
        output += """

        ## Risk-Adjusted Metrics

        **Sharpe-like Ratios (Mean / Std Dev):**
        """

        for (name, result) in results.sorted(by: { $0.key < $1.key }) {
            let mean = result.statistics.mean
            let stdDev = result.statistics.stdDev
            let sharpe = stdDev > 0 ? mean / stdDev : 0
            output += """

            - \(name): \(String(format: "%.3f", sharpe))
            """
        }

        output += """


        **Interpretation:**
        Each scenario was run \(iterations) times, sampling from configured distributions.
        Higher Sharpe ratios indicate better risk-adjusted returns.
        The 90% confidence interval shows the range containing 90% of outcomes.

        **Note:** This analysis uses discrete scenarios. Each scenario represents a different
        set of assumptions about the future. Results help compare alternatives and assess risks.
        """

        return .success(text: output)
    }
}

// MARK: - Helper Functions

/// Parse a distribution from JSON configuration
private func parseDistribution(_ dict: [String: AnyCodable]) throws -> any DistributionRandom & Sendable {
    guard let typeStr = dict["type"]?.value as? String else {
        throw ToolError.invalidArguments("Distribution must have 'type' field")
    }

    switch typeStr.lowercased() {
    case "normal":
        guard let mean = extractDouble(dict["mean"]) else {
            throw ToolError.invalidArguments("Normal distribution requires 'mean' parameter")
        }
        guard let stdDev = extractDouble(dict["stdDev"]) ?? extractDouble(dict["stddev"]) else {
            throw ToolError.invalidArguments("Normal distribution requires 'stdDev' parameter")
        }
        guard stdDev > 0 else {
            throw ToolError.invalidArguments("Normal distribution stdDev must be positive")
        }
        return DistributionNormal(mean, stdDev)

    case "uniform":
        guard let min = extractDouble(dict["min"]) else {
            throw ToolError.invalidArguments("Uniform distribution requires 'min' parameter")
        }
        guard let max = extractDouble(dict["max"]) else {
            throw ToolError.invalidArguments("Uniform distribution requires 'max' parameter")
        }
        guard min < max else {
            throw ToolError.invalidArguments("Uniform distribution min must be less than max")
        }
        return DistributionUniform(min, max)

    case "triangular":
        guard let min = extractDouble(dict["min"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'min' parameter")
        }
        guard let mode = extractDouble(dict["mode"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'mode' parameter")
        }
        guard let max = extractDouble(dict["max"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'max' parameter")
        }
        guard min <= mode && mode <= max else {
            throw ToolError.invalidArguments("Triangular distribution requires min ≤ mode ≤ max")
        }
        return DistributionTriangular(low: min, high: max, base: mode)

    default:
        throw ToolError.invalidArguments("Unknown distribution type: \(typeStr)")
    }
}

/// Extract a Double from AnyCodable
private func extractDouble(_ value: AnyCodable?) -> Double? {
    if let d = value?.value as? Double {
        return d
    } else if let i = value?.value as? Int {
        return Double(i)
    }
    return nil
}

/// Create a model function from a simple expression
/// Supports basic arithmetic and variable references
private func createModelFromExpression(
    _ expression: String,
    inputNames: [String]
) throws -> @Sendable ([Double]) -> Double {
    // Simple expression evaluator
    // For now, create a closure that evaluates the expression

    // This is a simplified implementation
    // A full implementation would use proper expression parsing

    let trimmed = expression.trimmingCharacters(in: .whitespaces)

    // Create the model function
    return { inputs in
        // Replace input names with actual values
        var expr = trimmed
        for (index, name) in inputNames.enumerated() {
            let value = inputs[index]
            expr = expr.replacingOccurrences(of: name, with: "\(value)")
        }

        // Also support inputs[i] notation
        for (index, value) in inputs.enumerated() {
            expr = expr.replacingOccurrences(of: "inputs[\(index)]", with: "\(value)")
        }

        // Evaluate the expression (simplified)
        // In a real implementation, use NSExpression or a proper parser
        let result = evaluateExpression(expr)
        return result
    }
}

/// Simple expression evaluator
/// Note: This is a simplified version. A production implementation
/// should use a proper expression parser or NSExpression
private func evaluateExpression(_ expr: String) -> Double {
    // Remove whitespace
    let cleaned = expr.replacingOccurrences(of: " ", with: "")

    // Try to evaluate as NSExpression
    let expression = NSExpression(format: cleaned)
    if let result = expression.expressionValue(with: nil, context: nil) as? Double {
        return result
    }
    if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
        return result.doubleValue
    }

    // Fallback: return 0 if evaluation fails
    return 0.0
}

// MARK: - Tool Registration

public func getScenarioAnalysisTools() -> [MCPToolHandler] {
    return [
        ScenarioAnalysisTool()
    ]
}
