//
//  EigenvectorByComponentTests.swift
//  BusinessMath
//
//  Component-wise eigenvector centrality (ADR-010), ported from ClassGraph's ADR-015 suite. Expected
//  values are derived by hand from the closed forms of small graphs, not from the code under test:
//  the leading eigenvector of a path a-b-c is (1, sqrt 2, 1) / 2 and of a three-leaf star is
//  (sqrt 3, 1, 1, 1) / sqrt 6, so with the largest score 1 they are (0.7071, 1, 0.7071) and
//  (1, 0.5774, 0.5774, 0.5774). Floating-point claims use TestSupport's named comparisons; the
//  expressions inside #expect are kept short for the Swift 6.2.1 type checker.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport
@testable import BusinessMath

private let loose = 1e-8

private func graph(
	_ edges: [(String, String, Double)], isolated: [String] = []
) throws -> WeightedGraph<String> {
	try WeightedGraph(edges: edges, isolatedNodes: isolated)
}

private func close(_ value: Double?, _ expected: Double, _ epsilon: Double = loose) -> Bool {
	guard let value else { return false }
	return approximatelyEqual(value, expected, tolerance: epsilon)
}

/// Whether the node's score is bit for bit `expected`.
private func isExactly(_ value: Double?, _ expected: Double) -> Bool {
	guard let value else { return false }
	return identical(value, expected)
}

/// Whether two score tables hold the same nodes with the same bit patterns.
private func sameBits<Node: Hashable & Comparable & Sendable>(_ left: NodeScores<Node>, _ right: NodeScores<Node>) -> Bool {
	guard Set(left.scores.keys) == Set(right.scores.keys) else { return false }
	for (node, value) in left.scores {
		guard let other = right.scores[node], identical(value, other) else { return false }
	}
	return true
}

private func inUnitRange(_ value: Double) -> Bool { value >= 0 && value <= 1 }

private func isWellFormed<Node>(_ component: ComponentScoring<Node>) -> Bool {
	component.size >= 2 && component.scale > 0 && component.scale <= 1
}

/// The `index`th component's scale, or a failure (not a crash) if the result has fewer components.
private func scale<Node>(_ result: ComponentwiseScores<Node>, _ index: Int) throws -> Double {
	try #require(result.components.indices.contains(index) ? result.components[index].scale : nil)
}

/// A node name for a long path: zero-padded, so the names sort in path order.
private func pathName(_ index: Int) -> String {
	index < 10 ? "p0\(index)" : "p\(index)"
}

/// a-b-c, the pair d-e, and the isolate z.
private func pathPairIsolate() throws -> WeightedGraph<String> {
	try graph([("a", "b", 1), ("b", "c", 1), ("d", "e", 1)], isolated: ["z"])
}

/// a-b-c and the three-leaf star h-l1, h-l2, h-l3.
private func pathAndStar() throws -> WeightedGraph<String> {
	try graph([
		("a", "b", 1), ("b", "c", 1),
		("h", "l1", 1), ("h", "l2", 1), ("h", "l3", 1),
	])
}

/// A path of 30 (which does not converge in 200 passes) and a pair (which does).
private func longPathAndPair() throws -> WeightedGraph<String> {
	var edges: [(String, String, Double)] = (0..<29).map { (pathName($0), pathName($0 + 1), 1) }
	edges.append(("q0", "q1", 1))
	return try graph(edges)
}

@Suite("Eigenvector by component: values")
struct EigenvectorByComponentValueTests {

	@Test("two identical paths score like the path alone, both components at the same scale")
	func twoPaths() throws {
		let result = try Centrality.eigenvectorByComponent(graph([
			("a", "b", 1), ("b", "c", 1), ("d", "e", 1), ("e", "f", 1),
		]))
		let endScore: Double = 0.5.squareRoot()
		for middle in ["b", "e"] { #expect(close(result.scores[middle], 1), "\(middle)") }
		for end in ["a", "c", "d", "f"] { #expect(close(result.scores[end], endScore), "\(end)") }
		let scales: [Double] = result.components.map(\.scale)
		#expect(scales.count == 2)
		#expect(scales.allSatisfy { close($0, 1) })
	}

	@Test("a path, a pair and an isolate: the pair is scaled by min(rms)/rms, the isolate scores 0")
	func pathPairIsolateValues() throws {
		// rms(path) = sqrt((0.5 + 1 + 0.5) / 3) = sqrt(2/3); rms(pair) = 1; the path is more peaked so it
		// keeps its scale and the pair is multiplied by sqrt(2/3).
		let result = try Centrality.eigenvectorByComponent(pathPairIsolate())
		let flatter: Double = (2.0 / 3.0).squareRoot()
		let endScore: Double = 0.5.squareRoot()
		#expect(close(result.scores["b"], 1))
		#expect(close(result.scores["a"], endScore))
		#expect(close(result.scores["c"], endScore))
		#expect(close(result.scores["d"], flatter))
		#expect(close(result.scores["e"], flatter))
		#expect(isExactly(result.scores["z"], 0))
		#expect(result.isolatedCount == 1)
		#expect(result.components.map(\.anchor) == ["a", "d"])
		#expect(result.components.map(\.size) == [3, 2])
		#expect(close(try scale(result, 0), 1))
		#expect(close(try scale(result, 1), flatter))
	}

	@Test("a path and a star: the star, with the smaller rms, keeps its scale; the path is scaled by sqrt(3)/2")
	func pathAndStarValues() throws {
		// rms(star) = sqrt((1 + 3 * (1/3)) / 4) = sqrt(1/2) < rms(path) = sqrt(2/3); the factor for the path
		// is sqrt(1/2) / sqrt(2/3) = sqrt(3) / 2.
		let result = try Centrality.eigenvectorByComponent(pathAndStar())
		let root3: Double = 3.0.squareRoot()
		let factor: Double = root3 / 2
		let endScore: Double = 0.5.squareRoot() * factor
		#expect(close(result.scores["h"], 1))
		let leafScore: Double = 1 / root3
		for leaf in ["l1", "l2", "l3"] { #expect(close(result.scores[leaf], leafScore)) }
		#expect(close(result.scores["b"], factor))
		#expect(close(result.scores["a"], endScore))
		#expect(close(try scale(result, 0), factor))
		#expect(close(try scale(result, 1), 1))
	}

	@Test("the largest score is exactly 1 and none is below 0 or above 1")
	func rangeAndPeak() throws {
		for built in [try pathPairIsolate(), try pathAndStar()] {
			let values = try Centrality.eigenvectorByComponent(built).scores.scores.values
			let peak = try #require(values.max())
			#expect(identical(peak, 1))
			#expect(values.allSatisfy(inUnitRange))
		}
	}

	@Test("dividing by the stored scale recovers the per-component scale, whose largest is 1")
	func scaleIsRecoverable() throws {
		let result = try Centrality.eigenvectorByComponent(pathAndStar())
		let members: [[String]] = [["a", "b", "c"], ["h", "l1", "l2", "l3"]]
		#expect(result.components.count == 2)
		for (component, names) in zip(result.components, members) {
			let recovered = names.compactMap { result.scores[$0] }.map { $0 / component.scale }
			#expect(close(recovered.max(), 1))
		}
	}

	@Test("within a component the scores are the per-component eigenvector's, up to one factor")
	func withinComponentRatios() throws {
		let result = try Centrality.eigenvectorByComponent(pathAndStar())
		let pathAlone = try Centrality.eigenvector(graph([("a", "b", 1), ("b", "c", 1)]))
		let starAlone = try Centrality.eigenvector(
			graph([("h", "l1", 1), ("h", "l2", 1), ("h", "l3", 1)]))
		let pathScale = try scale(result, 0)
		let starScale = try scale(result, 1)
		for name in ["a", "b", "c"] {
			let expected = try #require(pathAlone[name])
			let recovered: Double? = result.scores[name].map { $0 / pathScale }
			#expect(close(recovered, expected), "\(name)")
		}
		for name in ["h", "l1", "l2", "l3"] {
			let expected = try #require(starAlone[name])
			let recovered: Double? = result.scores[name].map { $0 / starScale }
			#expect(close(recovered, expected), "\(name)")
		}
	}

	@Test("multiplying every weight by a constant changes nothing")
	func weightScaleInvariance() throws {
		let base: [(String, String, Double)] = [
			("a", "b", 0.5), ("b", "c", 0.37), ("a", "c", 0.2), ("d", "e", 2), ("e", "f", 1), ("g", "h", 1),
		]
		let plain = try Centrality.eigenvectorByComponent(graph(base, isolated: ["z"]))
		let scaled = try Centrality.eigenvectorByComponent(
			graph(base.map { ($0.0, $0.1, $0.2 * 7.3) }, isolated: ["z"]))
		#expect(close(plain.scores["a"], 0.9, 0.1))   // not the all-zero answer
		for (node, value) in plain.scores.scores {
			#expect(close(scaled.scores[node], value), "\(node)")
		}
	}

	@Test("renaming the nodes, which reorders them, changes no score")
	func relabelInvariance() throws {
		let edges: [(String, String, Double)] = [
			("a", "b", 1), ("b", "c", 2), ("c", "a", 1), ("c", "d", 1), ("x", "y", 3), ("y", "w", 1),
		]
		let plain = try Centrality.eigenvectorByComponent(graph(edges, isolated: ["q"]))
		let prefix = "zyxwvutsrq"
		let renamed = try Centrality.eigenvectorByComponent(
			graph(edges.map { (prefix + $0.0, prefix + $0.1, $0.2) }, isolated: [prefix + "q"]))
		let central = try #require(plain.scores["c"])
		#expect(central > 0.5)   // not the all-zero answer
		for (node, value) in plain.scores.scores {
			let renamedScore: Double? = renamed.scores[prefix + node]
			#expect(close(renamedScore, value), "\(node)")
		}
	}

	@Test("random graphs with several components keep the invariants")
	func randomGraphs() throws {
		var generator = DeterministicGenerator(seed: 2000)
		for round in 0..<60 {
			let count = generator.nextInt(in: 6..<37)
			var edges: [(String, String, Double)] = []
			for first in 0..<count {
				for second in (first + 1)..<count where generator.nextDouble(in: 0.0..<1.0) < 0.09 {
					edges.append(("n\(first)", "n\(second)", generator.nextDouble(in: 0.01...3.0)))
				}
			}
			let named = (0..<count).map { "n\($0)" }
			let built = try graph(edges, isolated: named)
			let result = try Centrality.eigenvectorByComponent(built)
			let values = result.scores.scores.values
			#expect(result.scores.scores.count == count, "round \(round)")
			#expect(values.allSatisfy(inUnitRange), "round \(round)")
			let withTies = Set(edges.flatMap { [$0.0, $0.1] })
			for name in named where !withTies.contains(name) {
				#expect(isExactly(result.scores[name], 0), "round \(round) \(name)")
			}
			let expectedIsolated: Int = count - withTies.count
			#expect(result.isolatedCount == expectedIsolated, "round \(round)")
			if !withTies.isEmpty {
				let peak = try #require(values.max())
				#expect(identical(peak, 1), "round \(round)")
			}
			#expect(result.components.allSatisfy(isWellFormed))
			let sizeTotal: Int = result.components.map(\.size).reduce(0, +)
			#expect(sizeTotal == withTies.count, "round \(round)")
			let anchors: [String] = result.components.map(\.anchor)
			#expect(anchors == anchors.sorted())
		}
	}
}

@Suite("Eigenvector by component: agreement with eigenvector when there is one component")
struct EigenvectorByComponentOneComponentTests {

	static let connected = ByComponentParityCases.all.filter {
		["karate", "kite", "path5", "star7", "weighted-bridge", "weighted-lollipop"].contains($0.name)
	}.map(\.name)

	@Test("a connected graph with no isolates scores bit for bit as eigenvector-centrality 5 does", arguments: connected)
	func connectedIsIdentical(name: String) throws {
		let source = try #require(ByComponentParityCases.all.first { $0.name == name })
		let built = try graph(source.edges, isolated: source.isolated)
		let result = try Centrality.eigenvectorByComponent(built)
		let direct = try Centrality.eigenvectorConvergence(built)
		#expect(sameBits(result.scores, direct.scores))
		#expect(result.convergence.iterations == direct.iterations)
		#expect(result.convergence.converged == direct.converged)
		#expect(identical(result.convergence.residual, direct.residual))
		#expect(result.components.count == 1)
		#expect(identical(try scale(result, 0), 1))
		#expect(result.isolatedCount == 0)
		#expect(result.components.first?.anchor == built.nodes.first)   // the lowest node names the component
		#expect(result.components.first?.size == built.nodeCount)
	}

	@Test("a connected graph reports the tolerance and ceiling it was given, a ceiling below one as one")
	func connectedSettings() throws {
		let source = try #require(ByComponentParityCases.all.first { $0.name == "kite" })
		let result = try Centrality.eigenvectorByComponent(graph(source.edges), maxIterations: 0, tolerance: 1e-6)
		#expect(exactlyEqual(result.convergence.tolerance, 1e-6))
		#expect(result.convergence.maxIterations == 1)
		#expect(result.components.first?.convergence == result.convergence)
		#expect(result.convergence.iterations == 1)
		#expect(!result.convergence.converged)
	}

	@Test("the same graph with an isolate added still scores its connected part the same, up to rounding")
	func isolateDoesNotMoveTheRest() throws {
		let source = try #require(ByComponentParityCases.all.first { $0.name == "kite" })
		let plain = try Centrality.eigenvectorByComponent(graph(source.edges))
		let withIsolate = try Centrality.eigenvectorByComponent(graph(source.edges, isolated: ["nobody"]))
		for (node, value) in plain.scores.scores { #expect(close(withIsolate.scores[node], value), "\(node)") }
		#expect(isExactly(withIsolate.scores["nobody"], 0))
		#expect(withIsolate.isolatedCount == 1)
	}

	@Test("eigenvector still refuses the graphs this one answers")
	func eigenvectorStillRefuses() throws {
		let built = try pathPairIsolate()
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 3)) {
			_ = try Centrality.eigenvector(built)
		}
		#expect(throws: Never.self) { _ = try Centrality.eigenvectorByComponent(built) }
	}
}

@Suite("Eigenvector by component: nodes with no ties, and trivial graphs")
struct EigenvectorByComponentTrivialTests {

	@Test("the empty graph is empty, trivially converged")
	func empty() throws {
		let result = try Centrality.eigenvectorByComponent(graph([]))
		#expect(result.scores.scores.isEmpty)
		#expect(result.components.isEmpty)
		#expect(result.isolatedCount == 0)
		let expected = ConvergenceReport(iterations: 0, converged: true, residual: 0, tolerance: 1e-10, maxIterations: 200)
		#expect(result.convergence == expected)
	}

	@Test("a lone node scores 0, not the 1 that eigenvector-centrality 5 gives a one-node graph")
	func lone() throws {
		let single = try graph([], isolated: ["solo"])
		let result = try Centrality.eigenvectorByComponent(single)
		#expect(isExactly(result.scores["solo"], 0))
		#expect(result.isolatedCount == 1)
		#expect(result.components.isEmpty)
		#expect(result.convergence.iterations == 0)
		#expect(result.convergence.converged)
		#expect(isExactly(try Centrality.eigenvector(single)["solo"], 1))
	}

	@Test("a graph with nothing to iterate still reports the tolerance and ceiling it was given")
	func trivialSettings() throws {
		let result = try Centrality.eigenvectorByComponent(graph([], isolated: ["x"]), maxIterations: 0, tolerance: 1e-6)
		let expected = ConvergenceReport(iterations: 0, converged: true, residual: 0, tolerance: 1e-6, maxIterations: 1)
		#expect(result.convergence == expected)
	}

	@Test("an edge-less graph is all zeros, not all ones")
	func edgeless() throws {
		let result = try Centrality.eigenvectorByComponent(graph([], isolated: ["x", "y", "z"]))
		#expect(result.scores.scores.count == 3)
		for name in ["x", "y", "z"] { #expect(isExactly(result.scores[name], 0), "\(name)") }
		#expect(result.isolatedCount == 3)
	}

	@Test("a tie of weight zero does not connect: its ends are scored as the ties of positive weight say")
	func zeroWeightTie() throws {
		let result = try Centrality.eigenvectorByComponent(graph([("a", "b", 1), ("b", "c", 0)]))
		#expect(close(result.scores["a"], 1))
		#expect(close(result.scores["b"], 1))
		#expect(isExactly(result.scores["c"], 0))
		#expect(result.isolatedCount == 1)
		#expect(result.components.map(\.size) == [2])
	}

	@Test("a graph whose only ties have weight zero has nothing to iterate")
	func onlyZeroWeights() throws {
		let result = try Centrality.eigenvectorByComponent(graph([("a", "b", 0)]))
		#expect(isExactly(result.scores["a"], 0))
		#expect(isExactly(result.scores["b"], 0))
		#expect(result.scores.scores.count == 2)
		#expect(result.isolatedCount == 2)
		#expect(result.convergence.iterations == 0)
	}

	@Test("every isolate counts, every one scores zero, beside a scored component")
	func isolatesBesideComponent() throws {
		let result = try Centrality.eigenvectorByComponent(
			graph([("a", "b", 1), ("b", "c", 1)], isolated: ["i1", "i2", "i3"]))
		#expect(result.isolatedCount == 3)
		for name in ["i1", "i2", "i3"] { #expect(isExactly(result.scores[name], 0)) }
		#expect(result.components.count == 1)
		#expect(identical(try scale(result, 0), 1))
	}

	@Test("a tie of positive weight between two isolates makes a component, not two isolates")
	func pairIsNotIsolated() throws {
		let result = try Centrality.eigenvectorByComponent(graph([("a", "b", 1)], isolated: ["z"]))
		#expect(result.isolatedCount == 1)
		#expect(result.components.map(\.size) == [2])
		#expect(close(result.scores["a"], 1))
	}
}

@Suite("Eigenvector by component: convergence across components")
struct EigenvectorByComponentConvergenceTests {

	@Test("with a low ceiling the aggregate is the worst case and the detail names the slow component")
	func worstCase() throws {
		let result = try Centrality.eigenvectorByComponent(longPathAndPair(), maxIterations: 3)
		let path = try #require(result.components.first { $0.anchor == "p00" })
		let pair = try #require(result.components.first { $0.anchor == "q0" })
		#expect(!path.convergence.converged)
		#expect(pair.convergence.converged)
		#expect(!result.convergence.converged)
		#expect(result.convergence.iterations == 3)
		#expect(identical(result.convergence.residual, path.convergence.residual))
		#expect(result.convergence.residual > 1e-10)
		#expect(result.unconverged.map(\.anchor) == ["p00"])
		#expect(result.convergence.maxIterations == 3)
		#expect(exactlyEqual(result.convergence.tolerance, 1e-10))
	}

	@Test("with the default ceiling every component converges and so does the aggregate")
	func allConverge() throws {
		var edges: [(String, String, Double)] = (0..<7).map { ("p\($0)", "p\($0 + 1)", 1) }
		edges.append(("q0", "q1", 1))
		let result = try Centrality.eigenvectorByComponent(graph(edges))
		#expect(result.components.allSatisfy { $0.convergence.converged })
		#expect(result.convergence.converged)
		#expect(result.unconverged.isEmpty)
		let passes: [Int] = result.components.map(\.convergence.iterations)
		let residuals: [Double] = result.components.map(\.convergence.residual)
		#expect(result.convergence.iterations == passes.max())
		let worstResidual = try #require(residuals.max())
		#expect(identical(result.convergence.residual, worstResidual))
	}

	@Test("a long path alone misses the default ceiling, and its component says so")
	func defaultCeilingMiss() throws {
		let result = try Centrality.eigenvectorByComponent(longPathAndPair())
		#expect(!result.convergence.converged)
		#expect(result.convergence.iterations == 200)
		#expect(result.unconverged.count == 1)
	}

	@Test("the aggregate is the maximum, not the first or last component, of passes and residual")
	func aggregateIsMaximum() throws {
		// Two components that stop at different passes: the pair converges almost at once, the path needs more.
		let result = try Centrality.eigenvectorByComponent(graph([
			("a", "b", 1), ("c", "d", 1), ("d", "e", 1), ("e", "f", 1), ("f", "g", 1),
		]))
		let passes: [Int] = result.components.map(\.convergence.iterations)
		#expect(passes.count == 2)
		#expect(Set(passes).count == 2)
		#expect(result.convergence.iterations == passes.max())
		let residuals: [Double] = result.components.map(\.convergence.residual)
		let worstResidual = try #require(residuals.max())
		#expect(identical(result.convergence.residual, worstResidual))
	}

	@Test("the configured tolerance and ceiling are reported, a ceiling below one as one")
	func settingsReported() throws {
		let result = try Centrality.eigenvectorByComponent(pathPairIsolate(), maxIterations: 0, tolerance: 1e-6)
		#expect(exactlyEqual(result.convergence.tolerance, 1e-6))
		#expect(result.convergence.maxIterations == 1)
		#expect(result.components.count == 2)
		#expect(result.components.allSatisfy { exactlyEqual($0.convergence.tolerance, 1e-6) })
		#expect(result.components.allSatisfy { $0.convergence.maxIterations == 1 })
	}

	@Test("running it twice gives the same answer")
	func deterministic() throws {
		let built = try pathAndStar()
		let first = try Centrality.eigenvectorByComponent(built)
		let second = try Centrality.eigenvectorByComponent(built)
		#expect(sameBits(first.scores, second.scores))
		#expect(first.convergence == second.convergence)
		#expect(first.components == second.components)
		let hub = try #require(first.scores["h"])
		#expect(hub > 0.5)   // not the all-zero answer
	}
}

@Suite("Eigenvector by component: the settings and the worst case reach every iteration")
struct EigenvectorByComponentSettingsTests {

	@Test("a looser tolerance stops the whole-graph iteration earlier, exactly where eigenvector stops it")
	func wholeGraphTolerance() throws {
		let source = try #require(ByComponentParityCases.all.first { $0.name == "kite" })
		let built = try graph(source.edges)
		let loose = try Centrality.eigenvectorByComponent(built, tolerance: 1e-3)
		let direct = try Centrality.eigenvectorConvergence(built, tolerance: 1e-3)
		let tight = try Centrality.eigenvectorByComponent(built)
		#expect(loose.convergence.iterations == direct.iterations)
		#expect(loose.convergence.iterations < tight.convergence.iterations)
	}

	@Test("a looser tolerance stops each component's iteration earlier, exactly where eigenvector stops it")
	func componentTolerance() throws {
		let built = try pathPairIsolate()
		let loose = try Centrality.eigenvectorByComponent(built, tolerance: 1e-3)
		let tight = try Centrality.eigenvectorByComponent(built)
		let pathAlone = try Centrality.eigenvectorConvergence(graph([("a", "b", 1), ("b", "c", 1)]), tolerance: 1e-3)
		let pairAlone = try Centrality.eigenvectorConvergence(graph([("d", "e", 1)]), tolerance: 1e-3)
		let passes: [Int] = loose.components.map(\.convergence.iterations)
		#expect(passes == [pathAlone.iterations, pairAlone.iterations])
		#expect(loose.convergence.iterations < tight.convergence.iterations)
	}

	@Test("a lower ceiling stops each component's iteration, as it does the whole graph's")
	func componentCeiling() throws {
		let result = try Centrality.eigenvectorByComponent(longPathAndPair(), maxIterations: 5)
		let path = try #require(result.components.first { $0.anchor == "p00" })
		#expect(path.convergence.iterations == 5)
		#expect(path.convergence.maxIterations == 5)
		let source = try #require(ByComponentParityCases.all.first { $0.name == "karate" })
		let whole = try Centrality.eigenvectorByComponent(graph(source.edges), maxIterations: 5)
		#expect(whole.convergence.iterations == 5)
		#expect(!whole.convergence.converged)
	}

	@Test("the aggregate is not judged by the first or the last component: a slow one in the middle shows")
	func slowComponentInTheMiddle() throws {
		var edges: [(String, String, Double)] = (0..<29).map { ("m" + pathName($0), "m" + pathName($0 + 1), 1) }
		edges.append(("a0", "a1", 1))
		edges.append(("z0", "z1", 1))
		let result = try Centrality.eigenvectorByComponent(graph(edges))
		let anchors: [String] = result.components.map(\.anchor)
		#expect(anchors == ["a0", "mp00", "z0"])
		let flags: [Bool] = result.components.map(\.convergence.converged)
		#expect(flags == [true, false, true])
		#expect(!result.convergence.converged)
		#expect(result.unconverged.map(\.anchor) == ["mp00"])
		#expect(result.convergence.iterations == 200)
	}

	@Test("a graph of one slow component reports it, the first and the last at once")
	func singleSlowComponentWithIsolate() throws {
		let result = try Centrality.eigenvectorByComponent(
			graph((0..<29).map { (pathName($0), pathName($0 + 1), 1) }, isolated: ["zz"]))
		#expect(!result.convergence.converged)
		#expect(result.unconverged.count == 1)
		#expect(result.isolatedCount == 1)
	}
}

@Suite("Eigenvector by component: weights too large for the iteration (an inherited limit, ADR-010)")
struct EigenvectorByComponentOverflowTests {

	private static let huge = 1e200

	private func hugeThenPlain() throws -> WeightedGraph<String> {
		try graph([
			("a", "b", Self.huge), ("b", "c", Self.huge),
			("d", "e", 1), ("e", "f", 1),
		])
	}

	@Test("eigenvector itself returns zeros, reported converged, for such weights: the limit is not new")
	func eigenvectorAloneIsSilent() throws {
		let run = try Centrality.eigenvectorConvergence(graph([("a", "b", Self.huge), ("b", "c", Self.huge)]))
		#expect(run.converged)
		for name in ["a", "b", "c"] { #expect(isExactly(run.scores[name], 0), "\(name)") }
	}

	@Test("a component of such weights scores as eigenvector scores it, keeps scale 1 and does not disturb the others")
	func hugeComponentBesidePlain() throws {
		let result = try Centrality.eigenvectorByComponent(hugeThenPlain())
		for name in ["a", "b", "c"] { #expect(isExactly(result.scores[name], 0), "\(name)") }
		#expect(close(result.scores["e"], 1))
		let endScore: Double = 0.5.squareRoot()
		#expect(close(result.scores["d"], endScore))
		#expect(result.isolatedCount == 0)
		#expect(result.components.map(\.size) == [3, 3])
		#expect(identical(try scale(result, 0), 1))
		#expect(identical(try scale(result, 1), 1))
		#expect(result.convergence.converged)
	}

	@Test("a graph WeightedGraph accepted is never refused here, even with a weight near half the largest finite number")
	func acceptedGraphIsAnswered() throws {
		// The component's own subgraph must not weigh more than the graph it came from: rebuilding it from
		// every tie twice would overflow the total and be refused by WeightedGraph, although the graph is valid.
		// WeightedGraph counts each tie from both ends, so 8e307 is accepted (1.6e308) and twice that is not.
		let built = try graph([("a", "b", 8e307), ("c", "d", 1)])
		#expect(throws: Never.self) { _ = try Centrality.eigenvectorByComponent(built) }
	}

	@Test("a graph of such components alone is all zeros, with no NaN and a scale of 1 for each")
	func onlyHugeComponents() throws {
		let result = try Centrality.eigenvectorByComponent(graph([
			("a", "b", Self.huge), ("b", "c", Self.huge), ("d", "e", Self.huge),
		]))
		for name in ["a", "b", "c", "d", "e"] { #expect(isExactly(result.scores[name], 0), "\(name)") }
		let scales: [Double] = result.components.map(\.scale)
		#expect(scales.count == 2)
		#expect(scales.allSatisfy { identical($0, 1) })
		#expect(result.convergence.converged)
	}
}

@Suite("Eigenvector by component: the stored metric")
struct EigenvectorByComponentMetricTests {

	@Test("the identifier and version are its own, kind scores")
	func descriptor() {
		let descriptor = ComponentwiseEigenvectorMetric<String>.descriptor
		#expect(descriptor.identifier == "eigenvector-centrality-by-component")
		#expect(ComponentwiseEigenvectorMetric<String>.identifier == "eigenvector-centrality-by-component")
		#expect(descriptor.version == 1)
		#expect(descriptor.title == "Eigenvector Centrality (by component)")
		#expect(!descriptor.interpretation.isEmpty)
		#expect(descriptor.highMeans.contains("between groups"))
		#expect(descriptor.lowMeans.contains("zero"))
		#expect(ComponentwiseScores<String>.kind == "scores")
	}

	@Test("the metric passes its own tolerance and ceiling on to the iteration")
	func metricSettings() throws {
		let built = try longPathAndPair()
		let result = try ComponentwiseEigenvectorMetric<String>(maxIterations: 3, tolerance: 1e-6).compute(on: built)
		#expect(result.convergence.maxIterations == 3)
		#expect(exactlyEqual(result.convergence.tolerance, 1e-6))
		#expect(result.convergence.iterations == 3)
		#expect(!result.convergence.converged)
		let relaxed = try ComponentwiseEigenvectorMetric<String>().compute(on: built)
		#expect(relaxed.convergence.maxIterations == 200)
		#expect(exactlyEqual(relaxed.convergence.tolerance, 1e-10))
	}

	@Test("it encodes with the envelope shape and decodes back equal")
	func roundTrip() throws {
		let result = try Centrality.eigenvectorByComponent(pathPairIsolate())
		let data = try JSONEncoder().encode(result)
		let again = try JSONDecoder().decode(ComponentwiseScores<String>.self, from: data)
		#expect(again == result)
		let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
		#expect(Set(object.keys) == ["scores", "convergence", "components", "isolatedCount"])
		let components = try #require(object["components"] as? [[String: Any]])
		let first = try #require(components.first)
		#expect(Set(first.keys) == ["anchor", "size", "convergence", "scale"])
	}

	@Test("an envelope of it reads as plain scores and carries the aggregate convergence")
	func envelopeReadsAsScores() throws {
		let result = try Centrality.eigenvectorByComponent(pathPairIsolate())
		let envelope = try MetricEnvelope(result)
		#expect(envelope.kind == "scores")
		let plain = try #require(try envelope.value(as: NodeScores<String>.self))
		#expect(sameBits(plain, result.scores))
		#expect(envelope.convergence == result.convergence)
		let back = try #require(try envelope.value(as: ComponentwiseScores<String>.self))
		#expect(back == result)
		let diagnosed = try #require(try envelope.value(as: DiagnosedScores<String>.self))
		#expect(diagnosed == result.diagnosed)
		let middle = try #require(result.scores["b"])
		#expect(middle > 0.5)   // not the all-zero answer
	}

	@Test("the diagnosed view is the scores and the aggregate, nothing more")
	func diagnosedView() throws {
		let result = try Centrality.eigenvectorByComponent(pathPairIsolate())
		#expect(result.diagnosed.scores == result.scores)
		#expect(result.diagnosed.convergence == result.convergence)
	}

	@Test("the standard registry lists it beside every other metric, which keep their versions")
	func registry() throws {
		let listed = MetricRegistry<String>.standard.available
		let found = try #require(listed.first { $0.identifier == "eigenvector-centrality-by-component" })
		#expect(found.version == 1)
		let old = try #require(listed.first { $0.identifier == "eigenvector-centrality" })
		#expect(old.version == 5)
		let pagerank = try #require(listed.first { $0.identifier == "pagerank" })
		#expect(pagerank.version == 3)
		#expect(listed.count == 12)
	}

	@Test("the old identifier still refuses a disconnected graph while the new one answers it")
	func oldIdentifierUnchanged() throws {
		let built = try pathPairIsolate()
		let registry = MetricRegistry<String>.standard
		let old = try #require(registry.metric(for: "eigenvector-centrality"))
		#expect(old.descriptor.version == 5)
		#expect(throws: GraphMeasureError.disconnectedGraph(components: 3)) {
			_ = try old.compute(on: built)
		}
		let output = try #require(try registry.run("eigenvector-centrality-by-component", on: built))
		let scores = try #require(try output.value(as: NodeScores<String>.self))
		#expect(scores.scores.count == 6)
		let middle = try #require(scores["b"])
		#expect(middle > 0.5)
	}

	@Test("a run records the new identifier and version")
	func recorded() throws {
		let built = try pathPairIsolate()
		let stamp = Date(timeIntervalSince1970: 0)
		let record = try #require(try MetricRegistry<String>.standard.record(
			"eigenvector-centrality-by-component", on: built, context: "synthetic", now: stamp))
		#expect(record.metric == "eigenvector-centrality-by-component")
		#expect(record.metricVersion == 1)
		#expect(record.output.convergence?.converged == true)
		let again = try JSONDecoder().decode(MetricRecord<String>.self, from: try JSONEncoder().encode(record))
		#expect(again == record)
		let typed = try #require(try again.output.value(as: ComponentwiseScores<String>.self))
		#expect(typed.components.count == 2)
	}
}
