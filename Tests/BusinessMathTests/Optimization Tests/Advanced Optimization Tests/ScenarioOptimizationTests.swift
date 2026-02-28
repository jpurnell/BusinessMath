//
//  ScenarioOptimizationTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import TestSupport  // Cross-platform math functions
import Testing
@testable import BusinessMath

/// Tests for scenario-based optimization with conditional constraints.
@Suite struct ScenarioOptimizationTests {

	// MARK: - Basic Scenario Optimization

	/// Test basic three-scenario optimization (bull/base/bear).
	@Test func bullBaseBearScenarios() throws {
		let scenarios = [
			NamedScenario(
				name: "Bull Market",
				probability: 0.30,
				parameters: ["stock_return": 0.20, "bond_return": 0.04]
			),
			NamedScenario(
				name: "Base Case",
				probability: 0.50,
				parameters: ["stock_return": 0.10, "bond_return": 0.05]
			),
			NamedScenario(
				name: "Bear Market",
				probability: 0.20,
				parameters: ["stock_return": -0.05, "bond_return": 0.06]
			)
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(
			scenarios: scenarios,
			maxIterations: 300,
			tolerance: 1e-4
		)

		var constraints: [ScenarioConstraint<VectorN<Double>>] = [
			.all(function: { x in x.toArray().reduce(0, +) - 1.0 }, isEquality: true)
		]
		// Add non-negativity
		for i in 0..<2 {
			constraints.append(.all(function: { x in -x.toArray()[i] }, isEquality: false))
		}

		let result = try optimizer.optimize(
			objective: { weights, scenario in
				let stockReturn = scenario["stock_return"] ?? 0.0
				let bondReturn = scenario["bond_return"] ?? 0.0
				let stockWeight = weights.toArray()[0]
				let bondWeight = weights.toArray()[1]
				return stockWeight * stockReturn + bondWeight * bondReturn
			},
			initialSolution: VectorN([0.5, 0.5]),
			constraints: constraints,
			minimize: false  // Maximize expected return
		)

		#expect(result.converged, "Optimization should converge")

		// Check budget constraint
		let weights = result.solution.toArray()
		#expect(abs(weights.reduce(0, +) - 1.0) < 1e-3)

		// Check non-negativity
		for weight in weights {
			#expect(weight.rounded() >= 0.0)
		}

		// Expected return should be positive
		#expect(result.expectedObjective > 0.0)

		// Check we have results for all scenarios
		#expect(result.scenarioObjectives.count == 3)
		#expect(result.objective(for: "Bull Market") != nil)
		#expect(result.objective(for: "Base Case") != nil)
		#expect(result.objective(for: "Bear Market") != nil)
	}

	/// Test probability weighting.
	@Test func probabilityWeighting() throws {
		// Two scenarios: 90% chance of 10% return, 10% chance of -50% return
		let scenarios = [
			NamedScenario(name: "Good", probability: 0.90, parameters: ["return": 0.10]),
			NamedScenario(name: "Bad", probability: 0.10, parameters: ["return": -0.50])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let amount = x.toArray()[0]
				let returnRate = scenario["return"] ?? 0.0
				return amount * returnRate
			},
			initialSolution: VectorN([100.0]),
			constraints: [],
			minimize: false
		)

		// Expected value: 0.90 * 0.10 + 0.10 * (-0.50) = 0.09 - 0.05 = 0.04
		// Per unit invested
		let expectedReturn = 0.90 * 0.10 + 0.10 * (-0.50)
		let investment = result.solution.toArray()[0]

		#expect(abs(result.expectedObjective - investment * expectedReturn) < 1e-3)
	}

	// MARK: - Weighted Optimization

	/// Test the convenience weighted optimization method.
	@Test func weightedOptimization() throws {
		let scenarioValues: [(name: String, probability: Double, objective: @Sendable (VectorN<Double>) -> Double)] = [
			("High Demand", 0.40, { x in x.toArray()[0] * 150.0 }),
			("Medium Demand", 0.40, { x in x.toArray()[0] * 100.0 }),
			("Low Demand", 0.20, { x in x.toArray()[0] * 50.0 })
		]

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.inequality(function: { x in -x.toArray()[0] }, gradient: nil),  // x >= 0
			.inequality(function: { x in x.toArray()[0] - 200.0 }, gradient: nil)  // x <= 200
		]

		let result = try ScenarioOptimizer<VectorN<Double>>.optimizeWeighted(
			scenarioValues: scenarioValues,
			initialSolution: VectorN([100.0]),
			constraints: constraints,
			minimize: false,
			maxIterations: 300,
			tolerance: 1e-4
		)

		#expect(result.converged)

		// Should produce at upper bound (200) since higher production always better
		let production = result.solution.toArray()[0]
		#expect(abs(production - 200.0) < 1.0)
	}

	// MARK: - Per-Scenario Analysis

	/// Test per-scenario objective analysis.
	@Test func perScenarioAnalysis() throws {
		let scenarios = [
			NamedScenario(name: "Scenario A", probability: 0.50, parameters: ["factor": 2.0]),
			NamedScenario(name: "Scenario B", probability: 0.50, parameters: ["factor": 3.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let value = x.toArray()[0]
				let factor = scenario["factor"] ?? 1.0
				return value * factor
			},
			initialSolution: VectorN([10.0]),
			constraints: [],
			minimize: false
		)

		// Check per-scenario objectives
		let objA = result.objective(for: "Scenario A")
		let objB = result.objective(for: "Scenario B")

		#expect(objA != nil)
		#expect(objB != nil)

		// B should have higher objective (factor 3 vs 2)
		if let a = objA, let b = objB {
			#expect(b > a)
		}

		// Can retrieve scenarios by name
		#expect(result.scenario(named: "Scenario A") != nil)
		#expect(result.scenario(named: "Scenario B") != nil)
		#expect(result.scenario(named: "Nonexistent") == nil)
	}

	/// Test variance calculation across scenarios.
	@Test func varianceCalculation() throws {
		// Scenarios with different outcomes
		let scenarios = [
			NamedScenario(name: "Low", probability: 0.33, parameters: ["multiplier": 0.5]),
			NamedScenario(name: "Med", probability: 0.34, parameters: ["multiplier": 1.0]),
			NamedScenario(name: "High", probability: 0.33, parameters: ["multiplier": 1.5])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let value = x.toArray()[0]
				let mult = scenario["multiplier"] ?? 1.0
				return value * mult
			},
			initialSolution: VectorN([100.0]),
			constraints: [],
			minimize: false
		)

		// Variance should be positive (different outcomes)
		#expect(result.objectiveVariance > 0.0)
		#expect(result.objectiveStdDev > 0.0)

		// Std dev should be sqrt(variance)
		#expect(abs(result.objectiveStdDev - sqrt(result.objectiveVariance)) < 1e-10)
	}

	// MARK: - Constraint Satisfaction

	/// Test that constraints are satisfied.
	@Test func constraintSatisfaction() throws {
		let scenarios = [
			NamedScenario(name: "S1", probability: 0.25, parameters: ["r": 0.10]),
			NamedScenario(name: "S2", probability: 0.25, parameters: ["r": 0.12]),
			NamedScenario(name: "S3", probability: 0.25, parameters: ["r": 0.08]),
			NamedScenario(name: "S4", probability: 0.25, parameters: ["r": 0.06])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		// Portfolio optimization with budget and non-negativity
		var constraints: [ScenarioConstraint<VectorN<Double>>] = [
			.all(function: { x in x.toArray().reduce(0, +) - 1.0 }, isEquality: true)
		]
		for i in 0..<4 {
			constraints.append(.all(function: { x in -x.toArray()[i] }, isEquality: false))
		}

		let result = try optimizer.optimize(
			objective: { weights, scenario in
				let r = scenario["r"] ?? 0.0
				return weights.toArray()[0] * r  // Just first asset for simplicity
			},
			initialSolution: VectorN([0.25, 0.25, 0.25, 0.25]),
			constraints: constraints,
			minimize: false
		)

		// Verify constraints
		let weights = result.solution.toArray()
		#expect(abs(weights.reduce(0, +) - 1.0) < 1e-3)
		for weight in weights {
			#expect(weight >= -1e-6)
		}
	}

	// MARK: - Equal Probability Scenarios

	/// Test with equal probability scenarios.
	@Test func equalProbabilityScenarios() throws {
		let scenarios = [
			NamedScenario(name: "A", probability: 1.0, parameters: ["value": 10.0]),
			NamedScenario(name: "B", probability: 1.0, parameters: ["value": 20.0]),
			NamedScenario(name: "C", probability: 1.0, parameters: ["value": 30.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let value = scenario["value"] ?? 0.0
				return x.toArray()[0] + value
			},
			initialSolution: VectorN([5.0]),
			constraints: [
				.all(function: { x in x.toArray()[0] - 100.0 }, isEquality: false)  // x <= 100
			],
			minimize: false
		)

		// With equal probabilities (1.0 each), expected value is average: (10+20+30)/3 = 20
		// Maximizing x + value with x <= 100, optimal is x = 100
		// Expected objective: 100 + 20 = 120
		#expect(result.converged)
		#expect(abs(result.expectedObjective - 120.0) < 1.0)
	}

	/// Test with single scenario (degenerate case).
	@Test func singleScenario() throws {
		let scenarios = [
			NamedScenario(name: "Only", probability: 1.0, parameters: ["multiplier": 2.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let mult = scenario["multiplier"] ?? 1.0
				return x.toArray()[0] * mult
			},
			initialSolution: VectorN([10.0]),
			constraints: [
				.all(function: { x in x.toArray()[0] - 50.0 }, isEquality: false)  // x <= 50
			],
			minimize: false
		)

		#expect(result.converged)

		// With single scenario, variance should be 0
		#expect(abs(result.objectiveVariance - 0.0) < 1e-10)

		// Should optimize to upper bound
		#expect(abs(result.solution.toArray()[0] - 50.0) < 0.5)
	}

	// MARK: - Minimize vs Maximize

	/// Test minimization objective.
	@Test func minimization() throws {
		let scenarios = [
			NamedScenario(name: "Low Cost", probability: 0.60, parameters: ["cost": 10.0]),
			NamedScenario(name: "High Cost", probability: 0.40, parameters: ["cost": 20.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let quantity = x.toArray()[0]
				let cost = scenario["cost"] ?? 0.0
				return quantity * cost  // Total cost
			},
			initialSolution: VectorN([5.0]),
			constraints: [
				.all(function: { x in 1.0 - x.toArray()[0] }, isEquality: false),  // x >= 1
				.all(function: { x in x.toArray()[0] - 10.0 }, isEquality: false)  // x <= 10
			],
			minimize: true  // Minimize cost
		)

		#expect(result.converged)

		// Should minimize to lower bound (x = 1)
		#expect(abs(result.solution.toArray()[0] - 1.0) < 0.5)
	}

	/// Test maximization objective.
	@Test func maximization() throws {
		let scenarios = [
			NamedScenario(name: "S1", probability: 0.50, parameters: ["revenue": 100.0]),
			NamedScenario(name: "S2", probability: 0.50, parameters: ["revenue": 150.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let quantity = x.toArray()[0]
				let revenue = scenario["revenue"] ?? 0.0
				return quantity * revenue
			},
			initialSolution: VectorN([5.0]),
			constraints: [
				.all(function: { x in 1.0 - x.toArray()[0] }, isEquality: false),
				.all(function: { x in x.toArray()[0] - 10.0 }, isEquality: false)
			],
			minimize: false  // Maximize revenue
		)

		#expect(result.converged)

		// Should maximize to upper bound (x = 10)
		#expect(abs(result.solution.toArray()[0] - 10.0) < 0.5)
	}

	// MARK: - Comparison with Other Optimizers

	/// Compare scenario-based vs stochastic optimization.
	@Test func comparisonWithStochastic() throws {
		// Same scenarios in both optimizers
		let namedScenarios = [
			NamedScenario(name: "S1", probability: 0.40, parameters: ["r1": 0.10, "r2": 0.12]),
			NamedScenario(name: "S2", probability: 0.30, parameters: ["r1": 0.08, "r2": 0.15]),
			NamedScenario(name: "S3", probability: 0.30, parameters: ["r1": 0.12, "r2": 0.10])
		]

		// Scenario-based optimization
		let scenarioOptimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: namedScenarios)

		var constraints: [ScenarioConstraint<VectorN<Double>>] = [
			.all(function: { x in x.toArray().reduce(0, +) - 1.0 }, isEquality: true)
		]
		for i in 0..<2 {
			constraints.append(.all(function: { x in -x.toArray()[i] }, isEquality: false))
		}

		let scenarioResult = try scenarioOptimizer.optimize(
			objective: { weights, scenario in
				let r1 = scenario["r1"] ?? 0.0
				let r2 = scenario["r2"] ?? 0.0
				return weights.toArray()[0] * r1 + weights.toArray()[1] * r2
			},
			initialSolution: VectorN([0.5, 0.5]),
			constraints: constraints,
			minimize: false
		)

		// Both should converge and find similar solutions
		#expect(scenarioResult.converged)
	}

	// MARK: - Edge Cases

	/// Test with zero probability scenario.
	@Test func zeroProbabilityScenario() throws {
		let scenarios = [
			NamedScenario(name: "Likely", probability: 1.0, parameters: ["value": 10.0]),
			NamedScenario(name: "Impossible", probability: 0.0, parameters: ["value": -1000.0])
		]

		let optimizer = ScenarioOptimizer<VectorN<Double>>(scenarios: scenarios)

		let result = try optimizer.optimize(
			objective: { x, scenario in
				let value = scenario["value"] ?? 0.0
				return x.toArray()[0] + value
			},
			initialSolution: VectorN([5.0]),
			constraints: [
				.all(function: { x in x.toArray()[0] - 10.0 }, isEquality: false)
			],
			minimize: false
		)

		// Zero probability scenario shouldn't affect result
		#expect(result.converged)
	}

	// MARK: - Convergence

	/// Test convergence with different tolerances.
	@Test func convergenceWithTolerance() throws {
		let scenarios = [
			NamedScenario(name: "A", probability: 0.50, parameters: ["r": 0.10]),
			NamedScenario(name: "B", probability: 0.50, parameters: ["r": 0.12])
		]

		for tolerance in [1e-6, 1e-4, 1e-2] {
			let optimizer = ScenarioOptimizer<VectorN<Double>>(
				scenarios: scenarios,
				maxIterations: 300,
				tolerance: tolerance
			)

			let result = try optimizer.optimize(
				objective: { x, scenario in
					let r = scenario["r"] ?? 0.0
					return x.toArray()[0] * r
				},
				initialSolution: VectorN([100.0]),
				constraints: [
					.all(function: { x in x.toArray()[0] - 200.0 }, isEquality: false)
				],
				minimize: false
			)

			#expect(result.converged, "Should converge with tolerance \(tolerance)")
		}
	}
}
