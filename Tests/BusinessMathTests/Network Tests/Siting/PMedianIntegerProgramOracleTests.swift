//
//  PMedianIntegerProgramOracleTests.swift
//  BusinessMath
//
//  A second, independent oracle for PMedian: the same instance written as an integer program
//  and solved by BusinessMath's own branch-and-bound solver.
//
//  The p-median is the textbook facility-location integer program. With binary y[j] ("site j
//  is chosen") and x[d][j] in [0, 1] ("the share of demand d served from site j"):
//
//      minimise    sum over d, j of  weight[d] * cost[d][j] * x[d][j]
//      subject to  sum over j of x[d][j] = 1          for every demand point d
//                  x[d][j] <= y[j]                     for every d and j
//                  sum over j of y[j] = p
//                  x >= 0,  y binary
//
//  Neither PMedian nor its tests share any code with this: the solver knows nothing about
//  subsets, greedy construction or swaps. A third, hand-written enumeration inside this file
//  checks the integer program itself, so a disagreement can be attributed.
//

import Foundation
import SwiftDeterminism
import Testing
import TestSupport

@testable import BusinessMath

@Suite("PMedian against an integer-programming oracle")
struct PMedianIntegerProgramOracleTests {

	/// A seeded instance: weights in [0.1, 10), costs in [0, 20).
	private struct Instance {
		let weights: [Double]
		let costs: [[Double]]

		init(seed: UInt64, sites: Int, demands: Int) {
			var rng = SplitMix64(seed: seed)
			var w: [Double] = []
			var c: [[Double]] = []
			for _ in 0..<demands {
				w.append(Double.random(in: 0.1...10, using: &rng))
				c.append((0..<sites).map { _ in Double.random(in: 0...20, using: &rng) })
			}
			weights = w
			costs = c
		}

		var siteCount: Int { costs[0].count }
		var demandCount: Int { weights.count }

		var problem: SiteProblem<Int, Int> {
			get throws {
				let table = costs
				return try SiteProblem(
					demand: Dictionary(uniqueKeysWithValues: weights.enumerated().map { ($0, $1) }),
					sites: Array(0..<siteCount),
					cost: { d, s in table[d][s] })
			}
		}
	}

	/// The integer program's answer: the chosen sites, and the optimal objective.
	private struct Solved {
		let sites: [Int]
		let objective: Double
		let status: IntegerSolutionStatus
	}

	/// Variable layout: `[y_0 ... y_{m-1}, x_00 ... x_0(m-1), x_10 ... ]`.
	private func solveIntegerProgram(_ instance: Instance, p: Int) throws -> Solved {
		let m = instance.siteCount
		let demands = instance.demandCount
		let dimension = m + demands * m
		func x(_ d: Int, _ j: Int) -> Int { m + d * m + j }

		var objective = [Double](repeating: 0, count: dimension)
		for d in 0..<demands {
			for j in 0..<m { objective[x(d, j)] = instance.weights[d] * instance.costs[d][j] }
		}

		var constraints: [MultivariateConstraint<VectorN<Double>>] = []
		// Every demand point is fully served.
		for d in 0..<demands {
			var row = [Double](repeating: 0, count: dimension)
			for j in 0..<m { row[x(d, j)] = 1 }
			constraints.append(.linearEquality(coefficients: row, rhs: 1))
		}
		// Demand can only be served from a chosen site: x[d][j] - y[j] <= 0.
		for d in 0..<demands {
			for j in 0..<m {
				var row = [Double](repeating: 0, count: dimension)
				row[x(d, j)] = 1
				row[j] = -1
				constraints.append(.linearInequality(coefficients: row, rhs: 0, sense: .lessOrEqual))
			}
		}
		// Exactly p sites.
		var count = [Double](repeating: 0, count: dimension)
		for j in 0..<m { count[j] = 1 }
		constraints.append(.linearEquality(coefficients: count, rhs: Double(p)))
		// x >= 0 (y >= 0 and y <= 1 come from the binary specification).
		for d in 0..<demands {
			for j in 0..<m {
				var row = [Double](repeating: 0, count: dimension)
				row[x(d, j)] = 1
				constraints.append(.linearInequality(coefficients: row, rhs: 0, sense: .greaterOrEqual))
			}
		}

		let solver = BranchAndBoundSolver<VectorN<Double>>(
			maxNodes: 200_000,
			timeLimit: unboundedSolverTimeLimit,
			relativeGapTolerance: 1e-9,
			nodeSelection: .bestBound)
		let result = try solver.solve(
			objective: StandardLinearFunction<VectorN<Double>>(coefficients: objective),
			from: VectorN(repeating: 0.1, count: dimension),
			subjectTo: constraints,
			integerSpec: IntegerProgramSpecification(binaryVariables: Set(0..<m)),
			minimize: true)
		let values = result.solution.toArray()
		let chosen = (0..<m).filter { values[$0] > 0.5 }
		return Solved(sites: chosen, objective: result.objectiveValue, status: result.status)
	}

	/// Every p-subset, written out here and sharing nothing with PMedian.
	private func enumeratedOptimum(_ instance: Instance, p: Int) -> (sites: [Int], total: Double) {
		var best: [Int] = []
		var bestTotal = Double.infinity
		for mask in 0..<(1 << instance.siteCount) where mask.nonzeroBitCount == p {
			var total = 0.0
			for d in 0..<instance.demandCount {
				var cheapest = Double.infinity
				for s in 0..<instance.siteCount where mask & (1 << s) != 0 {
					cheapest = min(cheapest, instance.costs[d][s])
				}
				total += instance.weights[d] * cheapest
			}
			if total < bestTotal {
				bestTotal = total
				best = (0..<instance.siteCount).filter { mask & (1 << $0) != 0 }
			}
		}
		return (best, bestTotal)
	}

	/// (seed, sites, demands): up to eight sites and twelve demand points.
	private static let shapes: [(UInt64, Int, Int)] = [
		(101, 6, 8), (102, 7, 10), (103, 8, 12), (104, 8, 9),
	]

	/// Relative tolerance on the objective. The solver recovers the objective's coefficients
	/// numerically (finite differences, roughly 1e-9 relative) and stops inside a relative gap
	/// of 1e-9, so agreement to 1e-6 is a wide margin over the solver's error and a narrow one
	/// over any real difference between two optima, which for random float costs is far larger.
	private static let relativeTolerance = 1e-6

	@Test("The integer program agrees with enumeration, so it is a trustworthy oracle",
		  arguments: [1, 2, 3])
	func programMatchesEnumeration(p: Int) throws {
		for (seed, sites, demands) in Self.shapes {
			let instance = Instance(seed: seed, sites: sites, demands: demands)
			let solved = try solveIntegerProgram(instance, p: p)
			let truth = enumeratedOptimum(instance, p: p)
			#expect(solved.status == .optimal, "seed \(seed) p \(p)")
			#expect(solved.sites == truth.sites, "seed \(seed) p \(p)")
			let gap: Double = abs(solved.objective - truth.total)
			#expect(gap <= Self.relativeTolerance * truth.total, "seed \(seed) p \(p)")
		}
	}

	@Test("PMedian's optimum equals the integer program's, for p = 1, 2, 3, with the same sites",
		  arguments: [1, 2, 3])
	func pMedianMatchesProgram(p: Int) throws {
		for (seed, sites, demands) in Self.shapes {
			let instance = Instance(seed: seed, sites: sites, demands: demands)
			let solved = try solveIntegerProgram(instance, p: p)
			let result = try PMedian().select(try instance.problem, count: p)
			#expect(result.isExact)
			#expect(solved.status == .optimal, "seed \(seed) p \(p)")
			let gap: Double = abs(result.totalWeightedCost - solved.objective)
			#expect(gap <= Self.relativeTolerance * solved.objective, "seed \(seed) p \(p)")
			#expect(result.chosen == solved.sites, "seed \(seed) p \(p)")
		}
	}

	@Test("The heuristic branch is never below the integer program's optimum, and usually reaches it",
		  arguments: [1, 2, 3])
	func heuristicAgainstProgram(p: Int) throws {
		var reached = 0
		var total = 0
		for (seed, sites, demands) in Self.shapes {
			let instance = Instance(seed: seed, sites: sites, demands: demands)
			let solved = try solveIntegerProgram(instance, p: p)
			let result = try PMedian(enumerationLimit: 0).select(try instance.problem, count: p)
			#expect(!result.isExact)
			let slack: Double = Self.relativeTolerance * solved.objective
			#expect(result.totalWeightedCost >= solved.objective - slack, "seed \(seed) p \(p)")
			total += 1
			if result.totalWeightedCost <= solved.objective + slack { reached += 1 }
		}
		// Teitz-Bart has no guarantee; on these seeded instances it reaches the optimum in most.
		#expect(reached >= total - 1, "reached \(reached) of \(total) at p \(p)")
	}
}
