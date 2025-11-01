//
//  RetailModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for Retail business model template.
///
/// These tests define the expected behavior of a retail financial model,
/// including inventory management, COGS, gross margin, turnover, and seasonal demand.
final class RetailModelTests: ModelTestCase {

    // MARK: - Basic Setup Tests

    func testRetailModel_BasicSetup() {
        // Given: A basic retail model with initial parameters
        let model = RetailModel(
            initialInventoryValue: 100_000,
            monthlyRevenue: 50_000,
            costOfGoodsSoldPercentage: 0.60,
            operatingExpenses: 15_000
        )

        // Then: The model should be initialized correctly
        XCTAssertEqual(model.initialInventoryValue, 100_000)
        XCTAssertEqual(model.monthlyRevenue, 50_000)
        XCTAssertEqual(model.costOfGoodsSoldPercentage, 0.60)
        XCTAssertEqual(model.operatingExpenses, 15_000)
    }

    // MARK: - COGS and Gross Margin Tests

    func testRetailModel_COGSCalculation() {
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
        XCTAssertEqual(cogs, 30_000, accuracy: 1.0)
    }

    func testRetailModel_GrossMarginCalculation() {
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
        XCTAssertEqual(grossMargin, 0.40, accuracy: 0.01)
    }

    func testRetailModel_GrossProfitCalculation() {
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
        XCTAssertEqual(grossProfit, 20_000, accuracy: 1.0)
    }

    // MARK: - Inventory Turnover Tests

    func testRetailModel_InventoryTurnoverCalculation() {
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
        XCTAssertEqual(turnover, 3.6, accuracy: 0.1)
    }

    func testRetailModel_DaysInventoryOutstanding() {
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
        XCTAssertEqual(dio, 101.4, accuracy: 1.0)
    }

    // MARK: - Net Profit Tests

    func testRetailModel_NetProfitCalculation() {
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
        XCTAssertEqual(netProfit, 5_000, accuracy: 1.0)
    }

    func testRetailModel_NetProfitMargin() {
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
        XCTAssertEqual(netProfitMargin, 0.10, accuracy: 0.01)
    }

    // MARK: - Seasonal Demand Tests

    func testRetailModel_SeasonalRevenue() {
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
        XCTAssertEqual(normalMonthRevenue, 50_000, accuracy: 1.0)
        XCTAssertEqual(novemberRevenue, 75_000, accuracy: 1.0)  // $50,000 * 1.5
        XCTAssertEqual(decemberRevenue, 100_000, accuracy: 1.0)  // $50,000 * 2.0
    }

    // MARK: - Projection Tests

    func testRetailModel_Projection12Months() {
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
        XCTAssertEqual(projection.revenue.count, 12)
        XCTAssertEqual(projection.grossProfit.count, 12)
        XCTAssertEqual(projection.netProfit.count, 12)

        // And: Values should be consistent with inputs
        let firstMonthRevenue = projection.revenue.valuesArray.first ?? 0
        XCTAssertEqual(firstMonthRevenue, 50_000, accuracy: 1.0)
    }

    // MARK: - Markup Tests

    func testRetailModel_MarkupCalculation() {
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
        XCTAssertEqual(markup, 0.667, accuracy: 0.01)
    }

    // MARK: - Break-Even Tests

    func testRetailModel_BreakEvenRevenue() {
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
        XCTAssertEqual(breakEvenRevenue, 37_500, accuracy: 1.0)
    }
}
