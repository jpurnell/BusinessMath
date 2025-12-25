import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Allocate budget across projects to maximize value
	let projectValues = [100.0, 150.0, 200.0]  // Value of each project
	let projectCosts = [50.0, 75.0, 100.0]     // Cost of each project
	let totalBudget = 200.0

	// Objective: Maximize total value
	let value: (VectorN<Double>) -> Double = { allocation in
		var total = 0.0
		for i in 0..<3 {
			total += allocation[i] * projectValues[i]
		}
		return -total  // Negative for minimization
	}

	// Constraints: Budget limit, non-negative allocations (0-100% per project)
	let constraints: [MultivariateConstraint<VectorN<Double>>] = [
		.inequality { allocation in
			let totalCost = (0..<3).map { i in
				allocation[i] * projectCosts[i]
			}.reduce(0, +)
			return totalCost - totalBudget  // ≤ budget
		}
	] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)
	  + MultivariateConstraint<VectorN<Double>>.positionLimit(1.0, dimension: 3)

	let optimizer = InequalityOptimizer<VectorN<Double>>()
	let result = try optimizer.minimize(
		value,
		from: VectorN([0.5, 0.5, 0.5]),
		subjectTo: constraints
	)

	print("Optimal allocations:")
	for (i, alloc) in result.solution.toArray().enumerated() {
		let funding = alloc * projectCosts[i]
		print("  Project \(i+1): \(alloc.percent()) → \(funding.currency())")
	}
