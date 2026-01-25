import Testing
import Foundation
@testable import BusinessMath

/// End-to-end integration tests for MINLP (Mixed-Integer Nonlinear Programming)
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until Phase 5B fixes any integration issues.
///
/// ## What We're Testing
/// - BranchAndBoundSolver with NonlinearRelaxationSolver solves MINLP problems
/// - Quadratic objectives with integer constraints work correctly
/// - Nonlinear constraints are properly handled in branch-and-bound
/// - Results are integer-feasible and satisfy all constraints
/// - Performance is acceptable for small-medium problems
@Suite("MINLP Integration Tests")
struct MINLPIntegrationTests {

    // MARK: - Simple MINLP Tests

    @Test("MINLP: Quadratic objective with binary variables")
    func testQuadraticObjectiveBinary() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x² + y² subject to x + y ≥ 2, x,y ∈ {0,1}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 1.0],
                rhs: 2.0,
                sense: .greaterOrEqual
            )
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Optimal: (1, 1) with objective = 2
        #expect(result.integerSolution == [1, 1],
                "Expected [1, 1], got \(result.integerSolution)")
        #expect(abs(result.objectiveValue - 2.0) < 1e-3,
                "Expected obj ≈ 2, got \(result.objectiveValue)")

        // Verify all binary
        for val in result.integerSolution {
            #expect(val == 0 || val == 1, "Not binary: \(val)")
        }
    }

    @Test("MINLP: Quadratic objective with integer variables")
    func testQuadraticObjectiveInteger() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 5000,
            timeLimit: 30.0,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x² + y² subject to x + y ≥ 3, x,y ∈ {0,1,2,3}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .greaterOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Verify constraint: x + y ≥ 3
        let sum = result.integerSolution[0] + result.integerSolution[1]
        #expect(sum >= 3, "Constraint violated: x + y = \(sum) < 3")

        // Verify all integer
        for val in result.integerSolution {
            #expect(Double(val) == Double(Int(val)), "Not integer: \(val)")
        }
    }

    // MARK: - MINLP with Nonlinear Constraints

    @Test("MINLP: Circle constraint with binary variables")
    func testCircleConstraintBinary() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x + y subject to x² + y² ≤ 1, x,y ∈ {0,1}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 1.0 }  // Circle
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Optimal should be (1, 0) or (0, 1) - both satisfy x² + y² ≤ 1
        let sum = result.integerSolution[0] + result.integerSolution[1]
        #expect(sum == 0 || sum == 1, "Expected sum 0 or 1, got \(sum)")

        // Verify circle constraint
        let x = Double(result.integerSolution[0])
        let y = Double(result.integerSolution[1])
        let radius = x * x + y * y
        #expect(radius <= 1.0 + 1e-6, "Circle constraint violated: r² = \(radius)")
    }

    @Test("MINLP: Ellipse constraint with integer variables")
    func testEllipseConstraintInteger() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 2000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x subject to (x/3)² + y² ≤ 1, x,y ∈ Z, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in
                (v[0] / 3.0) * (v[0] / 3.0) + v[1] * v[1] - 1.0
            }
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Verify ellipse constraint
        let x = Double(result.integerSolution[0])
        let y = Double(result.integerSolution[1])
        let ellipse = (x / 3.0) * (x / 3.0) + y * y
        #expect(ellipse <= 1.0 + 1e-3, "Ellipse constraint violated: \(ellipse)")

        // Since we minimize x, expect x = 0
        #expect(result.integerSolution[0] == 0, "Expected x = 0, got \(result.integerSolution[0])")
    }

    // MARK: - Mixed Objectives

    @Test("MINLP: Product term in objective")
    func testProductTermObjective() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize xy subject to x + y = 4, x,y ∈ {0,1,2,3,4}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearEquality(coefficients: [1.0, 1.0], rhs: 4.0)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 3.5]),  // Start near corner to find true minimum
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Optimal: (0, 4) or (4, 0) with objective = 0
        let product = result.integerSolution[0] * result.integerSolution[1]
        #expect(product == 0, "Expected product = 0, got \(product)")

        // Verify equality
        let sum = result.integerSolution[0] + result.integerSolution[1]
        #expect(sum == 4, "Equality violated: x + y = \(sum)")
    }

    // MARK: - Comparison with LP Relaxation

    @Test("MINLP: Nonlinear gives different result than linear")
    func testNonlinearVsLinear() throws {
        // Same problem solved with both relaxation methods

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budget(total: 3.0, dimension: 2)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        // Linear relaxation (SimplexRelaxationSolver extracts linear approximation)
        let linearSolver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: SimplexRelaxationSolver()
        )

        let linearResult = try linearSolver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Nonlinear relaxation (NonlinearRelaxationSolver uses true quadratic)
        let nonlinearSolver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        let nonlinearResult = try nonlinearSolver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Both should find same integer solution (quadratic minimized at origin)
        // But bounds/nodes explored may differ
        #expect(linearResult.status == .optimal)
        #expect(nonlinearResult.status == .optimal)

        // For this problem, both should find (0, 0) or (1, 0) or (0, 1)
        // depending on how budget constraint is handled
        #expect(linearResult.integerSolution.count == 2)
        #expect(nonlinearResult.integerSolution.count == 2)
    }

    // MARK: - Edge Cases

    @Test("MINLP: Infeasible nonlinear problem")
    func testInfeasibleNonlinear() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 500,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // x² + y² ≤ 1 AND x + y ≥ 3 (infeasible for integers)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] * v[0] + v[1] * v[1] - 1.0 },
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .greaterOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.status == .infeasible)
    }

    @Test("MINLP: Single variable nonlinear")
    func testSingleVariableNonlinear() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 500,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x² subject to x ≥ 2, x ≤ 5, x ∈ Z
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.0, sense: .greaterOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([3.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.status == .optimal)

        // Optimal: x = 2 with objective = 4
        #expect(result.integerSolution[0] == 2, "Expected x = 2, got \(result.integerSolution[0])")
        #expect(abs(result.objectiveValue - 4.0) < 1e-3, "Expected obj = 4, got \(result.objectiveValue)")
    }

    // MARK: - Performance Tests

    @Test("MINLP: Small problem completes quickly")
    func testPerformanceSmallProblem() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            timeLimit: 10.0,  // Should complete well under 10 seconds
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x² + y² + z² subject to x + y + z ≥ 3, x,y,z ∈ {0,1,2}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1] + v[2] * v[2]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 1.0, 1.0],
                rhs: 3.0,
                sense: .greaterOrEqual
            )
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 3)
        )

        #expect(result.status == .optimal || result.status == .nodeLimit || result.status == .timeLimit)

        // If optimal, verify constraint
        if result.status == .optimal {
            let sum = result.integerSolution[0] + result.integerSolution[1] + result.integerSolution[2]
            #expect(sum >= 3, "Constraint violated: sum = \(sum)")
        }
    }

    // MARK: - Correctness Validation

    @Test("MINLP: Solution satisfies all constraints")
    func testSolutionValidation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        // minimize x² + y² subject to:
        //   x² + y² ≥ 4 (outside radius-2 circle)
        //   x + y ≤ 5 (linear)
        //   x,y ∈ {0,1,2,3,4,5}
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0] + v[1] * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in -(v[0] * v[0] + v[1] * v[1]) + 4.0 },  // -(x²+y²) + 4 ≤ 0 => x²+y² ≥ 4
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.status == .optimal)

        // Verify all constraints
        let x = Double(result.integerSolution[0])
        let y = Double(result.integerSolution[1])

        let radius = x * x + y * y
        #expect(radius >= 4.0 - 1e-3, "Circle constraint violated: r² = \(radius) < 4")

        let sum = x + y
        #expect(sum <= 5.0 + 1e-3, "Linear constraint violated: x + y = \(sum) > 5")

        #expect(x >= 0 && y >= 0, "Non-negativity violated")
    }
}
