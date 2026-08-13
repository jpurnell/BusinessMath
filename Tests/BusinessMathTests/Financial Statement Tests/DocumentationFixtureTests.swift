//
//  DocumentationFixtureTests.swift
//
//  The documentation fixtures are used by doc-comment examples across the Financial
//  Statements area, and those examples are compiled but never *run* by `doc-comment-code`.
//  A fixture that throws, or that quietly does not balance, would therefore pass the
//  checker while teaching something false. These tests are what makes them trustworthy.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Documentation Fixtures")
struct DocumentationFixtureTests {

	@Test("The entity and period axis are well formed")
	func entityAndPeriods() {
		let entity = Entity.documentationFixture
		#expect(!entity.id.isEmpty, "examples print the entity; it needs an identifier")
		#expect(!entity.name.isEmpty)

		let quarters = Period.documentationQuarters
		#expect(quarters.count == 4, "examples index q1…q4, got \(quarters.count) periods")
		#expect(quarters[0] < quarters[3], "periods must be in chronological order")
	}

	@Test("Every fixture constructs without throwing")
	func fixturesConstruct() throws {
		_ = try BalanceSheet<Double>.documentationFixture
		_ = try IncomeStatement<Double>.documentationFixture
		_ = try CashFlowStatement<Double>.documentationFixture
	}

	/// The accounting identity, per period. An unbalanced balance sheet in a doc example
	/// would be worse than no example.
	@Test("The balance sheet balances in every period")
	func balanceSheetBalances() throws {
		let sheet = try BalanceSheet<Double>.documentationFixture

		for period in Period.documentationQuarters {
			let assets = sheet.totalAssets[period] ?? 0
            let liabilities = sheet.totalLiabilities[period] ?? 0
            let equity = sheet.totalEquity[period] ?? 0

			#expect(
				abs(assets - (liabilities + equity)) < 1e-9,
				"assets \(assets) != liabilities \(liabilities) + equity \(equity) in \(period)"
			)
			#expect(assets > 0, "a fixture of all zeroes would satisfy the identity and teach nothing")
		}
	}

	@Test("The income statement has revenue that moves")
	func incomeStatementIsUseful() throws {
		let statement = try IncomeStatement<Double>.documentationFixture
		let quarters = Period.documentationQuarters

		let first = statement.totalRevenue[quarters[0]] ?? 0
		let last = statement.totalRevenue[quarters[3]] ?? 0

		#expect(first > 0, "examples derive margins from revenue; it cannot be zero")
		#expect(last > first, "revenue should move across periods so derived ratios are not flat")
	}

	/// The projection is composed from the three statement fixtures, so a reader who
	/// reaches a statement through it must see the same numbers as one who reaches the
	/// statement directly. Two fixtures that disagreed would make two examples about the
	/// same company print different figures.
	@Test("The projection agrees with the statements it is composed from")
	func projectionIsConsistent() throws {
		let projection = try FinancialProjection.documentationFixture
		let balanceSheet = try BalanceSheet<Double>.documentationFixture
		let period = Period.documentationQuarters[0]

		#expect(
			projection.balanceSheet.totalAssets[period] == balanceSheet.totalAssets[period],
			"the projection's balance sheet must be the balance sheet fixture"
		)
		#expect(projection.scenario.name == FinancialScenario.documentationFixture.name)
	}

	/// Examples call `percentile(0.10)` and `percentile(0.90)` on this and print both.
	/// A simulation of identical projections would answer both calls happily with the
	/// same number, which is the one thing a distribution example must not demonstrate.
	@Test("The simulation fixture has a distribution, not a constant")
	func simulationSpreads() throws {
		let simulation = try FinancialSimulation.documentationFixture
		let q1 = Period.documentationQuarters[0]

		#expect(simulation.iterations > 1, "one projection cannot show a distribution")

		let p10 = simulation.percentile(0.10) { $0.incomeStatement.netIncome[q1] ?? 0 }
		let p50 = simulation.percentile(0.50) { $0.incomeStatement.netIncome[q1] ?? 0 }
		let p90 = simulation.percentile(0.90) { $0.incomeStatement.netIncome[q1] ?? 0 }

		#expect(p10 < p50, "10th percentile \(p10) should sit below the median \(p50)")
		#expect(p50 < p90, "median \(p50) should sit below the 90th percentile \(p90)")
	}

	/// These are values, and examples that print them should print the same thing every
	/// time they are read.
	@Test("Fixtures are stable across accesses")
	func fixturesAreStable() throws {
		let first = try BalanceSheet<Double>.documentationFixture
		let second = try BalanceSheet<Double>.documentationFixture
		let period = Period.documentationQuarters[0]

		#expect(first.totalAssets[period] == second.totalAssets[period])
	}
}
