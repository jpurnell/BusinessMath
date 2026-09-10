//
//  PertShapeTests.swift
//  BusinessMath
//
//  The PERT shape parameters, against the form that has no singularity.
//

import Testing
import TestSupport
@testable import BusinessMath

/// PERT's Beta shapes, asserted against the λ-form.
///
/// Two parameterisations describe the same distribution:
///
/// - **Mean-based:** `α = (μ−a)(2m−a−b) / ((m−μ)(b−a))`, with `μ = (a+λm+b)/(λ+2)`.
///   Both factors of the denominator vanish when the mode is central, so the expression is
///   `0/0` there and merely ill-conditioned near there.
/// - **λ-form:** `α = 1 + λ(m−a)/(b−a)`, `β = 1 + λ(b−m)/(b−a)`.
///   Defined for every `a < m < b`, with no branch and nothing to guard.
///
/// They agree exactly — at `a=0, m=1, b=4, λ=4` both give `(2, 4)`; at `a=0, m=3, b=4` both
/// give `(4, 2)` — so this is not a change of distribution, only of arithmetic. The
/// singularity was never in PERT; it was in the way PERT was being written down.
///
/// The λ-form is the oracle here precisely because it cannot be the thing under suspicion:
/// it has no subtraction of nearly-equal quantities anywhere in it.
@Suite("PERT shapes")
struct PertShapeTests {

	private static let lambda = 4.0

	/// `α = 1 + λ(m−a)/(b−a)` and `β = 1 + λ(b−m)/(b−a)`.
	private static func expectedShapes(min: Double, likely: Double, max: Double) -> (Double, Double) {
		let span: Double = max - min
		let lower: Double = likely - min
		let upper: Double = max - likely
		let alpha: Double = 1.0 + Self.lambda * lower / span
		let beta: Double = 1.0 + Self.lambda * upper / span
		return (alpha, beta)
	}

	@Test("A central mode gives the symmetric Beta exactly")
	func centralModeIsSymmetric() throws {
		let d = try #require(DistributionPert(min: 0, likely: 5, max: 10))
		// 1 + λ/2 = 3 for λ = 4, and both shapes must be it.
		#expect(abs(d.alpha - 3.0) < 1e-14, "alpha \(d.alpha)")
		#expect(abs(d.betaShape - 3.0) < 1e-14, "beta \(d.betaShape)")
	}

	/// The mode positions that matter, chosen from measurement rather than intuition.
	///
	/// With `min = 0` and `max = 10`, `centrality = 2·likely − 10` and the mean-based form's
	/// guard window closes at `centrality ≈ 6e-12`. The first probe of this suite used round
	/// numbers, passed, and proved nothing: the damage is concentrated in a narrow band
	/// immediately outside the guard, and a test that steps over that band reports a method
	/// as exact when it has lost four significant digits.
	///
	/// Measured relative error in `α` for the mean-based form: 0 at `centrality = 6e-12`,
	/// **2.5e-4** at 7e-12, **1.8e-4** at 1e-11, back to ~1e-9 by 1e-6. The three values
	/// below at 5 + 3.5e-12, 5 + 5e-12 and 5 + 5e-13 straddle it.
	/// Written as decimal literals rather than `5.0 - 3.5e-12`, because six arithmetic
	/// expressions inside one array literal, expanded through the `@Test` macro, is the exact
	/// shape that makes the type checker give up — and it did, on the local 6.4 compiler.
	/// The values either side of 5 are 5 ∓ 5e-12, 3.5e-12 and 5e-13.
	private static let modePositions: [Double] = [
		1.0, 2.5, 4.0, 4.9, 4.999, 4.999999,
		4.999999999995, 4.9999999999965, 4.9999999999995,
		5.0,
		5.0000000000005, 5.0000000000035, 5.000000000005,
		5.000001, 5.001, 5.1, 6.0, 7.5, 9.0
	]

	@Test("The shapes match the λ-form across the range, including beside the centre",
		  arguments: PertShapeTests.modePositions)
	func shapesMatchTheLambdaForm(likely: Double) throws {
		let d = try #require(DistributionPert(min: 0, likely: likely, max: 10),
							 "construction failed at likely \(likely)")
		let (alpha, beta) = Self.expectedShapes(min: 0, likely: likely, max: 10)
		// Relative, because the shapes are order 1 to 5 and an absolute bound would be
		// tighter at one end of the range than the other.
		#expect(abs(d.alpha - alpha) < 1e-12 * alpha,
				"likely \(likely): alpha \(d.alpha), λ-form says \(alpha)")
		#expect(abs(d.betaShape - beta) < 1e-12 * beta,
				"likely \(likely): beta \(d.betaShape), λ-form says \(beta)")
	}

	@Test("Textbook shapes, both ways round")
	func textbookShapes() throws {
		// Worked by hand from both parameterisations, which is what establishes that the
		// λ-form is a rewrite rather than a different distribution.
		let skewLow = try #require(DistributionPert(min: 0, likely: 1, max: 4))
		#expect(abs(skewLow.alpha - 2.0) < 1e-13, "alpha \(skewLow.alpha)")
		#expect(abs(skewLow.betaShape - 4.0) < 1e-13, "beta \(skewLow.betaShape)")

		let skewHigh = try #require(DistributionPert(min: 0, likely: 3, max: 4))
		#expect(abs(skewHigh.alpha - 4.0) < 1e-13, "alpha \(skewHigh.alpha)")
		#expect(abs(skewHigh.betaShape - 2.0) < 1e-13, "beta \(skewHigh.betaShape)")
	}

	@Test("The mean is unchanged by the reparameterisation",
		  arguments: [1.0, 4.999999, 5.0, 5.000001, 9.0] as [Double])
	func meanIsUnchanged(likely: Double) throws {
		// The counterweight: the shapes could be made continuous by computing a different
		// distribution. The PERT mean is fixed by its definition, so pinning it says the
		// distribution did not move.
		let d = try #require(DistributionPert(min: 0, likely: likely, max: 10))
		let expected: Double = (0.0 + Self.lambda * likely + 10.0) / (Self.lambda + 2.0)
		#expect(abs(d.mean - expected) < 1e-12,
				"likely \(likely): mean \(d.mean), definition says \(expected)")
	}
}
