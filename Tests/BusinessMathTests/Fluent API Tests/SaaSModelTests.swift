//
//  SaaSModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for SaaS (Software as a Service) model template.
///
/// These tests define the expected behavior of a SaaS financial model,
/// including MRR, ARR, churn, LTV, CAC, and growth projections.
final class SaaSModelTests: ModelTestCase {

    // MARK: - Basic Setup Tests

    func testSaaSModel_BasicSetup() {
        // Given: A basic SaaS model with initial parameters
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // Then: The model should be initialized correctly
        XCTAssertEqual(model.initialMRR, 10_000)
        XCTAssertEqual(model.churnRate, 0.05)
        XCTAssertEqual(model.newCustomersPerMonth, 100)
        XCTAssertEqual(model.averageRevenuePerUser, 100)
    }

    // MARK: - MRR Calculation Tests

    func testSaaSModel_MRRCalculation_FirstMonth() {
        // Given: A SaaS model with 100 customers at $100/month
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating MRR for the first month
        let mrr = model.calculateMRR(forMonth: 1)

        // Then: MRR should include initial customers + new customers - churned customers
        // Initial: 100 customers, New: 100, Churned: 100 * 0.05 = 5
        // Net: (100 - 5 + 100) * $100 = 195 * $100 = $19,500
        XCTAssertEqual(mrr, 19_500, accuracy: 1.0)
    }

    func testSaaSModel_MRRCalculation_MultipleMonths() {
        // Given: A SaaS model
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating MRR over 12 months
        let mrrSeries = model.projectMRR(months: 12)

        // Then: MRR should grow each month (assuming net positive growth)
        XCTAssertEqual(mrrSeries.count, 12)
        XCTAssertGreaterThan(mrrSeries.valuesArray.last ?? 0, mrrSeries.valuesArray.first ?? 0)
    }

    // MARK: - ARR Calculation Tests

    func testSaaSModel_ARRCalculation() {
        // Given: A SaaS model with known MRR
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating ARR
        let arr = model.calculateARR()

        // Then: ARR should be MRR * 12
        // With growth, this will be higher than initial MRR * 12
        XCTAssertGreaterThan(arr, 10_000 * 12)
    }

    // MARK: - Churn Impact Tests

    func testSaaSModel_ChurnImpact_HighChurn() {
        // Given: Two models with different churn rates
        let lowChurnModel = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.02,
            newCustomersPerMonth: 50,
            averageRevenuePerUser: 100
        )

        let highChurnModel = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.10,
            newCustomersPerMonth: 50,
            averageRevenuePerUser: 100
        )

        // When: Projecting 12 months
        let lowChurnMRR = lowChurnModel.projectMRR(months: 12)
        let highChurnMRR = highChurnModel.projectMRR(months: 12)

        // Then: Low churn should result in higher final MRR
        let lowChurnFinal = lowChurnMRR.valuesArray.last ?? 0
        let highChurnFinal = highChurnMRR.valuesArray.last ?? 0
        XCTAssertGreaterThan(lowChurnFinal, highChurnFinal)
    }

    func testSaaSModel_ChurnImpact_ZeroChurn() {
        // Given: A model with zero churn
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.0,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating MRR for month 1
        let mrr = model.calculateMRR(forMonth: 1)

        // Then: All initial customers should remain + new customers
        // (100 + 100) * $100 = $20,000
        XCTAssertEqual(mrr, 20_000, accuracy: 1.0)
    }

    // MARK: - Customer Growth Tests

    func testSaaSModel_CustomerGrowth() {
        // Given: A model with consistent new customer acquisition
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating customer count over time
        let customerCounts = model.projectCustomerCount(months: 6)

        // Then: Customer count should grow (net positive with these parameters)
        XCTAssertEqual(customerCounts.count, 6)
        let firstMonth = customerCounts.valuesArray.first ?? 0
        let lastMonth = customerCounts.valuesArray.last ?? 0
        XCTAssertGreaterThan(lastMonth, firstMonth)
    }

    // MARK: - LTV Calculation Tests

    func testSaaSModel_LTVCalculation() {
        // Given: A model with known parameters
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,  // 5% monthly churn
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Calculating customer lifetime value
        let ltv = model.calculateLTV()

        // Then: LTV should be ARPU / churn rate
        // $100 / 0.05 = $2,000
        XCTAssertEqual(ltv, 2_000, accuracy: 1.0)
    }

    func testSaaSModel_LTVCalculation_WithGrossMargin() {
        // Given: A model with gross margin specified
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100,
            grossMargin: 0.80  // 80% gross margin
        )

        // When: Calculating customer lifetime value
        let ltv = model.calculateLTV()

        // Then: LTV should be (ARPU * gross margin) / churn rate
        // ($100 * 0.80) / 0.05 = $1,600
        XCTAssertEqual(ltv, 1_600, accuracy: 1.0)
    }

    // MARK: - CAC Payback Tests

    func testSaaSModel_CACPayback() {
        // Given: A model with CAC specified
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100,
            customerAcquisitionCost: 500
        )

        // When: Calculating CAC payback period
        let paybackMonths = model.calculateCACPayback()

        // Then: Payback should be CAC / ARPU
        // $500 / $100 = 5 months
        XCTAssertEqual(paybackMonths, 5.0, accuracy: 0.1)
    }

    // MARK: - Unit Economics Tests

    func testSaaSModel_UnitEconomics_LTVtoCAC() {
        // Given: A model with both LTV and CAC
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100,
            customerAcquisitionCost: 500
        )

        // When: Calculating LTV:CAC ratio
        let ltvToCACRatio = model.calculateLTVtoCAC()

        // Then: LTV:CAC should be 2000 / 500 = 4.0 (healthy is > 3.0)
        XCTAssertEqual(ltvToCACRatio, 4.0, accuracy: 0.1)
        XCTAssertGreaterThan(ltvToCACRatio, 3.0, "LTV:CAC ratio should be > 3.0 for healthy unit economics")
    }

    // MARK: - Projection Tests

    func testSaaSModel_Projection36Months() {
        // Given: A SaaS model
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // When: Projecting 36 months
        let projection = model.project(months: 36)

        // Then: Should return projections for all 36 months
        XCTAssertEqual(projection.mrr.count, 36)
        XCTAssertEqual(projection.revenue.count, 36)
        XCTAssertEqual(projection.customers.count, 36)

        // And: Values should be realistic
        let finalMRR = projection.mrr.valuesArray.last ?? 0
        XCTAssertGreaterThan(finalMRR, 0)
    }

    // MARK: - Price Increase Tests

    func testSaaSModel_PriceIncrease() {
        // Given: A model with a price increase in year 2
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100,
            priceIncreases: [
                (month: 12, percentage: 0.05)  // 5% increase in month 12
            ]
        )

        // When: Calculating MRR before and after price increase
        let mrrBeforeIncrease = model.calculateMRR(forMonth: 11)
        let mrrAfterIncrease = model.calculateMRR(forMonth: 13)

        // Then: MRR after increase should be higher (accounting for price increase effect)
        XCTAssertGreaterThan(mrrAfterIncrease, mrrBeforeIncrease)
    }

    // MARK: - Negative Growth Scenario Tests

    func testSaaSModel_NegativeGrowth_HighChurnLowAcquisition() {
        // Given: A model with high churn and low acquisition
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.15,  // 15% monthly churn - very high!
            newCustomersPerMonth: 10,  // Only 10 new customers
            averageRevenuePerUser: 100
        )

        // When: Projecting 12 months
        let projection = model.projectMRR(months: 12)

        // Then: MRR should decline over time
        let initialMRR = projection.valuesArray.first ?? 0
        let finalMRR = projection.valuesArray.last ?? 0
        XCTAssertLessThan(finalMRR, initialMRR, "MRR should decline with high churn and low acquisition")
    }
}
