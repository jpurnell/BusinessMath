//
//  DistributionSeedDeterminismTests.swift
//  BusinessMath
//
//  Covers the seeding contract of the gamma-family distributions:
//  `distributionGamma`, `gammaVariate`, `distributionBeta`, `distributionGeometric`,
//  `distributionChiSquared`, `distributionChiSquaredThrowing`, `distributionF`,
//  `distributionT` and `sampleInverseGamma`.
//
//  These eight entry points used to take `seeds: [Double]?` — a finite array of
//  pre-drawn uniforms consumed by index, which fell through to
//  `Double.random(in: 0...1)` the moment the index ran past the end. Reproducibility
//  held for as long as the array lasted and then stopped, with no error and no signal.
//  Measured against the 10-element budget the distribution test suites themselves
//  used: `distributionF(df1: 1, df2: 1)` left the recorded stream on 1102 of 20,000
//  draws (5.5%), `distributionBeta(alpha: 0.5, beta: 0.5)` on 1017 of 20,000 (5.1%),
//  `distributionT(degreesOfFreedom: 1)` on 12 of 20,000.
//
//  The array is gone. What replaces it is the shape the rest of the library uses:
//  a `seed: UInt64?` convenience over ``DeterministicRNG``, and a
//  `using generator: inout G` form for callers who want one stream across several
//  draws.
//

import Foundation
import Testing
import TestSupport  // identical(_:_:) — bit-for-bit comparison
import Numerics

@testable import BusinessMath

/// Counts how many 64-bit words a caller pulls, so a test can assert that a
/// reproducible run consumed far more randomness than any fixed array would have held.
private struct DrawCountingRNG: RandomNumberGenerator {
	private var inner: Xoshiro256StarStar
	private(set) var draws = 0

	init(seed: UInt64) {
		inner = Xoshiro256StarStar(seed: seed)
	}

	mutating func next() -> UInt64 {
		draws += 1
		return inner.next()
	}
}

private func sampleMean(_ xs: [Double]) -> Double {
	xs.reduce(0, +) / Double(xs.count)
}

private func sampleVariance(_ xs: [Double]) -> Double {
	let m = sampleMean(xs)
	return xs.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(xs.count - 1)
}

// MARK: - Same seed twice, and different seeds

@Suite("Distribution Seeding — reproducibility")
struct DistributionSeedReproducibilityTests {

	/// Twenty draws rather than one: a single draw being equal across two seeds is
	/// possible by coincidence, a vector of twenty is not.
	private func block(_ draw: (UInt64) -> Double, seed: UInt64) -> [Double] {
		(0..<20).map { draw(seed &+ UInt64($0) &* 1_000_003) }
	}

	@Test("distributionGamma: same seed reproduces, different seeds diverge")
	func gammaSeed() {
		let a = block({ distributionGamma(r: 4, λ: 2.0, seed: $0) }, seed: 42)
		let b = block({ distributionGamma(r: 4, λ: 2.0, seed: $0) }, seed: 42)
		let c = block({ distributionGamma(r: 4, λ: 2.0, seed: $0) }, seed: 43)
		#expect(a == b, "Seed 42 must reproduce exactly")
		#expect(a != c, "Seed 43 must not reproduce seed 42")
	}

	@Test("gammaVariate: same seed reproduces, different seeds diverge")
	func gammaVariateSeed() {
		let a = block({ gammaVariate(shape: 2.5, scale: 1.5, seed: $0) }, seed: 42)
		let b = block({ gammaVariate(shape: 2.5, scale: 1.5, seed: $0) }, seed: 42)
		let c = block({ gammaVariate(shape: 2.5, scale: 1.5, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionBeta: same seed reproduces, different seeds diverge")
	func betaSeed() {
		let a = block({ distributionBeta(alpha: 2.0, beta: 5.0, seed: $0) }, seed: 42)
		let b = block({ distributionBeta(alpha: 2.0, beta: 5.0, seed: $0) }, seed: 42)
		let c = block({ distributionBeta(alpha: 2.0, beta: 5.0, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionGeometric: same seed reproduces, different seeds diverge")
	func geometricSeed() {
		let a = block({ distributionGeometric(0.2, seed: $0) }, seed: 42)
		let b = block({ distributionGeometric(0.2, seed: $0) }, seed: 42)
		let c = block({ distributionGeometric(0.2, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionChiSquared: same seed reproduces, different seeds diverge")
	func chiSquaredSeed() {
		let a = block({ distributionChiSquared(degreesOfFreedom: 5, seed: $0) }, seed: 42)
		let b = block({ distributionChiSquared(degreesOfFreedom: 5, seed: $0) }, seed: 42)
		let c = block({ distributionChiSquared(degreesOfFreedom: 5, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionChiSquaredThrowing: same seed reproduces, different seeds diverge")
	func chiSquaredThrowingSeed() throws {
		func draw(_ seed: UInt64) throws -> [Double] {
			try (0..<20).map { try distributionChiSquaredThrowing(degreesOfFreedom: 5, seed: seed &+ UInt64($0)) }
		}
		let a = try draw(42)
		let b = try draw(42)
		let c = try draw(4200)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionF: same seed reproduces, different seeds diverge")
	func fSeed() {
		let a = block({ distributionF(df1: 5, df2: 20, seed: $0) }, seed: 42)
		let b = block({ distributionF(df1: 5, df2: 20, seed: $0) }, seed: 42)
		let c = block({ distributionF(df1: 5, df2: 20, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("distributionT: same seed reproduces, different seeds diverge")
	func tSeed() {
		let a = block({ distributionT(degreesOfFreedom: 10, seed: $0) }, seed: 42)
		let b = block({ distributionT(degreesOfFreedom: 10, seed: $0) }, seed: 42)
		let c = block({ distributionT(degreesOfFreedom: 10, seed: $0) }, seed: 43)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("sampleInverseGamma: same seed reproduces, different seeds diverge")
	func inverseGammaSeed() throws {
		func draw(_ seed: UInt64) throws -> [Double] {
			try (0..<20).map { try sampleInverseGamma(shape: 5.0, scale: 4.0, seed: seed &+ UInt64($0)) }
		}
		let a = try draw(42)
		let b = try draw(42)
		let c = try draw(4200)
		#expect(a == b)
		#expect(a != c)
	}

	@Test("nil seed is non-reproducible by contract")
	func nilSeedIsNotReproducible() {
		// The documented unseeded path. Twenty draws with no seed must not repeat —
		// if they did, `seed:` would be doing nothing and the whole contract is a lie.
		let a = (0..<20).map { _ in distributionChiSquared(degreesOfFreedom: 5) as Double }
		let b = (0..<20).map { _ in distributionChiSquared(degreesOfFreedom: 5) as Double }
		#expect(a != b)
	}
}

// MARK: - One stream across several draws

@Suite("Distribution Seeding — caller-owned streams")
struct DistributionGeneratorStreamTests {

	@Test("A threaded generator reproduces the whole sequence")
	func threadedGeneratorReproduces() {
		func run() -> [Double] {
			var rng = DeterministicRNG(seed: 2718)
			var out: [Double] = []
			out.append(distributionChiSquared(degreesOfFreedom: 5, using: &rng))
			out.append(distributionF(df1: 5, df2: 20, using: &rng))
			out.append(distributionT(degreesOfFreedom: 10, using: &rng))
			out.append(distributionBeta(alpha: 2.0, beta: 5.0, using: &rng))
			out.append(distributionGamma(r: 4, λ: 2.0, using: &rng))
			out.append(distributionGeometric(0.2, using: &rng))
			out.append(gammaVariate(shape: 2.5, scale: 1.5, using: &rng))
			return out
		}
		#expect(run() == run())
	}

	/// The reason `using:` exists rather than only `seed:`. Two `seed: 42` calls start
	/// two streams at the same place, so a chi-squared and an F drawn that way are built
	/// from the same underlying uniforms — a correlation nobody asked for. Threading one
	/// generator makes the second draw independent of the first.
	@Test("Two seed: calls share uniforms; one threaded generator does not")
	func separateSeedsShareUniformsButOneStreamDoesNot() {
		var rng = DeterministicRNG(seed: 42)
		let chiThreaded = distributionChiSquared(degreesOfFreedom: 5, using: &rng) as Double
		let fThreaded = distributionF(df1: 5, df2: 5, using: &rng) as Double

		let chiSolo: Double = distributionChiSquared(degreesOfFreedom: 5, seed: 42)
		let fSolo: Double = distributionF(df1: 5, df2: 5, seed: 42)

		// The first draw off a fresh seed-42 stream is the same either way.
		#expect(identical(chiThreaded, chiSolo))
		// The second is not: `fSolo` restarts the stream, `fThreaded` continues it.
		#expect(!identical(fThreaded, fSolo))
	}

	@Test("A chi-squared drawn from seed 42 equals the F numerator drawn from seed 42")
	func seedCollisionIsRealAndIsWhatUsingAvoids() {
		// F(df1, df2) draws its numerator chi-squared first, so `seed: 42` gives
		// F a numerator identical to a `seed: 42` chi-squared with the same df.
		// This is not a bug — it is the arithmetic of independent streams, and the
		// documented way out is to thread one generator.
		let chi: Double = distributionChiSquared(degreesOfFreedom: 7, seed: 42)
		var rng = DeterministicRNG(seed: 42)
		let numerator = gammaVariate(shape: 3.5, scale: 2.0, using: &rng) as Double
		#expect(identical(chi, numerator))
	}
}

// MARK: - The defect: reproducibility past any fixed array

@Suite("Distribution Seeding — outlasting any uniform array")
struct DistributionSeedExhaustionTests {

	/// The old `seeds: [Double]?` gave up silently once the index passed the end.
	/// Every entry point below now draws far more uniforms than any array a caller
	/// would plausibly have supplied, and still reproduces bit-for-bit.
	@Test("Every entry point reproduces after tens of thousands of uniforms")
	func reproducibleFarPastArrayExhaustion() {
		func run() -> ([Double], Int) {
			var rng = DrawCountingRNG(seed: 31337)
			var out: [Double] = []
			out.reserveCapacity(7 * 2_000)
			for _ in 0..<2_000 {
				out.append(distributionGamma(r: 4, λ: 2.0, using: &rng))
				out.append(gammaVariate(shape: 0.5, scale: 1.0, using: &rng))
				out.append(distributionBeta(alpha: 0.5, beta: 0.5, using: &rng))
				out.append(distributionGeometric(0.2, using: &rng))
				out.append(distributionChiSquared(degreesOfFreedom: 1, using: &rng))
				out.append(distributionF(df1: 1, df2: 1, using: &rng))
				out.append(distributionT(degreesOfFreedom: 1, using: &rng))
			}
			return (out, rng.draws)
		}

		let (first, drawsFirst) = run()
		let (second, drawsSecond) = run()

		#expect(first == second, "A seeded stream must reproduce exactly, however long it runs")
		#expect(drawsFirst == drawsSecond, "Consumption must be reproducible too")
		// The old suites handed these functions 10 uniforms per sample. This run consumes
		// on the order of 10^5 — four orders of magnitude past where the array died.
		#expect(drawsFirst > 50_000, "Expected a long stream, drew \(drawsFirst) uniforms")
	}

	/// `gammaVariate` is the worst case by construction: rejection sampling bounded at
	/// 10,000 outer x 1,000 inner iterations, so the number of uniforms consumed is
	/// data-dependent and unbounded. Shape near 1 maximises rejection — measured mean
	/// consumption 4.08 uniforms at shape 0.5 and 3.15 at shape 1.0, with a maximum of
	/// 13 observed over 20,000 draws. No fixed array can be sized for that.
	@Test("gammaVariate reproduces across shapes that force rejection")
	func gammaVariateRejectionHeavyReproduces() {
		for shape in [0.05, 0.25, 0.5, 1.0, 1.0001] {
			func run() -> ([Double], Int) {
				var rng = DrawCountingRNG(seed: 8_675_309)
				let xs = (0..<20_000).map { _ in gammaVariate(shape: shape, scale: 1.0, using: &rng) as Double }
				return (xs, rng.draws)
			}
			let (a, drawsA) = run()
			let (b, drawsB) = run()
			#expect(a == b, "shape \(shape) must reproduce")
			#expect(drawsA == drawsB)
			#expect(drawsA > 60_000, "shape \(shape) drew \(drawsA) uniforms for 20,000 variates")
		}
	}

	/// The `seed:` convenience must reach the same place as the `using:` form; otherwise
	/// the two doors into the same function disagree about what a seed means.
	@Test("seed: and a fresh DeterministicRNG agree")
	func seedConvenienceMatchesFreshGenerator() {
		var rng = DeterministicRNG(seed: 4_294_967_311)
		let viaGenerator = distributionT(degreesOfFreedom: 3, using: &rng) as Double
		let viaSeed: Double = distributionT(degreesOfFreedom: 3, seed: 4_294_967_311)
		#expect(identical(viaGenerator, viaSeed))
	}

	@Test("Seeds above Int.max are legal and distinct")
	func largeSeedsDoNotTrapOrCollide() {
		// UInt64.max and UInt64.max - 1 both exceed Int.max; a seed pipeline that
		// narrows to Int or to 48 bits would trap or collide here.
		let a: Double = distributionChiSquared(degreesOfFreedom: 5, seed: UInt64.max)
		let b: Double = distributionChiSquared(degreesOfFreedom: 5, seed: UInt64.max)
		let c: Double = distributionChiSquared(degreesOfFreedom: 5, seed: UInt64.max &- 1)
		#expect(identical(a, b))
		#expect(!identical(a, c))
	}
}

// MARK: - Distributional sanity, seeded

/// Every bound below is a fixed-seed check against the analytic moment, not a
/// distribution-free confidence bound. The seed is pinned, so each assertion either
/// holds on every run or fails on every run — there is no flake surface. Tolerances
/// are stated as relative error and are roughly an order of magnitude above the
/// observed error at this sample size, which leaves them tight enough to catch a
/// misparameterised distribution and loose enough to survive a change of stream.
@Suite("Distribution Seeding — analytic moments under a fixed seed")
struct DistributionSeedMomentTests {

	private static let n = 60_000

	private func draws(seed: UInt64, _ body: (inout Xoshiro256StarStar) -> Double) -> [Double] {
		var rng = DeterministicRNG(seed: seed)
		return (0..<Self.n).map { _ in body(&rng) }
	}

	@Test("distributionGamma(r:λ:) has mean r/λ and variance r/λ²")
	func gammaMoments() {
		let r = 5, λ = 2.0
		let xs = draws(seed: 1001) { distributionGamma(r: r, λ: λ, using: &$0) }
		let expectedMean = Double(r) / λ            // 2.5
		let expectedVar = Double(r) / (λ * λ)       // 1.25
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02,
				"mean \(sampleMean(xs)) vs \(expectedMean)")   // tolerance: 2% relative
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.05,
				"variance \(sampleVariance(xs)) vs \(expectedVar)")  // tolerance: 5% relative
	}

	@Test("gammaVariate(shape:scale:) has mean kθ and variance kθ²")
	func gammaVariateMoments() {
		let k = 3.0, θ = 2.0
		let xs = draws(seed: 1002) { gammaVariate(shape: k, scale: θ, using: &$0) }
		let expectedMean = k * θ                    // 6.0
		let expectedVar = k * θ * θ                 // 12.0
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02)
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.05)
	}

	@Test("gammaVariate with shape < 1 has mean kθ")
	func gammaVariateSmallShapeMoments() {
		// Exercises the shape-transformation branch, which the shape >= 1 test does not.
		let k = 0.4, θ = 3.0
		let xs = draws(seed: 1003) { gammaVariate(shape: k, scale: θ, using: &$0) }
		let expectedMean = k * θ                    // 1.2
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.03)
	}

	@Test("distributionBeta has mean α/(α+β) and the Beta variance")
	func betaMoments() {
		let α = 2.0, β = 5.0
		let xs = draws(seed: 1004) { distributionBeta(alpha: α, beta: β, using: &$0) }
		let s = α + β
		let expectedMean = α / s                                  // 0.2857…
		let expectedVar = (α * β) / (s * s * (s + 1))             // 0.02551…
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02)
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.05)
		#expect(xs.allSatisfy { $0 >= 0 && $0 <= 1 }, "Beta variates must lie in [0, 1]")
	}

	@Test("distributionGeometric has mean 1/p")
	func geometricMoments() {
		let p = 0.25
		let xs = draws(seed: 1005) { distributionGeometric(p, using: &$0) }
		let expectedMean = 1.0 / p                                // 4.0
		let expectedVar = (1.0 - p) / (p * p)                     // 12.0
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02)
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.10,
				"variance \(sampleVariance(xs)) vs \(expectedVar)")  // discrete, heavier tail: 10%
		#expect(xs.allSatisfy { $0 >= 1 }, "Trial counts start at 1")
	}

	@Test("distributionChiSquared has mean df and variance 2df")
	func chiSquaredMoments() {
		let df = 8
		let xs = draws(seed: 1006) { distributionChiSquared(degreesOfFreedom: df, using: &$0) }
		let expectedMean = Double(df)               // 8
		let expectedVar = 2.0 * Double(df)          // 16
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02)
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.05)
	}

	@Test("distributionF has mean df2/(df2-2)")
	func fMoments() {
		let df1 = 10, df2 = 50
		let xs = draws(seed: 1007) { distributionF(df1: df1, df2: df2, using: &$0) }
		let expectedMean = Double(df2) / Double(df2 - 2)     // 1.041666…
		// F is right-skewed with a heavy tail; the sample variance converges slowly, so
		// only the mean is pinned. 3% relative.
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.03,
				"mean \(sampleMean(xs)) vs \(expectedMean)")
		#expect(xs.allSatisfy { $0 >= 0 }, "F variates are non-negative")
	}

	@Test("distributionT has mean 0 and variance df/(df-2)")
	func tMoments() {
		let df = 10
		let xs = draws(seed: 1008) { distributionT(degreesOfFreedom: df, using: &$0) }
		let expectedVar = Double(df) / Double(df - 2)        // 1.25
		// Mean is zero, so an absolute bound is the only meaningful one. The standard
		// error at n = 60,000 with sd = sqrt(1.25) is 0.0046; 0.05 is ten times that.
		#expect(abs(sampleMean(xs)) < 0.05, "mean \(sampleMean(xs)) should be near 0")
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.10,
				"variance \(sampleVariance(xs)) vs \(expectedVar)")  // fat tails: 10%
	}

	@Test("sampleInverseGamma has mean β/(α-1)")
	func inverseGammaMoments() throws {
		let α = 5.0, β = 4.0
		var rng = DeterministicRNG(seed: 1009)
		var xs: [Double] = []
		xs.reserveCapacity(Self.n)
		for _ in 0..<Self.n {
			xs.append(try sampleInverseGamma(shape: α, scale: β, using: &rng))
		}
		let expectedMean = β / (α - 1.0)                              // 1.0
		let expectedVar = (β * β) / ((α - 1) * (α - 1) * (α - 2))     // 0.3333…
		#expect(abs(sampleMean(xs) - expectedMean) / expectedMean < 0.02)
		#expect(abs(sampleVariance(xs) - expectedVar) / expectedVar < 0.10,
				"variance \(sampleVariance(xs)) vs \(expectedVar)")   // heavy right tail: 10%
		#expect(xs.allSatisfy { $0 > 0 }, "Inverse-Gamma variates are positive")
	}
}
