//
//  DocumentationFixtures.swift
//  BusinessMath
//
//  Ready-made statements for the examples in doc comments.
//

import Foundation
import Numerics

// MARK: - Why this exists
//
// A doc-comment example is checked by compiling the fence *alone*, with nothing
// imported but Foundation and this module. That is deliberate — a reader copying one
// panel out of Quick Help gets the fence and nothing else, so whatever the fence needs
// to say in order to build is exactly what that reader has to type. There is no shared
// preamble to hide setup in, and adding one would turn failing examples into passing
// examples while leaving them just as uncopyable.
//
// Without something like this, every example that wants a balance sheet has to build an
// entity, four periods and a dozen accounts before it can show the one line it is
// actually about. These fixtures collapse that to a line, so the example can be both
// runnable and about its subject.
//
// The name is long on purpose. `BalanceSheet.fixture` reads like something you might
// reasonably reach for in production; `BalanceSheet.documentationFixture` does not, and
// this is a financial library where a sample balance sheet reaching a real report is a
// worse outcome than a slightly verbose doc line.

// MARK: - Periods

extension Period {

	/// The four quarters of 2024, the period axis every documentation fixture shares.
	///
	/// Examples that need a single period take `.documentationQuarters[0]`; the doc
	/// comments name it `q1`.
	public static var documentationQuarters: [Period] {
		(1...4).map { Period.quarter(year: 2024, quarter: $0) }
	}
}

// MARK: - Entity

extension Entity {

	/// The company every documentation fixture belongs to.
	public static var documentationFixture: Entity {
		Entity(id: "ACME", name: "Acme Corporation", currency: "USD")
	}
}

// MARK: - Balance sheet

extension BalanceSheet where T == Double {

	/// A small, balanced balance sheet for use in doc-comment examples.
	///
	/// Assets total 1,000 against liabilities of 400 and equity of 600 in every period,
	/// so the accounting identity holds — an example that does not balance would teach
	/// the wrong thing about the type it is documenting.
	///
	/// - Throws: `AccountError` if a fixture account is malformed, which would be a bug
	///   in this file rather than in the caller's code.
	public static var documentationFixture: BalanceSheet<Double> {
		get throws {
			let entity = Entity.documentationFixture
			let periods = Period.documentationQuarters

			func account(_ name: String, _ role: BalanceSheetRole, _ values: [Double]) throws -> Account<Double> {
				try Account(
					entity: entity,
					name: name,
					balanceSheetRole: role,
					timeSeries: TimeSeries(periods: periods, values: values)
				)
			}

			let accounts = [
				try account("Cash", .cashAndEquivalents, [300, 320, 340, 360]),
				try account("Accounts Receivable", .accountsReceivable, [200, 210, 220, 230]),
				try account("Inventory", .inventory, [150, 150, 150, 150]),
				try account("Property, Plant and Equipment", .propertyPlantEquipment, [350, 340, 330, 320]),
				try account("Accounts Payable", .accountsPayable, [150, 155, 160, 165]),
				try account("Long-Term Debt", .longTermDebt, [250, 245, 240, 235]),
				try account("Common Stock", .commonStock, [400, 400, 400, 400]),
				try account("Retained Earnings", .retainedEarnings, [200, 220, 240, 260])
			]

			return try BalanceSheet(entity: entity, periods: periods, accounts: accounts)
		}
	}
}

// MARK: - Income statement

extension IncomeStatement where T == Double {

	/// A small income statement for use in doc-comment examples.
	///
	/// Revenue grows quarter on quarter against roughly stable costs, so ratios derived
	/// from it move in the direction a reader would expect rather than staying flat.
	///
	/// - Throws: `AccountError` if a fixture account is malformed.
	public static var documentationFixture: IncomeStatement<Double> {
		get throws {
			let entity = Entity.documentationFixture
			let periods = Period.documentationQuarters

			func account(_ name: String, _ role: IncomeStatementRole, _ values: [Double]) throws -> Account<Double> {
				try Account(
					entity: entity,
					name: name,
					incomeStatementRole: role,
					timeSeries: TimeSeries(periods: periods, values: values)
				)
			}

			let accounts = [
				try account("Revenue", .revenue, [1000, 1100, 1200, 1300]),
				try account("Cost of Goods Sold", .costOfGoodsSold, [600, 650, 700, 750]),
				try account("General and Administrative", .generalAndAdministrative, [200, 205, 210, 215])
			]

			return try IncomeStatement(entity: entity, periods: periods, accounts: accounts)
		}
	}
}

// MARK: - Cash flow statement

extension CashFlowStatement where T == Double {

	/// A small cash flow statement for use in doc-comment examples.
	///
	/// - Throws: `AccountError` if a fixture account is malformed.
	public static var documentationFixture: CashFlowStatement<Double> {
		get throws {
			let entity = Entity.documentationFixture
			let periods = Period.documentationQuarters

			func account(_ name: String, _ role: CashFlowRole, _ values: [Double]) throws -> Account<Double> {
				try Account(
					entity: entity,
					name: name,
					cashFlowRole: role,
					timeSeries: TimeSeries(periods: periods, values: values)
				)
			}

			let accounts = [
				try account("Net Income", .netIncome, [200, 245, 290, 335]),
				try account("Depreciation", .depreciationAmortizationAddback, [10, 10, 10, 10]),
				try account("Capital Expenditures", .capitalExpenditures, [-40, -40, -40, -40]),
				try account("Dividends Paid", .dividendsPaid, [-20, -20, -20, -20])
			]

			return try CashFlowStatement(entity: entity, periods: periods, accounts: accounts)
		}
	}
}

// MARK: - Scenario and projection

extension FinancialScenario {

	/// The scenario every projection fixture runs under.
	public static var documentationFixture: FinancialScenario {
		FinancialScenario(name: "Base Case", description: "Expected scenario")
	}
}

extension FinancialProjection {

	/// A projection over the three statement fixtures, for doc-comment examples.
	///
	/// Composed rather than hand-built, so an example that reaches through a projection
	/// to a statement sees the same numbers as one that reaches the statement directly.
	///
	/// - Throws: `AccountError` if a fixture statement is malformed.
	public static var documentationFixture: FinancialProjection {
		get throws {
			FinancialProjection(
				scenario: FinancialScenario.documentationFixture,
				incomeStatement: try IncomeStatement<Double>.documentationFixture,
				balanceSheet: try BalanceSheet<Double>.documentationFixture,
				cashFlowStatement: try CashFlowStatement<Double>.documentationFixture
			)
		}
	}
}
