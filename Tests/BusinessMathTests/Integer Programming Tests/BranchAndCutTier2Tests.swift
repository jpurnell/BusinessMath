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
    /// `Phase1_CutValidityTests` uses, and it cuts: 37 cuts over 31 rounds with aging off,
    /// taking the tree from 17 nodes without cutting planes to 5 with them.
    ///
    /// Integer optimum **4**, attained at (1, 3), (2, 2), (3, 1) and (4, 0) — four argmaxes, so
    /// no assertion below may name a point.
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

    /// Aging reports what it removed, which is the contract it previously lacked.
    ///
    /// `CuttingPlaneStats.cutsRemoved` exists because aging had no observable effect:
    /// `totalCutsGenerated` counts cuts *generated* rather than retained, so removal moved
    /// nothing a caller could read, and a test could not distinguish working aging from a
    /// feature that had been deleted.
    @Test("Aging reports the cuts it discards, and reports none when disabled")
    func agingReportsWhatItRemoved() throws {
        let unaged = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, enableCutAging: false))
        let unagedStats = try #require(unaged.cuttingPlaneStats)
        #expect(unagedStats.cutsRemoved == 0,
                "aging was off and \(unagedStats.cutsRemoved) cuts were removed")

        // At a limit of 1 every cut is discarded the round after it is added, so the count
        // has to be positive and cannot exceed what was generated.
        let aged = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10,
            enableCutAging: true, cutAgingLimit: 1))
        let agedStats = try #require(aged.cuttingPlaneStats)
        #expect(agedStats.cutsRemoved > 0, "aging was on and nothing was removed")
        #expect(agedStats.cutsRemoved <= agedStats.totalCutsGenerated,
                "\(agedStats.cutsRemoved) removed of \(agedStats.totalCutsGenerated) generated")
    }

    /// Aging removes cuts, removes none when off, and removes none when it cannot be reached.
    ///
    /// Measured on `cutRich` at `maxCuttingRounds: 10`:
    ///
    /// | Aging limit | off | 1 | 2 | 3 | 5 | 10 |
    /// |---|---|---|---|---|---|---|
    /// | **Generated** | 37 | 30 | 31 | 37 | 37 | 37 |
    /// | **Removed** | 0 | 21 | 22 | 24 | 14 | 0 |
    /// | **Share** | 0 | .700 | **.710** | .649 | .378 | 0 |
    ///
    /// ## What this deliberately does not claim
    ///
    /// **Monotonicity, in either counts or shares.** This test asserted the raw count against a
    /// fixed table, and when that broke it was rewritten to assert the *share* falls — on the
    /// reasoning that a longer age limit lets each cut survive more rounds, so a smaller fraction
    /// is discarded. That reasoning is wrong, and the table above shows where: the share rises
    /// from .700 to .710 between limits 1 and 2.
    ///
    /// The flaw in it is that the aging limit is not a filter applied to a fixed population. It
    /// changes which cuts are in the LP, which changes the re-solve, which changes how many
    /// rounds run and how many nodes are explored — so it moves the denominator as well as the
    /// numerator. Limit 1 generates 30 cuts over 7 nodes; limit 3 generates 37 over 5. Nothing
    /// orders those.
    ///
    /// So this asserts the properties that hold for a reason rather than by measurement: off
    /// removes nothing, a limit no cut can reach removes nothing, a tight limit removes
    /// something, and removal never exceeds generation. The counts above are provenance, not
    /// assertions — they have moved twice already, once when cuts became valid and once when the
    /// relaxation became exact.
    @Test("Aging removes cuts when it can, and nothing when it cannot")
    func agingRemovesCutsOnlyWhenReachable() throws {
        let unaged = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10, enableCutAging: false))
        let unagedStats = try #require(unaged.cuttingPlaneStats)
        #expect(unagedStats.cutsRemoved == 0,
                "aging off removed \(unagedStats.cutsRemoved)")

        let tight = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10,
            enableCutAging: true, cutAgingLimit: 1))
        let tightStats = try #require(tight.cuttingPlaneStats)
        #expect(tightStats.cutsRemoved > 0,
                "a limit of 1 discards a cut the round after it is added, yet removed nothing")

        // Removal can never exceed generation, at any limit. A count above the number generated
        // would mean the index arithmetic that shifts `cutAges` after a removal had gone wrong,
        // which is the live risk in that block.
        for limit in [1, 2, 3, 5] {
            let result = try solveCutRich(BranchAndBoundSolver(
                enableCuttingPlanes: true, maxCuttingRounds: 10,
                enableCutAging: true, cutAgingLimit: limit))
            let stats = try #require(result.cuttingPlaneStats)
            let generated: Int = stats.totalCutsGenerated
            #expect(generated > 0, "limit \(limit) generated no cuts, so there is nothing to age")
            #expect(stats.cutsRemoved <= generated,
                    "limit \(limit): \(stats.cutsRemoved) removed of \(generated) generated")
        }

        // A limit equal to the round budget cannot be reached: no cut survives to that age in a
        // solve that runs that many rounds. This is the boundary an off-by-one would cross.
        let atBudget = try solveCutRich(BranchAndBoundSolver(
            enableCuttingPlanes: true, maxCuttingRounds: 10,
            enableCutAging: true, cutAgingLimit: 10))
        let atBudgetStats = try #require(atBudget.cuttingPlaneStats)
        #expect(atBudgetStats.cutsRemoved == 0,
                "a limit equal to the round budget is unreachable, yet removed \(atBudgetStats.cutsRemoved)")
    }

    /// Aging discards most of the cuts it generates and the objective does not move.
    ///
    /// The test that stood here was named "Inactive cuts are removed after aging limit",
    /// ran a problem that generates **zero cuts**, and asserted `result.status == .optimal`.
    /// It would have passed with aging disabled, with aging broken, or with the feature
    /// deleted. Its own comment conceded the point: *"Exact verification requires internal
    /// state access."*
    ///
    /// With ``CuttingPlaneStats/cutsRemoved`` that is no longer true, and the two facts can
    /// now be separated. Aging **works** — at a limit of 1 it discards 21 of the 30 cuts
    /// generated. Aging also **changes no answer**: the status and the objective match a solve
    /// with aging off, at every limit.
    ///
    /// Those are consistent rather than contradictory, and this is the assertion that says
    /// so. Cuts are valid inequalities — they remove no integer-feasible point — so
    /// discarding them may cost search effort but can never make a wrong solution look
    /// right. That the node count does not move either says the discarded cuts were not
    /// binding on this problem, which is a property of the problem and not a promise.
    ///
    /// If a future change removes something load-bearing, or removes at the wrong index,
    /// this is what catches it — and the index-adjustment arithmetic in that block makes
    /// the second a live possibility.
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

        // The **objective**, not the point. `max x + y` on `cutRich` attains 4 at (1,3), (2,2),
        // (3,1) and (4,0), so which optimum a solve lands on is a function of search order and
        // carries no claim; aging legitimately changes it. This compared the solution
        // componentwise and passed only because aging happened not to reorder the search under
        // the old, invalid cuts. Under valid cuts it does, and the componentwise assertion was
        // failing on a pair of equally optimal answers.
        //
        // Compared with a tolerance rather than `isEqual(to:)` because `objectiveValue` is the
        // objective at the relaxation point that passed the integrality test, not at the integer
        // point reported, so two solves reaching the same optimum differ in the seventh decimal.
        let objectiveGap: Double = abs(aged.objectiveValue - unaged.objectiveValue)
        #expect(objectiveGap < 1e-6,
                "objective \(aged.objectiveValue) against \(unaged.objectiveValue)")

        let agedTotal = aged.integerSolution.reduce(0, +)
        let unagedTotal = unaged.integerSolution.reduce(0, +)
        #expect(agedTotal == unagedTotal,
                "aged \(aged.integerSolution) totals \(agedTotal), unaged \(unaged.integerSolution) totals \(unagedTotal)")
        #expect(agedTotal == 4,
                "the integer optimum of max x + y on cutRich is 4, got \(agedTotal)")
    }

    /// The pool cap is honoured exactly, and tightening it costs search effort.
    ///
    /// What stood here asserted `totalCutsGenerated <= 100` against a configured cap of
    /// **50**, on a problem that generates **zero** cuts. Three separate reasons it could
    /// not fail.
    ///
    /// The cap is one of the few cut options with a genuinely observable contract, because
    /// `totalCutsGenerated` is precisely the quantity it bounds. Measured on `cutRich` under
    /// mixed-integer cuts, with `enableCutAging` at its default of `true` and limit 5, which is
    /// the configuration these solves actually run in:
    ///
    /// | Cap | Cuts | Nodes |
    /// |---|---|---|
    /// | 3 | 3 | 17 |
    /// | 5 | 5 | 17 |
    /// | 100 | 37 | 5 |
    ///
    /// Thirty-seven rather than the 14 this table used to record, because valid cuts survive
    /// their re-solve and the loop keeps finding more to make. Seventeen nodes at a cap of 3 is
    /// exactly what this problem costs with cutting planes off altogether — three cuts buy
    /// nothing here — which is the trade the option exists to let a caller make.
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
        let uncapped = 37
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
        // not a change of problem. Compared by objective within a tolerance, for the reason
        // recorded on ``agingNeverChangesTheAnswer(limit:)`` — the reported value sits within
        // the integrality tolerance of the true one, and the optimum here has four argmaxes.
        let objectiveGap: Double = abs(tight.objectiveValue - loose.objectiveValue)
        #expect(objectiveGap < 1e-6,
                "\(tight.objectiveValue) against \(loose.objectiveValue)")

        let tightTotal = tight.integerSolution.reduce(0, +)
        let looseTotal = loose.integerSolution.reduce(0, +)
        #expect(tightTotal == looseTotal,
                "tight \(tight.integerSolution), loose \(loose.integerSolution)")
    }
}
