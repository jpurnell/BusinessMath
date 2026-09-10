//
//  MyersonNearSymmetryTests.swift
//  BusinessMath
//
//  The Myerson quantile on both sides of its symmetric branch.
//

import Testing
import TestSupport
@testable import BusinessMath

/// Myerson where the two arms are nearly, but not exactly, equal.
///
/// The quantile is `mode + (high − mode)·(bʳ − 1)/(b − 1)` with `b` the ratio of the arms.
/// As `b → 1` both the numerator and the denominator go to zero, and the limit is a normal
/// with scale `(high − low)/2z`. The implementation switched to that limit whenever `b` was
/// within `1e-9` of 1.
///
/// The switch is not the problem; the formula on the far side of it is. Written literally,
/// `pow(b, r) − 1` cancels catastrophically for `b` near 1 — the subtraction discards the
/// information the answer is made of — so the general branch was *least* accurate exactly
/// where it was asked to take over from the limit.
///
/// `expm1(r · log1p(b − 1))` computes the same quantity without ever forming `bʳ` or
/// subtracting 1 from something close to 1. It is exact to rounding at any `b`, so the
/// branch narrows from a `1e-9` window to `b == 1` itself — and the discontinuity the window
/// was hiding stops existing rather than moving.
@Suite("Myerson near symmetry")
struct MyersonNearSymmetryTests {

	private static let mode = 100.0
	private static let arm = 50.0

	/// A Myerson whose upper arm exceeds its lower by a relative `delta`.
	private static func nearSymmetric(delta: Double) -> DistributionMyerson? {
		let upper: Double = arm * (1.0 + delta)
		return DistributionMyerson(low: mode - arm, mode: mode, high: mode + upper)
	}

	/// The limit the family converges to: a normal of scale `(high − low)/2z`.
	private static func symmetricLimit(_ p: Double) -> Double {
		let z: Double = inverseNormalCDF(p: 0.95, mean: 0, stdDev: 1)
		let scale: Double = (2.0 * arm) / (2.0 * z)
		let standard: Double = inverseNormalCDF(p: p, mean: 0, stdDev: 1)
		return mode + scale * standard
	}

	/// Measured, not guessed. For a relative arm difference `delta` the quantile moves by
	/// almost exactly `arm · delta` -- confirmed at 1e-12, 1e-10, 1e-8, 1e-7, 1e-6 and 1e-4,
	/// where the observed gap is within a factor of two of that everywhere. The bound is five
	/// times it, which is loose enough for the linear regime and tight enough to catch the
	/// cancellation, which overshoots by a factor of about a hundred.
	private static func bound(delta: Double) -> Double {
		5.0 * abs(delta) * arm
	}

	@Test("Just outside the old switch, the quantile is still the limit to within the nudge",
		  arguments: [1e-12, 1e-10, 1e-9, 2e-9, 1e-8, 1e-7, 1e-6])
	func nearSymmetricMatchesTheLimit(delta: Double) throws {
		// A relative arm difference of `delta` can move the quantile by a term of order
		// `delta`, and no more. The old general branch was off by up to 3.9e-6 here --
		// hundreds of times the perturbation it was reporting.
		let d = try #require(Self.nearSymmetric(delta: delta), "construction failed at delta \(delta)")
		for p in [0.05, 0.25, 0.5, 0.75, 0.95] {
			let actual: Double = d.quantile(p)
			let limit: Double = Self.symmetricLimit(p)
			let gap: Double = abs(actual - limit)
			// The cancelling form peaked at 4.89e-6 here against an expected 5e-8 -- about
			// a hundred times the perturbation it was reporting, and worst precisely at the
			// boundary where the limit branch handed over.
			let bound: Double = Self.bound(delta: delta)
			#expect(gap < bound,
					"delta \(delta) at p \(p): quantile \(actual) is \(gap) from the limit \(limit), bound \(bound)")
		}
	}

	@Test("The quantile is continuous across the symmetric branch")
	func continuousAcrossTheBranch() throws {
		// Probed on both sides, which is what makes this a continuity test rather than a
		// one-sided sanity check: an implementation that switched to the limit only from
		// above would pass a test that never looked below.
		let exact = try #require(Self.nearSymmetric(delta: 0.0), "construction failed at delta 0")
		for p in [0.05, 0.5, 0.95] {
			let centre: Double = exact.quantile(p)
			for delta in [1e-12, 1e-11, 1e-10, 1e-9, 1e-8] {
				let above = try #require(Self.nearSymmetric(delta: delta))
				let below = try #require(Self.nearSymmetric(delta: -delta))
				let gapAbove: Double = abs(above.quantile(p) - centre)
				let gapBelow: Double = abs(below.quantile(p) - centre)
				// Bounded by a multiple of the nudge, not by a fixed tolerance: a fixed 1e-3
				// bound passes a jump 10^5 times the perturbation, which is how a
				// discontinuity this size sat under a continuity test.
				let bound: Double = Self.bound(delta: delta)
				#expect(gapAbove < bound,
						"p \(p), +\(delta): moved \(gapAbove), bound \(bound)")
				#expect(gapBelow < bound,
						"p \(p), -\(delta): moved \(gapBelow), bound \(bound)")
			}
		}
	}

	@Test("A frankly asymmetric case is unchanged")
	func asymmetricStillWorks() throws {
		// The counterweight: making the near-symmetric case exact must not have collapsed
		// the general formula into the limit everywhere.
		let d = try #require(DistributionMyerson(low: 0, mode: 10, high: 100))
		let median: Double = d.quantile(0.5)
		#expect(abs(median - 10.0) < 1e-9, "the median of a Myerson is its mode, got \(median)")
		let upper: Double = d.quantile(0.95)
		#expect(abs(upper - 100.0) < 1e-6, "the 95th percentile is the high point, got \(upper)")
		let lower: Double = d.quantile(0.05)
		#expect(abs(lower - 0.0) < 1e-6, "the 5th percentile is the low point, got \(lower)")
	}
}
