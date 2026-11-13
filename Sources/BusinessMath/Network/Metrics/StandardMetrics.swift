//
//  StandardMetrics.swift
//  BusinessMath
//

import Foundation

/// Weighted degree.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try DegreeMetric<String>().compute(on: graph)
/// print(scores["b"] ?? 0)   // 2.0
/// ```
public struct DegreeMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "degree", version: 1, title: "Degree",
			interpretation: "How much recorded connection this classmate has.",
			highMeans: "Many or strong recorded ties.",
			lowMeans: "Few recorded ties — which may mean few ties, or ties the "
				+ "University never recorded. The data cannot tell these apart."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.degree(graph)
	}
}

/// Eigenvector centrality — the bringers.
///
/// Version 3 supersedes version 2. Version 2 returned wrong scores on every bipartite graph
/// (trees, stars, paths); a stored record with `metricVersion` 2 for such a graph should be
/// recomputed, not compared.
///
/// Version 4 returns ``DiagnosedScores``: the same scores, plus a ``ConvergenceReport`` saying
/// whether the iteration reached its tolerance before the ceiling (200 passes by default, which
/// is short for weakly bridged clusters, lattices and long paths). Print
/// ``ConvergenceNote/sentence(_:)`` of it wherever the scores are shown.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let result = try EigenvectorMetric<String>().compute(on: graph)
/// print(result.convergence?.converged ?? false)   // true
/// ```
public struct EigenvectorMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "eigenvector-centrality", version: 4, title: "Eigenvector Centrality",
			interpretation: "Who is connected to well-connected classmates. "
				+ "Prone to localising — check it against PageRank before acting.",
			highMeans: "Well connected within whichever cluster this measure has "
				+ "fastened onto, which may not be the class. On the Class of 2000 "
				+ "the Forbes–Economics community holds a tenth of the class and "
				+ "took three quarters of the top twenty-five.",
			lowMeans: "Outside that cluster — which says little on its own, because "
				+ "everything outside a localised cluster scores near zero "
				+ "regardless of structure. Use PageRank for bringers and k-core "
				+ "for the periphery."
		)
	}
	/// The iteration ceiling.
	public let maxIterations: Int
	/// The convergence threshold.
	public let tolerance: Double
	/// Creates the metric.
	public init(maxIterations: Int = 200, tolerance: Double = 1e-10) {
		self.maxIterations = maxIterations
		self.tolerance = tolerance
	}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> DiagnosedScores<Node> {
		let run = Centrality.eigenvectorConvergence(
			graph, maxIterations: maxIterations, tolerance: tolerance)
		return DiagnosedScores(
			scores: run.scores,
			convergence: ConvergenceReport(
				iterations: run.iterations, converged: run.converged, residual: run.residual,
				tolerance: tolerance, maxIterations: max(1, maxIterations)))
	}
}

/// PageRank — a damped cross-check on eigenvector centrality.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try PageRankMetric<String>().compute(on: graph)
/// print(scores.ranked.first?.node ?? "")   // b
/// ```
public struct PageRankMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "pagerank", version: 2, title: "PageRank",
			interpretation: "Who is connected to well-connected classmates. "
				+ "The measure to use for bringers.",
			highMeans: "A bringer — activating this person reaches others through "
				+ "them. Damping keeps it from collapsing onto one dense pocket the "
				+ "way eigenvector centrality does: on the Class of 2000 its top "
				+ "twenty-five spans seven communities to eigenvector's three.",
			lowMeans: "Not well placed to activate others. Read alongside k-core "
				+ "before treating anyone as peripheral."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.pageRank(graph)
	}
}

/// Betweenness — the connectors.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try BetweennessMetric<String>().compute(on: graph)
/// print(scores["b"] ?? 0)   // 1.0
/// ```
public struct BetweennessMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "betweenness-centrality", version: 1, title: "Betweenness Centrality",
			interpretation: "Who bridges otherwise-separate parts of the class.",
			highMeans: "A connector — the route into a pocket that is otherwise hard "
				+ "to reach. Not the same people as the bringers.",
			lowMeans: "Not on the paths between groups. Says nothing about how well "
				+ "connected they are within their own group."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.betweenness(graph)
	}
}

/// Closeness — broadcast seeding.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try ClosenessMetric<String>().compute(on: graph)
/// print(scores["b"] ?? 0)   // 1.0
/// ```
public struct ClosenessMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "closeness-centrality", version: 1, title: "Closeness Centrality",
			interpretation: "Who can reach the rest of the class in few steps.",
			highMeans: "A good place to start something that has to spread.",
			lowMeans: "Far from most of the class, or in a small component."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.closeness(graph)
	}
}

/// k-core — the underserved.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try KCoreMetric<String>().compute(on: graph)
/// print(scores["b"] ?? 0)   // 1.0
/// ```
public struct KCoreMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "k-core", version: 1, title: "Core Number",
			interpretation: "How deep in the densely connected part of the class "
				+ "this person sits.",
			highMeans: "Embedded in a group whose members are themselves "
				+ "well connected.",
			lowMeans: "The outreach target. A thin tie in a thin neighbourhood — "
				+ "but read as a call-and-ask list, never as a finding that this "
				+ "person is isolated. The records cannot see a friendship they "
				+ "never recorded."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Community.kCore(graph)
	}
}

/// Louvain communities.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let result = try LouvainMetric<String>().compute(on: graph)
/// print(result.communityCount > 0)   // true
/// ```
public struct LouvainMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "louvain", version: 1, title: "Communities",
			interpretation: "The natural groupings in the class, by modularity.",
			highMeans: "Not a score — an assignment. Every other metric should be "
				+ "reported against these groups rather than the class as a whole.",
			lowMeans: "Not applicable."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodePartition<Node> {
		Community.louvain(graph)
	}
}

/// Harmonic centrality — reach on a graph that is not fully connected.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try HarmonicMetric<String>().compute(on: graph)
/// print(scores.ranked.first?.node ?? "")   // b
/// ```
public struct HarmonicMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "harmonic-centrality", version: 1, title: "Harmonic Centrality",
			interpretation: "Who can reach the most of the class in the fewest steps.",
			highMeans: "A good place to start something that has to spread. More "
				+ "trustworthy than closeness here, because it stays meaningful "
				+ "when part of the class is unreachable — and a hundred "
				+ "classmates are.",
			lowMeans: "Far from most of the class, or in a small pocket of it."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.harmonic(graph)
	}
}

/// Local clustering — whether someone's ties know each other.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let scores = try ClusteringMetric<String>().compute(on: graph)
/// print(scores["b"] ?? 1)   // 0.0
/// ```
public struct ClusteringMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "clustering", version: 1, title: "Clustering Coefficient",
			interpretation: "How much this classmate's connections know each other.",
			highMeans: "A closed circle — everyone they know knows everyone else, "
				+ "so reaching them reaches nobody new.",
			lowMeans: "Their ties come from separate places, which is what a "
				+ "connector looks like from the inside. Read with betweenness: "
				+ "high betweenness and low clustering is a genuine bridge."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodeScores<Node> {
		Centrality.clustering(graph)
	}
}

/// Connected components — who can reach whom at all.
///
/// ```swift
/// import BusinessMath
///
/// let graph = WeightedGraph(unweightedEdges: [("a", "b"), ("b", "c")])
/// let result = try ComponentsMetric<String>().compute(on: graph)
/// print(result.communityCount)   // 1
/// ```
public struct ComponentsMetric<Node: Hashable & Comparable & Sendable & Codable>: GraphMetric {
	/// What this metric answers, and how to read it.
	public static var descriptor: MetricDescriptor {
		MetricDescriptor(
			identifier: "components", version: 1, title: "Connected Components",
			interpretation: "Which parts of the class have any path to each other.",
			highMeans: "Not a score — a partition. One large component and a long "
				+ "tail of ones means the class holds together with individuals "
				+ "hanging off it, which is what this data shows.",
			lowMeans: "Not applicable. A component of one is a classmate with no "
				+ "recorded tie, which is silence in the records rather than "
				+ "isolation."
		)
	}
	/// Creates the metric. Stateless.
	public init() {}
	/// Computes it over the graph.
	public func compute(on graph: WeightedGraph<Node>) throws -> NodePartition<Node> {
		Community.connectedComponents(graph)
	}
}
