//
//  ProductionPlanningExample.swift
//  BusinessMath Examples
//
//  Demonstrates multi-product manufacturing optimization using ProductionPlanningOptimizer
//

import Foundation
@testable import BusinessMath

/// Example: Electronics manufacturer with 3 product lines
func electronicsManufacturingExample() throws {
	print("=== Electronics Manufacturing Example ===\n")

	// Define product catalog
	let products = [
		ManufacturedProduct(
			id: "premium",
			name: "Premium Model",
			pricePerUnit: 500,
			variableCostPerUnit: 280,
			demand: .range(min: 100, max: 400),
			resourceRequirements: [
				"assembly_hours": 5.0,
				"testing_hours": 3.0,
				"components_units": 50.0
			]
		),
		ManufacturedProduct(
			id: "standard",
			name: "Standard Model",
			pricePerUnit: 300,
			variableCostPerUnit: 160,
			demand: .range(min: 200, max: 800),
			resourceRequirements: [
				"assembly_hours": 3.0,
				"testing_hours": 2.0,
				"components_units": 30.0
			]
		),
		ManufacturedProduct(
			id: "budget",
			name: "Budget Model",
			pricePerUnit: 150,
			variableCostPerUnit: 75,
			demand: .unlimited,
			resourceRequirements: [
				"assembly_hours": 1.5,
				"testing_hours": 1.0,
				"components_units": 15.0
			]
		)
	]

	// Monthly capacity
	let resources = [
		"assembly_hours": 3000.0,
		"testing_hours": 2000.0,
		"components_units": 50_000.0
	]

	// Contractual minimum for premium (enterprise customers)
	let constraints: [ProductionConstraint] = [
		.minimumProduction(productId: "premium", quantity: 120)
	]

	// Optimize for maximum profit
	let optimizer = ProductionPlanningOptimizer(maxIterations: 300)
	let plan = try optimizer.optimize(
		products: products,
		resources: resources,
		objective: .maximizeProfit,
		constraints: constraints
	)

	print("Optimization Status:")
	print("  Converged: \(plan.converged)")
	print("  Iterations: \(plan.iterations)\n")

	print("Production Plan:")
	print(String(repeating: "-", count: 96))
	print("\("Product".padding(toLength: 18, withPad: " ", startingAt: 0)) \("Quantity".padding(toLength: 14, withPad: " ", startingAt: 0)) \("Revenue".padding(toLength: 16, withPad: " ", startingAt: 0)) \("Cost".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Profit".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Margin".padding(toLength: 10, withPad: " ", startingAt: 0))")
	print(String(repeating: "-", count: 96))

	for product in products.sorted(by: { $0.name > $1.name }) {
		let quantity = plan.productionQuantities[product.id] ?? 0
		let revenue = product.pricePerUnit * quantity
		let cost = product.variableCostPerUnit * quantity
		let profit = revenue - cost
		let margin = revenue > 0 ? (profit / revenue) * 100 : 0

		print("\(product.name.padding(toLength: 16, withPad: " ", startingAt: 0)) \(quantity.number().paddingLeft(toLength: 10)) \(revenue.currency().paddingLeft(toLength: 13)) \(cost.currency().paddingLeft(toLength: 13)) \(profit.currency().paddingLeft(toLength: 14)) \(margin.percent().paddingLeft(toLength: 10))")
	}

	print(String(repeating: "-", count: 96))
	print("\("TOTAL".padding(toLength: 18, withPad: " ", startingAt: 0))            \(plan.revenue.currency()) \(plan.costs.currency().paddingLeft(toLength: 13)) \(plan.profit.currency().paddingLeft(toLength: 14)) \(((plan.profit / plan.revenue) * 100).number().paddingLeft(toLength: 10))%")
	print(String(repeating: "-", count: 96))
	print()

	print("Resource Utilization:")
	for (resource, utilization) in plan.resourceUtilization.sorted(by: { $0.key < $1.key }) {
		let percentage = Int(utilization * 100)
		let capacity = resources[resource] ?? 0
		let used = utilization * capacity
		let bar = String(repeating: "█", count: min(50, percentage / 2))

		print("  \(resource.padding(toLength: 20, withPad: " ", startingAt: 0)) \(used.number().paddingLeft(toLength: 5)) / \(capacity.number().paddingLeft(toLength: 5)) (\((utilization * 100).number())%) \(bar)")
	}

	// Show contribution margin analysis
	print()
	print("Contribution Margin Analysis:")
	for product in products {
		let margin = product.contributionMargin
		let marginPercent = (margin / product.pricePerUnit) * 100

		// Calculate margin per machine hour
		let assemblyHours = product.resourceRequirements["assembly_hours"] ?? 1
		let marginPerHour = margin / assemblyHours

		print("  \(product.name):")
		print("    Margin: \(margin.currency()) (\(marginPercent.number())%)")
		print("    Margin per assembly hour: \(marginPerHour.currency())")
	}

	print("\n" + String(repeating: "=", count: 96) + "\n")
}

/// Example: Comparing different objectives
func objectiveComparisonExample() throws {
	print("=== Objective Function Comparison ===\n")

	let products = [
		ManufacturedProduct(
			id: "product_a",
			name: "Product A (High Price, Low Margin)",
			pricePerUnit: 200,
			variableCostPerUnit: 180,  // 10% margin
			demand: .unlimited,
			resourceRequirements: ["machine_hours": 1.0]
		),
		ManufacturedProduct(
			id: "product_b",
			name: "Product B (Low Price, High Margin)",
			pricePerUnit: 80,
			variableCostPerUnit: 30,  // 62.5% margin
			demand: .unlimited,
			resourceRequirements: ["machine_hours": 1.0]
		)
	]

	let resources = ["machine_hours": 1000.0]

	let objectives: [ProductionObjective] = [
		.maximizeProfit,
		.maximizeRevenue,
		.maximizeMargin
	]

	print("\("Objective".padding(toLength: 20, withPad: " ", startingAt: 0)) \("Product A Qty".paddingLeft(toLength: 15)) \("Product B Qty".paddingLeft(toLength: 15)) \("Total Revenue".paddingLeft(toLength: 15)) \("Total Profit".paddingLeft(toLength: 15))")
	print(String(repeating: "-", count: 96))

	for objective in objectives {
		let optimizer = ProductionPlanningOptimizer()
		let plan = try optimizer.optimize(
			products: products,
			resources: resources,
			objective: objective
		)

		let qtyA = plan.productionQuantities["product_a"] ?? 0
		let qtyB = plan.productionQuantities["product_b"] ?? 0

		let objectiveName: String
		switch objective {
		case .maximizeProfit: objectiveName = "Maximize Profit"
		case .maximizeRevenue: objectiveName = "Maximize Revenue"
		case .maximizeMargin: objectiveName = "Maximize Margin"
		default: objectiveName = "Other"
		}
		print("\(objectiveName.padding(toLength: 20, withPad: " ", startingAt: 0)) \(qtyA.number().paddingLeft(toLength: 15)) \(qtyB.number().paddingLeft(toLength: 15)) \(plan.revenue.currency().paddingLeft(toLength: 15)) \(plan.profit.currency().paddingLeft(toLength: 15))")
	}

	print(String(repeating: "-", count: 96))
	print()

	print("Insights:")
	print("  • Maximize Profit: Favors Product B (higher contribution margin)")
	print("  • Maximize Revenue: Favors Product A (higher price per unit)")
	print("  • Maximize Margin: Favors Product B (higher margin percentage)")
	print()

	print("Lesson: Different objectives lead to different optimal solutions!")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Resource-constrained production
func resourceConstrainedExample() throws {
	print("=== Resource-Constrained Production Example ===\n")

	// Two products competing for multiple resources
	let products = [
		ManufacturedProduct(
			id: "product_x",
			name: "Product X",
			pricePerUnit: 120,
			variableCostPerUnit: 50,
			demand: .unlimited,
			resourceRequirements: [
				"machine_a_hours": 3.0,
				"machine_b_hours": 1.0,
				"labor_hours": 2.0
			]
		),
		ManufacturedProduct(
			id: "product_y",
			name: "Product Y",
			pricePerUnit: 100,
			variableCostPerUnit: 40,
			demand: .unlimited,
			resourceRequirements: [
				"machine_a_hours": 1.0,
				"machine_b_hours": 3.0,
				"labor_hours": 2.0
			]
		)
	]

	let resources = [
		"machine_a_hours": 500.0,
		"machine_b_hours": 500.0,
		"labor_hours": 400.0
	]

	let optimizer = ProductionPlanningOptimizer()
	let plan = try optimizer.optimize(
		products: products,
		resources: resources,
		objective: .maximizeProfit
	)

	print("Production Quantities:")
	for product in products {
		let quantity = plan.productionQuantities[product.id] ?? 0
		print("  \(product.name): \(Int(quantity)) units")
	}
	print()

	print("Bottleneck Analysis:")
	let sortedUtilization = plan.resourceUtilization.sorted { $0.value > $1.value }
	for (resource, utilization) in sortedUtilization {
		let percentage = Int(utilization * 100)
		let isBottleneck = utilization > 0.95
		let marker = isBottleneck ? " ⚠️ BOTTLENECK" : ""
		print("  \(resource.padding(toLength: 20, withPad: " ", startingAt: 0)) \(percentage.number())%\(marker)")
	}
	print()

	if let (bottleneck, utilization) = sortedUtilization.first, utilization > 0.95 {
		print("The bottleneck is \(bottleneck).")
		print("Recommendation: Increase \(bottleneck) capacity to improve output.")
	}

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Production Planning Examples")
print(String(repeating: "=", count: 50))
print("\n")

try electronicsManufacturingExample()
try objectiveComparisonExample()
try resourceConstrainedExample()

print("Examples complete!")
