//
//  Scenario.swift
//  BusinessMathDSL
//
//  Created by Justin Purnell on 2025-12-29.
//

import Foundation
import Numerics

/// # Scenario Analysis Components
///
/// Building blocks for what-if analysis and sensitivity testing with support for:
/// - Named scenarios with custom parameters
/// - Parameter variations across ranges
/// - Sensitivity analysis with percentage ranges
/// - Tornado chart data generation
/// - Monte Carlo simulation with probability distributions
///
/// ## Usage Examples
///
/// ### Simple Scenario with Parameters
/// ```swift
/// let scenario = Scenario("Base Case") {
///     Parameter("revenue", value: 1_000_000)
///     Parameter("growth", value: 0.15)
///     Parameter("expenses", value: 0.60)
/// }
/// // Access: scenario.parameters["revenue"] → 1,000,000
/// ```
///
/// ### Parameter Variation with Range
/// ```swift
/// Vary("growth", from: 0.05, to: 0.25, steps: 5)
/// // Generates: [0.05, 0.10, 0.15, 0.20, 0.25]
/// ```
///
/// ### Parameter Variation with Specific Values
/// ```swift
/// Vary("taxRate", values: [0.15, 0.21, 0.25, 0.30])
/// // Uses exact values provided
/// ```
///
/// ### Sensitivity Analysis (Percentage of Base)
/// ```swift
/// BaseScenario {
///     Parameter("revenue", value: 1_000_000)
/// }
/// Sensitivity(on: "revenue", range: 0.80...1.20, steps: 5)
/// // Varies revenue from 80% to 120% of base: [800k, 900k, 1M, 1.1M, 1.2M]
/// ```
///
/// ### Tornado Chart for Multiple Parameters
/// ```swift
/// TornadoChart {
///     Vary("revenue", by: 0.20)     // ±20%: [0.8x, 1.0x, 1.2x]
///     Vary("expenses", by: 0.10)    // ±10%: [0.9x, 1.0x, 1.1x]
///     Vary("growth", by: 0.05)      // ±5%:  [0.95x, 1.0x, 1.05x]
/// }
/// ```
///
/// ### Monte Carlo Simulation
/// ```swift
/// MonteCarlo(trials: 1000) {
///     RandomParameter("growth", distribution: .normal(mean: 0.15, stdDev: 0.05))
///     RandomParameter("expenses", distribution: .uniform(min: 0.50, max: 0.70))
///     RandomParameter("tax", distribution: .triangular(min: 0.15, mode: 0.21, max: 0.30))
/// }
/// // Generates 1000 random scenarios with specified distributions
/// ```

// MARK: - Parameter

/// A named parameter with a value for scenario analysis.
public struct Parameter {
    /// The parameter name used as a key in scenario lookups.
    public let name: String
    /// The parameter value.
    public let value: Double

    /// Creates a named parameter with the specified value.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - value: The parameter value.
    public init(_ name: String, value: Double) {
        self.name = name
        self.value = value
    }
}

// MARK: - Scenario

/// A scenario with named parameters for what-if analysis.
public struct Scenario {
    /// The scenario name (e.g., "Base Case", "Optimistic").
    public let name: String
    /// Dictionary of parameter names to values.
    public let parameters: [String: Double]

    /// Creates a scenario with explicit parameters dictionary.
    ///
    /// - Parameters:
    ///   - name: The scenario name.
    ///   - parameters: Dictionary mapping parameter names to values.
    public init(name: String, parameters: [String: Double]) {
        self.name = name
        self.parameters = parameters
    }

    /// Create scenario using result builder
    public init(_ name: String, @ScenarioBuilder content: () -> Scenario) {
        let scenario = content()
        self.name = name
        self.parameters = scenario.parameters
    }
}

// MARK: - Scenario Result Builder

/// Result builder for constructing `Scenario` instances declaratively.
///
/// Allows composing parameters using Swift's result builder syntax.
@resultBuilder
public struct ScenarioBuilder {
    /// Builds a scenario from the provided parameter components.
    ///
    /// - Parameter components: The parameters to include in the scenario.
    /// - Returns: A scenario containing all parameters.
    public static func buildBlock(_ components: Parameter...) -> Scenario {
        var parameters: [String: Double] = [:]
        for param in components {
            parameters[param.name] = param.value
        }
        return Scenario(name: "", parameters: parameters)
    }

    /// Passes a parameter expression through to the builder.
    public static func buildExpression(_ expression: Parameter) -> Parameter {
        expression
    }
}

// MARK: - BaseScenario

/// Base scenario that other variations build upon
public struct BaseScenario {
    public let parameters: [String: Double]

    internal init(parameters: [String: Double] = [:]) {
        self.parameters = parameters
    }

    /// Creates a base scenario using the result builder DSL.
    ///
    /// - Parameter content: A closure that builds the scenario parameters.
    public init(@ScenarioBuilder content: () -> Scenario) {
        let scenario = content()
        self.parameters = scenario.parameters
    }
}

// MARK: - Vary Component

/// Varies a parameter across a range or specific values
///
/// `Vary` creates multiple scenarios by systematically changing one parameter while keeping
/// others constant. Supports three modes:
/// 1. **Range variation**: Evenly spaced steps between min and max
/// 2. **Specific values**: Exact values to test
/// 3. **Percentage variation**: Multipliers for tornado charts (±X%)
///
/// ## Examples
/// ```swift
/// // Range: 5 evenly-spaced values from 5% to 25%
/// Vary("growth", from: 0.05, to: 0.25, steps: 5)
/// // → [0.05, 0.10, 0.15, 0.20, 0.25]
///
/// // Specific values: test exact tax rates
/// Vary("taxRate", values: [0.15, 0.21, 0.25, 0.30])
/// // → [0.15, 0.21, 0.25, 0.30]
///
/// // Percentage: ±20% for tornado analysis
/// Vary("revenue", by: 0.20)
/// // → [0.8, 1.0, 1.2] (applied as multipliers to base value)
/// ```
public struct Vary {
    public let parameterName: String
    public let values: [Double]

    /// Vary parameter from min to max in specified steps
    public init(_ name: String, from min: Double, to max: Double, steps: Int) {
        self.parameterName = name

        guard steps > 0 else {
            self.values = [min]
            return
        }

        if steps == 1 {
            self.values = [min]
        } else {
            let stepSize = (max - min) / Double(steps - 1)
            self.values = (0..<steps).map { min + Double($0) * stepSize }
        }
    }

    /// Vary parameter across specific values
    public init(_ name: String, values: [Double]) {
        self.parameterName = name
        self.values = values
    }

    /// Vary parameter by percentage (for tornado charts)
    public init(_ name: String, by percentage: Double) {
        self.parameterName = name
        // Will be resolved later with base value
        self.values = [1.0 - percentage, 1.0, 1.0 + percentage]
    }
}

// MARK: - Sensitivity Component

/// Sensitivity analysis on a single parameter.
public struct Sensitivity {
    /// The name of the parameter to vary.
    public let parameterName: String
    /// The range of multipliers to apply (e.g., 0.8...1.2 for ±20%).
    public let range: ClosedRange<Double>
    /// The number of steps to generate within the range.
    public let steps: Int

    /// Creates a sensitivity analysis configuration.
    ///
    /// - Parameters:
    ///   - parameter: The name of the parameter to vary.
    ///   - range: The range of multipliers to apply to the base value.
    ///   - steps: The number of evenly-spaced steps within the range.
    public init(on parameter: String, range: ClosedRange<Double>, steps: Int) {
        self.parameterName = parameter
        self.range = range
        self.steps = steps
    }
}

// MARK: - TornadoChart Component

/// Tornado chart sensitivity analysis.
public struct TornadoChart {
    /// The parameter variations to analyze.
    public let variations: [Vary]

    /// Creates a tornado chart configuration using the result builder DSL.
    ///
    /// - Parameter content: A closure that builds the parameter variations.
    public init(@TornadoChartBuilder content: () -> [Vary]) {
        self.variations = content()
    }
}

/// Result builder for constructing tornado chart variations.
@resultBuilder
public struct TornadoChartBuilder {
    /// Collects the `Vary` components into an array.
    public static func buildBlock(_ components: Vary...) -> [Vary] {
        Array(components)
    }

    /// Passes a `Vary` expression through to the builder.
    public static func buildExpression(_ expression: Vary) -> Vary {
        expression
    }
}

// MARK: - MonteCarlo Component

/// Monte Carlo random scenario generation.
public struct MonteCarlo {
    /// The number of simulation trials to run.
    public let trials: Int
    /// The random parameters with their probability distributions.
    public let randomParameters: [RandomParameter]

    /// Creates a Monte Carlo simulation configuration.
    ///
    /// - Parameters:
    ///   - trials: The number of random scenarios to generate.
    ///   - content: A closure that builds the random parameter definitions.
    public init(trials: Int, @MonteCarloBuilder content: () -> [RandomParameter]) {
        self.trials = trials
        self.randomParameters = content()
    }
}

/// Result builder for constructing Monte Carlo parameter definitions.
@resultBuilder
public struct MonteCarloBuilder {
    /// Collects the `RandomParameter` components into an array.
    public static func buildBlock(_ components: RandomParameter...) -> [RandomParameter] {
        Array(components)
    }

    /// Passes a `RandomParameter` expression through to the builder.
    public static func buildExpression(_ expression: RandomParameter) -> RandomParameter {
        expression
    }
}

// MARK: - RandomParameter

/// Random parameter with a probability distribution for Monte Carlo simulation.
public struct RandomParameter {
    /// The parameter name.
    public let name: String
    /// The probability distribution to sample from.
    public let distribution: Distribution

    /// Creates a random parameter with the specified distribution.
    ///
    /// - Parameters:
    ///   - name: The parameter name.
    ///   - distribution: The probability distribution for sampling values.
    public init(_ name: String, distribution: Distribution) {
        self.name = name
        self.distribution = distribution
    }
}

/// Probability distributions for random parameters in Monte Carlo simulations
///
/// Provides three common distributions for modeling uncertainty:
///
/// ## Normal Distribution
/// Bell curve centered on mean with specified standard deviation. Best for:
/// - Growth rates with historical volatility
/// - Market variables with symmetric uncertainty
/// - Parameters that cluster around a central tendency
///
/// ```swift
/// .normal(mean: 0.15, stdDev: 0.05)
/// // 68% of samples within ±0.05 of 0.15 (0.10 to 0.20)
/// // 95% of samples within ±0.10 of 0.15 (0.05 to 0.25)
/// ```
///
/// ## Uniform Distribution
/// Equal probability across entire range. Best for:
/// - Parameters with no preferred value in range
/// - Conservative worst-to-best case analysis
/// - Maximum entropy when you have min/max bounds
///
/// ```swift
/// .uniform(min: 0.50, max: 0.70)
/// // All values between 50% and 70% equally likely
/// ```
///
/// ## Triangular Distribution
/// Peak at mode with linear tails to min/max. Best for:
/// - Expert estimates with most likely value
/// - Bounded scenarios with asymmetric probability
/// - Three-point estimates (pessimistic, likely, optimistic)
///
/// ```swift
/// .triangular(min: 0.15, mode: 0.21, max: 0.30)
/// // Most likely: 21%, range: 15% to 30%
/// // Probability decreases linearly from mode to extremes
/// ```
public enum Distribution {
    case normal(mean: Double, stdDev: Double)
    case uniform(min: Double, max: Double)
    case triangular(min: Double, mode: Double, max: Double)

    /// Generate a random value from this distribution
    public func sample() -> Double {
        switch self {
        case .normal(let mean, let stdDev):
            // Box-Muller transform
            let u1 = Double.random(in: 0..<1)
            let u2 = Double.random(in: 0..<1)
            let z = sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
            return mean + stdDev * z

        case .uniform(let min, let max):
            return Double.random(in: min...max)

        case .triangular(let min, let mode, let max):
            let u = Double.random(in: 0..<1)
            let fc = (mode - min) / (max - min)
            if u < fc {
                return min + sqrt(u * (max - min) * (mode - min))
            } else {
                return max - sqrt((1 - u) * (max - min) * (max - mode))
            }
        }
    }
}
