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

	// MARK: - Differential evolution

	private static func runDE(populationSize: Int, seed: UInt64) -> (fitness: Double, solution: [Double]) {
		let optimizer = DifferentialEvolution<VectorN<Double>>(
			config: DifferentialEvolutionConfig(
				populationSize: populationSize,
				generations: 5,
				seed: seed
			),
			searchSpace: searchSpace
		)
		let result = optimizer.optimizeDetailed(objective: sphere)
		return (result.fitness, result.solution.toArray())
	}

	@Test("Differential evolution reproduces below the GPU threshold (population 999)")
	func deReproducesBelowThreshold() {
		let first = Self.runDE(populationSize: 999, seed: 4242)
		let second = Self.runDE(populationSize: 999, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness, bit for bit")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution, bit for bit")
	}

	@Test("Differential evolution reproduces at the GPU threshold (population 1000)")
	func deReproducesAtThreshold() {
		let first = Self.runDE(populationSize: 1000, seed: 4242)
		let second = Self.runDE(populationSize: 1000, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness on the GPU path too")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution on the GPU path too")
	}

	// MARK: - Particle swarm

	private static func runPSO(swarmSize: Int, seed: UInt64) -> (fitness: Double, solution: [Double]) {
		let optimizer = ParticleSwarmOptimization<VectorN<Double>>(
			config: ParticleSwarmConfig(
				swarmSize: swarmSize,
				maxIterations: 5,
				seed: seed
			),
			searchSpace: searchSpace
		)
		let result = optimizer.optimizeDetailed(objective: sphere)
		return (result.fitness, result.solution.toArray())
	}

	@Test("Particle swarm reproduces below the GPU threshold (swarm 999)")
	func psoReproducesBelowThreshold() {
		let first = Self.runPSO(swarmSize: 999, seed: 4242)
		let second = Self.runPSO(swarmSize: 999, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness, bit for bit")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution, bit for bit")
	}

	@Test("Particle swarm reproduces at the GPU threshold (swarm 1000)")
	func psoReproducesAtThreshold() {
		let first = Self.runPSO(swarmSize: 1000, seed: 4242)
		let second = Self.runPSO(swarmSize: 1000, seed: 4242)

		#expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness on the GPU path too")
		#expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution on the GPU path too")
	}
}
