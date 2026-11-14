//
//  ByComponentParityCases.swift
//  BusinessMath
//
//  The synthetic graphs the by-component parity goldens are generated over, as plain data. A
//  scratch program outside this repository (kept as a script under
//  project/summaries/2026-11-14_network_eigenvector_by_component/golden/) compiles THIS file
//  together with a copy of ClassGraph's ComponentwiseEigenvector.swift and prints the encoded
//  results; the tests build graphs from the same file. Nothing here is derived from real data.
//

import Foundation
import TestSupport

/// One graph and one set of iteration settings for the parity goldens.
struct ByComponentParityCase {
	/// A short stable name; the golden table is keyed by it.
	let name: String
	/// `(from, to, weight)` ties.
	let edges: [(String, String, Double)]
	/// Nodes with no ties at all.
	let isolated: [String]
	/// The iteration ceiling the case is run with.
	let maxIterations: Int
	/// The convergence tolerance the case is run with.
	let tolerance: Double
	/// Whether the result is the same bit for bit in every process.
	///
	/// `WeightedGraph` sums its total weight in dictionary order, so for weights that are not
	/// binary fractions the last bit of every score can differ between processes (measured while
	/// generating these goldens: two of the decimal-weight cases differed in 8 runs). A case with
	/// `exact == false` is compared to a tolerance, not to the bytes.
	let exact: Bool

	init(
		_ name: String, edges: [(String, String, Double)], isolated: [String] = [],
		maxIterations: Int = 200, tolerance: Double = 1e-10, exact: Bool = true
	) {
		self.name = name
		self.edges = edges
		self.isolated = isolated
		self.maxIterations = maxIterations
		self.tolerance = tolerance
		self.exact = exact
	}
}

/// The cases the by-component goldens cover. All synthetic.
enum ByComponentParityCases {

	private static func unit(_ pairs: [(String, String)]) -> [(String, String, Double)] {
		pairs.map { ($0.0, $0.1, 1.0) }
	}

	private static func pathName(_ index: Int) -> String {
		index < 10 ? "p0\(index)" : "p\(index)"
	}

	private static var longPath: [(String, String, Double)] {
		(0..<29).map { (pathName($0), pathName($0 + 1), 1.0) }
	}

	private static var karate: [(String, String, Double)] {
		unit(ReferenceGraphs.karateEdges.map { (String($0.0), String($0.1)) })
	}

	/// Five components built by formula (rings and a ladder) and three isolates. `step` is the
	/// weight unit: 0.125 keeps every sum exact, 0.1 does not.
	private static func formula(step: Double) -> [(String, String, Double)] {
		var edges: [(String, String, Double)] = []
		for ring in 0..<3 {
			let size = 4 + ring
			for index in 0..<size {
				let weight = step * Double((index + ring) % 7 + 1)
				edges.append(("r\(ring)n\(index)", "r\(ring)n\((index + 1) % size)", weight))
			}
		}
		for rung in 0..<4 {
			edges.append(("l0r\(rung)", "l1r\(rung)", 0.25 * Double(rung + 1)))
			if rung > 0 {
				edges.append(("l0r\(rung - 1)", "l0r\(rung)", 0.5))
				edges.append(("l1r\(rung - 1)", "l1r\(rung)", 0.5))
			}
		}
		edges.append(("s0", "s1", 3.0))
		return edges
	}

	/// Every case in the golden table, in a fixed order.
	static let all: [ByComponentParityCase] = [
		// One component, no isolate: bit-identical to eigenvector-centrality 5.
		ByComponentParityCase("karate", edges: karate),
		ByComponentParityCase("kite", edges: unit(ReferenceGraphs.kiteEdges)),
		ByComponentParityCase("path5", edges: unit([("a", "b"), ("b", "c"), ("c", "d"), ("d", "e")])),
		ByComponentParityCase("star7", edges: unit([
			("hub", "l1"), ("hub", "l2"), ("hub", "l3"), ("hub", "l4"), ("hub", "l5"), ("hub", "l6"),
		])),
		// The next two are ClassGraph's own parity graphs, with decimal weights: not bit-stable across processes.
		ByComponentParityCase("weighted-bridge", edges: [
			("a", "b", 0.5), ("b", "c", 0.37), ("a", "c", 0.02),
			("d", "e", 0.41), ("e", "f", 0.23), ("d", "f", 0.19), ("c", "d", 0.013),
		], exact: false),
		ByComponentParityCase("weighted-lollipop", edges: [
			("k1", "k2", 1.5), ("k1", "k3", 0.75), ("k1", "k4", 2.25),
			("k2", "k3", 0.5), ("k2", "k4", 1.0), ("k3", "k4", 0.125),
			("k4", "t1", 0.3), ("t1", "t2", 0.3), ("t2", "t3", 0.3),
		], exact: false),
		ByComponentParityCase("kite-low-ceiling", edges: unit(ReferenceGraphs.kiteEdges), maxIterations: 0, tolerance: 1e-6),
		// Several components, with and without isolates.
		ByComponentParityCase("disconnected", edges: [("a", "b", 1), ("b", "c", 1), ("d", "e", 2)], isolated: ["z"]),
		ByComponentParityCase("path-pair-isolate", edges: unit([("a", "b"), ("b", "c"), ("d", "e")]), isolated: ["z"]),
		ByComponentParityCase("path-star", edges: unit([
			("a", "b"), ("b", "c"), ("h", "l1"), ("h", "l2"), ("h", "l3"),
		])),
		ByComponentParityCase("two-paths", edges: unit([("a", "b"), ("b", "c"), ("d", "e"), ("e", "f")])),
		ByComponentParityCase("triangles-pair-isolates", edges: [
			("a", "b", 0.5), ("b", "c", 0.375), ("a", "c", 0.25),
			("d", "e", 2.0), ("e", "f", 1.0), ("d", "f", 0.75),
			("g", "h", 1.0),
		], isolated: ["i1", "i2"]),
		ByComponentParityCase("triangles-pair-isolates-decimal", edges: [
			("a", "b", 0.5), ("b", "c", 0.37), ("a", "c", 0.2),
			("d", "e", 2.0), ("e", "f", 1.0), ("d", "f", 0.75),
			("g", "h", 1.0),
		], isolated: ["i1", "i2"], exact: false),
		ByComponentParityCase("karate-star-pair-isolates", edges: karate.map { ("k" + $0.0, "k" + $0.1, $0.2) } + [
			("hub", "x1", 1), ("hub", "x2", 1), ("hub", "x3", 1), ("hub", "x4", 1), ("y1", "y2", 1),
		], isolated: ["lone1", "lone2", "lone3"]),
		ByComponentParityCase("kite-and-isolate", edges: unit(ReferenceGraphs.kiteEdges), isolated: ["nobody"]),
		ByComponentParityCase("formula-five-components", edges: formula(step: 0.125), isolated: ["q1", "q2", "q3"]),
		ByComponentParityCase("formula-five-components-decimal", edges: formula(step: 0.1),
			isolated: ["q1", "q2", "q3"], exact: false),
		ByComponentParityCase("path-pair-low-ceiling", edges: unit([("a", "b"), ("b", "c"), ("d", "e")]), isolated: ["z"],
			maxIterations: 0, tolerance: 1e-6),
		// A long path does not converge in the default ceiling; the pair beside it does.
		ByComponentParityCase("long-path-and-pair", edges: longPath + [("q0", "q1", 1.0)]),
		ByComponentParityCase("long-path-and-pair-ceiling-3", edges: longPath + [("q0", "q1", 1.0)], maxIterations: 3),
		// Zero-weight ties do not connect.
		ByComponentParityCase("zero-weight-tie", edges: [("a", "b", 1), ("b", "c", 0)]),
		ByComponentParityCase("only-zero-weights", edges: [("a", "b", 0)]),
		// Trivial graphs.
		ByComponentParityCase("edgeless", edges: [], isolated: ["x", "y", "z"]),
		ByComponentParityCase("lone", edges: [], isolated: ["solo"]),
		ByComponentParityCase("empty", edges: []),
		ByComponentParityCase("lone-low-ceiling", edges: [], isolated: ["x"], maxIterations: 0, tolerance: 1e-6),
	]
}
