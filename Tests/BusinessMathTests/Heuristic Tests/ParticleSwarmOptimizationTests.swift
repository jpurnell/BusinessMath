//
//  ParticleSwarmOptimizationTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 12/27/25.
//

import Testing
import TestSupport  // Cross-platform math functions
import Numerics
import Foundation
@testable import BusinessMath

@Suite("Particle Swarm Optimization Tests")
struct ParticleSwarmOptimizationTests {

    // MARK: - Configuration Tests

    @Test("ParticleSwarmConfig has sensible defaults")
    func testDefaultConfig() {
        let config = ParticleSwarmConfig.default

        #expect(config.swarmSize == 50)
        #expect(config.maxIterations == 100)
        #expect(config.inertiaWeight == 0.7298)  // Standard PSO parameter
        #expect(config.cognitiveCoefficient == 1.49618)  // c1
        #expect(config.socialCoefficient == 1.49618)  // c2
    }

    @Test("ParticleSwarmConfig high performance preset")
    func testHighPerformanceConfig() {
        let config = ParticleSwarmConfig.highPerformance

        #expect(config.swarmSize == 1000)
        #expect(config.maxIterations == 500)
        #expect(config.inertiaWeight > 0.0)
        #expect(config.cognitiveCoefficient > 0.0)
        #expect(config.socialCoefficient > 0.0)
    }

    // MARK: - Simple Optimization Tests

    @Test("Sphere function optimization (2D)")
    func testSphereFunction2D() throws {
        // f(x,y) = x² + y² has minimum at (0, 0)
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 50,
                seed: 42
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // PSO should find minimum accurately
        #expect(result.value < 0.01)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
        #expect(result.iterations > 0)
        #expect(result.iterations <= 50)
    }

    @Test("1D parabola optimization")
    func testParabola1D() throws {
        // f(x) = (x - 3)² has minimum at x = 3
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 20,
                maxIterations: 30,
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
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 50,
                maxIterations: 200,
                seed: 456
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

        // PSO typically performs well on Rosenbrock
        #expect(result.value < 0.5)
        #expect(abs(result.solution[0] - 1.0) < 0.5)
        #expect(abs(result.solution[1] - 1.0) < 0.5)
    }

    // MARK: - Inertia Weight Tests

    @Test("High inertia weight increases exploration")
    func testHighInertiaWeight() throws {
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 50,
                inertiaWeight: 0.9,  // Higher than default
                seed: 111
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should still converge despite high inertia
        #expect(result.value < 0.5)
    }

    @Test("Low inertia weight increases exploitation")
    func testLowInertiaWeight() throws {
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 50,
                inertiaWeight: 0.4,  // Lower than default
                seed: 222
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Low inertia should converge quickly
        #expect(result.value < 0.1)
    }

    // MARK: - Coefficient Tests

    @Test("Cognitive-only PSO (c2=0)")
    func testCognitiveOnly() throws {
        // Only personal best, no social component
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 50,
                cognitiveCoefficient: 2.0,
                socialCoefficient: 0.0,
                seed: 333
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should still find reasonable solution
        #expect(result.value < 1.0)
    }

    @Test("Social-only PSO (c1=0)")
    func testSocialOnly() throws {
        // Only global best, no personal best
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 50,
                cognitiveCoefficient: 0.0,
                socialCoefficient: 2.0,
                seed: 444
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should converge (may be premature)
        #expect(result.value < 1.0)
    }

    // MARK: - Higher Dimensional Tests

    @Test("High dimensional sphere (10D)")
    func testSphereFunctionHighDim() throws {
        let dimension = 10
        let searchSpace = Array(repeating: (-5.0, 5.0), count: dimension)

        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 100,
                maxIterations: 300,
                seed: 789
            ),
            searchSpace: searchSpace
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let initialGuess = VectorN(Array(repeating: 2.0, count: dimension))
        let result = try optimizer.minimize(sphere, from: initialGuess)

        // PSO should handle 10D reasonably
        #expect(result.value < 10.0)

        // Most components should be near zero
        let componentsNearZero = result.solution.toArray().filter { abs($0) < 1.0 }.count
        #expect(componentsNearZero >= 8)  // At least 80% near zero
    }

    // MARK: - Constraint Handling Tests

    @Test("Equality constraint via penalty method")
    func testEqualityConstraint() throws {
        // Minimize x² + y² subject to x + y = 1
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 50,
                maxIterations: 100,
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
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 50,
                maxIterations: 100,
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
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 30,
                maxIterations: 1000,  // Set very high
                seed: 555
            ),
            searchSpace: [(-1.0, 1.0)]
        )

        let simple: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0]
            return x * x
        }

        let result = optimizer.optimizeDetailed(objective: simple)

        // Should converge before max iterations
        #expect(result.converged)
        #expect(result.iterations < 1000)
        #expect(result.convergenceReason.contains("improvement") || result.convergenceReason.contains("swarm"))
    }

    @Test("Maximum iterations reached")
    func testMaxIterations() throws {
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 10,
                maxIterations: 5,  // Very low
                seed: 666
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let result = optimizer.optimizeDetailed(objective: rosenbrock)

        #expect(!result.converged)
        #expect(result.iterations == 5)
        #expect(result.convergenceReason.contains("Maximum"))
    }

    // MARK: - Deterministic Tests

    @Test("Same seed produces same result")
    func testDeterministicBehavior() throws {
        let seed: UInt64 = 12345
        let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

        let optimizer1 = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 20,
                maxIterations: 30,
                seed: seed
            ),
            searchSpace: searchSpace
        )

        let optimizer2 = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 20,
                maxIterations: 30,
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
        #expect(result1.iterations == result2.iterations)
    }

    // MARK: - Velocity Clamping Tests

    @Test("Velocity clamping prevents explosion")
    func testVelocityClamping() throws {
        // Test with extreme coefficients
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 20,
                maxIterations: 50,
                inertiaWeight: 0.9,
                cognitiveCoefficient: 3.0,
                socialCoefficient: 3.0,
                velocityClamp: 2.0,  // Clamp velocities
                seed: 999
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(sphere, from: VectorN([5.0, 5.0]))

        // Should still find reasonable solution despite extreme params
        #expect(result.value < 1.0)
    }

    // MARK: - Result Properties Tests

    @Test("Result contains convergence history")
    func testConvergenceHistory() throws {
        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: ParticleSwarmConfig(
                swarmSize: 20,
                maxIterations: 30,
                seed: 111
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Should have history for each iteration
        #expect(result.convergenceHistory.count == result.iterations)

        // Fitness should improve over time
        guard let firstFitness = result.convergenceHistory.first,
              let lastFitness = result.convergenceHistory.last else {
            Issue.record("Convergence history should not be empty after optimization")
            return
        }
        #expect(lastFitness <= firstFitness)
    }

    @Test("Evaluation count is accurate")
    func testEvaluationCount() throws {
        let config = ParticleSwarmConfig(
            swarmSize: 15,
            maxIterations: 10,
            seed: 222
        )

        let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
            config: config,
            searchSpace: [(-10.0, 10.0)]
        )

        let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = optimizer.optimizeDetailed(objective: sphere)

        // Initial swarm + iterations
        #expect(result.evaluations <= config.swarmSize * (config.maxIterations + 1))
    }
}
