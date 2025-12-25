import Testing
import Numerics
@testable import BusinessMath

@Suite("MultivariateOptimizer Protocol Tests")
struct MultivariateOptimizerProtocolTests {

    @Test("Protocol conformance - GradientDescent")
    func gradientDescentConformance() throws {
        // Use protocol type to test polymorphism
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.01,
            maxIterations: 1000,
            tolerance: 0.0001
        )

        // Simple quadratic function: f(x,y) = x² + y²
        // Minimum at (0,0)
        let objective = { (v: VectorN<Double>) -> Double in
            v.dot(v)
        }

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        // Solution should be near origin
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
        #expect(result.objectiveValue < 0.01)
    }

    @Test("Protocol conformance - NewtonRaphson")
    func newtonRaphsonConformance() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateNewtonRaphson<VectorN<Double>>(
            maxIterations: 100,
            tolerance: 0.0001
        )

        let objective = { (v: VectorN<Double>) -> Double in
            v.dot(v)
        }

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(abs(result.solution[0]) < 0.01)
        #expect(abs(result.solution[1]) < 0.01)
    }

    @Test("Unconstrained optimizer rejects constraints")
    func unconstrainedRejectsConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.01,
            maxIterations: 1000
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let constraint: MultivariateConstraint<VectorN<Double>> = .equality { v in v[0] - 1.0 }

        #expect(throws: OptimizationError.self) {
            try optimizer.minimize(objective, from: VectorN([5.0, 5.0]), constraints: [constraint])
        }
    }

    @Test("Constrained optimizer accepts equality constraints")
    func constrainedAcceptsEqualityConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer<VectorN<Double>>()

        // Minimize x² + y² subject to x = 1
        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let constraint: MultivariateConstraint<VectorN<Double>> = .equality { v in v[0] - 1.0 }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([5.0, 5.0]),
            constraints: [constraint]
        )

        // x should be constrained to 1, y should be 0
        #expect(abs(result.solution[0] - 1.0) < 0.01)
        #expect(abs(result.solution[1]) < 0.01)
    }

    @Test("Constrained optimizer accepts inequality constraints")
    func constrainedAcceptsInequalityConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer<VectorN<Double>>()

        // Minimize x² + y² subject to x ≥ 1 (i.e., 1 - x ≤ 0)
        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let constraint: MultivariateConstraint<VectorN<Double>> = .inequality { v in 1.0 - v[0] }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([5.0, 5.0]),
            constraints: [constraint]
        )

        // x should be at boundary (x=1), y should be 0
        #expect(abs(result.solution[0] - 1.0) < 0.01)
        #expect(abs(result.solution[1]) < 0.01)
    }

    @Test("Algorithm swapping at runtime")
    func algorithmSwapping() throws {
        // Test polymorphism - same problem, different algorithms
        let algorithms: [any MultivariateOptimizer<VectorN<Double>>] = [
            MultivariateGradientDescent(
                learningRate: 0.01,
                maxIterations: 1000,
                tolerance: 0.0001
            ),
            MultivariateNewtonRaphson(
                maxIterations: 100,
                tolerance: 0.0001
            )
        ]

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        for optimizer in algorithms {
            let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

            // Both algorithms should find the same solution
            #expect(abs(result.solution[0]) < 0.1)
            #expect(abs(result.solution[1]) < 0.1)
            #expect(result.objectiveValue < 0.01)
        }
    }

    @Test("Convenience method without constraints")
    func convenienceMethodWithoutConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.01,
            maxIterations: 1000
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        // Should be able to call without specifying constraints parameter
        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
    }

    @Test("Equality-only optimizer rejects inequality constraints")
    func equalityOnlyRejectsInequality() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = ConstrainedOptimizer<VectorN<Double>>()

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let inequality: MultivariateConstraint<VectorN<Double>> = .inequality { v in 1.0 - v[0] }

        #expect(throws: OptimizationError.self) {
            try optimizer.minimize(objective, from: VectorN([5.0, 5.0]), constraints: [inequality])
        }
    }

    @Test("Result type contains expected fields")
    func resultTypeFields() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.01,
            maxIterations: 1000
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        // Verify all expected result fields are accessible
        _ = result.solution  // VectorN<Double>
        _ = result.objectiveValue  // Double
        _ = result.iterations  // Int
        _ = result.convergenceReason  // String or similar
    }

    @Test("Protocol works with different vector types")
    func differentVectorTypes() throws {
        // Test with Vector2D
        let optimizer2D: any MultivariateOptimizer<Vector2D<Double>> = MultivariateGradientDescent<Vector2D<Double>>(
            learningRate: 0.01,
            maxIterations: 1000
        )

        let objective2D = { (v: Vector2D<Double>) -> Double in
            v.x * v.x + v.y * v.y
        }

        let result2D = try optimizer2D.minimize(objective2D, from: Vector2D(x: 5.0, y: 5.0))

        #expect(abs(result2D.solution.x) < 0.1)
        #expect(abs(result2D.solution.y) < 0.1)

        // Test with Vector3D
        let optimizer3D: any MultivariateOptimizer<Vector3D<Double>> = MultivariateGradientDescent<Vector3D<Double>>(
            learningRate: 0.01,
            maxIterations: 1000
        )

        let objective3D = { (v: Vector3D<Double>) -> Double in
            v.x * v.x + v.y * v.y + v.z * v.z
        }

        let result3D = try optimizer3D.minimize(objective3D, from: Vector3D(x: 5.0, y: 5.0, z: 5.0))

        #expect(abs(result3D.solution.x) < 0.1)
        #expect(abs(result3D.solution.y) < 0.1)
        #expect(abs(result3D.solution.z) < 0.1)
    }
}
