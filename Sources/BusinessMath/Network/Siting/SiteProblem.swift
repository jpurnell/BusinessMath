//
//  SiteProblem.swift
//  BusinessMath
//

import Foundation

/// Why a siting problem or a selection was rejected.
public enum SiteError: Error, Sendable, Equatable {
	/// A demand weight was `NaN`, infinite or negative.
	case invalidWeight(demand: String)
	/// Every demand weight was zero, so there is nothing to serve.
	case noPositiveWeight
	/// The candidate list was empty.
	case noCandidateSites
	/// A candidate site appeared more than once.
	case duplicateSite(site: String)
	/// The cost function returned `NaN`, an infinity or a negative number.
	case invalidCost(demand: String, site: String)
	/// The requested number of sites was below one or above the candidate count.
	case invalidCount(requested: Int, available: Int)
	/// There is no demand at all.
	case noDemand
}

/// A weighted demand set, candidate sites and a cost function: the input to site selection.
///
/// This is not a graph metric — its inputs are who needs serving and what serving them
/// from each site costs, not a graph — so it has its own protocol, ``SiteSelector``.
///
/// ## Example
///
/// Three regions of demand, two candidate venues, cost as travel hours:
///
/// ```swift
/// let hours: [String: [String: Double]] = [
///     "East": ["Boston": 1, "Denver": 5],
///     "Mid": ["Boston": 3, "Denver": 3],
///     "West": ["Boston": 6, "Denver": 2],
/// ]
/// let problem = try SiteProblem(
///     demand: ["East": 10, "Mid": 5, "West": 5],
///     sites: ["Boston", "Denver"],
///     cost: { demand, site in hours[demand]?[site] ?? 0 })
/// print(try problem.meanCost(at: "Boston"))   // (10 + 15 + 30) / 20 = 2.75
/// let best = try PMedian().select(problem, count: 1)
/// print(best.chosen)   // ["Boston"]
/// ```
public struct SiteProblem<Demand: Hashable & Sendable, Site: Hashable & Sendable>: Sendable {

	/// Weight (how much is served) by demand point.
	public let demand: [Demand: Double]

	/// Candidate sites, in the order given.
	public let sites: [Site]

	/// Cost of serving one unit of one demand point from one site.
	public let cost: @Sendable (Demand, Site) -> Double

	/// Creates a problem.
	///
	/// - Parameters:
	///   - demand: Non-negative finite weights; at least one must be positive.
	///   - sites: Candidate sites; non-empty, no duplicates.
	///   - cost: Evaluated lazily; must return finite, non-negative values.
	/// - Throws: ``SiteError`` if the demand or the sites are invalid.
	public init(
		demand: [Demand: Double],
		sites: [Site],
		cost: @escaping @Sendable (Demand, Site) -> Double
	) throws {
		guard !demand.isEmpty else { throw SiteError.noDemand }
		var total = 0.0
		for (key, weight) in demand {
			guard weight.isFinite, weight >= 0 else {
				throw SiteError.invalidWeight(demand: String(describing: key))
			}
			total += weight
		}
		guard total > 0 else { throw SiteError.noPositiveWeight }
		guard !sites.isEmpty else { throw SiteError.noCandidateSites }
		var seen = Set<Site>()
		for site in sites {
			guard seen.insert(site).inserted else {
				throw SiteError.duplicateSite(site: String(describing: site))
			}
		}
		self.demand = demand
		self.sites = sites
		self.cost = cost
	}

	/// The sum of all demand weights; always positive.
	public var totalWeight: Double { demand.values.reduce(0, +) }

	/// The cost of one demand point and one site, validated.
	func validatedCost(_ point: Demand, _ site: Site) throws -> Double {
		let value = cost(point, site)
		guard value.isFinite, value >= 0 else {
			throw SiteError.invalidCost(
				demand: String(describing: point), site: String(describing: site))
		}
		return value
	}

	/// The total weighted cost of serving every demand point from one site.
	///
	/// - Throws: ``SiteError/invalidCost(demand:site:)`` if the cost function misbehaves.
	public func weightedCost(at site: Site) throws -> Double {
		var total = 0.0
		for (point, weight) in demand {
			total += weight * (try validatedCost(point, site))
		}
		return total
	}

	/// The weighted mean cost per unit of demand when everything is served from one site.
	///
	/// - Throws: ``SiteError/invalidCost(demand:site:)`` if the cost function misbehaves.
	public func meanCost(at site: Site) throws -> Double {
		let weight = totalWeight
		guard weight > 0 else { throw SiteError.noPositiveWeight }
		return try weightedCost(at: site) / weight
	}
}
