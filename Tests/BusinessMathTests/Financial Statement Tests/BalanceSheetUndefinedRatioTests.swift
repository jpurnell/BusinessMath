//
//  BalanceSheetUndefinedRatioTests.swift
//  BusinessMath
//
//  Every ratio on a balance sheet divides one aggregate by another, and each of
//  those denominators can be zero on a perfectly ordinary set of books: a company
//  that owes nothing short-term, a company financed entirely by debt, an entity
//  opened but not yet funded. Unguarded, each returned `+infinity`, which is not
//  representable in JSON — so the ratio did not merely read wrong, it took the
//  whole enclosing snapshot down with it at encoding time.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Balance Sheet: Undefined Ratios")
struct BalanceSheetUndefinedRatioTests {

	private static let entity = Entity(id: "test", name: "Test Entity")
	private static let periods = [Period.quarter(year: 2025, quarter: 1)]
	private static var q1: Period { periods[0] }

	private static func account(
		_ name: String,
		_ role: BalanceSheetRole,
		_ value: Double
	) throws -> Account<Double> {
		try Account(
			entity: entity,
			name: name,
			balanceSheetRole: role,
			timeSeries: TimeSeries(periods: periods, values: [value])
		)
	}

	/// Assets 100k in cash, no liabilities at all, 100k of equity. The books
	/// balance; there is simply nothing owed.
	private static func debtFreeSheet() throws -> BalanceSheet<Double> {
		try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [
				account("Cash", .cashAndEquivalents, 100_000),
				account("Common Stock", .commonStock, 100_000)
			]
		)
	}

	/// Assets 100k, all of it financed by a term loan, so equity is zero.
	private static func noEquitySheet() throws -> BalanceSheet<Double> {
		try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [
				account("Cash", .cashAndEquivalents, 100_000),
				account("Term Loan", .longTermDebt, 100_000),
				account("Common Stock", .commonStock, 0)
			]
		)
	}

	/// An entity that exists on paper and holds nothing.
	private static func emptySheet() throws -> BalanceSheet<Double> {
		try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [
				account("Cash", .cashAndEquivalents, 0),
				account("Common Stock", .commonStock, 0)
			]
		)
	}

	// MARK: - Coverage ratios with nothing to cover

	@Test("Liquidity ratios with no current liabilities have no value")
	func liquidityRatiosWithNoCurrentLiabilities() throws {
		let sheet = try Self.debtFreeSheet()

		#expect(sheet.currentLiabilities[Self.q1] == 0, "precondition: nothing owed short-term")

		#expect(
			sheet.currentRatio[Self.q1] == nil,
			"current ratio was \(String(describing: sheet.currentRatio[Self.q1]))"
		)
		#expect(sheet.quickRatio[Self.q1] == nil)
		#expect(sheet.cashRatio[Self.q1] == nil)
	}

	// MARK: - Leverage ratios with no equity

	@Test("Debt-to-equity with no equity has no value")
	func debtToEquityWithNoEquity() throws {
		let sheet = try Self.noEquitySheet()

		#expect(sheet.totalEquity[Self.q1] == 0, "precondition: no equity")
		#expect(
			sheet.debtToEquity[Self.q1] == nil,
			"debt-to-equity was \(String(describing: sheet.debtToEquity[Self.q1]))"
		)
	}

	// MARK: - Composition ratios with no assets

	@Test("Composition ratios with no assets have no value")
	func compositionRatiosWithNoAssets() throws {
		let sheet = try Self.emptySheet()

		#expect(sheet.totalAssets[Self.q1] == 0, "precondition: nothing on the books")
		#expect(sheet.equityRatio[Self.q1] == nil)
		#expect(sheet.debtRatio[Self.q1] == nil)
	}

	// MARK: - Zero is not the answer either

	/// Zero is the wrong answer in the direction that matters. A minimum-coverage
	/// threshold — "current ratio at least 1.25" — is failed by zero, so the one
	/// balance sheet that owes nothing would read as the least liquid on the books.
	/// The same for leverage in reverse: zero debt-to-equity on a company with no
	/// equity at all reads as unlevered.
	@Test("An undefined ratio is absent, not zero")
	func undefinedRatioIsAbsentNotZero() throws {
		let liquid = try Self.debtFreeSheet()
		#expect(liquid.currentRatio[Self.q1] != 0.0, "zero would read as no coverage at all")

		let levered = try Self.noEquitySheet()
		#expect(levered.debtToEquity[Self.q1] != 0.0, "zero would read as unlevered")
	}

	// MARK: - The downstream break

	/// The reason this matters beyond the reading: `+infinity` is not encodable, and
	/// the balance sheet's own materialised form carries every one of these ratios.
	@Test("A materialised debt-free balance sheet encodes")
	func materializedDebtFreeSheetEncodes() throws {
		let sheet = try Self.debtFreeSheet()
		let materialized = sheet.materialize()

		let encoder = JSONEncoder()
		#expect(throws: Never.self) {
			_ = try encoder.encode(materialized.currentRatio)
		}
		#expect(throws: Never.self) {
			_ = try encoder.encode(materialized.debtToEquity)
		}
		#expect(throws: Never.self) {
			_ = try encoder.encode(materialized.equityRatio)
		}
	}

	/// A covenant that requires a *minimum* current ratio is satisfied by a company
	/// with no current liabilities — there is nothing it can fail to cover. Reading
	/// the absent ratio as zero would report a breach against the strongest possible
	/// short-term position.
	@Test("A minimum current-ratio covenant is not breached by having no current liabilities")
	func minimumCurrentRatioCovenantWithNoCurrentLiabilities() throws {
		let sheet = try Self.debtFreeSheet()

		let revenue = try Account(
			entity: Self.entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: Self.periods, values: [50_000.0])
		)
		let incomeStatement = try IncomeStatement(
			entity: Self.entity,
			periods: Self.periods,
			accounts: [revenue]
		)

		let covenant = FinancialCovenant(
			name: "Minimum Current Ratio",
			requirement: .minimumRatio(metric: .currentRatio, threshold: 1.25)
		)

		let results = CovenantMonitor(covenants: [covenant]).checkCompliance(
			incomeStatement: incomeStatement,
			balanceSheet: sheet,
			period: Self.q1
		)

		#expect(
			results.map(\.isCompliant) == [true],
			"actual value reported: \(results.map(\.actualValue))"
		)
	}
}
