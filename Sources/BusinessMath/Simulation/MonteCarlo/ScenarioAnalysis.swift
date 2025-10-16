//
//  ScenarioAnalysis.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Errors

/// Errors that can occur during scenario analysis.
public enum ScenarioError: Error, Sendable {
	/// A scenario is missing configuration for one or more required inputs.
	case missingInputConfiguration(scenario: String, missingInputs: [String])

	/// A scenario references an input name that doesn't exist in the analysis.
	case unknownInput(scenario: String, inputName: String)

	/// No scenarios have been added to the analysis.
	case noScenarios
}

extension ScenarioError: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .missingInputConfiguration(let scenario, let missing):
			return "Scenario '\(scenario)' is missing configuration for inputs: \(missing.joined(separator: ", "))"
		case .unknownInput(let scenario, let input):
			return "Scenario '\(scenario)' references unknown input: \(input)"
		case .noScenarios:
			return "No scenarios have been added to the analysis"
		}
	}
}

// MARK: - Scenario Configuration

/// Builder for configuring scenario inputs using either fixed values or distributions.
///
/// This class provides a fluent interface for defining scenario parameters.
public final class ScenarioConfiguration: @unchecked Sendable {
	var values: [String: Double] = [:]
	var distributions: [String: any DistributionRandom & Sendable] = [:]

	/// Sets a fixed value for an input variable.
	///
	/// - Parameters:
	///   - value: The fixed value to use
	///   - inputName: The name of the input variable
	public func setValue(_ value: Double, forInput inputName: String) {
		values[inputName] = value
	}

	/// Sets a probability distribution for an input variable.
	///
	/// - Parameters:
	///   - distribution: The distribution to sample from
	///   - inputName: The name of the input variable
	public func setDistribution<D: DistributionRandom & Sendable>(
		_ distribution: D,
		forInput inputName: String
	) where D.T == Double {
		distributions[inputName] = distribution
	}
}

// MARK: - Scenario

/// Represents a specific scenario with named input configurations.
///
/// A scenario defines a complete set of assumptions for all model inputs,
/// using either fixed values or probability distributions.
///
/// ## Example
///
/// ```swift
/// let baseCase = Scenario(name: "Base Case") { config in
///     config.setValue(1_000_000.0, forInput: "Revenue")
///     config.setDistribution(
///         DistributionNormal(700_000.0, 50_000.0),
///         forInput: "Costs"
///     )
/// }
/// ```
public struct Scenario: Sendable {
	/// The name of this scenario (e.g., "Base Case", "Best Case", "Worst Case")
	public let name: String

	/// Fixed values for inputs (deterministic)
	public let inputValues: [String: Double]

	/// Distributions for inputs (uncertain)
	public let inputDistributions: [String: any DistributionRandom & Sendable]

	/// Creates a new scenario with the given name and configuration.
	///
	/// - Parameters:
	///   - name: The scenario name
	///   - configuration: A closure that configures the scenario inputs
	public init(name: String, configuration: (ScenarioConfiguration) -> Void) {
		self.name = name
		let config = ScenarioConfiguration()
		configuration(config)
		self.inputValues = config.values
		self.inputDistributions = config.distributions
	}
}

// MARK: - Scenario Analysis

/// Framework for running and comparing multiple scenarios in Monte Carlo simulation.
///
/// ScenarioAnalysis enables "what-if" analysis by running the same model
/// under different assumptions (scenarios) and comparing the results.
///
/// ## Example
///
/// ```swift
/// var analysis = ScenarioAnalysis(
///     inputNames: ["Revenue", "Costs"],
///     model: { inputs in inputs[0] - inputs[1] },
///     iterations: 10_000
/// )
///
/// analysis.addScenario(Scenario(name: "Base Case") { config in
///     config.setValue(1_000_000.0, forInput: "Revenue")
///     config.setValue(700_000.0, forInput: "Costs")
/// })
///
/// analysis.addScenario(Scenario(name: "Best Case") { config in
///     config.setValue(1_200_000.0, forInput: "Revenue")
///     config.setValue(600_000.0, forInput: "Costs")
/// })
///
/// let results = try analysis.run()
/// let comparison = ScenarioComparison(results: results)
/// print(comparison.bestScenario(by: .mean).name)
/// ```
public struct ScenarioAnalysis: Sendable {
	/// The names of all input variables (in order)
	public let inputNames: [String]

	/// The model function to execute
	private let model: @Sendable ([Double]) -> Double

	/// Number of Monte Carlo iterations per scenario
	public let iterations: Int

	/// All scenarios to analyze
	public private(set) var scenarios: [Scenario]

	/// Creates a new scenario analysis.
	///
	/// - Parameters:
	///   - inputNames: Names of all input variables (order matters for model function)
	///   - model: The model function that computes outcomes from inputs
	///   - iterations: Number of Monte Carlo iterations per scenario
	public init(
		inputNames: [String],
		model: @escaping @Sendable ([Double]) -> Double,
		iterations: Int
	) {
		self.inputNames = inputNames
		self.model = model
		self.iterations = iterations
		self.scenarios = []
	}

	/// Adds a scenario to the analysis.
	///
	/// - Parameter scenario: The scenario to add
	public mutating func addScenario(_ scenario: Scenario) {
		scenarios.append(scenario)
	}

	/// Runs all scenarios and returns the results.
	///
	/// - Returns: A dictionary mapping scenario names to their simulation results
	/// - Throws: `ScenarioError` if scenarios are invalid or missing input configurations
	public func run() throws -> [String: SimulationResults] {
		guard !scenarios.isEmpty else {
			throw ScenarioError.noScenarios
		}

		var results: [String: SimulationResults] = [:]

		for scenario in scenarios {
			// Validate that all inputs are configured
			let configuredInputs = Set(scenario.inputValues.keys).union(scenario.inputDistributions.keys)
			let requiredInputs = Set(inputNames)
			let missingInputs = requiredInputs.subtracting(configuredInputs)

			guard missingInputs.isEmpty else {
				throw ScenarioError.missingInputConfiguration(
					scenario: scenario.name,
					missingInputs: Array(missingInputs)
				)
			}

			// Validate that no extra inputs are configured
			for inputName in configuredInputs {
				guard requiredInputs.contains(inputName) else {
					throw ScenarioError.unknownInput(scenario: scenario.name, inputName: inputName)
				}
			}

			// Create simulation inputs
			var simulation = MonteCarloSimulation(iterations: iterations, model: model)

			for inputName in inputNames {
				let input: SimulationInput

				if let fixedValue = scenario.inputValues[inputName] {
					// Fixed value: create constant sampler
					input = SimulationInput(name: inputName) {
						fixedValue
					}
				} else if let distribution = scenario.inputDistributions[inputName] {
					// Distribution: use it directly
					input = SimulationInput(name: inputName) {
						distribution.next() as! Double
					}
				} else {
					// This shouldn't happen due to validation above
					throw ScenarioError.missingInputConfiguration(
						scenario: scenario.name,
						missingInputs: [inputName]
					)
				}

				simulation.addInput(input)
			}

			// Run simulation
			let scenarioResults = try simulation.run()
			results[scenario.name] = scenarioResults
		}

		return results
	}
}

// MARK: - Metric Enum

/// Metrics for comparing scenarios.
public enum ScenarioMetric: Sendable {
	case mean
	case median
	case stdDev
	case p5
	case p95
	case var95
	case cvar95

	/// Extracts the metric value from simulation results.
	func value(from results: SimulationResults) -> Double {
		switch self {
		case .mean: return results.statistics.mean
		case .median: return results.statistics.median
		case .stdDev: return results.statistics.stdDev
		case .p5: return results.percentiles.p5
		case .p95: return results.percentiles.p95
		case .var95: return results.valueAtRisk(confidenceLevel: 0.95)
		case .cvar95: return results.conditionalValueAtRisk(confidenceLevel: 0.95)
		}
	}
}

// MARK: - Scenario Comparison

/// Comparison utilities for analyzing multiple scenario results.
///
/// Provides methods for ranking scenarios, identifying best/worst cases,
/// and generating summary tables.
public struct ScenarioComparison: Sendable {
	/// All scenario results
	public let results: [String: SimulationResults]

	/// Names of all scenarios
	public var scenarioNames: [String] {
		Array(results.keys)
	}

	/// Creates a comparison from scenario analysis results.
	///
	/// - Parameter results: The results dictionary from ScenarioAnalysis.run()
	public init(results: [String: SimulationResults]) {
		self.results = results
	}

	/// Finds the best scenario according to a metric.
	///
	/// - Parameter metric: The metric to optimize (higher is better for mean, lower is better for risk)
	/// - Returns: The scenario with the best metric value
	public func bestScenario(by metric: ScenarioMetric) -> (name: String, results: SimulationResults) {
		let ranked = rankScenarios(by: metric, ascending: false)
		return (name: ranked[0].name, results: ranked[0].results)
	}

	/// Finds the worst scenario according to a metric.
	///
	/// - Parameter metric: The metric to optimize
	/// - Returns: The scenario with the worst metric value
	public func worstScenario(by metric: ScenarioMetric) -> (name: String, results: SimulationResults) {
		let ranked = rankScenarios(by: metric, ascending: true)
		return (name: ranked[0].name, results: ranked[0].results)
	}

	/// Ranks all scenarios by a metric.
	///
	/// - Parameters:
	///   - metric: The metric to rank by
	///   - ascending: If true, lower values rank higher; if false, higher values rank higher
	/// - Returns: Sorted list of scenarios with their results
	public func rankScenarios(
		by metric: ScenarioMetric,
		ascending: Bool
	) -> [(name: String, results: SimulationResults)] {
		let sorted = results.sorted { lhs, rhs in
			let lhsValue = metric.value(from: lhs.value)
			let rhsValue = metric.value(from: rhs.value)
			return ascending ? lhsValue < rhsValue : lhsValue > rhsValue
		}

		return sorted.map { (name: $0.key, results: $0.value) }
	}

	/// Generates a summary table with key metrics for all scenarios.
	///
	/// - Parameter metrics: The metrics to include in the summary
	/// - Returns: Dictionary mapping scenario names to metric values
	public func summaryTable(metrics: [ScenarioMetric]) -> [String: [Double]] {
		var summary: [String: [Double]] = [:]

		for (name, results) in results {
			let values = metrics.map { $0.value(from: results) }
			summary[name] = values
		}

		return summary
	}
}

// MARK: - Sensitivity Analysis

/// Framework for analyzing how individual input variables affect model outputs.
///
/// Sensitivity analysis identifies which inputs have the greatest impact
/// on outcomes, helping prioritize data collection and risk mitigation efforts.
public struct SensitivityAnalysis: Sendable {
	/// Names of all input variables
	public let inputNames: [String]

	/// The model function
	private let model: @Sendable ([Double]) -> Double

	/// Base case values for all inputs
	public let baseValues: [String: Double]

	/// Number of Monte Carlo iterations per scenario
	public let iterations: Int

	/// Creates a new sensitivity analysis.
	///
	/// - Parameters:
	///   - inputNames: Names of all input variables
	///   - model: The model function
	///   - baseValues: Base case values for all inputs
	///   - iterations: Number of iterations per scenario
	public init(
		inputNames: [String],
		model: @escaping @Sendable ([Double]) -> Double,
		baseValues: [String: Double],
		iterations: Int
	) {
		self.inputNames = inputNames
		self.model = model
		self.baseValues = baseValues
		self.iterations = iterations
	}

	/// Analyzes sensitivity to a single input variable.
	///
	/// - Parameters:
	///   - inputName: The input to vary
	///   - range: The range to vary the input (as multipliers of base value)
	///   - steps: Number of steps to sample within the range
	/// - Returns: Sensitivity results for this input
	public func analyzeInput(
		_ inputName: String,
		range: ClosedRange<Double>,
		steps: Int = 5
	) throws -> InputSensitivity {
		guard baseValues[inputName] != nil else {
			throw ScenarioError.unknownInput(scenario: "Sensitivity Analysis", inputName: inputName)
		}

		let baseValue = baseValues[inputName]!
		var scenarios: [(multiplier: Double, result: SimulationResults)] = []

		// Generate multipliers evenly spaced in range
		let stepSize = (range.upperBound - range.lowerBound) / Double(steps - 1)

		for i in 0..<steps {
			let multiplier = range.lowerBound + Double(i) * stepSize

			// Create scenario with this multiplier
			var analysis = ScenarioAnalysis(
				inputNames: inputNames,
				model: model,
				iterations: iterations
			)

			let scenario = Scenario(name: "\(inputName)_\(multiplier)") { config in
				for name in self.inputNames {
					if name == inputName {
						config.setValue(baseValue * multiplier, forInput: name)
					} else {
						config.setValue(self.baseValues[name]!, forInput: name)
					}
				}
			}

			analysis.addScenario(scenario)
			let results = try analysis.run()
			scenarios.append((multiplier: multiplier, result: results[scenario.name]!))
		}

		return InputSensitivity(
			inputName: inputName,
			baseValue: baseValue,
			scenarios: scenarios
		)
	}

	/// Generates tornado chart data showing relative impact of all inputs.
	///
	/// A tornado chart displays the range of outcomes when each input is varied,
	/// sorted by impact (largest first).
	///
	/// - Parameters:
	///   - range: The range to vary each input (as multipliers)
	/// - Returns: Tornado chart bars sorted by impact (descending)
	public func tornadoChart(range: ClosedRange<Double>) throws -> [TornadoBar] {
		var bars: [TornadoBar] = []

		for inputName in inputNames {
			let sensitivity = try analyzeInput(inputName, range: range, steps: 2)

			// Get output range (low and high)
			let lowScenario = sensitivity.scenarios.first { $0.multiplier == range.lowerBound }!
			let highScenario = sensitivity.scenarios.first { $0.multiplier == range.upperBound }!

			let lowOutput = lowScenario.result.statistics.mean
			let highOutput = highScenario.result.statistics.mean

			bars.append(TornadoBar(
				inputName: inputName,
				low: min(lowOutput, highOutput),
				high: max(lowOutput, highOutput)
			))
		}

		// Sort by impact (descending)
		bars.sort { ($0.high - $0.low) > ($1.high - $1.low) }

		return bars
	}
}

/// Results of sensitivity analysis for a single input variable.
public struct InputSensitivity: Sendable {
	/// The input variable name
	public let inputName: String

	/// The base case value of this input
	public let baseValue: Double

	/// Scenarios with different input values and their results
	public let scenarios: [(multiplier: Double, result: SimulationResults)]
}

/// A bar in a tornado chart showing input impact.
public struct TornadoBar: Sendable {
	/// The input variable name
	public let inputName: String

	/// Output value when input is at low end of range
	public let low: Double

	/// Output value when input is at high end of range
	public let high: Double

	/// Impact range
	public var impact: Double {
		high - low
	}
}
