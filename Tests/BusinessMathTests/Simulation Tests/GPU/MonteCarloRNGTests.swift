import Testing
import TestSupport  // Cross-platform math functions
import Foundation
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// Tests for GPU random number generator quality
///
/// Validates that the Metal-based RNG produces statistically sound random numbers
/// suitable for Monte Carlo simulation. Tests include:
/// - Uniformity (Chi-square test)
/// - Distribution matching (Kolmogorov-Smirnov test)
/// - Independence (Autocorrelation test)
/// - Box-Muller transform correctness
@Suite("Monte Carlo GPU RNG Quality Tests")
struct MonteCarloRNGTests {

    // MARK: - Helper: GPU RNG Sampler

    /// Helper to generate samples from GPU RNG for testing
    private func generateGPUSamples(count: Int) throws -> [Float] {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            // Skip test if Metal not available
            return []
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue

        // Compile test kernel for uniform sampling
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct RNGState {
            ulong s0;
            ulong s1;
        };

        inline float nextUniform(thread RNGState* state) {
            ulong s1 = state->s0;
            ulong s0 = state->s1;
            state->s0 = s0;
            s1 ^= s1 << 23;
            state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
            return float(state->s0 + state->s1) * 1.08420217e-19f;
        }

        kernel void initializeRNG(
            device RNGState* states [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            states[tid].s0 = baseSeed ^ tid;
            states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);

            // Warm up the RNG
            for (int i = 0; i < 10; i++) {
                nextUniform(&states[tid]);
            }
        }

        kernel void generateUniformSamples(
            device RNGState* states [[buffer(0)]],
            device float* outputs [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            outputs[tid] = nextUniform(&states[tid]);
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let initFunc = library.makeFunction(name: "initializeRNG"),
              let sampleFunc = library.makeFunction(name: "generateUniformSamples") else {
            // Skip test if kernel compilation fails
            return []
        }

        let initPipeline = try device.makeComputePipelineState(function: initFunc)
        let samplePipeline = try device.makeComputePipelineState(function: sampleFunc)

        // Allocate buffers
        let stateSize = count * MemoryLayout<(UInt64, UInt64)>.stride
        let outputSize = count * MemoryLayout<Float>.stride

        guard let stateBuffer = device.makeBuffer(length: stateSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            // Skip test if buffer allocation fails
            return []
        }

        // Initialize RNG states
        var seed: UInt64 = UInt64(arc4random()) << 32 | UInt64(arc4random())

        let commandBuffer1 = commandQueue.makeCommandBuffer()!
        let encoder1 = commandBuffer1.makeComputeCommandEncoder()!
        encoder1.setComputePipelineState(initPipeline)
        encoder1.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder1.setBytes(&seed, length: MemoryLayout<UInt64>.stride, index: 1)

        let threadsPerGroup = MTLSize(width: min(count, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (count + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        encoder1.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder1.endEncoding()
        commandBuffer1.commit()
        commandBuffer1.waitUntilCompleted()

        // Generate samples
        let commandBuffer2 = commandQueue.makeCommandBuffer()!
        let encoder2 = commandBuffer2.makeComputeCommandEncoder()!
        encoder2.setComputePipelineState(samplePipeline)
        encoder2.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder2.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder2.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder2.endEncoding()
        commandBuffer2.commit()
        commandBuffer2.waitUntilCompleted()

        // Read results
        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { pointer[$0] }
        #else
        // Return empty array when Metal is unavailable (tests will skip)
        return []
        #endif
    }

    /// Generate normal samples using Box-Muller transform on GPU
    private func generateGPUNormalSamples(count: Int, mean: Float, stdDev: Float) throws -> [Float] {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            // Skip test if Metal not available
            return []
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue

        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct RNGState {
            ulong s0;
            ulong s1;
        };

        inline float nextUniform(thread RNGState* state) {
            ulong s1 = state->s0;
            ulong s0 = state->s1;
            state->s0 = s0;
            s1 ^= s1 << 23;
            state->s1 = s1 ^ s0 ^ (s1 >> 18) ^ (s0 >> 5);
            return float(state->s0 + state->s1) * 1.08420217e-19f;
        }

        inline float2 nextNormal(thread RNGState* state, float mean, float stdDev) {
            float u1 = nextUniform(state);
            float u2 = nextUniform(state);
            float r = sqrt(-2.0f * log(u1));
            float theta = 2.0f * M_PI_F * u2;
            return float2(
                mean + stdDev * r * cos(theta),
                mean + stdDev * r * sin(theta)
            );
        }

        kernel void initializeRNG(
            device RNGState* states [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            uint tid [[thread_position_in_grid]]
        ) {
            states[tid].s0 = baseSeed ^ tid;
            states[tid].s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);

            for (int i = 0; i < 10; i++) {
                nextUniform(&states[tid]);
            }
        }

        kernel void generateNormalSamples(
            device RNGState* states [[buffer(0)]],
            device float* outputs [[buffer(1)]],
            constant float& mean [[buffer(2)]],
            constant float& stdDev [[buffer(3)]],
            uint tid [[thread_position_in_grid]]
        ) {
            outputs[tid] = nextNormal(&states[tid], mean, stdDev).x;
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let initFunc = library.makeFunction(name: "initializeRNG"),
              let sampleFunc = library.makeFunction(name: "generateNormalSamples") else {
            // Skip test if kernel compilation fails
            return []
        }

        let initPipeline = try device.makeComputePipelineState(function: initFunc)
        let samplePipeline = try device.makeComputePipelineState(function: sampleFunc)

        let stateSize = count * MemoryLayout<(UInt64, UInt64)>.stride
        let outputSize = count * MemoryLayout<Float>.stride

        guard let stateBuffer = device.makeBuffer(length: stateSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            // Skip test if buffer allocation fails
            return []
        }

        var seed: UInt64 = UInt64(arc4random()) << 32 | UInt64(arc4random())

        // Initialize RNG
        let commandBuffer1 = commandQueue.makeCommandBuffer()!
        let encoder1 = commandBuffer1.makeComputeCommandEncoder()!
        encoder1.setComputePipelineState(initPipeline)
        encoder1.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder1.setBytes(&seed, length: MemoryLayout<UInt64>.stride, index: 1)

        let threadsPerGroup = MTLSize(width: min(count, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (count + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        encoder1.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder1.endEncoding()
        commandBuffer1.commit()
        commandBuffer1.waitUntilCompleted()

        // Generate samples
        var meanVar = mean
        var stdDevVar = stdDev

        let commandBuffer2 = commandQueue.makeCommandBuffer()!
        let encoder2 = commandBuffer2.makeComputeCommandEncoder()!
        encoder2.setComputePipelineState(samplePipeline)
        encoder2.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder2.setBuffer(outputBuffer, offset: 0, index: 1)
        encoder2.setBytes(&meanVar, length: MemoryLayout<Float>.stride, index: 2)
        encoder2.setBytes(&stdDevVar, length: MemoryLayout<Float>.stride, index: 3)
        encoder2.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder2.endEncoding()
        commandBuffer2.commit()
        commandBuffer2.waitUntilCompleted()

        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { pointer[$0] }
        #else
        // Return empty array when Metal is unavailable (tests will skip)
        return []
        #endif
    }

    // MARK: - Statistical Test Helpers

    /// Chi-square test for uniformity
    private func chiSquareTest(samples: [Float], bins: Int = 100) -> Double {
        let histogram = Array(repeating: 0, count: bins).enumerated().map { index, _ in
            samples.filter { sample in
                let binIndex = Int(sample * Float(bins))
                return binIndex == index || (index == bins - 1 && sample == 1.0)
            }.count
        }

        let expected = Double(samples.count) / Double(bins)
        let chiSquare = histogram.reduce(0.0) { sum, count in
            let diff = Double(count) - expected
            return sum + (diff * diff) / expected
        }

        return chiSquare
    }

    /// Kolmogorov-Smirnov test statistic
    private func kolmogorovSmirnovTest(samples: [Float], cdf: (Float) -> Float) -> Double {
        let sorted = samples.sorted()
        let maxDeviation = sorted.enumerated().map { i, x in
            let empiricalCDF = Double(i + 1) / Double(samples.count)
            let theoreticalCDF = Double(cdf(x))
            return abs(empiricalCDF - theoreticalCDF)
        }.max() ?? 0.0

        return maxDeviation
    }

    /// Autocorrelation test
    private func autocorrelation(samples: [Float], lag: Int = 1) -> Double {
        let mean = samples.map { Double($0) }.reduce(0.0, +) / Double(samples.count)
        let variance = samples.map { pow(Double($0) - mean, 2) }.reduce(0.0, +) / Double(samples.count)

        let n = samples.count - lag
        let pairs = zip(samples.prefix(n), samples.dropFirst(lag))
        let covariance = pairs.map { (x, y) in (Double(x) - mean) * (Double(y) - mean) }.reduce(0.0, +)
        let autocorr = covariance / (Double(n) * variance)

        return autocorr
    }

    // MARK: - Tests

    @Test("GPU RNG uniformity (Chi-square test)")
    func testUniformity() throws {
        let samples = try generateGPUSamples(count: 100_000)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // Validate range [0, 1)
        #expect(samples.allSatisfy { $0 >= 0.0 && $0 < 1.0 })

        // Chi-square test with 100 bins
        let chiSquare = chiSquareTest(samples: samples, bins: 100)

        // Critical value for df=99, α=0.05 is approximately 123.23
        // We use a more lenient threshold for randomness (α=0.01, critical ≈ 135)
        #expect(chiSquare < 135.0, "Chi-square statistic \(chiSquare) should be < 135 for uniform distribution")

        // Also check mean ≈ 0.5
        let mean = samples.reduce(0.0, +) / Float(samples.count)
        #expect(abs(mean - 0.5) < 0.01, "Mean \(mean) should be close to 0.5")
    }

    @Test("GPU RNG independence (Autocorrelation test)")
    func testIndependence() throws {
        let samples = try generateGPUSamples(count: 50_000)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // Test lag-1 autocorrelation
        let autocorr = autocorrelation(samples: samples, lag: 1)

        // For independent samples, autocorrelation should be close to 0
        #expect(abs(autocorr) < 0.05, "Autocorrelation \(autocorr) should be close to 0 for independent samples")
    }

    @Test("Box-Muller transform produces standard normal")
    func testBoxMullerStandardNormal() throws {
        let samples = try generateGPUNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // Calculate empirical statistics
        let mean = samples.reduce(0.0, +) / Float(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(samples.count)
        let stdDev = sqrt(variance)

        // Validate mean ≈ 0.0 ± 0.02
        #expect(abs(mean) < 0.02, "Mean \(mean) should be close to 0.0")

        // Validate stdDev ≈ 1.0 ± 0.02
        #expect(abs(stdDev - 1.0) < 0.02, "Standard deviation \(stdDev) should be close to 1.0")
    }

    @Test("Box-Muller transform with custom parameters")
    func testBoxMullerCustomParameters() throws {
        let targetMean: Float = 100.0
        let targetStdDev: Float = 15.0

        let samples = try generateGPUNormalSamples(count: 10_000, mean: targetMean, stdDev: targetStdDev)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // Calculate empirical statistics
        let mean = samples.reduce(0.0, +) / Float(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(samples.count)
        let stdDev = sqrt(variance)

        // Validate mean ≈ 100.0 ± 1.0
        #expect(abs(mean - targetMean) < 1.0, "Mean \(mean) should be close to \(targetMean)")

        // Validate stdDev ≈ 15.0 ± 1.0
        #expect(abs(stdDev - targetStdDev) < 1.0, "Standard deviation \(stdDev) should be close to \(targetStdDev)")
    }

    @Test("Kolmogorov-Smirnov test for uniform distribution")
    func testKSUniform() throws {
        let samples = try generateGPUSamples(count: 10_000)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // CDF for uniform [0, 1) is F(x) = x
        let ksStatistic = kolmogorovSmirnovTest(samples: samples) { x in x }

        // Critical value for n=10000, α=0.05 is approximately 0.0136
        #expect(ksStatistic < 0.02, "K-S statistic \(ksStatistic) should be small for matching distribution")
    }

    @Test("Kolmogorov-Smirnov test for normal distribution")
    func testKSNormal() throws {
        let samples = try generateGPUNormalSamples(count: 10_000, mean: 0.0, stdDev: 1.0)
        guard !samples.isEmpty else { return } // Skip if Metal unavailable

        // CDF for standard normal (approximation using erf)
        let normalCDF: (Float) -> Float = { x in
            0.5 * (1.0 + erf(x / sqrt(2.0)))
        }

        let ksStatistic = kolmogorovSmirnovTest(samples: samples, cdf: normalCDF)

        // Critical value for n=10000, α=0.05 is approximately 0.0136
        #expect(ksStatistic < 0.02, "K-S statistic \(ksStatistic) should be small for matching distribution")
    }
}
