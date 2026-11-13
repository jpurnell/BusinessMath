//
//  WeightConsumerDiffusionTests.swift
//  BusinessMath
//
//  What the diffusion models, the estimator and siting do with the weights that remain legal
//  (zero, tiny, huge). Ported from SwiftGraphMetrics's WeightConsumerTests and
//  SummariseNeverNaNTests. The metric-registry cases arrive with the registry.
//

import Foundation
import SwiftDeterminism
import Testing

@testable import BusinessMath

@Suite("Weight consumers: diffusion and siting")
struct WeightConsumerDiffusionTests {

	/// A ring with a chord, so every node has two or three ties, in the given weight pattern.
	private func graph(weights: [Double]) throws -> WeightedGraph<String> {
		let pairs = [("n0", "n1"), ("n1", "n2"), ("n2", "n3"), ("n3", "n4"), ("n4", "n0"), ("n0", "n2")]
		var edges: [(String, String, Double)] = []
		for (offset, pair) in pairs.enumerated() {
			edges.append((pair.0, pair.1, weights[offset % weights.count]))
		}
		return try WeightedGraph(edges: edges, isolatedNodes: ["lonely"])
	}

	static let patterns: [[Double]] = [
		[0], [1e-300], [1e300], [1], [0, 1], [1e-300, 1e300], [1, 0, 1e-300, 1e300, 1, 0],
	]

	@Test("Every diffusion model keeps its count in range and the estimate finite", arguments: patterns)
	func diffusionFinite(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		let flat = DiffusionGraph(graph)
		#expect(flat.weights.allSatisfy { $0.isFinite && $0 >= 0 })
		#expect(flat.weightedDegree.allSatisfy { $0.isFinite && $0 >= 0 })
		#expect(flat.maxWeight.isFinite && flat.maxWeight >= 0)
		let estimator = try SpreadEstimator(trials: 25, seed: 3)
		let models: [any DiffusionModel] = [
			try IndependentCascade(probability: 0.5),
			try IndependentCascade(weightScaledProbability: 0.5),
			try IndependentCascade(weightScaledProbability: 1),
			LinearThreshold(),
		]
		let ceiling = Double(graph.nodeCount)
		for model in models {
			let estimate = estimator.estimate(model: model, on: flat, seeds: [0])
			#expect(estimate.mean.isFinite && estimate.mean >= 1 && estimate.mean <= ceiling)
			#expect(estimate.standardError.isFinite && estimate.standardError >= 0)
		}
	}

	@Test("Seed selection and a probability sweep pick real, distinct nodes", arguments: patterns)
	func selectionFinite(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		let models: [any DiffusionModel] = [try IndependentCascade(weightScaledProbability: 0.7), LinearThreshold()]
		for model in models {
			let selection = try SeedSelector<String>(model: model, budget: 3, trials: 20, seed: 5).compute(on: graph)
			#expect(selection.nodes.count == 3)
			#expect(Set(selection.nodes).count == 3)
			#expect(selection.picks.allSatisfy { $0.marginalGain.isFinite && $0.marginalGain >= 0 })
		}
		let sweep = try SeedSelector<String>.sweep(
			on: graph, probabilities: [0.2, 0.9], budget: 2, trials: 20, seed: 5,
			model: { try IndependentCascade(weightScaledProbability: $0) })
		#expect(sweep.meanPairwiseJaccard.isFinite)
	}

	@Test("Siting on NodeScores built from weighted degree stays finite", arguments: patterns)
	func sitingFromScoresFinite(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		var table: [String: Double] = [:]
		for node in graph.nodes {
			let degree: Double = graph.degree(of: node) ?? 0
			table[node] = degree.isFinite ? degree + 1 : 1
		}
		let problem = try SiteProblem(
			demand: NodeScores(table), sites: ["n0", "n2"], cost: { demand, site in demand == site ? 0 : 1 })
		let assignment = try PMedian().select(problem, count: 1)
		#expect(assignment.meanWeightedCost.isFinite)
		#expect(assignment.meanWeightedCost >= 0 && assignment.meanWeightedCost <= 1)
	}

	/// Demand is each node's weighted degree plus a unit floor: a graph whose every tie is zero
	/// has all-zero degrees, and a problem needs a positive total weight.
	@Test("Siting on degree-weighted demand stays finite", arguments: patterns)
	func sitingFinite(weights: [Double]) throws {
		let graph = try graph(weights: weights)
		var demand: [String: Double] = [:]
		for node in graph.nodes {
			let degree: Double = graph.degree(of: node) ?? 0
			demand[node] = degree.isFinite ? degree + 1 : 1
		}
		let problem = try SiteProblem(
			demand: demand, sites: ["n0", "n2"], cost: { demand, site in demand == site ? 0 : 1 })
		let assignment = try PMedian().select(problem, count: 1)
		#expect(assignment.meanWeightedCost.isFinite)
		#expect(assignment.meanWeightedCost >= 0 && assignment.meanWeightedCost <= 1)
	}
}

@Suite("SpreadEstimator.summarise: a standard error is never NaN")
struct SummariseNeverNaNTests {

	@Test("One trial of any count has standard error exactly zero, never NaN", arguments: [0, 1, 2, 7, 1000])
	func singleTrial(count: Int) {
		let estimate = SpreadEstimator.summarise(sum: count, sumOfSquares: count * count, trials: 1)
		#expect(estimate.standardError == 0)
		#expect(estimate.mean.isEqual(to: Double(count)))
	}

	@Test("For seeded random trial counts the standard error is finite, non-negative and matches the two-pass formula")
	func seededRandomRuns() {
		var rng = SplitMix64(seed: 21)
		for _ in 0..<300 {
			let trials = Int.random(in: 1...40, using: &rng)
			let counts = (0..<trials).map { _ in Int.random(in: 0...50, using: &rng) }
			let estimate = SpreadEstimator.summarise(
				sum: counts.reduce(0, +), sumOfSquares: counts.reduce(0) { $0 + $1 * $1 }, trials: trials)
			#expect(estimate.standardError.isFinite && estimate.standardError >= 0)
			let mean = Double(counts.reduce(0, +)) / Double(trials)
			if trials > 1 {
				var squares = 0.0
				for count in counts { squares += (Double(count) - mean) * (Double(count) - mean) }
				let variance = squares / Double(trials - 1)
				let expected = (variance / Double(trials)).squareRoot()
				#expect(abs(estimate.standardError - expected) < 1e-9)
			}
		}
	}
}
