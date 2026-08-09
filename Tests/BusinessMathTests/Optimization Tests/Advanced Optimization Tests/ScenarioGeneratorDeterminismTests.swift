//
//  ScenarioGeneratorDeterminismTests.swift
//  BusinessMathTests
//
//  `ScenarioGenerator.normal`, `.bootstrap` and `.uniform` each advertised a seed
//  "for reproducibility" and then drew from `srand48`/`drand48` — one stream shared
//  by the whole process. A seed that only holds when nothing else is drawing is not
//  a seed. These tests pin the three properties the parameter always claimed:
//  same seed reproduces, different seeds diverge, and neither of those depends on
//  what any other thread happens to be doing at the time.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("ScenarioGenerator determinism")
struct ScenarioGeneratorDeterminismTests {

	// MARK: - Fixtures

	/// Ten observations of two variables, for the bootstrap generator.
	private static let historicalData: [[Double]] = [
		[0.05, 0.03], [0.12, 0.08], [-0.02, 0.01], [0.15, 0.10], [0.08, 0.05],
		[0.02, 0.02], [0.18, 0.12], [-0.05, 0.00], [0.10, 0.06], [0.07, 0.04]
	]

	/// Flattens a scenario list into the parameter values in generation order, so two
	/// runs can be compared for bit-identity rather than for statistical similarity.
	private static func values(_ scenarios: [MonteCarloScenario], dimension: Int) -> [Double] {
		scenarios.flatMap { scenario in
			(0..<dimension).map { scenario["param_\($0)"] ?? .nan }
		}
	}

	private static func normalRun(seed: UInt64, count: Int = 200) -> [Double] {
		values(
			ScenarioGenerator.normal(
				mean: [0.10, 0.12],
				standardDeviation: [0.15, 0.20],
				numberOfScenarios: count,
				seed: seed
			),
			dimension: 2
		)
	}

	private static func bootstrapRun(seed: UInt64, count: Int = 200) throws -> [Double] {
		values(
			try ScenarioGenerator.bootstrap(
				historicalData: historicalData,
				numberOfScenarios: count,
				seed: seed
			),
			dimension: 2
		)
	}

	private static func uniformRun(seed: UInt64, count: Int = 200) -> [Double] {
		values(
			ScenarioGenerator.uniform(
				lowerBounds: [0.0, -1.0],
				upperBounds: [1.0, 3.0],
				numberOfScenarios: count,
				seed: seed
			),
			dimension: 2
		)
	}

	// MARK: - Reproducibility

	// Both halves of the contract are asserted for each generator. "Same seed, same
	// output" alone is satisfied by a function that ignores its input and returns a
	// constant, so it cannot distinguish a working seed from a dead one.

	@Test("normal: the same seed reproduces the same scenarios")
	func normalSameSeedIsReproducible() {
		#expect(Self.normalRun(seed: 42) == Self.normalRun(seed: 42))
	}

	@Test("normal: different seeds produce different scenarios")
	func normalDifferentSeedsDiverge() {
		#expect(Self.normalRun(seed: 42) != Self.normalRun(seed: 43))
	}

	@Test("bootstrap: the same seed reproduces the same scenarios")
	func bootstrapSameSeedIsReproducible() throws {
		#expect(try Self.bootstrapRun(seed: 42) == Self.bootstrapRun(seed: 42))
	}

	@Test("bootstrap: different seeds produce different scenarios")
	func bootstrapDifferentSeedsDiverge() throws {
		#expect(try Self.bootstrapRun(seed: 42) != Self.bootstrapRun(seed: 43))
	}

	@Test("uniform: the same seed reproduces the same scenarios")
	func uniformSameSeedIsReproducible() {
		#expect(Self.uniformRun(seed: 42) == Self.uniformRun(seed: 42))
	}

	@Test("uniform: different seeds produce different scenarios")
	func uniformDifferentSeedsDiverge() {
		#expect(Self.uniformRun(seed: 42) != Self.uniformRun(seed: 43))
	}

	// MARK: - Concurrency

	/// The defect, stated directly: two seeded generations running at the same time.
	///
	/// With `srand48`/`drand48` the draws come from one process-global stream, so
	/// concurrent callers consume each other's values and neither gets the sequence its
	/// seed names. The failure is a race, so it is intermittent — this runs enough
	/// rounds, with enough work per round, that interleaving is near-certain somewhere.
	/// Each task is compared against *its own* serial baseline, which is the property a
	/// seed is supposed to guarantee.
	@Test("normal: concurrent seeded runs each match their serial baseline")
	func normalConcurrentRunsAreIsolated() async {
		let baselineA = Self.normalRun(seed: 1_001, count: 500)
		let baselineB = Self.normalRun(seed: 2_002, count: 500)

		for round in 0..<40 {
			async let a = Task.detached { Self.normalRun(seed: 1_001, count: 500) }.value
			async let b = Task.detached { Self.normalRun(seed: 2_002, count: 500) }.value
			let (resultA, resultB) = await (a, b)

			#expect(resultA == baselineA, "round \(round): seed 1001 did not reproduce under concurrency")
			#expect(resultB == baselineB, "round \(round): seed 2002 did not reproduce under concurrency")
		}
	}

	@Test("uniform and bootstrap: concurrent seeded runs of different generators do not interfere")
	func mixedGeneratorsConcurrentRunsAreIsolated() async throws {
		let uniformBaseline = Self.uniformRun(seed: 3_003, count: 500)
		let bootstrapBaseline = try Self.bootstrapRun(seed: 4_004, count: 500)

		for round in 0..<40 {
			async let u = Task.detached { Self.uniformRun(seed: 3_003, count: 500) }.value
			async let b = Task.detached { try? Self.bootstrapRun(seed: 4_004, count: 500) }.value
			let (uniformResult, bootstrapResult) = await (u, b)

			#expect(uniformResult == uniformBaseline, "round \(round): uniform seed 3003 did not reproduce")
			#expect(bootstrapResult == bootstrapBaseline, "round \(round): bootstrap seed 4004 did not reproduce")
		}
	}

	// MARK: - Seed range

	/// `seed` is `UInt64`, so every one of its values is legal input. The old code wrote
	/// `srand48(Int(seed))`, which traps for anything above `Int.max` — a library killing
	/// the host process on a value its own signature accepts.
	@Test("a seed above Int.max is accepted, not a trap")
	func largeSeedDoesNotTrap() throws {
		let large: UInt64 = UInt64(Int.max) + 1
		let larger: UInt64 = .max

		let a = Self.normalRun(seed: large, count: 20)
		let b = Self.normalRun(seed: large, count: 20)
		#expect(a == b)
		#expect(a.allSatisfy { $0.isFinite })

		#expect(Self.uniformRun(seed: larger, count: 20).allSatisfy { $0.isFinite })
		#expect(try Self.bootstrapRun(seed: larger, count: 20).allSatisfy { $0.isFinite })
	}

	/// `srand48` keeps only 48 bits, so seeds differing above bit 47 were the same seed.
	@Test("seeds differing only above bit 47 produce different scenarios")
	func highSeedBitsAreNotDiscarded() {
		let low: UInt64 = 0x0000_0000_0000_002A
		let high: UInt64 = 0x0001_0000_0000_002A   // identical in the low 48 bits
		#expect(Self.normalRun(seed: low, count: 50) != Self.normalRun(seed: high, count: 50))
	}

	// MARK: - Caller-owned streams

	@Test("normal: a caller-supplied generator reproduces the scenarios")
	func normalWithGeneratorIsReproducible() {
		var g1 = SplitMix64(seed: 7)
		var g2 = SplitMix64(seed: 7)
		let a = ScenarioGenerator.normal(mean: [0, 1], standardDeviation: [1, 2], numberOfScenarios: 100, using: &g1)
		let b = ScenarioGenerator.normal(mean: [0, 1], standardDeviation: [1, 2], numberOfScenarios: 100, using: &g2)
		#expect(Self.values(a, dimension: 2) == Self.values(b, dimension: 2))
	}

	@Test("uniform: a caller-supplied generator reproduces the scenarios")
	func uniformWithGeneratorIsReproducible() {
		var g1 = SplitMix64(seed: 7)
		var g2 = SplitMix64(seed: 7)
		let a = ScenarioGenerator.uniform(lowerBounds: [0], upperBounds: [1], numberOfScenarios: 100, using: &g1)
		let b = ScenarioGenerator.uniform(lowerBounds: [0], upperBounds: [1], numberOfScenarios: 100, using: &g2)
		#expect(Self.values(a, dimension: 1) == Self.values(b, dimension: 1))
	}

	@Test("bootstrap: a caller-supplied generator reproduces the scenarios")
	func bootstrapWithGeneratorIsReproducible() throws {
		var g1 = SplitMix64(seed: 7)
		var g2 = SplitMix64(seed: 7)
		let a = try ScenarioGenerator.bootstrap(historicalData: Self.historicalData, numberOfScenarios: 100, using: &g1)
		let b = try ScenarioGenerator.bootstrap(historicalData: Self.historicalData, numberOfScenarios: 100, using: &g2)
		#expect(Self.values(a, dimension: 2) == Self.values(b, dimension: 2))
	}

	/// The reason the `using:` overloads exist. Three seeded calls with one seed give
	/// three streams that all start at the same place; sharing one generator gives three
	/// independent blocks without the caller inventing seed arithmetic.
	@Test("one generator drives successive blocks without restarting the stream")
	func successiveBlocksOnOneGeneratorDiffer() {
		var rng = DeterministicRNG(seed: 99)
		let first = ScenarioGenerator.uniform(lowerBounds: [0], upperBounds: [1], numberOfScenarios: 50, using: &rng)
		let second = ScenarioGenerator.uniform(lowerBounds: [0], upperBounds: [1], numberOfScenarios: 50, using: &rng)
		#expect(Self.values(first, dimension: 1) != Self.values(second, dimension: 1))

		// Whereas two seeded calls with the same seed are, correctly, the same block.
		#expect(Self.uniformRun(seed: 99, count: 50) == Self.uniformRun(seed: 99, count: 50))
	}

	// MARK: - Distributional sanity

	/// Determinism is worthless if the numbers stopped being normal. Both moments are
	/// checked, seeded, against bounds derived from the sampling error at n = 20,000:
	/// se(mean) = σ/√n = 0.15/141.4 ≈ 1.06e-3 and se(sd) ≈ σ/√(2n) ≈ 7.5e-4. The bounds
	/// below are roughly five standard errors — loose enough that no legitimate stream
	/// fails, tight enough that a Box–Muller that lost its scale or its centre could not
	/// pass. Seeded, so it is one fixed arithmetic fact rather than a 3σ coin flip.
	@Test("normal: the seeded stream has the requested mean and standard deviation")
	func normalMomentsAreCorrect() {
		let n = 20_000
		let scenarios = ScenarioGenerator.normal(
			mean: [0.10, -2.0],
			standardDeviation: [0.15, 4.0],
			numberOfScenarios: n,
			seed: 20_260_809
		)

		for (index, (expectedMean, expectedSD)) in zip([0.10, -2.0], [0.15, 4.0]).enumerated() {
			let sample = scenarios.map { $0["param_\(index)"] ?? .nan }
			let mean = sample.reduce(0.0, +) / Double(n)
			let variance = sample.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(n - 1)
			let sd = variance.squareRoot()

			#expect(abs(mean - expectedMean) < expectedSD * 5.0 / Double(n).squareRoot(),
					"param_\(index) mean \(mean) is not within five standard errors of \(expectedMean)")
			#expect(abs(sd - expectedSD) < expectedSD * 5.0 / (2.0 * Double(n)).squareRoot(),
					"param_\(index) sd \(sd) is not within five standard errors of \(expectedSD)")
		}
	}

	/// Every generated value must be finite. Box–Muller's first uniform sits under a
	/// logarithm, and `Double.random(in: 0..<1)` includes exactly zero — `log(0)` is
	/// `-infinity`, and the variate that comes out of it is not a number.
	@Test("normal: no draw is non-finite")
	func normalDrawsAreFinite() {
		for seed in UInt64(0)..<UInt64(25) {
			let sample = Self.normalRun(seed: seed, count: 400)
			#expect(sample.allSatisfy { $0.isFinite }, "seed \(seed) produced a non-finite draw")
		}
	}

	/// The pole itself, forced. A generator pinned to return all-zero words makes
	/// `Double.random(in: 0..<1)` return exactly 0.0, which is the input `log` cannot take.
	@Test("normal: a uniform draw of exactly zero still yields a finite variate")
	func normalSurvivesAZeroUniform() {
		var rng = ZeroGenerator()
		let scenarios = ScenarioGenerator.normal(
			mean: [0.0], standardDeviation: [1.0], numberOfScenarios: 4, using: &rng
		)
		let sample = Self.values(scenarios, dimension: 1)
		#expect(sample.count == 4)
		#expect(sample.allSatisfy { $0.isFinite },
				"a zero uniform reached log() unguarded: \(sample)")
	}
}

/// A generator that always returns zero — the worst case for anything that takes a
/// logarithm of a uniform draw. `Double.random(in: 0..<1, using:)` returns exactly 0.0
/// from it, which is a legal draw from `[0, 1)` and a pole for `log`.
private struct ZeroGenerator: RandomNumberGenerator {
	mutating func next() -> UInt64 { 0 }
}
