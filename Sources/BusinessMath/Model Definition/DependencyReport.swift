//
//  DependencyReport.swift
//  BusinessMath
//

import Foundation
import RealModule

// MARK: - DependencyCycle

/// A group of accounts that depend on each other, and one route round it.
///
/// A cycle is a *set* of accounts — everything in a strongly connected component of the
/// dependency graph — together with one concrete traversal for a reader to follow.
///
/// ```
/// interest → debt → cashFlow → interest
/// ```
///
/// ## Identity is the membership, never the path
///
/// `interest → debt → cashFlow → interest` and `debt → cashFlow → interest → debt` are the
/// same cycle. Which one is recovered depends on where the walk entered the component, which
/// depends on the account names, which change when a user renames something. Two cycles are
/// therefore equal when their ``accounts`` match, whatever path each carries — so anything
/// keyed on a cycle keeps matching after a rename that leaves the membership alone.
///
/// The path exists to be read, not to be matched on.
public struct DependencyCycle: Sendable, Hashable {

	/// Every account in the cycle, sorted.
	///
	/// The canonical identity. Sorted so that two runs, and two routes round the same loop,
	/// produce the same value.
	public let accounts: [String]

	/// One route round the cycle, beginning and ending at the same account.
	///
	/// A single traversal rather than every possible one: a component of six accounts can hold
	/// several hundred elementary cycles, and printing them is not a diagnostic.
	public let path: [String]

	/// Whether the cycle's members combine linearly, and so whether it has an exact solution.
	///
	/// Read from the formulas, before any figures exist. See ``Form``.
	public let form: Form

	/// Creates a cycle. Found by ``ModelDefinition/dependencyReport()``, not built by callers.
	///
	/// - Parameters:
	///   - accounts: The component's membership, sorted.
	///   - path: One traversal, first element repeated as the last.
	///   - form: Whether the members combine linearly.
	init(accounts: [String], path: [String], form: Form) {
		self.accounts = accounts
		self.path = path
		self.form = form
	}

	/// Two cycles are equal when they cover the same accounts.
	///
	/// Neither the path nor the form takes part: both are things said *about* a cycle, and a
	/// declaration keyed on one would stop matching when a formula was rewritten.
	///
	/// - Parameters:
	///   - lhs: A cycle.
	///   - rhs: Another.
	/// - Returns: Whether they are the same cycle, ignoring which route round it each carries.
	public static func == (lhs: DependencyCycle, rhs: DependencyCycle) -> Bool {
		lhs.accounts == rhs.accounts
	}

	/// Hashes the membership, and deliberately not the path, so that equal cycles hash equally.
	///
	/// - Parameter hasher: The hasher to feed.
	public func hash(into hasher: inout Hasher) {
		hasher.combine(accounts)
	}
}

// MARK: - DependencyReport

/// What a model's formulas depend on, described rather than judged.
///
/// Produced by ``ModelDefinition/dependencyReport()``. It is *total*: a model with a cycle in
/// it gets described, not rejected. That asymmetry is deliberate — a circular reference in a
/// spreadsheet is a defect, and a circular reference in a levered financial model is the
/// normal shape of the thing. Interest depends on debt, debt depends on the cash flow, and the
/// cash flow depends on interest. Reporting is the part that can be done without knowing which
/// of those a user meant.
///
/// Deciding what to *do* about a cycle needs an intent the graph does not contain, so nothing
/// here decides. Until a caller can express that intent, evaluating a cyclic model is refused:
/// ``ModelDefinition/evaluate()`` throws ``BusinessMathError/circularDependency(path:)``.
///
/// ```swift
/// let report = try model.dependencyReport()
/// for cycle in report.cycles {
///     print(cycle.path.joined(separator: " → "))
/// }
/// ```
public struct DependencyReport: Sendable, Equatable {

	/// The derived accounts, grouped into strongly connected components, in dependency order.
	///
	/// Each group's dependencies are wholly contained in the groups before it. In a model with
	/// no cycles every group holds one account, and flattening them gives the evaluation
	/// order. A group with more than one account is a cycle: its members cannot be put in an
	/// order relative to each other, which is exactly what makes them a cycle.
	///
	/// Members are sorted within a group; groups are in the order they must be computed.
	public let components: [[String]]

	/// Every cycle in the model, not just the first one found.
	///
	/// A first-cycle-and-stop walk tells a user with three circularities about one; they fix
	/// it and are told about the next. Sorted by membership, and empty for an acyclic model.
	public let cycles: [DependencyCycle]

	/// The accounts that must be supplied as data: named by a formula, defined by none.
	public let requiredInputs: [String]

	/// Creates a report.
	///
	/// - Parameters:
	///   - components: The strongly connected components, in dependency order.
	///   - cycles: The components that are cycles, sorted by membership.
	///   - requiredInputs: The undefined names formulas read, sorted.
	init(components: [[String]], cycles: [DependencyCycle], requiredInputs: [String]) {
		self.components = components
		self.cycles = cycles
		self.requiredInputs = requiredInputs
	}

	/// Whether the model has no cycles, and so can be evaluated in a single pass.
	public var isAcyclic: Bool { cycles.isEmpty }

	/// The order the derived accounts can be computed in, or `nil` when a cycle makes one
	/// impossible.
	///
	/// `nil` rather than a partial or arbitrary order: an order that put the members of a
	/// cycle in some sequence would be a claim that evaluating them in that sequence works,
	/// and it does not.
	public var evaluationOrder: [String]? {
		isAcyclic ? components.flatMap { $0 } : nil
	}

	/// Whether every cycle here has an exact answer, so nothing needs iterating to a tolerance.
	///
	/// `true` for an acyclic model, and for one whose every cycle is
	/// ``DependencyCycle/Form/linear``. The question a caller can ask before deciding anything:
	/// a linear cycle is a small simultaneous system with a closed form, and a nonlinear one
	/// has to be approached by iteration, which brings a tolerance, an iteration cap and the
	/// possibility of not converging at all.
	///
	/// It is a claim about the *structure* of the formulas, not about the data. A linear system
	/// can still be singular once its coefficients are known.
	public var isExactlySolvable: Bool {
		cycles.allSatisfy { $0.form == .linear }
	}
}

// MARK: - The graph algorithms

/// Tarjan's strongly connected components, and the walk that recovers a readable path from one.
///
/// Kept over a bare adjacency map so the algorithm can be read, tested and reused without a
/// model around it. Both walks use an explicit stack: a chain of a thousand derived accounts is
/// a legitimate model, and whether it can be analysed should not depend on how much call stack
/// happens to be left.
enum DependencyGraph {

	/// The strongly connected components of `graph`, in dependency order.
	///
	/// Tarjan's algorithm: one depth-first pass, `O(V + E)`, every component rather than the
	/// first cycle. Components are emitted as their roots finish, which for a graph whose edges
	/// point at dependencies means each component appears after everything it depends on.
	///
	/// Deterministic: vertices are entered in sorted order and each adjacency list is assumed
	/// already sorted, so nothing about the result depends on `Set` or `Dictionary` iteration.
	///
	/// - Parameter graph: Account to the accounts it reads. Names with no entry are leaves —
	///   supplied data — and are not vertices.
	/// - Returns: The components, members sorted within each.
	static func components(of graph: [String: [String]]) -> [[String]] {
		var nextIndex = 0
		var index: [String: Int] = [:]
		var lowlink: [String: Int] = [:]
		var componentStack: [String] = []
		var onStack: Set<String> = []
		var components: [[String]] = []

		for root in graph.keys.sorted() {
			guard index[root] == nil else { continue }

			index[root] = nextIndex
			lowlink[root] = nextIndex
			nextIndex += 1
			componentStack.append(root)
			onStack.insert(root)

			var work: [(name: String, next: Int)] = [(root, 0)]

			while let frame = work.last {
				let dependencies = graph[frame.name] ?? []

				guard frame.next < dependencies.count else {
					work.removeLast()
					if let parent = work.last?.name {
						lowlink[parent] = min(
							lowlink[parent] ?? nextIndex,
							lowlink[frame.name] ?? nextIndex
						)
					}
					if lowlink[frame.name] == index[frame.name] {
						components.append(pop(&componentStack, &onStack, upTo: frame.name))
					}
					continue
				}

				work[work.count - 1].next += 1
				let dependency = dependencies[frame.next]

				// A name nothing defines is supplied data, not a vertex.
				guard graph[dependency] != nil else { continue }

				if index[dependency] == nil {
					index[dependency] = nextIndex
					lowlink[dependency] = nextIndex
					nextIndex += 1
					componentStack.append(dependency)
					onStack.insert(dependency)
					work.append((dependency, 0))
				} else if onStack.contains(dependency) {
					lowlink[frame.name] = min(
						lowlink[frame.name] ?? nextIndex,
						index[dependency] ?? nextIndex
					)
				}
			}
		}

		return components
	}

	/// Empties the component stack down to and including `root`, which is one component.
	private static func pop(
		_ stack: inout [String],
		_ onStack: inout Set<String>,
		upTo root: String
	) -> [String] {
		var component: [String] = []
		while let member = stack.popLast() {
			onStack.remove(member)
			component.append(member)
			if member == root { break }
		}
		return component.sorted()
	}

	/// The components that are cycles, with a path recovered for each.
	///
	/// A component of two or more accounts is a cycle by definition. A component of one is a
	/// cycle only when the account's formula names itself — `Revenue: "Revenue * 1.1"` — which
	/// Tarjan reports as an ordinary trivial component and which is a cycle all the same.
	///
	/// - Parameters:
	///   - components: The output of ``components(of:)``.
	///   - graph: The same graph those components came from.
	///   - form: Classifies a component's membership. Supplied rather than computed here
	///     because degree is a property of the formulas and this type only ever sees the graph.
	/// - Returns: The cycles, sorted by membership.
	/// - Throws: Whatever `form` throws — a formula that cannot be read has no form.
	static func cycles(
		in components: [[String]],
		of graph: [String: [String]],
		form: ([String]) throws -> DependencyCycle.Form
	) rethrows -> [DependencyCycle] {
		try components
			.filter { component in
				guard let only = component.first, component.count == 1 else { return true }
				return graph[only]?.contains(only) ?? false
			}
			.map { component in
				DependencyCycle(
					accounts: component,
					path: path(round: component, of: graph),
					form: try form(component)
				)
			}
			.sorted { $0.accounts.lexicographicallyPrecedes($1.accounts) }
	}

	/// One route round a component, from its first member back to itself.
	///
	/// A depth-first walk confined to the component's own vertices. Because every member of a
	/// strongly connected component can reach every other, a closing edge is guaranteed to
	/// exist and to be found — which is why one path can be recovered cheaply here, while
	/// enumerating *all* of a component's cycles is exponential and worth refusing.
	///
	/// - Parameters:
	///   - component: A component's members, sorted.
	///   - graph: The graph it came from.
	/// - Returns: A path whose first and last elements are the component's first member.
	private static func path(round component: [String], of graph: [String: [String]]) -> [String] {
		guard let start = component.first else { return [] }
		let members = Set(component)

		var path: [String] = [start]
		var visited: Set<String> = [start]
		var work: [(name: String, next: Int)] = [(start, 0)]

		while let frame = work.last {
			let dependencies = (graph[frame.name] ?? []).filter { members.contains($0) }

			guard frame.next < dependencies.count else {
				work.removeLast()
				path.removeLast()
				continue
			}

			work[work.count - 1].next += 1
			let dependency = dependencies[frame.next]

			guard dependency != start else { return path + [start] }
			guard !visited.contains(dependency) else { continue }

			visited.insert(dependency)
			path.append(dependency)
			work.append((dependency, 0))
		}

		// Unreachable for a real component: every member reaches `start`, so the last edge on
		// some path into it is walked and closes the loop above. Returning the entry point
		// alone rather than inventing an edge keeps the impossible case from asserting one.
		return [start]
	}
}

// MARK: - ModelDefinition

extension ModelDefinition {

	/// Describes what this model's formulas depend on, including any cycles.
	///
	/// Total, except for a formula that cannot be read: a cyclic model is reported, not
	/// refused, because whether a given cycle is a mistake is something only the modeller
	/// knows. See ``DependencyReport``.
	///
	/// Needs no data. A configuration can be checked when it is written rather than when it is
	/// first run against a company.
	///
	/// ```swift
	/// let report = try model.dependencyReport()
	/// if let order = report.evaluationOrder {
	///     print("evaluates in \(order.count) steps")
	/// } else {
	///     for cycle in report.cycles {
	///         print("cycle: \(cycle.path.joined(separator: " → "))")
	///     }
	/// }
	/// ```
	///
	/// - Returns: The components, the cycles and the accounts that must be supplied.
	/// - Throws: ``FormulaError`` when a formula cannot be read — a formula that cannot be
	///   tokenised has no dependencies to report and reporting none would claim it had none, and
	///   one that cannot be parsed has no ``DependencyCycle/form`` and calling it nonlinear
	///   would claim something about an expression nobody could read.
	public func dependencyReport() throws -> DependencyReport {
		let graph = try dependencyGraph()
		let components = DependencyGraph.components(of: graph)
		return DependencyReport(
			components: components,
			cycles: try DependencyGraph.cycles(in: components, of: graph, form: form(ofCycle:)),
			requiredInputs: try requiredInputs()
		)
	}
}
