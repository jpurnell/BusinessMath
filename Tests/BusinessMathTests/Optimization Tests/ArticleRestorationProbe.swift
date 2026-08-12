//
//  ArticleRestorationProbe.swift
//
//  Replicates the pre-shrink (9a6c73b^) configurations of 5.7, 5.13 and 5.14 to
//  measure whether they can now be restored. Does not touch the articles.
//
//  Each case asserts the model's own stated constraints rather than only running to
//  completion. Without that, a solve that returns portfolio weights of −1.9e13 for a
//  model requiring them non-negative and summing to one reports as a pass, which is
//  how 5.13 Example 1 looked green while diverging.
//
//  The suite carries a time limit because these configurations are exactly the ones
//  that were shrunk for being slow: 5.14's quick start once took 116 minutes, and the
//  useful signal from a restoration probe is "not restorable" in reasonable time, not
//  an hour of occupied CI.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Article Restoration Probe", .serialized, .timeLimit(.minutes(1)))
struct ArticleRestorationProbe {

	static func time<T>(_ label: String, _ body: () throws -> T) rethrows -> T {
		let t0 = Date()
		let r = try body()
		print("[\(label)] \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
		return r
	}

	// MARK: 5.7 — resource allocation in RAW DOLLARS (pre-shrink units, 5 projects)

	@Test("5.7 raw dollars, five projects")
	func article57() throws {
		let capitalProjects = [
			AllocationOption(id: "infrastructure", name: "Infrastructure Upgrade",
							 expectedValue: 300_000, resourceRequirements: ["budget": 200_000, "headcount": 5], strategicValue: 8.0),
			AllocationOption(id: "new_product", name: "New Product Launch",
							 expectedValue: 800_000, resourceRequirements: ["budget": 400_000, "headcount": 10], strategicValue: 9.0),
			AllocationOption(id: "marketing", name: "Marketing Expansion",
							 expectedValue: 400_000, resourceRequirements: ["budget": 250_000, "headcount": 3], strategicValue: 6.0),
			AllocationOption(id: "cost_reduction", name: "Cost Reduction Initiative",
							 expectedValue: 200_000, resourceRequirements: ["budget": 100_000, "headcount": 2], strategicValue: 7.0),
			AllocationOption(id: "acquisition", name: "Strategic Acquisition",
							 expectedValue: 1_000_000, resourceRequirements: ["budget": 600_000, "headcount": 8], strategicValue: 8.5)
		]
		let optimizer = ResourceAllocationOptimizer()
		let result = try Self.time("5.7 dollars") {
			try optimizer.optimize(options: capitalProjects, objective: .maximizeValue,
								   constraints: [.totalBudget(1_000_000)])
		}
		print("  converged=\(result.converged) value=\(result.totalValue) selected=\(result.selectedOptions.map { $0.id })")
		print("  allocations=\(result.allocations.sorted { $0.key < $1.key })")

		// Same model in $ millions
		let inMillions = capitalProjects.map { p in
			AllocationOption(id: p.id, name: p.name, expectedValue: p.expectedValue / 1e6,
							 resourceRequirements: p.resourceRequirements.mapValues { $0 == 0 ? 0 : ($0 > 100 ? $0 / 1e6 : $0) },
							 strategicValue: p.strategicValue)
		}
		let r2 = try Self.time("5.7 millions") {
			try optimizer.optimize(options: inMillions, objective: .maximizeValue, constraints: [.totalBudget(1.0)])
		}
		print("  converged=\(r2.converged) value=\(r2.totalValue) selected=\(r2.selectedOptions.map { $0.id })")

		#expect(result.converged, "raw-dollar model should converge")
		#expect(r2.converged, "the same model in millions should converge")
		#expect(result.totalValue.isFinite, "total value must be finite, got \(result.totalValue)")

		// The point of running it twice: dividing every dollar figure by a million
		// restates the model, it does not change which projects are worth funding.
		// A selection that depends on the units is the defect this article opened on.
		let dollarPicks = Set(result.selectedOptions.map { $0.id })
		let millionPicks = Set(r2.selectedOptions.map { $0.id })
		#expect(
			dollarPicks == millionPicks,
			"selection must not depend on units — dollars chose \(dollarPicks.sorted()), millions chose \(millionPicks.sorted())"
		)
	}

	// MARK: 5.13 — Example 1 at the DEFAULT 1e-6 tolerance (workaround was 1e-3)

	@Test("5.13 Example 1 at default tolerance")
	func article513Example1() throws {
		let optimizer = try MultiPeriodOptimizer<VectorN<Double>>(numberOfPeriods: 4, discountRate: 0.02)
		let returns = VectorN([0.08, 0.10, 0.12, 0.15])
		let vols = [0.10, 0.15, 0.20, 0.25]
		let cov = (0..<4).map { i in (0..<4).map { j in i == j ? vols[i] * vols[i] : 0.0 } }
		let riskAversion = [1.0, 1.5, 2.0, 2.5]

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [.budgetEachPeriod, .turnoverLimit(0.20)]
		constraints.append(contentsOf: MultiPeriodConstraint<VectorN<Double>>.nonNegativityEachPeriod(dimension: 4))
		for i in 0..<4 {
			constraints.append(.eachPeriod { _, w in w.toArray()[i] - 0.60 })
		}

		let result = try Self.time("5.13 ex1 tol=1e-6") {
			try optimizer.optimize(
				objective: { period, weights in
					let w = weights.toArray()
					let expectedReturn = weights.dot(returns)
					let variance = (0..<4).map { i in (0..<4).map { j in w[i] * cov[i][j] * w[j] }.reduce(0, +) }.reduce(0, +)
					return expectedReturn - riskAversion[period] * variance
				},
				initialState: VectorN([0.05, 0.10, 0.25, 0.60]),
				constraints: constraints,
				minimize: false)
		}
		print("  converged=\(result.converged) total=\(result.totalObjective)")
		for (t, x) in result.trajectory.enumerated() {
			print("  Q\(t + 1): \(x.toArray().map { ($0 * 1000).rounded() / 10 })")
		}

		#expect(result.converged, "5.13 Example 1 should converge at the default tolerance")
		#expect(result.totalObjective.isFinite, "objective must be finite, got \(result.totalObjective)")

		// `.budgetEachPeriod`, `.nonNegativityEachPeriod` and the per-asset 0.60 cap,
		// restated as assertions so a divergent solve cannot report success.
		for (t, x) in result.trajectory.enumerated() {
			let weights = x.toArray()
			let total = weights.reduce(0, +)
			#expect(abs(total - 1.0) < 1e-3, "Q\(t + 1) weights must sum to 1, got \(total)")
			#expect(weights.allSatisfy { $0 >= -1e-6 }, "Q\(t + 1) weights must be non-negative, got \(weights)")
			#expect(weights.allSatisfy { $0 <= 0.60 + 1e-6 }, "Q\(t + 1) weights must not exceed 0.60, got \(weights)")
		}

		// `.turnoverLimit(0.20)` — the L1 distance between consecutive allocations.
		for t in 1..<result.trajectory.count {
			let previous = result.trajectory[t - 1].toArray()
			let current = result.trajectory[t].toArray()
			let turnover = zip(previous, current).map { abs($1 - $0) }.reduce(0, +)
			#expect(turnover <= 0.20 + 1e-3, "turnover Q\(t) → Q\(t + 1) must not exceed 0.20, got \(turnover)")
		}
	}

	// MARK: 5.13 — Example 4 at SIX periods and default tolerance (workaround: 4 periods, 1e-4)

	@Test("5.13 Example 4 at six periods, default tolerance")
	func article513Example4() throws {
		let optimizer = try MultiPeriodOptimizer<VectorN<Double>>(numberOfPeriods: 6, discountRate: 0.0)
		let demand = [180.0, 150.0, 120.0, 180.0, 140.0, 160.0]
		let productionCost = 50.0
		let holdingCost = 5.0
		let maxProduction = 160.0
		let maxInventory = 100.0

		var constraints: [MultiPeriodConstraint<VectorN<Double>>] = [
			.eachPeriod { _, x in -x.toArray()[0] },
			.eachPeriod { _, x in -x.toArray()[1] },
			.eachPeriod { _, x in x.toArray()[0] - maxProduction },
			.eachPeriod { _, x in x.toArray()[1] - maxInventory }
		]
		for t in 0..<6 {
			constraints.append(.eachPeriod { period, x in
				period == t ? demand[t] - x.toArray()[0] - x.toArray()[1] : 0.0
			})
		}

		let result = try Self.time("5.13 ex4 6 periods tol=1e-6") {
			try optimizer.optimize(
				objective: { _, x in
					let a = x.toArray()
					return productionCost * a[0] + holdingCost * a[1]
				},
				initialState: VectorN([150.0, 50.0]),
				constraints: constraints,
				minimize: true)
		}
		print("  converged=\(result.converged) total=\(result.totalObjective)")

		#expect(result.converged, "5.13 Example 4 should converge at six periods")
		#expect(result.totalObjective.isFinite, "objective must be finite, got \(result.totalObjective)")

		// Production and inventory bounds, restated from the constraints above.
		for (t, x) in result.trajectory.enumerated() {
			let state = x.toArray()
			guard state.count >= 2 else {
				Issue.record("period \(t + 1) state has \(state.count) components, expected 2")
				continue
			}
			#expect(state[0] >= -1e-6, "period \(t + 1) production must be non-negative, got \(state[0])")
			#expect(state[1] >= -1e-6, "period \(t + 1) inventory must be non-negative, got \(state[1])")
			#expect(state[0] <= maxProduction + 1e-3, "period \(t + 1) production must not exceed \(maxProduction), got \(state[0])")
			#expect(state[1] <= maxInventory + 1e-3, "period \(t + 1) inventory must not exceed \(maxInventory), got \(state[1])")
		}
	}

	// MARK: 5.14 — Quick Start with a PURELY LINEAR objective and 100 samples

	@Test("5.14 quick start, linear objective, 100 samples")
	func article514QuickStart() throws {
		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: try BoxUncertaintySet(nominal: [0.10, 0.12, 0.08], deviations: [0.02, 0.03, 0.01]),
			samplesPerIteration: 100,
			maxIterations: 500,
			tolerance: 1e-6)

		let constraints: [MultivariateConstraint<VectorN<Double>>] =
			[.budgetConstraint] + MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 3)

		let result = try Self.time("5.14 quickstart linear, 100 samples") {
			try optimizer.optimize(
				objective: { weights, returns in -weights.dot(VectorN(returns)) },
				nominalParameters: [0.10, 0.12, 0.08],
				initialSolution: VectorN([0.33, 0.33, 0.34]),
				constraints: constraints,
				minimize: true)
		}
		print("  weights=\(result.solution.toArray()) worstCase=\(result.worstCaseObjective)")

		let weights = result.solution.toArray()
		let total = weights.reduce(0, +)
		#expect(abs(total - 1.0) < 1e-3, "weights must sum to 1, got \(total)")
		#expect(weights.allSatisfy { $0 >= -1e-6 }, "weights must be non-negative, got \(weights)")

		// This one has a closed form, which is worth pinning rather than merely
		// sanity-checking. The objective −w·r is linear, so its worst case over the
		// box is at a vertex: for w ≥ 0 the worst return vector is nominal − deviation
		// = [0.08, 0.09, 0.07]. Maximising the worst case puts everything on the best
		// of those, so w = [0, 1, 0] and the worst case is −0.09 exactly.
		#expect(
			abs(result.worstCaseObjective - (-0.09)) < 1e-4,
			"worst case should be −0.09, got \(result.worstCaseObjective)"
		)
		#expect(abs(weights[1] - 1.0) < 1e-3, "all weight belongs on asset 2, got \(weights)")
	}

	// MARK: 5.14 — Example 2 at FOUR assets, 100 samples (pre-shrink)

	@Test("5.14 worst-case portfolio, four assets, 100 samples")
	func article514Example2() throws {
		let nominal = [0.10, 0.12, 0.08, 0.15]
		let deviations = [0.03, 0.02, 0.01, 0.04]
		let vols = [0.15, 0.10, 0.05, 0.20]
		let riskAversion = 1.5
		let cov = (0..<4).map { i in (0..<4).map { j in i == j ? vols[i] * vols[i] : 0.0 } }

		let optimizer = RobustOptimizer<VectorN<Double>>(
			uncertaintySet: try BoxUncertaintySet(nominal: nominal, deviations: deviations),
			samplesPerIteration: 100,
			maxIterations: 500,
			tolerance: 1e-6)

		var constraints: [MultivariateConstraint<VectorN<Double>>] = [.budgetConstraint]
		constraints.append(contentsOf: MultivariateConstraint<VectorN<Double>>.nonNegativity(dimension: 4))
		for i in 0..<4 {
			constraints.append(.inequality { weights in weights.toArray()[i] - 0.40 })
		}

		let result = try Self.time("5.14 ex2 4 assets, 100 samples") {
			try optimizer.optimize(
				objective: { weights, returns in
					let w = weights.toArray()
					let expectedReturn = weights.dot(VectorN(returns))
					let variance = (0..<4).map { i in (0..<4).map { j in w[i] * cov[i][j] * w[j] }.reduce(0, +) }.reduce(0, +)
					return -(expectedReturn - riskAversion * variance)
				},
				nominalParameters: nominal,
				initialSolution: VectorN([0.25, 0.25, 0.25, 0.25]),
				constraints: constraints,
				minimize: true)
		}
		print("  weights=\(result.solution.toArray()) worstCase=\(result.worstCaseObjective)")

		let weights = result.solution.toArray()
		let total = weights.reduce(0, +)
		#expect(abs(total - 1.0) < 1e-3, "weights must sum to 1, got \(total)")
		#expect(weights.allSatisfy { $0 >= -1e-6 }, "weights must be non-negative, got \(weights)")
		#expect(weights.allSatisfy { $0 <= 0.40 + 1e-3 }, "no asset may exceed 0.40, got \(weights)")
		#expect(result.worstCaseObjective.isFinite, "worst case must be finite, got \(result.worstCaseObjective)")
	}
}
