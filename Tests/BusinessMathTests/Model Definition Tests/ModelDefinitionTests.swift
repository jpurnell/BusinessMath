//
//  ModelDefinitionTests.swift
//  BusinessMath
//

import Testing
import Foundation
import TestSupport  // identical(_:_:) — bit-for-bit comparison
@testable import BusinessMath

/// A model whose accounts hold formulas rather than answers.
///
/// The point of the type is that a *derivation* becomes data, which is the thing the library
/// previously had nowhere to put: `FormulaEvaluator` maps names to already-computed series, so
/// one account could never refer to another. These tests are therefore mostly about the two
/// properties that only exist once accounts can refer to each other — that evaluation happens
/// in an order where every dependency is already computed, and that the order is the same
/// order every time.
@Suite("Model Definition")
struct ModelDefinitionTests {

	private let months = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	private func series(_ values: [Double]) -> TimeSeries<Double> {
		TimeSeries(periods: months, values: values)
	}

	/// A small income statement: seven derived accounts over three supplied ones.
	///
	/// Written out rather than generated, because the pinned evaluation order below is only
	/// meaningful if the graph it comes from is visible next to it.
	private var incomeStatement: [(String, String)] {
		[
			("revenue", "units * unitPrice"),
			("cogs", "units * unitCost"),
			("grossProfit", "revenue - cogs"),
			("opex", "revenue * 0.1"),
			("ebit", "grossProfit - opex"),
			("tax", "ebit * taxRate"),
			("netIncome", "ebit - tax")
		]
	}

	private var incomeStatementInputs: [String: TimeSeries<Double>] {
		[
			"units": series([10, 20, 30]),
			"unitPrice": series([100, 100, 100]),
			"unitCost": series([40, 40, 40]),
			"taxRate": series([0.25, 0.25, 0.25])
		]
	}

	private func incomeStatementModel(
		definedIn order: [(String, String)]? = nil
	) -> ModelDefinition<Double> {
		var model = ModelDefinition<Double>(inputs: incomeStatementInputs)
		for (name, formula) in order ?? incomeStatement {
			model.define(name, as: formula)
		}
		return model
	}

	// MARK: - Evaluation in dependency order

	@Test("A definition set whose accounts refer to each other evaluates")
	func evaluatesDerivedAccounts() throws {
		let values = try incomeStatementModel().evaluate()

		#expect(values["revenue"]?.valuesArray == [1000, 2000, 3000])
		#expect(values["cogs"]?.valuesArray == [400, 800, 1200])
		#expect(values["grossProfit"]?.valuesArray == [600, 1200, 1800])
		#expect(values["ebit"]?.valuesArray == [500, 1000, 1500])
		#expect(values["netIncome"]?.valuesArray == [375, 750, 1125])
	}

	@Test("The supplied inputs come back alongside the derived accounts")
	func inputsSurviveEvaluation() throws {
		let values = try incomeStatementModel().evaluate()

		#expect(values["units"]?.valuesArray == [10, 20, 30])
		#expect(values.keys.count == incomeStatement.count + incomeStatementInputs.count)
	}

	/// The property the ordering exists for: nothing is computed before what it reads.
	@Test("Every dependency is ordered before the account that reads it")
	func dependenciesPrecedeDependents() throws {
		let model = incomeStatementModel()
		let order = try model.evaluationOrder()
		let graph = try model.dependencyGraph()

		for (position, account) in order.enumerated() {
			let computedEarlier = Set(order.prefix(position))
			for dependency in graph[account] ?? [] where graph[dependency] != nil {
				#expect(
					computedEarlier.contains(dependency),
					"\(account) reads \(dependency), which is computed later"
				)
			}
		}
	}

	@Test("An account with no dependencies at all is still ordered and evaluated")
	func constantAccount() throws {
		var model = ModelDefinition<Double>(inputs: ["revenue": series([100, 200, 300])])
		model.define("headcount", as: "12")

		#expect(try model.evaluationOrder() == ["headcount"])
		#expect(try model.evaluate()["headcount"]?.valuesArray == [12, 12, 12])
	}

	// MARK: - Determinism

	/// Swift seeds hashing per process, so `Set` and `Dictionary` iteration order differs
	/// between runs. `accountNames(in:)` returns a `Set`, which is exactly the leak: an order
	/// derived from it would be stable within a run and different in the next one.
	///
	/// Pinning the order is what makes that testable at all. This assertion runs in a fresh
	/// process every time the suite runs, so an implementation that let `Set` order through
	/// would not fail *sometimes* — it would fail on the first run whose seed differs.
	@Test("The evaluation order is pinned, not merely reproducible within one run")
	func evaluationOrderIsPinned() throws {
		#expect(try incomeStatementModel().evaluationOrder() == [
			"cogs", "revenue", "grossProfit", "opex", "ebit", "tax", "netIncome"
		])
	}

	/// And it is a function of the formulas, not of the order they were written in — which is
	/// the stronger guarantee, and the one that survives a user reorganising their config file.
	@Test("The order does not depend on the order the accounts were defined in")
	func orderIsIndependentOfInsertionOrder() throws {
		let asWritten = try incomeStatementModel().evaluationOrder()
		let reversed = try incomeStatementModel(definedIn: incomeStatement.reversed()).evaluationOrder()
		let alphabetical = try incomeStatementModel(
			definedIn: incomeStatement.sorted { $0.0 < $1.0 }
		).evaluationOrder()

		#expect(asWritten == reversed)
		#expect(asWritten == alphabetical)
	}

	@Test("Repeated calls give the same order")
	func orderIsStableAcrossCalls() throws {
		let model = incomeStatementModel()

		#expect(try model.evaluationOrder() == (try model.evaluationOrder()))
	}

	/// The adjacency lists are where a `Set` would leak into the output, so they are sorted at
	/// the source rather than at every use.
	@Test("The dependency graph's adjacency lists are sorted")
	func adjacencyIsSorted() throws {
		let graph = try incomeStatementModel().dependencyGraph()

		for (account, dependencies) in graph {
			#expect(dependencies == dependencies.sorted(), "\(account)'s dependencies are unsorted")
		}
		#expect(graph["revenue"] == ["unitPrice", "units"])
	}

	// MARK: - Cycles

	/// A cycle must stop the evaluation. Not loop, not overflow the stack, and above all not
	/// return a partial answer that looks like a whole one.
	@Test("A cyclic definition set refuses to produce an evaluation order")
	func cycleIsRefused() throws {
		var model = ModelDefinition<Double>(inputs: [
			"Units": series([1, 2, 3]),
			"UnitCost": series([1, 1, 1])
		])
		model.define("Revenue", as: "GrossProfit + COGS")
		model.define("GrossProfit", as: "Revenue - COGS")
		model.define("COGS", as: "Units * UnitCost")

		let error = #expect(throws: BusinessMathError.self) {
			try model.evaluationOrder()
		}

		guard case .circularDependency(let path)? = error else {
			Issue.record("expected a circular dependency, got \(String(describing: error))")
			return
		}
		#expect(path.count >= 3)
		#expect(path.first == path.last, "a cycle path should close on the account it entered")
		#expect(Set(path) == ["Revenue", "GrossProfit"])
	}

	@Test("Evaluating a cyclic definition set refuses too, rather than partially succeeding")
	func cycleIsRefusedByEvaluate() throws {
		var model = ModelDefinition<Double>(inputs: ["Units": series([1, 2, 3])])
		model.define("Revenue", as: "GrossProfit + Units")
		model.define("GrossProfit", as: "Revenue - Units")

		#expect(throws: BusinessMathError.self) {
			try model.evaluate()
		}
	}

	/// A one-account cycle. `Revenue: "Revenue * 1.1"` is almost always a typo, and it is a
	/// cycle by the same definition as any other.
	@Test("An account that names itself is a cycle")
	func selfReferenceIsACycle() throws {
		var model = ModelDefinition<Double>(inputs: ["Units": series([1, 2, 3])])
		model.define("Revenue", as: "Revenue * 1.1")

		let error = #expect(throws: BusinessMathError.self) {
			try model.evaluationOrder()
		}

		guard case .circularDependency(let path)? = error else {
			Issue.record("expected a circular dependency, got \(String(describing: error))")
			return
		}
		#expect(path == ["Revenue", "Revenue"])
	}

	@Test("The reported code is E201, and the message names the path")
	func cycleErrorIsE201() throws {
		var model = ModelDefinition<Double>(inputs: [:])
		model.define("a", as: "b")
		model.define("b", as: "a")

		let error = #expect(throws: BusinessMathError.self) {
			try model.evaluationOrder()
		}

		#expect(error?.code == "E201")
		#expect(error?.errorDescription == "Circular dependency detected: a → b → a")
	}

	// MARK: - Names that are not there

	/// `FormulaEvaluator` refuses a missing account rather than reading it as zero, because a
	/// zero in `revenue - cogs` returns revenue and calls it gross profit. A definition set has
	/// the same obligation.
	@Test("A formula naming an account nothing defines and nothing supplies is refused")
	func unknownAccountIsRefused() throws {
		var model = ModelDefinition<Double>(inputs: ["revenue": series([100, 200, 300])])
		model.define("grossProfit", as: "revenue - cogs")

		#expect(throws: FormulaError.unknownAccount("cogs")) {
			try model.evaluate()
		}
	}

	/// Which name is reported cannot depend on hashing either.
	@Test("The refusal names the first missing account alphabetically, whatever the graph")
	func unknownAccountIsReportedDeterministically() throws {
		var model = ModelDefinition<Double>(inputs: [:])
		model.define("total", as: "zeta + alpha + middle")

		#expect(throws: FormulaError.unknownAccount("alpha")) {
			try model.evaluate()
		}
	}

	@Test("Names a formula reads and no formula defines are reported as required inputs")
	func requiredInputsAreTheLeaves() throws {
		#expect(try incomeStatementModel().requiredInputs() == [
			"taxRate", "unitCost", "unitPrice", "units"
		])
	}

	/// An account that is both supplied and derived is ambiguous — the supplied series would be
	/// silently shadowed by the formula. Refused rather than picked between.
	@Test("An account cannot be both an input and a definition")
	func inputAndDefinitionCollide() throws {
		var model = ModelDefinition<Double>(inputs: ["revenue": series([100, 200, 300])])
		model.define("revenue", as: "units * unitPrice")

		#expect(throws: BusinessMathError.self) {
			try model.evaluate()
		}
	}

	// MARK: - Shared dependencies

	/// A diamond: `total` reads both halves, both halves read `base`. `base` must be computed
	/// once — evaluating it twice is the naive-recursion failure mode, and on a wide graph it
	/// is exponential rather than merely wasteful.
	@Test("A shared dependency is evaluated once, not once per dependent")
	func diamondEvaluatesTheSharedAccountOnce() throws {
		var model = ModelDefinition<Double>(inputs: ["seed": series([1, 2, 3])])
		model.define("total", as: "left + right")
		model.define("left", as: "base * 2")
		model.define("right", as: "base * 3")
		model.define("base", as: "seed + 10")

		let order = try model.evaluationOrder()

		#expect(order == ["base", "left", "right", "total"])
		#expect(order.filter { $0 == "base" }.count == 1)
		#expect(try model.evaluate()["total"]?.valuesArray == [55, 60, 65])
	}

	// MARK: - Agreement with the evaluator it is built on

	/// The whole type is a scheduler around `FormulaEvaluator`. If the numbers it produces ever
	/// differ from the same formulas driven by hand, the scheduling has changed the meaning.
	@Test("The numbers match the same formulas evaluated by hand, in order")
	func roundTripAgainstFormulaEvaluator() throws {
		var accounts = incomeStatementInputs
		for (name, formula) in [
			("revenue", "units * unitPrice"),
			("cogs", "units * unitCost"),
			("grossProfit", "revenue - cogs"),
			("opex", "revenue * 0.1"),
			("ebit", "grossProfit - opex"),
			("tax", "ebit * taxRate"),
			("netIncome", "ebit - tax")
		] {
			accounts[name] = try FormulaEvaluator(accounts: accounts).evaluate(formula)
		}

		let values = try incomeStatementModel().evaluate()

		for (name, byHand) in accounts {
			#expect(values[name]?.periods == byHand.periods, "\(name) covers different periods")
			#expect(values[name]?.valuesArray == byHand.valuesArray, "\(name) differs")
		}
	}

	// MARK: - Building a definition set

	@Test("Defining the same account twice replaces the formula in place")
	func redefinitionReplaces() throws {
		var model = ModelDefinition<Double>(inputs: ["units": series([1, 2, 3])])
		model.define("revenue", as: "units * 10")
		model.define("cost", as: "units * 2")
		model.define("revenue", as: "units * 100")

		#expect(model.definitions.map(\.name) == ["revenue", "cost"])
		#expect(model.formula(for: "revenue") == "units * 100")
		#expect(try model.evaluate()["revenue"]?.valuesArray == [100, 200, 300])
	}

	/// The reason a derivation is text: it can come from a file. A definition that could not
	/// make the round trip would be a configuration language you had to write in Swift.
	@Test("A definition survives a round trip through JSON")
	func definitionsAreCodable() throws {
		let original = AccountDefinition(name: "Gross Profit", formula: "[Total Revenue] - cogs")

		let decoded = try JSONDecoder().decode(
			AccountDefinition.self,
			from: try JSONEncoder().encode(original)
		)

		#expect(decoded == original)
		#expect(try ModelDefinition<Double>(
			inputs: ["Total Revenue": series([100, 200, 300]), "cogs": series([40, 80, 120])],
			definitions: [decoded]
		).evaluate()["Gross Profit"]?.valuesArray == [60, 120, 180])
	}

	@Test("A definition set can be built without mutation")
	func fluentConstruction() throws {
		let model = ModelDefinition<Double>(inputs: ["units": series([1, 2, 3])])
			.defining("revenue", as: "units * 10")
			.defining("doubled", as: "revenue * 2")

		#expect(try model.evaluate()["doubled"]?.valuesArray == [20, 40, 60])
	}

	@Test("A definition set with no definitions evaluates to its inputs")
	func emptyDefinitionSet() throws {
		let model = ModelDefinition<Double>(inputs: ["units": series([1, 2, 3])])

		#expect(try model.evaluationOrder().isEmpty)
		#expect(try model.evaluate()["units"]?.valuesArray == [1, 2, 3])
	}

	/// Detection has to work before any data exists — a configuration is validated when it is
	/// written, not when it is first run.
	@Test("Structure can be inspected with no data supplied at all")
	func structureWithoutData() throws {
		let model = ModelDefinition<Double>()
			.defining("grossProfit", as: "revenue - cogs")
			.defining("margin", as: "grossProfit / revenue")

		#expect(try model.evaluationOrder() == ["grossProfit", "margin"])
		#expect(try model.requiredInputs() == ["cogs", "revenue"])
	}

	@Test("A formula that cannot be tokenised is refused when the order is computed")
	func unreadableFormulaIsRefused() throws {
		let model = ModelDefinition<Double>().defining("broken", as: "revenue $ cogs")

		#expect(throws: FormulaError.unexpectedCharacter("$")) {
			try model.evaluationOrder()
		}
	}

	// MARK: - Bracketed names

	/// Real account names have spaces in them, and the graph has to be built from the same
	/// tokeniser the evaluator uses or the two will disagree about what an account is called.
	@Test("Bracketed account names participate in the graph")
	func bracketedNamesInTheGraph() throws {
		let model = ModelDefinition<Double>(inputs: [
			"Total Revenue": series([100, 200, 300]),
			"Cost of Goods Sold": series([40, 80, 120])
		])
			.defining("Gross Profit", as: "[Total Revenue] - [Cost of Goods Sold]")
			.defining("Gross Margin", as: "[Gross Profit] / [Total Revenue]")

		#expect(try model.evaluationOrder() == ["Gross Profit", "Gross Margin"])
		let margin = try #require(model.evaluate()["Gross Margin"]?.valuesArray)
		#expect(identical(margin, [0.6, 0.6, 0.6]))
	}
}
