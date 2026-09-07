//
//  TimeLimitEnforcementTests.swift
//  BusinessMath
//
//  A time limit that is only checked between nodes is not a time limit.
//
//  `BranchAndBoundSolver` tests `timeLimit` at the top of its node loop. Once a
//  node begins there is no way to interrupt it, so the guarantee a caller actually
//  gets is "the limit, plus however long one node takes" — and a node is an
//  arbitrary nonlinear program over a caller-supplied objective, so that second
//  term is unbounded.
//
//  Measured before this was fixed: the MINLP portfolio model configured with
//  `timeLimit: 30.0` ran for 93 seconds, because one node spent 78 of them inside
//  a stalled BFGS. Fixing the stall removed that particular node, but not the
//  structural problem: any sufficiently expensive objective reproduces it, and a
//  caller who sets a limit to stay responsive is entitled to get one.
//
//  The objective below is deliberately costly rather than artificially slow — no
//  sleeping, just arithmetic — because that is what an expensive model looks like
//  and it is what the deadline has to survive.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Branch-and-bound honours its time limit")
struct TimeLimitEnforcementTests {

	/// An objective that costs real time to evaluate.
	///
	/// The loop is summed into the result so the optimiser cannot be lifted out of
	/// it, and the value is still a smooth function of the point, so the search
	/// behaves normally — just slowly. Used only by the expired-deadline test, where
	/// the point is that even an expensive evaluation does not delay the exit.
	private static func expensiveObjective(_ point: VectorN<Double>) -> Double {
		let values = point.toArray()
		var accumulated = 0.0
		for step in 0..<4_000 {
			let angle: Double = Double(step) * 1e-4
			accumulated += Foundation.sin(angle) * 1e-12
		}
		var total = accumulated
		for value in values {
			let centred: Double = value - 2.5
			total += centred * centred
		}
		return total
	}

	@Test("A deadline already past stops the search before its first step")
	func expiredDeadlineStopsImmediately() throws {
		// The mechanism, tested without a clock: hand it a deadline in the past and
		// the answer is not "soon", it is "now". Deterministic under any load, which
		// the end-to-end timing test below cannot be.
		let expired = ContinuousClock().now - .seconds(60)
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 10_000, tolerance: 1e-12, useLineSearch: true,
			recordHistory: false, deadline: expired)

		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			return values[0] * values[0] + values[1] * values[1]
		}
		let result = try optimizer.minimizeBFGS(
			function: objective,
			gradient: { point in VectorN(point.toArray().map { 2 * $0 }) },
			initialGuess: VectorN([10.0, -7.0]))

		#expect(result.iterations == 0, "an expired deadline still took \(result.iterations) iterations")
		#expect(!result.converged, "an expired deadline reported convergence")
		// It must still hand back the point it was given rather than nothing.
		#expect(result.solution.toArray() == [10.0, -7.0],
				"the starting point was not returned: \(result.solution.toArray())")
	}

	@Test("A deadline in the future does not interfere")
	func futureDeadlineIsInert() throws {
		// The other half: a deadline that cannot bind must change nothing, or the
		// test above would pass for a solver that simply never runs.
		let generous = ContinuousClock().now + .seconds(600)
		let optimizer = MultivariateNewtonRaphson<VectorN<Double>>(
			maxIterations: 10_000, tolerance: 1e-10, useLineSearch: true,
			recordHistory: false, deadline: generous)

		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			let first: Double = values[0] - 3
			let second: Double = values[1] + 2
			return first * first + 4 * second * second
		}
		let result = try optimizer.minimizeBFGS(
			function: objective,
			gradient: { point in
				let values = point.toArray()
				return VectorN([2 * (values[0] - 3), 8 * (values[1] + 2)])
			},
			initialGuess: VectorN([-5.0, 7.0]))

		#expect(result.converged, "a generous deadline prevented convergence")
		#expect(abs(result.solution.toArray()[0] - 3) < 1e-6)
		#expect(abs(result.solution.toArray()[1] + 2) < 1e-6)
	}

	@Test("The relaxation solver passes an expired deadline through")
	func relaxationHonoursAnExpiredDeadline() throws {
		// The plumbing between branch-and-bound and the inner search, checked at the
		// seam rather than through it.
		let expired = ContinuousClock().now - .seconds(60)
		var constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budget(total: 5.0, dimension: 2)
		]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2))

		let solver = NonlinearRelaxationSolver()
		let result = try solver.solveRelaxation(
			objective: Self.expensiveObjective,
			constraints: constraints,
			initialGuess: VectorN([2.0, 3.0]),
			minimize: true,
			deadline: expired)

		// Returning *something* matters as much as returning quickly: a node that
		// hands back nothing deletes the whole subtree below it.
		#expect(result.status == .optimal || result.status == .infeasible,
				"an expired deadline produced status \(result.status)")
	}

	@Test("A one-second limit stops after one second of modelled work")
	func timeLimitIsEnforcedWithinANode() throws {
		// No wall clock, and no sleeping. The counter advances only when the
		// objective is evaluated — ten milliseconds per call — so "one second" means
		// exactly one hundred evaluations, whatever the machine is doing. The
		// assertion is then about the solver rather than about the scheduler.
		//
		// Before the deadline reached inside the relaxation this was measured at
		// 153 seconds against a one-second limit, because `timeLimit` was only
		// tested between nodes and a node is an arbitrary program over the caller's
		// objective.
		let time = ManualElapsedTimeSource()
		let evaluations = Counter()
		let costPerEvaluation = Duration.milliseconds(10)

		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			time.advance(by: costPerEvaluation)
			evaluations.increment()
			let values = point.toArray()
			var total = 0.0
			for value in values {
				let centred: Double = value - 2.5
				total += centred * centred
			}
			return total
		}

		let dimension = 3
		var constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.budget(total: 7.0, dimension: dimension)
		]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: dimension))
		for i in 0..<dimension {
			constraints.append(.inequality { point in point[i] - 6.0 })
		}

		let limit = 1.0
		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 10_000,
			timeLimit: limit,
			relaxationSolver: NonlinearRelaxationSolver(elapsedTime: time),
			elapsedTime: time
		)

		let result = try solver.solve(
			objective: objective,
			from: VectorN(Array(repeating: 2.0, count: dimension)),
			subjectTo: constraints,
			integerSpec: .allInteger(dimension: dimension),
			minimize: true
		)

		// One second of modelled time is a hundred evaluations. The deadline can only
		// be tested at iteration boundaries and a single BFGS step costs several
		// evaluations, so the bound is generous — but it is a *fixed* bound, not one
		// that moves with the machine.
		let spent = evaluations.value
		#expect(spent < 400,
				"""
				a \(limit)s limit at \(costPerEvaluation) per evaluation spent \(spent) \
				evaluations — over four seconds of modelled work, so the deadline is not \
				reaching inside the relaxation (\(result.nodesExplored) nodes, status \(result.status))
				""")

		// And it must still answer. Running out of time is a legitimate outcome with
		// its own status; returning nothing, or claiming optimality it did not prove,
		// would not be.
		#expect(result.status == .timeLimit || result.status == .optimal || result.status == .feasible,
				"status was \(result.status)")
	}

	/// A counter the objective closure can increment from anywhere.
	///
	/// The closure is `@Sendable` and the solver may evaluate it from more than one
	/// context, so the count is guarded rather than a bare `var`.
	// Justification: The single mutable stored property (count) is protected by an NSLock; no unguarded access.
	private final class Counter: @unchecked Sendable {
		private var count = 0
		private let lock = NSLock()
		func increment() {
			lock.lock(); defer { lock.unlock() }
			count += 1
		}
		var value: Int {
			lock.lock(); defer { lock.unlock() }
			return count
		}
	}

	@Test("A generous limit still lets an easy problem finish and prove optimality")
	func aGenerousLimitDoesNotTruncate() throws {
		// The guard against a deadline that fires too eagerly: a small, fast problem
		// must still reach `.optimal` rather than being cut short.
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			return -(3.0 * values[0] + 4.0 * values[1])
		}
		var constraints: [MultivariateConstraint<VectorN<Double>>] = [
			.inequality { point in 2.0 * point[0] + 3.0 * point[1] - 11.0 }
		]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 2))
		for i in 0..<2 {
			constraints.append(.inequality { point in point[i] - 5.0 })
		}

		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 10_000, timeLimit: 120.0,
			relaxationSolver: NonlinearRelaxationSolver())
		let result = try solver.solve(
			objective: objective, from: VectorN([1.0, 1.0]),
			subjectTo: constraints, integerSpec: .allInteger(dimension: 2), minimize: true)

		#expect(result.status == .optimal, "status \(result.status) — a generous limit truncated an easy problem")
		for (index, value) in result.solution.toArray().enumerated() {
			#expect(abs(value - value.rounded()) < 1e-6,
					"variable \(index) came back at \(value), which is not an integer")
		}
	}
}
