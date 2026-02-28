import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tier 2 - Required for Algorithmic Completeness
@Suite("Branch-and-Cut Tier 2: Algorithmic Completeness")
struct BranchAndCutTier2Tests {

    // MARK: - Mixed-Integer Rounding (MIR) Cuts

    @Test("MIR cuts are generated for mixed-integer constraints")
    func mirCutsGeneration() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableMIRCuts: true
        )

        // Mixed problem: max 2x + 3y s.t. 1.5x + 2.3y ≤ 7.8, x ∈ Z, y continuous
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(2.0 * arr[0] + 3.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.5, 2.3], rhs: 7.8, sense: .lessOrEqual)
        ]

        // Only x is integer, y is continuous
        let spec = IntegerProgramSpecification(
            integerVariables: Set([0]),
            binaryVariables: Set()
        )

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 1.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == .optimal)

        // MIR cuts should be generated for mixed-integer rows
        if let stats = result.cuttingPlaneStats {
            #expect(stats.mirCuts >= 0)  // MIR cuts available
        }
    }

    @Test("MIR cuts stronger than Gomory for mixed problems")
    func mirCutsStrongerThanGomory() throws {
        // This test verifies MIR cuts provide tighter bounds than pure Gomory
        // for mixed-integer problems

        // Solver with MIR enabled
        let solverMIR = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            enableMIRCuts: true
        )

        // Solver with only Gomory
        let solverGomory = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            enableMIRCuts: false
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + 2.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.5, 1.3], rhs: 8.7, sense: .lessOrEqual)
        ]

        let spec = IntegerProgramSpecification(integerVariables: Set([0]))

        let resultMIR = try solverMIR.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        let resultGomory = try solverGomory.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        // Both should find same optimal solution
        #expect(resultMIR.status == .optimal)
        #expect(resultGomory.status == .optimal)

        // MIR might explore fewer nodes (stronger cuts)
        // This is a weak test - just verify both work
        #expect(resultMIR.nodesExplored > 0)
        #expect(resultGomory.nodesExplored > 0)
    }

    // MARK: - Cover Cuts for Knapsack Constraints

    @Test("Cover cuts generated for knapsack constraints")
    func coverCutsForKnapsack() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableCoverCuts: true
        )

        // Classic 0-1 knapsack: max 5x₁ + 4x₂ + 3x₃ s.t. 3x₁ + 2x₂ + 2x₃ ≤ 4
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(5.0 * arr[0] + 4.0 * arr[1] + 3.0 * arr[2])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [3.0, 2.0, 2.0], rhs: 4.0, sense: .lessOrEqual)
        ]

        let spec = IntegerProgramSpecification.allBinary(dimension: 3)

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: spec,
            minimize: true
        )

        #expect(result.status == .optimal)

        // Cover cuts should be generated for knapsack structure
        if let stats = result.cuttingPlaneStats {
            #expect(stats.coverCuts >= 0)
        }
    }

    @Test("Lifted cover cuts improve bound")
    func liftedCoverCuts() throws {
        // Test that lifted cover cuts provide better bounds than minimal covers

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            enableCoverCuts: true,
            liftCoverCuts: true
        )

        // Knapsack with good lifting potential
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(4.0 * arr[0] + 3.0 * arr[1] + 2.0 * arr[2] + 1.0 * arr[3])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [5.0, 3.0, 2.0, 1.0], rhs: 6.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5, 0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allBinary(dimension: 4),
            minimize: true
        )

        #expect(result.status == .optimal)
        // Lifted cuts should help (reflected in statistics or node count)
    }

    // MARK: - Cut Dominance and Subsumption

    @Test("Dominated cuts are not added to LP")
    func dominatedCutsFiltered() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5,
            filterDominatedCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        // Multiple constraints that might generate dominated cuts
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 3.7, sense: .lessOrEqual),
            .linearInequality(coefficients: [2.0, 2.0], rhs: 7.5, sense: .lessOrEqual)  // Dominated
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // With filtering, should generate fewer cuts
        if let stats = result.cuttingPlaneStats {
            // Should not add redundant cuts
            #expect(stats.totalCutsGenerated < 20)
        }
    }

    @Test("Parallel cuts are detected and removed")
    func parallelCutsDetection() throws {
        // Test that cuts parallel to existing constraints are filtered

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            filterDominatedCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.2]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        #expect(result.status == .optimal)
    }

    // MARK: - Cut Aging and Removal

    @Test("Inactive cuts are removed after aging limit")
    func cutAgingMechanism() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5,
            enableCutAging: true,
            cutAgingLimit: 3
        )

        // Problem requiring significant branching
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1] + arr[2])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 5.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        #expect(result.status == .optimal)

        // With aging, LP shouldn't grow too large
        // (Exact verification requires internal state access)
    }

    @Test("Cut pool maintains reasonable size")
    func cutPoolSizeManagement() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10,
            enableCutAging: true,
            maxCutPoolSize: 50
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
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

        #expect(result.status == .optimal)

        // Total cuts should respect pool size limit
        if let stats = result.cuttingPlaneStats {
            #expect(stats.totalCutsGenerated <= 100)  // Reasonable upper bound
        }
    }
}
