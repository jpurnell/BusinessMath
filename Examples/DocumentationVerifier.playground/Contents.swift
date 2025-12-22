import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Define SaaS business assumptions (fixed parameters)
	let currentCustomers = 3000.0
	let customerAcquisitionCost = 500.0  // CAC per customer
	let grossMarginPercent = 0.75        // 75% gross margin

	let drivers = [
		OptimizableDriver(
			name: "price_per_seat",
			currentValue: 50,
			range: 40...70,
			changeConstraint: .percentageChange(max: 0.20)
		),
		OptimizableDriver(
			name: "monthly_churn_rate",
			currentValue: 0.05,
			range: 0.02...0.08
		)
	]

	let targets = [
		FinancialTarget(metric: "mrr", target: .minimum(150_000), weight: 2.0),
		FinancialTarget(metric: "ltv_cac_ratio", target: .minimum(3.0), weight: 1.5)
	]

	let optimizer = DriverOptimizer()

	let result = try optimizer.optimize(
		drivers: drivers,
		targets: targets,
		model: { driverValues in
			// Extract driver values
			let price = driverValues["price_per_seat"]!
			let monthlyChurn = driverValues["monthly_churn_rate"]!

			// Calculate MRR (Monthly Recurring Revenue)
			let mrr = currentCustomers * price

			// Calculate Customer Lifetime Value (LTV)
			// LTV = ARPU × (1 / monthly_churn) × gross_margin
			let averageLifetimeMonths = 1.0 / monthlyChurn
			let lifetimeRevenue = price * averageLifetimeMonths
			let ltv = lifetimeRevenue * grossMarginPercent

			// Calculate LTV/CAC ratio
			let ltvCacRatio = ltv / customerAcquisitionCost

			return [
				"mrr": mrr,
				"ltv_cac_ratio": ltvCacRatio
			]
		}
	)

	print("\n=== Driver Optimization Results ===")
	print("Optimized drivers:")
	for (name, value) in result.optimizedDrivers {
		print("  \(name): \(value.number(2))")
	}

	print("\nTarget achievement:")
	print("  All targets met: \(result.feasible)")

	// Show the achieved metrics
	let optimizedMetrics = result.achievedMetrics
	print("\nAchieved metrics:")
	if let mrr = optimizedMetrics["mrr"] {
		print("  MRR: \(mrr.currency(0))")
	}
	if let ratio = optimizedMetrics["ltv_cac_ratio"] {
		print("  LTV/CAC Ratio: \(ratio.number(2))x")
	}
