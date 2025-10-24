import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for lease accounting under IFRS 16 / ASC 842
@Suite("Lease Accounting Tests")
struct LeaseAccountingTests {

    // MARK: - Right-of-Use Asset Calculation

    @Test("Right-of-use asset - basic calculation")
    func rightOfUseAssetBasic() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3] // 4 quarters

        let payments = TimeSeries(
            periods: periods,
            values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.06,
        )

        let rouAsset = lease.rightOfUseAsset()

        // Present value of 4 payments of $25,000 at 6% annual (1.5% quarterly)
        // PV = 25,000 * [(1 - (1.015)^-4) / 0.015]
        // ≈ 96,454
        #expect(rouAsset > 95_000.0)
        #expect(rouAsset < 97_000.0)
    }

    @Test("Right-of-use asset with initial direct costs")
    func rightOfUseAssetWithInitialCosts() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [10_000.0, 10_000.0, 10_000.0, 10_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.08,
            startDate: q1.startDate,
            initialDirectCosts: 5_000.0
        )

        let rouAsset = lease.rightOfUseAsset()

        // PV of payments + initial direct costs
        let pvPayments = lease.presentValueOfPayments()
        let expectedROU = pvPayments + 5_000.0

        #expect(abs(rouAsset - expectedROU) < 1.0)
    }

    @Test("Right-of-use asset with prepayments")
    func rightOfUseAssetWithPrepayments() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [20_000.0, 20_000.0, 20_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.05,
            startDate: q1.startDate,
            prepaidAmount: 10_000.0
        )

        let rouAsset = lease.rightOfUseAsset()

        // ROU = PV of payments + prepayments
        let pvPayments = lease.presentValueOfPayments()
        let expectedROU = pvPayments + 10_000.0

        #expect(abs(rouAsset - expectedROU) < 1.0)
    }

    // MARK: - Lease Liability Calculation

    @Test("Lease liability - initial recognition")
    func leaseLiabilityInitial() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3, q1 + 4]

        let payments = TimeSeries(
            periods: periods,
            values: [50_000.0, 50_000.0, 50_000.0, 50_000.0, 50_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.07
		)

        let liabilitySchedule = lease.liabilitySchedule()

        // Initial liability = PV of all payments
        let initialLiability = liabilitySchedule[q1]!
        let expectedPV = lease.presentValueOfPayments()

        #expect(abs(initialLiability - expectedPV) < 10.0)
    }

    @Test("Lease liability - amortization over time")
    func leaseLiabilityAmortization() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [30_000.0, 30_000.0, 30_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.08
		)

        let liabilitySchedule = lease.liabilitySchedule()

        // Liability should decrease each period
        let liability1 = liabilitySchedule[q1]!
        let liability2 = liabilitySchedule[q1 + 1]!
        let liability3 = liabilitySchedule[q1 + 2]!

        #expect(liability1 > liability2)
        #expect(liability2 > liability3)
        #expect(abs(liability3) < 100.0) // Nearly zero at end
    }

    // MARK: - Interest Expense Calculation

    @Test("Interest expense - first period")
    func interestExpenseFirstPeriod() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.08 // 8% annual
        )

        let interestExpense = lease.interestExpense(period: q1)

        // Interest = Opening liability * discount rate * time
        // Quarterly rate = 0.08 / 4 = 0.02
        let openingLiability = lease.rightOfUseAsset()
        let expectedInterest = openingLiability * 0.02

        #expect(abs(interestExpense - expectedInterest) < 50.0)
    }

    @Test("Interest expense - declining over time")
    func interestExpenseDeclining() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.10
        )

        let interest1 = lease.interestExpense(period: q1)
        let interest2 = lease.interestExpense(period: q1 + 1)
        let interest3 = lease.interestExpense(period: q1 + 2)
        let interest4 = lease.interestExpense(period: q1 + 3)

        // Interest should decline as liability reduces
        #expect(interest1 > interest2)
        #expect(interest2 > interest3)
        #expect(interest3 > interest4)
    }

    // MARK: - Principal Reduction

    @Test("Principal reduction per period")
    func principalReduction() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1]

        let payments = TimeSeries(
            periods: periods,
            values: [50_000.0, 50_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.06
        )

        let payment = payments[q1]!
        let interest = lease.interestExpense(period: q1)
        let principal = lease.principalReduction(period: q1)

        // Principal = Payment - Interest
        let expectedPrincipal = payment - interest
        #expect(abs(principal - expectedPrincipal) < 1.0)
    }

    @Test("Principal increasing over time")
    func principalIncreasing() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [30_000.0, 30_000.0, 30_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.08
		)

        let principal1 = lease.principalReduction(period: q1)
        let principal2 = lease.principalReduction(period: q1 + 1)
        let principal3 = lease.principalReduction(period: q1 + 2)

        // Principal portion should increase as interest decreases
        #expect(principal1 < principal2)
        #expect(principal2 < principal3)
    }

    // MARK: - Payment + Interest = Total Check

    @Test("Payment breakdown - principal plus interest")
    func paymentBreakdown() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [40_000.0, 40_000.0, 40_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.09
        )

        for period in periods {
            let payment = payments[period]!
            let interest = lease.interestExpense(period: period)
            let principal = lease.principalReduction(period: period)

            // Payment = Interest + Principal
            #expect(abs((interest + principal) - payment) < 1.0)
        }
    }

    // MARK: - Depreciation of ROU Asset

    @Test("ROU asset depreciation - straight line")
    func rouAssetDepreciationStraightLine() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.06,
            startDate: q1.startDate,
            depreciationMethod: .straightLine
        )

        let rouAsset = lease.rightOfUseAsset()
        let depreciation = lease.depreciation(period: q1)

        // Straight line: ROU Asset / 4 periods
        let expectedDepreciation = rouAsset / Double(periods.count)

        #expect(abs(depreciation - expectedDepreciation) < 1.0)
    }

    @Test("ROU asset carrying value over time")
    func rouAssetCarryingValue() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [30_000.0, 30_000.0, 30_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.07,
            startDate: q1.startDate,
            depreciationMethod: .straightLine
        )

        let carryingValue1 = lease.carryingValue(period: q1)
        let carryingValue2 = lease.carryingValue(period: q1 + 1)
        let carryingValue3 = lease.carryingValue(period: q1 + 2)

        // Carrying value should decline
        #expect(carryingValue1 > carryingValue2)
        #expect(carryingValue2 > carryingValue3)
        #expect(abs(carryingValue3) < 100.0) // Nearly zero at end
    }

    // MARK: - Variable Payments

    @Test("Lease with variable payments")
    func leaseWithVariablePayments() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        // Fixed payments
        let fixedPayments = TimeSeries(
            periods: periods,
            values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
        )

        // Variable payments (not included in liability)
        let variablePayments = TimeSeries(
            periods: periods,
            values: [5_000.0, 6_000.0, 4_500.0, 5_500.0]
        )

        let lease = Lease(
            payments: fixedPayments,
            discountRate: 0.08,
            startDate: q1.startDate,
            variablePayments: variablePayments
        )

        // ROU asset and liability based only on fixed payments
        let rouAsset = lease.rightOfUseAsset()
        let pvFixed = lease.presentValueOfPayments()

        #expect(abs(rouAsset - pvFixed) < 1.0)

        // Total cash paid includes variable
        let totalPaidQ1 = lease.totalCashPayment(period: q1)
        #expect(abs(totalPaidQ1 - 25_000.0) < 1.0) // 20k fixed + 5k variable
    }

    // MARK: - Lease Modifications

    @Test("Lease modification - extension")
    func leaseModificationExtension() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let originalPeriods = [q1, q1 + 1]

        let originalPayments = TimeSeries(
            periods: originalPeriods,
            values: [40_000.0, 40_000.0]
        )

        var lease = Lease(
            payments: originalPayments,
            discountRate: 0.06
		)

        let originalROU = lease.rightOfUseAsset()

        // Extend lease by 2 more periods
        let extensionPeriods = [q1 + 2, q1 + 3]
        let extensionPayments = TimeSeries(
            periods: extensionPeriods,
            values: [40_000.0, 40_000.0]
        )

        lease = lease.extend(additionalPayments: extensionPayments)

        let newROU = lease.rightOfUseAsset()

        // New ROU should be higher
        #expect(newROU > originalROU)
    }

    @Test("Lease modification - rent reduction")
    func leaseModificationRentReduction() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let originalPayments = TimeSeries(
            periods: periods,
            values: [50_000.0, 50_000.0, 50_000.0]
        )

        var lease = Lease(
            payments: originalPayments,
            discountRate: 0.08
        )

        let originalLiability = lease.liabilitySchedule()[q1]!

        // Negotiate rent reduction
        let reducedPayments = TimeSeries(
            periods: periods,
            values: [40_000.0, 40_000.0, 40_000.0]
        )

        lease = lease.modify(newPayments: reducedPayments, atPeriod: q1)

        let newLiability = lease.liabilitySchedule()[q1]!

        // New liability should be lower
        #expect(newLiability < originalLiability)
    }

    // MARK: - Short-term Lease Exemption

    @Test("Short-term lease - exemption test")
    func shortTermLeaseExemption() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3] // 1 year

        let payments = TimeSeries(
            periods: periods,
            values: [10_000.0, 10_000.0, 10_000.0, 10_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.05,
            startDate: q1.startDate,
            leaseTerm: .months(12) // 12 months
        )

        // Short-term leases (≤12 months) can be expensed directly
        #expect(lease.isShortTerm)

        // If elected, no ROU asset or liability recognized
        if lease.applyShortTermExemption {
            #expect(lease.rightOfUseAsset() == 0.0)
            #expect(lease.liabilitySchedule()[q1] == 0.0)
        }
    }

    // MARK: - Low-value Asset Exemption

    @Test("Low-value lease - exemption test")
    func lowValueLeaseExemption() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [500.0, 500.0, 500.0, 500.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.06,
            startDate: q1.startDate,
            underlyingAssetValue: 4_000.0 // Low value (< $5,000)
        )

        // Low-value leases can be expensed
        #expect(lease.isLowValue)

        if lease.applyLowValueExemption {
            #expect(lease.rightOfUseAsset() == 0.0)
        }
    }

    // MARK: - Incremental Borrowing Rate

    @Test("Discount rate - incremental borrowing rate")
    func incrementalBorrowingRate() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [30_000.0, 30_000.0, 30_000.0, 30_000.0]
        )

        // Cannot determine implicit rate, use IBR
        let lease = Lease(
            payments: payments,
            discountRate: 0.07, // IBR = 7%
            startDate: q1.startDate,
            discountRateType: .incrementalBorrowingRate
        )

        let rouAsset = lease.rightOfUseAsset()

        // Should use IBR for discounting
        #expect(rouAsset > 0.0)
        #expect(lease.effectiveRate == 0.07)
    }

    @Test("Discount rate - implicit rate in lease")
    func implicitRateInLease() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2]

        let payments = TimeSeries(
            periods: periods,
            values: [35_000.0, 35_000.0, 35_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.055, // Implicit rate = 5.5%
            startDate: q1.startDate,
            discountRateType: .implicitRate,
            fairValueOfAsset: 100_000.0
        )

        // Implicit rate preferred when determinable
        #expect(lease.effectiveRate == 0.055)
    }

    // MARK: - Sale and Leaseback

    @Test("Sale and leaseback - gain recognition")
    func saleAndLeasebackGain() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let assetCarryingValue = 500_000.0
        let salePrice = 600_000.0

        let leasebackPayments = TimeSeries(
            periods: periods,
            values: [40_000.0, 40_000.0, 40_000.0, 40_000.0]
        )

        let transaction = SaleAndLeaseback(
            carryingValue: assetCarryingValue,
            salePrice: salePrice,
            leasebackPayments: leasebackPayments,
            discountRate: 0.06,
            startDate: q1.startDate
        )

        let gain = transaction.recognizedGain()

        // If at fair value, recognize full gain
        // Gain = Sale Price - Carrying Value - PV of leaseback
        #expect(gain > 0.0)
        #expect(gain < (salePrice - assetCarryingValue))
    }

    @Test("Sale and leaseback - deferred gain")
    func saleAndLeasebackDeferredGain() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1]

        let assetCarryingValue = 300_000.0
        let salePrice = 350_000.0

        let leasebackPayments = TimeSeries(
            periods: periods,
            values: [100_000.0, 100_000.0]
        )

        let transaction = SaleAndLeaseback(
            carryingValue: assetCarryingValue,
            salePrice: salePrice,
            leasebackPayments: leasebackPayments,
            discountRate: 0.05,
            startDate: q1.startDate
        )

        // If significant leaseback, defer portion of gain
        let immediateGain = transaction.recognizedGain()
        let deferredGain = transaction.deferredGain()

        #expect(immediateGain + deferredGain > 0.0)
    }

    // MARK: - Lease vs Buy Analysis

    @Test("Lease vs buy decision analysis")
    func leaseVsBuyAnalysis() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        // Lease option
        let leasePayments = TimeSeries(
            periods: periods,
            values: [25_000.0, 25_000.0, 25_000.0, 25_000.0]
        )

        let lease = Lease(
            payments: leasePayments,
            discountRate: 0.07
        )

        let leasePV = lease.presentValueOfPayments()

        // Buy option
        let purchasePrice = 95_000.0
        let residualValue = 10_000.0
        let discountRate = 0.07

        let buyPV = purchasePrice - (residualValue / pow(1.07, 1.0))

        // Compare NPVs
        let analysis = LeaseVsBuyAnalysis(
            leasePV: leasePV,
            buyPV: buyPV
        )

        #expect(analysis.recommendation != nil)
    }

    // MARK: - Operating Lease (Pre-IFRS 16 Comparison)

    @Test("Operating lease comparison - old vs new standard")
    func operatingLeaseComparison() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [20_000.0, 20_000.0, 20_000.0, 20_000.0]
        )

        // Old standard (Operating Lease): Expense payments as incurred
        let oldStandardExpense = payments[q1]! // Just current period

        // New standard (IFRS 16): Recognize ROU asset and liability
        let lease = Lease(
            payments: payments,
            discountRate: 0.06
        )

        let rouAsset = lease.rightOfUseAsset()
        let depreciation = lease.depreciation(period: q1)
        let interestExpense = lease.interestExpense(period: q1)
        let newStandardExpense = depreciation + interestExpense

        // New standard front-loads expenses
        #expect(newStandardExpense > oldStandardExpense)
    }

    // MARK: - Disclosure Requirements

    @Test("Lease disclosure - maturity analysis")
    func leaseDisclosureMaturityAnalysis() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3, q1 + 4]

        let payments = TimeSeries(
            periods: periods,
            values: [30_000.0, 30_000.0, 30_000.0, 30_000.0, 30_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.08,
        )

        let maturityAnalysis = lease.maturityAnalysis()

        // Should show payments by year
        #expect(maturityAnalysis["Year 1"] != nil)
        #expect(maturityAnalysis["Year 2"] != nil)
    }

    @Test("Lease disclosure - total commitments")
    func leaseDisclosureTotalCommitments() throws {
        let q1 = Period.quarter(year: 2025, quarter: 1)
        let periods = [q1, q1 + 1, q1 + 2, q1 + 3]

        let payments = TimeSeries(
            periods: periods,
            values: [50_000.0, 50_000.0, 50_000.0, 50_000.0]
        )

        let lease = Lease(
            payments: payments,
            discountRate: 0.06
        )

        let totalFuturePayments = lease.totalFuturePayments()
        let pvOfPayments = lease.presentValueOfPayments()

        // Total undiscounted payments
        #expect(abs(totalFuturePayments - 200_000.0) < 1.0)

        // Present value should be less
        #expect(pvOfPayments < totalFuturePayments)
    }
}
