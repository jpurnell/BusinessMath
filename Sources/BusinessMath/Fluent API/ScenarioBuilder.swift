//
//  ScenarioBuilder.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

// MARK: - Scenario Set

/// A collection of scenarios for sensitivity analysis.
///
/// Use the `ScenarioSetBuilder` to define multiple scenarios:
///
/// ```swift
/// let scenarios = ScenarioSet {
///     Baseline {
///         revenue(1_000_000)
///         growth(0.10)
///     }
///
///     Pessimistic {
///         revenue(800_000)
///         growth(0.05)
///     }
///
///     Optimistic {
///         revenue(1_200_000)
///         growth(0.15)
///     }
/// }
/// ```
public struct ScenarioSet: Sendable {
    /// All scenarios in this set
    public var scenarios: [ScenarioConfig]

    /// Initialize an empty scenario set
    public init() {
        self.scenarios = []
    }

    /// Initialize a scenario set using the builder DSL
    public init(@ScenarioSetBuilder builder: () -> [ScenarioConfig]) {
        self.scenarios = builder()
    }

    /// Get a scenario by name
    public func scenario(named name: String) -> ScenarioConfig? {
        scenarios.first { $0.name == name }
    }

    /// Apply a scenario to a baseline value
    public func apply(_ scenarioName: String, to baseValue: Double, for parameter: String) -> Double {
        guard let scenario = scenario(named: scenarioName) else {
            return baseValue
        }

        if let override = scenario.parameters[parameter] {
            return override
        }

        if let adjustment = scenario.adjustments[parameter] {
            return baseValue * (1 + adjustment)
        }

        return baseValue
    }
}

// MARK: - Scenario Configuration

/// Configuration for a single scenario.
public struct ScenarioConfig: Sendable {
    /// Name of the scenario
    public let name: String

    /// Direct parameter values (overrides)
    public var parameters: [String: Double] = [:]

    /// Percentage adjustments to parameters
    public var adjustments: [String: Double] = [:]

    /// Description of the scenario
    public var description: String?

    /// Probability of this scenario occurring (optional)
    public var probability: Double?

    /// Create a scenario configuration with a name and optional metadata.
    ///
    /// - Parameters:
    ///   - name: Name of the scenario (e.g., "Baseline", "Pessimistic")
    ///   - description: Optional detailed description
    ///   - probability: Optional probability (0.0 to 1.0) for weighted analysis
    ///
    /// ## Example
    /// ```swift
    /// let scenario = ScenarioConfig(
    ///     name: "Aggressive Growth",
    ///     description: "High market share capture with premium pricing",
    ///     probability: 0.25
    /// )
    /// ```
    ///
    /// ## See Also
    /// - ``Baseline(_:)`` for creating baseline scenarios via builder
    public init(name: String, description: String? = nil, probability: Double? = nil) {
        self.name = name
        self.description = description
        self.probability = probability
    }

    /// Access a parameter value by name.
    ///
    /// Example:
    /// ```swift
    /// let growthRate = scenario["Revenue Growth"] ?? 0.10
    /// ```
    public subscript(parameterName: String) -> Double? {
        parameters[parameterName]
    }
}

// MARK: - Result Builders

/// Result builder for creating a set of scenarios.
///
/// Enables declarative construction of multiple scenarios for sensitivity analysis.
///
/// ## Example
/// ```swift
/// let scenarios = ScenarioSet {
///     Baseline {
///         revenue(1_000_000)
///         growth(0.10)
///     }
///
///     Pessimistic {
///         revenue(800_000)
///         growth(0.05)
///     }
///
///     Optimistic {
///         revenue(1_200_000)
///         growth(0.15)
///     }
/// }
/// ```
///
/// ## See Also
/// - ``ScenarioSet/init(builder:)`` for using this builder
/// - ``Baseline(_:)``, ``Pessimistic(_:)``, ``Optimistic(_:)`` for scenario functions
@resultBuilder
public struct ScenarioSetBuilder {
    /// Build a block of scenarios from variadic arrays.
    /// - Parameter scenarios: Arrays of scenarios to flatten
    /// - Returns: Flattened array of all scenarios
    public static func buildBlock(_ scenarios: [ScenarioConfig]...) -> [ScenarioConfig] {
        scenarios.flatMap { $0 }
    }

    /// Convert a single scenario into an array.
    /// - Parameter scenario: A single scenario configuration
    /// - Returns: Array containing the scenario
    public static func buildExpression(_ scenario: ScenarioConfig) -> [ScenarioConfig] {
        [scenario]
    }

    /// Build scenarios from for-loop arrays.
    /// - Parameter scenarios: Nested arrays from loops
    /// - Returns: Flattened array of scenarios
    public static func buildArray(_ scenarios: [[ScenarioConfig]]) -> [ScenarioConfig] {
        scenarios.flatMap { $0 }
    }

    /// Build optional scenarios (from if statements without else).
    /// - Parameter scenarios: Optional array of scenarios
    /// - Returns: Scenarios if present, empty array otherwise
    public static func buildOptional(_ scenarios: [ScenarioConfig]?) -> [ScenarioConfig] {
        scenarios ?? []
    }

    /// Build conditional scenarios (if/else first branch).
    /// - Parameter scenarios: Scenarios from the first branch
    /// - Returns: The scenarios unchanged
    public static func buildEither(first scenarios: [ScenarioConfig]) -> [ScenarioConfig] {
        scenarios
    }

    /// Build conditional scenarios (if/else second branch).
    /// - Parameter scenarios: Scenarios from the second branch
    /// - Returns: The scenarios unchanged
    public static func buildEither(second scenarios: [ScenarioConfig]) -> [ScenarioConfig] {
        scenarios
    }
}

/// Result builder for configuring individual scenarios.
///
/// Enables declarative definition of scenario parameters using functions like
/// `revenue()`, `growth()`, `adjustCosts()`, etc.
///
/// ## Example
/// ```swift
/// let scenario = Baseline {
///     revenue(1_000_000)
///     growth(0.10)
///     costs(600_000)
///     adjustCosts(by: -0.05)  // 5% cost reduction
/// }
/// ```
///
/// ## See Also
/// - ``Baseline(_:)`` for creating baseline scenarios
/// - ``revenue(_:)``, ``growth(_:)``, etc. for parameter functions
@resultBuilder
public struct ScenarioConfigBuilder {
    /// Build a block of scenario parameters from variadic arrays.
    /// - Parameter components: Arrays of parameters to flatten
    /// - Returns: Flattened array of all parameters
    public static func buildBlock(_ components: [ScenarioParameter]...) -> [ScenarioParameter] {
        components.flatMap { $0 }
    }

    /// Convert a single parameter into an array.
    /// - Parameter component: A single scenario parameter
    /// - Returns: Array containing the parameter
    public static func buildExpression(_ component: ScenarioParameter) -> [ScenarioParameter] {
        [component]
    }

    /// Convert an array of parameters (pass through).
    /// - Parameter components: Array of parameters
    /// - Returns: The array unchanged
    public static func buildExpression(_ components: [ScenarioParameter]) -> [ScenarioParameter] {
        components
    }

    /// Build parameters from for-loop arrays.
    /// - Parameter components: Nested arrays from loops
    /// - Returns: Flattened array of parameters
    public static func buildArray(_ components: [[ScenarioParameter]]) -> [ScenarioParameter] {
        components.flatMap { $0 }
    }

    /// Build optional parameters (from if statements without else).
    /// - Parameter components: Optional array of parameters
    /// - Returns: Parameters if present, empty array otherwise
    public static func buildOptional(_ components: [ScenarioParameter]?) -> [ScenarioParameter] {
        components ?? []
    }

    /// Build conditional parameters (if/else first branch).
    /// - Parameter components: Parameters from the first branch
    /// - Returns: The parameters unchanged
    public static func buildEither(first components: [ScenarioParameter]) -> [ScenarioParameter] {
        components
    }

    /// Build conditional parameters (if/else second branch).
    /// - Parameter components: Parameters from the second branch
    /// - Returns: The parameters unchanged
    public static func buildEither(second components: [ScenarioParameter]) -> [ScenarioParameter] {
        components
    }
}

// MARK: - Scenario Parameters

/// A parameter in a scenario configuration.
public enum ScenarioParameter: Sendable {
    case value(String, Double)
    case adjustment(String, Double)
    case name(String)
    case description(String)
    case absoluteIncrease(String, Double)
    case multiplier(String, Double)
}

// MARK: - Scenario Builders

/// Create a baseline scenario.
public func Baseline(@ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    createScenario(name: "Baseline", builder: builder)
}

/// Create a pessimistic scenario.
public func Pessimistic(@ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    createScenario(name: "Pessimistic", builder: builder)
}

/// Create an optimistic scenario.
public func Optimistic(@ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    createScenario(name: "Optimistic", builder: builder)
}

/// Create a custom named scenario.
public func ScenarioNamed(_ name: String, @ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    createScenario(name: name, builder: builder)
}

/// Helper function to create scenarios.
private func createScenario(name: String, builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    var scenarioName = name
    var scenarioDescription: String? = nil
    var config = ScenarioConfig(name: name)
    let parameters = builder()

    for param in parameters {
        switch param {
        case .value(let key, let value):
            config.parameters[key] = value
        case .adjustment(let key, let percentage):
            config.adjustments[key] = percentage
        case .name(let newName):
            scenarioName = newName
        case .description(let desc):
            scenarioDescription = desc
        case .absoluteIncrease(let key, let increase):
            // Store as direct value override for now
            // In practice, this would need baseline context
            config.parameters[key] = increase
        case .multiplier(let key, let factor):
            // Store as adjustment representing the multiplier
            config.adjustments[key] = factor - 1.0
        }
    }

    // Update config with collected name and description
    config = ScenarioConfig(name: scenarioName, description: scenarioDescription)

    // Re-apply parameters and adjustments
    for param in parameters {
        switch param {
        case .value(let key, let value):
            config.parameters[key] = value
        case .adjustment(let key, let percentage):
            config.adjustments[key] = percentage
        case .absoluteIncrease(let key, let increase):
            config.parameters[key] = increase
        case .multiplier(let key, let factor):
            config.adjustments[key] = factor - 1.0
        case .name, .description:
            break // Already handled
        }
    }

    return config
}

// MARK: - Parameter Functions

/// Set a direct value for a parameter.
public func revenue(_ value: Double) -> ScenarioParameter {
    .value("revenue", value)
}

/// Set a growth rate.
public func growth(_ rate: Double) -> ScenarioParameter {
    .value("growth", rate)
}

/// Set costs.
public func costs(_ value: Double) -> ScenarioParameter {
    .value("costs", value)
}

/// Set a margin percentage.
public func margin(_ percentage: Double) -> ScenarioParameter {
    .value("margin", percentage)
}

/// Set a discount rate.
public func discountRate(_ rate: Double) -> ScenarioParameter {
    .value("discountRate", rate)
}

/// Set a custom parameter value.
public func parameter(_ name: String, value: Double) -> ScenarioParameter {
    .value(name, value)
}

/// Adjust revenue by a percentage.
public func adjustRevenue(by percentage: Double) -> ScenarioParameter {
    .adjustment("revenue", percentage)
}

/// Adjust costs by a percentage.
public func adjustCosts(by percentage: Double) -> ScenarioParameter {
    .adjustment("costs", percentage)
}

/// Adjust growth by a percentage.
public func adjustGrowth(by percentage: Double) -> ScenarioParameter {
    .adjustment("growth", percentage)
}

/// Adjust a custom parameter by a percentage.
public func adjust(_ name: String, by percentage: Double) -> ScenarioParameter {
    .adjustment(name, percentage)
}

// MARK: - Additional Component Functions (Documented API)

/// Top-level wrapper for building a single scenario.
///
/// Example:
/// ```swift
/// let scenario = buildScenario {
///     Name("Base Case")
///     Description("Expected performance")
///     Driver("Revenue Growth", value: 0.15)
/// }
/// ```
public func buildScenario(@ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> ScenarioConfig {
    createScenario(name: "Scenario", builder: builder)
}

/// Set the name of the scenario.
///
/// Example:
/// ```swift
/// buildScenario {
///     Name("Aggressive Growth")
///     revenue(2_000_000)
/// }
/// ```
public func Name(_ name: String) -> ScenarioParameter {
    .name(name)
}

/// Set the description of the scenario.
///
/// Example:
/// ```swift
/// buildScenario {
///     Name("Best Case")
///     Description("Optimistic assumptions with strong market conditions")
/// }
/// ```
public func Description(_ description: String) -> ScenarioParameter {
    .description(description)
}

/// Set a generic driver parameter value.
///
/// Note: Cannot use `Driver()` as a function name due to conflict with the Driver protocol.
/// Use this function instead.
///
/// Example:
/// ```swift
/// buildScenario {
///     ScenarioDriver("Revenue Growth", value: 0.15)
///     ScenarioDriver("Gross Margin", value: 0.60)
/// }
/// ```
public func ScenarioDriver(_ name: String, value: Double) -> ScenarioParameter {
    .value(name, value)
}

/// Add a new driver to the scenario.
///
/// Functionally identical to `ScenarioDriver()`, but semantically indicates adding
/// a new parameter rather than overriding an existing one.
///
/// Example:
/// ```swift
/// ScenarioAdjustment("Add International Revenue") {
///     AddScenarioDriver("International Revenue", value: 300_000)
/// }
/// ```
public func AddScenarioDriver(_ name: String, value: Double) -> ScenarioParameter {
    .value(name, value)
}

/// Adjust a driver by an absolute increase.
///
/// Example:
/// ```swift
/// AdjustScenarioDriver("Operating Expenses", increase: 50_000)
/// ```
public func AdjustScenarioDriver(_ name: String, increase: Double) -> ScenarioParameter {
    .absoluteIncrease(name, increase)
}

/// Adjust a driver by a multiplication factor.
///
/// Example:
/// ```swift
/// AdjustScenarioDriver("Cost of Goods Sold", multiplyBy: 1.10)  // Increase by 10%
/// ```
public func AdjustScenarioDriver(_ name: String, multiplyBy: Double) -> ScenarioParameter {
    .multiplier(name, multiplyBy)
}

/// Container for grouping related adjustments.
///
/// This is syntactic sugar for organizing adjustments in the DSL.
/// The adjustments are flattened into the parent scenario.
///
/// Example:
/// ```swift
/// buildScenario {
///     Name("Expansion Scenario")
///     ScenarioAdjustment("Add International Revenue") {
///         AddScenarioDriver("International Revenue", value: 300_000)
///         AdjustScenarioDriver("Operating Expenses", increase: 50_000)
///         AdjustScenarioDriver("Cost of Goods Sold", multiplyBy: 1.10)
///     }
/// }
/// ```
public func ScenarioAdjustment(_ name: String, @ScenarioConfigBuilder builder: () -> [ScenarioParameter]) -> [ScenarioParameter] {
    // Return all parameters from the adjustment group
    // The name is just for documentation/organization purposes
    builder()
}

// MARK: - Probability Extensions

extension ScenarioConfig {
    /// Set the probability of this scenario.
    public func withProbability(_ prob: Double) -> ScenarioConfig {
        var copy = self
        copy.probability = prob
        return copy
    }

    /// Set the description of this scenario.
    public func withDescription(_ desc: String) -> ScenarioConfig {
        var copy = self
        copy.description = desc
        return copy
    }
}

// MARK: - Scenario Analysis

extension ScenarioSet {
    /// Calculate expected value across all scenarios (requires probabilities).
    ///
    /// - Parameter getValue: Function to extract the value from each scenario
    /// - Returns: Probability-weighted expected value, or nil if any scenario lacks probability
    public func expectedValue(_ getValue: (ScenarioConfig) -> Double) -> Double? {
        // Check if all scenarios have probabilities
        guard scenarios.allSatisfy({ $0.probability != nil }) else {
            return nil
        }

        // Verify probabilities sum to 1.0 (within tolerance)
        let totalProb = scenarios.compactMap(\.probability).reduce(0, +)
        guard abs(totalProb - 1.0) < 0.001 else {
            return nil
        }

        return scenarios.reduce(0.0) { sum, scenario in
            sum + getValue(scenario) * (scenario.probability ?? 0)
        }
    }

    /// Calculate variance across scenarios (requires probabilities).
    ///
    /// - Parameter getValue: Function to extract the value from each scenario
    /// - Returns: Variance of values across scenarios, or nil if expected value cannot be calculated
    public func variance(_ getValue: (ScenarioConfig) -> Double) -> Double? {
        guard let expectedVal = expectedValue(getValue) else {
            return nil
        }

        return scenarios.reduce(0.0) { sum, scenario in
            let value = getValue(scenario)
            let diff = value - expectedVal
            return sum + diff * diff * (scenario.probability ?? 0)
        }
    }

    /// Calculate standard deviation across scenarios.
    public func standardDeviation(_ getValue: (ScenarioConfig) -> Double) -> Double? {
        variance(getValue).map { sqrt($0) }
    }

    /// Get the range of values across all scenarios.
    public func range(_ getValue: (ScenarioConfig) -> Double) -> (min: Double, max: Double)? {
        let values = scenarios.map(getValue)
        guard let min = values.min(), let max = values.max() else {
            return nil
        }
        return (min, max)
    }
}

// MARK: - Common Scenario Templates

extension ScenarioSet {
    /// Create a standard three-scenario set (pessimistic, base, optimistic).
    ///
    /// - Parameters:
    ///   - baseRevenue: Baseline revenue
    ///   - baseGrowth: Baseline growth rate
    ///   - variability: Percentage variability for scenarios (default 20%)
    /// - Returns: ScenarioSet with three scenarios
    public static func standardThreeWay(
        baseRevenue: Double,
        baseGrowth: Double,
        variability: Double = 0.20
    ) -> ScenarioSet {
        ScenarioSet {
            Pessimistic {
                revenue(baseRevenue * (1 - variability))
                growth(baseGrowth * (1 - variability))
            }
            .withProbability(0.25)

            Baseline {
                revenue(baseRevenue)
                growth(baseGrowth)
            }
            .withProbability(0.50)

            Optimistic {
                revenue(baseRevenue * (1 + variability))
                growth(baseGrowth * (1 + variability))
            }
            .withProbability(0.25)
        }
    }

    /// Create a five-scenario set (worst case, pessimistic, base, optimistic, best case).
    ///
    /// - Parameters:
    ///   - baseRevenue: Baseline revenue
    ///   - baseGrowth: Baseline growth rate
    ///   - moderateVariability: Moderate scenario variability (default 15%)
    ///   - extremeVariability: Extreme scenario variability (default 30%)
    /// - Returns: ScenarioSet with five scenarios
    public static func standardFiveWay(
        baseRevenue: Double,
        baseGrowth: Double,
        moderateVariability: Double = 0.15,
        extremeVariability: Double = 0.30
    ) -> ScenarioSet {
        ScenarioSet {
            ScenarioNamed("Worst Case") {
                revenue(baseRevenue * (1 - extremeVariability))
                growth(baseGrowth * (1 - extremeVariability))
            }
            .withProbability(0.10)

            Pessimistic {
                revenue(baseRevenue * (1 - moderateVariability))
                growth(baseGrowth * (1 - moderateVariability))
            }
            .withProbability(0.20)

            Baseline {
                revenue(baseRevenue)
                growth(baseGrowth)
            }
            .withProbability(0.40)

            Optimistic {
                revenue(baseRevenue * (1 + moderateVariability))
                growth(baseGrowth * (1 + moderateVariability))
            }
            .withProbability(0.20)

            ScenarioNamed("Best Case") {
                revenue(baseRevenue * (1 + extremeVariability))
                growth(baseGrowth * (1 + extremeVariability))
            }
            .withProbability(0.10)
        }
    }
}
