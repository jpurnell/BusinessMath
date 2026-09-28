//
//  ContaminatedBusinessModelTests.swift
//  BusinessMathTests
//
//  From the parallel probe pass. Four measurements, all confirmed before any edit:
//
//  | call                                          | clean      | before the fix |
//  | leasePaymentsPV(r: nan)                       | —          | 5000.00        |
//  | leasePaymentsPV(r: -0.02)                     | 5314.58    | 5000.00        |
//  | SaaSModel.calculateGrowthRate, NaN MRR        | 0.4628     | 0.0            |
//  | ManufacturingModel unit cost at 0% capacity   | +infinity  | 0.0            |
//  | RetailModel margin, month with no revenue     | -infinity  | 0.0            |
//
//  The lease case has two separate failures behind one guard. `nan > 0` is false, so a
//  contaminated rate returned the undiscounted sum — and so did a **negative** rate, which is
//  ordinary in EUR markets and which the annuity formula below the guard handles perfectly
//  well. Understating the lease PV biases `netAdvantageToLeasing = buyPV - leasePV` upward and
//  flips `LeaseVsBuyAnalysis.shouldLease` from false to true.
//
//  The manufacturing case is the one with no contamination at all: zero is the best value on a
//  *cost* scale, so sweeping utilisation for the cheapest operating point picked 0% capacity
//  outright — and the parameter's own DocC declares 0.0 valid input. It is also false
//  arithmetic, since materials and labour are incurred on every unit and do not vanish when
//  none are made.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Business templates on input they cannot price")
struct ContaminatedBusinessModelTests {

    // MARK: - Lease present value

    @Test("LeasePV_ContaminatedRate_IsUndefined")
    func leasePVContaminatedRateIsUndefined() {
        let pv = leasePaymentsPV(periodicPayment: 1000, periods: 5, discountRate: .nan)
        #expect(pv.isNaN, "reported \(pv) — the undiscounted sum, presented as a present value")
    }

    /// A negative rate is a real quote, and the formula below the guard handles it.
    @Test("LeasePV_NegativeRate_UsesTheAnnuityFormula")
    func leasePVNegativeRateUsesTheAnnuityFormula() {
        let pv = leasePaymentsPV(periodicPayment: 1000, periods: 5, discountRate: -0.02)
        #expect(abs(pv - 5314.580854) < 1e-5, "got \(pv); the undiscounted sum would be 5000")
    }

    /// Control: a zero rate genuinely IS the undiscounted sum, and must not move.
    @Test("LeasePV_ZeroRate_StillTheUndiscountedSum")
    func leasePVZeroRateStillTheUndiscountedSum() {
        #expect(leasePaymentsPV(periodicPayment: 1000, periods: 5, discountRate: 0.0)
            .isEqual(to: 5000.0))
        #expect(abs(leasePaymentsPV(periodicPayment: 1000, periods: 5, discountRate: 0.05)
            - 4329.476671) < 1e-5, "and an ordinary rate is unchanged")
    }

    // MARK: - SaaS growth

    @Test("SaaSGrowth_UnusableMRR_IsRefused")
    func saaSGrowthUnusableMRRIsRefused() {
        let model = SaaSModel(initialMRR: .nan, churnRate: 0.05,
                              newCustomersPerMonth: 100, averageRevenuePerUser: 100)
        #expect(throws: BusinessMathError.self) {
            try model.calculateGrowthRate(from: 1, to: 2)
        }
    }

    /// Growth from nothing is undefined, not flat — a separate error from contamination.
    @Test("SaaSGrowth_ZeroBase_IsRefused")
    func saaSGrowthZeroBaseIsRefused() {
        let preRevenue = SaaSModel(initialMRR: 0, churnRate: 0.05,
                                   newCustomersPerMonth: 0, averageRevenuePerUser: 100)
        #expect(throws: BusinessMathError.self) {
            try preRevenue.calculateGrowthRate(from: 1, to: 2)
        }
    }

    @Test("SaaSGrowth_CleanModel_Unchanged")
    func saaSGrowthCleanModelUnchanged() throws {
        let clean = SaaSModel(initialMRR: 10_000, churnRate: 0.05,
                              newCustomersPerMonth: 100, averageRevenuePerUser: 100)
        let growth = try clean.calculateGrowthRate(from: 1, to: 2)
        #expect(abs(growth - 0.462821) < 1e-5, "got \(growth)")
    }

    // MARK: - Manufacturing unit economics

    /// A `nan` utilisation is an unusable input, not zero production.
    @Test("UnitCost_ContaminatedUtilisation_IsUndefined")
    func unitCostContaminatedUtilisationIsUndefined() {
        let mfg = ManufacturingModel(productionCapacity: 10_000, sellingPricePerUnit: 50,
                                     directMaterialCostPerUnit: 15, directLaborCostPerUnit: 10,
                                     monthlyOverhead: 150_000)
        #expect(mfg.calculateUnitCost(atCapacityUtilization: .nan).isNaN)
        #expect(mfg.calculateOverheadPerUnit(atProduction: .nan).isNaN)
    }

    /// Zero production keeps its documented `0`. This pins an existing deliberate decision
    /// rather than endorsing it: measured, a utilisation sweep for the cheapest unit cost
    /// still picks 0% capacity, because 0 is the best value on a cost scale. Flagged for a
    /// separate call; see the note at the guard.
    @Test("UnitCost_AtZeroProduction_KeepsTheDocumentedZero")
    func unitCostAtZeroProductionKeepsTheDocumentedZero() {
        let mfg = ManufacturingModel(productionCapacity: 10_000, sellingPricePerUnit: 50,
                                     directMaterialCostPerUnit: 15, directLaborCostPerUnit: 10,
                                     monthlyOverhead: 150_000)
        #expect(mfg.calculateUnitCost(atCapacityUtilization: 0.0).isEqual(to: 0.0))
        #expect(mfg.calculateOverheadPerUnit(atProduction: 0).isEqual(to: 0.0))
    }

    @Test("UnitCost_OrdinaryUtilisation_Unchanged")
    func unitCostOrdinaryUtilisationUnchanged() {
        let mfg = ManufacturingModel(productionCapacity: 10_000, sellingPricePerUnit: 50,
                                     directMaterialCostPerUnit: 15, directLaborCostPerUnit: 10,
                                     monthlyOverhead: 150_000)
        #expect(mfg.calculateUnitCost(atCapacityUtilization: 0.80).isEqual(to: 43.75))
        #expect(mfg.calculateOverheadPerUnit(atProduction: 8_000).isEqual(to: 18.75))
    }

    // MARK: - Retail margin

    @Test("NetProfitMargin_MonthWithNoRevenue_IsUnbounded")
    func netProfitMarginMonthWithNoRevenueIsUnbounded() {
        let retail = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: 50_000,
                                 costOfGoodsSoldPercentage: 0.60, operatingExpenses: 15_000,
                                 seasonalMultipliers: [1: 0.0])
        let margin = retail.calculateNetProfitMargin(forMonth: 1)
        #expect(margin.isEqual(to: -.infinity),
                "reported \(margin), which passes any `margin >= 0` break-even screen")
    }

    /// The NaN path was already correct, because `!=` lets contamination through.
    @Test("NetProfitMargin_ContaminatedRevenue_AlreadyPropagated")
    func netProfitMarginContaminatedRevenueAlreadyPropagated() {
        let contaminated = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: .nan,
                                       costOfGoodsSoldPercentage: 0.60, operatingExpenses: 15_000)
        #expect(contaminated.calculateNetProfitMargin().isNaN)
    }

    @Test("NetProfitMargin_OrdinaryMonth_Unchanged")
    func netProfitMarginOrdinaryMonthUnchanged() {
        let retail = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: 50_000,
                                 costOfGoodsSoldPercentage: 0.60, operatingExpenses: 15_000,
                                 seasonalMultipliers: [1: 0.0])
        #expect(retail.calculateNetProfitMargin(forMonth: 2).isEqual(to: 0.1))
    }
}
