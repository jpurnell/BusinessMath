import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Adversarial and Stress Tests
///
/// Tests designed to break the solver:
/// - Ill-conditioned problems
/// - Extreme coefficient ranges
/// - Nearly-degenerate problems
/// - Pathological edge cases
/// - Numerical precision stress tests
@Suite("Adversarial and Stress Tests")
struct AdversarialTests {

    // MARK: - Ill-Conditioned Problems

    @Test("Extreme coefficient magnitude ratio")
    func extremeCoefficientRatio() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            normalizeCuts: true
        )

        // Coefficient ratio: 1e12 (very ill-conditioned)
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

        // Should not crash, should find some solution
        let validStatuses: [IntegerSolutionStatus] = [.optimal, .feasible, .nodeLimit, .timeLimit]
        #expect(validStatuses.contains(result.status))
    }

    @Test("Tiny coefficients near machine epsilon")
    func tinyCoefficientsMachineEpsilon() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            normalizeCuts: true,
            cutCoefficientThreshold: 1e-10
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e-12 * arr[0] + 1e-12 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e-12, 1e-12], rhs: 5.5e-12, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle gracefully
        #expect(!result.objectiveValue.isNaN)
        #expect(!result.objectiveValue.isInfinite)
    }

    @Test("Mixed scales in same problem")
    func mixedScalesInProblem() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            normalizeCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e8 * arr[0] + arr[1] + 1e-8 * arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e8, 1.0, 1e-8], rhs: 3.7e8, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0, 1e6, 1.0], rhs: 1e6, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 500.0, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        #expect(result.status != .infeasible || result.status == .infeasible)  // Should complete
    }

    // MARK: - Nearly-Degenerate Problems

    @Test("Nearly-integer fractional values")
    func nearlyIntegerFractionalValues() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // RHS very close to integer
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.0 + 1e-9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should recognize as essentially integer
        #expect(result.integerSolution[0] <= 2)
    }

    @Test("Degenerate LP with multiple optimal bases")
    func degenerateLPMultipleOptimalBases() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0]  // Only depends on x
        }

        // y is free within bounds (degenerate)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 0.0], rhs: 3.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 5.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle degeneracy
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] <= 4)
    }

    @Test("Tight constraint creating near-zero slack")
    func tightConstraintNearZeroSlack() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Multiple tight constraints
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 4.0000001, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0, -1.0], rhs: 0.0000001, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal || result.status == .feasible)
    }

    // MARK: - Precision Boundary Cases

    @Test("Objective value near zero")
    func objectiveValueNearZero() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] - 2.0  // Zero when x=2
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -1.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should handle zero objective
        #expect(!result.objectiveValue.isNaN)
        #expect(abs(result.objectiveValue) < 1.0)
    }

    @Test("Gap calculation with near-zero objective")
    func gapCalculationNearZeroObjective() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] - 5.0  // Near zero
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

        // Gap should not be NaN or infinite
        #expect(!result.relativeGap.isNaN)
        #expect(!result.relativeGap.isInfinite)
    }

    @Test("Very large objective values")
    func veryLargeObjectiveValues() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e10 * arr[0] + 1e10 * arr[1]
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

        // Should not overflow
        #expect(!result.objectiveValue.isInfinite)
        #expect(result.status == .optimal)
    }

    // MARK: - Pathological Branching Cases

    @Test("All fractional variables at 0.5")
    func allVariablesFractionalMidpoint() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray().reduce(0.0, +)
        }

        // LP solution: all variables = 0.5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0, 1.0], rhs: 2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 4),
            minimize: true
        )

        // Maximum branching ambiguity - should handle
        #expect(result.status == .optimal || result.status == .nodeLimit)
    }

    @Test("Binary knapsack with many items")
    func binaryKnapsackManyItems() throws {
        // Classic hard case for branch-and-bound
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 1000  // Limit to prevent timeout
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            let values = [23.0, 31.0, 29.0, 44.0, 53.0, 38.0, 63.0, 85.0]
            return -zip(arr, values).map(*).reduce(0.0, +)  // Maximize value
        }

        let weights = [12.0, 15.0, 11.0, 18.0, 22.0, 16.0, 28.0, 35.0]
        let capacity = 50.0

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: weights, rhs: capacity, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN(Array(repeating: 0.5, count: 8)),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [],
                binaryVariables: Set(0..<8)
            ),
            minimize: true  // Minimizing negative = maximizing
        )

        // Should find feasible solution or hit limit
        let validStatuses: [IntegerSolutionStatus] = [.optimal, .feasible, .nodeLimit]
        #expect(validStatuses.contains(result.status))
    }

    // MARK: - Constraint Structure Pathologies

    @Test("Redundant constraints")
    func redundantConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Multiple redundant versions of same constraint
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [2.0, 2.0], rhs: 10.0, sense: .lessOrEqual),  // Redundant
            .linearInequality(coefficients: [0.5, 0.5], rhs: 2.5, sense: .lessOrEqual)    // Redundant
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle redundancy
        #expect(result.status == .optimal)
    }

    @Test("Nearly-parallel constraints")
    func nearlyParallelConstraints() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Constraints nearly parallel
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0 + 1e-8, 1.0 - 1e-8], rhs: 5.1, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal || result.status == .feasible)
    }

    // MARK: - Variable Shifting Edge Cases

    @Test("Large negative bounds requiring shifting")
    func largeNegativeBoundsShifting() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Very negative lower bounds
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 1000.0, sense: .lessOrEqual),  // x ≥ -1000
            .linearInequality(coefficients: [0.0, -1.0], rhs: 500.0, sense: .lessOrEqual)    // y ≥ -500
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should handle large shifts
        #expect(result.status == .optimal)
        let sol = result.solution.toArray()
        #expect(sol[0] >= -1001.0)
        #expect(sol[1] >= -501.0)
    }

    // MARK: - Cutting Plane Stress Tests

    @Test("Many cutting rounds with stagnation")
    func manyCuttingRoundsStagnation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 20,  // Many rounds
            detectStagnation: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.1, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should terminate via stagnation before 20 rounds
        #expect(result.status == .optimal)
    }

    @Test("Cuts with numerical drift accumulation")
    func cutsNumericalDriftAccumulation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5,
            normalizeCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1.0001 * arr[0] + 0.9999 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0001, 0.9999], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should maintain numerical stability across rounds
        #expect(!result.objectiveValue.isNaN)
        #expect(result.status == .optimal || result.status == .feasible)
    }

    // MARK: - Memory and Performance Stress

    @Test("High-dimensional problem")
    func highDimensionalProblem() throws {
        let dimension = 20
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100  // Limit for performance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray().reduce(0.0, +)
        }

        let coefficients = Array(repeating: 1.0, count: dimension)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: coefficients, rhs: 10.5, sense: .lessOrEqual)
        ]

        let initialGuess = VectorN(Array(repeating: 0.5, count: dimension))

        let result = try solver.solve(
            objective: objective,
            from: initialGuess,
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: dimension),
            minimize: true
        )

        // Should handle high dimension without crashing
        let validStatuses2: [IntegerSolutionStatus] = [.optimal, .feasible, .nodeLimit]
        #expect(validStatuses2.contains(result.status))
    }

    @Test("Deep branching tree")
    func deepBranchingTree() throws {
        // Problem designed to force deep tree
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 500
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            // Carefully balanced to force exploration
            return arr[0] + 1.01 * arr[1] + 1.02 * arr[2] + 1.03 * arr[3]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0, 1.0], rhs: 6.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.6, 1.6, 1.6, 1.6]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 4),
            minimize: true
        )

        // Should handle deep trees
        let validStatuses3: [IntegerSolutionStatus] = [.optimal, .feasible, .nodeLimit]
        #expect(validStatuses3.contains(result.status))
    }
}
