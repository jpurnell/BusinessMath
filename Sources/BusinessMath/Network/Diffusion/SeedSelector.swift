//
//  SeedSelector.swift
//  BusinessMath
//

import Foundation

/// Greedy influence maximisation: which few nodes, seeded, would spread furthest.
///
/// Picks `budget` nodes one at a time, each time adding the node whose seeding raises the
/// expected spread most. Because expected spread under the standard models is monotone and
/// submodular, this greedy choice reaches at least `1 − 1/e` (about 63%) of the best
/// possible set (Kempe, Kleinberg & Tardos 2003). That bound is about expected spread; the
/// selector maximises the average over a fixed set of trials, and the `1 − 1/e` guarantee is
/// tested for independent cascade only.
///
/// ## Method
///
/// - **Lazy evaluation (CELF), where it is sound.** For a model whose single trials are
///   submodular (``DiffusionModel/hasSubmodularTrials``, true of ``IndependentCascade``) a
///   node's marginal gain can only shrink as seeds are added, so a stale gain is an upper bound.
///   Each round re-evaluates only the leading stale candidates and stops when a fresh gain still
///   leads. For any other model, including ``LinearThreshold``, it does not: the selector
///   re-scores every candidate every round and is exactly plain greedy. See ADR-005.
/// - **Common random numbers.** Every candidate is evaluated on the *same* trials, so gains
///   differ because of the seeds, not because of sampling luck.
/// - **Parallel first pass.** Scoring every node alone is the expensive step; it is split
///   across threads. Results land in fixed slots by node index and are integers summed
///   exactly, so the output is bit-identical to a serial run.
/// - **Ties** break toward the lower node index, which is the sorted node order.
///
/// ## Read this before using it
///
/// This metric is **exploratory**. It turns assumed parameters into precise-looking numbers.
/// The model's activation probability or thresholds are not observed anywhere in the graph,
/// and every result is conditional on them. Use
/// ``sweep(on:probabilities:budget:trials:seed:model:)`` to see how the picks move as the
/// assumption moves: a node that is picked across the whole range is a far firmer finding
/// than the top of a single-parameter ranking.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("hub", "a"), ("hub", "b"), ("hub", "c"), ("x", "y")])
/// let selector = SeedSelector<String>(
///     model: try IndependentCascade(probability: 1), budget: 2, trials: 20, seed: 1)
/// let selection = try selector.compute(on: graph)
/// print(selection.nodes)   // ["hub", "x"]
/// ```
public struct SeedSelector<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {

	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "seed-selection", version: 1, title: "Seed Selection",
			interpretation: "EXPLORATORY. Which few nodes, activated first, would spread "
				+ "something furthest under an assumed diffusion model. The result is "
				+ "conditional on that model and its parameters, which have not been "
				+ "calibrated against observed spread. A pick that appears across a whole "
				+ "sweep of parameter values is more trustworthy than a single-parameter "
				+ "ranking.",
			highMeans: "A large marginal gain: given the picks before it, seeding this node "
				+ "is expected to reach many more nodes under the assumed model. Firmest "
				+ "when the node also holds up across a range of parameter values.",
			lowMeans: "A small marginal gain: the node adds little beyond what earlier "
				+ "picks already reach, or sits in a small or isolated part of the graph. "
				+ "It does not mean the node is unimportant in other ways, and later picks "
				+ "always gain less than earlier ones."
		)
	}

	/// The diffusion model whose spread is maximised.
	public let model: any DiffusionModel

	/// How many nodes to pick.
	public let budget: Int

	/// Monte Carlo trials per spread estimate.
	public let trials: Int

	/// Master seed. Equal seeds give identical selections.
	public let seed: UInt64

	/// Creates a selector. Arguments are validated when it runs.
	///
	/// - Parameters:
	///   - model: The diffusion model.
	///   - budget: How many seeds to pick. Zero is allowed and picks none; more than the
	///     node count picks every node.
	///   - trials: Monte Carlo trials, at least one.
	///   - seed: Master seed.
	public init(model: any DiffusionModel, budget: Int, trials: Int, seed: UInt64) {
		self.init(model: model, budget: budget, trials: trials, seed: seed, lazyRefreshBatch: nil)
	}

	/// How many stale candidates a lazy pass refreshes together; `nil` means one per core. Tests
	/// set it to 1 to make the evaluation as lazy as it can be.
	let lazyRefreshBatch: Int?

	init(model: any DiffusionModel, budget: Int, trials: Int, seed: UInt64, lazyRefreshBatch: Int?) {
		self.model = model
		self.budget = budget
		self.trials = trials
		self.seed = seed
		self.lazyRefreshBatch = lazyRefreshBatch
	}

	/// Picks seeds, scoring the first pass across threads with `DispatchQueue.concurrentPerform`.
	///
	/// - Throws: ``DiffusionError/invalidTrialCount(_:)`` or ``DiffusionError/invalidBudget(_:)``.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeSelection<Node> {
		let engine = try makeEngine(for: graph)
		guard let engine else { return NodeSelection([]) }
		let chunks = engine.chunkRanges()
		let collector = ChunkCollector(count: chunks.count)
		DispatchQueue.concurrentPerform(iterations: chunks.count) { chunk in
			collector.store(engine.singleTotals(in: chunks[chunk]), at: chunk)
		}
		return engine.select(firstPass: collector.flattened(), graph: graph)
	}

	/// Picks seeds, scoring the first pass with structured concurrency (a task group).
	///
	/// Gives the same result as ``compute(on:)``, bit for bit.
	///
	/// - Throws: ``DiffusionError/invalidTrialCount(_:)`` or ``DiffusionError/invalidBudget(_:)``.
	public func computeAsync(on graph: WeightedGraph<Node>) async throws -> NodeSelection<Node> {
		let engine = try makeEngine(for: graph)
		guard let engine else { return NodeSelection([]) }
		let chunks = engine.chunkRanges()
		var ordered = [[Int]](repeating: [], count: chunks.count)
		await withTaskGroup(of: (Int, [Int]).self) { group in
			for (position, range) in chunks.enumerated() {
				group.addTask { (position, engine.singleTotals(in: range)) }
			}
			for await (position, totals) in group { ordered[position] = totals }
		}
		return engine.select(firstPass: ordered.flatMap { $0 }, graph: graph)
	}

	/// Validates, and returns `nil` when there is nothing to pick.
	private func makeEngine(for graph: WeightedGraph<Node>) throws -> GreedyEngine? {
		guard trials >= 1 else { throw DiffusionError.invalidTrialCount(trials) }
		guard budget >= 0 else { throw DiffusionError.invalidBudget(budget) }
		guard budget > 0, graph.nodeCount > 0 else { return nil }
		return GreedyEngine(
			model: model, graph: DiffusionGraph(graph), budget: budget, trials: trials, seed: seed,
			refreshBatch: lazyRefreshBatch)
	}
}

/// Collects per-chunk results written from concurrent iterations into fixed slots.
// Justification: every slot is written by exactly one iteration and the lock serialises all access to the array.
private final class ChunkCollector: @unchecked Sendable {
	private let lock = NSLock()
	private var slots: [[Int]]

	init(count: Int) { slots = Array(repeating: [], count: count) }

	func store(_ totals: [Int], at position: Int) {
		lock.lock()
		defer { lock.unlock() }
		guard position >= 0, position < slots.count else { return }
		slots[position] = totals
	}

	func flattened() -> [Int] {
		lock.lock()
		defer { lock.unlock() }
		return slots.flatMap { $0 }
	}
}

/// The non-generic greedy/CELF machinery over integer spread totals.
///
/// Spread is kept as an integer total of activated nodes over all trials, so sums are exact
/// and independent of evaluation order; it is divided by the trial count only when reported.
private struct GreedyEngine: Sendable {
	let model: any DiffusionModel
	let graph: DiffusionGraph
	let budget: Int
	let trials: Int
	let randomness: [TrialRandomness]
	let refreshBatch: Int?

	init(
		model: any DiffusionModel, graph: DiffusionGraph, budget: Int, trials: Int, seed: UInt64,
		refreshBatch: Int?
	) {
		self.refreshBatch = refreshBatch
		self.model = model
		self.graph = graph
		self.budget = budget
		self.trials = trials
		self.randomness = (0..<trials).map { TrialRandomness(masterSeed: seed, trial: $0) }
	}

	/// Total activated nodes over all trials for a seed set.
	func total(of seeds: [Int]) -> Int {
		var sum = 0
		for trial in randomness {
			sum += model.simulate(on: graph, seeds: seeds, randomness: trial)
		}
		return sum
	}

	/// Contiguous node ranges to score in parallel.
	func chunkRanges() -> [Range<Int>] {
		let n = graph.nodeCount
		let wanted = max(1, ProcessInfo.processInfo.activeProcessorCount * 4)
		let size = max(1, (n + wanted - 1) / wanted)
		return stride(from: 0, to: n, by: size).map { $0..<min(n, $0 + size) }
	}

	/// Totals of each node seeded alone, for one range of nodes.
	func singleTotals(in range: Range<Int>) -> [Int] {
		range.map { total(of: [$0]) }
	}

	func select<Node: Hashable & Comparable & Sendable>(
		firstPass: [Int], graph source: WeightedGraph<Node>
	) -> NodeSelection<Node> {
		let n = graph.nodeCount
		guard trials > 0 else { return NodeSelection([]) }
		let target = min(budget, n)
		// gain[i]: last computed marginal total gain; round[i]: how many picks it was computed against.
		var gain = firstPass
		var round = [Int](repeating: 0, count: n)
		var chosen = [Bool](repeating: false, count: n)
		var seeds: [Int] = []
		var currentTotal = 0
		var picks: [NodeSelection<Node>.Pick] = []

		for pick in 0..<target {
			// Every pass refreshes at least the front-runner, so this loop ends within n passes.
			for _ in 0...n {
				let front = frontRunners(gain: gain, chosen: chosen, count: batchSize)
				guard let best = front.first else { break }
				if round[best] == pick {
					seeds.append(best)
					chosen[best] = true
					currentTotal += gain[best]
					picks.append(
						NodeSelection<Node>.Pick(
							node: source.nodes[best], marginalGain: Double(gain[best]) / Double(trials)))
					break
				}
				// Refresh every stale leader at once. Each is evaluated against the same seed
				// set on the same trials, so the values do not depend on which thread ran them,
				// and which candidates are refreshed depends only on the state so far.
				let stale = front.filter { round[$0] != pick }
				let totals = totals(of: stale, adding: seeds)
				for (position, candidate) in stale.enumerated() {
					gain[candidate] = totals[position] - currentTotal
					round[candidate] = pick
				}
			}
		}
		return NodeSelection(picks)
	}

	/// How many stale candidates to refresh together: one per core.
	///
	/// Only a model with ``DiffusionModel/hasSubmodularTrials`` may be lazy. For any other, the
	/// batch is every node: after one refresh pass every unchosen candidate holds its exact gain,
	/// so the front-runner is the true argmax and the result is plain greedy.
	private var batchSize: Int {
		guard model.hasSubmodularTrials else { return max(1, graph.nodeCount) }
		return max(1, refreshBatch ?? ProcessInfo.processInfo.activeProcessorCount)
	}

	/// Total spread of `seeds + [candidate]` for each candidate, evaluated in parallel into
	/// fixed slots.
	private func totals(of candidates: [Int], adding seeds: [Int]) -> [Int] {
		guard candidates.count > 1 else { return candidates.map { total(of: seeds + [$0]) } }
		let collector = ChunkCollector(count: candidates.count)
		DispatchQueue.concurrentPerform(iterations: candidates.count) { position in
			collector.store([total(of: seeds + [candidates[position]])], at: position)
		}
		return collector.flattened()
	}

	/// The best `count` unchosen nodes by gain, highest first; the lowest index wins ties.
	private func frontRunners(gain: [Int], chosen: [Bool], count: Int) -> [Int] {
		let open = (0..<gain.count).filter { !chosen[$0] }
		let ordered = open.sorted { gain[$0] != gain[$1] ? gain[$0] > gain[$1] : $0 < $1 }
		return Array(ordered.prefix(count))
	}
}

// MARK: - Sensitivity sweep

/// One point of a sensitivity sweep: the picks made at one assumed probability.
public struct SweepPoint<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {
	/// The activation probability assumed.
	public let probability: Double
	/// The seeds greedy chose under it.
	public let selection: NodeSelection<Node>

	/// Creates a point.
	public init(probability: Double, selection: NodeSelection<Node>) {
		self.probability = probability
		self.selection = selection
	}
}

/// How the picks of a seed selection move as the assumed probability moves.
///
/// The activation probability is not observable, so a single run answers "what if it were
/// exactly this". The sweep answers the question that can be defended: *which picks do not
/// depend on the guess?*
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [(0, 1), (0, 2), (0, 3), (4, 5)])
/// let sweep = try SeedSelector<Int>.sweep(
///     on: graph, probabilities: [0.5, 1.0], budget: 1, trials: 30, seed: 1)
/// print(sweep.alwaysPicked)             // [0]
/// print(sweep.meanPairwiseJaccard)      // 1.0
/// ```
///
/// Conforms to ``MetricValue`` (kind `"seed-sweep"`) when `Node` is `Codable`, so a sweep can be
/// stored in a ``MetricEnvelope`` and read back equal to what was written.
public struct SeedSweep<Node: Hashable & Comparable & Sendable>: Sendable, Hashable {

	/// One selection per probability, in the order the probabilities were given.
	public let results: [SweepPoint<Node>]

	/// For each node picked at least once, the fraction of sweep points whose picks include
	/// it. `1.0` means picked at every probability tried.
	public let topKFrequency: [Node: Double]

	/// Jaccard overlap (|A∩B| / |A∪B|) between the pick sets of every pair of sweep points,
	/// indexed like ``results``. The diagonal is 1; two empty sets count as identical.
	public let pairwiseJaccard: [[Double]]

	/// The mean of the off-diagonal ``pairwiseJaccard`` entries. `1` means the pick set never
	/// changed across the sweep; near `0` means it is mostly an artefact of the assumed
	/// probability. A sweep of one point has no pairs and reports `1`.
	public let meanPairwiseJaccard: Double

	/// The nodes picked at every probability in the sweep, in node order.
	public var alwaysPicked: [Node] {
		topKFrequency.filter { $0.value >= 1.0 }.keys.sorted()
	}

	/// Creates a sweep from its points, computing the stability summary.
	public init(results: [SweepPoint<Node>]) {
		self.results = results
		let sets = results.map { Set($0.selection.nodes) }

		var counts: [Node: Int] = [:]
		for set in sets { for node in set { counts[node, default: 0] += 1 } }
		let denominator = Double(max(1, results.count))
		self.topKFrequency = counts.mapValues { Double($0) / denominator }

		var matrix = [[Double]](
			repeating: [Double](repeating: 1.0, count: sets.count), count: sets.count)
		var total = 0.0
		var pairs = 0
		for i in 0..<sets.count {
			for j in (i + 1)..<max(i + 1, sets.count) {
				let overlap = Self.jaccard(sets[i], sets[j])
				matrix[i][j] = overlap
				matrix[j][i] = overlap
				total += overlap
				pairs += 1
			}
		}
		self.pairwiseJaccard = matrix
		self.meanPairwiseJaccard = pairs > 0 ? total / Double(pairs) : 1.0
	}

	private static func jaccard(_ a: Set<Node>, _ b: Set<Node>) -> Double {
		let union = a.union(b).count
		guard union > 0 else { return 1.0 }
		return Double(a.intersection(b).count) / Double(union)
	}
}

extension SeedSelector {

	/// Runs the selection across a range of assumed probabilities and summarises how stable
	/// the picks are.
	///
	/// Every probability uses the same master seed, so differences between points come from
	/// the probability, not from different random numbers. The model is built per point by
	/// `model`; the default is ``IndependentCascade/init(probability:)``. Pass
	/// `{ try IndependentCascade(weightScaledProbability: $0) }` to sweep the weight-scaled form.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - probabilities: The assumed activation probabilities to try, each in `[0, 1]`.
	///   - budget: Seeds to pick at each point.
	///   - trials: Monte Carlo trials per spread estimate.
	///   - seed: Master seed.
	///   - model: Builds the model for a probability.
	/// - Throws: ``DiffusionError/emptySweep``, or the errors of ``compute(on:)``.
	public static func sweep(
		on graph: WeightedGraph<Node>,
		probabilities: [Double],
		budget: Int,
		trials: Int,
		seed: UInt64,
		model: @Sendable (Double) throws -> any DiffusionModel = { try IndependentCascade(probability: $0) }
	) throws -> SeedSweep<Node> {
		guard !probabilities.isEmpty else { throw DiffusionError.emptySweep }
		var points: [SweepPoint<Node>] = []
		points.reserveCapacity(probabilities.count)
		for probability in probabilities {
			let selector = SeedSelector(
				model: try model(probability), budget: budget, trials: trials, seed: seed)
			points.append(
				SweepPoint(probability: probability, selection: try selector.compute(on: graph)))
		}
		return SeedSweep(results: points)
	}
}

extension SweepPoint: Codable where Node: Codable {}

/// Only the points are stored. The stability summary (``SeedSweep/topKFrequency``,
/// ``SeedSweep/pairwiseJaccard``, ``SeedSweep/meanPairwiseJaccard``) is derived from them, so
/// decoding rebuilds it through ``SeedSweep/init(results:)`` and a stored sweep cannot carry a
/// summary that disagrees with its own points. A decoded sweep equals the one that was encoded.
///
/// A point whose probability is `NaN` or infinite cannot be encoded (JSON has no such number);
/// the encoder throws rather than storing something else.
extension SeedSweep: Codable where Node: Codable {

	private enum CodingKeys: String, CodingKey { case results }

	/// Decodes the points and recomputes the summary from them.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.init(results: try container.decode([SweepPoint<Node>].self, forKey: .results))
	}

	/// Encodes the points only.
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(results, forKey: .results)
	}
}

extension SeedSweep: MetricValue where Node: Codable {
	/// `"seed-sweep"`.
	public static var kind: String { "seed-sweep" }
}
