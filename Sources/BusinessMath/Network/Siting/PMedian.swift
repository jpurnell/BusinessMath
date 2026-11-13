//
//  PMedian.swift
//  BusinessMath
//

import Foundation

/// Chooses sites for a ``SiteProblem``.
public protocol SiteSelector: Sendable {

	/// Chooses `count` sites.
	///
	/// - Throws: ``SiteError`` if `count` is not in `1...problem.sites.count` or the cost
	///   function returns an invalid value.
	func select<Demand, Site>(
		_ problem: SiteProblem<Demand, Site>, count: Int
	) throws -> SiteAssignment<Demand, Site>
	where Demand: Hashable & Sendable & Comparable & Codable,
		  Site: Hashable & Sendable & Comparable & Codable
}

/// The p-median: choose `k` sites minimising total weighted cost, each demand point
/// served by its cheapest chosen site (ties to the site that sorts first).
///
/// ## Exact and heuristic branches
///
/// When the number of `k`-subsets, C(sites, k), is at most ``enumerationLimit``, every
/// subset is tried and the result is the proven optimum (``SiteAssignment/isExact`` is
/// `true`). Above the limit the result is **a heuristic with no optimality guarantee**:
/// greedy construction followed by Teitz–Bart swap local search to a local optimum, and
/// `isExact` is `false`. Among equal-cost subsets the first in site order wins.
///
/// - `count` below 1 or above the number of sites throws ``SiteError/invalidCount(requested:available:)``
///   (a request that cannot be met is reported, not silently clamped).
///
/// ```swift
/// // Demand on a line at 0, 1, 2, 10; cost is distance. The 1-median is the weighted median.
/// let problem = try SiteProblem(
///     demand: [0: 1, 1: 1, 2: 1, 10: 1], sites: [0, 1, 2, 10],
///     cost: { demand, site in Double(abs(demand - site)) })
/// let result = try PMedian().select(problem, count: 1)
/// print(result.chosen, result.isExact)   // [1] true
/// ```
public struct PMedian: SiteSelector {

	/// The default ``enumerationLimit``: 200,000 subsets, a fraction of a second of work.
	public static let defaultEnumerationLimit = 200_000

	/// Upper bound on Teitz–Bart improvement passes.
	static let maxSwapPasses = 10_000

	/// The largest C(sites, k) solved exactly by enumeration.
	public let enumerationLimit: Int

	/// Creates a selector.
	///
	/// - Parameter enumerationLimit: Above this many subsets the heuristic runs instead.
	public init(enumerationLimit: Int = PMedian.defaultEnumerationLimit) {
		self.enumerationLimit = max(0, enumerationLimit)
	}

	/// Chooses `count` sites; see the type documentation.
	public func select<Demand, Site>(
		_ problem: SiteProblem<Demand, Site>, count: Int
	) throws -> SiteAssignment<Demand, Site>
	where Demand: Hashable & Sendable & Comparable & Codable,
		  Site: Hashable & Sendable & Comparable & Codable {
		let available = problem.sites.count
		guard count >= 1, count <= available else {
			throw SiteError.invalidCount(requested: count, available: available)
		}
		let sites = problem.sites.sorted()
		let points = problem.demand.keys.sorted()
		var weights: [Double] = []
		var cost: [[Double]] = []
		for point in points {
			weights.append(problem.demand[point] ?? 0)
			var row: [Double] = []
			for site in sites { row.append(try problem.validatedCost(point, site)) }
			cost.append(row)
		}

		func objective(_ subset: [Int]) -> Double {
			var total = 0.0
			for d in cost.indices {
				var best = Double.infinity
				for s in subset where cost[d][s] < best { best = cost[d][s] }
				total += weights[d] * best
			}
			return total
		}

		let exact = Self.subsetCount(available, count, cap: enumerationLimit) <= enumerationLimit
		let picked: [Int]
		if exact {
			picked = Self.enumerate(
				n: available, k: count,
				subsets: Self.subsetCount(available, count, cap: enumerationLimit),
				objective: objective)
		} else {
			let greedy = Self.greedy(n: available, k: count, objective: objective)
			picked = Self.swapSearch(
				start: greedy, n: available, objective: objective)
		}

		var assignments: [SiteAssignment<Demand, Site>.Assignment] = []
		let chosenSorted = picked.sorted()
		for d in cost.indices {
			var bestSite = chosenSorted[0]
			for s in chosenSorted where cost[d][s] < cost[d][bestSite] { bestSite = s }
			assignments.append(.init(
				demand: points[d], site: sites[bestSite],
				cost: cost[d][bestSite], weight: weights[d]))
		}
		return SiteAssignment(
			chosen: (exact ? chosenSorted : picked).map { sites[$0] },
			assignments: assignments, isExact: exact)
	}

	/// C(n, k), saturating just above `cap` so it never overflows.
	static func subsetCount(_ n: Int, _ k: Int, cap: Int) -> Int {
		let r = min(k, n - k)
		guard r >= 0 else { return 0 }
		var value = 1
		for i in 0..<r {
			let (product, overflow) = value.multipliedReportingOverflow(by: n - i)
			guard !overflow else { return Int.max }
			value = product / (i + 1)
			if value > cap { return cap + 1 }
		}
		return value
	}

	/// Every k-subset in lexicographic order (`subsets` of them); the first strictly best wins.
	static func enumerate(n: Int, k: Int, subsets: Int, objective: ([Int]) -> Double) -> [Int] {
		var current = Array(0..<k)
		var best = current
		var bestValue = objective(current)
		for _ in 1..<max(1, subsets) {
			var i = k - 1
			while i >= 0 && current[i] == n - k + i { i -= 1 }
			guard i >= 0 else { break }
			current[i] += 1
			for j in (i + 1)..<max(i + 1, k) { current[j] = current[j - 1] + 1 }
			let value = objective(current)
			if value < bestValue {
				bestValue = value
				best = current
			}
		}
		return best
	}

	/// Greedy construction: add the site that lowers the objective most; ties to the lowest index.
	static func greedy(n: Int, k: Int, objective: ([Int]) -> Double) -> [Int] {
		var chosen: [Int] = []
		for _ in 0..<k {
			var bestSite = -1
			var bestValue = Double.infinity
			for s in 0..<n where !chosen.contains(s) {
				let value = objective(chosen + [s])
				if value < bestValue {
					bestValue = value
					bestSite = s
				}
			}
			guard bestSite >= 0 else { break }
			chosen.append(bestSite)
		}
		return chosen
	}

	/// Teitz–Bart: take the best single swap each pass until none improves.
	static func swapSearch(start: [Int], n: Int, objective: ([Int]) -> Double) -> [Int] {
		var chosen = start
		var current = objective(chosen)
		for _ in 0..<maxSwapPasses {
			var bestSwap: (position: Int, site: Int)?
			var bestValue = current
			for position in chosen.indices {
				for s in 0..<n where !chosen.contains(s) {
					var trial = chosen
					trial[position] = s
					let value = objective(trial)
					if value < bestValue - 1e-12 * max(1, abs(current)) {
						bestValue = value
						bestSwap = (position, s)
					}
				}
			}
			guard let swap = bestSwap else { break }
			chosen[swap.position] = swap.site
			current = bestValue
		}
		return chosen
	}
}
