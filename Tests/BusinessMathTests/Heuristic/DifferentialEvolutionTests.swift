//
//  DifferentialEvolutionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Testing
import TestSupport  // Cross-platform math functions
import Numerics
import Foundation
@testable import BusinessMath

@Suite("Differential Evolution Tests")
struct DifferentialEvolutionTests {

    // MARK: - Configuration Tests

    @Test("DifferentialEvolutionConfig has sensible defaults")
    func testDefaultConfig() {
        let config = DifferentialEvolutionConfig.default

        #expect(config.populationSize == 100)
        #expect(config.generations == 200)
        #expect(config.mutationFactor == 0.8)
        #expect(config.crossoverRate == 0.9)
        #expect(config.strategy == .rand1)
    }

    @Test("DifferentialEvolutionConfig high performance preset")
    func testHighPerformanceConfig() {
        let config = DifferentialEvolutionConfig.highPerformance

        #expect(config.populationSize == 1000)
        #expect(config.generations == 500)
        #expect(config.mutationFactor == 0.7)
        #expect(config.crossoverRate == 0.95)
    }

    // MARK: - Simple Optimization Tests

    @Test("Sphere function optimization (2D)")
    func testSphereFunction2D() throws {
        // f(x,y) = x² + y² has minimum at (0, 0)
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                seed: 42
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // DE should find minimum very accurately
        #expect(result.value < 0.01)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
        #expect(result.iterations > 0)
        #expect(result.iterations <= 100)
    }

    @Test("1D parabola optimization")
    func testParabola1D() throws {
        // f(x) = (x - 3)² has minimum at x = 3
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
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
        #expect(result.value < 0.01)
        #expect(abs(result.solution[0] - 3.0) < 0.1)
    }

    @Test("Rosenbrock function optimization")
    func testRosenbrockFunction() throws {
        // f(x,y) = (1-x)² + 100(y-x²)² has minimum at (1, 1)
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 100,
                generations: 300,
                mutationFactor: 0.8,
                crossoverRate: 0.9,
                seed: 456
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

        // DE typically finds Rosenbrock minimum better than GA
        #expect(result.value < 0.1)
        #expect(abs(result.solution[0] - 1.0) < 0.3)
        #expect(abs(result.solution[1] - 1.0) < 0.3)
    }

    // MARK: - Strategy Tests

    @Test("rand/1 strategy")
    func testRand1Strategy() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                strategy: .rand1,
                seed: 111
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        #expect(result.value < 0.1)
    }

    @Test("best/1 strategy")
    func testBest1Strategy() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                strategy: .best1,
                seed: 222
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // best/1 often converges faster
        #expect(result.value < 0.1)
    }

    @Test("currentToBest1 strategy")
    func testCurrentToBest1Strategy() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                strategy: .currentToBest1,
                seed: 333
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        #expect(result.value < 0.1)
    }

    // MARK: - Higher Dimensional Tests

    @Test("High dimensional sphere (10D)")
    func testSphereFunctionHighDim() throws {
        let dimension = 10
        let searchSpace = Array(repeating: (-5.0, 5.0), count: dimension)

        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 150,  // Larger population for higher dimension
                generations: 400,     // More generations needed
                seed: 789
            ),
            searchSpace: searchSpace
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let initialGuess = VectorN(Array(repeating: 2.0, count: dimension))
        let result = try optimizer.minimize(sphere, from: initialGuess)

        // Should find reasonable minimum (10D is harder, be realistic)
        #expect(result.value < 15.0)

        // Check most components are reasonably close to zero
        let componentsNearZero = result.solution.toArray().filter { abs($0) < 1.5 }.count
        #expect(componentsNearZero >= 8)  // At least 80% of components near zero
    }

    // MARK: - Constraint Handling Tests

    @Test("Equality constraint via penalty method")
    func testEqualityConstraint() throws {
        // Minimize x² + y² subject to x + y = 1
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 100,
                generations: 200,
                seed: 777
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
            v[0] + v[1] - 1.0
        }

        let result = try optimizer.minimize(sphere, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should be near (0.5, 0.5)
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 0.3)
        #expect(result.value < 3.0)
    }

    @Test("Inequality constraint via penalty method")
    func testInequalityConstraint() throws {
        // Minimize -x - y subject to x² + y² ≤ 1
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 100,
                generations: 200,
                seed: 888
            ),
            searchSpace: [(-2.0, 2.0), (-2.0, 2.0)]
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in -(v[0] + v[1]) }
        let constraint = MultivariateConstraint<VectorN<Double>>.inequality { v in
            v.dot(v) - 1.0
        }

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [constraint])

        // Solution should be near (1/√2, 1/√2)
        let sqrt2inv = 1.0 / Double.sqrt(2.0)
        #expect(abs(result.solution[0] - sqrt2inv) < 0.3)
        #expect(abs(result.solution[1] - sqrt2inv) < 0.3)

        // Constraint should be satisfied
        let constraintValue = result.solution.dot(result.solution) - 1.0
        #expect(constraintValue <= 0.1)
    }

    // MARK: - Convergence Tests

    @Test("Early convergence detection")
    func testEarlyConvergence() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 1000,  // Set high
                seed: 444
            ),
            searchSpace: [(-1.0, 1.0)]
        )

        let simple: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0]
            return x * x
        }

        let result = optimizer.optimizeDetailed(objective: simple)

        // Should converge before max generations
        #expect(result.converged)
        #expect(result.generations < 1000)
        #expect(result.convergenceReason.contains("improvement"))
    }

    @Test("Maximum generations reached")
    func testMaxGenerations() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 20,
                generations: 10,
                seed: 555
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = optimizer.optimizeDetailed(objective: rosenbrock)

        #expect(!result.converged)
        #expect(result.generations == 10)
        #expect(result.convergenceReason.contains("Maximum"))
    }

    // MARK: - Deterministic Tests

    @Test("Same seed produces same result")
    func testDeterministicBehavior() throws {
        let seed: UInt64 = 12345
        let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

        let optimizer1 = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 30,
                generations: 50,
                seed: seed
            ),
            searchSpace: searchSpace
        )

        let optimizer2 = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 30,
                generations: 50,
                seed: seed
            ),
            searchSpace: searchSpace
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let result1 = optimizer1.optimizeDetailed(objective: sphere)
        let result2 = optimizer2.optimizeDetailed(objective: sphere)

        // Same seed should produce identical results
        #expect(abs(result1.fitness - result2.fitness) < 0.001)
        #expect(abs(result1.solution[0] - result2.solution[0]) < 0.001)
        #expect(abs(result1.solution[1] - result2.solution[1]) < 0.001)
        #expect(result1.generations == result2.generations)
    }

    // MARK: - Parameter Sensitivity Tests

    @Test("High mutation factor increases exploration")
    func testHighMutationFactor() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                mutationFactor: 1.2,  // Higher than typical
                seed: 666
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should still converge despite high mutation
        #expect(result.value < 1.0)
    }

    @Test("Low crossover rate")
    func testLowCrossoverRate() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 50,
                generations: 100,
                crossoverRate: 0.5,  // Lower than typical
                seed: 777
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        #expect(result.value < 1.0)
    }

    // MARK: - Result Properties Tests

    @Test("Result contains convergence history")
    func testConvergenceHistory() throws {
        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: DifferentialEvolutionConfig(
                populationSize: 20,
                generations: 50,
                seed: 888
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should have history for each generation
        #expect(result.convergenceHistory.count == result.generations)

        // Fitness should improve over time
        let firstFitness = result.convergenceHistory.first!
        let lastFitness = result.convergenceHistory.last!
        #expect(lastFitness <= firstFitness)
    }

    @Test("Evaluation count is accurate")
    func testEvaluationCount() throws {
        let config = DifferentialEvolutionConfig(
            populationSize: 30,
            generations: 20,
            seed: 999
        )

        let optimizer = DifferentialEvolution<VectorN<Double>>(
            config: config,
            searchSpace: [(-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Initial population + generations
        #expect(result.evaluations <= config.populationSize * (config.generations + 1))
    }
}
