//
//  FutureValueTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Future Value Tests")
struct FutureValueTests {

	let tolerance: Double = 0.01  // $0.01 tolerance for financial calculations

	// MARK: - Basic Future Value Tests

	@Test("Future value of $1000 in 1 year at 10%")
	func fvBasic() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.10, periods: 1)

		// FV = 1000 * (1 + 0.10)^1 = 1100.00
		#expect(abs(fv - 1100.00) < tolerance)
	}

	@Test("Future value of $1000 in 5 years at 10%")
	func fv5Years() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.10, periods: 5)

		// FV = 1000 * (1.10)^5 = 1610.51
		#expect(abs(fv - 1610.51) < tolerance)
	}

	@Test("Future value with zero rate equals present value")
	func fvZeroRate() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.0, periods: 5)

		#expect(abs(fv - 1000.0) < tolerance)
	}

	@Test("Future value with very small rate")
	func fvSmallRate() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.01, periods: 10)

		// FV = 1000 * (1.01)^10 = 1104.62
		#expect(abs(fv - 1104.62) < tolerance)
	}

	@Test("Future value with high rate")
	func fvHighRate() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.50, periods: 3)

		// FV = 1000 * (1.50)^3 = 3375.00
		#expect(abs(fv - 3375.00) < tolerance)
	}

	// MARK: - Future Value Annuity - Ordinary

	@Test("FV of ordinary annuity: $100/year for 5 years at 10%")
	func fvAnnuityOrdinaryBasic() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .ordinary)

		// FV = 100 * [((1.10)^5 - 1) / 0.10] = 610.51
		#expect(abs(fv - 610.51) < tolerance)
	}

	@Test("FV of ordinary annuity: $1000/month for 12 months at 1%/month")
	func fvAnnuityOrdinaryMonthly() {
		let fv = futureValueAnnuity(payment: 1000.0, rate: 0.01, periods: 12, type: .ordinary)

		// FV = 1000 * [((1.01)^12 - 1) / 0.01] = 12682.50
		#expect(abs(fv - 12682.50) < tolerance)
	}

	@Test("FV of ordinary annuity with zero rate")
	func fvAnnuityOrdinaryZeroRate() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.0, periods: 5, type: .ordinary)

		// With zero rate, FV = payment * periods
		#expect(abs(fv - 500.0) < tolerance)
	}

	@Test("FV of ordinary annuity: single period")
	func fvAnnuityOrdinarySinglePeriod() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 1, type: .ordinary)

		// FV = 100 (payment at end, no growth)
		#expect(abs(fv - 100.0) < tolerance)
	}

	// MARK: - Future Value Annuity - Due

	@Test("FV of annuity due: $100/year for 5 years at 10%")
	func fvAnnuityDueBasic() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .due)

		// FV_due = FV_ordinary * (1 + rate)
		// FV = 610.51 * 1.10 = 671.56
		#expect(abs(fv - 671.56) < tolerance)
	}

	@Test("FV of annuity due: $1000/month for 12 months at 1%/month")
	func fvAnnuityDueMonthly() {
		let fv = futureValueAnnuity(payment: 1000.0, rate: 0.01, periods: 12, type: .due)

		// FV_due = 12682.50 * 1.01 = 12809.33
		#expect(abs(fv - 12809.33) < tolerance)
	}

	@Test("FV of annuity due with zero rate equals FV ordinary")
	func fvAnnuityDueZeroRate() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.0, periods: 5, type: .due)

		// With zero rate, due and ordinary are the same
		#expect(abs(fv - 500.0) < tolerance)
	}

	@Test("FV of annuity due: single period")
	func fvAnnuityDueSinglePeriod() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 1, type: .due)

		// FV = 100 * 1.10 = 110.00 (payment at beginning, grows for one period)
		#expect(abs(fv - 110.0) < tolerance)
	}

	// MARK: - Comparison Tests

	@Test("Annuity due is always greater than ordinary annuity")
	func annuityDueGreaterThanOrdinary() {
		let fvOrdinary = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .ordinary)
		let fvDue = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .due)

		#expect(fvDue > fvOrdinary)
	}

	@Test("Annuity due equals ordinary times (1 + rate)")
	func annuityDueRelationship() {
		let rate = 0.10
		let fvOrdinary = futureValueAnnuity(payment: 100.0, rate: rate, periods: 5, type: .ordinary)
		let fvDue = futureValueAnnuity(payment: 100.0, rate: rate, periods: 5, type: .due)

		#expect(abs(fvDue - (fvOrdinary * (1.0 + rate))) < tolerance)
	}

	// MARK: - Real-World Scenarios

	@Test("Savings account: $200/month for 60 months at 0.5%/month")
	func savingsAccountScenario() {
		// Monthly deposits into savings account
		let fv = futureValueAnnuity(payment: 200.0, rate: 0.005, periods: 60, type: .ordinary)

		// Should be approximately $13,954.01
		#expect(abs(fv - 13954.01) < 1.0)
	}

	@Test("401k contributions: $500/month for 30 years at 7% annual (0.583%/month)")
	func retirement401kScenario() {
		// Monthly 401k contributions
		let monthlyRate = 0.07 / 12.0
		let periods = 30 * 12
		let fv = futureValueAnnuity(payment: 500.0, rate: monthlyRate, periods: periods, type: .ordinary)

		// Should be approximately $604,890 (long-term projection, higher tolerance)
		#expect(abs(fv - 604890.0) < 6000.0)
	}

	@Test("College savings: $300/month for 18 years at 6% annual")
	func collegeSavingsScenario() {
		// Monthly contributions for child's college fund
		let monthlyRate = 0.06 / 12.0
		let periods = 18 * 12
		let fv = futureValueAnnuity(payment: 300.0, rate: monthlyRate, periods: periods, type: .ordinary)

		// Should be approximately $116,206 (long-term projection, higher tolerance)
		#expect(abs(fv - 116206.0) < 5000.0)
	}

	@Test("Lump sum investment: $10,000 for 20 years at 8%")
	func lumpSumInvestmentScenario() {
		// Single investment growing over time
		let fv = futureValue(presentValue: 10000.0, rate: 0.08, periods: 20)

		// Should be approximately $46,610
		#expect(abs(fv - 46610.0) < 1.0)
	}

	// MARK: - Reciprocal Relationship with Present Value

	@Test("FV of PV equals original FV")
	func reciprocalRelationshipBasic() {
		let originalFV = 1000.0
		let rate = 0.10
		let periods = 5

		// Calculate PV from FV
		let pv = presentValue(futureValue: originalFV, rate: rate, periods: periods)

		// Calculate FV back from PV
		let calculatedFV = futureValue(presentValue: pv, rate: rate, periods: periods)

		#expect(abs(calculatedFV - originalFV) < tolerance)
	}

	@Test("FV annuity and PV annuity are reciprocal")
	func reciprocalAnnuityRelationship() {
		let payment = 100.0
		let rate = 0.10
		let periods = 5

		// Calculate FV of annuity
		let fv = futureValueAnnuity(payment: payment, rate: rate, periods: periods, type: .ordinary)

		// Calculate PV of that FV
		let pv = presentValue(futureValue: fv, rate: rate, periods: periods)

		// This PV should equal the PV of the annuity
		let pvAnnuity = presentValueAnnuity(payment: payment, rate: rate, periods: periods, type: .ordinary)

		#expect(abs(pv - pvAnnuity) < tolerance)
	}

	// MARK: - Edge Cases

	@Test("Future value with zero present value")
	func fvZeroPresentValue() {
		let fv = futureValue(presentValue: 0.0, rate: 0.10, periods: 5)
		#expect(fv == 0.0)
	}

	@Test("Future value with zero periods")
	func fvZeroPeriods() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.10, periods: 0)

		// With zero periods, FV = PV
		#expect(abs(fv - 1000.0) < tolerance)
	}

	@Test("Annuity with zero payment")
	func annuityZeroPayment() {
		let fv = futureValueAnnuity(payment: 0.0, rate: 0.10, periods: 5, type: .ordinary)
		#expect(fv == 0.0)
	}

	@Test("Annuity with zero periods")
	func annuityZeroPeriods() {
		let fv = futureValueAnnuity(payment: 100.0, rate: 0.10, periods: 0, type: .ordinary)
		#expect(fv == 0.0)
	}

	@Test("Large number of periods")
	func fvLargePeriods() {
		let fv = futureValue(presentValue: 1000.0, rate: 0.05, periods: 100)

		// Should be a very large number
		#expect(fv > 100000.0)
		#expect(fv < 200000.0)  // 1000 * (1.05)^100 = 131,501.26
	}

	// MARK: - Validation Tests

	@Test("Negative rate should be handled")
	func fvNegativeRate() {
		// In some scenarios (deflation), negative rates are possible
		let fv = futureValue(presentValue: 1000.0, rate: -0.02, periods: 5)

		// With negative rate, FV < PV
		#expect(fv < 1000.0)
	}

	@Test("Compound growth verification")
	func compoundGrowthVerification() {
		// Verify compound interest formula
		let pv = 1000.0
		let rate = 0.10
		let periods = 5

		let fv = futureValue(presentValue: pv, rate: rate, periods: periods)

		// Manual calculation: 1000 * 1.10 * 1.10 * 1.10 * 1.10 * 1.10
		let manual = pv * 1.10 * 1.10 * 1.10 * 1.10 * 1.10

		#expect(abs(fv - manual) < tolerance)
	}
}
