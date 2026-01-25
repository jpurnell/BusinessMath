import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 1.2: LP Status Handling (Infeasible vs Unbounded)
///
/// Tests proper handling of different LP relaxation statuses:
/// - Infeasible LP → Infeasible IP (prune node)
/// - Unbounded LP → May have bounded IP (continue branching with safeguards)
/// - Numerical failure → Graceful handling
@Suite("Phase 1.2: LP Status Handling")
struct LPStatusHandlingTests {

    // MARK: - Infeasible LP Tests

    @Test("Infeasible LP relaxation implies infeasible integer program")
    func infeasibleLPImpliesInfeasibleIP() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Contradictory constraints: x ≤ 1 and x ≥ 2
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 1.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0], rhs: -2.0, sense: .lessOrEqual)  // x ≥ 2
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        // Should detect infeasibility
        #expect(result.status == .infeasible)
    }

    @Test("Infeasible LP at root node terminates immediately")
    func infeasibleRootNode() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Impossible constraints
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 5.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, -1.0], rhs: -10.0, sense: .lessOrEqual)  // x+y ≥ 10
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([3.0, 3.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        #expect(result.status == .infeasible)
        // Should explore minimal nodes (just root)
        #expect(result.nodesExplored <= 2)
    }

    @Test("Infeasible LP in subtree prunes correctly")
    func infeasibleSubtreePruning() throws {
        // Problem that becomes infeasible after branching
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Feasible at root, but may become infeasible with integer constraints
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0], rhs: 1.5, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, 0.0], rhs: -0.8, sense: .lessOrEqual),  // x ≥ 0.8
            .linearInequality(coefficients: [0.0, -1.0], rhs: -0.8, sense: .lessOrEqual)   // y ≥ 0.8
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.75, 0.75]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // LP is feasible (x=y=0.75), but IP is infeasible
        // (need x,y ≥ 1 to be integer, but x+y ≤ 1.5)
        #expect(result.status == .infeasible)
    }

    // MARK: - Unbounded LP Tests

    @Test("Unbounded LP with integer constraints may be bounded")
    func unboundedLPBoundedIP() throws {
        // This test requires careful construction
        // LP: maximize x (unbounded)
        // IP: maximize x where x ≤ y and y ∈ {0,1} → x ≤ 1

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]  // Maximize x
        }

        // x ≤ y, and y is binary
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, -1.0], rhs: 0.0, sense: .lessOrEqual),  // x ≤ y
            .linearInequality(coefficients: [0.0, 1.0], rhs: 1.0, sense: .lessOrEqual),   // y ≤ 1
            .linearInequality(coefficients: [0.0, -1.0], rhs: 0.0, sense: .lessOrEqual)   // y ≥ 0
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.5, 0.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [0],
                binaryVariables: [1]
            ),
            minimize: false  // Maximization
        )

        // LP is unbounded in x (given any y, x can grow)
        // But IP is bounded: x ≤ y and y ∈ {0,1} → x ≤ 1
        // Solver should handle this gracefully
        #expect(result.status == .optimal || result.status == .feasible)

        if result.status == .optimal {
            // Should find x=1, y=1
            let sol = result.integerSolution
            #expect(sol[0] <= 1)
            #expect(sol[1] <= 1)
        }
    }

    @Test("Unbounded LP uses safe finite bound")
    func unboundedLPSafeBound() throws {
        // When LP is unbounded, solver should use a large but finite bound
        // rather than -∞ or +∞

        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Unbounded: x can grow without limit, but x must be integer
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [-1.0], rhs: 0.0, sense: .lessOrEqual)  // x ≥ 0
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([10.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false  // Maximize unbounded variable
        )

        // Solver should either:
        // 1. Detect unboundedness and report it
        // 2. Hit node/time limit with feasible solution

        // bestBound should be finite, not infinite
        #expect(!result.bestBound.isInfinite)
    }

    // MARK: - Status Propagation Tests

    @Test("LP status correctly propagates to result")
    func statusPropagation() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Feasible problem
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

        // Should successfully solve
        #expect(result.status == .optimal || result.status == .feasible)
    }

    @Test("Multiple infeasible branches prune correctly")
    func multipleInfeasibleBranches() throws {
        // Problem where many branches become infeasible
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        // Tight constraints that become infeasible when branching
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 2.1, sense: .lessOrEqual),
            .linearInequality(coefficients: [-1.0, -1.0, -1.0], rhs: -1.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.65, 0.65, 0.65]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        // Should handle multiple infeasible branches efficiently
        // (May be infeasible or find solution)
        #expect(result.status == .infeasible || result.status == .optimal)
    }

    // MARK: - Numerical Failure Handling

    @Test("Numerical failure in LP handled gracefully")
    func numericalFailureHandling() throws {
        // This test is placeholder - actual numerical failure requires
        // extremely ill-conditioned problems or solver-specific issues

        // For now, verify that solver doesn't crash on difficult problems
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return 1e-10 * arr[0] + 1e10 * arr[1]
        }

        // Ill-conditioned constraint
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1e-10, 1e10], rhs: 1.5e10, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0, 1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: true
        )

        // Should not crash - any valid status is acceptable
        #expect([.optimal, .feasible, .infeasible, .nodeLimit, .timeLimit].contains(result.status))
    }

    // MARK: - Status vs Solution Consistency

    @Test("Optimal status guarantees solution exists")
    func optimalStatusHasSolution() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: true
        )

        if result.status == .optimal {
            // Optimal status must have valid solution
            let sol = result.integerSolution
            #expect(sol.count > 0)
            #expect(sol[0] >= 0)
            #expect(sol[0] <= 3)
        }
    }

    @Test("Infeasible status has no valid incumbent")
    func infeasibleStatusNoSolution() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>()

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Infeasible constraints
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

        #expect(result.status == .infeasible)
        // Objective value should indicate no solution found
        // (Implementation-dependent: might be infinity or initial value)
    }

    @Test("Feasible status has valid solution but not proven optimal")
    func feasibleStatusHasSolution() throws {
        // Hit node limit to get feasible but not optimal
        let solver = BranchAndBoundSolver<VectorN<Double>>(maxNodes: 5)

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0, 1.0, 1.0], rhs: 5.9, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: true
        )

        if result.status == .nodeLimit || result.status == .feasible {
            // Should have found some integer solution
            let sol = result.integerSolution
            #expect(sol.reduce(0, +) <= 6)
        }
    }
}
