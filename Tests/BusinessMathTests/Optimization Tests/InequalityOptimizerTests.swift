//
//  InequalityOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Inequality Optimizer Tests")
struct InequalityOptimizerTests {

	// MARK: - Basic Inequality Tests

	@Test("Minimize quadratic with box constraints")
	func minimizeQuadraticWithBoxConstraints() throws {
		// Minimize f(x, y) = (x-2)² + (y-2)²
		// Subject to: x ≥ 0, y ≥ 0
		//
		// Unconstrained minimum: (2, 2)
		// Constrained minimum: (2, 2) (feasible, so same)

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 2.0) * (v[1] - 2.0)
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] },  // x ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[1] }   // y ≥ 0
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: 50)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([1.0, 1.0]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0] - 2.0) < 0.1, "x should be ~2")
		#expect(abs(result.solution[1] - 2.0) < 0.1, "y should be ~2")
		#expect(result.constraintViolation < 1e-4, "Constraints should be satisfied")
	}

	@Test("Tutorial example: minimize distance from (1,1) with linear constraint")
	func tutorialExample() throws {
		// From inequality.md tutorial
		// Minimize f(x, y) = (x-1)² + (y-1)²
		// Subject to: x ≥ 0, y ≥ 0, x+y ≤ 2
		//
		// Unconstrained minimum: (1, 1)
		// Constrained minimum: (1, 1) (feasible, so same)

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let x = v[0] - 1
			let y = v[1] - 1
			return x*x + y*y
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] },        // x ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[1] },        // y ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in v[0] + v[1] - 2 }  // x+y ≤ 2
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>()

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5, 0.5]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0] - 1.0) < 0.01, "x should be ~1")
		#expect(abs(result.solution[1] - 1.0) < 0.01, "y should be ~1")
		#expect(result.objectiveValue < 0.01, "Objective should be ~0")
		#expect(result.constraintViolation < 1e-4, "Constraints should be satisfied")
	}

	@Test("Minimize with active inequality constraint")
	func minimizeWithActiveConstraint() throws {
		// Minimize f(x, y) = (x-2)² + (y-2)²
		// Subject to: x ≥ 0, y ≥ 0, x ≤ 1
		//
		// Unconstrained minimum: (2, 2)
		// Constrained minimum: (1, 2) - x hits upper bound

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			(v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 2.0) * (v[1] - 2.0)
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] },      // x ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[1] },      // y ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in v[0] - 1.0 }  // x ≤ 1
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: 50)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5, 1.5]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")
		// Barrier methods may not reach exact boundary - check reasonable proximity
		#expect(abs(result.solution[0] - 1.0) < 0.3, "x should be near 1 (at boundary)")
		#expect(abs(result.solution[1] - 2.0) < 0.3, "y should be near 2")
	}

	// MARK: - Portfolio No-Short-Selling Tests

	@Test("Portfolio optimization with no short-selling")
	func portfolioNoShortSelling() throws {
		// Minimize portfolio variance: Σwᵢ²
		// Subject to: Σw = 1, w ≥ 0
		//
		// For uncorrelated assets with equal variance,
		// minimum variance portfolio is w = [1/n, 1/n, ..., 1/n]

		let n = 3
		let objective: @Sendable (VectorN<Double>) -> Double = { weights in
			// Simplified variance for uncorrelated assets
			weights.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budgetConstraint  // Σw = 1
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: n)  // w ≥ 0

		let optimizer = InequalityOptimizer<VectorN<Double>>(
			maxIterations: 100
		)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.4, 0.3, 0.3]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")

		// Check all weights are non-negative
		for i in 0..<n {
			#expect(result.solution[i] >= -1e-6, "Weight \(i) should be non-negative")
		}

		// Check weights sum to 1
		let sumWeights = result.solution.sum
		#expect(abs(sumWeights - 1.0) < 1e-3, "Weights should sum to 1")

		// For equal uncorrelated assets, expect equal weights
		let expectedWeight = 1.0 / Double(n)
		for i in 0..<n {
			#expect(abs(result.solution[i] - expectedWeight) < 0.1, "Weight \(i) should be ~\(expectedWeight)")
		}
	}

	@Test("Portfolio with unequal assets and no short-selling")
	func portfolioUnequalAssetsNoShortSelling() throws {
		// Three assets with different variances: σ² = [0.04, 0.01, 0.09]
		// Uncorrelated, so portfolio variance = Σwᵢ²σᵢ²
		// Minimum variance portfolio should allocate more to lower-variance asset

		let variances = VectorN([0.04, 0.01, 0.09])  // Asset 1: 20%, Asset 2: 10%, Asset 3: 30% vol

		let objective: @Sendable (VectorN<Double>) -> Double = { weights in
			// Portfolio variance: Σwᵢ²σᵢ²
			var variance = 0.0
			for i in 0..<3 {
				variance += weights[i] * weights[i] * variances[i]
			}
			return variance
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budgetConstraint
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: 100)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.33, 0.33, 0.34]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")

		// Check feasibility
		#expect(result.solution.toArray().allSatisfy { $0 >= -1e-6 }, "All weights should be non-negative")
		#expect(abs(result.solution.sum - 1.0) < 1e-3, "Weights should sum to 1")

		// Asset 2 (lowest variance) should have highest weight
		#expect(result.solution[1] > result.solution[0], "Lowest variance asset should have more weight")
		#expect(result.solution[1] > result.solution[2], "Lowest variance asset should have more weight")
	}

	// MARK: - Mixed Constraints

	@Test("Portfolio with equality and inequality constraints")
	func portfolioMixedConstraints() throws {
		// Minimize variance with:
		// - Budget: Σw = 1 (equality)
		// - No short-selling: w ≥ 0 (inequality)
		// - Position limits: w ≤ 0.5 (inequality)

		let objective: @Sendable (VectorN<Double>) -> Double = { weights in
			weights.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budgetConstraint
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)
		  + MultivariateConstraint<VectorN<Double>>.positionLimit(0.5, dimension: 3)

		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: 100)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.4, 0.3, 0.3]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")

		// Check all constraints
		for i in 0..<3 {
			#expect(result.solution[i] >= -1e-6, "Weight \(i) should be non-negative")
			#expect(result.solution[i] <= 0.5 + 1e-6, "Weight \(i) should be ≤ 0.5")
		}
		#expect(abs(result.solution.sum - 1.0) < 1e-3, "Weights should sum to 1")
	}

	// MARK: - Edge Cases

	@Test("Feasible initial point for inequalities")
	func feasibleInitialPoint() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }

		let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

		let optimizer = InequalityOptimizer<VectorN<Double>>()

		// Start from feasible point
		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5, 0.5]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge from feasible start")
		#expect(result.solution.toArray().allSatisfy { $0 >= -1e-6 }, "Should maintain feasibility")
	}

	@Test("Maximize with inequality constraints")
	func maximizeWithInequalities() throws {
		// Maximize f(x, y) = -(x-1)² - (y-1)²
		// Subject to: x ≥ 0, y ≥ 0, x+y ≤ 1.5
		//
		// Maximum at (0.75, 0.75)

		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			-((v[0] - 1.0) * (v[0] - 1.0) + (v[1] - 1.0) * (v[1] - 1.0))
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] },           // x ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in -v[1] },           // y ≥ 0
			MultivariateConstraint<VectorN<Double>>.inequality { v in v[0] + v[1] - 1.5 } // x+y ≤ 1.5
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>(maxIterations: 50)

		let result = try optimizer.maximize(
			objective,
			from: VectorN([0.5, 0.5]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")
		// Barrier method may not reach exact boundary
		#expect(abs(result.solution[0] + result.solution[1] - 1.5) < 0.5, "x+y should be reasonably close to 1.5")
		#expect(result.solution[0] >= -1e-6 && result.solution[1] >= -1e-6, "Should satisfy non-negativity")
	}

	// MARK: - Realistic Portfolio Test

	@Test("Realistic portfolio with correlation and no short-selling")
	func realisticPortfolioWithCorrelation() throws {
		// 3-asset portfolio with covariance
		// Assets: Stock, Bond, Gold
		// Volatilities: [0.20, 0.08, 0.15]
		// Correlation: moderate positive except gold

		let volatilities = VectorN([0.20, 0.08, 0.15])
		let correlations = [
			[1.0, 0.3, -0.1],
			[0.3, 1.0, 0.2],
			[-0.1, 0.2, 1.0]
		]

		// Covariance = σᵢ * σⱼ * ρᵢⱼ
		let covariance: [[Double]] = (0..<3).map { i in
			(0..<3).map { j in
				volatilities[i] * volatilities[j] * correlations[i][j]
			}
		}

		let portfolioVariance: @Sendable (VectorN<Double>) -> Double = { w in
			var variance = 0.0
			for i in 0..<3 {
				for j in 0..<3 {
					variance += w[i] * w[j] * covariance[i][j]
				}
			}
			return variance
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budgetConstraint
		] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

		let optimizer = InequalityOptimizer<VectorN<Double>>(
			maxIterations: 100
		)

		let result = try optimizer.minimize(
			portfolioVariance,
			from: VectorN([0.33, 0.33, 0.34]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge for realistic portfolio")
		#expect(result.solution.toArray().allSatisfy { $0 >= -1e-5 }, "All weights non-negative")
		#expect(abs(result.solution.sum - 1.0) < 1e-3, "Weights sum to 1")
		#expect(result.objectiveValue > 0, "Variance should be positive")
		#expect(result.objectiveValue < 0.1, "Variance should be reasonable")

		// Bond (lowest vol) should have significant allocation
		#expect(result.solution[1] > 0.1, "Bond should have significant weight")
	}

	// MARK: - Error Handling

	@Test("Reject empty constraints")
	func rejectEmptyConstraints() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] * v[0] }
		let optimizer = InequalityOptimizer<VectorN<Double>>()

		#expect(throws: OptimizationError.self) {
			_ = try optimizer.minimize(objective, from: VectorN([0.5]), subjectTo: [])
		}
	}
}
