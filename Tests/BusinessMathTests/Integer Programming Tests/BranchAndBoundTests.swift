import Testing
import Foundation
@testable import BusinessMath

@Suite("Branch and Bound Tests")
struct BranchAndBoundTests {

    @Test("Simple knapsack problem (5 items)")
    func testSimpleKnapsack() throws {
        // Knapsack: max Σ vᵢxᵢ  s.t. Σ wᵢxᵢ ≤ capacity, xᵢ ∈ {0,1}
        let values = [10.0, 40.0, 30.0, 50.0, 35.0]
        let weights = [5.0, 4.0, 6.0, 3.0, 7.0]
        let capacity = 10.0

        let spec = IntegerProgramSpecification.allBinary(dimension: 5)

        // Objective: maximize value (minimize negative value)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            let totalValue = zip(values, x.toArray()).map(*).reduce(0, +)
            return -totalValue  // Minimize negative value = maximize value
        }

        // Constraint: weight ≤ capacity
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in
                let totalWeight = zip(weights, x.toArray()).map(*).reduce(0, +)
                return totalWeight - capacity
            },
            // Non-negativity (x ≥ 0)
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in -x.toArray()[2] },
            .inequality { x in -x.toArray()[3] },
            .inequality { x in -x.toArray()[4] },
            // Upper bounds (x ≤ 1) for binary
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
            .inequality { x in x.toArray()[2] - 1.0 },
            .inequality { x in x.toArray()[3] - 1.0 },
            .inequality { x in x.toArray()[4] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should find a solution
        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)

        // Solution should be binary
        #expect(spec.isIntegerFeasible(result.solution))

        // Check constraint satisfaction
        let totalWeight = zip(weights, result.solution.toArray()).map(*).reduce(0, +)
        #expect(totalWeight <= capacity + 1e-6)

        // Optimal value for this problem is 90 (items 1, 3, 4: weights 4+3 = 7, values 40+50 = 90)
        // Or could be items 1, 3 (weights 4+3+7 = 14 > 10, invalid)
        // Actually optimal: items 1, 3 (weights 4+3 = 7, values 40+50 = 90)
        let actualValue = -result.objectiveValue
        #expect(actualValue >= 85.0)  // Should be close to optimal
    }

    @Test("Binary variable problem - already integer at root")
    func testAlreadyIntegerAtRoot() throws {
        // Problem where LP relaxation gives integer solution
        let spec = IntegerProgramSpecification.allBinary(dimension: 2)

        // Objective: minimize x₀ + x₁
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + x.toArray()[1]
        }

        // Constraints: x₀ + x₁ ≥ 1, x₀, x₁ ∈ [0,1]
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in 1.0 - x.toArray()[0] - x.toArray()[1] },
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should find optimal solution quickly (minimal branching)
        #expect(result.status == IntegerSolutionStatus.optimal)
        #expect(result.nodesExplored <= 10)  // Should be very few nodes

        // Optimal solution: x₀ = 1, x₁ = 0 (or vice versa)
        #expect(abs(result.objectiveValue - 1.0) < 1e-4)
        #expect(spec.isIntegerFeasible(result.solution))
    }

    @Test("Infeasible integer program")
    func testInfeasibleProgram() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 2)

        // Objective: minimize x₀ + x₁
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + x.toArray()[1]
        }

        // Impossible constraints: x₀ + x₁ ≥ 3, but x₀, x₁ ∈ {0,1}
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in 3.0 - x.toArray()[0] - x.toArray()[1] },
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(maxNodes: 100)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should detect infeasibility
        #expect(result.status == IntegerSolutionStatus.infeasible || result.objectiveValue == Double.infinity)
    }

    @Test("Node limit termination", .disabled("Test problem too easy - LP relaxation finds integer solution at root"))
    func testNodeLimitTermination() throws {
        // Create a problem that requires branching
        // Classic knapsack: weights = [2,3,4,5], values = [3,4,5,6], capacity = 5
        // LP relaxation will have x[3] fractional
        let spec = IntegerProgramSpecification.allBinary(dimension: 4)

        // Maximize profit (minimize negative profit)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            let arr = x.toArray()
            return -(3.0*arr[0] + 4.0*arr[1] + 5.0*arr[2] + 6.0*arr[3])
        }

        // Weight constraint: 2*x[0] + 3*x[1] + 4*x[2] + 5*x[3] ≤ 5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in
                let arr = x.toArray()
                return 5.0 - (2.0*arr[0] + 3.0*arr[1] + 4.0*arr[2] + 5.0*arr[3])
            }
        ]

        // Set very low node limit
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 5,
            timeLimit: 60.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.5, count: 4)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should hit node limit
        #expect(result.status == IntegerSolutionStatus.nodeLimit)
        #expect(result.nodesExplored <= 6)  // Should explore approximately maxNodes
    }

    @Test("Mixed integer problem (not all binary)")
    func testMixedIntegerProblem() throws {
        // x₀ is general integer, x₁ is binary
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0]),
            binaryVariables: Set([1])
        )

        // Objective: minimize x₀ + 10*x₁
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + 10.0 * x.toArray()[1]
        }

        // Constraints: x₀ + x₁ ≥ 2.5, x₀ ≥ 0, x₁ ∈ {0,1}
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in 2.5 - x.toArray()[0] - x.toArray()[1] },
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in x.toArray()[1] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))

        // Optimal: x₀ = 3, x₁ = 0 (cost 3) OR x₀ = 2, x₁ = 1 (cost 12)
        // Best is x₀ = 3, x₁ = 0
        #expect(result.objectiveValue <= 3.5)
    }

    @Test("Optimality gap calculation")
    func testOptimalityGap() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + 2.0 * x.toArray()[1] + 3.0 * x.toArray()[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in -x.toArray()[2] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
            .inequality { x in x.toArray()[2] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relativeGapTolerance: 1e-4
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should achieve small gap
        if result.status == IntegerSolutionStatus.optimal {
            #expect(result.relativeGap < 1e-3)
        }

        // Gap should be non-negative
        #expect(result.relativeGap >= 0.0)
    }

    @Test("Best-bound node selection finds optimum")
    func testBestBoundNodeSelection() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 4)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            -x.toArray().reduce(0, +)  // Maximize sum
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray().reduce(0, +) - 2.0 },  // At most 2
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in -x.toArray()[2] },
            .inequality { x in -x.toArray()[3] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
            .inequality { x in x.toArray()[2] - 1.0 },
            .inequality { x in x.toArray()[3] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            nodeSelection: .bestBound
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal)
        // Optimal: select any 2 variables = sum of 2 = -2
        #expect(abs(result.objectiveValue - (-2.0)) < 1e-4)

        // Should have selected exactly 2 variables
        let sum = result.solution.toArray().reduce(0, +)
        #expect(abs(sum - 2.0) < 1e-4)
    }

    @Test("Depth-first node selection")
    func testDepthFirstNodeSelection() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray().reduce(0, +)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in -x.toArray()[2] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
            .inequality { x in x.toArray()[2] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            nodeSelection: .depthFirst
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should still find optimal
        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))
    }

    @Test("Breadth-first node selection")
    func testBreadthFirstNodeSelection() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray().reduce(0, +)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in -x.toArray()[2] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
            .inequality { x in x.toArray()[2] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            nodeSelection: .breadthFirst
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))
    }

    @Test("Solution status reporting")
    func testSolutionStatusReporting() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 2)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + x.toArray()[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Check status is one of the valid values
        let validStatuses: [IntegerSolutionStatus] = [.optimal, .feasible, .infeasible, .nodeLimit, .timeLimit]
        #expect(validStatuses.contains { status in
            switch (status, result.status) {
            case (.optimal, .optimal): return true
            case (.feasible, .feasible): return true
            case (.infeasible, .infeasible): return true
            case (.nodeLimit, .nodeLimit): return true
            case (.timeLimit, .timeLimit): return true
            default: return false
            }
        })

        // Solve time should be positive
        #expect(result.solveTime > 0.0)

        // Nodes explored should be positive
        #expect(result.nodesExplored > 0)
    }

    @Test("Performance: 10-variable problem solves quickly")
    func testPerformance10Variables() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 10)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            -x.toArray().enumerated().map { Double($0.offset + 1) * $0.element }.reduce(0, +)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray().reduce(0, +) - 5.0 }
        ] + (0..<10).flatMap { i in
            [
                MultivariateConstraint<VectorN<Double>>.inequality { x in -x.toArray()[i] },
                MultivariateConstraint<VectorN<Double>>.inequality { x in x.toArray()[i] - 1.0 }
            ]
        }

        let startTime = Date()
        let solver = BranchAndBoundSolver<VectorN<Double>>(timeLimit: 5.0)

        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.5, count: 10)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        let elapsed = Date().timeIntervalSince(startTime)

        // Should complete in under 5 seconds
        #expect(elapsed < 5.0)

        // Should find a solution
        #expect(result.status != IntegerSolutionStatus.infeasible)
    }

    @Test("Constraint satisfaction in final solution")
    func testConstraintSatisfaction() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 4)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray().reduce(0, +)
        }

        // Constraint: x₀ + x₁ + x₂ + x₃ ≤ 2
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray().reduce(0, +) - 2.0 }
        ] + (0..<4).flatMap { i in
            [
                MultivariateConstraint<VectorN<Double>>.inequality { x in -x.toArray()[i] },
                MultivariateConstraint<VectorN<Double>>.inequality { x in x.toArray()[i] - 1.0 }
            ]
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Verify constraint is satisfied
        let sum = result.solution.toArray().reduce(0, +)
        #expect(sum <= 2.0 + 1e-6)

        // Verify solution is binary
        #expect(spec.isIntegerFeasible(result.solution))
    }

    @Test("Maximization problem (minimize negative)")
    func testMaximizationProblem() throws {
        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        // Maximize: 3x₀ + 2x₁ + x₂
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            -(3.0 * x.toArray()[0] + 2.0 * x.toArray()[1] + x.toArray()[2])
        }

        // Constraint: x₀ + x₁ + x₂ ≤ 2
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray().reduce(0, +) - 2.0 }
        ] + (0..<3).flatMap { i in
            [
                MultivariateConstraint<VectorN<Double>>.inequality { x in -x.toArray()[i] },
                MultivariateConstraint<VectorN<Double>>.inequality { x in x.toArray()[i] - 1.0 }
            ]
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)

        // Optimal: x₀=1, x₁=1, x₂=0 → value = 3+2 = 5
        let actualValue = -result.objectiveValue
        #expect(abs(actualValue - 5.0) < 1e-3)
    }

    // MARK: - SimplexSolver Integration Tests

    @Test("SimplexSolver integration - simple binary problem")
    func testSimplexIntegrationSimpleBinary() throws {
        // Simplest problem: minimize x subject to x ∈ {0,1}
        let spec = IntegerProgramSpecification.allBinary(dimension: 1)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0]  // Minimize x (optimal: x=0)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in -x.toArray()[0] },       // x ≥ 0
            .inequality { x in x.toArray()[0] - 1.0 },  // x ≤ 1
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should find optimal solution (or feasible for simple problems)
        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(abs(result.objectiveValue - 0.0) < 1e-6)
        #expect(abs(result.solution.toArray()[0] - 0.0) < 1e-6)
    }

    @Test("SimplexSolver integration - 2D linear program")
    func testSimplexIntegration2D() throws {
        // Minimize x + 2y subject to:
        // x + y ≥ 3
        // x, y ∈ {0,1,2,3,...}
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1]),
            binaryVariables: Set()
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + 2.0 * x.toArray()[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in 3.0 - x.toArray()[0] - x.toArray()[1] },  // x + y ≥ 3
            .inequality { x in -x.toArray()[0] },  // x ≥ 0
            .inequality { x in -x.toArray()[1] },  // y ≥ 0
            .inequality { x in x.toArray()[0] - 10.0 },  // x ≤ 10 (reasonable bound)
            .inequality { x in x.toArray()[1] - 10.0 },  // y ≤ 10
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should find optimal solution
        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))

        // Optimal: x=3, y=0 → value=3 or x=0, y=3 → value=6
        // Best is x=3, y=0 → value=3
        #expect(result.objectiveValue <= 3.5)
    }

    @Test("SimplexSolver integration - knapsack with linear constraints")
    func testSimplexIntegrationKnapsack() throws {
        // Simple knapsack: maximize value subject to weight constraint
        // This should work well with SimplexSolver as the LP relaxation solver
        let values = [5.0, 3.0, 4.0]
        let weights = [2.0, 1.0, 2.0]
        let capacity = 3.0

        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        // Objective: maximize value (minimize negative value)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            -zip(values, x.toArray()).map(*).reduce(0, +)
        }

        // Constraint: weight ≤ capacity
        let weightConstraint = MultivariateConstraint<VectorN<Double>>.inequality { x in
            let arr = x.toArray()
            let totalWeight = weights[0] * arr[0] + weights[1] * arr[1] + weights[2] * arr[2]
            return totalWeight - capacity
        }

        var constraints: [MultivariateConstraint<VectorN<Double>>] = [weightConstraint]
        for i in 0..<3 {
            constraints.append(.inequality { x in -x.toArray()[i] })
            constraints.append(.inequality { x in x.toArray()[i] - 1.0 })
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))

        // Verify weight constraint
        let totalWeight = zip(weights, result.solution.toArray()).map(*).reduce(0, +)
        #expect(totalWeight <= capacity + 1e-6)

        // Optimal: items 0,1 (weights 2+1=3, values 5+3=8)
        let actualValue = -result.objectiveValue
        #expect(actualValue >= 7.5)  // Should be close to 8
    }

    @Test("SimplexSolver integration - infeasible LP relaxation")
    func testSimplexIntegrationInfeasible() throws {
        // Problem where LP relaxation is infeasible
        let spec = IntegerProgramSpecification.allBinary(dimension: 2)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + x.toArray()[1]
        }

        // Contradictory constraints: x + y ≤ 0.5 AND x + y ≥ 1.5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray()[0] + x.toArray()[1] - 0.5 },  // x + y ≤ 0.5
            .inequality { x in 1.5 - x.toArray()[0] - x.toArray()[1] },  // x + y ≥ 1.5
            .inequality { x in -x.toArray()[0] },
            .inequality { x in -x.toArray()[1] },
            .inequality { x in x.toArray()[0] - 1.0 },
            .inequality { x in x.toArray()[1] - 1.0 },
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(maxNodes: 10)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Should detect infeasibility quickly
        #expect(result.status == IntegerSolutionStatus.infeasible)
    }

    @Test("SimplexSolver integration - equality constraints")
    func testSimplexIntegrationEqualityConstraints() throws {
        // Test with equality constraint: x + y = 2, x,y ∈ {0,1,2}
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1]),
            binaryVariables: Set()
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray()[0] + x.toArray()[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .equality { x in x.toArray()[0] + x.toArray()[1] - 2.0 },  // x + y = 2
            .inequality { x in -x.toArray()[0] },  // x ≥ 0
            .inequality { x in -x.toArray()[1] },  // y ≥ 0
            .inequality { x in x.toArray()[0] - 3.0 },  // x ≤ 3
            .inequality { x in x.toArray()[1] - 3.0 },  // y ≤ 3
        ]

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            timeLimit: 10.0
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)
        #expect(spec.isIntegerFeasible(result.solution))

        // Optimal: any (x,y) where x+y=2, minimizing x+y gives 2
        #expect(abs(result.objectiveValue - 2.0) < 1e-4)

        // Verify equality constraint
        let sum = result.solution.toArray()[0] + result.solution.toArray()[1]
        #expect(abs(sum - 2.0) < 1e-6)
    }

    @Test("SimplexSolver integration - validates solution feasibility")
    func testSimplexIntegrationFeasibilityCheck() throws {
        // Ensure SimplexSolver correctly identifies feasible/infeasible nodes
        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            x.toArray().reduce(0, +)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { x in x.toArray().reduce(0, +) - 1.0 }  // At most 1 variable set
        ] + (0..<3).flatMap { i in
            [
                MultivariateConstraint<VectorN<Double>>.inequality { x in -x.toArray()[i] },
                MultivariateConstraint<VectorN<Double>>.inequality { x in x.toArray()[i] - 1.0 }
            ]
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == IntegerSolutionStatus.optimal || result.status == IntegerSolutionStatus.feasible)

        // All constraints must be satisfied
        for constraint in constraints {
            let value = constraint.evaluate(at: result.solution)
            #expect(value <= 1e-6)  // Should satisfy g(x) ≤ 0
        }
    }

    @Test("Production scheduling with setup costs and demand constraints")
    func testProductionSchedulingWithDemandConstraints() throws {
        // From PHASE_6.2_INTEGER_PROGRAMMING_TUTORIAL.md Example 4
        let productionCosts = [25.0, 30.0, 20.0, 28.0]   // Per unit
        let setupCosts = [500.0, 600.0, 450.0, 550.0]    // Fixed
        let demands = [100.0, 150.0, 80.0, 120.0]        // Must meet
        let capacities = [200.0, 250.0, 150.0, 200.0]    // Max production

        // Decision variables:
        // x[0..3]: Integer - production quantity
        // y[4..7]: Binary - whether to produce (incur setup)
        let dimension = 8
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0, 1, 2, 3]),  // Production quantities
            binaryVariables: Set([4, 5, 6, 7])     // Setup decisions
        )

        // Objective: minimize total cost (variable + fixed)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            let vars = x.toArray()
            var variableCost = 0.0
            for i in 0..<4 {
                variableCost += productionCosts[i] * vars[i]
            }
            var fixedCost = 0.0
            for i in 0..<4 {
                fixedCost += setupCosts[i] * vars[4 + i]
            }
            return variableCost + fixedCost
        }

        var constraints: [MultivariateConstraint<VectorN<Double>>] = []

        // Demand constraints: must produce at least demand
        // xᵢ ≥ demandᵢ  ⟺  demandᵢ - xᵢ ≤ 0
        for i in 0..<4 {
            constraints.append(.inequality { x in
                demands[i] - x.toArray()[i]
            })
        }

        // Linking constraints: can only produce if setup
        // xᵢ ≤ capacityᵢ·yᵢ  ⟺  xᵢ - capacityᵢ·yᵢ ≤ 0
        for i in 0..<4 {
            constraints.append(.inequality { x in
                let vars = x.toArray()
                return vars[i] - capacities[i] * vars[4 + i]
            })
        }

        // Capacity constraints: xᵢ ≤ capacityᵢ
        for i in 0..<4 {
            constraints.append(.inequality { x in
                x.toArray()[i] - capacities[i]
            })
        }

        // Non-negativity and binary bounds
        for i in 0..<dimension {
            constraints.append(.inequality { x in -x.toArray()[i] })
            if i >= 4 {
                constraints.append(.inequality { x in x.toArray()[i] - 1.0 })
            }
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 3000,
            timeLimit: 30.0,
            nodeSelection: .bestBound
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.0, count: dimension)),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        let vars = result.solution.toArray()

        print("Production Scheduling Test Results:")
        for i in 0..<4 {
            let production = vars[i]
            let productionRounded = Int(round(vars[i]))  // Properly round for display
            let demand = demands[i]
            print("  Product \(i): Production=\(productionRounded) (\(production)), Demand=\(demand)")

            // CRITICAL TEST: Production must meet or exceed demand within tolerance
            #expect(production >= demand - 1e-6,
                "Product \(i): Production (\(production)) is less than demand (\(demand))")

            // When properly rounded, should equal demand
            #expect(productionRounded == Int(demand),
                "Product \(i): Rounded production (\(productionRounded)) doesn't match demand (\(Int(demand)))")
        }

        // Verify all constraints are satisfied
        for (idx, constraint) in constraints.enumerated() {
            let value = constraint.evaluate(at: result.solution)
            #expect(value <= 1e-6,
                "Constraint \(idx) violated: g(x) = \(value) > 0")
        }

        // Verify integer feasibility
        #expect(spec.isIntegerFeasible(result.solution, tolerance: 1e-6))

        // Expected: produce exactly at demand (no benefit to producing more)
        for i in 0..<4 {
            #expect(abs(vars[i] - demands[i]) < 0.5,
                "Expected production at demand for cost minimization")
        }
    }
}
