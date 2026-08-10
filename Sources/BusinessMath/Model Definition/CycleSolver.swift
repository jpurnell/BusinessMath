//
//  CycleSolver.swift
//  BusinessMath
//

import Foundation
import RealModule

// MARK: - CycleSolverError

/// Why a cycle could not be resolved to values.
///
/// Separate from ``BusinessMathError`` because these are answers about a *model*, not about a
/// matrix. A caller who gets one of these needs to know what to change in their definitions,
/// and "column 1 is entirely zero" does not tell them.
public enum CycleSolverError: Error, Equatable, Sendable {

	/// The cycle is linear but has more than one solution, so there is no answer to return.
	///
	/// The formulas round the loop repeat each other rather than pinning the members down —
	/// `a = b + fee` together with `b = a - fee` is true of every pair a `fee` apart. Excel
	/// would iterate this and settle wherever it started, which is a number with no claim on
	/// being the answer.
	///
	/// - Parameters:
	///   - accounts: The cycle's members, sorted.
	///   - period: The first period in which the system had no unique solution. Reported per
	///     period because the coefficients are per period: a cycle can be determined in one
	///     month and not in the next.
	///   - detail: What was observed about the system.
	case underdetermined(accounts: [String], period: Period, detail: String)

	/// The cycle has a unique solution in exact arithmetic and not in floating point.
	///
	/// The gain round the loop is within a rounding error of exactly 1 — a structure that
	/// almost, but not quite, funds itself. Every digit of the answer would come from the
	/// cancellation of two nearly equal numbers, so returning it would be returning noise
	/// formatted as a figure.
	///
	/// - Parameters:
	///   - accounts: The cycle's members, sorted.
	///   - period: The first period in which elimination lost its meaning.
	///   - detail: What was observed about the system.
	case illConditioned(accounts: [String], period: Period, detail: String)

	/// The cycle was iterated and did not settle.
	///
	/// Thrown rather than returned beside a `converged: false` flag. An unconverged iterate is a
	/// number in the right units that prints like an answer, and the only thing distinguishing
	/// it is a field a hurried caller will not read.
	///
	/// - Parameters:
	///   - accounts: The cycle's members, in the order each sweep visited them.
	///   - state: What the sequence of changes was observed doing. See ``ConvergenceState``.
	///   - iterations: Sweeps actually spent, which is not always the cap — a cycle whose values
	///     stopped being finite is abandoned where it stood.
	///   - finalChange: The largest change any member made on the last sweep. The number that
	///     answers "was it close?".
	///   - stillMoving: The members whose change was outside tolerance when it stopped, sorted.
	///     Knowing that seven accounts settled and one did not is a better place to start than a
	///     single residual.
	case notConverged(
		accounts: [String],
		state: ConvergenceState,
		iterations: Int,
		finalChange: Double,
		stillMoving: [String]
	)
}

extension CycleSolverError: LocalizedError {

	/// A message naming the cycle, the period, and what was observed.
	public var errorDescription: String? {
		switch self {
		case .underdetermined(let accounts, let period, let detail):
			return """
				The cycle \(accounts.joined(separator: " ↔ ")) has no unique solution in \
				\(period.label): \(detail)
				"""
		case .illConditioned(let accounts, let period, let detail):
			return """
				The cycle \(accounts.joined(separator: " ↔ ")) cannot be solved reliably in \
				\(period.label): \(detail)
				"""
		case .notConverged(let accounts, let state, let iterations, let finalChange, let stillMoving):
			return """
				The cycle \(accounts.joined(separator: " ↔ ")) did not settle after \
				\(iterations) sweeps. The change was \(state.observed); the largest on the last \
				sweep was \(finalChange), and \(stillMoving.joined(separator: ", ")) had not \
				stopped moving.
				"""
		}
	}

	/// What to change, in the order the causes are worth checking.
	public var recoverySuggestion: String? {
		switch self {
		case .underdetermined(let accounts, _, _):
			return """
				One of these accounts needs a formula that says something the others do not:
				  • Look for two definitions that are rearrangements of one equation — \
				'a = b + c' and 'b = a - c' are the same statement written twice.
				  • Check for a sign error that turned a constraint into an identity.
				  • Check that every account in the cycle is meant to be derived. An account \
				that is really data belongs in `inputs`, which removes it from the cycle.
				Members: \(accounts.joined(separator: ", "))
				"""
		case .illConditioned:
			return """
				The loop very nearly reproduces itself, so its answer is a large number divided \
				by an almost-zero one:
				  • Check the rate or share that closes the loop. A gain of exactly 1 has no \
				finite answer, and one within 1e-9 of it has no answer double precision can hold.
				  • Rescale the accounts if they differ by many orders of magnitude.
				  • If the structure is deliberate, the model is telling you it is unstable, \
				and that is a finding rather than a defect in the arithmetic.
				"""
		case .notConverged(_, let state, _, _, let stillMoving):
			switch state {
			case .diverging:
				return """
					The loop amplifies: each sweep moved further than the last. Damping and a \
					higher iteration cap will not change that.
					  • Look for a feedback whose gain exceeds 1 — a cost that grows faster than \
					the base it is charged on.
					  • Check the sign of the term that closes the loop.
					  • Reformulate so the fed-back quantity is bounded by something outside \
					the cycle.
					"""
			case .oscillating:
				return """
					The iterate steps past the answer and back again without settling.
					  • Damp it: pass `IterationSettings(relaxation: 0.5)` and raise the factor \
					back towards 1 if it settles.
					  • If damping does not help either, the gain exceeds 1 and the model needs \
					reformulating rather than tuning.
					"""
			case .exhausted:
				return """
					It was still shrinking when the sweeps ran out.
					  • Compare the final change against your tolerance. If it is close, raise \
					`maxIterations`.
					  • If it is not close, or barely moved over the last few sweeps, the \
					tolerance may be below what the arithmetic can deliver at these magnitudes.
					  • Start closer, with `InitialValues.supplied`, if you have a prior answer.
					Still moving: \(stillMoving.joined(separator: ", "))
					"""
			}
		}
	}
}

extension ConvergenceState {

	/// What was seen, as a phrase that fits into a sentence about the last few sweeps.
	///
	/// Deliberately an observation rather than a verdict: "growing from sweep to sweep" is
	/// something that happened, and "your model is wrong" is a claim the solver cannot support.
	var observed: String {
		switch self {
		case .diverging: return "growing from sweep to sweep"
		case .oscillating: return "alternating in sign without shrinking"
		case .exhausted: return "still shrinking, with further to go"
		}
	}
}

// MARK: - ModelDefinition

extension ModelDefinition {

	/// Evaluates every account, resolving cycles rather than refusing them.
	///
	/// ``evaluate()`` refuses any cycle, because it has no way of knowing whether one was
	/// intended. Calling `solve()` is that statement of intent: it says the cycles in this model
	/// are meant to be there and should be resolved.
	///
	/// ```swift
	/// // A fee charged on a total that includes the fee — the classic gross-up.
	/// let model = ModelDefinition<Double>(inputs: ["base": base])
	///     .defining("fee", as: "total * 0.10")
	///     .defining("total", as: "base + fee")
	///
	/// let values = try model.solve()   // total = base / 0.9, exactly
	/// ```
	///
	/// ## How a cycle is resolved
	///
	/// The model is split into strongly connected components and worked through in dependency
	/// order, so an account outside a cycle is evaluated once and a cycle is reached with
	/// everything it reads already known. That matters at any size: a model with four hundred
	/// accounts and one three-account cycle does three hundred and ninety-seven single
	/// evaluations and solves three simultaneously.
	///
	/// A cycle whose ``DependencyCycle/form`` is ``DependencyCycle/Form/linear`` is a
	/// simultaneous linear system in its members, and is solved **exactly** — the coefficients
	/// are read off the parse tree, one *n*×*n* system is built per period, and Gaussian
	/// elimination gives the answer. There is no tolerance and no iteration count, because there
	/// is nothing to converge to: the answer solves the equations as written, to within the
	/// rounding of the same arithmetic done by hand.
	///
	/// A cycle that is ``DependencyCycle/Form/nonlinear`` has no exact answer to extract, so it
	/// is iterated: Gauss–Seidel sweeps in sorted account order, optionally damped, from a
	/// starting iterate you can name. `settings` governs that and nothing else — a linear cycle
	/// reads none of it.
	///
	/// ## What it refuses
	///
	/// - A cycle that does not settle, with
	///   ``CycleSolverError/notConverged(accounts:state:iterations:finalChange:stillMoving:)``,
	///   carrying what the change was observed doing, how many sweeps were spent, how far the
	///   last one moved, and which accounts were still moving. It is a throw and not a flag on a
	///   returned struct: an unconverged iterate looks exactly like an answer.
	/// - A linear cycle with more than one solution, with
	///   ``CycleSolverError/underdetermined(accounts:period:detail:)``.
	/// - A linear cycle whose answer would be numerical noise, with
	///   ``CycleSolverError/illConditioned(accounts:period:detail:)``.
	///
	/// ## What it cannot express
	///
	/// The same thing ``evaluate()`` cannot: a reference to another period. A cycle here is a
	/// cycle *within* one period. An opening balance is supplied as data and the roll-forward
	/// that carries a closing balance into the next period stays the caller's loop.
	///
	/// - Parameter settings: How hard to try on the cycles that must be iterated, and from
	///   where. Ignored by cycles that are solved exactly.
	/// - Returns: Every account, supplied and derived, by name.
	/// - Throws: ``CycleSolverError`` when a cycle has no usable answer;
	///   ``BusinessMathError/inconsistentData(description:)`` when an account is both supplied
	///   and derived; ``FormulaError`` for a missing account or a formula that cannot be read.
	public func solve(
		settings: IterationSettings<T> = IterationSettings()
	) throws -> [String: TimeSeries<T>] {
		let report = try dependencyReport()
		try refuseUnusableDefinitions(report)

		var accounts = inputs
		for component in report.components {
			if let cycle = report.cycles.first(where: { $0.accounts == component }) {
				try resolve(cycle, into: &accounts, settings: settings)
			} else if let name = component.first, let formula = formula(for: name) {
				accounts[name] = try FormulaEvaluator(accounts: accounts).evaluate(formula)
			}
		}
		return accounts
	}

	/// Refuses a definition set that cannot be evaluated whichever route is taken through it.
	///
	/// Both checks run before anything is computed, so a model is refused for the same reason
	/// whichever account would have been reached first. Shared by ``evaluate()`` and
	/// ``solve()``: resolving cycles changes what happens to a cycle, and nothing about what a
	/// usable set of definitions is.
	///
	/// - Parameter report: This model's dependency report.
	/// - Throws: ``BusinessMathError/inconsistentData(description:)`` when an account is both
	///   supplied and derived; ``FormulaError/unknownAccount(_:)`` when a required input is
	///   missing.
	func refuseUnusableDefinitions(_ report: DependencyReport) throws {
		if let collision = definitions.map(\.name).sorted().first(where: { inputs[$0] != nil }) {
			throw BusinessMathError.inconsistentData(
				description: """
					'\(collision)' is supplied as an input and also defined by a formula. \
					Remove one: a derived account would shadow the supplied series, and \
					nothing downstream could tell which had been used.
					"""
			)
		}
		if let missing = report.requiredInputs.first(where: { inputs[$0] == nil }) {
			throw FormulaError.unknownAccount(missing)
		}
	}

	/// Resolves one cycle in place, leaving every member at its solved value.
	///
	/// The routing decision, and the only place it is made: a linear cycle goes to elimination
	/// and a nonlinear one to iteration. Nothing here chooses to iterate something that has an
	/// exact answer, which is the difference between this and a spreadsheet.
	private func resolve(
		_ cycle: DependencyCycle,
		into accounts: inout [String: TimeSeries<T>],
		settings: IterationSettings<T>
	) throws {
		let formulas = cycle.accounts.reduce(into: [String: String]()) { formulas, member in
			formulas[member] = formula(for: member)
		}

		let solved: [String: TimeSeries<T>]
		switch cycle.form {
		case .linear:
			solved = try LinearCycleSolver<T>(
				accounts: accounts,
				members: cycle.accounts,
				formulas: formulas
			).solve()
		case .nonlinear:
			solved = try IterativeCycleSolver<T>(
				accounts: accounts,
				sweepOrder: cycle.accounts,
				formulas: formulas,
				settings: settings
			).solve()
		}

		// Written back in the cycle's own sorted order rather than by iterating the result,
		// so nothing about the model depends on dictionary order even in principle.
		for member in cycle.accounts {
			accounts[member] = solved[member]
		}
	}
}
