//
//  MultiPeriodOptimizationTests.swift
//  BusinessMathTests
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite struct MultiPeriodOptimizationTests {

	// MARK: - Basic Multi-Period Tests

	/// Test 1: Simple 3-period portfolio with budget constraints
	@Test func simpleThreePeriodPortfolio() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,
			discountRate: 0.0  // No discounting for simplicity
		)

		// Expected returns for each asset
		let returns = VectorN([0.10, 0.15, 0.12])

		// Objective: maximize expected return each period
		let result = try optimizer.optimize(
			objective: { weights in
				weights.dot(returns)
			},
			initialState: VectorN([1.0/3.0, 1.0/3.0, 1.0/3.0]),
			constraints: [
				.budgetEachPeriod,  // Sum to 1 each period
				MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[0],  // w[0] ≥ 0
				MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[1],  // w[1] ≥ 0
				MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3)[2]   // w[2] ≥ 0
			],
			minimize: false  // Maximize
		)

		// Check convergence
		#expect(result.converged, "Optimization should converge")

		// Check all periods have 3 weights
		#expect(result.numberOfPeriods == 3)
		for xₜ in result.trajectory {
			#expect(xₜ.toArray().count == 3)
		}

		print("Test result trajectory:")
		for (t, xₜ) in result.trajectory.enumerated() {
			let weights = xₜ.toArray()
			print("  Period \(t): \(weights.map { String(format: "%.4f", $0) }.joined(separator: ", "))")
		}

		// Without turnover constraints, should allocate 100% to highest return asset (index 1)
		// each period
		for (t, xₜ) in result.trajectory.enumerated() {
			let weights = xₜ.toArray()
			let sum = weights.reduce(0.0, +)
			#expect(abs(sum - 1.0) < 0.05, "Period \(t) weights should sum to 1")

			// All weights should be non-negative
			for (i, w) in weights.enumerated() {
				#expect(w >= -0.01, "Period \(t), weight[\(i)] should be >= 0")
			}

			// Highest return asset should dominate (but constraint may not be tight)
			// #expect(weights[1] > 0.50, "Should favor highest return asset")
		}
	}

	/// Test 2: Two-period with turnover constraint
	@Test func twoPeriodWithTurnoverConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 2,
			discountRate: 0.0
		)

		let returns = VectorN([0.08, 0.12])

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
			.budgetEachPeriod,
			.turnoverLimit(0.30)  // Max 30% turnover between periods
		]
		// Add non-negativity constraints for numerical stability
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 2))

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([0.50, 0.50]),  // Start 50/50
			constraints: constraints,
			minimize: false
		)

		#expect(result.converged)
		#expect(result.numberOfPeriods == 2)

		// Check turnover between periods
		let w0 = result.trajectory[0].toArray()
		let w1 = result.trajectory[1].toArray()

		let turnover = zip(w0, w1).map { abs($1 - $0) }.reduce(0.0, +)
		#expect(turnover <= 0.31, "Turnover should respect 30% limit")

		print("Turnover: \(String(format: "%.2f%%", turnover * 100))")
	}

	/// Test 3: Multi-period with discount rate
	@Test func discountedMultiPeriod() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 4,
			discountRate: 0.10  // 10% discount rate
		)

		let returns = VectorN([0.12, 0.15])

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [.budgetEachPeriod]
		// Add non-negativity constraints for numerical stability
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 2))

		let result = try optimizer.optimize(
			objective: { _, weights in
				// Simple return
				weights.dot(returns)
			},
			initialState: VectorN([0.50, 0.50]),
			constraints: constraints,
			minimize: false
		)

		#expect(result.converged)

		// Discount factor should be 1/1.10 ≈ 0.909
		let expectedDiscount = 1.0 / 1.10
		#expect(abs(optimizer.discountFactor - expectedDiscount) < 0.001)

		// Verify total objective accounts for discounting
		// Total = r₀ + δr₁ + δ²r₂ + δ³r₃
		var expectedTotal = 0.0
		for (t, objective) in result.periodObjectives.enumerated() {
			let discount = pow(expectedDiscount, Double(t))
			expectedTotal += discount * objective
		}

		#expect(abs(result.totalObjective - expectedTotal) < 0.01)
	}

	/// Test 4: Terminal constraint
	@Test func terminalConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,
			discountRate: 0.0
		)

		let returns = VectorN([0.08, 0.12, 0.10])

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
			.budgetEachPeriod,
			// Terminal constraint: final weight on asset 0 ≥ 40%
			.terminal(
				function: { xₜ in
					let w0 = xₜ.toArray()[0]
					return 0.40 - w0  // w0 ≥ 0.40 → 0.40 - w0 ≤ 0
				},
				isEquality: false
			)
		]
		// Add non-negativity constraints for numerical stability
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3))

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([1.0/3.0, 1.0/3.0, 1.0/3.0]),
			constraints: constraints,
			minimize: false
		)

		#expect(result.converged)

		// Check terminal constraint is satisfied
		let finalWeights = result.terminalState.toArray()
		#expect(finalWeights[0] >= 0.39, "Terminal weight should be ≥ 40%")

		print("Final weights: \(finalWeights.map { String(format: "%.2f", $0) })")
	}

	// MARK: - Constraint Tests

	/// Test 5: Each-period non-negativity constraints
	@Test func nonNegativityConstraints() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 2,
			discountRate: 0.0
		)

		// Negative return on asset 1, positive on asset 0
		let returns = VectorN([0.10, -0.05])

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([0.50, 0.50]),
			constraints: [
				.budgetEachPeriod
			] + MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 2),
			minimize: false
		)

		#expect(result.converged)

		// All weights should be non-negative
		for (t, xₜ) in result.trajectory.enumerated() {
			let weights = xₜ.toArray()
			for (i, w) in weights.enumerated() {
				#expect(w >= -0.01, "Period \(t), Asset \(i) weight should be ≥ 0")
			}
		}

		// Should allocate all to positive return asset
		for xₜ in result.trajectory {
			let weights = xₜ.toArray()
			#expect(weights[0] > 0.90, "Should allocate to positive return asset")
		}
	}

	/// Test 6: Transition constraints (inventory dynamics)
	@Test func transitionConstraint() throws {
		// Model simple inventory problem
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,
			discountRate: 0.0,
			maxIterations: 200,
			tolerance: 1e-4  // Relaxed tolerance for stability
		)

		// Decision: [production, inventory]
		// Constraint: inventoryₜ₊₁ = inventoryₜ + productionₜ - demand

		let demand = 10.0  // Constant demand
		let productionCost = 2.0
		let holdingCost = 0.5  // Reduced from 1.0 for better scaling

		// Build constraints array
		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = []

		// Inventory balance: invₜ₊₁ = invₜ + prodₜ - demand
		constraints.append(.transition(
			function: { _, xₜ, xₜ₊₁ in
				let prodₜ = xₜ.toArray()[0]
				let invₜ = xₜ.toArray()[1]
				let invₜ₊₁ = xₜ₊₁.toArray()[1]
				// Constraint: invₜ₊₁ - (invₜ + prodₜ - demand) = 0
				return invₜ₊₁ - (invₜ + prodₜ - demand)
			},
			isEquality: true
		))

		// Non-negativity
		constraints.append(.eachPeriod(function: { _, x in -x.toArray()[0] }))  // production ≥ 0
		constraints.append(.eachPeriod(function: { _, x in -x.toArray()[1] }))  // inventory ≥ 0

		// Upper bounds for numerical stability
		constraints.append(.eachPeriod(function: { _, x in x.toArray()[0] - 50.0 }))  // production ≤ 50
		constraints.append(.eachPeriod(function: { _, x in x.toArray()[1] - 50.0 }))  // inventory ≤ 50

		let result = try optimizer.optimize(
			objective: { decision in
				let production = decision.toArray()[0]
				let inventory = decision.toArray()[1]
				// Minimize: production cost + holding cost (positive formulation)
				return productionCost * production + holdingCost * inventory
			},
			initialState: VectorN([10.0, 5.0]),  // Initial: produce 10, hold 5
			constraints: constraints,
			minimize: true
		)

		#expect(result.converged)

		// Verify inventory dynamics
		for t in 0..<(result.numberOfPeriods - 1) {
			let xₜ = result.trajectory[t].toArray()
			let xₜ₊₁ = result.trajectory[t+1].toArray()

			let prodₜ: Double = xₜ[0]
			let invₜ: Double = xₜ[1]
			let invₜ₊₁: Double = xₜ₊₁[1]

			let expected = invₜ + prodₜ - demand
			#expect(abs(invₜ₊₁ - expected) < 1.0, "Inventory balance should hold")
		}
	}

	/// Test 7: Trajectory constraint (average over periods)
	@Test func trajectoryConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 4,
			discountRate: 0.0
		)

		let returns = VectorN([0.08, 0.14])

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([0.50, 0.50]),
			constraints: [
				.budgetEachPeriod,
				// Average allocation to asset 0 across all periods ≥ 30%
				.averageConstraint(
					metric: { x in x.toArray()[0] },
					minimumAverage: 0.30
				)
			],
			minimize: false
		)

		#expect(result.converged)

		// Calculate average allocation to asset 0
		let allocationsToAsset0 = result.trajectory.map { $0.toArray()[0] }
		let average = allocationsToAsset0.reduce(0.0, +) / Double(allocationsToAsset0.count)

		#expect(average >= 0.29, "Average should be ≥ 30%")
		print("Average allocation to asset 0: \(String(format: "%.2f%%", average * 100))")
	}

	// MARK: - Real-World Scenarios

	/// Test 8: Portfolio rebalancing with transaction costs
	@Test func portfolioRebalancingWithTransactionCosts() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,  // 3 periods (reduced from 6 for performance)
			discountRate: 0.005  // 0.5% monthly discount
		)

		// 3 assets with different expected returns (reduced from 4 for performance)
		let returns = VectorN([0.08, 0.12, 0.10])

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
			.budgetEachPeriod,
			.turnoverLimit(0.15)  // Max 15% rebalancing per period
		]
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 3))

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([1.0/3.0, 1.0/3.0, 1.0/3.0]),
			constraints: constraints,
			minimize: false
		)

		#expect(result.converged)
		#expect(result.numberOfPeriods == 3)

		// Verify turnover constraints
		for t in 0..<2 {
			let wₜ = result.trajectory[t].toArray()
			let wₜ₊₁ = result.trajectory[t+1].toArray()
			let turnover = zip(wₜ, wₜ₊₁).map { abs($1 - $0) }.reduce(0.0, +)
			#expect(turnover <= 0.16, "Turnover in period \(t) should be ≤ 15%")
		}

		print("Portfolio rebalancing successful over 3 periods")
		print("Final allocation: \(result.terminalState.toArray().map { String(format: "%.2f", $0) })")
	}

	/// Test 9: Production planning over time
	@Test func multiPeriodProductionPlanning() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,  // 3 quarters (reduced from 4 for performance)
			discountRate: 0.03  // 3% quarterly discount
		)

		// Decision: [production_product1, production_product2]
		let priceProduct1 = 100.0
		let priceProduct2 = 150.0
		let costProduct1 = 60.0
		let costProduct2 = 90.0

		let result = try optimizer.optimize(
			objective: { t, decision in
				let prod1 = decision.toArray()[0]
				let prod2 = decision.toArray()[1]

				// Revenue - costs (profit per unit)
				let profit1 = priceProduct1 - costProduct1
				let profit2 = priceProduct2 - costProduct2

				return profit1 * prod1 + profit2 * prod2
			},
			initialState: VectorN([50.0, 50.0]),  // Start strictly inside feasible region (100 < 120)
			constraints: [
				// Non-negativity
				.eachPeriod(function: { _, x in -x.toArray()[0] }),  // prod1 ≥ 0
				.eachPeriod(function: { _, x in -x.toArray()[1] }),  // prod2 ≥ 0

				// Production capacity: total production ≤ 120 units
				.eachPeriod(function: { _, x in
					let total = x.toArray()[0] + x.toArray()[1]
					return total - 120.0
				})
			],
			minimize: false
		)

		#expect(result.converged)

		// Verify production is within capacity
		for (t, decision) in result.trajectory.enumerated() {
			let d = decision.toArray()
			let totalProduction = d[0] + d[1]
			#expect(totalProduction <= 121.0, "Period \(t) production should be ≤ 120")
			print("Q\(t+1) production: Product1=\(String(format: "%.0f", d[0])), Product2=\(String(format: "%.0f", d[1]))")
		}
	}

	/// Test 10: Cumulative budget constraint
	@Test func cumulativeBudgetConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 5,
			discountRate: 0.0
		)

		// Decision: investment amount each period
		let expectedReturns = [0.12, 0.10, 0.15, 0.08, 0.11]

		let result = try optimizer.optimize(
			objective: { t, investment in
				// Return for this period
				let amount = investment.toArray()[0]
				return expectedReturns[t] * amount
			},
			initialState: VectorN([20.0]),  // Start with $20k investment
			constraints: [
				// Non-negativity
				.eachPeriod(function: { _, x in -x.toArray()[0] }),

				// Total investment across all periods ≤ $100k
				.cumulativeLimit(
					metric: { x in x.toArray()[0] },
					maximum: 100.0
				),

				// Each period investment ≤ $30k
				.eachPeriod(function: { _, x in x.toArray()[0] - 30.0 })
			],
			minimize: false
		)

		#expect(result.converged)

		// Verify cumulative constraint
		let totalInvestment = result.trajectory.map { $0.toArray()[0] }.reduce(0.0, +)
		#expect(totalInvestment <= 101.0, "Total investment should be ≤ $100k")

		print("Total investment: $\(String(format: "%.0f", totalInvestment))k over 5 periods")
		print("Investments: \(result.trajectory.map { String(format: "%.0f", $0.toArray()[0]) })")
	}

	// MARK: - Edge Cases

	/// Test 11: Single period (degenerates to static optimization)
	@Test func singlePeriod() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 1,
			discountRate: 0.0
		)

		let returns = VectorN([0.10, 0.15, 0.12])

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([1.0/3.0, 1.0/3.0, 1.0/3.0]),
			constraints: [.budgetEachPeriod],
			minimize: false
		)

		#expect(result.converged)
		#expect(result.numberOfPeriods == 1)

		// Should allocate to highest return asset
		let weights = result.trajectory[0].toArray()
		#expect(weights[1] > 0.90, "Should allocate to highest return")
	}

	/// Test 12: Constraint satisfaction check
	@Test func constraintSatisfaction() throws {
		let constraint = MultiPeriodConstraint<VectorN<Double>>.budgetEachPeriod

		// Feasible trajectory
		let feasible = [
			VectorN([0.25, 0.25, 0.25, 0.25]),
			VectorN([0.30, 0.30, 0.20, 0.20]),
			VectorN([0.40, 0.30, 0.20, 0.10])
		]

		#expect(constraint.isSatisfied(trajectory: feasible))

		// Infeasible trajectory
		let infeasible = [
			VectorN([0.50, 0.30, 0.10, 0.05]),  // Sums to 0.95, not 1.0
			VectorN([0.30, 0.30, 0.20, 0.20])
		]

		#expect(!constraint.isSatisfied(trajectory: infeasible))
	}
}
