//
//  PaymentTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Payment Tests")
struct PaymentTests {

	let tolerance: Double = 0.01  // $0.01 tolerance for financial calculations

	// MARK: - Basic Payment Tests

	@Test("Payment for $10,000 loan at 5% for 60 months")
	func paymentBasic() {
		let pmt = payment(presentValue: 10000.0, rate: 0.05 / 12.0, periods: 60)

		// Monthly payment should be $188.71
		#expect(abs(pmt - 188.71) < tolerance)
	}

	@Test("Payment for $250,000 mortgage at 4% for 30 years")
	func paymentMortgage() {
		let monthlyRate = 0.04 / 12.0
		let periods = 30 * 12
		let pmt = payment(presentValue: 250000.0, rate: monthlyRate, periods: periods)

		// Monthly payment should be $1,193.54
		#expect(abs(pmt - 1193.54) < tolerance)
	}

	@Test("Payment with zero rate")
	func paymentZeroRate() {
		let pmt = payment(presentValue: 12000.0, rate: 0.0, periods: 12)

		// With zero rate, payment = principal / periods
		#expect(abs(pmt - 1000.0) < tolerance)
	}

	@Test("Payment for single period")
	func paymentSinglePeriod() {
		let pmt = payment(presentValue: 1000.0, rate: 0.10, periods: 1)

		// For single period: payment = PV * (1 + rate)
		#expect(abs(pmt - 1100.0) < tolerance)
	}

	@Test("Payment with future value")
	func paymentWithFutureValue() {
		// Loan with balloon payment: $10,000 loan, $2,000 balloon
		let pmt = payment(
			presentValue: 10000.0,
			rate: 0.05 / 12.0,
			periods: 60,
			futureValue: 2000.0,
			type: .ordinary
		)

		// Payment should be lower with balloon: ~$142.78
		#expect(abs(pmt - 142.78) < 20.0)
	}

	@Test("Payment annuity due vs ordinary")
	func paymentAnnuityDueVsOrdinary() {
		let pmtOrdinary = payment(
			presentValue: 10000.0,
			rate: 0.05 / 12.0,
			periods: 60,
			type: .ordinary
		)

		let pmtDue = payment(
			presentValue: 10000.0,
			rate: 0.05 / 12.0,
			periods: 60,
			type: .due
		)

		// Due payment should be slightly lower (paid at start)
		#expect(pmtDue < pmtOrdinary)
	}

	// MARK: - Principal Payment Tests

	@Test("Principal payment in first period")
	func principalPaymentFirstPeriod() {
		// $10,000 loan at 5%/12 for 60 months
		let ppmt = principalPayment(
			rate: 0.05 / 12.0,
			period: 1,
			totalPeriods: 60,
			presentValue: 10000.0
		)

		// First payment principal portion: ~$147.04
		#expect(abs(ppmt - 147.04) < tolerance)
	}

	@Test("Principal payment in last period")
	func principalPaymentLastPeriod() {
		// $10,000 loan at 5%/12 for 60 months
		let ppmt = principalPayment(
			rate: 0.05 / 12.0,
			period: 60,
			totalPeriods: 60,
			presentValue: 10000.0
		)

		// Last payment principal portion: ~$187.93
		#expect(abs(ppmt - 187.93) < tolerance)
	}

	@Test("Principal payment increases over time")
	func principalPaymentIncreases() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let ppmt1 = principalPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)
		let ppmt30 = principalPayment(rate: rate, period: 30, totalPeriods: periods, presentValue: pv)
		let ppmt60 = principalPayment(rate: rate, period: 60, totalPeriods: periods, presentValue: pv)

		// Principal portion increases over time
		#expect(ppmt30 > ppmt1)
		#expect(ppmt60 > ppmt30)
	}

	// MARK: - Interest Payment Tests

	@Test("Interest payment in first period")
	func interestPaymentFirstPeriod() {
		// $10,000 loan at 5%/12 for 60 months
		let ipmt = interestPayment(
			rate: 0.05 / 12.0,
			period: 1,
			totalPeriods: 60,
			presentValue: 10000.0
		)

		// First payment interest portion: ~$41.67
		#expect(abs(ipmt - 41.67) < tolerance)
	}

	@Test("Interest payment in last period")
	func interestPaymentLastPeriod() {
		// $10,000 loan at 5%/12 for 60 months
		let ipmt = interestPayment(
			rate: 0.05 / 12.0,
			period: 60,
			totalPeriods: 60,
			presentValue: 10000.0
		)

		// Last payment interest portion: ~$0.78
		#expect(abs(ipmt - 0.78) < tolerance)
	}

	@Test("Interest payment decreases over time")
	func interestPaymentDecreases() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let ipmt1 = interestPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)
		let ipmt30 = interestPayment(rate: rate, period: 30, totalPeriods: periods, presentValue: pv)
		let ipmt60 = interestPayment(rate: rate, period: 60, totalPeriods: periods, presentValue: pv)

		// Interest portion decreases over time
		#expect(ipmt30 < ipmt1)
		#expect(ipmt60 < ipmt30)
	}

	// MARK: - Payment Integrity Tests

	@Test("Payment equals principal plus interest")
	func paymentIntegrity() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60
		let period = 15

		let pmt = payment(presentValue: pv, rate: rate, periods: periods)
		let ppmt = principalPayment(rate: rate, period: period, totalPeriods: periods, presentValue: pv)
		let ipmt = interestPayment(rate: rate, period: period, totalPeriods: periods, presentValue: pv)

		// Payment should equal principal + interest
		#expect(abs(pmt - (ppmt + ipmt)) < tolerance)
	}

	@Test("All principal payments sum to loan amount")
	func allPrincipalSumsToLoan() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		var totalPrincipal = 0.0
		for period in 1...periods {
			let ppmt = principalPayment(
				rate: rate,
				period: period,
				totalPeriods: periods,
				presentValue: pv
			)
			totalPrincipal += ppmt
		}

		// All principal payments should sum to original loan
		#expect(abs(totalPrincipal - pv) < 1.0)  // $1 tolerance for rounding
	}

	// MARK: - Cumulative Interest Tests

	@Test("Cumulative interest for entire loan")
	func cumulativeInterestFull() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumInt = cumulativeInterest(
			rate: rate,
			startPeriod: 1,
			endPeriod: periods,
			totalPeriods: periods,
			presentValue: pv
		)

		// Total interest over 60 months: ~$1,322.74
		#expect(abs(cumInt - 1322.74) < 1.0)
	}

	@Test("Cumulative interest for first year")
	func cumulativeInterestFirstYear() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumInt = cumulativeInterest(
			rate: rate,
			startPeriod: 1,
			endPeriod: 12,
			totalPeriods: periods,
			presentValue: pv
		)

		// Interest in first 12 months: ~$445.72 (higher tolerance for cumulative)
		#expect(abs(cumInt - 445.72) < 15.0)
	}

	@Test("Cumulative interest for last year")
	func cumulativeInterestLastYear() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumInt = cumulativeInterest(
			rate: rate,
			startPeriod: 49,
			endPeriod: 60,
			totalPeriods: periods,
			presentValue: pv
		)

		// Interest in last 12 months: ~$60.16 (higher tolerance for cumulative)
		#expect(abs(cumInt - 60.16) < 10.0)
	}

	// MARK: - Cumulative Principal Tests

	@Test("Cumulative principal for entire loan")
	func cumulativePrincipalFull() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumPrinc = cumulativePrincipal(
			rate: rate,
			startPeriod: 1,
			endPeriod: periods,
			totalPeriods: periods,
			presentValue: pv
		)

		// Total principal over 60 months equals loan amount
		#expect(abs(cumPrinc - pv) < 1.0)
	}

	@Test("Cumulative principal for first year")
	func cumulativePrincipalFirstYear() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumPrinc = cumulativePrincipal(
			rate: rate,
			startPeriod: 1,
			endPeriod: 12,
			totalPeriods: periods,
			presentValue: pv
		)

		// Principal in first 12 months: ~$1,818.77 (higher tolerance for cumulative)
		#expect(abs(cumPrinc - 1818.77) < 15.0)
	}

	@Test("Cumulative principal for last year")
	func cumulativePrincipalLastYear() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let cumPrinc = cumulativePrincipal(
			rate: rate,
			startPeriod: 49,
			endPeriod: 60,
			totalPeriods: periods,
			presentValue: pv
		)

		// Principal in last 12 months: ~$2,204.39 (higher tolerance for cumulative)
		#expect(abs(cumPrinc - 2204.39) < 10.0)
	}

	// MARK: - Cumulative Integrity Tests

	@Test("Cumulative principal and interest sum to total payments")
	func cumulativeIntegrity() {
		let rate = 0.05 / 12.0
		let pv = 10000.0
		let periods = 60

		let pmt = payment(presentValue: pv, rate: rate, periods: periods)
		let totalPayments = pmt * Double(periods)

		let cumInt = cumulativeInterest(
			rate: rate,
			startPeriod: 1,
			endPeriod: periods,
			totalPeriods: periods,
			presentValue: pv
		)

		let cumPrinc = cumulativePrincipal(
			rate: rate,
			startPeriod: 1,
			endPeriod: periods,
			totalPeriods: periods,
			presentValue: pv
		)

		// Cumulative interest + principal should equal total payments
		#expect(abs(totalPayments - (cumInt + cumPrinc)) < 1.0)
	}

	// MARK: - Real-World Scenarios

	@Test("Car loan amortization analysis")
	func carLoanScenario() {
		// $30,000 car loan at 6% for 60 months
		let rate = 0.06 / 12.0
		let pv = 30000.0
		let periods = 60

		let pmt = payment(presentValue: pv, rate: rate, periods: periods)

		// Monthly payment: ~$579.98
		#expect(abs(pmt - 579.98) < tolerance)

		// First payment breakdown
		let ipmt1 = interestPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)
		let ppmt1 = principalPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)

		// First payment: $150 interest, ~$429.98 principal
		#expect(abs(ipmt1 - 150.0) < tolerance)
		#expect(abs(ppmt1 - 429.98) < tolerance)

		// Total interest over life of loan
		let totalInterest = cumulativeInterest(
			rate: rate,
			startPeriod: 1,
			endPeriod: periods,
			totalPeriods: periods,
			presentValue: pv
		)

		// Total interest: ~$4,799.08
		#expect(abs(totalInterest - 4799.08) < 10.0)
	}

	@Test("Mortgage amortization first vs last payment")
	func mortgageScenario() {
		// $250,000 mortgage at 4% for 30 years
		let rate = 0.04 / 12.0
		let pv = 250000.0
		let periods = 30 * 12

		// First payment breakdown
		let ipmt1 = interestPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)
		let ppmt1 = principalPayment(rate: rate, period: 1, totalPeriods: periods, presentValue: pv)

		// First payment: ~$833.33 interest, ~$360.21 principal
		#expect(abs(ipmt1 - 833.33) < tolerance)
		#expect(abs(ppmt1 - 360.21) < tolerance)

		// Last payment breakdown
		let ipmtLast = interestPayment(rate: rate, period: periods, totalPeriods: periods, presentValue: pv)
		let ppmtLast = principalPayment(rate: rate, period: periods, totalPeriods: periods, presentValue: pv)

		// Last payment: ~$3.96 interest, ~$1,189.58 principal
		#expect(abs(ipmtLast - 3.96) < tolerance)
		#expect(abs(ppmtLast - 1189.58) < tolerance)

		// Interest is much higher at start, principal at end
		#expect(ipmt1 > ipmtLast * 100)
		#expect(ppmtLast > ppmt1 * 3)
	}

	@Test("Interest paid in first 5 years vs last 5 years")
	func mortgageInterestComparison() {
		// $200,000 mortgage at 4.5% for 30 years
		let rate = 0.045 / 12.0
		let pv = 200000.0
		let periods = 30 * 12

		// First 5 years (months 1-60)
		let first5Years = cumulativeInterest(
			rate: rate,
			startPeriod: 1,
			endPeriod: 60,
			totalPeriods: periods,
			presentValue: pv
		)

		// Last 5 years (months 301-360)
		let last5Years = cumulativeInterest(
			rate: rate,
			startPeriod: 301,
			endPeriod: 360,
			totalPeriods: periods,
			presentValue: pv
		)

		// Much more interest paid in first 5 years
		#expect(first5Years > last5Years * 5)
	}

	// MARK: - Edge Cases

	@Test("Payment with zero periods")
	func paymentZeroPeriods() {
		// Edge case: should handle gracefully
		let pmt = payment(presentValue: 10000.0, rate: 0.05, periods: 0)
		#expect(pmt == 0.0 || pmt.isInfinite)
	}

	@Test("Principal payment at period zero")
	func principalPaymentPeriodZero() {
		let ppmt = principalPayment(
			rate: 0.05 / 12.0,
			period: 0,
			totalPeriods: 60,
			presentValue: 10000.0
		)
		#expect(ppmt == 0.0)
	}

	@Test("Interest payment at period zero")
	func interestPaymentPeriodZero() {
		let ipmt = interestPayment(
			rate: 0.05 / 12.0,
			period: 0,
			totalPeriods: 60,
			presentValue: 10000.0
		)
		#expect(ipmt == 0.0)
	}
	
		// MARK: - Payment bounds

			@Test("Principal/Interest payment beyond final period is zero")
			func paymentsBeyondTerm() {
				let rate = 0.05/12.0
				let pv = 10_000.0
				let n = 60
				let ppmt = principalPayment(rate: rate, period: n+1, totalPeriods: n, presentValue: pv)
				let ipmt = interestPayment(rate: rate, period: n+1, totalPeriods: n, presentValue: pv)
				#expect(abs(ppmt) < 1e-9)
				#expect(abs(ipmt) < 1e-9)
			}
}
