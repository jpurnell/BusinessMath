//
//  DriverOptimizationTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Driver Optimization Tests")
struct DriverOptimizationTests {

	// MARK: - Basic Target Seeking

	@Test("Simple target seeking - single driver, single target")
	func simpleTargetSeeking() throws {
		// Price optimization: find price to hit revenue target
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 50...150
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(120_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				let volume = 1000.0  // Fixed volume
				return ["revenue": price * volume]
			}
		)

		#expect(result.converged, "Should converge")
		#expect(result.feasible, "Should be feasible")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		#expect(achievedRevenue >= 119_000, "Should achieve minimum revenue")
	}

	@Test("Multi-driver optimization - find price and volume")
	func multiDriverOptimization() throws {
		// Optimize both price and volume to hit revenue target
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 80...120,
				changeConstraint: .percentageChange(max: 0.15)  // Max 15% change
			),
			OptimizableDriver(
				name: "volume",
				currentValue: 1000,
				range: 800...1500
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(120_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				let volume = driverValues["volume"]!
				return ["revenue": price * volume]
			}
		)

		#expect(result.converged, "Should converge")

		// Check price stayed within 15% of current
		let priceChange = result.driverChanges["price"] ?? 0
		let percentChange = priceChange / 100.0
		#expect(abs(percentChange) <= 0.16, "Price should respect percentage constraint")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		#expect(achievedRevenue >= 118_000, "Should achieve revenue target")
	}

	// MARK: - Multi-Target Optimization

	@Test("Multiple targets with different priorities")
	func multipleTargetsWithPriorities() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 80...150
			),
			OptimizableDriver(
				name: "cost",
				currentValue: 40,
				range: 35...50
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(120_000),
				weight: 2.0  // High priority
			),
			FinancialTarget(
				metric: "margin",
				target: .minimum(0.5),  // 50% margin
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				let cost = driverValues["cost"]!
				let volume = 1000.0
				let revenue = price * volume
				let totalCost = cost * volume
				let margin = (revenue - totalCost) / revenue
				return [
					"revenue": revenue,
					"margin": margin
				]
			}
		)

		#expect(result.converged, "Should converge")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		let achievedMargin = result.achievedMetrics["margin"] ?? 0

		#expect(achievedRevenue >= 115_000, "Should prioritize revenue target")
		#expect(achievedMargin >= 0.45, "Should achieve margin target")
	}

	@Test("Exact target matching")
	func exactTargetMatching() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 95,
				range: 80...120
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .exact(100_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				return ["revenue": price * 1000]
			}
		)

		#expect(result.converged, "Should converge")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		let error = abs(achievedRevenue - 100_000) / 100_000

		#expect(error < 0.02, "Should hit exact target within 2%")
	}

	// MARK: - Constraints

	@Test("Absolute change constraint")
	func absoluteChangeConstraint() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 50...150,
				changeConstraint: .absoluteChange(max: 10)  // Max $10 change
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(115_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				return ["revenue": price * 1000]
			}
		)

		#expect(result.converged, "Should converge")

		let priceChange = result.driverChanges["price"] ?? 0
		#expect(abs(priceChange) <= 11.0, "Should respect absolute change constraint")
	}

	@Test("Percentage change constraint")
	func percentageChangeConstraint() throws {
		let drivers = [
			OptimizableDriver(
				name: "conversion_rate",
				currentValue: 0.02,  // 2%
				range: 0.01...0.05,
				changeConstraint: .percentageChange(max: 0.25)  // Max 25% change
			)
		]

		let targets = [
			FinancialTarget(
				metric: "conversions",
				target: .minimum(250),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let conversionRate = driverValues["conversion_rate"]!
				let visitors = 10_000.0
				return ["conversions": conversionRate * visitors]
			}
		)

		#expect(result.converged, "Should converge")

		let newRate = result.optimizedDrivers["conversion_rate"] ?? 0
		let percentChange = abs((newRate / 0.02) - 1.0)
		#expect(percentChange <= 0.26, "Should respect percentage constraint")
	}

	// MARK: - Different Objectives

	@Test("Minimize cost objective")
	func minimizeCostObjective() throws {
		// Simplified test: two drivers with different change costs
		let drivers = [
			OptimizableDriver(
				name: "driver_a",
				currentValue: 10.0,
				range: 5.0...20.0
			),
			OptimizableDriver(
				name: "driver_b",
				currentValue: 10.0,
				range: 5.0...20.0
			)
		]

		let targets = [
			FinancialTarget(
				metric: "sum",
				target: .minimum(30.0),  // Need sum ≥ 30
				weight: 1.0
			)
		]

		// Driver A is cheaper to change than driver B
		let costs = ["driver_a": 1.0, "driver_b": 5.0]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let a = driverValues["driver_a"]!
				let b = driverValues["driver_b"]!
				return ["sum": a + b]
			},
			objective: .minimizeCost(costs)
		)

		#expect(result.converged, "Should converge")

		// Should achieve target
		let achievedSum = result.achievedMetrics["sum"] ?? 0
		#expect(achievedSum >= 29.0, "Should achieve sum target")
	}

	@Test("Custom objective function")
	func customObjective() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 80...120
			),
			OptimizableDriver(
				name: "discount",
				currentValue: 0.0,
				range: 0.0...0.3
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(110_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				let discount = driverValues["discount"]!
				let effectivePrice = price * (1.0 - discount)
				let volume = 1000.0 * (1.0 + discount * 2.0)  // Discount boosts volume
				return ["revenue": effectivePrice * volume]
			},
			objective: .custom({ driverValues in
				// Prefer higher price, lower discount
				let price = driverValues["price"]!
				let discount = driverValues["discount"]!
				return -(price - 100.0 * discount)  // Negative because we minimize
			})
		)

		#expect(result.converged, "Should converge")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		#expect(achievedRevenue >= 105_000, "Should achieve revenue target")
	}

	// MARK: - Edge Cases

	@Test("Infeasible target")
	func infeasibleTarget() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 90...110,  // Limited range
				changeConstraint: .absoluteChange(max: 5)  // Tight constraint
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(200_000),  // Impossible with constraints
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				return ["revenue": price * 1000]
			}
		)

		// Should converge but not be feasible
		#expect(!result.feasible, "Should recognize infeasibility")
	}

	@Test("Target range constraint")
	func targetRangeConstraint() throws {
		let drivers = [
			OptimizableDriver(
				name: "price",
				currentValue: 100,
				range: 80...120
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .range(100_000, 110_000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["price"]!
				return ["revenue": price * 1000]
			}
		)

		#expect(result.converged, "Should converge")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		#expect(achievedRevenue >= 99_000, "Should be in target range (lower)")
		#expect(achievedRevenue <= 111_000, "Should be in target range (upper)")
	}

	// MARK: - Real-World Scenarios

	@Test("SaaS revenue model - optimize MRR")
	func saasRevenueModel() throws {
		// Optimize subscription metrics to hit MRR target
		let drivers = [
			OptimizableDriver(
				name: "price_per_seat",
				currentValue: 50,
				range: 40...70,
				changeConstraint: .percentageChange(max: 0.20)
			),
			OptimizableDriver(
				name: "churn_rate",
				currentValue: 0.05,  // 5% monthly churn
				range: 0.02...0.08,
				changeConstraint: .absoluteChange(max: 0.015)  // Max 1.5% change
			),
			OptimizableDriver(
				name: "new_customers_monthly",
				currentValue: 100,
				range: 80...150
			)
		]

		let targets = [
			FinancialTarget(
				metric: "mrr",
				target: .minimum(60_000),
				weight: 2.0
			),
			FinancialTarget(
				metric: "customer_count",
				target: .minimum(1000),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer(maxIterations: 300)
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let pricePerSeat = driverValues["price_per_seat"]!
				let churnRate = driverValues["churn_rate"]!
				let newCustomersMonthly = driverValues["new_customers_monthly"]!

				// Simplified steady-state model
				let steadyStateCustomers = newCustomersMonthly / churnRate
				let mrr = steadyStateCustomers * pricePerSeat

				return [
					"mrr": mrr,
					"customer_count": steadyStateCustomers
				]
			}
		)

		#expect(result.converged, "Should converge")

		let achievedMRR = result.achievedMetrics["mrr"] ?? 0
		let achievedCustomers = result.achievedMetrics["customer_count"] ?? 0

		#expect(achievedMRR >= 55_000, "Should achieve MRR target")
		#expect(achievedCustomers >= 950, "Should achieve customer count target")

		// Verify constraints respected
		let churnChange = abs(result.driverChanges["churn_rate"] ?? 0)
		#expect(churnChange <= 0.016, "Should respect churn rate change constraint")
	}

	@Test("E-commerce optimization - balance price and conversion")
	func ecommerceOptimization() throws {
		let drivers = [
			OptimizableDriver(
				name: "product_price",
				currentValue: 100,
				range: 80...150
			),
			OptimizableDriver(
				name: "conversion_rate",
				currentValue: 0.03,  // 3%
				range: 0.02...0.05,
				changeConstraint: .percentageChange(max: 0.30)
			),
			OptimizableDriver(
				name: "traffic",
				currentValue: 10_000,
				range: 8_000...15_000
			)
		]

		let targets = [
			FinancialTarget(
				metric: "revenue",
				target: .minimum(35_000),
				weight: 2.0
			),
			FinancialTarget(
				metric: "orders",
				target: .minimum(300),
				weight: 1.0
			)
		]

		let optimizer = DriverOptimizer()
		let result = try optimizer.optimize(
			drivers: drivers,
			targets: targets,
			model: { driverValues in
				let price = driverValues["product_price"]!
				let conversionRate = driverValues["conversion_rate"]!
				let traffic = driverValues["traffic"]!

				// Price elasticity: higher price reduces conversion
				let priceImpact = 1.0 - (price - 100) / 200.0
				let effectiveConversion = conversionRate * max(0.5, priceImpact)

				let orders = traffic * effectiveConversion
				let revenue = orders * price

				return [
					"revenue": revenue,
					"orders": orders
				]
			},
			objective: .minimizeChange
		)

		#expect(result.converged, "Should converge")

		let achievedRevenue = result.achievedMetrics["revenue"] ?? 0
		let achievedOrders = result.achievedMetrics["orders"] ?? 0

		#expect(achievedRevenue >= 32_000, "Should achieve revenue target")
		#expect(achievedOrders >= 280, "Should achieve order target")
	}
}
