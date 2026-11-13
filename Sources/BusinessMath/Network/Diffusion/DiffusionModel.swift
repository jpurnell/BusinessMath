//
//  DiffusionModel.swift
//  BusinessMath
//

import Foundation
import SwiftDeterminism

/// A rule for how something spreads through a graph.
///
/// A model simulates **one trial**: given the nodes that start active and the trial's random
/// numbers, it says how many nodes end up active. Averaging many trials is
/// ``SpreadEstimator``'s job, and choosing seeds is ``SeedSelector``'s.
///
/// ## What a model assumes
///
/// Every model needs parameters nobody can observe — how likely a tie is to carry influence,
/// or how much influence a person needs before acting. This package ships the two standard
/// models, ``IndependentCascade`` and ``LinearThreshold``. A result is only ever as good as
/// the parameters fed in, which is why ``SeedSelector/sweep(on:probabilities:budget:trials:seed:model:)``
/// exists.
///
/// ## Writing a model
///
/// Draw every random number from the ``TrialRandomness`` argument — never from a global or
/// shared generator — and a conforming model inherits determinism and common random numbers.
///
/// ```swift
/// import BusinessMath
///
/// /// Everything a seed touches directly activates; nothing spreads further.
/// struct OneHop: DiffusionModel {
///     func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
///         var active = Set(seeds.filter { $0 >= 0 && $0 < graph.nodeCount })
///         for seed in Array(active) { active.formUnion(graph.neighbours(of: seed)) }
///         return active.count
///     }
/// }
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let count = OneHop().simulate(
///     on: DiffusionGraph(graph), seeds: [0], randomness: TrialRandomness(masterSeed: 1, trial: 0))
/// print(count)   // 2
/// ```
public protocol DiffusionModel: Sendable {

	/// Runs one trial.
	///
	/// - Parameters:
	///   - graph: The flattened graph.
	///   - seeds: Indices of the nodes that start active. Out-of-range indices are ignored and
	///     duplicates count once.
	///   - randomness: This trial's random numbers.
	/// - Returns: How many nodes are active at the end, seeds included.
	func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int

	/// Whether, for any one trial's randomness, adding a seed to a larger seed set never gains
	/// more than adding it to a smaller one.
	///
	/// ``SeedSelector`` may skip re-evaluating a candidate whose last gain was already too small
	/// to lead (lazy evaluation) only if this is `true`, because only then is an old gain an
	/// upper bound on the current one. The default is `false`, which is always safe: the
	/// selector then re-scores every candidate every round and returns exactly plain greedy.
	///
	/// Declare `true` only if each trial of the model is a fixed set of live edges (or any other
	/// coverage function), which is submodular. ``IndependentCascade`` is; ``LinearThreshold``
	/// is not, because a node's threshold is fixed per trial and two neighbours that each fall
	/// short of it can together clear it.
	var hasSubmodularTrials: Bool { get }
}

extension DiffusionModel {

	/// `false`: assume nothing, so seed selection stays exactly greedy.
	public var hasSubmodularTrials: Bool { false }

	/// Runs one trial, drawing the trial's randomness from a caller-supplied generator.
	///
	/// Convenient for a single ad hoc trial. It consumes one value from `rng` to key the
	/// trial; for repeatable estimates over many trials use ``SpreadEstimator``.
	///
	/// ```swift
	/// import SwiftDeterminism
	/// import BusinessMath
	///
	/// let graph = WeightedGraph(unweightedEdges: [("a", "b")])
	/// var rng = Xoshiro256StarStar(seed: 1)
	/// let model = try IndependentCascade(probability: 1)
	/// print(model.simulate(on: graph, seeds: [0], using: &rng))   // 2
	/// ```
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - seeds: Indices of the nodes that start active.
	///   - rng: Source of the trial's randomness.
	public func simulate<Node: Hashable & Comparable & Sendable, Generator: RandomNumberGenerator>(
		on graph: WeightedGraph<Node>, seeds: [Int], using rng: inout Generator
	) -> Int {
		let randomness = TrialRandomness(masterSeed: rng.next(), trial: 0)
		return simulate(on: DiffusionGraph(graph), seeds: seeds, randomness: randomness)
	}
}

/// Shared cascade plumbing: de-duplicated, in-range seeds and the activation frontier.
enum CascadeSupport {

	/// Marks the valid seeds active and returns them as the initial frontier.
	static func activate(
		seeds: [Int], nodeCount: Int, active: inout [Bool]
	) -> [Int] {
		var frontier: [Int] = []
		for seed in seeds where seed >= 0 && seed < nodeCount && !active[seed] {
			active[seed] = true
			frontier.append(seed)
		}
		return frontier
	}
}

/// How likely an edge is to carry the cascade, in ``IndependentCascade``.
public enum EdgeProbability: Sendable, Equatable {
	/// Every edge fires with the same probability, ignoring weights.
	case uniform(Double)
	/// An edge of weight `w` fires with probability `base · w / maxWeight`, capped at 1, so
	/// the strongest tie in the graph fires with probability `base`.
	case weightScaled(base: Double)
}

/// The independent cascade model (Goldenberg et al. 2001; Kempe, Kleinberg & Tardos 2003).
///
/// When a node becomes active it gets exactly **one** chance to activate each inactive
/// neighbour, succeeding with the edge's probability. Success or failure, it never tries
/// again. The cascade ends when a round activates nobody.
///
/// ## Two forms
///
/// - ``init(probability:)``: every edge fires with the same probability. Use this when edge
///   weights are not trustworthy as strengths.
/// - ``init(weightScaledProbability:)``: edge `i–j` fires with probability
///   `p · w_ij / maxEdgeWeight`, capped at 1.
///
/// Closed form on a star with `n` leaves, centre seeded, uniform probability `p`: expected
/// spread `1 + n·p`.
///
/// ```swift
/// import BusinessMath
///
/// let star = WeightedGraph(unweightedEdges: [("c", "a"), ("c", "b"), ("c", "d")])
/// let model = try IndependentCascade(probability: 1)
/// let estimate = try SpreadEstimator(trials: 10, seed: 1)
///     .estimate(model: model, on: star, seeds: [star.indexOf["c"] ?? 0])
/// print(estimate.mean)   // 4.0
/// ```
public struct IndependentCascade: DiffusionModel, Equatable {

	/// `true`. Every edge's coin is fixed per trial, so a trial is a set of live edges and the
	/// nodes reached from a seed set are a coverage function, which is submodular.
	public var hasSubmodularTrials: Bool { true }

	/// How edges fire.
	public let edgeProbability: EdgeProbability

	/// A cascade in which every edge fires with the same probability.
	///
	/// - Parameter probability: In `[0, 1]`.
	/// - Throws: ``DiffusionError/invalidProbability(_:)`` otherwise.
	public init(probability: Double) throws {
		try Self.validate(probability)
		self.edgeProbability = .uniform(probability)
	}

	/// A cascade in which an edge's firing probability scales with its weight.
	///
	/// - Parameter weightScaledProbability: The probability of the heaviest edge, in `[0, 1]`.
	/// - Throws: ``DiffusionError/invalidProbability(_:)`` otherwise.
	public init(weightScaledProbability: Double) throws {
		try Self.validate(weightScaledProbability)
		self.edgeProbability = .weightScaled(base: weightScaledProbability)
	}

	private static func validate(_ p: Double) throws {
		guard p.isFinite, p >= 0, p <= 1 else { throw DiffusionError.invalidProbability(p) }
	}

	/// Runs one cascade.
	public func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
		let n = graph.nodeCount
		guard n > 0 else { return 0 }
		var active = [Bool](repeating: false, count: n)
		var queue = CascadeSupport.activate(seeds: seeds, nodeCount: n, active: &active)

		// Probability of an edge of weight w. Hoisted: zero maxWeight means no edges to fire.
		let uniformProbability: Double?
		let base: Double
		let scale: Double
		switch edgeProbability {
		case .uniform(let p):
			uniformProbability = p
			base = p
			scale = 0
		case .weightScaled(let b):
			uniformProbability = nil
			base = b
			scale = graph.maxWeight > 0 ? 1 / graph.maxWeight : 0
		}

		// Each node enters the queue at most once, so the walk is bounded by `n`.
		for head in 0..<n {
			guard head < queue.count else { break }
			let source = queue[head]
			for slot in graph.offsets[source]..<graph.offsets[source + 1] {
				let target = graph.targets[slot]
				guard !active[target] else { continue }
				let probability = uniformProbability ?? min(1, base * graph.weights[slot] * scale)
				guard randomness.uniform(from: source, to: target) < probability else { continue }
				active[target] = true
				queue.append(target)
			}
		}
		return queue.count
	}
}

/// The linear threshold model (Granovetter 1978; Kempe, Kleinberg & Tardos 2003).
///
/// Every node draws a threshold uniformly from `[0, 1)` once per trial. A node activates when
/// the share of its **weighted degree** held by active neighbours reaches its threshold. The
/// weight a neighbour `u` contributes to `v` is `w_uv / degree(v)`, so a node's incoming
/// weights sum to 1.
///
/// A node with two neighbours of equal weight, one active, holds share ½ and activates with
/// probability ½. With both active the share is 1, which meets every threshold, so it always
/// activates. Nodes with no edges never activate unless seeded.
///
/// Unlike ``IndependentCascade`` this has no probability parameter: the threshold
/// distribution is the assumption. That is still an assumption — uniform thresholds are
/// a convention, not something measured.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "v"), ("b", "v")])
/// let a = graph.indexOf["a"] ?? 0
/// let b = graph.indexOf["b"] ?? 0
/// let estimate = try SpreadEstimator(trials: 20, seed: 1)
///     .estimate(model: LinearThreshold(), on: graph, seeds: [a, b])
/// print(estimate.mean)   // 3.0
/// ```
public struct LinearThreshold: DiffusionModel, Equatable {

	/// Creates the model. It has no parameters.
	public init() {}

	/// Runs one trial.
	public func simulate(on graph: DiffusionGraph, seeds: [Int], randomness: TrialRandomness) -> Int {
		let n = graph.nodeCount
		guard n > 0 else { return 0 }
		var active = [Bool](repeating: false, count: n)
		var influence = [Double](repeating: 0, count: n)
		var queue = CascadeSupport.activate(seeds: seeds, nodeCount: n, active: &active)

		// Each node enters the queue at most once, so the walk is bounded by `n`.
		for head in 0..<n {
			guard head < queue.count else { break }
			let source = queue[head]
			for slot in graph.offsets[source]..<graph.offsets[source + 1] {
				let target = graph.targets[slot]
				guard !active[target] else { continue }
				let degree = graph.weightedDegree[target]
				guard degree > 0 else { continue }
				influence[target] += graph.weights[slot] / degree
				// Compared with a tolerance below one part in 10^12 so that shares which sum
				// to exactly 1 on paper (1/3 + 1/3 + 1/3) are not lost to rounding.
				guard influence[target] + 1e-12 >= randomness.uniform(forNode: target) else { continue }
				active[target] = true
				queue.append(target)
			}
		}
		return queue.count
	}
}
