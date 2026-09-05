//
//  SeededStreamRegressionTests.swift
//  BusinessMathTests
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

/// Guards the rule that a retrofitted distribution keeps its own `next(using:)`.
///
/// ``ContinuousDistribution`` supplies a default sampler by inverse transform — one
/// uniform in, one draw out. ``DistributionNormal`` samples by Box–Muller and consumes
/// two; ``DistributionGamma`` samples by Marsaglia–Tsang rejection and consumes an
/// unbounded number. Both conform for their `cdf` and `quantile`, and both must keep
/// their own sampler, or the same seed silently produces a different stream and every
/// stored simulation result becomes unreproducible.
///
/// Swift's dispatch prefers a concrete method over a protocol-extension default, so
/// the rule holds right up until someone deletes a method that looks redundant.
///
/// ## Why there are no captured values here
///
/// The obvious guard is to paste twenty-four draws from a fixed seed and assert they
/// never change. That works, and it is the wrong test: the numbers explain nothing, a
/// reader cannot tell a correct one from a corrupted one, and a legitimate improvement
/// to a sampler fails the suite with no indication of what was actually violated.
///
/// The property is *"this type did not inherit the default"*, and that is directly
/// observable. Inverse transform draws exactly one word from the generator and returns
/// `quantile` of it. So a type that inherited the default produces exactly that value,
/// and one that did not, does not — no captured data required, and the failure message
/// says which rule broke.
@Suite("Seeded stream regression — non-inverse-transform samplers")
struct SeededStreamRegressionTests {

	/// Counts how many words a sampler draws, so the sampling *method* can be
	/// identified rather than assumed.
	struct CountingGenerator: RandomNumberGenerator {
		private var underlying: Xoshiro256StarStar
		private(set) var wordsDrawn = 0

		init(seed: UInt64) { underlying = Xoshiro256StarStar(seed: seed) }

		mutating func next() -> UInt64 {
			wordsDrawn += 1
			return underlying.next()
		}
	}

	/// What the protocol's default sampler would return from this generator state.
	private func inverseTransformDraw<D: ContinuousDistribution>(
		_ distribution: D, seed: UInt64
	) -> Double where D.T == Double {
		var generator = Xoshiro256StarStar(seed: seed)
		return distribution.quantile(Double.openUnitRandom(using: &generator))
	}

	@Test("DistributionNormal still samples by Box–Muller, not by inverse transform")
	func normalKeepsBoxMuller() {
		let distribution = DistributionNormal(10.0, 2.5)
		let seed: UInt64 = 42

		var generator = Xoshiro256StarStar(seed: seed)
		let actual = distribution.next(using: &generator)
		let ifInherited = inverseTransformDraw(distribution, seed: seed)

		// Bit-identity, not numeric inequality: the claim is "this is not the same
		// computation", and an inherited default would reproduce the value exactly.
		#expect(actual.bitPattern != ifInherited.bitPattern,
			"DistributionNormal returned exactly what the inherited inverse-transform default would, which means it no longer has its own next(using:). Restore it — see §3.4 of PROPOSAL_distribution_contract_and_sampling.md.")

		// Box–Muller needs a radius and an angle: two words, every draw.
		var counter = CountingGenerator(seed: seed)
		_ = distribution.next(using: &counter)
		#expect(counter.wordsDrawn == 2,
			"Box–Muller draws two uniforms; this drew \(counter.wordsDrawn)")
	}

	@Test("DistributionGamma still samples by Marsaglia–Tsang rejection")
	func gammaKeepsRejectionSampling() {
		let distribution = DistributionGamma(r: 3, λ: 2.0)
		let seed: UInt64 = 42

		var generator = Xoshiro256StarStar(seed: seed)
		let actual = distribution.next(using: &generator)
		let ifInherited = inverseTransformDraw(distribution, seed: seed)

		#expect(actual.bitPattern != ifInherited.bitPattern,
			"DistributionGamma returned exactly what the inherited inverse-transform default would, which means it no longer has its own next(using:).")

		// Rejection sampling consumes a variable number of words, and more than one.
		var counts = Set<Int>()
		for trial in UInt64(1)...50 {
			var counter = CountingGenerator(seed: trial)
			_ = distribution.next(using: &counter)
			counts.insert(counter.wordsDrawn)
		}
		#expect(counts.allSatisfy { $0 > 1 },
			"a rejection sampler cannot draw a single word: saw \(counts.sorted())")
	}

	@Test("A type that does inherit the default draws exactly one word")
	func inheritedDefaultDrawsOneWord() {
		// The control. Without it the assertions above could pass because the counting
		// generator is wrong rather than because the samplers are right.
		struct Inherited: ContinuousDistribution {
			typealias T = Double
			func cdf(_ x: Double) -> Double { x <= 0 ? 0 : -Double.expMinusOne(-x) }
			func quantile(_ p: Double) -> Double { -Double.log(onePlus: -p) }
		}

		let distribution = Inherited()
		var counter = CountingGenerator(seed: 42)
		let drawn = distribution.next(using: &counter)

		#expect(counter.wordsDrawn == 1,
			"the inverse-transform default must draw exactly one word, or a quasi-random point set cannot stay aligned with it")
		#expect(drawn.bitPattern == inverseTransformDraw(distribution, seed: 42).bitPattern,
			"the default sampler must be exactly quantile(openUnitRandom)")
	}

	@Test("A seeded stream is reproducible")
	func streamsAreReproducible() {
		let distributions: [any SeedableDistribution<Double>] = [
			DistributionNormal(0.0, 1.0),
			DistributionGamma(r: 3, λ: 2.0),
			DistributionLogNormal(0.5, 0.75),
			DistributionBeta(alpha: 2.0, beta: 5.0)
		]
		for distribution in distributions {
			var first = Xoshiro256StarStar(seed: 7)
			var second = Xoshiro256StarStar(seed: 7)
			for _ in 0..<50 {
				let a = distribution.next(using: &first)
				let b = distribution.next(using: &second)
				// Bit-identity is the reproducibility claim, and finiteness is asserted
				// separately: `a == b` is false for NaN, while `bitPattern ==` is true,
				// so neither operator alone distinguishes "same stream" from "same
				// stream of NaNs".
				#expect(a.isFinite, "\(type(of: distribution)) produced \(a)")
				#expect(a.bitPattern == b.bitPattern,
					"\(type(of: distribution)) is not reproducible from its seed")
			}
		}
	}
}
