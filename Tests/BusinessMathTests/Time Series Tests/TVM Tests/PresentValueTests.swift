//
//  PresentValueTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Present Value Tests")
struct PresentValueTests {

	let tolerance: Double = 0.01  // $0.01 tolerance for financial calculations

	// MARK: - Basic Present Value Tests

	@Test("Present value of $1000 in 1 year at 10%")
	func pvBasic() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.10, periods: 1)

		// PV = 1000 / (1 + 0.10)^1 = 909.09
		#expect(abs(pv - 909.09) < tolerance)
	}

	@Test("Present value of $1000 in 5 years at 10%")
	func pv5Years() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.10, periods: 5)

		// PV = 1000 / (1.10)^5 = 620.92
		#expect(abs(pv - 620.92) < tolerance)
	}

	@Test("Present value with zero rate equals future value")
	func pvZeroRate() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.0, periods: 5)

		#expect(abs(pv - 1000.0) < tolerance)
	}

	@Test("Present value with very small rate")
	func pvSmallRate() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.01, periods: 10)

		// PV = 1000 / (1.01)^10 = 905.29
		#expect(abs(pv - 905.29) < tolerance)
	}

	@Test("Present value with high rate")
	func pvHighRate() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.50, periods: 3)

		// PV = 1000 / (1.50)^3 = 296.30
		#expect(abs(pv - 296.30) < tolerance)
	}

	// MARK: - Present Value Annuity - Ordinary

	@Test("PV of ordinary annuity: $100/year for 5 years at 10%")
	func pvAnnuityOrdinaryBasic() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .ordinary)

		// PV = 100 * [(1 - (1.10)^-5) / 0.10] = 379.08
		#expect(abs(pv - 379.08) < tolerance)
	}

	@Test("PV of ordinary annuity: $1000/month for 12 months at 1%/month")
	func pvAnnuityOrdinaryMonthly() {
		let pv = presentValueAnnuity(payment: 1000.0, rate: 0.01, periods: 12, type: .ordinary)

		// PV = 1000 * [(1 - (1.01)^-12) / 0.01] = 11255.08
		#expect(abs(pv - 11255.08) < tolerance)
	}

	@Test("PV of ordinary annuity with zero rate")
	func pvAnnuityOrdinaryZeroRate() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.0, periods: 5, type: .ordinary)

		// With zero rate, PV = payment * periods
		#expect(abs(pv - 500.0) < tolerance)
	}

	@Test("PV of ordinary annuity: single period")
	func pvAnnuityOrdinarySinglePeriod() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 1, type: .ordinary)

		// PV = 100 / 1.10 = 90.91
		#expect(abs(pv - 90.91) < tolerance)
	}

	// MARK: - Present Value Annuity - Due

	@Test("PV of annuity due: $100/year for 5 years at 10%")
	func pvAnnuityDueBasic() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .due)

		// PV_due = PV_ordinary * (1 + rate)
		// PV = 379.08 * 1.10 = 416.99
		#expect(abs(pv - 416.99) < tolerance)
	}

	@Test("PV of annuity due: $1000/month for 12 months at 1%/month")
	func pvAnnuityDueMonthly() {
		let pv = presentValueAnnuity(payment: 1000.0, rate: 0.01, periods: 12, type: .due)

		// PV_due = 11255.08 * 1.01 = 11367.63
		#expect(abs(pv - 11367.63) < tolerance)
	}

	@Test("PV of annuity due with zero rate equals PV ordinary")
	func pvAnnuityDueZeroRate() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.0, periods: 5, type: .due)

		// With zero rate, due and ordinary are the same
		#expect(abs(pv - 500.0) < tolerance)
	}

	@Test("PV of annuity due: single period")
	func pvAnnuityDueSinglePeriod() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 1, type: .due)

		// PV = 100 (payment at beginning, no discounting)
		#expect(abs(pv - 100.0) < tolerance)
	}

	// MARK: - Comparison Tests

	@Test("Annuity due is always greater than ordinary annuity")
	func annuityDueGreaterThanOrdinary() {
		let pvOrdinary = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .ordinary)
		let pvDue = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 5, type: .due)

		#expect(pvDue > pvOrdinary)
	}

	@Test("Annuity due equals ordinary times (1 + rate)")
	func annuityDueRelationship() {
		let rate = 0.10
		let pvOrdinary = presentValueAnnuity(payment: 100.0, rate: rate, periods: 5, type: .ordinary)
		let pvDue = presentValueAnnuity(payment: 100.0, rate: rate, periods: 5, type: .due)

		#expect(abs(pvDue - (pvOrdinary * (1.0 + rate))) < tolerance)
	}

	// MARK: - Real-World Scenarios

	@Test("Car loan: $30,000 for 60 months at 5% APR")
	func carLoanScenario() {
		// What monthly payment is needed?
		// First, find what PV of $1/month annuity is
		let rate = 0.05 / 12.0  // Monthly rate
		let periods = 60

		let pvOf1PerMonth = presentValueAnnuity(payment: 1.0, rate: rate, periods: periods, type: .ordinary)

		// Payment = PV / pvOf1PerMonth
		let payment = 30000.0 / pvOf1PerMonth

		// Should be approximately $566.14/month
		#expect(abs(payment - 566.14) < tolerance)
	}

	@Test("Lottery annuity: $1M paid over 20 years at 6%")
	func lotteryAnnuityScenario() {
		// Lottery advertises $1M prize paid as $50k/year for 20 years
		// What's the present value?
		let pv = presentValueAnnuity(payment: 50000.0, rate: 0.06, periods: 20, type: .ordinary)

		// Should be approximately $573,496
		#expect(abs(pv - 573496.0) < 1.0)
	}

	@Test("Retirement income: Need $50k/year for 30 years at 4%")
	func retirementIncomeScenario() {
		// How much do you need at retirement to generate $50k/year?
		let pv = presentValueAnnuity(payment: 50000.0, rate: 0.04, periods: 30, type: .ordinary)

		// Should be approximately $864,601
		#expect(abs(pv - 864601.0) < 1.0)
	}

	@Test("Bond valuation: $1000 face value, 5% coupon, 10 years, 6% yield")
	func bondValuationScenario() {
		// Bond pays $50/year (5% of $1000) for 10 years, then $1000 at maturity
		let couponPV = presentValueAnnuity(payment: 50.0, rate: 0.06, periods: 10, type: .ordinary)
		let facePV = presentValue(futureValue: 1000.0, rate: 0.06, periods: 10)

		let bondValue = couponPV + facePV

		// Should be approximately $926.40
		#expect(abs(bondValue - 926.40) < tolerance)
	}

	// MARK: - Edge Cases

	@Test("Present value with zero future value")
	func pvZeroFutureValue() {
		let pv = presentValue(futureValue: 0.0, rate: 0.10, periods: 5)
		#expect(pv == 0.0)
	}

	@Test("Present value with zero periods")
	func pvZeroPeriods() {
		let pv = presentValue(futureValue: 1000.0, rate: 0.10, periods: 0)

		// With zero periods, PV = FV
		#expect(abs(pv - 1000.0) < tolerance)
	}

	@Test("Annuity with zero payment")
	func annuityZeroPayment() {
		let pv = presentValueAnnuity(payment: 0.0, rate: 0.10, periods: 5, type: .ordinary)
		#expect(pv == 0.0)
	}

	@Test("Annuity with zero periods")
	func annuityZeroPeriods() {
		let pv = presentValueAnnuity(payment: 100.0, rate: 0.10, periods: 0, type: .ordinary)
		#expect(pv == 0.0)
	}

	@Test("Large number of periods")
	func pvLargePeriods() {
		let pv = presentValue(futureValue: 1000000.0, rate: 0.05, periods: 100)

		// Should be a very small number
		#expect(pv < 10000.0)
		#expect(pv > 0.0)
	}

	// MARK: - Validation Tests

	@Test("Negative rate should be handled")
	func pvNegativeRate() {
		// In some scenarios (deflation), negative rates are possible
		let pv = presentValue(futureValue: 1000.0, rate: -0.02, periods: 5)

		// With negative rate, PV > FV
		#expect(pv > 1000.0)
	}
	
		// MARK: - PV/FV/NPV pathological rates

		   @Test("presentValue with rate = -1 and odd period should be undefined")
		   func pvRateNegativeOne() {
			   let pv = presentValue(futureValue: 1000.0, rate: -1.0, periods: 1)
			   #expect(pv.isNaN || pv.isInfinite)
		   }

		   @Test("npv with rate = -1 should be undefined due to zero denominators")
		   func npvRateNegativeOne() {
			   let cashFlows = [-1000.0, 500.0, 500.0]
			   let v = npv(discountRate: -1.0, cashFlows: cashFlows)
			   #expect(v.isNaN || v.isInfinite)
		   }
}
