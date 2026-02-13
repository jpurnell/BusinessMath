import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 1.4: Objective Value Consistency with Variable Shifting
///
/// Tests that objective values are correctly computed in both shifted and unshifted spaces.
/// Critical when variable shifting transforms x → x' = x - shift.
@Suite("Phase 1.4: Objective Consistency")
struct ObjectiveConsistencyTests {

    // MARK: - Linear Objectives (Shift Invariant)

    @Test("Linear objective consistent after variable shifting")
    func linearObjectiveShiftConsistent() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // Linear objective: 2x + 3y
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 2.0 * arr[0] + 3.0 * arr[1]
        }

        // Constraint with negative bound: x ≥ -2
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 2.0, sense: .lessOrEqual)  // x ≥ -2
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Verify objective value matches solution
        let solution = result.solution.toArray()
        let expectedObjective = 2.0 * solution[0] + 3.0 * solution[1]

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    @Test("Linear objective: shifted vs unshifted values equal")
    func linearObjectiveShiftEquivalence() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1] + 3.0 * arr[2]
        }

        // Constraints forcing negative variables
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 2.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0, 0.0], rhs: 3.0, sense: .lessOrEqual),  // x ≥ -3
            .linearInequality(coefficients: [0.0, -1.0, 0.0], rhs: 2.0, sense: .lessOrEqual),  // y ≥ -2
            .linearInequality(coefficients: [0.0, 0.0, -1.0], rhs: 1.0, sense: .lessOrEqual)   // z ≥ -1
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // For linear objectives, value should match exactly
		// let solution = result.solution.toArray()
        let recomputedObjective = objective(result.solution)

        #expect(abs(result.objectiveValue - recomputedObjective) < 1e-6)
    }

    // MARK: - Objective Recomputation

    @Test("Objective value recomputed in original space")
    func objectiveRecomputedInOriginalSpace() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Force variable shifting with negative bound
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 5.0, sense: .lessOrEqual)  // x ≥ -5
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Solution should be in original (unshifted) space
        let solution = result.solution

        // Objective value should match solution
        let actualObjective = objective(solution)
        #expect(abs(result.objectiveValue - actualObjective) < 1e-6)
    }

    @Test("Objective consistency across multiple incumbents")
    func objectiveConsistencyMultipleIncumbents() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 10.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0, 0.0], rhs: 3.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Final incumbent objective should match solution
        let finalObjective = objective(result.solution)
        #expect(abs(result.objectiveValue - finalObjective) < 1e-6)
    }

    // MARK: - Nonlinear Objectives (Not Shift Invariant)

    @Test("Quadratic objective handled correctly with shifting")
    func quadraticObjectiveWithShifting() throws {
        // Quadratic objectives are NOT shift-invariant
        // (x - a)² ≠ x² when shifting

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // Quadratic objective: x²
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let x = v.toArray()[0]
            return x * x
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: 3.0, sense: .lessOrEqual)  // x ≥ -3
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Objective value MUST be recomputed in original space
        let solution = result.solution.toArray()[0]
        let expectedObjective = solution * solution

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-4)
    }

    @Test("Absolute value objective with shifting")
    func absoluteValueObjectiveWithShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // Absolute value: |x|
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            abs(v.toArray()[0])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: 5.0, sense: .lessOrEqual)  // x ≥ -5
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should find x = 0 (minimum of |x|)
        let solution = result.solution.toArray()[0]
        let expectedObjective = abs(solution)

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    // MARK: - Edge Cases

    @Test("Zero objective value with shifting")
    func zeroObjectiveWithShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] - 5.0  // Can be zero
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 2.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, -1.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let solution = result.solution.toArray()
        let expectedObjective = solution[0] + solution[1] - 5.0

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    @Test("Negative objective value with shifting")
    func negativeObjectiveWithShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] - 10.0  // Negative values
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 2.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, -1.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let solution = result.solution.toArray()
        let expectedObjective = solution[0] + solution[1] - 10.0

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    // MARK: - Shifting Disabled (Control Cases)

    @Test("Objective consistency without shifting enabled")
    func objectiveConsistencyNoShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: false  // Disabled
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let solution = result.solution.toArray()
        let expectedObjective = solution[0] + solution[1]

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    // MARK: - Maximization

    @Test("Maximization objective consistent with shifting")
    func maximizationObjectiveConsistency() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1]  // Maximize
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false  // Maximization
        )

        let solution = result.solution.toArray()
        let expectedObjective = solution[0] + 2.0 * solution[1]

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    // MARK: - Multi-Variable Shifting

    @Test("Objective consistent with multiple shifted variables")
    func multipleShiftedVariables() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        // All variables have negative lower bounds
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0, 0.0], rhs: 3.0, sense: .lessOrEqual),  // x ≥ -3
            .linearInequality(coefficients: [0.0, -1.0, 0.0], rhs: 2.0, sense: .lessOrEqual),  // y ≥ -2
            .linearInequality(coefficients: [0.0, 0.0, -1.0], rhs: 1.0, sense: .lessOrEqual)   // z ≥ -1
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        let solution = result.solution.toArray()
        let expectedObjective = solution[0] + solution[1] + solution[2]

        #expect(abs(result.objectiveValue - expectedObjective) < 1e-6)
    }

    // MARK: - Regression Tests

    @Test("Objective value not corrupted by intermediate solutions")
    func objectiveNotCorruptedByIntermediateSolutions() throws {
        // Ensure final objective matches final solution, not any intermediate incumbent
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 8.7, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([3.0, 3.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Recompute from scratch
        let finalObjective = objective(result.solution)
        #expect(abs(result.objectiveValue - finalObjective) < 1e-6)
    }
}
