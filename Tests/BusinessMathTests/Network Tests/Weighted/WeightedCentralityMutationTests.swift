//
//  WeightedCentralityMutationTests.swift
//  BusinessMath
//  Written from the mutation audit of the Phase-0 metrics (see
//  project/summaries/2026-11-11_centrality_mutation/summary.md).
//
//  Every expected value here is derived by hand from the definition (or
//  from a closed form for a small named graph), or comes from a reference
//  implementation that shares no code with the one under test. None of it
//  was read off the code being tested.
//

import Foundation
import SwiftDeterminism
import Testing

import TestSupport
@testable import BusinessMath

// MARK: - Helpers

private func graph(
	_ edges: [(String, String)], isolated: [String] = []
) -> WeightedGraph<String> {
	WeightedGraph(unweightedEdges: edges, isolatedNodes: isolated)
}

private func close(_ actual: Double?, _ expected: Double?, tolerance: Double = 1e-9) -> Bool {
	guard let actual, let expected else { return false }
	return abs(actual - expected) <= tolerance
}

/// True only when the value is present and at most `bound`.
private func atMost(_ value: Double?, _ bound: Double) -> Bool {
	guard let value else { return false }
	return value <= bound
}

/// Where a label goes under a relabelling that is a permutation of the names.
private func image(_ node: String, _ permutation: [String: String]) -> String {
	permutation[node] ?? node
}

private func names(_ count: Int) -> [String] {
	(0..<count).map { "n" + String($0 + 100) }
}

private func pathGraph(_ count: Int) -> WeightedGraph<String> {
	let nodes = names(count)
	return graph((1..<count).map { (nodes[$0 - 1], nodes[$0]) }, isolated: nodes)
}

/// A connected random weighted graph: a random spanning tree plus random chords.
/// Deterministic for a given seed. Edge weights are positive and not all equal.
private func randomConnected(
	seed: UInt64, count: Int, chords: Int
) -> [(String, String, Double)] {
	var rng = SplitMix64(seed: seed)
	let nodes = names(count)
	var edges: [(String, String, Double)] = []
	for index in 1..<count {
		let parent = Int.random(in: 0..<index, using: &rng)
		edges.append((nodes[index], nodes[parent], Double(Int.random(in: 1...4, using: &rng))))
	}
	for _ in 0..<chords {
		let a = Int.random(in: 0..<count, using: &rng)
		let b = Int.random(in: 0..<count, using: &rng)
		edges.append((nodes[a], nodes[b], Double(Int.random(in: 1...4, using: &rng))))
	}
	return edges
}

private func randomGraph(
	seed: UInt64, count: Int, edgeCount: Int, isolated: Int = 0
) throws -> WeightedGraph<String> {
	var rng = SplitMix64(seed: seed)
	let nodes = names(count + isolated)
	var edges: [(String, String, Double)] = []
	for _ in 0..<edgeCount {
		let a = Int.random(in: 0..<count, using: &rng)
		let b = Int.random(in: 0..<count, using: &rng)
		edges.append((nodes[a], nodes[b], Double(Int.random(in: 1...4, using: &rng))))
	}
	return try WeightedGraph(edges: edges, isolatedNodes: nodes)
}

private func relabelled(
	_ edges: [(String, String, Double)], through map: (String) -> String
) throws -> WeightedGraph<String> {
	try WeightedGraph(edges: edges.map { (map($0.0), map($0.1), $0.2) })
}


/// The documented iteration written out densely: start from a uniform vector,
/// apply A + sI with s the mean weighted degree, scale to unit length, stop when
/// the L1 change between passes falls below the tolerance (or after the ceiling,
/// never fewer than one pass), then scale so the largest entry is 1. A literal
/// transcription of the contract, so a partly converged answer (large tolerance,
/// small ceiling) can be compared exactly.
private func eigenvectorIteration(
	_ g: WeightedGraph<String>, maxIterations: Int, tolerance: Double
) -> [Double] {
	let n = g.nodeCount
	var a = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
	for i in 0..<n { for (j, w) in g.adjacency[i] { a[i][j] = w } }
	let shift = 2 * g.totalWeight / Double(n)
	var v = [Double](repeating: 1 / Double(n), count: n)
	for _ in 0..<max(1, maxIterations) {
		var next = (0..<n).map { i in (0..<n).reduce(shift * v[i]) { $0 + a[i][$1] * v[$1] } }
		let length = next.reduce(0) { $0 + $1 * $1 }.squareRoot()
		next = next.map { $0 / length }
		let change = zip(next, v).reduce(0) { $0 + abs($1.0 - $1.1) }
		v = next
		if change < tolerance { break }
	}
	let peak = v.max() ?? 1
	return v.map { $0 / peak }
}

// MARK: - Eigenvector

@Suite("Mutation audit: eigenvector centrality")
struct EigenvectorMutationTests {

	/// REGRESSION. Power iteration on the plain adjacency matrix does not
	/// converge on a bipartite graph: -lambda is an eigenvalue of the same
	/// modulus, so the iterate oscillates between two vectors. On the path
	/// a-b-c it returned (1, 1, 1) after an even number of iterations and
	/// (1/2, 1, 1/2) after an odd one. The eigenvector is (1/sqrt2, 1, 1/sqrt2).
	/// Every tree is bipartite.
	@Test("Path of three: the middle node leads, the ends are 1/sqrt(2)")
	func pathOfThree() throws {
		let scores = try Centrality.eigenvector(graph([("a", "b"), ("b", "c")]))
		let end = 1 / 2.0.squareRoot()
		#expect(close(scores["a"], end, tolerance: 1e-7), "a: \(String(describing: scores["a"]))")
		#expect(close(scores["b"], 1, tolerance: 1e-7))
		#expect(close(scores["c"], end, tolerance: 1e-7))
	}

	/// Weighted path with weights 1 and 3: the eigenvector is (w1, lambda, w2)
	/// with lambda = sqrt(w1^2 + w2^2) = sqrt(10); normalised to a peak of 1.
	@Test("Weighted path of three matches the closed form")
	func weightedPath() throws {
		let g = try WeightedGraph(edges: [("a", "b", 1.0), ("b", "c", 3.0)])
		let scores = try Centrality.eigenvector(g)
		let lambda = 10.0.squareRoot()
		#expect(close(scores["a"], 1 / lambda, tolerance: 1e-7))
		#expect(close(scores["b"], 1, tolerance: 1e-7))
		#expect(close(scores["c"], 3 / lambda, tolerance: 1e-7))
	}

	/// Star with four leaves: lambda = 2, centre 1, each leaf 1/2.
	@Test("Star: the hub is 1 and each leaf is one half")
	func star() throws {
		let scores = try Centrality.eigenvector(
			graph([("hub", "a"), ("hub", "b"), ("hub", "c"), ("hub", "d")]))
		#expect(close(scores["hub"], 1, tolerance: 1e-7))
		for leaf in ["a", "b", "c", "d"] { #expect(close(scores[leaf], 0.5, tolerance: 1e-7)) }
	}

	/// Path of four: lambda is the golden ratio phi; eigenvector (1, phi, phi, 1).
	@Test("Path of four: the ends are 1/phi")
	func pathOfFour() throws {
		let phi = (1 + 5.0.squareRoot()) / 2
		let scores = try Centrality.eigenvector(pathGraph(4))
		let nodes = names(4)
		#expect(close(scores[nodes[0]], 1 / phi, tolerance: 1e-7))
		#expect(close(scores[nodes[1]], 1, tolerance: 1e-7))
		#expect(close(scores[nodes[2]], 1, tolerance: 1e-7))
		#expect(close(scores[nodes[3]], 1 / phi, tolerance: 1e-7))
	}

	/// K(2,3): lambda = sqrt(6). The two-node side scores 1, the three-node
	/// side sqrt(2/3).
	@Test("Complete bipartite K(2,3): sides are 1 and sqrt(2/3)")
	func completeBipartite() throws {
		var edges: [(String, String)] = []
		for left in ["l1", "l2"] { for right in ["r1", "r2", "r3"] { edges.append((left, right)) } }
		let scores = try Centrality.eigenvector(graph(edges))
		for left in ["l1", "l2"] { #expect(close(scores[left], 1, tolerance: 1e-7)) }
		for right in ["r1", "r2", "r3"] {
			#expect(close(scores[right], (2.0 / 3.0).squareRoot(), tolerance: 1e-7))
		}
	}

	@Test("The empty graph has no scores and a lone node scores 1")
	func degenerate() throws {
		#expect(try Centrality.eigenvector(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		let lone = try Centrality.eigenvector(graph([], isolated: ["x"]))
		#expect(lone.scores == ["x": 1])
	}

	/// With no edges at all there is nothing to rank. Before ADR-009 every node scored exactly 1, the
	/// tied largest, which reported the absence of a ranking as if it were a measurement. An edgeless
	/// graph of two or more nodes is disconnected, and is refused with one component per node.
	@Test("An edgeless graph is refused, one component per node (it used to score every node 1)")
	func edgeless() throws {
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 3)) {
			_ = try Centrality.eigenvector(graph([], isolated: ["x", "y", "z"]))
		}
	}

	@Test("Two nodes: a joined pair both score one, and two strangers are refused")
	func twoNodes() throws {
		let pair = try Centrality.eigenvector(graph([("a", "b")]))
		#expect(close(pair["a"], 1, tolerance: 1e-9)); #expect(close(pair["b"], 1, tolerance: 1e-9))
		#expect(pair.scores.count == 2)
		// Two strangers are two components: refused since ADR-009 (they used to both score 1, the
		// tied largest, which reported the absence of a ranking as a measurement).
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 2)) {
			_ = try Centrality.eigenvector(graph([], isolated: ["a", "b"]))
		}
	}

	/// Path of six has eigenvector sin(k pi / 7), peak sin(3 pi / 7). The
	/// answer cannot depend on the size of the weights: weights of 0.01 and of
	/// 100 must give the same scores as weights of 1. (A convergence test that
	/// looks at the unnormalised vector, or a normaliser that is not the norm,
	/// stops early on small weights and returns a half-converged vector.)
	@Test("Path of six matches sin(k pi / 7) whatever the size of the weights")
	func pathOfSixAtAnyScale() throws {
		let nodes = names(6)
		let peak = sin(3 * Double.pi / 7)
		for weight in [1.0, 0.01, 0.0001, 100.0, 1e6] {
			let g = try WeightedGraph(edges: (1..<6).map { (nodes[$0 - 1], nodes[$0], weight) })
			let scores = try Centrality.eigenvector(g)
			for (k, node) in nodes.enumerated() {
				#expect(close(scores[node], sin(Double(k + 1) * Double.pi / 7) / peak, tolerance: 1e-6),
						"weight \(weight) node \(k)")
			}
		}
	}

	/// Tolerance is the convergence threshold on the change per pass: an
	/// enormous one is met after the first pass, a negative one never is.
	@Test("An enormous tolerance stops after one pass; a negative one runs to the ceiling")
	func toleranceStops() throws {
		let g = pathGraph(6)
		let one = try Centrality.eigenvector(g, maxIterations: 1)
		#expect(try Centrality.eigenvector(g, maxIterations: 200, tolerance: 1e9) == one)
		let few = try Centrality.eigenvector(g, maxIterations: 3, tolerance: -1)
		let fewNoTolerance = try Centrality.eigenvector(g, maxIterations: 3, tolerance: 0)
		let fourPasses = try Centrality.eigenvector(g, maxIterations: 4, tolerance: -1)
		#expect(few == fewNoTolerance)
		#expect(few != fourPasses)
		#expect(try Centrality.eigenvector(g) != one)
	}

	/// The tolerance decides when to stop, so a loose one leaves a visibly
	/// unconverged vector that a tight one does not, and the answer at any
	/// tolerance is exactly what the documented iteration gives.
	@Test("Stops when the change per pass falls below the tolerance, exactly as documented")
	func stoppingRule() throws {
		var graphs: [WeightedGraph<String>] = [pathGraph(6), pathGraph(9), pathGraph(3)]
		for seed in 0..<4 as Range<UInt64> {
			graphs.append(try WeightedGraph(edges: randomConnected(seed: 30 + seed, count: 8, chords: Int(seed))))
		}
		for (index, g) in graphs.enumerated() {
			let converged = try Centrality.eigenvector(g, maxIterations: 20_000, tolerance: 1e-15)
			for tolerance in [1e-1, 1e-2, 1e-3, 1e-5] {
				let scores = try Centrality.eigenvector(g, maxIterations: 5_000, tolerance: tolerance)
				let expected = eigenvectorIteration(g, maxIterations: 5_000, tolerance: tolerance)
				for (k, node) in g.nodes.enumerated() {
					#expect(close(scores[node], expected[k], tolerance: 1e-12), "graph \(index) tol \(tolerance)")
				}
				if tolerance >= 1e-3 && index < 2 {     // slow-converging paths: visibly short of the limit
					let gap = g.nodes.map { abs((scores[$0] ?? 0) - (converged[$0] ?? 0)) }.max() ?? 0
					#expect(gap > 1e-7, "graph \(index) tol \(tolerance) did not stop early (gap \(gap))")
					#expect(gap < 0.5, "graph \(index) tol \(tolerance) gap \(gap)")
				}
			}
		}
	}

	/// One pass from the uniform start, by hand. Path a-b-c: the mean weighted
	/// degree is 4/3, so one pass of (A + 4/3 I) on (1,1,1)/3 gives
	/// (7/3, 10/3, 7/3)/3, i.e. scores (0.7, 1, 0.7). This pins the shift that
	/// makes the iteration converge on bipartite graphs.
	@Test("One pass from the uniform start, by hand")
	func onePass() throws {
		let one = try Centrality.eigenvector(graph([("a", "b"), ("b", "c")]), maxIterations: 1)
		#expect(close(one["a"], 0.7, tolerance: 1e-12)); #expect(close(one["b"], 1, tolerance: 1e-12))
		#expect(close(one["c"], 0.7, tolerance: 1e-12))
	}

	@Test("A node with no ties beside a connected component is refused, not scored zero (ADR-009)")
	func isolateIsRefused() throws {
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 2)) {
			_ = try Centrality.eigenvector(graph([("a", "b"), ("b", "c"), ("c", "a")], isolated: ["x"]))
		}
	}

	/// Before ADR-009 the dominant component won: a triangle (lambda 2) beat a lone edge (lambda 1)
	/// and the edge's two nodes decayed to zero. Two components are refused instead.
	@Test("Two components, one dominant, are refused instead of the larger eigenvalue taking all the weight")
	func dominantComponent() throws {
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 2)) {
			_ = try Centrality.eigenvector(graph([("a", "b"), ("b", "c"), ("c", "a"), ("x", "y")]))
		}
	}

	/// `maxIterations` is a ceiling that is floored at one pass.
	@Test("The iteration ceiling is honoured and never below one")
	func iterationCeiling() throws {
		let g = pathGraph(6)
		let zero = try Centrality.eigenvector(g, maxIterations: 0)
		let one = try Centrality.eigenvector(g, maxIterations: 1)
		let two = try Centrality.eigenvector(g, maxIterations: 2)
		let converged = try Centrality.eigenvector(g, maxIterations: 5_000, tolerance: 1e-14)
		#expect(zero == one)
		#expect(one != two)
		#expect(one != converged)
		// A uniform start is not one pass: one pass has already moved off it.
		#expect(Set(one.scores.values).count > 1)
	}

	/// The defaults are part of the contract: a stored result is only
	/// comparable across years if the same call keeps meaning the same thing.
	/// A path of fifteen converges slowly enough that the ceiling binds, a
	/// path of six converges inside it at a rate that makes the tolerance bind.
	@Test("The defaults are 200 iterations and a tolerance of 1e-10")
	func defaultsArePinned() throws {
		for g in [pathGraph(15), pathGraph(6), pathGraph(8)] {
			let byDefault = try Centrality.eigenvector(g)
			let explicit = try Centrality.eigenvector(g, maxIterations: 200, tolerance: 1e-10)
			#expect(byDefault == explicit)
		}
	}

	// MARK: Properties

	/// The defining equation, checked directly: A v = lambda v. Run on random
	/// connected weighted graphs, trees included (trees are bipartite).
	@Test("The result satisfies A v = lambda v on random graphs, trees included")
	func eigenEquation() throws {
		for seed in 0..<12 as Range<UInt64> {
			let count = 6 + Int(seed % 5)
			let chords = seed % 3 == 0 ? 0 : Int(seed % 4) + 1   // some pure trees
			let g = try WeightedGraph(edges: randomConnected(seed: seed, count: count, chords: chords))
			let scores = try Centrality.eigenvector(g)
			let v = g.nodes.map { scores[$0] ?? .nan }
			let av = (0..<g.nodeCount).map { row in
				g.adjacency[row].reduce(0.0) { $0 + $1.weight * v[$1.neighbour] }
			}
			// lambda from the Rayleigh quotient.
			let lambda = zip(av, v).reduce(0.0) { $0 + $1.0 * $1.1 } / v.reduce(0.0) { $0 + $1 * $1 }
			#expect(lambda > 0, "seed \(seed)")
			for row in 0..<v.count {
				#expect(abs(av[row] - lambda * v[row]) < 1e-5 * max(1, lambda),
						"seed \(seed) node \(row): residual \(av[row] - lambda * v[row])")
			}
			#expect(close(v.max(), 1, tolerance: 1e-12))
			#expect(v.allSatisfy { $0 >= 0 && $0 <= 1 })
		}
	}

	@Test("Invariant under relabelling that keeps the sort order, and under weight scaling")
	func invariances() throws {
		for seed in 0..<6 as Range<UInt64> {
			let edges = randomConnected(seed: 50 + seed, count: 9, chords: 4)
			let base = try Centrality.eigenvector(try WeightedGraph(edges: edges))
			let renamed = try Centrality.eigenvector(try relabelled(edges) { "z" + $0 })
			let scaledEdges = edges.map { ($0.0, $0.1, $0.2 * 8) }       // exact in binary
			let scaled = try Centrality.eigenvector(try WeightedGraph(edges: scaledEdges))
			let scaledOdd = try Centrality.eigenvector(
				try WeightedGraph(edges: edges.map { ($0.0, $0.1, $0.2 * 3.7) }))
			for node in names(9) {
				#expect(close(renamed["z" + node], base[node], tolerance: 1e-12))
				#expect(close(scaled[node], base[node], tolerance: 1e-12))
				#expect(close(scaledOdd[node], base[node], tolerance: 1e-8))
			}
		}
	}

	/// Reversing the sort order of the labels is a genuine permutation, and
	/// the scores must follow the nodes.
	@Test("Invariant under an arbitrary permutation of the labels")
	func permutationInvariance() throws {
		let edges = randomConnected(seed: 77, count: 8, chords: 3)
		let nodes = names(8)
		let permutation = Dictionary(uniqueKeysWithValues: zip(nodes, nodes.reversed()))
		let base = try Centrality.eigenvector(try WeightedGraph(edges: edges))
		let permuted = try Centrality.eigenvector(try relabelled(edges) { permutation[$0] ?? $0 })
		for node in nodes {
			#expect(close(permuted[image(node, permutation)], base[node], tolerance: 1e-7))
		}
	}
}

// MARK: - PageRank

/// Reference PageRank by solving the linear system directly (Gaussian
/// elimination with partial pivoting): p = (1-d)/n + d (M p + dangling/n),
/// i.e. (I - d (M + (1/n) e dangling^T)) p = (1-d)/n. No iteration, so it
/// shares neither the method nor any code with the implementation.
private func pageRankBySolving(
	_ g: WeightedGraph<String>, damping d: Double
) -> [String: Double] {
	let n = g.nodeCount
	var a = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
	for row in 0..<n { a[row][row] = 1; a[row][n] = (1 - d) / Double(n) }
	for source in 0..<n {
		let degree = g.adjacency[source].reduce(0.0) { $0 + $1.weight }
		if degree > 0 {
			for (target, weight) in g.adjacency[source] { a[target][source] -= d * weight / degree }
		} else {
			for target in 0..<n { a[target][source] -= d / Double(n) }
		}
	}
	for column in 0..<n {
		var pivot = column
		for row in column..<n where abs(a[row][column]) > abs(a[pivot][column]) { pivot = row }
		a.swapAt(column, pivot)
		for row in 0..<n where row != column {
			let factor = a[row][column] / a[column][column]
			for k in column...n { a[row][k] -= factor * a[column][k] }
		}
	}
	var result: [String: Double] = [:]
	for (index, node) in g.nodes.enumerated() { result[node] = a[index][n] / a[index][index] }
	return result
}

@Suite("Mutation audit: PageRank")
struct PageRankMutationTests {

	/// Path a-b-c, d = 0.85, t = 0.15/3 = 0.05. By symmetry p_a = p_c = x and
	/// x = t + d y / 2, y = t + 2 d x, so x = t (1 + d/2) / (1 - d^2).
	@Test("Path of three matches the closed form")
	func pathOfThree() throws {
		let d = 0.85, t = 0.05
		let x = t * (1 + d / 2) / (1 - d * d)
		let scores = try Centrality.pageRank(graph([("a", "b"), ("b", "c")]))
		#expect(close(scores["a"], x))
		#expect(close(scores["c"], x))
		#expect(close(scores["b"], 1 - 2 * x))
		#expect(close(x, 0.2567567567567568, tolerance: 1e-12))
	}

	/// Star with three leaves: c = t (1 + 3d) / (1 - d^2), t = 0.15 / 4.
	@Test("Star matches the closed form")
	func star() throws {
		let d = 0.85, t = 0.15 / 4
		let hub = t * (1 + 3 * d) / (1 - d * d)
		let scores = try Centrality.pageRank(graph([("h", "a"), ("h", "b"), ("h", "c")]))
		#expect(close(scores["h"], hub))
		for leaf in ["a", "b", "c"] { #expect(close(scores[leaf], (1 - hub) / 3)) }
	}

	/// An isolated node is dangling and shares its mass equally. Edge a-b plus
	/// isolate c: z = t / (1 - d/3), x = (t + d z / 3) / (1 - d), t = 0.05.
	@Test("A dangling node's mass is shared equally")
	func dangling() throws {
		let d = 0.85, t = 0.05
		let z = t / (1 - d / 3)
		let x = (t + d * z / 3) / (1 - d)
		let scores = try Centrality.pageRank(graph([("a", "b")], isolated: ["c"]))
		#expect(close(scores["c"], z))
		#expect(close(scores["a"], x))
		#expect(close(scores["b"], x))
	}

	@Test("Damping zero is uniform; out-of-range damping is refused, not clamped (ADR-009)")
	func damping() throws {
		let g = graph([("a", "b"), ("b", "c"), ("c", "d"), ("b", "d")])
		let uniform = try Centrality.pageRank(g, damping: 0)
		for node in g.nodes { #expect(close(uniform[node], 0.25, tolerance: 1e-12)) }
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.pageRank(g, damping: -3) }
		let high = try Centrality.pageRank(g, damping: 0.999)
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.pageRank(g, damping: 7) }
		#expect(throws: GraphMeasureError.self) { _ = try Centrality.pageRank(g, damping: 1) }
		#expect(try Centrality.pageRank(g, damping: 0.5) != uniform)
		#expect(try Centrality.pageRank(g, damping: 0.5) != high)
	}

	@Test("The empty graph has no scores; a single node holds all the rank")
	func degenerate() throws {
		#expect(try Centrality.pageRank(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		let lone = try Centrality.pageRank(graph([], isolated: ["x"]))
		#expect(close(lone["x"], 1, tolerance: 1e-9))
	}

	/// One pass from the uniform start, by hand. Path a-b-c, d = 0.85:
	/// a gets 0.05 + 0.85 (1/3)/2 = 0.19167; b gets 0.05 + 2 (0.85)(1/3) = 0.61667.
	@Test("The iteration ceiling is honoured and floored at one pass")
	func iterationCeiling() throws {
		let g = graph([("a", "b"), ("b", "c")])
		let one = try Centrality.pageRank(g, maxIterations: 1)
		#expect(close(one["a"], 0.05 + 0.85 / 6, tolerance: 1e-12))
		#expect(close(one["b"], 0.05 + 2 * 0.85 / 3, tolerance: 1e-12))
		#expect(close(one["c"], 0.05 + 0.85 / 6, tolerance: 1e-12))
		#expect(try Centrality.pageRank(g, maxIterations: 0) == one)
		#expect(try Centrality.pageRank(g, maxIterations: 2) != one)
		let twoPasses = try Centrality.pageRank(g, maxIterations: 2)
		let converged = try Centrality.pageRank(g)
		#expect(twoPasses != converged)
	}

	@Test("An enormous tolerance stops after one pass")
	func toleranceStops() throws {
		let g = pathGraph(6)
		let one = try Centrality.pageRank(g, maxIterations: 1)
		#expect(try Centrality.pageRank(g, maxIterations: 200, tolerance: 1e9) == one)
		let fivePasses = try Centrality.pageRank(g, maxIterations: 5, tolerance: -1)
		let sixPasses = try Centrality.pageRank(g, maxIterations: 6, tolerance: -1)
		#expect(fivePasses != sixPasses)
		#expect(try Centrality.pageRank(g) != one)
	}

	@Test("A loose tolerance stops visibly short of the converged answer")
	func looseToleranceStopsEarly() throws {
		let g = pathGraph(7)
		let converged = try Centrality.pageRank(g, maxIterations: 20_000, tolerance: 1e-15)
		let loose = try Centrality.pageRank(g, maxIterations: 5_000, tolerance: 1e-3)
		let gap = g.nodes.map { abs((loose[$0] ?? 0) - (converged[$0] ?? 0)) }.max() ?? 0
		#expect(gap > 1e-7 && gap < 0.05, "gap \(gap)")
		let tight = try Centrality.pageRank(g, maxIterations: 5_000, tolerance: 1e-9)
		let tightGap = g.nodes.map { abs((tight[$0] ?? 0) - (converged[$0] ?? 0)) }.max() ?? 0
		#expect(tightGap < gap)
		#expect(tightGap < 1e-7)
	}

	@Test("The defaults are 200 iterations and a tolerance of 1e-12")
	func defaultsArePinned() throws {
		let g = pathGraph(7)
		let byDefault = try Centrality.pageRank(g)
		let explicit = try Centrality.pageRank(g, damping: 0.85, maxIterations: 200, tolerance: 1e-12)
		#expect(byDefault == explicit)
		// Heavy damping converges so slowly the ceiling binds.
		let heavyDefault = try Centrality.pageRank(g, damping: 0.99)
		let heavyExplicit = try Centrality.pageRank(g, damping: 0.99, maxIterations: 200, tolerance: 1e-12)
		#expect(heavyDefault == heavyExplicit)
	}

	@Test("The default tolerance reaches the converged answer to better than 1e-9")
	func defaultToleranceIsTight() throws {
		let g = pathGraph(7)
		let reference = pageRankBySolving(g, damping: 0.85)
		let scores = try Centrality.pageRank(g)
		for node in g.nodes { #expect(close(scores[node], reference[node], tolerance: 1e-10)) }
	}

	// MARK: Properties

	@Test("Agrees with a direct linear solve on random weighted graphs, isolates and light weights included")
	func agreesWithLinearSolve() throws {
		for seed in 0..<10 as Range<UInt64> {
			let count = 5 + Int(seed % 5)
			var edges: [(String, String, Double)] = []
			// Rebuild with light (< 1) weights so a node's weighted degree can be below one.
			var rng = SplitMix64(seed: 900 + seed)
			let nodes = names(count + 2)           // two nodes never get an edge
			for _ in 0..<(6 + Int(seed)) {
				let a = Int.random(in: 0..<count, using: &rng)
				let b = Int.random(in: 0..<count, using: &rng)
				edges.append((nodes[a], nodes[b], Double(Int.random(in: 1...8, using: &rng)) / 10))
			}
			let g = try WeightedGraph(edges: edges, isolatedNodes: nodes)
			for damping in [0.85, 0.5] {
				let reference = pageRankBySolving(g, damping: damping)
				let scores = try Centrality.pageRank(g, damping: damping)
				for node in g.nodes {
					#expect(close(scores[node], reference[node], tolerance: 1e-9),
							"seed \(seed) d \(damping) \(node)")
				}
			}
		}
	}

	@Test("Scores are positive and sum to one")
	func sumsToOne() throws {
		for seed in 0..<8 as Range<UInt64> {
			let g = try randomGraph(seed: 400 + seed, count: 8, edgeCount: 9, isolated: 2)
			let scores = try Centrality.pageRank(g)
			#expect(close(scores.scores.values.reduce(0, +), 1, tolerance: 1e-9))
			#expect(scores.scores.values.allSatisfy { $0 > 0 })
			#expect(scores.scores.count == g.nodeCount)
		}
	}

	@Test("Invariant under weight scaling and under relabelling")
	func invariances() throws {
		for seed in 0..<5 as Range<UInt64> {
			let edges = randomConnected(seed: 70 + seed, count: 8, chords: 3)
			let base = try Centrality.pageRank(try WeightedGraph(edges: edges))
			let scaled = try Centrality.pageRank(
				try WeightedGraph(edges: edges.map { ($0.0, $0.1, $0.2 * 0.01) }))
			let nodes = names(8)
			let permutation = Dictionary(uniqueKeysWithValues: zip(nodes, nodes.reversed()))
			let permuted = try Centrality.pageRank(try relabelled(edges) { permutation[$0] ?? $0 })
			for node in nodes {
				#expect(close(scaled[node], base[node], tolerance: 1e-9))
				#expect(close(permuted[image(node, permutation)], base[node], tolerance: 1e-9))
			}
		}
	}

	@Test("Nodes in symmetric positions score the same")
	func symmetry() throws {
		let ring = graph((0..<5).map { ("r\($0)", "r\(($0 + 1) % 5)") })
		let scores = try Centrality.pageRank(ring)
		for node in ring.nodes { #expect(close(scores[node], 0.2, tolerance: 1e-9)) }
	}
}

// MARK: - Betweenness

@Suite("Mutation audit: betweenness")
struct BetweennessMutationTests {

	@Test("Path of three: the middle node carries the only pair, so 1 normalised and 1 raw")
	func pathOfThree() throws {
		let g = graph([("a", "b"), ("b", "c")])
		let normalised = Centrality.betweenness(g)
		#expect(close(normalised["b"], 1)); #expect(close(normalised["a"], 0)); #expect(close(normalised["c"], 0))
		let raw = Centrality.betweenness(g, normalized: false)
		#expect(close(raw["b"], 1)); #expect(close(raw["a"], 0))
	}

	/// Star with four leaves: the hub is on all C(4,2) = 6 leaf pairs.
	@Test("Star hub: raw 6, normalised 1")
	func star() throws {
		let g = graph([("h", "a"), ("h", "b"), ("h", "c"), ("h", "d")])
		#expect(close(Centrality.betweenness(g, normalized: false)["h"], 6))
		#expect(close(Centrality.betweenness(g)["h"], 1))
		#expect(close(Centrality.betweenness(g)["a"], 0))
	}

	/// Path of four: each inner node is on two pairs (raw 2); normaliser is C(3,2) = 3.
	@Test("Path of four: inner nodes 2 raw, 2/3 normalised")
	func pathOfFour() throws {
		let g = pathGraph(4)
		let nodes = names(4)
		let raw = Centrality.betweenness(g, normalized: false)
		let normalised = Centrality.betweenness(g)
		for inner in [nodes[1], nodes[2]] {
			#expect(close(raw[inner], 2)); #expect(close(normalised[inner], 2.0 / 3.0))
		}
		for end in [nodes[0], nodes[3]] { #expect(close(raw[end], 0)); #expect(close(normalised[end], 0)) }
	}

	/// Four-cycle: opposite nodes have two shortest paths, so each of the two
	/// middle nodes carries half a pair. Raw 1/2 each; normalised 1/6.
	@Test("Four-cycle splits a pair between two shortest paths")
	func fourCycle() throws {
		let g = graph([("a", "b"), ("b", "c"), ("c", "d"), ("d", "a")])
		let raw = Centrality.betweenness(g, normalized: false)
		let normalised = Centrality.betweenness(g)
		for node in ["a", "b", "c", "d"] {
			#expect(close(raw[node], 0.5)); #expect(close(normalised[node], 1.0 / 6.0))
		}
	}

	/// Path a-b-c next to an unconnected isolate x: n = 4, so the normaliser is
	/// C(3,2) = 3 and b scores 1/3. Pairs with x are unreachable and count for nothing.
	@Test("Unreachable pairs contribute nothing")
	func disconnected() throws {
		let g = graph([("a", "b"), ("b", "c")], isolated: ["x"])
		#expect(close(Centrality.betweenness(g, normalized: false)["b"], 1))
		#expect(close(Centrality.betweenness(g)["b"], 1.0 / 3.0))
		#expect(close(Centrality.betweenness(g)["x"], 0))
	}

	@Test("Graphs of at most two nodes score zero for every node")
	func tiny() throws {
		#expect(Centrality.betweenness(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		#expect(Centrality.betweenness(graph([], isolated: ["x"])).scores == ["x": 0])
		#expect(Centrality.betweenness(graph([("a", "b")])).scores == ["a": 0, "b": 0])
		#expect(Centrality.betweenness(graph([], isolated: ["x", "y"])).scores == ["x": 0, "y": 0])
		#expect(Centrality.betweenness(graph([("a", "b")]), normalized: false).scores == ["a": 0, "b": 0])
	}

	@Test("Edge weights record strength, not distance: they do not change the result")
	func weightsIgnored() throws {
		let heavy = try WeightedGraph(edges: [("a", "b", 100.0), ("b", "c", 0.01), ("c", "d", 7.0), ("a", "d", 0.5)])
		let light = graph([("a", "b"), ("b", "c"), ("c", "d"), ("a", "d")])
		#expect(Centrality.betweenness(heavy) == Centrality.betweenness(light))
	}

	// MARK: Properties

	@Test("Brandes agrees with brute-force enumeration on random graphs, isolates included")
	func agreesWithEnumeration() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try randomGraph(seed: 500 + seed, count: 8, edgeCount: 7 + Int(seed % 6), isolated: Int(seed % 3))
			for normalized in [true, false] {
				let fast = Centrality.betweenness(g, normalized: normalized)
				let slow = IndependentImplementations.betweennessByEnumeration(g, normalized: normalized)
				for node in g.nodes {
					#expect(close(fast[node], slow[node], tolerance: 1e-9), "seed \(seed) \(node)")
				}
			}
		}
	}

	@Test("Normalised betweenness lies in [0, 1]; it is invariant under any relabelling")
	func boundsAndRelabelling() throws {
		for seed in 0..<8 as Range<UInt64> {
			let edges = randomConnected(seed: 600 + seed, count: 9, chords: 4)
			let base = Centrality.betweenness(try WeightedGraph(edges: edges))
			let nodes = names(9)
			let permutation = Dictionary(uniqueKeysWithValues: zip(nodes, nodes.reversed()))
			let permuted = Centrality.betweenness(try relabelled(edges) { permutation[$0] ?? $0 })
			for node in nodes {
				let value = base[node]
				#expect(atMost(value, 1) && atMost(value.map { -$0 }, 0))
				#expect(close(permuted[image(node, permutation)], value, tolerance: 1e-12))
			}
		}
	}
}

// MARK: - Closeness and harmonic

@Suite("Mutation audit: closeness and harmonic centrality")
struct ClosenessHarmonicMutationTests {

	/// Closeness here is (reached/(n-1)) / (mean distance) = reached^2 / ((n-1) total).
	/// Path a-b-c: an end reaches 2 nodes at total distance 3, so 4/(2*3) = 2/3;
	/// the middle has total 2, so 4/(2*2) = 1.
	@Test("Closeness on a path of three")
	func closenessPathOfThree() throws {
		let scores = Centrality.closeness(graph([("a", "b"), ("b", "c")]))
		#expect(close(scores["a"], 2.0 / 3.0)); #expect(close(scores["c"], 2.0 / 3.0))
		#expect(close(scores["b"], 1))
	}

	/// Star with four leaves: a leaf reaches 4 at total 1 + 2*3 = 7: 16/(4*7) = 4/7.
	@Test("Closeness on a star")
	func closenessStar() throws {
		let scores = Centrality.closeness(
			graph([("h", "a"), ("h", "b"), ("h", "c"), ("h", "d")]))
		#expect(close(scores["h"], 1))
		for leaf in ["a", "b", "c", "d"] { #expect(close(scores[leaf], 4.0 / 7.0)) }
	}

	/// A pair has one other node at distance one: closeness is 1.
	@Test("Closeness of a lone edge is one")
	func closenessEdge() throws {
		let scores = Centrality.closeness(graph([("a", "b")]))
		#expect(close(scores["a"], 1)); #expect(close(scores["b"], 1))
	}

	/// Path a-b-c with an isolate x (n = 4): an end reaches 2 of 3 at total 3:
	/// 4 / (3 * 3) = 4/9. The isolate reaches nobody: 0.
	@Test("Closeness discounts what cannot be reached, and an isolate scores zero")
	func closenessDisconnected() throws {
		let scores = Centrality.closeness(graph([("a", "b"), ("b", "c")], isolated: ["x"]))
		#expect(close(scores["a"], 4.0 / 9.0))
		#expect(close(scores["b"], 4.0 / (3 * 2)))
		#expect(close(scores["x"], 0))
	}

	@Test("Closeness of a graph of at most one node is zero")
	func closenessTiny() throws {
		#expect(Centrality.closeness(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		#expect(Centrality.closeness(graph([], isolated: ["x"])).scores == ["x": 0])
		#expect(Centrality.closeness(graph([], isolated: ["x", "y"])).scores == ["x": 0, "y": 0])
	}

	/// Path a-b-c: an end has distances 1 and 2, so (1 + 1/2) / 2 = 3/4; the
	/// middle (1 + 1)/2 = 1.
	@Test("Harmonic on a path of three")
	func harmonicPathOfThree() throws {
		let scores = Centrality.harmonic(graph([("a", "b"), ("b", "c")]))
		#expect(close(scores["a"], 0.75)); #expect(close(scores["c"], 0.75))
		#expect(close(scores["b"], 1))
	}

	/// Path a-b-c with an isolate: an end sums 1 + 1/2 over n - 1 = 3.
	@Test("Harmonic counts the unreachable as zero but still divides by n - 1")
	func harmonicDisconnected() throws {
		let scores = Centrality.harmonic(graph([("a", "b"), ("b", "c")], isolated: ["x"]))
		#expect(close(scores["a"], 1.5 / 3)); #expect(close(scores["b"], 2.0 / 3))
		#expect(close(scores["x"], 0))
	}

	/// Path of five: an end has distances 1, 2, 3, 4: (1 + 1/2 + 1/3 + 1/4) / 4.
	@Test("Harmonic on a path of five weights distance 3 and 4 by their reciprocals")
	func harmonicPathOfFive() throws {
		let scores = Centrality.harmonic(pathGraph(5))
		let nodes = names(5)
		let endExpected: Double = (1.0 + 0.5 + 1.0 / 3.0 + 0.25) / 4.0
		let middleExpected: Double = (1.0 + 1.0 + 0.5 + 0.5) / 4.0
		#expect(close(scores[nodes[0]], endExpected))
		#expect(close(scores[nodes[2]], middleExpected))
	}

	@Test("Harmonic of a graph of at most one node is zero")
	func harmonicTiny() throws {
		#expect(Centrality.harmonic(try WeightedGraph<String>(edges: [])).scores.isEmpty)
		#expect(Centrality.harmonic(graph([], isolated: ["x"])).scores == ["x": 0])
		#expect(close(Centrality.harmonic(graph([("a", "b")]))["a"], 1))
	}

	/// Brute-force distances by Floyd-Warshall: no queue, no frontier.
	private func allPairs(_ g: WeightedGraph<String>) -> [[Int]] {
		let n = g.nodeCount, none = 1_000_000
		var d = [[Int]](repeating: [Int](repeating: none, count: n), count: n)
		for i in 0..<n { d[i][i] = 0; for (j, _) in g.adjacency[i] { d[i][j] = 1 } }
		for k in 0..<n { for i in 0..<n { for j in 0..<n where d[i][k] + d[k][j] < d[i][j] {
			d[i][j] = d[i][k] + d[k][j] } } }
		return d.map { $0.map { $0 >= none ? -1 : $0 } }
	}

	@Test("Closeness and harmonic agree with Floyd-Warshall distances on random graphs")
	func agreesWithAllPairs() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try randomGraph(seed: 700 + seed, count: 9, edgeCount: 6 + Int(seed % 6), isolated: Int(seed % 3))
			let d = allPairs(g), n = g.nodeCount
			let closeness = Centrality.closeness(g), harmonic = Centrality.harmonic(g)
			for (i, node) in g.nodes.enumerated() {
				let reachable = (0..<n).filter { $0 != i && d[i][$0] > 0 }
				let total = reachable.reduce(0) { $0 + d[i][$1] }
				let expectedCloseness = reachable.isEmpty
					? 0 : Double(reachable.count * reachable.count) / Double((n - 1) * total)
				let expectedHarmonic = reachable.reduce(0.0) { $0 + 1.0 / Double(d[i][$1]) } / Double(n - 1)
				#expect(close(closeness[node], expectedCloseness), "seed \(seed) \(node)")
				#expect(close(harmonic[node], expectedHarmonic), "seed \(seed) \(node)")
				#expect(expectedCloseness >= 0 && expectedCloseness <= 1)
				#expect(expectedHarmonic >= 0 && expectedHarmonic <= 1)
			}
		}
	}

	@Test("Both are invariant under weight scaling, which they ignore")
	func weightsIgnored() throws {
		let edges = randomConnected(seed: 801, count: 8, chords: 3)
		let a = try WeightedGraph(edges: edges)
		let b = try WeightedGraph(edges: edges.map { ($0.0, $0.1, $0.2 * 13) })
		#expect(Centrality.closeness(a) == Centrality.closeness(b))
		#expect(Centrality.harmonic(a) == Centrality.harmonic(b))
	}
}

// MARK: - Clustering

@Suite("Mutation audit: clustering coefficient")
struct ClusteringMutationTests {

	/// Triangle a-b-c with a tail d off a. a has neighbours b, c, d, of which
	/// one pair (b-c) is linked: 1/3. b has neighbours a, c, which are linked: 1.
	/// d has a single tie: 0.
	@Test("Triangle with a pendant")
	func trianglePlusPendant() throws {
		let scores = Centrality.clustering(graph([("a", "b"), ("b", "c"), ("a", "c"), ("a", "d")]))
		#expect(close(scores["a"], 1.0 / 3.0))
		#expect(close(scores["b"], 1)); #expect(close(scores["c"], 1))
		#expect(close(scores["d"], 0))
	}

	@Test("A complete graph is fully clustered and a star not at all")
	func extremes() throws {
		let k4 = graph([("a", "b"), ("a", "c"), ("a", "d"), ("b", "c"), ("b", "d"), ("c", "d")])
		for node in k4.nodes { #expect(close(Centrality.clustering(k4)[node], 1)) }
		let star = Centrality.clustering(graph([("h", "a"), ("h", "b"), ("h", "c")]))
		for node in ["h", "a", "b", "c"] { #expect(close(star[node], 0)) }
	}

	/// Four-cycle: each node has two neighbours that are not linked.
	@Test("A node of degree two whose neighbours are not linked scores zero")
	func degreeTwoOpen() throws {
		let scores = Centrality.clustering(graph([("a", "b"), ("b", "c"), ("c", "d"), ("d", "a")]))
		for node in ["a", "b", "c", "d"] { #expect(close(scores[node], 0)) }
	}

	/// Two triangles sharing the node s: s has four neighbours with two linked
	/// pairs: 2 / C(4,2) = 1/3.
	@Test("Bow-tie centre")
	func bowTie() throws {
		let scores = Centrality.clustering(graph(
			[("s", "a"), ("s", "b"), ("a", "b"), ("s", "c"), ("s", "d"), ("c", "d")]))
		#expect(close(scores["s"], 1.0 / 3.0))
		for node in ["a", "b", "c", "d"] { #expect(close(scores[node], 1)) }
	}

	@Test("Isolates and edgeless graphs score zero; every node is present")
	func isolates() throws {
		let scores = Centrality.clustering(graph([("a", "b"), ("b", "c"), ("a", "c")], isolated: ["x"]))
		#expect(scores.scores.count == 4); #expect(close(scores["x"], 0))
		#expect(Centrality.clustering(try WeightedGraph<String>(edges: [])).scores.isEmpty)
	}

	/// Brute-force triangle counting over node triples.
	@Test("Agrees with explicit triangle counting on random graphs; weights are ignored")
	func agreesWithTriples() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try randomGraph(seed: 900 + seed, count: 9, edgeCount: 10 + Int(seed % 8), isolated: 1)
			let n = g.nodeCount
			var linked = [[Bool]](repeating: [Bool](repeating: false, count: n), count: n)
			for i in 0..<n { for (j, _) in g.adjacency[i] { linked[i][j] = true } }
			let scores = Centrality.clustering(g)
			for (i, node) in g.nodes.enumerated() {
				let neighbours = (0..<n).filter { linked[i][$0] }
				var triangles = 0
				for x in 0..<neighbours.count { for y in (x + 1)..<max(x + 1, neighbours.count)
					where linked[neighbours[x]][neighbours[y]] { triangles += 1 } }
				let k = Double(neighbours.count)
				let expected = neighbours.count < 2 ? 0 : Double(triangles) / (k * (k - 1) / 2)
				#expect(close(scores[node], expected), "seed \(seed) \(node)")
				#expect(expected >= 0 && expected <= 1)
			}
		}
	}
}

// MARK: - Connected components and k-core

@Suite("Mutation audit: components and k-core")
struct ComponentsKCoreMutationTests {

	/// Components are numbered 0, 1, 2 ... in the order of their smallest node,
	/// so stored results compare across runs. Here: {a,b} {c} {d,e,f}.
	@Test("Component labels are dense and ordered by smallest member")
	func labelsAreDense() throws {
		let g = graph([("a", "b"), ("d", "e"), ("e", "f")], isolated: ["c"])
		let partition = Community.connectedComponents(g)
		#expect(partition.communities == ["a": 0, "b": 0, "c": 1, "d": 2, "e": 2, "f": 2])
		#expect(Set(partition.communities.values) == [0, 1, 2])
	}

	@Test("Every node is in a component; edgeless graph gives n components")
	func total() throws {
		let g = graph([], isolated: ["x", "y", "z"])
		#expect(Community.connectedComponents(g).communities == ["x": 0, "y": 1, "z": 2])
		#expect(Community.connectedComponents(try WeightedGraph<String>(edges: [])).communities.isEmpty)
	}

	@Test("A chain is one component however it is reached")
	func chain() throws {
		let g = graph([("e", "d"), ("d", "c"), ("c", "b"), ("b", "a")])
		#expect(Set(Community.connectedComponents(g).communities.values) == [0])
	}

	/// Union-find reference: no queue.
	@Test("Agrees with union-find on random graphs, and two nodes share a label iff connected")
	func agreesWithUnionFind() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try randomGraph(seed: 1_100 + seed, count: 9, edgeCount: 4 + Int(seed % 5), isolated: 2)
			var parent = Array(0..<g.nodeCount)
			func find(_ x: Int) -> Int { var r = x; while parent[r] != r { r = parent[r] }; return r }
			for i in 0..<g.nodeCount { for (j, _) in g.adjacency[i] { parent[find(i)] = find(j) } }
			let partition = Community.connectedComponents(g)
			for i in 0..<g.nodeCount {
				for j in 0..<g.nodeCount {
					#expect((partition[g.nodes[i]] == partition[g.nodes[j]]) == (find(i) == find(j)))
				}
			}
		}
	}

	/// K4 (abcd) with a pendant e off a: the K4 is the 3-core, e is 1.
	@Test("k-core of a clique with a pendant")
	func cliquePlusPendant() throws {
		let g = graph([("a", "b"), ("a", "c"), ("a", "d"), ("b", "c"), ("b", "d"), ("c", "d"), ("a", "e")],
					  isolated: ["x"])
		let cores = Community.kCore(g)
		for node in ["a", "b", "c", "d"] { #expect(close(cores[node], 3)) }
		#expect(close(cores["e"], 1)); #expect(close(cores["x"], 0))
	}

	@Test("k-core of paths, stars and cycles")
	func simpleShapes() throws {
		let path = Community.kCore(pathGraph(5))
		for node in names(5) { #expect(close(path[node], 1)) }
		let star = Community.kCore(graph([("h", "a"), ("h", "b"), ("h", "c")]))
		for node in ["h", "a", "b", "c"] { #expect(close(star[node], 1)) }
		let cycle = Community.kCore(graph([("a", "b"), ("b", "c"), ("c", "d"), ("d", "a")]))
		for node in ["a", "b", "c", "d"] { #expect(close(cycle[node], 2)) }
	}

	/// A triangle whose members each carry a tail of two: the triangle is the
	/// 2-core, the tails 1. Peeling the tails must not lower the triangle.
	@Test("Peeling a tail does not reduce the core beneath it")
	func tails() throws {
		let g = graph([("a", "b"), ("b", "c"), ("c", "a"), ("a", "a1"), ("a1", "a2"), ("b", "b1")])
		let cores = Community.kCore(g)
		for node in ["a", "b", "c"] { #expect(close(cores[node], 2)) }
		for node in ["a1", "a2", "b1"] { #expect(close(cores[node], 1)) }
	}

	@Test("Agrees with literal peeling on random graphs, and is bounded by degree")
	func agreesWithPeeling() throws {
		for seed in 0..<12 as Range<UInt64> {
			let g = try randomGraph(seed: 1_300 + seed, count: 10, edgeCount: 8 + Int(seed), isolated: 1)
			let fast = Community.kCore(g)
			let slow = IndependentImplementations.kCoreByPeeling(g)
			for (i, node) in g.nodes.enumerated() {
				#expect(fast[node] == slow[node], "seed \(seed) \(node)")
				#expect(atMost(fast[node], Double(g.neighbourCount(i))))
			}
		}
	}

	@Test("Weights do not affect core numbers")
	func weightsIgnored() throws {
		let edges = randomConnected(seed: 1_400, count: 9, chords: 6)
		#expect(Community.kCore(try WeightedGraph(edges: edges))
				== Community.kCore(try WeightedGraph(edges: edges.map { ($0.0, $0.1, $0.2 * 9) })))
	}
}
