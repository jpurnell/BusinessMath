//
//  SitingTests.swift
//  BusinessMath
//
//  Site selection (p-median). Ported from SwiftGraphMetrics. Reference truth: businessMath
//  weighted-average results computed earlier in the project, hand arithmetic, and a brute
//  force written here. The envelope and node-score cases arrive with the metric value layer.
//

import Foundation
import SwiftDeterminism
import Testing

import TestSupport

@testable import BusinessMath

private let regions = [
	"NY/NJ/CT", "PA/DE/MD/DC/VA", "New England", "Southeast",
	"Midwest", "Texas-Mountain-Southwest", "West Coast", "International",
]
private let headcount: [Double] = [287, 186, 65, 123, 79, 96, 218, 65]
private let siteNames = ["New York", "Chicago", "Philadelphia"]

private let hours: [[Double]] = [
	[1, 5.5, 2], [3.5, 5.5, 2.5], [4, 6, 5], [5.5, 5, 5.5],
	[6, 3.5, 6], [7, 5.5, 7], [9, 7, 9], [13, 14, 13.5],
]
private let cash: [[Double]] = [
	[60, 330, 90], [130, 330, 90], [130, 340, 150], [380, 330, 360],
	[340, 110, 340], [440, 380, 440], [520, 400, 520], [900, 950, 880],
]

private func classProblem(_ table: [[Double]]) throws -> SiteProblem<String, String> {
	var weights: [String: Double] = [:]
	for (i, r) in regions.enumerated() { weights[r] = headcount[i] }
	return try SiteProblem(demand: weights, sites: siteNames) { region, site in
		guard let r = regions.firstIndex(of: region),
			let s = siteNames.firstIndex(of: site)
		else { return .nan }
		return table[r][s]
	}
}

private func denseMean(_ table: [[Double]], site: Int) -> Double {
	var total = 0.0
	for r in 0..<regions.count { total += headcount[r] * table[r][site] }
	return total / headcount.reduce(0, +)
}

@Suite("Site selection")
struct SitingTests {

	// businessMath values (4 dp), hand-checked: NY hours = 5827.5 / 1119.
	@Test("Golden path: travel hours")
	func goldenHours() throws {
		let problem = try classProblem(hours)
		#expect(abs(try problem.meanCost(at: "New York") - 5.2078) < 1e-3)
		#expect(abs(try problem.meanCost(at: "Chicago") - 6.1189) < 1e-3)
		#expect(abs(try problem.meanCost(at: "Philadelphia") - 5.3852) < 1e-3)
		for (i, name) in siteNames.enumerated() {
			#expect(abs(try problem.meanCost(at: name) - denseMean(hours, site: i)) < 1e-9)
		}
		#expect(abs(try problem.weightedCost(at: "New York") - 5827.5) < 1e-9)
		let result = try PMedian().select(problem, count: 1)
		#expect(result.chosen == ["New York"])
		#expect(result.isExact)
	}

	@Test("Golden path: cash cost picks a different winner")
	func goldenCash() throws {
		let problem = try classProblem(cash)
		#expect(abs(try problem.meanCost(at: "New York") - 301.6533) < 1e-3)
		#expect(abs(try problem.meanCost(at: "Chicago") - 368.9902) < 1e-3)
		#expect(abs(try problem.meanCost(at: "Philadelphia") - 300.5004) < 1e-3)
		for (i, name) in siteNames.enumerated() {
			#expect(abs(try problem.meanCost(at: name) - denseMean(cash, site: i)) < 1e-9)
		}
		let result = try PMedian().select(problem, count: 1)
		#expect(result.chosen == ["Philadelphia"])
		#expect(abs(result.meanWeightedCost - 300.5004) < 1e-3)
	}

	// Line, unit cost = distance. Demand weights: 0:1, 1:1, 2:1, 10:1, sites = same points.
	// k=1: costs 0->13, 1->11, 2->11, 10->27; tie 1 vs 2 goes to the lower site: 1.
	// Weighted case: weights 0:5, 4:1, 5:1, 9:5 (total 12). k=2 by hand: {0,9} costs
	// 4 at distance 4 from 0 (4) + 5 at distance 4 from 9 (4) = 8 ; {0,5}: 4*1+5*4 = 21 ;
	// {4,9}: 5*4 + 1*1 = 21 ; {0,4}: 1*1+5*5 = 26 ; so {0,9} wins at 8.
	// k=3: {0,4,9}: 4 served at 0, 5 at distance 1 -> total 1. {0,5,9}: 4 at distance 1 -> 1.
	// Tie; the lower subset in site order wins: [0,4,9].
	@Test("Hand cases on a line: k = 1, 2, 3")
	func lineHandCases() throws {
		let unit = try SiteProblem(
			demand: [0: 1, 1: 1, 2: 1, 10: 1], sites: [0, 1, 2, 10],
			cost: { demand, site in Double(abs(demand - site)) })
		let one = try PMedian().select(unit, count: 1)
		#expect(one.chosen == [1])
		#expect(abs(one.totalWeightedCost - 11) < 1e-12)

		let weighted = try SiteProblem(
			demand: [0: 5, 4: 1, 5: 1, 9: 5], sites: [0, 4, 5, 9],
			cost: { demand, site in Double(abs(demand - site)) })
		let two = try PMedian().select(weighted, count: 2)
		#expect(two.chosen == [0, 9])
		#expect(abs(two.totalWeightedCost - 8) < 1e-12)
		let three = try PMedian().select(weighted, count: 3)
		#expect(three.chosen == [0, 4, 9])
		#expect(abs(three.totalWeightedCost - 1) < 1e-12)
		#expect(three.loads.map(\.weight) == [5, 1 + 1, 5])
	}

	private func randomSiteInstance(
		_ rng: inout SplitMix64, sites: Int, demands: Int
	) -> (w: [Double], c: [[Double]]) {
		let w = (0..<demands).map { _ in Double.random(in: 0.1...10, using: &rng) }
		let c = (0..<demands).map { _ in
			(0..<sites).map { _ in Double.random(in: 0...20, using: &rng) }
		}
		return (w, c)
	}

	private func bruteForce(_ w: [Double], _ c: [[Double]], k: Int) -> Double {
		let siteCount = c[0].count
		var best = Double.infinity
		for mask in 0..<(1 << siteCount) where mask.nonzeroBitCount == k {
			var total = 0.0
			for d in 0..<w.count {
				var m = Double.infinity
				for s in 0..<siteCount where mask & (1 << s) != 0 { m = min(m, c[d][s]) }
				total += w[d] * m
			}
			best = min(best, total)
		}
		return best
	}

	private func greedyCost(_ w: [Double], _ c: [[Double]], k: Int) -> Double {
		var chosen: [Int] = []
		func total(_ set: [Int]) -> Double {
			(0..<w.count).reduce(0) { acc, d in
				acc + w[d] * (set.map { c[d][$0] }.min() ?? 0)
			}
		}
		for _ in 0..<k {
			let options = (0..<c[0].count).filter { !chosen.contains($0) }
			guard let pick = options.min(by: { total(chosen + [$0]) < total(chosen + [$1]) })
			else { break }
			chosen.append(pick)
		}
		return total(chosen)
	}

	@Test("Exact branch equals brute force; heuristic is never worse than greedy", .timeLimit(.minutes(1)))
	func bruteForceAgreement() throws {
		var rng = SplitMix64(seed: 2028)
		var heuristicHits = 0
		var trials = 0
		for _ in 0..<60 {
			let n = Int.random(in: 6...9, using: &rng)
			let k = Int.random(in: 1...3, using: &rng)
			let demands = Int.random(in: 5...12, using: &rng)
			let (w, c) = randomSiteInstance(&rng, sites: n, demands: demands)
			let problem = try SiteProblem(
				demand: Dictionary(uniqueKeysWithValues: w.enumerated().map { ($0, $1) }),
				sites: Array(0..<n),
				cost: { [c] d, s in c[d][s] })
			let optimum = bruteForce(w, c, k: k)

			let exact = try PMedian().select(problem, count: k)
			#expect(exact.isExact)
			#expect(abs(exact.totalWeightedCost - optimum) < 1e-9)

			let heuristic = try PMedian(enumerationLimit: 0).select(problem, count: k)
			#expect(!heuristic.isExact)
			#expect(heuristic.totalWeightedCost <= greedyCost(w, c, k: k) + 1e-9)
			#expect(heuristic.totalWeightedCost >= optimum - 1e-9)
			trials += 1
			if abs(heuristic.totalWeightedCost - optimum) < 1e-9 { heuristicHits += 1 }
		}
		print("Teitz-Bart matched the optimum on \(heuristicHits)/\(trials) instances")
		// Teitz-Bart has no optimality guarantee, so no theory gives this bar. It is a measured
		// regression bar: 56 of 60 instances (93%) with seed 2028 on 2026-11-11, bar 80%.
		#expect(Double(heuristicHits) / Double(trials) >= 0.8)
	}

	@Test("Edge cases")
	func edges() throws {
		let problem = try classProblem(hours)
		#expect(throws: SiteError.invalidCount(requested: 0, available: 3)) {
			try PMedian().select(problem, count: 0)
		}
		#expect(throws: SiteError.invalidCount(requested: 4, available: 3)) {
			try PMedian().select(problem, count: 4)
		}
		let single = try SiteProblem(demand: ["a": 1], sites: ["s"], cost: { _, _ in 2 })
		let one = try PMedian().select(single, count: 1)
		#expect(one.chosen == ["s"] && one.meanWeightedCost == 2)
		// k = number of sites chooses all, each demand to its cheapest.
		let all = try PMedian().select(problem, count: 3)
		#expect(all.chosen == ["Chicago", "New York", "Philadelphia"])
		#expect(all.assignments.first { $0.demand == "Midwest" }?.site == "Chicago")

		// zero-weight demand is allowed and contributes nothing.
		let zero = try SiteProblem(
			demand: ["a": 1, "b": 0], sites: ["x", "y"],
			cost: { d, s in d == "a" ? (s == "x" ? 1 : 2) : 100 })
		let result = try PMedian().select(zero, count: 1)
		#expect(result.chosen == ["x"] && result.totalWeightedCost == 1)

		#expect(throws: SiteError.noPositiveWeight) {
			try SiteProblem(demand: ["a": 0], sites: ["x"], cost: { _, _ in 1 })
		}
		#expect(throws: SiteError.noCandidateSites) {
			try SiteProblem<String, String>(demand: ["a": 1], sites: [], cost: { _, _ in 1 })
		}
		#expect(throws: SiteError.duplicateSite(site: "x")) {
			try SiteProblem(demand: ["a": 1], sites: ["x", "x"], cost: { _, _ in 1 })
		}
		#expect(throws: SiteError.invalidWeight(demand: "a")) {
			try SiteProblem(demand: ["a": -1, "b": 1], sites: ["x"], cost: { _, _ in 1 })
		}
		#expect(throws: SiteError.invalidWeight(demand: "a")) {
			try SiteProblem(demand: ["a": .nan], sites: ["x"], cost: { _, _ in 1 })
		}
		let bad = try SiteProblem(demand: ["a": 1], sites: ["x"], cost: { _, _ in .nan })
		#expect(throws: SiteError.invalidCost(demand: "a", site: "x")) {
			try PMedian().select(bad, count: 1)
		}
		let negative = try SiteProblem(demand: ["a": 1], sites: ["x"], cost: { _, _ in -1 })
		#expect(throws: SiteError.invalidCost(demand: "a", site: "x")) {
			try negative.meanCost(at: "x")
		}
	}

	@Test("Ties are stable: equal-cost sites resolve to the lower site, every run")
	func determinism() throws {
		let tie = try SiteProblem(
			demand: ["a": 1, "b": 1], sites: ["z", "m", "a"], cost: { _, _ in 1 })
		let first = try PMedian().select(tie, count: 1)
		#expect(first.chosen == ["a"])
		for _ in 0..<20 {
			#expect(try PMedian().select(tie, count: 1) == first)
			let heuristic = try PMedian(enumerationLimit: 0).select(tie, count: 1)
			#expect(heuristic.chosen == first.chosen)
			#expect(heuristic.assignments == first.assignments)
		}
		let two = try PMedian().select(tie, count: 2)
		#expect(two.chosen == ["a", "m"])
		#expect(two.assignments.allSatisfy { $0.site == "a" })
	}
}

// MARK: - Mutation-audit additions (test-quality pass, 2026-11-11)
//
// Everything below was written after a mutation audit showed that the tests above could
// not tell correct siting code from subtly broken siting code. Each test names the wrong
// behaviour it rejects. Oracles are independent of the implementation: a lexicographic
// brute force over index subsets, direct recomputation of every total from the cost
// function, and closed-form binomial coefficients.

/// A random instance on sites `0..<sites` and demands `0..<demands`, with its dense tables.
///
/// With `integerValued`, weights are in 1...5 and costs in 0...6, so totals are exact in
/// `Double` and equal-cost subsets are common: that is what exercises the tie-breaks.
private struct SiteInstance {
	let weights: [Double]
	let costs: [[Double]]
	let problem: SiteProblem<Int, Int>

	init(seed: UInt64, sites: Int, demands: Int, integerValued: Bool) throws {
		var rng = SplitMix64(seed: seed)
		var w: [Double] = []
		var c: [[Double]] = []
		for _ in 0..<demands {
			w.append(integerValued
				? Double(Int.random(in: 1...5, using: &rng))
				: Double.random(in: 0.1...10, using: &rng))
			c.append((0..<sites).map { _ in
				integerValued
					? Double(Int.random(in: 0...6, using: &rng))
					: Double.random(in: 0...20, using: &rng)
			})
		}
		weights = w
		costs = c
		problem = try SiteProblem(
			demand: Dictionary(uniqueKeysWithValues: w.enumerated().map { ($0, $1) }),
			sites: Array(0..<sites),
			cost: { [c] d, s in c[d][s] })
	}

	/// Total weighted cost of serving each demand from its cheapest member of `set`.
	func total(_ set: [Int]) -> Double {
		var sum = 0.0
		for d in 0..<weights.count { sum += weights[d] * (set.map { costs[d][$0] }.min() ?? 0) }
		return sum
	}

	/// Every k-subset of `0..<n` in lexicographic order.
	static func subsets(_ n: Int, _ k: Int) -> [[Int]] {
		var out: [[Int]] = []
		var current: [Int] = []
		func go(_ start: Int) {
			if current.count == k { out.append(current); return }
			guard start < n else { return }
			for i in start..<n { current.append(i); go(i + 1); current.removeLast() }
		}
		go(0)
		return out
	}

	/// The first strictly-best subset in lexicographic order, and its total.
	func optimum(k: Int) -> (set: [Int], total: Double) {
		var best: [Int] = []
		var bestValue = Double.infinity
		for set in Self.subsets(costs[0].count, k) {
			let value = total(set)
			if value < bestValue { bestValue = value; best = set }
		}
		return (best, bestValue)
	}
}

@Suite("Site selection: invariants")
struct SitingInvariantTests {

	private static let seeds: [UInt64] = Array(1...12)

	/// Checks everything a `SiteAssignment` must satisfy, against the instance rather than
	/// against the assignment's own fields.
	private func checkStructure(_ result: SiteAssignment<Int, Int>, _ instance: SiteInstance, k: Int) {
		// k distinct chosen sites, all candidates.
		#expect(result.chosen.count == k)
		#expect(Set(result.chosen).count == k)
		#expect(result.chosen.allSatisfy { (0..<instance.costs[0].count).contains($0) })
		// One assignment per demand point, sorted by demand.
		#expect(result.assignments.map(\.demand) == Array(0..<instance.weights.count))
		let chosenAscending = result.chosen.sorted()
		var recomputed = 0.0
		var loadBySite: [Int: Double] = [:]
		for item in result.assignments {
			// Weight and cost are the problem's, not invented.
			#expect(item.weight == instance.weights[item.demand])
			#expect(item.cost == instance.costs[item.demand][item.site])
			#expect(result.chosen.contains(item.site))
			// The cheapest chosen site, ties to the one that sorts first.
			let cheapest = chosenAscending.min {
				instance.costs[item.demand][$0] < instance.costs[item.demand][$1]
			}
			#expect(item.site == cheapest, "demand \(item.demand)")
			recomputed += item.weight * item.cost
			loadBySite[item.site, default: 0] += item.weight
		}
		#expect(abs(result.totalWeightedCost - recomputed) < 1e-9)
		#expect(abs(result.totalWeightedCost - instance.total(result.chosen)) < 1e-9)
		let totalWeight = instance.weights.reduce(0, +)
		#expect(abs(result.meanWeightedCost - recomputed / totalWeight) < 1e-9)
		// Loads: sorted by site, one per site that serves anyone, summing to the total weight.
		#expect(result.loads.map(\.site) == loadBySite.keys.sorted())
		for load in result.loads { #expect(abs(load.weight - (loadBySite[load.site] ?? .nan)) < 1e-9) }
		#expect(abs(result.loads.reduce(0) { $0 + $1.weight } - totalWeight) < 1e-9)
		#expect(abs(instance.problem.totalWeight - totalWeight) < 1e-9)
	}

	@Test("Exact result: structure, and the lexicographically first optimum, even with ties", .timeLimit(.minutes(1)),
		  arguments: SitingInvariantTests.seeds)
	func exactMatchesOracle(seed: UInt64) throws {
		for integerValued in [true, false] {
			let n = 5 + Int(seed % 3)
			let instance = try SiteInstance(seed: seed, sites: n, demands: 6, integerValued: integerValued)
			for k in 1...n {
				let result = try PMedian().select(instance.problem, count: k)
				let oracle = instance.optimum(k: k)
				#expect(result.isExact)
				#expect(abs(result.totalWeightedCost - oracle.total) < 1e-9)
				// First in site order among equal-cost subsets. For float costs ties do not
				// occur, so this is the optimum itself; for integer costs they do.
				#expect(result.chosen == oracle.set, "seed \(seed) n \(n) k \(k) int \(integerValued)")
				checkStructure(result, instance, k: k)
			}
		}
	}

	@Test("k = 1 is never worse than any single site, and equals the best one", .timeLimit(.minutes(1)),
		  arguments: SitingInvariantTests.seeds)
	func singleSiteIsBest(seed: UInt64) throws {
		let instance = try SiteInstance(seed: seed, sites: 7, demands: 9, integerValued: false)
		let result = try PMedian().select(instance.problem, count: 1)
		var best = Double.infinity
		for site in 0..<7 {
			let direct = try instance.problem.weightedCost(at: site)
			#expect(direct >= result.totalWeightedCost - 1e-9, "site \(site)")
			#expect(abs(direct - instance.total([site])) < 1e-9)
			best = min(best, direct)
		}
		#expect(abs(result.totalWeightedCost - best) < 1e-9)
	}

	@Test("Optimum never rises as k grows, and k = number of sites costs the cheapest-of-all", .timeLimit(.minutes(1)),
		  arguments: SitingInvariantTests.seeds)
	func monotoneInK(seed: UInt64) throws {
		let instance = try SiteInstance(seed: seed, sites: 6, demands: 8, integerValued: true)
		var previous = Double.infinity
		for k in 1...6 {
			let value = try PMedian().select(instance.problem, count: k).totalWeightedCost
			#expect(value <= previous + 1e-9, "k \(k)")
			previous = value
		}
		let floor = (0..<8).reduce(0.0) { acc, d in
			acc + instance.weights[d] * (instance.costs[d].min() ?? 0)
		}
		#expect(abs(previous - floor) < 1e-9)
	}

	@Test("Heuristic branch: structure, no better than the optimum, no worse than greedy, swap-optimal", .timeLimit(.minutes(1)),
		  arguments: SitingInvariantTests.seeds)
	func heuristicInvariants(seed: UInt64) throws {
		for integerValued in [true, false] {
			let instance = try SiteInstance(seed: seed, sites: 8, demands: 10, integerValued: integerValued)
			for k in 1...4 {
				let result = try PMedian(enumerationLimit: 0).select(instance.problem, count: k)
				#expect(!result.isExact)
				checkStructure(result, instance, k: k)
				let optimum = instance.optimum(k: k).total
				#expect(result.totalWeightedCost >= optimum - 1e-9)
				// Greedy construction by hand: add the site that lowers the total most,
				// lowest index on ties.
				var greedy: [Int] = []
				for _ in 0..<k {
					var bestSite = -1
					var bestValue = Double.infinity
					for s in 0..<8 where !greedy.contains(s) {
						let value = instance.total(greedy + [s])
						if value < bestValue { bestValue = value; bestSite = s }
					}
					greedy.append(bestSite)
				}
				#expect(result.totalWeightedCost <= instance.total(greedy) + 1e-9)
				// Local optimum: no single swap lowers the total.
				for position in 0..<k {
					for s in 0..<8 where !result.chosen.contains(s) {
						var trial = result.chosen
						trial[position] = s
						#expect(instance.total(trial) >= result.totalWeightedCost - 1e-9,
								"swap \(result.chosen[position]) -> \(s) improves")
					}
				}
			}
		}
	}

	@Test("Input order of the candidate list never changes the answer", .timeLimit(.minutes(1)),
		  arguments: SitingInvariantTests.seeds)
	func siteOrderInvariant(seed: UInt64) throws {
		let instance = try SiteInstance(seed: seed, sites: 7, demands: 7, integerValued: true)
		var rng = SplitMix64(seed: seed &+ 1000)
		let shuffled = try SiteProblem(
			demand: instance.problem.demand, sites: Array(0..<7).shuffled(using: &rng),
			cost: instance.problem.cost)
		for k in [1, 3] {
			for limit in [PMedian.defaultEnumerationLimit, 0] {
				let a = try PMedian(enumerationLimit: limit).select(instance.problem, count: k)
				let b = try PMedian(enumerationLimit: limit).select(shuffled, count: k)
				#expect(a == b, "k \(k) limit \(limit)")
			}
		}
	}

	@Test("Scaling every weight, or every cost, by c scales the total by c and changes no choice", .timeLimit(.minutes(1)),
		  arguments: [0.5, 3.0, 1000.0])
	func scaling(factor: Double) throws {
		let instance = try SiteInstance(seed: 77, sites: 6, demands: 8, integerValued: false)
		let weightScaled = try SiteProblem(
			demand: instance.problem.demand.mapValues { $0 * factor }, sites: Array(0..<6),
			cost: instance.problem.cost)
		let base = instance.problem.cost
		let costScaled = try SiteProblem(
			demand: instance.problem.demand, sites: Array(0..<6),
			cost: { d, s in base(d, s) * factor })
		for k in [1, 2, 3] {
			let original = try PMedian().select(instance.problem, count: k)
			for scaled in [weightScaled, costScaled] {
				let result = try PMedian().select(scaled, count: k)
				#expect(result.chosen == original.chosen)
				#expect(abs(result.totalWeightedCost - factor * original.totalWeightedCost)
					< 1e-9 * factor)
				// The mean per unit of demand scales with cost but not with weight.
				if scaled.totalWeight == instance.problem.totalWeight {
					#expect(abs(result.meanWeightedCost - factor * original.meanWeightedCost)
						< 1e-9 * factor)
				} else {
					#expect(abs(result.meanWeightedCost - original.meanWeightedCost) < 1e-9)
				}
			}
		}
	}

	// MARK: Exact/heuristic boundary and the internals

	@Test("A result is exact precisely when C(sites, k) <= enumerationLimit")
	func enumerationLimitBoundary() throws {
		let instance = try SiteInstance(seed: 5, sites: 6, demands: 5, integerValued: true)
		// C(6, 3) = 20.
		#expect(try PMedian(enumerationLimit: 20).select(instance.problem, count: 3).isExact)
		#expect(try PMedian(enumerationLimit: 21).select(instance.problem, count: 3).isExact)
		#expect(!(try PMedian(enumerationLimit: 19).select(instance.problem, count: 3).isExact))
		#expect(!(try PMedian(enumerationLimit: 0).select(instance.problem, count: 3).isExact))
		// C(6, 6) = 1 and C(6, 1) = 6 sit on the same boundary.
		#expect(try PMedian(enumerationLimit: 1).select(instance.problem, count: 6).isExact)
		#expect(!(try PMedian(enumerationLimit: 5).select(instance.problem, count: 1).isExact))
		#expect(try PMedian(enumerationLimit: 6).select(instance.problem, count: 1).isExact)
		#expect(PMedian(enumerationLimit: -7).enumerationLimit == 0)
		#expect(PMedian().enumerationLimit == PMedian.defaultEnumerationLimit)
		#expect(PMedian.defaultEnumerationLimit == 200_000)
	}

	@Test("subsetCount is the binomial coefficient, symmetric, saturating and overflow-safe",
		  arguments: [
			(5, 2, 10), (10, 3, 120), (10, 7, 120), (6, 0, 1), (7, 7, 1), (1, 1, 1),
			(30, 15, 155_117_520), (20, 10, 184_756), (4, 5, 0),
		  ] as [(Int, Int, Int)])
	func subsetCount(n: Int, k: Int, expected: Int) {
		#expect(PMedian.subsetCount(n, k, cap: Int.max) == expected)
		// With a cap below the true value it reports exactly cap + 1; at or above, the value.
		if expected > 1 {
			#expect(PMedian.subsetCount(n, k, cap: expected - 1) == expected)
			#expect(PMedian.subsetCount(n, k, cap: expected) == expected)
		}
		#expect(PMedian.subsetCount(40, 20, cap: 1000) == 1001)
		#expect(PMedian.subsetCount(100, 50, cap: Int.max) == Int.max)
	}

	@Test("enumerate visits every k-subset once, lexicographically, and keeps the first strict best")
	func enumerateOrder() {
		for (n, k) in [(5, 3), (6, 1), (4, 4), (6, 2)] {
			var visited: [[Int]] = []
			let total = PMedian.subsetCount(n, k, cap: Int.max)
			_ = PMedian.enumerate(n: n, k: k, subsets: total) { subset in
				visited.append(subset)
				return 0
			}
			#expect(visited == SiteInstance.subsets(n, k), "n \(n) k \(k)")
		}
		// A constant objective ties everything: the first subset wins.
		#expect(PMedian.enumerate(n: 5, k: 2, subsets: 10) { _ in 1 } == [0, 1])
		// Strictly best is the last subset: reached, not skipped.
		let all = SiteInstance.subsets(5, 2)
		#expect(PMedian.enumerate(n: 5, k: 2, subsets: 10) { Double(10 - (all.firstIndex(of: $0) ?? 0)) } == [3, 4])
	}

	@Test("greedy adds the best site each round, lowest index on ties, and stops when none are left")
	func greedyRules() {
		let values: [Double] = [1, 5, 3, 5, 2]
		let objective: ([Int]) -> Double = { set in -set.reduce(0.0) { $0 + values[$1] } }
		#expect(PMedian.greedy(n: 5, k: 2, objective: objective) == [1, 3])
		#expect(PMedian.greedy(n: 5, k: 3, objective: objective) == [1, 3, 2])
		#expect(PMedian.greedy(n: 4, k: 3, objective: { _ in 1 }) == [0, 1, 2])
		#expect(PMedian.greedy(n: 2, k: 5, objective: { _ in 1 }) == [0, 1])
	}

	@Test("swapSearch takes the best single swap until none improves by more than rounding")
	func swapSearchRules() {
		let values: [Double] = [1, 9, 4, 8, 2]
		let objective: ([Int]) -> Double = { set in -set.reduce(0.0) { $0 + values[$1] } }
		#expect(PMedian.swapSearch(start: [0, 4], n: 5, objective: objective).sorted() == [1, 3])
		// An improvement of 1e-6 is real and is taken; one of 1e-15 is rounding and is not.
		let near: [Double] = [1.0, 1.000_001]
		#expect(PMedian.swapSearch(start: [0], n: 2, objective: { -near[$0[0]] }) == [1])
		let tie: [Double] = [1.0, 1.0 + 1e-15]
		#expect(PMedian.swapSearch(start: [0], n: 2, objective: { -tie[$0[0]] }) == [0])
		// An already-optimal start is returned unchanged, in its own order.
		#expect(PMedian.swapSearch(start: [3, 1], n: 5, objective: objective) == [3, 1])
	}

	// MARK: Validation

	@Test("Invalid weights, costs and counts are each rejected with the offending value named")
	func validation() throws {
		for bad in [Double.infinity, -.infinity, .nan, -0.5] {
			#expect(throws: SiteError.invalidWeight(demand: "k")) {
				try SiteProblem(demand: ["k": bad, "ok": 1], sites: ["x"], cost: { _, _ in 1 })
			}
		}
		#expect(throws: SiteError.noDemand) {
			try SiteProblem<String, String>(demand: [:], sites: ["x"], cost: { _, _ in 1 })
		}
		// Zero cost is valid; any non-finite or negative cost is not, from every entry point.
		let free = try SiteProblem(demand: ["a": 1], sites: ["x"], cost: { _, _ in 0 })
		#expect(try free.meanCost(at: "x") == 0)
		#expect(try PMedian().select(free, count: 1).totalWeightedCost == 0)
		for bad in [Double.infinity, -.infinity, .nan, -1e-9] {
			let problem = try SiteProblem(demand: ["a": 1], sites: ["x", "y"], cost: { _, site in
				site == "y" ? bad : 1 })
			#expect(throws: SiteError.invalidCost(demand: "a", site: "y")) {
				try PMedian().select(problem, count: 1)
			}
			#expect(throws: SiteError.invalidCost(demand: "a", site: "y")) {
				try PMedian(enumerationLimit: 0).select(problem, count: 2)
			}
			#expect(throws: SiteError.invalidCost(demand: "a", site: "y")) {
				try problem.weightedCost(at: "y")
			}
			#expect(try problem.weightedCost(at: "x") == 1)
		}
		#expect(throws: SiteError.invalidCount(requested: -1, available: 2)) {
			try PMedian().select(try SiteProblem(demand: ["a": 1], sites: ["x", "y"], cost: { _, _ in 1 }), count: -1)
		}
		// Weights that are tiny but positive are accepted; the total need only be positive.
		let tiny = try SiteProblem(demand: ["a": 1e-300], sites: ["x"], cost: { _, _ in 2 })
		#expect(abs(try tiny.meanCost(at: "x") - 2) < 1e-12)
	}

	// MARK: SiteAssignment: ordering and round trip

	@Test("SiteAssignment sorts by demand and site whatever order it is built in, and re-sorting is a no-op",
		  arguments: SitingInvariantTests.seeds)
	func assignmentOrdering(seed: UInt64) throws {
		let instance = try SiteInstance(seed: seed, sites: 5, demands: 9, integerValued: false)
		let result = try PMedian().select(instance.problem, count: 3)
		var rng = SplitMix64(seed: seed)
		for _ in 0..<5 {
			let rebuilt = SiteAssignment<Int, Int>(
				chosen: result.chosen, assignments: result.assignments.shuffled(using: &rng),
				isExact: result.isExact)
			#expect(rebuilt == result)
			#expect(rebuilt.totalWeightedCost.bitPattern == result.totalWeightedCost.bitPattern)
		}
		let again = SiteAssignment<Int, Int>(
			chosen: result.chosen, assignments: result.assignments, isExact: result.isExact)
		#expect(again == result)
		#expect(result.assignments.map(\.demand) == result.assignments.map(\.demand).sorted())
		#expect(result.loads.map(\.site) == result.loads.map(\.site).sorted())
		// Loads are grouped by site: one entry per site, never two for the same one.
		#expect(Set(result.loads.map(\.site)).count == result.loads.count)
	}

	@Test("A result with no weight reports mean 0, not NaN")
	func zeroWeightMean() {
		let result = SiteAssignment<Int, Int>(
			chosen: [0],
			assignments: [.init(demand: 1, site: 0, cost: 5, weight: 0)], isExact: true)
		#expect(result.totalWeightedCost == 0)
		#expect(result.meanWeightedCost == 0)
		#expect(result.loads == [.init(site: 0, weight: 0)])
	}

	@Test("Round trip: encode then decode returns the original as JSON",
		  arguments: SitingInvariantTests.seeds)
	func roundTrip(seed: UInt64) throws {
		let instance = try SiteInstance(seed: seed, sites: 6, demands: 7, integerValued: seed % 2 == 0)
		for limit in [PMedian.defaultEnumerationLimit, 0] {
			let result = try PMedian(enumerationLimit: limit).select(instance.problem, count: 1 + Int(seed % 3))
			let data = try JSONEncoder().encode(result)
			#expect(try JSONDecoder().decode(SiteAssignment<Int, Int>.self, from: data) == result)
		}
	}
}

extension SitingInvariantTests {

	/// Scaling by 1e-20 puts every total far below the rounding step of a total that started
	/// at 1.0, so any offset folded into the objective would erase every difference between
	/// subsets and leave the first one winning.
	@Test("Scale invariance holds at extreme magnitudes, where an offset would swallow every difference", .timeLimit(.minutes(1)),
		  arguments: [1e-20, 1e-12, 1e12, 1e150])
	func extremeScaling(factor: Double) throws {
		var checkedDistinct = 0
		for seed in 1...6 as ClosedRange<UInt64> {
			let instance = try SiteInstance(seed: seed, sites: 6, demands: 8, integerValued: false)
			let scaled = try SiteProblem(
				demand: instance.problem.demand.mapValues { $0 * factor }, sites: Array(0..<6),
				cost: instance.problem.cost)
			for k in 1...4 {
				let original = try PMedian().select(instance.problem, count: k)
				let result = try PMedian().select(scaled, count: k)
				#expect(result.chosen == original.chosen, "seed \(seed) k \(k) factor \(factor)")
				let rescaled: Double = result.totalWeightedCost / factor
				let allowed: Double = 1e-9 * max(1, original.totalWeightedCost)
				#expect(abs(rescaled - original.totalWeightedCost) < allowed)
				if original.chosen != Array(0..<k) { checkedDistinct += 1 }
			}
		}
		// The check only means something where the optimum is not simply the first subset.
		#expect(checkedDistinct > 10)
	}

	@Test("enumerate stops at the last subset even when asked for more, and never reads past it")
	func enumerateSurplus() {
		for (n, k) in [(4, 2), (5, 3), (3, 3), (6, 1)] {
			var visited: [[Int]] = []
			_ = PMedian.enumerate(n: n, k: k, subsets: 1000) { subset in
				visited.append(subset)
				return 0
			}
			#expect(visited == SiteInstance.subsets(n, k), "n \(n) k \(k)")
		}
	}

	/// Improvement must exceed 1e-12 x max(1, |current|) to count: below it is rounding.
	/// Each row is (current objective, improvement offered, swap expected).
	@Test("swapSearch accepts an improvement only when it exceeds 1e-12 x max(1, |current|)",
		  arguments: [
			(1.0, 5e-13, false),    // below the tolerance at current 1
			(1.0, 5e-12, true),     // above it
			(1.0, 1.5e-12, true),   // between 1e-12 and 2e-12: rules out max(2, |current|)
			(0.5, 7e-13, false),    // current below 1: the floor of 1 applies, tolerance 1e-12
			(100.0, 5e-11, false),  // current above 1: tolerance scales up to 1e-10
			(100.0, 5e-10, true),
			(1e6, 5e-7, false),     // tolerance 1e-6
			(1e6, 5e-6, true),
		  ] as [(Double, Double, Bool)])
	func swapTolerance(current: Double, improvement: Double, expectSwap: Bool) {
		let objective: ([Int]) -> Double = { $0[0] == 0 ? current : current - improvement }
		let result = PMedian.swapSearch(start: [0], n: 2, objective: objective)
		#expect(result == (expectSwap ? [1] : [0]), "current \(current) improvement \(improvement)")
	}

	/// The tolerance is 1e-12 x max(1, |current|) where `current` is the objective being improved
	/// on, held fixed for the whole pass. Scanning in order, the first swap (to {1, 2}) takes the
	/// objective from 1e6 to 1.0; a later one (to {0, 3}) is better by 5e-7, which is below
	/// 1e-12 x 1e6 and so is rounding at the scale of the objective being improved on, and is not
	/// taken. A tolerance scaled by the best candidate so far (1.0) would take it and settle on a
	/// different set.
	@Test("swapSearch scales its tolerance by the objective being improved on, not by the best candidate")
	func swapToleranceScalesWithCurrent() {
		let table: [Set<Int>: Double] = [
			[0, 1]: 1e6, [1, 2]: 1.0, [0, 3]: 1.0 - 5e-7, [1, 3]: 1e6, [0, 2]: 1e6, [2, 3]: 1e6,
		]
		let result = PMedian.swapSearch(start: [0, 1], n: 4) { table[Set($0)] ?? .infinity }
		#expect(result == [2, 1])
	}

	@Test("An improvement exactly equal to the tolerance is not taken (the comparison is strict)")
	func swapToleranceBoundary() {
		for current in [1.0, 3.5, 250.0] {
			let threshold: Double = current - 1e-12 * max(1, abs(current))
			let result = PMedian.swapSearch(start: [0], n: 2) { $0[0] == 0 ? current : threshold }
			#expect(result == [0], "current \(current)")
		}
	}
}

extension SitingInvariantTests {

	/// Documented: a heuristic result lists sites "in the order the search settled on (greedy
	/// pick order, swaps replacing in place)", not sorted. When greedy's set is already
	/// swap-optimal the search changes nothing, so the list must be greedy's pick order.
	@Test("A heuristic result that needs no swaps lists the sites in greedy pick order, unsorted", .timeLimit(.minutes(1)))
	func heuristicKeepsPickOrder() throws {
		var unsortedCases = 0
		for seed in 1...40 as ClosedRange<UInt64> {
			let instance = try SiteInstance(seed: seed, sites: 8, demands: 10, integerValued: false)
			let k = 3
			var greedy: [Int] = []
			for _ in 0..<k {
				var bestSite = -1
				var bestValue = Double.infinity
				for s in 0..<8 where !greedy.contains(s) {
					let value = instance.total(greedy + [s])
					if value < bestValue { bestValue = value; bestSite = s }
				}
				greedy.append(bestSite)
			}
			let base = instance.total(greedy)
			var swapOptimal = true
			for position in 0..<k {
				for s in 0..<8 where !greedy.contains(s) {
					var trial = greedy
					trial[position] = s
					if instance.total(trial) < base - 1e-9 { swapOptimal = false }
				}
			}
			guard swapOptimal else { continue }
			let result = try PMedian(enumerationLimit: 0).select(instance.problem, count: k)
			#expect(result.chosen == greedy, "seed \(seed)")
			if greedy != greedy.sorted() { unsortedCases += 1 }
		}
		#expect(unsortedCases >= 3, "only \(unsortedCases) cases exercised an unsorted pick order")
		// The exact branch, by contrast, is ascending.
		let exact = try PMedian().select(try SiteInstance(seed: 3, sites: 8, demands: 10, integerValued: false).problem, count: 3)
		#expect(exact.chosen == exact.chosen.sorted())
	}
}

extension SitingInvariantTests {

	/// 120 sites choose 8 is about 8e11 subsets, far above the limit, so this is the
	/// heuristic at a size where enumeration would never finish, and the subset count must
	/// saturate rather than overflow on the way to that decision.
	@Test("A large heuristic problem finishes, is not exact, and is swap-optimal",
		  .timeLimit(.minutes(1)))
	func largeHeuristic() throws {
		let instance = try SiteInstance(seed: 99, sites: 120, demands: 60, integerValued: false)
		let result = try PMedian().select(instance.problem, count: 8)
		#expect(!result.isExact)
		#expect(result.chosen.count == 8 && Set(result.chosen).count == 8)
		#expect(abs(result.totalWeightedCost - instance.total(result.chosen)) < 1e-6)
		// Spot-check swap optimality on a spread of positions and candidates.
		for position in 0..<8 {
			for s in stride(from: 0, to: 120, by: 7) where !result.chosen.contains(s) {
				var trial = result.chosen
				trial[position] = s
				#expect(instance.total(trial) >= result.totalWeightedCost - 1e-9)
			}
		}
		// A subset count beyond Int: C(200, 100) is about 9e58 and must saturate, not trap.
		let wide = try SiteInstance(seed: 4, sites: 200, demands: 4, integerValued: true)
		let half = try PMedian().select(wide.problem, count: 100)
		#expect(!half.isExact && half.chosen.count == 100)
	}
}
