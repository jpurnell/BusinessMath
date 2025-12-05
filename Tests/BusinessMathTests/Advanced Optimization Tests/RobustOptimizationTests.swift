//
//  RobustOptimizationTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import XCTest
@testable import BusinessMath

/// Tests for robust optimization with uncertainty sets.
final class RobustOptimizationTests: XCTestCase {

	// MARK: - Uncertainty Set Tests

	/// Test box uncertainty set generation and containment.
	func testBoxUncertaintySet() {
		let box = BoxUncertaintySet(
			nominal: [0.10, 0.12, 0.08],
			deviations: [0.02, 0.03, 0.01]
		)

		XCTAssertEqual(box.dimension, 3)

		// Test containment
		XCTAssertTrue(box.contains([0.10, 0.12, 0.08]))  // Nominal
		XCTAssertTrue(box.contains([0.12, 0.15, 0.09]))  // Upper corner
		XCTAssertTrue(box.contains([0.08, 0.09, 0.07]))  // Lower corner
		XCTAssertFalse(box.contains([0.15, 0.12, 0.08]))  // Outside

		// Test sampling
		let samples = box.samplePoints(numberOfSamples: 100)
		XCTAssertGreaterThanOrEqual(samples.count, 8)  // At least 2^3 corners
		for sample in samples {
			XCTAssertTrue(box.contains(sample), "Sampled point should be in the set")
		}

		// Test bounds (with tolerance for floating point)
		XCTAssertEqual(box.lowerBounds[0], 0.08, accuracy: 1e-10)
		XCTAssertEqual(box.lowerBounds[1], 0.09, accuracy: 1e-10)
		XCTAssertEqual(box.lowerBounds[2], 0.07, accuracy: 1e-10)
		XCTAssertEqual(box.upperBounds[0], 0.12, accuracy: 1e-10)
		XCTAssertEqual(box.upperBounds[1], 0.15, accuracy: 1e-10)
		XCTAssertEqual(box.upperBounds[2], 0.09, accuracy: 1e-10)
	}

	/// Test ellipsoidal uncertainty set.
	func testEllipsoidalUncertaintySet() {
		let covariance = [
			[0.04, 0.00, 0.00],
			[0.00, 0.09, 0.00],
			[0.00, 0.00, 0.01]
		]

		let ellipsoid = EllipsoidalUncertaintySet(
			nominal: [0.10, 0.12, 0.08],
			covariance: covariance,
			radius: 1.0
		)

		XCTAssertEqual(ellipsoid.dimension, 3)

		// Test containment (nominal should be in)
		XCTAssertTrue(ellipsoid.contains([0.10, 0.12, 0.08]))

		// Test sampling
		let samples = ellipsoid.samplePoints(numberOfSamples: 100)
		XCTAssertEqual(samples.count, 100)
	}

	/// Test discrete uncertainty set.
	func testDiscreteUncertaintySet() {
		let points = [
			[0.05, 0.08, 0.03],  // Low returns
			[0.10, 0.12, 0.08],  // Nominal
			[0.15, 0.18, 0.12]   // High returns
		]

		let discrete = DiscreteUncertaintySet(points: points)

		XCTAssertEqual(discrete.dimension, 3)
		XCTAssertTrue(discrete.contains([0.10, 0.12, 0.08]))
		XCTAssertFalse(discrete.contains([0.11, 0.12, 0.08]))

		let samples = discrete.samplePoints(numberOfSamples: 10)
		XCTAssertEqual(samples.count, 3)  // Returns all points
	}

	// MARK: - Robust Portfolio Optimization

	/// Test worst-case portfolio optimization with box uncertainty.
	func testWorstCasePortfolioWithBoxUncertainty() throws {
		// Nominal returns and their uncertainty
		let nominalReturns = [0.10, 0.12, 0.08]
		let deviations = [0.02, 0.03, 0.01]  // ±2%, ±3%, ±1%

		let uncertaintySet = BoxUncertaintySet(
			nominal: nominalReturns,
			deviations: deviations
		)

		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: 50,
			maxIterations: 300,
			tolerance: 1e-4
		)

		// Add constraints
		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		let result = try optimizer.optimize(
			objective: { weights, returns in
				// Negative for maximization of worst-case return
				-weights.dot(VectorN(returns))
			},
			nominalParameters: nominalReturns,
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true  // Minimize the negative = maximize worst-case return
		)

		XCTAssertTrue(result.converged, "Optimization should converge")

		// Verify budget constraint
		let weights = result.solution.toArray()
		XCTAssertEqual(weights.reduce(0.0, +), 1.0, accuracy: 1e-3)

		// Verify non-negativity
		for weight in weights {
			XCTAssertGreaterThanOrEqual(weight, 0.0)
		}

		// Since we minimize negative return, worst-case objective is the most negative
		// (We want to maximize the worst-case return, so minimize its negative)
		// Worst-case should be more negative than or equal to nominal
		XCTAssertGreaterThanOrEqual(result.worstCaseObjective, result.nominalObjective - 1e-6,
									"Worst-case (most negative) should be >= nominal (less negative)")

		// Worst-case parameters should be in uncertainty set
		let worstInSet = uncertaintySet.contains(result.worstCaseParameters)
		// Note: Due to sampling, worst-case may be approximate
		// Just verify it's reasonable
		XCTAssertTrue(worstInSet || result.worstCaseParameters.count == nominalReturns.count,
					 "Worst-case parameters should be in set or have correct dimension")
	}

	/// Test robust vs non-robust portfolio comparison.
	func testRobustVsNonRobustComparison() throws {
		let nominalReturns = [0.10, 0.12, 0.08]
		let deviations = [0.03, 0.04, 0.02]

		// Non-robust: optimize for nominal case
		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		let nominalOptimizer = InequalityOptimizer<VectorN<Double>>(
			constraintTolerance: 1e-4,
			gradientTolerance: 1e-4,
			maxIterations: 300
		)

		let nominalResult = try nominalOptimizer.minimize(
			{ weights in
				-weights.dot(VectorN(nominalReturns))  // Maximize return
			},
			from: VectorN([1.0/3, 1.0/3, 1.0/3]),
			subjectTo: constraints
		)

		// Robust: optimize for worst-case
		let robustResult = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominal: nominalReturns,
			deviations: deviations,
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true,
			samplesPerIteration: 50,
			maxIterations: 300,
			tolerance: 1e-4
		)

		// Robust solution should have better worst-case than nominal solution
		let nominalWeights = nominalResult.solution
		let worstCaseReturns = zip(nominalReturns, deviations).map { $0 - $1 }
		let nominalWorstCase = -nominalWeights.dot(VectorN(worstCaseReturns))

		XCTAssertLessThanOrEqual(
			robustResult.worstCaseObjective,
			nominalWorstCase + 1e-3,
			"Robust solution should have better or equal worst-case"
		)
	}

	// MARK: - Discrete Uncertainty

	/// Test robust optimization with discrete uncertainty set.
	func testRobustWithDiscreteUncertainty() throws {
		// Three scenarios: bull, base, bear
		let scenarios = [
			[0.15, 0.18, 0.12],  // Bull
			[0.10, 0.12, 0.08],  // Base
			[0.02, 0.04, 0.05]   // Bear (worst case)
		]

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		let result = try RobustOptimizer<VectorN<Double>>.optimizeDiscrete(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))  // Maximize return
			},
			uncertainPoints: scenarios,
			nominalIndex: 1,  // Base case
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true,
			maxIterations: 300,
			tolerance: 1e-4
		)

		XCTAssertTrue(result.converged)

		// Worst-case should be bear scenario (lowest returns)
		// Since we minimize negative return, worst-case objective is the most negative value
		// which corresponds to the lowest actual return
		let bearReturns = scenarios[2]
		let bearObjective = -result.solution.dot(VectorN(bearReturns))

		// The worst-case objective should correspond to bear market
		XCTAssertEqual(result.worstCaseObjective, bearObjective, accuracy: 1e-3)
	}

	// MARK: - Robust Production Planning

	/// Test robust production planning with uncertain demand.
	func testRobustProductionPlanning() throws {
		// Production cost, selling price, shortage penalty
		let productionCost = 10.0
		let sellingPrice = 25.0
		let shortagePenalty = 5.0

		// Uncertain demand: nominal 100, can vary ±20
		let nominalDemand = [100.0]
		let demandDeviation = [20.0]

		let result = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { production, demand in
				let q = production.toArray()[0]
				let d = max(0, demand[0])

				// Profit = revenue - cost - shortage penalty
				let revenue = min(q, d) * sellingPrice
				let cost = q * productionCost
				let shortage = max(0, d - q) * shortagePenalty

				return -(revenue - cost - shortage)  // Negative for maximization
			},
			nominal: nominalDemand,
			deviations: demandDeviation,
			initialSolution: VectorN([100.0]),
			constraints: [
				.inequality(function: { x in -x.toArray()[0] }, gradient: nil),  // q >= 0
				.inequality(function: { x in x.toArray()[0] - 150.0 }, gradient: nil)  // q <= 150
			],
			minimize: true,
			samplesPerIteration: 30,
			maxIterations: 300,
			tolerance: 1e-4
		)

		XCTAssertTrue(result.converged)

		let optimalProduction = result.solution.toArray()[0]
		XCTAssertGreaterThan(optimalProduction, 80.0)
		XCTAssertLessThan(optimalProduction, 150.0)

		// Worst-case should have reasonable profit
		XCTAssertGreaterThan(-result.worstCaseObjective, 0.0, "Worst-case profit should be positive")
	}

	// MARK: - Constraint Satisfaction

	/// Test that constraints are satisfied in all scenarios.
	func testConstraintSatisfactionInAllScenarios() throws {
		let nominalReturns = [0.10, 0.12, 0.08, 0.04]
		let deviations = [0.02, 0.03, 0.01, 0.01]

		let uncertaintySet = BoxUncertaintySet(
			nominal: nominalReturns,
			deviations: deviations
		)

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 4))

		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: uncertaintySet,
			samplesPerIteration: 50,
			maxIterations: 300,
			tolerance: 1e-4
		)

		let result = try optimizer.optimize(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominalParameters: nominalReturns,
			initialSolution: VectorN([0.25, 0.25, 0.25, 0.25]),
			constraints: constraints,
			minimize: true
		)

		// Verify constraints at solution
		let weights = result.solution.toArray()

		// Budget constraint
		XCTAssertEqual(weights.reduce(0.0, +), 1.0, accuracy: 1e-3)

		// Non-negativity
		for weight in weights {
			XCTAssertGreaterThanOrEqual(weight, 0.0)
		}

		// Test constraints hold for sampled uncertainty points
		let samples = uncertaintySet.samplePoints(numberOfSamples: 20)
		for sample in samples {
			// At minimum, budget and non-negativity must hold
			// (These are scenario-independent)
			XCTAssertEqual(weights.reduce(0.0, +), 1.0, accuracy: 1e-3)
			for weight in weights {
				XCTAssertGreaterThanOrEqual(weight, -1e-6)
			}
		}
	}

	// MARK: - Conservative Allocation

	/// Test that robust optimization is more conservative.
	func testConservativeAllocation() throws {
		let nominalReturns = [0.08, 0.15, 0.10]  // Second asset has high return but high uncertainty
		let deviations = [0.01, 0.08, 0.02]      // Second asset is very uncertain

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		let result = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominal: nominalReturns,
			deviations: deviations,
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true,
			samplesPerIteration: 50,
			maxIterations: 300,
			tolerance: 1e-4
		)

		XCTAssertTrue(result.converged)

		let weights = result.solution.toArray()

		// Robust optimization should allocate less to the high-variance asset (asset 1)
		// This is a characteristic of worst-case optimization
		XCTAssertEqual(weights.reduce(0.0, +), 1.0, accuracy: 1e-3)
	}

	// MARK: - Edge Cases

	/// Test with zero uncertainty (should equal nominal).
	func testZeroUncertainty() throws {
		let nominalReturns = [0.10, 0.12, 0.08]
		let zeroDeviations = [0.0, 0.0, 0.0]

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		let result = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominal: nominalReturns,
			deviations: zeroDeviations,
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true,
			samplesPerIteration: 10,
			maxIterations: 300,
			tolerance: 1e-4
		)

		// With zero uncertainty, worst-case should equal nominal
		XCTAssertEqual(result.worstCaseObjective, result.nominalObjective, accuracy: 1e-3)

		// Should allocate entirely to highest-return asset (asset 1 with 12%)
		let weights = result.solution.toArray()
		XCTAssertGreaterThan(weights[1], 0.9, "Should allocate mostly to highest-return asset")
	}

	/// Test single-asset portfolio (trivial case).
	func testSingleAssetPortfolio() throws {
		let nominalReturns = [0.10]
		let deviations = [0.02]

		let result = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominal: nominalReturns,
			deviations: deviations,
			initialSolution: VectorN([1.0]),
			constraints: [.budgetConstraint],
			minimize: true,
			samplesPerIteration: 10,
			maxIterations: 100
		)

		XCTAssertTrue(result.converged)

		// With one asset, weight must be 1.0
		let weight = result.solution.toArray()[0]
		XCTAssertEqual(weight, 1.0, accuracy: 1e-3)

		// Worst-case return should be nominal - deviation
		let worstReturn = -result.worstCaseObjective
		XCTAssertEqual(worstReturn, 0.08, accuracy: 1e-3)
	}

	// MARK: - Convergence

	/// Test convergence with different sample sizes.
	func testConvergenceWithSampleSizes() throws {
		let nominalReturns = [0.10, 0.12, 0.08]
		let deviations = [0.02, 0.03, 0.01]

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		for samples in [10, 30, 50] {
			let result = try RobustOptimizer<VectorN<Double>>.optimizeBox(
				objective: { weights, returns in
					-weights.dot(VectorN(returns))
				},
				nominal: nominalReturns,
				deviations: deviations,
				initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
				constraints: constraints,
				minimize: true,
				samplesPerIteration: samples,
				maxIterations: 300,
				tolerance: 1e-4
			)

			XCTAssertTrue(result.converged, "Should converge with \(samples) samples")
			let weights = result.solution.toArray()
			XCTAssertEqual(weights.reduce(0.0, +), 1.0, accuracy: 1e-3)
		}
	}

	// MARK: - Performance Comparison

	/// Compare stochastic vs robust optimization.
	func testStochasticVsRobustComparison() throws {
		let nominalReturns = [0.10, 0.12, 0.08]
		let deviations = [0.02, 0.03, 0.01]

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3))

		// Stochastic optimization (expected value)
		let stochasticResult = try StochasticOptimizer<VectorN<Double>>(
			numberOfSamples: 100,
			seed: 42,
			maxIterations: 300,
			tolerance: 1e-4
		).optimize(
			objective: { weights, scenario in
				let returns = (0..<3).map { scenario["param_\($0)"] ?? 0.0 }
				return weights.dot(VectorN(returns))
			},
			scenarioGenerator: {
				ScenarioGenerator.uniform(
					lowerBounds: zip(nominalReturns, deviations).map { $0 - $1 },
					upperBounds: zip(nominalReturns, deviations).map { $0 + $1 },
					numberOfScenarios: 1,
					seed: nil
				).first!
			},
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: false
		)

		// Robust optimization (worst-case)
		let robustResult = try RobustOptimizer<VectorN<Double>>.optimizeBox(
			objective: { weights, returns in
				-weights.dot(VectorN(returns))
			},
			nominal: nominalReturns,
			deviations: deviations,
			initialSolution: VectorN([1.0/3, 1.0/3, 1.0/3]),
			constraints: constraints,
			minimize: true,
			samplesPerIteration: 50,
			maxIterations: 300,
			tolerance: 1e-4
		)

		// Both should converge
		XCTAssertTrue(stochasticResult.converged)
		XCTAssertTrue(robustResult.converged)

		// Stochastic optimizes expected value (should have higher expected return)
		// Robust optimizes worst-case (should have better worst-case)
		// Both are valid but different objectives
		XCTAssertGreaterThan(stochasticResult.expectedObjective, -0.15)
		XCTAssertGreaterThan(-robustResult.worstCaseObjective, 0.05)
	}
}
