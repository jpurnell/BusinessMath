//
//  TriangularSupportTests.swift
//  BusinessMath
//
//  The triangular sampler returned numbers from outside its own support, and said nothing.
//
//  `Distribution.triangular(min:mode:max:)` is a plain enum case with no validating
//  constructor, so any three numbers reach the sampler. The `fp-safety:disable` on its
//  division named the missing requirement — *"triangular requires max > min"* — as the reason
//  the line was safe, and nothing anywhere required it.
//
//  What made it worth finding is that nothing failed. No NaN, no crash: the sampler went on
//  returning ordinary-looking numbers, from outside the interval its own parameters describe,
//  straight into a Monte Carlo. Measured over 20,000 draws before the fix:
//
//  | parameters | support | observed | outside |
//  |---|---|---|---|
//  | `(0.15, 0.21, 0.30)` sound | [0.15, 0.30] | [0.150, 0.300] | 0 |
//  | `(0.20, 0.20, 0.20)` degenerate | [0.20, 0.20] | [0.20, 0.20] | 0 |
//  | `(0.10, 0.90, 0.20)` mode outside | [0.10, 0.20] | [0.101, 0.383] | **17,578** |
//  | `(0.30, 0.20, 0.10)` transposed | [0.10, 0.30] | [4.6e-06, 0.400] | **20,000** |
//
//  The comment two cases above it in the source already records this package being bitten by
//  exactly this shape: a suppression whose stated reason was false, on the Box-Muller pole.
//

import Testing
import Foundation
@testable import BusinessMath
@testable import BusinessMathDSL

@Suite("Triangular sampling stays inside its support")
struct TriangularSupportTests {

	/// Enough draws that a support violation of the size measured above cannot hide.
	///
	/// The transposed case put every one of 20,000 samples outside, and the mode-outside case
	/// 88% of them, so this many would have failed on the first few.
	private static let draws = 20_000

	@Test("Sound parameters never sample outside the interval")
	func soundParametersStayInSupport() {
		var rng = DeterministicRNG(seed: 0x5EED_1234_ABCD_0001)
		let distribution = Distribution.triangular(min: 0.15, mode: 0.21, max: 0.30)

		var lowest = Double.infinity
		var highest = -Double.infinity
		var outside = 0
		for _ in 0..<Self.draws {
			let value = distribution.sample(using: &rng)
			lowest = Swift.min(lowest, value)
			highest = Swift.max(highest, value)
			if value < 0.15 || value > 0.30 { outside += 1 }
		}

		let complaint = "\(outside) of \(Self.draws) samples fell outside [0.15, 0.30]; observed [\(lowest), \(highest)]"
		#expect(outside == 0, "\(complaint)")
		// And the draws actually span the interval, so a sampler pinned to one point would
		// not pass this by sitting safely in the middle. The generator is seeded, so this
		// is a fixed fact about a fixed stream rather than a probabilistic hope.
		#expect(lowest < 0.20, "lowest draw was \(lowest); the sampler is not spanning")
		#expect(highest > 0.25, "highest draw was \(highest); the sampler is not spanning")
	}

	@Test("A degenerate triangle is a point mass, not a division by zero")
	func degenerateTriangleIsAPointMass() {
		// This case used to arrive at the right answer by accident: `(mode - min) / (max -
		// min)` was `0 / 0`, and `u < .nan` being false sent it down the branch that
		// subtracts `sqrt(0)`. It is now stated rather than stumbled into.
		var rng = DeterministicRNG(seed: 0x5EED_1234_ABCD_0001)
		let distribution = Distribution.triangular(min: 0.20, mode: 0.20, max: 0.20)
		for _ in 0..<1_000 {
			let value = distribution.sample(using: &rng)
			// `isEqual(to:)` rather than `==`: identical behaviour, but it says this is a
			// deliberate exact comparison. A degenerate triangle has one value in its
			// support and the sampler must return that value, not something near it.
			#expect(value.isEqual(to: 0.20), "degenerate triangle sampled \(value)")
		}
	}

	@Test("A narrow triangle still respects its bounds")
	func narrowTriangleRespectsBounds() {
		var rng = DeterministicRNG(seed: 0x5EED_1234_ABCD_0001)
		let distribution = Distribution.triangular(min: 1.0, mode: 1.0, max: 1.000001)
		for _ in 0..<5_000 {
			let value = distribution.sample(using: &rng)
			#expect(value >= 1.0 && value <= 1.000001, "sampled \(value)")
		}
	}

	@Test("Transposed parameters trap rather than sampling from nowhere",
		  .requiresUnsanitizedRuntime)
	func transposedParametersTrap() async {
		// Before the precondition this returned 20,000 of 20,000 samples outside the
		// interval, every one of them a plausible number.
		let result = await #expect(processExitsWith: .failure,
								   observing: [\.standardErrorContent]) {
			var rng = DeterministicRNG(seed: 0x5EED_1234_ABCD_0001)
			let distribution = Distribution.triangular(min: 0.30, mode: 0.20, max: 0.10)
			_ = distribution.sample(using: &rng)
		}
		#if DEBUG
		let errorBytes = result?.standardErrorContent ?? []
		let message = String(decoding: errorBytes, as: UTF8.self)
		#expect(message.contains("min <= mode <= max"),
				"""
				The trap fired, but not from the triangular precondition — stderr never named \
				the requirement. Standard error was: \(message)
				""")
		#else
		_ = result
		#endif
	}
}
