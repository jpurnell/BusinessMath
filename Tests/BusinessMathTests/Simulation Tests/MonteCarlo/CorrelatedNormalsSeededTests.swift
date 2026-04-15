//
//  CorrelatedNormalsSeededTests.swift
//  BusinessMath
//
//  Tests for deterministic seeded sampling via sample(using:).
//

import Foundation
import Testing
import Numerics

@testable import BusinessMath

@Suite("CorrelatedNormals Seeded Sampling", .serialized)
struct CorrelatedNormalsSeededTests {

    // MARK: - Deterministic Reproducibility

    @Test("Same seed produces identical samples")
    func deterministicReproducibility() throws {
        let means = [0.0, 0.0]
        let correlationMatrix = [
            [1.0, 0.5],
            [0.5, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        // Run 1
        var rng1 = DeterministicRNG(seed: 42)
        var samples1: [[Double]] = []
        for _ in 0..<100 {
            samples1.append(correlated.sample(using: &rng1))
        }

        // Run 2 with same seed
        var rng2 = DeterministicRNG(seed: 42)
        var samples2: [[Double]] = []
        for _ in 0..<100 {
            samples2.append(correlated.sample(using: &rng2))
        }

        // Every sample must be identical
        for i in 0..<100 {
            for j in 0..<2 {
                #expect(samples1[i][j] == samples2[i][j],
                        "Sample [\(i)][\(j)] must be identical with same seed")
            }
        }
    }

    @Test("Different seeds produce different samples")
    func differentSeedsDiffer() throws {
        let means = [0.0, 0.0]
        let correlationMatrix = [
            [1.0, 0.5],
            [0.5, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng1 = DeterministicRNG(seed: 42)
        let sample1 = correlated.sample(using: &rng1)

        var rng2 = DeterministicRNG(seed: 99)
        let sample2 = correlated.sample(using: &rng2)

        let differ = (sample1[0] != sample2[0]) || (sample1[1] != sample2[1])
        #expect(differ, "Different seeds should produce different samples")
    }

    // MARK: - Correlation Fidelity

    @Test("Seeded sampling preserves positive correlation")
    func seededPositiveCorrelation() throws {
        let means = [0.0, 0.0]
        let targetCorr = 0.7
        let correlationMatrix = [
            [1.0, targetCorr],
            [targetCorr, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        var s1: [Double] = []
        var s2: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            s1.append(sample[0])
            s2.append(sample[1])
        }

        let empiricalCorr = try correlationCoefficient(s1, s2)
        #expect(abs(empiricalCorr - targetCorr) < 0.05,
                "Empirical correlation \(empiricalCorr) should be within 0.05 of target \(targetCorr)")
    }

    @Test("Seeded sampling preserves negative correlation")
    func seededNegativeCorrelation() throws {
        let means = [0.0, 0.0]
        let targetCorr = -0.6
        let correlationMatrix = [
            [1.0, targetCorr],
            [targetCorr, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 77)
        var s1: [Double] = []
        var s2: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            s1.append(sample[0])
            s2.append(sample[1])
        }

        let empiricalCorr = try correlationCoefficient(s1, s2)
        #expect(abs(empiricalCorr - targetCorr) < 0.05,
                "Empirical correlation \(empiricalCorr) should be within 0.05 of target \(targetCorr)")
    }

    @Test("Seeded sampling preserves zero correlation (independence)")
    func seededZeroCorrelation() throws {
        let means = [0.0, 0.0]
        let correlationMatrix = [
            [1.0, 0.0],
            [0.0, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        var s1: [Double] = []
        var s2: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            s1.append(sample[0])
            s2.append(sample[1])
        }

        let empiricalCorr = try correlationCoefficient(s1, s2)
        #expect(abs(empiricalCorr) < 0.05,
                "Correlation should be near zero, got \(empiricalCorr)")
    }

    // MARK: - Mean and Variance

    @Test("Seeded sampling produces correct means")
    func seededMeans() throws {
        let means = [100.0, -50.0]
        let correlationMatrix = [
            [1.0, 0.3],
            [0.3, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        var s1: [Double] = []
        var s2: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            s1.append(sample[0])
            s2.append(sample[1])
        }

        let mean1 = s1.reduce(0, +) / Double(s1.count)
        let mean2 = s2.reduce(0, +) / Double(s2.count)

        #expect(abs(mean1 - 100.0) < 1.0, "Mean1 should be close to 100, got \(mean1)")
        #expect(abs(mean2 - (-50.0)) < 1.0, "Mean2 should be close to -50, got \(mean2)")
    }

    @Test("Seeded sampling produces unit variance with identity correlation")
    func seededVariance() throws {
        let means = [0.0, 0.0]
        let correlationMatrix = [
            [1.0, 0.0],
            [0.0, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        var samples: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            samples.append(sample[0])
        }

        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count - 1)

        #expect(abs(variance - 1.0) < 0.1, "Variance should be close to 1.0, got \(variance)")
    }

    // MARK: - Three Variables

    @Test("Seeded three-variable correlation fidelity")
    func seededThreeVariables() throws {
        let means = [0.0, 0.0, 0.0]
        let correlationMatrix = [
            [1.0, 0.5, 0.3],
            [0.5, 1.0, 0.4],
            [0.3, 0.4, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        var s1: [Double] = []
        var s2: [Double] = []
        var s3: [Double] = []

        for _ in 0..<10_000 {
            let sample = correlated.sample(using: &rng)
            s1.append(sample[0])
            s2.append(sample[1])
            s3.append(sample[2])
        }

        let c12 = try correlationCoefficient(s1, s2)
        let c13 = try correlationCoefficient(s1, s3)
        let c23 = try correlationCoefficient(s2, s3)

        #expect(abs(c12 - 0.5) < 0.05, "Corr(1,2) should be ~0.5, got \(c12)")
        #expect(abs(c13 - 0.3) < 0.05, "Corr(1,3) should be ~0.3, got \(c13)")
        #expect(abs(c23 - 0.4) < 0.05, "Corr(2,3) should be ~0.4, got \(c23)")
    }

    // MARK: - Edge Cases

    @Test("Seeded single variable (1D)")
    func seededSingleVariable() throws {
        let means = [5.0]
        let corr = [[1.0]]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: corr)

        var rng = DeterministicRNG(seed: 42)
        var samples: [Double] = []
        for _ in 0..<5_000 {
            samples.append(correlated.sample(using: &rng)[0])
        }

        let mean = samples.reduce(0, +) / Double(samples.count)
        #expect(abs(mean - 5.0) < 0.2, "Mean should be close to 5, got \(mean)")
    }

    @Test("Seeded sample has correct dimension")
    func seededDimension() throws {
        let means = [10.0, 20.0, 30.0, 40.0]
        let correlationMatrix = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ]
        let correlated = try CorrelatedNormals(means: means, correlationMatrix: correlationMatrix)

        var rng = DeterministicRNG(seed: 42)
        let sample = correlated.sample(using: &rng)

        #expect(sample.count == 4, "Sample should have 4 dimensions")
    }
}

// MARK: - DeterministicRNG Tests

@Suite("DeterministicRNG")
struct DeterministicRNGTests {

    @Test("Same seed produces identical sequence")
    func reproducibility() {
        var rng1 = DeterministicRNG(seed: 42)
        var rng2 = DeterministicRNG(seed: 42)

        for _ in 0..<100 {
            #expect(rng1.next() == rng2.next())
        }
    }

    @Test("Different seeds produce different sequences")
    func differentSeeds() {
        var rng1 = DeterministicRNG(seed: 42)
        var rng2 = DeterministicRNG(seed: 99)

        #expect(rng1.next() != rng2.next())
    }

    @Test("Conforms to RandomNumberGenerator — usable with Double.random")
    func conformsToProtocol() {
        var rng = DeterministicRNG(seed: 42)
        let val1 = Double.random(in: 0..<1, using: &rng)
        let val2 = Double.random(in: 0..<1, using: &rng)

        // Both should be in range
        #expect(val1 >= 0.0 && val1 < 1.0)
        #expect(val2 >= 0.0 && val2 < 1.0)

        // Deterministic: reset and verify same values
        var rng2 = DeterministicRNG(seed: 42)
        let val1b = Double.random(in: 0..<1, using: &rng2)
        let val2b = Double.random(in: 0..<1, using: &rng2)

        #expect(val1 == val1b)
        #expect(val2 == val2b)
    }

    @Test("Generates values across full UInt64 range")
    func fullRange() {
        var rng = DeterministicRNG(seed: 42)
        var hasHigh = false
        var hasLow = false

        for _ in 0..<1000 {
            let val = rng.next()
            if val > UInt64.max / 2 { hasHigh = true }
            if val < UInt64.max / 2 { hasLow = true }
        }

        #expect(hasHigh, "Should produce values in upper half of UInt64 range")
        #expect(hasLow, "Should produce values in lower half of UInt64 range")
    }
}
