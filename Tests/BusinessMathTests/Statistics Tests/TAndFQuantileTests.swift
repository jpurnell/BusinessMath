//
//  TAndFQuantileTests.swift
//  BusinessMathTests
//
//  Student's t and F, across the full probability range including both far tails.
//
//  These two were the exception recorded when the distribution contract landed: their
//  quantiles bisected on their own CDFs against an *absolute* tolerance, so at
//  p = 1e-8 they stopped as soon as the CDF was within 9e-13 — about 1e-5 relative on
//  a probability of 1e-8. The conformance grid stopped short of the tail rather than
//  the tolerance being loosened, which left the gap visible. This closes it.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Student's t and F — quantiles across the full range")
struct TAndFQuantileTests {

	/// Both quantiles are now a closed-form map of a root-found beta inverse, so they
	/// inherit its accuracy rather than a bisection's stopping rule.
	static let relativeTolerance = 1e-9

	@Test("tQuantile matches scipy.stats.t.ppf, tails included")
	func tQuantileMatchesReference() throws {
		let fixture = try ReferenceFixture.load("studentT")
		#expect(!fixture.cases.isEmpty)

		for testCase in fixture.cases {
			let df = Int(try testCase.required("df", in: fixture.name))
			let p = try testCase.required("p", in: fixture.name)
			let expected = try testCase.required("quantile", in: fixture.name)

			let actual: Double = try tQuantile(p: p, df: df)
			let scale = Swift.max(abs(expected), 1e-12)
			#expect(abs(actual - expected) / scale < Self.relativeTolerance,
				"t⁻¹(p: \(p), df: \(df)) = \(actual), expected \(expected)")
		}
	}

	@Test("tCDF matches scipy.stats.t.cdf at those same points")
	func tCDFMatchesReference() throws {
		let fixture = try ReferenceFixture.load("studentT")
		for testCase in fixture.cases {
			let df = Int(try testCase.required("df", in: fixture.name))
			let x = try testCase.required("quantile", in: fixture.name)
			let expected = try testCase.required("cdf", in: fixture.name)
			guard x.isFinite else { continue }

			let actual: Double = try tCDF(t: x, df: df)
			#expect(abs(actual - expected) < 1e-12,
				"tCDF(\(x), df: \(df)) = \(actual), expected \(expected)")
		}
	}

	@Test("fQuantile matches scipy.stats.f.ppf, tails included")
	func fQuantileMatchesReference() throws {
		let fixture = try ReferenceFixture.load("fDistribution")
		#expect(!fixture.cases.isEmpty)

		for testCase in fixture.cases {
			let df1 = Int(try testCase.required("df1", in: fixture.name))
			let df2 = Int(try testCase.required("df2", in: fixture.name))
			let p = try testCase.required("p", in: fixture.name)
			let expected = try testCase.required("quantile", in: fixture.name)

			let actual: Double = try fQuantile(p: p, df1: df1, df2: df2)
			let scale = Swift.max(abs(expected), 1e-12)
			#expect(abs(actual - expected) / scale < Self.relativeTolerance,
				"F⁻¹(p: \(p), df1: \(df1), df2: \(df2)) = \(actual), expected \(expected)")
		}
	}

	@Test("fCDF matches scipy.stats.f.cdf at those same points")
	func fCDFMatchesReference() throws {
		let fixture = try ReferenceFixture.load("fDistribution")
		for testCase in fixture.cases {
			let df1 = Int(try testCase.required("df1", in: fixture.name))
			let df2 = Int(try testCase.required("df2", in: fixture.name))
			let x = try testCase.required("quantile", in: fixture.name)
			let expected = try testCase.required("cdf", in: fixture.name)
			guard x.isFinite, x > 0 else { continue }

			let actual: Double = try fCDF(f: x, df1: df1, df2: df2)
			#expect(abs(actual - expected) < 1e-12,
				"fCDF(\(x), df1: \(df1), df2: \(df2)) = \(actual), expected \(expected)")
		}
	}

	// MARK: - Identities, which need no reference at all

	/// Probabilities whose complement is exact.
	///
	/// `1 - 1e-8` is `0.99999999`, and subtracting that from one recovers
	/// `1.0000000050e-08` — a 5e-9 relative error in the tail probability before any
	/// quantile is evaluated. Testing a symmetry identity there measures the
	/// representability of the *argument*, not the function.
	///
	/// A negative power of two has an exact complement, so `p` and `1 - p` really are
	/// complementary and the identity can be asserted to full precision. These reach
	/// further into the tail than the decimal grid does: 2⁻⁴⁰ is about 9e-13.
	static let dyadicProbabilities: [Double] = [
		0x1p-2, 0x1p-4, 0x1p-8, 0x1p-16, 0x1p-24, 0x1p-32, 0x1p-40
	]

	@Test("Student's t is symmetric about zero")
	func tIsSymmetric() throws {
		for df in [1, 3, 8, 30] {
			for p in Self.dyadicProbabilities {
				#expect(1 - (1 - p) == p, "\(p) does not have an exact complement")
				let lower: Double = try tQuantile(p: p, df: df)
				let upper: Double = try tQuantile(p: 1 - p, df: df)
				#expect(abs(lower + upper) < 1e-12 * abs(lower),
					"t⁻¹(\(p)) = \(lower) and t⁻¹(1−\(p)) = \(upper) are not mirror images")
			}
		}
	}

	@Test("t with one degree of freedom is the Cauchy distribution")
	func tWithOneDegreeOfFreedomIsCauchy() throws {
		// Derived, not tabulated: the standard Cauchy quantile is tan(π(p − ½)).
		for p in [1e-6, 0.01, 0.1, 0.3, 0.5, 0.7, 0.9, 0.99] {
			let derived = Double.tan(Double.pi * (p - 0.5))
			let actual: Double = try tQuantile(p: p, df: 1)
			let scale = Swift.max(abs(derived), 1e-12)
			#expect(abs(actual - derived) / scale < 1e-9,
				"t⁻¹(\(p), df: 1) = \(actual), Cauchy says \(derived)")
		}
	}

	@Test("F(d1, d2) at p is the reciprocal of F(d2, d1) at 1 − p")
	func fReciprocalIdentity() throws {
		// A defining property of the F distribution, and it needs no reference: if
		// X ~ F(d1, d2) then 1/X ~ F(d2, d1). It catches a swapped argument pair,
		// which a one-sided fixture comparison would not.
		// Dyadic probabilities, for the reason given on ``dyadicProbabilities``: an
		// identity between p and 1 − p can only be tested where those two really are
		// complementary.
		for (d1, d2) in [(5, 9), (3, 20), (20, 3), (1, 10)] {
			for p in Self.dyadicProbabilities {
				let direct: Double = try fQuantile(p: p, df1: d1, df2: d2)
				let mirrored: Double = try fQuantile(p: 1 - p, df1: d2, df2: d1)
				#expect(abs(direct * mirrored - 1) < 1e-11,
					"F⁻¹(\(p); \(d1),\(d2)) · F⁻¹(1−\(p); \(d2),\(d1)) = \(direct * mirrored)")
			}
		}
	}

	@Test("F with one numerator degree of freedom is a squared t")
	func fWithOneNumeratorDegreeIsTSquared() throws {
		// If T ~ t(ν) then T² ~ F(1, ν). Two independently implemented routes to the
		// same number, so a shared error in the beta inversion would have to be
		// symmetric in a way that is very hard to arrange by accident.
		for df in [2, 5, 12, 30] {
			for p in [0.6, 0.9, 0.99, 0.999, 1 - 1e-6] {
				let fromT: Double = try tQuantile(p: (1 + p) / 2, df: df)
				let fromF: Double = try fQuantile(p: p, df1: 1, df2: df)
				#expect(abs(fromT * fromT - fromF) / fromF < 1e-8,
					"t⁻¹((1+\(p))/2, df: \(df))² = \(fromT * fromT), F⁻¹(\(p); 1,\(df)) = \(fromF)")
			}
		}
	}

	@Test("Both quantiles round-trip through their own CDFs")
	func quantilesRoundTrip() throws {
		for df in [1, 3, 8, 30] {
			for p in [1e-8, 1e-4, 0.01, 0.5, 0.99, 1 - 1e-4, 1 - 1e-8] {
				let x: Double = try tQuantile(p: p, df: df)
				let back: Double = try tCDF(t: x, df: df)
				#expect(abs(back - p) / Swift.max(p, 1e-12) < 1e-8,
					"t round trip at p = \(p), df = \(df) returned \(back)")
			}
		}
		for (d1, d2) in [(5, 9), (3, 20), (20, 3)] {
			for p in [1e-8, 1e-4, 0.01, 0.5, 0.99, 1 - 1e-4] {
				let x: Double = try fQuantile(p: p, df1: d1, df2: d2)
				let back: Double = try fCDF(f: x, df1: d1, df2: d2)
				#expect(abs(back - p) / Swift.max(p, 1e-12) < 1e-8,
					"F round trip at p = \(p), df = (\(d1),\(d2)) returned \(back)")
			}
		}
	}

	@Test("Both still reject invalid input")
	func invalidInputIsRejected() {
		for p in [-0.1, 0.0, 1.0, 1.5] {
			#expect(throws: (any Error).self) { let _: Double = try tQuantile(p: p, df: 5) }
			#expect(throws: (any Error).self) { let _: Double = try fQuantile(p: p, df1: 5, df2: 9) }
		}
		#expect(throws: (any Error).self) { let _: Double = try tQuantile(p: 0.5, df: 0) }
		#expect(throws: (any Error).self) { let _: Double = try fQuantile(p: 0.5, df1: 0, df2: 9) }
		#expect(throws: (any Error).self) { let _: Double = try fQuantile(p: 0.5, df1: 5, df2: 0) }
	}
}
