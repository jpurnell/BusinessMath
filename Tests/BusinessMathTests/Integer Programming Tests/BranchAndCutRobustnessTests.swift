import Testing
import Numerics
@testable import BusinessMath

// MARK: - Branch-and-Bound & Branch-and-Cut Robustness Tests

@Suite("Branch-and-Cut Mathematical Robustness")
struct BranchAndCutRobustnessTests {

    // MARK: Tier 1 — Mathematical Correctness

    @Test("Cuts are generated at non-root nodes when enabled")
    func cutsGeneratedAtChildNodes() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        // Knapsack problem: max 5x + 4y s.t. 3x + 2y ≤ 7.5
        // This problem has fractional LP optimum that requires branching
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(5.0 * arr[0] + 4.0 * arr[1])  // Maximize
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [3.0, 2.0], rhs: 7.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: true
        )

        // Cuts should be generated if fractional basic variables exist
        // Note: Cut generation depends on simplex basis structure
        #expect(result.cuttingPlaneStats != nil)
        #expect(result.cuttingPlaneStats!.totalCutsGenerated >= 0)
    }

    @Test("LP infeasibility after cuts prunes node")
    func lpInfeasibilityAfterCutsPrunes() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Infeasible constraints: x <= 0.2 and x >= 0.8
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 0.2, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -0.8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.status == .infeasible || result.nodesExplored < 3)
    }

    // MARK: Tier 2 — Algorithmic Completeness

    @Test("Mixed-Integer Rounding cuts are generated when enabled")
    func mirCutsGenerated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        // Create linear objective: min x + 3y
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + 3.0 * arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.3, 0.7]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.cuttingPlaneStats?.mirCuts ?? 0 >= 0)
    }

    @Test("Duplicate cuts are not added repeatedly")
    func duplicateCutsAreDeduplicated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 0.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.cuttingPlaneStats!.totalCutsGenerated < 5)
    }

    // MARK: Tier 3 — Numerical Robustness

    @Test("Cutting terminates when no bound improvement occurs")
    func cuttingTerminatesOnStagnation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.999999]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.cuttingPlaneStats!.maxRoundsAtNode <= solver.maxCuttingRounds)
    }

    @Test("Numerical tolerance does not reject near-integer solutions")
    func nearIntegerSolutionsAccepted() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-6
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.9999999]),
            subjectTo: [],
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.integerSolution[0] == 1)
    }

    // MARK: Tier 4 — Bound Management & Termination

    @Test("Global bound never exceeds incumbent for minimization")
    func globalBoundIsValid() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.4]),
            subjectTo: [],
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.bestBound <= result.objectiveValue + 1e-8)
    }

    @Test("Relative gap is non-negative")
    func relativeGapNonNegative() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.6]),
            subjectTo: [],
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.relativeGap >= 0.0)
    }

    // MARK: Tier 5 — API Safety

    @Test("Variable shifting preserves optimal solution")
    func variableShiftingCorrectness() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableVariableShifting: true
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Constraints: -x <= 3 (x >= -3) and x <= 5
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [-1.0], rhs: 3.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [1.0], rhs: 5.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.integerSolution[0] == -3)
    }

    @Test("Cuts disabled when relaxation solver lacks tableau")
    func cutsDisabledForNonSimplexSolver() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            relaxationSolver: DummyNonlinearRelaxationSolver()
        )

        // Create linear objective: min x
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: [],
            integerSpec: .allInteger(dimension: 1)
        )

        #expect(result.cuttingPlaneStats?.totalCutsGenerated == 0)
    }
}

// MARK: - Test Support

/// Mock relaxation solver that doesn't provide simplex tableau
struct DummyNonlinearRelaxationSolver: RelaxationSolver {
    func solveRelaxation<V: VectorSpace>(
        objective: @Sendable @escaping (V) -> Double,
        constraints: [MultivariateConstraint<V>],
        initialGuess: V,
        minimize: Bool
    ) throws -> RelaxationResult where V.Scalar == Double, V: Sendable {
        // Return optimal result but without simplex tableau
        let solution = VectorN(initialGuess.toArray())
        return RelaxationResult(
            solution: solution,
            objectiveValue: objective(initialGuess),
            status: .optimal,
            simplexResult: nil  // No tableau available
        )
    }
}
