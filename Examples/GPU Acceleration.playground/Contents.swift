import Cocoa
import BusinessMath

// Define search space bounds
let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

// Create optimizer (GPU activates automatically for large populations)
let optimizer = GeneticAlgorithm<VectorN<Double>>(
	config: GeneticAlgorithmConfig(
		populationSize: 2000,  // ≥ 1000 triggers GPU
		generations: 100
	),
	searchSpace: searchSpace
)

// Minimize objective function
let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

print("Solution: \(result.solution.toArray())")     // Near [0, 0]
print("Fitness: \(result.value.number(2))")         // Near 0
print("Generations: \(result.iterations)")
