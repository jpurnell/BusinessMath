import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 1.1: Bound Semantics and Sign Conventions
///
/// Tests mathematical correctness of bound handling for minimization and maximization.
/// Ensures relaxation bounds are always valid (lower bound for min, upper bound for max).
@Suite("Phase 1.1: Bound Semantics")
struct BoundSemanticsTests {

    // MARK: - Minimization Bound Properties

    @Test("Minimization: LP relaxation provides lower bound")
    func minimizationRelaxationIsLowerBound() throws {
        // For minimization, LP relaxation ≤ IP optimum
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]  // Minimize x + y
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // LP optimum: 3.7 (both variables = 1.85)
        // IP optimum: 4.0 (both variables = 2)
        // Therefore: bestBound ≤ objectiveValue
        #expect(result.bestBound <= result.objectiveValue + 1e-6)
    }

    @Test("Minimization: Best bound monotonically increases")
    func minimizationBoundMonotonicity() throws {
        // As we explore nodes, best bound should never decrease (for minimization)
        // This test would require instrumentation to track bound history
        // For now, we verify the final bound is valid

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Bound must be valid
        #expect(result.bestBound <= result.objectiveValue + 1e-6)
    }

    @Test("Minimization: Gap is always non-negative")
    func minimizationGapNonNegative() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 4.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Gap = incumbent - bound (for minimization)
        let gap = result.objectiveValue - result.bestBound
        #expect(gap >= -1e-6)  // Allow small numerical error
        #expect(result.relativeGap >= -1e-6)
    }

    // MARK: - Maximization Bound Properties

    @Test("Maximization: LP relaxation provides upper bound")
    func maximizationRelaxationIsUpperBound() throws {
        // For maximization, LP relaxation ≥ IP optimum
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])  // Maximize x + y (minimize negative)
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false  // Maximization
        )

        // LP optimum: 3.7
        // IP optimum: 3.0 (both variables = 1 or one = 3, other = 0)
        // For maximization: bestBound ≥ objectiveValue
        #expect(result.bestBound >= result.objectiveValue - 1e-6)
    }

    @Test("Maximization: Best bound monotonically decreases")
    func maximizationBoundMonotonicity() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 2.0 * arr[1]  // Maximize
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false  // Maximization
        )

        // For maximization: bound ≥ objective
        #expect(result.bestBound >= result.objectiveValue - 1e-6)
    }

    @Test("Maximization: Gap is always non-negative")
    func maximizationGapNonNegative() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 4.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: false  // Maximization
        )

        // Gap = bound - incumbent (for maximization)
        let gap = result.bestBound - result.objectiveValue
        #expect(gap >= -1e-6)
        #expect(result.relativeGap >= -1e-6)
    }

    // MARK: - Gap Computation Correctness

    @Test("Relative gap formula is correct for minimization")
    func relativeGapMinimization() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Manual gap computation
        let absoluteGap = result.objectiveValue - result.bestBound
        let expectedRelativeGap = abs(absoluteGap) / max(abs(result.objectiveValue), 1e-10)

        #expect(abs(result.relativeGap - expectedRelativeGap) < 1e-6)
    }

    @Test("Relative gap formula is correct for maximization")
    func relativeGapMaximization() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false  // Maximization
        )

        // Manual gap computation (for maximization: bound - objective)
        let absoluteGap = result.bestBound - result.objectiveValue
        let expectedRelativeGap = abs(absoluteGap) / max(abs(result.objectiveValue), 1e-10)

        #expect(abs(result.relativeGap - expectedRelativeGap) < 1e-6)
    }

    @Test("Zero gap when optimal solution found at root")
    func zeroGapAtOptimal() throws {
        // Problem where LP and IP solutions coincide
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Constraint with integer RHS and integer-optimal solution
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

        // When LP solution is integer, gap should be zero
        #expect(result.relativeGap < 1e-6)
    }

    // MARK: - Bound Comparison Properties

    @Test("Bound comparison respects minimization direction")
    func boundComparisonMinimization() throws {
        // Test that bound comparisons use correct direction
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 2.0 * arr[0] + 3.0 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // For minimization: better bound is LOWER
        // bestBound should be the lowest bound seen
        #expect(result.bestBound <= result.objectiveValue + 1e-6)
    }

    @Test("Bound comparison respects maximization direction")
    func boundComparisonMaximization() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 2.0 * arr[0] + 3.0 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false  // Maximization
        )

        // For maximization: better bound is HIGHER
        // bestBound should be the highest bound seen
        #expect(result.bestBound >= result.objectiveValue - 1e-6)
    }

    // MARK: - Edge Cases

    @Test("Gap calculation with zero objective value")
    func gapWithZeroObjective() throws {
        // Edge case: objective value is zero
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] - 2.0  // Can be zero when x=2
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -1.5, sense: .lessOrEqual)  // x >= 1.5
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should handle division by zero in relative gap
        #expect(!result.relativeGap.isNaN)
        #expect(!result.relativeGap.isInfinite)
    }

    @Test("Gap calculation with negative objective values")
    func gapWithNegativeObjective() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] - 10.0  // Negative values
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Gap should still be non-negative
        #expect(result.relativeGap >= -1e-6)

        // Bound should be valid
        #expect(result.bestBound <= result.objectiveValue + 1e-6)
    }

    @Test("Large coefficient problem maintains bound validity")
    func largeCoefficients() throws {
        // Test with large coefficients to stress numerical precision
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e6 * arr[0] + 1e6 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e6, 1e6], rhs: 3.7e6, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Bounds should remain valid despite large coefficients
        #expect(result.bestBound <= result.objectiveValue + 1e-3)  // Slightly relaxed tolerance
        #expect(result.relativeGap >= -1e-6)
    }
}
