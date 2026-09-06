//
//  CashFlowParityTests.swift
//  BusinessMathTests
//
//  XNPV, XIRR, MIRR, CUMIPMT and CUMPRINC — functions this package already had, against
//  a spreadsheet for the first time.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Cash-flow parity — XNPV, XIRR, MIRR, CUMIPMT, CUMPRINC")
struct CashFlowParityTests {

	static let tolerance = 1e-12

	static func cases(_ function: String) throws -> [[String: Double]] {
		let fixture = try ReferenceFixture.load("excelFinancial")
		let order = try #require(fixture.functionOrder)
		let index = try #require(order.firstIndex(of: function))
		return fixture.cases.filter { $0["function"] == Double(index) }
	}

	/// The irregular schedule the XNPV and XIRR cases were generated against.
	static let schedule: [(year: Int, month: Int, day: Int)] = [
		(2024, 1, 1), (2024, 3, 15), (2024, 7, 1), (2025, 1, 10), (2026, 2, 28)
	]
	static let flows: [Double] = [-10_000, 2_750, 4_250, 3_250, 2_950]

	static func dates() -> [Date] {
		schedule.map {
			var components = DateComponents()
			components.year = $0.year
			components.month = $0.month
			components.day = $0.day
			guard let date = Calendar.current.date(from: components) else {
				preconditionFailure("bad date")
			}
			return date
		}
	}

	static func check(_ actual: Double, _ expected: Double, _ label: String,
					  tolerance: Double = tolerance,
					  sourceLocation: SourceLocation = #_sourceLocation) {
		let scale = Swift.max(abs(expected), 1.0)
		#expect(abs(actual - expected) / scale < tolerance,
			"\(label): ours \(actual), spreadsheet \(expected), relative \(abs(actual - expected) / scale)",
			sourceLocation: sourceLocation)
	}

	@Test("XNPV matches the spreadsheet")
	func xnpvMatchesReference() throws {
		let cases = try Self.cases("XNPV")
		#expect(cases.count == 3)
		for c in cases {
			let actual: Double = try xnpv(rate: c["rate"] ?? 0, dates: Self.dates(),
										  cashFlows: Self.flows)
			Self.check(actual, c["value"] ?? 0, "XNPV(\(c["rate"] ?? 0))")
		}
	}

	@Test("XIRR matches the spreadsheet")
	func xirrMatchesReference() throws {
		let cases = try Self.cases("XIRR")
		#expect(cases.count == 1)
		let actual: Double = try xirr(dates: Self.dates(), cashFlows: Self.flows)
		// A rate, so the scale floor is a rate rather than one.
		let expected = cases[0]["value"] ?? 0
		#expect(abs(actual - expected) / Swift.max(abs(expected), 1e-6) < 1e-9,
			"XIRR: ours \(actual), spreadsheet \(expected)")
	}

	@Test("MIRR matches the spreadsheet")
	func mirrMatchesReference() throws {
		let cases = try Self.cases("MIRR")
		#expect(cases.count == 3)
		for c in cases {
			let actual: Double = try mirr(cashFlows: Self.flows,
										  financeRate: c["financeRate"] ?? 0,
										  reinvestmentRate: c["reinvestRate"] ?? 0)
			let expected = c["value"] ?? 0
			#expect(abs(actual - expected) / Swift.max(abs(expected), 1e-6) < 1e-9,
				"MIRR(\(c["financeRate"] ?? 0), \(c["reinvestRate"] ?? 0)): ours \(actual), spreadsheet \(expected)")
		}
	}

	@Test("CUMIPMT and CUMPRINC match the spreadsheet")
	func cumulativePaymentsMatchReference() throws {
		// Excel returns these negative — money leaving the borrower. This package
		// returns magnitudes, the same convention `payment()` uses, so the comparison
		// takes the absolute value and the sign difference is stated rather than
		// silently absorbed.
		let interestCases = try Self.cases("CUMIPMT")
		let principalCases = try Self.cases("CUMPRINC")
		#expect(interestCases.count == 8, "the fixture supplied \(interestCases.count) CUMIPMT cases")
		#expect(principalCases.count == 8, "the fixture supplied \(principalCases.count) CUMPRINC cases")

		for c in interestCases {
			let actual: Double = cumulativeInterest(
				rate: c["rate"] ?? 0, startPeriod: Int(c["start"] ?? 1),
				endPeriod: Int(c["end"] ?? 1), totalPeriods: Int(c["nper"] ?? 1),
				presentValue: c["pv"] ?? 0,
				type: (c["type"] ?? 0) == 1 ? .due : .ordinary)
			Self.check(abs(actual), abs(c["value"] ?? 0),
				"CUMIPMT(\(Int(c["start"] ?? 0))…\(Int(c["end"] ?? 0)), type \(Int(c["type"] ?? 0)))")
		}
		for c in principalCases {
			let actual: Double = cumulativePrincipal(
				rate: c["rate"] ?? 0, startPeriod: Int(c["start"] ?? 1),
				endPeriod: Int(c["end"] ?? 1), totalPeriods: Int(c["nper"] ?? 1),
				presentValue: c["pv"] ?? 0,
				type: (c["type"] ?? 0) == 1 ? .due : .ordinary)
			Self.check(abs(actual), abs(c["value"] ?? 0),
				"CUMPRINC(\(Int(c["start"] ?? 0))…\(Int(c["end"] ?? 0)), type \(Int(c["type"] ?? 0)))")
		}
	}
}
