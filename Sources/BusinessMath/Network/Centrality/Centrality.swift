//
//  Centrality.swift
//  BusinessMath
//

import Foundation
import Numerics

public extension Graph {

	// MARK: - Degree

	/// The number of neighbours of each node.
	///
	/// The cheapest measure and often the right one — but it answers *popularity*, and
	/// several questions that sound like popularity are not. See
	/// ``betweennessCentrality`` for the one that most often gets asked by mistake.
	var degreeCentrality: [Node: Double] {
		var result: [Node: Double] = [:]
		for node in nodes {
			result[node] = Double(neighbors(of: node).count)
		}
		return result
	}

	// MARK: - Betweenness

	/// The share of shortest paths that run through each node, by Brandes' algorithm.
	///
	/// **Brokerage, not popularity, and the distinction is not academic.** A node with two
	/// edges can have the highest betweenness in a graph if it is the only route between
	/// two clusters. `CentralityTests` uses exactly that shape: two triangles joined
	/// through a single bridge, where the bridge has the *lowest* degree and the *lowest*
	/// PageRank of seven nodes, and the highest betweenness. Remove it and the graph falls
	/// in half.
	///
	/// In supply-chain, organisational-network and counterparty analysis, brokerage is
	/// usually the question being asked — which supplier is a single point of failure,
	/// who connects two departments that otherwise never speak — and no amount of tuning
	/// a popularity measure produces it.
	///
	/// Brandes: one breadth-first search per node accumulating dependencies backwards,
	/// `O(VE)` rather than the `O(V³)` of computing all pairs and counting. Normalised by
	/// `(n−1)(n−2)/2`, the number of pairs a node could stand between, and halved because
	/// an undirected graph counts each pair twice.
	var betweennessCentrality: [Node: Double] {
		var score: [Node: Double] = [:]
		for node in nodes { score[node] = 0 }
		guard nodes.count > 2 else { return score }

		for source in nodes {
			var stack: [Node] = []
			var predecessors: [Node: [Node]] = [:]
			var pathCount: [Node: Double] = [:]
			var distance: [Node: Int] = [:]
			for node in nodes { predecessors[node] = []; pathCount[node] = 0; distance[node] = -1 }
			pathCount[source] = 1
			distance[source] = 0

			var queue: [Node] = [source]
			var head = 0
			while head < queue.count {
				let current = queue[head]
				head += 1
				stack.append(current)
				for next in neighbors(of: current) {
					if distance[next] == -1 {
						distance[next] = (distance[current] ?? 0) + 1
						queue.append(next)
					}
					if distance[next] == (distance[current] ?? 0) + 1 {
						pathCount[next] = (pathCount[next] ?? 0) + (pathCount[current] ?? 0)
						predecessors[next]?.append(current)
					}
				}
			}

			var dependency: [Node: Double] = [:]
			for node in nodes { dependency[node] = 0 }
			while let node = stack.popLast() {
				for predecessor in predecessors[node] ?? [] {
					let share = (pathCount[predecessor] ?? 0) / (pathCount[node] ?? 1)
					let carried = share * (1 + (dependency[node] ?? 0))
					dependency[predecessor] = (dependency[predecessor] ?? 0) + carried
				}
				if node != source {
					score[node] = (score[node] ?? 0) + (dependency[node] ?? 0)
				}
			}
		}

		let count = Double(nodes.count)
		let pairs = (count - 1) * (count - 2) / 2
		guard pairs > 0 else { return score }
		var normalised: [Node: Double] = [:]
		for (node, value) in score {
			let halved = value / 2
			normalised[node] = halved / pairs
		}
		return normalised
	}

	// MARK: - Closeness

	/// Harmonic closeness: the mean reciprocal distance to every other node.
	///
	/// **Harmonic rather than classical, so that disconnection is defined.** Classical
	/// closeness is `n−1` over the *sum* of distances, and that sum is infinite the moment
	/// anything is unreachable — which collapses the measure to zero for every node in a
	/// graph with more than one component, including nodes that are perfectly central
	/// within their own. Summing reciprocals instead lets an unreachable node contribute
	/// nothing while the rest of the answer survives.
	///
	/// Real graphs are disconnected more often than not, so this is the variant that
	/// works on data rather than on examples.
	var harmonicCloseness: [Node: Double] {
		var result: [Node: Double] = [:]
		guard nodes.count > 1 else {
			for node in nodes { result[node] = 0 }
			return result
		}
		let others = Double(nodes.count - 1)
		guard others > 0 else { return result }
		for source in nodes {
			var distance: [Node: Int] = [source: 0]
			var queue: [Node] = [source]
			var head = 0
			while head < queue.count {
				let current = queue[head]
				head += 1
				let step = (distance[current] ?? 0) + 1
				for next in neighbors(of: current) where distance[next] == nil {
					distance[next] = step
					queue.append(next)
				}
			}
			var total: Double = 0
			for (node, steps) in distance where node != source && steps > 0 {
				total += 1 / Double(steps)
			}
			result[source] = total / others
		}
		return result
	}

	// MARK: - PageRank

	/// PageRank, by power iteration.
	///
	/// - Parameters:
	///   - damping: The probability of following an edge rather than teleporting, in
	///     `(0, 1)`. The conventional 0.85.
	///   - tolerance: Convergence is declared when no score moves by more than this.
	///   - maxIterations: The budget.
	/// - Returns: Scores summing to one, or `nil` if the graph is empty, the damping is
	///   outside `(0, 1)`, or the iteration did not converge.
	///
	///   **`nil` rather than the last iterate.** An unconverged PageRank vector is a
	///   ranking with no meaning and nothing about its shape says so — the numbers still
	///   sum to one, still order the nodes, and still look like an answer. Returning it
	///   is the fail-silent pattern this release exists to remove.
	func pageRank(damping: Double = 0.85,
				  tolerance: Double = 1e-12,
				  maxIterations: Int = 200) -> [Node: Double]? {
		guard !nodes.isEmpty else { return nil }
		guard damping > 0, damping < 1 else { return nil }
		let count = Double(nodes.count)
		guard count > 0 else { return nil }
		var score: [Node: Double] = [:]
		for node in nodes { score[node] = 1 / count }

		let teleport = (1 - damping) / count
		for _ in 0..<maxIterations {
			var next: [Node: Double] = [:]
			// Mass sitting on nodes with no out-edges would simply vanish; it is
			// redistributed uniformly, which is what keeps the vector summing to one.
			var dangling: Double = 0
			for node in nodes where neighbors(of: node).isEmpty {
				dangling += score[node] ?? 0
			}
			let stranded: Double = damping * dangling
			let spread: Double = stranded / count
			for node in nodes { next[node] = teleport + spread }
			for node in nodes {
				let outgoing = neighbors(of: node)
				let fanOut = Double(outgoing.count)
				guard fanOut > 0 else { continue }
				let mass: Double = damping * (score[node] ?? 0)
				let share: Double = mass / fanOut
				for target in outgoing {
					next[target] = (next[target] ?? 0) + share
				}
			}
			var movement: Double = 0
			for node in nodes {
				let change = Swift.abs((next[node] ?? 0) - (score[node] ?? 0))
				if change > movement { movement = change }
			}
			score = next
			if movement < tolerance { return score }
		}
		return nil
	}

	// MARK: - Eigenvector

	/// Eigenvector centrality: the leading eigenvector of the adjacency matrix.
	///
	/// A node is important if its neighbours are, recursively. On a graph with genuine hub
	/// structure — a referral network, a citation graph, an exposure network — this
	/// separates nodes that degree and PageRank rank alike.
	///
	/// - Parameters:
	///   - tolerance: Convergence threshold for the power iteration.
	///   - maxIterations: The budget.
	/// - Returns: An L2-normalised vector, or `nil` when the measure is not meaningful.
	///
	/// ## The localisation refusal
	///
	/// `nil` on a **disconnected** graph, and this is a refusal rather than a limitation.
	/// Each component has its own leading eigenvector, the power iteration converges to
	/// whichever the starting vector happens to favour, and the result is stable, plausible
	/// and a property of the initial guess rather than of the graph. Running it per
	/// component is the meaningful thing to do, and the caller has to choose that.
	///
	/// Also `nil` for a graph with no edges, which has no leading eigenvector at all.
	func eigenvectorCentrality(tolerance: Double = 1e-12,
							   maxIterations: Int = 1000) -> [Node: Double]? {
		guard !nodes.isEmpty, edgeCount > 0 else { return nil }
		guard isWeaklyConnected else { return nil }

		let count = Double(nodes.count)
		let start = 1 / count.squareRoot()
		var vector: [Node: Double] = [:]
		for node in nodes { vector[node] = start }

		for _ in 0..<maxIterations {
			var next: [Node: Double] = [:]
			for node in nodes { next[node] = 0 }
			for node in nodes {
				for target in neighbors(of: node) {
					next[target] = (next[target] ?? 0) + (vector[node] ?? 0)
				}
			}
			var lengthSquared: Double = 0
			for value in next.values { lengthSquared += value * value }
			guard lengthSquared > 0 else { return nil }
			let length = lengthSquared.squareRoot()
			var movement: Double = 0
			for node in nodes {
				let scaled = (next[node] ?? 0) / length
				let change = Swift.abs(scaled - (vector[node] ?? 0))
				if change > movement { movement = change }
				next[node] = scaled
			}
			vector = next
			if movement < tolerance { return vector }
		}
		return vector
	}

	/// Whether every node reaches every other when edge direction is ignored.
	var isWeaklyConnected: Bool {
		guard let first = nodes.first else { return false }
		var undirected: [Node: Set<Node>] = [:]
		for node in nodes { undirected[node] = [] }
		for node in nodes {
			for target in neighbors(of: node) {
				undirected[node]?.insert(target)
				undirected[target]?.insert(node)
			}
		}
		var seen: Set<Node> = [first]
		var queue: [Node] = [first]
		var head = 0
		while head < queue.count {
			let current = queue[head]
			head += 1
			for next in (undirected[current] ?? []).sorted() where !seen.contains(next) {
				seen.insert(next)
				queue.append(next)
			}
		}
		return seen.count == nodes.count
	}
}
