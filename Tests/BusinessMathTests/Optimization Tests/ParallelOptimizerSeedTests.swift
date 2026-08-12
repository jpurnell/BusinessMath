//
//  ParallelOptimizerSeedTests.swift
//  BusinessMath
//
//  ParallelOptimizer draws its starting points at random, and until it took a seed there
//  was no way to run it twice and get the same answer — which also meant no way to tell a
//  regression from a redraw. These pin the seed contract: same seed reproduces, a
//  different seed does not, and omitting the seed leaves the old behaviour alone.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

@Suite("Parallel Optimizer Seed Determinism", .serialized)
struct ParallelOptimizerSeedTests {

	/// A quadratic with its minimum away from the origin. Smooth and cheap, and with a
	/// modest iteration budget each start lands somewhere distinct, so the best-of-N is
	/// a unique result rather than a tie broken by whichever task happened to finish first.
	private static let quadratic: @Sendable (VectorN<Double>) -> Double = { v in
		let x = v[0]
		let y = v[1]
		return (x - 3.0) * (x - 3.0) + (y - 4.0) * (y - 4.0)
	}

	private static let searchRegion = (
		lower: VectorN([-10.0, -10.0]),
		upper: VectorN([10.0, 10.0])
	)

	private static func optimizer(seed: UInt64?) -> ParallelOptimizer<VectorN<Double>> {
		ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.05),
			numberOfStarts: 6,
			maxIterations: 20,
			tolerance: 1e-6,
			seed: seed
		)
	}

	private static func run(seed: UInt64?) async throws -> ParallelOptimizationResult<VectorN<Double>> {
		try await optimizer(seed: seed).optimize(
			objective: quadratic,
			searchRegion: searchRegion,
			constraints: []
		)
	}

	// MARK: - Same seed reproduces

	@Test("Same seed reproduces the same parallel optimization")
	func testSameSeedReproduces() async throws {
		let first = try await Self.run(seed: 20260811)
		let second = try await Self.run(seed: 20260811)

		#expect(identical(first.objectiveValue, second.objectiveValue), "Same seed must reproduce the objective value, bit for bit")
		#expect(identical(first.solution.toArray(), second.solution.toArray()), "Same seed must reproduce the solution, bit for bit")
		#expect(identical(first.bestStartingPoint.toArray(), second.bestStartingPoint.toArray()), "Same seed must draw the same starting points")
		#expect(identical(first.successRate, second.successRate), "Same seed must reproduce the success rate")
	}

	@Test("Same seed reproduces the synchronous protocol path")
	func testSameSeedReproducesSynchronousMinimize() throws {
		let start = VectorN([1.0, 1.0])

		let first = try Self.optimizer(seed: 777).minimize(Self.quadratic, from: start)
		let second = try Self.optimizer(seed: 777).minimize(Self.quadratic, from: start)

		#expect(identical(first.value, second.value), "Same seed must reproduce the objective value through the protocol method too")
		#expect(identical(first.solution.toArray(), second.solution.toArray()), "Same seed must reproduce the solution through the protocol method too")
	}

	// MARK: - A different seed is a different run

	@Test("Different seeds draw different starting points")
	func testDifferentSeedsDiverge() async throws {
		let first = try await Self.run(seed: 20260811)
		let second = try await Self.run(seed: 19991231)

		// `identical` rather than `!=`: `!=` reports a NaN as different from itself, so
		// this assertion would pass for free on a run that went non-finite — which is the
		// exact failure the unseeded starting points used to produce.
		#expect(!identical(first.bestStartingPoint.toArray(), second.bestStartingPoint.toArray()), "A different seed must draw different starting points")
		#expect(first.objectiveValue.isFinite, "The objective value must be a number, not a NaN that flatters the comparison above")
		#expect(second.objectiveValue.isFinite, "The objective value must be a number, not a NaN that flatters the comparison above")
	}

	// MARK: - The unseeded path is unchanged

	@Test("Omitting the seed leaves the optimizer unseeded and working")
	func testUnseededPathStillWorks() async throws {
		let unseeded = ParallelOptimizer<VectorN<Double>>(
			algorithm: .gradientDescent(learningRate: 0.05),
			numberOfStarts: 6,
			maxIterations: 200
		)

		#expect(unseeded.seed == nil, "The seed must default to nil, so existing callers keep the behaviour they had")

		let result = try await unseeded.optimize(
			objective: Self.quadratic,
			searchRegion: Self.searchRegion,
			constraints: []
		)

		#expect(result.objectiveValue.isFinite, "An unseeded run must still produce a finite result")
		#expect(approximatelyEqual(result.solution[0], 3.0, tolerance: 0.5), "An unseeded run must still find the optimum")
		#expect(approximatelyEqual(result.solution[1], 4.0, tolerance: 0.5), "An unseeded run must still find the optimum")
	}
}
