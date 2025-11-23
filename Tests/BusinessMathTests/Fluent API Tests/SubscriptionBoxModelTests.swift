//
//  SubscriptionBoxModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
import RealModule
@testable import BusinessMath

/// Tests for Subscription Box business model template.
///
/// These tests define the expected behavior of a subscription box financial model,
/// including subscriber metrics, box costs, fulfillment, churn, and LTV.
@Suite("SubscriptionBoxModelTests") struct SubscriptionBoxModelTests {

    // MARK: - Basic Setup Tests

    @Test("SubscriptionBoxModel_BasicSetup") func LSubscriptionBoxModel_BasicSetup() {
        // Given: A basic subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // Then: The model should be initialized correctly
        #expect(model.initialSubscribers == 1_000)
        #expect(model.monthlyBoxPrice == 49.99)
        #expect(model.costOfGoodsPerBox == 20)
        #expect(model.shippingCostPerBox == 5)
        #expect(model.monthlyChurnRate == 0.08)
        #expect(model.newSubscribersPerMonth == 150)
        #expect(model.customerAcquisitionCost == 40)
    }

    // MARK: - Subscriber Growth Tests

    @Test("SubscriptionBoxModel_SubscriberCount_FirstMonth") func LSubscriptionBoxModel_SubscriberCount_FirstMonth() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating subscribers after month 1
        let subscribers = model.calculateSubscribers(forMonth: 1)

        // Then: Subscribers = Initial - Churned + New
        // 1,000 - (1,000 * 0.08) + 150 = 1,000 - 80 + 150 = 1,070
        #expect(abs(subscribers - 1_070) < 1.0)
    }

    @Test("SubscriptionBoxModel_SubscriberGrowth_12Months") func LSubscriptionBoxModel_SubscriberGrowth_12Months() {
        // Given: A subscription box model with net positive growth
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.05,  // Lower churn for growth
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Projecting 12 months
        let projection = model.projectSubscribers(months: 12)

        // Then: Subscribers should grow over time
        let firstMonth = projection.valuesArray.first ?? 0
        let lastMonth = projection.valuesArray.last ?? 0
        #expect(lastMonth > firstMonth)
    }

    // MARK: - Revenue Tests

    @Test("SubscriptionBoxModel_MonthlyRevenue") func LSubscriptionBoxModel_MonthlyRevenue() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating revenue for month 1
        let revenue = model.calculateRevenue(forMonth: 1)

        // Then: Revenue = Subscribers * Box Price
        // 1,070 * $49.99 ≈ $53,489
        #expect(abs(revenue - 53_489) < 10.0)
    }

    // MARK: - Cost Tests

    @Test("SubscriptionBoxModel_FulfillmentCostPerBox") func LSubscriptionBoxModel_FulfillmentCostPerBox() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating fulfillment cost per box
        let cost = model.calculateFulfillmentCostPerBox()

        // Then: Fulfillment = COGS + Shipping
        // $20 + $5 = $25
        #expect(abs(cost - 25) < 0.1)
    }

    @Test("SubscriptionBoxModel_TotalMonthlyCosts") func LSubscriptionBoxModel_TotalMonthlyCosts() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating total costs for month 1
        let costs = model.calculateTotalCosts(forMonth: 1)

        // Then: Costs = (Fulfillment * Subscribers) + (CAC * New Subscribers)
        // ($25 * 1,070) + ($40 * 150) = $26,750 + $6,000 = $32,750
        #expect(abs(costs - 32_750) < 10.0)
    }

    // MARK: - Gross Margin Tests

    @Test("SubscriptionBoxModel_GrossMarginPerBox") func LSubscriptionBoxModel_GrossMarginPerBox() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating gross margin per box
        let margin = model.calculateGrossMarginPerBox()

        // Then: Margin = Price - COGS - Shipping
        // $49.99 - $20 - $5 = $24.99
        #expect(abs(margin - 24.99) < 0.01)
    }

    @Test("SubscriptionBoxModel_GrossMarginPercentage") func LSubscriptionBoxModel_GrossMarginPercentage() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating gross margin percentage
        let percentage = model.calculateGrossMarginPercentage()

        // Then: Margin % = Gross Margin / Price
        // $24.99 / $49.99 ≈ 0.50 (50%)
        #expect(abs(percentage - 0.50) < 0.01)
    }

    // MARK: - LTV Tests

    @Test("SubscriptionBoxModel_CustomerLifetimeValue") func LSubscriptionBoxModel_CustomerLifetimeValue() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating LTV
        let ltv = model.calculateCustomerLifetimeValue()

        // Then: LTV = Gross Margin per Box / Churn Rate
        // $24.99 / 0.08 ≈ $312.38
        #expect(abs(ltv - 312.38) < 1.0)
    }

    // MARK: - Unit Economics Tests

    @Test("SubscriptionBoxModel_LTVtoCAC") func LSubscriptionBoxModel_LTVtoCAC() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating LTV:CAC ratio
        let ratio = model.calculateLTVtoCAC()

        // Then: LTV:CAC = $312.38 / $40 ≈ 7.81
        #expect(abs(ratio - 7.81) < 0.1)
        #expect(ratio > 3.0, "Healthy LTV:CAC should be > 3.0")
    }

    @Test("SubscriptionBoxModel_CACPaybackMonths") func LSubscriptionBoxModel_CACPaybackMonths() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating CAC payback period
        let months = model.calculateCACPaybackMonths()

        // Then: Payback = CAC / Gross Margin per Box
        // $40 / $24.99 ≈ 1.6 months
        #expect(abs(months - 1.6) < 0.1)
    }

    // MARK: - Profit Tests

    @Test("SubscriptionBoxModel_MonthlyProfit") func LSubscriptionBoxModel_MonthlyProfit() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating profit for month 1
        let profit = model.calculateProfit(forMonth: 1)

        // Then: Profit = Revenue - Total Costs
        // $53,489 - $32,750 ≈ $20,739
        #expect(abs(profit - 20_739) < 50.0)
    }

    // MARK: - Projection Tests

    @Test("SubscriptionBoxModel_Projection12Months") func LSubscriptionBoxModel_Projection12Months() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Projecting 12 months
        let projection = model.project(months: 12)

        // Then: Should return projections for all 12 months
        #expect(projection.subscribers.count == 12)
        #expect(projection.revenue.count == 12)
        #expect(projection.profit.count == 12)
    }

    // MARK: - Retention Tests

    @Test("SubscriptionBoxModel_RetentionRate") func LSubscriptionBoxModel_RetentionRate() {
        // Given: A subscription box model
        let model = SubscriptionBoxModel(
            initialSubscribers: 1_000,
            monthlyBoxPrice: 49.99,
            costOfGoodsPerBox: 20,
            shippingCostPerBox: 5,
            monthlyChurnRate: 0.08,
            newSubscribersPerMonth: 150,
            customerAcquisitionCost: 40
        )

        // When: Calculating retention rate
        let retention = model.calculateRetentionRate()

        // Then: Retention = 1 - Churn Rate
        // 1 - 0.08 = 0.92 (92%)
        #expect(abs(retention - 0.92) < 0.01)
    }
}
