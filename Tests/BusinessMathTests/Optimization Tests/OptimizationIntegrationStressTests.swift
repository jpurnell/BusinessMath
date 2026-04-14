//
//  OptimizationIntegrationStressTests.swift
//  BusinessMath
//
//  Integration stress tests for the full optimization pipeline.
//  Uses seeded RNG for reproducibility across CI runs.
//

import Foundation
import Testing
@testable import BusinessMath

// MARK: - Seeded RNG Helper (Optimization)

/// A simple seeded random number generator for reproducible optimization stress tests.
/// Marked @unchecked Sendable because stress tests run serialized.
private final class OptSeededRNG: @unchecked Sendable {
    // Justification: Tests run serialized; no concurrent access to drand48 state.
    init(seed: Int) {
        srand48(seed)
    }

    /// Returns a uniform random Double in [low, high).
    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let low = range.lowerBound
        let high = range.upperBound
        return low + (high - low) * drand48()
    }
}

// MARK: - Test Functions

/// Standard test functions for optimization stress testing.
/// All are @Sendable closures suitable for MultivariateGradientDescent.
private enum TestFunctions {

    /// Sphere function: f(x) = sum(x_i^2). Minimum at origin, value = 0.
    static let sphere: @Sendable (VectorN<Double>) -> Double = { v in
        let arr = v.toArray()
        return arr.reduce(0.0) { $0 + $1 * $1 }
    }

    /// Rosenbrock function: f(x,y) = (1-x)^2 + 100(y - x^2)^2. Minimum at (1,1), value = 0.
    static let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        return (1 - x) * (1 - x) + 100 * (y - x * x) * (y - x * x)
    }

    /// Booth function: f(x,y) = (x + 2y - 7)^2 + (2x + y - 5)^2. Minimum at (1,3), value = 0.
    static let booth: @Sendable (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        return (x + 2 * y - 7) * (x + 2 * y - 7) + (2 * x + y - 5) * (2 * x + y - 5)
    }

    /// Beale function: f(x,y) = (1.5 - x + xy)^2 + (2.25 - x + xy^2)^2 + (2.625 - x + xy^3)^2.
    /// Minimum at (3, 0.5), value = 0.
    static let beale: @Sendable (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        let t1 = 1.5 - x + x * y
        let t2 = 2.25 - x + x * y * y
        let t3 = 2.625 - x + x * y * y * y
        return t1 * t1 + t2 * t2 + t3 * t3
    }

    /// Matyas function: f(x,y) = 0.26(x^2 + y^2) - 0.48xy. Minimum at (0,0), value = 0.
    static let matyas: @Sendable (VectorN<Double>) -> Double = { v in
        let x = v[0], y = v[1]
        return 0.26 * (x * x + y * y) - 0.48 * x * y
    }
}

// MARK: - Tests

@Suite("Optimization Integration Stress Tests", .serialized)
struct OptimizationIntegrationStressTests {

    // MARK: - D.2.1: Randomized Starting Points on Quadratic

    @Test("Randomized starting points on sphere function - 100 iterations")
    func randomizedStartingPointsQuadratic() throws {
        let rng = OptSeededRNG(seed: 42)

        let optimizer = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.1,
            maxIterations: 1000,
            tolerance: 1e-6
        )

        for _ in 0..<100 {
            let x0 = rng.nextDouble(in: -10.0...10.0)
            let y0 = rng.nextDouble(in: -10.0...10.0)
            let initialGuess = VectorN([x0, y0])

            let result = try optimizer.minimize(
                function: TestFunctions.sphere,
                initialGuess: initialGuess
            )

            // Assert: solution values are finite (no NaN)
            let solutionArray = result.solution.toArray()
            for component in solutionArray {
                #expect(component.isFinite)
            }

            // Assert: function value is finite
            #expect(result.value.isFinite)

            // For sphere function with learning rate 0.1, expect convergence
            if result.converged {
                // If converged, solution should be near origin
                #expect(result.value < 1e-6)
            }
        }
    }

    // MARK: - D.2.2: Randomized Starting Points on Rosenbrock

    @Test("Randomized starting points on Rosenbrock - 50 iterations")
    func randomizedStartingPointsRosenbrock() throws {
        let rng = OptSeededRNG(seed: 42)

        // Rosenbrock is harder; use more iterations
        let optimizer = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.001,
            maxIterations: 5000,
            tolerance: 1e-6
        )

        for _ in 0..<50 {
            let x0 = rng.nextDouble(in: -5.0...5.0)
            let y0 = rng.nextDouble(in: -5.0...5.0)
            let initialGuess = VectorN([x0, y0])

            let result = try optimizer.minimize(
                function: TestFunctions.rosenbrock,
                initialGuess: initialGuess
            )

            // Assert: solution values are finite
            let solutionArray = result.solution.toArray()
            for component in solutionArray {
                #expect(component.isFinite)
            }

            // Assert: function value is finite
            #expect(result.value.isFinite)

            // Assert: iterations is non-negative
            #expect(result.iterations >= 0)
        }
    }

    // MARK: - D.2.3: Curated Test Functions

    @Test("Curated test functions with random starts - 4 functions x 10 starts")
    func curatedTestFunctions() throws {
        let rng = OptSeededRNG(seed: 42)

        struct NamedFunction {
            let name: String
            let function: @Sendable (VectorN<Double>) -> Double
            let searchRange: ClosedRange<Double>
            let learningRate: Double
            let maxIterations: Int
        }

        let functions: [NamedFunction] = [
            NamedFunction(
                name: "Sphere",
                function: TestFunctions.sphere,
                searchRange: -10.0...10.0,
                learningRate: 0.1,
                maxIterations: 1000
            ),
            NamedFunction(
                name: "Booth",
                function: TestFunctions.booth,
                searchRange: -10.0...10.0,
                learningRate: 0.01,
                maxIterations: 2000
            ),
            NamedFunction(
                name: "Beale",
                function: TestFunctions.beale,
                searchRange: -4.5...4.5,
                learningRate: 0.0001,
                maxIterations: 5000
            ),
            NamedFunction(
                name: "Matyas",
                function: TestFunctions.matyas,
                searchRange: -10.0...10.0,
                learningRate: 0.1,
                maxIterations: 1000
            ),
        ]

        for namedFunc in functions {
            let optimizer = MultivariateGradientDescent<VectorN<Double>>(
                learningRate: namedFunc.learningRate,
                maxIterations: namedFunc.maxIterations,
                tolerance: 1e-8
            )

            for _ in 0..<10 {
                let x0 = rng.nextDouble(in: namedFunc.searchRange)
                let y0 = rng.nextDouble(in: namedFunc.searchRange)
                let initialGuess = VectorN([x0, y0])

                let result = try optimizer.minimize(
                    function: namedFunc.function,
                    initialGuess: initialGuess
                )

                // Assert: solution values are finite
                let solutionArray = result.solution.toArray()
                for component in solutionArray {
                    #expect(component.isFinite)
                }

                // Assert: function value is finite
                #expect(result.value.isFinite)

                // Assert: iterations is non-negative
                #expect(result.iterations >= 0)
            }
        }
    }
}
