//
//  ManufacturingModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
import RealModule
@testable import BusinessMath

/// Tests for Manufacturing business model template.
///
/// These tests define the expected behavior of a manufacturing financial model,
/// including production capacity, unit costs, overhead allocation, and efficiency metrics.
@Suite("ManufacturingModelTests") struct ManufacturingModelTests {

    // MARK: - Basic Setup Tests

    @Test("ManufacturingModel_BasicSetup") func LManufacturingModel_BasicSetup() {
        // Given: A basic manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,  // units per month
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // Then: The model should be initialized correctly
        #expect(model.productionCapacity == 10_000)
        #expect(model.sellingPricePerUnit == 50)
        #expect(model.directMaterialCostPerUnit == 15)
        #expect(model.directLaborCostPerUnit == 10)
        #expect(model.monthlyOverhead == 150_000)
    }

    // MARK: - Unit Cost Tests

    @Test("ManufacturingModel_UnitCostCalculation") func LManufacturingModel_UnitCostCalculation() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating unit cost at full capacity
        let unitCost = model.calculateUnitCost(atCapacityUtilization: 1.0)

        // Then: Unit Cost = Direct Materials + Direct Labor + Overhead per Unit
        // Overhead per unit at 100% = $150,000 / 10,000 = $15
        // Total: $15 + $10 + $15 = $40
        #expect(abs(unitCost - 40) < 0.1)
    }

    @Test("ManufacturingModel_UnitCostAtPartialCapacity") func LManufacturingModel_UnitCostAtPartialCapacity() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating unit cost at 50% capacity
        let unitCost = model.calculateUnitCost(atCapacityUtilization: 0.5)

        // Then: Unit Cost increases because overhead is spread over fewer units
        // Overhead per unit at 50% = $150,000 / 5,000 = $30
        // Total: $15 + $10 + $30 = $55
        #expect(abs(unitCost - 55) < 0.1)
    }

    // MARK: - Contribution Margin Tests

    @Test("ManufacturingModel_ContributionMarginPerUnit") func LManufacturingModel_ContributionMarginPerUnit() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating contribution margin per unit
        let contributionMargin = model.calculateContributionMarginPerUnit()

        // Then: Contribution Margin = Selling Price - Variable Costs
        // Variable Costs = Direct Materials + Direct Labor = $15 + $10 = $25
        // Contribution Margin = $50 - $25 = $25
        #expect(abs(contributionMargin - 25) < 0.1)
    }

    @Test("ManufacturingModel_ContributionMarginRatio") func LManufacturingModel_ContributionMarginRatio() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating contribution margin ratio
        let ratio = model.calculateContributionMarginRatio()

        // Then: CM Ratio = Contribution Margin / Selling Price
        // $25 / $50 = 0.50 (50%)
        #expect(abs(ratio - 0.50) < 0.01)
    }

    // MARK: - Break-Even Tests

    @Test("ManufacturingModel_BreakEvenUnits") func LManufacturingModel_BreakEvenUnits() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating break-even units
        let breakEvenUnits = model.calculateBreakEvenUnits()

        // Then: Break-even = Fixed Costs / Contribution Margin per Unit
        // $150,000 / $25 = 6,000 units
        #expect(abs(breakEvenUnits - 6_000) < 1.0)
    }

    @Test("ManufacturingModel_BreakEvenRevenue") func LManufacturingModel_BreakEvenRevenue() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating break-even revenue
        let breakEvenRevenue = model.calculateBreakEvenRevenue()

        // Then: Break-even Revenue = Break-even Units * Selling Price
        // 6,000 * $50 = $300,000
        #expect(abs(breakEvenRevenue - 300_000) < 1.0)
    }

    // MARK: - Capacity Utilization Tests

    @Test("ManufacturingModel_CapacityUtilization") func LManufacturingModel_CapacityUtilization() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating capacity utilization for 7,500 units
        let utilization = model.calculateCapacityUtilization(actualProduction: 7_500)

        // Then: Utilization = Actual / Capacity
        // 7,500 / 10,000 = 0.75 (75%)
        #expect(abs(utilization - 0.75) < 0.01)
    }

    // MARK: - Profit Tests

    @Test("ManufacturingModel_MonthlyProfit") func LManufacturingModel_MonthlyProfit() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating profit for 8,000 units production
        let profit = model.calculateProfit(unitsProduced: 8_000)

        // Then: Profit = (Selling Price - Variable Costs) * Units - Fixed Costs
        // ($50 - $25) * 8,000 - $150,000
        // $25 * 8,000 - $150,000 = $200,000 - $150,000 = $50,000
        #expect(abs(profit - 50_000) < 1.0)
    }

    @Test("ManufacturingModel_ProfitAtBreakEven") func LManufacturingModel_ProfitAtBreakEven() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating profit at break-even units
        let breakEvenUnits = model.calculateBreakEvenUnits()
        let profit = model.calculateProfit(unitsProduced: breakEvenUnits)

        // Then: Profit should be zero (or very close to zero)
        #expect(abs(profit - 0) < 1.0)
    }

    // MARK: - Production Efficiency Tests

    @Test("ManufacturingModel_ProductionEfficiency") func LManufacturingModel_ProductionEfficiency() {
        // Given: A model with target production of 9,000 units
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000,
            targetProduction: 9_000
        )

        // When: Calculating efficiency for 8,500 units actual
        let efficiency = model.calculateProductionEfficiency(actualProduction: 8_500)

        // Then: Efficiency = Actual / Target
        // 8,500 / 9,000 ≈ 0.944 (94.4%)
        #expect(abs(efficiency - 0.944) < 0.01)
    }

    // MARK: - Overhead Allocation Tests

    @Test("ManufacturingModel_OverheadPerUnit") func LManufacturingModel_OverheadPerUnit() {
        // Given: A manufacturing model
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Calculating overhead per unit at 8,000 units production
        let overheadPerUnit = model.calculateOverheadPerUnit(atProduction: 8_000)

        // Then: Overhead per Unit = Total Overhead / Units
        // $150,000 / 8,000 = $18.75
        #expect(abs(overheadPerUnit - 18.75) < 0.01)
    }

    // MARK: - Projection Tests

    @Test("ManufacturingModel_Projection12Months") func LManufacturingModel_Projection12Months() {
        // Given: A manufacturing model with monthly production of 8,000 units
        let model = ManufacturingModel(
            productionCapacity: 10_000,
            sellingPricePerUnit: 50,
            directMaterialCostPerUnit: 15,
            directLaborCostPerUnit: 10,
            monthlyOverhead: 150_000
        )

        // When: Projecting 12 months at 8,000 units/month
        let projection = model.project(months: 12, unitsPerMonth: 8_000)

        // Then: Should return projections for all 12 months
        #expect(projection.revenue.count == 12)
        #expect(projection.profit.count == 12)
        #expect(projection.unitCost.count == 12)

        // And: First month values should match calculations
        let firstMonthRevenue = projection.revenue.valuesArray.first ?? 0
        #expect(abs(firstMonthRevenue - 400_000) < 1.0)  // 8,000 * $50

        let firstMonthProfit = projection.profit.valuesArray.first ?? 0
        #expect(abs(firstMonthProfit - 50_000) < 1.0)  // Calculated above
    }
}
