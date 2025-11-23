//
//  SaaSModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
import RealModule
@testable import BusinessMath

/// Tests for SaaS (Software as a Service) model template.
///
/// These tests define the expected behavior of a SaaS financial model,
/// including MRR, ARR, churn, LTV, CAC, and growth projections.
@Suite("SaaSModelTests") struct SaaSModelTests {

    // MARK: - Basic Setup Tests

    @Test("SaaSModel_BasicSetup") func LSaaSModel_BasicSetup() {
        // Given: A basic SaaS model with initial parameters
        let model = SaaSModel(
            initialMRR: 10_000,
            churnRate: 0.05,
            newCustomersPerMonth: 100,
            averageRevenuePerUser: 100
        )

        // Then: The model should be initialized correctly
        #expect(model.initialMRR == 10_000)
        #expect(model.churnRate == 0.05)
        #expect(model.newCustomersPerMonth == 100)
        #expect(model.averageRevenuePerUser == 100)
    }

    // MARK: - MRR Calculation Tests

    @Test("SaaSModel_MRRCalculation_FirstMonth") func LSaaSModel_MRRCalculation_FirstMonth() {
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
        #expect(abs(mrr - 19_500) < 1.0)
    }

    @Test("SaaSModel_MRRCalculation_MultipleMonths") func LSaaSModel_MRRCalculation_MultipleMonths() {
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
        #expect(mrrSeries.count == 12)
        #expect(mrrSeries.valuesArray.last ?? 0 > mrrSeries.valuesArray.first ?? 0)
    }

    // MARK: - ARR Calculation Tests

    @Test("SaaSModel_ARRCalculation") func LSaaSModel_ARRCalculation() {
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
        #expect(arr > 10_000 * 12)
    }

    // MARK: - Churn Impact Tests

    @Test("SaaSModel_ChurnImpact_HighChurn") func LSaaSModel_ChurnImpact_HighChurn() {
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
        #expect(lowChurnFinal > highChurnFinal)
    }

    @Test("SaaSModel_ChurnImpact_ZeroChurn") func LSaaSModel_ChurnImpact_ZeroChurn() {
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
        #expect(abs(mrr - 20_000) < 1.0)
    }

    // MARK: - Customer Growth Tests

    @Test("SaaSModel_CustomerGrowth") func LSaaSModel_CustomerGrowth() {
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
        #expect(customerCounts.count == 6)
        let firstMonth = customerCounts.valuesArray.first ?? 0
        let lastMonth = customerCounts.valuesArray.last ?? 0
        #expect(lastMonth > firstMonth)
    }

    // MARK: - LTV Calculation Tests

    @Test("SaaSModel_LTVCalculation") func LSaaSModel_LTVCalculation() {
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
        #expect(abs(ltv - 2_000) < 1.0)
    }

    @Test("SaaSModel_LTVCalculation_WithGrossMargin") func LSaaSModel_LTVCalculation_WithGrossMargin() {
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
        #expect(abs(ltv - 1_600) < 1.0)
    }

    // MARK: - CAC Payback Tests

    @Test("SaaSModel_CACPayback") func LSaaSModel_CACPayback() {
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
        #expect(abs(paybackMonths - 5.0) < 0.1)
    }

    // MARK: - Unit Economics Tests

    @Test("SaaSModel_UnitEconomics_LTVtoCAC") func LSaaSModel_UnitEconomics_LTVtoCAC() {
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
        #expect(abs(ltvToCACRatio - 4.0) < 0.1)
        #expect(ltvToCACRatio > 3.0, "LTV:CAC ratio should be > 3.0 for healthy unit economics")
    }

    // MARK: - Projection Tests

    @Test("SaaSModel_Projection36Months") func LSaaSModel_Projection36Months() {
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
        #expect(projection.mrr.count == 36)
        #expect(projection.revenue.count == 36)
        #expect(projection.customers.count == 36)

        // And: Values should be realistic
        let finalMRR = projection.mrr.valuesArray.last ?? 0
        #expect(finalMRR > 0)
    }

    // MARK: - Price Increase Tests

    @Test("SaaSModel_PriceIncrease") func LSaaSModel_PriceIncrease() {
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
        #expect(mrrAfterIncrease > mrrBeforeIncrease)
    }

    // MARK: - Negative Growth Scenario Tests

    @Test("SaaSModel_NegativeGrowth_HighChurnLowAcquisition") func LSaaSModel_NegativeGrowth_HighChurnLowAcquisition() {
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
        #expect(finalMRR < initialMRR, "MRR should decline with high churn and low acquisition")
    }
}
