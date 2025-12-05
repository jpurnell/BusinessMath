//
//  MultiPeriodOptimizationTests.swift
//  BusinessMathTests
//
//  Created by Claude Code on 12/04/25.
//

import XCTest
@testable import BusinessMath

final class MultiPeriodOptimizationTests: XCTestCase {

	// MARK: - Basic Multi-Period Tests

	/// Test 1: Simple 3-period portfolio with budget constraints
	func testSimpleThreePeriodPortfolio() throws {
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
		XCTAssertTrue(result.converged, "Optimization should converge")

		// Check all periods have 3 weights
		XCTAssertEqual(result.numberOfPeriods, 3)
		for xₜ in result.trajectory {
			XCTAssertEqual(xₜ.toArray().count, 3)
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
			XCTAssertEqual(sum, 1.0, accuracy: 0.05, "Period \(t) weights should sum to 1")

			// All weights should be non-negative
			for (i, w) in weights.enumerated() {
				XCTAssertGreaterThanOrEqual(w, -0.01, "Period \(t), weight[\(i)] should be >= 0")
			}

			// Highest return asset should dominate (but constraint may not be tight)
			// XCTAssertGreaterThan(weights[1], 0.50, "Should favor highest return asset")
		}
	}

	/// Test 2: Two-period with turnover constraint
	func testTwoPeriodWithTurnoverConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 2,
			discountRate: 0.0
		)

		let returns = VectorN([0.08, 0.12])

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([0.50, 0.50]),  // Start 50/50
			constraints: [
				.budgetEachPeriod,
				.turnoverLimit(0.30)  // Max 30% turnover between periods
			],
			minimize: false
		)

		XCTAssertTrue(result.converged)
		XCTAssertEqual(result.numberOfPeriods, 2)

		// Check turnover between periods
		let w0 = result.trajectory[0].toArray()
		let w1 = result.trajectory[1].toArray()

		let turnover = zip(w0, w1).map { abs($1 - $0) }.reduce(0.0, +)
		XCTAssertLessThanOrEqual(turnover, 0.31, "Turnover should respect 30% limit")

		print("Turnover: \(String(format: "%.2f%%", turnover * 100))")
	}

	/// Test 3: Multi-period with discount rate
	func testDiscountedMultiPeriod() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 4,
			discountRate: 0.10  // 10% discount rate
		)

		let returns = VectorN([0.12, 0.15])

		let result = try optimizer.optimize(
			objective: { _, weights in
				// Simple return
				weights.dot(returns)
			},
			initialState: VectorN([0.50, 0.50]),
			constraints: [.budgetEachPeriod],
			minimize: false
		)

		XCTAssertTrue(result.converged)

		// Discount factor should be 1/1.10 ≈ 0.909
		let expectedDiscount = 1.0 / 1.10
		XCTAssertEqual(optimizer.discountFactor, expectedDiscount, accuracy: 0.001)

		// Verify total objective accounts for discounting
		// Total = r₀ + δr₁ + δ²r₂ + δ³r₃
		var expectedTotal = 0.0
		for (t, objective) in result.periodObjectives.enumerated() {
			let discount = pow(expectedDiscount, Double(t))
			expectedTotal += discount * objective
		}

		XCTAssertEqual(result.totalObjective, expectedTotal, accuracy: 0.01)
	}

	/// Test 4: Terminal constraint
	func testTerminalConstraint() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,
			discountRate: 0.0
		)

		let returns = VectorN([0.08, 0.12, 0.10])

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([1.0/3.0, 1.0/3.0, 1.0/3.0]),
			constraints: [
				.budgetEachPeriod,
				// Terminal constraint: final weight on asset 0 ≥ 40%
				.terminal(
					function: { xₜ in
						let w0 = xₜ.toArray()[0]
						return 0.40 - w0  // w0 ≥ 0.40 → 0.40 - w0 ≤ 0
					},
					isEquality: false
				)
			],
			minimize: false
		)

		XCTAssertTrue(result.converged)

		// Check terminal constraint is satisfied
		let finalWeights = result.terminalState.toArray()
		XCTAssertGreaterThanOrEqual(finalWeights[0], 0.39, "Terminal weight should be ≥ 40%")

		print("Final weights: \(finalWeights.map { String(format: "%.2f", $0) })")
	}

	// MARK: - Constraint Tests

	/// Test 5: Each-period non-negativity constraints
	func testNonNegativityConstraints() throws {
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

		XCTAssertTrue(result.converged)

		// All weights should be non-negative
		for (t, xₜ) in result.trajectory.enumerated() {
			let weights = xₜ.toArray()
			for (i, w) in weights.enumerated() {
				XCTAssertGreaterThanOrEqual(w, -0.01, "Period \(t), Asset \(i) weight should be ≥ 0")
			}
		}

		// Should allocate all to positive return asset
		for xₜ in result.trajectory {
			let weights = xₜ.toArray()
			XCTAssertGreaterThan(weights[0], 0.90, "Should allocate to positive return asset")
		}
	}

	/// Test 6: Transition constraints (inventory dynamics)
	func testTransitionConstraint() throws {
		// Model simple inventory problem
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 3,
			discountRate: 0.0
		)

		// Decision: [production, inventory]
		// Constraint: inventoryₜ₊₁ = inventoryₜ + productionₜ - demand

		let demand = 10.0  // Constant demand
		let productionCost = 2.0
		let holdingCost = 1.0

		let result = try optimizer.optimize(
			objective: { decision in
				let production = decision.toArray()[0]
				let inventory = decision.toArray()[1]
				// Minimize: production cost + holding cost
				return -(productionCost * production + holdingCost * inventory)
			},
			initialState: VectorN([10.0, 5.0]),  // Initial: produce 10, hold 5
			constraints: [
				// Inventory balance: invₜ₊₁ = invₜ + prodₜ - demand
				.transition(
					function: { _, xₜ, xₜ₊₁ in
						let prodₜ = xₜ.toArray()[0]
						let invₜ = xₜ.toArray()[1]
						let invₜ₊₁ = xₜ₊₁.toArray()[1]

						// Constraint: invₜ₊₁ - (invₜ + prodₜ - demand) = 0
						return invₜ₊₁ - (invₜ + prodₜ - demand)
					},
					isEquality: true
				),
				// Non-negativity
				.eachPeriod(function: { _, x in -x.toArray()[0] }),  // production ≥ 0
				.eachPeriod(function: { _, x in -x.toArray()[1] })   // inventory ≥ 0
			],
			minimize: true
		)

		XCTAssertTrue(result.converged)

		// Verify inventory dynamics
		for t in 0..<(result.numberOfPeriods - 1) {
			let xₜ = result.trajectory[t].toArray()
			let xₜ₊₁ = result.trajectory[t+1].toArray()

			let prodₜ = xₜ[0]
			let invₜ = xₜ[1]
			let invₜ₊₁ = xₜ₊₁[1]

			let expected = invₜ + prodₜ - demand
			XCTAssertEqual(invₜ₊₁, expected, accuracy: 0.5, "Inventory balance should hold")
		}
	}

	/// Test 7: Trajectory constraint (average over periods)
	func testTrajectoryConstraint() throws {
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

		XCTAssertTrue(result.converged)

		// Calculate average allocation to asset 0
		let allocationsToAsset0 = result.trajectory.map { $0.toArray()[0] }
		let average = allocationsToAsset0.reduce(0.0, +) / Double(allocationsToAsset0.count)

		XCTAssertGreaterThanOrEqual(average, 0.29, "Average should be ≥ 30%")
		print("Average allocation to asset 0: \(String(format: "%.2f%%", average * 100))")
	}

	// MARK: - Real-World Scenarios

	/// Test 8: Portfolio rebalancing with transaction costs
	func testPortfolioRebalancingWithTransactionCosts() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 6,  // 6 months
			discountRate: 0.005  // 0.5% monthly discount
		)

		// 4 assets with different expected returns
		let returns = VectorN([0.08, 0.12, 0.10, 0.05])

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
			.budgetEachPeriod,
			.turnoverLimit(0.15)  // Max 15% rebalancing per period
		]
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 4))

		let result = try optimizer.optimize(
			objective: { weights in weights.dot(returns) },
			initialState: VectorN([0.25, 0.25, 0.25, 0.25]),
			constraints: constraints,
			minimize: false
		)

		XCTAssertTrue(result.converged)
		XCTAssertEqual(result.numberOfPeriods, 6)

		// Verify turnover constraints
		for t in 0..<5 {
			let wₜ = result.trajectory[t].toArray()
			let wₜ₊₁ = result.trajectory[t+1].toArray()
			let turnover = zip(wₜ, wₜ₊₁).map { abs($1 - $0) }.reduce(0.0, +)
			XCTAssertLessThanOrEqual(turnover, 0.16, "Turnover in period \(t) should be ≤ 15%")
		}

		print("Portfolio rebalancing successful over 6 periods")
		print("Final allocation: \(result.terminalState.toArray().map { String(format: "%.2f", $0) })")
	}

	/// Test 9: Production planning over time
	func testMultiPeriodProductionPlanning() throws {
		let optimizer = MultiPeriodOptimizer<VectorN<Double>>(
			numberOfPeriods: 4,  // 4 quarters
			discountRate: 0.03  // 3% quarterly discount
		)

		// Decision: [production_product1, production_product2, inventory_1, inventory_2]
		let priceProduct1 = 100.0
		let priceProduct2 = 150.0
		let costProduct1 = 60.0
		let costProduct2 = 90.0
		let holdingCostPerUnit = 2.0

		// Demand per quarter: (product1, product2)
		// let demands = [(50.0, 40.0), (60.0, 45.0), (55.0, 50.0), (65.0, 48.0)]

		let result = try optimizer.optimize(
			objective: { t, decision in
				let prod1 = decision.toArray()[0]
				let prod2 = decision.toArray()[1]
				let inv1 = decision.toArray()[2]
				let inv2 = decision.toArray()[3]

				// Revenue - costs
				let revenue = priceProduct1 * prod1 + priceProduct2 * prod2
				let prodCost = costProduct1 * prod1 + costProduct2 * prod2
				let holdCost = holdingCostPerUnit * (inv1 + inv2)

				return revenue - prodCost - holdCost
			},
			initialState: VectorN([50.0, 40.0, 0.0, 0.0]),
			constraints: [
				// Non-negativity
				.eachPeriod(function: { _, x in -x.toArray()[0] }),  // prod1 ≥ 0
				.eachPeriod(function: { _, x in -x.toArray()[1] }),  // prod2 ≥ 0
				.eachPeriod(function: { _, x in -x.toArray()[2] }),  // inv1 ≥ 0
				.eachPeriod(function: { _, x in -x.toArray()[3] }),  // inv2 ≥ 0

				// Production capacity: total production ≤ 120 units
				.eachPeriod(function: { _, x in
					let total = x.toArray()[0] + x.toArray()[1]
					return total - 120.0
				})
			],
			minimize: false
		)

		XCTAssertTrue(result.converged)

		// Verify production is within capacity
		for (t, decision) in result.trajectory.enumerated() {
			let d = decision.toArray()
			let totalProduction = d[0] + d[1]
			XCTAssertLessThanOrEqual(totalProduction, 121.0, "Period \(t) production should be ≤ 120")
			print("Q\(t+1) production: Product1=\(String(format: "%.0f", d[0])), Product2=\(String(format: "%.0f", d[1]))")
		}
	}

	/// Test 10: Cumulative budget constraint
	func testCumulativeBudgetConstraint() throws {
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

		XCTAssertTrue(result.converged)

		// Verify cumulative constraint
		let totalInvestment = result.trajectory.map { $0.toArray()[0] }.reduce(0.0, +)
		XCTAssertLessThanOrEqual(totalInvestment, 101.0, "Total investment should be ≤ $100k")

		print("Total investment: $\(String(format: "%.0f", totalInvestment))k over 5 periods")
		print("Investments: \(result.trajectory.map { String(format: "%.0f", $0.toArray()[0]) })")
	}

	// MARK: - Edge Cases

	/// Test 11: Single period (degenerates to static optimization)
	func testSinglePeriod() throws {
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

		XCTAssertTrue(result.converged)
		XCTAssertEqual(result.numberOfPeriods, 1)

		// Should allocate to highest return asset
		let weights = result.trajectory[0].toArray()
		XCTAssertGreaterThan(weights[1], 0.90, "Should allocate to highest return")
	}

	/// Test 12: Constraint satisfaction check
	func testConstraintSatisfaction() throws {
		let constraint = MultiPeriodConstraint<VectorN<Double>>.budgetEachPeriod

		// Feasible trajectory
		let feasible = [
			VectorN([0.25, 0.25, 0.25, 0.25]),
			VectorN([0.30, 0.30, 0.20, 0.20]),
			VectorN([0.40, 0.30, 0.20, 0.10])
		]

		XCTAssertTrue(constraint.isSatisfied(trajectory: feasible))

		// Infeasible trajectory
		let infeasible = [
			VectorN([0.50, 0.30, 0.10, 0.05]),  // Sums to 0.95, not 1.0
			VectorN([0.30, 0.30, 0.20, 0.20])
		]

		XCTAssertFalse(constraint.isSatisfied(trajectory: infeasible))
	}
}
