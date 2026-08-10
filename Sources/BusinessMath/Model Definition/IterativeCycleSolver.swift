//
//  IterativeCycleSolver.swift
//  BusinessMath
//

import Foundation
import RealModule

// MARK: - ConvergenceState

/// What an iteration was observed doing when it stopped.
///
/// Three states rather than one, because they call for three different things and a single
/// "did not converge" would send every reader to the same wrong remedy. Each is a statement
/// about the sequence of changes that was seen, not a diagnosis of the model's economics.
public enum ConvergenceState: Sendable, Hashable {

	/// The change grew from sweep to sweep, with a constant sign, or the values stopped being
	/// finite.
	///
	/// The loop amplifies. No tolerance, iteration cap or damping factor fixes that — the
	/// structure feeds back on itself with a gain above one, and it is the model that has to
	/// change.
	case diverging

	/// The change alternated in sign without shrinking.
	///
	/// The iterate steps past the answer and back again. This is the case
	/// ``IterationSettings/relaxation`` exists for: a factor below 1 shortens each step and
	/// usually settles it.
	case oscillating

	/// None of the above, and the sweeps ran out.
	///
	/// The change may have been shrinking steadily and simply had further to go, or it may have
	/// stalled near the limit of what the arithmetic can resolve. The final change reported
	/// alongside is what tells the two apart.
	case exhausted
}

// MARK: - InitialValues

/// Where an iteration starts.
///
/// Enumerated rather than defaulted to whatever data happens to be loaded, because the starting
/// iterate changes the trajectory, the number of sweeps, and — for a nonlinear cycle with more
/// than one fixed point — which answer comes back. A start that depended on load order would
/// make the answer depend on load order.
public enum InitialValues<T: Real & Sendable>: Sendable {

	/// Every member starts at zero.
	///
	/// The default, because it is the one a reader can predict without knowing anything about
	/// the caller.
	case zero

	/// A warm start, by account name.
	///
	/// A member with no entry starts at zero; entries for accounts outside the cycle are
	/// ignored, since everything outside it is already known.
	case supplied([String: TimeSeries<T>])
}

// MARK: - IterationSettings

/// How hard to try, and from where.
///
/// Passed to ``ModelDefinition/solve(settings:)`` rather than stored on the model: an iteration
/// budget is a property of the question being asked, not of the thing being modelled. The same
/// definitions can be explored at a loose tolerance and published at a tight one.
///
/// These apply only to cycles that must be iterated. A cycle that is
/// ``DependencyCycle/Form/linear`` is solved exactly and reads none of them.
public struct IterationSettings<T: Real & Sendable>: Sendable {

	/// How many sweeps to spend before giving up. Defaults to 100, as Excel does.
	public var maxIterations: Int

	/// A change this small or smaller counts as settled. Defaults to 1e-9.
	public var absoluteTolerance: T

	/// A change this small relative to the value counts as settled. Defaults to 1e-9.
	///
	/// Both are checked and either satisfies. An absolute threshold alone is meaningless across
	/// a model where cash is in the billions and a margin is 0.4.
	public var relativeTolerance: T

	/// How much of each computed step to take — `ω` in `x + ω·(F(x) − x)`. Defaults to 1.
	///
	/// Below 1 damps: it shortens every step, which stabilises a cycle that overshoots and back
	/// again at the cost of more sweeps. Above 1 over-relaxes, which can be faster on a slow
	/// cycle and can destabilise one that was working. It is a constant, deliberately: an
	/// adaptive factor would make the answer depend on the trajectory, and a change in
	/// convergence behaviour indistinguishable from a change in the model.
	public var relaxation: T

	/// Where the iteration starts. Defaults to ``InitialValues/zero``.
	public var initialValues: InitialValues<T>

	/// Creates a set of settings.
	///
	/// - Parameters:
	///   - maxIterations: Sweeps to spend before giving up.
	///   - absoluteTolerance: A change at or below this counts as settled.
	///   - relativeTolerance: A change at or below this share of the value counts as settled.
	///   - relaxation: The share of each computed step to take.
	///   - initialValues: Where to start.
	public init(
		maxIterations: Int = 100,
		absoluteTolerance: T = T(1) / T(1_000_000_000),
		relativeTolerance: T = T(1) / T(1_000_000_000),
		relaxation: T = T(1),
		initialValues: InitialValues<T> = .zero
	) {
		self.maxIterations = maxIterations
		self.absoluteTolerance = absoluteTolerance
		self.relativeTolerance = relativeTolerance
		self.relaxation = relaxation
		self.initialValues = initialValues
	}
}

// MARK: - IterativeCycleSolver

/// Gauss–Seidel over one cycle, with damping, that refuses to return an unsettled iterate.
///
/// ## The method
///
/// Each sweep evaluates every member's formula in turn and writes the result back immediately,
/// so a member later in the sweep sees this sweep's values for the members before it. That is
/// what makes Gauss–Seidel worth having over Jacobi on a financial model: models are nearly
/// triangular — a long chain with a small feedback edge closing it — so one sweep propagates
/// information the whole way round rather than one edge at a time.
///
/// ## Determinism
///
/// Updating in place makes the trajectory depend on the order, so the order is not allowed to be
/// an accident. ``sweepOrder`` is a stored array, sorted by account name, and the starting
/// iterate is enumerated by ``InitialValues`` rather than taken from whatever is loaded. Nothing
/// in a sweep reads a `Set` or a `Dictionary` in iteration order.
///
/// The order is part of the contract, because it is visible in the last digits of the answer and
/// in how many sweeps it took.
struct IterativeCycleSolver<T: Real & Sendable & LosslessStringConvertible> {

	/// Everything already known: the supplied inputs and every component solved before this one.
	let accounts: [String: TimeSeries<T>]

	/// The cycle's members in the order each sweep visits them — sorted by name.
	let sweepOrder: [String]

	/// Each member's formula.
	let formulas: [String: String]

	/// How hard to try, and from where.
	let settings: IterationSettings<T>

	/// The periods a starting value spans: every period any known account covers.
	private var universe: [Period] {
		accounts.values
			.reduce(into: Set<Period>()) { $0.formUnion($1.periods) }
			.sorted()
	}

	/// Iterates the cycle to a fixed point.
	///
	/// - Returns: Each member's settled series.
	/// - Throws: ``CycleSolverError/notConverged(accounts:state:iterations:finalChange:stillMoving:)``
	///   when the cycle does not settle; ``FormulaError`` when a formula cannot be read.
	func solve() throws -> [String: TimeSeries<T>] {
		var current = startingValues()
		var magnitudes: [T] = []
		var signs: [Int] = []
		var stillMoving: [String] = sweepOrder
		var lastChange = T.infinity
		var sweepsUsed = 0

		while sweepsUsed < settings.maxIterations {
			sweepsUsed += 1
			let sweep = try sweepOnce(from: &current)

			guard sweep.finite else {
				throw notConverged(.diverging, sweepsUsed, sweep.change, sweepOrder)
			}

			magnitudes.append(sweep.change)
			signs.append(sweep.sign)
			stillMoving = sweep.moving
			lastChange = sweep.change

			if sweep.moving.isEmpty { return current }
		}

		throw notConverged(
			state(magnitudes: magnitudes, signs: signs),
			sweepsUsed,
			lastChange,
			stillMoving
		)
	}

	// MARK: - One sweep

	/// What a single sweep did.
	private struct Sweep {

		/// The largest change any member made, over any period.
		let change: T

		/// The sign of that change: `1`, `-1`, or `0`.
		let sign: Int

		/// The members whose change exceeded both tolerances, sorted.
		let moving: [String]

		/// Whether every value written is still a number.
		let finite: Bool
	}

	/// Evaluates every member once, in ``sweepOrder``, writing each result back before the next.
	private func sweepOnce(from current: inout [String: TimeSeries<T>]) throws -> Sweep {
		var known = accounts
		for member in sweepOrder {
			known[member] = current[member]
		}

		var change = T(0)
		var sign = 0
		var moving: [String] = []

		for member in sweepOrder {
			guard let formula = formulas[member] else { throw FormulaError.unknownAccount(member) }
			let previous = known[member] ?? TimeSeries(periods: [], values: [])
			let updated = relaxed(previous, try FormulaEvaluator(accounts: known).evaluate(formula))

			guard updated.valuesArray.allSatisfy({ $0.isFinite }) else {
				return Sweep(change: T.infinity, sign: 0, moving: sweepOrder, finite: false)
			}

			let step = self.step(from: previous, to: updated)
			if step.magnitude > change {
				change = step.magnitude
				sign = step.sign
			}
			if step.moving { moving.append(member) }

			current[member] = updated
			known[member] = updated
		}

		return Sweep(change: change, sign: sign, moving: moving, finite: true)
	}

	/// Applies the relaxation factor, taking `ω` of the computed step.
	///
	/// A factor of exactly 1 short-circuits to the computed value, so the ordinary case adds no
	/// arithmetic and cannot introduce a rounding difference of its own.
	private func relaxed(_ previous: TimeSeries<T>, _ computed: TimeSeries<T>) -> TimeSeries<T> {
		guard settings.relaxation != T(1) else { return computed }
		let omega = TimeSeries(
			periods: computed.periods,
			values: Array(repeating: settings.relaxation, count: computed.count)
		)
		return previous + omega * (computed - previous)
	}

	/// The size and direction of one member's move, and whether it counts as settled.
	///
	/// Settled when the change is within the absolute tolerance **or** within the relative
	/// tolerance of the new value, per period. Either satisfies, because a model holding both
	/// cash in the billions and a margin of 0.4 has no single threshold that means anything in
	/// both places.
	private func step(from previous: TimeSeries<T>, to updated: TimeSeries<T>)
		-> (magnitude: T, sign: Int, moving: Bool) {
		var magnitude = T(0)
		var sign = 0
		var moving = false

		for period in updated.periods {
			guard let new = updated[period] else { continue }
			let delta = new - (previous[period] ?? T(0))
			let size = abs(delta)

			if size > magnitude {
				magnitude = size
				sign = delta > T(0) ? 1 : (delta < T(0) ? -1 : 0)
			}
			if size > settings.absoluteTolerance && size > settings.relativeTolerance * abs(new) {
				moving = true
			}
		}

		return (magnitude, sign, moving)
	}

	// MARK: - Starting, and stopping

	/// The starting iterate, by name.
	private func startingValues() -> [String: TimeSeries<T>] {
		let span = universe
		let zero = TimeSeries(periods: span, values: Array(repeating: T(0), count: span.count))

		switch settings.initialValues {
		case .zero:
			return sweepOrder.reduce(into: [String: TimeSeries<T>]()) { $0[$1] = zero }
		case .supplied(let supplied):
			return sweepOrder.reduce(into: [String: TimeSeries<T>]()) { $0[$1] = supplied[$1] ?? zero }
		}
	}

	/// Classifies what the sequence of changes was observed doing.
	///
	/// Reported as the state *seen*, over a window of the last four sweeps, and not as an
	/// assertion about the model. "The change alternated in sign four times without shrinking"
	/// is an observation; "your model is wrong" is not, and a confident wrong cause is worse
	/// than an honest list of possibilities.
	///
	/// Alternation is tested before growth, because a cycle that overshoots and grows is one
	/// damping can still rescue, and telling its author to reformulate would be the more
	/// expensive wrong answer.
	private func state(magnitudes: [T], signs: [Int]) -> ConvergenceState {
		let window = 4
		guard magnitudes.count >= window else { return .exhausted }

		let recent = Array(magnitudes.suffix(window))
		let recentSigns = Array(signs.suffix(window))

		let alternating = zip(recentSigns, recentSigns.dropFirst())
			.allSatisfy { $0 != 0 && $1 != 0 && $0 != $1 }
		if alternating, let first = recent.first, let last = recent.last, last >= first {
			return .oscillating
		}

		if zip(recent, recent.dropFirst()).allSatisfy({ $1 > $0 }) { return .diverging }

		return .exhausted
	}

	/// Builds the refusal, carrying everything a caller needs to decide what to do next.
	private func notConverged(
		_ state: ConvergenceState,
		_ iterations: Int,
		_ change: T,
		_ stillMoving: [String]
	) -> CycleSolverError {
		.notConverged(
			accounts: sweepOrder,
			state: state,
			iterations: iterations,
			finalChange: reportable(change),
			stillMoving: stillMoving.sorted()
		)
	}

	/// Widens a change magnitude for reporting.
	///
	/// The diagnostic is a magnitude, not a figure in the model, so it is carried as a `Double`
	/// rather than making every `catch` site name the model's numeric type. Every floating-point
	/// type this can be used with round-trips through its own description; one that did not
	/// would report an unbounded change rather than a flattering small one.
	private func reportable(_ change: T) -> Double {
		Double(change.description) ?? .infinity
	}
}
