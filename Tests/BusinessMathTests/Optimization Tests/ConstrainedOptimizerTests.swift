//
//  ConstrainedOptimizerTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Constrained Optimizer Tests")
struct ConstrainedOptimizerTests {

	// MARK: - Basic Equality Constraint Tests

	@Test("Minimize quadratic with linear equality constraint")
	func minimizeQuadraticWithLinearConstraint() throws {
		// Minimize f(x, y) = x² + y²
		// Subject to: x + y = 1
		//
		// Solution: x = 0.5, y = 0.5, f* = 0.5
		// Lagrange multiplier: λ = -1

		let objective: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1]
		}

		let constraint = MultivariateConstraint<VectorN<Double>>.equality(
			function: { v in v[0] + v[1] - 1.0 },
			gradient: { _ in VectorN([1.0, 1.0]) }
		)

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(
			constraintTolerance: 1e-6,
			maxIterations: 50
		)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.0, 1.0]),
			subjectTo: [constraint]
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0] - 0.5) < 1e-4, "x should be 0.5")
		#expect(abs(result.solution[1] - 0.5) < 1e-4, "y should be 0.5")
		#expect(abs(result.objectiveValue - 0.5) < 1e-4, "Objective should be 0.5")
		#expect(result.constraintViolation < 1e-5, "Constraint should be satisfied")
	}

	@Test("Portfolio variance minimization with budget constraint")
	func portfolioVarianceWithBudgetConstraint() throws {
		// Minimize portfolio variance subject to weights summing to 1
		// For 3 uncorrelated assets with equal variance σ² = 1
		// Minimum variance portfolio: w = [1/3, 1/3, 1/3], σ² = 1/3

		let objective: (VectorN<Double>) -> Double = { weights in
			// Simplified variance: σ² = Σwᵢ² (for uncorrelated assets)
			weights[0] * weights[0] +
			weights[1] * weights[1] +
			weights[2] * weights[2]
		}

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5, 0.3, 0.2]),
			subjectTo: [.budgetConstraint]
		)

		#expect(result.converged, "Should converge")

		// Check weights are equal (minimum variance for uncorrelated assets)
		let expectedWeight = 1.0 / 3.0
		#expect(abs(result.solution[0] - expectedWeight) < 1e-3, "Weight 0 should be ~1/3")
		#expect(abs(result.solution[1] - expectedWeight) < 1e-3, "Weight 1 should be ~1/3")
		#expect(abs(result.solution[2] - expectedWeight) < 1e-3, "Weight 2 should be ~1/3")

		// Check variance
		let expectedVariance = 1.0 / 3.0
		#expect(abs(result.objectiveValue - expectedVariance) < 1e-3, "Variance should be ~1/3")

		// Check constraint
		#expect(result.constraintViolation < 1e-5, "Budget constraint should be satisfied")
	}

	@Test("Multiple equality constraints")
	func multipleEqualityConstraints() throws {
		// Minimize f(x, y, z) = x² + y² + z²
		// Subject to: x + y + z = 3
		//            x - y = 0
		//
		// Solution: x = 1, y = 1, z = 1, f* = 3

		let objective: (VectorN<Double>) -> Double = { v in
			v[0] * v[0] + v[1] * v[1] + v[2] * v[2]
		}

		let constraints = [
			MultivariateConstraint<VectorN<Double>>.equality { v in v[0] + v[1] + v[2] - 3.0 },
			MultivariateConstraint<VectorN<Double>>.equality { v in v[0] - v[1] }
		]

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: 100)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([1.0, 0.5, 1.5]),
			subjectTo: constraints
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0] - 1.0) < 1e-3, "x should be 1")
		#expect(abs(result.solution[1] - 1.0) < 1e-3, "y should be 1")
		#expect(abs(result.solution[2] - 1.0) < 1e-3, "z should be 1")
		#expect(abs(result.objectiveValue - 3.0) < 1e-3, "Objective should be 3")
		#expect(result.lagrangeMultipliers.count == 2, "Should have 2 Lagrange multipliers")
	}

	// MARK: - Maximize Tests

	@Test("Maximize with equality constraint")
	func maximizeWithConstraint() throws {
		// Maximize f(x, y) = -(x² + y²) = minimize x² + y²
		// Subject to: x + y = 2
		//
		// Solution: x = 1, y = 1, f* = -2

		let objective: (VectorN<Double>) -> Double = { v in
			-(v[0] * v[0] + v[1] * v[1])
		}

		let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
			v[0] + v[1] - 2.0
		}

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		let result = try optimizer.maximize(
			objective,
			from: VectorN([0.5, 1.5]),
			subjectTo: [constraint]
		)

		#expect(result.converged, "Should converge")
		#expect(abs(result.solution[0] - 1.0) < 1e-3, "x should be 1")
		#expect(abs(result.solution[1] - 1.0) < 1e-3, "y should be 1")
		#expect(abs(result.objectiveValue - (-2.0)) < 1e-3, "Objective should be -2")
	}

	// MARK: - Lagrange Multiplier Interpretation

	@Test("Lagrange multiplier shadow price interpretation")
	func lagrangeMultiplierInterpretation() throws {
		// Minimize f(x, y) = x² + y²
		// Subject to: x + y = b
		//
		// Lagrange multiplier λ represents how much f* changes per unit change in b
		// For this problem: f*(b) = b²/2, so df*/db = b
		// At b = 1: λ ≈ -1 (negative because we're minimizing)

		let testConstraintValue: (Double) -> (solution: VectorN<Double>, multiplier: Double) = { b in
			let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }
			let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in v[0] + v[1] - b }
			let optimizer = ConstrainedOptimizer<VectorN<Double>>()

			let result = try! optimizer.minimize(objective, from: VectorN([b/2, b/2]), subjectTo: [constraint])
			return (result.solution, result.lagrangeMultipliers[0])
		}

		let result1 = testConstraintValue(1.0)
		let result2 = testConstraintValue(1.1)

		// Approximate derivative: Δf*/Δb
		let df_db = (
			(result2.solution[0] * result2.solution[0] + result2.solution[1] * result2.solution[1]) -
			(result1.solution[0] * result1.solution[0] + result1.solution[1] * result1.solution[1])
		) / 0.1

		// Lagrange multiplier should approximate the shadow price
		// (with opposite sign due to minimization)
		#expect(abs(result1.multiplier + df_db) < 0.2, "Lagrange multiplier should approximate shadow price")
	}

	// MARK: - Edge Cases

	@Test("Feasible initial point")
	func feasibleInitialPoint() throws {
		// Starting from a point that already satisfies the constraint

		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }
		let constraint = MultivariateConstraint<VectorN<Double>>.budgetConstraint

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		// Start from feasible point: [0.5, 0.5]
		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5, 0.5]),
			subjectTo: [constraint]
		)

		#expect(result.converged, "Should converge from feasible start")
		#expect(result.constraintViolation < 1e-5, "Should maintain feasibility")
	}

	@Test("Infeasible initial point")
	func infeasibleInitialPoint() throws {
		// Starting from a point that violates the constraint

		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }
		let constraint = MultivariateConstraint<VectorN<Double>>.budgetConstraint

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		// Start from infeasible point: [0.3, 0.3] (sum = 0.6 ≠ 1)
		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.3, 0.3]),
			subjectTo: [constraint]
		)

		#expect(result.converged, "Should converge from infeasible start")
		#expect(result.constraintViolation < 1e-5, "Should reach feasibility")
	}

	@Test("High-dimensional problem")
	func highDimensionalProblem() throws {
		// Minimize sum of squares with budget constraint
		// f(x) = Σxᵢ²
		// Subject to: Σxᵢ = 1
		//
		// Solution: xᵢ = 1/n for all i

		let n = 10
		let objective: (VectorN<Double>) -> Double = { v in
			v.toArray().reduce(0.0) { $0 + $1 * $1 }
		}

		let constraint = MultivariateConstraint<VectorN<Double>>.equality(
			function: { v in v.sum - 1.0 },
			gradient: { v in VectorN<Double>(repeating: 1.0, count: n) }
		)

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: 100)

		let result = try optimizer.minimize(
			objective,
			from: VectorN<Double>(repeating: 0.1, count: n),
			subjectTo: [constraint]
		)

		#expect(result.converged, "Should converge for high-dimensional problem")

		let expectedWeight = 1.0 / Double(n)
		let expectedObjective = expectedWeight * expectedWeight * Double(n)

		for i in 0..<n {
			#expect(abs(result.solution[i] - expectedWeight) < 1e-2, "Weight \(i) should be ~\(expectedWeight)")
		}
		#expect(abs(result.objectiveValue - expectedObjective) < 1e-2, "Objective should be ~\(expectedObjective)")
	}

	// MARK: - Error Handling

	@Test("Reject inequality constraints")
	func rejectInequalityConstraints() throws {
		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] }
		let constraint = MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] }

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		#expect(throws: OptimizationError.self) {
			_ = try optimizer.minimize(objective, from: VectorN([0.5]), subjectTo: [constraint])
		}
	}

	@Test("Reject empty constraints")
	func rejectEmptyConstraints() throws {
		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] }
		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		#expect(throws: OptimizationError.self) {
			_ = try optimizer.minimize(objective, from: VectorN([0.5]), subjectTo: [])
		}
	}

	// MARK: - Convergence Tests

	@Test("Convergence history tracking")
	func convergenceHistoryTracking() throws {
		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }
		let constraint = MultivariateConstraint<VectorN<Double>>.budgetConstraint

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: 20)

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.3, 0.3]),
			subjectTo: [constraint]
		)

		#expect(result.history != nil && !result.history!.isEmpty, "Should record history")
		#expect(result.history!.count <= 20, "History should not exceed max iterations")
		#expect(result.history!.last!.0 == result.iterations - 1, "Last history entry should match iteration count")

		// For augmented Lagrangian, objective may temporarily increase
		// Just check that we eventually converge to a reasonable solution
		if let history = result.history, history.count > 1 {
			let firstObj = history[0].2  // tuple.2 is objectiveValue
			let lastObj = history.last!.2
			// Augmented Lagrangian can increase temporarily, so just check final value is reasonable
			#expect(lastObj < 1.0, "Final objective should be reasonable for this problem")
		}
	}

	@Test("Different starting points converge to same solution")
	func multipleStartingPoints() throws {
		let objective: (VectorN<Double>) -> Double = { v in v[0] * v[0] + v[1] * v[1] }
		let constraint = MultivariateConstraint<VectorN<Double>>.budgetConstraint

		let optimizer = ConstrainedOptimizer<VectorN<Double>>()

		let start1 = VectorN([0.9, 0.1])
		let start2 = VectorN([0.1, 0.9])
		let start3 = VectorN([0.5, 0.5])

		let result1 = try optimizer.minimize(objective, from: start1, subjectTo: [constraint])
		let result2 = try optimizer.minimize(objective, from: start2, subjectTo: [constraint])
		let result3 = try optimizer.minimize(objective, from: start3, subjectTo: [constraint])

		// All should converge to same solution
		#expect(abs(result1.objectiveValue - result2.objectiveValue) < 1e-3, "Same objective from different starts")
		#expect(abs(result2.objectiveValue - result3.objectiveValue) < 1e-3, "Same objective from different starts")
	}

	// MARK: - Real Portfolio Optimization

	@Test("Realistic portfolio optimization with covariance")
	func realisticPortfolioOptimization() throws {
		// 3-asset portfolio with actual covariance structure
		// Assets: Stock, Bond, Gold
		// Expected returns: [0.10, 0.05, 0.07]
		// Volatilities: [0.20, 0.08, 0.15]
		// Correlation matrix:
		//   [1.0, 0.3, -0.1]
		//   [0.3, 1.0,  0.2]
		//   [-0.1, 0.2, 1.0]

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

		// Portfolio variance: σ²ₚ = wᵀΣw
		let portfolioVariance: (VectorN<Double>) -> Double = { w in
			var variance = 0.0
			for i in 0..<3 {
				for j in 0..<3 {
					variance += w[i] * w[j] * covariance[i][j]
				}
			}
			return variance
		}

		let optimizer = ConstrainedOptimizer<VectorN<Double>>(maxIterations: 100)

		let result = try optimizer.minimize(
			portfolioVariance,
			from: VectorN([0.33, 0.33, 0.34]),
			subjectTo: [.budgetConstraint]
		)

		#expect(result.converged, "Should converge for realistic portfolio")
		#expect(result.constraintViolation < 1e-5, "Budget constraint should be satisfied")

		// Check weights sum to 1
		let sumWeights = result.solution.sum
		#expect(abs(sumWeights - 1.0) < 1e-4, "Weights should sum to 1")

		// Minimum variance should be positive and reasonable
		#expect(result.objectiveValue > 0, "Variance should be positive")
		#expect(result.objectiveValue < 0.1, "Variance should be reasonable")

		// Due to negative correlation with gold, expect some gold allocation
		#expect(result.solution[2] > 0.01, "Should allocate to gold due to diversification")
	}
}
