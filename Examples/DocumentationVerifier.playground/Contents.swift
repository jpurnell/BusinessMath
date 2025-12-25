import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Large knapsack: 20 items
	let numItems = 20
	let values = (0..<numItems).map { Double($0 + 1) * 10.0 }
	let weights = (0..<numItems).map { Double($0 + 1) * 5.0 }
	let capacity = 100.0

	let spec = IntegerProgramSpecification.allBinary(dimension: numItems)

	let objective: @Sendable (VectorN<Double>) -> Double = { x in
		-zip(values, x.toArray()).map(*).reduce(0, +)
	}

	var constraints: [MultivariateConstraint<VectorN<Double>>] = [
		.inequality { x in
			zip(weights, x.toArray()).map(*).reduce(0, +) - capacity
		}
	]

	constraints.append(contentsOf: (0..<numItems).flatMap { i in
		[
			MultivariateConstraint<VectorN<Double>>.inequality { x in -x.toArray()[i] },
			MultivariateConstraint<VectorN<Double>>.inequality { x in x.toArray()[i] - 1.0 }
		]
	})

	let initialGuess = VectorN(Array(repeating: 0.5, count: numItems))

	// 1. Solve with Branch-and-Bound
	print("=== Branch-and-Bound ===")
	let bbSolver = BranchAndBoundSolver<VectorN<Double>>(
		maxNodes: 10000,
		timeLimit: 60.0,
		nodeSelection: .bestBound
	)

	let startBB = Date()
	let bbResult = try bbSolver.solve(
		objective: objective,
		from: initialGuess,
		subjectTo: constraints,
		integerSpec: spec,
		minimize: true
	)
	let timeBB = Date().timeIntervalSince(startBB)

	print("Status: \(bbResult.status)")
print("Objective: \((-bbResult.objectiveValue).number(0))")
	print("Nodes explored: \(bbResult.nodesExplored)")
print("Time: \(timeBB.number(2))s")
print("Gap: \(bbResult.relativeGap.percent(2))")

	// 2. Solve with Branch-and-Cut
	print("\n=== Branch-and-Cut ===")
	let bcSolver = BranchAndCutSolver<VectorN<Double>>(
		maxNodes: 10000,
		maxCuttingRounds: 5,
		cutTolerance: 1e-6,
		enableCoverCuts: true,  // Good for knapsack
		enableMIRCuts: true,
		timeLimit: 60.0,
		nodeSelection: .bestBound
	)

	let startBC = Date()
	let bcResult = try bcSolver.solve(
		objective: objective,
		from: initialGuess,
		subjectTo: constraints,
		integerSpec: spec,
		minimize: true
	)
	let timeBC = Date().timeIntervalSince(startBC)

	print("Status: \(bcResult.success ? "Optimal" : bcResult.terminationReason)")
print("Objective: \((-bcResult.objectiveValue).number(0))")
	print("Nodes explored: \(bcResult.nodesExplored)")
print("Time: \(timeBC.number(2))s")
print("Gap: \(bcResult.gap.percent(2))")
	print("Cuts generated: \(bcResult.cutsGenerated)")
	print("Cutting rounds: \(bcResult.cuttingRounds)")

	// 3. Comparison
	print("\n=== Comparison ===")
	let nodeReduction = Double(bbResult.nodesExplored - bcResult.nodesExplored) / Double(bbResult.nodesExplored)
	let speedup = timeBB / timeBC

print("Node reduction: \(nodeReduction.percent(2))")
print("Speedup: \(speedup.number(2))x")
	print("B&B nodes: \(bbResult.nodesExplored)")
	print("B&C nodes: \(bcResult.nodesExplored)")
