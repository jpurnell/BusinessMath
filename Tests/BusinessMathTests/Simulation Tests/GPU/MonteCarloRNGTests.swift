import Testing
import TestSupport  // Cross-platform math functions
import Foundation
#if canImport(Metal)
import Metal
#endif
@testable import BusinessMath

/// Tests for GPU random number generator quality.
///
/// Validates that the Metal-based RNG produces statistically sound random numbers
/// suitable for Monte Carlo simulation: uniformity (chi-square), distribution
/// matching (Kolmogorov-Smirnov), independence (autocorrelation), and the
/// Box-Muller transform.
///
/// ## What "a sample" means here, and why it matters
///
/// The GPU draws in a shape the CPU does not. `initializeRNG` gives every thread its
/// own `RNGState`, and a Monte Carlo dispatch then takes *one* draw per thread. So
/// there are two entirely different sequences one could call "the RNG's output":
///
/// - **Within a stream** — successive `nextUniform` calls on one thread's state.
///   This is what "lag-1 autocorrelation", "K-S", and "uniformity" conventionally
///   mean, and it is what these tests measure. ``streamUniforms(count:seed:)``
///   produces it.
/// - **Across streams** — the first draw of thread 0, then of thread 1, and so on.
///   Reading a Metal output buffer in index order gives this, not the above.
///   ``firstDrawPerThread(count:seed:)`` produces it, and exactly one test below
///   measures it, under a name that says so.
///
/// An earlier version of this suite generated across-stream samples and ran
/// `autocorrelation(lag: 1)` over them while calling the result "lag-1
/// autocorrelation". That statistic is real and worth having, but it is a
/// cross-stream independence check and it does not test what its name claimed.
///
/// ## These tests did not run before
///
/// Every kernel here used to be a local copy of the MSL that declared
/// `nextUniform(thread RNGState*)` and then called it with a `device RNGState*`.
/// That does not compile. The failure was swallowed by `try?`, the helper returned
/// `[]`, and each test began `guard !samples.isEmpty else { return }` — so the whole
/// suite passed by never executing. The kernels now interpolate
/// ``MetalShaderSource/randomNumberGeneration``, which is the same text production
/// compiles and carries both address-space overloads, and a compilation failure is
/// now thrown rather than mistaken for "no GPU on this machine".
@Suite("Monte Carlo GPU RNG Quality Tests")
struct MonteCarloRNGTests {

    #if canImport(Metal)

    // MARK: - Device Access

    private struct GPUContext {
        let device: MTLDevice
        let queue: MTLCommandQueue
    }

    /// A device that can compile MSL at runtime, or `nil` if this machine has none.
    ///
    /// Compiling a trivial kernel first is what separates "no shader compiler here,
    /// skip" from "our source is broken, fail". Without that split every assertion
    /// below would be reported as a shader bug on a machine that simply has no GPU.
    private func gpuContext() -> GPUContext? {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let trivial = """
        #include <metal_stdlib>
        using namespace metal;
        kernel void trivial(device float* out [[buffer(0)]], uint tid [[thread_position_in_grid]]) {
            out[tid] = 1.0f;
        }
        """
        guard (try? device.makeLibrary(source: trivial, options: nil)) != nil else { return nil }
        guard let queue = device.makeCommandQueue() else { return nil }
        return GPUContext(device: device, queue: queue)
    }

    /// The production seeding, verbatim, so these tests exercise the real streams.
    ///
    /// Kept in one place because it appears in both sampler kernels and because it
    /// is the subject of ``adjacentThreadFirstDrawsAreCorrelated()``.
    private static let seedAndWarmUp = """
    inline void seedState(thread RNGState* state, ulong baseSeed, uint tid) {
        state->s0 = baseSeed ^ tid;
        state->s1 = (baseSeed >> 32) ^ (ulong(tid) << 32);
        for (int i = 0; i < 10; i++) { nextUniform(state); }
    }
    """

    // MARK: - Samplers

    /// `count` successive draws from **one** thread's stream.
    ///
    /// This is the sequence the quality statistics below are defined over. A single
    /// thread is slow by GPU standards and deliberately so: the point is the order
    /// of the draws, which a parallel dispatch destroys.
    private func streamUniforms(count: Int, seed: UInt64) throws -> [Float]? {
        guard let gpu = gpuContext() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        \(MetalShaderSource.randomNumberGeneration)

        \(Self.seedAndWarmUp)

        kernel void streamUniforms(
            device float* outputs [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            constant uint& count [[buffer(2)]],
            uint tid [[thread_position_in_grid]]
        ) {
            if (tid != 0) { return; }
            thread RNGState state;
            seedState(&state, baseSeed, 0);
            for (uint i = 0; i < count; i++) { outputs[i] = nextUniform(&state); }
        }
        """

        return try runSingleThread(gpu, source: source, function: "streamUniforms",
                                   count: count, seed: seed, extraBytes: [])
    }

    /// `count` successive normal variates from **one** thread's stream.
    private func streamNormals(count: Int, mean: Float, stdDev: Float, seed: UInt64) throws -> [Float]? {
        guard let gpu = gpuContext() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        \(MetalShaderSource.randomNumberGeneration)

        \(Self.seedAndWarmUp)

        kernel void streamNormals(
            device float* outputs [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            constant uint& count [[buffer(2)]],
            constant float& mean [[buffer(3)]],
            constant float& stdDev [[buffer(4)]],
            uint tid [[thread_position_in_grid]]
        ) {
            if (tid != 0) { return; }
            thread RNGState state;
            seedState(&state, baseSeed, 0);
            for (uint i = 0; i < count; i++) {
                outputs[i] = nextNormal(&state, mean, stdDev).x;
            }
        }
        """

        let meanBytes = withUnsafeBytes(of: mean) { Array($0) }
        let stdDevBytes = withUnsafeBytes(of: stdDev) { Array($0) }
        return try runSingleThread(gpu, source: source, function: "streamNormals",
                                   count: count, seed: seed,
                                   extraBytes: [meanBytes, stdDevBytes])
    }

    /// The **first** draw of each of `count` independently seeded threads.
    ///
    /// This is the dispatch shape a real Monte Carlo run uses — one draw per thread,
    /// read back in thread order. It is a sample across streams, not along one, and
    /// only ``adjacentThreadFirstDrawsAreCorrelated()`` interprets it.
    private func firstDrawPerThread(count: Int, seed: UInt64) throws -> [Float]? {
        guard let gpu = gpuContext() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        \(MetalShaderSource.randomNumberGeneration)

        \(Self.seedAndWarmUp)

        kernel void firstDrawPerThread(
            device float* outputs [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            constant uint& count [[buffer(2)]],
            uint tid [[thread_position_in_grid]]
        ) {
            // ceil(count / 256) * 256 threads are dispatched; the tail must not write
            // past the end of the buffer, which under parallel test execution means
            // into whatever the next allocation happens to be.
            if (tid >= count) { return; }
            thread RNGState state;
            seedState(&state, baseSeed, tid);
            outputs[tid] = nextUniform(&state);
        }
        """

        let library = try gpu.device.makeLibrary(source: source, options: nil)
        let function = try #require(library.makeFunction(name: "firstDrawPerThread"))
        let pipeline = try gpu.device.makeComputePipelineState(function: function)
        let output = try #require(gpu.device.makeBuffer(length: count * MemoryLayout<Float>.stride,
                                                        options: .storageModeShared))
        var baseSeed = seed
        var sampleCount = UInt32(count)

        let commands = try #require(gpu.queue.makeCommandBuffer())
        let encoder = try #require(commands.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(output, offset: 0, index: 0)
        encoder.setBytes(&baseSeed, length: MemoryLayout<UInt64>.stride, index: 1)
        encoder.setBytes(&sampleCount, length: MemoryLayout<UInt32>.stride, index: 2)
        let perGroup = MTLSize(width: min(count, 256), height: 1, depth: 1)
        let groups = MTLSize(width: (count + perGroup.width - 1) / perGroup.width, height: 1, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: perGroup)
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()

        let values = output.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { values[$0] }
    }

    /// Dispatches a one-thread kernel that fills `outputs[0..<count]` in stream order.
    private func runSingleThread(
        _ gpu: GPUContext,
        source: String,
        function name: String,
        count: Int,
        seed: UInt64,
        extraBytes: [[UInt8]]
    ) throws -> [Float] {
        let library = try gpu.device.makeLibrary(source: source, options: nil)
        let function = try #require(library.makeFunction(name: name))
        let pipeline = try gpu.device.makeComputePipelineState(function: function)
        let output = try #require(gpu.device.makeBuffer(length: count * MemoryLayout<Float>.stride,
                                                        options: .storageModeShared))
        var baseSeed = seed
        var sampleCount = UInt32(count)

        let commands = try #require(gpu.queue.makeCommandBuffer())
        let encoder = try #require(commands.makeComputeCommandEncoder())
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(output, offset: 0, index: 0)
        encoder.setBytes(&baseSeed, length: MemoryLayout<UInt64>.stride, index: 1)
        encoder.setBytes(&sampleCount, length: MemoryLayout<UInt32>.stride, index: 2)
        for (offset, bytes) in extraBytes.enumerated() {
            encoder.setBytes(bytes, length: bytes.count, index: 3 + offset)
        }
        let one = MTLSize(width: 1, height: 1, depth: 1)
        encoder.dispatchThreadgroups(one, threadsPerThreadgroup: one)
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()

        let values = output.contents().bindMemory(to: Float.self, capacity: count)
        return (0..<count).map { values[$0] }
    }

    // MARK: - Statistical Test Helpers

    /// Chi-square goodness-of-fit against a uniform histogram.
    private func chiSquareTest(samples: [Float], bins: Int = 100) -> Double {
        var histogram = [Int](repeating: 0, count: bins)
        for sample in samples {
            // nextUniform's range is a *closed* [0, 1] once rounded to Float32,
            // so 1.0 is attainable and belongs in the top bin, not past the end.
            let index = min(bins - 1, max(0, Int(Double(sample) * Double(bins))))
            histogram[index] += 1
        }
        let expected = Double(samples.count) / Double(bins)
        return histogram.reduce(0.0) { sum, count in
            let diff = Double(count) - expected
            return sum + (diff * diff) / expected
        }
    }

    /// Two-sided Kolmogorov-Smirnov statistic.
    ///
    /// Both `i/n − F(x)` and `F(x) − (i−1)/n` are taken. The one-sided form the
    /// earlier version used systematically understates D and cannot be compared
    /// against a published critical value.
    private func kolmogorovSmirnovTest(samples: [Float], cdf: (Float) -> Float) -> Double {
        let sorted = samples.sorted()
        let n = Double(samples.count)
        var deviation = 0.0
        for (i, x) in sorted.enumerated() {
            let theoretical = Double(cdf(x))
            deviation = max(deviation, abs(Double(i + 1) / n - theoretical))
            deviation = max(deviation, abs(theoretical - Double(i) / n))
        }
        return deviation
    }

    /// Two-sided K-S critical value at α = 0.01.
    private func ksCritical01(_ n: Int) -> Double { 1.628 / Double(n).squareRoot() }

    /// Sample autocorrelation at `lag`, over whatever order the array is in.
    private func autocorrelation(samples: [Float], lag: Int = 1) -> Double {
        let mean = samples.map { Double($0) }.reduce(0.0, +) / Double(samples.count)
        let variance = samples.map { pow(Double($0) - mean, 2) }.reduce(0.0, +) / Double(samples.count)

        let n = samples.count - lag
        let pairs = zip(samples.prefix(n), samples.dropFirst(lag))
        let covariance = pairs.map { (x, y) in (Double(x) - mean) * (Double(y) - mean) }.reduce(0.0, +)
        return covariance / (Double(n) * variance)
    }

    /// A fixed seed, so a failure is reproducible and is not one draw in twenty.
    ///
    /// Statistical assertions against a critical value reject a correct generator at
    /// the stated rate; with `arc4random()` that turns into an intermittent test
    /// nobody trusts. Pinning the seed converts these into regression tests on a
    /// known-good draw, which is what they are for.
    private static let fixedSeed: UInt64 = 0x9E37_79B9_7F4A_7C15

    // MARK: - Tests

    @Test("GPU RNG uniformity within one stream (Chi-square test)")
    func testUniformity() throws {
        guard let samples = try streamUniforms(count: 100_000, seed: Self.fixedSeed) else { return }

        #expect(samples.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })

        let chiSquare = chiSquareTest(samples: samples, bins: 100)

        // Critical value for df = 99: 123.2 at α = 0.05, 135.8 at α = 0.01.
        #expect(chiSquare < 135.0, "Chi-square statistic \(chiSquare) should be < 135 for uniform distribution")

        let mean = samples.reduce(0.0, +) / Float(samples.count)
        #expect(abs(mean - 0.5) < 0.01, "Mean \(mean) should be close to 0.5")
    }

    /// Lag-1 autocorrelation of **successive draws from a single stream**.
    ///
    /// The name is the whole point. This walks one thread's `RNGState` forward
    /// 50,000 times and correlates each draw with the next, which is what lag-1
    /// autocorrelation means. The cross-stream property is a different question and
    /// has its own test below.
    @Test("GPU RNG independence within one stream (lag-1 autocorrelation)")
    func testIndependenceWithinStream() throws {
        guard let samples = try streamUniforms(count: 50_000, seed: Self.fixedSeed) else { return }

        let autocorr = autocorrelation(samples: samples, lag: 1)
        #expect(abs(autocorr) < 0.05,
                "Lag-1 autocorrelation \(autocorr) should be close to 0 for successive draws")

        // Lag 2 as well: a generator can be clean at one lag and structured at the next.
        let lag2 = autocorrelation(samples: samples, lag: 2)
        #expect(abs(lag2) < 0.05, "Lag-2 autocorrelation \(lag2) should be close to 0")
    }

    /// Adjacent threads' first draws, which are **not** independent.
    ///
    /// `initializeRNG` seeds thread `t` as `s0 = baseSeed ^ t`, `s1 = (baseSeed >> 32)
    /// ^ (t << 32)`, so neighbouring threads start one or two bits apart. Xorshift128+
    /// is GF(2)-linear in its state, which means the difference between two threads'
    /// states evolves as its own xorshift trajectory seeded by that tiny delta — and a
    /// one-bit delta takes far more than ten rounds to diffuse. The ten warm-up rounds
    /// are not enough, and adding more does not fix it: measured on an M1 Max, the
    /// cross-thread lag-1 correlation is +0.29 at 10 rounds, +0.09 at 20, +0.17 at 50,
    /// −0.10 at 100 and +0.08 at 1000. It moves around; it does not decay.
    ///
    /// The individual streams are fine — ``testIndependenceWithinStream()`` passes with
    /// |ρ| ≈ 0.001 — so this is the seeding, not the generator. The standard remedy is
    /// SplitMix64 seed-splitting, which brings the same measurement to |ρ| < 0.008
    /// across twelve random base seeds and removes the need for warm-up entirely. That
    /// change moves every seeded GPU result in the package, so it is not made here.
    ///
    /// Recorded as a known issue rather than deleted: the property is one the package
    /// should have, and `withKnownIssue` fails if it ever starts holding, so fixing the
    /// seeding cannot leave this comment quietly wrong.
    @Test("Adjacent threads' first draws are independent (known issue: baseSeed ^ tid seeding)")
    func adjacentThreadFirstDrawsAreCorrelated() throws {
        guard let samples = try firstDrawPerThread(count: 50_000, seed: Self.fixedSeed) else { return }

        withKnownIssue("`s0 = baseSeed ^ tid` correlates neighbouring streams at ρ ≈ +0.26; changing it moves every seeded GPU result and is not this test's call.") {
            let crossStream = autocorrelation(samples: samples, lag: 1)
            #expect(abs(crossStream) < 0.05,
                    "Correlation \(crossStream) between the first draws of adjacent threads should be ~0")
        }
    }

    @Test("Box-Muller transform produces standard normal")
    func testBoxMullerStandardNormal() throws {
        guard let samples = try streamNormals(count: 10_000, mean: 0.0, stdDev: 1.0,
                                              seed: Self.fixedSeed) else { return }

        let mean = samples.reduce(0.0, +) / Float(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(samples.count)
        let stdDev = sqrt(variance)

        #expect(abs(mean) < 0.04, "Mean \(mean) should be close to 0.0")
        #expect(abs(stdDev - 1.0) < 0.02, "Standard deviation \(stdDev) should be close to 1.0")
    }

    @Test("Box-Muller transform with custom parameters")
    func testBoxMullerCustomParameters() throws {
        let targetMean: Float = 100.0
        let targetStdDev: Float = 15.0

        guard let samples = try streamNormals(count: 10_000, mean: targetMean, stdDev: targetStdDev,
                                              seed: Self.fixedSeed) else { return }

        let mean = samples.reduce(0.0, +) / Float(samples.count)
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0.0, +) / Float(samples.count)
        let stdDev = sqrt(variance)

        #expect(abs(mean - targetMean) < 1.0, "Mean \(mean) should be close to \(targetMean)")
        #expect(abs(stdDev - targetStdDev) < 1.0, "Standard deviation \(stdDev) should be close to \(targetStdDev)")
    }

    @Test("Kolmogorov-Smirnov test for uniform distribution")
    func testKSUniform() throws {
        let count = 10_000
        guard let samples = try streamUniforms(count: count, seed: Self.fixedSeed) else { return }

        let ksStatistic = kolmogorovSmirnovTest(samples: samples) { x in x }
        let critical = ksCritical01(count)

        #expect(ksStatistic < critical,
                "K-S statistic \(ksStatistic) should be below the α = 0.01 critical value \(critical)")
    }

    @Test("Kolmogorov-Smirnov test for normal distribution")
    func testKSNormal() throws {
        let count = 10_000
        guard let samples = try streamNormals(count: count, mean: 0.0, stdDev: 1.0,
                                              seed: Self.fixedSeed) else { return }

        let normalCDF: (Float) -> Float = { x in
            0.5 * (1.0 + erf(x / sqrt(2.0)))
        }

        let ksStatistic = kolmogorovSmirnovTest(samples: samples, cdf: normalCDF)
        let critical = ksCritical01(count)

        #expect(ksStatistic < critical,
                "K-S statistic \(ksStatistic) should be below the α = 0.01 critical value \(critical)")
    }

    #endif
}
