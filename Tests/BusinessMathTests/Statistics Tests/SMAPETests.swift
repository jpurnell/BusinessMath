//
//  SMAPETests.swift
//  BusinessMath
//
//  RED phase — step 1 of PROPOSAL_ets_fitting.md.
//
//  SMAPE is tested by its defining property rather than against a remembered constant:
//  swapping the arguments must leave the result bit-for-bit unchanged. That is what
//  distinguishes it from MAPE and it is the assertion a wrong implementation cannot pass.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("SMAPE — symmetric mean absolute percentage error")
struct SMAPETests {

	let tolerance: Double = 1e-12

	// MARK: - The defining property

	/// Argument pairs spanning positives, negatives, zeros on each side, and zeros on both.
	private static let symmetryCases: [(actual: [Double], forecast: [Double])] = [
		(actual: [100, 110, 120], forecast: [95, 115, 118]),
		(actual: [0, 100, 200], forecast: [10, 90, 210]),          // zero on the left
		(actual: [50, 100, 150], forecast: [0, 90, 160]),          // zero on the right
		(actual: [0, 100, 0], forecast: [0, 90, 25]),              // zero on both, and one-sided
		(actual: [-10, -20, -30], forecast: [-11, -19, -33]),      // wholly negative
		(actual: [-5, 5, -5], forecast: [5, -5, 5]),               // sign flips every term
		(actual: [0, 0, 0], forecast: [0, 0, 0])                   // degenerate: all both-zero
	]

	@Test("Swapping the arguments leaves SMAPE bit-for-bit unchanged", arguments: symmetryCases)
	func symmetryIsExact(pair: (actual: [Double], forecast: [Double])) {
		let forward: Double = smape(pair.actual, pair.forecast)
		let reversed: Double = smape(pair.forecast, pair.actual)
		#expect(forward.isEqual(to: reversed), "SMAPE must be symmetric in its arguments")
	}

	// MARK: - Range

	@Test("SMAPE lies in [0, 2] on every symmetry case", arguments: symmetryCases)
	func rangeIsZeroToTwo(pair: (actual: [Double], forecast: [Double])) {
		let value: Double = smape(pair.actual, pair.forecast)
		#expect(value >= 0.0)
		#expect(value <= 2.0)
	}

	@Test("The halved denominator puts the worst case at 2, not 1")
	func halvedDenominatorReachesTwo() {
		// Every actual is ±1 against a forecast of zero: each term is 1 / ((1 + 0) / 2) = 2.
		// The unhalved form is bounded by 1 by the triangle inequality and could never
		// reach this. Excel's FORECAST.ETS.STAT type 5 returned 1.94306435 on an
		// alternating series, which is only reachable under the halved convention.
		let actual: [Double] = [1, -1, 1, -1]
		let forecast: [Double] = [0, 0, 0, 0]
		let value: Double = smape(actual, forecast)
		#expect(abs(value - 2.0) < tolerance)
	}

	// MARK: - The both-zero term

	@Test("A term where actual and forecast are both zero contributes zero, not NaN")
	func bothZeroContributesZero() {
		// Terms: (0,0) → 0, and (100, 50) → 50 / 75 = 2/3. Mean over two terms = 1/3.
		let actual: [Double] = [0, 100]
		let forecast: [Double] = [0, 50]
		let value: Double = smape(actual, forecast)
		let expected: Double = 1.0 / 3.0
		#expect(abs(value - expected) < tolerance)
	}

	@Test("An all-both-zero series scores zero rather than NaN")
	func allBothZeroScoresZero() {
		let zeros: [Double] = [0, 0, 0]
		let value: Double = smape(zeros, zeros)
		#expect(abs(value) < tolerance)
	}

	// MARK: - Known values

	@Test("A perfect forecast scores zero")
	func perfectForecastScoresZero() {
		let values: [Double] = [10, 20, 30]
		#expect(abs(smape(values, values)) < tolerance)
	}

	@Test("A uniform 10% overshoot scores 2 · 10 / 210")
	func uniformOvershoot() {
		let actual: [Double] = [100, 200, 300]
		let forecast: [Double] = [110, 220, 330]
		// Each term: |a − 1.1a| / ((a + 1.1a) / 2) = 0.1a / (1.05a) = 2/21.
		let value: Double = smape(actual, forecast)
		let expected: Double = 2.0 / 21.0
		#expect(abs(value - expected) < tolerance)
	}

	// MARK: - Refusals

	@Test("Empty input returns NaN")
	func emptyReturnsNaN() {
		let empty: [Double] = []
		#expect(smape(empty, empty).isNaN)
	}

	@Test("Mismatched lengths return NaN")
	func mismatchedReturnsNaN() {
		#expect(smape([1.0, 2.0], [1.0]).isNaN)
	}

	// MARK: - Generic support

	@Test("SMAPE works with Float")
	func floatSupport() {
		let actual: [Float] = [100, 110, 120]
		let forecast: [Float] = [95, 115, 125]
		let value: Float = smape(actual, forecast)
		#expect(value > 0)
		#expect(value <= 2)
	}
}
