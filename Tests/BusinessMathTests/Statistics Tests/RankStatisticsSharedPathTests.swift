//
//  RankStatisticsSharedPathTests.swift
//  BusinessMathTests
//
//  `dValue`, `friedmanChiSquare` and `kendallW` each carried the same twenty-line preamble:
//  validate, derive judges and items, sum ranks by column. This pins what the three do
//  before that preamble is extracted, including the places where they deliberately differ.
//

import Testing
import Numerics
@testable import BusinessMath

/// The three rank statistics that share an input shape, and what they agree on.
///
/// All three take a judges × items matrix of ranks and begin by reducing it to one rank sum
/// per item. They then diverge into genuinely different statistics — so the preamble is
/// shared and the mathematics is not.
@Suite("Rank statistics — shared input path")
struct RankStatisticsSharedPathTests {

	/// Three judges ranking four items, each row a permutation of 1…4.
	private static let wellFormed: [[Double]] = [[1, 2, 3, 4], [2, 1, 4, 3], [1, 3, 2, 4]]

	/// Column sums of `wellFormed`, which every one of the three computes identically.
	private static let expectedRankSums: [Double] = [4, 6, 9, 11]

	@Test("All three reduce the same matrix to the same rank sums")
	func rankSumsAgree() {
		// Verified through the public entry points rather than by reaching for the
		// preamble: the rank sums are not returned, so they are checked by the fact that
		// the from-rank-sums overloads reproduce the whole-matrix answers exactly.
		let sums = Self.expectedRankSums
		let matrix = Self.wellFormed

		let dWhole = dValue(matrix)
		let dFromSums = dValueFromRankSums(rankSums: sums, judges: 3, items: 4)
		#expect(dWhole.isEqual(to: dFromSums), "dValue: \(dWhole) against \(dFromSums)")

		let wWhole = kendallW(matrix)
		let wFromSums = kendallWFromRankSums(rankSums: sums, judges: 3, items: 4)
		#expect(wWhole.isEqual(to: wFromSums), "kendallW: \(wWhole) against \(wFromSums)")

		let fWhole = friedmanChiSquare(matrix)
		let fFromSums = friedmanChiSquareFromRankSums(rankSums: sums, judges: 3, items: 4)
		#expect(fWhole.isEqual(to: fFromSums), "friedman: \(fWhole) against \(fFromSums)")
	}

	/// The relationship that makes these two the same measurement written twice.
	///
	/// `dValue` centres its squared deviations on the *theoretical* mean rank sum,
	/// `n(k+1)/2`. `kendallW` centres on the *empirical* mean of the rank sums it was
	/// given. For a complete ranking — every judge ranking every item exactly once — those
	/// two quantities are equal by construction, so D and S are the same number reached by
	/// different routes.
	///
	/// They part company the moment the input is not a complete ranking, and **neither
	/// function checks that it is.** That is recorded in `theyDivergeOnMalformedInput`
	/// below rather than fixed here, because refusing such input changes what these
	/// functions return.
	@Test("On a complete ranking, dValue's D and Kendall's S are the same number")
	func dEqualsSOnWellFormedInput() {
		let sums = Self.expectedRankSums
		let d = dValueFromRankSums(rankSums: sums, judges: 3, items: 4)

		// Kendall's S, computed here from the definition rather than taken from `kendallW`,
		// which divides it through by n²(k³−k) before returning.
		let meanRankSum = sums.reduce(0.0, +) / Double(sums.count)
		let s = sums.reduce(0.0) { $0 + ($1 - meanRankSum) * ($1 - meanRankSum) }

		#expect(d.isEqual(to: s), "D was \(d) and S was \(s)")
		// And the value itself, so neither can drift while still matching the other.
		#expect(d.isEqual(to: 29.0), "D was \(d)")
	}

	/// The same S is `variance(rankSums, .population) × count`, which the library exports.
	@Test("Kendall's S is the population variance of the rank sums, scaled by their count")
	func sIsScaledPopulationVariance() {
		let sums = Self.expectedRankSums
		let viaLibrary = variance(sums, .population) * Double(sums.count)
		let d = dValueFromRankSums(rankSums: sums, judges: 3, items: 4)
		#expect(viaLibrary.isEqual(to: d), "variance route gave \(viaLibrary), D gave \(d)")
	}

	/// What the missing validation costs, measured.
	@Test("On input that is not a complete ranking, the two centres disagree")
	func theyDivergeOnMalformedInput() {
		// The first judge has given every item rank 1, which is not a ranking. Both
		// functions accept it; the theoretical centre still assumes a complete ranking
		// while the empirical centre follows the data, so the two answers separate.
		let malformed: [[Double]] = [[1, 1, 1, 1], [2, 1, 4, 3], [1, 3, 2, 4]]
		var sums = [Double](repeating: 0, count: 4)
		for row in malformed {
			for (column, rank) in row.enumerated() { sums[column] += rank }
		}
		#expect(sums == [4, 5, 7, 8], "rank sums were \(sums)")

		let d = dValueFromRankSums(rankSums: sums, judges: 3, items: 4)
		let meanRankSum = sums.reduce(0.0, +) / Double(sums.count)
		let s = sums.reduce(0.0) { $0 + ($1 - meanRankSum) * ($1 - meanRankSum) }

		#expect(d.isEqual(to: 19.0), "D was \(d)")
		#expect(s.isEqual(to: 10.0), "S was \(s)")
		// Pinned as a difference rather than asserted to be zero: this is the current
		// behaviour, and it is the reason validation is worth adding.
		#expect((d - s).isEqual(to: 9.0), "the two centres differed by \(d - s)")
	}

	/// The three do not agree about what an empty matrix is.
	@Test("Empty input returns zero from dValue and NaN from the other two")
	func emptyInputIsAnswerdInconsistently() {
		let empty: [[Double]] = []
		let emptyRow: [[Double]] = [[]]

		// `dValue` reports zero — a value in the statistic's own range, indistinguishable
		// from a matrix of perfectly tied ranks.
		#expect(dValue(empty).isEqual(to: 0.0), "dValue(empty) was \(dValue(empty))")
		#expect(dValue(emptyRow).isEqual(to: 0.0), "dValue([[]]) was \(dValue(emptyRow))")

		// The other two report NaN, which a caller can detect.
		#expect(kendallW(empty).isNaN, "kendallW(empty) was \(kendallW(empty))")
		#expect(friedmanChiSquare(empty).isNaN, "friedman(empty) was \(friedmanChiSquare(empty))")
	}

	@Test("A single item is refused by the two that need a comparison to make")
	func singleItemIsRefused() {
		let oneItem: [[Double]] = [[1], [1], [1]]
		#expect(kendallW(oneItem).isNaN, "kendallW was \(kendallW(oneItem))")
		#expect(friedmanChiSquare(oneItem).isNaN, "friedman was \(friedmanChiSquare(oneItem))")
	}
}
