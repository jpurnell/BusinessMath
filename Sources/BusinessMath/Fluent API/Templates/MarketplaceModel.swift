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

    // Snapshot model properties (for simplified usage)

    /// Total number of buyers (snapshot model only).
    ///
    /// Used when modeling a static marketplace state rather than growth over time.
    /// `nil` for growth-based models.
    public let numberOfBuyers: Double?

    /// Total number of sellers (snapshot model only).
    ///
    /// Used when modeling a static marketplace state rather than growth over time.
    /// `nil` for growth-based models.
    public let numberOfSellers: Double?

    /// Total transactions per month (snapshot model only).
    ///
    /// Used when modeling a static marketplace state rather than growth over time.
    /// `nil` for growth-based models.
    public let transactionsPerMonth: Double?

    /// Cost to acquire each buyer (snapshot model only).
    ///
    /// Used for CAC calculations in snapshot models.
    /// `nil` for growth-based models.
    public let buyerAcquisitionCost: Double?

    /// Cost to acquire each seller (snapshot model only).
    ///
    /// Used for CAC calculations in snapshot models.
    /// `nil` for growth-based models.
    public let sellerAcquisitionCost: Double?

    // MARK: - Initialization

    /// Creates a marketplace model with growth-over-time parameters.
    ///
    /// Use this initializer to model marketplace dynamics with buyer/seller acquisition,
    /// churn, and transaction patterns evolving over time.
    ///
    /// - Parameters:
    ///   - initialBuyers: Starting number of buyers
    ///   - initialSellers: Starting number of sellers
    ///   - monthlyTransactionsPerBuyer: Average transactions per buyer per month
    ///   - averageOrderValue: Average transaction value (GMV per transaction)
    ///   - takeRate: Platform commission rate (e.g., 0.15 for 15%)
    ///   - newBuyersPerMonth: Buyer acquisition rate per month
    ///   - newSellersPerMonth: Seller acquisition rate per month
    ///   - buyerChurnRate: Monthly buyer churn rate (e.g., 0.05 for 5%)
    ///   - sellerChurnRate: Monthly seller churn rate (e.g., 0.03 for 3%)
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

        // Snapshot properties not used in this initializer
        self.numberOfBuyers = nil
        self.numberOfSellers = nil
        self.transactionsPerMonth = nil
        self.buyerAcquisitionCost = nil
        self.sellerAcquisitionCost = nil
    }

    /// Simplified snapshot initializer for marketplace models.
    ///
    /// Use this when you have a static snapshot of marketplace state
    /// rather than tracking growth over time.
    ///
    /// Example:
    /// ```swift
    /// let model = MarketplaceModel(
    ///     numberOfBuyers: 10_000,
    ///     numberOfSellers: 1_000,
    ///     transactionsPerMonth: 5_000,
    ///     averageOrderValue: 150,
    ///     takeRate: 0.15,
    ///     buyerAcquisitionCost: 25,
    ///     sellerAcquisitionCost: 100
    /// )
    /// ```
    public init(
        numberOfBuyers: Double,
        numberOfSellers: Double,
        transactionsPerMonth: Double,
        averageOrderValue: Double,
        takeRate: Double,
        buyerAcquisitionCost: Double,
        sellerAcquisitionCost: Double
    ) {
        self.numberOfBuyers = numberOfBuyers
        self.numberOfSellers = numberOfSellers
        self.transactionsPerMonth = transactionsPerMonth
        self.averageOrderValue = averageOrderValue
        self.takeRate = takeRate
        self.buyerAcquisitionCost = buyerAcquisitionCost
        self.sellerAcquisitionCost = sellerAcquisitionCost

        // Calculate derived values for growth model properties
        self.initialBuyers = numberOfBuyers
        self.initialSellers = numberOfSellers
        self.monthlyTransactionsPerBuyer = transactionsPerMonth / numberOfBuyers
        self.newBuyersPerMonth = 0
        self.newSellersPerMonth = 0
        self.buyerChurnRate = 0
        self.sellerChurnRate = 0
    }

    // MARK: - User Calculations

    /// Get current buyer count.
    ///
    /// For snapshot models, returns numberOfBuyers.
    /// For growth models, returns initialBuyers.
    ///
    /// - Returns: Current buyer count
    public var currentBuyers: Double {
        return numberOfBuyers ?? initialBuyers
    }

    /// Get current seller count.
    ///
    /// For snapshot models, returns numberOfSellers.
    /// For growth models, returns initialSellers.
    ///
    /// - Returns: Current seller count
    public var currentSellers: Double {
        return numberOfSellers ?? initialSellers
    }

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

    /// Calculate Gross Merchandise Value using snapshot data.
    ///
    /// GMV = Transactions per Month × Average Order Value
    ///
    /// - Returns: GMV for current state, or 0 if using growth model
    public func calculateGMV() -> Double {
        guard let transactions = transactionsPerMonth else { return 0 }
        return transactions * averageOrderValue
    }

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

    /// Calculate platform revenue using snapshot data.
    ///
    /// Revenue = GMV × Take Rate
    ///
    /// - Returns: Platform revenue for current state
    public func calculateRevenue() -> Double {
        let gmv = calculateGMV()
        return gmv * takeRate
    }

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

    /// Calculate buyer-seller ratio using snapshot data.
    ///
    /// - Returns: Buyer-seller ratio, or 0 if using growth model
    public func calculateBuyerSellerRatio() -> Double {
        guard let buyers = numberOfBuyers, let sellers = numberOfSellers else { return 0 }
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
