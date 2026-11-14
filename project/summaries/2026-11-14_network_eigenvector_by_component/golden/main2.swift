import Foundation
import BusinessMath
import TestSupport
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


// Registry with ClassGraph's component-wise metric registered beside the standard ones (the original Network at ae06466f).
let registry = MetricRegistry<String>.standard.registering(ComponentwiseEigenvectorMetric<String>())
let id = "eigenvector-centrality-by-component"
guard let descriptor = registry.available.first(where: { $0.identifier == id }) else { throw MissingMetric(identifier: id) }
print("LISTING\t" + (try json(descriptor)))
for f in fixtures {
	let graph = try WeightedGraph(edges: f.edges, isolatedNodes: f.isolated)
	let context = GoldenContext(fixture: f.name, weighting: "golden", minimumEdgeWeight: 0.02)
	guard let record = try registry.record(id, on: graph, context: context, now: clock),
		let bare = try registry.run(id, on: graph) else { throw MissingMetric(identifier: id) }
	let bits = try tokens(bare, graph.nodes, diagnosed: false)
	print("CASE\t\(f.name)\t" + "\t\t\t\t(\"\(id)\",\n\t\t\t\t \(lit(try json(record))),\n\t\t\t\t \(lit(try json(bare))),\n\t\t\t\t \"\(bits)\"),".replacingOccurrences(of: "\n", with: "<NL>"))
}
let intGraph = WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges)
let intRegistry = MetricRegistry<Int>.standard.registering(ComponentwiseEigenvectorMetric<Int>())
guard let env = try intRegistry.run(id, on: intGraph) else { throw MissingMetric(identifier: id) }
print("INT\t" + (try tokens(env, intGraph.nodes, diagnosed: false)))
