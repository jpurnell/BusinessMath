//
//  RetailModel.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

/// A financial model template for Retail businesses.
///
/// This model handles key retail metrics including:
/// - Cost of Goods Sold (COGS)
/// - Gross margin and gross profit
/// - Inventory turnover and days inventory outstanding
/// - Net profit and margins
/// - Seasonal demand patterns
/// - Markup calculations
/// - Break-even analysis
///
/// Example:
/// ```swift
/// let model = RetailModel(
///     initialInventoryValue: 100_000,
///     monthlyRevenue: 50_000,
///     costOfGoodsSoldPercentage: 0.60,
///     operatingExpenses: 15_000
/// )
///
/// let turnover = model.calculateInventoryTurnover()
/// let breakEven = model.calculateBreakEvenRevenue()
/// let projection = model.project(months: 12)
/// ```
public struct RetailModel: Sendable {
    // MARK: - Properties

    /// Initial inventory value
    public let initialInventoryValue: Double

    /// Monthly revenue (baseline, before seasonal adjustments)
    public let monthlyRevenue: Double

    /// Cost of Goods Sold as a percentage of revenue
    public let costOfGoodsSoldPercentage: Double

    /// Monthly operating expenses (rent, salaries, utilities, etc.)
    public let operatingExpenses: Double

    /// Seasonal multipliers by month (1-12)
    public let seasonalMultipliers: [Int: Double]

    // Store-level properties (optional, for multi-store models)
    /// Number of retail store locations
    public let numberOfStores: Int?
    /// Average monthly revenue per store
    public let averageStoreRevenue: Double?
    /// Same-store sales growth rate (comp store growth)
    public let sameStoreSalesGrowth: Double?
    /// Average monthly customer visits per store
    public let footTraffic: Double?
    /// Percentage of visitors who make a purchase
    public let conversionRate: Double?
    /// Average transaction value
    public let averageTransaction: Double?

    // MARK: - Initialization

    /// Creates a retail model with baseline financial parameters.
    /// - Parameters:
    ///   - initialInventoryValue: Starting inventory value
    ///   - monthlyRevenue: Baseline monthly revenue before seasonal adjustments
    ///   - costOfGoodsSoldPercentage: COGS as percentage of revenue (e.g., 0.60 for 60%)
    ///   - operatingExpenses: Monthly operating expenses (rent, salaries, utilities)
    ///   - seasonalMultipliers: Optional multipliers by month (1-12) for seasonal variations (default: empty)
    public init(
        initialInventoryValue: Double,
        monthlyRevenue: Double,
        costOfGoodsSoldPercentage: Double,
        operatingExpenses: Double,
        seasonalMultipliers: [Int: Double] = [:]
    ) {
        self.initialInventoryValue = initialInventoryValue
        self.monthlyRevenue = monthlyRevenue
        self.costOfGoodsSoldPercentage = costOfGoodsSoldPercentage
        self.operatingExpenses = operatingExpenses
        self.seasonalMultipliers = seasonalMultipliers

        // Store-level properties not used in this initializer
        self.numberOfStores = nil
        self.averageStoreRevenue = nil
        self.sameStoreSalesGrowth = nil
        self.footTraffic = nil
        self.conversionRate = nil
        self.averageTransaction = nil
    }

    /// Store-focused initializer for multi-location retail businesses.
    ///
    /// This initializer calculates aggregate values from store-level metrics.
    ///
    /// - Parameters:
    ///   - numberOfStores: Number of retail locations
    ///   - averageStoreRevenue: Average monthly revenue per store
    ///   - sameStoreSalesGrowth: Same-store sales growth rate (comp store growth)
    ///   - footTraffic: Average monthly customer visits per store
    ///   - conversionRate: Percentage of visitors who make a purchase
    ///   - averageTransaction: Average transaction value
    ///   - costOfGoodsSold: COGS as percentage of revenue
    ///   - operatingExpensesPerStore: Monthly operating expenses per store
    public init(
        numberOfStores: Int,
        averageStoreRevenue: Double,
        sameStoreSalesGrowth: Double,
        footTraffic: Double,
        conversionRate: Double,
        averageTransaction: Double,
        costOfGoodsSold: Double,
        operatingExpensesPerStore: Double
    ) {
        self.numberOfStores = numberOfStores
        self.averageStoreRevenue = averageStoreRevenue
        self.sameStoreSalesGrowth = sameStoreSalesGrowth
        self.footTraffic = footTraffic
        self.conversionRate = conversionRate
        self.averageTransaction = averageTransaction

        // Calculate aggregate values
        self.monthlyRevenue = averageStoreRevenue * Double(numberOfStores)
        self.costOfGoodsSoldPercentage = costOfGoodsSold
        self.operatingExpenses = operatingExpensesPerStore * Double(numberOfStores)

        // Estimate initial inventory (rough rule: ~2 months of COGS)
        let monthlyCOGS = self.monthlyRevenue * costOfGoodsSold
        self.initialInventoryValue = monthlyCOGS * 2.0

        self.seasonalMultipliers = [:]
    }

    // MARK: - Computed Properties

    /// Access COGS percentage (alias for costOfGoodsSoldPercentage).
    public var costOfGoodsSold: Double {
        costOfGoodsSoldPercentage
    }

    // MARK: - Revenue Calculations

    /// Calculate total monthly revenue.
    ///
    /// For store-based models, this is numberOfStores × averageStoreRevenue.
    /// For simple models, this is the baseline monthlyRevenue.
    ///
    /// - Returns: Total monthly revenue
    public func calculateTotalRevenue() -> Double {
        return monthlyRevenue
    }

    /// Calculate revenue for a specific month, accounting for seasonal adjustments.
    ///
    /// - Parameter month: The month (1-12)
    /// - Returns: Revenue for the specified month
    public func calculateRevenue(forMonth month: Int) -> Double {
        let monthOfYear = ((month - 1) % 12) + 1
        let multiplier = seasonalMultipliers[monthOfYear] ?? 1.0
        return monthlyRevenue * multiplier
    }

    // MARK: - COGS and Gross Margin Calculations

    /// Calculate Cost of Goods Sold for baseline revenue.
    ///
    /// - Returns: Monthly COGS
    public func calculateCOGS() -> Double {
        return monthlyRevenue * costOfGoodsSoldPercentage
    }

    /// Calculate COGS for a specific month, accounting for seasonal revenue.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: COGS for the specified month
    public func calculateCOGS(forMonth month: Int) -> Double {
        return calculateRevenue(forMonth: month) * costOfGoodsSoldPercentage
    }

    /// Calculate gross margin (as a percentage).
    ///
    /// Gross Margin = (Revenue - COGS) / Revenue = 1 - COGS%
    ///
    /// - Returns: Gross margin percentage
    public func calculateGrossMargin() -> Double {
        return 1.0 - costOfGoodsSoldPercentage
    }

    /// Calculate gross profit for baseline revenue.
    ///
    /// Gross Profit = Revenue - COGS
    ///
    /// - Returns: Monthly gross profit
    public func calculateGrossProfit() -> Double {
        return monthlyRevenue - calculateCOGS()
    }

    /// Calculate gross profit for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Gross profit for the specified month
    public func calculateGrossProfit(forMonth month: Int) -> Double {
        let revenue = calculateRevenue(forMonth: month)
        let cogs = calculateCOGS(forMonth: month)
        return revenue - cogs
    }

    // MARK: - Inventory Metrics

    /// Calculate annual inventory turnover.
    ///
    /// Inventory Turnover = Annual COGS / Average Inventory
    ///
    /// - Returns: Number of times inventory turns over per year
    public func calculateInventoryTurnover() -> Double {
        let annualCOGS = calculateCOGS() * 12
        return annualCOGS / initialInventoryValue
    }

    /// Calculate annual inventory turns (alias for calculateInventoryTurnover).
    ///
    /// - Returns: Number of times inventory turns over per year
    public func calculateInventoryTurns() -> Double {
        return calculateInventoryTurnover()
    }

    /// Calculate days inventory outstanding (DIO).
    ///
    /// DIO = 365 / Inventory Turnover
    ///
    /// This represents the average number of days it takes to sell through inventory.
    ///
    /// - Returns: Days inventory outstanding
    public func calculateDaysInventoryOutstanding() -> Double {
        let turnover = calculateInventoryTurnover()
        return 365.0 / turnover
    }

    // MARK: - Net Profit Calculations

    /// Calculate net profit for baseline revenue.
    ///
    /// Net Profit = Gross Profit - Operating Expenses
    ///
    /// - Returns: Monthly net profit
    public func calculateNetProfit() -> Double {
        return calculateGrossProfit() - operatingExpenses
    }

    /// Calculate net profit for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Net profit for the specified month
    public func calculateNetProfit(forMonth month: Int) -> Double {
        return calculateGrossProfit(forMonth: month) - operatingExpenses
    }

    /// Calculate net profit margin.
    ///
    /// Net Profit Margin = Net Profit / Revenue
    ///
    /// - Returns: Net profit margin percentage
    public func calculateNetProfitMargin() -> Double {
        return calculateNetProfit() / monthlyRevenue
    }

    /// Calculate net profit margin for a specific month.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Net profit margin for the specified month
    public func calculateNetProfitMargin(forMonth month: Int) -> Double {
        let netProfit = calculateNetProfit(forMonth: month)
        let revenue = calculateRevenue(forMonth: month)
        return netProfit / revenue
    }

    // MARK: - Markup Calculations

    /// Calculate markup percentage.
    ///
    /// Markup = (Selling Price - Cost) / Cost
    ///
    /// If COGS is 60% of selling price, then:
    /// - Cost = $0.60 per $1.00 selling price
    /// - Markup = ($1.00 - $0.60) / $0.60 = 66.7%
    ///
    /// - Returns: Markup percentage
    public func calculateMarkup() -> Double {
        return (1.0 - costOfGoodsSoldPercentage) / costOfGoodsSoldPercentage
    }

    // MARK: - Break-Even Analysis

    /// Calculate break-even revenue.
    ///
    /// Break-even occurs when: Gross Profit = Operating Expenses
    /// Revenue * (1 - COGS%) = Operating Expenses
    /// Revenue = Operating Expenses / (1 - COGS%)
    ///
    /// - Returns: Monthly revenue needed to break even
    public func calculateBreakEvenRevenue() -> Double {
        return operatingExpenses / calculateGrossMargin()
    }

    // MARK: - Store Performance Metrics

    /// Calculate revenue per square foot.
    ///
    /// This is a key retail performance metric. Divides total monthly revenue
    /// by the total square footage to measure sales productivity per unit area.
    ///
    /// - Parameter squareFootage: Total square footage (for all stores if multi-location)
    /// - Returns: Monthly revenue per square foot
    public func calculateRevenuePerSquareFoot(squareFootage: Double) -> Double {
        return monthlyRevenue / squareFootage
    }

    /// Calculate revenue per square foot for a specific store.
    ///
    /// - Parameters:
    ///   - squareFootage: Square footage for one store
    ///   - storeIndex: Store index (for multi-location models)
    /// - Returns: Monthly revenue per square foot for the store
    public func calculateRevenuePerSquareFoot(squareFootage: Double, forStore storeIndex: Int) -> Double {
        guard let avgRevenue = averageStoreRevenue else {
            // Single-store model: use total revenue
            return monthlyRevenue / squareFootage
        }
        return avgRevenue / squareFootage
    }

    // MARK: - Comprehensive Projections

    /// Project revenue, gross profit, and net profit over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Tuple containing time series for revenue, gross profit, and net profit
    public func project(months: Int) -> (
        revenue: TimeSeries<Double>,
        grossProfit: TimeSeries<Double>,
        netProfit: TimeSeries<Double>
    ) {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }

        let revenueValues = (1...months).map { calculateRevenue(forMonth: $0) }
        let grossProfitValues = (1...months).map { calculateGrossProfit(forMonth: $0) }
        let netProfitValues = (1...months).map { calculateNetProfit(forMonth: $0) }

        return (
            revenue: TimeSeries(periods: periods, values: revenueValues),
            grossProfit: TimeSeries(periods: periods, values: grossProfitValues),
            netProfit: TimeSeries(periods: periods, values: netProfitValues)
        )
    }
}
