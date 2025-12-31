//
//  NelderMeadTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation
import Testing
@testable import BusinessMath

/// Tests for Nelder-Mead simplex optimizer
@Suite("Nelder-Mead Tests")
struct NelderMeadTests {

    // MARK: - Basic Optimization Tests

    @Test("Nelder-Mead minimizes simple quadratic")
    func simpleQuadratic() throws {
        // f(x,y) = x² + y², minimum at (0, 0)
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(
            objective,
            from: VectorN([5.0, 5.0])
        )

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
        #expect(result.value < 0.1)
    }

    @Test("Nelder-Mead minimizes Rosenbrock function")
    func rosenbrockFunction() throws {
        // f(x,y) = (1-x)² + 100(y-x²)²
        // Global minimum at (1, 1)
        let objective: (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1.0 - x) * (1.0 - x) + 100.0 * (y - x * x) * (y - x * x)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-6,
                maxIterations: 1000
            )
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0])
        )

        #expect(result.converged)
        // Nelder-Mead should get close to (1, 1)
        #expect(abs(result.solution[0] - 1.0) < 0.1)
        #expect(abs(result.solution[1] - 1.0) < 0.1)
        #expect(result.value < 0.1)
    }

    @Test("Nelder-Mead handles non-smooth function")
    func nonSmoothFunction() throws {
        // f(x,y) = |x| + |y|, minimum at (0, 0)
        let objective: (VectorN<Double>) -> Double = { v in
            abs(v[0]) + abs(v[1])
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(
            objective,
            from: VectorN([3.0, 3.0])
        )

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.2)
        #expect(abs(result.solution[1]) < 0.2)
        #expect(result.value < 0.2)
    }

    // MARK: - Simplex Operation Tests

    @Test("Reflection operation improves solution")
    func reflectionOperation() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 2.0) * (v[0] - 2.0)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                reflectionCoefficient: 1.0,
                tolerance: 1e-6,
                maxIterations: 100
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 2.0) < 0.1)
    }

    @Test("Expansion explores promising directions")
    func expansionOperation() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 10.0) * (v[0] - 10.0)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                expansionCoefficient: 2.0,
                tolerance: 1e-6,
                maxIterations: 200
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([0.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 10.0) < 0.5)
    }

    @Test("Contraction refines near minimum")
    func contractionOperation() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                contractionCoefficient: 0.5,
                tolerance: 1e-8,
                maxIterations: 200
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([1.0, 1.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.05)
        #expect(abs(result.solution[1]) < 0.05)
    }

    @Test("Shrink operation when other operations fail")
    func shrinkOperation() throws {
        // Create a difficult valley function
        let objective: (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (x - 1.0) * (x - 1.0) + 100.0 * (y - x * x) * (y - x * x)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                shrinkCoefficient: 0.5,
                tolerance: 1e-4,
                maxIterations: 500
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([2.0, 2.0]))

        #expect(result.converged || result.iterations == 500)
        // Should make significant improvement
        #expect(result.value < 50.0)
    }

    // MARK: - Coefficient Tests

    @Test("Custom simplex coefficients")
    func customCoefficients() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                reflectionCoefficient: 1.5,
                expansionCoefficient: 2.5,
                contractionCoefficient: 0.4,
                shrinkCoefficient: 0.6,
                tolerance: 1e-6,
                maxIterations: 200
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([3.0, 3.0]))

        #expect(result.converged)
        #expect(result.value < 0.1)
    }

    @Test("Adaptive simplex size")
    func adaptiveSimplexSize() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 5.0) * (v[0] - 5.0) + (v[1] - 3.0) * (v[1] - 3.0)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                initialSimplexSize: 2.0,
                tolerance: 1e-6,
                maxIterations: 300
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 5.0) < 0.1)
        #expect(abs(result.solution[1] - 3.0) < 0.1)
    }

    // MARK: - Convergence Tests

    @Test("Converges when simplex size is small")
    func simplexSizeConvergence() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-8,
                maxIterations: 500
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([2.0, 2.0]))

        #expect(result.converged)
        #expect(result.value < 1e-6)
    }

    @Test("Converges when function value improvement is small")
    func functionValueConvergence() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            exp(v.dot(v))
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-4,
                maxIterations: 300
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([1.0, 1.0]))

        #expect(result.converged || result.iterations == 300)
        #expect(result.value < 1.5) // Should find something near minimum
    }

    @Test("Respects max iterations")
    func respectsMaxIterations() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-15, // Impossibly tight
                maxIterations: 10
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.iterations <= 10)
    }

    // MARK: - Constraint Handling Tests

    @Test("Nelder-Mead with equality constraint")
    func equalityConstraint() throws {
        // Minimize x² + y² subject to x + y = 2
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let constraint: MultivariateConstraint<VectorN<Double>> = .equality(
            function: { v in v[0] + v[1] - 2.0 },
            gradient: { _ in VectorN([1.0, 1.0]) }
        )

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(
            objective,
            from: VectorN([3.0, 3.0]),
            constraints: [constraint]
        )

        #expect(result.converged)
        // Solution should be near (1, 1)
        let constraintValue = result.solution[0] + result.solution[1]
        #expect(abs(constraintValue - 2.0) < 0.3)
    }

    @Test("Nelder-Mead with inequality constraint")
    func inequalityConstraint() throws {
        // Minimize (x-3)² + (y-3)² subject to x + y ≤ 4
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 3.0) * (v[0] - 3.0) + (v[1] - 3.0) * (v[1] - 3.0)
        }

        let constraint: MultivariateConstraint<VectorN<Double>> = .inequality(
            function: { v in v[0] + v[1] - 4.0 },
            gradient: { _ in VectorN([1.0, 1.0]) }
        )

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.0, 0.0]),
            constraints: [constraint]
        )

        #expect(result.converged)
        // Constrained minimum on boundary near (2, 2)
        let constraintValue = result.solution[0] + result.solution[1]
        #expect(constraintValue <= 4.5)
    }

    // MARK: - Dimensional Tests

    @Test("1D optimization")
    func oneDimensional() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 7.0) * (v[0] - 7.0)
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(objective, from: VectorN([0.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 7.0) < 0.1)
    }

    @Test("High-dimensional optimization")
    func highDimensional() throws {
        // 5D sphere function
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-4,
                maxIterations: 1000
            )
        )

        let initialGuess = VectorN(Array(repeating: 2.0, count: 5))
        let result = try optimizer.minimize(objective, from: initialGuess)

        #expect(result.converged || result.iterations == 1000)
        #expect(result.value < 1.0) // Should significantly improve
    }

    // MARK: - Configuration Tests

    @Test("Default configuration is reasonable")
    func defaultConfiguration() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(objective, from: VectorN([3.0, 3.0]))

        #expect(result.converged)
        #expect(result.value < 0.1)
    }

    @Test("High precision configuration")
    func highPrecisionConfiguration() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .highPrecision)

        let result = try optimizer.minimize(objective, from: VectorN([2.0, 2.0]))

        #expect(result.converged)
        #expect(result.value < 1e-6)
    }

    // MARK: - Edge Cases

    @Test("Already optimal initial guess")
    func alreadyOptimal() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            v.dot(v)
        }

        let optimizer = NelderMead<VectorN<Double>>(config: .default)

        let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]))

        #expect(result.converged)
        // Nelder-Mead needs to establish simplex even at optimal point
        #expect(result.iterations < 50)
        #expect(result.value < 0.01)
    }

    @Test("Difficult initial guess far from minimum")
    func difficultInitialGuess() throws {
        let objective: (VectorN<Double>) -> Double = { v in
            (v[0] - 5.0) * (v[0] - 5.0)
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-6,
                maxIterations: 300
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([100.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0] - 5.0) < 0.5)
    }

    @Test("Flat region near minimum")
    func flatRegion() throws {
        // Function with flat region
        let objective: (VectorN<Double>) -> Double = { v in
            let x = v[0]
            return x * x * x * x // Very flat near origin
        }

        let optimizer = NelderMead<VectorN<Double>>(
            config: NelderMeadConfig(
                tolerance: 1e-4,
                maxIterations: 200
            )
        )

        let result = try optimizer.minimize(objective, from: VectorN([2.0]))

        #expect(result.converged || result.iterations == 200)
        #expect(abs(result.solution[0]) < 1.0)
    }
}
