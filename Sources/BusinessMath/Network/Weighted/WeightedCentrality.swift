//
//  WeightedCentrality.swift
//  BusinessMath
//

import Foundation

/// Centrality measures over a ``WeightedGraph``.
///
/// ## Two different questions
///
/// These are not interchangeable, and treating them as such is the most common
/// way this kind of analysis goes wrong.
///
/// **Who can activate others?** ``eigenvector(_:maxIterations:tolerance:)`` and
/// ``pageRank(_:damping:maxIterations:tolerance:)`` answer that: they score a
/// node by how connected *its neighbours* are. These find the bringers.
///
/// **Who bridges otherwise-separate groups?** ``betweenness(_:normalized:)``
/// answers that, by counting shortest paths that must pass through a node.
/// These find the connectors — the route into an isolated pocket.
///
/// Krackhardt's kite exists to make the difference concrete: Diane has the
/// highest degree, Heather the highest betweenness. They are different people
/// and they are useful for different things.
public enum Centrality {

	/// Weighted degree — the simplest signal, and the one that finds thin ties.
	///
	/// A zero-weight tie still counts as an edge for every topology measure in this enum, but it
	/// adds nothing here because degree sums weights. See ADR-007.
	///
	/// ```swift
	/// let graph = WeightedGraph(unweightedEdges: [("hub", "a"), ("hub", "b")])
	/// let scores = Centrality.degree(graph)
	/// print(scores["hub"] ?? 0)   // 2.0
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: The weighted degree of every node, isolated nodes scoring zero.
	public static func degree<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			scores[node] = graph.weightedDegree(index)
		}
		return NodeScores(scores)
	}

	/// Eigenvector centrality by power iteration.
	///
	/// Scores a node by the scores of its neighbours, so being connected to
	/// well-connected people counts for more than being connected to many
	/// people. This is the bringers measure.
	///
	/// The iteration stops when the L1 change between passes falls below
	/// `tolerance` or after `maxIterations` passes, whichever comes first. It
	/// does not say which: a result that hit the ceiling looks like any other.
	/// Use ``eigenvectorConvergence(_:maxIterations:tolerance:)`` to find out,
	/// on any connected graph, how many passes it took and whether it converged.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - maxIterations: Iteration ceiling, so a non-converging graph
	///     terminates rather than hanging.
	///   - tolerance: Convergence threshold on the L1 change per iteration.
	/// - Returns: Scores normalised so the largest is 1.
	///
	/// ## What it refuses
	///
	/// - **A graph that is not connected is refused**, with ``GraphMeasureError/disconnectedGraph(components:)``
	///   (ADR-009). The iteration used to run and the leading eigenvector lives on the component with
	///   the largest eigenvalue; every other component, and every isolated node, decayed toward zero
	///   (about 3.5e-12 for an isolate after the default 200 passes), which reads as "unimportant"
	///   rather than "not comparable". The unweighted `Graph.eigenvectorCentrality` returns `nil`.
	///   Connectivity is judged through ties of positive weight: a zero-weight tie carries nothing
	///   through the iteration, so it does not connect. An edgeless graph of two or more nodes is
	///   disconnected too; it used to score every node 1, the absence of a ranking presented as a
	///   measurement. The empty graph and a lone node are still answered.
	/// - **The ceiling is still silent here.** A result that stopped at `maxIterations` looks like any
	///   other; ``eigenvectorConvergence(_:maxIterations:tolerance:)`` is the way to ask.
	///
	/// - Throws: ``GraphMeasureError/disconnectedGraph(components:)``.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let scores = try Centrality.eigenvector(path)
	/// print(scores["b"] ?? 0)   // 1.0
	/// print(scores["a"] ?? 0)   // 0.7071...
	/// ```
	public static func eigenvector<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, maxIterations: Int = 200, tolerance: Double = 1e-10
	) throws -> NodeScores<Node> {
		try eigenvectorConvergence(graph, maxIterations: maxIterations, tolerance: tolerance).scores
	}

	/// Eigenvector centrality together with how the iteration ended.
	///
	/// This *is* the iteration ``eigenvector(_:maxIterations:tolerance:)`` runs, not a
	/// copy of it: `eigenvector` calls this and returns `scores`, so the two cannot
	/// drift apart. Use it to measure, on any graph, whether the iteration ceiling
	/// is enough.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - maxIterations: Iteration ceiling. Never fewer than one pass is run.
	///   - tolerance: Convergence threshold on the L1 change per pass.
	/// - Returns:
	///   - `iterations`: passes run. Zero for a graph of fewer than two nodes,
	///     where there is nothing to iterate.
	///   - `converged`: whether the change fell below `tolerance` within the ceiling.
	///     `true` for graphs with nothing to iterate (fewer than two nodes).
	///   - `residual`: the L1 change between the last two iterates, the quantity
	///     compared with `tolerance`. Zero when there was nothing to iterate.
	///   - `scores`: exactly what `eigenvector` returns for the same arguments.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let report = try Centrality.eigenvectorConvergence(path)
	/// print(report.converged)    // true
	/// print(report.iterations)   // a few dozen passes
	/// ```
	public static func eigenvectorConvergence<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, maxIterations: Int = 200, tolerance: Double = 1e-10
	) throws -> (iterations: Int, converged: Bool, residual: Double, scores: NodeScores<Node>) {
		let count = graph.nodeCount
		guard count > 0 else { return (0, true, 0, NodeScores([:])) }
		guard count > 1 else { return (0, true, 0, NodeScores([graph.nodes[0]: 1])) }
		let components = positiveTieComponentCount(graph)
		guard components == 1 else { throw GraphMeasureError.disconnectedGraph(components: components) }

		var current = [Double](repeating: 1 / Double(count), count: count)
		let shift = 2 * graph.totalWeight / Double(count)
		var iterations = 0
		var converged = false
		var residual = 0.0
		for _ in 0..<max(1, maxIterations) {
			// Iterate on A + sI rather than A. The two share every eigenvector,
			// but A has -lambda as an eigenvalue whenever the graph is
			// bipartite (every tree, every star), which ties with +lambda in
			// modulus and leaves plain power iteration oscillating between two
			// vectors instead of converging. Shifting moves the eigenvalues to
			// lambda + s and s - lambda, and the dominant one is then strictly
			// larger in modulus. The shift is the mean weighted degree, so it
			// is the same size as the eigenvalues whatever the weights are:
			// a fixed shift of one would swamp a graph of weights near 0.02.
			var next = current.map { $0 * shift }
			for index in 0..<count {
				for (neighbour, weight) in graph.adjacency[index] {
					next[index] += weight * current[neighbour]
				}
			}
			let norm = sqrt(next.reduce(0) { $0 + $1 * $1 })
			// A connected graph of positive ties has a positive shift, so this is not reached
			// for ordinary weights (an edgeless graph is refused above). It is reached if the
			// products underflow, as for weights near 1e-300: `next` is then zero, there is
			// nothing to normalise, and the uniform starting vector stands, so every node
			// scores 1 below. That outcome predates ADR-009 and is not addressed by it.
			guard norm > 0 else {
				iterations += 1
				converged = true
				residual = 0
				break
			}
			for index in 0..<count { next[index] /= norm }

			var delta = 0.0
			for index in 0..<count { delta += abs(next[index] - current[index]) }
			current = next
			iterations += 1
			residual = delta
			if delta < tolerance {
				converged = true
				break
			}
		}

		let peak = current.max() ?? 0
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			scores[node] = peak > 0 ? current[index] / peak : 0
		}
		return (iterations, converged, residual, NodeScores(scores))
	}

	/// The number of connected components of the graph read through ties of positive weight.
	///
	/// A zero-weight tie is stored as an edge but carries nothing through the eigenvector
	/// iteration, so for that measure it does not connect (unlike ``Community/connectedComponents(_:)``,
	/// which reads topology; ADR-007).
	private static func positiveTieComponentCount<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>
	) -> Int {
		let count = graph.nodeCount
		var seen = [Bool](repeating: false, count: count)
		var components = 0
		for start in 0..<count where !seen[start] {
			components += 1
			seen[start] = true
			var queue = [start]
			var head = 0
			while head < queue.count {
				let node = queue[head]
				head += 1
				for (neighbour, weight) in graph.adjacency[node] where weight > 0 && !seen[neighbour] {
					seen[neighbour] = true
					queue.append(neighbour)
				}
			}
		}
		return components
	}

	/// PageRank — eigenvector centrality with damping, which behaves better on
	/// sparse or disconnected graphs.
	///
	/// This is ``pageRankConvergence(_:damping:maxIterations:tolerance:)`` with the report
	/// dropped: that function runs the loop and this one returns its `scores`, so the two cannot
	/// drift apart. A result that stopped at the ceiling looks like any other here; ask
	/// ``pageRankConvergence(_:damping:maxIterations:tolerance:)`` (or use the registered
	/// ``PageRankMetric``, which reports it) to learn whether the iteration converged.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - damping: Probability of following an edge rather than teleporting.
	///   - maxIterations: Iteration ceiling.
	///   - tolerance: Convergence threshold on the L1 change.
	/// - Returns: A score per node, summing to one.
	///
	/// ## What it refuses, and what it still does not say
	///
	/// - **`damping` outside `[0, 1)` is refused**, with ``GraphMeasureError/invalidDamping(_:)``.
	///   It used to be clamped into `[0, 0.999]` (so `1.5` ran as `0.999` and `-1` as `0`) and a
	///   `NaN` damping gave `NaN` scores (ADR-009). A damping between `0.999` and `1` now runs as given.
	/// - **The last iterate is still returned at the ceiling** by this function, converged or not,
	///   with no flag. At the defaults the 200 passes suffice (the error after `k` passes is at most
	///   `2 * damping^k`), but a damping near 1 or a tiny `maxIterations` can stop short.
	///   ``pageRankConvergence(_:damping:maxIterations:tolerance:)`` reports it.
	/// - Dangling mass (a node with no weighted tie) is spread uniformly; an empty graph gives
	///   an empty result.
	///
	/// - Throws: ``GraphMeasureError/invalidDamping(_:)``.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let scores = try Centrality.pageRank(path)
	/// print(scores["b"] ?? 0)   // 0.4864...
	/// print(scores["a"] ?? 0)   // 0.2567...
	/// ```
	public static func pageRank<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, damping: Double = 0.85,
		maxIterations: Int = 200, tolerance: Double = 1e-12
	) throws -> NodeScores<Node> {
		try pageRankConvergence(
			graph, damping: damping, maxIterations: maxIterations, tolerance: tolerance).scores
	}

	/// PageRank together with how the iteration ended.
	///
	/// This *is* the iteration ``pageRank(_:damping:maxIterations:tolerance:)`` runs, not a copy
	/// of it: `pageRank` calls this and returns `scores`, so the two cannot drift apart. Use it to
	/// find out, on any graph and any damping, whether the ceiling was enough.
	///
	/// ## What to expect
	///
	/// PageRank is a contraction in the L1 norm with factor `damping`, whatever the graph, so the
	/// distance to the fixed point after `k` passes is at most `2 * damping^k`. That fixes the
	/// number of passes `ceil(ln(tolerance / 2) / ln(damping))` that guarantee convergence at a
	/// given tolerance: 175 at the defaults, so the default ceiling of 200 is enough on every graph
	/// (measured: no graph needed more); 269 at damping 0.9, 553 at 0.95 and 2,819 at 0.99,
	/// where the default ceiling is not enough and this report says so. The bound is the worst
	/// case; most graphs stop far sooner.
	///
	/// ## A false "did not converge"
	///
	/// The stopping rule is an absolute L1 change of `tolerance` between passes. On a star-like hub,
	/// where one node sums very many equal contributions, rounding error keeps the change above
	/// `1e-12` however long the loop runs, so a star of about eleven thousand nodes or more reports
	/// `converged == false` at the ceiling although its scores are accurate to about `1e-11` (measured; see
	/// `project/summaries/2026-11-13_network_explicit_behaviours/pagerank-measurement.md`).
	/// That is why the report carries the `residual` and not only the flag: a residual a small
	/// multiple of the tolerance, unchanged from pass to pass, is that rounding floor and not slow
	/// convergence. It was not found on any other family tried, up to 200,000 nodes.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - damping: Probability of following an edge rather than teleporting, in `[0, 1)`.
	///   - maxIterations: Iteration ceiling. Never fewer than one pass is run.
	///   - tolerance: Convergence threshold on the L1 change per pass.
	/// - Returns:
	///   - `iterations`: passes run. Zero for an empty graph, where there is nothing to iterate.
	///   - `converged`: whether the change fell below `tolerance` within the ceiling. `true` for
	///     an empty graph.
	///   - `residual`: the L1 change between the last two iterates, the quantity compared with
	///     `tolerance`. Zero for an empty graph.
	///   - `scores`: exactly what `pageRank` returns for the same arguments.
	/// - Throws: ``GraphMeasureError/invalidDamping(_:)`` if `damping` is `NaN`, infinite, negative
	///   or at least one. Checked before anything else, so an empty graph refuses it too.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let run = try Centrality.pageRankConvergence(path)
	/// print(run.converged)    // true
	/// print(run.iterations)   // well under the ceiling of 200
	///
	/// let slow = try Centrality.pageRankConvergence(path, damping: 0.99, maxIterations: 20)
	/// print(slow.converged)   // false
	/// ```
	public static func pageRankConvergence<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, damping: Double = 0.85,
		maxIterations: Int = 200, tolerance: Double = 1e-12
	) throws -> (iterations: Int, converged: Bool, residual: Double, scores: NodeScores<Node>) {
		// Written so that a comparison that cannot be evaluated (NaN) fails it and lands on the
		// refusal, not on "valid".
		guard damping.isFinite, damping >= 0, damping < 1 else {
			throw GraphMeasureError.invalidDamping(damping)
		}
		let count = graph.nodeCount
		guard count > 0 else { return (0, true, 0, NodeScores([:])) }
		let teleport = (1 - damping) / Double(count)

		var current = [Double](repeating: 1 / Double(count), count: count)
		let degrees = (0..<count).map { graph.weightedDegree($0) }
		var iterations = 0
		var converged = false
		var residual = 0.0

		for _ in 0..<max(1, maxIterations) {
			var next = [Double](repeating: teleport, count: count)
			var danglingMass = 0.0
			for index in 0..<count where degrees[index] <= 0 {
				danglingMass += current[index]
			}
			let spread = damping * danglingMass / Double(count)
			for index in 0..<count { next[index] += spread }

			for index in 0..<count {
				let degree = degrees[index]
				guard degree > 0 else { continue }
				let share = damping * current[index] / degree
				for (neighbour, weight) in graph.adjacency[index] {
					next[neighbour] += share * weight
				}
			}

			var delta = 0.0
			for index in 0..<count { delta += abs(next[index] - current[index]) }
			current = next
			iterations += 1
			residual = delta
			if delta < tolerance {
				converged = true
				break
			}
		}

		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() { scores[node] = current[index] }
		return (iterations, converged, residual, NodeScores(scores))
	}

	/// Betweenness centrality by Brandes' algorithm.
	///
	/// Counts the shortest paths between all other pairs that pass through each
	/// node. High betweenness means removing that person would separate parts
	/// of the class — which makes them the route into a pocket, not necessarily
	/// someone with many ties.
	///
	/// Unweighted: shortest means fewest hops. Edge weights record *strength*
	/// here, not distance, and treating a strong tie as a long road would
	/// invert the meaning.
	///
	/// - Parameters:
	///   - graph: The graph.
	///   - normalized: Divide by the number of possible pairs, giving `0...1`.
	/// - Returns: Betweenness per node; every node scores zero on a graph of at most two nodes.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let scores = Centrality.betweenness(path)
	/// print(scores["b"] ?? 0)   // 1.0, every shortest path between a and c runs through b
	/// print(scores["a"] ?? 0)   // 0.0
	/// ```
	public static func betweenness<Node: Hashable & Comparable & Sendable>(
		_ graph: WeightedGraph<Node>, normalized: Bool = true
	) -> NodeScores<Node> {
		let count = graph.nodeCount
		var centrality = [Double](repeating: 0, count: count)
		guard count > 2 else {
			return NodeScores(Dictionary(
				uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))
		}

		for source in 0..<count {
			var stack: [Int] = []
			var predecessors: [[Int]] = Array(repeating: [], count: count)
			var pathCount = [Double](repeating: 0, count: count)
			var distance = [Int](repeating: -1, count: count)
			pathCount[source] = 1
			distance[source] = 0

			var queue = [source]
			var head = 0
			while head < queue.count {
				let node = queue[head]
				head += 1
				stack.append(node)
				for (neighbour, _) in graph.adjacency[node] {
					if distance[neighbour] < 0 {
						distance[neighbour] = distance[node] + 1
						queue.append(neighbour)
					}
					if distance[neighbour] == distance[node] + 1 {
						pathCount[neighbour] += pathCount[node]
						predecessors[neighbour].append(node)
					}
				}
			}

			var dependency = [Double](repeating: 0, count: count)
			for node in stack.reversed() {
				for predecessor in predecessors[node] {
					// pathCount is only zero for unreachable nodes, which never
					// enter the stack — but the guard keeps that implicit fact
					// from becoming a division by zero if it ever changes.
					guard pathCount[node] > 0 else { continue }
					dependency[predecessor] +=
						(pathCount[predecessor] / pathCount[node]) * (1 + dependency[node])
				}
				if node != source { centrality[node] += dependency[node] }
			}
		}

		// Each undirected pair was counted from both ends.
		let pairs = Double((count - 1) * (count - 2))
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			var value = centrality[index] / 2
			if normalized, pairs > 0 { value /= (pairs / 2) }
			scores[node] = value
		}
		return NodeScores(scores)
	}

	/// Closeness centrality — the inverse mean hop distance to everyone
	/// reachable, scaled by the fraction of the graph that is reachable.
	///
	/// Answers "who can reach the class in few steps", which is the measure to
	/// use when seeding a broadcast rather than bridging a gap.
	///
	/// This is the Wasserman-Faust form: `(reached / (n - 1)) / meanDistance`, where `reached`
	/// is the number of other nodes the source can reach. It is hop-count based and ignores
	/// weights. A node that reaches nobody scores zero, as does every node of a graph of at most
	/// one node.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let scores = Centrality.closeness(path)
	/// print(scores["b"] ?? 0)   // 1.0
	/// print(scores["a"] ?? 0)   // 0.6666...
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: Closeness per node.
	public static func closeness<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		let count = graph.nodeCount
		var scores: [Node: Double] = [:]
		guard count > 1 else {
			return NodeScores(Dictionary(
				uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))
		}

		for source in 0..<count {
			var distance = [Int](repeating: -1, count: count)
			distance[source] = 0
			var queue = [source]
			var head = 0
			var total = 0
			var reached = 0
			while head < queue.count {
				let node = queue[head]
				head += 1
				for (neighbour, _) in graph.adjacency[node] where distance[neighbour] < 0 {
					distance[neighbour] = distance[node] + 1
					total += distance[neighbour]
					reached += 1
					queue.append(neighbour)
				}
			}
			// An isolated node reaches nobody; its closeness is zero rather
			// than an infinity or a division by zero.
			guard reached > 0, total > 0 else {
				scores[graph.nodes[source]] = 0
				continue
			}
			let reachedCount = Double(reached)
			guard reachedCount > 0 else {
				scores[graph.nodes[source]] = 0
				continue
			}
			let meanDistance = Double(total) / reachedCount
			guard meanDistance > 0 else {
				scores[graph.nodes[source]] = 0
				continue
			}
			let others = Double(count - 1)
			guard others > 0 else {
				scores[graph.nodes[source]] = 0
				continue
			}
			let reachableFraction = reachedCount / others
			scores[graph.nodes[source]] = reachableFraction / meanDistance
		}
		return NodeScores(scores)
	}
}

extension Centrality {

	/// Harmonic centrality — the sum of reciprocal distances to everyone else.
	///
	/// Closeness divides by a mean distance and so needs the graph to be
	/// connected; on a graph with isolated pockets it either breaks or quietly
	/// measures only the component a person sits in. Harmonic centrality sums
	/// `1/d` instead, treating unreachable people as contributing nothing, so
	/// it stays meaningful across a disconnected class — which this class is,
	/// with a hundred classmates in no community at all.
	///
	/// ```swift
	/// let path = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
	/// let scores = Centrality.harmonic(path)
	/// print(scores["b"] ?? 0)   // 1.0
	/// print(scores["a"] ?? 0)   // 0.75
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: The sum of reciprocal hop distances to every reachable node, divided by `n - 1`.
	public static func harmonic<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		let count = graph.nodeCount
		var scores: [Node: Double] = [:]
		guard count > 1 else {
			return NodeScores(Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 0.0) }))
		}

		for source in 0..<count {
			var distance = [Int](repeating: -1, count: count)
			distance[source] = 0
			var queue = [source]
			var head = 0
			var total = 0.0
			while head < queue.count {
				let node = queue[head]
				head += 1
				for (neighbour, _) in graph.adjacency[node] where distance[neighbour] < 0 {
					distance[neighbour] = distance[node] + 1
					let hops = Double(distance[neighbour])
					// Distances out of a breadth-first search start at one, so
					// this cannot be zero — but the guard keeps that implicit
					// fact from becoming a division by zero if it ever changes.
					guard hops > 0 else { continue }
					total += 1.0 / hops
					queue.append(neighbour)
				}
			}
			let others = Double(count - 1)
			guard others > 0 else { scores[graph.nodes[source]] = 0; continue }
			scores[graph.nodes[source]] = total / others
		}
		return NodeScores(scores)
	}

	/// Local clustering coefficient — how many of someone's ties know each other.
	///
	/// The complement of bridging. A coefficient near one means a closed
	/// circle: everyone this person knows knows everyone else, so reaching them
	/// reaches nobody new. Near zero means their ties come from separate
	/// places, which is what a connector looks like from the inside.
	///
	/// Read against betweenness: high betweenness with low clustering is a
	/// genuine bridge; high betweenness with high clustering usually means one
	/// large dense group rather than a person joining two.
	///
	/// A node with fewer than two neighbours scores zero. A zero-weight tie counts as a
	/// neighbour (ADR-007).
	///
	/// ```swift
	/// let triangle = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c"), ("a", "c")])
	/// let scores = Centrality.clustering(triangle)
	/// print(scores["a"] ?? 0)   // 1.0
	/// ```
	///
	/// - Parameter graph: The graph.
	/// - Returns: The fraction of each node's neighbour pairs that are themselves tied.
	public static func clustering<Node: Hashable & Comparable & Sendable>(_ graph: WeightedGraph<Node>) -> NodeScores<Node> {
		var scores: [Node: Double] = [:]
		for (index, node) in graph.nodes.enumerated() {
			let neighbours = graph.adjacency[index].map(\.neighbour)
			let degree = neighbours.count
			guard degree > 1 else { scores[node] = 0; continue }

			let neighbourSet = Set(neighbours)
			var links = 0
			for neighbour in neighbours {
				for (other, _) in graph.adjacency[neighbour]
				where other != index && neighbourSet.contains(other) {
					links += 1
				}
			}
			// Each link inside the neighbourhood was counted from both ends.
			let possible = Double(degree * (degree - 1))
			guard possible > 0 else { scores[node] = 0; continue }
			scores[node] = Double(links) / possible
		}
		return NodeScores(scores)
	}
}
