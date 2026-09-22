//
//  ProfitabilityIndexNoInvestmentTests.swift
//  BusinessMathTests
//
//  `profitabilityIndex` invented a number when there was nothing to divide by.
//
//      guard pvNegative < T.zero else {
//          // No investments, return infinity or very large number
//          return T(1000000)
//      }
//
//  A profitability index of 1,000,000 is a value a real project can produce — a small
//  outflow against large inflows — so a caller could not tell an extraordinary project from
//  one the function was never given an investment for. The comment names the right answer
//  and then returns the other one.
//
//  `mirr` refuses the identical precondition in the sibling file, throwing
//  `BusinessMathError.calculationFailed` with three suggestions attached. This is the same
//  situation handled two ways in two files.
//
//  The division answers both cases on its own, which is the change `sharpeRatio(weights:)`
//  already made at zero risk — see `SharpeZeroRiskTests`, whose table is the precedent:
//
//  | excess return | risk | Sharpe |
//  |---|---|---|
//  | positive | 0 | `+infinity` — infinitely good, and true |
//  | zero | 0 | `NaN` — 0/0, genuinely undefined |
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Profitability index with nothing invested")
struct ProfitabilityIndexNoInvestmentTests {

	/// Unbounded return per unit of invested capital, because none was invested.
	@Test("NoOutflows_IsUnbounded") func noOutflowsIsUnbounded() {
		let pi = profitabilityIndex(rate: 0.10, cashFlows: [100.0, 600.0, 600.0])
		#expect(pi.isInfinite && pi > 0, "was the literal 1000000, which a real project can also score")
	}

	/// No cash flows at all is `0 / 0` — undefined, not infinitely good.
	@Test("NoFlowsAtAll_IsUndefined") func noFlowsAtAllIsUndefined() {
		#expect(profitabilityIndex(rate: 0.10, cashFlows: [0.0, 0.0]).isNaN,
				"nothing in and nothing out has no ratio")
	}

	/// The sign matters: `pvNegative` is exactly zero when no outflow was ever added, and
	/// negating a zero gives `-0.0`, which would have turned a positive numerator into
	/// *negative* infinity. The magnitude is taken instead.
	///
	/// **This one passes against the unfixed source too**, because `1000000` is also
	/// positive. It pins the sign of the new behaviour rather than catching the old defect —
	/// without it, a later simplification back to `pvPositive / (-pvNegative)` would return
	/// `-infinity` here and only the two tests above would notice.
	@Test("NoOutflows_IsPositiveInfinity_NotNegative") func noOutflowsIsPositiveInfinity() {
		let pi = profitabilityIndex(rate: 0.05, cashFlows: [50.0, 50.0])
		#expect(pi > 0, "a project returning cash is not infinitely bad: \(pi)")
	}

	/// And every project that had an answer keeps exactly the same one — this is the value
	/// the existing `NPVTests` fixture already pins.
	@Test("OrdinaryProject_BitIdentical") func ordinaryProjectBitIdentical() {
		let pi = profitabilityIndex(rate: 0.10, cashFlows: [-1000.0, 600.0, 600.0])
		#expect(pi.isEqual(to: 1.0413223140495866))
	}

	/// A project that destroys value still scores below one, unchanged.
	@Test("NegativeNPVProject_Unchanged") func negativeNPVProjectUnchanged() {
		let pi = profitabilityIndex(rate: 0.10, cashFlows: [-1000.0, 400.0, 400.0])
		#expect(pi < 1.0, "PI was \(pi)")
		#expect(pi.isFinite)
	}

	/// The sibling that already refused this input, for contrast — `mirr` throws where the
	/// profitability index used to invent a number.
	@Test("MIRR_RefusesTheSameInput") func mirrRefusesTheSameInput() {
		#expect(throws: BusinessMathError.self) {
			_ = try mirr(cashFlows: [100.0, 600.0, 600.0], financeRate: 0.10, reinvestmentRate: 0.10)
		}
	}
}
