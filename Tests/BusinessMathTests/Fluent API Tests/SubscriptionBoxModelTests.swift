//
//  SubscriptionBoxModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for Subscription Box business model template.
///
/// These tests define the expected behavior of a subscription box financial model,
/// including subscriber metrics, box costs, fulfillment, churn, and LTV.
final class SubscriptionBoxModelTests: ModelTestCase {

    // MARK: - Basic Setup Tests

    func testSubscriptionBoxModel_BasicSetup() {
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
        XCTAssertEqual(model.initialSubscribers, 1_000)
        XCTAssertEqual(model.monthlyBoxPrice, 49.99)
        XCTAssertEqual(model.costOfGoodsPerBox, 20)
        XCTAssertEqual(model.shippingCostPerBox, 5)
        XCTAssertEqual(model.monthlyChurnRate, 0.08)
        XCTAssertEqual(model.newSubscribersPerMonth, 150)
        XCTAssertEqual(model.customerAcquisitionCost, 40)
    }

    // MARK: - Subscriber Growth Tests

    func testSubscriptionBoxModel_SubscriberCount_FirstMonth() {
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
        XCTAssertEqual(subscribers, 1_070, accuracy: 1.0)
    }

    func testSubscriptionBoxModel_SubscriberGrowth_12Months() {
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
        XCTAssertGreaterThan(lastMonth, firstMonth)
    }

    // MARK: - Revenue Tests

    func testSubscriptionBoxModel_MonthlyRevenue() {
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
        XCTAssertEqual(revenue, 53_489, accuracy: 10.0)
    }

    // MARK: - Cost Tests

    func testSubscriptionBoxModel_FulfillmentCostPerBox() {
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
        XCTAssertEqual(cost, 25, accuracy: 0.1)
    }

    func testSubscriptionBoxModel_TotalMonthlyCosts() {
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
        XCTAssertEqual(costs, 32_750, accuracy: 10.0)
    }

    // MARK: - Gross Margin Tests

    func testSubscriptionBoxModel_GrossMarginPerBox() {
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
        XCTAssertEqual(margin, 24.99, accuracy: 0.01)
    }

    func testSubscriptionBoxModel_GrossMarginPercentage() {
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
        XCTAssertEqual(percentage, 0.50, accuracy: 0.01)
    }

    // MARK: - LTV Tests

    func testSubscriptionBoxModel_CustomerLifetimeValue() {
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
        XCTAssertEqual(ltv, 312.38, accuracy: 1.0)
    }

    // MARK: - Unit Economics Tests

    func testSubscriptionBoxModel_LTVtoCAC() {
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
        XCTAssertEqual(ratio, 7.81, accuracy: 0.1)
        XCTAssertGreaterThan(ratio, 3.0, "Healthy LTV:CAC should be > 3.0")
    }

    func testSubscriptionBoxModel_CACPaybackMonths() {
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
        XCTAssertEqual(months, 1.6, accuracy: 0.1)
    }

    // MARK: - Profit Tests

    func testSubscriptionBoxModel_MonthlyProfit() {
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
        XCTAssertEqual(profit, 20_739, accuracy: 50.0)
    }

    // MARK: - Projection Tests

    func testSubscriptionBoxModel_Projection12Months() {
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
        XCTAssertEqual(projection.subscribers.count, 12)
        XCTAssertEqual(projection.revenue.count, 12)
        XCTAssertEqual(projection.profit.count, 12)
    }

    // MARK: - Retention Tests

    func testSubscriptionBoxModel_RetentionRate() {
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
        XCTAssertEqual(retention, 0.92, accuracy: 0.01)
    }
}
