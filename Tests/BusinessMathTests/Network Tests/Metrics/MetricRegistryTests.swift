//
//  MetricRegistryTests.swift
//  BusinessMath
//
//  The registry exists so algorithms can change over decades without editing a switch that every
//  call site depends on. Ported from SwiftGraphMetrics (RegistryTests, the registry parts of
//  ReferenceValueTests, ValueTests and DiffusionTests) and extended. Synthetic data only.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

private var karate: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges.map {
		(String($0.0), String($0.1))
	})
}

private var kite: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
}

private let stamp = Date(timeIntervalSince1970: 1_770_000_000)

@Suite("MetricRegistry")
struct MetricRegistryTests {

	@Test("Ships the metrics the design calls for")
	func shipsStandardMetrics() {
		let identifiers = Set(MetricRegistry<String>.standard.available.map(\.identifier))
		for expected in [
			"degree", "eigenvector-centrality", "pagerank",
			"betweenness-centrality", "closeness-centrality", "k-core", "louvain",
			"burt-constraint",
		] {
			#expect(identifiers.contains(expected), "missing \(expected)")
		}
	}

	@Test("Every added measure is in the registry, and there are exactly eleven")
	func registered() {
		let identifiers = Set(MetricRegistry<String>.standard.available.map(\.identifier))
		for expected in ["harmonic-centrality", "clustering", "components"] {
			#expect(identifiers.contains(expected))
		}
		#expect(MetricRegistry<String>.standard.available.count == 11)
	}

	@Test("Runs a metric by identifier")
	func runsByIdentifier() throws {
		let output = try #require(try MetricRegistry<String>.standard.run("degree", on: karate))
		#expect(output.kind == "scores")
		let scores = try #require(try output.value(as: NodeScores<String>.self))
		#expect(scores["34"]?.isEqual(to: 17) == true)
	}

	@Test("Returns nil for an unknown identifier rather than throwing")
	func unknownIdentifier() throws {
		#expect(try MetricRegistry<String>.standard.run("no-such-metric", on: karate) == nil)
		#expect(MetricRegistry<String>.standard.metric(for: "no-such-metric") == nil)
	}

	/// The point of the registry: adding a metric requires no edit anywhere else.
	@Test("A new metric can be added without touching existing code")
	func extensible() throws {
		struct AlwaysSeven: GraphMetric {
			static let descriptor = MetricDescriptor(
				identifier: "always-seven", version: 1, title: "Seven",
				interpretation: "A metric added from outside the package.",
				highMeans: "Seven.", lowMeans: "Also seven."
			)
			func compute(on graph: WeightedGraph<String>) throws -> NodeScores<String> {
				NodeScores(Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, 7.0) }))
			}
		}
		let standard = MetricRegistry<String>.standard
		let extended = standard.registering(AlwaysSeven())
		let output = try #require(try extended.run("always-seven", on: karate))
		let scores = try #require(try output.value(as: NodeScores<String>.self))
		#expect(scores["1"]?.isEqual(to: 7) == true)
		let before: Int = standard.available.count
		#expect(extended.available.count == before + 1)
		// The original registry is a value and is not changed by registering.
		#expect(try standard.run("always-seven", on: karate) == nil)
	}

	@Test("When two metrics share an identifier the first wins, in the initialiser and in registering")
	func firstWins() throws {
		struct Constant: GraphMetric {
			let value: Double
			static let descriptor = MetricDescriptor(
				identifier: "constant", version: 1, title: "Constant",
				interpretation: "A constant.", highMeans: "High.", lowMeans: "Low.")
			func compute(on graph: WeightedGraph<String>) throws -> NodeScores<String> {
				NodeScores(Dictionary(uniqueKeysWithValues: graph.nodes.map { ($0, value) }))
			}
		}
		let graph = WeightedGraph(unweightedEdges: [("a", "b")])
		let first = MetricRegistry<String>([AnyGraphMetric(Constant(value: 1)), AnyGraphMetric(Constant(value: 2))])
		let scores = try #require(try first.run("constant", on: graph)?.value(as: NodeScores<String>.self))
		#expect(scores["a"]?.isEqual(to: 1) == true)
		#expect(first.available.count == 1)
		let later = MetricRegistry<String>([AnyGraphMetric(Constant(value: 1))]).registering(Constant(value: 2))
		let kept = try #require(try later.run("constant", on: graph)?.value(as: NodeScores<String>.self))
		#expect(kept["a"]?.isEqual(to: 1) == true)
		#expect(later.available.count == 1)
	}

	@Test("An empty registry lists nothing and runs nothing")
	func emptyRegistry() throws {
		let empty = MetricRegistry<String>([])
		#expect(empty.available.isEmpty)
		#expect(try empty.run("degree", on: karate) == nil)
	}

	@Test("Every metric states what a low score does and does not mean")
	func descriptorsExplainThemselves() {
		// Reading a low centrality as "isolated" is the failure mode this
		// library is most exposed to, so every metric has to say otherwise.
		for descriptor in MetricRegistry<String>.standard.available {
			#expect(!descriptor.interpretation.isEmpty)
			#expect(!descriptor.highMeans.isEmpty)
			#expect(!descriptor.lowMeans.isEmpty)
			#expect(!descriptor.title.isEmpty)
		}
		let kCore = MetricRegistry<String>.standard.metric(for: "k-core")?.descriptor
		#expect(kCore?.lowMeans.contains("call-and-ask") == true)
	}

	@Test("A metric looked up by identifier carries the descriptor it was registered with")
	func lookupDescriptor() throws {
		for descriptor in MetricRegistry<String>.standard.available {
			let found = try #require(MetricRegistry<String>.standard.metric(for: descriptor.identifier))
			#expect(found.descriptor == descriptor)
		}
	}

	/// Moved metrics keep their versions: the numbers did not change. The exception is
	/// eigenvector centrality, bumped 2 to 3 when the bipartite fix changed its numbers, and 3 to 4
	/// when it began reporting convergence. PageRank was bumped 2 to 3 in step 4 when it began doing the
	/// same (ADR-009).
	@Test("Moved metrics keep the versions they had; eigenvector is at 4 and pagerank at 3")
	func versionsUnchanged() {
		let versions = Dictionary(
			uniqueKeysWithValues: MetricRegistry<String>.standard.available.map {
				($0.identifier, $0.version)
			})
		#expect(versions["eigenvector-centrality"] == 4)
		#expect(versions["pagerank"] == 3)
		for identifier in [
			"degree", "betweenness-centrality", "closeness-centrality", "k-core",
			"louvain", "harmonic-centrality", "clustering", "components", "burt-constraint",
		] {
			#expect(versions[identifier] == 1, "\(identifier)")
		}
	}

	@Test("The registry lists its metrics in identifier order, once each")
	func availableIsSorted() {
		let identifiers = MetricRegistry<String>.standard.available.map(\.identifier)
		#expect(identifiers == identifiers.sorted())
		#expect(identifiers.count == Set(identifiers).count)
		#expect(identifiers.first == "betweenness-centrality")
		#expect(identifiers.last == "pagerank")
	}

	@Test("A partition metric comes back as a partition envelope")
	func partitionKind() throws {
		let output = try #require(try MetricRegistry<String>.standard.run("louvain", on: karate))
		#expect(output.kind == "partition")
		let partition = try #require(try output.value(as: NodePartition<String>.self))
		#expect(partition.communities.count == 34)
		// Asking for the wrong kind is nil, not a decoding error.
		#expect(try output.value(as: NodeScores<String>.self) == nil)
	}

	@Test("Every standard metric's envelope is the value its function returns, wrapped")
	func registryAgreesWithFunctions() throws {
		let graph = karate
		let registry = MetricRegistry<String>.standard
		let pairs: [(String, NodeScores<String>)] = [
			("degree", Centrality.degree(graph)),
			("pagerank", Centrality.pageRank(graph)),
			("betweenness-centrality", Centrality.betweenness(graph)),
			("closeness-centrality", Centrality.closeness(graph)),
			("harmonic-centrality", Centrality.harmonic(graph)),
			("clustering", Centrality.clustering(graph)),
			("k-core", Community.kCore(graph)),
			("burt-constraint", Brokerage.constraint(graph)),
		]
		for (identifier, expected) in pairs {
			let output = try #require(try registry.run(identifier, on: graph))
			#expect(try output.value(as: NodeScores<String>.self) == expected, "\(identifier)")
		}
		let louvain = try #require(try registry.run("louvain", on: graph))
		#expect(try louvain.value(as: NodePartition<String>.self) == Community.louvain(graph))
		let components = try #require(try registry.run("components", on: graph))
		#expect(try components.value(as: NodePartition<String>.self) == Community.connectedComponents(graph))
		let eigenvector = try #require(try registry.run("eigenvector-centrality", on: graph))
		let typed = try #require(try eigenvector.value(as: DiagnosedScores<String>.self))
		#expect(typed.scores == Centrality.eigenvector(graph))
	}

	@Test("A custom value type can travel through the registry")
	func customValue() throws {
		struct Count: MetricValue {
			static let kind = "count"
			let value: Int
		}
		struct Counter: GraphMetric {
			static let descriptor = MetricDescriptor(
				identifier: "counter", version: 1, title: "Counter",
				interpretation: "Counts nodes.", highMeans: "Big.", lowMeans: "Small.")
			func compute(on graph: WeightedGraph<String>) throws -> Count {
				Count(value: graph.nodeCount)
			}
		}
		let registry = MetricRegistry<String>([AnyGraphMetric(Counter())])
		let output = try #require(try registry.run(
			"counter", on: WeightedGraph(unweightedEdges: [("a", "b")])))
		#expect(output.kind == "count")
		#expect(try output.value(as: Count.self)?.value == 2)
	}

	@Test("A metric that throws makes the registry throw, not return nil")
	func throwing() {
		struct Failure: Error {}
		struct Failing: GraphMetric {
			static let descriptor = MetricDescriptor(
				identifier: "failing", version: 1, title: "Failing",
				interpretation: "Always fails.", highMeans: "-", lowMeans: "-")
			func compute(on graph: WeightedGraph<String>) throws -> NodeScores<String> { throw Failure() }
		}
		let registry = MetricRegistry<String>([AnyGraphMetric(Failing())])
		#expect(throws: Failure.self) { try registry.run("failing", on: karate) }
		#expect(throws: Failure.self) {
			try registry.record("failing", on: karate, context: 1, now: stamp)
		}
	}

	@Test("The seed selector registers and round-trips as a selection envelope")
	func seedSelectorRoundTrip() throws {
		let selector = SeedSelector<String>(
			model: try IndependentCascade(probability: 0.3), budget: 3, trials: 50, seed: 1)
		let registry = MetricRegistry<String>.standard.registering(selector)
		let envelope = try #require(try registry.run("seed-selection", on: kite))
		#expect(envelope.kind == "selection")
		let decoded = try #require(try envelope.value(as: NodeSelection<String>.self))
		#expect(decoded.picks.count == 3)
		#expect(decoded == (try selector.compute(on: kite)))
	}

	@Test("The seed selector is deliberately not in the standard registry")
	func seedSelectorNotStandard() {
		#expect(MetricRegistry<String>.standard.metric(for: "seed-selection") == nil)
	}
}

@Suite("MetricRecord provenance")
struct MetricRecordTests {

	private struct Context: Codable, Sendable, Hashable {
		let weighting: String
		let minimumEdgeWeight: Double
	}

	@Test("Records the context and metric version alongside the numbers")
	func recordsProvenance() throws {
		let context = Context(weighting: "newman", minimumEdgeWeight: 0.02)
		let record = try #require(
			try MetricRegistry<String>.standard.record("degree", on: karate, context: context, now: stamp))
		#expect(record.metric == "degree")
		#expect(record.metricVersion == 1)
		#expect(record.context == context)
		#expect(record.output.kind == "scores")
	}

	@Test("A record's output is what run returns for the same graph")
	func outputMatchesRun() throws {
		let registry = MetricRegistry<String>.standard
		for descriptor in registry.available {
			let record = try #require(try registry.record(
				descriptor.identifier, on: karate, context: Context(weighting: "x", minimumEdgeWeight: 0), now: stamp))
			#expect(record.output == (try registry.run(descriptor.identifier, on: karate)))
			#expect(record.metric == descriptor.identifier)
			#expect(record.metricVersion == descriptor.version)
		}
	}

	/// A record stored under version 2 must stay distinguishable from one computed now:
	/// version 2 scores on bipartite graphs are wrong, version 3 supersedes them.
	@Test("An eigenvector record stored under version 2 decodes as 2; a new one carries 4")
	func versionDistinguishesStoredRecords() throws {
		let stored = """
		{"metric":"eigenvector-centrality","metricVersion":2,
		 "context":{"weighting":"old","minimumEdgeWeight":0},
		 "computedAt":0,"output":{"kind":"nodeScores","payload":{}}}
		"""
		let old = try JSONDecoder().decode(MetricRecord<Context>.self, from: Data(stored.utf8))
		#expect(old.metricVersion == 2)
		let fresh = try #require(
			try MetricRegistry<String>.standard.record(
				"eigenvector-centrality", on: karate,
				context: Context(weighting: "x", minimumEdgeWeight: 0), now: stamp))
		#expect(fresh.metricVersion == 4)
		#expect(fresh.metricVersion != old.metricVersion)
	}

	@Test("Round-trips through Codable so a record survives to be compared later")
	func codable() throws {
		let record = try #require(
			try MetricRegistry<String>.standard.record(
				"louvain", on: karate, context: Context(weighting: "x", minimumEdgeWeight: 0), now: stamp))
		let restored = try JSONDecoder().decode(
			MetricRecord<Context>.self, from: try JSONEncoder().encode(record))
		#expect(restored == record)
	}

	@Test("Uses the clock it was given rather than reading the wall clock")
	func injectedClock() throws {
		let record = try #require(
			try MetricRegistry<String>.standard.record(
				"degree", on: karate, context: Context(weighting: "x", minimumEdgeWeight: 0), now: stamp))
		#expect(record.computedAt == stamp)
	}

	@Test("The record initialiser keeps every field it is given")
	func initialiserKeepsFields() {
		let output = MetricEnvelope(kind: "k", payload: .number(1))
		let record = MetricRecord(
			metric: "m", metricVersion: 7, context: Context(weighting: "w", minimumEdgeWeight: 0.5),
			computedAt: Date(timeIntervalSince1970: 42), output: output)
		#expect(record.metric == "m")
		#expect(record.metricVersion == 7)
		#expect(record.context == Context(weighting: "w", minimumEdgeWeight: 0.5))
		#expect(record.computedAt == Date(timeIntervalSince1970: 42))
		#expect(record.output == output)
	}

	@Test("An unknown identifier records nothing")
	func unknown() throws {
		#expect(try MetricRegistry<String>.standard.record(
			"nope", on: karate, context: 1, now: Date(timeIntervalSince1970: 0)) == nil)
	}
}
