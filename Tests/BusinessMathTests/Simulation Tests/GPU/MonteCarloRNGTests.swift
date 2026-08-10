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
    /// This is ``MetalShaderSource/randomNumberGeneration``'s `seedRNGState`, not a
    /// copy of it. A copy is how the defect in ``adjacentThreadFirstDrawsAreIndependent()``
    /// could have been fixed in production and left unmeasured here.
    private static let seedAndWarmUp = """
    inline void seedState(thread RNGState* state, ulong baseSeed, uint tid) {
        seedRNGState(state, baseSeed, tid);
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
    /// only the cross-thread tests interpret it.
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

    /// The seeded `RNGState` of each of `count` threads, before any draw is taken.
    ///
    /// Reading the state rather than a variate is what lets ``seedingNeverProducesTheAbsorbingState()``
    /// assert on `(0, 0)` directly. Inferring it from output would not: a thread stuck
    /// in the absorbing state emits `0.0f`, and `0.0f` is also a legitimate draw.
    private func seededStates(count: Int, seed: UInt64) throws -> [SIMD2<UInt64>]? {
        guard let gpu = gpuContext() else { return nil }

        let source = """
        #include <metal_stdlib>
        using namespace metal;

        \(MetalShaderSource.randomNumberGeneration)

        \(Self.seedAndWarmUp)

        kernel void seededStates(
            device ulong2* outputs [[buffer(0)]],
            constant ulong& baseSeed [[buffer(1)]],
            constant uint& count [[buffer(2)]],
            uint tid [[thread_position_in_grid]]
        ) {
            if (tid >= count) { return; }
            thread RNGState state;
            seedState(&state, baseSeed, tid);
            outputs[tid] = ulong2(state.s0, state.s1);
        }
        """

        let library = try gpu.device.makeLibrary(source: source, options: nil)
        let function = try #require(library.makeFunction(name: "seededStates"))
        let pipeline = try gpu.device.makeComputePipelineState(function: function)
        let output = try #require(gpu.device.makeBuffer(length: count * MemoryLayout<SIMD2<UInt64>>.stride,
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

        let values = output.contents().bindMemory(to: SIMD2<UInt64>.self, capacity: count)
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

    /// Base seeds for the cross-thread statistics, chosen to include the degenerate
    /// shapes as well as ordinary ones.
    ///
    /// `0` and `1` matter specifically: under the previous `s0 = baseSeed ^ tid`
    /// seeding, base seed `0` gave thread `0` the state `(0, 0)`, which is xorshift128+'s
    /// absorbing state. Low seeds are the ones a caller actually types.
    private static let crossThreadSeeds: [UInt64] = [
        0x9E37_79B9_7F4A_7C15,
        0x0123_4567_89AB_CDEF,
        0xDEAD_BEEF_CAFE_BABE,
        0x5555_5555_5555_5555,
        0x0000_0000_0000_0000,
        0x0000_0000_0000_0001
    ]

    /// Adjacent threads' first draws, which must be independent.
    ///
    /// Each GPU thread is one Monte Carlo iteration, so a correlation here is a
    /// correlation between adjacent iterations of a simulation — it shows up directly
    /// in every percentile and VaR the GPU path reports.
    ///
    /// This is the test the seeding fix was made for, and it was written to fail while
    /// the defect stood. `initializeRNG` used to seed thread `t` as `s0 = baseSeed ^ t`,
    /// `s1 = (baseSeed >> 32) ^ (t << 32)`, so neighbouring threads started one or two
    /// bits apart. Xorshift128+ is GF(2)-linear in its state, so the difference between
    /// two threads evolves as its own trajectory from that tiny delta and never
    /// diffuses. Measured here on an M1 Max over these six base seeds plus six more,
    /// the old seeding gave median |ρ| of 0.26 at lag 1 and 0.32 at lag 4 — and warm-up
    /// did not help, wandering to +0.10 at 20 rounds, +0.17 at 50, −0.10 at 100.
    ///
    /// SplitMix64 seed-splitting brings the same measurement to a median |ρ| of 0.0030
    /// over 12 base seeds × 5 lags, with the worst of those 60 pairs at 0.0103. The
    /// 0.05 bar below is about 11 standard errors for n = 50,000 and roughly five times
    /// the worst value observed, so it fails on the defect and does not fail on
    /// sampling noise.
    ///
    /// Lags 2 to 5 are checked as well because the old seeding was worse at lag 4 than
    /// at lag 1: a lag-1-only assertion could be satisfied by a seeding that merely
    /// moved the structure one step out.
    @Test("Adjacent threads' first draws are independent", arguments: MonteCarloRNGTests.crossThreadSeeds)
    func adjacentThreadFirstDrawsAreIndependent(seed: UInt64) throws {
        guard let samples = try firstDrawPerThread(count: 50_000, seed: seed) else { return }

        for lag in 1...5 {
            let crossStream = autocorrelation(samples: samples, lag: lag)
            #expect(abs(crossStream) < 0.05,
                    "Lag-\(lag) correlation \(crossStream) across threads, base seed \(seed), should be ~0")
        }
    }

    /// The cross-thread marginal, at the sample size where the defect was visible.
    ///
    /// The count is load-bearing and is not 50,000. The old seeding produced a
    /// *stratified* set of first draws, not a merely non-uniform one: at n = 50,000 its
    /// K-S statistic was 0.0014 to 0.0053, which is *below* the 0.0038 expected of an
    /// honest sample and passes any critical value. At n = 10,000 the same seeding gives
    /// 0.0207 to 0.0271 against a 0.0163 critical value and fails every time. Asserting
    /// at 50,000 would have measured nothing.
    ///
    /// With SplitMix64 seeding the statistic at n = 10,000 is 0.0057 to 0.0117 over
    /// twelve base seeds, comfortably inside the α = 0.01 value.
    @Test("Cross-thread first draws are uniform (K-S)", arguments: MonteCarloRNGTests.crossThreadSeeds)
    func crossThreadFirstDrawsAreUniform(seed: UInt64) throws {
        let count = 10_000
        guard let samples = try firstDrawPerThread(count: count, seed: seed) else { return }

        let ksStatistic = kolmogorovSmirnovTest(samples: samples) { x in x }
        let critical = ksCritical01(count)

        #expect(ksStatistic < critical,
                "Cross-thread K-S \(ksStatistic) at base seed \(seed) should be below the α = 0.01 value \(critical)")
    }

    /// A seeded dispatch is a function of its seed and nothing else.
    ///
    /// Reproducibility is the whole reason the seed is a parameter, and it is the
    /// property most easily lost by a seeding change — a seeding that read anything
    /// per-dispatch would still pass every statistic above.
    ///
    /// Compared as bit patterns rather than as `Float`s. The claim is that the second
    /// dispatch reproduced the first exactly, which is a statement about the bits; `==`
    /// on `Float` would additionally have to be reasoned about for NaN and for signed
    /// zero, neither of which is what is being asserted.
    @Test("The same base seed gives the same draws, a different one does not")
    func seededDispatchIsReproducible() throws {
        guard let first = try firstDrawPerThread(count: 4096, seed: Self.fixedSeed) else { return }
        let second = try #require(try firstDrawPerThread(count: 4096, seed: Self.fixedSeed))
        let other = try #require(try firstDrawPerThread(count: 4096, seed: Self.fixedSeed &+ 1))

        let bits: ([Float]) -> [UInt32] = { $0.map(\.bitPattern) }
        #expect(bits(first) == bits(second),
                "the same base seed must reproduce the same draws exactly")
        #expect(bits(first) != bits(other),
                "a different base seed must not reproduce the same draws")
    }

    /// `(0, 0)` is absorbing for xorshift128+, and no thread may be seeded into it.
    ///
    /// From `s0 = s1 = 0` the recurrence keeps both words zero forever, so that thread
    /// emits `0.0f` for the life of the simulation. The previous seeding could reach it:
    /// base seed `0`, thread `0` gave `s0 = 0 ^ 0` and `s1 = 0 ^ 0`.
    ///
    /// SplitMix64 cannot, and the argument is exact rather than statistical. Its output
    /// function is a bijection with `mix(0) = 0`, so `s0 == 0` requires the internal
    /// counter to be exactly `0` after its first increment — which happens for one base
    /// seed and thread, `baseSeed = -0x9E3779B97F4A7C15` at `tid = 0`. The counter is
    /// then `0`, the second call mixes `0x9E3779B97F4A7C15`, and `s1` is not zero. That
    /// one case is constructed below rather than hoped for, alongside a sweep wide
    /// enough to catch a seeding that reached the state some other way.
    @Test("Seeding never produces xorshift128+'s absorbing state")
    func seedingNeverProducesTheAbsorbingState() throws {
        // The unique (baseSeed, tid) that drives SplitMix64's counter to zero.
        let adversarial = UInt64(0) &- 0x9E37_79B9_7F4A_7C15
        guard let constructed = try seededStates(count: 1, seed: adversarial) else { return }
        #expect(constructed[0].x == 0, "the constructed case should be the one that zeroes s0")
        // s1 is mix(0x9E3779B97F4A7C15) — SplitMix64's output for a counter that has just
        // wrapped to zero. The value follows from the mixing constants above rather than
        // from observation, so asserting it, instead of merely "not zero", also fails if
        // the mixing itself is changed.
        #expect(constructed[0].y == 0xE220_A839_7B1D_CDAF,
                "s1 must be mix(0x9E3779B97F4A7C15), not \(constructed[0].y) — and above all not zero, which is the absorbing state")

        for seed in Self.crossThreadSeeds + [adversarial] {
            let states = try #require(try seededStates(count: 100_000, seed: seed))
            let absorbing = states.filter { $0.x == 0 && $0.y == 0 }
            #expect(absorbing.isEmpty,
                    "\(absorbing.count) threads at base seed \(seed) were seeded into (0, 0)")
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
