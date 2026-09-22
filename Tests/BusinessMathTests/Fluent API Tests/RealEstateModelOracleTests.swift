//
//  RealEstateModelOracleTests.swift
//  BusinessMathTests
//
//  `RealEstateModel` is a complete property investment model — amortisation, depreciation,
//  tax impact, cap rate, IRR, equity multiple — and **not one of its 22 members was executed
//  by any test**. Measured with `swift test --enable-code-coverage`; it was one of the
//  largest untested clusters in the package, alongside `RingBuffer` and
//  `ConsolidatedStatements`.
//
//  Every expectation below was computed independently in Python from first principles — a
//  month-by-month amortisation loop, not a rearrangement of the Swift — and then differenced
//  against it. **The arithmetic matched to the bit at every one of them**, including the
//  internal rate of return and the equity multiple. That is worth recording as plainly as a
//  defect would be: the oracle found nothing wrong here.
//
//  Two things the oracle did surface:
//
//  1. At year 30 the independent amortisation drifts to a balance of `-1.37e-08` while the
//     model returns exactly `0.0`. The model clamps, which is the right answer — a loan
//     cannot be repaid to less than nothing — and that is pinned below.
//  2. `calculateCashOnCashReturn` is the **after-tax** variant, where the industry convention
//     is pre-tax, and on this property the two differ in sign. That is now stated on the
//     method; the test pins both figures so the distinction cannot quietly drift.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Real estate model against an independent oracle")
struct RealEstateModelOracleTests {

    /// A 400,000 property, 20% down, 6% over 30 years, 36,000 of rent at 5% vacancy against
    /// 12,000 of expenses, appreciating 3% with rents growing 2.5%, 24% tax.
    private static let model = RealEstateModel(
        purchasePrice: 400_000, downPaymentPercentage: 0.20,
        interestRate: 0.06, loanTermYears: 30,
        annualRent: 36_000, vacancyRate: 0.05,
        annualOperatingExpenses: 12_000, annualAppreciationRate: 0.03,
        closingCostsPercentage: 0.03, rentGrowthRate: 0.025,
        depreciationPeriodYears: 27.5, taxRate: 0.24
    )

    // MARK: - Acquisition

    @Test("Acquisition_MatchesOracle") func acquisitionMatchesOracle() {
        let m = Self.model
        #expect(m.downPayment.isEqual(to: 80_000.0))
        #expect(m.loanAmount.isEqual(to: 320_000.0))
        #expect(m.closingCosts.isEqual(to: 12_000.0))
        #expect(m.initialInvestment.isEqual(to: 92_000.0), "down payment plus closing costs")
        #expect(m.monthlyMortgagePayment.isEqual(to: 1918.5616804888223))
        #expect(m.annualMortgagePayment.isEqual(to: 23_022.740165865867))
        // 80% of the purchase price is building, over 27.5 years, straight line to zero.
        #expect(m.annualDepreciation.isEqual(to: 11_636.363636363636))
    }

    // MARK: - Amortisation, the part most likely to be off by a month

    /// Interest is summed over months `12(y-1)+1` through `12y`, matched against a
    /// month-by-month loop that carries the balance forward.
    @Test("MortgageInterest_MatchesOracle", arguments: [
        (1, 19_093.102686580194),
        (2, 18_850.73124543712),
        (5, 18_030.178341399194),
        (30, 731.1023342683117),
    ])
    func mortgageInterestMatchesOracle(year: Int, expected: Double) {
        #expect(Self.model.mortgageInterest(year: year).isEqual(to: expected), "year \(year)")
    }

    @Test("LoanBalance_MatchesOracle", arguments: [
        (1, 316_070.3625207144),
        (2, 311_898.3536002856),
        (5, 297_773.94183302147),
    ])
    func loanBalanceMatchesOracle(year: Int, expected: Double) {
        #expect(Self.model.loanBalance(atYear: year).isEqual(to: expected), "year \(year)")
    }

    /// The independent loop finishes at `-1.37e-08` from accumulated rounding. A loan is not
    /// repaid to less than nothing, and the model clamps — which is the better answer, so it
    /// is pinned rather than treated as a disagreement.
    @Test("LoanBalance_AtTermIsExactlyZero") func loanBalanceAtTermIsExactlyZero() {
        #expect(Self.model.loanBalance(atYear: 30).isEqual(to: 0.0))
        #expect(Self.model.loanBalance(atYear: 30) >= 0, "never negative")
    }

    // MARK: - Operations

    /// Year 1 carries no rent growth, so the exponent is `year - 1`. Expenses do **not** grow
    /// — by year 30 rent has risen 2.5% a year for 29 years while expenses sit at 12,000 —
    /// which is a modelling choice this pins rather than endorses.
    @Test("RentalIncomeAndNOI_MatchOracle", arguments: [
        (1, 34_200.0, 22_200.0),
        (2, 35_055.0, 23_055.0),
        (5, 37_750.40085937498, 25_750.400859374982),
        (30, 69_987.13288253374, 57_987.13288253374),
    ])
    func rentalIncomeAndNOIMatchOracle(year: Int, rent: Double, noi: Double) {
        #expect(Self.model.effectiveRentalIncome(year: year).isEqual(to: rent), "year \(year)")
        #expect(Self.model.netOperatingIncome(year: year).isEqual(to: noi), "year \(year)")
    }

    @Test("CapRate_IsFirstYearNOIOverPrice") func capRateIsFirstYearNOIOverPrice() {
        #expect(Self.model.calculateCapRate().isEqual(to: 0.0555))
        // 22,200 / 400,000, stated as the identity rather than only as a constant.
        let identity = Self.model.netOperatingIncome(year: 1) / 400_000.0
        #expect(Self.model.calculateCapRate().isEqual(to: identity))
    }

    @Test("CashFlowsAndTax_MatchOracle", arguments: [
        (1, -822.7401658658673, -8529.46632294383, -2047.0719175065192, 1224.3317516406519),
        (2, 32.25983413413269, -7432.094881800756, -1783.7027716321816, 1815.9626057663143),
        (5, 2727.660693509115, -3916.141118387848, -939.8738684130835, 3667.5345619221985),
        (30, 34_964.39271666788, 45_619.66691190179, 10_948.720058856428, 24_015.672657811447),
    ])
    func cashFlowsAndTaxMatchOracle(
        year: Int, btcf: Double, taxable: Double, taxImpact: Double, atcf: Double
    ) {
        let m = Self.model
        #expect(m.beforeTaxCashFlow(year: year).isEqual(to: btcf), "year \(year)")
        #expect(m.taxableIncome(year: year).isEqual(to: taxable), "year \(year)")
        #expect(m.taxImpact(year: year).isEqual(to: taxImpact), "year \(year)")
        #expect(m.afterTaxCashFlow(year: year).isEqual(to: atcf), "year \(year)")
    }

    /// The first four years run at a taxable loss, so tax is negative and after-tax cash flow
    /// *exceeds* before-tax. That is the depreciation shield, and it is the reason the two
    /// cash-on-cash figures below disagree in sign.
    @Test("EarlyYears_ShowATaxableLoss") func earlyYearsShowATaxableLoss() {
        for year in 1...4 {
            #expect(Self.model.taxableIncome(year: year) < 0, "year \(year)")
            #expect(Self.model.afterTaxCashFlow(year: year)
                    > Self.model.beforeTaxCashFlow(year: year), "year \(year)")
        }
    }

    // MARK: - Value and exit

    @Test("PropertyValueAndEquity_MatchOracle", arguments: [
        (1, 412_000.0, 95_929.6374792856),
        (2, 424_360.0, 112_461.6463997144),
        (5, 463_709.62972, 165_935.68788697856),
    ])
    func propertyValueAndEquityMatchOracle(year: Int, value: Double, equity: Double) {
        #expect(Self.model.propertyValue(atYear: year).isEqual(to: value), "year \(year)")
        #expect(Self.model.equity(atYear: year).isEqual(to: equity), "year \(year)")
    }

    @Test("SaleProceeds_MatchOracle") func saleProceedsMatchOracle() {
        // Value at 6% selling costs, less the outstanding balance.
        #expect(Self.model.saleProceeds(year: 1).isEqual(to: 71_209.6374792856))
        #expect(Self.model.saleProceeds(year: 5).isEqual(to: 138_113.11010377854))
    }

    /// Bisected independently against the cash-flow vector `[-92,000, ATCF₁…ATCF₄,
    /// ATCF₅ + proceeds₅]`.
    @Test("IRRAndEquityMultiple_MatchOracle") func irrAndEquityMultipleMatchOracle() throws {
        let irr = try #require(Self.model.calculateIRR(holdingPeriodYears: 5))
        #expect(abs(irr - 0.1062056693547474) < 1e-12, "IRR was \(irr)")
        #expect(Self.model.calculateEquityMultiple(holdingPeriodYears: 5)
            .isEqual(to: 1.633462724512769))
    }

    @Test("ProjectCashFlow_AgreesWithPerYearCalls") func projectCashFlowAgreesWithPerYearCalls() {
        let projected = Self.model.projectCashFlow(years: 5).valuesArray
        #expect(projected.count == 5)
        for (offset, value) in projected.enumerated() {
            #expect(value.isEqual(to: Self.model.afterTaxCashFlow(year: offset + 1)),
                    "year \(offset + 1)")
        }
    }

    // MARK: - The definitional one

    /// `calculateCashOnCashReturn` is the **after-tax** variant where the industry convention
    /// is pre-tax, and here the two differ in sign. Both are pinned so the choice cannot drift
    /// without a test noticing.
    @Test("CashOnCash_IsTheAfterTaxVariant") func cashOnCashIsTheAfterTaxVariant() {
        let m = Self.model
        #expect(m.calculateCashOnCashReturn(year: 1).isEqual(to: 0.013307953822181),
                "after-tax: the depreciation shield makes it positive")
        let beforeTax = m.beforeTaxCashFlow(year: 1) / m.initialInvestment
        #expect(beforeTax.isEqual(to: -0.008942827889846384),
                "pre-tax, the conventional figure, is negative for this property")
        #expect(m.calculateCashOnCashReturn(year: 1) > 0 && beforeTax < 0,
                "they disagree in sign, which is why the method now says which it is")
    }
}
