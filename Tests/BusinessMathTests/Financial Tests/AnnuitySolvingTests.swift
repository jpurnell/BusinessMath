//
//  AnnuitySolvingTests.swift
//  BusinessMathTests
//
//  RATE, NPER, PDURATION and NOMINAL, against LibreOffice Calc.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Solving the annuity — rate, term, growth and nominal rate")
struct AnnuitySolvingTests {

	static let referenceTolerance = 1e-12

	static func cases(_ function: String) throws -> [[String: Double]] {
		let fixture = try ReferenceFixture.load("excelFinancial")
		let order = try #require(fixture.functionOrder)
		let index = try #require(order.firstIndex(of: function))
		return fixture.cases.filter { $0["function"] == Double(index) }
	}

	static func annuityType(_ marker: Double) -> AnnuityType {
		marker == 1 ? .due : .ordinary
	}

	// MARK: - Against the spreadsheet

	@Test("NPER matches the spreadsheet, at both payment timings and at a zero rate")
	func numberOfPeriodsMatchesReference() throws {
		let cases = try Self.cases("NPER")
		#expect(cases.count == 8)
		for c in cases {
			let actual = try numberOfPeriods(
				rate: c["rate"] ?? 0, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let expected = c["value"] ?? 0
			#expect(abs(actual - expected) / Swift.max(abs(expected), 1) < Self.referenceTolerance,
				"NPER(rate \(c["rate"] ?? 0), type \(c["type"] ?? 0)) = \(actual), LibreOffice says \(expected)")
		}
	}

	@Test("RATE matches the spreadsheet")
	func periodicRateMatchesReference() throws {
		let cases = try Self.cases("RATE")
		#expect(cases.count == 8)
		for c in cases {
			let actual = try periodicRate(
				periods: c["nper"] ?? 1, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let expected = c["value"] ?? 0
			// A rate can legitimately be near zero, so the scale floor is a rate rather
			// than one: 1e-6 is a tenth of a basis point.
			#expect(abs(actual - expected) / Swift.max(abs(expected), 1e-6) < 1e-9,
				"RATE(n \(c["nper"] ?? 0), pmt \(c["pmt"] ?? 0), pv \(c["pv"] ?? 0), fv \(c["fv"] ?? 0)) = \(actual), LibreOffice says \(expected)")
		}
	}

	@Test("PDURATION matches the spreadsheet")
	func periodsToGrowMatchesReference() throws {
		let cases = try Self.cases("PDURATION")
		#expect(cases.count == 4)
		for c in cases {
			let actual = try periodsToGrow(
				rate: c["rate"] ?? 0, presentValue: c["pv"] ?? 1, futureValue: c["fv"] ?? 1)
			let expected = c["value"] ?? 0
			#expect(abs(actual - expected) / Swift.max(abs(expected), 1) < Self.referenceTolerance,
				"PDURATION(\(c["rate"] ?? 0), \(c["pv"] ?? 0), \(c["fv"] ?? 0)) = \(actual), LibreOffice says \(expected)")
		}
	}

	@Test("NOMINAL matches the spreadsheet")
	func nominalRateMatchesReference() throws {
		let cases = try Self.cases("NOMINAL")
		#expect(cases.count == 5)
		for c in cases {
			let actual = try nominalRate(
				effectiveRate: c["effectRate"] ?? 0, periodsPerYear: c["periodsPerYear"] ?? 1)
			let expected = c["value"] ?? 0
			#expect(abs(actual - expected) / Swift.max(abs(expected), 1e-6) < Self.referenceTolerance,
				"NOMINAL(\(c["effectRate"] ?? 0), \(c["periodsPerYear"] ?? 0)) = \(actual), LibreOffice says \(expected)")
		}
	}

	// MARK: - Identities, which need no spreadsheet

	@Test("Every solved rate and term satisfies the identity it was solved from")
	func solutionsSatisfyTheIdentity() throws {
		// The strongest check available without a reference, and independent of it: a
		// root is a root. If the residual is zero the answer is right whatever any
		// spreadsheet says.
		for c in try Self.cases("RATE") {
			let rate = try periodicRate(
				periods: c["nper"] ?? 1, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let residual = annuityResidual(
				rate: rate, periods: c["nper"] ?? 1, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let scale = Swift.max(abs(c["pv"] ?? 0), abs(c["fv"] ?? 0), 1)
			#expect(abs(residual) / scale < 1e-10,
				"rate \(rate) leaves a residual of \(residual)")
		}

		for c in try Self.cases("NPER") {
			let periods = try numberOfPeriods(
				rate: c["rate"] ?? 0, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let residual = annuityResidual(
				rate: c["rate"] ?? 0, periods: periods, payment: c["pmt"] ?? 0,
				presentValue: c["pv"] ?? 0, futureValue: c["fv"] ?? 0,
				type: Self.annuityType(c["type"] ?? 0))
			let scale = Swift.max(abs(c["pv"] ?? 0), abs(c["fv"] ?? 0), 1)
			#expect(abs(residual) / scale < 1e-10,
				"term \(periods) leaves a residual of \(residual)")
		}
	}

	@Test("RATE and the existing payment function are inverses")
	func rateInvertsPayment() throws {
		// payment() uses the magnitude convention — positive present value in, positive
		// payment out — so the sign is flipped on the way across. That flip is exactly
		// the binding the coverage proposal describes, and pinning it here means a
		// change to either convention has to be deliberate.
		for periods in [12, 60, 360] {
			for rate in [0.0025, 0.005, 0.01] {
				let pmt = payment(presentValue: 100_000, rate: rate, periods: periods)
				let recovered = try periodicRate(
					periods: Double(periods), payment: -pmt, presentValue: 100_000)
				#expect(abs(recovered - rate) < 1e-10,
					"payment of \(pmt) over \(periods) implies \(recovered), not \(rate)")
			}
		}
	}

	@Test("NOMINAL inverts the effective rate it is given")
	func nominalInvertsEffective() throws {
		// Compounding the nominal rate back up must return the effective rate it came
		// from. Derived from the definition, so no reference is involved.
		for effective in [0.01, 0.05, 0.1, 0.25, 1.0] {
			for periods in [1.0, 2.0, 12.0, 365.0] {
				let nominal = try nominalRate(effectiveRate: effective, periodsPerYear: periods)
				let recompounded = Double.pow(1 + nominal / periods, periods) - 1
				#expect(abs(recompounded - effective) < 1e-12,
					"\(effective) at \(periods) periods went to \(nominal) and back to \(recompounded)")
			}
		}
	}

	@Test("PDURATION inverts compound growth")
	func periodsToGrowInvertsCompounding() throws {
		for rate in [0.01, 0.07, 0.25] {
			for target in [1.5, 2.0, 10.0] {
				let periods = try periodsToGrow(rate: rate, presentValue: 1_000,
												futureValue: 1_000 * target)
				let grown = 1_000 * Double.pow(1 + rate, periods)
				#expect(abs(grown - 1_000 * target) / (1_000 * target) < 1e-12,
					"growing 1000 at \(rate) for \(periods) gave \(grown), wanted \(1_000 * target)")
			}
		}
	}

	// MARK: - Rejections

	@Test("Combinations with no solution are refused rather than guessed at")
	func unsolvableCombinationsAreRefused() {
		// Payments that never oppose the principal: the balance only grows, so no rate
		// above −100% balances the books.
		#expect(throws: (any Error).self) {
			_ = try periodicRate(periods: 10, payment: 100, presentValue: 1_000, futureValue: 5_000)
		}
		#expect(throws: (any Error).self) {
			_ = try periodicRate(periods: 0, payment: -100, presentValue: 1_000)
		}
		// No interest and no payment: the balance never changes, so no term reaches fv.
		#expect(throws: (any Error).self) {
			_ = try numberOfPeriods(rate: 0, payment: 0, presentValue: 1_000, futureValue: 2_000)
		}
		// Payments exactly service the interest.
		#expect(throws: (any Error).self) {
			_ = try numberOfPeriods(rate: 0.01, payment: -10, presentValue: 1_000)
		}
		for bad in [(0.0, 100.0, 200.0), (0.05, 0.0, 200.0), (0.05, 100.0, 0.0), (-0.05, 100.0, 200.0)] {
			#expect(throws: (any Error).self) {
				_ = try periodsToGrow(rate: bad.0, presentValue: bad.1, futureValue: bad.2)
			}
		}
		#expect(throws: (any Error).self) { _ = try nominalRate(effectiveRate: 0.1, periodsPerYear: 0) }
		#expect(throws: (any Error).self) { _ = try nominalRate(effectiveRate: -1.5, periodsPerYear: 12) }
	}
}
