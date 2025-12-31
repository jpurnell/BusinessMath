//
//  ScenarioAnalysis.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Scenario Analysis Framework
///
/// A declarative DSL for what-if analysis, sensitivity testing, and Monte Carlo simulation
/// in financial and business modeling. Build complex scenario analyses using an intuitive
/// result builder syntax.
///
/// ## Core Features
///
/// - **Named Scenarios**: Compare distinct business cases side-by-side
/// - **Parameter Variation**: Systematically test ranges of input values
/// - **Sensitivity Analysis**: Measure impact of parameter changes on outcomes
/// - **Tornado Charts**: Identify which parameters have greatest impact
/// - **Monte Carlo Simulation**: Model uncertainty with probability distributions
/// - **Statistical Analysis**: Compute mean, median, percentiles, and more
///
/// ## Basic Usage
///
/// ### Simple Scenario Comparison
/// ```swift
/// let analysis = ScenarioAnalysis {
///     Scenario("Conservative") {
///         Parameter("revenue", value: 800_000)
///         Parameter("growth", value: 0.05)
///     }
///     Scenario("Aggressive") {
///         Parameter("revenue", value: 1_500_000)
///         Parameter("growth", value: 0.25)
///     }
/// }
///
/// // Evaluate with custom function
/// let results = analysis.evaluate { scenario in
///     let revenue = scenario.parameters["revenue"]!
///     let growth = scenario.parameters["growth"]!
///     return revenue * (1 + growth)
/// }
/// // results["Conservative"] → 840,000
/// // results["Aggressive"] → 1,875,000
/// ```
///
/// ### Parameter Sensitivity Analysis
/// ```swift
/// let analysis = ScenarioAnalysis {
///     BaseScenario {
///         Parameter("revenue", value: 1_000_000)
///         Parameter("expenses", value: 0.60)
///     }
///     Vary("growth", from: 0.05, to: 0.25, steps: 5)
/// }
/// // Creates 5 scenarios with growth: [5%, 10%, 15%, 20%, 25%]
///
/// let stats = analysis.statistics { scenario in
///     let revenue = scenario.parameters["revenue"]!
///     let growth = scenario.parameters["growth"]!
///     return revenue * growth  // Simple metric
/// }
/// print("Mean: \(stats.mean), Median: \(stats.median)")
/// ```
///
/// ### Multi-Parameter Variations
/// ```swift
/// let analysis = ScenarioAnalysis {
///     BaseScenario {
///         Parameter("price", value: 100)
///     }
///     Vary("volume", from: 1000, to: 2000, steps: 3)
///     Vary("discount", values: [0.0, 0.10, 0.20])
/// }
/// // Creates 3 × 3 = 9 scenarios (Cartesian product)
/// ```
///
/// ### Tornado Chart Analysis
/// ```swift
/// let analysis = ScenarioAnalysis {
///     BaseScenario {
///         Parameter("revenue", value: 1_000_000)
///         Parameter("expenses", value: 600_000)
///         Parameter("growth", value: 0.15)
///     }
///     TornadoChart {
///         Vary("revenue", by: 0.20)    // ±20%
///         Vary("expenses", by: 0.10)   // ±10%
///         Vary("growth", by: 0.05)     // ±5 percentage points
///     }
/// }
/// // Creates low/base/high scenarios for each parameter
/// // Use to identify which parameters have greatest impact
/// ```
///
/// ### Monte Carlo Simulation
/// ```swift
/// let analysis = ScenarioAnalysis {
///     BaseScenario {
///         Parameter("revenue", value: 1_000_000)
///     }
///     MonteCarlo(trials: 10_000) {
///         RandomParameter("growth", distribution: .normal(mean: 0.15, stdDev: 0.05))
///         RandomParameter("expenses", distribution: .uniform(min: 0.50, max: 0.70))
///     }
/// }
///
/// // Compute percentiles for risk analysis
/// let p10 = analysis.percentile(10, for: evaluateFunction)
/// let p50 = analysis.percentile(50, for: evaluateFunction)  // Median
/// let p90 = analysis.percentile(90, for: evaluateFunction)
/// ```
///
/// ## Advanced: Integration with Cash Flow Models
///
/// ```swift
/// let scenarios = ScenarioAnalysis {
///     Scenario("Base Case") {
///         Parameter("baseRevenue", value: 1_000_000)
///         Parameter("growthRate", value: 0.15)
///         Parameter("expenseRate", value: 0.60)
///     }
/// }
///
/// // Use scenario parameters to build cash flow model
/// let netIncome = scenarios.evaluate { scenario in
///     let projection = CashFlowModel(
///         revenue: Revenue {
///             Base(scenario.parameters["baseRevenue"]!)
///             GrowthRate(scenario.parameters["growthRate"]!)
///         },
///         expenses: Expenses {
///             Variable(percentage: scenario.parameters["expenseRate"]!)
///         },
///         taxes: Taxes {
///             CorporateRate(0.21)
///         }
///     )
///     return projection.calculate(year: 1).netIncome
/// }
/// ```

// MARK: - Scenario Analysis

/// Container for multiple scenarios for comparison and sensitivity analysis
public struct ScenarioAnalysis {
    public let scenarios: [Scenario]

    internal init(scenarios: [Scenario]) {
        self.scenarios = scenarios
    }

    /// Create scenario analysis using result builder
    public init(@ScenarioAnalysisBuilder content: () -> ScenarioAnalysis) {
        self = content()
    }

    // MARK: - Evaluation

    /// Evaluate all scenarios with a given function
    /// - Parameter evaluate: Function that takes a scenario and returns a result
    /// - Returns: Dictionary mapping scenario names to results
    public func evaluate(with evaluate: @escaping (Scenario) -> Double) -> [String: Double] {
        var results: [String: Double] = [:]
        for scenario in scenarios {
            results[scenario.name] = evaluate(scenario)
        }
        return results
    }

    /// Find the best scenario by evaluation function
    /// - Parameter evaluate: Function that determines scenario quality (higher is better)
    /// - Returns: The best scenario, or nil if no scenarios
    public func best(by evaluate: @escaping (Scenario) -> Double) -> Scenario? {
        scenarios.max { evaluate($0) < evaluate($1) }
    }

    /// Find the worst scenario by evaluation function
    /// - Parameter evaluate: Function that determines scenario quality (higher is better)
    /// - Returns: The worst scenario, or nil if no scenarios
    public func worst(by evaluate: @escaping (Scenario) -> Double) -> Scenario? {
        scenarios.min { evaluate($0) < evaluate($1) }
    }

    // MARK: - Statistics

    /// Calculate statistics for scenario outcomes
    public struct Statistics {
        public let mean: Double
        public let median: Double
        public let stdDev: Double
        public let min: Double
        public let max: Double
        public let count: Int
    }

    /// Calculate statistics across all scenarios
    /// - Parameter evaluate: Function to evaluate each scenario
    /// - Returns: Statistical summary of results
    public func statistics(for evaluate: @escaping (Scenario) -> Double) -> Statistics {
        let values = scenarios.map(evaluate).sorted()

        guard !values.isEmpty else {
            return Statistics(mean: 0, median: 0, stdDev: 0, min: 0, max: 0, count: 0)
        }

        let count = values.count
        let sum = values.reduce(0, +)
        let mean = sum / Double(count)

        let median: Double
        if count % 2 == 0 {
            median = (values[count/2 - 1] + values[count/2]) / 2
        } else {
            median = values[count/2]
        }

        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(count)
        let stdDev = sqrt(variance)

        return Statistics(
            mean: mean,
            median: median,
            stdDev: stdDev,
            min: values.first!,
            max: values.last!,
            count: count
        )
    }

    /// Calculate percentile value
    /// - Parameters:
    ///   - percentile: Percentile to calculate (0-100)
    ///   - evaluate: Function to evaluate each scenario
    /// - Returns: Value at the specified percentile
    public func percentile(_ percentile: Int, for evaluate: @escaping (Scenario) -> Double) -> Double {
        let values = scenarios.map(evaluate).sorted()
        guard !values.isEmpty else { return 0 }

        let index = Int(Double(values.count - 1) * Double(percentile) / 100.0)
        return values[index]
    }
}

// MARK: - Scenario Analysis Result Builder

@resultBuilder
public struct ScenarioAnalysisBuilder {
    public static func buildBlock(_ components: ScenarioAnalysisComponent...) -> ScenarioAnalysis {
        var scenarios: [Scenario] = []
        var baseScenario: [String: Double]? = nil

        // Process components
        for component in components {
            switch component {
            case .scenario(let scenario):
                scenarios.append(scenario)

            case .baseScenario(let base):
                baseScenario = base.parameters

            case .vary(let vary):
                // Apply variation to base scenario
                guard let base = baseScenario else {
                    fatalError("Vary requires a BaseScenario")
                }

                // If no existing scenarios, create them from this variation
                if scenarios.isEmpty {
                    for value in vary.values {
                        var params = base
                        params[vary.parameterName] = value
                        scenarios.append(Scenario(
                            name: "\(vary.parameterName)=\(value)",
                            parameters: params
                        ))
                    }
                } else {
                    // Apply variation to existing scenarios (cartesian product)
                    var newScenarios: [Scenario] = []
                    for scenario in scenarios {
                        for value in vary.values {
                            var params = scenario.parameters
                            params[vary.parameterName] = value
                            newScenarios.append(Scenario(
                                name: "\(scenario.name),\(vary.parameterName)=\(value)",
                                parameters: params
                            ))
                        }
                    }
                    scenarios = newScenarios
                }

            case .sensitivity(let sensitivity):
                guard let base = baseScenario else {
                    fatalError("Sensitivity requires a BaseScenario")
                }

                let baseValue = base[sensitivity.parameterName] ?? 0
                let stepSize = (sensitivity.range.upperBound - sensitivity.range.lowerBound) / Double(sensitivity.steps - 1)

                for i in 0..<sensitivity.steps {
                    let multiplier = sensitivity.range.lowerBound + Double(i) * stepSize
                    var params = base
                    params[sensitivity.parameterName] = baseValue * multiplier

                    scenarios.append(Scenario(
                        name: "\(sensitivity.parameterName) @ \(Int(multiplier * 100))%",
                        parameters: params
                    ))
                }

            case .tornadoChart(let tornado):
                guard let base = baseScenario else {
                    fatalError("TornadoChart requires a BaseScenario")
                }

                for vary in tornado.variations {
                    let baseValue = base[vary.parameterName] ?? 0

                    for (index, multiplier) in vary.values.enumerated() {
                        var params = base
                        params[vary.parameterName] = baseValue * multiplier

                        let label = index == 0 ? "low" : (index == 1 ? "base" : "high")
                        scenarios.append(Scenario(
                            name: "\(vary.parameterName) (\(label))",
                            parameters: params
                        ))
                    }
                }

            case .monteCarlo(let monteCarlo):
                guard let base = baseScenario else {
                    fatalError("MonteCarlo requires a BaseScenario")
                }

                for trial in 0..<monteCarlo.trials {
                    var params = base

                    for randomParam in monteCarlo.randomParameters {
                        params[randomParam.name] = randomParam.distribution.sample()
                    }

                    scenarios.append(Scenario(
                        name: "Trial \(trial + 1)",
                        parameters: params
                    ))
                }
            }
        }

        return ScenarioAnalysis(scenarios: scenarios)
    }

    public static func buildExpression(_ expression: Scenario) -> ScenarioAnalysisComponent {
        .scenario(expression)
    }

    public static func buildExpression(_ expression: BaseScenario) -> ScenarioAnalysisComponent {
        .baseScenario(expression)
    }

    public static func buildExpression(_ expression: Vary) -> ScenarioAnalysisComponent {
        .vary(expression)
    }

    public static func buildExpression(_ expression: Sensitivity) -> ScenarioAnalysisComponent {
        .sensitivity(expression)
    }

    public static func buildExpression(_ expression: TornadoChart) -> ScenarioAnalysisComponent {
        .tornadoChart(expression)
    }

    public static func buildExpression(_ expression: MonteCarlo) -> ScenarioAnalysisComponent {
        .monteCarlo(expression)
    }
}

// MARK: - Scenario Analysis Component

public enum ScenarioAnalysisComponent {
    case scenario(Scenario)
    case baseScenario(BaseScenario)
    case vary(Vary)
    case sensitivity(Sensitivity)
    case tornadoChart(TornadoChart)
    case monteCarlo(MonteCarlo)
}
