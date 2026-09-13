//
//  CuttingPlaneStatisticsTests.swift
//  BusinessMathTests
//
//  The cut counters reported zero while cuts were being generated and applied.
//

import Testing
import Foundation
@testable import BusinessMath

/// `cuttingPlaneStats` has to describe the solve that happened.
///
/// Four of the five return paths in `solve` built the result with a freshly-constructed
/// `CuttingPlaneStats()` — an empty object — instead of the tracker that had been
/// accumulating. So a solve that generated cuts reported `totalCutsGenerated == 0`
/// whenever it returned through one of them, which is every solve that finishes at the
/// root.
///
/// The consequence was worse than a wrong number. The whole cut-validity suite asserts
/// against these counters, `Phase1_CutValidityTests` among them, and the assertions that
/// read them are of the form `stats.totalCutsGenerated >= 0` — true of an unsigned count
/// whatever happens. **Cutting planes worked the entire time; nothing could see it.**
///
/// Traced before the fix on `max 3x + 4y s.t. 2x + 3y <= 11`, both variables integer:
///
/// ```
/// cut loop entered, maxRounds=5
/// hasFractional=true  solution=[5.5, 0.0]      ← LP optimum, fractional
/// tableau=true basis=true
/// incremented -> 1                              ← a Gomory cut, generated and counted
/// hasFractional=false solution=[4.0, 1.0]      ← the cut made it integral at the root
/// result nodes=1 cuts=0                         ← and the count was thrown away
/// ```
@Suite("Cutting plane statistics")
struct CuttingPlaneStatisticsTests {

    /// A fixture whose LP relaxation is fractional, so a cut has something to do.
    ///
    /// `max 3x + 4y` subject to `2x + 3y <= 11` has LP optimum x = 5.5, y = 0 — the ratio
    /// 3/2 beats 4/3, so the solver loads x — and integer optimum 16 at (4, 1).
    private func fractionalProblem() throws -> IntegerOptimizationResult<VectorN<Double>> {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5
        )
        return try solver.solve(
            objective: { v in let a = v.toArray(); return 3 * a[0] + 4 * a[1] },
            from: VectorN([1.0, 1.0]),
            subjectTo: [.linearInequality(coefficients: [2.0, 3.0], rhs: 11.0, sense: .lessOrEqual)],
            integerSpec: IntegerProgramSpecification(integerVariables: Set([0, 1]), binaryVariables: []),
            minimize: false
        )
    }

    @Test("A solve that generates a cut reports it")
    func generatedCutsAreReported() throws {
        let result = try fractionalProblem()
        let stats = try #require(result.cuttingPlaneStats,
                                 "cutting planes were enabled, so there should be statistics")

        #expect(stats.totalCutsGenerated > 0,
                "the LP optimum is fractional at x = 5.5, so a cut has work to do; reported \(stats.totalCutsGenerated)")
        #expect(stats.gomoryCuts > 0, "reported \(stats.gomoryCuts) Gomory cuts")
        #expect(stats.cuttingRounds > 0, "reported \(stats.cuttingRounds) rounds")
    }

    /// The cut did its job: the root became integral, so nothing had to branch.
    ///
    /// This is the claim `cutsReduceTreeSize` is named for and does not make. Here it is
    /// exact rather than comparative — one node means the cut alone closed the problem.
    @Test("The cut closes the problem at the root")
    func cutSolvesAtTheRoot() throws {
        let result = try fractionalProblem()
        #expect(result.status == .optimal)
        #expect(result.integerSolution == [4, 1], "got \(result.integerSolution)")
        #expect(abs(result.objectiveValue - 16.0) < 1e-6, "got \(result.objectiveValue)")
        #expect(result.nodesExplored == 1,
                "the cut made the root integral, so no branching was needed; explored \(result.nodesExplored)")
    }

    /// With cuts disabled the same problem still solves, and reports no statistics.
    ///
    /// The control: it shows the counters above are reporting the cutting, not merely
    /// counting something that happens regardless.
    @Test("With cutting planes off there are no statistics and no cuts")
    func disabledMeansNoStatistics() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(enableCuttingPlanes: false)
        let result = try solver.solve(
            objective: { v in let a = v.toArray(); return 3 * a[0] + 4 * a[1] },
            from: VectorN([1.0, 1.0]),
            subjectTo: [.linearInequality(coefficients: [2.0, 3.0], rhs: 11.0, sense: .lessOrEqual)],
            integerSpec: IntegerProgramSpecification(integerVariables: Set([0, 1]), binaryVariables: []),
            minimize: false
        )
        #expect(result.cuttingPlaneStats == nil, "cuts were disabled; got statistics anyway")
        #expect(result.status == .optimal)
        #expect(result.integerSolution == [4, 1], "got \(result.integerSolution)")
    }
}
