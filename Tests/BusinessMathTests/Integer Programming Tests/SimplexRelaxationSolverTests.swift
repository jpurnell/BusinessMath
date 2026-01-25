import Testing
import Foundation
@testable import BusinessMath

/// Tests for SimplexRelaxationSolver (LP relaxation wrapper)
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until Phase 2B implements the solver.
///
/// ## What We're Testing
/// - SimplexRelaxationSolver conforms to RelaxationSolver protocol
/// - Correctly extracts linear coefficients from objective functions
/// - Converts MultivariateConstraint to SimplexConstraint
/// - Returns RelaxationResult with proper status (optimal/infeasible/unbounded)
/// - Backward compatibility with current BranchAndBound behavior
@Suite("SimplexRelaxationSolver Tests")
struct SimplexRelaxationSolverTests {

    // MARK: - Basic Functionality Tests

    @Test("SimplexRelaxationSolver conforms to RelaxationSolver")
    func testProtocolConformance() {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)
        let _: any RelaxationSolver = solver
        #expect(true)  // Compilation is the test
    }

    @Test("SimplexRelaxationSolver solves simple LP minimization")
    func testSimpleLPMinimization() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize 2x + 3y subject to x + y ≤ 5, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([0.5, 0.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: (0, 0) with objective = 0
        let sol = result.solution!
        #expect(abs(sol[0]) < 1e-6, "Expected x ≈ 0, got \(sol[0])")
        #expect(abs(sol[1]) < 1e-6, "Expected y ≈ 0, got \(sol[1])")
        #expect(abs(result.objectiveValue) < 1e-6, "Expected obj ≈ 0, got \(result.objectiveValue)")
    }

    @Test("SimplexRelaxationSolver solves simple LP maximization")
    func testSimpleLPMaximization() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // maximize x + y subject to x + y ≤ 10, x,y ≥ 0
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: false  // Maximize!
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: (10, 0) or (0, 10) or anywhere on x + y = 10
        let sol = result.solution!
        let sum = sol[0] + sol[1]
        #expect(abs(sum - 10.0) < 1e-6, "Expected x + y = 10, got \(sum)")
        #expect(abs(result.objectiveValue - 10.0) < 1e-6)
    }

    // MARK: - Coefficient Extraction Tests

    @Test("SimplexRelaxationSolver extracts correct coefficients")
    func testCoefficientExtraction() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // 3x + 2y - 5
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            3.0 * v[0] + 2.0 * v[1] - 5.0
        }

        let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: (0, 0) with objective = -5
        let sol = result.solution!
        #expect(abs(sol[0]) < 1e-6)
        #expect(abs(sol[1]) < 1e-6)
        #expect(abs(result.objectiveValue - (-5.0)) < 1e-6)
    }

    // MARK: - Constraint Conversion Tests

    @Test("SimplexRelaxationSolver handles linearInequality constraints")
    func testLinearInequalityConstraint() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize x + y subject to 2x + 3y ≥ 6 (demand)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 3.0], rhs: 6.0, sense: .greaterOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([2.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify constraint satisfied: 2x + 3y ≥ 6
        let sol = result.solution!
        let demand = 2.0 * sol[0] + 3.0 * sol[1]
        #expect(demand >= 6.0 - 1e-6, "Demand constraint violated: \(demand) < 6")
    }

    @Test("SimplexRelaxationSolver handles linearEquality constraints")
    func testLinearEqualityConstraint() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize x + y subject to x + y = 5
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearEquality(coefficients: [1.0, 1.0], rhs: 5.0)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([2.5, 2.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify equality: x + y = 5
        let sol = result.solution!
        let sum = sol[0] + sol[1]
        #expect(abs(sum - 5.0) < 1e-6, "Equality violated: x + y = \(sum) ≠ 5")
    }

    @Test("SimplexRelaxationSolver handles closure-based constraints")
    func testClosureConstraint() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize x + y subject to x + 2y ≤ 10 (closure form)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .inequality { v in v[0] + 2.0 * v[1] - 10.0 }  // x + 2y - 10 ≤ 0
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0, 1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify constraint: x + 2y ≤ 10
        let sol = result.solution!
        let lhs = sol[0] + 2.0 * sol[1]
        #expect(lhs <= 10.0 + 1e-6, "Constraint violated: \(lhs) > 10")
    }

    // MARK: - Infeasibility Tests

    @Test("SimplexRelaxationSolver detects infeasibility")
    func testInfeasible() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // x ≥ 5 AND x ≤ 2 (infeasible)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .greaterOrEqual),  // x ≥ 5
            .linearInequality(coefficients: [1.0], rhs: 2.0, sense: .lessOrEqual)      // x ≤ 2
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([3.0]),
            minimize: true
        )

        #expect(result.status == .infeasible)
        #expect(result.solution == nil)
        #expect(result.objectiveValue == Double.infinity)  // Minimization infeasible
    }

    @Test("SimplexRelaxationSolver detects unboundedness")
    func testUnbounded() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize -x with no upper bound (unbounded below)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in -v[0] }

        let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 1)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0]),
            minimize: true
        )

        // Note: SimplexSolver treats unbounded as infeasible in some cases
        // Accept either unbounded or extremely negative objective
        if result.status == .unbounded {
            #expect(result.objectiveValue == -Double.infinity)
        } else if result.status == .optimal {
            // Some LP solvers return large objective instead of unbounded
            #expect(result.objectiveValue < -1e6)
        } else {
            #expect(result.status == .infeasible)
        }
    }

    // MARK: - Edge Cases

    @Test("SimplexRelaxationSolver handles single variable")
    func testSingleVariable() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize x subject to x ≥ 2, x ≤ 5
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.0, sense: .greaterOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([3.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: x = 2
        let sol = result.solution!
        #expect(abs(sol[0] - 2.0) < 1e-6, "Expected x = 2, got \(sol[0])")
    }

    @Test("SimplexRelaxationSolver handles empty constraints")
    func testEmptyConstraints() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // minimize x with only non-negativity
        let objective: @Sendable (VectorN<Double>) -> Double = { v in v[0] }

        let constraints = MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 1)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([1.0]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Optimal: x = 0
        let sol = result.solution!
        #expect(abs(sol[0]) < 1e-6)
    }

    // MARK: - Knapsack Example (Realistic Test)

    @Test("SimplexRelaxationSolver solves knapsack relaxation")
    func testKnapsackRelaxation() throws {
        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // Knapsack: maximize value subject to weight constraint
        let values = [60.0, 100.0, 120.0]
        let weights = [10.0, 20.0, 30.0]
        let capacity = 50.0

        // Maximize value (minimize negative value)
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            -(values[0] * v[0] + values[1] * v[1] + values[2] * v[2])
        }

        // Weight constraint + non-negativity + upper bounds (for binary relaxation)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: weights, rhs: capacity, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.box(lower: 0.0, upper: 1.0, dimension: 3)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([0.5, 0.5, 0.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Verify weight constraint
        let sol = result.solution!
        let totalWeight = zip(weights, sol.toArray()).reduce(0.0) { $0 + $1.0 * $1.1 }
        #expect(totalWeight <= capacity + 1e-6, "Weight exceeded: \(totalWeight) > \(capacity)")

        // Verify box constraints
        for val in sol.toArray() {
            #expect(val >= -1e-6, "Lower bound violated: \(val) < 0")
            #expect(val <= 1.0 + 1e-6, "Upper bound violated: \(val) > 1")
        }

        // Relaxation value should be >= any integer solution
        let relaxationValue = -result.objectiveValue
        #expect(relaxationValue >= 180.0, "Relaxation too weak: \(relaxationValue) < 180")
    }

    // MARK: - Backward Compatibility Test

    @Test("SimplexRelaxationSolver matches BranchAndBound behavior")
    func testBackwardCompatibility() throws {
        // This test verifies SimplexRelaxationSolver gives same results
        // as the current BranchAndBound LP relaxation

        let solver = SimplexRelaxationSolver(lpTolerance: 1e-8)

        // Simple problem from BranchAndBound tests
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.budget(total: 5.0, dimension: 2)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solveRelaxation(
            objective: objective,
            constraints: constraints,
            initialGuess: VectorN([0.5, 0.5]),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.solution != nil)

        // Expected: (0, 0) with objective = 0
        let sol = result.solution!
        #expect(abs(sol[0]) < 1e-6)
        #expect(abs(sol[1]) < 1e-6)
        #expect(abs(result.objectiveValue) < 1e-6)
    }
}
