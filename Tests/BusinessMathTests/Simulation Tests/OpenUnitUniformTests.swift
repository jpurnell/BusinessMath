//
//  OpenUnitUniformTests.swift
//  BusinessMath
//
//  The mapping every seeded sampler in the package goes through.
//

import Testing
import TestSupport
import Foundation
@testable import BusinessMath

/// ``openUnitUniform(_:using:)`` — the endpoints, the draw count, and the distribution.
///
/// The endpoints are the point of the function, and nothing asserted them until this suite.
/// The first version of the mapping used 53 bits, `(Double(x >> 11) + 0.5) * 0x1p-53`, which is
/// the form most references give. It returns **exactly 1.0** on an all-ones word: the largest
/// shifted word is `2⁵³ - 1`, adding `0.5` needs a 54th significant bit, and the sum rounds
/// ties-to-even up to `2⁵³`. The half-cell offset that opens the bottom of the interval closes
/// the top, and `boxMullerSeed` through it produced a radius of `-0.0` — the pole the whole
/// exercise existed to make unreachable, reached on the first draw.
///
/// It was found by printing the value, not by reading the formula. These tests are what makes
/// it stay found.
@Suite("Open unit uniform")
struct OpenUnitUniformTests {

	/// A generator that returns the same word forever, so an endpoint can be demanded.
	private struct ConstantWordRNG: RandomNumberGenerator {
		let word: UInt64
		func next() -> UInt64 { word }
	}

	@Test("The smallest word gives the smallest uniform, and it is above zero")
	func smallestWordIsAboveZero() {
		var rng = ConstantWordRNG(word: 0)
		let u: Double = openUnitUniform(Double.self, using: &rng)
		// (0 + 0.5) · 2⁻⁵² = 2⁻⁵³.
		#expect(identical(u, 0x1p-53), "the zero word gave \(u), not 2⁻⁵³")
		#expect(u > 0.0, "a uniform of \(u) is not inside the open interval")
	}

	@Test("The largest word gives the largest uniform, and it is below one")
	func largestWordIsBelowOne() {
		var rng = ConstantWordRNG(word: .max)
		let u: Double = openUnitUniform(Double.self, using: &rng)
		// (2⁵² − 1 + 0.5) · 2⁻⁵² = 1 − 2⁻⁵³, the largest Double below one.
		#expect(identical(u, 1.0 - 0x1p-53), "the all-ones word gave \(u), not 1 − 2⁻⁵³")
		#expect(u < 1.0, "a uniform of \(u) is not inside the open interval — this is the regression")
	}

	@Test("The logarithm of every extreme is finite")
	func logarithmsStayFinite() {
		// The reason the interval has to be open, stated as the thing that actually breaks.
		for word: UInt64 in [0, 1, 2, UInt64.max, UInt64.max - 1, 1 << 63, (1 << 63) | 1] {
			var rng = ConstantWordRNG(word: word)
			let u: Double = openUnitUniform(Double.self, using: &rng)
			#expect(Foundation.log(u).isFinite, "log(\(u)) from word \(word) is not finite")
			#expect((1.0 / u).isFinite, "1/\(u) from word \(word) is not finite")
			#expect(Foundation.log1p(-u).isFinite, "log(1 − \(u)) from word \(word) is not finite")
		}
	}

	@Test("Ten million draws never reach an endpoint")
	func manyDrawsStayInside() {
		// The endpoint tests above demand the extremes from a rigged generator. This one asks
		// whether a real stream can stumble onto one, which is the question a caller has.
		var rng = DeterministicRNG(seed: 20_260_910)
		var atZero = 0
		var atOne = 0
		for _ in 0..<10_000_000 {
			let u: Double = openUnitUniform(Double.self, using: &rng)
			if u <= 0.0 { atZero += 1 }
			if u >= 1.0 { atOne += 1 }
		}
		#expect(atZero == 0, "\(atZero) draws were at or below zero")
		#expect(atOne == 0, "\(atOne) draws were at or above one")
	}

	@Test("It advances the generator exactly once")
	func advancesExactlyOnce() {
		// The contract a caller interleaving several families on one stream depends on, and the
		// reason this is not rejection sampling: a variable number of draws would make the
		// order of a mixed stream unpredictable.
		var counting = DrawCountingRNG(base: DeterministicRNG(seed: 11))
		let _: Double = openUnitUniform(Double.self, using: &counting)
		#expect(counting.draws == 1, "one uniform consumed \(counting.draws) words")
	}

	@Test("The draws are uniform")
	func drawsAreUniform() {
		// Not a strong test of uniformity and not meant to be — the endpoints are this
		// function's subject. It is here so a mapping that is open at both ends but badly
		// distributed cannot pass the suite. Standard error of the mean of n uniforms is
		// 1/√(12n); at n = 200,000 that is 6.45e-4, and four of those is 2.6e-3.
		var rng = DeterministicRNG(seed: 4_242)
		let n = 200_000
		var total = 0.0
		for _ in 0..<n {
			total += openUnitUniform(Double.self, using: &rng)
		}
		let mean: Double = total / Double(n)
		#expect(abs(mean - 0.5) < 2.6e-3, "mean of \(n) draws was \(mean)")
	}
}

/// Counts the words a consumer takes from its base generator.
// Justification: A struct with value semantics; each copy counts its own draws and none is shared.
private struct DrawCountingRNG<Base: RandomNumberGenerator>: RandomNumberGenerator {
	var base: Base
	var draws = 0
	init(base: Base) { self.base = base }
	mutating func next() -> UInt64 {
		draws += 1
		return base.next()
	}
}
