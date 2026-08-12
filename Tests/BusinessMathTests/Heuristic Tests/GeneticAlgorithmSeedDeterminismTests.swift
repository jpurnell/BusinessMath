//
//  GeneticAlgorithmSeedDeterminismTests.swift
//  BusinessMath
//
//  `GeneticAlgorithmConfig.seed` is one promise, and it has to hold on both sides of the
//  GPU threshold. The GPU path engages at `populationSize >= 1000`, so a determinism test
//  that only runs a small population tests the CPU implementation and reports on the API.
//  These cross the threshold deliberately: 999 and 1000, same seed, same claim.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

@Suite("Genetic Algorithm Seed Determinism")
struct GeneticAlgorithmSeedDeterminismTests {

    /// Sphere function — smooth, unimodal, and cheap, so the population size is the
    /// only thing that varies between the CPU and GPU cases below.
    private static let sphere: @Sendable (VectorN<Double>) -> Double = { v in v.dot(v) }

    private static let searchSpace = [(-10.0, 10.0), (-10.0, 10.0)]

    /// Run a genetic algorithm once and return the numbers a caller would compare.
    private static func run(populationSize: Int, seed: UInt64) throws -> (fitness: Double, solution: [Double]) {
        let optimizer = GeneticAlgorithm<VectorN<Double>>(
            config: GeneticAlgorithmConfig(
                populationSize: populationSize,
                generations: 5,
                seed: seed
            ),
            searchSpace: searchSpace
        )
        let result = try optimizer.optimizeDetailed(objective: sphere)
        return (result.fitness, result.solution.toArray())
    }

    // MARK: - Below the GPU threshold

    @Test("Same seed reproduces below the GPU threshold (population 999)")
    func testSeededReproducibilityBelowThreshold() throws {
        let first = try Self.run(populationSize: 999, seed: 4242)
        let second = try Self.run(populationSize: 999, seed: 4242)

        #expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness, bit for bit")
        #expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution, bit for bit")
    }

    // MARK: - At and above the GPU threshold

    @Test("Same seed reproduces at the GPU threshold (population 1000)")
    func testSeededReproducibilityAtThreshold() throws {
        let first = try Self.run(populationSize: 1000, seed: 4242)
        let second = try Self.run(populationSize: 1000, seed: 4242)

        #expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness on the GPU path too")
        #expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution on the GPU path too")
    }

    @Test("Same seed reproduces above the GPU threshold (population 1200)")
    func testSeededReproducibilityAboveThreshold() throws {
        let first = try Self.run(populationSize: 1200, seed: 909)
        let second = try Self.run(populationSize: 1200, seed: 909)

        #expect(identical(first.fitness, second.fitness), "Same seed must reproduce the same fitness above the threshold")
        #expect(identical(first.solution, second.solution), "Same seed must reproduce the same solution above the threshold")
    }

    // MARK: - A different seed is a different run

    @Test("Different seeds diverge on the GPU path")
    func testDifferentSeedsDivergeAtThreshold() throws {
        let first = try Self.run(populationSize: 1000, seed: 4242)
        let second = try Self.run(populationSize: 1000, seed: 8484)

        // `identical` rather than `!=` on purpose: `!=` reports a NaN as different from
        // itself, so this assertion would pass for free if either stream went non-finite.
        #expect(!identical(first.fitness, second.fitness), "A different seed must be a different run")
        #expect(first.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
        #expect(second.fitness.isFinite, "Fitness must be a number, not a NaN that flatters the comparison above")
    }
}
