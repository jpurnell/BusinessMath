import Foundation
import SwiftGraphMetrics
import SwiftDeterminism

// Generates GoldenRecordData.swift for the BusinessMath metric-registry step (ADR-006 step 3).
// Every standard metric's full MetricRecord (and the bare envelope) is encoded by SwiftGraphMetrics'
// own registry over a spread of fixtures, with JSONEncoder .sortedKeys and a fixed clock. Scores are
// also rendered as Double bit patterns, so equality is bit for bit and does not rest on the text.

typealias Edge = (String, String, Double)
struct Fixture { let name: String; let edges: [Edge]; let isolated: [String] }

struct GoldenContext: Codable, Sendable, Hashable {
	let fixture: String
	let weighting: String
	let minimumEdgeWeight: Double
}

struct MissingMetric: Error { let identifier: String }

func label(_ prefix: String, _ i: Int) -> String { prefix + (i < 10 ? "0\(i)" : "\(i)") }
func unit(_ pairs: [(String, String)]) -> [Edge] { pairs.map { ($0.0, $0.1, 1.0) } }
func hex(_ value: Double) -> String { String(value.bitPattern, radix: 16) }

var fixtures: [Fixture] = []
fixtures.append(Fixture(name: "path7", edges: unit((0..<6).map { (label("p", $0), label("p", $0 + 1)) }), isolated: []))
fixtures.append(Fixture(name: "path60", edges: unit((0..<59).map { (label("q", $0), label("q", $0 + 1)) }), isolated: []))
fixtures.append(Fixture(name: "star7", edges: unit((1...6).map { ("hub", label("l", $0)) }), isolated: []))
fixtures.append(Fixture(name: "triangle", edges: unit([("a", "b"), ("b", "c"), ("a", "c")]), isolated: []))
fixtures.append(Fixture(name: "evenCycle6", edges: unit((0..<6).map { (label("c", $0), label("c", ($0 + 1) % 6)) }), isolated: []))
fixtures.append(Fixture(name: "oddCycle5", edges: unit((0..<5).map { (label("o", $0), label("o", ($0 + 1) % 5)) }), isolated: []))
fixtures.append(Fixture(name: "k23", edges: unit([("a1", "b1"), ("a1", "b2"), ("a1", "b3"), ("a2", "b1"), ("a2", "b2"), ("a2", "b3")]), isolated: []))
let kite: [(String, String)] = [
	("Andre", "Beverly"), ("Andre", "Carol"), ("Andre", "Diane"), ("Andre", "Fernando"),
	("Beverly", "Diane"), ("Beverly", "Ed"), ("Beverly", "Garth"),
	("Carol", "Diane"), ("Carol", "Fernando"),
	("Diane", "Ed"), ("Diane", "Fernando"), ("Diane", "Garth"),
	("Ed", "Garth"), ("Fernando", "Garth"), ("Fernando", "Heather"),
	("Garth", "Heather"), ("Heather", "Ike"), ("Ike", "Jane"),
]
fixtures.append(Fixture(name: "kite", edges: unit(kite), isolated: []))
fixtures.append(Fixture(name: "karate", edges: unit(ReferenceGraphs.karateEdges.map { (label("k", $0.0), label("k", $0.1)) }), isolated: []))
let w12: [Edge] = [
	("n01", "n02", 3.0), ("n01", "n03", 2.5), ("n02", "n03", 4.0), ("n03", "n04", 1.0),
	("n04", "n05", 5.0), ("n04", "n06", 0.5), ("n05", "n06", 2.0), ("n06", "n07", 0.25),
	("n07", "n08", 3.5), ("n07", "n09", 1.5), ("n08", "n09", 2.0), ("n09", "n10", 4.5),
	("n10", "n11", 1.0), ("n10", "n12", 2.5), ("n11", "n12", 3.0), ("n01", "n12", 0.125),
]
fixtures.append(Fixture(name: "weighted12", edges: w12, isolated: []))
fixtures.append(Fixture(name: "twoComponents", edges: unit([("a", "b"), ("b", "c"), ("a", "c"), ("x", "y"), ("y", "z")]), isolated: []))
fixtures.append(Fixture(name: "isolates", edges: unit([("a", "b"), ("b", "c")]), isolated: ["x", "y", "z"]))
fixtures.append(Fixture(name: "edgeless4", edges: [], isolated: ["a", "b", "c", "d"]))
fixtures.append(Fixture(name: "single", edges: [], isolated: ["only"]))
fixtures.append(Fixture(name: "empty", edges: [], isolated: []))
fixtures.append(Fixture(name: "zeroWeights", edges: [("a", "b", 1.0), ("a", "c", 0.0), ("b", "c", 1.0), ("c", "d", 2.0), ("d", "e", 0.0)], isolated: []))
for (seed, count, edgeCount, isolatedCount) in [(1, 15, 30, 0), (2, 22, 40, 2), (3, 25, 60, 3), (4, 18, 20, 1)] as [(UInt64, Int, Int, Int)] {
	var rng = SplitMix64(seed: seed)
	var edges: [Edge] = []
	for _ in 0..<edgeCount {
		let a = Int.random(in: 0..<count, using: &rng)
		let b = Int.random(in: 0..<count, using: &rng)
		let weight = Double(Int.random(in: 1...16, using: &rng)) * 0.25
		edges.append((label("v", a), label("v", b), weight))
	}
	fixtures.append(Fixture(name: "random\(seed)", edges: edges, isolated: (0..<isolatedCount).map { label("iso", $0) }))
}

let clock = Date(timeIntervalSince1970: 1_770_000_000)
let encoder = JSONEncoder()
encoder.outputFormatting = [.sortedKeys]
func json<T: Encodable>(_ value: T) throws -> String { String(decoding: try encoder.encode(value), as: UTF8.self) }
func lit(_ text: String) -> String {
	"#\"" + text + "\"#"
}

func scoreTokens<N: Hashable & Comparable>(_ s: NodeScores<N>, _ nodes: [N]) -> String {
	nodes.map { s.scores[$0].map(hex) ?? "-" }.joined(separator: " ")
}
func partTokens<N: Hashable & Comparable>(_ p: NodePartition<N>, _ nodes: [N]) -> String {
	nodes.map { p.communities[$0].map(String.init) ?? "-" }.joined(separator: " ")
}
/// Bit-pattern rendering of whatever the envelope holds, by kind.
func tokens<N: Hashable & Comparable & Sendable & Codable>(_ envelope: MetricEnvelope, _ nodes: [N], diagnosed wantsDiagnosis: Bool) throws -> String {
	if !wantsDiagnosis, let plain = try envelope.value(as: NodeScores<N>.self) { return scoreTokens(plain, nodes) }
	if let diagnosed = try envelope.value(as: DiagnosedScores<N>.self) {
		var text = scoreTokens(diagnosed.scores, nodes)
		if let c = diagnosed.convergence {
			text += " | \(c.iterations) \(c.converged ? 1 : 0) \(hex(c.residual)) \(hex(c.tolerance)) \(c.maxIterations)"
		} else { text += " | unknown" }
		return text
	}
	if let partition = try envelope.value(as: NodePartition<N>.self) { return partTokens(partition, nodes) }
	return "?"
}

struct Out { var text = ""; mutating func add(_ s: String) { text += s } }
var out = Out()
out.add("//\n//  GoldenRecordData.swift\n//  BusinessMath\n//\n")
out.add("//  GENERATED by project/summaries/2026-11-13_network_metric_registry/golden/main.swift, a scratch\n")
out.add("//  program outside both repositories that depends on SwiftGraphMetrics (commit 0aa9c80) by path and\n")
out.add("//  encodes every standard metric's full MetricRecord with SGM's own registry, JSONEncoder .sortedKeys,\n")
out.add("//  the clock 1_770_000_000 and the context below. Scores are also given as Double bit patterns in hex,\n")
out.add("//  one token per node in sorted node order, so equality is bit for bit. If a test against this file\n")
out.add("//  fails, a stored metric record has changed meaning: fix the code, never the constant.\n//\n\n")
out.add("struct GoldenRecordCase: Sendable {\n\tlet name: String\n\tlet edges: [(String, String, Double)]\n\tlet isolated: [String]\n\t/// (identifier, encoded MetricRecord, encoded bare envelope, bit-pattern tokens)\n\tlet records: [(String, String, String, String)]\n}\n\n")
out.add("enum GoldenRecordData {\n")

let registry = MetricRegistry<String>.standard
out.add("\t/// `MetricRegistry.standard.available` encoded as a JSON array.\n")
out.add("\tstatic let registryListing = \(lit(try json(registry.available)))\n\n")
out.add("\t/// (identifier, version) in listing order.\n\tstatic let identifiersAndVersions: [(String, Int)] = [\n")
for d in registry.available { out.add("\t\t(\"\(d.identifier)\", \(d.version)),\n") }
out.add("\t]\n\n")

out.add("\tstatic let cases: [GoldenRecordCase] = [\n")
for f in fixtures {
	let graph = try WeightedGraph(edges: f.edges, isolatedNodes: f.isolated)
	let context = GoldenContext(fixture: f.name, weighting: "golden", minimumEdgeWeight: 0.02)
	func literalEdges() -> String { f.edges.map { "(\"\($0.0)\", \"\($0.1)\", \($0.2))" }.joined(separator: ", ") }
	out.add("\t\tGoldenRecordCase(\n\t\t\tname: \"\(f.name)\",\n\t\t\tedges: [\(literalEdges())],\n\t\t\tisolated: [\(f.isolated.map { "\"\($0)\"" }.joined(separator: ", "))],\n\t\t\trecords: [\n")
	for d in registry.available {
		guard let record = try registry.record(d.identifier, on: graph, context: context, now: clock),
			let bare = try registry.run(d.identifier, on: graph) else { throw MissingMetric(identifier: d.identifier) }
		let bits = try tokens(bare, graph.nodes, diagnosed: d.identifier == "eigenvector-centrality")
		out.add("\t\t\t\t(\"\(d.identifier)\",\n\t\t\t\t \(lit(try json(record))),\n\t\t\t\t \(lit(try json(bare))),\n\t\t\t\t \"\(bits)\"),\n")
	}
	out.add("\t\t\t]),\n")
}
out.add("\t]\n\n")

// Non-default eigenvector settings, as the bare envelope (not registered, so no record).
out.add("\t/// Eigenvector envelopes at non-default settings: (fixture, maxIterations, tolerance, envelope).\n")
out.add("\tstatic let eigenvectorSettings: [(String, Int, Double, String, String)] = [\n")
for f in fixtures where ["path60", "karate", "random3", "single", "empty"].contains(f.name) {
	let graph = try WeightedGraph(edges: f.edges, isolatedNodes: f.isolated)
	for (ceiling, tol) in [(5, 1e-10), (0, 1e-3), (200, 1e-3), (1_000_000, 1e-10)] as [(Int, Double)] {
		let env = try MetricEnvelope(EigenvectorMetric<String>(maxIterations: ceiling, tolerance: tol).compute(on: graph))
		out.add("\t\t(\"\(f.name)\", \(ceiling), \(tol), \(lit(try json(env))), \"\(try tokens(env, graph.nodes, diagnosed: true))\"),\n")
	}
}
out.add("\t]\n\n")

// Integer nodes: karate through MetricRegistry<Int>. Integer-keyed dictionaries have no defined
// key order under .sortedKeys, so this set is compared decoded, with bit-pattern tokens, not as text.
let intGraph = WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
let intRegistry = MetricRegistry<Int>.standard
out.add("\t/// Karate club on Int nodes: (identifier, bit-pattern tokens). Compared decoded: the encoded\n\t/// text of an Int-keyed dictionary has no defined key order.\n")
out.add("\tstatic let karateIntTokens: [(String, String)] = [\n")
for d in intRegistry.available {
	guard let env = try intRegistry.run(d.identifier, on: intGraph) else { throw MissingMetric(identifier: d.identifier) }
	out.add("\t\t(\"\(d.identifier)\", \"\(try tokens(env, intGraph.nodes, diagnosed: d.identifier == "eigenvector-centrality"))\"),\n")
}
out.add("\t]\n}\n")
try out.text.write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
print("fixtures", fixtures.count, "bytes", out.text.utf8.count)
