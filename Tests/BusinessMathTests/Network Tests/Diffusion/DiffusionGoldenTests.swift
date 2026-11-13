//
//  DiffusionGoldenTests.swift
//  BusinessMath
//
//  Seed-for-seed reproduction of SwiftGraphMetrics. Every constant in GoldenSGMValues.swift
//  was computed by that package on 2026-11-12, before this code existed here. A stored seed
//  selection depends on every draw, every per-trial outcome and every estimate below, so each
//  is compared bit for bit, never within a tolerance.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

@Suite("Diffusion: golden values from SwiftGraphMetrics")
struct DiffusionGoldenTests {

	// MARK: Fixtures

	private static func weighted12() throws -> WeightedGraph<Int> {
		let edges: [(Int, Int, Double)] = GoldenSGM.weighted12Edges.map { ($0.from, $0.to, $0.weight) }
		return try WeightedGraph(edges: edges, isolatedNodes: Array(0..<12))
	}

	private static func flat(_ name: String) throws -> DiffusionGraph {
		switch name {
		case "kite": return DiffusionGraph(WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges))
		case "karate": return DiffusionGraph(WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges))
		default: return DiffusionGraph(try weighted12())
		}
	}

	private static func model(_ name: String) throws -> any DiffusionModel {
		switch name {
		case "ic0.3": return try IndependentCascade(probability: 0.3)
		case "icw0.8": return try IndependentCascade(weightScaledProbability: 0.8)
		default: return LinearThreshold()
		}
	}

	/// Count from the generator overload, which needs the unflattened graph.
	private static func generatorCount(
		graph name: String, model: any DiffusionModel, seeds: [Int], generatorSeed: UInt64
	) throws -> Int {
		var rng = Xoshiro256StarStar(seed: generatorSeed)
		switch name {
		case "kite":
			return model.simulate(
				on: WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges), seeds: seeds, using: &rng)
		case "karate":
			return model.simulate(
				on: WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges), seeds: seeds, using: &rng)
		default:
			return model.simulate(on: try weighted12(), seeds: seeds, using: &rng)
		}
	}

	// MARK: Draws

	@Test("Every recorded node draw is reproduced bit for bit")
	func nodeDraws() {
		#expect(GoldenSGM.nodeDraws.count == 40)
		for row in GoldenSGM.nodeDraws {
			let draw = TrialRandomness(masterSeed: row.seed, trial: row.trial).uniform(forNode: row.node)
			#expect(draw.bitPattern == row.bits, "seed \(row.seed) trial \(row.trial) node \(row.node)")
		}
	}

	@Test("Every recorded edge draw is reproduced bit for bit")
	func edgeDraws() {
		#expect(GoldenSGM.edgeDraws.count == 56)
		for row in GoldenSGM.edgeDraws {
			let draw = TrialRandomness(masterSeed: row.seed, trial: row.trial)
				.uniform(from: row.from, to: row.to)
			#expect(draw.bitPattern == row.bits, "seed \(row.seed) trial \(row.trial) \(row.from)->\(row.to)")
		}
	}

	// MARK: Flattening

	@Test("The compressed-row form of the weighted graph is reproduced exactly")
	func flattening() throws {
		let flat = DiffusionGraph(try Self.weighted12())
		#expect(flat.offsets == GoldenSGM.flatOffsets)
		#expect(flat.targets == GoldenSGM.flatTargets)
		#expect(flat.weights.map(\.bitPattern) == GoldenSGM.flatWeightBits)
		#expect(flat.weightedDegree.map(\.bitPattern) == GoldenSGM.flatDegreeBits)
		#expect(flat.maxWeight.bitPattern == GoldenSGM.flatMaxWeightBits)
	}

	// MARK: Per-trial outcomes

	@Test("Per-trial counts and exact activated sets match, for both models on three graphs")
	func perTrialSets() throws {
		#expect(GoldenSGM.trials.count == 168)
		for row in GoldenSGM.trials {
			let flat = try Self.flat(row.graph)
			let model = try Self.model(row.model)
			let randomness = TrialRandomness(masterSeed: row.masterSeed, trial: row.trial)
			let label = "\(row.graph) \(row.model) seeds \(row.seeds) trial \(row.trial)"
			let count = model.simulate(on: flat, seeds: row.seeds, randomness: randomness)
			#expect(count == row.count, "\(label)")
			// A node is active iff it is a valid seed or adding it as a seed changes nothing.
			let valid = Set(row.seeds.filter { $0 >= 0 && $0 < flat.nodeCount })
			var activated: [Int] = []
			for node in 0..<flat.nodeCount {
				if valid.contains(node) {
					activated.append(node)
				} else if model.simulate(on: flat, seeds: row.seeds + [node], randomness: randomness) == count {
					activated.append(node)
				}
			}
			#expect(activated == row.activated, "\(label)")
		}
	}

	// MARK: Estimates

	@Test("Mean and standard error are bit-identical, through both estimator overloads")
	func estimates() throws {
		#expect(GoldenSGM.estimates.count == 63)
		for row in GoldenSGM.estimates {
			let flat = try Self.flat(row.graph)
			let model = try Self.model(row.model)
			let estimator = try SpreadEstimator(trials: row.trials, seed: row.masterSeed)
			let estimate = estimator.estimate(model: model, on: flat, seeds: row.seeds)
			let label = "\(row.graph) \(row.model) seeds \(row.seeds) master \(row.masterSeed)"
			#expect(estimate.mean.bitPattern == row.meanBits, "\(label)")
			#expect(estimate.standardError.bitPattern == row.standardErrorBits, "\(label)")
			#expect(estimate.trials == row.trials)
		}
		// The unflattened overload on the one graph that is cheap to rebuild.
		let graph = try Self.weighted12()
		for row in GoldenSGM.estimates where row.graph == "weighted12" {
			let model = try Self.model(row.model)
			let estimate = try SpreadEstimator(trials: row.trials, seed: row.masterSeed)
				.estimate(model: model, on: graph, seeds: row.seeds)
			#expect(estimate.mean.bitPattern == row.meanBits)
			#expect(estimate.standardError.bitPattern == row.standardErrorBits)
		}
	}

	// MARK: Generator overload

	@Test("The generator overload keys the trial from one Xoshiro256StarStar draw, as before")
	func generatorOverload() throws {
		#expect(GoldenSGM.generatorCounts.count == 18)
		for row in GoldenSGM.generatorCounts {
			let model = try Self.model(row.model)
			let count = try Self.generatorCount(
				graph: row.graph, model: model, seeds: row.seeds, generatorSeed: row.generatorSeed)
			#expect(count == row.count, "\(row.graph) \(row.model) generator \(row.generatorSeed)")
		}
	}
}
