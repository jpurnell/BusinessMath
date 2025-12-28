//
//  ResourceAllocationExample.swift
//  BusinessMath Examples
//
//  Demonstrates capital budgeting and project selection using ResourceAllocationOptimizer
//

import Foundation
@testable import BusinessMath

/// Example: Technology company with 5 potential projects and $1M budget
func capitalBudgetingExample() throws {
	print("=== Capital Budgeting Example ===\n")

	// Define 5 potential projects
	let projects = [
		AllocationOption(
			id: "cloud_migration",
			name: "Cloud Infrastructure Migration",
			expectedValue: 400_000,  // 3-year NPV
			resourceRequirements: ["budget": 250_000, "headcount": 8],
			strategicValue: 9.0,
			dependencies: nil
		),
		AllocationOption(
			id: "mobile_app",
			name: "Mobile App Development",
			expectedValue: 600_000,
			resourceRequirements: ["budget": 300_000, "headcount": 12],
			strategicValue: 8.5,
			dependencies: ["cloud_migration"]  // Requires cloud infrastructure
		),
		AllocationOption(
			id: "analytics_platform",
			name: "Analytics Platform",
			expectedValue: 350_000,
			resourceRequirements: ["budget": 200_000, "headcount": 6],
			strategicValue: 7.5,
			dependencies: nil
		),
		AllocationOption(
			id: "security_upgrade",
			name: "Security Infrastructure Upgrade",
			expectedValue: 200_000,
			resourceRequirements: ["budget": 150_000, "headcount": 5],
			strategicValue: 9.5,  // Critical for compliance
			dependencies: nil
		),
		AllocationOption(
			id: "marketing_automation",
			name: "Marketing Automation System",
			expectedValue: 300_000,
			resourceRequirements: ["budget": 180_000, "headcount": 4],
			strategicValue: 6.5,
			dependencies: nil
		)
	]

	// Define constraints
	let constraints: [AllocationConstraint] = [
		.totalBudget(1_000_000),                          // $1M capital budget
		.resourceLimit(resource: "headcount", limit: 20), // Max 20 FTEs
		.requiredOption(optionId: "security_upgrade"),    // Must do security (compliance)
		.mutuallyExclusive(["mobile_app", "marketing_automation"])  // Can't do both in same period
	]

	// Optimize with 70% financial value, 30% strategic importance
	let optimizer = ResourceAllocationOptimizer()
	let result = try optimizer.optimize(
		options: projects,
		objective: .maximizeWeightedValue(strategicWeight: 0.3),
		constraints: constraints
	)

	// Display results
	print("Optimization Status:")
	print("  Converged: \(result.converged)")
	print("  Iterations: \(result.iterations)\n")

	print("Selected Projects:")
	for option in result.selectedOptions.sorted(by: { $0.name < $1.name }) {
		let allocation = result.allocations[option.id] ?? 0
		let funding = allocation * (option.resourceRequirements["budget"] ?? 0)

		print("  ✓ \(option.name)")
		print("    Allocation: \(allocation.percent())")
		print("    Funding: \(funding.currency())")
		print("    Expected Value: \(option.expectedValue.currency())")
		print("    Strategic Value: \(option.strategicValue ?? 0)/10")

		if let deps = option.dependencies, !deps.isEmpty {
			print("    Dependencies: \(deps.joined(separator: ", "))")
		}
		print()
	}

	print("Financial Summary:")
	print("  Total Value: \(result.totalValue.currency())")
	print()

	print("Resource Usage:")
	for (resource, used) in result.totalResourcesUsed.sorted(by: { $0.key < $1.key }) {
		print("  \(resource): \(used.number(0))")
	}

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

/// Example: Marketing budget allocation across channels
func marketingAllocationExample() throws {
	print("=== Marketing Budget Allocation Example ===\n")

	let channels = [
		AllocationOption(
			id: "google_ads",
			name: "Google Search Ads",
			expectedValue: 200_000,  // Expected revenue
			resourceRequirements: ["spend": 50_000]
		),
		AllocationOption(
			id: "facebook_ads",
			name: "Facebook Ads",
			expectedValue: 150_000,
			resourceRequirements: ["spend": 40_000]
		),
		AllocationOption(
			id: "linkedin_ads",
			name: "LinkedIn Ads",
			expectedValue: 180_000,
			resourceRequirements: ["spend": 60_000]
		),
		AllocationOption(
			id: "content_marketing",
			name: "Content Marketing",
			expectedValue: 100_000,
			resourceRequirements: ["spend": 30_000]
		),
		AllocationOption(
			id: "influencer_marketing",
			name: "Influencer Marketing",
			expectedValue: 120_000,
			resourceRequirements: ["spend": 35_000]
		)
	]

	let constraints: [AllocationConstraint] = [
		.totalBudget(150_000),  // Q1 marketing budget
		.minimumAllocation(optionId: "google_ads", amount: 0.5)  // Must maintain Google presence
	]

	// Optimize for maximum ROI (value per dollar)
	let optimizer = ResourceAllocationOptimizer()
	let result = try optimizer.optimize(
		options: channels,
		objective: .maximizeValuePerDollar,
		constraints: constraints
	)

	print("Selected Channels:")
	for option in result.selectedOptions.sorted(by: {
		let roi1 = $0.expectedValue / ($0.resourceRequirements["spend"] ?? 1)
		let roi2 = $1.expectedValue / ($1.resourceRequirements["spend"] ?? 1)
		return roi1 > roi2
	}) {
		let allocation = result.allocations[option.id] ?? 0
		let spend = allocation * (option.resourceRequirements["spend"] ?? 0)
		let expectedRevenue = allocation * option.expectedValue
		let roi = expectedRevenue / spend

		print("  \(option.name):")
		print("    Allocation: \(allocation.percent())")
		print("    Spend: \(spend.currency())")
		print("    Expected Revenue: \(expectedRevenue.currency())")
		print("    ROI: \(roi.percent())")
		print()
	}

	print("Total Expected Revenue: \(result.totalValue.currency())")
	print("Total Spend: \(result.totalResourcesUsed["spend"]?.currency() ?? "$0.00")")
	let overallROI = result.totalValue / (result.totalResourcesUsed["spend"] ?? 1)
	print("Overall ROI: \(overallROI.number())x")

	print("\n" + String(repeating: "=", count: 50) + "\n")
}

// Run examples
print("\n")
print("BusinessMath - Resource Allocation Examples")
print(String(repeating: "*", count: 60))
print("\n")

try capitalBudgetingExample()
try marketingAllocationExample()

print("Examples complete!")
