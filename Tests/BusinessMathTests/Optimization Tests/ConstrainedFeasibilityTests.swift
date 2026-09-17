import Testing
import Foundation
@testable import BusinessMath

/// A constrained optimizer must return a point that satisfies its constraints, or say it could not.
///
/// ## The defect this suite was written for
///
/// `minimize(_:from:constraints:)` on every heuristic optimizer routed constraints through a
/// fixed-weight quadratic penalty and then **never checked the result**. `converged` was passed
/// straight through from the unconstrained search on the penalised objective — it reported that
/// the simplex had settled, which says nothing about feasibility — and `value` was the
/// *unpenalised* objective at a point that did not satisfy the constraints.
///
/// The shortfall is not noise. A quadratic penalty of weight `w` on `min ‖x‖²` subject to
/// `x₀ ≥ 3` has its minimum at `x₀ = 3w/(1 + w)`, so the method converges to the constraint only
/// as `w → ∞`:
///
/// | `w` | returned `x₀` | violation | reported value |
/// |---|---|---|---|
/// | 100 (the default) | 2.9702970 | 3.0e-2 | 8.8227 |
/// | 10³ | 2.9970030 | 3.0e-3 | 8.9820 |
/// | 10⁶ | 2.9999970 | 3.0e-6 | 8.99998 |
/// | 10⁹ | 2.9999999970 | 3.0e-9 | 8.99999998 |
///
/// The true constrained optimum is **9**, at (3, 0, 0). Every row reports a value *below* it,
/// and that is the damaging part: violating the constraint lowers the reported objective, so a
/// caller comparing two designs prefers whichever one breaks its constraints hardest.
///
/// It also scales with the objective's magnitude, so the error depends on the units the caller
/// happened to choose. On `min 1000‖x‖²` with the same constraint and the same default weight,
/// the returned `x₀` is **0.2727** — a 91% violation — reported at 74.38 against a true optimum
/// of 9000.
///
/// ## What is asserted here
///
/// Feasibility is a **requirement**, not a quality metric. There is no objective value good
/// enough to justify returning a point outside the feasible set, because a threshold is a
/// threshold: a minimum order quantity, a capital adequacy floor, a staffing level. The only
/// legitimate slack is numerical.
@Suite("Constrained optimizers return feasible points")
struct ConstrainedFeasibilityTests {

	typealias Vec = VectorN<Double>

	/// How far outside the feasible set a point may sit and still count as feasible.
	///
	/// Numerical slack only. Wide enough to absorb floating-point error in evaluating the
	/// constraint, far too narrow to absorb the 3e-2 a default-weight penalty leaves behind.
	static let feasibilityTolerance: Double = 1e-7

	// MARK: - Problems with a closed-form constrained optimum

	struct Problem {
		let name: String
		let objective: @Sendable (Vec) -> Double
		let constraints: [MultivariateConstraint<Vec>]
		/// The constrained optimum, by hand.
		let optimum: Double
		let argmin: [Double]
	}

	/// `min k‖x‖²` subject to `x₀ ≥ b`, whose optimum is `k·b²` at `(b, 0, 0)`.
	///
	/// The scale factor `k` is the point of the fixture rather than decoration: a penalty weight
	/// is compared against the objective's magnitude, so the same geometry at `k = 1000` is where
	/// a fixed weight fails hardest.
	private static func floored(_ b: Double, scale k: Double, _ label: String) -> Problem {
		Problem(
			name: "min \(label)‖x‖² s.t. x₀ ≥ \(b)",
			objective: { point in k * point.toArray().reduce(0) { $0 + $1 * $1 } },
			constraints: [.linearInequality(coefficients: [1, 0, 0], rhs: b, sense: .greaterOrEqual)],
			optimum: k * b * b,
			argmin: [b, 0, 0]
		)
	}

	/// `min k‖x‖²` subject to `x₀ + x₁ + x₂ = s`, whose optimum is `k·s²/3` at `(s/3, s/3, s/3)`.
	private static func onPlane(_ s: Double, scale k: Double, _ label: String) -> Problem {
		Problem(
			name: "min \(label)‖x‖² s.t. Σx = \(s)",
			objective: { point in k * point.toArray().reduce(0) { $0 + $1 * $1 } },
			constraints: [.linearEquality(coefficients: [1, 1, 1], rhs: s)],
			optimum: k * s * s / 3.0,
			argmin: [s / 3, s / 3, s / 3]
		)
	}

	static let problems: [Problem] = [
		floored(3, scale: 1, "") ,
		floored(3, scale: 1000, "1000·"),
		floored(3, scale: 0.001, "0.001·"),
		onPlane(6, scale: 1, ""),
		onPlane(6, scale: 1000, "1000·"),
		onPlane(6, scale: 0.001, "0.001·")
	]

	/// The worst constraint violation at a point: zero when feasible.
	static func worstViolation(_ point: Vec, _ constraints: [MultivariateConstraint<Vec>]) -> Double {
		var worst = 0.0
		for constraint in constraints {
			let g = constraint.evaluate(at: point)
			let amount = constraint.isEquality ? Swift.abs(g) : Swift.max(0, g)
			worst = Swift.max(worst, amount)
		}
		return worst
	}

	// MARK: - Every optimizer, every problem

	static func searchSpace(_ dimension: Int) -> [(lower: Double, upper: Double)] {
		Array(repeating: (lower: -20.0, upper: 20.0), count: dimension)
	}

	/// Every constrained entry point, run on one problem.
	static func solveEveryWay(_ problem: Problem) throws -> [(String, MultivariateOptimizationResult<Vec>)] {
		let start = Vec([0.0, 0.0, 0.0])
		let space = searchSpace(3)
		var results: [(String, MultivariateOptimizationResult<Vec>)] = []

		results.append((
			"NelderMead",
			try NelderMead<Vec>().minimize(problem.objective, from: start, constraints: problem.constraints)
		))
		results.append((
			"DifferentialEvolution",
			try DifferentialEvolution<Vec>(config: .init(seed: 20_260_917), searchSpace: space)
				.minimize(problem.objective, from: start, constraints: problem.constraints)
		))
		results.append((
			"ParticleSwarm",
			try ParticleSwarmOptimization<Vec>(config: .init(seed: 20_260_917), searchSpace: space)
				.minimize(problem.objective, from: start, constraints: problem.constraints)
		))
		results.append((
			"SimulatedAnnealing",
			try SimulatedAnnealing<Vec>(config: .init(seed: 20_260_917), searchSpace: space)
				.minimize(problem.objective, from: start, constraints: problem.constraints)
		))
		return results
	}

	/// The claim. A returned point satisfies its constraints, or the result says it does not.
	@Test("A returned point is feasible, or the result says it is not",
		  arguments: problems.indices)
	func returnedPointIsFeasibleOrDeclared(_ index: Int) throws {
		let problem = Self.problems[index]

		for (who, result) in try Self.solveEveryWay(problem) {
			let violation: Double = Self.worstViolation(result.solution, problem.constraints)
			let feasible: Bool = violation <= Self.feasibilityTolerance

			if feasible {
				#expect(result.terminationReason != .infeasible,
						"\(who) on \(problem.name): feasible at violation \(violation), yet reported infeasible")
			} else {
				#expect(result.terminationReason == .infeasible,
						"\(who) on \(problem.name): violation \(violation) at \(result.solution.toArray()), reported \(result.terminationReason)")
				#expect(!result.converged,
						"\(who) on \(problem.name): violation \(violation) and converged == true")
			}

			// Whatever the status, the reported violation must be the one actually present.
			let reportedError: Double = abs(result.constraintViolation - violation)
			#expect(reportedError < 1e-9,
					"\(who) on \(problem.name): reported violation \(result.constraintViolation), actual \(violation)")
		}
	}

	/// Every one of these problems has a feasible optimum, so every solve must find one.
	///
	/// Separate from the claim above because they fail differently: that one catches a solver
	/// that lies about its answer, this one catches a solver that gives up on a solvable problem.
	@Test("A problem with a feasible optimum is solved feasibly", arguments: problems.indices)
	func feasibleProblemsAreSolved(_ index: Int) throws {
		let problem = Self.problems[index]

		for (who, result) in try Self.solveEveryWay(problem) {
			let violation: Double = Self.worstViolation(result.solution, problem.constraints)
			#expect(violation <= Self.feasibilityTolerance,
					"\(who) on \(problem.name): violation \(violation) at \(result.solution.toArray()), and a feasible optimum exists at \(problem.argmin)")
		}
	}

	/// The reported value is the objective at the reported point, and never better than the
	/// constrained optimum.
	///
	/// The second half is what the penalty method broke: an infeasible point scores below the
	/// true optimum, so the number looks like an improvement. A minimisation that reports less
	/// than is attainable is worse than one that reports more.
	@Test("The reported value is attainable and matches the point", arguments: problems.indices)
	func reportedValueIsAttainable(_ index: Int) throws {
		let problem = Self.problems[index]
		let scale: Double = Swift.max(1.0, Swift.abs(problem.optimum))

		for (who, result) in try Self.solveEveryWay(problem) {
			let recomputed: Double = problem.objective(result.solution)
			let identityError: Double = abs(result.value - recomputed)
			#expect(identityError < 1e-9 * scale,
					"\(who) on \(problem.name): reported \(result.value), objective at the point is \(recomputed)")

			// A feasible point cannot beat the constrained optimum. Slack is one part in 10^6 of
			// the problem's scale, which is search quality, not a licence to be below it.
			let shortfall: Double = problem.optimum - recomputed
			#expect(shortfall < 1e-6 * scale,
					"\(who) on \(problem.name): reported \(recomputed), below the attainable optimum \(problem.optimum) by \(shortfall)")
		}
	}

	/// Genuinely conflicting constraints return the least-violating point, not a throw.
	///
	/// `x₀ ≥ 5` and `x₀ ≤ 2` cannot both hold. The modeller wants to see *which* constraint is
	/// the problem and by how much — that is usually a modelling error to be corrected, not an
	/// exception to be caught — so the result carries the near-miss and says it is infeasible.
	@Test("Conflicting constraints report infeasible with the least-violating point")
	func conflictingConstraintsReportInfeasible() throws {
		let conflicting: [MultivariateConstraint<Vec>] = [
			.linearInequality(coefficients: [1, 0, 0], rhs: 5, sense: .greaterOrEqual),
			.linearInequality(coefficients: [1, 0, 0], rhs: 2, sense: .lessOrEqual)
		]
		let objective: @Sendable (Vec) -> Double = { point in
			point.toArray().reduce(0) { $0 + $1 * $1 }
		}
		let problem = Problem(name: "x₀ ≥ 5 and x₀ ≤ 2", objective: objective,
							  constraints: conflicting, optimum: .nan, argmin: [])

		for (who, result) in try Self.solveEveryWay(problem) {
			#expect(result.terminationReason == .infeasible,
					"\(who): conflicting constraints reported \(result.terminationReason)")
			#expect(result.constraintViolation > 0,
					"\(who): reported infeasible with a violation of \(result.constraintViolation)")

			// The least-violating point for this pair sits between the two bounds, so the
			// violation cannot exceed the gap between them. A result that walked off to the
			// search-space edge would be feasible for neither and useless for diagnosis.
			#expect(result.constraintViolation <= 3.0 + Self.feasibilityTolerance,
					"\(who): violation \(result.constraintViolation) exceeds the 3.0 gap between the bounds")
		}
	}
}
