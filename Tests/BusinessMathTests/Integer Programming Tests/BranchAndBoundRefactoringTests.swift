import Testing
import Foundation
@testable import BusinessMath

/// Tests for BranchAndBound refactoring to use RelaxationSolver protocol
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until Phase 3B refactors BranchAndBound to accept pluggable solvers.
///
/// ## What We're Testing
/// - BranchAndBoundSolver accepts custom RelaxationSolver parameter
/// - Defaults to SimplexRelaxationSolver for backward compatibility
/// - Existing tests continue to pass (no regressions)
/// - Can solve problems with custom relaxation solver
@Suite("BranchAndBound Refactoring Tests")
struct BranchAndBoundRefactoringTests {

    // MARK: - Constructor Tests

    @Test("BranchAndBound accepts custom relaxation solver")
    func testCustomRelaxationSolver() {
        let customSolver = SimplexRelaxationSolver(lpTolerance: 1e-8)
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: customSolver
        )

        // Verify solver was created successfully
        #expect(solver.maxNodes == 10_000)  // Default value
    }

    @Test("BranchAndBound defaults to SimplexRelaxationSolver")
    func testDefaultRelaxationSolver() {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Should use SimplexRelaxationSolver by default (test by solving a problem)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }
        let result = try? solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: [],
            integerSpec: .allBinary(dimension: 1)
        )

        #expect(result != nil)
        #expect(result?.status == .optimal)
    }

    @Test("BranchAndBound accepts all constructor parameters with relaxation solver")
    func testFullConstructor() {
        let customSolver = SimplexRelaxationSolver(lpTolerance: 1e-7)
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 5000,
            timeLimit: 60.0,
            relativeGapTolerance: 1e-3,
            nodeSelection: .depthFirst,
            branchingRule: .mostFractional,
            lpTolerance: 1e-7,
            integralityTolerance: 1e-6,
            validateLinearity: false,
            enableVariableShifting: true,
            relaxationSolver: customSolver
        )

        #expect(solver.maxNodes == 5000)
        #expect(solver.timeLimit == 60.0)
    }

    // MARK: - Solving Tests

    @Test("BranchAndBound solves simple problem with custom solver")
    func testSolveWithCustomSolver() throws {
        let customSolver = SimplexRelaxationSolver(lpTolerance: 1e-8)
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: customSolver
        )

        // minimize 2x + 3y subject to x + y ≤ 5, x,y ∈ {0,1}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budget(total: 5.0, dimension: 2)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        #expect(result.status == .optimal)
        #expect(result.integerSolution == [0, 0])
        #expect(abs(result.objectiveValue) < 1e-6)
    }

    @Test("BranchAndBound solves knapsack with custom solver")
    func testKnapsackWithCustomSolver() throws {
        let customSolver = SimplexRelaxationSolver(lpTolerance: 1e-8)
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: customSolver
        )

        // Knapsack: maximize value subject to weight constraint
        let values = [60.0, 100.0, 120.0]
        let weights = [10.0, 20.0, 30.0]
        let capacity = 50.0

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            -(values[0] * v[0] + values[1] * v[1] + values[2] * v[2])
        }

        let constraints = [
            .linearInequality(coefficients: weights, rhs: capacity, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 3)
        )

        #expect(result.status == .optimal)

        // Verify weight constraint
        let totalWeight = zip(weights, result.integerSolution).reduce(0.0) { $0 + $1.0 * Double($1.1) }
        #expect(totalWeight <= capacity + 1e-6)

        // Verify all binary
        for val in result.integerSolution {
            #expect(val == 0 || val == 1)
        }
    }

    // MARK: - Backward Compatibility Tests

    @Test("BranchAndBound without relaxation solver parameter still works")
    func testBackwardCompatibilityNoParameter() throws {
        // Old API: create solver without specifying relaxation solver
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 10_000,
            timeLimit: 300.0
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        #expect(result.status == .optimal)
        #expect(result.integerSolution == [0, 0])
    }

    @Test("BranchAndBound gives same results with explicit SimplexRelaxationSolver")
    func testExplicitSimplexMatchesDefault() throws {
        // Solve same problem with default solver and explicit SimplexRelaxationSolver
        let problem = {
            (solver: BranchAndBoundSolver<VectorN<Double>>) throws -> IntegerProgramResult in
            let objective: @Sendable (VectorN<Double>) -> Double = { v in
                3.0 * v[0] + 2.0 * v[1]
            }

            let constraints = [
                .linearInequality(coefficients: [2.0, 3.0], rhs: 12.0, sense: .lessOrEqual)
            ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

            return try solver.solve(
                objective: objective,
                from: VectorN([1.0, 1.0]),
                subjectTo: constraints,
                integerSpec: .allInteger(dimension: 2)
            )
        }

        // Default solver
        let defaultSolver = BranchAndBoundSolver<VectorN<Double>>()
        let result1 = try problem(defaultSolver)

        // Explicit SimplexRelaxationSolver
        let explicitSolver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: SimplexRelaxationSolver(lpTolerance: 1e-8)
        )
        let result2 = try problem(explicitSolver)

        // Results should be identical
        #expect(result1.status == result2.status)
        #expect(result1.integerSolution == result2.integerSolution)
        #expect(abs(result1.objectiveValue - result2.objectiveValue) < 1e-6)
    }

    // MARK: - Mock Solver Tests

    @Test("BranchAndBound can use mock relaxation solver for testing")
    func testMockRelaxationSolver() throws {
        // Create a mock solver that always returns a fixed solution
        struct MockRelaxationSolver: RelaxationSolver {
            func solveRelaxation<V: VectorSpace>(
                objective: @Sendable @escaping (V) -> Double,
                constraints: [MultivariateConstraint<V>],
                initialGuess: V,
                minimize: Bool
            ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
                // Return fixed solution for testing
                let mockSolution = VectorN([0.0, 0.0])
                let mockObjective = objective(initialGuess)

                return RelaxationResult(
                    solution: mockSolution,
                    objectiveValue: mockObjective,
                    status: .optimal
                )
            }
        }

        let mockSolver = MockRelaxationSolver()
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: mockSolver
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] + v[1] }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: [],
            integerSpec: .allBinary(dimension: 2)
        )

        // Mock solver returns (0, 0) which is integer-feasible
        #expect(result.status == .optimal)
        #expect(result.integerSolution == [0, 0])
    }

    // MARK: - Edge Cases

    @Test("BranchAndBound handles nil relaxation solver (uses default)")
    func testNilRelaxationSolverUsesDefault() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            relaxationSolver: nil  // Explicitly pass nil
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: [],
            integerSpec: .allBinary(dimension: 1)
        )

        #expect(result.status == .optimal)
    }

    @Test("BranchAndBound relaxation solver respects lpTolerance")
    func testRelaxationSolverTolerance() {
        // If lpTolerance is specified, default SimplexRelaxationSolver should use it
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            lpTolerance: 1e-10  // Very tight tolerance
        )

        // Verify solver created successfully
        #expect(solver.lpTolerance == 1e-10)
    }
}
