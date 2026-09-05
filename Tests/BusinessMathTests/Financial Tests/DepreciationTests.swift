//
//  DepreciationTests.swift
//  BusinessMathTests
//
//  The four depreciation methods, against LibreOffice Calc.
//
//  `PROPOSAL_excel_function_coverage.md` §2.3 says these are defined by what a
//  spreadsheet computes, and asks for a workbook whose values are the oracle. That
//  workbook is `Scripts/reference-fixtures/generate_excel_financial.py`: it writes
//  formulas with no cached values, has LibreOffice evaluate them, and reads back what
//  it computed. The reference carries about fifteen significant digits, which is what
//  sets the tolerance here — not the accuracy of the implementation.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Depreciation — SLN, SYD, DDB and VDB")
struct DepreciationTests {

	/// LibreOffice writes about fifteen significant digits, so a tighter bound would be
	/// asserting precision the reference does not carry.
	static let referenceTolerance = 1e-12

	static func cases(_ function: String) throws -> [[String: Double]] {
		let fixture = try ReferenceFixture.load("excelFinancial")
		let order = try #require(fixture.functionOrder)
		let index = try #require(order.firstIndex(of: function))
		return fixture.cases.filter { $0["function"] == Double(index) }
	}

	static func assertClose(_ actual: Double, _ expected: Double, _ label: String,
							sourceLocation: SourceLocation = #_sourceLocation) {
		let scale = Swift.max(abs(expected), 1.0)
		#expect(abs(actual - expected) / scale < referenceTolerance,
			"\(label): got \(actual), LibreOffice says \(expected)",
			sourceLocation: sourceLocation)
	}

	// MARK: - Against the spreadsheet

	@Test("SLN matches the spreadsheet")
	func straightLineMatchesReference() throws {
		let cases = try Self.cases("SLN")
		#expect(cases.count == 5)
		for c in cases {
			let actual = try straightLineDepreciation(
				cost: c["cost"] ?? 0, salvage: c["salvage"] ?? 0, life: c["life"] ?? 1)
			Self.assertClose(actual, c["value"] ?? 0,
				"SLN(\(c["cost"] ?? 0), \(c["salvage"] ?? 0), \(c["life"] ?? 0))")
		}
	}

	@Test("SYD matches the spreadsheet")
	func sumOfYearsDigitsMatchesReference() throws {
		let cases = try Self.cases("SYD")
		#expect(cases.count == 16)
		for c in cases {
			let actual = try sumOfYearsDigitsDepreciation(
				cost: c["cost"] ?? 0, salvage: c["salvage"] ?? 0,
				life: c["life"] ?? 1, period: c["per"] ?? 1)
			Self.assertClose(actual, c["value"] ?? 0,
				"SYD(life \(c["life"] ?? 0), period \(c["per"] ?? 0))")
		}
	}

	@Test("DDB matches the spreadsheet, including where salvage binds")
	func decliningBalanceMatchesReference() throws {
		let cases = try Self.cases("DDB")
		#expect(cases.count == 25)
		for c in cases {
			let actual = try decliningBalanceDepreciation(
				cost: c["cost"] ?? 0, salvage: c["salvage"] ?? 0, life: c["life"] ?? 1,
				period: c["period"] ?? 1, factor: c["factor"] ?? 2)
			Self.assertClose(actual, c["value"] ?? 0,
				"DDB(salvage \(c["salvage"] ?? 0), period \(c["period"] ?? 0), factor \(c["factor"] ?? 0))")
		}
	}

	@Test("VDB matches the spreadsheet, switching and not, whole periods and fractional")
	func variableDecliningBalanceMatchesReference() throws {
		let cases = try Self.cases("VDB")
		#expect(cases.count == 15)
		for c in cases {
			let actual = try variableDecliningBalanceDepreciation(
				cost: c["cost"] ?? 0, salvage: c["salvage"] ?? 0, life: c["life"] ?? 1,
				start: c["start"] ?? 0, end: c["end"] ?? 0, factor: c["factor"] ?? 2,
				switchToStraightLine: (c["noSwitch"] ?? 0) == 0)
			Self.assertClose(actual, c["value"] ?? 0,
				"VDB([\(c["start"] ?? 0), \(c["end"] ?? 0)], noSwitch \(c["noSwitch"] ?? 0))")
		}
	}

	// MARK: - Identities, which need no spreadsheet

	@Test("Every method depreciates exactly cost minus salvage over the full life")
	func methodsAgreeOnTheTotal() throws {
		// The one thing these must agree on, and the strongest check available without
		// a reference: whatever the shape of the schedule, the area under it is the
		// depreciable amount. Plain declining balance is excluded deliberately — it
		// never quite arrives, which is the reason VDB switches at all.
		let cost = 30_000.0, salvage = 7_500.0, life = 10.0
		let depreciable = cost - salvage

		let straight = try straightLineDepreciation(cost: cost, salvage: salvage, life: life) * life
		#expect(abs(straight - depreciable) < 1e-9, "straight line totalled \(straight)")

		var digits = 0.0
		for period in 1...Int(life) {
			digits += try sumOfYearsDigitsDepreciation(
				cost: cost, salvage: salvage, life: life, period: Double(period))
		}
		#expect(abs(digits - depreciable) < 1e-9, "sum-of-years-digits totalled \(digits)")

		let variable = try variableDecliningBalanceDepreciation(
			cost: cost, salvage: salvage, life: life, start: 0, end: life)
		#expect(abs(variable - depreciable) < 1e-9, "VDB totalled \(variable)")
	}

	@Test("VDB over adjacent spans adds up to VDB over the whole")
	func variableDecliningBalanceIsAdditive() throws {
		// Additivity over a partition, including at fractional cut points. A schedule
		// that weighted a partial period wrongly would fail here even with every
		// whole-period value right.
		let cost = 10_000.0, salvage = 1_000.0, life = 5.0
		let whole = try variableDecliningBalanceDepreciation(
			cost: cost, salvage: salvage, life: life, start: 0, end: life)
		for cut in [1.0, 2.5, 3.0, 4.25] {
			let first = try variableDecliningBalanceDepreciation(
				cost: cost, salvage: salvage, life: life, start: 0, end: cut)
			let second = try variableDecliningBalanceDepreciation(
				cost: cost, salvage: salvage, life: life, start: cut, end: life)
			#expect(abs(first + second - whole) < 1e-9,
				"cut at \(cut): \(first) + \(second) ≠ \(whole)")
		}
	}

	@Test("Declining balance never takes the book value below salvage")
	func decliningBalanceRespectsSalvage() throws {
		let cost = 10_000.0
		for salvage in [0.0, 1_000.0, 5_000.0, 9_000.0, 9_999.0] {
			var accumulated = 0.0
			for period in 1...5 {
				accumulated += try decliningBalanceDepreciation(
					cost: cost, salvage: salvage, life: 5, period: Double(period))
			}
			#expect(accumulated <= cost - salvage + 1e-9,
				"salvage \(salvage): depreciated \(accumulated) of \(cost - salvage) available")
		}
	}

	@Test("A factor of one matches straight line only when salvage is zero")
	func factorOneMatchesStraightLineOnlyWithoutSalvage() throws {
		// Declining balance at factor 1 takes cost/life in the first period; straight
		// line takes (cost − salvage)/life. They agree only when salvage is zero, which
		// is worth pinning: it looks like it should hold generally and does not.
		let declining = try decliningBalanceDepreciation(
			cost: 10_000, salvage: 0, life: 5, period: 1, factor: 1)
		let straight = try straightLineDepreciation(cost: 10_000, salvage: 0, life: 5)
		#expect(abs(declining - straight) < 1e-9)

		let withSalvage = try decliningBalanceDepreciation(
			cost: 10_000, salvage: 1_000, life: 5, period: 1, factor: 1)
		let straightWithSalvage = try straightLineDepreciation(cost: 10_000, salvage: 1_000, life: 5)
		#expect(abs(withSalvage - straightWithSalvage) > 1.0,
			"with salvage the two should differ, got \(withSalvage) and \(straightWithSalvage)")
	}

	// MARK: - Rejections

	@Test("Invalid arguments are refused")
	func invalidArgumentsAreRefused() {
		#expect(throws: (any Error).self) { _ = try straightLineDepreciation(cost: 100, salvage: 0, life: 0) }
		#expect(throws: (any Error).self) { _ = try straightLineDepreciation(cost: 100, salvage: 0, life: -5) }

		// A period beyond the asset's life, which the spreadsheet also refuses.
		#expect(throws: (any Error).self) {
			_ = try sumOfYearsDigitsDepreciation(cost: 100, salvage: 0, life: 5, period: 6)
		}
		#expect(throws: (any Error).self) {
			_ = try sumOfYearsDigitsDepreciation(cost: 100, salvage: 0, life: 5, period: 0)
		}
		#expect(throws: (any Error).self) {
			_ = try decliningBalanceDepreciation(cost: 100, salvage: 0, life: 5, period: 0.5)
		}
		#expect(throws: (any Error).self) {
			_ = try decliningBalanceDepreciation(cost: 100, salvage: 0, life: 5, period: 1, factor: 0)
		}
		#expect(throws: (any Error).self) {
			_ = try variableDecliningBalanceDepreciation(
				cost: 100, salvage: 0, life: 5, start: 3, end: 1)
		}
		#expect(throws: (any Error).self) {
			_ = try variableDecliningBalanceDepreciation(
				cost: 100, salvage: 0, life: 5, start: -1, end: 1)
		}
	}
}
