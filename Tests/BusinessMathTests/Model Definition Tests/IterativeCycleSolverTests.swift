//
//  IterativeCycleSolverTests.swift
//  BusinessMath
//

import Testing
import Foundation
import TestSupport  // identical(_:_:) — bit-for-bit comparison
@testable import BusinessMath

/// Iterating the cycles that have no exact answer, and refusing to pretend when they do not
/// settle.
///
/// Two properties are load-bearing here and each has tests of its own.
///
/// **Non-convergence throws.** There is no `converged: Bool` on a struct full of numbers. An
/// unconverged iterate is in the right units, prints, and looks exactly like an answer; the only
/// thing distinguishing it is a flag a hurried caller will not read. So it is not returned at
/// all, and what comes back instead carries the diagnosis: how many sweeps were spent, how far
/// the last one moved, and which accounts were still moving when it stopped.
///
/// **The sweep order is fixed and observable.** Gauss–Seidel updates in place, so which account
/// is updated first changes the trajectory. The order is the cycle's sorted membership, and the
/// test that pins it stops after one sweep and checks the exact numbers that order produces —
/// not that two runs happen to agree, which would pass even if the order were random per
/// process.
@Suite("Iterative Cycle Solver")
struct IterativeCycleSolverTests {

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

	/// `a = 0.5·a² + 0.25`, whose fixed point reachable from zero is `1 − √½`.
	private func contracting() -> ModelDefinition<Double> {
		ModelDefinition<Double>(inputs: [
			"half": series([0.5, 0.5]),
			"quarter": series([0.25, 0.25])
		])
			.defining("a", as: "a * a * half + quarter")
	}

	/// `a = 1 − a²` from zero, which lands on 1, 0, 1, 0 and stays there.
	private func oscillating() -> ModelDefinition<Double> {
		ModelDefinition<Double>(inputs: ["one": series([1, 1])])
			.defining("a", as: "one - a * a")
	}

	/// `a = 2a² + 1`, whose iterates grow without bound from any start.
	private func diverging() -> ModelDefinition<Double> {
		ModelDefinition<Double>(inputs: [
			"two": series([2, 2]),
			"one": series([1, 1])
		])
			.defining("a", as: "a * a * two + one")
	}

	// MARK: - Converging

	@Test("A contracting nonlinear cycle converges to its fixed point")
	func contractingSelfCycle() throws {
		let solved = try contracting().solve()

		#expect(try abs(value(solved, "a") - (1 - (0.5 as Double).squareRoot())) <= 1e-7)
	}

	@Test("A two-account nonlinear cycle converges to its fixed point")
	func contractingPair() throws {
		let solved = try ModelDefinition<Double>(inputs: [
			"half": series([0.5, 0.5]),
			"quarter": series([0.25, 0.25])
		])
			.defining("a", as: "b * b * half")
			.defining("b", as: "a + quarter")
			.solve()

		let b = 1 - (0.5 as Double).squareRoot()
		#expect(try abs(value(solved, "b") - b) <= 1e-7)
		#expect(try abs(value(solved, "a") - (b - 0.25)) <= 1e-7)
	}

	@Test("Every period is solved, not only the first")
	func everyPeriod() throws {
		let solved = try contracting().solve()
		let fixedPoint = 1 - (0.5 as Double).squareRoot()

		#expect(try abs(value(solved, "a", 0) - fixedPoint) <= 1e-7)
		#expect(try abs(value(solved, "a", 1) - fixedPoint) <= 1e-7)
	}

	// MARK: - Not converging

	/// Alternating signs with an amplitude that does not decay. The state matters because the
	/// remedy differs: this one is what damping exists for, and telling the user to raise the
	/// iteration cap instead would waste their afternoon.
	@Test("An oscillating cycle throws, and is named as oscillating")
	func oscillationThrows() throws {
		do {
			_ = try oscillating().solve()
			Issue.record("expected an oscillating cycle to be refused")
		} catch let error as CycleSolverError {
			guard case .notConverged(let accounts, let state, _, _, let stillMoving) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(accounts == ["a"])
			#expect(state == .oscillating)
			#expect(stillMoving == ["a"])
		}
	}

	@Test("Damping settles the cycle that plain iteration could not")
	func dampingSettlesOscillation() throws {
		let solved = try oscillating().solve(settings: IterationSettings(relaxation: 0.5))

		// The positive root of x² + x − 1, which is where 1 − x² has its fixed point.
		#expect(try abs(value(solved, "a") - 0.618_033_988_749_895) <= 1e-8)
	}

	/// Growing changes with a constant sign. Damping does not fix this one and the diagnosis
	/// should not suggest it.
	@Test("A diverging cycle is named as diverging rather than merely exhausted")
	func divergenceIsNamed() throws {
		do {
			_ = try diverging().solve(settings: IterationSettings(maxIterations: 5))
			Issue.record("expected a diverging cycle to be refused")
		} catch let error as CycleSolverError {
			guard case .notConverged(_, let state, let iterations, _, _) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(state == .diverging)
			#expect(iterations == 5)
		}
	}

	/// Left to run, this cycle overflows. Iterating on into infinities and then into NaNs would
	/// turn a diagnosable divergence into a series of blanks, so it stops at the first value
	/// that is no longer a number.
	@Test("Iteration stops when the values stop being finite")
	func nonFiniteStops() throws {
		do {
			_ = try diverging().solve()
			Issue.record("expected a diverging cycle to be refused")
		} catch let error as CycleSolverError {
			guard case .notConverged(_, let state, let iterations, _, _) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(state == .diverging)
			#expect(iterations < 100)
		}
	}

	@Test("A cycle that has not settled by the cap reports how far it still had to go")
	func exhaustedCarriesTheDiagnosis() throws {
		do {
			_ = try contracting().solve(settings: IterationSettings(maxIterations: 2))
			Issue.record("expected two sweeps to be too few")
		} catch let error as CycleSolverError {
			guard case .notConverged(_, let state, let iterations, let finalChange, let stillMoving) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(state == .exhausted)
			#expect(iterations == 2)
			#expect(finalChange > 0)
			#expect(stillMoving == ["a"])
			#expect(error.errorDescription?.contains("2 sweeps") == true)
		}
	}

	// MARK: - Sweep order

	/// The pin. In sorted order `a` is updated before `b`, so the first sweep computes `a` from
	/// `b`'s starting value of zero — leaving it at zero and unmoved — and then `b` from the `a`
	/// it has just written. Sweeping in the other order would move both. The assertion is those
	/// exact numbers, not that two runs agree: a per-process random order would pass that.
	@Test("The sweep order is the cycle's sorted membership, and one sweep proves it")
	func sweepOrderIsPinned() throws {
		let model = ModelDefinition<Double>(inputs: [
			"half": series([0.5, 0.5]),
			"quarter": series([0.25, 0.25])
		])
			.defining("a", as: "b * b * half")
			.defining("b", as: "a + quarter")

		do {
			_ = try model.solve(settings: IterationSettings(maxIterations: 1))
			Issue.record("expected one sweep to be too few")
		} catch let error as CycleSolverError {
			guard case .notConverged(_, _, _, let finalChange, let stillMoving) = error else {
				Issue.record("expected a convergence failure, got \(error)")
				return
			}
			#expect(stillMoving == ["b"])
			// Exact, and deliberately so: 0.25 is representable and the change is a single
			// subtraction from zero, so an epsilon here would hide the order changing.
			#expect(finalChange.isEqual(to: 0.25))
		}
	}

	// MARK: - Initial values

	/// A nonlinear cycle can have more than one fixed point, and which one is reached is a
	/// property of where the iteration started. `a = a²` has two, and the result is whichever
	/// basin the start sat in — so the start is enumerated rather than being whatever happened
	/// to be loaded.
	@Test("The starting iterate decides which fixed point a nonlinear cycle reaches")
	func initialValuesDecideTheAnswer() throws {
		let model = ModelDefinition<Double>(inputs: ["one": series([1, 1])])
			.defining("a", as: "a * a * one")

		let fromZero = try model.solve()
		let fromOne = try model.solve(
			settings: IterationSettings(initialValues: .supplied(["a": series([1, 1])]))
		)

		#expect(try value(fromZero, "a") == 0)
		#expect(try identical(value(fromOne, "a"), 1))
	}

	// MARK: - Alongside the exact path

	/// Settings belong to iteration, and a linear cycle does not iterate. A cap of zero sweeps
	/// is a cap on something this model never does.
	@Test("A linear cycle is still solved exactly, whatever the iteration settings say")
	func linearCyclesDoNotIterate() throws {
		let solved = try ModelDefinition<Double>(inputs: ["base": series([1_000, 1_000])])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")
			.solve(settings: IterationSettings(maxIterations: 0))

		#expect(try abs(value(solved, "total") - 1_000 / 0.9) <= 1e-12)
	}

	@Test("A model with one cycle of each kind solves one exactly and iterates the other")
	func mixedModel() throws {
		let solved = try ModelDefinition<Double>(inputs: [
			"base": series([1_000, 1_000]),
			"half": series([0.5, 0.5]),
			"quarter": series([0.25, 0.25])
		])
			.defining("fee", as: "total * 0.10")
			.defining("total", as: "base + fee")
			.defining("a", as: "a * a * half + quarter")
			.solve()

		#expect(try abs(value(solved, "total") - 1_000 / 0.9) <= 1e-12)
		#expect(try abs(value(solved, "a") - (1 - (0.5 as Double).squareRoot())) <= 1e-7)
	}

	@Test("An acyclic model is unaffected by iteration settings")
	func acyclicIsUnaffected() throws {
		let model = ModelDefinition<Double>(inputs: ["units": series([10, 20])])
			.defining("revenue", as: "units * 100")

		#expect(try model.solve(settings: IterationSettings(maxIterations: 0))["revenue"]?.valuesArray == [1_000, 2_000])
	}

	// MARK: - Determinism

	/// Gauss–Seidel is order-dependent, and the order is derived from sorted names rather than
	/// from any dictionary, so the same model gives the same digits every time.
	@Test("Iterating the same model twice gives bit-identical answers")
	func repeatable() throws {
		let first = try contracting().solve()
		let second = try contracting().solve()

		#expect(first["a"]?.valuesArray == second["a"]?.valuesArray)
	}

	/// Definitions are written in one order and the sweep runs in another, so a model that is
	/// the same set of formulas typed in a different sequence is the same model.
	@Test("The order definitions were written in does not change the answer")
	func definitionOrderDoesNotMatter() throws {
		let inputs: [String: TimeSeries<Double>] = [
			"half": series([0.5, 0.5]),
			"quarter": series([0.25, 0.25])
		]

		let one = try ModelDefinition<Double>(inputs: inputs)
			.defining("a", as: "b * b * half")
			.defining("b", as: "a + quarter")
			.solve()

		let other = try ModelDefinition<Double>(inputs: inputs)
			.defining("b", as: "a + quarter")
			.defining("a", as: "b * b * half")
			.solve()

		#expect(one["a"]?.valuesArray == other["a"]?.valuesArray)
		#expect(one["b"]?.valuesArray == other["b"]?.valuesArray)
	}
}
