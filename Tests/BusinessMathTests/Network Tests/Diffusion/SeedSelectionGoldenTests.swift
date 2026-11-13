//
//  SeedSelectionGoldenTests.swift
//  BusinessMath
//
//  Seed-for-seed reproduction of SwiftGraphMetrics's seed selection. Every constant in
//  GoldenSeedValues.swift was computed by that package on 2026-11-12, before SeedSelector was
//  ported. A stored seed selection depends on the picks, their order, the gains, the stream
//  derivation, the refresh batching and the encoding, so each is compared exactly: every
//  Double by its bit pattern, every JSON text character for character.
//

import Foundation
import Testing
import TestSupport

@testable import BusinessMath

@Suite("SeedSelector: golden values from SwiftGraphMetrics")
struct SeedSelectionGoldenTests {

	// MARK: Fixtures

	private static func weighted12() throws -> WeightedGraph<Int> {
		let edges: [(Int, Int, Double)] = GoldenSGM.weighted12Edges.map { ($0.from, $0.to, $0.weight) }
		return try WeightedGraph(edges: edges, isolatedNodes: Array(0..<12))
	}

	private static func twoComponents() -> WeightedGraph<Int> {
		WeightedGraph(
			unweightedEdges: [(0, 1), (0, 2), (0, 3), (4, 5), (4, 6), (7, 8)], isolatedNodes: [9])
	}

	private static func intGraph(_ name: String) throws -> WeightedGraph<Int> {
		switch name {
		case "karate": return WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
		case "weighted12": return try weighted12()
		default: return twoComponents()
		}
	}

	private static func model(_ name: String) throws -> any DiffusionModel {
		switch name {
		case "ic0.3": return try IndependentCascade(probability: 0.3)
		case "icw0.8": return try IndependentCascade(weightScaledProbability: 0.8)
		default: return LinearThreshold()
		}
	}

	private static func encode<T: Encodable>(_ value: T) throws -> String {
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return String(decoding: try encoder.encode(value), as: UTF8.self)
	}

	// MARK: Selections

	/// Everything one golden row records about one selector run, compared to the live answer.
	private func check<N: Hashable & Comparable & Sendable & Codable>(
		_ row: GoldenSelection, on graph: WeightedGraph<N>, asyncSelection: NodeSelection<N>?
	) throws {
		let model = try Self.model(row.model)
		let label = "\(row.graph) \(row.model) budget \(row.budget) trials \(row.trials) seed \(row.seed)"
		let selector = SeedSelector<N>(model: model, budget: row.budget, trials: row.trials, seed: row.seed)
		let selection = try selector.compute(on: graph)
		#expect(selection.nodes.map { String(describing: $0) } == row.nodes, "\(label)")
		#expect(selection.picks.map(\.marginalGain.bitPattern) == row.gainBits, "\(label)")
		#expect(selection.totalGain.bitPattern == row.totalGainBits, "\(label)")
		if let asyncSelection {
			#expect(asyncSelection == selection, "\(label): async")
		}
		let chosen = selection.nodes.compactMap { graph.indexOf[$0] }
		let estimate = try SpreadEstimator(trials: row.trials, seed: row.seed)
			.estimate(model: model, on: graph, seeds: chosen)
		#expect(estimate.mean.bitPattern == row.spreadMeanBits, "\(label): spread")
		#expect(estimate.standardError.bitPattern == row.spreadStandardErrorBits, "\(label): standard error")
		#expect(try Self.encode(selection) == row.json, "\(label): json")
		#expect(try Self.encode(try MetricEnvelope(selection)) == row.envelopeJSON, "\(label): envelope")
		// The stored form reads back to the same selection.
		let back = try JSONDecoder().decode(NodeSelection<N>.self, from: Data(row.json.utf8))
		#expect(back == selection, "\(label): decoded")
		let stored = try JSONDecoder().decode(MetricEnvelope.self, from: Data(row.envelopeJSON.utf8))
		#expect(try stored.value(as: NodeSelection<N>.self) == selection, "\(label): envelope decoded")
	}

	@Test("Every recorded selection is reproduced exactly: picks, gains, spread, JSON, envelope")
	func selections() throws {
		#expect(GoldenSeeds.selections.count == 48)
		for row in GoldenSeeds.selections {
			if row.graph == "kite" {
				try check(row, on: WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges), asyncSelection: nil)
			} else {
				try check(row, on: try Self.intGraph(row.graph), asyncSelection: nil)
			}
		}
	}

	@Test("The task-group version reproduces the same recorded selections")
	func asyncSelections() async throws {
		for row in GoldenSeeds.selections {
			let model = try Self.model(row.model)
			let label = "\(row.graph) \(row.model) budget \(row.budget) seed \(row.seed)"
			if row.graph == "kite" {
				let graph = WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
				let found = try await SeedSelector<String>(
					model: model, budget: row.budget, trials: row.trials, seed: row.seed).computeAsync(on: graph)
				#expect(found.nodes == row.nodes, "\(label)")
				#expect(found.picks.map(\.marginalGain.bitPattern) == row.gainBits, "\(label)")
			} else {
				let graph = try Self.intGraph(row.graph)
				let found = try await SeedSelector<Int>(
					model: model, budget: row.budget, trials: row.trials, seed: row.seed).computeAsync(on: graph)
				#expect(found.nodes.map { String($0) } == row.nodes, "\(label)")
				#expect(found.picks.map(\.marginalGain.bitPattern) == row.gainBits, "\(label)")
			}
		}
	}

	// MARK: Sweeps

	private static func liveSweep(_ row: GoldenSweep) throws -> SeedSweep<Int> {
		let probabilities = row.points.map { Double(bitPattern: $0.probabilityBits) }
		let graph = try intGraph(row.graph)
		switch row.builder {
		case "icw":
			return try SeedSelector<Int>.sweep(
				on: graph, probabilities: probabilities, budget: row.budget, trials: row.trials,
				seed: row.seed, model: { try IndependentCascade(weightScaledProbability: $0) })
		case "lt":
			return try SeedSelector<Int>.sweep(
				on: graph, probabilities: probabilities, budget: row.budget, trials: row.trials,
				seed: row.seed, model: { _ in LinearThreshold() })
		default:
			return try SeedSelector<Int>.sweep(
				on: graph, probabilities: probabilities, budget: row.budget, trials: row.trials,
				seed: row.seed)
		}
	}

	/// A sweep rebuilt from the recorded points alone.
	private static func rebuilt(_ row: GoldenSweep) -> SeedSweep<Int> {
		SeedSweep(results: row.points.map { point in
			let picks = zip(point.nodes, point.gainBits).map {
				NodeSelection<Int>.Pick(node: $0, marginalGain: Double(bitPattern: $1))
			}
			return SweepPoint(
				probability: Double(bitPattern: point.probabilityBits), selection: NodeSelection(picks))
		})
	}

	private func compareSummary(_ sweep: SeedSweep<Int>, to row: GoldenSweep, _ label: String) {
		let frequency = sweep.topKFrequency.sorted { $0.key < $1.key }
		#expect(frequency.map(\.key) == row.frequencyNodes, "\(label): frequency nodes")
		#expect(frequency.map(\.value.bitPattern) == row.frequencyBits, "\(label): frequencies")
		#expect(sweep.pairwiseJaccard.map { $0.map(\.bitPattern) } == row.jaccardBits, "\(label): jaccard")
		#expect(sweep.meanPairwiseJaccard.bitPattern == row.meanJaccardBits, "\(label): mean jaccard")
		#expect(sweep.alwaysPicked == row.alwaysPicked, "\(label): always picked")
	}

	@Test("Every recorded sweep is reproduced exactly: picks, summary, JSON, envelope")
	func sweeps() throws {
		#expect(GoldenSeeds.sweeps.count == 10)
		for row in GoldenSeeds.sweeps {
			let label = row.name
			let sweep = row.builder == "points" ? Self.rebuilt(row) : try Self.liveSweep(row)
			#expect(sweep.results.count == row.points.count, "\(label)")
			for (found, want) in zip(sweep.results, row.points) {
				#expect(found.probability.bitPattern == want.probabilityBits, "\(label): probability")
				#expect(found.selection.nodes == want.nodes, "\(label): picks")
				#expect(found.selection.picks.map(\.marginalGain.bitPattern) == want.gainBits, "\(label): gains")
			}
			compareSummary(sweep, to: row, label)
			#expect(try Self.encode(sweep) == row.json, "\(label): json")
			#expect(try Self.encode(try MetricEnvelope(sweep)) == row.envelopeJSON, "\(label): envelope")
		}
	}

	@Test("The stability summary is derived the same way from every recorded set of points")
	func summaryFromPoints() {
		#expect(GoldenSeeds.sweeps.count == 10)
		for row in GoldenSeeds.sweeps {
			compareSummary(Self.rebuilt(row), to: row, "\(row.name) rebuilt")
		}
	}

	@Test("A stored sweep reads back equal, with the summary recomputed")
	func storedSweepsDecode() throws {
		for row in GoldenSeeds.sweeps {
			let expected = Self.rebuilt(row)
			let back = try JSONDecoder().decode(SeedSweep<Int>.self, from: Data(row.json.utf8))
			#expect(back == expected, "\(row.name)")
			compareSummary(back, to: row, "\(row.name) decoded")
			let stored = try JSONDecoder().decode(MetricEnvelope.self, from: Data(row.envelopeJSON.utf8))
			#expect(stored.kind == "seed-sweep", "\(row.name)")
			#expect(try stored.value(as: SeedSweep<Int>.self) == expected, "\(row.name) envelope")
		}
	}

	// MARK: Descriptor

	@Test("The descriptor encodes to exactly the text the original produced")
	func descriptor() throws {
		#expect(try Self.encode(SeedSelector<Int>.descriptor) == GoldenSeeds.descriptorJSON)
		#expect(try Self.encode(SeedSelector<String>.descriptor) == GoldenSeeds.descriptorJSON)
	}
}
