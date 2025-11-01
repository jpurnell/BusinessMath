//
//  MarketplaceModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for Marketplace business model template.
///
/// These tests define the expected behavior of a marketplace financial model,
/// including GMV, take rate, transaction metrics, and network effects.
final class MarketplaceModelTests: ModelTestCase {

    // MARK: - Basic Setup Tests

    func testMarketplaceModel_BasicSetup() {
        // Given: A basic marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // Then: The model should be initialized correctly
        XCTAssertEqual(model.initialBuyers, 10_000)
        XCTAssertEqual(model.initialSellers, 500)
        XCTAssertEqual(model.monthlyTransactionsPerBuyer, 2)
        XCTAssertEqual(model.averageOrderValue, 75)
        XCTAssertEqual(model.takeRate, 0.15)
    }

    // MARK: - GMV Tests

    func testMarketplaceModel_GMVCalculation() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating GMV for month 1
        let gmv = model.calculateGMV(forMonth: 1)

        // Then: GMV = Buyers * Transactions per Buyer * AOV
        // First, calculate buyers after month 1:
        // 10,000 - (10,000 * 0.05) + 1,000 = 10,500
        // GMV = 10,500 * 2 * $75 = $1,575,000
        XCTAssertEqual(gmv, 1_575_000, accuracy: 100.0)
    }

    // MARK: - Revenue Tests

    func testMarketplaceModel_RevenueCalculation() {
        // Given: A marketplace model with 15% take rate
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating revenue for month 1
        let revenue = model.calculateRevenue(forMonth: 1)

        // Then: Revenue = GMV * Take Rate
        // $1,575,000 * 0.15 = $236,250
        XCTAssertEqual(revenue, 236_250, accuracy: 100.0)
    }

    // MARK: - User Growth Tests

    func testMarketplaceModel_BuyerGrowth() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating buyers after month 1
        let buyers = model.calculateBuyers(forMonth: 1)

        // Then: Buyers = Initial - Churned + New
        // 10,000 - (10,000 * 0.05) + 1,000 = 10,500
        XCTAssertEqual(buyers, 10_500, accuracy: 1.0)
    }

    func testMarketplaceModel_SellerGrowth() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating sellers after month 1
        let sellers = model.calculateSellers(forMonth: 1)

        // Then: Sellers = Initial - Churned + New
        // 500 - (500 * 0.03) + 50 = 535
        XCTAssertEqual(sellers, 535, accuracy: 1.0)
    }

    // MARK: - Liquidity Tests

    func testMarketplaceModel_Liquidity() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating liquidity for month 1
        let liquidity = model.calculateLiquidity(forMonth: 1)

        // Then: Liquidity = Buyers / Sellers
        // 10,500 / 535 ≈ 19.6
        XCTAssertEqual(liquidity, 19.6, accuracy: 0.5)
    }

    // MARK: - Transaction Metrics Tests

    func testMarketplaceModel_TotalTransactions() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating total transactions for month 1
        let transactions = model.calculateTotalTransactions(forMonth: 1)

        // Then: Transactions = Buyers * Transactions per Buyer
        // 10,500 * 2 = 21,000
        XCTAssertEqual(transactions, 21_000, accuracy: 1.0)
    }

    func testMarketplaceModel_TransactionsPerSeller() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating transactions per seller for month 1
        let transactionsPerSeller = model.calculateTransactionsPerSeller(forMonth: 1)

        // Then: Transactions per Seller = Total Transactions / Sellers
        // 21,000 / 535 ≈ 39.3
        XCTAssertEqual(transactionsPerSeller, 39.3, accuracy: 1.0)
    }

    // MARK: - Seller Economics Tests

    func testMarketplaceModel_AverageSellerRevenue() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating average seller revenue for month 1
        let avgRevenue = model.calculateAverageSellerRevenue(forMonth: 1)

        // Then: Avg Seller Revenue = GMV / Sellers
        // $1,575,000 / 535 ≈ $2,944
        XCTAssertEqual(avgRevenue, 2_944, accuracy: 10.0)
    }

    // MARK: - Network Effects Tests

    func testMarketplaceModel_BuyerSellerRatio() {
        // Given: A marketplace with healthy buyer-to-seller ratio
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating buyer-seller ratio for month 1
        let ratio = model.calculateBuyerSellerRatio(forMonth: 1)

        // Then: Ratio = Buyers / Sellers
        // 10,500 / 535 ≈ 19.6
        XCTAssertEqual(ratio, 19.6, accuracy: 0.5)
    }

    // MARK: - Projection Tests

    func testMarketplaceModel_Projection12Months() {
        // Given: A marketplace model
        let model = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.15,
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Projecting 12 months
        let projection = model.project(months: 12)

        // Then: Should return projections for all 12 months
        XCTAssertEqual(projection.gmv.count, 12)
        XCTAssertEqual(projection.revenue.count, 12)
        XCTAssertEqual(projection.buyers.count, 12)
        XCTAssertEqual(projection.sellers.count, 12)

        // And: GMV should grow over time (net positive user growth)
        let firstMonthGMV = projection.gmv.valuesArray.first ?? 0
        let lastMonthGMV = projection.gmv.valuesArray.last ?? 0
        XCTAssertGreaterThan(lastMonthGMV, firstMonthGMV)
    }

    // MARK: - Take Rate Sensitivity Tests

    func testMarketplaceModel_TakeRateImpactOnRevenue() {
        // Given: Two models with different take rates
        let lowTakeRate = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.10,  // 10% take rate
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        let highTakeRate = MarketplaceModel(
            initialBuyers: 10_000,
            initialSellers: 500,
            monthlyTransactionsPerBuyer: 2,
            averageOrderValue: 75,
            takeRate: 0.20,  // 20% take rate
            newBuyersPerMonth: 1_000,
            newSellersPerMonth: 50,
            buyerChurnRate: 0.05,
            sellerChurnRate: 0.03
        )

        // When: Calculating revenue for month 1
        let lowRevenue = lowTakeRate.calculateRevenue(forMonth: 1)
        let highRevenue = highTakeRate.calculateRevenue(forMonth: 1)

        // Then: Higher take rate should produce proportionally more revenue
        // Low: $1,575,000 * 0.10 = $157,500
        // High: $1,575,000 * 0.20 = $315,000
        XCTAssertEqual(lowRevenue, 157_500, accuracy: 100.0)
        XCTAssertEqual(highRevenue, 315_000, accuracy: 100.0)
        XCTAssertEqual(highRevenue / lowRevenue, 2.0, accuracy: 0.1)
    }
}
