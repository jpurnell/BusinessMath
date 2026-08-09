//
//  SimplexScaleInvarianceTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-08-08.
//

import Testing
import Foundation
@testable import BusinessMath

/// Feasibility must not depend on the units a problem is written in.
///
/// Phase I of the two-phase simplex minimises the sum of the artificial
/// variables, and that sum carries the magnitude of the constraint right-hand
/// sides. Comparing it to an **absolute** tolerance therefore ties the
/// feasibility verdict to the scale of the data: the same model expressed in
/// dollars and in thousands of dollars is the same model, and one of them was
/// being declared infeasible.
///
/// The failure was found in a DEA run over marketplace listings, where benchmark
/// scores (~10⁴) sit beside RAM in gigabytes (~10¹). At 120 units with four
/// outputs the Phase I residual settled at 5.65e-10 against a 1e-10 tolerance —
/// a *relative* error of about 5.6e-14, roughly 250× machine epsilon, which is
/// accumulated rounding across several thousand pivots and nothing else.
/// Dividing every value by 1,000 made the same problem solve.
@Suite("Simplex scale invariance")
struct SimplexScaleInvarianceTests {

    // MARK: - Fixture

    /// Marketplace-shaped DMUs: one cost input, four benefit outputs whose raw
    /// magnitudes differ by three orders of magnitude.
    private func listings(count: Int, scale: Double) -> [DMU] {
        (0..<count).map { index in
            let cost = (200.0 + Double((index * 37) % 1_800)) * scale
            let spans: [(Double, Int)] = [(3_000, 9_000), (700, 900), (8, 120), (128, 3_800)]
            let outputs = spans.enumerated().map { dimension, span in
                (span.0 + Double((index * (29 + dimension * 7)) % span.1)) * scale
            }
            return DMU(name: "u\(index)", inputs: [cost], outputs: outputs)
        }
    }

    // MARK: - The bug

    @Test("a feasible DEA problem is not declared infeasible because of its units")
    func largeMagnitudesStillSolve() throws {
        let solver = DEASolver()
        let result = try solver.solve(dmus: listings(count: 120, scale: 1.0),
                                      model: .ccr, orientation: .inputOriented)

        #expect(result.scores.count == 120)
        // An input-oriented model always admits θ = 1 for the unit under
        // evaluation, so no unit here can be genuinely infeasible.
        #expect(result.scores.allSatisfy { $0.efficiency > 0 && $0.efficiency <= 1.0 + 1e-9 })
    }

    /// The mathematical claim, stated directly: DEA efficiency is invariant to the
    /// units each input and output is measured in. These two calls are the same
    /// problem, so they must produce the same scores — and before the fix, one of
    /// them threw.
    @Test("efficiency scores are invariant to a change of units")
    func scoresAreInvariantToUnits() throws {
        let solver = DEASolver()
        let raw = try solver.solve(dmus: listings(count: 120, scale: 1.0),
                                   model: .ccr, orientation: .inputOriented)
        let rescaled = try solver.solve(dmus: listings(count: 120, scale: 0.001),
                                        model: .ccr, orientation: .inputOriented)

        #expect(raw.scores.count == rescaled.scores.count)
        for (left, right) in zip(raw.scores, rescaled.scores) {
            #expect(left.name == right.name)
            #expect(abs(left.efficiency - right.efficiency) < 1e-6,
                    "\(left.name): \(left.efficiency) in raw units, \(right.efficiency) rescaled")
        }
    }

    @Test("the same invariance holds under BCC")
    func bccIsAlsoInvariant() throws {
        let solver = DEASolver()
        let raw = try solver.solve(dmus: listings(count: 60, scale: 1.0),
                                   model: .bcc, orientation: .inputOriented)
        let rescaled = try solver.solve(dmus: listings(count: 60, scale: 0.001),
                                        model: .bcc, orientation: .inputOriented)

        for (left, right) in zip(raw.scores, rescaled.scores) {
            #expect(abs(left.efficiency - right.efficiency) < 1e-6, "\(left.name)")
        }
    }

    // MARK: - The fix must not swallow real infeasibility

    /// A relative tolerance widens the feasibility threshold in proportion to the
    /// data, so the guard that matters is that a genuinely infeasible problem is
    /// still caught *at that scale*. Here the violation is 10⁶ while the widened
    /// threshold is around 10⁻⁴ — six orders apart, not a close call.
    @Test("a genuinely infeasible problem is still infeasible at large magnitudes")
    func genuineInfeasibilitySurvivesRescaling() throws {
        let solver = SimplexSolver()

        for magnitude in [1.0, 1_000.0, 1_000_000.0] {
            let result = try solver.maximize(
                objective: [1.0, 1.0],
                subjectTo: [
                    SimplexConstraint(coefficients: [1.0, 1.0], relation: .lessOrEqual,
                                      rhs: 1.0 * magnitude),
                    SimplexConstraint(coefficients: [1.0, 1.0], relation: .greaterOrEqual,
                                      rhs: 2.0 * magnitude)
                ])
            #expect(result.status == SimplexStatus.infeasible,
                    "x+y ≤ \(magnitude) with x+y ≥ \(2 * magnitude) is infeasible in any units")
        }
    }

    /// A near-miss: the violation is small but real, and small *relative* to the
    /// data. It must still be caught rather than absorbed by the tolerance.
    @Test("a proportionally small but real violation is still infeasible")
    func smallRelativeViolationIsCaught() throws {
        let solver = SimplexSolver()
        let result = try solver.maximize(
            objective: [1.0],
            subjectTo: [
                SimplexConstraint(coefficients: [1.0], relation: .lessOrEqual, rhs: 1_000_000.0),
                SimplexConstraint(coefficients: [1.0], relation: .greaterOrEqual, rhs: 1_000_001.0)
            ])
        #expect(result.status == SimplexStatus.infeasible)
    }
}
