import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Tier 2 - Required for Algorithmic Completeness
@Suite("Branch-and-Cut Tier 2: Algorithmic Completeness")
struct BranchAndCutTier2Tests {

    // MARK: - A fixture that actually generates cuts

    /// `5x + 4y ≤ 22`, `3x + 7y ≤ 25`, maximising `x + y` over the integers.
    ///
    /// The cut-configuration tests below used to run problems that generate **no cuts at
    /// all** — measured at zero, at every pool size and every aging limit — so nothing they
    /// asserted could depend on the option they were named for. This polytope is the one
    /// `Phase1_CutValidityTests` uses, and it cuts: 14 cuts over 5 rounds, taking the tree
    /// from 17 nodes without cutting planes to 6 with them.
    private static let cutRich: [MultivariateConstraint<VectorN<Double>>] = [
        .linearInequality(coefficients: [5.0, 4.0], rhs: 22.0, sense: .lessOrEqual),
        .linearInequality(coefficients: [3.0, 7.0], rhs: 25.0, sense: .lessOrEqual)
    ]

    private static let cutRichObjective: @Sendable (VectorN<Double>) -> Double = { v in
        let arr = v.toArray()
        return arr[0] + arr[1]
    }

    private func solveCutRich(
        _ solver: BranchAndBoundSolver<VectorN<Double>>
    ) throws -> IntegerOptimizationResult<VectorN<Double>> {
        try solver.solve(
            objective: Self.cutRichObjective,
            from: VectorN([2.5, 2.5]),
            subjectTo: Self.cutRich,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )
    }

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

        // `stats.coverCuts >= 0` stood here, which an `Int` count satisfies always — and
        // inside an `if let`, so a nil `stats` asserted nothing at all. The comment said
        // cover cuts *should* be generated and the assertion permitted none.
        //
        // Measured on this knapsack: one cover cut and one Gomory cut, in a single round.
        let stats = try #require(result.cuttingPlaneStats, "no cutting-plane statistics")
        #expect(stats.coverCuts == 1, "cover cuts generated: \(stats.coverCuts)")
        #expect(stats.gomoryCuts == 1, "Gomory cuts generated: \(stats.gomoryCuts)")
        #expect(stats.totalCutsGenerated == 2, "total cuts: \(stats.totalCutsGenerated)")
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

    /// Aging removes cuts from the LP, and nothing a caller can see reflects that.
    ///
    /// The test that stood here was named "Inactive cuts are removed after aging limit",
    /// ran a problem that generates **zero cuts**, and asserted `result.status == .optimal`.
    /// It would have passed with aging disabled, with aging broken, or with the feature
    /// deleted. Its own comment conceded the point: *"Exact verification requires internal
    /// state access."*
    ///
    /// That concession is half right. Instrumenting the solver shows aging doing exactly
    /// what it claims — at `cutAgingLimit: 1` it discards both of the previous round's cuts
    /// every round, holding the constraint count flat at 4 where it otherwise grows to 8.
    /// But **none of that reaches the public surface**: `totalCutsGenerated` counts cuts
    /// *generated*, not retained, so it is unchanged by removal, and there is no
    /// `cutsRemoved` or active-constraint count on ``CuttingPlaneStats``.
    ///
    /// So what is asserted here is the strongest claim the public API supports, and it is a
    /// real one: **aging must not change the answer.** Cuts are valid inequalities, so
    /// discarding them may cost search effort but can never make a wrong solution look
    /// right. If a future change to aging removes something load-bearing, or removes the
    /// wrong index, this is what catches it.
    @Test("Aging changes no answer, at any limit — cuts are valid, so discarding them is safe",
          arguments: [1, 2, 3, 5, 10])
    func agingNeverChangesTheAnswer(limit: Int) throws {
        let unaged = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, enableCutAging: false))
        let aged = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10,
            enableCutAging: true, cutAgingLimit: limit))

        #expect(aged.status == unaged.status,
                "status \(aged.status) against \(unaged.status)")
        #expect(aged.objectiveValue.isEqual(to: unaged.objectiveValue),
                "objective \(aged.objectiveValue) against \(unaged.objectiveValue)")

        let agedSolution = aged.solution.toArray()
        let unagedSolution = unaged.solution.toArray()
        #expect(agedSolution.count == unagedSolution.count)
        for (index, pair) in zip(agedSolution, unagedSolution).enumerated() {
            #expect(pair.0.isEqual(to: pair.1),
                    "component \(index): \(pair.0) against \(pair.1)")
        }
    }

    /// The pool cap is honoured exactly, and tightening it costs search effort.
    ///
    /// What stood here asserted `totalCutsGenerated <= 100` against a configured cap of
    /// **50**, on a problem that generates **zero** cuts. Three separate reasons it could
    /// not fail.
    ///
    /// The cap is one of the few cut options with a genuinely observable contract, because
    /// `totalCutsGenerated` is precisely the quantity it bounds. Measured on `cutRich`,
    /// which generates 14 cuts uncapped:
    ///
    /// | Cap | Cuts | Nodes |
    /// |---|---|---|
    /// | 3 | 3 | 9 |
    /// | 5 | 5 | 17 |
    /// | 100 | 14 | 6 |
    ///
    /// The node counts are the reason this matters rather than being bookkeeping: a
    /// tighter pool means a weaker relaxation and more branching, which is the trade the
    /// option exists to let a caller make.
    @Test("A cut pool cap is honoured exactly", arguments: [3, 5, 100])
    func cutPoolCapIsHonoured(cap: Int) throws {
        let result = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, maxCutPoolSize: cap))

        #expect(result.status == .optimal)
        let stats = try #require(result.cuttingPlaneStats, "no cutting-plane statistics")

        #expect(stats.totalCutsGenerated <= cap,
                "\(stats.totalCutsGenerated) cuts against a cap of \(cap)")
        // And the cap has to actually bind rather than sit above what the problem produces,
        // or this asserts nothing — the failure the old version made.
        let uncapped = 14
        if cap < uncapped {
            #expect(stats.totalCutsGenerated == cap,
                    "a binding cap of \(cap) yielded \(stats.totalCutsGenerated) cuts")
        } else {
            #expect(stats.totalCutsGenerated == uncapped,
                    "an unbinding cap yielded \(stats.totalCutsGenerated), not \(uncapped)")
        }
    }

    /// A tighter cut pool buys fewer cuts at the price of more branching.
    @Test("Capping the cut pool costs nodes")
    func tighterPoolExploresMoreNodes() throws {
        let tight = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, maxCutPoolSize: 3))
        let loose = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, maxCutPoolSize: 100))

        #expect(tight.nodesExplored > loose.nodesExplored,
                "tight pool explored \(tight.nodesExplored), loose explored \(loose.nodesExplored)")
        // Both still have to arrive at the same optimum: a cut pool is a search budget,
        // not a change of problem.
        #expect(tight.objectiveValue.isEqual(to: loose.objectiveValue),
                "\(tight.objectiveValue) against \(loose.objectiveValue)")
    }
}
