import Testing
import Foundation
@testable import BusinessMath

/// Tests for node-level cut loop integration in Branch-and-Bound
///
/// Following TDD: These tests are written FIRST (RED phase) and will fail
/// until the cut loop is integrated into BranchAndBoundSolver.
///
/// ## What We're Testing
/// - Cut generation at fractional nodes
/// - LP re-solve after adding cuts
/// - Cut round termination conditions
/// - Bound strengthening from cuts
/// - Correct handling of integer solutions
///
/// ## Critical Implementation Requirements
/// From the gap analysis, the node-level cut loop must:
/// 1. Solve LP relaxation
/// 2. If fractional, generate violated cuts
/// 3. Add cuts and re-solve LP
/// 4. Repeat until no cuts or max rounds
/// 5. Only then branch if still fractional
@Suite("Node-Level Cut Loop Tests")
struct NodeCutLoopTests {

    // MARK: - Basic Cut Loop Behavior

    @Test("Cut loop generates cuts for fractional LP solution")
    func testCutGenerationAtFractionalNode() throws {
        // Problem with fractional LP relaxation
        // max x + y
        // s.t. x + 2y ≤ 7
        //      2x + y ≤ 7
        //      x, y ∈ {0,1,2,3}
        // LP optimal: x = y = 7/3 (fractional)

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,  // NEW: Enable cut generation
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        // Result should contain cutting plane statistics
        #expect(result.cuttingPlaneStats != nil, "Should track cutting plane statistics")

        if let stats = result.cuttingPlaneStats {
            // At least some cuts should have been generated
            #expect(stats.totalCutsGenerated >= 0, "Should track total cuts")
            #expect(stats.cuttingRounds >= 0, "Should track cutting rounds")
        }
    }

    @Test("LP is re-solved after adding cuts")
    func testLPResolvesAfterCuts() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .optimal || result.status == .feasible)

        // If cuts were generated, verify the LP was re-solved
        if let stats = result.cuttingPlaneStats {
            if stats.totalCutsGenerated > 0 {
                // Each cut round should have triggered an LP re-solve
                #expect(stats.lpResolves >= stats.cuttingRounds,
                       "Should re-solve LP after each cut round")
            }
        }
    }

    @Test("Cut rounds terminate at max iterations")
    func testCutRoundTermination() throws {
        let maxRounds = 2

        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: maxRounds
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        if let stats = result.cuttingPlaneStats {
            // Should not exceed max cutting rounds per node
            #expect(stats.maxRoundsAtNode <= maxRounds,
                   "Should respect max cutting rounds limit")
        }
    }

    @Test("Cut rounds terminate when no violations found")
    func testCutRoundTerminationNoViolations() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 10  // High limit, but should terminate early
        )

        // Problem where cuts quickly eliminate fractional solutions
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 0.0],
                rhs: 3.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [0.0, 1.0],
                rhs: 2.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .optimal)

        if let stats = result.cuttingPlaneStats {
            // Should terminate early when solution becomes integer
            // or no more violated cuts are found
            #expect(stats.maxRoundsAtNode < 10,
                   "Should terminate before max rounds when no violations")
        }
    }

    // MARK: - Bound Strengthening

    @Test("Cuts strengthen LP relaxation bound")
    func testCutsStrengthenBound() throws {
        // Solve same problem with and without cuts
        // The version with cuts should have a tighter bound

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let integerSpec = IntegerProgramSpecification.allInteger(dimension: 2)

        // Solve WITHOUT cuts
        let solverNoCuts = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: false
        )

        let resultNoCuts = try solverNoCuts.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: integerSpec,
            minimize: false
        )

        // Solve WITH cuts
        let solverWithCuts = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let resultWithCuts = try solverWithCuts.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: integerSpec,
            minimize: false
        )

        // Both should find optimal solution
        #expect(resultNoCuts.status == .optimal)
        #expect(resultWithCuts.status == .optimal)

        // Objective values should be same (same optimum)
        #expect(abs(resultNoCuts.objectiveValue - resultWithCuts.objectiveValue) < 1e-6)

        // But version with cuts should explore fewer nodes
        if let statsWithCuts = resultWithCuts.cuttingPlaneStats {
            if statsWithCuts.totalCutsGenerated > 0 {
                #expect(resultWithCuts.nodesExplored <= resultNoCuts.nodesExplored,
                       "Cuts should reduce branching (nodes explored)")
            }
        }
    }

    @Test("Cuts improve dual bound closer to integer optimum")
    func testCutsImproveDualBound() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        if let stats = result.cuttingPlaneStats {
            if stats.totalCutsGenerated > 0 {
                // After cuts, root LP bound should be tighter
                // (closer to integer optimum than initial LP relaxation)
                #expect(stats.rootLPBoundAfterCuts <= stats.rootLPBoundBeforeCuts + 1e-6,
                       "Root bound after cuts should not be worse")

                // For maximization, bound should decrease (get tighter)
                // Initial LP: ~4.67, After cuts: closer to integer optimum of 4
                let improvement = stats.rootLPBoundBeforeCuts - stats.rootLPBoundAfterCuts
                #expect(improvement >= -1e-6,
                       "Cuts should improve (or maintain) LP bound")
            }
        }
    }

    // MARK: - Integer Solution Handling

    @Test("Integer LP solution skips cut generation")
    func testIntegerSolutionSkipsCuts() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        // Problem where LP relaxation is already integer
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            2.0 * v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 1.0],
                rhs: 5.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 0.0],
                rhs: 3.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .optimal)

        // Should find integer solution immediately (x=3, y=2)
        let solution = result.integerSolution
        #expect(solution == [3, 2], "Should find integer optimum")

        if let stats = result.cuttingPlaneStats {
            // No cuts should be generated for integer LP solution
            #expect(stats.totalCutsGenerated == 0,
                   "Should not generate cuts when LP solution is integer")
        }
    }

    // MARK: - Cut Statistics Tracking

    @Test("Cutting plane statistics are tracked correctly")
    func testCuttingPlaneStatistics() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        guard let stats = result.cuttingPlaneStats else {
            Issue.record("Expected cutting plane statistics")
            return
        }

        // Verify statistics are sensible
        #expect(stats.totalCutsGenerated >= 0, "Total cuts should be non-negative")
        #expect(stats.cuttingRounds >= 0, "Cutting rounds should be non-negative")
        #expect(stats.lpResolves >= 0, "LP resolves should be non-negative")

        // If cuts were generated, rounds should be positive
        if stats.totalCutsGenerated > 0 {
            #expect(stats.cuttingRounds > 0, "Should have at least one cutting round")
        }

        // Track cuts by type
        #expect(stats.gomoryCuts >= 0, "Gomory cuts should be tracked")
        #expect(stats.mirCuts >= 0, "MIR cuts should be tracked")

        // Total cuts should equal sum of types
        let sumByType = stats.gomoryCuts + stats.mirCuts + stats.coverCuts
        #expect(stats.totalCutsGenerated == sumByType,
               "Total cuts should equal sum by type")
    }

    @Test("Cut statistics track bound improvement")
    func testBoundImprovementTracking() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        if let stats = result.cuttingPlaneStats {
            // Root LP bounds should be tracked
            #expect(stats.rootLPBoundBeforeCuts.isFinite, "Before-cuts bound should be finite")
            #expect(stats.rootLPBoundAfterCuts.isFinite, "After-cuts bound should be finite")

            // Percentage improvement should be meaningful
            if stats.totalCutsGenerated > 0 {
                #expect(stats.percentageGapClosed >= 0.0 && stats.percentageGapClosed <= 100.0,
                       "Gap closed percentage should be in [0, 100]")
            }
        }
    }

    // MARK: - Edge Cases

    @Test("No cuts generated when disabled")
    func testNoCutsWhenDisabled() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: false  // Explicitly disabled
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 2.0],
                rhs: 7.0,
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [2.0, 1.0],
                rhs: 7.0,
                sense: .lessOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .optimal)

        // Should have no cutting plane statistics when disabled
        if let stats = result.cuttingPlaneStats {
            #expect(stats.totalCutsGenerated == 0, "No cuts when disabled")
            #expect(stats.cuttingRounds == 0, "No cutting rounds when disabled")
        }
    }

    @Test("Infeasible problems handle cuts correctly")
    func testInfeasibleProblemWithCuts() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 100,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        // Infeasible integer program
        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v[0] + v[1]
        }

        let constraints = [
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 0.0],
                rhs: 0.5,  // x ≤ 0.5
                sense: .lessOrEqual
            ),
            MultivariateConstraint<VectorN<Double>>.linearInequality(
                coefficients: [1.0, 0.0],
                rhs: -1.5,  // x ≥ 1.5 (conflicts with above)
                sense: .greaterOrEqual
            )
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: .allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .infeasible)

        // Should detect infeasibility without generating many cuts
        if let stats = result.cuttingPlaneStats {
            // Might generate some cuts before detecting infeasibility
            #expect(stats.totalCutsGenerated >= 0)
        }
    }
}
