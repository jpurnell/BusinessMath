//
//  UnreachableBreakEvenTests.swift
//  BusinessMathTests
//
//  From the fanned-out triage of `Fluent API/` and `Financial Statements/`.
//
//  Most of this sweep has been about contaminated data. These are different: they fire on
//  **ordinary business input**, no `nan` required.
//
//      guard cmPerUnit > 0 else { return 0 }        // break-even units
//      guard grossMargin > 0 else { return 0 }      // break-even revenue
//      guard turnover > 0 else { return 0 }         // days inventory outstanding
//
//  Each guard was written to prevent a division by zero and silently captured the *negative*
//  case with it — a product sold below variable cost, a retailer whose COGS exceeds its price,
//  inventory that does not move. Loss leaders and distressed stock are configurations these
//  templates exist to model.
//
//  Measured before the fix:
//
//      contribution margin -1.00/unit  ->  break-even 0 units      (profitable: 5,556)
//      gross margin        -10%        ->  break-even 0.0 revenue  (healthy:  125,000)
//
//  Zero is the *best* value on a "how much do I need" scale: already past it, from the first
//  unit. The one configuration where break-even is unreachable reports that it has been
//  reached. The honest answer is that it never is.
//
//  The contaminated cases are the same guards seen from the other side. `wacc` returns **0.0**
//  for an unvaluable equity stake — a weighted average cost of capital of zero, i.e. capital
//  is free — and that is the hurdle rate every project is compared against and every NPV is
//  discounted at.
//
//  `CapitalStructure.debtRatio` returns 0.0 — unlevered, the safest reading on any covenant or
//  credit screen. Note that the textually identical guard four lines below it, in
//  `equityRatio`, is **correct**: zero equity is the alarming end. Same shape, opposite
//  meaning, and they must not be tidied into agreement.
//

import Testing
import Foundation
@testable import BusinessMath

@Suite("Break-even and capital ratios that cannot be reached")
struct UnreachableBreakEvenTests {

    // MARK: - Ordinary input, no contamination

    /// A product sold below variable cost never breaks even.
    @Test("BreakEvenUnits_BelowVariableCost_IsUnreachable")
    func breakEvenUnitsBelowVariableCostIsUnreachable() {
        let lossMaking = ManufacturingModel(productionCapacity: 1000, sellingPricePerUnit: 10,
                                            directMaterialCostPerUnit: 6, directLaborCostPerUnit: 5,
                                            monthlyOverhead: 50_000)
        #expect(lossMaking.calculateContributionMarginPerUnit().isEqual(to: -1.0),
                "the fixture really does lose money per unit")
        let units = lossMaking.calculateBreakEvenUnits()
        #expect(units.isEqual(to: .infinity),
                "reported \(units) units — already past break-even from the first one")
    }

    /// And neither does the revenue form built on it.
    @Test("BreakEvenRevenue_BelowVariableCost_IsUnreachable")
    func breakEvenRevenueBelowVariableCostIsUnreachable() {
        let lossMaking = ManufacturingModel(productionCapacity: 1000, sellingPricePerUnit: 10,
                                            directMaterialCostPerUnit: 6, directLaborCostPerUnit: 5,
                                            monthlyOverhead: 50_000)
        #expect(lossMaking.calculateBreakEvenRevenue().isEqual(to: .infinity))
    }

    /// A retailer whose cost of goods exceeds its price never covers opex.
    @Test("RetailBreakEven_NegativeGrossMargin_IsUnreachable")
    func retailBreakEvenNegativeGrossMarginIsUnreachable() {
        let lossLeader = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: 100_000,
                                     costOfGoodsSoldPercentage: 1.1, operatingExpenses: 50_000)
        #expect(lossLeader.calculateGrossMargin() < 0, "the fixture really is loss-making")
        let revenue = lossLeader.calculateBreakEvenRevenue()
        #expect(revenue.isEqual(to: .infinity), "reported \(revenue)")
    }

    /// Inventory that does not move does not sell through on day zero.
    @Test("DaysInventoryOutstanding_NoTurnover_IsUnbounded")
    func daysInventoryOutstandingNoTurnoverIsUnbounded() {
        let stagnant = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: 0,
                                   costOfGoodsSoldPercentage: 0.6, operatingExpenses: 50_000)
        let days = stagnant.calculateDaysInventoryOutstanding()
        #expect(days.isEqual(to: .infinity),
                "reported \(days) days — the fastest-moving inventory in the chain")
    }

    // MARK: - Contaminated input

    /// The hurdle rate.
    @Test("WACC_WithAnUnvaluableStake_IsUndefined")
    func waccWithAnUnvaluableStakeIsUndefined() {
        let rate = wacc(equityValue: .nan, debtValue: 100_000,
                        costOfEquity: 0.10, costOfDebt: 0.05, taxRate: 0.21)
        #expect(rate.isNaN, "reported \(rate) — capital is free and every project clears")
    }

    @Test("DebtRatio_WithAnUnvaluableStake_IsUndefined")
    func debtRatioWithAnUnvaluableStakeIsUndefined() {
        let structure = CapitalStructure(debtValue: .nan, equityValue: 1_000_000,
                                         costOfDebt: 0.05, costOfEquity: 0.10, taxRate: 0.21)
        #expect(structure.debtRatio.isNaN, "reported \(structure.debtRatio) — unlevered")
    }

    // MARK: - Controls

    /// The profitable cases are untouched, at their measured values.
    @Test("ProfitableModels_Unchanged")
    func profitableModelsUnchanged() {
        let viable = ManufacturingModel(productionCapacity: 1000, sellingPricePerUnit: 20,
                                        directMaterialCostPerUnit: 6, directLaborCostPerUnit: 5,
                                        monthlyOverhead: 50_000)
        #expect(viable.calculateContributionMarginPerUnit().isEqual(to: 9.0))
        #expect(abs(viable.calculateBreakEvenUnits() - 5555.555555555556) < 1e-9,
                "got \(viable.calculateBreakEvenUnits())")

        let healthy = RetailModel(initialInventoryValue: 100_000, monthlyRevenue: 100_000,
                                  costOfGoodsSoldPercentage: 0.6, operatingExpenses: 50_000)
        #expect(healthy.calculateGrossMargin().isEqual(to: 0.4))
        #expect(healthy.calculateBreakEvenRevenue().isEqual(to: 125_000.0))
    }

    /// A real capital structure is unchanged, and `equityRatio` keeps the zero that is
    /// correct for it — the asymmetry four lines apart must survive.
    @Test("CapitalStructure_Unchanged")
    func capitalStructureUnchanged() {
        let rate = wacc(equityValue: 900_000, debtValue: 100_000,
                        costOfEquity: 0.10, costOfDebt: 0.05, taxRate: 0.21)
        #expect(abs(rate - 0.09395) < 1e-9, "got \(rate)")

        let structure = CapitalStructure(debtValue: 400_000, equityValue: 600_000,
                                         costOfDebt: 0.05, costOfEquity: 0.10, taxRate: 0.21)
        #expect(structure.debtRatio.isEqual(to: 0.4))
        #expect(structure.equityRatio.isEqual(to: 0.6))

        let empty = CapitalStructure(debtValue: 0, equityValue: 0,
                                     costOfDebt: 0.05, costOfEquity: 0.10, taxRate: 0.21)
        #expect(empty.equityRatio.isEqual(to: 0.0), "no equity is the alarming end, and stays 0")
    }
}
