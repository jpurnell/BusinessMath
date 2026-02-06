//
//  GeneticAlgorithmTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/26/25.
//

import Testing
import Numerics
import Foundation
@testable import BusinessMath

@Suite("Genetic Algorithm Tests")
struct GeneticAlgorithmTests {

    // MARK: - Configuration Tests

    @Test("GeneticAlgorithmConfig has sensible defaults")
    func testDefaultConfig() {
        let config = GeneticAlgorithmConfig.default

        #expect(config.populationSize == 100)
        #expect(config.generations == 100)
        #expect(config.crossoverRate == 0.8)
        #expect(config.mutationRate == 0.1)
        #expect(config.eliteCount == 2)
        #expect(config.tournamentSize == 3)
    }

    @Test("GeneticAlgorithmConfig high performance preset")
    func testHighPerformanceConfig() {
        let config = GeneticAlgorithmConfig.highPerformance

        #expect(config.populationSize == 1000)
        #expect(config.generations == 500)
        #expect(config.eliteCount == 10)
        #expect(config.tournamentSize == 5)
    }

    // MARK: - Simple Optimization Tests

    @Test("Sphere function optimization (2D)")
    func testSphereFunction2D() throws {
        // f(x,y) = x² + y² has minimum at (0, 0)
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 50,
                generations: 100,
                seed: 42  // Deterministic for testing
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should find minimum near (0, 0)
        #expect(result.objectiveValue < 0.1)
        #expect(abs(result.solution[0]) < 0.5)
        #expect(abs(result.solution[1]) < 0.5)
        #expect(result.iterations > 0)
        #expect(result.iterations <= 100)
    }

    @Test("1D parabola optimization")
    func testParabola1D() throws {
        // f(x) = (x - 3)² has minimum at x = 3
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 30,
                generations: 50,
                seed: 123
            ),
            searchSpace: [(0.0, 10.0)]
        )

        let parabola: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0]
            return (x - 3.0) * (x - 3.0)
        }

        let result = try optimizer.minimize(parabola, from: VectorN([0.0]))

        // Should find minimum near x = 3
        #expect(result.objectiveValue < 0.1)
        #expect(abs(result.solution[0] - 3.0) < 0.5)
    }

    @Test("Rosenbrock function optimization")
    func testRosenbrockFunction() throws {
        // f(x,y) = (1-x)² + 100(y-x²)² has minimum at (1, 1)
        // This is a harder problem - narrow valley
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 500,
                mutationStrength: 0.2,  // Higher mutation for exploration
                seed: 456
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

        // Rosenbrock is hard - just check reasonable convergence
        #expect(result.objectiveValue < 1.0)
        #expect(abs(result.solution[0] - 1.0) < 0.5)
        #expect(abs(result.solution[1] - 1.0) < 0.5)
    }

    // MARK: - Higher Dimensional Tests

    @Test("High dimensional sphere (10D)")
    func testSphereFunctionHighDim() throws {
        let dimension = 10
        let searchSpace = Array(repeating: (-5.0, 5.0), count: dimension)

        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 200,
                seed: 789
            ),
            searchSpace: searchSpace
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let initialGuess = VectorN(Array(repeating: 2.0, count: dimension))
        let result = try optimizer.minimize(sphere, from: initialGuess)

        // Should find minimum near origin
        #expect(result.objectiveValue < 1.0)

        // Check all components are near zero
        for i in 0..<dimension {
            #expect(abs(result.solution[i]) < 0.5)
        }
    }

    // MARK: - Result Properties Tests

    @Test("Result contains convergence history")
    func testConvergenceHistory() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 20,
                generations: 50,
                seed: 111
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.optimizeDetailed(objective: sphere)

        // Should have history for each generation
        #expect(result.convergenceHistory.count == result.generations)

        // Fitness should improve (or stay same) over time
        let firstFitness = result.convergenceHistory.first!
        let lastFitness = result.convergenceHistory.last!
        #expect(lastFitness <= firstFitness)
    }

    @Test("Result contains diversity history")
    func testDiversityHistory() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 20,
                generations: 50,
                seed: 222
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.optimizeDetailed(objective: sphere)

        // Should have diversity history for each generation
        #expect(result.diversityHistory.count == result.generations)

        // Diversity should generally decrease as population converges
        // (though not monotonically due to mutation)
        #expect(result.diversityHistory.allSatisfy { $0 >= 0.0 })
    }

    @Test("Evaluation count is accurate")
    func testEvaluationCount() throws {
        let config = GeneticAlgorithmConfig(
            populationSize: 30,
            generations: 20,
            seed: 333
        )

        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: config,
            searchSpace: [(-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.optimizeDetailed(objective: sphere)

        // Each individual in initial population + any new individuals
        // For simple GA: evaluations = populationSize * generations (approximately)
        #expect(result.evaluations <= config.populationSize * config.generations + config.populationSize)
    }

    // MARK: - Constraint Handling Tests

    @Test("Equality constraint via penalty method")
    func testEqualityConstraint() throws {
        // Minimize x² + y² subject to x + y = 1
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 200,
                seed: 777
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
            v[0] + v[1] - 1.0  // x + y = 1
        }

        let result = try optimizer.minimize(sphere, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should be near (0.5, 0.5) - minimum of x²+y² on line x+y=1
        // Penalty methods are approximate, so allow generous tolerance
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 0.3)  // Constraint satisfaction

        // Objective value should be reasonable (minimum is 0.5 when x=y=0.5)
        #expect(result.value < 3.0)  // Should find something better than random
    }

    @Test("Inequality constraint via penalty method")
    func testInequalityConstraint() throws {
        // Minimize -x - y subject to x² + y² ≤ 1 (maximize x+y on unit circle)
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 200,
                seed: 888
            ),
            searchSpace: [(-2.0, 2.0), (-2.0, 2.0)]
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            -(v[0] + v[1])  // Minimize negative (i.e., maximize x+y)
        }

        let constraint = MultivariateConstraint<VectorN<Double>>.inequality { v in
            v.dot(v) - 1.0  // x² + y² ≤ 1
        }

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should be near (1/√2, 1/√2) ≈ (0.707, 0.707)
        let sqrt2inv = 1.0 / Double.sqrt(2.0)
        #expect(abs(result.solution[0] - sqrt2inv) < 0.3)
        #expect(abs(result.solution[1] - sqrt2inv) < 0.3)

        // Constraint should be satisfied (≤ 0)
        let constraintValue = result.solution.dot(result.solution) - 1.0
        #expect(constraintValue <= 0.1)  // Allow small tolerance
    }

    @Test("Multiple constraints via penalty method")
    func testMultipleConstraints() throws {
        // Minimize x² + y² subject to x ≥ 0, y ≥ 0, x + y ≥ 1
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 200,
                seed: 999
            ),
            searchSpace: [(-1.0, 2.0), (-1.0, 2.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] },  // x ≥ 0 → -x ≤ 0
            MultivariateConstraint<VectorN<Double>>.inequality { v in -v[1] },  // y ≥ 0 → -y ≤ 0
            MultivariateConstraint<VectorN<Double>>.inequality { v in 1.0 - v[0] - v[1] }  // x+y ≥ 1 → 1-x-y ≤ 0
        ]

        let result = try optimizer.minimize(sphere, from: VectorN([1.0, 1.0]), constraints: constraints)

        // Solution should be near (0.5, 0.5) - closest point to origin on x+y=1 in first quadrant
        #expect(result.solution[0] >= -0.1)  // x ≥ 0 (small tolerance)
        #expect(result.solution[1] >= -0.1)  // y ≥ 0
        #expect(result.solution[0] + result.solution[1] >= 0.9)  // x + y ≥ 1
    }

    // MARK: - Convergence Tests

    @Test("Early convergence detection")
    func testEarlyConvergence() throws {
        // Simple problem that should converge quickly
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 50,
                generations: 1000,  // Set high, but should converge early
                seed: 444
            ),
            searchSpace: [(-1.0, 1.0)]
        )

        let simple: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0]
            return x * x
        }

        let result = try optimizer.optimizeDetailed(objective: simple)

        // Should converge before hitting max generations
        #expect(result.converged)
        #expect(result.generations < 1000)
        #expect(result.convergenceReason.contains("improvement"))
    }

    @Test("Maximum generations reached")
    func testMaxGenerations() throws {
        // Harder problem with few generations
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 20,
                generations: 10,  // Very few generations
                seed: 555
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.optimizeDetailed(objective: rosenbrock)

        // Should hit max generations
        #expect(!result.converged)
        #expect(result.generations == 10)
        #expect(result.convergenceReason.contains("Maximum"))
    }

    // MARK: - Deterministic Tests (Seeded RNG)

    @Test("Same seed produces same result")
    func testDeterministicBehavior() throws {
        let seed: UInt64 = 12345
        let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

        let config1 = GeneticAlgorithmConfig(
            populationSize: 30,
            generations: 50,
            seed: seed
        )
        let optimizer1 = GeneticAlgorithm<VectorN<Double>>(
            config: config1,
            searchSpace: searchSpace
        )

        let config2 = GeneticAlgorithmConfig(
            populationSize: 30,
            generations: 50,
            seed: seed
        )
        let optimizer2 = GeneticAlgorithm<VectorN<Double>>(
            config: config2,
            searchSpace: searchSpace
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let result1 = try optimizer1.optimizeDetailed(objective: sphere)
        let result2 = try optimizer2.optimizeDetailed(objective: sphere)

        // Same seed should produce identical results
        #expect(abs(result1.fitness - result2.fitness) < 0.001)
        #expect(abs(result1.solution[0] - result2.solution[0]) < 0.001)
        #expect(abs(result1.solution[1] - result2.solution[1]) < 0.001)
        #expect(result1.generations == result2.generations)
    }

    // MARK: - Edge Cases

    @Test("Empty search space dimension")
    func testEmptyDimension() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: .default,
            searchSpace: []
        )

        let constant = { (_: VectorN<Double>) -> Double in 1.0 }

        let result = try optimizer.minimize(constant, from: VectorN([]))

        // Should handle empty vector
        #expect(result.solution.dimension == 0)
    }

    @Test("Large mutation strength exploration")
    func testLargeMutationStrength() throws {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 30,
                generations: 50,
                mutationRate: 0.5,  // High mutation rate
                mutationStrength: 1.0,  // Large mutations
                seed: 666
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should still converge despite high mutation
        #expect(result.objectiveValue < 2.0)
    }

    // MARK: - GPU Acceleration Tests

    @Test("GPU acceleration for large population")
    func testGPUAcceleration() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else {
            // Skip test if Metal not available
            return
        }

        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 1000,  // Triggers GPU threshold
                generations: 10,       // Keep short for testing
                seed: 12345
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Verify GPU produced valid result
        #expect(result.value < 10.0)
        #expect(result.converged || result.iterations > 0)
        #expect(result.solution.dimension == 2)

        // Result should be close to origin
        #expect(abs(result.solution[0]) < 3.0)
        #expect(abs(result.solution[1]) < 3.0)
        #else
        // Test passes on non-Metal platforms
        #endif
    }

    @Test("GPU vs CPU produces similar results")
    func testGPUVsCPUConsistency() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else {
            return
        }

        // CPU version (small population)
        let cpuOptimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 100,
                generations: 20,
                seed: 99999
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        // GPU version (large population, same seed)
        let gpuOptimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: 1000,
                generations: 20,
                seed: 99999
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let cpuResult = try cpuOptimizer.minimize(sphere, from: VectorN([3.0, 3.0]))
        let gpuResult = try gpuOptimizer.minimize(sphere, from: VectorN([3.0, 3.0]))

        // Both should find reasonable solutions (GPU may be better due to larger population)
        #expect(cpuResult.value < 5.0)
        #expect(gpuResult.value < 5.0)

        // GPU should find at least as good a solution (larger population)
        #expect(gpuResult.value <= cpuResult.value + 1.0)
        #endif
    }

    // MARK: - Performance Benchmarks

    @Test("Benchmark: GPU completes large population efficiently")
    func benchmarkGPUEfficiency() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else {
            return
        }

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let searchSpace = Array(repeating: (-10.0, 10.0), count: 5)  // 5D problem
        let generations = 20

        // Large GPU population
        let gpuConfig = GeneticAlgorithmConfig(
            populationSize: 2000,
            generations: generations,
            seed: 777
        )
        let gpuOptimizer = GeneticAlgorithm<VectorN<Double>>(
            config: gpuConfig,
            searchSpace: searchSpace
        )

        let gpuStart = Date()
        let result = try gpuOptimizer.minimize(sphere, from: VectorN(Array(repeating: 5.0, count: 5)))
        let gpuTime = Date().timeIntervalSince(gpuStart)

        // Print benchmark results
		print("GPU (2000 individuals × 20 gen × 5D): \(gpuTime.number(3))s")
		print("Final fitness: \(result.value.number(6))")
		print("Throughput: \((Double(2000 * 20) / gpuTime).number(0)) evaluations/sec")

        // Should complete efficiently (< 3 seconds on Apple Silicon)
        #expect(gpuTime < 5.0)
        #expect(result.value < 2.0)  // Should find good solution
        #endif
    }

    @Test("Benchmark: GPU advantage at scale")
    func benchmarkGPUAdvantage() throws {
        #if canImport(Metal)
        guard MetalDevice.shared != nil else {
            return
        }

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let searchSpace = Array(repeating: (-10.0, 10.0), count: 10)  // 10D problem

        // Large GPU problem
        let gpuConfig = GeneticAlgorithmConfig(
            populationSize: 2000,
            generations: 30,
            seed: 888
        )
        let gpuOptimizer = GeneticAlgorithm<VectorN<Double>>(
            config: gpuConfig,
            searchSpace: searchSpace
        )

        let gpuStart = Date()
        let result = try gpuOptimizer.minimize(sphere, from: VectorN(Array(repeating: 5.0, count: 10)))
        let gpuTime = Date().timeIntervalSince(gpuStart)

		print("GPU (2000 individuals × 30 gen × 10D): \(gpuTime.number(3))s")
		print("Final fitness: \(result.value.number(6))")

        // Should complete in reasonable time (< 5 seconds on M1/M2)
        #expect(gpuTime < 10.0)
        #expect(result.value < 5.0)  // Should find good solution
        #endif
    }
}
