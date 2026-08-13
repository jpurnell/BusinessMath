//
//  ValuePerShareGuardTests.swift
//  BusinessMath
//
//  Four types spell `valuePerShare` and they did not agree on what to do with an
//  impossible share count. `DividendDiscountModel` has always guarded its denominator and
//  thrown; `ResidualIncomeModel` and `FCFEModel` carried byte-identical two-line bodies
//  that were declared `throws` and never threw, so zero shares produced infinity and a
//  negative count produced a negative share price. The duplicate carried the defect with
//  the code.
//
//  These pin the guard on both, so the next copy of that body cannot quietly drop it.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Value Per Share Guards")
struct ValuePerShareGuardTests {

	private static var periods: [Period] { Period.documentationQuarters }

	private static var residualIncome: ResidualIncomeModel<Double> {
		ResidualIncomeModel(
			currentBookValue: 1_000.0,
			netIncome: TimeSeries(periods: periods, values: [120, 132, 145, 160]),
			bookValue: TimeSeries(periods: periods, values: [1_000, 1_100, 1_210, 1_331]),
			costOfEquity: 0.10,
			terminalGrowthRate: 0.03
		)
	}

	private static var fcfe: FCFEModel<Double> {
		FCFEModel(
			operatingCashFlow: TimeSeries(periods: periods, values: [500, 575, 661, 760]),
			capitalExpenditures: TimeSeries(periods: periods, values: [100, 115, 132, 152]),
			netBorrowing: nil,
			costOfEquity: 0.12,
			terminalGrowthRate: 0.04
		)
	}

	// MARK: - The valuation still works

	@Test("A positive share count still values normally")
	func positiveShareCountWorks() throws {
		let riPrice = try Self.residualIncome.valuePerShare(sharesOutstanding: 100.0)
		let fcfePrice = try Self.fcfe.valuePerShare(sharesOutstanding: 100.0)

		#expect(riPrice.isFinite && riPrice > 0, "residual income price was \(riPrice)")
		#expect(fcfePrice.isFinite && fcfePrice > 0, "FCFE price was \(fcfePrice)")
	}

	/// The guard must not change any answer it was not meant to change.
	@Test("The guard leaves the arithmetic untouched")
	func guardDoesNotAlterResults() throws {
		let shares = 250.0
		let riExpected = try Self.residualIncome.equityValue() / shares
		let fcfeExpected = try Self.fcfe.equityValue() / shares

		#expect(try Self.residualIncome.valuePerShare(sharesOutstanding: shares) == riExpected)
		#expect(try Self.fcfe.valuePerShare(sharesOutstanding: shares) == fcfeExpected)
	}

	// MARK: - Zero shares

	@Test("Zero shares throws rather than returning infinity")
	func zeroSharesThrows() throws {
		#expect(throws: ValuationError.self) {
			_ = try Self.residualIncome.valuePerShare(sharesOutstanding: 0.0)
		}
		#expect(throws: ValuationError.self) {
			_ = try Self.fcfe.valuePerShare(sharesOutstanding: 0.0)
		}
	}

	// MARK: - Negative shares

	/// A negative share count is not merely undefined — it silently flips the sign, so the
	/// caller gets a plausible-looking negative price rather than an obvious infinity.
	@Test("A negative share count throws rather than returning a negative price")
	func negativeSharesThrow() throws {
		#expect(throws: ValuationError.self) {
			_ = try Self.residualIncome.valuePerShare(sharesOutstanding: -100.0)
		}
		#expect(throws: ValuationError.self) {
			_ = try Self.fcfe.valuePerShare(sharesOutstanding: -100.0)
		}
	}
}
