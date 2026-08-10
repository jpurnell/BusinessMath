//
//  DependencyReportTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// What a dependency graph contains, reported rather than judged.
///
/// The distinction these tests are built around: finding a cycle and deciding a cycle is a
/// problem are two jobs, and only the first belongs here. A report is total — it describes the
/// model it was given and has no opinion about it — because the cycles an analyst puts in a
/// levered model on purpose and the ones they put in by accident are indistinguishable from
/// the graph alone.
///
/// The other property under test is completeness. A depth-first walk that returns the *first*
/// cycle tells a user with three circularities about one of them; they fix it and are told
/// about the next. Tarjan's algorithm finds every strongly connected component in one pass, so
/// the report can name all three at once.
@Suite("Dependency Report")
struct DependencyReportTests {

	private let months = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: months, values: values)
	}

	/// Two independent two-account cycles, one account caught downstream of one of them, and
	/// one account with nothing to do with either.
	private func twoCycles() -> ModelDefinition<Double> {
		ModelDefinition<Double>(inputs: ["seed": series([1, 2, 3])])
			.defining("a", as: "b + seed")
			.defining("b", as: "a + seed")
			.defining("x", as: "y + seed")
			.defining("y", as: "x + seed")
			.defining("downstream", as: "a * 2")
			.defining("independent", as: "seed * 2")
	}

	// MARK: - An acyclic model

	@Test("An acyclic model reports no cycles")
	func acyclicReportsNothing() throws {
		let report = try ModelDefinition<Double>()
			.defining("grossProfit", as: "revenue - cogs")
			.defining("margin", as: "grossProfit / revenue")
			.dependencyReport()

		#expect(report.cycles.isEmpty)
		#expect(report.isAcyclic)
		#expect(report.evaluationOrder == ["grossProfit", "margin"])
		#expect(report.requiredInputs == ["cogs", "revenue"])
	}

	/// One order, not two. The report and the evaluator must not be able to disagree about
	/// which account comes first, so the evaluator asks the report.
	@Test("The report's order is the order evaluation actually uses")
	func reportOrderIsTheEvaluationOrder() throws {
		let model = ModelDefinition<Double>(inputs: [
			"units": series([10, 20, 30]),
			"unitPrice": series([100, 100, 100]),
			"unitCost": series([40, 40, 40]),
			"taxRate": series([0.25, 0.25, 0.25])
		])
			.defining("revenue", as: "units * unitPrice")
			.defining("cogs", as: "units * unitCost")
			.defining("grossProfit", as: "revenue - cogs")
			.defining("opex", as: "revenue * 0.1")
			.defining("ebit", as: "grossProfit - opex")
			.defining("tax", as: "ebit * taxRate")
			.defining("netIncome", as: "ebit - tax")

		#expect(try model.dependencyReport().evaluationOrder == (try model.evaluationOrder()))
	}

	/// In an acyclic model every component is a single account, which is what makes the
	/// condensation flatten into an evaluation order at all.
	@Test("Each account of an acyclic model is its own component")
	func acyclicComponentsAreSingletons() throws {
		let report = try ModelDefinition<Double>()
			.defining("total", as: "left + right")
			.defining("left", as: "base * 2")
			.defining("right", as: "base * 3")
			.defining("base", as: "seed + 10")
			.dependencyReport()

		#expect(report.components == [["base"], ["left"], ["right"], ["total"]])
	}

	// MARK: - Detection is total

	/// The property that separates this from validation: a cyclic model is described, not
	/// rejected. A cycle in a three-statement model is often the model.
	@Test("Reporting a cyclic model does not throw")
	func detectionNeverThrowsOnACycle() throws {
		let report = try twoCycles().dependencyReport()

		#expect(report.cycles.count == 2)
		#expect(report.isAcyclic == false)
	}

	@Test("There is no evaluation order for a cyclic model, and the report says so rather than inventing one")
	func noOrderWhenCyclic() throws {
		#expect(try twoCycles().dependencyReport().evaluationOrder == nil)
	}

	/// The reason for Tarjan rather than the first-cycle walk the debugging guide used to
	/// teach: a user with two circularities should be told about two.
	@Test("Every cycle is reported, not the first one found")
	func everyCycleIsReported() throws {
		let report = try twoCycles().dependencyReport()

		#expect(report.cycles.map(\.accounts) == [["a", "b"], ["x", "y"]])
	}

	@Test("Accounts outside a cycle are still placed, including one that depends on a cycle")
	func acyclicAccountsSurviveACyclicModel() throws {
		let report = try twoCycles().dependencyReport()

		#expect(report.components == [
			["a", "b"], ["downstream"], ["independent"], ["x", "y"]
		])
	}

	// MARK: - The path

	/// A component is a set, and a set is not what a user asks for. `interest → debt →
	/// cashFlow → interest` is the thing that can be read and acted on.
	@Test("A cycle carries a concrete path that closes on itself")
	func cycleCarriesAPath() throws {
		let report = try ModelDefinition<Double>()
			.defining("p", as: "q")
			.defining("q", as: "r")
			.defining("r", as: "p")
			.dependencyReport()

		let cycle = try #require(report.cycles.first)

		#expect(cycle.accounts == ["p", "q", "r"])
		#expect(cycle.path == ["p", "q", "r", "p"])
		#expect(cycle.path.first == cycle.path.last)
		#expect(Set(cycle.path) == Set(cycle.accounts))
	}

	/// One traversal, not an enumeration. Every elementary cycle of a six-account component can
	/// run to hundreds, and a list that long is not a diagnostic.
	@Test("A path closes without repeating an account on the way round")
	func pathIsElementary() throws {
		let report = try twoCycles().dependencyReport()

		for cycle in report.cycles {
			#expect(cycle.path.first == cycle.path.last)
			#expect(Set(cycle.path.dropLast()).count == cycle.path.count - 1)
			#expect(Set(cycle.path).isSubset(of: Set(cycle.accounts)))
		}
	}

	/// An account whose formula names itself is a one-member component with an edge to
	/// itself. Tarjan calls that trivial; it is still a cycle, and usually a typo.
	@Test("An account that names itself is reported as a cycle")
	func selfEdgeIsACycle() throws {
		let report = try ModelDefinition<Double>()
			.defining("Revenue", as: "Revenue * 1.1")
			.defining("Costs", as: "Units * 2")
			.dependencyReport()

		#expect(report.cycles.map(\.accounts) == [["Revenue"]])
		#expect(report.cycles.map(\.path) == [["Revenue", "Revenue"]])
	}

	@Test("A one-member component with no self-edge is not a cycle")
	func singletonWithoutSelfEdgeIsNotACycle() throws {
		let report = try ModelDefinition<Double>()
			.defining("Revenue", as: "Units * Price")
			.dependencyReport()

		#expect(report.cycles.isEmpty)
		#expect(report.components == [["Revenue"]])
	}

	// MARK: - Identity

	/// The load-bearing decision. `a → b → c → a` and `b → c → a → b` are one cycle; which one
	/// is shown depends on where the walk started, which depends on names, which change. A
	/// declaration keyed on the path would stop matching after a rename and start reporting an
	/// error about a model the user had already accepted.
	@Test("Two cycles over the same accounts are the same cycle, whatever path was recovered")
	func identityIsTheAccountSetNotThePath() {
		let entered = DependencyCycle(
			accounts: ["a", "b", "c"], path: ["a", "b", "c", "a"], form: .linear
		)
		let rotated = DependencyCycle(
			accounts: ["a", "b", "c"], path: ["b", "c", "a", "b"], form: .linear
		)
		let different = DependencyCycle(
			accounts: ["a", "b", "d"], path: ["a", "b", "d", "a"], form: .linear
		)

		#expect(entered == rotated)
		#expect(entered.hashValue == rotated.hashValue)
		#expect(entered != different)
		#expect(Set([entered, rotated]).count == 1)
	}

	@Test("Membership is sorted, so it is the same key however the graph was walked")
	func membershipIsSorted() throws {
		let report = try twoCycles().dependencyReport()

		for cycle in report.cycles {
			#expect(cycle.accounts == cycle.accounts.sorted())
		}
	}

	/// Renaming an account outside the cycle changes which account the walk reaches first, and
	/// must not change the cycle's identity.
	@Test("A cycle keeps its identity when an unrelated account is renamed")
	func identitySurvivesUnrelatedRenames() throws {
		let first = try ModelDefinition<Double>()
			.defining("aaa", as: "interest")
			.defining("interest", as: "debt * 0.05")
			.defining("debt", as: "interest + 100")
			.dependencyReport()
		let second = try ModelDefinition<Double>()
			.defining("zzz", as: "interest")
			.defining("interest", as: "debt * 0.05")
			.defining("debt", as: "interest + 100")
			.dependencyReport()

		#expect(first.cycles == second.cycles)
		#expect(first.cycles.map(\.accounts) == [["debt", "interest"]])
	}

	// MARK: - Determinism

	/// Pinned rather than merely compared to itself: `accountNames(in:)` returns a `Set` and
	/// Swift seeds hashing per process, so an order that leaked through a `Set` would be
	/// stable within a run and wrong in the next. A pinned expectation fails on the first run
	/// whose seed differs; a self-comparison never would.
	@Test("Components, cycles and paths are all pinned")
	func reportIsPinned() throws {
		let report = try twoCycles().dependencyReport()

		#expect(report.components == [["a", "b"], ["downstream"], ["independent"], ["x", "y"]])
		#expect(report.cycles.map(\.accounts) == [["a", "b"], ["x", "y"]])
		#expect(report.cycles.map(\.path) == [["a", "b", "a"], ["x", "y", "x"]])
		#expect(report.requiredInputs == ["seed"])
	}

	@Test("The report does not depend on the order the accounts were defined in")
	func reportIsIndependentOfInsertionOrder() throws {
		let forwards = try twoCycles().dependencyReport()
		let backwards = try ModelDefinition<Double>(
			inputs: ["seed": series([1, 2, 3])],
			definitions: Array(twoCycles().definitions.reversed())
		).dependencyReport()

		#expect(forwards.components == backwards.components)
		#expect(forwards.cycles == backwards.cycles)
		#expect(forwards.cycles.map(\.path) == backwards.cycles.map(\.path))
	}

	@Test("Repeated reports are identical")
	func reportIsStableAcrossCalls() throws {
		let model = twoCycles()

		#expect(try model.dependencyReport() == (try model.dependencyReport()))
	}

	// MARK: - Still refuses to evaluate

	/// Reporting is total; evaluating is not. Nothing has been taught yet about which cycles a
	/// caller intends, so the only safe thing to do with one is refuse — quietly iterating a
	/// model nobody asked to have iterated is how a wrong number gets published.
	@Test("A cyclic model still refuses to evaluate, and names one cycle in the error")
	func evaluationStillRefuses() throws {
		let error = #expect(throws: BusinessMathError.self) {
			try twoCycles().evaluate()
		}

		guard case .circularDependency(let path)? = error else {
			Issue.record("expected a circular dependency, got \(String(describing: error))")
			return
		}
		#expect(path == ["a", "b", "a"])
		#expect(error?.errorDescription == "Circular dependency detected: a → b → a")
	}

	@Test("Which cycle the error names is deterministic when there are several")
	func thrownCycleIsDeterministic() throws {
		let model = ModelDefinition<Double>()
			.defining("x", as: "y")
			.defining("y", as: "x")
			.defining("a", as: "b")
			.defining("b", as: "a")

		let error = #expect(throws: BusinessMathError.self) { try model.evaluationOrder() }

		guard case .circularDependency(let path)? = error else {
			Issue.record("expected a circular dependency, got \(String(describing: error))")
			return
		}
		#expect(path == ["a", "b", "a"])
	}

	// MARK: - Formulas that cannot be read

	/// The one thing detection does throw for. A formula that will not tokenise has no
	/// dependencies to report — reporting none would claim it was a leaf.
	@Test("An unreadable formula is refused rather than reported as having no dependencies")
	func unreadableFormulaIsRefused() {
		let model = ModelDefinition<Double>().defining("broken", as: "revenue $ cogs")

		#expect(throws: FormulaError.unexpectedCharacter("$")) {
			try model.dependencyReport()
		}
	}

	// MARK: - Scale

	/// A long chain is a legitimate model, and detection should not depend on how much stack
	/// is left when it runs.
	@Test("A chain of a thousand accounts is walked without recursing")
	func longChain() throws {
		var model = ModelDefinition<Double>()
		model.define("account0", as: "seed + 1")
		for index in 1..<1000 {
			model.define("account\(index)", as: "account\(index - 1) + 1")
		}

		let report = try model.dependencyReport()

		#expect(report.cycles.isEmpty)
		#expect(report.components.count == 1000)
		#expect(report.evaluationOrder?.first == "account0")
		#expect(report.evaluationOrder?.last == "account999")
	}

	@Test("A cycle a thousand accounts long is one component, and one path")
	func longCycle() throws {
		var model = ModelDefinition<Double>()
		for index in 0..<1000 {
			model.define("account\(index)", as: "account\((index + 999) % 1000)")
		}

		let report = try model.dependencyReport()

		#expect(report.cycles.count == 1)
		#expect(report.cycles.first?.accounts.count == 1000)
		#expect(report.cycles.first?.path.count == 1001)
	}
}
