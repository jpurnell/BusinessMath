//
//  ModelDefinition.swift
//  BusinessMath
//

import Foundation
import RealModule

// MARK: - AccountDefinition

/// One account's derivation: the name it defines, and the formula that defines it.
///
/// A definition is text, not a computed series. That is the whole point of it — a derivation
/// that is data can be read from a configuration file, compared between companies, and
/// inspected before any figures exist. ``ModelDefinition`` is what holds a set of them.
///
/// ```swift
/// let grossProfit = AccountDefinition(name: "grossProfit", formula: "revenue - cogs")
/// ```
///
/// The formula is in ``FormulaEvaluator``'s grammar: `+ − × ÷`, parentheses, unary minus,
/// numbers, and account names — bracketed where they contain spaces or punctuation.
public struct AccountDefinition: Sendable, Hashable, Codable {

	/// The account this formula defines.
	public let name: String

	/// The expression that produces it, in ``FormulaEvaluator``'s grammar.
	public let formula: String

	/// Creates a definition.
	///
	/// - Parameters:
	///   - name: The account being defined. Matched verbatim against the names formulas read,
	///     spaces included.
	///   - formula: The expression producing it. Not parsed here — a definition set can hold a
	///     formula that does not tokenise, and says so when its order is computed.
	public init(name: String, formula: String) {
		self.name = name
		self.formula = formula
	}
}

// MARK: - ModelDefinition

/// A model whose accounts hold formulas, evaluated in dependency order.
///
/// ## What it is for
///
/// ``FormulaEvaluator`` maps account names to series that have *already been computed*, so a
/// formula can name an account but an account cannot name a formula. That is enough for a
/// derived line or two, and not enough for a model: the moment gross profit is derived from
/// revenue and margin from gross profit, something has to know that revenue comes first.
///
/// `ModelDefinition` is that something. It holds the derivations, works out from the formulas
/// alone which account depends on which, and evaluates them in an order where nothing is
/// computed before what it reads.
///
/// ```swift
/// let model = ModelDefinition<Double>(inputs: ["units": units, "unitPrice": price])
///     .defining("revenue", as: "units * unitPrice")
///     .defining("cogs", as: "units * 40")
///     .defining("grossProfit", as: "revenue - cogs")
///
/// let values = try model.evaluate()
/// let margin = values["grossProfit"]
/// ```
///
/// ## Inputs and definitions
///
/// An account is one or the other, never both. ``inputs`` are the leaves — data you supply.
/// ``definitions`` are derived from them and from each other. A name that appears in both is
/// refused rather than resolved, because either answer silently discards something the caller
/// provided.
///
/// A name a formula reads and no definition defines is an input, and ``requiredInputs()``
/// lists them. Supplying nothing for one is refused rather than read as zero — the same
/// refusal ``FormulaEvaluator`` makes, for the same reason: a missing account in
/// `revenue - cogs` returns revenue and presents it as gross profit.
///
/// ## Order is a stated property, not an accident
///
/// ``evaluationOrder()`` is derived from the formulas by a depth-first walk over names in
/// sorted order, with each account's dependencies sorted too. It therefore does not depend on
/// the order the definitions were written in, and — more importantly — it does not depend on
/// `Set` or `Dictionary` iteration, which Swift seeds per process and which would otherwise
/// give a different answer in every run.
///
/// ## Cycles
///
/// A definition set *may* contain a cycle. Constructing one does not throw, and
/// ``dependencyReport()`` describes one without complaint — a cycle is a fact about a model
/// that something has to be able to look at, and in a levered model it is often deliberate.
///
/// Evaluating one does throw, because nothing here yet knows which cycles a caller intended:
/// ``BusinessMathError/circularDependency(path:)``, carrying one path that closes a loop.
///
/// ```swift
/// let broken = ModelDefinition<Double>()
///     .defining("Revenue", as: "GrossProfit + COGS")
///     .defining("GrossProfit", as: "Revenue - COGS")
///
/// let cycles = try broken.dependencyReport().cycles   // reports, does not judge
/// try broken.evaluationOrder()
/// // E201: Circular dependency detected: GrossProfit → Revenue → GrossProfit
/// ```
///
/// ## What it deliberately does not do
///
/// It inherits ``FormulaEvaluator``'s grammar exactly, and that grammar has **no reference to
/// another period**. An account reads other accounts in the period being evaluated. A
/// roll-forward — `openingDebt(t) = closingDebt(t−1)` — cannot be written, so the circular
/// models that motivate cycle handling in a three-statement model cannot be expressed here
/// yet, and no amount of dependency analysis changes that.
public struct ModelDefinition<T: Real & Sendable & LosslessStringConvertible>: Sendable {

	/// The derivations, in the order they were added.
	///
	/// An array rather than a dictionary: insertion order is stable across processes and
	/// dictionary iteration order is not. Nothing in evaluation depends on this order — see
	/// ``evaluationOrder()`` — but a definition set that is printed, diffed or serialised
	/// should look the same twice.
	public private(set) var definitions: [AccountDefinition]

	/// The supplied data: accounts that are given rather than derived.
	public var inputs: [String: TimeSeries<T>]

	/// Creates a definition set.
	///
	/// - Parameters:
	///   - inputs: The leaves — accounts supplied as data. Defaults to none, because the
	///     structure of a model can be inspected before any figures exist.
	///   - definitions: The derived accounts. A name defined more than once keeps its first
	///     position and its last formula.
	public init(inputs: [String: TimeSeries<T>] = [:], definitions: [AccountDefinition] = []) {
		self.inputs = inputs
		self.definitions = []
		for definition in definitions {
			define(definition.name, as: definition.formula)
		}
	}

	// MARK: - Building

	/// Adds or replaces a derivation.
	///
	/// Defining a name that is already defined replaces its formula in place, keeping its
	/// position, so a definition set cannot come to hold two answers for one account.
	///
	/// - Parameters:
	///   - name: The account being defined.
	///   - formula: The expression producing it.
	public mutating func define(_ name: String, as formula: String) {
		let definition = AccountDefinition(name: name, formula: formula)
		if let existing = definitions.firstIndex(where: { $0.name == name }) {
			definitions[existing] = definition
		} else {
			definitions.append(definition)
		}
	}

	/// Returns a copy with one more derivation, for building a model in an expression.
	///
	/// - Parameters:
	///   - name: The account being defined.
	///   - formula: The expression producing it.
	/// - Returns: A definition set including it.
	public func defining(_ name: String, as formula: String) -> ModelDefinition<T> {
		var copy = self
		copy.define(name, as: formula)
		return copy
	}

	/// The formula defining an account, if it is derived rather than supplied.
	///
	/// - Parameter name: An account name.
	/// - Returns: Its formula, or `nil` when nothing defines it.
	public func formula(for name: String) -> String? {
		definitions.first { $0.name == name }?.formula
	}

	// MARK: - Structure

	/// Which accounts each definition reads.
	///
	/// Keyed by defined account; the values include names that nothing defines, because a
	/// formula's dependencies are what it reads, not what happens to be derived. Every
	/// adjacency list is sorted, which is where determinism starts: `accountNames(in:)` returns
	/// a `Set`, and a `Set`'s order is seeded per process.
	func dependencyGraph() throws -> [String: [String]] {
		var graph: [String: [String]] = [:]
		for definition in definitions {
			graph[definition.name] = try FormulaEvaluator<T>
				.accountNames(in: definition.formula)
				.sorted()
		}
		return graph
	}

	/// The accounts that must be supplied as data.
	///
	/// Every name some formula reads and no formula defines — the leaves of the graph. Answers
	/// "which figures does this configuration need" before any of them exist.
	///
	/// - Returns: The names, sorted.
	/// - Throws: ``FormulaError`` when a formula cannot be tokenised.
	public func requiredInputs() throws -> [String] {
		let defined = Set(definitions.map(\.name))
		var required: Set<String> = []
		for definition in definitions {
			required.formUnion(try FormulaEvaluator<T>.accountNames(in: definition.formula))
		}
		return required.subtracting(defined).sorted()
	}

	/// The order the derived accounts must be computed in.
	///
	/// Every dependency appears before its dependent, and a shared dependency appears once.
	/// Supplied inputs are not in the result — there is nothing to compute for them.
	///
	/// Deterministic by construction: derived from ``dependencyReport()``, which enters
	/// accounts in sorted name order and reads each account's dependencies in sorted order. The
	/// result is a function of the formulas alone. It does not vary with the order definitions
	/// were added, and it does not vary between processes.
	///
	/// - Returns: The derived account names, in evaluation order.
	/// - Throws: ``BusinessMathError/circularDependency(path:)`` when the definitions contain a
	///   cycle, and ``FormulaError`` when a formula cannot be tokenised.
	public func evaluationOrder() throws -> [String] {
		try order(from: try dependencyReport())
	}

	/// The one place a cycle turns from something reported into something refused.
	///
	/// The error carries a single path because that is what its message renders, and because a
	/// caller who wants all of them should ask ``dependencyReport()``, which lists every cycle
	/// rather than the first.
	private func order(from report: DependencyReport) throws -> [String] {
		guard let order = report.evaluationOrder else {
			throw BusinessMathError.circularDependency(path: report.cycles.first?.path ?? [])
		}
		return order
	}

	// MARK: - Evaluation

	/// Evaluates every derived account, in dependency order.
	///
	/// Each definition is evaluated by ``FormulaEvaluator`` against the inputs and the accounts
	/// already computed, so a formula here means exactly what the same formula means there —
	/// including about periods that do not line up, which intersect rather than being filled
	/// with zeros.
	///
	/// - Returns: Every account, supplied and derived, by name.
	/// - Throws: ``BusinessMathError/circularDependency(path:)`` when the definitions contain a
	///   cycle; ``BusinessMathError/inconsistentData(description:)`` when an account is both
	///   supplied and derived; ``FormulaError/unknownAccount(_:)`` when a formula reads
	///   something neither supplied nor defined; ``FormulaError`` for a formula that cannot be
	///   read.
	public func evaluate() throws -> [String: TimeSeries<T>] {
		let report = try dependencyReport()
		let order = try self.order(from: report)
		try refuseUnusableDefinitions(report)

		var accounts = inputs
		for name in order {
			guard let formula = formula(for: name) else { continue }
			accounts[name] = try FormulaEvaluator(accounts: accounts).evaluate(formula)
		}
		return accounts
	}
}
