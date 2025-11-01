//
//  MarketplaceModel.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

/// A financial model template for Marketplace businesses.
///
/// This model handles key marketplace metrics including:
/// - Gross Merchandise Value (GMV)
/// - Take rate and platform revenue
/// - Buyer and seller growth
/// - Transaction metrics
/// - Liquidity ratios
/// - Network effects
/// - Seller economics
///
/// Example:
/// ```swift
/// let model = MarketplaceModel(
///     initialBuyers: 10_000,
///     initialSellers: 500,
///     monthlyTransactionsPerBuyer: 2,
///     averageOrderValue: 75,
///     takeRate: 0.15,
///     newBuyersPerMonth: 1_000,
///     newSellersPerMonth: 50,
///     buyerChurnRate: 0.05,
///     sellerChurnRate: 0.03
/// )
///
/// let gmv = model.calculateGMV(forMonth: 1)
/// let liquidity = model.calculateLiquidity(forMonth: 1)
/// let projection = model.project(months: 12)
/// ```
public struct MarketplaceModel: Sendable {
    // MARK: - Properties

    /// Initial number of buyers
    public let initialBuyers: Double

    /// Initial number of sellers
    public let initialSellers: Double

    /// Average transactions per buyer per month
    public let monthlyTransactionsPerBuyer: Double

    /// Average order value (AOV)
    public let averageOrderValue: Double

    /// Take rate (commission percentage)
    public let takeRate: Double

    /// New buyers acquired per month
    public let newBuyersPerMonth: Double

    /// New sellers onboarded per month
    public let newSellersPerMonth: Double

    /// Monthly buyer churn rate
    public let buyerChurnRate: Double

    /// Monthly seller churn rate
    public let sellerChurnRate: Double

    // MARK: - Initialization

    public init(
        initialBuyers: Double,
        initialSellers: Double,
        monthlyTransactionsPerBuyer: Double,
        averageOrderValue: Double,
        takeRate: Double,
        newBuyersPerMonth: Double,
        newSellersPerMonth: Double,
        buyerChurnRate: Double,
        sellerChurnRate: Double
    ) {
        self.initialBuyers = initialBuyers
        self.initialSellers = initialSellers
        self.monthlyTransactionsPerBuyer = monthlyTransactionsPerBuyer
        self.averageOrderValue = averageOrderValue
        self.takeRate = takeRate
        self.newBuyersPerMonth = newBuyersPerMonth
        self.newSellersPerMonth = newSellersPerMonth
        self.buyerChurnRate = buyerChurnRate
        self.sellerChurnRate = sellerChurnRate
    }

    // MARK: - User Calculations

    /// Calculate buyer count for a specific month.
    ///
    /// - Parameter month: The month to calculate (1-indexed)
    /// - Returns: Number of buyers at the end of the month
    public func calculateBuyers(forMonth month: Int) -> Double {
        var buyers = initialBuyers

        for _ in 1...month {
            let churnedBuyers = buyers * buyerChurnRate
            buyers = buyers - churnedBuyers + newBuyersPerMonth
        }

        return buyers
    }

    /// Calculate seller count for a specific month.
    ///
    /// - Parameter month: The month to calculate (1-indexed)
    /// - Returns: Number of sellers at the end of the month
    public func calculateSellers(forMonth month: Int) -> Double {
        var sellers = initialSellers

        for _ in 1...month {
            let churnedSellers = sellers * sellerChurnRate
            sellers = sellers - churnedSellers + newSellersPerMonth
        }

        return sellers
    }

    // MARK: - GMV Calculations

    /// Calculate Gross Merchandise Value for a specific month.
    ///
    /// GMV = Buyers × Transactions per Buyer × Average Order Value
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: GMV for the specified month
    public func calculateGMV(forMonth month: Int) -> Double {
        let buyers = calculateBuyers(forMonth: month)
        let transactions = buyers * monthlyTransactionsPerBuyer
        return transactions * averageOrderValue
    }

    // MARK: - Revenue Calculations

    /// Calculate platform revenue for a specific month.
    ///
    /// Revenue = GMV × Take Rate
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Platform revenue for the specified month
    public func calculateRevenue(forMonth month: Int) -> Double {
        let gmv = calculateGMV(forMonth: month)
        return gmv * takeRate
    }

    // MARK: - Transaction Metrics

    /// Calculate total number of transactions for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Total transactions
    public func calculateTotalTransactions(forMonth month: Int) -> Double {
        let buyers = calculateBuyers(forMonth: month)
        return buyers * monthlyTransactionsPerBuyer
    }

    /// Calculate average transactions per seller for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Transactions per seller
    public func calculateTransactionsPerSeller(forMonth month: Int) -> Double {
        let totalTransactions = calculateTotalTransactions(forMonth: month)
        let sellers = calculateSellers(forMonth: month)
        return totalTransactions / sellers
    }

    // MARK: - Seller Economics

    /// Calculate average revenue per seller for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Average revenue per seller
    public func calculateAverageSellerRevenue(forMonth month: Int) -> Double {
        let gmv = calculateGMV(forMonth: month)
        let sellers = calculateSellers(forMonth: month)
        return gmv / sellers
    }

    // MARK: - Liquidity Metrics

    /// Calculate marketplace liquidity for a specific month.
    ///
    /// Liquidity = Buyers / Sellers
    ///
    /// Higher liquidity indicates more buyers per seller, which generally
    /// improves seller success and retention.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Liquidity ratio
    public func calculateLiquidity(forMonth month: Int) -> Double {
        let buyers = calculateBuyers(forMonth: month)
        let sellers = calculateSellers(forMonth: month)
        return buyers / sellers
    }

    /// Calculate buyer-seller ratio for a specific month.
    ///
    /// This is the same as liquidity, but provided as a separate method
    /// for clarity in certain contexts.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Buyer-seller ratio
    public func calculateBuyerSellerRatio(forMonth month: Int) -> Double {
        return calculateLiquidity(forMonth: month)
    }

    // MARK: - Comprehensive Projections

    /// Project GMV, revenue, buyers, and sellers over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Tuple containing time series for GMV, revenue, buyers, and sellers
    public func project(months: Int) -> (
        gmv: TimeSeries<Double>,
        revenue: TimeSeries<Double>,
        buyers: TimeSeries<Double>,
        sellers: TimeSeries<Double>
    ) {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }

        let gmvValues = (1...months).map { calculateGMV(forMonth: $0) }
        let revenueValues = (1...months).map { calculateRevenue(forMonth: $0) }
        let buyerValues = (1...months).map { calculateBuyers(forMonth: $0) }
        let sellerValues = (1...months).map { calculateSellers(forMonth: $0) }

        return (
            gmv: TimeSeries(periods: periods, values: gmvValues),
            revenue: TimeSeries(periods: periods, values: revenueValues),
            buyers: TimeSeries(periods: periods, values: buyerValues),
            sellers: TimeSeries(periods: periods, values: sellerValues)
        )
    }
}
