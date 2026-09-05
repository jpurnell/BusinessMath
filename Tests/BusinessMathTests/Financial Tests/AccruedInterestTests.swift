//
//  AccruedInterestTests.swift
//  BusinessMathTests
//
//  ACCRINT, tested against Excel and against identities — and deliberately not against
//  LibreOffice.
//
//  Every other financial function in this package is verified through the generated
//  LibreOffice workbook. This one is not, because LibreOffice is wrong here in two
//  independent ways, and a committed fixture full of its values would read as reference
//  truth. See `Scripts/reference-fixtures/generate_excel_financial.py` for the record.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Accrued interest")
struct AccruedInterestTests {

	static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
		var components = DateComponents()
		components.year = year
		components.month = month
		components.day = day
		guard let date = Calendar.current.date(from: components) else {
			preconditionFailure("\(year)-\(month)-\(day) is not a date")
		}
		return date
	}

	// MARK: - Against Excel

	@Test("A month-end settlement matches the value Excel returns")
	func monthEndSettlementMatchesExcel() throws {
		// Excel's answer, obtained by hand on 2026-09-05, for the case that separates the
		// documented formula from LibreOffice's arithmetic:
		//
		//   =ACCRINT(DATE(2023,11,30), DATE(2024,11,30), DATE(2024,3,31),
		//            0.0625, 10000, 2, 0)   →  208.333333
		//
		// LibreOffice returns 210.069444 for the same call, implying a 30/360 day count
		// of 121 where its own DAYS360, YEARFRAC and COUPDAYBS all say 120. Excel's value
		// is exactly 120/180 of a semi-annual coupon on 10,000 at 6.25%, which is what
		// `par · (rate/frequency) · Σ Aᵢ/NLᵢ` gives.
		let accrued: Double = try accruedInterest(
			issue: Self.date(2023, 11, 30),
			firstInterest: Self.date(2024, 11, 30),
			settlement: Self.date(2024, 3, 31),
			rate: 0.0625, par: 10_000,
			frequency: .semiAnnual, basis: .thirty360)

		#expect(abs(accrued - 208.333333) < 1e-6, "got \(accrued), Excel gives 208.333333")

		// Stated as the fraction it is, so a future reader can check the arithmetic
		// without a spreadsheet: 120 days of a 180-day period.
		let coupon = 10_000.0 * 0.0625 / 2
		#expect(abs(accrued - coupon * 120.0 / 180.0) < 1e-9)
	}

	// MARK: - Identities, which hold for every basis

	@Test("A whole quasi-coupon period accrues one coupon — where the basis says it should")
	func wholePeriodAccruesOneCoupon() throws {
		// The obvious identity is "a full period accrues exactly one coupon", and it is
		// only true for some of the bases. Worth writing down carefully, because getting
		// it wrong the other way — forcing every basis to one — would mean forcing a bug.
		//
		// A real half-year between 30 November and 30 May is **182 actual days** against
		// a nominal 180. So:
		//
		//   30/360 and 30E/360  A is 180 by construction, NL is 180  → exactly one coupon
		//   both actual/actual  NL *is* the period's real length     → exactly one coupon
		//   actual/360          182 real days over a nominal 180     → 182/180 of a coupon
		//   actual/365          182 real days over a nominal 182.5   → 182/182.5
		//
		// Accruing more than a coupon over a coupon period is not an error: it is what
		// quoting a 360-day year against a 365-day calendar means, and it is the reason
		// money-market instruments pay what they do.
		let issue = Self.date(2023, 11, 30)
		let first = Self.date(2024, 11, 30)
		let midpoint = Self.date(2024, 5, 30)
		let par = 10_000.0, rate = 0.0625
		let coupon = par * rate / 2

		let actualDays = DayCountConvention.actual365.days(from: issue, to: midpoint)
		#expect(actualDays.isEqual(to: 182), "the period is \(actualDays) actual days")

		for basis in [DayCountConvention.thirty360, .thirty360European,
					  .actualActual, .isdaActualActual] {
			let accrued: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: midpoint,
				rate: rate, par: par, frequency: .semiAnnual, basis: basis)
			#expect(abs(accrued - coupon) < 1e-9,
				"\(basis.rawValue): one period accrued \(accrued), not \(coupon)")
		}

		let over360: Double = try accruedInterest(
			issue: issue, firstInterest: first, settlement: midpoint,
			rate: rate, par: par, frequency: .semiAnnual, basis: .actual360)
		#expect(abs(over360 - coupon * 182.0 / 180.0) < 1e-9, "got \(over360)")

		let over365: Double = try accruedInterest(
			issue: issue, firstInterest: first, settlement: midpoint,
			rate: rate, par: par, frequency: .semiAnnual, basis: .actual365)
		#expect(abs(over365 - coupon * 182.0 / 182.5) < 1e-9, "got \(over365)")

		// Two whole periods are twice one, on every basis — that part *is* universal,
		// and it is what pins the grid rather than the day count.
		for basis in DayCountConvention.allCases {
			let one: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: midpoint,
				rate: rate, par: par, frequency: .semiAnnual, basis: basis)
			let two: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: first,
				rate: rate, par: par, frequency: .semiAnnual, basis: basis)
			let second: Double = try accruedInterest(
				issue: midpoint, firstInterest: first, settlement: first,
				rate: rate, par: par, frequency: .semiAnnual, basis: basis)
			#expect(abs(one + second - two) < 1e-9,
				"\(basis.rawValue): \(one) + \(second) ≠ \(two)")
		}
	}

	@Test("Accrual is additive across a settlement in the middle")
	func accrualIsAdditive() throws {
		// Splitting the span at any date and summing must give the whole. A grid or a
		// partial-period weight that was wrong would generally break this even when the
		// whole-period identity above holds.
		let issue = Self.date(2023, 11, 30)
		let first = Self.date(2024, 11, 30)

		for basis in DayCountConvention.allCases {
			let whole: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: Self.date(2024, 8, 15),
				rate: 0.0625, par: 10_000, frequency: .semiAnnual, basis: basis)
			let firstPart: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: Self.date(2024, 3, 31),
				rate: 0.0625, par: 10_000, frequency: .semiAnnual, basis: basis)
			let secondPart: Double = try accruedInterest(
				issue: Self.date(2024, 3, 31), firstInterest: first,
				settlement: Self.date(2024, 8, 15),
				rate: 0.0625, par: 10_000, frequency: .semiAnnual, basis: basis)
			#expect(abs(firstPart + secondPart - whole) < 1e-9,
				"\(basis.rawValue): \(firstPart) + \(secondPart) ≠ \(whole)")
		}
	}

	@Test("Only actual/actual makes the answer depend on the frequency")
	func frequencyDependenceIsConfinedToActualActual() throws {
		// For a fixed year length NLᵢ is 360/f or 365/f, the f cancels, and the sum
		// collapses to par·rate·yearFraction — so the frequency cannot matter. Under
		// actual/actual each quasi-coupon period has its own real length and it can.
		//
		// This is why ACCRINT is a sum rather than one year fraction, and asserting it
		// both ways keeps that reason visible.
		let issue = Self.date(2024, 3, 1)
		let first = Self.date(2024, 8, 31)
		let settlement = Self.date(2024, 5, 1)

		for basis in [DayCountConvention.thirty360, .thirty360European, .actual360, .actual365] {
			var seen: [Double] = []
			for frequency in [PaymentFrequency.annual, .semiAnnual, .quarterly] {
				seen.append(try accruedInterest(
					issue: issue, firstInterest: first, settlement: settlement,
					rate: 0.1, par: 1_000, frequency: frequency, basis: basis))
			}
			#expect(abs(seen[0] - seen[1]) < 1e-9 && abs(seen[1] - seen[2]) < 1e-9,
				"\(basis.rawValue) should not depend on frequency, got \(seen)")

			// And it equals the collapsed form.
			let fraction: Double = basis.yearFraction(from: issue, to: settlement)
			#expect(abs(seen[0] - 1_000 * 0.1 * fraction) < 1e-9,
				"\(basis.rawValue) should equal par·rate·yearFraction")
		}
	}

	// MARK: - Rejections

	@Test("Invalid arguments are refused")
	func invalidArgumentsAreRefused() {
		let issue = Self.date(2024, 1, 1)
		let first = Self.date(2025, 1, 1)
		#expect(throws: (any Error).self) {
			let _: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: issue, rate: 0.05)
		}
		#expect(throws: (any Error).self) {
			let _: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: Self.date(2023, 1, 1), rate: 0.05)
		}
		#expect(throws: (any Error).self) {
			let _: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: Self.date(2024, 6, 1), rate: -0.01)
		}
		#expect(throws: (any Error).self) {
			let _: Double = try accruedInterest(
				issue: issue, firstInterest: first, settlement: Self.date(2024, 6, 1),
				rate: 0.05, par: 0)
		}
	}
}
