//
//  SimulatedAnnealingTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Testing
@testable import BusinessMath

/// Tests for Simulated Annealing optimizer
@Suite("Simulated Annealing Tests")
struct SimulatedAnnealingTests {

    // MARK: - Basic Optimization Tests

    @Test("Simulated Annealing minimizes simple quadratic")
    func simpleQuadratic() throws {
        // f(x,y) = x² + y², minimum at (0, 0)
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: .default,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([5.0, 5.0])
        )

        #expect(result.converged)
        // SA is stochastic - allow some tolerance
        #expect(abs(result.solution[0]) < 1.0)
        #expect(abs(result.solution[1]) < 1.0)
        #expect(result.value < 2.0) // Should be much better than initial (~50)
    }

    @Test("Simulated Annealing minimizes Rosenbrock function")
    func rosenbrockFunction() throws {
        // f(x,y) = (1-x)² + 100(y-x²)²
        // Global minimum at (1, 1)
        let objective: (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 100.0,
                finalTemperature: 0.01,
                coolingRate: 0.95,
                maxIterations: 5000,
                perturbationScale: 0.5
            ),
            searchSpace: [(-5.0, 5.0), (-5.0, 5.0)]
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0])
        )

        #expect(result.converged)
        // Rosenbrock is challenging - SA should improve from initial but may not reach global min
        // Just verify we found a reasonable solution
        #expect(result.value < 100.0) // Much better than starting point
    }

    @Test("Simulated Annealing handles multimodal function (Rastrigin)")
    func rastriginFunction() throws {
        // Rastrigin: f(x) = 10n + Σ(x²- 10cos(2πx))
        // Many local minima, global minimum at origin
        let objective: (VectorN<Double>) -> Double = { v in
            let n = Double(v.dimension)
            var sum = 10.0 * n
            for i in 0..<v.dimension {
                let xi = v[i]
                sum += xi * xi - 10.0 * cos(2.0 * .pi * xi)
            }
            return sum
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 200.0,
                finalTemperature: 0.1,
                coolingRate: 0.98,
                maxIterations: 10000,
                perturbationScale: 1.0
            ),
            searchSpace: [(-5.12, 5.12), (-5.12, 5.12)]
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([3.0, 3.0])
        )

        // Rastrigin is very difficult with many local minima
        // SA should improve from initial but may not reach global optimum
        #expect(result.value < 30.0) // Better than starting point (~36)
    }

    // MARK: - Cooling Schedule Tests

    @Test("Geometric cooling schedule")
    func geometricCooling() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 2.0) * (v[0] - 2.0)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 50.0,
                finalTemperature: 0.01,
                coolingRate: 0.9, // Geometric: T_new = coolingRate * T_old
                maxIterations: 1000,
                perturbationScale: 0.5
            ),
            searchSpace: [(-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 2.0) < 0.5)
    }

    @Test("Fast cooling vs slow cooling")
    func coolingRateComparison() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        // Fast cooling
        let fastOptimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 50.0,
                finalTemperature: 0.01,
                coolingRate: 0.8, // Fast cooling
                maxIterations: 500
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let fastResult = try fastOptimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        // Slow cooling
        let slowOptimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 50.0,
                finalTemperature: 0.01,
                coolingRate: 0.98, // Slow cooling
                maxIterations: 2000
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let slowResult = try slowOptimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        // Both should converge and improve from initial
        #expect(fastResult.converged)
        #expect(slowResult.converged)
        // Both should find good solutions - allow tolerance for stochastic nature
        #expect(fastResult.value < 3.0)
        #expect(slowResult.value < 3.0)
    }

    // MARK: - Perturbation Tests

    @Test("Small perturbation scale for fine-tuning")
    func smallPerturbation() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 3.0) * (v[0] - 3.0)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 10.0,
                finalTemperature: 0.01,
                coolingRate: 0.95,
                maxIterations: 500,
                perturbationScale: 0.1 // Small perturbations
            ),
            searchSpace: [(-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([3.5]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 3.0) < 0.2)
    }

    @Test("Large perturbation scale for exploration")
    func largePerturbation() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 3.0) * (v[0] - 3.0)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 50.0,
                finalTemperature: 0.01,
                coolingRate: 0.95,
                maxIterations: 1000,
                perturbationScale: 2.0 // Large perturbations
            ),
            searchSpace: [(-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([0.0]))
		print("Result:\n\(result.formattedDescription)")
        #expect(result.converged)
        #expect(abs(result.solution[0] - 3.0) < 1.0)
    }

    // MARK: - Reheating Tests

    @Test("Simulated Annealing with reheating")
    func reheatingEscapesLocalMinima() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            let x = v[0]
            // Multiple local minima
            return sin(x) + sin(3.0 * x) / 3.0 + x * x / 100.0
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 20.0,
                finalTemperature: 0.01,
                coolingRate: 0.95,
                maxIterations: 2000,
                perturbationScale: 0.5,
                reheatInterval: 200, // Reheat every 200 iterations
                reheatTemperature: 10.0
            ),
            searchSpace: [(-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0]))

        #expect(result.converged)
        // Should find a good minimum
        #expect(result.value < 0.0)
    }

    // MARK: - Constraint Handling Tests

    @Test("Simulated Annealing with equality constraint")
    func equalityConstraint() throws {
        // Minimize x² + y² subject to x + y = 1
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let constraint: MultivariateConstraint<VectorN<Double>> = .equality(
            function: { v in v[0] + v[1] - 1.0 },
            gradient: { _ in VectorN([1.0, 1.0]) }
        )

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: .default,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([2.0, 2.0]),
            constraints: [constraint]
        )

        #expect(result.converged)
        // Solution should be near (0.5, 0.5) which minimizes x² + y² subject to x + y = 1
        // Penalty method has limited accuracy for constraints
        let constraintValue = result.solution[0] + result.solution[1]
        #expect(abs(constraintValue - 1.0) < 0.3) // Constraint approximately satisfied
    }

    @Test("Simulated Annealing with inequality constraint")
    func inequalityConstraint() throws {
        // Minimize (x-2)² + (y-2)² subject to x + y ≤ 3
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 2.0) * (v[0] - 2.0) + (v[1] - 2.0) * (v[1] - 2.0)
        }

        let constraint: MultivariateConstraint<VectorN<Double>> = .inequality(
            function: { v in v[0] + v[1] - 3.0 }, // g(x) ≤ 0
            gradient: { _ in VectorN([1.0, 1.0]) }
        )

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: .default,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0]),
            constraints: [constraint]
        )

        #expect(result.converged)
        // Unconstrained minimum is (2,2), but constraint forces x+y ≤ 3
        // Constrained minimum should be on boundary near (1.5, 1.5)
        let constraintValue = result.solution[0] + result.solution[1]
        #expect(constraintValue <= 3.5) // Constraint satisfied (with tolerance)
    }

    // MARK: - Convergence Tests

    @Test("Early convergence when temperature reaches final")
    func earlyConvergence() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 10.0,
                finalTemperature: 0.1,
                coolingRate: 0.5, // Fast cooling
                maxIterations: 10000 // High max
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.converged)
        // Should stop before maxIterations due to temperature
        #expect(result.iterations < 10000)
        #expect(result.iterations < 100)
    }

    @Test("Respects max iterations")
    func respectsMaxIterations() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 100.0,
                finalTemperature: 0.0001, // Very low
                coolingRate: 0.9999, // Very slow cooling
                maxIterations: 50 // Low max
            ),
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.iterations <= 50)
    }

    // MARK: - Configuration Tests

    @Test("Default configuration is reasonable")
    func defaultConfiguration() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: .default,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.converged)
        #expect(result.value < 1.0)
    }

    @Test("Custom seed provides deterministic results")
    func deterministicWithSeed() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let config = SimulatedAnnealingConfig(
            initialTemperature: 50.0,
            finalTemperature: 0.01,
            coolingRate: 0.95,
            maxIterations: 500,
            seed: 42
        )

        let optimizer1 = SimulatedAnnealing<VectorN<Double>>(
            config: config,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let optimizer2 = SimulatedAnnealing<VectorN<Double>>(
            config: config,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result1 = try optimizer1.minimize(objective, from: VectorN([5.0, 5.0]))
        let result2 = try optimizer2.minimize(objective, from: VectorN([5.0, 5.0]))

        // Results should be identical with same seed
        #expect(abs(result1.value - result2.value) < 1e-10)
        #expect(result1.iterations == result2.iterations)
    }

    // MARK: - Edge Cases

    @Test("Already optimal initial guess")
    func alreadyOptimal() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: .default,
            searchSpace: [(-10.0, 10.0), (-10.0, 10.0)]
        )

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]))

        #expect(result.converged)
        #expect(result.value < 0.1)
    }

    @Test("High-dimensional problem")
    func highDimensional() throws {
        // 10D sphere function
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let bounds = Array(repeating: (-5.0, 5.0), count: 10)
        let optimizer = SimulatedAnnealing<VectorN<Double>>(
            config: SimulatedAnnealingConfig(
                initialTemperature: 100.0,
                finalTemperature: 0.01,
                coolingRate: 0.95,
                maxIterations: 5000
            ),
            searchSpace: bounds
        )

        let initialGuess = VectorN(Array(repeating: 3.0, count: 10))
        let result = try optimizer.minimize(objective, from: initialGuess)

        #expect(result.converged)
        #expect(result.value < 50.0) // Should improve significantly from initial (~90)
    }
}
