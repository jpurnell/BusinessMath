//
//  BoxMullerCanonicalTests.swift
//  BusinessMath
//
//  The canonical Box-Muller transform: full precision, reproducible, and finite.
//

import Foundation
import Testing
import TestSupport
@testable import BusinessMath

/// A generator that emits a scripted list of words, then repeats the last one.
///
/// `Double.random(in: 0..<1, using:)` consumes one word and keeps 53 bits of it,
/// so scripting the word is the only way to land a test on a specific uniform —
/// including the two that matter here, the smallest and the largest.
private struct WordRNG: RandomNumberGenerator {
	private var words: [UInt64]
	private var index = 0
	init(_ words: [UInt64]) { self.words = words }
	mutating func next() -> UInt64 {
		defer { index += 1 }
		return index < words.count ? words[index] : (words.last ?? 0)
	}
}

/// The canonical transform lives in one place and every Swift caller draws from it.
///
/// Two things it has to be that the seed-taking form on its own could not:
///
/// * **Full precision.** Seeds routed through `distributionUniform` are quantized to
///   multiples of 1e-7, which puts the whole distribution on a ten-million-point
///   lattice and caps the radius a legitimate draw can reach at
///   `sqrt(-2·log(1e-7))` = 5.6777. Above that only the old `1e-15` clamp could
///   reach, and it did so as an atom at 8.3113. `PortfolioUtilities` already drew
///   full 53-bit uniforms, so the shared routine had to match it before it could
///   absorb it. The gap this closes covers 1.37e-8 of the distribution — about
///   0.001 draws in a 10,000-iteration run, which is to say nothing anyone was
///   going to notice. It is closed because a shared routine should not be the
///   worst of the things it replaces.
///
/// * **Reproducible from a generator.** `inout RandomNumberGenerator` is the shape
///   the rest of the library standardised on (`git show 4b021b8`, `git show d247691`);
///   it lets one seed drive several blocks of draws without the caller inventing
///   seed arithmetic.
@Suite("Box-Muller Canonical Transform")
struct BoxMullerCanonicalTests {

	// MARK: - Full precision

	/// `1 - Double.random(in: 0..<1)` with an all-ones word gives u₁ = 2⁻⁵³,
	/// whose radius is `sqrt(2 · 53 · ln 2)` = 8.5716 — well past the 5.6777
	/// ceiling the quantized path could reach.
	@Test("The generator path reaches radii the 1e-7 lattice cannot")
	func fullPrecisionReachesDeepTail() {
		var rng = WordRNG([.max, 0])
		let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
		let radius = (z1 * z1 + z2 * z2).squareRoot()

		#expect(radius > 5.6777,
				"radius \(radius) — the quantized path tops out at sqrt(-2·log(1e-7)) = 5.6777")
		#expect(radius.isFinite)
		// u₁ = 2⁻⁵³ exactly, so the radius is pinned, not merely large.
		let expected = (2.0 * 53.0 * Foundation.log(2.0)).squareRoot()
		#expect(abs(radius - expected) < 1e-9, "radius \(radius), expected \(expected)")
	}

	/// A lattice shows up as every recovered uniform being a multiple of 1e-7.
	/// Recovering `u₁ = exp(-r²/2)` from the pair is exact to a few ulp, so the
	/// test can look straight at the quantity that was quantized.
	@Test("Draws are not confined to the 1e-7 lattice")
	func fullPrecisionIsNotOnALattice() {
		var rng = DeterministicRNG(seed: 20_260_809)
		var offLattice = 0
		let n = 1_000

		for _ in 0..<n {
			let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
			let u1 = Foundation.exp(-(z1 * z1 + z2 * z2) / 2.0)
			let scaled = u1 * 10_000_000.0
			if abs(scaled - scaled.rounded()) > 1e-3 { offLattice += 1 }
		}

		// On the lattice this count is 0. Off it, essentially every draw misses.
		#expect(offLattice > n - 10, "\(offLattice) of \(n) draws were off the 1e-7 lattice")
	}

	/// The seed-taking form is the same transform, so it must lose the lattice too.
	/// A seed *is* a uniform; running it through `distributionUniform` to get
	/// another uniform only threw away 46 bits of it.
	@Test("The seed form no longer quantizes its seeds")
	func seedFormIsFullPrecision() {
		// Two seeds that the 1e-7 lattice cannot tell apart.
		let (a, _): (Double, Double) = boxMullerSeed(0.500_000_04, 0.25)
		let (b, _): (Double, Double) = boxMullerSeed(0.500_000_09, 0.25)
		#expect(a != b, "both seeds quantize to 0.5; the transform must still see the difference")

		// And a seed below the lattice floor is a real tail draw, not the 8.3113 atom.
		let (z1, z2): (Double, Double) = boxMullerSeed(1e-9, 0.0)
		let radius = (z1 * z1 + z2 * z2).squareRoot()
		let expected = (-2.0 * Foundation.log(1e-9)).squareRoot()
		#expect(abs(radius - expected) < 1e-9, "radius \(radius), expected \(expected)")
	}

	// MARK: - Reproducibility

	@Test("The same seed twice gives the same stream")
	func generatorPathIsReproducible() {
		func draw(_ seed: UInt64) -> [Double] {
			var rng = DeterministicRNG(seed: seed)
			return (0..<200).flatMap { _ -> [Double] in
				let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
				return [z1, z2]
			}
		}
		// Reproducibility is a bit-for-bit claim. Written with `==` it would be weaker in
		// both directions: two runs that both went NaN in the same place would *fail* the
		// first assertion, and the second would *pass* on a stream that had silently gone
		// NaN throughout — satisfied for exactly the reason it was written to exclude.
		#expect(identical(draw(7), draw(7)))
		#expect(!identical(draw(7), draw(8)))
	}

	@Test("One generator threaded through many calls does not repeat itself")
	func oneGeneratorGivesIndependentBlocks() {
		var rng = DeterministicRNG(seed: 11)
		let first: (z1: Double, z2: Double) = boxMullerSeed(using: &rng)
		let second: (z1: Double, z2: Double) = boxMullerSeed(using: &rng)
		#expect(first != second)
	}

	// MARK: - Distributional sanity

	/// Mean, variance, and — the one nothing asserted before the `cos(2π)` fix —
	/// that the two variates of a pair are uncorrelated. A `cos(2π)`-shaped
	/// mistake leaves z2 equal to the radius times a uniform, which is strongly
	/// correlated with z1 and has variance 1/3; both bounds below reject it.
	@Test("Seeded moments: mean 0, variance 1, and the pair uncorrelated")
	func generatorPathMomentsAreStandardNormal() {
		var rng = DeterministicRNG(seed: 424_242)
		let n = 200_000
		var s1 = 0.0, s2 = 0.0, q1 = 0.0, q2 = 0.0, cross = 0.0

		for _ in 0..<n {
			let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
			s1 += z1; s2 += z2
			q1 += z1 * z1; q2 += z2 * z2
			cross += z1 * z2
		}

		let m1 = s1 / Double(n), m2 = s2 / Double(n)
		let v1 = q1 / Double(n) - m1 * m1
		let v2 = q2 / Double(n) - m2 * m2
		// Standard error of the mean is 1/sqrt(200_000) = 0.0022; 0.01 is 4.5 of those.
		#expect(abs(m1) < 0.01, "z1 mean \(m1)")
		#expect(abs(m2) < 0.01, "z2 mean \(m2)")
		#expect(abs(v1 - 1.0) < 0.02, "z1 variance \(v1)")
		#expect(abs(v2 - 1.0) < 0.02, "z2 variance \(v2)")

		let correlation = (cross / Double(n) - m1 * m2) / (v1 * v2).squareRoot()
		#expect(abs(correlation) < 0.01, "z1/z2 correlation \(correlation)")
	}

	// MARK: - The pole

	@Test("No non-finite output over a large seeded run")
	func generatorPathIsAlwaysFinite() {
		var rng = DeterministicRNG(seed: 8_675_309)
		// The first offending draw, if there is one, and then stop: half a million more
		// reports of the same defect say nothing the first does not.
		var firstNonFinite: (z1: Double, z2: Double)?
		for _ in 0..<500_000 {
			let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
			if !z1.isFinite || !z2.isFinite {
				firstNonFinite = (z1, z2)
				break
			}
		}
		#expect(firstNonFinite == nil,
				"non-finite draw \(String(describing: firstNonFinite)) over 500,000 seeded draws")
	}

	/// A generator stuck on zero words is the pole itself: `Double.random(in: 0..<1)`
	/// returns 0.0 every time, so an implementation that fed `u₁` straight to `log`
	/// would return -∞. `1 - u` sends it to 1, whose radius is 0 — the correct
	/// value for that draw, and no atom anywhere.
	@Test("A generator that only returns zero words stays finite")
	func zeroWordGeneratorIsFinite() {
		var rng = WordRNG([0])
		for _ in 0..<100 {
			let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
			#expect(z1.isFinite && z2.isFinite, "(\(z1), \(z2))")
			// Exactly zero, not near zero: a tolerance would also pass for a radius that
			// was merely tiny, which is what the *almost*-correct guard produces —
			// `log(u + 1e-10)` instead of `1 - u` — and is the failure this excludes.
			//
			// IEEE equality rather than a bit comparison, because the sign of this zero
			// is not part of the claim and is not positive: `log 1` is `+0.0`, so the
			// radius is `sqrt(-2 · +0.0)` = `sqrt(-0.0)` = `-0.0`, and both products
			// inherit that sign. `-0.0` is the mean just as much as `+0.0` is.
			#expect(exactlyEqual(z1, 0.0), "u₁ = 1 has radius 0; got z₁ = \(z1)")
			#expect(exactlyEqual(z2, 0.0), "u₁ = 1 has radius 0; got z₂ = \(z2)")
		}
	}

	@Test("A generator stuck on all-ones words stays finite")
	func maxWordGeneratorIsFinite() {
		var rng = WordRNG([.max])
		for _ in 0..<100 {
			let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
			#expect(z1.isFinite && z2.isFinite, "(\(z1), \(z2))")
		}
	}

	@Test("The seed form is finite across the whole closed [0, 1]",
		  arguments: [0.0, 1e-300, 1e-15, 1e-9, 1e-7, 0.25, 0.5, 1.0 - 1e-16, 1.0])
	func seedFormIsFiniteEverywhere(seed: Double) {
		for other in [0.0, 0.5, 1.0] {
			let (z1, z2): (Double, Double) = boxMullerSeed(seed, other)
			#expect(z1.isFinite, "boxMullerSeed(\(seed), \(other)).z1 = \(z1)")
			#expect(z2.isFinite, "boxMullerSeed(\(seed), \(other)).z2 = \(z2)")
			let (w1, w2): (Double, Double) = boxMullerSeed(other, seed)
			#expect(w1.isFinite && w2.isFinite, "boxMullerSeed(\(other), \(seed))")
		}
	}

	// MARK: - One variate without waste

	/// `distributionRayleigh` wants the *radius*, not a normal variate. Asking the
	/// pair-returning entry point for it would compute a sine and a cosine and
	/// throw both away, and would consume two uniforms where one is needed — which
	/// is why the radius is its own entry point rather than a caller inlining
	/// `sqrt(-2·log(u))` for the eleventh time.
	@Test("The radius entry point consumes exactly one uniform")
	func radiusDrawsOneUniform() {
		// A counting generator: the pair takes two words, the radius one.
		final class Counter: @unchecked Sendable { var count = 0 } // Justification: A test-local counter mutated and read from one task inside a single test body; never shared across concurrent contexts.
		struct CountingRNG: RandomNumberGenerator {
			let counter: Counter
			func next() -> UInt64 {
				counter.count += 1
				return 0x9E37_79B9_7F4A_7C15
			}
		}

		let pairCounter = Counter()
		var pairRNG = CountingRNG(counter: pairCounter)
		let _: (z1: Double, z2: Double) = boxMullerSeed(using: &pairRNG)
		#expect(pairCounter.count == 2)

		let radiusCounter = Counter()
		var radiusRNG = CountingRNG(counter: radiusCounter)
		let _: Double = boxMullerRadius(using: &radiusRNG)
		#expect(radiusCounter.count == 1)
	}

	/// The radius is the same quantity the pair is built from, so the two must agree
	/// exactly when handed the same uniform.
	@Test("The radius agrees with the pair it is built from")
	func radiusMatchesThePair() {
		for seed in [0.001, 0.1, 0.5, 0.9, 0.999_999_9] {
			let radius: Double = boxMullerRadius(seed)
			let (z1, z2): (Double, Double) = boxMullerSeed(seed, 0.375)
			let fromPair = (z1 * z1 + z2 * z2).squareRoot()
			#expect(abs(radius - fromPair) < 1e-12 * Swift.max(1.0, radius),
					"seed \(seed): radius \(radius), pair \(fromPair)")
		}
	}

	@Test("The radius is finite and non-negative across the closed seed range",
		  arguments: [0.0, 1e-300, 1e-9, 1e-7, 0.5, 1.0 - 1e-16, 1.0])
	func radiusIsFiniteEverywhere(seed: Double) {
		let radius: Double = boxMullerRadius(seed)
		#expect(radius.isFinite, "boxMullerRadius(\(seed)) = \(radius)")
		#expect(radius >= 0.0)
	}
}
