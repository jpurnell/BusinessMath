import Testing
import Foundation
@testable import BusinessMath

/// Randomized integer programs checked against exhaustive enumeration.
///
/// ## Why this suite exists, when the audit had already been done
///
/// `project/checklists/completed/CURRENT_OracleAudit.md` audited branch-and-bound with exactly
/// the right oracle — *"exhaustive enumeration of the boxed integer points"* — found a
/// suboptimal answer reported as `.optimal`, fixed it, and marked Tier B complete. Two further
/// defects of the same shape survived that, and were found by running the same oracle over
/// **instances nobody chose**:
///
/// - A feasible subtree pruned as infeasible. `max 4x + 7y` subject to `7x+3y ≤ 19`,
///   `8x+2y ≤ 27`, `3x+7y ≤ 21` returned **18** against an optimum of **21**.
/// - An integral vertex read as fractional, cut away by a cut derived from `f₀ = 0.99999834`.
///   `max 2x + y` subject to `x + y ≤ 20` returned **38** against an optimum of **40**.
///
/// The difference was coverage, not method. A fixture set is chosen by someone reading the
/// code, so it samples the cases the author already had in mind; and every hand-chosen fixture
/// is well conditioned, because nobody writes down a polytope in order to branch it into a
/// feasible region that is a single point. **That geometry is manufactured by the algorithm.**
/// A fixed fixture set structurally cannot reach it, however good its oracle.
///
/// ## What makes this an oracle rather than a second opinion
///
/// The expected value is computed by enumerating every integer point in the box and taking the
/// best feasible one. No part of that touches the solver, the simplex, or any cut. It is slow
/// and it is right, which is the correct trade for a few hundred small instances.
///
/// ## Determinism
///
/// The generator is a linear congruential sequence from a fixed seed, so a failure reproduces
/// exactly and the failure message carries the instance that produced it. Nothing here depends
/// on the system random number generator or the clock.
@Suite("Integer programming: randomized audit")
struct IntegerProgramRandomizedAuditTests {

	// MARK: - Deterministic generation

	private struct Generator {
		var state: UInt64

		mutating func next(_ bound: Int) -> Int {
			state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
			return Int((state >> 33) % UInt64(bound))
		}
	}

	private struct Row {
		let coefficients: [Double]
		let rhs: Double
		let sense: ConstraintSense
	}

	private struct Instance: CustomStringConvertible {
		let objective: [Double]
		let rows: [Row]
		let minimize: Bool
		let binary: Bool

		var description: String {
			let direction = minimize ? "min" : "max"
			let kind = binary ? "binary" : "integer"
			let symbol: (ConstraintSense) -> String = { sense in
				switch sense {
				case .lessOrEqual: return "<="
				case .greaterOrEqual: return ">="
				case .equal: return "=="
				}
			}
			let constraints = rows
				.map { "\($0.coefficients) \(symbol($0.sense)) \($0.rhs)" }
				.joined(separator: ", ")
			return "\(direction) \(objective) [\(kind)] s.t. \(constraints)"
		}
	}

	/// What shape of instance a generator round produces.
	///
	/// Not `private`, because it is a parameter of a `@Test` and Swift Testing needs to see it.
	enum Shape: String, CaseIterable, Sendable {
		/// Dense positive coefficients with a right-hand side chosen independently, so the
		/// optimal face generally misses the lattice.
		case general
		/// Right-hand sides set to `c · p` for a lattice point `p`, so every row is **tight at an
		/// integer point**. This is the geometry branching manufactures — each bound slices the
		/// polytope thinner, and deep in a tree a feasible region that is a single point is
		/// ordinary. It is also the geometry a hand-written fixture never has.
		case tightAtLattice
		/// Mixes in `>=` rows, which bound from the other side and exercise the sign flip in the
		/// solver's canonical form.
		case withGreaterOrEqual
		/// Mixes in `==` rows, which have neither slack nor surplus.
		case withEquality
		/// All variables binary.
		case binary
	}

	/// One instance of the requested shape.
	///
	/// Two or three variables and one to three rows, with all coefficients positive and all
	/// variables non-negative. That combination is what makes the enumeration box provable — see
	/// ``variableCaps(_:)`` — and keeps the oracle cheap enough to run on every instance.
	private static func instance(_ rng: inout Generator, shape: Shape) -> Instance {
		let n = 2 + rng.next(2)
		let m = 1 + rng.next(3)
		let minimize = rng.next(2) == 0

		var objective: [Double] = []
		for _ in 0..<n { objective.append(Double(1 + rng.next(9))) }

		// The lattice point the tight shape anchors its rows to.
		var anchor: [Int] = []
		for _ in 0..<n { anchor.append(rng.next(6)) }

		var rows: [Row] = []
		for _ in 0..<m {
			var coefficients: [Double] = []
			for _ in 0..<n { coefficients.append(Double(1 + rng.next(8))) }

			var lattice = 0.0
			for index in 0..<n { lattice += coefficients[index] * Double(anchor[index]) }

			let rhs: Double
			let sense: ConstraintSense
			switch shape {
			case .general, .binary:
				rhs = Double(5 + rng.next(25))
				sense = .lessOrEqual
			case .tightAtLattice:
				rhs = lattice
				sense = .lessOrEqual
			case .withGreaterOrEqual:
				rhs = lattice
				sense = rng.next(3) == 0 ? .greaterOrEqual : .lessOrEqual
			case .withEquality:
				rhs = lattice
				sense = rng.next(4) == 0 ? .equal : .lessOrEqual
			}
			rows.append(Row(coefficients: coefficients, rhs: rhs, sense: sense))
		}

		return Instance(
			objective: objective,
			rows: rows,
			minimize: minimize,
			binary: shape == .binary
		)
	}

	// MARK: - The oracle

	/// A per-variable cap that **provably** contains the optimum.
	///
	/// Every coefficient is positive and every variable non-negative, so any `≤` or `=` row
	/// `c · x ≤ b` gives `x_j ≤ b / c_j` for each `j` with `c_j > 0`; the cap is the tightest
	/// such row. A `≥` row bounds from below and contributes nothing here.
	///
	/// This replaced a fixed box of 30, and the replacement is the point. A box that does not
	/// contain the optimum makes the oracle wrong rather than merely incomplete: for a
	/// maximisation it under-reports, so a *correct* solver reads as broken; for a minimisation
	/// it over-reports, so the failures point the other way. Three such false alarms appeared in
	/// the sweep that built this suite, every one of them the oracle's fault. An oracle needs its
	/// own correctness argument, and "comfortably larger than the coefficients" is not one.
	///
	/// - Returns: The caps, or `nil` when some variable is bounded by no row — the integer
	///   program may then be unbounded, and enumeration cannot answer it.
	private static func variableCaps(_ instance: Instance) -> [Int]? {
		let n = instance.objective.count
		var caps = Array(repeating: Int.max, count: n)

		for row in instance.rows where row.sense != .greaterOrEqual {
			for index in 0..<n where row.coefficients[index] > 0 {
				let limit = Int((row.rhs / row.coefficients[index]).rounded(.down))
				caps[index] = Swift.min(caps[index], limit)
			}
		}

		if caps.contains(Int.max) { return nil }
		if caps.contains(where: { $0 < 0 }) { return nil }
		return caps
	}

	/// The best feasible integer point, by enumeration over the proven box.
	///
	/// Deliberately naive. It shares no code with the solver and makes no use of duality,
	/// bounding or cuts, so agreement between the two is evidence rather than a tautology.
	private static func enumerate(_ instance: Instance, caps: [Int]) -> Double? {
		let n = instance.objective.count
		var best: Double? = nil
		var point = Array(repeating: 0, count: n)

		func visit(_ index: Int) {
			if index == n {
				for row in instance.rows {
					var lhs = 0.0
					for i in 0..<n { lhs += row.coefficients[i] * Double(point[i]) }
					switch row.sense {
					case .lessOrEqual: if lhs > row.rhs + 1e-9 { return }
					case .greaterOrEqual: if lhs < row.rhs - 1e-9 { return }
					case .equal: if abs(lhs - row.rhs) > 1e-9 { return }
					}
				}
				var value = 0.0
				for i in 0..<n { value += instance.objective[i] * Double(point[i]) }
				guard let current = best else { best = value; return }
				best = instance.minimize ? Swift.min(current, value) : Swift.max(current, value)
				return
			}
			let top = instance.binary ? Swift.min(1, caps[index]) : caps[index]
			guard top >= 0 else { return }
			for candidate in 0...top {
				point[index] = candidate
				visit(index + 1)
			}
		}
		visit(0)
		return best
	}

	/// How many points the box holds, so an instance too large to enumerate is skipped rather
	/// than allowed to dominate the suite's runtime.
	private static func boxSize(_ caps: [Int], binary: Bool) -> Int {
		var total = 1
		for cap in caps {
			let top = binary ? Swift.min(1, cap) : cap
			guard top >= 0 else { return 0 }
			let (product, overflow) = total.multipliedReportingOverflow(by: top + 1)
			if overflow { return Int.max }
			total = product
		}
		return total
	}

	private static func solve(
		_ instance: Instance,
		with solver: BranchAndBoundSolver<VectorN<Double>>
	) throws -> IntegerOptimizationResult<VectorN<Double>> {
		let n = instance.objective.count
		let coefficients = instance.objective
		let objective: @Sendable (VectorN<Double>) -> Double = { point in
			let values = point.toArray()
			var total = 0.0
			for i in 0..<Swift.min(values.count, coefficients.count) {
				total += values[i] * coefficients[i]
			}
			return total
		}
		let constraints: [MultivariateConstraint<VectorN<Double>>] = instance.rows.map {
			.linearInequality(coefficients: $0.coefficients, rhs: $0.rhs, sense: $0.sense)
		}
		let spec = instance.binary
			? IntegerProgramSpecification.allBinary(dimension: n)
			: IntegerProgramSpecification(integerVariables: Set(0..<n), binaryVariables: [])

		return try solver.solve(
			objective: objective,
			from: VectorN(Array(repeating: 0.0, count: n)),
			subjectTo: constraints,
			integerSpec: spec,
			minimize: instance.minimize
		)
	}

	// MARK: - Configurations under test

	/// Every configuration must agree with enumeration. A knob is a performance choice, and a
	/// performance choice that changes the answer is a defect by definition.
	private static func configurations() -> [(String, BranchAndBoundSolver<VectorN<Double>>)] {
		[
			("default", BranchAndBoundSolver()),
			("depthFirst", BranchAndBoundSolver(nodeSelection: .depthFirst)),
			("breadthFirst", BranchAndBoundSolver(nodeSelection: .breadthFirst)),
			("pseudoCost", BranchAndBoundSolver(branchingRule: .pseudoCost)),
			("strongBranching", BranchAndBoundSolver(branchingRule: .strongBranching)),
			("variableShifting", BranchAndBoundSolver(enableVariableShifting: true)),
			("cuts", BranchAndBoundSolver(enableCuttingPlanes: true, maxCuttingRounds: 10)),
			("cuts+cover", BranchAndBoundSolver(
				enableCuttingPlanes: true, maxCuttingRounds: 10, enableCoverCuts: true)),
			("cuts+MIR", BranchAndBoundSolver(
				enableCuttingPlanes: true, maxCuttingRounds: 10, enableMIRCuts: true)),
			("cuts+noAging", BranchAndBoundSolver(
				enableCuttingPlanes: true, maxCuttingRounds: 10, enableCutAging: false))
		]
	}

	/// Skip an instance whose box is larger than this; enumeration is exponential and a handful
	/// of wide instances would otherwise set the suite's runtime.
	private static let boxLimit: Int = 400_000

	/// One instance against one configuration. Returns a description of the disagreement, or nil.
	private static func disagreement(
		_ instance: Instance,
		_ label: String,
		_ solver: BranchAndBoundSolver<VectorN<Double>>,
		_ truth: Double,
		seed: UInt64
	) -> String? {
		do {
			let result = try solve(instance, with: solver)
			guard result.status == .optimal else {
				return "\(label): status \(result.status) on a bounded feasible instance — \(instance) [seed \(seed)]"
			}
			let error: Double = abs(result.objectiveValue - truth)
			guard error < 1e-5 else {
				return "\(label): reported \(result.objectiveValue) at \(result.integerSolution), enumeration says \(truth) — \(instance) [seed \(seed)]"
			}
			return nil
		} catch {
			return "\(label): threw \(error) — \(instance) [seed \(seed)]"
		}
	}

	/// Run one shape across every configuration and report what disagreed.
	private static func sweep(shape: Shape, seed: UInt64, rounds: Int)
	-> (checked: Int, skipped: Int, failures: [String]) {
		var rng = Generator(state: seed)
		var failures: [String] = []
		var checked = 0
		var skipped = 0

		for _ in 0..<rounds {
			let instanceSeed = rng.state
			let candidate = instance(&rng, shape: shape)

			guard let caps = variableCaps(candidate),
				  boxSize(caps, binary: candidate.binary) <= boxLimit,
				  let truth = enumerate(candidate, caps: caps) else {
				skipped += 1
				continue
			}

			for (label, solver) in configurations() {
				checked += 1
				if let problem = disagreement(candidate, label, solver, truth, seed: instanceSeed) {
					failures.append(problem)
				}
			}
		}
		return (checked, skipped, failures)
	}

	// MARK: - The claims

	/// Every shape, every configuration, against enumeration.
	///
	/// The count assertion is not ceremony. An instance is skipped when its box cannot be proven
	/// finite or is too wide to enumerate, and a generator that drifted into producing only such
	/// instances would leave this test passing while checking nothing — the failure mode named in
	/// the project's own notes as *partial results reading as complete*. So the sweep reports how
	/// much it actually did, and the test fails if that collapses.
	@Test("Every configuration matches exhaustive enumeration", arguments: Shape.allCases)
	func configurationsMatchEnumeration(_ shape: Shape) throws {
		let seeds: [Shape: UInt64] = [
			.general: 20_260_916,
			.tightAtLattice: 8_675_309,
			.withGreaterOrEqual: 77_001,
			.withEquality: 77_002,
			.binary: 77_003
		]
		let seed = try #require(seeds[shape], "no seed registered for \(shape.rawValue)")
		let outcome = Self.sweep(shape: shape, seed: seed, rounds: 120)

		// Measured: 1,200 checks for every shape but `withGreaterOrEqual`, which skips the
		// instances a `>=` row leaves with no proven upper box, and runs 1,020. The floor sits
		// below the lowest of those with room to spare, and well above zero — its job is to catch
		// a generator that has drifted into producing nothing enumerable, not to pin a count.
		#expect(outcome.checked > 900,
				"\(shape.rawValue): only \(outcome.checked) checks ran, \(outcome.skipped) instances skipped")

		let report: String = outcome.failures.prefix(6).joined(separator: "\n")
		#expect(outcome.failures.isEmpty,
				"\(shape.rawValue): \(outcome.failures.count) of \(outcome.checked) disagreed:\n\(report)")
	}

	/// The three defects this suite was written for, named, so a regression reads as itself
	/// rather than as an anonymous seed.
	///
	/// - A feasible subtree pruned as infeasible, because linearisation noise emptied a thin
	///   region. `max 4x + 7y` returned 18 against an optimum of 21.
	/// - An integral vertex read as fractional and then cut away. `max 2x + y` returned 38
	///   against 40.
	/// - A global bound taken from the next node in the search order rather than the best open
	///   node, which closed the relative gap around a suboptimal incumbent. Depth-first returned
	///   36 against 32, with a reported gap of 5.2e-9.
	@Test("The three instances that motivated this suite")
	func motivatingInstances() throws {
		func row(_ coefficients: [Double], _ rhs: Double) -> Row {
			Row(coefficients: coefficients, rhs: rhs, sense: .lessOrEqual)
		}

		let prunedSubtree = Instance(
			objective: [4.0, 7.0],
			rows: [row([7.0, 3.0], 19.0), row([8.0, 2.0], 27.0), row([3.0, 7.0], 21.0)],
			minimize: false,
			binary: false
		)
		let integralVertex = Instance(
			objective: [2.0, 1.0],
			rows: [row([1.0, 1.0], 20.0)],
			minimize: false,
			binary: false
		)
		let collapsedBound = Instance(
			objective: [2.0, 6.0, 6.0],
			rows: [
				row([1.0, 8.0, 8.0], 49.0),
				Row(coefficients: [3.0, 8.0, 3.0], rhs: 41.0, sense: .greaterOrEqual),
				row([7.0, 8.0, 5.0], 49.0)
			],
			minimize: true,
			binary: false
		)

		for (instance, truth, what) in [
			(prunedSubtree, 21.0, "a feasible subtree pruned as infeasible"),
			(integralVertex, 40.0, "an integral vertex read as fractional"),
			(collapsedBound, 32.0, "a global bound read off the wrong node")
		] {
			let caps = try #require(Self.variableCaps(instance), "\(what): the box is not provably finite")
			let enumerated = try #require(Self.enumerate(instance, caps: caps))
			let enumerationError: Double = abs(enumerated - truth)
			#expect(enumerationError < 1e-9,
					"\(what): the oracle itself disagrees, \(enumerated) against \(truth)")

			for (label, solver) in Self.configurations() {
				let problem = Self.disagreement(instance, label, solver, truth, seed: 0)
				#expect(problem == nil, "\(what) — \(problem ?? "")")
			}
		}
	}
}
