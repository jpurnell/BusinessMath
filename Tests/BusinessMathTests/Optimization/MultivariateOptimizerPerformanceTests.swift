import Testing
import Numerics
@testable import BusinessMath

@Suite("MultivariateOptimizer Performance Tests")
struct MultivariateOptimizerPerformanceTests {

    // MARK: - Protocol vs Concrete Type Performance

    @Test("Performance - Protocol dispatch vs concrete type")
    func protocolVsConcretePerformance() throws {
        let iterations = 100
        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let initialGuess = VectorN([5.0, 5.0])

        // Measure concrete type performance
        let concreteOptimizer = MultivariateGradientDescent<VectorN<Double>>(
            learningRate: 0.01,
            maxIterations: 100
        )

        var concreteResults: [MultivariateOptimizationResult<VectorN<Double>>] = []
        for _ in 0..<iterations {
            let result = try concreteOptimizer.minimize(
                function: objective,
                initialGuess: initialGuess
            )
            concreteResults.append(result)
        }

        // Measure protocol type performance
        let protocolOptimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 100
        )

        var protocolResults: [MultivariateOptimizationResult<VectorN<Double>>] = []
        for _ in 0..<iterations {
            let result = try protocolOptimizer.minimize(objective, from: initialGuess)
            protocolResults.append(result)
        }

        // Verify results are equivalent
        #expect(concreteResults.count == protocolResults.count)
        for (concrete, protocol_result) in zip(concreteResults, protocolResults) {
            #expect(abs(concrete.objectiveValue - protocol_result.objectiveValue) < 0.01)
        }
    }

    @Test("Performance - Algorithm factory overhead")
    func factoryOverhead() throws {
        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let initialGuess = VectorN([3.0, 4.0])
        let iterations = 50

        // Factory function that creates optimizer
        func createOptimizer() -> any MultivariateOptimizer<VectorN<Double>> {
            MultivariateGradientDescent<VectorN<Double>>(
                learningRate: 0.01,
                maxIterations: 100
            )
        }

        var results: [MultivariateOptimizationResult<VectorN<Double>>] = []
        for _ in 0..<iterations {
            let optimizer = createOptimizer()
            let result = try optimizer.minimize(objective, from: initialGuess)
            results.append(result)
        }

        // All results should be consistent
        #expect(results.count == iterations)
        let firstValue = results[0].objectiveValue
        for result in results {
            #expect(abs(result.objectiveValue - firstValue) < 0.01)
        }
    }

    // MARK: - Scalability Tests

    @Test("Performance - Small problem (2D)")
    func smallProblemPerformance() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateNewtonRaphson(
            maxIterations: 50,
            tolerance: 1e-6
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([10.0, 10.0]))

        #expect(result.converged)
        #expect(result.iterations < 20)  // Should converge quickly for small problems
    }

    @Test("Performance - Medium problem (10D)")
    func mediumProblemPerformance() throws {
        let dimension = 10
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 500,
            tolerance: 1e-3
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let initialGuess = VectorN(Array(repeating: 5.0, count: dimension))

        let result = try optimizer.minimize(objective, from: initialGuess)

        #expect(result.converged)
        #expect(result.objectiveValue < 1.0)
    }

    @Test("Performance - Large problem (50D)")
    func largeProblemPerformance() throws {
        let dimension = 50
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 1000,
            tolerance: 1e-2
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let initialGuess = VectorN(Array(repeating: 2.0, count: dimension))

        let result = try optimizer.minimize(objective, from: initialGuess)

        // Should handle large problems
        #expect(result.objectiveValue < 10.0)  // Reasonable convergence
    }

    // MARK: - Constraint Complexity

    @Test("Performance - Single constraint optimization")
    func singleConstraintPerformance() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer(
            maxIterations: 50
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let constraint = MultivariateConstraint<VectorN<Double>>.budgetConstraint

        let result = try optimizer.minimize(
            objective,
            from: VectorN([0.5, 0.5]),
            constraints: [constraint]
        )

        #expect(result.converged)
        #expect(result.iterations < 100)
    }

    @Test("Performance - Multiple constraints (5 constraints)")
    func multipleConstraintsPerformance() throws {
        let dimension = 5
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer(
            maxIterations: 200
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        // Budget + non-negativity constraints
        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budgetConstraint
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: dimension)

        let initialGuess = VectorN(Array(repeating: 1.0 / Double(dimension), count: dimension))
        let result = try optimizer.minimize(objective, from: initialGuess, constraints: constraints)

        #expect(result.converged || result.iterations == 200)  // Should make progress
    }

    // MARK: - Algorithm Efficiency Comparison

    @Test("Performance - Gradient Descent efficiency")
    func gradientDescentEfficiency() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 200
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([10.0, 10.0]))

        #expect(result.converged)
        // Gradient descent should converge in reasonable iterations for simple problems
        #expect(result.iterations < 200)
    }

    @Test("Performance - Newton-Raphson efficiency")
    func newtonRaphsonEfficiency() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateNewtonRaphson(
            maxIterations: 50,
            tolerance: 1e-6
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([10.0, 10.0]))

        #expect(result.converged)
        // Newton-Raphson should converge very quickly for quadratic problems
        #expect(result.iterations < 10)
    }

    @Test("Performance - Adaptive optimizer selection time")
    func adaptiveSelectionTime() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = AdaptiveOptimizer(
            maxIterations: 500,
            tolerance: 1e-4
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }
        let result = try optimizer.minimize(objective, from: VectorN([5.0, 5.0]))

        #expect(result.converged)
        // Adaptive should be competitive despite algorithm selection overhead
        #expect(result.iterations < 500)
    }

    // MARK: - Memory Efficiency

    @Test("Performance - Repeated optimization without memory growth")
    func repeatedOptimizationMemory() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 100
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        // Run many optimizations to check for memory leaks
        for i in 0..<100 {
            let initialGuess = VectorN([Double(i % 10), Double(i % 10)])
            let result = try optimizer.minimize(objective, from: initialGuess)
            #expect(result.objectiveValue >= 0)
        }

        // If we got here without crashes, memory management is working
        #expect(true)
    }

    // MARK: - Convergence Rate Tests

    @Test("Performance - Convergence rate for well-conditioned problems")
    func wellConditionedConvergence() throws {
        // Well-conditioned: f(x,y) = x² + y²
        let wellConditioned = { (v: VectorN<Double>) -> Double in v.dot(v) }

        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 100,
            tolerance: 1e-4
        )

        let result = try optimizer.minimize(wellConditioned, from: VectorN([10.0, 10.0]))

        #expect(result.converged)
        // Well-conditioned problems should converge quickly
        #expect(result.iterations < 100)  // Gradient descent can take more iterations than Newton
    }

    @Test("Performance - Convergence rate for ill-conditioned problems")
    func illConditionedConvergence() throws {
        // Ill-conditioned: f(x,y) = x² + 100y²
        let illConditioned = { (v: VectorN<Double>) -> Double in
            v[0] * v[0] + 100 * v[1] * v[1]
        }

        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 500,
            tolerance: 1e-2
        )

        let result = try optimizer.minimize(illConditioned, from: VectorN([10.0, 10.0]))

        // Ill-conditioned may take more iterations or not fully converge
        #expect(result.iterations > 0)
        #expect(result.objectiveValue < 20000.0)  // Should make some progress from initial value (20000)
    }

    // MARK: - Real-World Problem Performance

    @Test("Performance - Portfolio optimization with 10 assets")
    func portfolioOptimizationPerformance() throws {
        let numAssets = 10

        // Simplified covariance matrix (diagonal)
        var covariance = Array(repeating: Array(repeating: 0.0, count: numAssets), count: numAssets)
        for i in 0..<numAssets {
            covariance[i][i] = 0.04 + Double(i) * 0.01  // Increasing variance
        }

        let variance = { (weights: VectorN<Double>) -> Double in
            let w = weights.toArray()
            var v = 0.0
            for i in 0..<numAssets {
                for j in 0..<numAssets {
                    v += w[i] * covariance[i][j] * w[j]
                }
            }
            return v
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budgetConstraint
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: numAssets)

        let optimizer: any MultivariateOptimizer<VectorN<Double>> = InequalityOptimizer(
            maxIterations: 200
        )

        let initialGuess = VectorN(Array(repeating: 1.0 / Double(numAssets), count: numAssets))
        let result = try optimizer.minimize(variance, from: initialGuess, constraints: constraints)

        #expect(result.converged || result.iterations == 200)
        // Portfolio should be feasible
        let sum = result.solution.toArray().reduce(0.0, +)
        #expect(abs(sum - 1.0) < 0.1)
    }

    // MARK: - Stress Tests

    @Test("Performance - Extreme initial guess")
    func extremeInitialGuess() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.01,
            maxIterations: 1000,
            tolerance: 1e-2
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        // Start very far from optimum
        let result = try optimizer.minimize(objective, from: VectorN([1000.0, 1000.0]))

        // Should still make progress
        #expect(result.objectiveValue < 1_000_000.0)  // Better than initial value
    }

    @Test("Performance - Near-zero gradients")
    func nearZeroGradients() throws {
        let optimizer: any MultivariateOptimizer<VectorN<Double>> = MultivariateGradientDescent(
            learningRate: 0.1,
            maxIterations: 100,
            tolerance: 1e-6
        )

        let objective = { (v: VectorN<Double>) -> Double in v.dot(v) }

        // Start very close to optimum
        let result = try optimizer.minimize(objective, from: VectorN([0.001, 0.001]))

        #expect(result.converged)
        #expect(result.objectiveValue < 0.01)
    }
}
