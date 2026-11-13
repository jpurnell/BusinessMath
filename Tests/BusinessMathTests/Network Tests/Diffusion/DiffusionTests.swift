//
//  DiffusionTests.swift
//  BusinessMath
//
//  Diffusion models and spread estimation. Ported from SwiftGraphMetrics's DiffusionTests.
//
//  Reference truth is derived by hand (closed forms on stars, paths and a two-neighbour
//  threshold case), or from a brute-force enumeration run through the same estimator.
//  None of it comes from the code under test's own output. The seed-selection and sweep
//  suites of the original arrive with the seed selector.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

private typealias F = DiffusionFixtures

// MARK: - Independent cascade

@Suite("IndependentCascade")
struct IndependentCascadeTests {

	/// Star, centre seeded: each leaf activates with probability p independently, so the
	/// expected spread is 1 + n*p. p = 0 gives 1 and p = 1 gives n + 1 exactly.
	@Test("Star centre at p = 0 spreads to exactly 1")
	func starCentreZero() throws {
		let g = F.star(leaves: 10)
		let e = try F.estimate(try IndependentCascade(probability: 0), g, seeds: ["c"], trials: 50)
		#expect(F.near(e.mean, 1.0))
		#expect(F.near(e.standardError, 0.0))
	}

	@Test("Star centre at p = 1 spreads to exactly n + 1")
	func starCentreOne() throws {
		let g = F.star(leaves: 10)
		let e = try F.estimate(try IndependentCascade(probability: 1), g, seeds: ["c"], trials: 50)
		#expect(F.near(e.mean, 11.0))
	}

	/// 1 + 10 * 0.5 = 6.0. Tolerance is four standard errors from the estimator itself.
	@Test("Star centre at p = 0.5, n = 10 is within 4 SE of 6.0 (2000 trials)")
	func starCentreHalf() throws {
		let g = F.star(leaves: 10)
		let e = try F.estimate(try IndependentCascade(probability: 0.5), g, seeds: ["c"], trials: 2000)
		#expect(e.trials == 2000)
		#expect(e.standardError > 0)
		#expect(abs(e.mean - 6.0) <= 4 * e.standardError, "mean \(e.mean) se \(e.standardError)")
	}

	@Test("A leaf at p = 1 reaches the whole star; at p = 0 only itself")
	func leafSeeds() throws {
		let g = F.star(leaves: 10)
		let one = try F.estimate(try IndependentCascade(probability: 1), g, seeds: ["l03"], trials: 20)
		let zero = try F.estimate(try IndependentCascade(probability: 0), g, seeds: ["l03"], trials: 20)
		#expect(F.near(one.mean, 11.0))
		#expect(F.near(zero.mean, 1.0))
	}

	@Test("Path at p = 1: spread is the component size from any seed")
	func pathFullProbability() throws {
		let g = F.path(8)
		let model = try IndependentCascade(probability: 1)
		for name in ["p0", "p3", "p7"] {
			#expect(F.near(try F.estimate(model, g, seeds: [name], trials: 10).mean, 8.0))
		}
	}

	@Test("Two components at p = 1: only the seeded component activates")
	func twoComponents() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("x", "y")])
		let model = try IndependentCascade(probability: 1)
		#expect(F.near(try F.estimate(model, g, seeds: ["a"], trials: 10).mean, 3.0))
		#expect(F.near(try F.estimate(model, g, seeds: ["x"], trials: 10).mean, 2.0))
		#expect(F.near(try F.estimate(model, g, seeds: ["a", "x"], trials: 10).mean, 5.0))
	}

	/// Weight-scaled form: probability p * w / maxWeight. Edge weights 1 and 0.5 with
	/// p = 1: the heavy edge always fires, the light edge fires with probability 0.5, so
	/// from the hub, expected spread = 1 + 1 + 0.5 = 2.5.
	@Test("Weight-scaled probability uses w / maxWeight")
	func weightScaled() throws {
		let g = try WeightedGraph(edges: [("hub", "heavy", 1.0), ("hub", "light", 0.5)])
		let model = try IndependentCascade(weightScaledProbability: 1.0)
		let e = try F.estimate(model, g, seeds: ["hub"], trials: 4000)
		#expect(abs(e.mean - 2.5) <= 4 * e.standardError, "mean \(e.mean) se \(e.standardError)")
	}

	@Test("Probability outside [0, 1] or non-finite is rejected")
	func invalidProbability() {
		#expect(throws: DiffusionError.self) { try IndependentCascade(probability: -0.1) }
		#expect(throws: DiffusionError.self) { try IndependentCascade(probability: 1.1) }
		#expect(throws: DiffusionError.self) { try IndependentCascade(probability: .nan) }
		#expect(throws: DiffusionError.self) { try IndependentCascade(weightScaledProbability: 2) }
	}
}

// MARK: - Linear threshold

@Suite("LinearThreshold")
struct LinearThresholdTests {

	/// Hand derivation. Node v has two neighbours a and b of equal weight, so each
	/// contributes w / deg(v) = 1/2.
	///   - Both seeded: influence = 1 >= theta for every theta in [0, 1), so v always
	///     activates. Spread = 3 exactly.
	///   - One seeded: influence = 1/2; v activates iff theta <= 1/2, probability 1/2.
	///     Spread = 2 + 1/2 = 1.5 expected.
	/// (a and b have no other neighbours, so seeded a cannot activate b.)
	@Test("Two seeded neighbours of equal weight always activate the shared node")
	func bothNeighbours() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "v"), ("b", "v")])
		let e = try F.estimate(LinearThreshold(), g, seeds: ["a", "b"], trials: 200)
		#expect(F.near(e.mean, 3.0))
	}

	@Test("One of two neighbours activates the shared node with probability 1/2")
	func oneNeighbour() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "v"), ("b", "v")])
		let e = try F.estimate(LinearThreshold(), g, seeds: ["a"], trials: 4000)
		// Expected spread 1 (a) + 1/2 (v) + (b only if v active and b's threshold met:
		// b has single neighbour v, weight share 1, so b activates whenever v does) = 1 + 0.5 + 0.5.
		#expect(abs(e.mean - 2.0) <= 4 * e.standardError, "mean \(e.mean) se \(e.standardError)")
	}

	@Test("A neighbour whose whole weight is active always activates (share = 1)")
	func fullShare() throws {
		let g = F.path(6)
		// Path: interior nodes have two neighbours (share 1/2), so a single end seed does not
		// always propagate. Node p1's only active neighbour is p0 (share 1/2): P = 1/2.
		// Expected spread from p0 is therefore strictly between 1 and 6.
		let e = try F.estimate(LinearThreshold(), g, seeds: ["p0"], trials: 500)
		#expect(e.mean > 1.0 && e.mean < 6.0)
		// Seeding both ends and everything between: spread = 6 exactly.
		let all = try F.estimate(LinearThreshold(), g, seeds: (0..<6).map { "p\($0)" }, trials: 10)
		#expect(F.near(all.mean, 6.0))
	}

	@Test("An isolated node is never activated by others and counts when seeded")
	func isolated() throws {
		let g = WeightedGraph(unweightedEdges: [("a", "b")], isolatedNodes: ["z"])
		#expect(F.near(try F.estimate(LinearThreshold(), g, seeds: ["z"], trials: 20).mean, 1.0))
		#expect(try F.estimate(LinearThreshold(), g, seeds: ["a"], trials: 400).mean <= 2.0)
	}
}

// MARK: - Estimator

@Suite("SpreadEstimator")
struct SpreadEstimatorTests {

	@Test("Identical inputs give bit-identical estimates")
	func deterministic() throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.3)
		let a = try F.estimate(model, g, seeds: ["Diane"], trials: 300, seed: 99)
		let b = try F.estimate(model, g, seeds: ["Diane"], trials: 300, seed: 99)
		#expect(a == b)
		#expect(a.mean.bitPattern == b.mean.bitPattern)
		#expect(a.standardError.bitPattern == b.standardError.bitPattern)
	}

	@Test("Different master seeds give different estimates")
	func seedsDiffer() throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.3)
		let a = try F.estimate(model, g, seeds: ["Diane"], trials: 300, seed: 1)
		let b = try F.estimate(model, g, seeds: ["Diane"], trials: 300, seed: 2)
		#expect(a != b)
	}

	@Test("Estimates are identical when run concurrently under different scheduling")
	func schedulingIndependent() async throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.3)
		let reference = try F.estimate(model, g, seeds: ["Diane", "Heather"], trials: 200, seed: 5)
		let results = await withTaskGroup(of: SpreadEstimate?.self) { group in
			for _ in 0..<16 {
				group.addTask {
					try? F.estimate(model, g, seeds: ["Diane", "Heather"], trials: 200, seed: 5)
				}
			}
			var all: [SpreadEstimate?] = []
			for await r in group { all.append(r) }
			return all
		}
		#expect(results.count == 16)
		#expect(results.allSatisfy { $0 == reference })
	}

	@Test("trials = 0 and negative trials throw a clear error")
	func zeroTrials() {
		#expect(throws: DiffusionError.invalidTrialCount(0)) {
			try SpreadEstimator(trials: 0, seed: 1)
		}
		#expect(throws: DiffusionError.invalidTrialCount(-3)) {
			try SpreadEstimator(trials: -3, seed: 1)
		}
	}

	@Test("Empty seed set spreads to nothing; out-of-range and duplicate seeds are ignored")
	func seedHandling() throws {
		let g = F.star(leaves: 4)
		let model = try IndependentCascade(probability: 1)
		let estimator = try SpreadEstimator(trials: 5, seed: 1)
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: []).mean, 0))
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [999, -1]).mean, 0))
		let c = F.index(g, "c")
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [c, c]).mean, 5.0))
	}

	@Test("A single trial reports zero standard error rather than dividing by zero")
	func singleTrial() throws {
		let g = F.star(leaves: 4)
		let e = try F.estimate(try IndependentCascade(probability: 0.5), g, seeds: ["c"], trials: 1)
		#expect(F.near(e.standardError, 0))
	}

	@Test("The RNG-driven simulate overload is reproducible for equal generator state")
	func rngOverload() throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.4)
		var r1 = Xoshiro256StarStar(seed: 3)
		var r2 = Xoshiro256StarStar(seed: 3)
		let s = [F.index(g, "Andre")]
		#expect(model.simulate(on: g, seeds: s, using: &r1) == model.simulate(on: g, seeds: s, using: &r2))
	}
}

@Suite("Diffusion: estimator and plumbing")
struct DiffusionEstimatorOracleTests {

	private struct DrawModel: DiffusionModel {
		func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
			Int(randomness.uniform(forNode: 0) * 10)
		}
	}

	@Test("Mean and standard error are the two-pass sample statistics of the per-trial counts",
		  arguments: [1, 2, 3, 7, 50, 400])
	func summaryStatistics(trials: Int) throws {
		let g = F.star(leaves: 2)
		let masterSeed: UInt64 = 19
		let counts = (0..<trials).map {
			Double(Int(TrialRandomness(masterSeed: masterSeed, trial: $0).uniform(forNode: 0) * 10))
		}
		let mean = counts.reduce(0, +) / Double(trials)
		var expectedSE = 0.0
		if trials > 1 {
			let variance = counts.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(trials - 1)
			expectedSE = (variance / Double(trials)).squareRoot()
		}
		let e = try SpreadEstimator(trials: trials, seed: masterSeed)
			.estimate(model: DrawModel(), on: g, seeds: [0])
		#expect(abs(e.mean - mean) < 1e-12)
		#expect(abs(e.standardError - expectedSE) < 1e-12)
		#expect(e.trials == trials)
	}

	@Test("summarise: hand-checked values, a degenerate run, and zero trials")
	func summarise() {
		// Counts 2,4,4,4,5,5,7,9: mean 5, sum of squares 232, sample variance 32/7.
		let e = SpreadEstimator.summarise(sum: 40, sumOfSquares: 232, trials: 8)
		#expect(abs(e.mean - 5) < 1e-12)
		let expectedVariance: Double = 32.0 / 7.0
		let expectedError: Double = (expectedVariance / 8.0).squareRoot()
		#expect(abs(e.standardError - expectedError) < 1e-12)
		#expect(e.trials == 8)
		// Every trial agrees: zero variance, zero error.
		let same = SpreadEstimator.summarise(sum: 21, sumOfSquares: 147, trials: 3)
		#expect(same.mean == 7 && same.standardError == 0)
		#expect(SpreadEstimator.summarise(sum: 9, sumOfSquares: 81, trials: 1)
			== SpreadEstimate(mean: 9, standardError: 0, trials: 1))
		#expect(SpreadEstimator.summarise(sum: 0, sumOfSquares: 0, trials: 0)
			== SpreadEstimate(mean: 0, standardError: 0, trials: 0))
	}

	@Test("The estimator reads the same trials as TrialRandomness(masterSeed:, trial:) in order, and the flat and unflattened overloads agree")
	func estimatorUsesTrialStreams() throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.35)
		let seeds = [F.index(g, "Diane")]
		let flat = DiffusionGraph(g)
		let estimator = try SpreadEstimator(trials: 64, seed: 8)
		var total = 0
		for trial in 0..<64 {
			total += model.simulate(
				on: flat, seeds: seeds, randomness: TrialRandomness(masterSeed: 8, trial: trial))
		}
		let a = estimator.estimate(model: model, on: g, seeds: seeds)
		let b = estimator.estimate(model: model, on: flat, seeds: seeds)
		#expect(a == b)
		#expect(abs(a.mean - Double(total) / 64) < 1e-12)
		#expect(estimator.trials == 64 && estimator.seed == 8)
		#expect(try SpreadEstimator(trials: 64, seed: 8) == estimator)
		#expect(try SpreadEstimator(trials: 64, seed: 9) != estimator)
		#expect(try SpreadEstimator(trials: 65, seed: 8) != estimator)
	}

	@Test("The generator overload keys one trial from exactly one draw of the generator")
	func rngOverloadConsumesOneDraw() throws {
		let g = F.kite()
		let model = try IndependentCascade(probability: 0.4)
		let seeds = [F.index(g, "Andre"), F.index(g, "Heather")]
		for seed in 1...10 as ClosedRange<UInt64> {
			var rng = Xoshiro256StarStar(seed: seed)
			var shadow = Xoshiro256StarStar(seed: seed)
			let got = model.simulate(on: g, seeds: seeds, using: &rng)
			let key = shadow.next()
			let want = model.simulate(
				on: DiffusionGraph(g), seeds: seeds,
				randomness: TrialRandomness(masterSeed: key, trial: 0))
			#expect(got == want, "seed \(seed)")
			// Exactly one value was consumed.
			#expect(rng == shadow, "seed \(seed)")
		}
	}

	@Test("Seed handling at the boundaries: 0 and n-1 count, n and -1 do not, repeats count once")
	func seedBoundaries() throws {
		let g = F.path(5)
		let model = try IndependentCascade(probability: 0)
		let estimator = try SpreadEstimator(trials: 3, seed: 1)
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [0]).mean, 1))
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [4]).mean, 1))
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [5]).mean, 0))
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [-1]).mean, 0))
		#expect(F.near(estimator.estimate(model: model, on: g, seeds: [0, 4, 4, 0, 5, -1]).mean, 2))
		let lt = LinearThreshold()
		#expect(F.near(estimator.estimate(model: lt, on: g, seeds: [5, -1]).mean, 0))
		#expect(F.near(estimator.estimate(model: lt, on: g, seeds: [0, 0]).mean, 1 + (estimator.estimate(model: lt, on: g, seeds: [0]).mean - 1)))
	}

	@Test("Models validate probabilities at the boundaries and expose what they were given")
	func probabilityValidation() throws {
		// The enum's description names the form and carries the value it was given.
		#expect("\(try IndependentCascade(probability: 0).edgeProbability)" == "uniform(0.0)")
		#expect("\(try IndependentCascade(probability: 1).edgeProbability)" == "uniform(1.0)")
		#expect(try IndependentCascade(weightScaledProbability: 0.25).edgeProbability == .weightScaled(base: 0.25))
		#expect(try IndependentCascade(probability: 0.5) != IndependentCascade(weightScaledProbability: 0.5))
		let rejected: [Double] = [Double(1).nextUp, Double(0).nextDown, 2, -1, .infinity, -.infinity]
		for bad in rejected {
			#expect(throws: DiffusionError.invalidProbability(bad)) { try IndependentCascade(probability: bad) }
			#expect(throws: DiffusionError.invalidProbability(bad)) {
				try IndependentCascade(weightScaledProbability: bad)
			}
		}
		do {
			_ = try IndependentCascade(probability: .nan)
			Issue.record("NaN must be rejected")
		} catch DiffusionError.invalidProbability(let value) {
			#expect(value.isNaN)
		}
	}

	@Test("A weight-scaled cascade on an edgeless graph, and any model on the empty graph, spread to nothing")
	func degenerateGraphs() throws {
		let empty = DiffusionGraph(try WeightedGraph<Int>(edges: []))
		#expect(empty.nodeCount == 0 && empty.maxWeight == 0 && empty.offsets == [0])
		let randomness = TrialRandomness(masterSeed: 1, trial: 0)
		#expect(try IndependentCascade(probability: 1).simulate(on: empty, seeds: [0], randomness: randomness) == 0)
		#expect(LinearThreshold().simulate(on: empty, seeds: [0], randomness: randomness) == 0)
		let lonely = DiffusionGraph(try WeightedGraph<Int>(edges: [], isolatedNodes: [0, 1, 2]))
		#expect(try IndependentCascade(weightScaledProbability: 1).simulate(on: lonely, seeds: [1], randomness: randomness) == 1)
		#expect(LinearThreshold().simulate(on: lonely, seeds: [0, 2], randomness: randomness) == 2)
	}

	/// NaN, infinite and negative weights used to be accepted here (and a NaN fired the
	/// weight-scaled cascade with certainty). They are now refused when the graph is built, which
	/// `WeightValidationTests` covers; these are the extreme weights that remain legal.
	@Test("Extreme legal weights never trap or hang, and the count stays in range",
		  arguments: [0, 1e-300, 1, 1e300])
	func hostileWeights(weight: Double) throws {
		let g = try WeightedGraph(edges: [(0, 1, weight), (1, 2, 1.0), (2, 3, weight), (3, 0, 1.0)])
		let flat = DiffusionGraph(g)
		for trial in 0..<20 {
			let randomness = TrialRandomness(masterSeed: 5, trial: trial)
			for model: any DiffusionModel in [
				try IndependentCascade(probability: 0.5),
				try IndependentCascade(weightScaledProbability: 0.5),
				LinearThreshold(),
			] {
				let count = model.simulate(on: flat, seeds: [0], randomness: randomness)
				#expect((1...4).contains(count), "weight \(weight) trial \(trial)")
			}
		}
	}

	@Test("A large graph finishes within a time limit", .timeLimit(.minutes(1)))
	func largeGraph() throws {
		let g = try F.randomWeightedGraph(nodes: 3000, edgeProbability: 0.002, seed: 9, weighted: true)
		let estimator = try SpreadEstimator(trials: 20, seed: 1)
		let e = estimator.estimate(model: try IndependentCascade(probability: 0.2), on: g, seeds: [0, 1, 2])
		#expect(e.mean >= 3 && e.mean <= 3000)
	}

	@Test("SpreadEstimate round-trips through JSON, for seeded arbitrary values",
		  arguments: [1, 2, 3, 4, 5, 6] as [UInt64])
	func spreadEstimateRoundTrip(seed: UInt64) throws {
		var rng = SplitMix64(seed: seed)
		for _ in 0..<50 {
			let original = SpreadEstimate(
				mean: Double.random(in: 0...1e6, using: &rng),
				standardError: Double.random(in: 0...1e3, using: &rng),
				trials: Int.random(in: 1...1_000_000, using: &rng))
			let data = try JSONEncoder().encode(original)
			let back = try JSONDecoder().decode(SpreadEstimate.self, from: data)
			#expect(back == original)
			#expect(back.mean.bitPattern == original.mean.bitPattern)
		}
	}
}

@Suite("Diffusion: graph and randomness primitives")
struct DiffusionPrimitiveTests {

	@Test("DiffusionGraph is the weighted graph's adjacency in compressed rows",
		  arguments: F.oracleSeeds)
	func flattening(seed: UInt64) throws {
		let graph = try F.randomWeightedGraph(nodes: 12, edgeProbability: 0.3, seed: seed, weighted: true)
		let flat = DiffusionGraph(graph)
		#expect(flat.nodeCount == graph.nodeCount)
		#expect(flat.offsets.count == graph.nodeCount + 1)
		#expect(flat.offsets.first == 0 && flat.offsets.last == flat.targets.count)
		#expect(flat.offsets == flat.offsets.sorted())
		#expect(flat.targets.count == 2 * graph.edgeCount && flat.weights.count == flat.targets.count)
		for node in 0..<graph.nodeCount {
			let expected = graph.adjacency[node]
			#expect(Array(flat.neighbours(of: node)) == expected.map(\.neighbour))
			#expect(Array(flat.weights[flat.offsets[node]..<flat.offsets[node + 1]]) == expected.map(\.weight))
			#expect(abs(flat.weightedDegree[node] - graph.weightedDegree(node)) < 1e-12)
		}
		let heaviest = try #require(graph.adjacency.flatMap { $0 }.map(\.weight).max())
		#expect(flat.maxWeight.isEqual(to: heaviest))
	}

	@Test("neighbours(of:) is empty out of bounds and valid at both ends")
	func neighbourBounds() {
		let flat = DiffusionGraph(WeightedGraph(unweightedEdges: [(0, 1), (1, 2)]))
		#expect(Array(flat.neighbours(of: 0)) == [1])
		#expect(Array(flat.neighbours(of: 1)) == [0, 2])
		#expect(Array(flat.neighbours(of: 2)) == [1])
		#expect(flat.neighbours(of: 3).isEmpty)
		#expect(flat.neighbours(of: -1).isEmpty)
		#expect(flat.neighbours(of: Int.max).isEmpty)
		#expect(flat.maxWeight == 1 && flat.weightedDegree == [1, 2, 1])
	}

	@Test("TrialRandomness: draws are in [0, 1), reproducible, and sensitive to every input")
	func trialRandomnessBasics() {
		let a = TrialRandomness(masterSeed: 42, trial: 3)
		#expect(a == TrialRandomness(masterSeed: 42, trial: 3))
		#expect(a != TrialRandomness(masterSeed: 42, trial: 4))
		#expect(a != TrialRandomness(masterSeed: 43, trial: 3))
		#expect(a.uniform(forNode: 7) == TrialRandomness(masterSeed: 42, trial: 3).uniform(forNode: 7))
		#expect(a.uniform(forNode: 7) != a.uniform(forNode: 8))
		#expect(a.uniform(forNode: 7) != TrialRandomness(masterSeed: 42, trial: 4).uniform(forNode: 7))
		#expect(a.uniform(from: 1, to: 2) == a.uniform(from: 1, to: 2))
		// The edge u->v and the edge v->u are different draws.
		#expect(a.uniform(from: 1, to: 2) != a.uniform(from: 2, to: 1))
		// An edge draw is not a node draw, even when the numbers coincide.
		#expect(a.uniform(from: 0, to: 5) != a.uniform(forNode: 5))
		// Pairs are distinguished all the way up the index range the 32-bit packing allows.
		#expect(a.uniform(from: 0, to: 1 << 31) != a.uniform(from: 1, to: 0))
		#expect(a.uniform(from: 0, to: 1 << 20) != a.uniform(from: 1, to: 0))
		#expect(a.uniform(from: 3, to: 1 << 30) != a.uniform(from: 3, to: 0))
		// Different trials give different draws for the same edge.
		#expect(a.uniform(from: 1, to: 2) != TrialRandomness(masterSeed: 42, trial: 4).uniform(from: 1, to: 2))
		#expect(a.uniform(from: 1, to: 2) != TrialRandomness(masterSeed: 43, trial: 3).uniform(from: 1, to: 2))
	}

	/// 20,000 uniform draws: mean 1/2, variance 1/12, so the standard error of the mean is
	/// sqrt(1/12 / 20000) = 0.00204 and 4.5 of them is 0.0092. Each of ten equal buckets
	/// holds Binomial(20000, 0.1): mean 2000, sd 42.4, tolerance 4.5 sd.
	@Test("Edge and node draws are uniform on [0, 1): mean, spread and bucket counts")
	func uniformity() {
		let n = 20_000
		for kind in 0..<2 {
			let randomness = TrialRandomness(masterSeed: 2028, trial: 1)
			let draws = (0..<n).map {
				kind == 0 ? randomness.uniform(forNode: $0) : randomness.uniform(from: $0 % 150, to: $0 / 150)
			}
			#expect(draws.allSatisfy { $0 >= 0 && $0 < 1 })
			let mean = draws.reduce(0, +) / Double(n)
			let meanError: Double = (1.0 / 12 / Double(n)).squareRoot()
			#expect(abs(mean - 0.5) <= 4.5 * meanError, "kind \(kind) mean \(mean)")
			let variance = draws.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n - 1)
			// Var of the sample variance of U(0,1): (mu4 - sigma^4 (n-3)/(n-1)) / n, mu4 = 1/80.
			let seVariance: Double = ((1.0 / 80 - (1.0 / 144)) / Double(n)).squareRoot()
			let uniformVariance: Double = 1.0 / 12
			#expect(abs(variance - uniformVariance) <= 4.5 * seVariance, "kind \(kind) variance \(variance)")
			var buckets = [Int](repeating: 0, count: 10)
			for value in draws { buckets[Int(value * 10)] += 1 }
			let sd = (Double(n) * 0.1 * 0.9).squareRoot()
			let expectedBucket: Double = Double(n) / 10
			for count in buckets { #expect(abs(Double(count) - expectedBucket) <= 4.5 * sd, "kind \(kind) \(buckets)") }
		}
	}

	@Test("All 2,500 directed pairs on 50 nodes get distinct draws")
	func pairsDistinct() {
		let randomness = TrialRandomness(masterSeed: 1, trial: 0)
		var seen = Set<UInt64>()
		for from in 0..<50 { for to in 0..<50 { seen.insert(randomness.uniform(from: from, to: to).bitPattern) } }
		#expect(seen.count == 2500)
	}
}

@Suite("Diffusion: boundaries found by the mutation audit")
struct DiffusionBoundaryTests {

	@Test("A graph of one node is simulated, not skipped: a seed counts as 1 under every model")
	func singleNode() throws {
		let one = DiffusionGraph(try WeightedGraph<Int>(edges: [], isolatedNodes: [0]))
		let randomness = TrialRandomness(masterSeed: 1, trial: 0)
		#expect(try IndependentCascade(probability: 1).simulate(on: one, seeds: [0], randomness: randomness) == 1)
		#expect(try IndependentCascade(weightScaledProbability: 1).simulate(on: one, seeds: [0], randomness: randomness) == 1)
		#expect(LinearThreshold().simulate(on: one, seeds: [0], randomness: randomness) == 1)
		#expect(LinearThreshold().simulate(on: one, seeds: [], randomness: randomness) == 0)
	}

	@Test("A single trial is a valid trial count for the estimator: a whole number of nodes, no spread")
	func oneTrial() throws {
		let g = F.karate()
		let model = try IndependentCascade(probability: 0.3)
		let spread = try SpreadEstimator(trials: 1, seed: 5).estimate(model: model, on: g, seeds: [0, 33])
		#expect(spread.trials == 1)
		#expect(spread.mean.rounded() == spread.mean)
		#expect(spread.mean >= 2)
		#expect(spread.standardError == 0)
	}

	@Test("Weight-scaled probability on a graph whose every edge weighs zero is 0, not NaN or 1")
	func allZeroWeights() throws {
		let g = DiffusionGraph(try WeightedGraph(edges: [(0, 1, 0.0), (1, 2, 0.0)]))
		#expect(g.maxWeight == 0)
		for trial in 0..<20 {
			let randomness = TrialRandomness(masterSeed: 3, trial: trial)
			#expect(try IndependentCascade(weightScaledProbability: 1).simulate(on: g, seeds: [0], randomness: randomness) == 1)
			// The uniform form ignores weights altogether.
			#expect(try IndependentCascade(probability: 1).simulate(on: g, seeds: [0], randomness: randomness) == 3)
		}
	}

	/// The edge fires iff draw < p, so a probability equal to the draw does not fire it and
	/// the next representable probability does. That is what makes P(fire) equal p exactly
	/// for a draw uniform on [0, 1).
	@Test("An edge fires on draw < p strictly: p equal to its draw does not fire, the next value up does")
	func strictInequality() throws {
		let g = DiffusionGraph(try WeightedGraph(edges: [(0, 1, 1.0)]))
		var checked = 0
		for trial in 0..<40 {
			let randomness = TrialRandomness(masterSeed: 77, trial: trial)
			let draw = randomness.uniform(from: 0, to: 1)
			guard draw > 0, draw.nextUp <= 1 else { continue }
			#expect(try IndependentCascade(probability: draw).simulate(on: g, seeds: [0], randomness: randomness) == 1)
			#expect(try IndependentCascade(probability: draw.nextUp).simulate(on: g, seeds: [0], randomness: randomness) == 2)
			#expect(try IndependentCascade(weightScaledProbability: draw).simulate(on: g, seeds: [0], randomness: randomness) == 1)
			// The reverse direction uses a different draw.
			let reverse = randomness.uniform(from: 1, to: 0)
			#expect(try IndependentCascade(probability: reverse).simulate(on: g, seeds: [1], randomness: randomness) == 1)
			checked += 1
		}
		#expect(checked == 40)
	}

	/// Node `v` has neighbours `a` (seeded, weight x) and `b` (weight 1 - x), so its share
	/// from `a` is x / (x + (1 - x)) = x, and the rule is `share + 1e-12 >= theta`. Choosing
	/// x relative to v's actual threshold places the share inside, on, or outside that
	/// tolerance. `b` has no other neighbour, so it follows `v` (share 1): the count is 3 if
	/// `v` activates and 1 if not.
	@Test("The threshold rule is share + 1e-12 >= theta: inside the tolerance activates, outside does not")
	func thresholdToleranceWindow() throws {
		func count(offsetFromTheta offset: Double, trial: Int) throws -> (Int, Double, Double)? {
			let theta = TrialRandomness(masterSeed: 9, trial: trial).uniform(forNode: 2)
			guard theta > 0.01, theta < 0.99 else { return nil }
			let x = theta + offset
			let y = 1 - x
			let share = x / (x + y)
			let graph = DiffusionGraph(try WeightedGraph(edges: [("a", "v", x), ("b", "v", y)]))
			let n = LinearThreshold().simulate(
				on: graph, seeds: [0], randomness: TrialRandomness(masterSeed: 9, trial: trial))
			return (n, share, theta)
		}
		var exact = 0
		for trial in 0..<400 {
			// Within the tolerance below the threshold: still activates. A tolerance of 1e-13
			// or a negative sign would lose it.
			if let (n, share, theta) = try count(offsetFromTheta: -5e-13, trial: trial), abs(share - (theta - 5e-13)) < 1e-15 {
				#expect(n == 3, "share below theta by 5e-13, trial \(trial)")
			}
			// Just above the threshold: activates (a negative tolerance would lose it).
			if let (n, share, theta) = try count(offsetFromTheta: 5e-13, trial: trial), abs(share - (theta + 5e-13)) < 1e-15 {
				#expect(n == 3, "share above theta by 5e-13, trial \(trial)")
			}
			// Just outside the tolerance (5e-12 against 1e-12): does not.
			if let (n, share, theta) = try count(offsetFromTheta: -5e-12, trial: trial), abs(share - (theta - 5e-12)) < 1e-15 {
				#expect(n == 1, "share below theta by 5e-12, trial \(trial)")
			}
			// Far outside the tolerance below the threshold: does not.
			if let (n, share, theta) = try count(offsetFromTheta: -5e-9, trial: trial), abs(share - (theta - 5e-9)) < 1e-15 {
				#expect(n == 1, "share below theta by 5e-9, trial \(trial)")
			}
			// Exactly on the edge of the tolerance the comparison is inclusive.
			if let (n, share, theta) = try count(offsetFromTheta: -1e-12, trial: trial), share + 1e-12 == theta {
				#expect(n == 3, "share + 1e-12 equals theta, trial \(trial)")
				exact += 1
			}
		}
		#expect(exact > 0, "no trial put share + 1e-12 exactly on theta")
	}

	@Test("A node whose incident weights are all zero has no share to give and never activates")
	func zeroDegreeNeverActivates() throws {
		// Negative weights, which used to cancel a degree to zero, are refused at the graph
		// boundary; zero-weight ties are the legal way to reach a zero weighted degree.
		let g = DiffusionGraph(try WeightedGraph(edges: [("s", "v", 0.0), ("t", "v", 0.0)]))
		// Nodes sorted: s = 0, t = 1, v = 2.
		for trial in 0..<20 {
			let randomness = TrialRandomness(masterSeed: 2, trial: trial)
			#expect(LinearThreshold().simulate(on: g, seeds: [0], randomness: randomness) == 1)
			#expect(LinearThreshold().simulate(on: g, seeds: [0, 1], randomness: randomness) == 2)
		}
	}
}

@Suite("Diffusion: reproducibility of the trial streams")
struct TrialStreamTests {

	/// A seed `m` and a seed `m + 1` must not share trials shifted by one: estimates made
	/// with neighbouring seeds (1, 2, 3, ...) would otherwise be correlated.
	@Test("No two (master seed, trial) pairs share a stream, including neighbouring seeds and trials")
	func streamsAreDistinct() {
		var seen = Set<UInt64>()
		for seed in 0..<30 as Range<UInt64> {
			for trial in 0..<30 {
				seen.insert(TrialRandomness(masterSeed: seed, trial: trial).uniform(forNode: 0).bitPattern)
			}
		}
		#expect(seen.count == 900)
		for seed in 1..<10 as Range<UInt64> {
			for trial in 1..<10 {
				let a = TrialRandomness(masterSeed: seed, trial: trial)
				let b = TrialRandomness(masterSeed: seed + 1, trial: trial - 1)
				#expect(a.uniform(from: 0, to: 1) != b.uniform(from: 0, to: 1), "seed \(seed) trial \(trial)")
			}
		}
	}

	@Test("Node indices that need all 32 bits of the edge packing are still told apart")
	func largeIndices() {
		let a = TrialRandomness(masterSeed: 42, trial: 3)
		#expect(a.uniform(from: 1 << 31, to: 5) != a.uniform(from: 0, to: 5))
		#expect(a.uniform(from: 1 << 31, to: 5) != a.uniform(from: 1 << 30, to: 5))
		#expect(a.uniform(forNode: 1 << 40) != a.uniform(forNode: 0))
	}

	/// A golden master, not a correctness proof: the exact numbers are the reproducibility
	/// contract (the same seed must select the same people in the next release), so they are
	/// pinned. Computed by an independent Python implementation of Vigna's splitmix64
	/// (checked against its published vector, seed 0 -> 0xE220A8397B1DCDAF) following the
	/// derivation documented on `TrialRandomness`; they were not read off this code.
	/// Changing them is a breaking change to every stored result and needs a changelog entry.
	@Test("Draws match values computed independently, bit for bit",
		  arguments: [
			(UInt64(42), 3, 0.2970818772970488, 0.33708464165628627, 0.4284450282604503, 0.6260283673034724, 0.14929205342471052),
			(UInt64(0), 0, 0.03310180062949397, 0.33623135575516283, 0.6557968405337219, 0.6159857589307652, 0.4416558485862969),
			(UInt64(2028), 17, 0.8317333022685992, 0.8425211063652377, 0.6760902307730351, 0.5493312139720753, 0.6590744099250909),
		  ] as [(UInt64, Int, Double, Double, Double, Double, Double)])
	func goldenMaster(seed: UInt64, trial: Int, node7: Double, node0: Double, edge12: Double, edge21: Double, edgeLarge: Double) {
		let r = TrialRandomness(masterSeed: seed, trial: trial)
		#expect(r.uniform(forNode: 7).isEqual(to: node7))
		#expect(r.uniform(forNode: 0).isEqual(to: node0))
		#expect(r.uniform(from: 1, to: 2).isEqual(to: edge12))
		#expect(r.uniform(from: 2, to: 1).isEqual(to: edge21))
		#expect(r.uniform(from: 0, to: 1 << 31).isEqual(to: edgeLarge))
	}
}

@Suite("Diffusion: model declarations")
struct DiffusionModelDeclarationTests {

	/// A model that declares nothing, so it gets every protocol default.
	private struct Plain: DiffusionModel {
		func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int { 0 }
	}

	/// Lazy seed selection is exact only for models whose every trial is a coverage function,
	/// so the declaration is part of the contract: independent cascade is, linear threshold
	/// is not (two neighbours that each fall short of a fixed threshold can together clear it),
	/// and a model that says nothing must be assumed not to be.
	@Test("Only the independent cascade declares submodular trials; the default assumes nothing")
	func submodularDeclarations() throws {
		#expect(try IndependentCascade(probability: 0.5).hasSubmodularTrials)
		#expect(try IndependentCascade(weightScaledProbability: 0.5).hasSubmodularTrials)
		#expect(!LinearThreshold().hasSubmodularTrials)
		#expect(!Plain().hasSubmodularTrials)
	}
}
