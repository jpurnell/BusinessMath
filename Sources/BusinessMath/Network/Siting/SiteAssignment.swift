//
//  SiteAssignment.swift
//  BusinessMath
//

import Foundation

/// The result of site selection: which sites were chosen and who each one serves.
///
/// Deterministic: assignments are sorted by demand, loads by site, and a demand point
/// equidistant from two chosen sites goes to the one that sorts first.
///
/// The stored-record shape (the `"site-assignment"` kind of the metric value layer) is declared
/// where that layer lives; this type is a plain `Codable` value without it.
///
/// ```swift
/// let problem = try SiteProblem(
///     demand: [1: 1, 2: 1, 3: 1], sites: [1, 2, 3],
///     cost: { demand, site in Double(abs(demand - site)) })
/// let result = try PMedian().select(problem, count: 1)
/// print(result.chosen, result.totalWeightedCost)   // [2] 2.0
/// ```
public struct SiteAssignment<
	Demand: Hashable & Sendable & Comparable & Codable,
	Site: Hashable & Sendable & Comparable & Codable
>: Sendable, Codable, Hashable {

	/// One demand point's assignment.
	public struct Assignment: Sendable, Codable, Hashable {
		/// The demand point.
		public let demand: Demand
		/// The chosen site serving it.
		public let site: Site
		/// The cost per unit of demand.
		public let cost: Double
		/// The demand weight.
		public let weight: Double
	}

	/// Weight served by one chosen site.
	public struct Load: Sendable, Codable, Hashable {
		/// The chosen site.
		public let site: Site
		/// The total demand weight assigned to it.
		public let weight: Double
	}

	/// The chosen sites. For an exact result, ascending site order; for a heuristic result,
	/// the order the search settled on (greedy pick order, swaps replacing in place).
	public let chosen: [Site]

	/// Every demand point's assigned site and cost, sorted by demand.
	public let assignments: [Assignment]

	/// Sum of weight times cost over all demand.
	public let totalWeightedCost: Double

	/// ``totalWeightedCost`` divided by the total weight.
	public let meanWeightedCost: Double

	/// Weight served by each chosen site, sorted by site.
	public let loads: [Load]

	/// `true` if the result is the proven optimum (enumeration); `false` if it is a
	/// local optimum from a heuristic with no optimality guarantee.
	public let isExact: Bool

	/// Builds the result from a choice and its assignments, deriving totals and loads.
	init(chosen: [Site], assignments: [Assignment], isExact: Bool) {
		let sorted = assignments.sorted { $0.demand < $1.demand }
		var total = 0.0
		var weightSum = 0.0
		var loadBySite: [Site: Double] = [:]
		for item in sorted {
			total += item.weight * item.cost
			weightSum += item.weight
			loadBySite[item.site, default: 0] += item.weight
		}
		self.chosen = chosen
		self.assignments = sorted
		self.totalWeightedCost = total
		self.meanWeightedCost = weightSum > 0 ? total / weightSum : 0
		self.loads = loadBySite.map { Load(site: $0.key, weight: $0.value) }
			.sorted { $0.site < $1.site }
		self.isExact = isExact
	}
}
