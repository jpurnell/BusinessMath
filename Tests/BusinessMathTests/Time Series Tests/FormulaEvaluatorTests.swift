//
//  FormulaEvaluatorTests.swift
//  BusinessMath
//

import Testing
import Foundation
@testable import BusinessMath

/// Formulas as configuration.
///
/// The point of the type is that a derived account can be data rather than code, so the tests
/// that matter are the ones about what a formula means when the data is imperfect — because
/// configuration is written once and then run against companies whose statements do not match
/// each other.
@Suite("Formula Evaluator")
struct FormulaEvaluatorTests {

	private let months = [
		Period.month(year: 2026, month: 1),
		Period.month(year: 2026, month: 2),
		Period.month(year: 2026, month: 3)
	]

	private func evaluator(
		_ accounts: [String: [Double]] = ["revenue": [100, 200, 300], "cogs": [40, 80, 120]]
	) -> FormulaEvaluator<Double> {
		FormulaEvaluator(accounts: accounts.mapValues {
			TimeSeries(periods: Array(months.prefix($0.count)), values: $0)
		})
	}

	// MARK: - Arithmetic

	@Test("Arithmetic and precedence", arguments: [
		("revenue - cogs", [60.0, 120.0, 180.0]),
		("revenue + cogs", [140.0, 280.0, 420.0]),
		("revenue * 2", [200.0, 400.0, 600.0]),
		("revenue / 2", [50.0, 100.0, 150.0]),
		("revenue - cogs * 2", [20.0, 40.0, 60.0]),
		("(revenue - cogs) * 2", [120.0, 240.0, 360.0]),
		("-cogs + revenue", [60.0, 120.0, 180.0]),
		("revenue - (cogs - 10)", [70.0, 130.0, 190.0])
	])
	func arithmetic(formula: String, expected: [Double]) throws {
		let result = try evaluator().evaluate(formula)

		#expect(result.valuesArray == expected, "\(formula) gave \(result.valuesArray)")
	}

	@Test("Nested parentheses and whitespace are immaterial")
	func nestingAndWhitespace() throws {
		let tight = try evaluator().evaluate("((revenue-cogs)/revenue)")
		let loose = try evaluator().evaluate("  ( ( revenue - cogs ) / revenue )  ")

		#expect(tight.valuesArray == loose.valuesArray)
		#expect(tight.valuesArray == [0.6, 0.6, 0.6])
	}

	// MARK: - Names as they actually appear

	/// A chart of accounts is not a set of identifiers. Without bracketing, "Cost of Goods
	/// Sold" tokenises as three separate accounts and "A/P" as a division.
	@Test("A bracketed name may contain anything", arguments: [
		"[Total Revenue]", "[Cost of Goods Sold]", "[Sales & Marketing]", "[A/P]", "[R&D - Core]"
	])
	func bracketedNames(name: String) throws {
		let bare = String(name.dropFirst().dropLast())
		let evaluator = FormulaEvaluator(accounts: [
			bare: TimeSeries(periods: months, values: [1, 2, 3])
		])

		#expect(try evaluator.evaluate(name).valuesArray == [1, 2, 3])
	}

	@Test("Bracketed and bare names mix in one formula")
	func mixedNames() throws {
		let evaluator = FormulaEvaluator(accounts: [
			"Total Revenue": TimeSeries(periods: months, values: [100, 200, 300]),
			"cogs": TimeSeries(periods: months, values: [40, 80, 120])
		])

		#expect(try evaluator.evaluate("[Total Revenue] - cogs").valuesArray == [60, 120, 180])
	}

	@Test("A name opened with a bracket must be closed")
	func unterminatedName() {
		#expect(throws: FormulaError.unterminatedAccountName) {
			try evaluator().evaluate("[Total Revenue - cogs")
		}
	}

	// MARK: - Periods that do not line up

	/// The property the whole thing rests on, and the one the original implementation got
	/// backwards: a period missing from one side is dropped, not read as zero.
	///
	/// Zero-filling would return February's revenue as February's gross profit — a number that
	/// looks like an answer, sits in a statement, and is wrong by the whole of the cost line.
	@Test("A period missing from one account drops out rather than becoming zero")
	func missingPeriodsAreDropped() throws {
		let evaluator = FormulaEvaluator(accounts: [
			"revenue": TimeSeries(periods: months, values: [100, 200, 300]),
			// No February.
			"cogs": TimeSeries(periods: [months[0], months[2]], values: [40, 120])
		])

		let result = try evaluator.evaluate("revenue - cogs")

		#expect(result.periods == [months[0], months[2]])
		#expect(result.valuesArray == [60, 180])
		#expect(result[months[1]] == nil, "February was invented from a missing cost")
	}

	/// And it agrees with the operator, which is the reason it delegates.
	@Test("A formula equals the same expression written in Swift")
	func agreesWithTheOperators() throws {
		let revenue = TimeSeries(periods: months, values: [100, 200, 300])
		let cogs = TimeSeries(periods: [months[0], months[2]], values: [40, 120])
		let evaluator = FormulaEvaluator(accounts: ["revenue": revenue, "cogs": cogs])

		let byFormula = try evaluator.evaluate("(revenue - cogs) / revenue")
		let bySwift = (revenue - cogs) / revenue

		#expect(byFormula.periods == bySwift.periods)
		#expect(byFormula.valuesArray == bySwift.valuesArray)
	}

	/// A literal has no periods of its own, so it takes the accounts'. Without that, the
	/// intersection would empty every expression a constant touched.
	@Test("A constant spans the accounts' periods")
	func constantsSpanTheData() throws {
		let result = try evaluator().evaluate("revenue * 2 + 1")

		#expect(result.periods == months)
		#expect(result.valuesArray == [201, 401, 601])
	}

	// MARK: - Refusals

	/// An account nobody supplied is refused, not defaulted. Treating it as zero would make
	/// `revenue - cogs` return revenue and call it gross profit.
	@Test("An unknown account is refused")
	func unknownAccount() {
		#expect(throws: FormulaError.unknownAccount("opex")) {
			try evaluator().evaluate("revenue - opex")
		}
	}

	@Test("Malformed formulas are refused", arguments: [
		"revenue -", "(revenue - cogs", "revenue - cogs)", "* revenue", "revenue $ cogs"
	])
	func malformed(formula: String) {
		#expect(throws: (any Error).self) { try evaluator().evaluate(formula) }
	}

	/// Division follows the `/` operator exactly: period-wise, and a zero denominator gives a
	/// non-finite value rather than throwing. Asserted so it is a known property rather than a
	/// surprise met in a report.
	@Test("A zero denominator yields a non-finite value, as the operator does")
	func divisionByZero() throws {
		let evaluator = FormulaEvaluator(accounts: [
			"profit": TimeSeries(periods: months, values: [10, 20, 30]),
			"revenue": TimeSeries(periods: months, values: [100, 0, 300])
		])

		let result = try evaluator.evaluate("profit / revenue")

		#expect(abs(result.valuesArray[0] - 0.1) < 1e-12)
		#expect(!result.valuesArray[1].isFinite, "a zero denominator produced a usable-looking number")
		#expect(abs(result.valuesArray[2] - 0.1) < 1e-12)
	}

	// MARK: - Validating a configuration before data exists

	/// A company definition can be checked for the accounts it requires without loading any.
	@Test("The accounts a formula needs can be read without evaluating it")
	func accountNamesWithoutData() throws {
		let names = try FormulaEvaluator<Double>.accountNames(
			in: "([Total Revenue] - cogs) / [Total Revenue] + 1")

		#expect(names == ["Total Revenue", "cogs"])
	}

	@Test("Reading the names of a malformed formula still refuses")
	func accountNamesOfMalformed() {
		#expect(throws: FormulaError.unterminatedAccountName) {
			try FormulaEvaluator<Double>.accountNames(in: "[Total Revenue")
		}
	}
}
