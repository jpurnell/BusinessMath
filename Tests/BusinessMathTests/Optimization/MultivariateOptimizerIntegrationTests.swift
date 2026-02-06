import Testing
import Numerics
@testable import BusinessMath

@Suite("MultivariateOptimizer Integration Tests", .serialized)
struct MultivariateOptimizerIntegrationTests {

    // MARK: - Individual Optimizer Conformance Tests

    @Test("MultivariateGradientDescent - All variants work via protocol")
    func gradientDescentVariants() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 1000
        )

        // Simple quadratic: f(x,y) = x² + y²
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
        #expect(result.objectiveValue < 0.01)
    }

    @Test("MultivariateNewtonRaphson - Protocol conformance")
    func newtonRaphsonConformance() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateNewtonRaphson(
            maxIterations: 100,
            tolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let result = try optimizer.minimize(objective, from: VectorN([3.0, 4.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.01)
        #expect(abs(result.solution[1]) < 0.01)
    }

    @Test("ConstrainedOptimizer - Equality constraints via protocol")
    func constrainedOptimizerViaProtocol() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = ConstrainedOptimizer()

        // Minimize x² + y² subject to x + y = 1
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in
            v[0] + v[1] - 1.0
        }

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            constraints: [constraint]
        )

        #expect(result.converged)
        // Solution should be [0.5, 0.5] (equal split minimizes sum of squares)
        #expect(abs(result.solution[0] - 0.5) < 0.05)
        #expect(abs(result.solution[1] - 0.5) < 0.05)
        // Constraint should be satisfied
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 0.01)
    }

    @Test("InequalityOptimizer - Mixed constraints via protocol")
    func inequalityOptimizerViaProtocol() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        // Budget constraint (equality) + non-negativity (inequality)
        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budgetConstraint
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            constraints: constraints
        )

        #expect(result.converged)
        #expect(result.solution[0] >= -0.01)  // Non-negative
        #expect(result.solution[1] >= -0.01)  // Non-negative
        #expect(abs(result.solution[0] + result.solution[1] - 1.0) < 0.01)  // Budget
    }

    @Test("AdaptiveOptimizer - Automatic algorithm selection")
    func adaptiveOptimizerViaProtocol() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = AdaptiveOptimizer(
            maxIterations: 1000,
            tolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let result = try optimizer.minimize(objective, from: VectorN([2.0, 3.0]))

        #expect(result.converged)
        #expect(abs(result.solution[0]) < 0.1)
        #expect(abs(result.solution[1]) < 0.1)
    }

    // MARK: - Constraint Validation Tests

    @Test("Protocol - Unconstrained optimizer rejects equality constraints")
    func unconstrainedRejectsEquality() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 100
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.equality { v in v[0] - 1.0 }

        #expect(throws: OptimizationError.self) {
            try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [constraint])
        }
    }

    @Test("Protocol - Unconstrained optimizer rejects inequality constraints")
    func unconstrainedRejectsInequality() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateNewtonRaphson(
            maxIterations: 100,
            tolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.inequality { v in v[0] - 1.0 }

        #expect(throws: OptimizationError.self) {
            try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [constraint])
        }
    }

    @Test("Protocol - ConstrainedOptimizer rejects inequality constraints")
    func constrainedRejectsInequality() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = ConstrainedOptimizer()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let inequality = MultivariateConstraint<VectorN<Double>>.inequality { v in v[0] - 1.0 }

        #expect(throws: OptimizationError.self) {
            try optimizer.minimize(objective, from: VectorN([0.0, 0.0]), constraints: [inequality])
        }
    }

    @Test("Protocol - InequalityOptimizer accepts both constraint types")
    func inequalityAcceptsBoth() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let equality = MultivariateConstraint<VectorN<Double>>.equality { v in v[0] + v[1] - 1.0 }
        let inequality = MultivariateConstraint<VectorN<Double>>.inequality { v in -v[0] }  // x >= 0

        // Should not throw
        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            constraints: [equality, inequality]
        )

        #expect(result.solution[0] >= -0.01)  // Satisfies inequality
    }

    // MARK: - Integration with Real Problems

    @Test("Protocol - Rosenbrock function optimization")
    func rosenbrockOptimization() throws {
        // Rosenbrock: f(x,y) = (1-x)² + 100(y-x²)²
        // Global minimum at (1, 1) with value 0
        let rosenbrock: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v[0], y = v[1]
            return (1 - x) * (1 - x) + 100 * (y - x*x) * (y - x*x)
        }

        let optimizers: [any MultivariateOptimizer<VectorN<Double>>] = [
            MultivariateNewtonRaphson(maxIterations: 200, tolerance: 1e-6),
            AdaptiveOptimizer(maxIterations: 1000, tolerance: 1e-4)
        ]

        for optimizer in optimizers {
            let result = try optimizer.minimize(rosenbrock, from: VectorN([0.0, 0.0]))

            // All optimizers should find solution near (1, 1)
            #expect(abs(result.solution[0] - 1.0) < 0.1)
            #expect(abs(result.solution[1] - 1.0) < 0.1)
            #expect(result.objectiveValue < 1.0)
        }
    }

    @Test("Protocol - Portfolio variance minimization")
    func portfolioVarianceMinimization() throws {
        // 3-asset portfolio with given covariance matrix
        let covariance = [
            [0.04, 0.01, 0.02],
            [0.01, 0.09, 0.03],
            [0.02, 0.03, 0.16]
        ]

        let variance = { (weights: VectorN<Double>) -> Double in
            let w = weights.toArray()
            var v = 0.0
            for i in 0..<3 {
                for j in 0..<3 {
                    v += w[i] * covariance[i][j] * w[j]
                }
            }
            return v
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budgetConstraint
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer(
            maxIterations: 100
        )

        let result = try optimizer.minimize(
            variance,
            from: VectorN([1.0/3, 1.0/3, 1.0/3]),
            constraints: constraints
        )

        #expect(result.converged)
        // Weights should sum to 1
        let sum = result.solution.toArray().reduce(0.0, +)
        #expect(abs(sum - 1.0) < 0.01)
        // All weights should be non-negative
        for w in result.solution.toArray() {
            #expect(w >= -0.01)
        }
        // Variance should be positive
        #expect(result.objectiveValue > 0)
    }

    @Test("Protocol - Multi-dimensional optimization (10D)")
    func highDimensionalOptimization() throws {
        let dimension = 10

        // Sum of squares: f(x) = Σxᵢ²
        let sumOfSquares: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let initialGuess = VectorN(Array(repeating: 5.0, count: dimension))

        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.05,
            maxIterations: 2000,
            tolerance: 1e-3
        )

        let result = try optimizer.minimize(sumOfSquares, from: initialGuess)

        #expect(result.converged)
        // All components should be near zero
        for i in 0..<dimension {
            #expect(abs(result.solution[i]) < 0.5)
        }
    }

    // MARK: - Different Vector Types

    @Test("Protocol - Vector2D optimization")
    func vector2DOptimization() throws {
        let optimizer: any MultivariateOptimizer<Vector2D<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 500
        )

        let objective = { (v: Vector2D<Double>) -> Double in
            v.x * v.x + v.y * v.y
        }

        let result = try optimizer.minimize(objective, from: Vector2D(x: 3.0, y: 4.0))

        #expect(result.converged)
        #expect(abs(result.solution.x) < 0.1)
        #expect(abs(result.solution.y) < 0.1)
    }

    @Test("Protocol - Vector3D optimization")
    func vector3DOptimization() throws {
        let optimizer: any MultivariateOptimizer<Vector3D<Double>> = MultivariateNewtonRaphson(
            maxIterations: 100,
            tolerance: 1e-6
        )

        let objective = { (v: Vector3D<Double>) -> Double in
            v.x * v.x + v.y * v.y + v.z * v.z
        }

        let result = try optimizer.minimize(objective, from: Vector3D(x: 1.0, y: 2.0, z: 3.0))

        #expect(result.converged)
        #expect(abs(result.solution.x) < 0.01)
        #expect(abs(result.solution.y) < 0.01)
        #expect(abs(result.solution.z) < 0.01)
    }

    // MARK: - Algorithm Comparison

    @Test("Protocol - Algorithm comparison on same problem")
    func algorithmComparison() throws {
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            (v[0] - 2) * (v[0] - 2) + (v[1] - 3) * (v[1] - 3)
        }

        let algorithms: [(name: String, optimizer: any MultivariateOptimizer<VectorN<Double>>)] = [
            ("GradientDescent", MultivariateGradientDescent(learningRate: 0.1, maxIterations: 1000)),
            ("NewtonRaphson", MultivariateNewtonRaphson(maxIterations: 100, tolerance: 1e-6)),
            ("Adaptive", AdaptiveOptimizer(maxIterations: 500))
        ]

        for (name, optimizer) in algorithms {
            let result = try optimizer.minimize(objective, from: VectorN([0.0, 0.0]))

            // All should converge to (2, 3)
            #expect(result.converged, "Algorithm \(name) did not converge")
            #expect(abs(result.solution[0] - 2.0) < 0.1, "Algorithm \(name) x-coordinate incorrect")
            #expect(abs(result.solution[1] - 3.0) < 0.1, "Algorithm \(name) y-coordinate incorrect")
        }
    }

    // MARK: - Constraint Combinations

    @Test("Protocol - Multiple equality constraints")
    func multipleEqualityConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer()

        // Minimize x² + y² + z²
        // Subject to: x + y + z = 1, x + 2y = 0.5
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.equality { v in
                v[0] + v[1] + v[2] - 1.0
            },
            MultivariateConstraint<VectorN<Double>>.equality { v in
                v[0] + 2 * v[1] - 0.5
            }
        ]

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.3, 0.3, 0.4]),
            constraints: constraints
        )

        #expect(result.converged)
        // Verify constraint satisfaction
        let c1 = result.solution[0] + result.solution[1] + result.solution[2]
        let c2 = result.solution[0] + 2 * result.solution[1]
        #expect(abs(c1 - 1.0) < 0.01)
        #expect(abs(c2 - 0.5) < 0.01)
    }

    @Test("Protocol - Box constraints (mixed inequality)")
    func boxConstraints() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer()

        // Minimize (x-2)² + (y-3)²
        // Subject to: 0 ≤ x ≤ 1, 0 ≤ y ≤ 1
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            (v[0] - 2) * (v[0] - 2) + (v[1] - 3) * (v[1] - 3)
        }

        let constraints = MultivariateConstraint<VectorN<Double>>.boxConstraints(
            min: 0.0,
            max: 1.0,
            dimension: 2
        )

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            constraints: constraints
        )

        #expect(result.converged)
        // Solution should be at boundary (1, 1) since unconstrained optimum is (2, 3)
        #expect(result.solution[0] >= -0.01 && result.solution[0] <= 1.01)
        #expect(result.solution[1] >= -0.01 && result.solution[1] <= 1.01)
        #expect(abs(result.solution[0] - 1.0) < 0.1)  // Should be near upper bound
        #expect(abs(result.solution[1] - 1.0) < 0.1)  // Should be near upper bound
    }

    // MARK: - Result Type Verification

    @Test("Protocol - Result contains all required fields")
    func resultFieldsPresent() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 100
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([1.0, 1.0]))

        // Verify all protocol-required fields are accessible
        _ = result.solution  // VectorN<Double>
        _ = result.objectiveValue  // Double
        _ = result.iterations  // Int
        _ = result.converged  // Bool
        _ = result.convergenceReason  // String

        #expect(result.iterations > 0)
        #expect(!result.convergenceReason.isEmpty)
    }

    @Test("Protocol - Convergence reason is informative")
    func convergenceReasonInformative() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 10  // Low limit to test non-convergence
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([100.0, 100.0]))

        // Should have meaningful convergence reason
        #expect(!result.convergenceReason.isEmpty)
        #expect(result.convergenceReason.count > 10)  // Should be descriptive
    }
}
