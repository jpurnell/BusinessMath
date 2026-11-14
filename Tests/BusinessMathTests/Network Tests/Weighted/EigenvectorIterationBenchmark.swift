//
//  EigenvectorIterationBenchmark.swift
//  BusinessMath
//

import Foundation
import SwiftDeterminism
import Testing

import TestSupport
@testable import BusinessMath

/// Measures how many power-iteration passes `Centrality.eigenvector` needs on synthetic
/// graphs of several sizes, densities and structures, and what the default ceiling of 200
/// leaves behind. It makes no assertion about the numbers: it is a measurement, and runs
/// only when asked.
///
/// ```
/// NETWORK_BENCHMARK=1 swift test -c release -Xswiftc -enable-testing --filter EigenvectorIterationBenchmark
/// NETWORK_BENCHMARK=1 NETWORK_BENCHMARK_OUT=/path/table.md swift test ...   # also write the table
/// ```
///
/// Columns: `n`, `edges`; `passes` is iterations to reach the default tolerance 1e-10 when
/// given a very large ceiling (`>cap` if even that was not enough); `at 200` is the state of
/// the shipped default (converged or not, the L1 change it stopped on); `eig-resid` is the
/// relative eigen-residual |Ax - rho x| / rho of the vector the default returns;
/// `max score err` is the largest difference, on the 0...1 score scale, between the default's
/// scores and a reference (analytic for a path; otherwise a run to 1e-13), or `n/a` when no
/// reference converged within the cap.
@Suite("Eigenvector iteration benchmark",
	   .enabled(if: ProcessInfo.processInfo.environment["NETWORK_BENCHMARK"] == "1"))
struct EigenvectorIterationBenchmark {

	static let cap = 6_000_000

	private struct Case {
		let family: String
		let graph: WeightedGraph<String>
		/// Analytic scores, where known.
		var analytic: [Double]? = nil
	}

	private static func scientific(_ value: Double) -> String {
		value.formatted(.number.notation(.scientific).precision(.significantDigits(3)))
	}

	private static func relativeEigenResidual(
		_ graph: WeightedGraph<String>, _ scores: NodeScores<String>
	) -> Double {
		let x: [Double] = graph.nodes.map { scores.scores[$0] ?? 0 }
		var sumSquares = 0.0
		for value in x { sumSquares += value * value }
		let length = sumSquares.squareRoot()
		let unit: [Double] = x.map { $0 / length }
		var applied = [Double](repeating: 0, count: unit.count)
		for i in 0..<unit.count {
			for (j, w) in graph.adjacency[i] { applied[i] += w * unit[j] }
		}
		var rho = 0.0
		for i in 0..<unit.count { rho += unit[i] * applied[i] }
		var residual = 0.0
		for i in 0..<unit.count {
			let difference = applied[i] - rho * unit[i]
			residual += difference * difference
		}
		return residual.squareRoot() / rho
	}

	private static func cases() throws -> [Case] {
		var list: [Case] = []
		for n in [50, 100, 200, 400, 1_100] {
			let analytic = (1...n).map { sin(Double($0) * Double.pi / Double(n + 1)) }
			let peak = analytic.max() ?? 1
			list.append(Case(family: "path", graph: try Synthetic.path(n), analytic: analytic.map { $0 / peak }))
		}
		list.append(Case(family: "star", graph: try Synthetic.star(1_100)))
		list.append(Case(family: "ring (uniform start is the answer)", graph: try Synthetic.ring(1_100)))
		for n in [100, 400, 1_100] {
			list.append(Case(family: "ring, weights 1-4", graph: try weightedRing(n, seed: UInt64(n))))
		}
		list.append(Case(family: "grid 33x33", graph: try Synthetic.grid(rows: 33, columns: 33)))
		list.append(Case(family: "grid 10x110", graph: try Synthetic.grid(rows: 10, columns: 110)))
		for n in [100, 300, 1_100, 3_000] {
			list.append(Case(family: "Erdos-Renyi, mean degree 6",
							 graph: try Synthetic.erdosRenyi(seed: 7, count: n, edgeCount: n * 3)))
		}
		for edges in [1_500, 3_000, 10_000, 30_000] {
			list.append(Case(family: "Erdos-Renyi",
							 graph: try Synthetic.erdosRenyi(seed: 8, count: 1_100, edgeCount: edges)))
		}
		for m in [2, 3, 10, 25] {
			list.append(Case(family: "preferential attachment m=\(m)",
							 graph: try Synthetic.preferentialAttachment(seed: 9, count: 1_100, perNode: m)))
		}
		for between in [2_000, 500, 100, 20] {
			list.append(Case(family: "10 communities, \(between) bridging edges",
							 graph: try Synthetic.communities(
								seed: 10, count: 1_100, groups: 10, inside: 1_500, between: between)))
		}
		for between in [100, 10, 3, 1] {
			list.append(Case(family: "2 dense clusters (5k edges each), \(between) bridging",
							 graph: try Synthetic.communities(
								seed: 11, count: 1_100, groups: 2, inside: 5_000, between: between)))
		}
		list.append(Case(family: "2 dense clusters (14k edges each), 1 bridging",
						 graph: try Synthetic.communities(
							seed: 12, count: 1_100, groups: 2, inside: 14_000, between: 1)))
		return list
	}

	private static func weightedRing(_ count: Int, seed: UInt64) throws -> WeightedGraph<String> {
		var rng = SplitMix64(seed: seed)
		return try Synthetic.graph(
			(0..<count).map {
				(Synthetic.name($0), Synthetic.name(($0 + 1) % count),
				 Double(Int.random(in: 1...4, using: &rng)))
			}, count: count)
	}

	@Test("Measure iterations to converge by size, density and structure")
	func measure() throws {
		var rows = [
			"| family | n | edges | passes to 1e-10 | at 200: converged | at 200: last change | at 200: eig-resid | at 200: max score err | seconds |",
			"|---|---:|---:|---:|:---:|---:|---:|---:|---:|",
		]
		for item in try Self.cases() {
			let graph = item.graph
			let started = Date()
			let full = try Centrality.eigenvectorConvergence(
				graph, maxIterations: Self.cap, tolerance: 1e-10)
			let seconds = Date().timeIntervalSince(started)
			let shipped = try Centrality.eigenvectorConvergence(graph)

			var reference: [Double]? = item.analytic
			if reference == nil {
				let tight = try Centrality.eigenvectorConvergence(
					graph, maxIterations: Self.cap, tolerance: 1e-13)
				if tight.converged { reference = graph.nodes.map { tight.scores.scores[$0] ?? 0 } }
			}
			let error: String
			if let reference {
				let mine: [Double] = graph.nodes.map { shipped.scores.scores[$0] ?? 0 }
				error = Self.scientific(zip(mine, reference).map { abs($0 - $1) }.max() ?? 0)
			} else { error = "n/a" }

			let passes = full.converged ? "\(full.iterations)" : ">\(Self.cap)"
			let converged = shipped.converged ? "yes" : "NO"
			let change = Self.scientific(shipped.residual)
			let eigen = Self.scientific(Self.relativeEigenResidual(graph, shipped.scores))
			let elapsed = String((seconds * 10).rounded() / 10)
			var row = "| \(item.family) | \(graph.nodeCount) | \(graph.edgeCount) | \(passes) | "
			row += "\(converged) | \(change) | \(eigen) | \(error) | \(elapsed) |"
			rows.append(row)
			print(row)
		}
		let table = rows.joined(separator: "\n") + "\n"
		if let path = ProcessInfo.processInfo.environment["NETWORK_BENCHMARK_OUT"] {
			try? table.write(toFile: path, atomically: true, encoding: .utf8)
		}
		#expect(rows.count > 2)
	}
}
