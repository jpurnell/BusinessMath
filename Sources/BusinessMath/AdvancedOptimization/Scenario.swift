//
//  Scenario.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation

// MARK: - OptimizationScenario Protocol

/// Protocol for random scenarios used in stochastic optimization.
///
/// A scenario represents one possible realization of uncertain parameters.
/// Stochastic optimization optimizes the expected value across many scenarios.
///
/// ## Example
/// ```swift
/// struct PortfolioScenario: OptimizationScenario {
///     let returns: [Double]  // Random returns for each asset
///     let probability: Double  // Optional: for discrete distributions
///
///     // Generate from historical data or Monte Carlo
///     static func generate() -> PortfolioScenario {
///         let returns = sampleFromHistoricalDistribution()
///         return PortfolioScenario(returns: returns, probability: 1.0)
///     }
/// }
/// ```
public protocol OptimizationScenario {
	/// Optional probability for discrete scenarios.
	///
	/// For continuous distributions (Monte Carlo), this is typically 1/N.
	/// For discrete scenarios, this is the scenario probability.
	var probability: Double { get }
}

// MARK: - MonteCarloScenario

/// A scenario generated via Monte Carlo sampling.
///
/// This is a generic container for random parameters used in stochastic optimization.
///
/// ## Example
/// ```swift
/// let scenario = MonteCarloScenario(
///     parameters: [
///         "stock_return": 0.12,
///         "bond_return": 0.04,
///         "inflation": 0.02
///     ]
/// )
///
/// let stockReturn = scenario.parameters["stock_return"]!
/// ```
public struct MonteCarloScenario: OptimizationScenario {
	/// Random parameters for this scenario
	public let parameters: [String: Double]

	/// Probability (1/N for Monte Carlo)
	public let probability: Double

	/// Creates a Monte Carlo scenario.
	///
	/// - Parameters:
	///   - parameters: Dictionary of random parameter values
	///   - probability: Scenario probability (default: 1.0, will be normalized)
	public init(parameters: [String: Double], probability: Double = 1.0) {
		self.parameters = parameters
		self.probability = probability
	}

	/// Convenience accessor for parameters.
	public subscript(key: String) -> Double? {
		return parameters[key]
	}
}

// MARK: - DiscreteScenario

/// A scenario from a discrete probability distribution.
///
/// Used when there are a finite number of possible futures (e.g., bull/base/bear market).
///
/// ## Example
/// ```swift
/// let scenarios = [
///     DiscreteScenario(name: "Bull", probability: 0.30, parameters: ["return": 0.20]),
///     DiscreteScenario(name: "Base", probability: 0.50, parameters: ["return": 0.10]),
///     DiscreteScenario(name: "Bear", probability: 0.20, parameters: ["return": -0.05])
/// ]
/// ```
public struct DiscreteScenario: OptimizationScenario {
	/// Scenario name
	public let name: String

	/// Scenario probability (should sum to 1 across all scenarios)
	public let probability: Double

	/// Scenario-specific parameters
	public let parameters: [String: Double]

	/// Creates a discrete scenario.
	///
	/// - Parameters:
	///   - name: Descriptive name
	///   - probability: Probability of this scenario
	///   - parameters: Scenario-specific parameter values
	public init(name: String, probability: Double, parameters: [String: Double]) {
		self.name = name
		self.probability = probability
		self.parameters = parameters
	}

	/// Convenience accessor for parameters.
	public subscript(key: String) -> Double? {
		return parameters[key]
	}
}

// MARK: - Scenario Generation

/// Helper for generating scenarios from distributions.
public struct ScenarioGenerator {

	/// Generate scenarios from normal distribution.
	///
	/// - Parameters:
	///   - mean: Mean vector
	///   - standardDeviation: Standard deviation vector
	///   - numberOfScenarios: Number of samples
	///   - seed: Random seed for reproducibility
	/// - Returns: Array of Monte Carlo scenarios
	public static func normal(
		mean: [Double],
		standardDeviation: [Double],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) -> [MonteCarloScenario] {
		precondition(mean.count == standardDeviation.count, "Mean and std dev must have same dimension")
		precondition(numberOfScenarios > 0, "Number of scenarios must be positive")

		// Set seed if provided
		if let seed = seed {
			srand48(Int(seed))
		}

		var scenarios: [MonteCarloScenario] = []
		let dimension = mean.count

		for _ in 0..<numberOfScenarios {
			var parameters: [String: Double] = [:]

			for i in 0..<dimension {
				// Box-Muller transform for normal samples
				let u1 = drand48()
				let u2 = drand48()
				let z = sqrt(-2.0 * log(u1)) * cos(2.0 * .pi * u2)
				let value = mean[i] + standardDeviation[i] * z

				parameters["param_\(i)"] = value
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios)
			))
		}

		return scenarios
	}

	/// Generate scenarios from historical data (bootstrap resampling).
	///
	/// - Parameters:
	///   - historicalData: Historical observations
	///   - numberOfScenarios: Number of bootstrap samples
	///   - seed: Random seed for reproducibility
	/// - Returns: Array of Monte Carlo scenarios
	public static func bootstrap(
		historicalData: [[Double]],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) -> [MonteCarloScenario] {
		precondition(!historicalData.isEmpty, "Historical data cannot be empty")
		precondition(numberOfScenarios > 0, "Number of scenarios must be positive")

		// Set seed if provided
		if let seed = seed {
			srand48(Int(seed))
		}

		var scenarios: [MonteCarloScenario] = []
		let dimension = historicalData.first!.count

		for _ in 0..<numberOfScenarios {
			// Random sample from historical data
			let index = Int(drand48() * Double(historicalData.count))
			let sample = historicalData[index]

			var parameters: [String: Double] = [:]
			for i in 0..<dimension {
				parameters["param_\(i)"] = sample[i]
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios)
			))
		}

		return scenarios
	}

	/// Generate uniform random scenarios.
	///
	/// - Parameters:
	///   - lowerBounds: Lower bounds for each parameter
	///   - upperBounds: Upper bounds for each parameter
	///   - numberOfScenarios: Number of samples
	///   - seed: Random seed for reproducibility
	/// - Returns: Array of Monte Carlo scenarios
	public static func uniform(
		lowerBounds: [Double],
		upperBounds: [Double],
		numberOfScenarios: Int,
		seed: UInt64? = nil
	) -> [MonteCarloScenario] {
		precondition(lowerBounds.count == upperBounds.count, "Bounds must have same dimension")
		precondition(numberOfScenarios > 0, "Number of scenarios must be positive")

		// Set seed if provided
		if let seed = seed {
			srand48(Int(seed))
		}

		var scenarios: [MonteCarloScenario] = []
		let dimension = lowerBounds.count

		for _ in 0..<numberOfScenarios {
			var parameters: [String: Double] = [:]

			for i in 0..<dimension {
				let u = drand48()
				let value = lowerBounds[i] + u * (upperBounds[i] - lowerBounds[i])
				parameters["param_\(i)"] = value
			}

			scenarios.append(MonteCarloScenario(
				parameters: parameters,
				probability: 1.0 / Double(numberOfScenarios)
			))
		}

		return scenarios
	}
}
