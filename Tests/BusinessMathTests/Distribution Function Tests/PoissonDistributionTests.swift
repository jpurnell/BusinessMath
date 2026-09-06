//
//  PoissonDistributionTests.swift
//  BusinessMath
//
//  The Poisson mathematics had no tests. It also trapped the process for any count
//  above 20, because `poisson(_:µ:)` divided by `x.factorial()` — an `Int` factorial,
//  and 21! exceeds `Int64.max`. λ = 25 is an ordinary arrival rate, so this was
//  reachable from ordinary input, and a trap is worse than a wrong number: there is no
//  value to inspect and no error to catch.
//
//  These tests pin the mathematics against a closed-form reference computed in log
//  space, over a range that includes the counts the old implementation could not reach.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Poisson distribution")
struct PoissonDistributionTests {

	/// P(X = k) = exp(k·ln λ − λ − ln Γ(k+1)), evaluated in log space.
	///
	/// Independent of the implementation under test: no factorial, no `pow`, so it
	/// neither overflows nor traps anywhere in the range exercised here.
	private static func referencePMF(_ k: Int, lambda: Double) -> Double {
		guard k >= 0 else { return 0 }
		if lambda == 0 { return k == 0 ? 1 : 0 }
		let logP = Double(k) * Foundation.log(lambda) - lambda - lgamma(Double(k) + 1)
		return Foundation.exp(logP)
	}

	private static func referenceCDF(_ k: Int, lambda: Double) -> Double {
		guard k >= 0 else { return 0 }
		var total = 0.0
		for i in 0...k { total += referencePMF(i, lambda: lambda) }
		return min(1.0, total)
	}

	// MARK: - The mathematics

	@Test("PMF matches the log-space reference, including counts above 20")
	func pmfMatchesReference() {
		// 20 is the old ceiling: 20! fits in Int64, 21! does not.
		let cases: [(Int, Double)] = [
			(0, 0.5), (1, 0.5), (3, 3.0), (5, 3.0), (10, 3.0),
			(20, 20.0), (21, 20.0), (25, 25.0), (30, 30.0),
			(40, 40.0), (60, 50.0), (100, 90.0), (150, 140.0)
		]
		for (k, lambda) in cases {
			let actual: Double = poisson(k, µ: lambda)
			let expected = Self.referencePMF(k, lambda: lambda)
			#expect(abs(actual - expected) <= 1e-12 * Swift.max(1e-300, expected),
					"pmf(k: \(k), λ: \(lambda)) = \(actual), expected \(expected)")
		}
	}

	@Test("PMF sums to one across the support")
	func pmfSumsToOne() {
		for lambda in [0.5, 3.0, 25.0, 60.0] {
			// Ten standard deviations past the mean leaves nothing material in the tail.
			let upper = Int(lambda + 10.0 * lambda.squareRoot()) + 20
			var total = 0.0
			for k in 0...upper { total += poisson(k, µ: lambda) as Double }
			#expect(abs(total - 1.0) < 1e-10, "λ = \(lambda) summed to \(total)")
		}
	}

	@Test("PMF is zero below the support and never negative")
	func pmfOutsideSupport() {
		for k in [-5, -1] {
			let p: Double = poisson(k, µ: 3.0)
			#expect(p == 0, "pmf(\(k)) should be zero, got \(p)")
		}
		for k in 0...50 {
			let p: Double = poisson(k, µ: 7.0)
			#expect(p >= 0 && p.isFinite, "pmf(\(k)) = \(p)")
		}
	}

	@Test("CDF matches the reference, including counts above 20")
	func cdfMatchesReference() {
		for lambda in [0.5, 3.0, 25.0, 40.0] {
			for k in [0, 1, 5, 20, 21, 30, 60] {
				let actual: Double = poissonCDF(Double(k), µ: lambda)
				let expected = Self.referenceCDF(k, lambda: lambda)
				#expect(abs(actual - expected) < 1e-10,
						"cdf(\(k), λ: \(lambda)) = \(actual), expected \(expected)")
			}
		}
	}

	@Test("CDF is non-decreasing and bounded by zero and one")
	func cdfMonotone() {
		for lambda in [0.5, 3.0, 25.0] {
			var previous = -1.0
			for k in 0...80 {
				let c: Double = poissonCDF(Double(k), µ: lambda)
				#expect(c >= previous, "cdf decreased at k = \(k) for λ = \(lambda)")
				#expect(c >= 0 && c <= 1 + 1e-12, "cdf(\(k)) = \(c) out of range")
				previous = c
			}
			#expect(previous > 1.0 - 1e-9, "cdf should approach 1; reached \(previous)")
		}
	}

	@Test("Degenerate and invalid rates")
	func edgeRates() {
		// λ = 0 puts all mass at zero. These are exact by construction — each comes
		// from a guard returning a literal, not from arithmetic — so the comparison is
		// a deliberate IEEE one and is named as such rather than given a tolerance it
		// does not need.
		#expect((poisson(0, µ: 0.0) as Double).isEqual(to: 1.0))
		#expect((poisson(1, µ: 0.0) as Double).isEqual(to: 0.0))
		#expect((poissonCDF(0.0, µ: 0.0) as Double).isEqual(to: 1.0))
		// A negative rate is not a Poisson.
		#expect((poissonCDF(1.0, µ: -1.0) as Double).isNaN)
	}

	@Test("CDF floors a non-integer argument")
	func cdfFloorsArgument() {
		// P(X ≤ 3.7) is P(X ≤ 3): the distribution has no mass between integers.
		let atThree: Double = poissonCDF(3.0, µ: 4.0)
		let atThreeSeven: Double = poissonCDF(3.7, µ: 4.0)
		#expect(abs(atThree - atThreeSeven) < 1e-15,
				"\(atThreeSeven) should equal \(atThree)")
	}
}
