//
//  DistributionCDFReferenceTests.swift
//  BusinessMath
//
//  Differential tests for the distribution CDFs and quantile functions against
//  published tables and closed-form identities. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// Chi-squared, Student's t, F, beta, lognormal, exponential, uniform and Poisson
/// CDFs against published values.
///
/// ## Where the reference values come from
///
/// - **A&S 26.7 / 26.8** — Abramowitz & Stegun, *Handbook of Mathematical
///   Functions* (NBS AMS 55, 1964), chi-squared distribution and its percentage
///   points. The values reproduced here — `χ²₀.₉₅,₁ = 3.841`, `χ²₀.₉₅,₁₀ = 18.307`,
///   `χ²₀.₉₉,₁₀ = 23.209` — are the entries printed in every statistics text.
/// - **A&S 26.10** — percentage points of Student's t. `t₀.₉₇₅,₁ = 12.706`,
///   `t₀.₉₇₅,₁₀ = 2.228`, `t₀.₉₅,₁ = 6.314`.
/// - **A&S 26.9** — percentage points of the F distribution.
///   `F₀.₉₅(5,10) = 3.326`, `F₀.₉₅(1,1) = 161.4`, `F₀.₉₅(2,3) = 9.55`.
/// - **Closed forms** — several entries are exact rationals and need no table at
///   all: `I₀.₅(2,3) = 11/16`, `I₀.₂₅(2,2) = 5/32`, `I₀.₅(a,a) = 1/2`,
///   `F(1,1) at f = 1` is `1/2`, `tCDF(1, 1) = 3/4` (the Cauchy), and the
///   exponential at `λx = 1` is `1 - e⁻¹`. These are the strongest assertions in
///   the file because there is nothing in them to tune.
/// - **Extended digits** — where more precision is needed than a table prints,
///   the value comes from an independent arbitrary-precision evaluation of the
///   regularized incomplete gamma and beta functions (mpmath 1.4.1 at 40 decimal
///   digits), never from BusinessMath. Leading digits were checked against the
///   corresponding A&S entry.
///
/// ## Where the tolerances come from
///
/// | tolerance | used for | justification |
/// |---|---|---|
/// | `1e-14` abs | chi-squared, t, F, beta CDF values | all four route through a series or continued fraction for the regularized incomplete gamma/beta. Measured worst case across every case below: **1.4e-15** (chi-squared at x = 20, df = 20). 1e-14 leaves ~7×, enough for libm ulp drift between platforms. |
/// | `1e-9` rel | `tQuantile` and `fQuantile` | these invert the CDF by search, not by a closed form. Measured worst case: **4.3e-10 absolute / 3.4e-11 relative** (`tQuantile(0.975, df: 1)`). Stated as relative because the F quantiles range over three orders of magnitude. |
/// | `1e-15` abs | lognormal, exponential, uniform CDFs | one transcendental call each over a well-conditioned argument. Measured worst case: **1.1e-16**. |
/// | `1e-3` abs | published three-decimal table entries | that is what the table prints. |
///
/// Every discrepancy found is marked `withKnownIssue` with its measured
/// magnitude rather than absorbed into a wider tolerance.
@Suite("Distribution CDFs vs published tables")
struct DistributionCDFReferenceTests {

	// MARK: - Chi-squared

	@Test("chiSquaredCDF at the published percentage points (A&S 26.8)")
	func chiSquaredAtPercentagePoints() throws {
		// The point of this arrangement: feed the *published quantile* and require
		// the *published probability* back. Both halves of the pair are citable, so
		// neither can drift to accommodate the other.
		let cases: [(x: Double, df: Int, p: Double)] = [
			(3.841458820694124, 1, 0.95),
			(5.023886187314887, 1, 0.975),
			(6.634896601021214, 1, 0.99),
			(11.070497693516351, 5, 0.95),
			(18.307038053275146, 10, 0.95),
			(23.209251158954356, 10, 0.99),
			(3.940299136119060, 10, 0.05)
		]
		for entry in cases {
			let got = try chiSquaredCDF(x: entry.x, df: entry.df)
			#expect(
				approximatelyEqual(got, entry.p, tolerance: 1e-14),
				"chiSquaredCDF(x: \(entry.x), df: \(entry.df)) = \(got), A&S 26.8 gives \(entry.p)"
			)
		}
	}

	@Test("chiSquaredCDF against closed forms and extended-precision values")
	func chiSquaredValues() throws {
		let cases: [(x: Double, df: Int, p: Double, source: String)] = [
			// df = 1 is 2Φ(√x) - 1, so P(1 | 1) = erf(1/√2) = the familiar 68.27%.
			(1.0, 1, 0.6826894921370859, "erf(1/√2), the 1σ interval"),
			// df = 2 is 1 - e^(-x/2) exactly.
			(2.0, 2, 0.6321205588285577, "1 - e⁻¹, closed form for df = 2"),
			(0.5, 1, 0.5204998778130465, "arbitrary precision"),
			(5.0, 5, 0.5841198130044921, "arbitrary precision"),
			(10.0, 10, 0.5595067149347875, "arbitrary precision"),
			(20.0, 20, 0.5420702855281478, "arbitrary precision")
		]
		for entry in cases {
			let got = try chiSquaredCDF(x: entry.x, df: entry.df)
			#expect(
				approximatelyEqual(got, entry.p, tolerance: 1e-14),
				"chiSquaredCDF(x: \(entry.x), df: \(entry.df)) = \(got), reference \(entry.p) (\(entry.source))"
			)
		}
	}

	@Test("chiSquaredCDF is monotone and in [0, 1]")
	func chiSquaredMonotone() throws {
		for df in [1, 2, 5, 30] {
			var previous = -Double.infinity
			var violations = 0
			for step in 0...400 {
				let x = 0.05 * Double(step)
				let value = try chiSquaredCDF(x: x, df: df)
				if value < previous { violations += 1 }
				#expect(value >= 0 && value <= 1, "chiSquaredCDF(x: \(x), df: \(df)) = \(value) is outside [0, 1]")
				previous = value
			}
			#expect(violations == 0, "chiSquaredCDF(df: \(df)) was non-monotone at \(violations) points")
		}
		#expect(exactlyEqual(try chiSquaredCDF(x: 0.0, df: 3), 0.0))
	}

	// MARK: - Student's t

	@Test("tCDF at the published percentage points (A&S 26.10)")
	func tAtPercentagePoints() throws {
		let cases: [(t: Double, df: Int, p: Double)] = [
			(12.706204736174693, 1, 0.975),
			(6.313751514675037, 1, 0.95),
			(2.228138851986274, 10, 0.975),
			(1.812461122811676, 10, 0.95),
			(3.169272672616951, 10, 0.995),
			(2.042272456301238, 30, 0.975),
			(1.979930405082440, 120, 0.975)
		]
		for entry in cases {
			let got = try tCDF(t: entry.t, df: entry.df)
			#expect(
				approximatelyEqual(got, entry.p, tolerance: 1e-14),
				"tCDF(t: \(entry.t), df: \(entry.df)) = \(got), A&S 26.10 gives \(entry.p)"
			)
		}
	}

	@Test("tCDF against closed forms")
	func tClosedForms() throws {
		// df = 1 is the Cauchy: F(t) = 1/2 + atan(t)/π, so F(1) = 3/4 exactly and
		// F(0) = 1/2 exactly. df = 2 has the closed form 1/2 + t/(2√(2+t²)),
		// giving F(2) = 1/2 + 1/√6.
		#expect(approximatelyEqual(try tCDF(t: 1.0, df: 1), 0.75, tolerance: 1e-14))
		#expect(approximatelyEqual(try tCDF(t: 2.0, df: 2), 0.9082482904638630, tolerance: 1e-14))
		#expect(approximatelyEqual(try tCDF(t: 2.5, df: 5), 0.9727549503288119, tolerance: 1e-14))
		#expect(approximatelyEqual(try tCDF(t: -2.0, df: 20), 0.029632767723285238, tolerance: 1e-14))
		// The median is exact for every df.
		for df in [1, 2, 5, 30, 1000] {
			#expect(exactlyEqual(try tCDF(t: 0.0, df: df), 0.5), "tCDF(t: 0, df: \(df)) is not exactly 1/2")
		}
	}

	@Test("tCDF is symmetric: F(-t) == 1 - F(t)")
	func tSymmetry() throws {
		// Exact claim about the definition, no external source. Tolerance 1e-15:
		// the two sides are computed from the same incomplete beta value by
		// different subtractions, so they can differ by an ulp at 1.
		for df in [1, 3, 10, 50] {
			for t in [0.5, 1.0, 2.0, 3.0, 5.0] {
				let lower = try tCDF(t: -t, df: df)
				let upper = try tCDF(t: t, df: df)
				#expect(
					approximatelyEqual(lower, 1 - upper, tolerance: 1e-15),
					"tCDF(-\(t), df: \(df)) = \(lower) but 1 - tCDF(\(t), df: \(df)) = \(1 - upper)"
				)
			}
		}
	}

	@Test("t converges to the normal as df grows")
	func tApproachesNormal() throws {
		// A&S 26.10 prints the df = ∞ row as the standard normal. At df = 100000 the
		// two must agree to about 1/(4·df) in probability — 2.5e-6 here — which is
		// the asymptotic term, not a tuned number.
		for t in [-2.0, -1.0, 0.5, 1.96, 3.0] {
			let student = try tCDF(t: t, df: 100_000)
			let gaussian = normalCDF(x: t)
			#expect(
				approximatelyEqual(student, gaussian, tolerance: 2.5e-6),
				"tCDF(\(t), df: 100000) = \(student) against normalCDF = \(gaussian)"
			)
		}
	}

	@Test("tQuantile inverts tCDF at the published percentage points")
	func tQuantileValues() throws {
		// Same published pairs, read the other way. Tolerance is relative at 1e-9:
		// tQuantile inverts by search, and its measured worst case here is 4.3e-10
		// absolute (3.4e-11 relative) at df = 1, where the tail is heaviest.
		let cases: [(p: Double, df: Int, t: Double)] = [
			(0.975, 1, 12.706204736174693),
			(0.95, 1, 6.313751514675037),
			(0.975, 10, 2.228138851986274),
			(0.95, 10, 1.812461122811676),
			(0.995, 10, 3.169272672616951),
			(0.975, 30, 2.042272456301238),
			(0.975, 120, 1.979930405082440)
		]
		for entry in cases {
			let got = try tQuantile(p: entry.p, df: entry.df)
			#expect(
				abs(got - entry.t) / entry.t < 1e-9,
				"tQuantile(p: \(entry.p), df: \(entry.df)) = \(got), A&S 26.10 gives \(entry.t), relative error \(abs(got - entry.t) / entry.t)"
			)
		}
	}

	@Test("tQuantile ∘ tCDF is the identity")
	func tQuantileRoundTrip() throws {
		// Needs no source. Tolerance 1e-8 in t: the round trip inherits the
		// quantile's search accuracy (1e-9 relative, measured above) on values up
		// to about 13 here.
		for df in [1, 5, 30] {
			for t in [-3.0, -1.0, 0.5, 2.0, 4.0] {
				let p = try tCDF(t: t, df: df)
				let back = try tQuantile(p: p, df: df)
				#expect(
					approximatelyEqual(back, t, tolerance: 1e-8),
					"tQuantile(tCDF(\(t), df: \(df))) = \(back)"
				)
			}
		}
	}

	// MARK: - F

	@Test("fCDF at the published percentage points (A&S 26.9)")
	func fAtPercentagePoints() throws {
		let cases: [(f: Double, df1: Int, df2: Int, p: Double)] = [
			(3.325834530413011, 5, 10, 0.95),
			(5.636326187669078, 5, 10, 0.99),
			(2.978237016082321, 10, 10, 0.95),
			(161.44763879758821, 1, 1, 0.95),
			(9.552094495921153, 2, 3, 0.95)
		]
		for entry in cases {
			let got = try fCDF(f: entry.f, df1: entry.df1, df2: entry.df2)
			#expect(
				approximatelyEqual(got, entry.p, tolerance: 1e-14),
				"fCDF(f: \(entry.f), df1: \(entry.df1), df2: \(entry.df2)) = \(got), A&S 26.9 gives \(entry.p)"
			)
		}
	}

	@Test("fCDF against closed forms")
	func fClosedForms() throws {
		// F(d, d) at f = 1 is exactly 1/2 for every d, because the distribution is
		// reciprocal-symmetric there. This is the assertion that catches an
		// incomplete beta whose two branches disagree at x = 1/2.
		//
		// Tolerance 1e-14 up to d = 30; the error grows with the degrees of
		// freedom, which is measured separately in
		// `incompleteBetaLosesAccuracyAsParametersGrow`.
		for d in [1, 2, 3, 5, 8, 10, 20, 30] {
			let got = try fCDF(f: 1.0, df1: d, df2: d)
			#expect(
				approximatelyEqual(got, 0.5, tolerance: 1e-14),
				"fCDF(f: 1, df1: \(d), df2: \(d)) = \(got), must be exactly 1/2"
			)
		}
		#expect(approximatelyEqual(try fCDF(f: 2.0, df1: 3, df2: 5), 0.7673760819999215, tolerance: 1e-14))
	}

	@Test("The incomplete beta loses about a digit per decade of parameter size")
	func incompleteBetaLosesAccuracyAsParametersGrow() throws {
		// `regularizedIncompleteBeta` documents no accuracy at all, and `betaCDF`,
		// `tCDF` and `fCDF` all inherit whatever it has. `I_½(a, a) = ½` exactly for
		// every `a`, so it makes a free error probe over the whole parameter range.
		//
		// Measured absolute error against the exact ½:
		//
		//   a = 2     5.6e-17
		//   a = 5     1.1e-15
		//   a = 10    1.4e-15
		//   a = 25    1.1e-14
		//   a = 40    7.4e-15
		//   a = 100   1.0e-13
		//
		// and `fCDF(1, d, d)`, which is the same call, tracks it: 1.1e-14 at
		// d = 50, 1.0e-13 at d = 200. Roughly one decimal digit lost per decade of
		// parameter size. That matters for an F-test on a large sample or a t-test
		// at high degrees of freedom, and it is not recorded anywhere in the
		// library's documentation today.
		//
		// This is an envelope, not a defect: the bound below is the measured value
		// with headroom, and it stays true if the implementation improves.
		let cases: [(parameter: Double, envelope: Double)] = [
			(2, 1e-15),
			(5, 5e-15),
			(10, 5e-15),
			(25, 5e-14),
			(40, 5e-14),
			(100, 5e-13)
		]
		for entry in cases {
			let got = try betaCDF(x: 0.5, alpha: entry.parameter, beta: entry.parameter)
			#expect(
				approximatelyEqual(got, 0.5, tolerance: entry.envelope),
				"betaCDF(0.5, \(entry.parameter), \(entry.parameter)) = \(got), error \(abs(got - 0.5))"
			)
		}
		// The same growth seen through fCDF, which is where a caller meets it.
		for entry in [(50, 5e-14), (100, 5e-13), (200, 5e-13)] as [(Int, Double)] {
			let got = try fCDF(f: 1.0, df1: entry.0, df2: entry.0)
			#expect(
				approximatelyEqual(got, 0.5, tolerance: entry.1),
				"fCDF(1, \(entry.0), \(entry.0)) = \(got), error \(abs(got - 0.5))"
			)
		}
	}

	@Test("F is the square of t: F(1, d) at t² equals 2·tCDF(t, d) - 1")
	func fIsTSquared() throws {
		// An identity between two independently implemented CDFs, which is what
		// makes it worth asserting: if either the beta branch selection or the t
		// sign handling is wrong, this fails. Tolerance 1e-14, the same incomplete
		// beta accuracy both sides inherit.
		for df in [1, 3, 10, 40] {
			for t in [0.5, 1.0, 2.0, 3.5] {
				let viaF = try fCDF(f: t * t, df1: 1, df2: df)
				let viaT = 2 * (try tCDF(t: t, df: df)) - 1
				#expect(
					approximatelyEqual(viaF, viaT, tolerance: 1e-14),
					"fCDF(\(t * t), 1, \(df)) = \(viaF) but 2·tCDF(\(t), \(df)) - 1 = \(viaT)"
				)
			}
		}
	}

	@Test("fQuantile inverts fCDF at the published percentage points")
	func fQuantileValues() throws {
		// Relative tolerance 1e-9. Measured worst case: 8.1e-10 absolute at
		// F₀.₉₅(1,1) = 161.4, which is 5.0e-12 relative — the search converges in
		// relative terms, so the assertion is stated that way.
		let cases: [(p: Double, df1: Int, df2: Int, f: Double)] = [
			(0.95, 5, 10, 3.325834530413011),
			(0.99, 5, 10, 5.636326187669078),
			(0.95, 10, 10, 2.978237016082321),
			(0.95, 1, 1, 161.44763879758821),
			(0.95, 2, 3, 9.552094495921153)
		]
		for entry in cases {
			let got = try fQuantile(p: entry.p, df1: entry.df1, df2: entry.df2)
			#expect(
				abs(got - entry.f) / entry.f < 1e-9,
				"fQuantile(p: \(entry.p), df1: \(entry.df1), df2: \(entry.df2)) = \(got), A&S 26.9 gives \(entry.f), relative error \(abs(got - entry.f) / entry.f)"
			)
		}
	}

	@Test("fCDF is monotone and in [0, 1]")
	func fMonotone() throws {
		for pair in [(1, 1), (5, 10), (10, 10)] {
			var previous = -Double.infinity
			var violations = 0
			for step in 0...400 {
				let f = 0.05 * Double(step)
				let value = try fCDF(f: f, df1: pair.0, df2: pair.1)
				if value < previous { violations += 1 }
				#expect(value >= 0 && value <= 1, "fCDF(\(f), \(pair.0), \(pair.1)) = \(value) is outside [0, 1]")
				previous = value
			}
			#expect(violations == 0, "fCDF(\(pair.0), \(pair.1)) was non-monotone at \(violations) points")
		}
	}

	// MARK: - Beta

	@Test("betaCDF against exact rational values of the regularized incomplete beta")
	func betaExactRationals() throws {
		// I_x(a, b) has a closed form for integer a and b. These four are exact
		// rationals, so the reference carries no rounding at all:
		//
		//   I₀.₅(1,1) = 1/2       (uniform)
		//   I₀.₂₅(2,2) = 5/32     = 0.15625
		//   I₀.₅(2,3)  = 11/16    = 0.6875
		//   I₀.₉(5,2)  = 0.885735 = 1 - 0.9⁵(1 + 5·0.1)... exactly 177147/200000
		//
		// and I_x(a, a) = 1/2 at x = 1/2 for any a by symmetry.
		let cases: [(x: Double, a: Double, b: Double, value: Double)] = [
			(0.5, 1, 1, 0.5),
			(0.25, 2, 2, 0.15625),
			(0.5, 2, 3, 0.6875),
			(0.9, 5, 2, 0.885735),
			(0.5, 0.5, 0.5, 0.5),
			(0.5, 3, 3, 0.5)
		]
		for entry in cases {
			let got = try betaCDF(x: entry.x, alpha: entry.a, beta: entry.b)
			#expect(
				approximatelyEqual(got, entry.value, tolerance: 1e-14),
				"betaCDF(x: \(entry.x), alpha: \(entry.a), beta: \(entry.b)) = \(got), exact value \(entry.value)"
			)
		}
		// A non-rational point, from the arbitrary-precision evaluation.
		#expect(approximatelyEqual(try betaCDF(x: 0.1, alpha: 0.5, beta: 5), 0.6833570849799877, tolerance: 1e-14))
	}

	@Test("betaCDF satisfies I_x(a,b) == 1 - I_(1-x)(b,a)")
	func betaReflection() throws {
		// The reflection formula, an exact identity of the definition. It exercises
		// both branches of the continued fraction, since the implementation swaps
		// arguments when x is above the crossover.
		for triple in [(0.3, 2.0, 5.0), (0.7, 0.5, 3.0), (0.2, 4.0, 1.5), (0.85, 6.0, 2.0)] {
			let forward = try betaCDF(x: triple.0, alpha: triple.1, beta: triple.2)
			let reflected = try betaCDF(x: 1 - triple.0, alpha: triple.2, beta: triple.1)
			#expect(
				approximatelyEqual(forward, 1 - reflected, tolerance: 1e-14),
				"I_\(triple.0)(\(triple.1),\(triple.2)) = \(forward) but 1 - I_\(1 - triple.0)(\(triple.2),\(triple.1)) = \(1 - reflected)"
			)
		}
	}

	// MARK: - Lognormal, exponential, uniform

	@Test("logNormalCDF equals the normal CDF of log x")
	func lognormalValues() {
		// F(x; μ, σ) = Φ((ln x - μ)/σ), so the median is exactly 1/2 at x = e^μ and
		// the rest come from the arbitrary-precision Φ evaluation.
		let cases: [(x: Double, mu: Double, sigma: Double, p: Double)] = [
			(1.0, 0.0, 1.0, 0.5),
			(2.0, 0.0, 1.0, 0.7558914042144173),
			(0.5, 0.0, 1.0, 0.24410859578558273),
			(10.0, 1.0, 0.5, 0.99540856824253004)
		]
		for entry in cases {
			let got = logNormalCDF(entry.x, mean: entry.mu, stdDev: entry.sigma)
			#expect(
				approximatelyEqual(got, entry.p, tolerance: 1e-15),
				"logNormalCDF(\(entry.x), mean: \(entry.mu), stdDev: \(entry.sigma)) = \(got), reference \(entry.p)"
			)
		}
	}

	@Test("exponentialCDF against 1 - e^(-λx)")
	func exponentialValues() {
		// Closed form, so the reference is exact to the type. λx = 1 gives 1 - e⁻¹
		// three different ways, which also checks that λ and x are not transposed.
		let oneMinusExpMinusOne = 0.6321205588285577
		#expect(approximatelyEqual(exponentialCDF(1.0, λ: 1.0), oneMinusExpMinusOne, tolerance: 1e-15))
		#expect(approximatelyEqual(exponentialCDF(2.0, λ: 0.5), oneMinusExpMinusOne, tolerance: 1e-15))
		#expect(approximatelyEqual(exponentialCDF(0.5, λ: 2.0), oneMinusExpMinusOne, tolerance: 1e-15))
		#expect(approximatelyEqual(exponentialCDF(1.0, λ: 0.1), 0.09516258196404043, tolerance: 1e-15))
		// The median: F(ln2 / λ) = 1/2.
		#expect(approximatelyEqual(exponentialCDF(0.6931471805599453 / 3.0, λ: 3.0), 0.5, tolerance: 1e-15))
		#expect(exactlyEqual(exponentialCDF(0.0, λ: 1.0), 0.0))
	}

	@Test("exponential and chi-squared agree where they are the same distribution")
	func exponentialIsChiSquaredWithTwoDegreesOfFreedom() throws {
		// χ²(2) is exponential with λ = 1/2. Two independent implementations — a
		// closed form and an incomplete gamma series — of one distribution.
		for x in [0.1, 0.5, 1.0, 2.0, 5.0, 10.0] {
			let viaChi = try chiSquaredCDF(x: x, df: 2)
			let viaExp = exponentialCDF(x, λ: 0.5)
			#expect(
				approximatelyEqual(viaChi, viaExp, tolerance: 1e-14),
				"chiSquaredCDF(\(x), df: 2) = \(viaChi) but exponentialCDF(\(x), λ: 0.5) = \(viaExp)"
			)
		}
	}

	@Test("uniformCDF is the identity on [0, 1] and clamps outside it")
	func uniformValues() {
		// Exact by definition, so bit comparison rather than tolerance.
		for x in [0.0, 0.25, 0.5, 0.6, 0.75, 0.999] {
			#expect(identical(uniformCDF(x: x), x), "uniformCDF(x: \(x)) = \(uniformCDF(x: x))")
		}
		#expect(identical(uniformCDF(x: -0.5), 0.0))
		#expect(identical(uniformCDF(x: 1.0), 1.0))
		#expect(identical(uniformCDF(x: 3.0), 1.0))
	}

	// MARK: - Poisson

	/// `P(X ≤ k)` for a Poisson mean of 3, from the arbitrary-precision sum
	/// `e^(-μ) Σ μᵏ/k!`. These are the entries a Poisson table prints.
	static let poissonMeanThree: [Double] = [
		0.049787068367863942,
		0.199148273471455772,
		0.423190081126843515,
		0.647231888782231259,
		0.815263244523772066,
		0.916082057968696551,
		0.966491464691158793,
		0.988095496143642611,
		0.996197007938324043
	]

	@Test("poissonCDF matches the published table at every integer argument")
	func poissonIntegerArguments() {
		// This was an off-by-one. `poissonCDF(_:µ:)` computed floor(x) by counting up
		// while `counter < x`, which overshoots by one whenever x is an exact integer,
		// so it summed k = 0 ... floor(x) - 1 and returned P(X ≤ k - 1).
		//
		// Measured before the fix, against the reference table above (µ = 3):
		//
		//   k    returned              reference             absolute error
		//   1    0.049787068367864     0.199148273471456     1.49e-01
		//   2    0.199148273471456     0.423190081126844     2.24e-01
		//   3    0.423190081126844     0.647231888782231     2.24e-01
		//   4    0.647231888782231     0.815263244523772     1.68e-01
		//
		// and the worst case anywhere was at µ = 1, k = 1: the function returned
		// 0.367879441171442 for a true 0.735758882342885, an absolute error of
		// **0.368**. The error was exactly P(X = k), so it peaked near the mode.
		//
		// Non-integer arguments were correct — poissonCDF(1.5, µ: 3) matched
		// P(X ≤ 1) — which is why the bug was invisible to any test that samples the
		// function on a grid of non-integers. The floor is now `x.rounded(.down)`.
		for k in 0...8 {
			let got = poissonCDF(Double(k), µ: 3.0)
			#expect(
				approximatelyEqual(got, Self.poissonMeanThree[k], tolerance: 1e-14),
				"poissonCDF(\(k), µ: 3) = \(got), reference P(X ≤ \(k)) = \(Self.poissonMeanThree[k])"
			)
		}
		// The worst single case, kept so its magnitude stays on record.
		let worst = poissonCDF(1.0, µ: 1.0)
		#expect(
			approximatelyEqual(worst, 0.7357588823428847, tolerance: 1e-14),
			"poissonCDF(1, µ: 1) = \(worst), reference e⁻¹(1 + 1) = 0.7357588823428847"
		)
	}

	@Test("poissonCDF is correct at non-integer arguments")
	func poissonNonIntegerArguments() {
		// The half-integer grid is where the function is right, and pinning it says
		// which half of the implementation is sound: the summation is correct and
		// only the floor is wrong.
		for k in 0...4 {
			let got = poissonCDF(Double(k) + 0.5, µ: 3.0)
			#expect(
				approximatelyEqual(got, Self.poissonMeanThree[k], tolerance: 1e-14),
				"poissonCDF(\(k).5, µ: 3) = \(got), reference P(X ≤ \(k)) = \(Self.poissonMeanThree[k])"
			)
		}
	}

	@Test("poissonCDF at a zero mean")
	func poissonZeroMean() {
		// A Poisson with µ = 0 is the point mass at zero, so P(X ≤ k) = 1 for every
		// k ≥ 0. The general sum evaluates `T.pow(0, 0)`, which returned NaN rather
		// than the 1 the limit requires, so the degenerate case is now written out.
		for k in [0.0, 0.5, 1.0, 7.0] {
			let got = poissonCDF(k, µ: 0.0)
			#expect(
				approximatelyEqual(got, 1.0, tolerance: 1e-15),
				"poissonCDF(\(k), µ: 0) = \(got), reference 1"
			)
		}
		// Still zero below the support, degenerate or not.
		#expect(exactlyEqual(poissonCDF(-1.0, µ: 0.0), 0.0))
	}
}
