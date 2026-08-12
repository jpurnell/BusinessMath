//
//  InequalityOptimizerScaleInvarianceTests.swift
//  BusinessMath
//
//  A model does not change when you change the units it is written in. These
//  tests pin that claim on `InequalityOptimizer`, which solves with an augmented
//  Lagrangian: the same allocation, written in dollars and in millions of
//  dollars, must produce the same answer and both must be the true optimum.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Inequality Optimizer Scale Invariance Tests")
struct InequalityOptimizerScaleInvarianceTests {

	// MARK: - The Allocation

	/// A two-project capital allocation, written at an arbitrary monetary scale.
	///
	/// ```
	/// minimize  (a − 1.2·s)² + (b − 0.9·s)²   distance from the ideal spend
	/// s.t.      a + b ≤ 1.5·s                 budget
	///           a ≥ 0, b ≥ 0
	/// ```
	///
	/// The ideal spend (1.2s, 0.9s) costs 2.1s and the budget is 1.5s, so the
	/// budget line is active and the optimum is the projection of the ideal spend
	/// onto it: **(0.9·s, 0.6·s)**, both projects funded, neither bound binding.
	///
	/// Returned normalised by `s`, so a correct solver answers `(0.9, 0.6)` at
	/// every scale.
	///
	/// - Parameter s: the monetary unit — `1.0` for millions, `1_000_000` for dollars.
	static func allocation(scale s: Double) throws -> (a: Double, b: Double, converged: Bool, violation: Double) {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let da = v[0] - 1.2 * s
			let db = v[1] - 0.9 * s
			return da * da + db * db
		}

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.inequality { v in v[0] + v[1] - 1.5 * s },  // a + b ≤ 1.5s
			.inequality { v in -v[0] },                  // a ≥ 0
			.inequality { v in -v[1] }                   // b ≥ 0
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>()

		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.5 * s, 0.5 * s]),
			subjectTo: constraints
		)

		return (
			result.solution[0] / s,
			result.solution[1] / s,
			result.converged,
			result.constraintViolation / s
		)
	}

	// MARK: - Scale Invariance

	@Test("The same allocation in dollars and in millions gives the same answer")
	func dollarsAndMillionsAgree() throws {
		let millions = try Self.allocation(scale: 1.0)
		let dollars = try Self.allocation(scale: 1_000_000.0)

		#expect(millions.converged, "written in millions: should converge")
		#expect(dollars.converged, "written in dollars: should converge")

		// Both must be the true optimum, (0.9, 0.6) in units of the budget scale.
		#expect(abs(millions.a - 0.9) < 1e-3, "millions: a should be 0.9 of scale, got \(millions.a)")
		#expect(abs(millions.b - 0.6) < 1e-3, "millions: b should be 0.6 of scale, got \(millions.b)")
		#expect(abs(dollars.a - 0.9) < 1e-3, "dollars: a should be 0.9 of scale, got \(dollars.a)")
		#expect(abs(dollars.b - 0.6) < 1e-3, "dollars: b should be 0.6 of scale, got \(dollars.b)")

		// And they must agree with each other: the unit the model is written in
		// is not an input to the answer.
		#expect(abs(millions.a - dollars.a) < 1e-3, "a differs by unit: \(millions.a) vs \(dollars.a)")
		#expect(abs(millions.b - dollars.b) < 1e-3, "b differs by unit: \(millions.b) vs \(dollars.b)")
	}

	@Test("The allocation is stable across nine orders of magnitude", arguments: [
		1e-3, 1.0, 1e3, 1e6
	])
	func stableAcrossScales(scale: Double) throws {
		let r = try Self.allocation(scale: scale)

		#expect(r.converged, "scale \(scale): should converge")
		#expect(abs(r.a - 0.9) < 1e-3, "scale \(scale): a should be 0.9, got \(r.a)")
		#expect(abs(r.b - 0.6) < 1e-3, "scale \(scale): b should be 0.6, got \(r.b)")
		#expect(r.violation < 1e-6, "scale \(scale): budget should hold, violation \(r.violation)")
	}

	// MARK: - Capital Budgeting (Linear Objective)

	/// The shape business allocation actually takes: a linear value per unit of
	/// capital, a budget, and a cap on each project.
	///
	/// ```
	/// maximize  3a + b            value returned
	/// s.t.      a + b ≤ 1.5·s     budget
	///           0 ≤ a ≤ s, 0 ≤ b ≤ s
	/// ```
	///
	/// Project *a* returns three times what *b* does, so fund it to its cap and put
	/// the remaining half-budget in *b*: the optimum is **(s, 0.5·s)**, one binding
	/// cap and one binding budget. Normalised by `s`, the answer is `(1.0, 0.5)`.
	static func capitalBudget(scale s: Double) throws -> (a: Double, b: Double, converged: Bool, violation: Double) {
		let value: @Sendable (VectorN<Double>) -> Double = { v in 3.0 * v[0] + v[1] }

		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.inequality { v in v[0] + v[1] - 1.5 * s },  // budget
			.inequality { v in -v[0] },                  // a ≥ 0
			.inequality { v in -v[1] },                  // b ≥ 0
			.inequality { v in v[0] - s },               // a ≤ s
			.inequality { v in v[1] - s }                // b ≤ s
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>()

		let result = try optimizer.maximize(
			value,
			from: VectorN([0.5 * s, 0.5 * s]),
			subjectTo: constraints
		)

		return (
			result.solution[0] / s,
			result.solution[1] / s,
			result.converged,
			result.constraintViolation / s
		)
	}

	@Test("Capital budgeting gives the same plan in dollars and in millions")
	func capitalBudgetDollarsAndMillionsAgree() throws {
		let millions = try Self.capitalBudget(scale: 1.0)
		let dollars = try Self.capitalBudget(scale: 1_000_000.0)

		#expect(millions.converged, "written in millions: should converge")
		#expect(dollars.converged, "written in dollars: should converge")

		#expect(abs(millions.a - 1.0) < 1e-3, "millions: a should be the cap, got \(millions.a)")
		#expect(abs(millions.b - 0.5) < 1e-3, "millions: b should be the remainder, got \(millions.b)")
		#expect(abs(dollars.a - 1.0) < 1e-3, "dollars: a should be the cap, got \(dollars.a)")
		#expect(abs(dollars.b - 0.5) < 1e-3, "dollars: b should be the remainder, got \(dollars.b)")

		#expect(abs(millions.a - dollars.a) < 1e-3, "a differs by unit: \(millions.a) vs \(dollars.a)")
		#expect(abs(millions.b - dollars.b) < 1e-3, "b differs by unit: \(millions.b) vs \(dollars.b)")
	}

	@Test("Capital budgeting is stable across nine orders of magnitude", arguments: [
		1e-3, 1.0, 1e3, 1e6
	])
	func capitalBudgetStableAcrossScales(scale: Double) throws {
		let r = try Self.capitalBudget(scale: scale)

		#expect(r.converged, "scale \(scale): should converge")
		#expect(abs(r.a - 1.0) < 1e-3, "scale \(scale): a should be 1.0, got \(r.a)")
		#expect(abs(r.b - 0.5) < 1e-3, "scale \(scale): b should be 0.5, got \(r.b)")
		#expect(r.violation < 1e-6, "scale \(scale): budget should hold, violation \(r.violation)")
	}

	// MARK: - The Outer Test Means Something

	/// A tolerance schedule that lets the inner solve stop early is only sound if the
	/// outer loop still refuses to call the result converged. This pins that: the
	/// starting point is strictly feasible and nowhere near optimal, so a solver whose
	/// outer test is feasibility alone can return it and claim success. This passed
	/// before the fix as well — the schedule has to leave it passing, which is the
	/// point of keeping it.
	@Test("Feasible is not the same as optimal")
	func feasibleStartIsNotConvergence() throws {
		let objective: @Sendable (VectorN<Double>) -> Double = { v in
			let dx = v[0] - 4.0
			let dy = v[1] - 4.0
			return dx * dx + dy * dy
		}
		let constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.inequality { v in v[0] + v[1] - 6.0 },
			.inequality { v in -v[0] },
			.inequality { v in -v[1] }
		]

		let optimizer = InequalityOptimizer<VectorN<Double>>()
		let result = try optimizer.minimize(
			objective,
			from: VectorN([0.05, 0.05]),  // strictly feasible, nowhere near optimal
			subjectTo: constraints
		)

		#expect(result.converged, "should converge")
		#expect(abs(result.solution[0] - 3.0) < 1e-3, "x should be 3, got \(result.solution[0])")
		#expect(abs(result.solution[1] - 3.0) < 1e-3, "y should be 3, got \(result.solution[1])")
	}
}
