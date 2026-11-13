//
//  SweepCodableTests.swift
//  BusinessMath
//
//  SeedSweep and SweepPoint persist: Codable round trips and the stored-record envelope.
//  Ported from SwiftGraphMetrics's SweepCodableTests.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

private func randomSweep(seed: UInt64) -> SeedSweep<Int> {
	var rng = SplitMix64(seed: seed)
	let points = (0..<Int.random(in: 1...5, using: &rng)).map { _ -> SweepPoint<Int> in
		let picks = (0..<Int.random(in: 0...4, using: &rng)).map { _ in
			NodeSelection<Int>.Pick(
				node: Int.random(in: 0..<12, using: &rng),
				marginalGain: Double.random(in: 0...20, using: &rng))
		}
		return SweepPoint(probability: Double.random(in: 0...1, using: &rng), selection: NodeSelection(picks))
	}
	return SeedSweep(results: points)
}

@Suite("SeedSweep and SweepPoint: Codable")
struct SweepCodableTests {

	@Test("A sweep round-trips through JSON exactly, for seeded arbitrary sweeps", arguments: Array(0..<40 as Range<UInt64>))
	func jsonRoundTrip(seed: UInt64) throws {
		let original = randomSweep(seed: seed)
		let back = try JSONDecoder().decode(SeedSweep<Int>.self, from: try JSONEncoder().encode(original))
		#expect(back == original)
		// Hashable equality is exact on the probabilities too; check the bits to be explicit.
		#expect(back.results.map(\.probability.bitPattern) == original.results.map(\.probability.bitPattern))
	}

	@Test("A sweep round-trips through its stored-record envelope, filed under \"seed-sweep\"",
		  arguments: Array(0..<40 as Range<UInt64>))
	func envelopeRoundTrip(seed: UInt64) throws {
		let original = randomSweep(seed: seed)
		let envelope = try MetricEnvelope(original)
		#expect(envelope.kind == "seed-sweep")
		#expect(try envelope.value(as: SeedSweep<Int>.self) == original)
		// And through the wire, as a stored result would.
		let wire = try JSONDecoder().decode(MetricEnvelope.self, from: try JSONEncoder().encode(envelope))
		#expect(try wire.value(as: SeedSweep<Int>.self) == original)
		// A different shape's reader does not mistake it.
		#expect(try envelope.value(as: NodeSelection<Int>.self) == nil)
	}

	@Test("A single point round-trips, including on String nodes", arguments: Array(0..<20 as Range<UInt64>))
	func pointRoundTrip(seed: UInt64) throws {
		var rng = SplitMix64(seed: seed)
		let picks = (0..<3).map {
			NodeSelection<String>.Pick(node: "n\($0)", marginalGain: Double.random(in: 0...9, using: &rng))
		}
		let point = SweepPoint(probability: Double.random(in: 0...1, using: &rng), selection: NodeSelection(picks))
		#expect(try JSONDecoder().decode(SweepPoint<String>.self, from: try JSONEncoder().encode(point)) == point)
	}

	@Test("A sweep produced by SeedSelector.sweep round-trips, derived summary included")
	func realSweepRoundTrips() throws {
		let graph = WeightedGraph(unweightedEdges: [(0, 1), (0, 2), (0, 3), (4, 5), (4, 6), (7, 8)])
		let sweep = try SeedSelector<Int>.sweep(
			on: graph, probabilities: [0.3, 0.6, 1.0], budget: 2, trials: 30, seed: 4)
		let back = try JSONDecoder().decode(SeedSweep<Int>.self, from: try JSONEncoder().encode(sweep))
		#expect(back == sweep)
		#expect(back.topKFrequency == sweep.topKFrequency)
		#expect(back.pairwiseJaccard == sweep.pairwiseJaccard)
		#expect(back.meanPairwiseJaccard == sweep.meanPairwiseJaccard)
		#expect(back.alwaysPicked == sweep.alwaysPicked)
	}

	@Test("Only the points are stored: the stability summary is recomputed, so it cannot disagree with them")
	func summaryIsDerived() throws {
		let sweep = randomSweep(seed: 3)
		let object = try #require(
			JSONSerialization.jsonObject(with: try JSONEncoder().encode(sweep)) as? [String: Any])
		#expect(Set(object.keys) == ["results"])
		// A stored value carrying a stale, wrong summary decodes to the summary the points imply.
		var tampered = object
		tampered["meanPairwiseJaccard"] = 0.123
		tampered["topKFrequency"] = [[99, 1.0]]
		let back = try JSONDecoder().decode(
			SeedSweep<Int>.self, from: try JSONSerialization.data(withJSONObject: tampered))
		#expect(back == sweep)
		#expect(back.meanPairwiseJaccard == sweep.meanPairwiseJaccard)
	}

	@Test("A point whose probability is NaN cannot be encoded, and says so rather than storing garbage")
	func nanProbabilityRefused() {
		let point = SweepPoint(probability: .nan, selection: NodeSelection<Int>([]))
		#expect(throws: (any Error).self) { _ = try JSONEncoder().encode(point) }
	}
}

