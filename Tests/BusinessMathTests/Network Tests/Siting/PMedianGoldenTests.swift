//
//  PMedianGoldenTests.swift
//  BusinessMath
//
//  Seed-for-seed reproduction of SwiftGraphMetrics's p-median. The instances and the answers
//  in GoldenSGMValues.swift were computed by that package on 2026-11-12, before this code
//  existed here. Stored site selections depend on the tie-breaks and the order of a heuristic
//  result, so chosen sites, assignments, loads and totals are compared exactly (bit for bit
//  for every Double).
//

import Foundation
import Testing

@testable import BusinessMath

@Suite("PMedian: golden values from SwiftGraphMetrics")
struct PMedianGoldenTests {

	private func problem(_ instance: GoldenSiteInstance) throws -> SiteProblem<Int, Int> {
		let weights: [Double] = instance.weightBits.map { Double(bitPattern: $0) }
		let costs: [[Double]] = instance.costBits.map { row in row.map { Double(bitPattern: $0) } }
		return try SiteProblem(
			demand: Dictionary(uniqueKeysWithValues: weights.enumerated().map { ($0, $1) }),
			sites: Array(0..<costs[0].count),
			cost: { d, s in costs[d][s] })
	}

	@Test("Every recorded selection is reproduced exactly, exact and heuristic branches alike")
	func selections() throws {
		#expect(GoldenSGM.sitingInstances.count == 3)
		#expect(GoldenSGM.sitingResults.count == 18)
		for row in GoldenSGM.sitingResults {
			let instance = try #require(GoldenSGM.sitingInstances.first { $0.name == row.instance })
			let result = try PMedian(enumerationLimit: row.enumerationLimit)
				.select(try problem(instance), count: row.count)
			let label = "instance \(row.instance) k \(row.count) limit \(row.enumerationLimit)"
			#expect(result.chosen == row.chosen, "\(label)")
			#expect(result.isExact == row.isExact, "\(label)")
			#expect(result.totalWeightedCost.bitPattern == row.totalBits, "\(label)")
			#expect(result.meanWeightedCost.bitPattern == row.meanBits, "\(label)")
			#expect(result.assignments.map(\.site) == row.assignedSites, "\(label)")
			#expect(result.loads.map(\.site) == row.loadSites, "\(label)")
			#expect(result.loads.map(\.weight.bitPattern) == row.loadBits, "\(label)")
		}
	}
}
