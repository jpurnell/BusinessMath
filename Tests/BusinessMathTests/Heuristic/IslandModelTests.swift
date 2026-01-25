//
//  IslandModelTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Testing
import Numerics
import Foundation
@testable import BusinessMath

@Suite("Island Model Genetic Algorithm Tests")
struct IslandModelTests {

    // MARK: - Configuration Tests

    @Test("IslandModelConfig has sensible defaults")
    func testDefaultConfig() {
        let config = IslandModelConfig.default

        #expect(config.numberOfIslands == 4)
        #expect(config.migrationInterval == 10)
        #expect(config.migrationSize == 2)
        #expect(config.topology == .ring)
    }

    @Test("IslandModelConfig custom configuration")
    func testCustomConfig() {
        let config = IslandModelConfig(
            numberOfIslands: 8,
            migrationInterval: 20,
            migrationSize: 5,
            topology: .fullyConnected
        )

        #expect(config.numberOfIslands == 8)
        #expect(config.migrationInterval == 20)
        #expect(config.migrationSize == 5)
        #expect(config.topology == .fullyConnected)
    }

    @Test("IslandModelConfig high performance preset")
    func testHighPerformanceConfig() {
        let config = IslandModelConfig.highPerformance

        #expect(config.numberOfIslands >= 4)
        #expect(config.migrationInterval > 0)
        #expect(config.migrationSize > 0)
    }

    // MARK: - Basic Optimization Tests

    @Test("Sphere function optimization with islands")
    func testSphereFunction() throws {
        // f(x,y) = x² + y² has minimum at (0, 0)
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 50,
            generations: 30,
            crossoverRate: 0.8,
            mutationRate: 0.1,
            seed: 42
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Island model should find minimum accurately
        #expect(result.value < 0.1)
        #expect(abs(result.solution[0]) < 0.5)
        #expect(abs(result.solution[1]) < 0.5)
    }

    @Test("1D parabola optimization with islands")
    func testParabola1D() throws {
        // f(x) = (x - 3)² has minimum at x = 3
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 30,
            generations: 20,
            seed: 123
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 3,
            migrationInterval: 5,
            migrationSize: 1,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(0.0, 10.0)]
        )

        let parabola = { (v: VectorN<Double>) -> Double in
            let x = v[0]
            return (x - 3.0) * (x - 3.0)
        }

        let result = try optimizer.minimize(parabola, from: VectorN([0.0]))

        // Should find minimum near x = 3
        #expect(result.value < 0.1)
        #expect(abs(result.solution[0] - 3.0) < 0.5)
    }

    @Test("Rosenbrock function with islands")
    func testRosenbrockFunction() throws {
        // f(x,y) = (1-x)² + 100(y-x²)² has minimum at (1, 1)
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 100,
            generations: 100,
            seed: 456
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 5,
            migrationInterval: 10,
            migrationSize: 3,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let rosenbrock = { (v: VectorN<Double>) -> Double in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

        // Island model should handle Rosenbrock well
        #expect(result.value < 5.0)
        #expect(abs(result.solution[0] - 1.0) < 1.0)
        #expect(abs(result.solution[1] - 1.0) < 1.0)
    }

    // MARK: - Migration Topology Tests

    @Test("Ring topology migration")
    func testRingTopology() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 25,
            seed: 777
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should converge with ring migration
        #expect(result.bestFitness < 1.0)
        #expect(result.generations > 0)
    }

    @Test("Fully connected topology migration")
    func testFullyConnectedTopology() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 25,
            seed: 888
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Fully connected should also converge
        #expect(result.bestFitness < 1.0)
        #expect(result.generations > 0)
    }

    @Test("Random topology migration")
    func testRandomTopology() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 25,
            seed: 999
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .random
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Random topology should still converge
        #expect(result.bestFitness < 1.0)
        #expect(result.generations > 0)
    }

    // MARK: - Migration Frequency Tests

    @Test("Frequent migration improves convergence")
    func testFrequentMigration() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 50,
            generations: 50,
            seed: 111
        )

        // Frequent migration (every 5 generations)
        let frequentConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 3,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: frequentConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should converge well with frequent migration
        #expect(result.bestFitness < 0.5)
    }

    @Test("Infrequent migration maintains diversity")
    func testInfrequentMigration() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 50,
            generations: 50,
            seed: 222
        )

        // Infrequent migration (every 25 generations)
        let infrequentConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 25,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: infrequentConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should still find good solution
        #expect(result.bestFitness < 2.0)
    }

    // MARK: - Number of Islands Tests

    @Test("Single island behaves like standard GA")
    func testSingleIsland() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 50,
            generations: 30,
            seed: 333
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 1,
            migrationInterval: 10,
            migrationSize: 1,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0)]
        )

        let simple = { (v: VectorN<Double>) -> Double in
            let x = v[0]
            return x * x
        }

        let result = try optimizer.minimize(simple, from: VectorN([5.0]))

        // Single island should still work
        #expect(result.value < 1.0)
    }

    @Test("Many islands improve exploration")
    func testManyIslands() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 30,
            generations: 30,
            seed: 444
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 8,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Many islands should explore well
        #expect(result.bestFitness < 1.0)
    }

    // MARK: - Convergence Tests

    @Test("Island model converges")
    func testConvergence() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 50,
            generations: 100,
            seed: 555
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 10,
            migrationSize: 3,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-5.0, 5.0)]
        )

        let simple = { (v: VectorN<Double>) -> Double in
            let x = v[0]
            return x * x
        }

        let result = optimizer.optimizeDetailed(objective: simple)

        // Should converge to good solution
        #expect(result.bestFitness < 0.1)
        #expect(result.generations > 0)
    }

    // MARK: - Constraint Handling Tests

    @Test("Equality constraint via penalty method")
    func testEqualityConstraint() throws {
        // Minimize x² + y² subject to x + y = 1
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 60,
            generations: 50,
            seed: 666
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 10,
            migrationSize: 2,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
            v[0] + v[1] - 1.0
        }

        let result = try optimizer.minimize(sphere, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should satisfy constraint
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 0.5)
        #expect(result.value < 2.0)
    }

    @Test("Inequality constraint via penalty method")
    func testInequalityConstraint() throws {
        // Minimize -x - y subject to x² + y² ≤ 1
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 60,
            generations: 50,
            seed: 777
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 10,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-2.0, 2.0), (-2.0, 2.0)]
        )

        let objective = { (v: VectorN<Double>) -> Double in -(v[0] + v[1]) }
        let constraint = MultivariateConstraint<VectorN<Double>>.inequality { v in
            v.dot(v) - 1.0
        }

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should satisfy constraint
        let constraintValue = result.solution.dot(result.solution) - 1.0
        #expect(constraintValue <= 0.2)
    }

    // MARK: - Deterministic Tests

    @Test("Same seed produces same result")
    func testDeterministicBehavior() throws {
        let seed: UInt64 = 12345
        let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 20,
            seed: seed
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 3,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer1 = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: searchSpace
        )

        let optimizer2 = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: searchSpace
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }

        let result1 = optimizer1.optimizeDetailed(objective: sphere)
        let result2 = optimizer2.optimizeDetailed(objective: sphere)

        // Same seed should produce identical results
        #expect(abs(result1.bestFitness - result2.bestFitness) < 0.001)
        #expect(abs(result1.solution[0] - result2.solution[0]) < 0.001)
        #expect(abs(result1.solution[1] - result2.solution[1]) < 0.001)
    }

    // MARK: - Result Properties Tests

    @Test("Result contains island information")
    func testResultProperties() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 25,
            seed: 888
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 5,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should have information about all islands
        #expect(result.islandFitnesses.count == 4)
        #expect(result.generations > 0)
        #expect(result.totalEvaluations > 0)

        // Best fitness should be among island fitnesses
        let minIslandFitness = result.islandFitnesses.min()!
        #expect(abs(result.bestFitness - minIslandFitness) < 0.001)
    }

    @Test("Migration count tracking")
    func testMigrationCount() throws {
        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 40,
            generations: 30,
            seed: 999
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 4,
            migrationInterval: 10,
            migrationSize: 2,
            topology: .ring
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: [(-10.0, 10.0)]
        )

        let simple = { (v: VectorN<Double>) -> Double in
            let x = v[0]
            return x * x
        }

        let result = optimizer.optimizeDetailed(objective: simple)

        // Should have performed migrations
        // With 30 generations and interval 10, should have 3 migrations
        #expect(result.migrationCount >= 2)
        #expect(result.migrationCount <= 3)
    }

    // MARK: - High Dimensional Tests

    @Test("Island model on 10D problem")
    func testHighDimensional() throws {
        let dimension = 10
        let searchSpace = Array(repeating: (-5.0, 5.0), count: dimension)

        let gaConfig = GeneticAlgorithmConfig(
            populationSize: 100,
            generations: 100,
            seed: 123456
        )

        let islandConfig = IslandModelConfig(
            numberOfIslands: 5,
            migrationInterval: 10,
            migrationSize: 3,
            topology: .fullyConnected
        )

        let optimizer = IslandModel<VectorN<Double>>(
            gaConfig: gaConfig,
            islandConfig: islandConfig,
            searchSpace: searchSpace
        )

        let sphere = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let initialGuess = VectorN(Array(repeating: 2.0, count: dimension))
        let result = try optimizer.minimize(sphere, from: initialGuess)

        // Should handle 10D reasonably
        #expect(result.value < 25.0)

        // Most components should be near zero
        let componentsNearZero = result.solution.toArray().filter { abs($0) < 2.0 }.count
        #expect(componentsNearZero >= 7)  // At least 70% near zero
    }
}
