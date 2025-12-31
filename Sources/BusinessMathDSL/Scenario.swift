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

/// A named parameter with a value for scenario analysis
public struct Parameter {
    public let name: String
    public let value: Double

    public init(_ name: String, value: Double) {
        self.name = name
        self.value = value
    }
}

// MARK: - Scenario

/// A scenario with named parameters for what-if analysis
public struct Scenario {
    public let name: String
    public let parameters: [String: Double]

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

@resultBuilder
public struct ScenarioBuilder {
    public static func buildBlock(_ components: Parameter...) -> Scenario {
        var parameters: [String: Double] = [:]
        for param in components {
            parameters[param.name] = param.value
        }
        return Scenario(name: "", parameters: parameters)
    }

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

/// Sensitivity analysis on a single parameter
public struct Sensitivity {
    public let parameterName: String
    public let range: ClosedRange<Double>
    public let steps: Int

    public init(on parameter: String, range: ClosedRange<Double>, steps: Int) {
        self.parameterName = parameter
        self.range = range
        self.steps = steps
    }
}

// MARK: - TornadoChart Component

/// Tornado chart sensitivity analysis
public struct TornadoChart {
    public let variations: [Vary]

    public init(@TornadoChartBuilder content: () -> [Vary]) {
        self.variations = content()
    }
}

@resultBuilder
public struct TornadoChartBuilder {
    public static func buildBlock(_ components: Vary...) -> [Vary] {
        Array(components)
    }

    public static func buildExpression(_ expression: Vary) -> Vary {
        expression
    }
}

// MARK: - MonteCarlo Component

/// Monte Carlo random scenario generation
public struct MonteCarlo {
    public let trials: Int
    public let randomParameters: [RandomParameter]

    public init(trials: Int, @MonteCarloBuilder content: () -> [RandomParameter]) {
        self.trials = trials
        self.randomParameters = content()
    }
}

@resultBuilder
public struct MonteCarloBuilder {
    public static func buildBlock(_ components: RandomParameter...) -> [RandomParameter] {
        Array(components)
    }

    public static func buildExpression(_ expression: RandomParameter) -> RandomParameter {
        expression
    }
}

// MARK: - RandomParameter

/// Random parameter with distribution
public struct RandomParameter {
    public let name: String
    public let distribution: Distribution

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
