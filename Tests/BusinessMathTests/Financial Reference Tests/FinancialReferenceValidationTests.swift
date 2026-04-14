//
//  FinancialReferenceValidationTests.swift
//  BusinessMath
//
//  Validates financial functions against published reference values
//  (Excel, textbook formulas) to ensure calculation accuracy.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Financial Reference Validation Tests")
struct FinancialReferenceValidationTests {

	@Test("NPV: rate=10%, flows=[-1000, 300, 420, 680] matches hand-calculated reference")
	func npvMatchesReference() throws {
		let cashFlows: [Double] = [-1000.0, 300.0, 420.0, 680.0]
		let rate = 0.10

		let result = npv(discountRate: rate, cashFlows: cashFlows)
		let expected = -1000.0 + 300.0 / 1.1 + 420.0 / 1.21 + 680.0 / 1.331

		#expect(abs(result - expected) < 0.01,
			"NPV \(result) should match hand-calculated \(expected)")

		let validatedResult = try calculateNPV(discountRate: rate, cashFlows: cashFlows)
		#expect(abs(validatedResult - expected) < 0.01,
			"Validated NPV \(validatedResult) should match hand-calculated \(expected)")
	}

	@Test("NPV Excel convention: npvExcel matches Excel NPV() behavior")
	func npvExcelConvention() throws {
		let cashFlows: [Double] = [-1000.0, 300.0, 420.0, 680.0]
		let rate = 0.10

		let result = npvExcel(rate: rate, cashFlows: cashFlows)
		let expected = -1000.0 / 1.1 + 300.0 / 1.21 + 420.0 / 1.331 + 680.0 / 1.4641

		#expect(abs(result - expected) < 0.01,
			"npvExcel \(result) should match Excel calculation \(expected)")
	}

	@Test("IRR: flows=[-1000, 300, 420, 680] converges to correct rate")
	func irrConverges() throws {
		let cashFlows: [Double] = [-1000.0, 300.0, 420.0, 680.0]

		let result = try irr(cashFlows: cashFlows)

		let npvAtIRR = npv(discountRate: result, cashFlows: cashFlows)
		#expect(abs(npvAtIRR) < 0.01,
			"NPV at IRR (\(result)) should be approximately zero, got \(npvAtIRR)")

		#expect(abs(result - 0.1634) < 0.01,
			"IRR \(result) should be approximately 0.1634")
	}

	@Test("IRR: simple doubling investment [-100, 200] = 100%")
	func irrSimpleDoubling() throws {
		let cashFlows: [Double] = [-100.0, 200.0]
		let result = try irr(cashFlows: cashFlows)

		#expect(abs(result - 1.0) < 0.01,
			"IRR for [-100, 200] should be 1.0 (100%), got \(result)")
	}

	@Test("Loan payment: PV=200000, rate=5%/12, n=360 matches Excel PMT")
	func loanPaymentMatchesExcel() throws {
		let pmt = payment(presentValue: 200_000.0, rate: 0.05 / 12.0, periods: 360)

		#expect(abs(pmt - 1073.64) < 0.01,
			"Monthly payment \(pmt) should be approximately 1073.64")
	}

	@Test("Loan payment: zero interest rate is PV / n")
	func loanPaymentZeroInterest() throws {
		let pmt = payment(presentValue: 12_000.0, rate: 0.0, periods: 12)

		#expect(abs(pmt - 1000.0) < 0.01,
			"Zero-interest payment \(pmt) should be exactly 1000.0")
	}

	@Test("Bond duration: higher coupon rate yields lower duration")
	func bondDurationCouponRelationship() throws {
		let calendar = Calendar.current
		let issueDate = calendar.date(from: DateComponents(year: 2020, month: 1, day: 1)) ?? Date()
		let maturityDate = calendar.date(from: DateComponents(year: 2030, month: 1, day: 1)) ?? Date()

		let lowCouponBond = Bond<Double>(
			faceValue: 1000.0, couponRate: 0.02,
			maturityDate: maturityDate, paymentFrequency: .semiAnnual, issueDate: issueDate
		)
		let highCouponBond = Bond<Double>(
			faceValue: 1000.0, couponRate: 0.08,
			maturityDate: maturityDate, paymentFrequency: .semiAnnual, issueDate: issueDate
		)

		let lowDuration = lowCouponBond.macaulayDuration(yield: 0.05, asOf: issueDate)
		let highDuration = highCouponBond.macaulayDuration(yield: 0.05, asOf: issueDate)

		#expect(lowDuration > highDuration,
			"Low coupon duration (\(lowDuration)) should exceed high coupon (\(highDuration))")
	}
}
