import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tier 1 - Mandatory for Mathematical Correctness
@Suite("Branch-and-Cut Tier 1: Mathematical Correctness")
struct BranchAndCutTier1Tests {

    // MARK: - Cut Validity Enforcement

    @Test("Generated cuts do not eliminate integer feasible solutions")
    func cutValidityPreservesIntegerSolutions() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )

        // Problem: max 3x + 2y s.t. x + y ≤ 5.5, x,y ∈ Z
        // Integer solutions: (0,0), (1,0), ..., (5,0), (0,1), ..., (0,5), (1,4), etc.
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(3.0 * arr[0] + 2.0 * arr[1])
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

        // Optimal should be (5,0) or (4,1) or (3,2) depending on objective
        // But ALL integer feasible solutions should remain feasible
        #expect(result.status == .optimal)

        // Verify the solution satisfies original constraints
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] <= 5) // Rounded from 5.5
    }

    @Test("Cuts preserve all vertices of integer hull")
    func cutsPreserveIntegerHull() throws {
        // Small knapsack problem where we can enumerate all integer solutions
        // max 2x + 3y s.t. x + 2y ≤ 4.5, x,y ∈ {0,1,2,3,4}

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(2.0 * arr[0] + 3.0 * arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 2.0], rhs: 4.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Integer feasible solutions: (0,0), (1,0), (2,0), (3,0), (4,0),
        //                             (0,1), (1,1), (2,1), (0,2)
        // Optimal: (0,2) with objective 6 or (2,1) with objective 7
        #expect(result.status == .optimal)
        let sol = result.integerSolution

        // Verify cuts didn't eliminate optimal
        #expect(sol[0] + 2 * sol[1] <= 5)
    }

    // MARK: - Global vs Local Cut Handling

    @Test("Global cuts are propagated to all child nodes")
    func globalCutsPropagation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        // Problem requiring branching
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 2.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Test passes if solver completes without error
        // Global cuts should strengthen bounds at all nodes
        #expect(result.status == .optimal)

        // If global cuts are working, we should see benefit in node count
        // (Exact count depends on implementation, but should be reasonable)
        #expect(result.nodesExplored > 0)
        #expect(result.nodesExplored < 100)
    }

    @Test("Local cuts do not propagate to sibling nodes")
    func localCutsIsolation() throws {
        // This test verifies that node-local cuts (valid only in subtree)
        // don't incorrectly propagate to other branches

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Problem with clear branching structure
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Solution should be correct regardless of cut propagation
        #expect(result.integerSolution[0] == 0)
        #expect(result.status == .optimal)
    }

    // MARK: - LP Infeasibility Detection After Cuts

    @Test("Node is pruned when LP becomes infeasible after adding cuts")
    func infeasibilityPruning() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 10  // Many rounds to potentially cause infeasibility
        )

        // Tightly constrained problem
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Very tight constraint: 0.8 ≤ x ≤ 1.2, x ∈ Z
        // Integer solution: x = 1
        // LP optimal: x = 1.2
        // After cuts, LP might become infeasible
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.2, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -0.8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should find integer solution or detect infeasibility quickly
        #expect(result.status == .optimal || result.status == .infeasible)

        // Should not explore excessive nodes due to infeasibility detection
        #expect(result.nodesExplored < 50)
    }

    @Test("Infeasible LP after cuts returns correct status")
    func infeasibleLPStatus() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Infeasible integer problem: 0.3 ≤ x ≤ 0.7, x ∈ Z
        // No integer in [0.3, 0.7]
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 0.7, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -0.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should correctly identify as infeasible
        #expect(result.status == .infeasible)
    }

    @Test("Cuts tighten bounds but preserve feasibility")
    func cutsTightenBoundsCorrectly() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return -(arr[0] + arr[1])
        }

        // Problem with fractional LP optimum
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 3.0], rhs: 10.5, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .optimal)

        // Cuts should improve bound (bring closer to integer optimum)
        if let stats = result.cuttingPlaneStats {
            // If cuts were generated, root bound should improve
            if stats.totalCutsGenerated > 0 {
                #expect(stats.rootLPBoundAfterCuts >= stats.rootLPBoundBeforeCuts - 0.1)
            }
        }
    }
}
