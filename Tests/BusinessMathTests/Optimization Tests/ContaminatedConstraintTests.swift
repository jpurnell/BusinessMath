//
//  ContaminatedConstraintTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Sources/BusinessMath/Optimization/`.
//
//  `constraintViolation` measures how far a point misses a constraint:
//
//      return V.Scalar.maximum(V.Scalar.zero, value)
//
//  `T.maximum` is IEEE `maxNum`, which treats a NaN as *missing* — this file's neighbour says
//  so in its own comment — so `maximum(0, nan)` is **0**: "this point satisfies the constraint
//  exactly". `worstConstraintViolation` then fails the same way a second time, because
//  `amount > worst` is false for a NaN and `worst` stays at zero.
//
//  A constraint closure returning NaN is not exotic. It is what a user's `log`, `sqrt` or
//  division-by-a-decision-variable does when a heuristic explores outside the intended region,
//  which is the whole point of a heuristic.
//
//  This is the shared constrained path for GeneticAlgorithm, DifferentialEvolution,
//  ParticleSwarmOptimization and NelderMead — all four call `penaltyConstrainedSolve` — and it
//  reports `terminationReason: .converged` with `constraintViolation: 0` for a point that
//  satisfies nothing. Meanwhile the augmented Lagrangian is NaN-valued wherever that
//  constraint bites, so the inner minimise has no gradient and returns near its start. The
//  starting point, certified as a converged feasible optimum: the `PortfolioOptimizer`
//  objective defect, one layer down and shared by four optimisers.
//
//  `SimulatedAnnealing.acceptanceProbability` fails in the same family:
//
//      guard deltaE > V.Scalar.zero else { return 1.0 }
//
//  false for a NaN, so an unevaluable move is accepted with certainty — the value reserved for
//  a strict improvement. `currentEnergy` then becomes NaN and stays NaN, because every later
//  `deltaE` is `x - nan`, so the Metropolis test is switched off for the rest of the schedule.
//
//  And two sites the *norm* fix exposed rather than created: `cosineSimilarity` and
//  `angle(with:)` guard `norms > 0`. Before `norm` learned to return NaN for a wholly
//  contaminated vector, that guard could not see one. Now it can, and it answers `0` —
//  "orthogonal" and "identical direction" respectively.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Constraints and similarity on contaminated input")
struct ContaminatedConstraintTests {

    // MARK: - Constraint violation

    /// A constraint that cannot be evaluated is not a satisfied constraint.
    @Test("Violation_OfAnUnevaluableConstraint_IsNotZero")
    func violationOfAnUnevaluableConstraintIsNotZero() {
        let unevaluable = MultivariateConstraint<Vector2D<Double>>.inequality { point in
            point.x < 0 ? Double.nan : point.x - 1
        }
        let violation = constraintViolation(of: unevaluable, at: Vector2D(x: -1.0, y: 0.0))
        #expect(!violation.isEqual(to: 0.0),
                "reported \(violation), i.e. the point satisfies the constraint exactly")
    }

    /// And the aggregate must not lose it either.
    @Test("WorstViolation_DoesNotSwallowAnUnevaluableConstraint")
    func worstViolationDoesNotSwallowAnUnevaluableConstraint() {
        let unevaluable = MultivariateConstraint<Vector2D<Double>>.inequality { point in
            point.x < 0 ? Double.nan : point.x - 1
        }
        let satisfied = MultivariateConstraint<Vector2D<Double>>.inequality { _ in -1.0 }
        let worst = worstConstraintViolation(of: [satisfied, unevaluable],
                                             at: Vector2D(x: -1.0, y: 0.0))
        #expect(!worst.isEqual(to: 0.0), "reported \(worst) — feasible")
    }

    /// Control: ordinary constraints are measured exactly as before.
    @Test("Violation_OrdinaryConstraints_Unchanged")
    func violationOrdinaryConstraintsUnchanged() {
        let satisfied = MultivariateConstraint<Vector2D<Double>>.inequality { _ in -2.0 }
        let violated = MultivariateConstraint<Vector2D<Double>>.inequality { _ in 3.0 }
        let equality = MultivariateConstraint<Vector2D<Double>>.equality { _ in -4.0 }
        let point = Vector2D(x: 0.0, y: 0.0)
        #expect(constraintViolation(of: satisfied, at: point).isEqual(to: 0.0))
        #expect(constraintViolation(of: violated, at: point).isEqual(to: 3.0))
        #expect(constraintViolation(of: equality, at: point).isEqual(to: 4.0), "magnitude")
        #expect(worstConstraintViolation(of: [satisfied, violated], at: point).isEqual(to: 3.0))
    }

    // MARK: - Simulated annealing

    /// An unevaluable move must not be accepted with certainty.
    @Test("AcceptanceProbability_OfAnUnevaluableMove_IsNotCertain")
    func acceptanceProbabilityOfAnUnevaluableMoveIsNotCertain() {
        let p = SimulatedAnnealing<Vector2D<Double>>.acceptanceProbability(
            deltaE: Double.nan, temperature: 10.0)
        #expect(!(p > 0.0), "reported \(p); 1.0 is reserved for a strict improvement")
    }

    /// Control: the Metropolis rule is untouched.
    @Test("AcceptanceProbability_OrdinaryMoves_Unchanged")
    func acceptanceProbabilityOrdinaryMovesUnchanged() {
        let improvement = SimulatedAnnealing<Vector2D<Double>>.acceptanceProbability(
            deltaE: -5.0, temperature: 10.0)
        #expect(improvement.isEqual(to: 1.0), "an improvement is always accepted")
        let worse = SimulatedAnnealing<Vector2D<Double>>.acceptanceProbability(
            deltaE: 10.0, temperature: 10.0)
        #expect(abs(worse - exp(-1.0)) < 1e-12, "got \(worse)")
        let frozen = SimulatedAnnealing<Vector2D<Double>>.acceptanceProbability(
            deltaE: 10.0, temperature: 0.0)
        #expect(frozen.isEqual(to: 0.0))
    }

    // MARK: - Similarity, exposed by the norm fix

    /// `0` is not neutral on a [-1, 1] similarity scale — it outranks every genuinely
    /// dissimilar candidate.
    @Test("CosineSimilarity_WithAContaminatedVector_IsUndefined")
    func cosineSimilarityWithAContaminatedVectorIsUndefined() {
        let contaminated = VectorN([Double.nan, Double.nan])
        let reference = VectorN([1.0, 0.0])
        let similarity = contaminated.cosineSimilarity(with: reference)
        #expect(similarity.isNaN, "reported \(similarity)")
        let opposite = VectorN([-1.0, 0.0]).cosineSimilarity(with: reference)
        #expect(opposite.isEqual(to: -1.0), "which a contaminated vector must not outrank")
    }

    /// An angle of 0 radians means "the same direction" — the best possible match.
    @Test("Angle_WithAContaminatedVector_IsUndefined")
    func angleWithAContaminatedVectorIsUndefined() {
        let angle = VectorN([Double.nan, Double.nan]).angle(with: VectorN([1.0, 0.0]))
        #expect(angle.isNaN, "reported \(angle) radians — indistinguishable from an exact match")
    }

    /// Control: a genuine zero vector keeps its documented answers, and ordinary vectors are
    /// unchanged.
    @Test("Similarity_OrdinaryAndZeroVectors_Unchanged")
    func similarityOrdinaryAndZeroVectorsUnchanged() {
        let reference = VectorN([1.0, 0.0])
        #expect(VectorN([0.0, 0.0]).cosineSimilarity(with: reference).isEqual(to: 0.0),
                "a zero-norm vector is documented as 0")
        #expect(reference.cosineSimilarity(with: reference).isEqual(to: 1.0))
        #expect(VectorN([0.0, 1.0]).cosineSimilarity(with: reference).isEqual(to: 0.0))
        let right = VectorN([0.0, 1.0]).angle(with: reference)
        #expect(abs(right - Double.pi / 2) < 1e-12, "got \(right)")
    }
}
