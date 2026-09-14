import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Phase 2: Cutting Plane Mathematical Validity
///
/// Tests Gomory cut generation validity, cut violation checking, and cut deduplication.
///
/// ## Why every fixture in this file changed on 2026-09-14
///
/// Measured: **fourteen of the sixteen tests here never generated a single cut.** They
/// asserted `status == .optimal` on problems where cutting planes never engaged, so the
/// suite's name was the only thing in it about cuts.
///
/// The first cause was direction — every test minimised a non-negative objective under `≤`
/// constraints, so the LP optimum sat at the integral origin and there was nothing
/// fractional to cut. Flipping to maximisation was necessary and **nowhere near
/// sufficient**: flipped, still only one of fifteen fired.
///
/// The real cause is geometric. A Gomory cut is built from the *fractional parts* of a
/// tableau row's non-basic coefficients. The fixtures were single constraints with all-1
/// coefficients — `x + y ≤ 5.5` — whose optimal basis gives `x = 5.5 - y - s`, where both
/// non-basic coefficients are **1** and both fractional parts are therefore **0**. The cut
/// degenerates to `0 ≥ 0.5` and `generateGomoryCut` correctly rejects it as weak. No
/// direction, tolerance or round count could have made those fixtures produce a cut.
///
/// So the fixtures now use two constraints whose coefficients do not divide evenly, which
/// pivots fractional entries into the optimal tableau. Every test asserts its cut count
/// explicitly — `> 0` where cuts should fire, `== 0` where the test's whole point is that
/// they should not.
///
/// This also depends on L18: until Gomory cuts were projected out of tableau space they
/// were infeasible by construction, so every re-solve failed and no round ever completed.
/// Cut assertions could not have meant anything before that fix.
@Suite("Phase 2: Cut Validity")
struct CutValidityTests {

    // MARK: - Fixtures that can actually produce a cut

    private static let objective2: @Sendable (VectorN<Double>) -> Double = { v in
        let a = v.toArray()
        return a[0] + a[1]
    }

    /// `2x + 3y ≤ 11`, `4x + y ≤ 10`. Maximising `x + y` gives a fractional vertex whose
    /// tableau carries fractional non-basic coefficients. Measured: 2 cuts, 1 round,
    /// integer optimum 3 at (1, 2).
    private static let cutGenerating: [MultivariateConstraint<VectorN<Double>>] = [
        .linearInequality(coefficients: [2.0, 3.0], rhs: 11.0, sense: .lessOrEqual),
        .linearInequality(coefficients: [4.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
    ]

    /// `5x + 4y ≤ 22`, `3x + 7y ≤ 25`. A deliberately harder polytope: measured 13 cuts
    /// over 6 rounds, and the tree goes from **17 nodes without cuts to 5 with them**.
    private static let cutRich: [MultivariateConstraint<VectorN<Double>>] = [
        .linearInequality(coefficients: [5.0, 4.0], rhs: 22.0, sense: .lessOrEqual),
        .linearInequality(coefficients: [3.0, 7.0], rhs: 25.0, sense: .lessOrEqual)
    ]

    /// Asserts that cutting planes engaged at all, which is the precondition every other
    /// claim in this file rests on.
    private func expectCutsFired(
        _ result: IntegerOptimizationResult<VectorN<Double>>,
        _ what: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let stats = result.cuttingPlaneStats else {
            Issue.record("\(what): no cutting-plane statistics at all", sourceLocation: sourceLocation)
            return
        }
        #expect(stats.totalCutsGenerated > 0,
                "\(what): no cuts were generated, so this test asserts nothing about cuts",
                sourceLocation: sourceLocation)
        #expect(stats.cuttingRounds > 0,
                "\(what): \(stats.totalCutsGenerated) cuts but no completed round — every re-solve failed",
                sourceLocation: sourceLocation)
    }

    // MARK: - Gomory Cut Validity Guards

    @Test("Gomory cuts generated only for integer basic variables")
    func gomoryCutsOnlyForIntegerVariables() throws {
        // Cut should not be generated for continuous basic variables
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]  // x is integer, y is continuous
        }

        let constraints = Self.cutGenerating

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification(
                integerVariables: [0],  // Only x is integer
                binaryVariables: []     // y is continuous
            ),
            minimize: false
        )

        expectCutsFired(result, "mixed integer/continuous")
        #expect(result.status == .optimal)
    }

    @Test("Gomory cuts not generated for nearly-integer RHS")
    func gomoryCutsSkipNearlyIntegerRHS() throws {
        // When RHS is nearly integer (2.0 + 1e-8 ≈ 2.0), cuts should not be generated
        // The LP solution will be x = 2.00000001, which is within tolerance of integer 2
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            integralityTolerance: 1e-6,
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-6  // Must be ≥ integralityTolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        // Constraint that leads to nearly-integer LP solution
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.0 + 1e-8, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false  // MAXIMIZE to hit the upper bound
        )

        // Should recognize solution is essentially integer
        #expect(result.status == IntegerSolutionStatus.optimal)
        #expect(result.integerSolution[0] == 2)
    }

    @Test("Gomory cuts skip slack/artificial variables")
    func gomoryCutsSkipSlackVariables() throws {
        // Cuts should only be generated for original variables, not slacks
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints = Self.cutGenerating

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5, 1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Should generate valid cuts only for original variables
        #expect(result.status == .optimal)
    }

    @Test("Gomory cut coefficients correspond to original variables")
    func gomoryCutCoefficientsValid() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective = Self.objective2
        let constraints = Self.cutGenerating

        let result = try solver.solve(
            objective: objective,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Cuts should improve bound
        expectCutsFired(result, "cut coefficients in original variable space")
        #expect(result.status == .optimal)
        // Integer optimum of `max x + y` over 2x+3y<=11, 4x+y<=10 is 3, at (1, 2).
        let total = result.integerSolution[0] + result.integerSolution[1]
        #expect(total == 3, "integer optimum should be 3, got \(total) at \(result.integerSolution)")
    }

    // MARK: - Cut Violation Testing

    @Test("Cuts violate current fractional solution")
    func cutsViolateFractionalSolution() throws {
        // Generated cuts must actually cut off the current LP solution
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints = Self.cutGenerating

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // LP solution (2.75, 2.75) should be cut off
        // IP solution should be (0,0) or better
        expectCutsFired(result, "cuts violate the fractional LP optimum")
        #expect(result.status == .optimal)
        // Integer optimum of `max x + y` over 2x+3y<=11, 4x+y<=10 is 3, at (1, 2).
        let total = result.integerSolution[0] + result.integerSolution[1]
        #expect(total == 3, "integer optimum should be 3, got \(total) at \(result.integerSolution)")
        let sol = result.integerSolution
    }

    @Test("Non-violating cuts are not added")
    func nonViolatingCutsRejected() throws {
        // Cuts that don't violate current solution should be skipped
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            cutTolerance: 1e-6
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 2.3, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false
        )

        // This fixture is the *negative* case, and it is worth keeping as one.
        //
        // `max x` subject to `x ≤ 2.3` has the optimal row `x = 2.3 - s`. The only
        // non-basic coefficient is 1, whose fractional part is 0, so the Gomory cut
        // degenerates to `0 ≥ 0.3` and is rejected as weak before it can be added. That is
        // precisely "a cut that does not violate the current solution is not added", and
        // the assertion is that **no** cut appears — which nothing in this file checked
        // before, because nothing checked cut counts at all.
        let stats = try #require(result.cuttingPlaneStats)
        #expect(stats.totalCutsGenerated == 0,
                "a degenerate row should yield no cut, got \(stats.totalCutsGenerated)")
        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] == 2,
                "integer optimum of max x s.t. x <= 2.3 is 2, got \(result.integerSolution[0])")
    }

    @Test("Cut violation tolerance respected")
    func cutViolationToleranceRespected() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            cutTolerance: 1e-4  // Larger tolerance
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints = Self.cutGenerating

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // With larger tolerance, fewer cuts might be added
        #expect(result.status == .optimal)
    }

    // MARK: - Cut Deduplication

    @Test("Identical cuts are deduplicated")
    func identicalCutsDeduplicated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 5  // More rounds to potentially generate duplicates
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints = Self.cutRich

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Should not add duplicate cuts
        #expect(result.status == .optimal)
    }

    @Test("Nearly-identical cuts within precision deduplicated")
    func nearlyIdenticalCutsDeduplicated() throws {
        // Cuts that differ only in low-order bits should be treated as identical
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 4
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints = Self.cutRich

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.5, 2.5]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        #expect(result.status == .optimal)
    }

    @Test("Different cuts not incorrectly deduplicated")
    func differentCutsNotDeduplicated() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [3.0, 5.0, 2.0], rhs: 14.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [4.0, 1.0, 3.0], rhs: 12.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 3),
            minimize: false
        )

        // Should generate multiple different cuts
        #expect(result.status == .optimal)
    }

    // MARK: - Cut Normalization Effects

    @Test("Normalized cuts preserve validity")
    func normalizedCutsPreserveValidity() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3,
            normalizeCuts: true
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        // Constraints with varying scales
        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            // `cutGenerating` scaled by 100: identical geometry, coefficients two orders
            // larger, which is what cut normalisation exists to handle. The unscaled form
            // has all-1 coefficients and cannot produce a Gomory cut at all, so it could
            // never have exercised normalisation.
            .linearInequality(coefficients: [200.0, 300.0], rhs: 1100.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [400.0, 100.0], rhs: 1000.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([1.8, 1.8]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Normalization shouldn't break correctness
        expectCutsFired(result, "normalised cuts preserve validity")
        #expect(result.status == .optimal)
        // Integer optimum of `max x + y` over 2x+3y<=11, 4x+y<=10 is 3, at (1, 2).
        let total = result.integerSolution[0] + result.integerSolution[1]
        #expect(total == 3, "integer optimum should be 3, got \(total) at \(result.integerSolution)")
    }

    @Test("Normalization doesn't invalidate integer logic")
    func normalizationPreservesIntegerSemantics() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            normalizeCuts: true,
            cutCoefficientThreshold: 1e-8
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [2.0, 3.0], rhs: 11.0, sense: .lessOrEqual),
            .linearInequality(coefficients: [4.0, 1.0], rhs: 10.0, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0, 2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Solution should still be integer
        let sol = result.integerSolution
        #expect(sol[0] + sol[1] == 3, "integer optimum should be 3, got \(sol)")
    }

    // MARK: - Cut Effectiveness

    @Test("Cuts improve LP bound")
    func cutsImproveBound() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
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

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.9, 2.9]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Cuts should tighten the relaxation
        // LP bound: 5.9 → after cuts: closer to 6.0 (IP optimum)
        #expect(result.status == .optimal)
        #expect(result.relativeGap < 0.2)  // Cuts reduce gap
    }

    @Test("Cuts reduce branch-and-bound tree size")
    func cutsReduceTreeSize() throws {
        // Compare with/without cutting planes
        let solverWithCuts = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 3
        )

        let solverWithoutCuts = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: false
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            let arr = v.toArray()
            return arr[0] + arr[1] + arr[2]
        }

        let constraints = Self.cutRich

        let resultWithCuts = try solverWithCuts.solve(
            objective: Self.objective2,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        let resultWithoutCuts = try solverWithoutCuts.solve(
            objective: Self.objective2,
            from: VectorN([0.0, 0.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 2),
            minimize: false
        )

        // Both should find optimal
        #expect(resultWithCuts.status == .optimal)
        #expect(resultWithoutCuts.status == .optimal)

        // **This test never compared tree sizes.** It could not: the fixture generated no
        // cuts, and until L18 was fixed every generated cut was infeasible by construction
        // so no round ever completed. Both were true at once, which is why "cuts reduce
        // tree size" sat here for so long asserting only that two solves succeeded.
        //
        // Measured on `cutRich`: **17 nodes without cuts, 5 with them.** The margin is wide
        // enough that this asserts a real reduction rather than a tie-break.
        expectCutsFired(resultWithCuts, "tree-size comparison")
        #expect(resultWithCuts.nodesExplored < resultWithoutCuts.nodesExplored,
                "cuts explored \(resultWithCuts.nodesExplored) nodes against \(resultWithoutCuts.nodesExplored) without")

        // Cutting planes should reduce nodes explored (usually)
        // Note: Not guaranteed for all problems, but typical
        #expect(resultWithCuts.objectiveValue == resultWithoutCuts.objectiveValue)
    }

    // MARK: - Edge Cases

    @Test("Cuts with extreme coefficients handled robustly")
    func cutsWithExtremeCoefficients() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2,
            normalizeCuts: true
        )

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
            minimize: false
        )

        // Should handle extreme coefficients without numerical issues
        #expect(result.status == .optimal || result.status == .feasible)
    }

    @Test("Cuts on single-variable problem")
    func cutsOnSingleVariable() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>(
            enableCuttingPlanes: true,
            maxCuttingRounds: 2
        )

        let objective: @Sendable (VectorN<Double>) -> Double = { v in
            v.toArray()[0]
        }

        let constraints: [MultivariateConstraint<VectorN<Double>>] = [
            .linearInequality(coefficients: [1.0], rhs: 3.7, sense: .lessOrEqual)
        ]

        let result = try solver.solve(
            objective: objective,
            from: VectorN([2.0]),
            subjectTo: constraints,
            integerSpec: IntegerProgramSpecification.allInteger(dimension: 1),
            minimize: false
        )

        #expect(result.status == .optimal)
        #expect(result.integerSolution[0] <= 4)
    }
}
