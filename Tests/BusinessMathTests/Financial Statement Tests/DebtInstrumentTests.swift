import Testing
import TestSupport  // Cross-platform math functions
import Foundation
@testable import BusinessMath

/// Comprehensive tests for debt instruments and amortization schedules
//@Suite("Debt Instrument Tests")
struct DebtInstrumentTests {

    // MARK: - Level Payment Amortization (Equal Total Payments)

    @Test("Level payment amortization - basic calculation")
    func levelPaymentBasic() throws {
        // $100,000 loan at 6% annual for 5 years, monthly payments
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // First payment
        let firstPeriod = schedule.periods.first!
        let firstInterest = schedule.interest[firstPeriod]!
        let firstPrincipal = schedule.principal[firstPeriod]!
        let firstPayment = schedule.payment[firstPeriod]!

        // Expected monthly rate: 0.06 / 12 = 0.005
        // Expected interest: 100,000 * 0.005 = 500
        #expect(abs(firstInterest - 500.0) < 1.0)

        // Payment should be constant
        let lastPayment = schedule.payment[schedule.periods.last!]!
        #expect(abs(firstPayment - lastPayment) < 0.01)

        // Principal should increase over time
        let lastPrincipal = schedule.principal[schedule.periods.last!]!
        #expect(lastPrincipal > firstPrincipal)

        // Ending balance should be zero
        let finalBalance = schedule.endingBalance[schedule.periods.last!]!
        #expect(abs(finalBalance) < 1.0)
    }

    @Test("Level payment - payment calculation formula")
    func levelPaymentFormula() throws {
        // Validate against standard mortgage formula
        // PMT = P * [r(1+r)^n] / [(1+r)^n - 1]
        let principal = 250_000.0
        let annualRate = 0.045
        let monthlyRate = annualRate / 12.0
        let years = 30
        let numPayments = years * 12

        // Expected payment
        let expectedPayment = principal * (monthlyRate * pow(1 + monthlyRate, Double(numPayments))) /
                            (pow(1 + monthlyRate, Double(numPayments)) - 1)

        let instrument = DebtInstrument(
            principal: principal,
            interestRate: annualRate,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Calendar.current.date(byAdding: .year, value: years, to: Date(timeIntervalSince1970: 0))!,
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()
        let actualPayment = schedule.payment[schedule.periods.first!]!

        // Should match formula within $0.01
        #expect(abs(actualPayment - expectedPayment) < 0.01)
    }

    @Test("Level payment - total interest paid")
    func levelPaymentTotalInterest() throws {
        let principal = 100_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.05,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Sum all interest payments
        let totalInterest = schedule.periods.reduce(0.0) { sum, period in
            sum + schedule.interest[period]!
        }

        // Sum all principal payments should equal original principal
        let totalPrincipal = schedule.periods.reduce(0.0) { sum, period in
            sum + schedule.principal[period]!
        }

        #expect(abs(totalPrincipal - principal) < 1.0)

        // Total interest should be positive and substantial
        #expect(totalInterest > 10_000.0)
        #expect(totalInterest < 20_000.0) // Reasonable for 5% over 5 years
    }

    // MARK: - Straight Line Amortization (Equal Principal Payments)

    @Test("Straight line amortization - equal principal")
    func straightLineEqualPrincipal() throws {
        let principal = 120_000.0
        let numPayments = 12
        let expectedPrincipalPerPayment = principal / Double(numPayments)

        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 31_536_000), // ~1 year
            paymentFrequency: .monthly,
            amortizationType: .straightLine
        )

        let schedule = instrument.schedule()

        // All principal payments should be equal
        for period in schedule.periods {
            let principalPayment = schedule.principal[period]!
            #expect(abs(principalPayment - expectedPrincipalPerPayment) < 0.01)
        }
    }

    @Test("Straight line - declining interest")
    func straightLineDecliningInterest() throws {
        let instrument = DebtInstrument(
            principal: 60_000.0,
            interestRate: 0.12,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 31_536_000), // ~1 year
            paymentFrequency: .monthly,
            amortizationType: .straightLine
        )

        let schedule = instrument.schedule()

        // Interest should decline each period
        var previousInterest = Double.infinity
        for period in schedule.periods {
            let interest = schedule.interest[period]!
            #expect(interest < previousInterest)
            previousInterest = interest
        }
    }

    @Test("Straight line - declining total payment")
    func straightLineDecliningPayment() throws {
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.08,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 63_072_000), // ~2 years
            paymentFrequency: .quarterly,
            amortizationType: .straightLine
        )

        let schedule = instrument.schedule()

        // Total payment (principal + interest) should decline
        var previousPayment = Double.infinity
        for period in schedule.periods {
            let payment = schedule.payment[period]!
            #expect(payment < previousPayment)
            previousPayment = payment
        }
    }

    // MARK: - Bullet Payment (Interest Only, Principal at Maturity)

    @Test("Bullet payment - interest only during term")
    func bulletPaymentInterestOnly() throws {
        let principal = 500_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.075,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 94_608_000), // ~3 years
            paymentFrequency: .quarterly,
            amortizationType: .bulletPayment
        )

        let schedule = instrument.schedule()

        // All periods except last should have zero principal payment
        for period in schedule.periods.dropLast() {
            let principalPayment = schedule.principal[period]!
            #expect(abs(principalPayment) < 0.01)
        }

        // Last period should have full principal
        let lastPrincipalPayment = schedule.principal[schedule.periods.last!]!
        #expect(abs(lastPrincipalPayment - principal) < 1.0)
    }

    @Test("Bullet payment - constant interest payments")
    func bulletPaymentConstantInterest() throws {
        let principal = 200_000.0
        let annualRate = 0.05
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: annualRate,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 63_072_000), // ~2 years
            paymentFrequency: .semiAnnual,
            amortizationType: .bulletPayment
        )

        let schedule = instrument.schedule()

        // Expected semi-annual interest: 200,000 * 0.05 * 0.5 = 5,000
        let expectedInterest = principal * annualRate * 0.5

        // All periods except last should have same interest
        for period in schedule.periods.dropLast() {
            let interest = schedule.interest[period]!
            #expect(abs(interest - expectedInterest) < 1.0)
        }
    }

    @Test("Bullet payment - balance remains constant until maturity")
    func bulletPaymentConstantBalance() throws {
        let principal = 1_000_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.04,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .annual,
            amortizationType: .bulletPayment
        )

        let schedule = instrument.schedule()

        // Ending balance should equal principal for all periods except last
        for period in schedule.periods.dropLast() {
            let endingBalance = schedule.endingBalance[period]!
            #expect(abs(endingBalance - principal) < 1.0)
        }

        // Last period should have zero balance
        let finalBalance = schedule.endingBalance[schedule.periods.last!]!
        #expect(abs(finalBalance) < 1.0)
    }

    // MARK: - Custom Payment Schedule

    @Test("Custom amortization - specified payments")
    func customAmortizationPayments() throws {
        let customPayments = [10_000.0, 15_000.0, 20_000.0, 25_000.0, 30_000.0]
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .annual,
            amortizationType: .custom(schedule: customPayments)
        )

        let schedule = instrument.schedule()

        // Payments should match custom schedule
        for (index, period) in schedule.periods.enumerated() {
            let payment = schedule.payment[period]!
            #expect(abs(payment - customPayments[index]) < 0.01)
        }
    }

    @Test("Custom amortization - varying payments still pay off loan")
    func customAmortizationPayoff() throws {
		let customPayments = [5_000.0, 10_000.0, 15_000.0, 20_000.0, 72_500.0]
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.05,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .annual,
            amortizationType: .custom(schedule: customPayments)
        )

        let schedule = instrument.schedule()

        // Final balance should be zero (or close)
        let finalBalance = schedule.endingBalance[schedule.periods.last!]!
        #expect(abs(finalBalance) < 100.0) // Allow small rounding
    }

    // MARK: - Payment Frequency Variations

    @Test("Monthly payment frequency")
    func monthlyPaymentFrequency() throws {
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 31_536_000), // ~1 year
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Should have 12 payments
        #expect(schedule.periods.count == 12)
    }

    @Test("Quarterly payment frequency")
    func quarterlyPaymentFrequency() throws {
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 63_072_000), // ~2 years
            paymentFrequency: .quarterly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Should have 8 payments
        #expect(schedule.periods.count == 8)
    }

    @Test("Annual payment frequency")
    func annualPaymentFrequency() throws {
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .annual,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Should have 5 payments
        #expect(schedule.periods.count == 5)
    }

    // MARK: - Balance Continuity

    @Test("Balance continuity - ending equals next beginning")
    func balanceContinuity() throws {
        let instrument = DebtInstrument(
            principal: 75_000.0,
            interestRate: 0.055,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 94_608_000), // ~3 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Each ending balance should equal next beginning balance
        for i in 0..<(schedule.periods.count - 1) {
            let currentPeriod = schedule.periods[i]
            let nextPeriod = schedule.periods[i + 1]

            let endingBalance = schedule.endingBalance[currentPeriod]!
            let nextBeginningBalance = schedule.beginningBalance[nextPeriod]!

            #expect(abs(endingBalance - nextBeginningBalance) < 0.01)
        }
    }

    @Test("Balance calculation - beginning minus principal equals ending")
    func balanceCalculation() throws {
        let instrument = DebtInstrument(
            principal: 150_000.0,
            interestRate: 0.07,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 126_144_000), // ~4 years
            paymentFrequency: .quarterly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        for period in schedule.periods {
            let beginning = schedule.beginningBalance[period]!
            let principal = schedule.principal[period]!
            let ending = schedule.endingBalance[period]!

            // Ending = Beginning - Principal
            #expect(abs((beginning - principal) - ending) < 0.01)
        }
    }

    // MARK: - Interest Rate Variations

    @Test("Zero interest rate - principal only")
    func zeroInterestRate() throws {
        let principal = 100_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.0,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 126_144_000), // ~4 years
            paymentFrequency: .annual,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // All interest should be zero
        for period in schedule.periods {
            let interest = schedule.interest[period]!
            #expect(abs(interest) < 0.01)
        }

        // Principal should be evenly divided
        let expectedPrincipal = principal / Double(schedule.periods.count)
        for period in schedule.periods {
            let principalPayment = schedule.principal[period]!
            #expect(abs(principalPayment - expectedPrincipal) < 0.01)
        }
    }

    @Test("High interest rate - substantial interest component")
    func highInterestRate() throws {
        let principal = 100_000.0
        let highRate = 0.15 // 15%
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: highRate,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // First payment should be mostly interest
        let firstPeriod = schedule.periods.first!
        let firstInterest = schedule.interest[firstPeriod]!
        let firstPrincipal = schedule.principal[firstPeriod]!

        #expect(firstInterest > firstPrincipal)
    }

    // MARK: - Edge Cases

    @Test("Single payment loan")
    func singlePaymentLoan() throws {
        let principal = 50_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.05,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 31_536_000), // ~1 year
            paymentFrequency: .annual,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        #expect(schedule.periods.count == 1)

        // Single payment should include full principal plus interest
        let payment = schedule.payment[schedule.periods.first!]!
        #expect(payment > principal)
    }

    @Test("Very short term loan - 1 month")
    func veryShortTermLoan() throws {
        let principal = 10_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.12,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 2_628_000), // ~1 month
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        #expect(schedule.periods.count == 1)

        // Should pay principal + 1 month interest
        let expectedInterest = principal * 0.12 / 12.0
        let interest = schedule.interest[schedule.periods.first!]!
        #expect(abs(interest - expectedInterest) < 1.0)
    }

    @Test("Large principal - millions")
    func largePrincipal() throws {
        let principal = 10_000_000.0
        let instrument = DebtInstrument(
            principal: principal,
            interestRate: 0.04,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 315_360_000), // ~10 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Should handle large numbers without overflow
        let totalPrincipal = schedule.periods.reduce(0.0) { sum, period in
            sum + schedule.principal[period]!
        }

        #expect(abs(totalPrincipal - principal) < 10.0)
    }

    // MARK: - Effective Interest Rate

    @Test("Effective annual rate calculation")
    func effectiveAnnualRate() throws {
        let nominalRate = 0.12
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: nominalRate,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 31_536_000), // ~1 year
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let ear = instrument.effectiveAnnualRate()

        // EAR = (1 + r/n)^n - 1
        // For 12% compounded monthly: (1 + 0.12/12)^12 - 1 ≈ 0.1268
        let expectedEAR = pow(1.0 + nominalRate / 12.0, 12.0) - 1.0

        #expect(abs(ear - expectedEAR) < 0.0001)
    }

    // MARK: - Payment to Principal Ratio

    @Test("Level payment - increasing principal ratio over time")
    func levelPaymentIncreasingPrincipalRatio() throws {
        let instrument = DebtInstrument(
            principal: 100_000.0,
            interestRate: 0.06,
            startDate: Date(timeIntervalSince1970: 0),
            maturityDate: Date(timeIntervalSince1970: 315_360_000), // ~10 years
            paymentFrequency: .monthly,
            amortizationType: .levelPayment
        )

        let schedule = instrument.schedule()

        // Calculate principal ratio (principal / payment) for each period
        var previousRatio = 0.0
        for period in schedule.periods {
            let principal = schedule.principal[period]!
            let payment = schedule.payment[period]!
            let ratio = principal / payment

            // Ratio should increase over time
            #expect(ratio >= previousRatio)
            previousRatio = ratio
        }
    }
	
	@Test("Custom schedule underpays and leaves residual balance")
	func customUnderpayLeavesBalance() throws {
		let instrument = DebtInstrument(
			principal: 100_000.0,
			interestRate: 0.06,
			startDate: Date(timeIntervalSince1970: 0),
			maturityDate: Date(timeIntervalSince1970: 157_680_000), // ~5 years
			paymentFrequency: .annual,
			amortizationType: .custom(schedule: [10_000, 10_000, 10_000, 10_000, 10_000]) // too small
		)

		let schedule = instrument.schedule()
		let finalBalance = schedule.endingBalance[schedule.periods.last!]!
		#expect(finalBalance > 0, "Underpaying custom schedule should leave a positive residual balance")
	}
}
