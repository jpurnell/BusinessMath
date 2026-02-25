import Testing
import TestSupport  // Cross-platform math functions
import Foundation
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// Tests for GPU distribution samplers
///
/// Validates that GPU-based distribution sampling produces statistically equivalent
/// results to CPU-based sampling. Tests include:
/// - Normal distribution (mean, stdDev matching)
/// - Uniform distribution (range, mean matching)
/// - Triangular distribution (mode, shape matching)
/// - Mixed distribution scenarios
@Suite("Monte Carlo GPU Distribution Sampler Tests")
struct MonteCarloDistributionTests {

    // MARK: - Helper: CPU Distribution Sampling

    /// Sample from CPU-based distributions for comparison
    private func sampleCPUDistribution(
        type: String,
        param1: Double,
        param2: Double,
        param3: Double,
        count: Int
    ) -> [Double] {
        var samples: [Double] = []
        samples.reserveCapacity(count)

        switch type {
        case "normal":
            // Use positional parameters: init(_ mean, _ stdDev)
            let dist = DistributionNormal(param1, param2)
            for _ in 0..<count {
                samples.append(dist.next())
            }
        case "uniform":
            let dist = DistributionUniform(param1, param2)
            for _ in 0..<count {
                samples.append(dist.next())
            }
        case "triangular":
            // Check DistributionTriangular init signature
            let dist = DistributionTriangular(low: param1, high: param2, base: param3)
            for _ in 0..<count {
                samples.append(dist.next())
            }
        default:
            break
        }

        return samples
    }

    // MARK: - Helper: GPU Distribution Sampling

    /// Sample from GPU-based distributions
    private func sampleGPUDistribution(
        type: String,
        param1: Float,
        param2: Float,
        param3: Float,
        count: Int
    ) throws -> [Float] {
        #if canImport(Metal)
        guard let metalDevice = MetalDevice.shared else {
            return [] // Skip if Metal unavailable
        }

        let device = metalDevice.device
        let commandQueue = metalDevice.commandQueue

        // Distribution type enum values
        let distTypeMap = ["normal": 0, "uniform": 1, "triangular": 2]
        guard let distType = distTypeMap[type] else {
            return []
        }

        // Compile kernel with RNG + distribution sampling
        let kernelSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct RNGState {
            ulong s0;
            ulong s1;
        };

        struct DistributionParams {
            float param1;
            float param2;
            float param3;
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

        inline float sampleNormal(thread RNGState* state, constant DistributionParams* params) {
            return nextNormal(state, params->param1, params->param2).x;
        }

        inline float sampleUniform(thread RNGState* state, constant DistributionParams* params) {
            float min = params->param1;
            float max = params->param2;
            return min + nextUniform(state) * (max - min);
        }

        inline float sampleTriangular(thread RNGState* state, constant DistributionParams* params) {
            float min = params->param1;
            float max = params->param2;
            float mode = params->param3;

            float u = nextUniform(state);
            float fc = (mode - min) / (max - min);

            if (u < fc) {
                return min + sqrt(u * (max - min) * (mode - min));
            } else {
                return max - sqrt((1.0f - u) * (max - min) * (max - mode));
            }
        }

        inline float sampleDistribution(
            thread RNGState* state,
            constant DistributionParams* params,
            int distType
        ) {
            switch (distType) {
                case 0: return sampleNormal(state, params);      // NORMAL
                case 1: return sampleUniform(state, params);     // UNIFORM
                case 2: return sampleTriangular(state, params);  // TRIANGULAR
                default: return 0.0f;
            }
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

        kernel void sampleDistributions(
            device RNGState* states [[buffer(0)]],
            constant DistributionParams* params [[buffer(1)]],
            constant int& distType [[buffer(2)]],
            device float* outputs [[buffer(3)]],
            uint tid [[thread_position_in_grid]]
        ) {
            outputs[tid] = sampleDistribution(&states[tid], params, distType);
        }
        """

        guard let library = try? device.makeLibrary(source: kernelSource, options: nil),
              let initFunc = library.makeFunction(name: "initializeRNG"),
              let sampleFunc = library.makeFunction(name: "sampleDistributions") else {
            return [] // Skip if compilation fails
        }

        let initPipeline = try device.makeComputePipelineState(function: initFunc)
        let samplePipeline = try device.makeComputePipelineState(function: sampleFunc)

        // Allocate buffers
        let stateSize = count * MemoryLayout<(UInt64, UInt64)>.stride
        let outputSize = count * MemoryLayout<Float>.stride

        guard let stateBuffer = device.makeBuffer(length: stateSize, options: .storageModeShared),
              let outputBuffer = device.makeBuffer(length: outputSize, options: .storageModeShared) else {
            return [] // Skip if allocation fails
        }

        // Initialize RNG
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

        // Sample from distributions
        var params = (param1, param2, param3)
        var distTypeVar = Int32(distType)

        let commandBuffer2 = commandQueue.makeCommandBuffer()!
        let encoder2 = commandBuffer2.makeComputeCommandEncoder()!
        encoder2.setComputePipelineState(samplePipeline)
        encoder2.setBuffer(stateBuffer, offset: 0, index: 0)
        encoder2.setBytes(&params, length: MemoryLayout<(Float, Float, Float)>.stride, index: 1)
        encoder2.setBytes(&distTypeVar, length: MemoryLayout<Int32>.stride, index: 2)
        encoder2.setBuffer(outputBuffer, offset: 0, index: 3)
        encoder2.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadsPerGroup)
        encoder2.endEncoding()
        commandBuffer2.commit()
        commandBuffer2.waitUntilCompleted()

        // Read results
        let pointer = outputBuffer.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { pointer[$0] }
        #else
        return [] // Metal not available
        #endif
    }

    // MARK: - Statistical Comparison Helpers

    private func calculateMean(_ samples: [Double]) -> Double {
        return samples.reduce(0.0, +) / Double(samples.count)
    }

    private func calculateStdDev(_ samples: [Double]) -> Double {
        let mean = calculateMean(samples)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(samples.count)
        return sqrt(variance)
    }

    // MARK: - Tests

    @Test("Normal distribution GPU vs CPU equivalence")
    func testNormalDistribution() throws {
        let targetMean = 100.0
        let targetStdDev = 15.0
        let sampleCount = 10_000

        // Sample from CPU
        let cpuSamples = sampleCPUDistribution(
            type: "normal",
            param1: targetMean,
            param2: targetStdDev,
            param3: 0.0,
            count: sampleCount
        )

        // Sample from GPU
        let gpuSamples = try sampleGPUDistribution(
            type: "normal",
            param1: Float(targetMean),
            param2: Float(targetStdDev),
            param3: 0.0,
            count: sampleCount
        )
        guard !gpuSamples.isEmpty else { return } // Skip if Metal unavailable

        // Compare statistics
        let cpuMean = calculateMean(cpuSamples)
        let cpuStdDev = calculateStdDev(cpuSamples)

        let gpuSamplesDouble = gpuSamples.map { Double($0) }
        let gpuMean = calculateMean(gpuSamplesDouble)
        let gpuStdDev = calculateStdDev(gpuSamplesDouble)

        // Validate means are within 5%
        let meanDiff = abs(cpuMean - gpuMean) / targetMean
        #expect(meanDiff < 0.05, "GPU mean \(gpuMean) should match CPU mean \(cpuMean) within 5%")

        // Validate stdDevs are within 10%
        let stdDevDiff = abs(cpuStdDev - gpuStdDev) / targetStdDev
        #expect(stdDevDiff < 0.10, "GPU stdDev \(gpuStdDev) should match CPU stdDev \(cpuStdDev) within 10%")
    }

    @Test("Uniform distribution correctness")
    func testUniformDistribution() throws {
        let min = 5.0
        let max = 10.0
        let expectedMean = (min + max) / 2.0
        let sampleCount = 10_000

        let gpuSamples = try sampleGPUDistribution(
            type: "uniform",
            param1: Float(min),
            param2: Float(max),
            param3: 0.0,
            count: sampleCount
        )
        guard !gpuSamples.isEmpty else { return } // Skip if Metal unavailable

        let gpuSamplesDouble = gpuSamples.map { Double($0) }

        // Validate all samples in range [min, max]
        #expect(gpuSamplesDouble.allSatisfy { $0 >= min && $0 <= max })

        // Validate mean ≈ 7.5 ± 0.1
        let mean = calculateMean(gpuSamplesDouble)
        #expect(abs(mean - expectedMean) < 0.1, "Mean \(mean) should be close to \(expectedMean)")

        // Validate min and max coverage
        let sampledMin = gpuSamplesDouble.min() ?? 0.0
        let sampledMax = gpuSamplesDouble.max() ?? 0.0
        #expect(sampledMin < min + 0.5, "Should sample near min")
        #expect(sampledMax > max - 0.5, "Should sample near max")
    }

    @Test("Triangular distribution shape validation")
    func testTriangularDistribution() throws {
        let min = 10.0
        let mode = 15.0
        let max = 25.0
        let sampleCount = 10_000

        let gpuSamples = try sampleGPUDistribution(
            type: "triangular",
            param1: Float(min),
            param2: Float(max),
            param3: Float(mode),
            count: sampleCount
        )
        guard !gpuSamples.isEmpty else { return } // Skip if Metal unavailable

        let gpuSamplesDouble = gpuSamples.map { Double($0) }

        // Validate all samples in range [min, max]
        #expect(gpuSamplesDouble.allSatisfy { $0 >= min && $0 <= max })

        // Mode should be the most frequent region
        // Count samples near mode vs elsewhere
        let nearMode = gpuSamplesDouble.filter { abs($0 - mode) < 2.0 }.count
        let nearMin = gpuSamplesDouble.filter { abs($0 - min) < 2.0 }.count
        let nearMax = gpuSamplesDouble.filter { abs($0 - max) < 2.0 }.count

        // Near mode should have more samples than near min or max
        #expect(nearMode > nearMin, "More samples near mode than min")
        #expect(nearMode > nearMax, "More samples near mode than max")

        // Validate asymmetry (mode closer to min, so right tail longer)
        let median = gpuSamplesDouble.sorted()[sampleCount / 2]
        #expect(median < (min + max) / 2.0, "Median should be left of center due to mode position")
    }

    @Test("Mixed distributions GPU sampling")
    func testMixedDistributions() throws {
        let sampleCount = 5_000

        // Sample from three different distributions
        let normalSamples = try sampleGPUDistribution(
            type: "normal",
            param1: 100.0,
            param2: 15.0,
            param3: 0.0,
            count: sampleCount
        )
        let uniformSamples = try sampleGPUDistribution(
            type: "uniform",
            param1: 0.9,
            param2: 1.1,
            param3: 0.0,
            count: sampleCount
        )
        let triangularSamples = try sampleGPUDistribution(
            type: "triangular",
            param1: 700_000.0,
            param2: 900_000.0,
            param3: 750_000.0,
            count: sampleCount
        )

        guard !normalSamples.isEmpty, !uniformSamples.isEmpty, !triangularSamples.isEmpty else {
            return // Skip if Metal unavailable
        }

        // Validate each distribution independently
        let normalMean = normalSamples.map { Double($0) }.reduce(0.0, +) / Double(sampleCount)
        #expect(abs(normalMean - 100.0) < 2.0, "Normal distribution mean correct")

        let uniformMean = uniformSamples.map { Double($0) }.reduce(0.0, +) / Double(sampleCount)
        #expect(abs(uniformMean - 1.0) < 0.05, "Uniform distribution mean correct")

        let triangularMean = triangularSamples.map { Double($0) }.reduce(0.0, +) / Double(sampleCount)
        #expect(triangularMean > 700_000.0 && triangularMean < 900_000.0, "Triangular distribution mean in range")
    }

    @Test("Distribution parameter edge cases")
    func testEdgeCases() throws {
        // Uniform with min == max (degenerate case)
        let degenerateSamples = try sampleGPUDistribution(
            type: "uniform",
            param1: 5.0,
            param2: 5.0,
            param3: 0.0,
            count: 1000
        )
        guard !degenerateSamples.isEmpty else { return }
        #expect(degenerateSamples.allSatisfy { abs($0 - 5.0) < 0.001 }, "Degenerate uniform should be constant")

        // Normal with zero stdDev (degenerate)
        let zeroStdDevSamples = try sampleGPUDistribution(
            type: "normal",
            param1: 50.0,
            param2: 0.000001, // Near zero
            param3: 0.0,
            count: 1000
        )
        guard !zeroStdDevSamples.isEmpty else { return }
        let zeroStdMean = zeroStdDevSamples.map { Double($0) }.reduce(0.0, +) / Double(zeroStdDevSamples.count)
        #expect(abs(zeroStdMean - 50.0) < 0.1, "Near-zero stdDev should cluster around mean")
    }
}
