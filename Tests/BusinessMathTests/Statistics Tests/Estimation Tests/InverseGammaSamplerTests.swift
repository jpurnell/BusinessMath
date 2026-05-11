import Testing
import Foundation
@testable import BusinessMath

@Suite("Inverse-Gamma Sampler")
struct InverseGammaSamplerTests {

    // MARK: - InverseGamma(3, 2): Mean within 5% of theoretical b/(a-1) = 1.0

    @Test("InverseGamma(3,2) sample mean approximates theoretical mean")
    func testInverseGammaMean() throws {
        let shape: Double = 3.0
        let scale: Double = 2.0
        let theoreticalMean = scale / (shape - 1.0) // 2.0 / 2.0 = 1.0
        let sampleCount = 50_000
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        for i in 0..<sampleCount {
            var idx = 0
            let value = try sampleInverseGamma(shape: shape, scale: scale, seeds: nil, seedIndex: &idx)
            samples.append(value)
        }

        let sampleMean = mean(samples)
        let relativeError = abs(sampleMean - theoreticalMean) / theoreticalMean
        #expect(relativeError < 0.05, "Sample mean \(sampleMean) not within 5% of theoretical \(theoreticalMean)")
    }

    // MARK: - InverseGamma(5, 4): Variance within 20% of theoretical

    @Test("InverseGamma(5,4) sample variance approximates theoretical variance")
    func testInverseGammaVariance() throws {
        // Use shape=5 for better convergence (more degrees of freedom than shape=3)
        let shape: Double = 5.0
        let scale: Double = 4.0
        // Theoretical mean = b/(a-1) = 4/4 = 1.0
        // Theoretical variance = b^2 / ((a-1)^2 * (a-2)) = 16 / (16 * 3) = 1/3
        let theoreticalVariance = (scale * scale) / ((shape - 1.0) * (shape - 1.0) * (shape - 2.0))
        let sampleCount = 50_000
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            var idx = 0
            let value = try sampleInverseGamma(shape: shape, scale: scale, seeds: nil, seedIndex: &idx)
            samples.append(value)
        }

        let sampleVar = varianceS(samples)
        let relativeError = abs(sampleVar - theoreticalVariance) / theoreticalVariance
        #expect(relativeError < 0.20, "Sample variance \(sampleVar) not within 20% of theoretical \(theoreticalVariance)")
    }

    // MARK: - All samples positive

    @Test("All Inverse-Gamma samples are positive")
    func testAllSamplesPositive() throws {
        let sampleCount = 10_000

        for _ in 0..<sampleCount {
            var idx = 0
            let value: Double = try sampleInverseGamma(shape: 3.0, scale: 2.0, seeds: nil, seedIndex: &idx)
            #expect(value > 0.0)
        }
    }

    // MARK: - Shape <= 0 throws

    @Test("Shape <= 0 throws invalidInput")
    func testNegativeShapeThrows() throws {
        var idx = 0
        #expect(throws: BusinessMathError.self) {
            let _: Double = try sampleInverseGamma(shape: 0.0, scale: 2.0, seeds: nil, seedIndex: &idx)
        }

        idx = 0
        #expect(throws: BusinessMathError.self) {
            let _: Double = try sampleInverseGamma(shape: -1.0, scale: 2.0, seeds: nil, seedIndex: &idx)
        }
    }

    // MARK: - Scale <= 0 throws

    @Test("Scale <= 0 throws invalidInput")
    func testNegativeScaleThrows() throws {
        var idx = 0
        #expect(throws: BusinessMathError.self) {
            let _: Double = try sampleInverseGamma(shape: 3.0, scale: 0.0, seeds: nil, seedIndex: &idx)
        }

        idx = 0
        #expect(throws: BusinessMathError.self) {
            let _: Double = try sampleInverseGamma(shape: 3.0, scale: -1.0, seeds: nil, seedIndex: &idx)
        }
    }

    // MARK: - Deterministic seeds produce consistent results

    @Test("Deterministic seeds produce repeatable results")
    func testDeterministicSeeds() throws {
        let seeds: [Double] = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.15]
        var idx1 = 0
        var idx2 = 0
        let val1: Double = try sampleInverseGamma(shape: 3.0, scale: 2.0, seeds: seeds, seedIndex: &idx1)
        let val2: Double = try sampleInverseGamma(shape: 3.0, scale: 2.0, seeds: seeds, seedIndex: &idx2)

        #expect(val1 == val2, "Same seeds should produce identical values")
    }
}
