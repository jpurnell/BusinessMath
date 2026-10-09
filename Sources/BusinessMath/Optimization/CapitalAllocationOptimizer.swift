//
//  CapitalAllocationOptimizer.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics
#if canImport(os)
import os
private let logger = Logger(subsystem: "com.businessmath", category: "CapitalAllocationOptimizer")
#endif

// MARK: - CapitalAllocationOptimizer

/// Optimizes capital allocation across multiple projects.
///
/// `CapitalAllocationOptimizer` helps decide how to allocate limited capital
/// across competing projects to maximize total NPV. It provides both greedy
/// and optimal (0-1 knapsack) algorithms.
///
/// ## Usage
///
/// ```swift
/// let optimizer = CapitalAllocationOptimizer<Double>()
///
/// let projects = [
///     CapitalAllocationOptimizer.Project(
///         name: "Project A",
///         npv: 100_000,
///         capitalRequired: 50_000,
///         risk: 0.2
///     ),
///     CapitalAllocationOptimizer.Project(
///         name: "Project B",
///         npv: 150_000,
///         capitalRequired: 100_000,
///         risk: 0.3
///     )
/// ]
///
/// // Greedy allocation (fast, approximate)
/// let greedy = optimizer.optimize(projects: projects, budget: 120_000)
///
/// // Optimal allocation (slower, exact)
/// let optimal = optimizer.optimizeIntegerProjects(projects: projects, budget: 120_000)
///
/// // The same, for numbers that arrive from outside the program: refuses what it cannot size
/// let checked = try optimizer.optimizeIntegerProjects(validating: projects, budget: 120_000)
///
/// print("Projects selected: \(optimal.projectsSelected)")
/// print("Total NPV: \(optimal.totalNPV)")
/// ```
///
/// ## Algorithms
///
/// ### Greedy Algorithm
/// Sorts projects by ROI (NPV / capital required) and selects projects in order
/// until the budget is exhausted. Fast but may not find the optimal solution.
///
/// ### Integer Programming (0-1 Knapsack)
/// Uses dynamic programming to find the optimal combination of projects.
/// Each project is either fully funded or not funded at all. Slower but
/// guaranteed to find the optimal solution.
///
/// The table it builds is sized by the caller's numbers, so those numbers are screened:
/// ``optimizeIntegerProjects(validating:budget:)`` throws a ``BusinessMathError`` naming the
/// argument, and ``optimizeIntegerProjects(projects:budget:)`` answers with `nan` totals. See
/// ``maximumAmount`` and ``maximumTableCells`` for the two stated limits.
public struct CapitalAllocationOptimizer<T> where T: Real & Sendable & Codable & Comparable & BinaryFloatingPoint {

	// MARK: - Project

	/// A capital project with NPV, capital requirements, and risk.
	public struct Project: Sendable {
		/// The name of the project.
		public let name: String

		/// The net present value of the project.
		public let npv: T

		/// The capital required to fund the project.
		public let capitalRequired: T

		/// The risk level of the project (0-1). Optional.
		public let risk: T

		/// The return on investment (NPV / capital required).
		public var roi: T {
			// This is the sole ranking key of the greedy allocator, which sorts on it. A `nan`
			// `capitalRequired` fired the guard and yielded `0` — measured, that ranks *above*
			// a project with ROI -2.0, so an unevaluable project read as "breaks even" and
			// outranked one that destroys value. A `nan` `npv` passed the guard and made the
			// key itself `nan`, which is worse: the sort predicate stops being a strict weak
			// ordering and the *valid* projects come back misordered — measured, the highest-ROI
			// project moved from first place to fourth.
			//
			// The `> 0` arm stays for a genuine zero-capital project; only contamination is
			// diverted.
			guard !capitalRequired.isNaN, !npv.isNaN else { return T.nan }
			guard capitalRequired > 0 else { return 0 }
			return npv / capitalRequired
		}

		/// Creates a capital project.
		///
		/// - Parameters:
		///   - name: The name of the project.
		///   - npv: The net present value.
		///   - capitalRequired: The capital required.
		///   - risk: The risk level (0-1). Defaults to 0.
		public init(
			name: String,
			npv: T,
			capitalRequired: T,
			risk: T = 0
		) {
			self.name = name
			self.npv = npv
			self.capitalRequired = capitalRequired
			self.risk = risk
		}
	}

	// MARK: - AllocationResult

	/// The result of capital allocation optimization.
	public struct AllocationResult: Sendable {
		/// Capital allocated to each project (project name -> amount).
		public let allocations: [String: T]

		/// The total NPV of selected projects.
		public let totalNPV: T

		/// The total capital used.
		public let capitalUsed: T

		/// Names of projects selected.
		public let projectsSelected: [String]

		/// A human-readable description of the result.
		public var description: String {
			var result = "Capital Allocation Result\n"
			result += "=========================\n"
			result += "Total NPV: \(totalNPV)\n"
			result += "Capital Used: \(capitalUsed)\n"
			result += "Projects Selected: \(projectsSelected.count)\n\n"

			if !projectsSelected.isEmpty {
				result += "Allocations:\n"
				for project in projectsSelected.sorted() {
					if let amount = allocations[project] {
						result += "  \(project): \(amount)\n"
					}
				}
			}

			return result
		}

		/// Creates an allocation result.
		///
		/// - Parameters:
		///   - allocations: Capital allocated to each project.
		///   - totalNPV: The total NPV.
		///   - capitalUsed: The total capital used.
		///   - projectsSelected: Names of projects selected.
		public init(
			allocations: [String: T],
			totalNPV: T,
			capitalUsed: T,
			projectsSelected: [String]
		) {
			self.allocations = allocations
			self.totalNPV = totalNPV
			self.capitalUsed = capitalUsed
			self.projectsSelected = projectsSelected
		}
	}

	// MARK: - Initialization

	/// Creates a capital allocation optimizer.
	public init() {}

	// MARK: - Greedy Optimization

	/// Optimizes capital allocation using a greedy algorithm.
	///
	/// Sorts projects by ROI (highest first) and allocates capital until
	/// the budget is exhausted. This is fast but may not find the globally
	/// optimal solution.
	///
	/// - Parameters:
	///   - projects: The projects to consider.
	///   - budget: The total budget available.
	/// - Returns: The allocation result.
	public func optimize(
		projects: [Project],
		budget: T
	) -> AllocationResult {
		guard budget > 0 else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		guard !projects.isEmpty else {
			return AllocationResult(
				allocations: [:],
				totalNPV: 0,
				capitalUsed: 0,
				projectsSelected: []
			)
		}

		// Sort projects by ROI (descending)
		let sortedProjects = projects.sorted { $0.roi > $1.roi }

		var allocations: [String: T] = [:]
		var totalNPV: T = 0
		var capitalUsed: T = 0
		var projectsSelected: [String] = []
		var remainingBudget = budget

		for project in sortedProjects {
			// Check if we can afford this project
			if project.capitalRequired <= remainingBudget {
				allocations[project.name] = project.capitalRequired
				totalNPV += project.npv
				capitalUsed += project.capitalRequired
				projectsSelected.append(project.name)
				remainingBudget -= project.capitalRequired
			}
		}

		return AllocationResult(
			allocations: allocations,
			totalNPV: totalNPV,
			capitalUsed: capitalUsed,
			projectsSelected: projectsSelected
		)
	}

	// MARK: - Integer Optimization (0-1 Knapsack)

	/// The largest `budget` or `capitalRequired` the knapsack will size: 2^53.
	///
	/// This is a representability limit, not a judgement about how much capital is plausible.
	/// The knapsack counts whole units of money, and 2^53 is the last magnitude at which a
	/// `Double` still tells adjacent whole units apart — past it the question the table answers
	/// cannot be posed. It is also far inside `Int`, so the conversion that sizes the table is
	/// exact for every amount that passes.
	public static var maximumAmount: T { T(9_007_199_254_740_992) }

	/// The most cells the knapsack table may have: ten million.
	///
	/// The table has one row per project plus one, and one column per whole unit of budget that
	/// the projects could actually spend, plus one. Both its memory and its running time are
	/// proportional to that product, so a finite, entirely representable budget is still a
	/// request for an arbitrary amount of both — a budget of a trillion over twenty projects is
	/// well formed and unanswerable.
	///
	/// Ten million is a resource limit and is stated as one. Measured in a release build with
	/// `T == Double` on an Apple silicon laptop, tables at the limit took 0.21 s (9 projects),
	/// 0.34 s (99) and 0.23 s (999) of one core, with a peak resident size of 11 MB. The bound on
	/// memory is one row of values — at most 8 bytes × 5,000,000 columns, 40 MB, and that only
	/// for a single project costing five million units — plus one bit per cell, 1.25 MB. The
	/// limit admits the type's own documented example (a budget of 120,000 over two projects)
	/// twenty-seven times over.
	///
	/// A problem past the limit is not a wrong question, only one stated in too fine a unit:
	/// express `budget` and `capitalRequired` in thousands or millions and it fits.
	public static var maximumTableCells: Int { 10_000_000 }

	/// Optimizes capital allocation using integer programming (0-1 knapsack).
	///
	/// Uses dynamic programming to find the optimal combination of projects.
	/// Each project is either fully funded or not funded at all. This is
	/// slower than the greedy algorithm but finds the globally optimal solution.
	///
	/// This form cannot throw, so it has one way to say that it was handed something it cannot
	/// size: the result. When ``optimizeIntegerProjects(validating:budget:)`` would refuse the
	/// input, this returns no selection, no allocations, and **`nan` for both `totalNPV` and
	/// `capitalUsed`** — never the zeroes of a genuine "fund nothing", which a caller would read
	/// as an answer. Prefer the validating form wherever the numbers come from outside the
	/// program: it says which argument was unusable and why.
	///
	/// For input the validating form accepts, the two return the same result to the bit.
	///
	/// - Parameters:
	///   - projects: The projects to consider.
	///   - budget: The total budget available.
	/// - Returns: The allocation result, or a result whose totals are `nan` when the input
	///   cannot be sized.
	public func optimizeIntegerProjects(
		projects: [Project],
		budget: T
	) -> AllocationResult {
		// Before 3.0.0-alpha.12 this function dropped a project it could not size and answered
		// for the rest, on the reasoning that "with a non-throwing signature dropping it is the
		// only option". It was not the only option, and it is the one the contamination contract
		// names first under Forbidden: an allocation that silently omits a project is
		// indistinguishable from one that considered it and declined. It also did not cover the
		// cases that mattered — a negative cost indexed past the table, a list left empty by the
		// filter crashed on `1...0`, and a large finite budget was simply allocated.
		do {
			return try optimizeIntegerProjects(validating: projects, budget: budget)
		} catch {
			// The result can say that the input was unusable but not which argument was, so
			// the refusal is logged. The error code is public; the description carries the
			// caller's own figures and is not.
			#if canImport(os)
			let code = (error as? BusinessMathError)?.code ?? "unclassified"
			logger.error("optimizeIntegerProjects could not size its input (\(code, privacy: .public)) and returned nan totals: \(error.localizedDescription, privacy: .private)")
			#endif
			return AllocationResult(
				allocations: [:],
				totalNPV: T.nan,
				capitalUsed: T.nan,
				projectsSelected: []
			)
		}
	}

	/// Optimizes capital allocation with the 0-1 knapsack, refusing input it cannot size.
	///
	/// The same computation as ``optimizeIntegerProjects(projects:budget:)`` — identical results,
	/// to the bit, for everything this accepts — with a typed refusal in place of a marked
	/// result. Use it for any `budget` or project list that arrives from outside the program: a
	/// request body, a file, a spreadsheet cell.
	///
	/// ```swift
	/// let optimizer = CapitalAllocationOptimizer<Double>()
	/// let projects = [
	///     CapitalAllocationOptimizer<Double>.Project(name: "Plant", npv: 150, capitalRequired: 100),
	///     CapitalAllocationOptimizer<Double>.Project(name: "Depot", npv: 80, capitalRequired: -5),
	/// ]
	/// do {
	///     let result = try optimizer.optimizeIntegerProjects(validating: projects, budget: 120)
	///     print(result.projectsSelected)
	/// } catch let error as BusinessMathError {
	///     print(error.localizedDescription)
	///     // Negative value for 'projects[1].capitalRequired' (-5.0) in
	///     // CapitalAllocationOptimizer.optimizeIntegerProjects
	/// }
	/// ```
	///
	/// ## What is refused
	///
	/// - `budget`, or any project's `capitalRequired`, that is not finite, is negative, or is
	///   above ``maximumAmount``.
	/// - Any project's `npv` that is not finite.
	/// - A table of more than ``maximumTableCells`` cells: `(projects.count + 1)` rows by one
	///   column per whole unit of budget the projects could spend, plus one.
	///
	/// Nothing is clamped, rounded into range, or left out. `risk` is not read by this
	/// algorithm and is not checked.
	///
	/// ## What is not refused
	///
	/// A budget of zero and an empty project list are valid questions whose answer is an empty
	/// allocation with totals of zero. A project that costs more than the budget is simply not
	/// affordable. A budget far larger than everything on the list costs nothing extra: the table
	/// is only as wide as the money that could be spent.
	///
	/// - Note: A project occupies `Int(capitalRequired)` whole units of the table — the cost is
	///   truncated — while the result reports the cost as given. Amounts with a fractional part
	///   are therefore sized optimistically, and a result built from them can report
	///   `capitalUsed` above `budget`. Express amounts in a unit small enough to be whole.
	///
	/// - Parameters:
	///   - projects: The projects to consider.
	///   - budget: The total budget available.
	/// - Returns: The allocation result.
	/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` for a
	///   non-finite `budget`, `capitalRequired` or `npv`;
	///   ``BusinessMathError/negativeValue(name:value:context:)`` for a negative `budget` or
	///   `capitalRequired`; ``BusinessMathError/outOfRange(value:min:max:context:)`` for one above
	///   ``maximumAmount``; ``BusinessMathError/resourceExhausted(resource:limit:context:)`` when
	///   the table would exceed ``maximumTableCells``. Each names the argument.
	public func optimizeIntegerProjects(
		validating projects: [Project],
		budget: T
	) throws -> AllocationResult {
		// Every argument is screened before either early exit, so an unusable budget is not
		// hidden by an empty list, nor an unusable project by a budget of zero.
		let maxBudget = try Self.wholeUnits(of: budget, named: "budget")
		var costs: [Int] = []
		costs.reserveCapacity(projects.count)
		for (index, project) in projects.enumerated() {
			guard project.npv.isFinite else {
				throw BusinessMathError.invalidInput(
					message: "projects[\(index)].npv must be a finite number",
					value: "\(project.npv)",
					expectedRange: "any finite value"
				)
			}
			costs.append(try Self.wholeUnits(
				of: project.capitalRequired, named: "projects[\(index)].capitalRequired"))
		}

		let nothing = AllocationResult(allocations: [:], totalNPV: 0, capitalUsed: 0, projectsSelected: [])
		guard budget > 0 else { return nothing }
		guard !projects.isEmpty else { return nothing }
		let n = projects.count

		// The table need only be as wide as the money that can be spent. A project dearer than
		// the budget is never taken, and once a column is at least the combined cost of every
		// affordable project seen so far, taking or leaving the next one reads the same two
		// values it would read at any wider column — so every column from `spendable` to the
		// budget holds the same bits, and the walk back from either selects the same projects.
		// Both operands are at most 2^53, so the sum cannot overflow.
		var spendable = 0
		for cost in costs where cost <= maxBudget {
			spendable = Swift.min(maxBudget, spendable + cost)
		}

		let width = spendable + 1
		let cells = (n + 1).multipliedReportingOverflow(by: width)
		guard !cells.overflow, cells.partialValue <= Self.maximumTableCells else {
			let total = cells.overflow ? "more than \(Int.max)" : "\(cells.partialValue)"
			throw BusinessMathError.resourceExhausted(
				resource: "capital allocation table cells",
				limit: Self.maximumTableCells,
				context: "\(Self.site): \(n + 1) rows × \(width) budget units = \(total) cells;"
					+ " express budget and capitalRequired in a coarser unit (thousands, millions),"
					+ " or use optimize(projects:budget:)"
			)
		}

		// best[w] = the most NPV reachable with budget w from the projects considered so far.
		// One row, filled from the top down so that `best[w - cost]` is still the previous
		// project's value when it is read. What the walk back needs from the full table is one
		// fact per cell — did taking this project improve on leaving it — so that is all that
		// is kept: a bit per cell instead of a value per cell.
		var best = [T](repeating: T(0), count: width)
		let wordsPerRow = (width + 63) / 64
		var improved = [UInt64](repeating: 0, count: wordsPerRow * n)

		for i in 0..<n {
			let cost = costs[i]
			guard cost <= spendable else { continue }
			let npv = projects[i].npv
			let rowStart = i * wordsPerRow
			for w in stride(from: spendable, through: cost, by: -1) {
				let valueWithProject = best[w - cost] + npv
				if valueWithProject > best[w] {
					best[w] = valueWithProject
					improved[rowStart + w / 64] |= UInt64(1) << UInt64(w % 64)
				}
			}
		}

		// Backtrack to find which projects were selected
		var allocations: [String: T] = [:]
		var projectsSelected: [String] = []
		var w = spendable
		var totalNPV: T = 0
		var capitalUsed: T = 0

		for i in (0..<n).reversed() {
			let word = improved[i * wordsPerRow + w / 64]
			guard (word >> UInt64(w % 64)) & 1 == 1 else { continue }
			let project = projects[i]
			allocations[project.name] = project.capitalRequired
			projectsSelected.append(project.name)
			totalNPV += project.npv
			capitalUsed += project.capitalRequired
			w -= costs[i]
		}

		return AllocationResult(
			allocations: allocations,
			totalNPV: totalNPV,
			capitalUsed: capitalUsed,
			projectsSelected: projectsSelected
		)
	}

	// MARK: - Screening

	/// How refusals name where they came from.
	private static var site: String { "CapitalAllocationOptimizer.optimizeIntegerProjects" }

	/// The whole units of money in `amount`, or a refusal that names the argument.
	///
	/// The order of the tests is the order of the diagnoses. `isFinite` goes first because every
	/// comparison with a `nan` is false: tested after `amount < 0` a `nan` would pass that test
	/// and be reported — or not reported — by whichever check happened to come next.
	///
	/// - Parameters:
	///   - amount: A budget or a capital requirement.
	///   - name: The argument as the caller wrote it, e.g. `projects[3].capitalRequired`.
	/// - Returns: `amount` truncated toward zero.
	/// - Throws: ``BusinessMathError`` when `amount` is not finite, is negative, or exceeds
	///   ``maximumAmount``.
	private static func wholeUnits(of amount: T, named name: String) throws -> Int {
		let limit: T = maximumAmount
		guard amount.isFinite else {
			throw BusinessMathError.invalidInput(
				message: "\(name) must be a finite number",
				value: "\(amount)",
				expectedRange: "0...9007199254740992"
			)
		}
		guard amount >= 0 else {
			throw BusinessMathError.negativeValue(name: name, value: Double(amount), context: site)
		}
		guard amount <= limit else {
			throw BusinessMathError.outOfRange(
				value: Double(amount), min: 0, max: Double(limit), context: "\(name) of \(site)")
		}
		return Int(amount)
	}
}
