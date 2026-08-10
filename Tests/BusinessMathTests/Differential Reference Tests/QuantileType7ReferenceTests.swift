//
//  QuantileType7ReferenceTests.swift
//  BusinessMath
//
//  Differential tests for the empirical quantile against R's type-7 definition,
//  which is what it documents. TrustPlan §2.2.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical, exactlyEqual, approximatelyEqual

@testable import BusinessMath

/// `quantile(sorted:p:)` against the published definition of R's type 7.
///
/// ## Why a definition and not a table
///
/// Five empirical percentile implementations existed in this library at once,
/// using two different algorithms — so the question is not "is this number
/// plausible" but "which of the nine published definitions is this". The answer
/// has to be checkable, and it is, because Hyndman & Fan enumerate them.
///
/// ## Where the reference values come from
///
/// - **Hyndman, R.J. & Fan, Y. (1996), "Sample Quantiles in Statistical
///   Packages", *The American Statistician* 50(4), 361-365**, definition 7. The
///   sample quantile is
///
///   ```
///   h    = (n - 1)p
///   Q(p) = x[⌊h⌋] + (h - ⌊h⌋)(x[⌊h⌋+1] - x[⌊h⌋])
///   ```
///
///   with `x` the ascending order statistics. This is the default in R
///   (`quantile(x, p, type = 7)`) and in NumPy (`np.quantile(x, p,
///   method = "linear")`), and it is what BusinessMath's doc comment claims.
/// - **Worked values** below are evaluated by hand from that formula, so every
///   expected number in this file can be checked with arithmetic and without
///   running anything. Where the arithmetic is exact in binary floating point the
///   assertion is a bit comparison; where it is not, the tolerance is stated.
///
/// ## Which definition it is *not*
///
/// Type 7 is pinned partly by what it disagrees with. For `[15, 20, 35, 40, 50]`
/// at `p = 0.4`:
///
/// | definition | `Q(0.4)` |
/// |---|---|
/// | type 7 (R, NumPy default) | **29** |
/// | type 6 (Minitab, SPSS) | 26 |
/// | type 4 (linear on the empirical CDF) | 20 |
/// | nearest-rank (Excel PERCENTILE.EXC neighbourhood) | 20 or 35 |
///
/// so a single assertion at that point distinguishes type 7 from the three most
/// common alternatives.
///
/// ## Where the tolerances come from
///
/// | tolerance | used for | justification |
/// |---|---|---|
/// | bit-exact | order statistics returned unmodified, and interpolations whose arithmetic is exact in binary | the documentation promises the order statistic "unmodified, with no floating-point interpolation error" when `h` lands on an index. A tolerance here would let a stray interpolation pass. |
/// | `1e-15` abs | interpolations with a non-dyadic fraction | one multiply and one add; the error is under an ulp of the result. |
@Suite("Empirical quantile vs R type 7")
struct QuantileType7ReferenceTests {

	/// `1 ... 10`, the sample the doc comment uses.
	static let oneToTen: [Double] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

	/// A five-point sample chosen so that type 7 separates from types 4 and 6.
	static let fivePoint: [Double] = [15, 20, 35, 40, 50]

	@Test("R type 7 on 1...10, worked out by hand")
	func typeSevenOnOneToTen() {
		// n = 10, so h = 9p.
		//
		//   p = 0.00  h = 0.0   Q = x[0]                       = 1
		//   p = 0.10  h = 0.9   Q = 1 + 0.9(2 - 1)             = 1.9
		//   p = 0.25  h = 2.25  Q = 3 + 0.25(4 - 3)            = 3.25
		//   p = 0.50  h = 4.5   Q = 5 + 0.5(6 - 5)             = 5.5
		//   p = 0.75  h = 6.75  Q = 7 + 0.75(8 - 7)            = 7.75
		//   p = 0.90  h = 8.1   Q = 9 + 0.1(10 - 9)            = 9.1
		//   p = 1.00  h = 9.0   Q = x[9]                       = 10
		#expect(identical(quantile(sorted: Self.oneToTen, p: 0.0), 1.0))
		#expect(identical(quantile(sorted: Self.oneToTen, p: 0.25), 3.25))
		#expect(identical(quantile(sorted: Self.oneToTen, p: 0.5), 5.5))
		#expect(identical(quantile(sorted: Self.oneToTen, p: 0.75), 7.75))
		#expect(identical(quantile(sorted: Self.oneToTen, p: 1.0), 10.0))
		// 0.9 and 0.1 are not exact in binary, so h = 8.1 and the fraction 0.1 both
		// round; the result is 9.1 to within an ulp rather than bit-exactly.
		#expect(approximatelyEqual(quantile(sorted: Self.oneToTen, p: 0.1), 1.9, tolerance: 1e-15))
		#expect(approximatelyEqual(quantile(sorted: Self.oneToTen, p: 0.9), 9.1, tolerance: 1e-15))
	}

	@Test("R type 7 separates from types 4 and 6")
	func typeSevenIsNotTypeFourOrSix() {
		// n = 5, h = 4p on [15, 20, 35, 40, 50].
		//
		//   p = 0.05  h = 0.2  Q = 15 + 0.2(20 - 15) = 16
		//   p = 0.30  h = 1.2  Q = 20 + 0.2(35 - 20) = 23
		//   p = 0.40  h = 1.6  Q = 20 + 0.6(35 - 20) = 29   <- type 6 gives 26
		//   p = 0.50  h = 2.0  Q = x[2]              = 35
		//   p = 0.75  h = 3.0  Q = x[3]              = 40
		#expect(approximatelyEqual(quantile(sorted: Self.fivePoint, p: 0.05), 16.0, tolerance: 1e-15))
		#expect(approximatelyEqual(quantile(sorted: Self.fivePoint, p: 0.30), 23.0, tolerance: 1e-15))
		#expect(
			approximatelyEqual(quantile(sorted: Self.fivePoint, p: 0.40), 29.0, tolerance: 1e-15),
			"Q(0.4) must be 29 (type 7); 26 would be type 6 and 20 would be type 4"
		)
		// h lands exactly on an index here, so the order statistic comes back
		// untouched — a bit comparison, as the doc comment promises.
		#expect(identical(quantile(sorted: Self.fivePoint, p: 0.50), 35.0))
		#expect(identical(quantile(sorted: Self.fivePoint, p: 0.75), 40.0))
	}

	@Test("Q(0) is the minimum and Q(1) is the maximum, bit-for-bit")
	func endpointsAreOrderStatistics() {
		// Type 7's defining boundary behaviour, and the property that separates it
		// from types 4-6 (which extrapolate past the sample at the extremes).
		for sample in [Self.oneToTen, Self.fivePoint, [2.5], [-3.0, 0.0, 7.25]] {
			#expect(identical(quantile(sorted: sample, p: 0.0), sample[0]))
			#expect(identical(quantile(sorted: sample, p: 1.0), sample[sample.count - 1]))
		}
	}

	@Test("Q(0.5) is the ordinary median for both odd and even n")
	func medianAgreesWithTheOrdinaryDefinition() {
		// Type 7 at p = 0.5 is the textbook median: the middle order statistic for
		// odd n, the average of the two middle ones for even n.
		#expect(identical(quantile(sorted: [1.0, 2.0, 3.0], p: 0.5), 2.0))
		#expect(identical(quantile(sorted: [1.0, 2.0, 3.0, 4.0], p: 0.5), 2.5))
		#expect(identical(quantile(sorted: [1.0, 2.0, 3.0, 4.0, 5.0], p: 0.5), 3.0))
		// And it agrees with the library's own `median`, which is a separate
		// implementation — the comparison that catches the two drifting apart.
		for sample in [Self.oneToTen, Self.fivePoint, [1.0, 2.0, 3.0, 4.0]] {
			#expect(
				identical(quantile(sorted: sample, p: 0.5), median(sample)),
				"quantile(p: 0.5) = \(quantile(sorted: sample, p: 0.5)) but median = \(median(sample))"
			)
		}
	}

	@Test("Every order statistic is reachable exactly")
	func orderStatisticsAreReachable() {
		// h = (n-1)p is an integer at p = i/(n-1), so Q must return x[i] unmodified.
		// This is the sweep that would have caught the inverse CDF's unreachable
		// interval had it been applied there: an interpolation that fires when it
		// should not shows up immediately.
		let n = Self.oneToTen.count
		for index in 0..<n {
			let p = Double(index) / Double(n - 1)
			let got = quantile(sorted: Self.oneToTen, p: p)
			#expect(
				identical(got, Self.oneToTen[index]),
				"quantile(p: \(p)) = \(got), expected order statistic \(Self.oneToTen[index]) exactly"
			)
		}
	}

	@Test("The quantile is monotone in p")
	func monotoneInP() {
		var previous = -Double.infinity
		for step in 0...1000 {
			let p = Double(step) / 1000.0
			let value = quantile(sorted: Self.oneToTen, p: p)
			#expect(value >= previous, "quantile fell from \(previous) to \(value) at p = \(p)")
			previous = value
		}
	}

	@Test("The quantile is equivariant under an affine change of units")
	func affineEquivariance() {
		// Q(ax + b) = aQ(x) + b for a > 0. Exact in the arithmetic when a and b are
		// dyadic, so a bit comparison — this is what catches an implementation that
		// rounds an index rather than interpolating a value.
		let scaled = Self.oneToTen.map { 4.0 * $0 + 0.5 }
		for p in [0.0, 0.125, 0.25, 0.5, 0.75, 1.0] {
			let direct = quantile(sorted: scaled, p: p)
			let transformed = 4.0 * quantile(sorted: Self.oneToTen, p: p) + 0.5
			#expect(
				identical(direct, transformed),
				"Q(4x + 0.5) at p = \(p) is \(direct) but 4Q(x) + 0.5 is \(transformed)"
			)
		}
	}

	@Test("Documented edge behaviour")
	func edges() {
		// The doc comment makes four promises about the edges. Each is asserted
		// because each is a decision a caller can depend on.
		#expect(quantile(sorted: [] as [Double], p: 0.5).isNaN, "an empty sample has no quantile")
		#expect(identical(quantile(sorted: [7.5], p: 0.0), 7.5))
		#expect(identical(quantile(sorted: [7.5], p: 0.9), 7.5))
		#expect(identical(quantile(sorted: [7.5], p: 2.0), 7.5))
		// p outside [0, 1] clamps rather than extrapolating or trapping.
		#expect(identical(quantile(sorted: Self.oneToTen, p: -1.0), 1.0))
		#expect(identical(quantile(sorted: Self.oneToTen, p: 2.0), 10.0))
		#expect(identical(quantile(sorted: Self.oneToTen, p: -.infinity), 1.0))
		#expect(identical(quantile(sorted: Self.oneToTen, p: .infinity), 10.0))
		#expect(quantile(sorted: Self.oneToTen, p: .nan).isNaN)
	}

	@Test("The empirical quantile recovers a known distribution's quantiles")
	func recoversTheNormalQuantiles() {
		// The end-to-end check: build a sample by evaluating the normal quantile
		// function on an even grid, then ask the empirical quantile for the same
		// probabilities back. This ties `quantile` to `inverseNormalCDF` — two
		// unrelated implementations — and would fail for either a wrong
		// interpolation rule or a discontinuous inverse CDF.
		//
		// Tolerance: the sample is 9999 points of the exact quantile function at
		// p = i/10000, and dropping the two infinite endpoints shifts the effective
		// grid by half a step. So the empirical quantile lands within one grid step
		// of the analytic one, and a grid step in z is dp/φ(z) = 1e-4/φ(z). The
		// worst case over the probabilities below is at p = 0.05 and p = 0.95, where
		// φ(z) = 0.1031, giving 9.7e-4. The band is 2e-3, twice that — it is set by
		// the grid, not by either function's accuracy.
		let grid = (0...10000).map { inverseNormalCDF(p: Double($0) / 10000.0) }
		let interior = Array(grid[1..<grid.count - 1]).sorted()
		for p in [0.05, 0.1, 0.25, 0.5, 0.75, 0.9, 0.95] {
			let empirical = quantile(sorted: interior, p: p)
			let analytic = inverseNormalCDF(p: p)
			#expect(
				approximatelyEqual(empirical, analytic, tolerance: 2e-3),
				"empirical Q(\(p)) = \(empirical) against the analytic \(analytic)"
			)
		}
	}
}
