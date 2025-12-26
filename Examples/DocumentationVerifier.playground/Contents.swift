import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

let benchmark = PerformanceBenchmark<VectorN<Double>>()

let rosenbrock: (VectorN<Double>) -> Double = { v in
	let x = v[0], y = v[1]
	let a = 1 - x
	let b = y - x*x
	return a*a + 100*b*b
}

let tolerances = [1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8]

let report = try benchmark.compareOptimizers(
	objective: rosenbrock,
	optimizers: tolerances.map { tol in
		("tol=\(tol)", AdaptiveOptimizer(tolerance: tol))
	},
	initialGuess: VectorN([1.0, 1.0]),
	trials: 20
)

print(report.summary())

// Find sweet spot (balance speed vs accuracy)
let winner = report.winner
print("\n🎯 Optimal tolerance: \(winner.name)")
print("  Speed: \(winner.avgTime)s")
print("  Accuracy: \(winner.avgObjectiveValue)")
print("  Reliability: \(winner.successRate.percent())")
