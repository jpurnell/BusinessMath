//
//  RetailModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
import RealModule
@testable import BusinessMath

/// Tests for Retail business model template.
///
/// These tests define the expected behavior of a retail financial model,
/// including inventory management, COGS, gross margin, turnover, and seasonal demand.
@Suite("RetailModelTests") struct RetailModelTests {

    // MARK: - Basic Setup Tests

    @Test("RetailModel_BasicSetup") func LRetailModel_BasicSetup() {
        // Given: A basic retail model with initial parameters
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // Then: The model should be initialized correctly
        #expect(model.initialInventoryValue == 100_000)
        #expect(model.monthlyRevenue == 50_000)
        #expect(model.costOfGoodsSoldPercentage == 0.60)
        #expect(model.operatingExpenses == 15_000)
    }

    // MARK: - COGS and Gross Margin Tests

    @Test("RetailModel_COGSCalculation") func LRetailModel_COGSCalculation() {
        // Given: A retail model with 60% COGS
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating COGS
        let cogs = model.calculateCOGS()

        // Then: COGS should be 60% of revenue
        // $50,000 * 0.60 = $30,000
        #expect(abs(cogs - 30_000) < 1.0)
    }

    @Test("RetailModel_GrossMarginCalculation") func LRetailModel_GrossMarginCalculation() {
        // Given: A retail model with 60% COGS
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating gross margin
        let grossMargin = model.calculateGrossMargin()

        // Then: Gross margin should be 40% (1 - 0.60)
        #expect(abs(grossMargin - 0.40) < 0.01)
    }

    @Test("RetailModel_GrossProfitCalculation") func LRetailModel_GrossProfitCalculation() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating gross profit
        let grossProfit = model.calculateGrossProfit()

        // Then: Gross profit = Revenue - COGS
        // $50,000 - $30,000 = $20,000
        #expect(abs(grossProfit - 20_000) < 1.0)
    }

    // MARK: - Inventory Turnover Tests

    @Test("RetailModel_InventoryTurnoverCalculation") func LRetailModel_InventoryTurnoverCalculation() {
        // Given: A retail model with known inventory and COGS
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating annual inventory turnover
        let turnover = model.calculateInventoryTurnover()

        // Then: Turnover = Annual COGS / Average Inventory
        // Annual COGS = $30,000 * 12 = $360,000
        // Turnover = $360,000 / $100,000 = 3.6 times per year
        #expect(abs(turnover - 3.6) < 0.1)
    }

    @Test("RetailModel_DaysInventoryOutstanding") func LRetailModel_DaysInventoryOutstanding() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating days inventory outstanding (DIO)
        let dio = model.calculateDaysInventoryOutstanding()

        // Then: DIO = 365 / Inventory Turnover
        // DIO = 365 / 3.6 ≈ 101 days
        #expect(abs(dio - 101.4) < 1.0)
    }

    // MARK: - Net Profit Tests

    @Test("RetailModel_NetProfitCalculation") func LRetailModel_NetProfitCalculation() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating net profit
        let netProfit = model.calculateNetProfit()

        // Then: Net Profit = Gross Profit - Operating Expenses
        // $20,000 - $15,000 = $5,000
        #expect(abs(netProfit - 5_000) < 1.0)
    }

    @Test("RetailModel_NetProfitMargin") func LRetailModel_NetProfitMargin() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating net profit margin
        let netProfitMargin = model.calculateNetProfitMargin()

        // Then: Net Profit Margin = Net Profit / Revenue
        // $5,000 / $50,000 = 0.10 (10%)
        #expect(abs(netProfitMargin - 0.10) < 0.01)
    }

    // MARK: - Seasonal Demand Tests

    @Test("RetailModel_SeasonalRevenue") func LRetailModel_SeasonalRevenue() {
        // Given: A model with seasonal multipliers
        let seasonalMultipliers: [Int: Double] = [
            11: 1.5,  // November: 50% increase
            12: 2.0   // December: 100% increase (holiday season)
        ]

        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000,
            seasonalMultipliers: seasonalMultipliers
        )

        // When: Calculating revenue for different months
        let normalMonthRevenue = model.calculateRevenue(forMonth: 1)
        let novemberRevenue = model.calculateRevenue(forMonth: 11)
        let decemberRevenue = model.calculateRevenue(forMonth: 12)

        // Then: Revenue should be adjusted by seasonal multipliers
        #expect(abs(normalMonthRevenue - 50_000) < 1.0)
        #expect(abs(novemberRevenue - 75_000) < 1.0)  // $50,000 * 1.5
        #expect(abs(decemberRevenue - 100_000) < 1.0)  // $50,000 * 2.0
    }

    // MARK: - Projection Tests

    @Test("RetailModel_Projection12Months") func LRetailModel_Projection12Months() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Projecting 12 months
        let projection = model.project(months: 12)

        // Then: Should return projections for all 12 months
        #expect(projection.revenue.count == 12)
        #expect(projection.grossProfit.count == 12)
        #expect(projection.netProfit.count == 12)

        // And: Values should be consistent with inputs
        let firstMonthRevenue = projection.revenue.valuesArray.first ?? 0
        #expect(abs(firstMonthRevenue - 50_000) < 1.0)
    }

    // MARK: - Markup Tests

    @Test("RetailModel_MarkupCalculation") func LRetailModel_MarkupCalculation() {
        // Given: A model with cost and selling price
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating markup
        let markup = model.calculateMarkup()

        // Then: Markup = (Selling Price - Cost) / Cost
        // If COGS is 60%, then for $1 selling price, cost is $0.60
        // Markup = ($1.00 - $0.60) / $0.60 = 0.40 / 0.60 ≈ 0.667 (66.7%)
        #expect(abs(markup - 0.667) < 0.01)
    }

    // MARK: - Break-Even Tests

    @Test("RetailModel_BreakEvenRevenue") func LRetailModel_BreakEvenRevenue() {
        // Given: A retail model
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // When: Calculating break-even revenue
        let breakEvenRevenue = model.calculateBreakEvenRevenue()

        // Then: Break-even occurs when Gross Profit = Operating Expenses
        // Required Revenue * (1 - COGS%) = Operating Expenses
        // Required Revenue * 0.40 = $15,000
        // Required Revenue = $15,000 / 0.40 = $37,500
        #expect(abs(breakEvenRevenue - 37_500) < 1.0)
    }
}
