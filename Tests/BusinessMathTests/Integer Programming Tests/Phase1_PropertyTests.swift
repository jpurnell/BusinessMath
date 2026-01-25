import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Property-Based Tests for Branch-and-Bound
///
/// Tests mathematical invariants that must ALWAYS hold, regardless of problem instance.
/// These are the fundamental correctness properties of the solver.
@Suite("Property-Based Tests")
struct PropertyBasedTests {

    // MARK: - Bound Validity Properties

    @Test("Property: Relaxation bound is always valid",
          arguments: [
            (minimize: true, rhs: 3.7),
            (minimize: true, rhs: 5.5),
            (minimize: false, rhs: 3.7),
            (minimize: false, rhs: 5.5)
          ])
    func relaxationBoundAlwaysValid(minimize: Bool, rhs: Double) throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: rhs, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: minimize
        )

        // Property: bound must be valid for direction
        if minimize {
            // Minimization: bound ≤ objective
            #expect(result.bestBound <= result.objectiveValue + 1e-6,
                   "Minimization bound violated: \(result.bestBound) > \(result.objectiveValue)")
        } else {
            // Maximization: bound ≥ objective
            #expect(result.bestBound >= result.objectiveValue - 1e-6,
                   "Maximization bound violated: \(result.bestBound) < \(result.objectiveValue)")
        }
    }

    @Test("Property: Gap is never negative",
          arguments: [1.5, 2.7, 3.9, 5.1, 10.3])
    func gapNeverNegative(rhs: Double) throws {
        for minimize in [true, false] {
            let solver = BranchAndBoundSolver<VectorN<Double>>()

            let objective: @Sendable (VectorN<Double>) -> Double = { v in
                let arr = v.toArray()
                return arr[0] + arr[1]
            }

            let constraints: [MultivariateConstraint<VectorN<Double>>] = [
                .linearInequality(coefficients: [1.0, 1.0], rhs: rhs, sense: .lessOrEqual)
            ]

            let result = try solver.solve(
                objective: objective,
                from: VectorN([rhs/3, rhs/3]),
                subjectTo: constraints,
                integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
                minimize: minimize
            )

            // Property: gap ≥ 0
            #expect(result.relativeGap >= -1e-6,
                   "Negative gap detected: \(result.relativeGap)")
        }
    }

    // MARK: - Solution Feasibility Properties

    @Test("Property: Integer solution satisfies integrality",
          arguments: [2, 3, 4, 5])
    func integerSolutionIsInteger(dimension: Int) throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray().reduce(0.0, +)
        }

        let rhs = Double(dimension) + 0.7
        let coefficients = Array(repeating: 1.0, count: dimension)
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: coefficients, rhs: rhs, sense: .lessOrEqual)
        ]

        let initialGuess = VectorN(Array(repeating: rhs / Double(dimension), count: dimension))

        let result = try solver.solve(
            objective: objective,
            from: initialGuess,
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: dimension),
            minimize: true
        )

        // Property: All variables must be integer
        let solution = result.solution.toArray()
        for (i, value) in solution.enumerated() {
            let fractionalPart = abs(value - round(value))
            #expect(fractionalPart < 1e-6,
                   "Variable \(i) not integer: \(value)")
        }
    }

    @Test("Property: Solution satisfies all constraints",
          arguments: [
            (coeffs: [1.0, 1.0], rhs: 3.7),
            (coeffs: [2.0, 1.0], rhs: 5.5),
            (coeffs: [1.0, 2.0], rhs: 4.8)
          ])
    func solutionSatisfiesConstraints(coeffs: [Double], rhs: Double) throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: coeffs, rhs: rhs, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: 0.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [0.0, -1.0], rhs: 0.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Property: Constraint violation ≤ tolerance
        let solution = result.solution.toArray()
        let lhs = coeffs[0] * solution[0] + coeffs[1] * solution[1]

        #expect(lhs <= rhs + 1e-6,
               "Constraint violated: \(lhs) > \(rhs)")
        #expect(solution[0] >= -1e-6, "Non-negativity violated")
        #expect(solution[1] >= -1e-6, "Non-negativity violated")
    }

    // MARK: - Objective Value Properties

    @Test("Property: Objective matches solution",
          arguments: [true, false])
    func objectiveMatchesSolution(minimize: Bool) throws {
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
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: minimize
        )

        // Property: Recomputed objective equals stored objective
        let recomputedObjective = objective(result.solution)
        #expect(abs(result.objectiveValue - recomputedObjective) < 1e-6,
               "Objective mismatch: stored=\(result.objectiveValue), recomputed=\(recomputedObjective)")
    }

    // MARK: - Status Consistency Properties

    @Test("Property: Optimal status implies valid solution")
    func optimalStatusImpliesValidSolution() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
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

        if result.status == .optimal {
            // Property: Optimal must have integer solution
            let frac = abs(result.solution.toArray()[0] - round(result.solution.toArray()[0]))
            #expect(frac < 1e-6, "Optimal solution not integer")

            // Property: Gap should be small
            #expect(result.relativeGap < 0.01, "Optimal has large gap")
        }
    }

    @Test("Property: Infeasible status has no valid solution")
    func infeasibleStatusNoValidSolution() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Contradictory constraints
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -2.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Property: Infeasible must be detected
        #expect(result.status == .infeasible,
               "Infeasible problem not detected")
    }

    // MARK: - Monotonicity Properties

    @Test("Property: Tighter constraints don't improve objective (minimization)")
    func tighterConstraintsDontImprove() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Solve with loose constraint
        let looseResult = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: [.linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)],
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Solve with tight constraint
        let tightResult = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: [.linearInequality(coefficients: [1.0, 1.0], rhs: 3.0, sense: .lessOrEqual)],
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Property: Tighter feasible region → objective ≥ original (for minimization)
        if tightResult.status != .infeasible {
            #expect(tightResult.objectiveValue >= looseResult.objectiveValue - 1e-6,
                   "Tighter constraint improved objective (minimization)")
        }
    }

    // MARK: - Symmetry Properties

    @Test("Property: Permuting variables doesn't change optimal value")
    func permutationSymmetry() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Symmetric objective and constraints
        let objective1: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let objective2: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[1] + arr[0]  // Permuted
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result1 = try solver.solve(
            objective: objective1,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let result2 = try solver.solve(
            objective: objective2,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Property: Symmetric problems have equal optimal values
        #expect(abs(result1.objectiveValue - result2.objectiveValue) < 1e-6,
               "Symmetry violated")
    }

    // MARK: - Scaling Properties

    @Test("Property: Objective scaling preserves optimality",
          arguments: [0.1, 1.0, 10.0, 100.0])
    func objectiveScalingPreservesOptimality(scale: Double) throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objectiveUnscaled: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let objectiveScaled: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return scale * (arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let resultUnscaled = try solver.solve(
            objective: objectiveUnscaled,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let resultScaled = try solver.solve(
            objective: objectiveScaled,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Property: Optimal solutions are the same
        let sol1 = resultUnscaled.integerSolution
        let sol2 = resultScaled.integerSolution

        #expect(sol1[0] == sol2[0] && sol1[1] == sol2[1],
               "Objective scaling changed optimal solution")

        // Objective values related by scale
        #expect(abs(resultScaled.objectiveValue - scale * resultUnscaled.objectiveValue) < 1e-4,
               "Objective scaling incorrect")
    }

    // MARK: - Bounds Tightening Properties

    @Test("Property: Adding valid integer cuts tightens bounds")
    func cutsAlwaysTightenBounds() throws {
        let solverWithoutCuts = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: false
        )

        let solverWithCuts = BranchAndBoundSolver<VectorN<Double>>(
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

        let resultWithoutCuts = try solverWithoutCuts.solve(
            objective: objective,
            from: VectorN([2.9, 2.9]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        let resultWithCuts = try solverWithCuts.solve(
            objective: objective,
            from: VectorN([2.9, 2.9]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Property: Cuts should close the gap (or keep it same)
        // Gap_with_cuts ≤ Gap_without_cuts
        #expect(resultWithCuts.relativeGap <= resultWithoutCuts.relativeGap + 1e-6,
               "Cuts increased gap")
    }

    // MARK: - Tolerance Consistency Properties

    @Test("Property: Solution respects integrality tolerance")
    func solutionRespectsInintegralityTolerance() throws {
        let tolerance = 1e-6
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: tolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
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

        // Property: Fractional part < tolerance
        let solution = result.solution.toArray()[0]
        let fractionalPart = abs(solution - round(solution))

        #expect(fractionalPart < tolerance,
               "Solution exceeds integrality tolerance: \(fractionalPart)")
    }
}
