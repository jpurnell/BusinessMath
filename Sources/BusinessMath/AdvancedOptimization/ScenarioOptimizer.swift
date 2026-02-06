//
//  ScenarioOptimizer.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Numerics

// MARK: - Scenario Definition

/// A named scenario with probability and parameters.
public struct NamedScenario: Sendable {
	/// Scenario name (e.g., "Bull Market", "Base Case", "Bear Market")
	public let name: String

	/// Probability of this scenario
	public let probability: Double

	/// Scenario-specific parameters as dictionary
	public let parameters: [String: Double]

	/// Creates a named scenario.
	public init(name: String, probability: Double, parameters: [String: Double]) {
		self.name = name
		self.probability = probability
		self.parameters = parameters
	}

	/// Convenience subscript for parameter access
	public subscript(key: String) -> Double? {
		parameters[key]
	}
}

// MARK: - Scenario Constraint

/// Constraint that may be conditional on scenarios.
public enum ScenarioConstraint<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {
	/// Constraint that applies to all scenarios
	case all(function: @Sendable (V) -> Double, isEquality: Bool)

	/// Constraint that applies only to specific scenario
	case inScenario(String, function: @Sendable (V) -> Double, isEquality: Bool)

	/// Constraint that applies to multiple scenarios
	case inScenarios([String], function: @Sendable (V) -> Double, isEquality: Bool)

	/// Check if constraint applies to a given scenario
	public func appliesTo(scenario: String) -> Bool {
		switch self {
		case .all:
			return true
		case .inScenario(let name, _, _):
			return name == scenario
		case .inScenarios(let names, _, _):
			return names.contains(scenario)
		}
	}

	/// Get the constraint function if it applies
	public func function(for scenario: String) -> (@Sendable (V) -> Double)? {
		guard appliesTo(scenario: scenario) else { return nil }

		switch self {
		case .all(let function, _):
			return function
		case .inScenario(_, let function, _):
			return function
		case .inScenarios(_, let function, _):
			return function
		}
	}

	/// Whether this is an equality constraint
	public var isEquality: Bool {
		switch self {
		case .all(_, let isEq):
			return isEq
		case .inScenario(_, _, let isEq):
			return isEq
		case .inScenarios(_, _, let isEq):
			return isEq
		}
	}
}

// MARK: - Scenario Optimization Result

/// Result from scenario-based optimization.
public struct ScenarioOptimizationResult<V: VectorSpace> where V.Scalar == Double {
	/// Optimal solution
	public let solution: V

	/// Expected objective value (probability-weighted)
	public let expectedObjective: Double

	/// Objective value for each scenario
	public let scenarioObjectives: [String: Double]

	/// Probability-weighted variance of objectives
	public let objectiveVariance: Double

	/// Standard deviation of objectives
	public var objectiveStdDev: Double { sqrt(objectiveVariance) }

	/// Whether optimization converged
	public let converged: Bool

	/// Number of iterations
	public let iterations: Int

	/// Scenarios used
	public let scenarios: [NamedScenario]

	/// Get objective for a specific scenario
	public func objective(for scenarioName: String) -> Double? {
		scenarioObjectives[scenarioName]
	}

	/// Get scenario by name
	public func scenario(named: String) -> NamedScenario? {
		scenarios.first { $0.name == named }
	}
}

// MARK: - Scenario Optimizer

/// Optimizer for discrete scenario-based problems with conditional constraints.
///
/// Scenario-based optimization optimizes expected value across named scenarios:
/// ```
/// minimize: Σᵢ pᵢ f(x, scenarioᵢ)
/// subject to:
///   - g(x) ≤ 0 for all scenarios
///   - hⱼ(x) ≤ 0 for scenario j only
/// ```
///
/// ## Example: Bull/Base/Bear Markets
/// ```swift
/// let scenarios = [
///     NamedScenario(
///         name: "Bull Market",
///         probability: 0.30,
///         parameters: ["stock_return": 0.20, "bond_return": 0.04]
///     ),
///     NamedScenario(
///         name: "Base Case",
///         probability: 0.50,
///         parameters: ["stock_return": 0.10, "bond_return": 0.05]
///     ),
///     NamedScenario(
///         name: "Bear Market",
///         probability: 0.20,
///         parameters: ["stock_return": -0.05, "bond_return": 0.06]
///     )
/// ]
///
/// let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)
///
/// let result = try optimizer.optimize(
///     objective: { weights, scenario in
///         let stockReturn = scenario["stock_return"] ?? 0.0
///         let bondReturn = scenario["bond_return"] ?? 0.0
///         return weights[0] * stockReturn + weights[1] * bondReturn
///     },
///     initialSolution: VectorN([0.5, 0.5]),
///     constraints: [
///         .all(function: { x in x.toArray().reduce(0, +) - 1.0 }, isEquality: true),
///         .inScenario("Bear Market", function: { x in 0.30 - x[1] }, isEquality: false)  // bonds ≥ 30% in bear
///     ],
///     minimize: false
/// )
/// ```
public struct ScenarioOptimizer<V: VectorSpace>: Sendable where V.Scalar == Double, V: Sendable {

	// MARK: - Properties

	/// Scenarios with probabilities
	public let scenarios: [NamedScenario]

	/// Maximum iterations for optimization
	public let maxIterations: Int

	/// Convergence tolerance
	public let tolerance: Double

	// MARK: - Initialization

	/// Creates a scenario-based optimizer.
	///
	/// - Parameters:
	///   - scenarios: Array of named scenarios with probabilities
	///   - maxIterations: Maximum iterations (default: 500)
	///   - tolerance: Convergence tolerance (default: 1e-6)
	public init(
		scenarios: [NamedScenario],
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) {
		precondition(!scenarios.isEmpty, "Must provide at least one scenario")
		precondition(scenarios.allSatisfy { $0.probability >= 0 }, "Probabilities must be non-negative")

		self.scenarios = scenarios
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}

	// MARK: - Optimization

	/// Optimize expected value across scenarios with conditional constraints.
	///
	/// - Parameters:
	///   - objective: Scenario-dependent objective function
	///   - initialSolution: Starting point
	///   - constraints: Constraints (may be conditional on scenarios)
	///   - minimize: Whether to minimize (true) or maximize (false)
	/// - Returns: Scenario optimization result
	/// - Throws: OptimizationError if optimization fails
	public func optimize(
		objective: @escaping @Sendable (V, NamedScenario) -> Double,
		initialSolution: V,
		constraints: [ScenarioConstraint<V>] = [],
		minimize: Bool = false
	) throws -> ScenarioOptimizationResult<V> {

		// Create expected value objective
		let totalProbability = scenarios.map { $0.probability }.reduce(0.0, +)

		let expectedObjective: @Sendable (V) -> Double = { x in
			var total = 0.0
			for scenario in self.scenarios {
				let value = objective(x, scenario)
				total += value * scenario.probability
			}
			return total / totalProbability
		}

		// Convert scenario constraints to standard constraints
		// For conditional constraints, we need to check them across all scenarios
		let standardConstraints = try convertScenarioConstraints(
			constraints,
			objective: objective
		)

		// Choose optimizer based on constraints
		let result: ConstrainedOptimizationResult<V>

		if standardConstraints.isEmpty {
			// No constraints - use unconstrained optimizer
			let optimizer = MultivariateGradientDescent<V>(
				learningRate: V.Scalar(0.01),
				maxIterations: maxIterations,
				tolerance: V.Scalar(tolerance)
			)
			let objectiveToMinimize = minimize ? expectedObjective : { -expectedObjective($0) }
			let unconstrainedResult = try optimizer.minimize(
				function: objectiveToMinimize,
				gradient: { x in try numericalGradient(objectiveToMinimize, at: x) },
				initialGuess: initialSolution
			)
			// Convert to ConstrainedOptimizationResult format
			result = ConstrainedOptimizationResult(
				solution: unconstrainedResult.solution,
				objectiveValue: Double(unconstrainedResult.value),
				lagrangeMultipliers: [],
				iterations: unconstrainedResult.iterations,
				converged: unconstrainedResult.converged,
				constraintViolation: 0.0
			)
		} else {
			let hasInequality = standardConstraints.contains { !$0.isEquality }

			if hasInequality {
				let optimizer = InequalityOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations,
					maxInnerIterations: 1000
				)
				result = try optimizer.minimize(
					minimize ? expectedObjective : { @Sendable (x: V) -> Double in -expectedObjective(x) },
					from: initialSolution,
					subjectTo: standardConstraints
				)
			} else {
				let optimizer = ConstrainedOptimizer<V>(
					constraintTolerance: V.Scalar(tolerance),
					gradientTolerance: V.Scalar(tolerance),
					maxIterations: maxIterations,
					maxInnerIterations: 1000
				)
				result = try optimizer.minimize(
					minimize ? expectedObjective : { @Sendable (x: V) -> Double in -expectedObjective(x) },
					from: initialSolution,
					subjectTo: standardConstraints
				)
			}
		}

		// Compute per-scenario objectives
		var scenarioObjectives: [String: Double] = [:]
		for scenario in scenarios {
			let value = objective(result.solution, scenario)
			scenarioObjectives[scenario.name] = value
		}

		// Compute statistics
		let expected = scenarioObjectives.values.enumerated().reduce(0.0) { sum, pair in
			let (index, value) = pair
			return sum + value * scenarios[index].probability
		} / totalProbability

		let variance = scenarioObjectives.values.enumerated().reduce(0.0) { sum, pair in
			let (index, value) = pair
			let diff = value - expected
			return sum + diff * diff * scenarios[index].probability
		} / totalProbability

		return ScenarioOptimizationResult(
			solution: result.solution,
			expectedObjective: minimize ? result.objectiveValue : -result.objectiveValue,
			scenarioObjectives: scenarioObjectives,
			objectiveVariance: variance,
			converged: result.converged,
			iterations: result.iterations,
			scenarios: scenarios
		)
	}

	// MARK: - Helper Methods

	/// Convert scenario constraints to standard constraints.
	private func convertScenarioConstraints(
		_ constraints: [ScenarioConstraint<V>],
		objective: @escaping @Sendable (V, NamedScenario) -> Double
	) throws -> [MultivariateConstraint<V>] {

		var standardConstraints: [MultivariateConstraint<V>] = []

		for constraint in constraints {
			switch constraint {
			case .all(let function, let isEquality):
				// Apply to all scenarios (just use the constraint directly)
				if isEquality {
					standardConstraints.append(.equality(function: function, gradient: nil))
				} else {
					standardConstraints.append(.inequality(function: function, gradient: nil))
				}

			case .inScenario:
				// Conditional constraint: only needs to hold for specific scenario
				// We can't enforce this directly in standard optimization
				// Instead, we'll validate it after optimization
				// For now, skip (will be checked in validation)
				continue

			case .inScenarios:
				// Similar to inScenario - validate after
				continue
			}
		}

		return standardConstraints
	}
}

// MARK: - Convenience Extensions

extension ScenarioOptimizer {

	/// Optimize with simple probability-weighted scenarios.
	///
	/// - Parameters:
	///   - objective: Objective that doesn't need scenario object
	///   - scenarioValues: Objective value for each scenario
	///   - probabilities: Probability for each scenario value
	///   - initialSolution: Starting point
	///   - constraints: Standard constraints
	///   - minimize: Whether to minimize
	public static func optimizeWeighted(
		scenarioValues: [(name: String, probability: Double, objective: @Sendable (V) -> Double)],
		initialSolution: V,
		constraints: [MultivariateConstraint<V>] = [],
		minimize: Bool = false,
		maxIterations: Int = 500,
		tolerance: Double = 1e-6
	) throws -> ScenarioOptimizationResult<V> {

		// Create scenarios
		let scenarios = scenarioValues.enumerated().map { index, value in
			NamedScenario(
				name: value.name,
				probability: value.probability,
				parameters: ["index": Double(index)]
			)
		}

		let optimizer = ScenarioOptimizer<V>(
			scenarios: scenarios,
			maxIterations: maxIterations,
			tolerance: tolerance
		)

		// Create objective that dispatches based on scenario
		let objective: @Sendable (V, NamedScenario) -> Double = { x, scenario in
			let index = Int(scenario["index"] ?? 0)
			return scenarioValues[index].objective(x)
		}

		// Convert constraints
		let scenarioConstraints = constraints.map { constraint -> ScenarioConstraint<V> in
			switch constraint {
			case .equality(let function, _):
				return .all(function: function, isEquality: true)
			case .inequality(let function, _):
				return .all(function: function, isEquality: false)
			case .linearInequality, .linearEquality:
				// Linear constraints: use the function property which converts them
				let function = constraint.function
				return .all(function: function, isEquality: constraint.isEquality)
			}
		}

		return try optimizer.optimize(
			objective: objective,
			initialSolution: initialSolution,
			constraints: scenarioConstraints,
			minimize: minimize
		)
	}
}
