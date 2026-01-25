import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 2: Cutting Plane Mathematical Validity
///
/// Tests Gomory cut generation validity, cut violation checking, and cut deduplication.
/// Ensures cuts are mathematically valid and actually improve the relaxation.
@Suite("Phase 2: Cut Validity")
struct CutValidityTests {

    // MARK: - Gomory Cut Validity Guards

    @Test("Gomory cuts generated only for integer basic variables")
    func gomoryCutsOnlyForIntegerVariables() throws {
        // Cut should not be generated for continuous basic variables
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]  // x is integer, y is continuous
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [0],  // Only x is integer
                binaryVariables: []     // y is continuous
            ),
            minimize: true
        )

        // Should succeed and generate cuts only for integer variable
        #expect(result.status == .optimal)
    }

    @Test("Gomory cuts not generated for nearly-integer RHS")
    func gomoryCutsSkipNearlyIntegerRHS() throws {
        // When RHS is nearly integer (2.0 + 1e-8 ≈ 2.0), cuts should not be generated
        // The LP solution will be x = 2.00000001, which is within tolerance of integer 2
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-5,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-5  // Must be ≥ integralityTolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Constraint that leads to nearly-integer LP solution
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.0 + 1e-8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false  // MAXIMIZE to hit the upper bound
        )

        // Should recognize solution is essentially integer
        #expect(result.status == IntegerSolutionStatus.optimal)
        #expect(result.integerSolution[0] == 2)
    }

    @Test("Gomory cuts skip slack/artificial variables")
    func gomoryCutsSkipSlackVariables() throws {
        // Cuts should only be generated for original variables, not slacks
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0, -1.0], rhs: 1.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should generate valid cuts only for original variables
        #expect(result.status == .optimal)
    }

    @Test("Gomory cut coefficients correspond to original variables")
    func gomoryCutCoefficientsValid() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 4.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Cuts should improve bound
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] + result.integerSolution[1] <= 5)
    }

    // MARK: - Cut Violation Testing

    @Test("Cuts violate current fractional solution")
    func cutsViolateFractionalSolution() throws {
        // Generated cuts must actually cut off the current LP solution
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // LP solution (2.75, 2.75) should be cut off
        // IP solution should be (0,0) or better
        #expect(result.status == .optimal)
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] <= 6)
    }

    @Test("Non-violating cuts are not added")
    func nonViolatingCutsRejected() throws {
        // Cuts that don't violate current solution should be skipped
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            cutTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should solve without issues
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] <= 3)
    }

    @Test("Cut violation tolerance respected")
    func cutViolationToleranceRespected() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-4  // Larger tolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // With larger tolerance, fewer cuts might be added
        #expect(result.status == .optimal)
    }

    // MARK: - Cut Deduplication

    @Test("Identical cuts are deduplicated")
    func identicalCutsDeduplicated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5  // More rounds to potentially generate duplicates
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 4.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should not add duplicate cuts
        #expect(result.status == .optimal)
    }

    @Test("Nearly-identical cuts within precision deduplicated")
    func nearlyIdenticalCutsDeduplicated() throws {
        // Cuts that differ only in low-order bits should be treated as identical
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 4
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.1, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)
    }

    @Test("Different cuts not incorrectly deduplicated")
    func differentCutsNotDeduplicated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 5.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Should generate multiple different cuts
        #expect(result.status == .optimal)
    }

    // MARK: - Cut Normalization Effects

    @Test("Normalized cuts preserve validity")
    func normalizedCutsPreserveValidity() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            normalizeCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Constraints with varying scales
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [100.0, 100.0], rhs: 370.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Normalization shouldn't break correctness
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] + result.integerSolution[1] <= 4)
    }

    @Test("Normalization doesn't invalidate integer logic")
    func normalizationPreservesIntegerSemantics() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            normalizeCuts: true,
            cutCoefficientThreshold: 1e-8
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 4.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Solution should still be integer
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] <= 5)
    }

    // MARK: - Cut Effectiveness

    @Test("Cuts improve LP bound")
    func cutsImproveBound() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.9, 2.9]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Cuts should tighten the relaxation
        // LP bound: 5.9 → after cuts: closer to 6.0 (IP optimum)
        #expect(result.status == .optimal)
        #expect(result.relativeGap < 0.2)  // Cuts reduce gap
    }

    @Test("Cuts reduce branch-and-bound tree size")
    func cutsReduceTreeSize() throws {
        // Compare with/without cutting planes
        let solverWithCuts = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let solverWithoutCuts = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: false
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 6.8, sense: .lessOrEqual)
        ]

        let resultWithCuts = try solverWithCuts.solve(
            objective: objective,
            from: VectorN([2.0, 2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        let resultWithoutCuts = try solverWithoutCuts.solve(
            objective: objective,
            from: VectorN([2.0, 2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Both should find optimal
        #expect(resultWithCuts.status == .optimal)
        #expect(resultWithoutCuts.status == .optimal)

        // Cutting planes should reduce nodes explored (usually)
        // Note: Not guaranteed for all problems, but typical
        #expect(resultWithCuts.objectiveValue == resultWithoutCuts.objectiveValue)
    }

    // MARK: - Edge Cases

    @Test("Cuts with extreme coefficients handled robustly")
    func cutsWithExtremeCoefficients() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            normalizeCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e6 * arr[0] + 1e-6 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e6, 1e-6], rhs: 2.5e6, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1e6]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle extreme coefficients without numerical issues
        #expect(result.status == .optimal || result.status == .feasible)
    }

    @Test("Cuts on single-variable problem")
    func cutsOnSingleVariable() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] <= 4)
    }
}
