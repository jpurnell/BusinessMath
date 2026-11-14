//
//  WeightedCrossCheckTests.swift
//  BusinessMath
//  The fast implementations checked against slow ones written independently.
//  Same quantity, different route, no shared code.
//

import Foundation
import Testing

import TestSupport
@testable import BusinessMath

private var kite: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.kiteEdges)
}

private var karate: WeightedGraph<String> {
	WeightedGraph(unweightedEdges: ReferenceGraphs.karateEdges.map {
		(String($0.0), String($0.1))
	})
}

@Suite("Second opinions")
struct WeightedCrossCheckTests {

	@Test("Brandes betweenness agrees with brute-force path enumeration on the kite")
	func betweennessAgreesOnKite() {
		let fast = Centrality.betweenness(kite)
		let slow = IndependentImplementations.betweennessByEnumeration(kite)
		for node in kite.nodes {
			let a = fast[node] ?? -1
			let b = slow[node] ?? -2
			#expect(abs(a - b) < 1e-9, "\(node): Brandes \(a), enumeration \(b)")
		}
	}

	@Test("Brandes betweenness agrees with enumeration on the karate club")
	func betweennessAgreesOnKarate() {
		let fast = Centrality.betweenness(karate)
		let slow = IndependentImplementations.betweennessByEnumeration(karate)
		for node in karate.nodes {
			let a = fast[node] ?? -1
			let b = slow[node] ?? -2
			#expect(abs(a - b) < 1e-9, "node \(node): Brandes \(a), enumeration \(b)")
		}
	}

	@Test("Power iteration agrees with dense matrix multiplication")
	func eigenvectorAgrees() throws {
		for graph in [kite, karate] {
			let fast = try Centrality.eigenvector(graph)
			let slow = IndependentImplementations.eigenvectorByDenseMatrix(graph)
			for node in graph.nodes {
				let a = fast[node] ?? -1
				let b = slow[node] ?? -2
				#expect(abs(a - b) < 1e-6, "\(node): iteration \(a), dense \(b)")
			}
		}
	}

	@Test("Core numbers agree with literal repeated peeling")
	func kCoreAgrees() {
		for graph in [kite, karate] {
			let fast = Community.kCore(graph)
			let slow = IndependentImplementations.kCoreByPeeling(graph)
			for node in graph.nodes {
				#expect(fast[node] == slow[node],
						"\(node): fast \(fast[node] ?? -1), peeling \(slow[node] ?? -2)")
			}
		}
	}

	/// Louvain's own objective, scored by a function that shares none of its code.
	@Test("Louvain's partition scores well under an independent modularity function")
	func louvainScoresWell() throws {
		let partition = Community.louvain(karate)
		let score = try Community.modularity(karate, partition: partition)
		// Any partition Louvain returns must beat both trivial partitions.
		let single = NodePartition<String>(Dictionary(
			uniqueKeysWithValues: karate.nodes.map { ($0, 0) }))
		let singletons = NodePartition<String>(Dictionary(
			uniqueKeysWithValues: karate.nodes.enumerated().map { ($0.element, $0.offset) }))
		let singleScore = try Community.modularity(karate, partition: single)
		let singletonScore = try Community.modularity(karate, partition: singletons)
		#expect(score > singleScore)
		#expect(score > singletonScore)
	}
}
