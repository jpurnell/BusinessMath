//
//  EigenvectorCentralityBipartiteTests.swift
//  BusinessMath
//
//  Eigenvector centrality on bipartite graphs, where plain power iteration on the
//  adjacency matrix does not converge: the spectrum is symmetric, so -λ ties +λ in
//  modulus and the iterate oscillates between two vectors.
//
//  ## Reference values (derived by hand, not read from the code under test)
//
//  Star with n leaves. Hub h, each leaf l. A v = λ v gives n·l = λ·h and h = λ·l, so
//  λ = √n and h = √n·l. Unit length: h² + n·l² = 1, so l²(n + n) = 1:
//  **l = 1/√(2n), h = 1/√2** whatever n is.
//
//  Path of 3: that star with n = 2: (1/2, 1/√2, 1/2), λ = √2.
//
//  Path of 5: eigenvectors of a path are sin(kπ/(N+1)); the leading one has entries
//  sin(π/6), sin(2π/6), sin(3π/6), ... = (1/2, √3/2, 1, √3/2, 1/2), squared length 3, so
//  the unit vector is that over √3. λ = 2cos(π/6) = √3.
//
//  Cycle of n: every node alike, 1/√n, λ = 2.
//
//  Complete bipartite K(p,q): λ² = pq; a node on the side of size p has q neighbours on
//  the other side. With y on the q-side and x on the p-side, λx = q·y and λy = p·x, so
//  x/y = √(q/p). Unit length: p·x² + q·y² = 1 gives **x = 1/√(2p), y = 1/√(2q)**.
//  K(2,3): x = 1/2, y = 1/√6, λ = √6.
//

import Testing
import Foundation
import Numerics
import TestSupport
@testable import BusinessMath

@Suite("Eigenvector centrality on bipartite graphs")
struct EigenvectorCentralityBipartiteTests {

	// MARK: - Builders

	/// Two-digit zero-padded, so labels sort in numeric order.
	private static func padded(_ value: Int) -> String {
		let text = String(value)
		return String(repeating: "0", count: Swift.max(0, 2 - text.count)) + text
	}

	/// An undirected graph from unordered pairs.
	private static func undirected(_ pairs: [(String, String)]) -> Graph<String> {
		var edges: [(String, String)] = []
		for (from, to) in pairs { edges.append((from, to)); edges.append((to, from)) }
		return Graph(edges: edges)
	}

	private static func path(_ count: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for index in 0..<(count - 1) { pairs.append(("p\(index)", "p\(index + 1)")) }
		return undirected(pairs)
	}

	private static func star(leaves: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for index in 0..<leaves { pairs.append(("hub", "leaf\(index)")) }
		return undirected(pairs)
	}

	private static func cycle(_ count: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for index in 0..<count { pairs.append(("c\(index)", "c\((index + 1) % count)")) }
		return undirected(pairs)
	}

	private static func completeBipartite(_ left: Int, _ right: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for i in 0..<left { for j in 0..<right { pairs.append(("l\(i)", "r\(j)")) } }
		return undirected(pairs)
	}

	/// The largest absolute difference from `wanted`, or infinity when the result is `nil`,
	/// has a different size, or lacks a wanted node.
	private static func deviation(_ got: [String: Double]?, _ wanted: [String: Double]) -> Double {
		guard let got, got.count == wanted.count else { return .infinity }
		var worst: Double = 0
		for (node, value) in wanted {
			guard let actual = got[node] else { return .infinity }
			worst = Swift.max(worst, Swift.abs(actual - value))
		}
		return worst
	}

	// MARK: - Dense reference solver (independent of the production loop)

	/// Cyclic Jacobi eigen-decomposition of a symmetric matrix. Returns the eigenvector of
	/// the largest eigenvalue, sign-fixed positive, unit length, and that eigenvalue.
	static func jacobiLeading(_ matrix: [[Double]]) -> (vector: [Double], value: Double) {
		let n = matrix.count
		var a = matrix
		var v = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
		for i in 0..<n { v[i][i] = 1 }
		for _ in 0..<100 {
			var off: Double = 0
			for i in 0..<n { for j in 0..<n where i != j { off += a[i][j] * a[i][j] } }
			if off < 1e-28 { break }
			for p in 0..<(n - 1) {
				for q in (p + 1)..<n {
					let apq = a[p][q]
					if Swift.abs(apq) < 1e-300 { continue }
					let theta: Double = (a[q][q] - a[p][p]) / (2 * apq)
					let sign: Double = theta >= 0 ? 1 : -1
					let t: Double = sign / (Swift.abs(theta) + (theta * theta + 1).squareRoot())
					let c: Double = 1 / (t * t + 1).squareRoot()
					let s: Double = t * c
					for k in 0..<n {
						let akp = a[k][p], akq = a[k][q]
						a[k][p] = c * akp - s * akq
						a[k][q] = s * akp + c * akq
					}
					for k in 0..<n {
						let apk = a[p][k], aqk = a[q][k]
						a[p][k] = c * apk - s * aqk
						a[q][k] = s * apk + c * aqk
					}
					for k in 0..<n {
						let vkp = v[k][p], vkq = v[k][q]
						v[k][p] = c * vkp - s * vkq
						v[k][q] = s * vkp + c * vkq
					}
				}
			}
		}
		var best = 0
		for i in 1..<n where a[i][i] > a[best][best] { best = i }
		var vector: [Double] = (0..<n).map { v[$0][best] }
		var length: Double = 0
		for x in vector { length += x * x }
		length = length.squareRoot()
		let orientation: Double = vector.reduce(0, +) < 0 ? -1 : 1
		vector = vector.map { orientation * $0 / length }
		return (vector, a[best][best])
	}

	private static func denseAdjacency(_ graph: Graph<String>) -> [[Double]] {
		let index = Dictionary(uniqueKeysWithValues: graph.nodes.enumerated().map { ($1, $0) })
		var m = [[Double]](repeating: [Double](repeating: 0, count: graph.nodes.count),
						   count: graph.nodes.count)
		for node in graph.nodes {
			for target in graph.neighbors(of: node) {
				if let i = index[node], let j = index[target] { m[i][j] = 1 }
			}
		}
		return m
	}

	// MARK: - Closed forms

	@Test("Path of 3 is (1/2, 1/sqrt2, 1/2)")
	func pathOfThree() {
		let root: Double = 1 / 2.0.squareRoot()
		let worst = Self.deviation(Self.path(3).eigenvectorCentrality(),
								   ["p0": 0.5, "p1": root, "p2": 0.5])
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	@Test("Path of 5 is sin(k pi/6) over sqrt3")
	func pathOfFive() {
		let root3: Double = 3.0.squareRoot()
		let worst = Self.deviation(Self.path(5).eigenvectorCentrality(), [
			"p0": 0.5 / root3, "p1": (root3 / 2) / root3, "p2": 1 / root3,
			"p3": (root3 / 2) / root3, "p4": 0.5 / root3,
		])
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	@Test("Path of 4 still right")
	func pathOfFour() {
		// sin(kπ/5), k = 1...4, normalised: the reference is the Jacobi solver.
		let graph = Self.path(4)
		let reference = Self.jacobiLeading(Self.denseAdjacency(graph)).vector
		var wanted: [String: Double] = [:]
		for (i, node) in graph.nodes.enumerated() { wanted[node] = reference[i] }
		let worst = Self.deviation(graph.eigenvectorCentrality(), wanted)
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	@Test("Stars: hub 1/sqrt2, each leaf 1/sqrt(2n)", arguments: [2, 3, 6, 10])
	func stars(leaves: Int) {
		let hub: Double = 1 / 2.0.squareRoot()
		let leaf: Double = 1 / (2.0 * Double(leaves)).squareRoot()
		var wanted: [String: Double] = ["hub": hub]
		for i in 0..<leaves { wanted["leaf\(i)"] = leaf }
		let worst = Self.deviation(Self.star(leaves: leaves).eigenvectorCentrality(), wanted)
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	@Test("Cycles, even and odd, are uniform 1/sqrt(n)", arguments: [3, 4, 5, 6, 7, 8])
	func cycles(count: Int) {
		let each: Double = 1 / Double(count).squareRoot()
		var wanted: [String: Double] = [:]
		for i in 0..<count { wanted["c\(i)"] = each }
		let worst = Self.deviation(Self.cycle(count).eigenvectorCentrality(), wanted)
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	@Test("K(2,3): 2-side 1/2, 3-side 1/sqrt6")
	func completeBipartite23() {
		let small: Double = 0.5
		let large: Double = 1 / 6.0.squareRoot()
		let worst = Self.deviation(Self.completeBipartite(2, 3).eigenvectorCentrality(), [
			"l0": small, "l1": small, "r0": large, "r1": large, "r2": large,
		])
		#expect(worst < 1e-9, "max deviation \(worst)")
	}

	// MARK: - Invariances

	@Test("The answer does not depend on the parity of maxIterations")
	func iterationParity() throws {
		for graph in [Self.path(3), Self.star(leaves: 3), Self.path(5), Self.cycle(6)] {
			let odd = try #require(graph.eigenvectorCentrality(maxIterations: 999))
			let even = try #require(graph.eigenvectorCentrality(maxIterations: 1000))
			for node in graph.nodes {
				let a: Double = odd[node] ?? .nan
				let b: Double = even[node] ?? .nan
				#expect(Swift.abs(a - b) < 1e-9, "\(node): \(a) vs \(b)")
			}
		}
	}

	@Test("Relabelling the nodes permutes the answer and changes nothing else")
	func relabelling() throws {
		let pairs: [(String, String)] = [("a", "b"), ("b", "c"), ("c", "d"), ("b", "e"), ("e", "f")]
		let rename: [String: String] = ["a": "z", "b": "m", "c": "q", "d": "a", "e": "k", "f": "b"]
		let original = Self.undirected(pairs)
		let renamed = Self.undirected(pairs.map { (rename[$0.0] ?? "", rename[$0.1] ?? "") })
		let first = try #require(original.eigenvectorCentrality())
		let second = try #require(renamed.eigenvectorCentrality())
		for (old, new) in rename {
			let a: Double = first[old] ?? .nan
			let b: Double = second[new] ?? .nan
			#expect(Swift.abs(a - b) < 1e-9, "\(old)->\(new): \(a) vs \(b)")
		}
	}

	// MARK: - Existing behaviour that must survive

	@Test("Non-bipartite fixture keeps its values")
	func nonBipartiteFixture() throws {
		let bridged = Self.undirected([("a", "b"), ("a", "c"), ("b", "c"), ("c", "d"),
									   ("d", "e"), ("e", "f"), ("e", "g"), ("f", "g")])
		let wanted: [String: Double] = [
			"a": 0.3348052733, "b": 0.3348052733, "c": 0.4496177297,
			"d": 0.3838092108, "e": 0.4496177297, "f": 0.3348052733, "g": 0.3348052733,
		]
		let worst = Self.deviation(bridged.eigenvectorCentrality(), wanted)
		#expect(worst < 1e-6, "max deviation \(worst)")
	}

	@Test("Nil conditions are kept")
	func nilConditions() {
		#expect(Graph(adjacency: ["a": [], "b": []]).eigenvectorCentrality() == nil)
		let split = Self.undirected([("a", "b"), ("c", "d")])
		#expect(split.eigenvectorCentrality() == nil)
	}

	@Test("Failing to converge within maxIterations is nil, not the last iterate")
	func nonConvergenceIsNil() {
		#expect(Self.star(leaves: 3).eigenvectorCentrality(maxIterations: 1) == nil)
		#expect(Self.path(5).eigenvectorCentrality(maxIterations: 2) == nil)
	}

	@Test("The result is an eigenvector: A v = lambda v")
	func residual() throws {
		for graph in [Self.path(5), Self.star(leaves: 6), Self.cycle(7),
					  Self.completeBipartite(2, 3), Self.path(3)] {
			let v = try #require(graph.eigenvectorCentrality())
			var rayleigh: Double = 0
			for node in graph.nodes {
				for target in graph.neighbors(of: node) {
					rayleigh += (v[node] ?? 0) * (v[target] ?? 0)
				}
			}
			var worst: Double = 0
			for node in graph.nodes {
				var sum: Double = 0
				for target in graph.neighbors(of: node) { sum += v[target] ?? 0 }
				let residual: Double = Swift.abs(sum - rayleigh * (v[node] ?? 0))
				if residual > worst { worst = residual }
			}
			#expect(worst < 1e-8, "residual \(worst) with lambda \(rayleigh)")
		}
	}

	// MARK: - The budget and the tolerance are exact

	/// How many passes a dense shifted power iteration needs before no component moves by
	/// `tolerance`: the contract of `maxIterations`, counted independently of the production loop.
	private static func passesNeeded(_ graph: Graph<String>, tolerance: Double) -> Int? {
		let a = denseAdjacency(graph)
		let n = a.count
		var edges: Double = 0
		for row in a { for x in row { edges += x } }
		let shift: Double = edges / Double(n)
		var v = [Double](repeating: 1 / Double(n).squareRoot(), count: n)
		for pass in 1...2000 {
			var next = [Double](repeating: 0, count: n)
			for i in 0..<n {
				var sum: Double = shift * v[i]
				for j in 0..<n { sum += a[i][j] * v[j] }
				next[i] = sum
			}
			var length: Double = 0
			for x in next { length += x * x }
			length = length.squareRoot()
			var movement: Double = 0
			for i in 0..<n {
				next[i] /= length
				movement = Swift.max(movement, Swift.abs(next[i] - v[i]))
			}
			v = next
			if movement < tolerance { return pass }
		}
		return nil
	}

	@Test("maxIterations is exactly the number of passes allowed",
		  arguments: [3, 5, 6])
	func budgetIsExact(size: Int) throws {
		for graph in [Self.path(size), Self.star(leaves: size), Self.completeBipartite(2, size)] {
			let needed = try #require(Self.passesNeeded(graph, tolerance: 1e-9))
			#expect(needed > 2, "fixture converges too fast to pin the budget")
			let enough = graph.eigenvectorCentrality(tolerance: 1e-9, maxIterations: needed)
			#expect(enough?.count == graph.nodes.count, "\(needed) passes should be enough")
			#expect(graph.eigenvectorCentrality(tolerance: 1e-9, maxIterations: needed - 1) == nil,
					"\(needed - 1) passes should not be enough")
		}
	}

	@Test("The tolerance is a strict bound: a movement of exactly zero does not beat tolerance 0")
	func toleranceIsStrict() {
		// The uniform start is already the eigenvector of a cycle, so every pass moves nothing.
		#expect(Self.cycle(5).eigenvectorCentrality(tolerance: 0) == nil)
		#expect(Self.cycle(5).eigenvectorCentrality(tolerance: 1e-300)?.count == 5)
	}

	// MARK: - Properties against the dense reference

	/// A connected random graph: a random spanning tree plus extra random edges.
	private static func randomConnected(rng: SeededRNG, size: Int, extra: Int) -> Graph<String> {
		var pairs: [(String, String)] = []
		for node in 1..<size {
			let parent = Int(rng.next() * Double(node))
			pairs.append(("n\(Self.padded(parent))", "n\(Self.padded(node))"))
		}
		for _ in 0..<extra {
			let a = Int(rng.next() * Double(size))
			let b = Int(rng.next() * Double(size))
			if a != b {
				pairs.append(("n\(Self.padded(a))", "n\(Self.padded(b))"))
			}
		}
		return undirected(pairs)
	}

	@Test("Random connected graphs (mostly trees, hence bipartite) match the Jacobi reference")
	func randomAgainstJacobi() throws {
		let rng = SeededRNG(seed: 2026)
		var checked = 0
		for trial in 0..<60 {
			let size = 3 + Int(rng.next() * 10)
			let extra = trial % 3 == 0 ? 3 : 0   // a third have cycles, two thirds are trees
			let graph = Self.randomConnected(rng: rng, size: size, extra: extra)
			let reference = Self.jacobiLeading(Self.denseAdjacency(graph)).vector
			let got = try #require(graph.eigenvectorCentrality(), "trial \(trial) returned nil")
			for (i, node) in graph.nodes.enumerated() {
				let actual: Double = got[node] ?? .nan
				#expect(Swift.abs(actual - reference[i]) < 1e-7,
						"trial \(trial) \(node): \(actual) vs \(reference[i])")
			}
			checked += 1
		}
		#expect(checked == 60)
	}
}
