import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
import Foundation
@testable import BusinessMath

/// Tests for the named MINLP entry point, ``BranchAndBoundSolver/minlp(...)``.
///
/// The capability being named here is not new: branch-and-bound over a nonlinear
/// relaxation has always been available as
/// `BranchAndBoundSolver(relaxationSolver: NonlinearRelaxationSolver())`. What was
/// missing was a name for it, so nobody reading the API could tell that MINLP was
/// in the box.
///
/// That makes faithfulness the whole contract. These tests assert that the factory
/// is the *same solver* as the explicit composition — same configuration, and
/// bit-for-bit the same answer on a problem with both a nonlinear objective and a
/// nonlinear constraint — so the alias cannot quietly drift into a second, subtly
/// different solver.
@Suite("MINLP Entry Point")
struct MINLPEntryPointTests {

    // MARK: - Fixtures

    /// minimize x² + y² − 4x − 4y over the disc x² + y² ≤ 9, with x, y integer.
    ///
    /// Both the objective and the binding constraint are nonlinear, so a simplex
    /// relaxation cannot express this problem at all — it is genuinely MINLP, not a
    /// MILP with decoration.
    private static let objective: @Sendable (VectorN<Double>) -> Double = { v in
        let quadratic = v[0] * v[0] + v[1] * v[1]
        let linear = 4.0 * v[0] + 4.0 * v[1]
        return quadratic - linear
    }

    private static var constraints: [MultivariateConstraint<VectorN<Double>>] {
        [
            .inequality(
                function: { v in v[0] * v[0] + v[1] * v[1] - 9.0 },
                gradient: nil
            )
        ] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2)
    }

    private static let initialGuess = VectorN<Double>([1.0, 1.0])

    // MARK: - Faithfulness

    @Test("minlp() is the same solver as the explicit NonlinearRelaxationSolver composition")
    func minlpMatchesExplicitComposition() throws {
        let named = BranchAndBoundSolver<VectorN<Double>>.minlp(maxNodes: 500)
        let explicit = BranchAndBoundSolver<VectorN<Double>>(
            maxNodes: 500,
            relaxationSolver: NonlinearRelaxationSolver()
        )

        let namedResult = try named.solve(
            objective: Self.objective,
            from: Self.initialGuess,
            subjectTo: Self.constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        let explicitResult = try explicit.solve(
            objective: Self.objective,
            from: Self.initialGuess,
            subjectTo: Self.constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        // Bit-for-bit, not approximately: the two solvers run the same deterministic
        // program over the same inputs, so any difference at all is a difference in
        // configuration, and that is exactly what this test exists to catch.
        #expect(namedResult.status == explicitResult.status,
                "status \(namedResult.status) vs \(explicitResult.status)")
        #expect(identical(namedResult.solution.toArray(), explicitResult.solution.toArray()),
                "solution \(namedResult.solution.toArray()) vs \(explicitResult.solution.toArray())")
        #expect(identical(namedResult.objectiveValue, explicitResult.objectiveValue),
                "objective \(namedResult.objectiveValue) vs \(explicitResult.objectiveValue)")
        #expect(identical(namedResult.bestBound, explicitResult.bestBound),
                "bound \(namedResult.bestBound) vs \(explicitResult.bestBound)")
        #expect(namedResult.nodesExplored == explicitResult.nodesExplored,
                "nodes \(namedResult.nodesExplored) vs \(explicitResult.nodesExplored)")
    }

    @Test("minlp() actually solves the nonlinear problem")
    func minlpSolvesNonlinearProblem() throws {
        let solver = BranchAndBoundSolver<VectorN<Double>>.minlp(maxNodes: 500)

        let result = try solver.solve(
            objective: Self.objective,
            from: Self.initialGuess,
            subjectTo: Self.constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        // The continuous optimum is (2, 2), which is integral and satisfies
        // 4 + 4 = 8 ≤ 9, so it is also the integer optimum. Objective = −8.
        #expect(result.integerSolution == [2, 2],
                "Expected [2, 2], got \(result.integerSolution)")
        #expect(approximatelyEqual(result.objectiveValue, -8.0, tolerance: 1e-3),
                "Expected obj ≈ −8, got \(result.objectiveValue)")

        // And the answer must lie in the disc it was constrained to.
        let solutionArray = result.solution.toArray()
        let radiusSquared = solutionArray[0] * solutionArray[0] + solutionArray[1] * solutionArray[1]
        #expect(radiusSquared <= 9.0 + 1e-6,
                "Solution outside the disc: r² = \(radiusSquared)")
    }

    @Test("minlp() branches when the nonlinear relaxation is fractional")
    func minlpBranchesOverTheNonlinearRelaxation() throws {
        // The fixture above has its continuous optimum at (2, 2), which is already
        // integral — so branch-and-bound takes it at the root and explores exactly one
        // node. That proves the composition solves an NLP; it does not prove that
        // *branching* over a nonlinear relaxation works, which is the whole difference
        // between MINLP and NLP.
        //
        // Steepening the linear term to 5 pushes the continuous optimum onto the
        // boundary of the disc, at (3/√2, 3/√2) ≈ (2.121, 2.121), which is fractional
        // in both coordinates. Now the search has to branch, and the bound it prunes
        // with comes from the NLP relaxation at each node rather than a simplex one.
        let steeper: @Sendable (VectorN<Double>) -> Double = { v in
            let quadratic = v[0] * v[0] + v[1] * v[1]
            let linear = 5.0 * v[0] + 5.0 * v[1]
            return quadratic - linear
        }

        let solver = BranchAndBoundSolver<VectorN<Double>>.minlp(maxNodes: 500)
        let result = try solver.solve(
            objective: steeper,
            from: Self.initialGuess,
            subjectTo: Self.constraints,
            integerSpec: .allInteger(dimension: 2)
        )

        #expect(result.nodesExplored > 1,
                "the relaxation was fractional, so the search had to branch; it explored \(result.nodesExplored) node(s)")

        // (2, 2) gives 8 − 20 = −12. The alternatives inside the disc are all worse:
        // (1, 2) and (2, 1) give −10, (3, 0) and (0, 3) give −6, and (3, 1) leaves the
        // disc at r² = 10.
        #expect(result.integerSolution == [2, 2],
                "expected [2, 2], got \(result.integerSolution)")
        #expect(approximatelyEqual(result.objectiveValue, -12.0, tolerance: 1e-3),
                "expected obj ≈ −12, got \(result.objectiveValue)")
        #expect(result.status == .optimal, "status was \(result.status)")

        // The bound must not claim more than the answer: for a minimisation the best
        // bound sits at or below the incumbent, and a bound above it would mean the
        // search pruned something it should have kept.
        #expect(result.bestBound <= result.objectiveValue + 1e-6,
                "bound \(result.bestBound) exceeds the incumbent \(result.objectiveValue)")
    }

    // MARK: - Configuration surface

    @Test("minlp() installs a nonlinear relaxation rather than the default simplex one")
    func minlpInstallsNonlinearRelaxation() {
        let solver = BranchAndBoundSolver<VectorN<Double>>.minlp()
        #expect(solver.relaxationSolver is NonlinearRelaxationSolver,
                "Expected NonlinearRelaxationSolver, got \(type(of: solver.relaxationSolver))")
    }

    @Test("minlp() carries the branch-and-bound defaults through unchanged")
    func minlpPreservesDefaults() {
        let named = BranchAndBoundSolver<VectorN<Double>>.minlp()
        let reference = BranchAndBoundSolver<VectorN<Double>>()

        #expect(named.maxNodes == reference.maxNodes)
        #expect(identical(named.timeLimit, reference.timeLimit))
        #expect(identical(named.relativeGapTolerance, reference.relativeGapTolerance))
        #expect(named.nodeSelection == reference.nodeSelection)
        #expect(named.branchingRule == reference.branchingRule)
        #expect(identical(named.lpTolerance, reference.lpTolerance))
        #expect(identical(named.integralityTolerance, reference.integralityTolerance))
        #expect(named.enableVariableShifting == reference.enableVariableShifting)
        #expect(named.enableWarmStart == reference.enableWarmStart)
    }

    @Test("minlp() forwards its configuration arguments")
    func minlpForwardsConfiguration() {
        let solver = BranchAndBoundSolver<VectorN<Double>>.minlp(
            maxNodes: 37,
            timeLimit: 12.5,
            nodeSelection: .depthFirst,
            branchingRule: .pseudoCost,
            integralityTolerance: 1e-7,
            enableVariableShifting: true
        )

        #expect(solver.maxNodes == 37)
        #expect(identical(solver.timeLimit, 12.5))
        #expect(solver.nodeSelection == .depthFirst)
        #expect(solver.branchingRule == .pseudoCost)
        #expect(identical(solver.integralityTolerance, 1e-7))
        #expect(solver.enableVariableShifting)
    }

    @Test("minlp() forwards the NLP solver's own tolerances")
    func minlpForwardsNLPConfiguration() {
        let solver = BranchAndBoundSolver<VectorN<Double>>.minlp(
            nlpMaxIterations: 250,
            nlpTolerance: 1e-4
        )

        guard let nonlinear = solver.relaxationSolver as? NonlinearRelaxationSolver else {
            Issue.record("Expected NonlinearRelaxationSolver, got \(type(of: solver.relaxationSolver))")
            return
        }
        #expect(nonlinear.maxIterations == 250)
        #expect(identical(nonlinear.tolerance, 1e-4))
    }
}
