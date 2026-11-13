//
//  SiteAssignmentGoldenTests.swift
//  BusinessMath
//
//  The stored forms of SiteAssignment, and of siting from NodeScores, against what
//  SwiftGraphMetrics produced on 2026-11-12 (GoldenSeedValues.swift). The Codable shape of
//  SiteAssignment did not change when it became a MetricValue, and a stored record depends
//  on it, so the JSON is compared character for character.
//

import Foundation
import Testing

@testable import BusinessMath

@Suite("SiteAssignment and NodeScores siting: golden values from SwiftGraphMetrics")
struct SiteAssignmentGoldenTests {

	private func problem(_ instance: GoldenSiteInstance) throws -> SiteProblem<Int, Int> {
		let weights: [Double] = instance.weightBits.map { Double(bitPattern: $0) }
		let costs: [[Double]] = instance.costBits.map { row in row.map { Double(bitPattern: $0) } }
		return try SiteProblem(
			demand: Dictionary(uniqueKeysWithValues: weights.enumerated().map { ($0, $1) }),
			sites: Array(0..<costs[0].count),
			cost: { d, s in costs[d][s] })
	}

	private func encode<T: Encodable>(_ value: T) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return String(decoding: try encoder.encode(value), as: UTF8.self)
	}

	@Test("The JSON and the envelope of every recorded p-median answer are reproduced exactly")
	func storedForms() throws {
		#expect(GoldenSeeds.siteJSON.count == 18)
		for row in GoldenSeeds.siteJSON {
			let instance = try #require(GoldenSGM.sitingInstances.first { $0.name == row.instance })
			let result = try PMedian(enumerationLimit: row.enumerationLimit)
				.select(try problem(instance), count: row.count)
			let label = "instance \(row.instance) k \(row.count) limit \(row.enumerationLimit)"
			#expect(try encode(result) == row.json, "\(label): json")
			let envelope = try MetricEnvelope(result)
			#expect(envelope.kind == "site-assignment", "\(label)")
			#expect(try encode(envelope) == row.envelopeJSON, "\(label): envelope")
			// What was stored by the original reads back as this answer.
			let back = try JSONDecoder().decode(SiteAssignment<Int, Int>.self, from: Data(row.json.utf8))
			#expect(back == result, "\(label): decoded")
			let stored = try JSONDecoder().decode(MetricEnvelope.self, from: Data(row.envelopeJSON.utf8))
			#expect(try stored.value(as: SiteAssignment<Int, Int>.self) == result, "\(label): envelope decoded")
		}
	}

	@Test("Siting from NodeScores reproduces the original's answers, totals and JSON exactly")
	func nodeScoreSiting() throws {
		#expect(GoldenSeeds.nodeScoreSiting.count == 5)
		for row in GoldenSeeds.nodeScoreSiting {
			var table: [Int: Double] = [:]
			for (key, bits) in zip(row.demandKeys, row.demandBits) { table[key] = Double(bitPattern: bits) }
			let problem = try SiteProblem(
				demand: NodeScores(table), sites: row.sites,
				cost: { demand, site in 1.5 * Double(abs(demand - site)) })
			let result = try PMedian().select(problem, count: row.count)
			let label = "\(row.name) k \(row.count)"
			#expect(problem.demand == table, "\(label)")
			#expect(problem.sites == row.sites, "\(label)")
			#expect(problem.totalWeight.bitPattern == row.totalWeightBits, "\(label)")
			#expect(result.chosen == row.chosen, "\(label)")
			#expect(result.totalWeightedCost.bitPattern == row.totalCostBits, "\(label)")
			#expect(result.meanWeightedCost.bitPattern == row.meanCostBits, "\(label)")
			#expect(try encode(result) == row.json, "\(label): json")
		}
	}
}
