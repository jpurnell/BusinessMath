//
//  LinearCycleSolverTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Solving a linear cycle exactly, rather than iterating towards it.
///
/// The property every test here is built around: there is no tolerance. A cycle that is linear
/// in its members is a simultaneous linear system whose coefficients are known before it is
/// solved, so the answer is the answer — the only error in it is the rounding that the same
/// arithmetic written by hand would carry. The expectations are therefore closed forms, checked
/// to a hair, not "close enough after enough passes".
///
/// The models are all *within-period*, because the formula language has no reference to another
/// period. An opening balance is supplied as data; the roll-forward that would carry a closing
/// balance into the next period is the caller's, and no example here pretends otherwise.
@Suite("Linear Cycle Solver")
struct LinearCycleSolverTests {

	private let months = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2)
	]

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: months, values: values)
	}

	private func value(
		_ solved: [String: TimeSeries<Double>],
		_ name: String,
		_ index: Int = 0
	) throws -> Double {
		let series = try #require(solved[name])
		return try #require(series[months[index]])
	}

	// MARK: - The shapes that are linear

	/// The gross-up: a fee charged on a total that includes the fee. Two accounts, each
	/// defined from the other, and one exact answer — `base / (1 − rate)`.
	@Test("A fee charged on a total that includes it is solved exactly")
	func grossUp() throws {
		let solved = try ModelDefinition<Double>(inputs: ["base": series([1_000, 1_000])])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")
			.solve()

		#expect(try abs(value(solved, "total") - 1_000 / 0.9) <= 1e-12)
		#expect(try abs(value(solved, "fee") - 100 / 0.9) <= 1e-12)
	}

	/// A profit share accrued inside the income it is computed from.
	@Test("A bonus accrued on the income it reduces is solved exactly")
	func profitShare() throws {
		let solved = try ModelDefinition<Double>(inputs: ["ebit": series([1_000, 1_000])])
			.defining("bonus", as: "netIncome * 0.15")
			.defining("netIncome", as: "ebit - bonus")
			.solve()

		#expect(try abs(value(solved, "netIncome") - 1_000 / 1.15) <= 1e-12)
		#expect(try abs(value(solved, "bonus") - 150 / 1.15) <= 1e-12)
	}

	/// Three accounts round a loop, which is the shape a levered model's interest takes inside
	/// a single period. The opening balance is data; carrying a closing balance forward is not
	/// something the formula language can express, and this does not pretend to.
	@Test("A three-account cycle is solved exactly")
	func threeAccountCycle() throws {
		let solved = try ModelDefinition<Double>(inputs: [
			"openingDebt": series([1_000, 1_000]),
			"rate": series([0.10, 0.10]),
			"ebitda": series([300, 300])
		])
			.defining("interest", as: "debt * rate")
			.defining("debt", as: "openingDebt - cashFlow")
			.defining("cashFlow", as: "ebitda - interest")
			.solve()

		#expect(try abs(value(solved, "interest") - 70 / 0.9) <= 1e-12)
		#expect(try abs(value(solved, "debt") - 700 / 0.9) <= 1e-11)
		#expect(try abs(value(solved, "cashFlow") - 200 / 0.9) <= 1e-12)
	}

	/// The reason coefficients are extracted per period rather than once. A rate that moves
	/// between periods is a different system in each, and one answer for both would be wrong in
	/// at least one of them.
	@Test("Coefficients are extracted per period, so a rate that varies gives a different answer in each")
	func coefficientsVaryByPeriod() throws {
		let solved = try ModelDefinition<Double>(inputs: [
			"base": series([1_000, 1_000]),
			"rate": series([0.10, 0.20])
		])
			.defining("fee", as: "total * rate")
			.defining("total", as: "base + fee")
			.solve()

		#expect(try abs(value(solved, "total", 0) - 1_000 / 0.9) <= 1e-12)
		#expect(try abs(value(solved, "total", 1) - 1_250) <= 1e-12)
	}

	@Test("A self-referential account is a one-by-one system, and still exact")
	func selfReference() throws {
		let solved = try ModelDefinition<Double>(inputs: ["base": series([1_000, 1_000])])
			.defining("revenue", as: "revenue * 0.5 + base")
			.solve()

		#expect(try abs(value(solved, "revenue") - 2_000) <= 1e-12)
	}

	/// The whole reason for decomposing into components rather than iterating the model: the
	/// accounts before a cycle are computed once and feed it as coefficients, and the accounts
	/// after it are computed once from its answer.
	@Test("Accounts before and after a cycle are evaluated once, in order")
	func aroundTheCycle() throws {
		let solved = try ModelDefinition<Double>(inputs: [
			"revenue": series([2_000, 2_000]),
			"costs": series([1_000, 1_000])
		])
			.defining("ebit", as: "revenue - costs")
			.defining("bonus", as: "netIncome * 0.15")
			.defining("netIncome", as: "ebit - bonus")
			.defining("margin", as: "netIncome / revenue")
			.solve()

		#expect(try value(solved, "ebit") == 1_000)
		#expect(try abs(value(solved, "netIncome") - 1_000 / 1.15) <= 1e-12)
		#expect(try abs(value(solved, "margin") - 1_000 / 1.15 / 2_000) <= 1e-15)
	}

	/// The answer is a solution of the equations as written, not a nearby number. Substituting
	/// it back leaves a residual at the size of double-precision rounding, not at a tolerance
	/// anyone chose.
	@Test("Substituting the answer back into the formulas leaves only rounding")
	func residualIsRoundingOnly() throws {
		let solved = try ModelDefinition<Double>(inputs: ["base": series([1_000, 1_000])])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")
			.solve()

		let fee = try value(solved, "fee")
		let total = try value(solved, "total")

		#expect(abs(fee - total * 0.10) <= 1e-12)
		#expect(abs(total - (1_000 + fee)) <= 1e-12)
	}

	// MARK: - Models with no cycle at all

	@Test("An acyclic model gives the same answer through solve as through evaluate")
	func acyclicMatchesEvaluate() throws {
		let model = ModelDefinition<Double>(inputs: [
			"units": series([10, 20]),
			"price": series([100, 100])
		])
			.defining("revenue", as: "units * price")
			.defining("tax", as: "revenue * 0.2")

		let evaluated = try model.evaluate()
		let solved = try model.solve()

		#expect(solved["revenue"]?.valuesArray == evaluated["revenue"]?.valuesArray)
		#expect(solved["tax"]?.valuesArray == evaluated["tax"]?.valuesArray)
	}

	@Test("Solving returns the supplied inputs alongside the derived accounts")
	func inputsSurvive() throws {
		let solved = try ModelDefinition<Double>(inputs: ["base": series([1_000, 1_000])])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")
			.solve()

		#expect(solved["base"]?.valuesArray == [1_000, 1_000])
	}

	// MARK: - When there is no exact answer

	/// A system that says the same thing twice. `a` is `seed` above `b`, and `b` is `seed`
	/// below `a` — true, and true of infinitely many pairs. The caller needs telling that the
	/// cycle does not pin its members down, not that a matrix was singular.
	@Test("An underdetermined cycle is named as such, per period")
	func underdeterminedCycle() throws {
		let model = ModelDefinition<Double>(inputs: ["seed": series([5, 5])])
			.defining("a", as: "b + seed")
			.defining("b", as: "a - seed")

		do {
			_ = try model.solve()
			Issue.record("expected an underdetermined cycle to be refused")
		} catch let error as CycleSolverError {
			guard case .underdetermined(let accounts, let period, _) = error else {
				Issue.record("expected an underdetermined cycle, got \(error)")
				return
			}
			#expect(accounts == ["a", "b"])
			#expect(period == months[0])
			#expect(error.errorDescription?.contains("no unique solution") == true)
		}
	}

	/// A loop whose gain is within a rounding error of exactly 1. In exact arithmetic there is
	/// an answer; in double precision every digit of it would come from cancellation, so the
	/// honest thing is to say so rather than return it.
	@Test("A cycle whose feedback is within rounding of unity is refused as ill-conditioned")
	func illConditionedCycle() throws {
		let model = ModelDefinition<Double>(inputs: ["seed": series([5, 5])])
			.defining("a", as: "b + seed")
			.defining("b", as: "a * 0.9999999999")

		do {
			_ = try model.solve()
			Issue.record("expected an ill-conditioned cycle to be refused")
		} catch let error as CycleSolverError {
			guard case .illConditioned(let accounts, let period, _) = error else {
				Issue.record("expected an ill-conditioned cycle, got \(error)")
				return
			}
			#expect(accounts == ["a", "b"])
			#expect(period == months[0])
		}
	}

	/// Nothing on this path iterates. A cycle that is not linear in its members has no exact
	/// answer to extract, and is routed to the iterative solver instead — see
	/// `IterativeCycleSolverTests`, which is where its behaviour is pinned.
	@Test("A nonlinear cycle does not come back through the exact path")
	func nonlinearIsNotSolvedExactly() throws {
		let model = ModelDefinition<Double>(inputs: ["seed": series([5, 5])])
			.defining("a", as: "b * c")
			.defining("b", as: "a + seed")
			.defining("c", as: "a + seed")

		let cycle = try #require(model.dependencyReport().cycles.first)
		#expect(cycle.form == .nonlinear)
		#expect(try model.dependencyReport().isExactlySolvable == false)
	}

	// MARK: - The refusals inherited from evaluation

	@Test("An account both supplied and derived is refused before anything is solved")
	func suppliedAndDerivedIsRefused() throws {
		let model = ModelDefinition<Double>(inputs: [
			"base": series([1_000, 1_000]),
			"fee": series([1, 1])
		])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")

		#expect(throws: BusinessMathError.self) { try model.solve() }
	}

	@Test("A missing input is refused rather than read as zero")
	func missingInputIsRefused() throws {
		let model = ModelDefinition<Double>()
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")

		#expect(throws: FormulaError.self) { try model.solve() }
	}

	// MARK: - Determinism

	/// There is no sweep order and no starting iterate for elimination to depend on, so the
	/// only thing that could vary is the order the members are put into the matrix — and that
	/// is the cycle's sorted membership.
	@Test("Solving the same model twice gives bit-identical answers")
	func repeatable() throws {
		let model = ModelDefinition<Double>(inputs: [
			"openingDebt": series([1_000, 1_100]),
			"rate": series([0.10, 0.12]),
			"ebitda": series([300, 350])
		])
			.defining("interest", as: "debt * rate")
			.defining("debt", as: "openingDebt - cashFlow")
			.defining("cashFlow", as: "ebitda - interest")

		let first = try model.solve()
		let second = try model.solve()

		for name in ["interest", "debt", "cashFlow"] {
			#expect(first[name]?.valuesArray == second[name]?.valuesArray)
		}
	}
}
