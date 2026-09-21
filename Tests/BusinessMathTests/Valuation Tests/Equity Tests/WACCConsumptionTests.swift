//
//  WACCConsumptionTests.swift
//  BusinessMath
//
//  What happens to a discount rate that cannot be one.
//
//  `DCFModel` in the DSL was validated and guarded after `pow(1 + wacc, years)` was found to
//  be a division by zero at exactly −100% WACC. This is the sweep of everywhere else a WACC
//  is consumed, written down because the *result* was that nothing else needed fixing — and
//  an absence is only useful if it is recorded with the evidence for it.
//
//  | site | at wacc = −100% | guarded? |
//  |---|---|---|
//  | `wacc(equityValue:…)` | not reached — it *computes* a rate | `totalValue > 0` before both divisions |
//  | `CapitalStructure.wacc` | same | via `equityRatio` / `debtRatio` |
//  | `enterpriseValueFromFCFF` | NaN | `denominator > 0`, plus NaN propagation |
//
//  The last of those is the one worth a test, because its NaN is **accidental**. At
//  `wacc = −100%` every discount factor is `pow(0, n) = 0`, so the explicit-period present
//  value is `+∞`; the terminal value is negative wherever the growth guard lets the
//  calculation through, so its present value is `−∞`; and `+∞ + (−∞)` is NaN. Nothing in the
//  function decided that. A refactor that changed a sign, or summed in a different order,
//  could turn the same input into a finite-looking `+∞` — an enterprise value that a caller
//  would have no reason to distrust.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("A discount rate that cannot be one")
struct WACCConsumptionTests {

	private static func fcff() -> TimeSeries<Double> {
		let periods = (1...4).map { Period.year(2024 + $0) }
		return TimeSeries(periods: periods, values: [100.0, 110.0, 120.0, 130.0])
	}

	@Test("A sound WACC still values the firm", arguments: [
		(0.10, 0.02), (0.08, 0.03), (0.12, 0.00)
	])
	func soundWACCValuesTheFirm(rate: Double, growth: Double) {
		let value = enterpriseValueFromFCFF(
			freeCashFlowToFirm: Self.fcff(), wacc: rate, terminalGrowthRate: growth)
		#expect(value.isFinite, "wacc \(rate), growth \(growth) gave \(value)")
		#expect(value > 0, "wacc \(rate), growth \(growth) gave \(value)")
	}

	@Test("No impossible discount rate produces a number a caller could believe", arguments: [
		(-1.0, -1.5),   // exactly -100%: every discount factor is pow(0, n) = 0
		(-1.0, -2.0),
		(-1.5, -2.0),   // below -100%: pow of a negative base, which is not real
		(-2.0, -3.0),
		(0.05, 0.05),   // wacc equals growth: the perpetuity does not converge
		(0.03, 0.05)    // growth exceeds wacc: it converges to the wrong sign
	])
	func impossibleRatesNeverLookLikeAnAnswer(rate: Double, growth: Double) {
		let value = enterpriseValueFromFCFF(
			freeCashFlowToFirm: Self.fcff(), wacc: rate, terminalGrowthRate: growth)
		#expect(!value.isFinite,
				"wacc \(rate), growth \(growth) returned \(value), which a caller would read as a valuation")
	}

	@Test("The capital structure's WACC is the free function's, not a second copy of it")
	func capitalStructureDelegates() {
		// The property's comment claimed it called the free function and did not — the
		// formula was written out twice. This is the assertion that keeps them together.
		let structures: [(Double, Double, Double, Double, Double)] = [
			(600, 400, 0.12, 0.06, 0.25),
			(1000, 0, 0.10, 0.05, 0.21),
			(0, 500, 0.15, 0.07, 0.30),
			(250, 750, 0.09, 0.04, 0.00)
		]
		for (equity, debt, re, rd, tax) in structures {
			let structure = CapitalStructure(
				debtValue: debt, equityValue: equity,
				costOfDebt: rd, costOfEquity: re, taxRate: tax)
			let direct = wacc(equityValue: equity, debtValue: debt,
							  costOfEquity: re, costOfDebt: rd, taxRate: tax)
			#expect(structure.wacc.isEqual(to: direct),
					"E \(equity) D \(debt): property \(structure.wacc), function \(direct)")
		}
	}

	@Test("A structure with no capital reports zero rather than dividing by zero")
	func emptyCapitalStructureIsZero() {
		let structure = CapitalStructure(
			debtValue: 0, equityValue: 0, costOfDebt: 0.05, costOfEquity: 0.10, taxRate: 0.21)
		#expect(structure.wacc.isEqual(to: 0.0), "got \(structure.wacc)")
		#expect(structure.debtRatio.isEqual(to: 0.0))
		#expect(structure.equityRatio.isEqual(to: 0.0))

		let direct = wacc(equityValue: 0, debtValue: 0,
						  costOfEquity: 0.10, costOfDebt: 0.05, taxRate: 0.21)
		#expect(direct.isEqual(to: 0.0), "got \(direct)")
	}
}
