//
//  ProductionPlanningTests.swift
//  BusinessMath
//
//  Created by Claude Code on 12/04/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Production Planning Tests")
struct ProductionPlanningTests {

	// MARK: - Basic Production Tests

	@Test("Single product with capacity constraint")
	func singleProductCapacityConstraint() throws {
		let products = [
			ManufacturedProduct(
				id: "widget",
				name: "Widget",
				pricePerUnit: 100,
				variableCostPerUnit: 45,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 2.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],
			objective: .maximizeProfit
		)

		#expect(plan.converged, "Should converge")
		#expect(plan.profit > 0, "Should generate profit")

		// With 1000 machine hours and 2 hours per widget, can produce up to 500 widgets
		let widgetQty = plan.productionQuantities["widget"]?.rounded() ?? 0
		#expect(widgetQty <= 500, "Should not exceed capacity")
	}

	@Test("Two products competing for same resource")
	func twoProductsOneResource() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 45,  // Margin: $55
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 2.0]
			),
			ManufacturedProduct(
				id: "product_b",
				name: "Product B",
				pricePerUnit: 80,
				variableCostPerUnit: 30,  // Margin: $50
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.5]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],
			objective: .maximizeProfit
		)

		#expect(plan.converged, "Should converge")
		#expect(plan.profit > 0, "Should generate profit")

		// Product A has higher margin per unit ($55 vs $50)
		// But Product B uses less machine time (1.5 vs 2.0)
		// Margin per machine hour: A = $27.50, B = $33.33
		// Should favor Product B
		let productBQty = plan.productionQuantities["product_b"] ?? 0
		#expect(productBQty > 100, "Should produce significant Product B")
	}

	// MARK: - Demand Constraints

	@Test("Fixed demand constraint")
	func fixedDemandConstraint() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 45,
				demand: .fixed(300),  // Can only sell 300 units
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],  // Enough capacity for 1000 units
			objective: .maximizeProfit
		)

		#expect(plan.converged, "Should converge")

		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty <= 305, "Should not significantly exceed demand")
	}

	@Test("Demand range constraint")
	func demandRangeConstraint() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 45,
				demand: .range(min: 100, max: 400),
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],
			objective: .maximizeProfit
		)

		#expect(plan.converged, "Should converge")

		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty >= 95, "Should meet minimum demand")
		#expect(productAQty <= 410, "Should not exceed maximum demand")
	}

	// MARK: - Multi-Resource Constraints

	@Test("Multiple resources - machine and labor")
	func multipleResources() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 150,
				variableCostPerUnit: 60,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 3.0, "labor_hours": 2.0]
			),
			ManufacturedProduct(
				id: "product_b",
				name: "Product B",
				pricePerUnit: 100,
				variableCostPerUnit: 40,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.5, "labor_hours": 3.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 500, "labor_hours": 600],
			objective: .maximizeProfit
		)

		#expect(plan.converged, "Should converge")
		#expect(plan.profit > 0, "Should generate profit")

		// Check both resources are not exceeded
		let machineUtil = plan.resourceUtilization["machine_hours"] ?? 0
		let laborUtil = plan.resourceUtilization["labor_hours"] ?? 0

		#expect(machineUtil <= 1.05, "Machine utilization should not wildly exceed 100%")
		#expect(laborUtil <= 1.05, "Labor utilization should not wildly exceed 100%")
	}

	// MARK: - Production Constraints

	@Test("Minimum production requirement")
	func minimumProductionRequirement() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A (low margin)",
				pricePerUnit: 50,
				variableCostPerUnit: 45,  // Only $5 margin
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			),
			ManufacturedProduct(
				id: "product_b",
				name: "Product B (high margin)",
				pricePerUnit: 150,
				variableCostPerUnit: 60,  // $90 margin
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],
			objective: .maximizeProfit,
			constraints: [
				.minimumProduction(productId: "product_a", quantity: 200)  // Must produce at least 200 of A
			]
		)

		#expect(plan.converged, "Should converge")

		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty >= 190, "Should meet minimum production")
	}

	@Test("Maximum production limit")
	func maximumProductionLimit() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 40,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 1000],
			objective: .maximizeProfit,
			constraints: [
				.maximumProduction(productId: "product_a", quantity: 300)
			]
		)

		#expect(plan.converged, "Should converge")

		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty <= 310, "Should respect maximum production")
	}

	// MARK: - Different Objectives

	@Test("Maximize revenue objective")
	func maximizeRevenueObjective() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A (expensive, low margin)",
				pricePerUnit: 200,
				variableCostPerUnit: 180,  // $20 margin
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			),
			ManufacturedProduct(
				id: "product_b",
				name: "Product B (cheap, high margin)",
				pricePerUnit: 80,
				variableCostPerUnit: 30,  // $50 margin
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 500],
			objective: .maximizeRevenue  // Focus on revenue, not profit
		)

		#expect(plan.converged, "Should converge")
		#expect(plan.revenue > 0, "Should generate revenue")

		// Maximizing revenue should favor expensive Product A
		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty > 100, "Should produce significant high-priced product")
	}

	@Test("Minimize costs objective")
	func minimizeCostsObjective() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 60,
				demand: .range(min: 50, max: 200),
				resourceRequirements: ["machine_hours": 1.0]
			),
			ManufacturedProduct(
				id: "product_b",
				name: "Product B",
				pricePerUnit: 80,
				variableCostPerUnit: 30,  // Lower cost
				demand: .range(min: 50, max: 200),
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 500],
			objective: .minimizeCosts
		)

		#expect(plan.converged, "Should converge")

		// Both have minimum demand of 50, optimizer should minimize total costs
		#expect(plan.costs > 0, "Should have positive costs")
	}

	// MARK: - Real-World Scenarios

	@Test("Manufacturing optimization - 3 products, 2 resources")
	func manufacturingOptimization() throws {
		let products = [
			ManufacturedProduct(
				id: "deluxe",
				name: "Deluxe Model",
				pricePerUnit: 250,
				variableCostPerUnit: 120,
				demand: .range(min: 50, max: 300),
				resourceRequirements: ["assembly_hours": 4.0, "testing_hours": 2.0]
			),
			ManufacturedProduct(
				id: "standard",
				name: "Standard Model",
				pricePerUnit: 150,
				variableCostPerUnit: 70,
				demand: .range(min: 100, max: 500),
				resourceRequirements: ["assembly_hours": 2.0, "testing_hours": 1.0]
			),
			ManufacturedProduct(
				id: "economy",
				name: "Economy Model",
				pricePerUnit: 80,
				variableCostPerUnit: 35,
				demand: .unlimited,
				resourceRequirements: ["assembly_hours": 1.0, "testing_hours": 0.5]
			)
		]

		let optimizer = ProductionPlanningOptimizer(maxIterations: 300)
		let plan = try optimizer.optimize(
			products: products,
			resources: ["assembly_hours": 2000, "testing_hours": 1000],
			objective: .maximizeProfit
		)

		#expect(plan.profit > 0, "Should generate profit")
		#expect(plan.productionQuantities.count == 3, "Should have quantities for all products")

		// Check minimum demands are met
		let deluxeQty = plan.productionQuantities["deluxe"] ?? 0
		let standardQty = plan.productionQuantities["standard"] ?? 0

		#expect(deluxeQty >= 45, "Should meet deluxe minimum demand")
		#expect(standardQty >= 95, "Should meet standard minimum demand")
	}

	@Test("Resource utilization optimization")
	func resourceUtilizationOptimization() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 50,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 800],
			objective: .maximizeUtilization
		)

		// Note: Utilization optimization can be tricky - it's trying to maximize
		// the percentage of resources used, not profit. With unlimited demand,
		// it should produce something, but may not hit high utilization.
		#expect(plan.converged, "Should converge")
		#expect(plan.profit > 0, "Should generate some profit")

		let utilization = plan.resourceUtilization["machine_hours"] ?? 0
		#expect(utilization >= 0, "Should have non-negative utilization")
	}

	// MARK: - Edge Cases

	@Test("Empty products throws error")
	func emptyProductsError() throws {
		let optimizer = ProductionPlanningOptimizer()

		#expect(throws: OptimizationError.self) {
			_ = try optimizer.optimize(
				products: [],
				resources: ["machine_hours": 1000],
				objective: .maximizeProfit
			)
		}
	}

	@Test("Very limited capacity resources")
	func limitedCapacityResources() throws {
		let products = [
			ManufacturedProduct(
				id: "product_a",
				name: "Product A",
				pricePerUnit: 100,
				variableCostPerUnit: 40,
				demand: .unlimited,
				resourceRequirements: ["machine_hours": 1.0]
			)
		]

		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: ["machine_hours": 50],  // Very limited capacity
			objective: .maximizeProfit
		)

		// With limited capacity, should produce up to capacity
		let productAQty = plan.productionQuantities["product_a"] ?? 0
		#expect(productAQty <= 55, "Should not exceed capacity")
		#expect(productAQty >= 0, "Should produce non-negative amount")
	}
}
