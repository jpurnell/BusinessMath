import Testing
import Foundation
@testable import BusinessMath

/// Integration tests for LinearFunction protocol with BranchAndBound solver
///
/// These tests verify end-to-end integration of:
/// - LinearFunction protocol (explicit coefficients)
/// - Linearity validation (rejects nonlinear)
/// - Natural-form constraints (x ≥ 0 written naturally)
/// - Variable shifting (handles negative bounds)
///
/// Following TDD: These tests are written FIRST and will fail until
/// Phase E2 integrates all features into BranchAndBound.
@Suite("LinearFunction Integration Tests")
struct LinearFunctionIntegrationTests {

    // MARK: - LinearFunction Protocol Tests

    @Test("Solve with explicit LinearFunction")
    func testExplicitLinearFunction() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // minimize 2x + 3y subject to x + y ≤ 5, x,y ∈ {0,1}
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [2.0, 3.0],
            constant: 0.0
        )

        let constraints = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Optimal: (0, 0) with objective = 0
        #expect(result.integerSolution == [0, 0])
        #expect(abs(result.objectiveValue) < 1e-6)
    }

    @Test("LinearFunction vs closure give same result")
    func testLinearFunctionVsClosure() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Test problem: minimize 3x + 2y subject to x + y ≤ 10, x,y binary
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
        ]

        // Version 1: Explicit LinearFunction
        let explicitObjective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [3.0, 2.0]
        )

        let result1 = try solver.solve(
            objective: explicitObjective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Version 2: Closure (old API)
        let closureObjective: @Sendable (VectorN<Double>) -> Double = { v in
            3.0 * v[0] + 2.0 * v[1]
        }

        let result2 = try solver.solve(
            objective: closureObjective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Results should be identical
        #expect(result1.integerSolution == result2.integerSolution)
        #expect(abs(result1.objectiveValue - result2.objectiveValue) < 1e-6)
    }

    // MARK: - Linearity Validation Tests

    @Test("Rejects quadratic objective with validation enabled")
    func testRejectsQuadraticObjective() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            validateLinearity: true
        )

        let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] * v[0]  // Nonlinear!
        }

        #expect(throws: OptimizationError.self) {
            try solver.solve(
                objective: quadratic,
                from: VectorN([0.5]),
                subjectTo: [],
                integerSpec: .allInteger(dimension: 1)
            )
        }
    }

    @Test("Rejects bilinear constraint with validation enabled")
    func testRejectsBilinearConstraint() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            validateLinearity: true
        )

        let bilinearConstraint = MultivariateConstraint<VectorN<Double>>.inequality { v in
            v[0] * v[1] - 1.0  // Nonlinear!
        }

        #expect(throws: OptimizationError.self) {
            try solver.solve(
                objective: { v in v[0] },
                from: VectorN([0.5, 0.5]),
                subjectTo: [bilinearConstraint],
                integerSpec: .allBinary(dimension: 2)
            )
        }
    }

    @Test("Accepts linear objective with validation enabled")
    func testAcceptsLinearObjective() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            validateLinearity: true
        )

        let linear: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + 3.0 * v[1] + 1.0  // Linear
        }

        // Should NOT throw
        let result = try solver.solve(
            objective: linear,
            from: VectorN([0.5, 0.5]),
            subjectTo: [],
            integerSpec: .allBinary(dimension: 2)
        )

        #expect(result.integerSolution.count == 2)
    }

    // MARK: - Natural-Form Constraint Tests

    @Test("Solve with natural-form constraints")
    func testNaturalFormConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // minimize 2x + 3y
        // subject to: x + y ≤ 10 (budget)
        //            x ≥ 0, y ≥ 0 (non-negativity in natural form!)
        //            x, y binary

        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [2.0, 3.0]
        )

        let constraints = [
            .budget(total: 10.0, dimension: 2)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Optimal: (0, 0) with objective = 0
        #expect(result.integerSolution == [0, 0])
    }

    @Test("Factory methods for constraints")
    func testConstraintFactoryMethods() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // maximize x + y subject to box constraints
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [-1.0, -1.0]  // Negate for maximization
        )

        let constraints = MultivariateConstraint<VectorN<Double>>.box(
            lower: 0.0,
            upper: 1.0,
            dimension: 2
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 2)
        )

        // Optimal: (1, 1) with objective = -2
        #expect(result.integerSolution == [1, 1])
        #expect(abs(result.objectiveValue - (-2.0)) < 1e-6)
    }

    // MARK: - Variable Shifting Tests

    @Test("Handles negative lower bounds with shifting")
    func testNegativeBoundsWithShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // minimize x subject to x ≥ -3, x ≤ 5, x integer
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [1.0]
        )

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: -3.0, sense: .greaterOrEqual), // x ≥ -3
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)      // x ≤ 5
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        // Optimal: x = -3
        #expect(result.integerSolution[0] == -3,
                "Expected x = -3, got \(result.integerSolution[0])")
    }

    @Test("Mixed positive and negative bounds")
    func testMixedBounds() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // minimize 2x + 3y
        // subject to: x ∈ [-5, 0], y ∈ [0, 10]
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [2.0, 3.0]
        )

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            // x bounds
            .linearInequality(coefficients: [1.0, 0.0], rhs: -5.0, sense: .greaterOrEqual), // x ≥ -5
            .linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),     // x ≤ 0
            // y bounds
            .linearInequality(coefficients: [0.0, 1.0], rhs: 0.0, sense: .greaterOrEqual),  // y ≥ 0
            .linearInequality(coefficients: [0.0, 1.0], rhs: 10.0, sense: .lessOrEqual),    // y ≤ 10
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 5.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        // Optimal: x = -5, y = 0 (minimize 2x + 3y)
        #expect(result.integerSolution == [-5, 0],
                "Expected [-5, 0], got \(result.integerSolution)")
        #expect(abs(result.objectiveValue - (-10.0)) < 1e-6)
    }

    @Test("Variable shifting with constraints")
    func testShiftingWithConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // minimize x + 2y
        // subject to: x + y ≥ -2 (shifted constraint)
        //            x ∈ [-3, 0], y ∈ [-1, 2]
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [1.0, 2.0]
        )

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            // Main constraint
            .linearInequality(coefficients: [1.0, 1.0], rhs: -2.0, sense: .greaterOrEqual), // x + y ≥ -2
            // x bounds
            .linearInequality(coefficients: [1.0, 0.0], rhs: -3.0, sense: .greaterOrEqual),
            .linearInequality(coefficients: [1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),
            // y bounds
            .linearInequality(coefficients: [0.0, 1.0], rhs: -1.0, sense: .greaterOrEqual),
            .linearInequality(coefficients: [0.0, 1.0], rhs: 2.0, sense: .lessOrEqual),
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        // Check solution is feasible
        let x = Double(result.integerSolution[0])
        let y = Double(result.integerSolution[1])

        #expect(x >= -3.0 && x <= 0.0, "x out of bounds: \(x)")
        #expect(y >= -1.0 && y <= 2.0, "y out of bounds: \(y)")
        #expect(x + y >= -2.0, "Constraint violated: \(x) + \(y) < -2")
    }

    // MARK: - End-to-End Realistic Tests

    @Test("Knapsack problem with LinearFunction")
    func testKnapsackWithLinearFunction() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Knapsack: maximize value subject to weight constraint
        let values = [60.0, 100.0, 120.0]
        let weights = [10.0, 20.0, 30.0]
        let capacity = 50.0

        // Maximize value (minimize negative value)
        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: values.map { -$0 }
        )

        // Weight constraint: w₁x₁ + w₂x₂ + w₃x₃ ≤ capacity
        let constraints = [
            .linearInequality(coefficients: weights, rhs: capacity, sense: .lessOrEqual)
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: .allBinary(dimension: 3)
        )

        // Check solution is feasible
        let totalWeight = zip(weights, result.integerSolution).reduce(0.0) { $0 + $1.0 * Double($1.1) }
        #expect(totalWeight <= capacity + 1e-6,
                "Weight constraint violated: \(totalWeight) > \(capacity)")

        // Check all binary
        for val in result.integerSolution {
            #expect(val == 0 || val == 1, "Not binary: \(val)")
        }
    }

    @Test("Production planning with natural constraints")
    func testProductionPlanning() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Minimize cost: 5x + 8y (production costs)
        // Subject to: 2x + 3y ≥ 100 (demand)
        //            x, y ≥ 0, integer

        let objective = StandardLinearFunction<VectorN<Double>>(
            coefficients: [5.0, 8.0]
        )

        let constraints = [
            .linearInequality(coefficients: [2.0, 3.0], rhs: 100.0, sense: .greaterOrEqual) // Demand
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([25.0, 25.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        // Check demand satisfied
        let demand = 2.0 * Double(result.integerSolution[0]) + 3.0 * Double(result.integerSolution[1])
        #expect(demand >= 100.0 - 1e-6,
                "Demand not satisfied: \(demand) < 100")

        // Check non-negative
        #expect(result.integerSolution[0] >= 0)
        #expect(result.integerSolution[1] >= 0)
    }
}
