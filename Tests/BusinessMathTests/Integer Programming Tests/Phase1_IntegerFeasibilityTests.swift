import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 1.3: Integer Feasibility Validation
///
/// Tests comprehensive validation of integer feasibility:
/// - Integrality of variables
/// - Constraint satisfaction after rounding
/// - Tolerance consistency
/// - Edge cases near boundaries
@Suite("Phase 1.3: Integer Feasibility Validation")
struct IntegerFeasibilityTests {

    // MARK: - Basic Integrality Checks

    @Test("Integer variables are truly integer within tolerance")
    func integerVariablesAreInteger() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Check each integer variable
        let solution = result.solution.toArray()
        for value in solution {
            let fractionalPart = abs(value - round(value))
            #expect(fractionalPart < 1e-6)
        }
    }

    @Test("Binary variables are in {0, 1}")
    func binaryVariablesAreBinary() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1] + 3.0 * arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [],
                binaryVariables: [0, 1, 2]
            ),
            minimize: true
        )

        let sol = result.integerSolution
        for value in sol {
            #expect(value == 0 || value == 1)
        }
    }

    @Test("Mixed integer-binary variables validated correctly")
    func mixedIntegerBinary() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 3.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [0, 1],
                binaryVariables: [2]
            ),
            minimize: true
        )

        let sol = result.integerSolution
        // First two should be integer
        #expect(abs(result.solution.toArray()[0] - Double(sol[0])) < 1e-6)
        #expect(abs(result.solution.toArray()[1] - Double(sol[1])) < 1e-6)
        // Third should be binary
        #expect(sol[2] == 0 || sol[2] == 1)
    }

    // MARK: - Constraint Satisfaction After Rounding

    @Test("Rounded solution satisfies all constraints")
    func roundedSolutionSatisfiesConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0, -1.0], rhs: 2.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 1.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Manually verify each constraint
        let solution = result.solution.toArray()

        // Constraint 1: x + y ≤ 5
        #expect(solution[0] + solution[1] <= 5.0 + 1e-6)

        // Constraint 2: x - y ≤ 2
        #expect(solution[0] - solution[1] <= 2.0 + 1e-6)

        // Constraint 3: -x + y ≤ 2
        #expect(-solution[0] + solution[1] <= 2.0 + 1e-6)
    }

    @Test("Solution near constraint boundary is valid")
    func solutionNearBoundary() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Tight constraint: exactly at integer boundary
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 4.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let solution = result.solution.toArray()
        #expect(solution[0] + solution[1] <= 4.0 + 1e-6)
    }

    @Test("Invalid rounded solution rejected")
    func invalidRoundedSolutionRejected() throws {
        // Problem where naive rounding violates constraints
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])  // Maximize
        }

        // LP optimal: (2.5, 2.5) = 5.0
        // Naive rounding up: (3, 3) = 6.0 violates x+y ≤ 5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false  // Maximization
        )

        // Should not round to (3,3) which violates constraint
        let solution = result.solution.toArray()
        #expect(solution[0] + solution[1] <= 5.0 + 1e-6)
    }

    // MARK: - Tolerance Edge Cases

    @Test("Value at integrality tolerance boundary accepted")
    func toleranceBoundaryAccepted() throws {
        // Test values like 1.999999 or 2.000001 near integers
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Solution should be integer within tolerance
        let solution = result.solution.toArray()[0]
        let fractionalPart = abs(solution - round(solution))
        #expect(fractionalPart < 1e-6)
    }

    @Test("Fractional value beyond tolerance rejected")
    func fractionalBeyondToleranceRejected() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Final solution must be integer, not 2.5
        let solution = result.solution.toArray()[0]
        let fractionalPart = abs(solution - round(solution))
        #expect(fractionalPart < 1e-6)
    }

    // MARK: - Implicit Integrality

    @Test("Variable with tight integer bounds is implicitly integer")
    func implicitIntegralityFromBounds() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // x ∈ [3, 3] → implicitly x = 3
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 0.0], rhs: 3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: -3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([3.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // x should be exactly 3 (implicitly integer)
        let solution = result.solution.toArray()
        #expect(abs(solution[0] - 3.0) < 1e-6)
    }

    // MARK: - Multiple Constraint Types

    @Test("Solution satisfies linear inequality constraints")
    func satisfiesLinearInequalities() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 1.0], rhs: 8.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0, 2.0], rhs: 7.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),  // x ≥ 0
            .linearInequality(coefficients: [0.0, -1.0], rhs: 0.0, sense: .lessOrEqual)   // y ≥ 0
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let sol = result.solution.toArray()

        // Verify each constraint
        #expect(2.0 * sol[0] + sol[1] <= 8.0 + 1e-6)
        #expect(sol[0] + 2.0 * sol[1] <= 7.0 + 1e-6)
        #expect(sol[0] >= -1e-6)
        #expect(sol[1] >= -1e-6)
    }

    @Test("Solution satisfies equality constraints")
    func satisfiesEqualityConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // x + y = 5 (equality)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, -1.0], rhs: -5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let sol = result.solution.toArray()
        #expect(abs(sol[0] + sol[1] - 5.0) < 1e-6)
    }

    // MARK: - Boundary and Edge Cases

    @Test("Zero as valid integer solution")
    func zeroIsValidInteger() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 1.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, -1.0], rhs: 0.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let sol = result.integerSolution
        // Should find (0, 0) or (1, 0) or (0, 1)
        #expect(sol[0] >= 0)
        #expect(sol[1] >= 0)
        #expect(sol[0] + sol[1] <= 2)
    }

    @Test("Large integer values validated correctly")
    func largeIntegerValues() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Large constraint
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1000.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([500.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        let solution = result.solution.toArray()[0]
        let fractionalPart = abs(solution - round(solution))
        #expect(fractionalPart < 1e-6)
        #expect(solution <= 1001.0)
    }

    @Test("Negative integer values validated correctly")
    func negativeIntegerValues() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Allow negative values: x ≥ -5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: 5.0, sense: .lessOrEqual)  // x ≥ -5
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        let solution = result.solution.toArray()[0]
        let fractionalPart = abs(solution - round(solution))
        #expect(fractionalPart < 1e-6)
        #expect(solution >= -5.5)
    }

    // MARK: - Comprehensive Validation

    @Test("All feasibility checks pass on valid solution")
    func comprehensiveValidation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1] + 3.0 * arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 10.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [2.0, 1.0, 0.0], rhs: 12.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0, 0.0], rhs: 0.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, -1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, 0.0, -1.0], rhs: 0.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([3.0, 3.0, 3.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        let sol = result.solution.toArray()

        // Check 1: Integrality
        for value in sol {
            let frac = abs(value - round(value))
            #expect(frac < 1e-6)
        }

        // Check 2: All constraints satisfied
        #expect(sol[0] + sol[1] + sol[2] <= 10.0 + 1e-6)
        #expect(2.0 * sol[0] + sol[1] <= 12.0 + 1e-6)
        #expect(sol[0] >= -1e-6)
        #expect(sol[1] >= -1e-6)
        #expect(sol[2] >= -1e-6)

        // Check 3: Non-negative
        #expect(sol[0] >= -1e-6)
        #expect(sol[1] >= -1e-6)
        #expect(sol[2] >= -1e-6)
    }
}
