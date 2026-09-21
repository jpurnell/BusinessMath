//
//  RankCorrelationDomainTests.swift
//  BusinessMath
//
//  Five functions built on Fisher's rank-correlation standard error, none of which checked
//  that the statistic exists.
//
//  SE(z) = sqrt(1.06 / (n - 3)), so `T(items - 3)` goes negative below n = 3 and the square
//  root is NaN. `fisher(_:)` guards its own singularity and throws — *"Fisher's Z requires
//  correlation strictly between -1 and 1"* — and `identricMean` guards its own `x == y`, so
//  the shape was recognised in this directory and not carried across.
//
//  Measured before the guards:
//
//  | items | `zScore(rho:items:)` | `zScore(fisherR:items:)` | `correlationBreakpoint` |
//  |---|---|---|---|
//  | 0, 1, 2 | **NaN** | **NaN** | **NaN** |
//  | 3 | 0.0 | 0.0 | **NaN** — its `zComponents` is the divisor |
//  | 4 | 0.673 | 0.673 | 0.935 |
//
//  The `n = 3` column is its own problem: the standard error is infinite there, so *every*
//  correlation scored exactly 0.0, including one of 0.99.
//
//  `tStatistic(_:dFr:)` is the same family and the same omission: `dFr / (1 - rho^2)` at
//  rho = +/-1. Its array overload feeds it `spearmansRho`, which is exactly +/-1 for any
//  perfectly monotone data — `[1, 2]` against `[3, 4]` returned NaN.
//

import Testing
@testable import BusinessMath

@Suite("Rank-correlation statistics reject samples too small to carry them")
struct RankCorrelationDomainTests {

	// MARK: - The throwing members say what is wrong

	@Test("ZScoreRho_BelowFour_Throws", arguments: [0, 1, 2, 3])
	func zScoreRhoBelowFourThrows(items: Int) {
		#expect(throws: BusinessMathError.self) {
			_ = try zScore(rho: 0.6, items: items)
		}
	}

	@Test("ZScoreArray_BelowFour_Throws") func zScoreArrayBelowFourThrows() {
		let xs: [Double] = [1, 2, 3]
		let ys: [Double] = [2, 4, 7]
		#expect(throws: BusinessMathError.self) { _ = try zScore(xs, vs: ys) }
		#expect(throws: BusinessMathError.self) { _ = try zScore(xs, r: 0.6) }
	}

	@Test("TStatisticArray_BelowThree_Throws") func tStatisticArrayBelowThreeThrows() {
		#expect(throws: BusinessMathError.self) {
			_ = try tStatistic([1.0, 2.0], [3.0, 4.0])
		}
	}

	// MARK: - The non-throwing members state their domain

	///
	/// The sizes are spelled out rather than looped: an exit-test body becomes a C function
	/// pointer, so it cannot capture a loop variable.
	@Test("ZScoreFisherR_BelowFour_Traps", .requiresUnsanitizedRuntime)
	func zScoreFisherRBelowFourTraps() async {
		await #expect(processExitsWith: .failure) { _ = zScore(fisherR: 0.693, items: 0) }
		await #expect(processExitsWith: .failure) { _ = zScore(fisherR: 0.693, items: 1) }
		await #expect(processExitsWith: .failure) { _ = zScore(fisherR: 0.693, items: 2) }
		await #expect(processExitsWith: .failure) { _ = zScore(fisherR: 0.693, items: 3) }
	}

	@Test("CorrelationBreakpoint_BelowFour_Traps", .requiresUnsanitizedRuntime)
	func correlationBreakpointBelowFourTraps() async {
		await #expect(processExitsWith: .failure) { _ = correlationBreakpoint(0, probability: 0.95) }
		await #expect(processExitsWith: .failure) { _ = correlationBreakpoint(1, probability: 0.95) }
		await #expect(processExitsWith: .failure) { _ = correlationBreakpoint(2, probability: 0.95) }
		await #expect(processExitsWith: .failure) { _ = correlationBreakpoint(3, probability: 0.95) }
	}

	/// A correlation outside [-1, 1] is not a correlation, and the radicand goes negative.
	@Test("TStatistic_CorrelationOutsideRange_Traps", .requiresUnsanitizedRuntime)
	func tStatisticOutsideRangeTraps() async {
		await #expect(processExitsWith: .failure) { _ = tStatistic(1.5, dFr: 8.0) }
		await #expect(processExitsWith: .failure) { _ = tStatistic(-1.5, dFr: 8.0) }
	}

	@Test("TStatistic_NonPositiveDegreesOfFreedom_Traps", .requiresUnsanitizedRuntime)
	func tStatisticNonPositiveDegreesOfFreedomTraps() async {
		await #expect(processExitsWith: .failure) { _ = tStatistic(0.8, dFr: 0.0) }
		await #expect(processExitsWith: .failure) { _ = tStatistic(0.8, dFr: -1.0) }
	}

	// MARK: - Everything that had an answer still has the same one

	/// The values measured at `items = 4`, where the statistic first exists, and at a size the
	/// existing suite already uses.
	@Test("FourAndAbove_Unchanged") func fourAndAboveUnchanged() throws {
		let atFour = try zScore(rho: 0.6, items: 4)
		#expect(atFour.isEqual(to: 0.6732440570106727), "the first size the statistic exists at")
		let atTen = try zScore(rho: 0.6, items: 10)
		#expect(atTen.isEqual(to: 1.7812363465024312), "and a size the existing suite uses")
		#expect(correlationBreakpoint(4, probability: 0.95).isEqual(to: 0.934589074411705))
		#expect(zScore(fisherR: 0.693, items: 4).isEqual(to: 0.673101102613584))
	}

	/// A perfect rank correlation is still infinity, which is the correct limit rather than a
	/// defect — the precondition deliberately admits `|rho| == 1`.
	@Test("PerfectCorrelation_IsStillInfinite") func perfectCorrelationIsStillInfinite() throws {
		let t = try tStatistic([1.0, 2.0, 3.0, 4.0], [2.0, 4.0, 6.0, 8.0])
		#expect(t.isInfinite && t > 0, "a perfect rank correlation has a vanishing p-value")
		let reversed = try tStatistic([1.0, 2.0, 3.0, 4.0], [8.0, 6.0, 4.0, 2.0])
		#expect(reversed.isInfinite && reversed < 0, "and so does a perfectly reversed one")
	}

	/// The ordinary case from the existing suite, to the bit.
	@Test("OrdinaryTStatistic_Unchanged") func ordinaryTStatisticUnchanged() {
		#expect(tStatistic(0.8, dFr: 10.0).isEqual(to: 4.21637021355784))
	}
}
