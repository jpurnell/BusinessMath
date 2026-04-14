//
//  MonteCarloIntegrationStressTests.swift
//  BusinessMath
//
//  Integration stress tests for the full Monte Carlo simulation pipeline.
//  Uses seeded RNG for reproducibility across CI runs.
//

import Foundation
import Testing
@testable import BusinessMath

// MARK: - Seeded RNG Helper

/// A simple seeded random number generator for reproducible stress tests.
/// Uses drand48/srand48 which are seeded globally.
/// Marked @unchecked Sendable because stress tests run serialized.
private final class SeededRNG: @unchecked Sendable {
    // Justification: Tests run serialized; no concurrent access to drand48 state.
    init(seed: Int) {
        srand48(seed)
    }

    /// Returns a uniform random Double in [0, 1).
    func nextDouble() -> Double {
        drand48()
    }

    /// Returns a uniform random Double in [low, high).
    func nextDouble(in range: ClosedRange<Double>) -> Double {
        let low = range.lowerBound
        let high = range.upperBound
        return low + (high - low) * drand48()
    }

    /// Returns a random Int in [low, high].
    func nextInt(in range: ClosedRange<Int>) -> Int {
        let low = range.lowerBound
        let high = range.upperBound
        guard high > low else { return low }
        return low + Int(drand48() * Double(high - low + 1))
    }
}

// MARK: - Tests

@Suite("Monte Carlo Integration Stress Tests", .serialized)
struct MonteCarloIntegrationStressTests {

    // MARK: - D.1.1: Randomized Distribution Types

    @Test("Randomized distribution types stress test - 100 iterations")
    func randomizedDistributionTypes() throws {
        let rng = SeededRNG(seed: 42)
        let simulationIterations = 1000

        for i in 0..<100 {
            // Randomly pick a distribution type: 0=Normal, 1=Uniform, 2=Triangular
            let distType = rng.nextInt(in: 0...2)

            let input: SimulationInput
            switch distType {
            case 0:
                // Normal: mean in [-1000, 1000], stdDev in [0.1, 500]
                let mean = rng.nextDouble(in: -1000...1000)
                let stdDev = rng.nextDouble(in: 0.1...500.0)
                input = SimulationInput(
                    name: "Input_\(i)",
                    distribution: DistributionNormal(mean, stdDev)
                )
            case 1:
                // Uniform: random min/max with min < max
                let a = rng.nextDouble(in: -1000...1000)
                let spread = rng.nextDouble(in: 0.1...1000.0)
                input = SimulationInput(
                    name: "Input_\(i)",
                    distribution: DistributionUniform(a, a + spread)
                )
            default:
                // Triangular: low < base < high
                let low = rng.nextDouble(in: -1000...0)
                let high = rng.nextDouble(in: 1.0...1000.0)
                let base = rng.nextDouble(in: low...high)
                input = SimulationInput(
                    name: "Input_\(i)",
                    distribution: DistributionTriangular(low: low, high: high, base: base)
                )
            }

            // Build and run a single-input simulation (identity model)
            var simulation = MonteCarloSimulation(iterations: simulationIterations, enableGPU: false) { inputs in
                inputs[0]
            }
            simulation.addInput(input)

            let results = try simulation.run()

            // Assert: all values finite
            for value in results.values {
                #expect(value.isFinite, "Non-finite value at stress iteration \(i)")
            }

            // Assert: variance >= 0
            #expect(results.statistics.variance >= 0,
                    "Negative variance at stress iteration \(i): \(results.statistics.variance)")

            // Assert: sample count matches
            #expect(results.values.count == simulationIterations,
                    "Expected \(simulationIterations) samples but got \(results.values.count) at iteration \(i)")
        }
    }

    // MARK: - D.1.2: Randomized Multi-Input Models

    @Test("Randomized multi-input models stress test - 50 iterations")
    func randomizedMultiInputModels() throws {
        let rng = SeededRNG(seed: 42)
        let simulationIterations = 1000

        for i in 0..<50 {
            // Random number of inputs: 2-4
            let inputCount = rng.nextInt(in: 2...4)

            // Random model type: 0=sum, 1=product, 2=difference (first - rest)
            let modelType = rng.nextInt(in: 0...2)

            let model: @Sendable ([Double]) -> Double
            switch modelType {
            case 0:
                model = { inputs in inputs.reduce(0.0, +) }
            case 1:
                model = { inputs in inputs.reduce(1.0, *) }
            default:
                model = { inputs in
                    guard let first = inputs.first else { return 0.0 }
                    return inputs.dropFirst().reduce(first, -)
                }
            }

            var simulation = MonteCarloSimulation(iterations: simulationIterations, enableGPU: false, model: model)

            // Add random inputs
            for j in 0..<inputCount {
                let distType = rng.nextInt(in: 0...2)
                let input: SimulationInput
                switch distType {
                case 0:
                    let mean = rng.nextDouble(in: 1.0...100.0)
                    let stdDev = rng.nextDouble(in: 0.1...10.0)
                    input = SimulationInput(
                        name: "Input_\(j)",
                        distribution: DistributionNormal(mean, stdDev)
                    )
                case 1:
                    let a = rng.nextDouble(in: 1.0...50.0)
                    let spread = rng.nextDouble(in: 0.1...50.0)
                    input = SimulationInput(
                        name: "Input_\(j)",
                        distribution: DistributionUniform(a, a + spread)
                    )
                default:
                    let low = rng.nextDouble(in: 1.0...10.0)
                    let high = rng.nextDouble(in: 20.0...100.0)
                    let base = rng.nextDouble(in: low...high)
                    input = SimulationInput(
                        name: "Input_\(j)",
                        distribution: DistributionTriangular(low: low, high: high, base: base)
                    )
                }
                simulation.addInput(input)
            }

            let results = try simulation.run()

            // Assert: all values finite
            for value in results.values {
                #expect(value.isFinite, "Non-finite value at multi-input iteration \(i)")
            }

            // Assert: statistics consistent (mean between min and max)
            #expect(results.statistics.mean >= results.statistics.min,
                    "Mean below min at iteration \(i)")
            #expect(results.statistics.mean <= results.statistics.max,
                    "Mean above max at iteration \(i)")

            // Assert: sample count matches
            #expect(results.values.count == simulationIterations)
        }
    }

    // MARK: - D.1.3: Edge Case Parameters

    @Test("Edge case parameters stress test - 10 cases")
    func edgeCaseParameters() throws {
        let simulationIterations = 1000

        struct EdgeCase {
            let name: String
            let input: SimulationInput
        }

        let edgeCases: [EdgeCase] = [
            // Very small stdDev
            EdgeCase(
                name: "Tiny stdDev (1e-10)",
                input: SimulationInput(name: "TinyStdDev", distribution: DistributionNormal(100.0, 1e-10))
            ),
            // Very large mean
            EdgeCase(
                name: "Large mean (1e10)",
                input: SimulationInput(name: "LargeMean", distribution: DistributionNormal(1e10, 1.0))
            ),
            // Very narrow uniform range
            EdgeCase(
                name: "Narrow uniform (0.001 range)",
                input: SimulationInput(name: "NarrowUniform", distribution: DistributionUniform(100.0, 100.001))
            ),
            // Very wide uniform range
            EdgeCase(
                name: "Wide uniform (1e8 range)",
                input: SimulationInput(name: "WideUniform", distribution: DistributionUniform(-1e8, 1e8))
            ),
            // Triangular with mode at low
            EdgeCase(
                name: "Triangular mode at low",
                input: SimulationInput(name: "TriLow", distribution: DistributionTriangular(low: 0.0, high: 100.0, base: 0.0))
            ),
            // Triangular with mode at high
            EdgeCase(
                name: "Triangular mode at high",
                input: SimulationInput(name: "TriHigh", distribution: DistributionTriangular(low: 0.0, high: 100.0, base: 100.0))
            ),
            // Very small values
            EdgeCase(
                name: "Small normal (mean=1e-10, stdDev=1e-12)",
                input: SimulationInput(name: "SmallNormal", distribution: DistributionNormal(1e-10, 1e-12))
            ),
            // Negative mean normal
            EdgeCase(
                name: "Negative mean (-1e6)",
                input: SimulationInput(name: "NegMean", distribution: DistributionNormal(-1e6, 100.0))
            ),
            // Triangular degenerate (low == mode == high)
            EdgeCase(
                name: "Degenerate triangular (all same)",
                input: SimulationInput(name: "DegenTri", distribution: DistributionTriangular(low: 50.0, high: 50.0, base: 50.0))
            ),
            // Large stdDev relative to mean
            EdgeCase(
                name: "Large stdDev (stdDev >> mean)",
                input: SimulationInput(name: "LargeStdDev", distribution: DistributionNormal(1.0, 1000.0))
            ),
        ]

        for edgeCase in edgeCases {
            var simulation = MonteCarloSimulation(iterations: simulationIterations, enableGPU: false) { inputs in
                inputs[0]
            }
            simulation.addInput(edgeCase.input)

            let results = try simulation.run()

            // Assert: no crashes (reaching here is success), all values finite
            for value in results.values {
                #expect(value.isFinite,
                        "Non-finite value in edge case '\(edgeCase.name)'")
            }

            // Assert: statistics are finite
            #expect(results.statistics.mean.isFinite,
                    "Non-finite mean in edge case '\(edgeCase.name)'")
            #expect(results.statistics.stdDev.isFinite,
                    "Non-finite stdDev in edge case '\(edgeCase.name)'")
            #expect(results.statistics.variance >= 0,
                    "Negative variance in edge case '\(edgeCase.name)'")
        }
    }
}
