//
//  SeededRandomnessTests.swift
//  BusinessMathTests
//
//  RED-phase tests for SplitMix64 and SeedableDistribution
//  (MonteCarloDeterminismAndAsyncExecution proposal, Phase 1).
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("SplitMix64 seeded generator")
struct SplitMix64Tests {

	/// Golden vectors derived from Vigna's reference splitmix64.c
	/// (seed 0 first output 0xE220A8397B1DCDAF is the published test vector;
	/// all values recomputed from the published algorithm on 2026-07-14).
	@Test("Reference vectors: seed 0")
	func referenceVectorsSeedZero() {
		var rng = SplitMix64(seed: 0)
		#expect(rng.next() == 0xE220A8397B1DCDAF)
		#expect(rng.next() == 0x6E789E6AA1B965F4)
		#expect(rng.next() == 0x06C45D188009454F)
	}

	@Test("Reference vectors: seed 42")
	func referenceVectorsSeed42() {
		var rng = SplitMix64(seed: 42)
		#expect(rng.next() == 0xBDD732262FEB6E95)
		#expect(rng.next() == 0x28EFE333B266F103)
		#expect(rng.next() == 0x47526757130F9F52)
	}

	@Test("Reference vectors: seed 1234567")
	func referenceVectorsSeed1234567() {
		var rng = SplitMix64(seed: 1_234_567)
		#expect(rng.next() == 0x599ED017FB08FC85)
		#expect(rng.next() == 0x2C73F08458540FA5)
		#expect(rng.next() == 0x883EBCE5A3F27C77)
	}

	@Test("Same seed produces identical streams")
	func identicalStreams() {
		var a = SplitMix64(seed: 9_876_543_210)
		var b = SplitMix64(seed: 9_876_543_210)
		for _ in 0..<100 {
			#expect(a.next() == b.next())
		}
	}

	@Test("Different seeds diverge")
	func differentSeedsDiverge() {
		var a = SplitMix64(seed: 1)
		var b = SplitMix64(seed: 2)
		let aValues = (0..<10).map { _ in a.next() }
		let bValues = (0..<10).map { _ in b.next() }
		#expect(aValues != bValues)
	}

	@Test("Drives Double.random(in:using:) within bounds")
	func drivesDoubleRandom() {
		var rng = SplitMix64(seed: 7)
		for _ in 0..<1_000 {
			let value = Double.random(in: 0...1, using: &rng)
			#expect(value >= 0 && value <= 1)
		}
	}
}

@Suite("SeedableDistribution refinement")
struct SeedableDistributionExemplarTests {

	@Test("DistributionNormal: same generator seed yields identical sample stream")
	func normalDeterministicStream() {
		let dist = DistributionNormal(1000, 200)
		var g1 = SplitMix64(seed: 42)
		var g2 = SplitMix64(seed: 42)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 == s2)
	}

	@Test("DistributionNormal: different seeds yield different streams")
	func normalSeedsDiverge() {
		let dist = DistributionNormal(1000, 200)
		var g1 = SplitMix64(seed: 1)
		var g2 = SplitMix64(seed: 2)
		let s1 = (0..<50).map { _ in dist.next(using: &g1) }
		let s2 = (0..<50).map { _ in dist.next(using: &g2) }
		#expect(s1 != s2)
	}

	@Test("DistributionNormal: seeded samples match distribution moments")
	func normalSeededMoments() {
		let dist = DistributionNormal(0, 1)
		var rng = SplitMix64(seed: 99)
		let n = 20_000
		let samples = (0..<n).map { _ in dist.next(using: &rng) }
		let mean = samples.reduce(0, +) / Double(n)
		let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(n - 1)
		// Deterministic given the fixed seed — tight bounds are safe.
		#expect(abs(mean) < 0.03)
		#expect(abs(variance - 1.0) < 0.05)
	}

	@Test("DistributionNormal is usable through the SeedableDistribution existential")
	func normalSeedableExistential() {
		let dist: any SeedableDistribution<Double> = DistributionNormal(5, 1)
		var rng = SplitMix64(seed: 3)
		let value = dist.next(using: &rng)
		#expect(value.isFinite)
	}
}
