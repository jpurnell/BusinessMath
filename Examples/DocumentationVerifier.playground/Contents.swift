import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Select projects to maximize NPV subject to budget constraint
	let projectNPVs = [50_000.0, 75_000.0, 60_000.0, 90_000.0]
	let projectCosts = [20_000.0, 35_000.0, 25_000.0, 40_000.0]
	let budget = 80_000.0

	
	// Constraint: total cost <= budget
	let constraints: [MultivariateConstraint<VectorN<Double>>] = [
		.inequality { v in
			let cost = zip(v.toArray(), projectCosts).map(*).reduce(0, +)
			return cost - budget
		}
	]

	// Integer specification: all variables are binary (0 or 1)
	let integerSpec = IntegerProgramSpecification.allBinary(dimension: projectNPVs.count)

	let solver = BranchAndBoundSolver<VectorN<Double>>()
	let result = try solver.solve(
		objective: { (selected: VectorN<Double>) -> Double in
			let npv = zip(selected.toArray(), projectNPVs).map(*).reduce(0, +)
		 return -npv  // Negate to maximize
	 }, // Objective: maximize total NPV (minimize negative NPV)
		from: VectorN([0, 0, 0, 0]),
		subjectTo: constraints,
		integerSpec: integerSpec,
		minimize: true  // Minimize negative NPV = maximize NPV
	)

	let selectedProjects = result.solution
