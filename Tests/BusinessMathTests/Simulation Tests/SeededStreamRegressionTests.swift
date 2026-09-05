//
//  SeededStreamRegressionTests.swift
//  BusinessMathTests
//
//  Captured 2026-09-04, before ContinuousDistribution landed.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

/// Pins the seeded output of the two distributions whose sampler is *not* an
/// inverse transform.
///
/// `ContinuousDistribution` supplies a default `next(using:)` that samples by
/// inverse transform — one uniform in, one draw out. ``DistributionNormal`` samples
/// by Box–Muller and consumes two; ``DistributionGamma`` samples by Marsaglia–Tsang
/// rejection and consumes an unbounded number. Both conform to
/// `ContinuousDistribution` for its `cdf`/`quantile`, and both must keep their own
/// `next(using:)`.
///
/// Nothing in the type system enforces that. Swift's dispatch prefers a concrete
/// method over a protocol-extension default, so the rule holds right up until
/// someone deletes a method that looks redundant — at which point the same seed
/// silently produces a different stream, every downstream determinism test starts
/// failing for a reason that points somewhere else, and any stored simulation
/// result becomes unreproducible.
///
/// These values are that method's only guard. They are captured output, not
/// derived: their correctness as *samples* is established by the distribution's own
/// tests, and their job here is solely to be unchanged.
///
/// If a deliberate change to a sampling algorithm makes this fail, recapture the
/// values and say so in the commit — the failure is the point at which that
/// decision gets recorded.
@Suite("Seeded stream regression — non-inverse-transform samplers")
struct SeededStreamRegressionTests {

	/// Box–Muller, two uniforms per draw. Seed 42, `DistributionNormal(10.0, 2.5)`.
	static let normalSeed42: [Double] = [
		13.836218308833548,
		8.9995162641912891,
		9.6817251715578632,
		8.3581016909522301,
		9.0768178477718795,
		12.114363622424213,
		11.500480874498699,
		8.5659914709997391,
		8.0242704426976115,
		7.9930288454241278,
		14.917444621302403,
		8.0742864367185359
	]

	/// Marsaglia–Tsang rejection, an unbounded number of uniforms per draw.
	/// Seed 42, `DistributionGamma(r: 3, λ: 2.0)`.
	static let gammaSeed42: [Double] = [
		0.85177574195198646,
		4.4294106373544215,
		2.3001780058948316,
		1.1830405700950868,
		1.6220800005211902,
		2.4836777391187121,
		1.2786519717412375,
		0.84582451821336702,
		0.77888438250984526,
		1.4137938510532011,
		1.749328707819533,
		2.9767586021408814
	]

	@Test("DistributionNormal still samples by Box–Muller")
	func normalStreamUnchanged() {
		var generator = Xoshiro256StarStar(seed: 42)
		let distribution = DistributionNormal(10.0, 2.5)

		for (index, expected) in Self.normalSeed42.enumerated() {
			let actual = distribution.next(using: &generator)
			#expect(actual == expected,
				"Draw \(index) is \(actual), was \(expected). If DistributionNormal now inherits the inverse-transform default from ContinuousDistribution, restore its own next(using:) — see §3.4 of PROPOSAL_distribution_contract_and_sampling.md.")
		}
	}

	@Test("DistributionGamma still samples by Marsaglia–Tsang rejection")
	func gammaStreamUnchanged() {
		var generator = Xoshiro256StarStar(seed: 42)
		let distribution = DistributionGamma(r: 3, λ: 2.0)

		for (index, expected) in Self.gammaSeed42.enumerated() {
			let actual = distribution.next(using: &generator)
			#expect(actual == expected,
				"Draw \(index) is \(actual), was \(expected). If DistributionGamma now inherits the inverse-transform default from ContinuousDistribution, restore its own next(using:) — see §3.4 of PROPOSAL_distribution_contract_and_sampling.md.")
		}
	}

	@Test("A seeded stream is reproducible within a run")
	func streamsAreReproducible() {
		var first = Xoshiro256StarStar(seed: 7)
		var second = Xoshiro256StarStar(seed: 7)
		let distribution = DistributionNormal(0.0, 1.0)

		for _ in 0..<50 {
			#expect(distribution.next(using: &first) == distribution.next(using: &second))
		}
	}
}
