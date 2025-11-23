//
//  MarketplaceModelTests.swift
//  BusinessMath Tests
//
//  Created on October 31, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Testing
import RealModule
@testable import BusinessMath

/// Tests for Marketplace business model template.
///
/// These tests define the expected behavior of a marketplace financial model,
/// including GMV, take rate, transaction metrics, and network effects.
@Suite("MarketplaceModelTests") struct MarketplaceModelTests {

    // MARK: - Basic Setup Tests

    @Test("MarketplaceModel_BasicSetup") func LMarketplaceModel_BasicSetup() {
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
        #expect(model.initialBuyers == 10_000)
        #expect(model.initialSellers == 500)
        #expect(model.monthlyTransactionsPerBuyer == 2)
        #expect(model.averageOrderValue == 75)
        #expect(model.takeRate == 0.15)
    }

    // MARK: - GMV Tests

    @Test("MarketplaceModel_GMVCalculation") func LMarketplaceModel_GMVCalculation() {
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
        #expect(abs(gmv - 1_575_000) < 100.0)
    }

    // MARK: - Revenue Tests

    @Test("MarketplaceModel_RevenueCalculation") func LMarketplaceModel_RevenueCalculation() {
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
        #expect(abs(revenue - 236_250) < 100.0)
    }

    // MARK: - User Growth Tests

    @Test("MarketplaceModel_BuyerGrowth") func LMarketplaceModel_BuyerGrowth() {
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
        #expect(abs(buyers - 10_500) < 1.0)
    }

    @Test("MarketplaceModel_SellerGrowth") func LMarketplaceModel_SellerGrowth() {
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
        #expect(abs(sellers - 535) < 1.0)
    }

    // MARK: - Liquidity Tests

    @Test("MarketplaceModel_Liquidity") func LMarketplaceModel_Liquidity() {
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
        #expect(abs(liquidity - 19.6) < 0.5)
    }

    // MARK: - Transaction Metrics Tests

    @Test("MarketplaceModel_TotalTransactions") func LMarketplaceModel_TotalTransactions() {
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
        #expect(abs(transactions - 21_000) < 1.0)
    }

    @Test("MarketplaceModel_TransactionsPerSeller") func LMarketplaceModel_TransactionsPerSeller() {
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
        #expect(abs(transactionsPerSeller - 39.3) < 1.0)
    }

    // MARK: - Seller Economics Tests

    @Test("MarketplaceModel_AverageSellerRevenue") func LMarketplaceModel_AverageSellerRevenue() {
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
        #expect(abs(avgRevenue - 2_944) < 10.0)
    }

    // MARK: - Network Effects Tests

    @Test("MarketplaceModel_BuyerSellerRatio") func LMarketplaceModel_BuyerSellerRatio() {
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
        #expect(abs(ratio - 19.6) < 0.5)
    }

    // MARK: - Projection Tests

    @Test("MarketplaceModel_Projection12Months") func LMarketplaceModel_Projection12Months() {
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
        #expect(projection.gmv.count == 12)
        #expect(projection.revenue.count == 12)
        #expect(projection.buyers.count == 12)
        #expect(projection.sellers.count == 12)

        // And: GMV should grow over time (net positive user growth)
        let firstMonthGMV = projection.gmv.valuesArray.first ?? 0
        let lastMonthGMV = projection.gmv.valuesArray.last ?? 0
        #expect(lastMonthGMV > firstMonthGMV)
    }

    // MARK: - Take Rate Sensitivity Tests

    @Test("MarketplaceModel_TakeRateImpactOnRevenue") func LMarketplaceModel_TakeRateImpactOnRevenue() {
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
        #expect(abs(lowRevenue - 157_500) < 100.0)
        #expect(abs(highRevenue - 315_000) < 100.0)
        #expect(abs(highRevenue / lowRevenue - 2.0) < 0.1)
    }
}
