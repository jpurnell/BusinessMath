//
//  HeuristicGPUSeedDeterminismTests.swift
//  BusinessMath
//
//  Differential evolution and particle swarm carry the same `seed` promise the genetic
//  algorithm does, and reach for the same GPU above the same threshold (population 1000,
//  `MetalDevice.shouldUseGPU(populationSize:)`). The determinism tests that existed
//  covered the genetic algorithm alone, so the identical defect in these two sat unseen:
//  each draws one seed per individual before the first operation that can fail, and an
//  abandoned GPU attempt left the generator advanced by those draws.
//
//  These cross the threshold deliberately — 999 and 1000 — because a determinism test
//  below it exercises the CPU implementation and reports on the API.
//
//  2.6.0 made the 1000 case pass by declining the GPU whenever a seed was set, which is
//  determinism bought by giving up the acceleration. `optimizeDetailed` now throws, so it
//  can refuse a broken promise instead of avoiding the possibility of one, and the seeded
//  cases below run on the GPU again. That makes the engagement assertions load-bearing:
//  without them the determinism tests would keep passing on the CPU while proving nothing
//  about the path they are named for.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

@Suite("Heuristic GPU Seed Determinism")
struct HeuristicGPUSeedDeterminismTests {

	/// Sphere function — smooth, unimodal, and cheap, so population size is the only
	/// thing that varies between the CPU and GPU cases below.
	private static let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

	private static let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

	// MARK: - The GPU case is not vacuous

	#if canImport(Metal)
	/// Every "at the threshold" test below is a CPU test on a machine whose Metal device
	/// declines the work, and would pass without exercising anything it claims to. Assert
	/// the precondition once, so that machine fails loudly here instead of quietly there.
	@Test("The GPU path is reachable at population 1000 on this machine")
	func gpuPathIsReachable() {
		#expect(
			MetalDevice.shouldUseGPU(populationSize: 1000),
			"no Metal device that takes work at population 1000: the seeded GPU tests below prove nothing here"
		)
	}
	#endif

	// MARK: - Differential evolution

	private static func makeDE(populationSize: Int, seed: UInt64) -> DifferentialEvolution<VectorN<Double>> {
		DifferentialEvolution<VectorN<Double>>(
			config: DifferentialEvolutionConfig(
				populationSize: populationSize,
				generations: 5,
				seed: seed
			),
			searchSpace: searchSpace
		)
	}

	private static func runDE(populationSize: Int, seed: UInt64) throws -> (fitness: Double, solution: [Double]) {
		let optimizer = makeDE(populationSize: populationSize, seed: seed)
		let result = try optimizer.optimizeDetailed(objective: sphere)
		return (result.fitness, result.solution.toArray())
	}

	#if canImport(Metal)
	/// The interim this replaces: a seed sent the run to the CPU, whatever its size.
	@Test("A seeded differential evolution run at the threshold still reaches for the GPU")
	func deSeededRunReachesForGPU() {
		let seeded = Self.makeDE(populationSize: 1000, seed: 4242)

		#expect(seeded.shouldUseGPU(), "a seed must no longer cost the acceleration")
	}
	#endif

	@Test("Differential evolution reproduces below the GPU threshold (population 999)")
	func deReproducesBelowThreshold() throws {
		let first = try Self.runDE(populationSize: 999, seed: 4242)
		let second = try Self.runDE(populationSize: 999, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness, bit for bit")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution, bit for bit")
	}

	@Test("Differential evolution reproduces at the GPU threshold (population 1000)")
	func deReproducesAtThreshold() throws {
		let first = try Self.runDE(populationSize: 1000, seed: 4242)
		let second = try Self.runDE(populationSize: 1000, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness on the GPU path too")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution on the GPU path too")
	}

	@Test("Differential evolution reproduces above the GPU threshold (population 1200)")
	func deReproducesAboveThreshold() throws {
		let first = try Self.runDE(populationSize: 1200, seed: 909)
		let second = try Self.runDE(populationSize: 1200, seed: 909)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness above the threshold")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution above the threshold")
	}

	/// `identical` rather than `!=` on purpose: `!=` reports a NaN as different from
	/// itself, so this would pass for free if either stream went non-finite.
	@Test("Different differential evolution seeds diverge on the GPU path")
	func deDifferentSeedsDivergeAtThreshold() throws {
		let first = try Self.runDE(populationSize: 1000, seed: 4242)
		let second = try Self.runDE(populationSize: 1000, seed: 8484)

		#expect(!identical(first.fitness, second.fitness), "A different seed must be a different run")
		#expect(first.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
		#expect(second.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
	}

	// MARK: - Particle swarm

	private static func makePSO(swarmSize: Int, seed: UInt64) -> ParticleSwarmOptimization<VectorN<Double>> {
		ParticleSwarmOptimization<VectorN<Double>>(
			config: ParticleSwarmConfig(
				swarmSize: swarmSize,
				maxIterations: 5,
				seed: seed
			),
			searchSpace: searchSpace
		)
	}

	private static func runPSO(swarmSize: Int, seed: UInt64) throws -> (fitness: Double, solution: [Double]) {
		let optimizer = makePSO(swarmSize: swarmSize, seed: seed)
		let result = try optimizer.optimizeDetailed(objective: sphere)
		return (result.fitness, result.solution.toArray())
	}

	#if canImport(Metal)
	@Test("A seeded particle swarm run at the threshold still reaches for the GPU")
	func psoSeededRunReachesForGPU() {
		let seeded = Self.makePSO(swarmSize: 1000, seed: 4242)

		#expect(seeded.shouldUseGPU(), "a seed must no longer cost the acceleration")
	}
	#endif

	@Test("Particle swarm reproduces below the GPU threshold (swarm 999)")
	func psoReproducesBelowThreshold() throws {
		let first = try Self.runPSO(swarmSize: 999, seed: 4242)
		let second = try Self.runPSO(swarmSize: 999, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness, bit for bit")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution, bit for bit")
	}

	@Test("Particle swarm reproduces at the GPU threshold (swarm 1000)")
	func psoReproducesAtThreshold() throws {
		let first = try Self.runPSO(swarmSize: 1000, seed: 4242)
		let second = try Self.runPSO(swarmSize: 1000, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness on the GPU path too")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution on the GPU path too")
	}

	@Test("Particle swarm reproduces above the GPU threshold (swarm 1200)")
	func psoReproducesAboveThreshold() throws {
		let first = try Self.runPSO(swarmSize: 1200, seed: 909)
		let second = try Self.runPSO(swarmSize: 1200, seed: 909)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness above the threshold")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution above the threshold")
	}

	@Test("Different particle swarm seeds diverge on the GPU path")
	func psoDifferentSeedsDivergeAtThreshold() throws {
		let first = try Self.runPSO(swarmSize: 1000, seed: 4242)
		let second = try Self.runPSO(swarmSize: 1000, seed: 8484)

		#expect(!identical(first.fitness, second.fitness), "A different seed must be a different run")
		#expect(first.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
		#expect(second.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
	}
}
