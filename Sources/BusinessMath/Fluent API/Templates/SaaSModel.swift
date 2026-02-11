//
//  SaaSModel.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import RealModule

/// A financial model template for Software as a Service (SaaS) businesses.
///
/// This model handles key SaaS metrics including:
/// - Monthly Recurring Revenue (MRR)
/// - Annual Recurring Revenue (ARR)
/// - Customer churn and acquisition
/// - Customer Lifetime Value (LTV)
/// - Customer Acquisition Cost (CAC) payback
/// - Unit economics (LTV:CAC ratio)
///
/// Example:
/// ```swift
/// let model = SaaSModel(
///     initialMRR: 10_000,
///     churnRate: 0.05,
///     newCustomersPerMonth: 100,
///     averageRevenuePerUser: 100
/// )
///
/// let projection = model.project(months: 36)
/// let ltv = model.calculateLTV()
/// let ltvToCAC = model.calculateLTVtoCAC()
/// ```
public struct SaaSModel: Sendable {
    // MARK: - Properties

    /// Initial Monthly Recurring Revenue
    public let initialMRR: Double

    /// Monthly churn rate (percentage of customers lost per month)
    public var churnRate: Double

    /// Number of new customers acquired per month
    public var newCustomersPerMonth: Double

    /// Average revenue per user (ARPU)
    public var averageRevenuePerUser: Double

    /// Gross margin percentage (optional, defaults to 1.0 for 100%)
    public var grossMargin: Double?

    /// Customer Acquisition Cost (optional)
    public var customerAcquisitionCost: Double?

    /// Price increases at specific months
    public var priceIncreases: [(month: Int, percentage: Double)]

    // MARK: - Initialization
	
	/// Creates a Subscription as a Service model with baseline financial parameters.
	/// - Parameters:
	///   - initialMRR: Starting Monthly Recurring Revenue
	///   - churnRate: Monthly churn rate (percentage of customers lost per month)
	///   - newCustomersPerMonth: Number of new customers acquired per month
	///   - averageRevenuePerUser: Average revenue per user (ARPU)
	///   - grossMargin: Gross margin percentage (optional, defaults to 1.0 for 100%)
	///   - customerAcquisitionCost: Customer Acquisition Cost (optional)
	///   - priceIncreases: Price increases at specific months
    public init(
        initialMRR: Double,
        churnRate: Double,
        newCustomersPerMonth: Double,
        averageRevenuePerUser: Double,
        grossMargin: Double? = nil,
        customerAcquisitionCost: Double? = nil,
        priceIncreases: [(month: Int, percentage: Double)] = []
    ) {
        self.initialMRR = initialMRR
        self.churnRate = churnRate
        self.newCustomersPerMonth = newCustomersPerMonth
        self.averageRevenuePerUser = averageRevenuePerUser
        self.grossMargin = grossMargin
        self.customerAcquisitionCost = customerAcquisitionCost
        self.priceIncreases = priceIncreases
    }

    // MARK: - Computed Properties

    /// Initial customer count derived from MRR and ARPU
    private var initialCustomerCount: Double {
        initialMRR / averageRevenuePerUser
    }

    // MARK: - MRR Calculations

    /// Calculate Monthly Recurring Revenue for a specific month.
    ///
    /// - Parameter month: The month to calculate (1-indexed)
    /// - Returns: MRR for the specified month
    public func calculateMRR(forMonth month: Int) -> Double {
        let customerCount = calculateCustomerCount(forMonth: month)
        let pricePerCustomer = calculatePricePerCustomer(atMonth: month)
        return customerCount * pricePerCustomer
    }

    /// Project MRR over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Time series of MRR values
    public func projectMRR(months: Int) -> TimeSeries<Double> {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }
        let values = (1...months).map { calculateMRR(forMonth: $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - ARR Calculations

    /// Calculate Annual Recurring Revenue.
    ///
    /// ARR is calculated as the MRR at month 12 multiplied by 12.
    /// If projecting less than 12 months, uses the final month's MRR.
    ///
    /// - Returns: Annual Recurring Revenue
    public func calculateARR() -> Double {
        let finalMonth = 12
        return calculateMRR(forMonth: finalMonth) * 12
    }

    // MARK: - Customer Calculations

    /// Calculate customer count for a specific month.
    ///
    /// - Parameter month: The month to calculate (1-indexed)
    /// - Returns: Number of customers at the end of the month
    public func calculateCustomerCount(forMonth month: Int) -> Double {
        var customers = initialCustomerCount

        for _ in 1...month {
            // Calculate churned customers
            let churnedCustomers = customers * churnRate

            // Net change in customers
            customers = customers - churnedCustomers + newCustomersPerMonth
        }

        return customers
    }

    /// Project customer count over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Time series of customer counts
    public func projectCustomerCount(months: Int) -> TimeSeries<Double> {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }
        let values = (1...months).map { calculateCustomerCount(forMonth: $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - Price Calculations

    /// Calculate price per customer at a specific month, accounting for price increases.
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Price per customer
    private func calculatePricePerCustomer(atMonth month: Int) -> Double {
        var price = averageRevenuePerUser

        // Apply price increases that occurred before or at this month
        for (increaseMonth, percentage) in priceIncreases {
            if increaseMonth <= month {
                price *= (1 + percentage)
            }
        }

        return price
    }

    // MARK: - LTV Calculations

    /// Calculate Customer Lifetime Value.
    ///
    /// LTV is calculated as: (ARPU * Gross Margin) / Churn Rate
    /// If no gross margin is specified, assumes 100% (1.0).
    ///
    /// - Returns: Customer Lifetime Value
    public func calculateLTV() -> Double {
        let margin = grossMargin ?? 1.0
        return (averageRevenuePerUser * margin) / churnRate
    }

    // MARK: - CAC Calculations

    /// Calculate Customer Acquisition Cost payback period in months.
    ///
    /// Payback period = CAC / ARPU
    ///
    /// - Returns: Number of months to recover CAC, or 0 if CAC is not specified
    public func calculateCACPayback() -> Double {
        guard let cac = customerAcquisitionCost else { return 0 }
        return cac / averageRevenuePerUser
    }

    // MARK: - Unit Economics

    /// Calculate LTV to CAC ratio.
    ///
    /// A healthy SaaS business typically has an LTV:CAC ratio > 3.0.
    ///
    /// - Returns: LTV:CAC ratio, or 0 if CAC is not specified
    public func calculateLTVtoCAC() -> Double {
        guard let cac = customerAcquisitionCost else { return 0 }
        return calculateLTV() / cac
    }

    // MARK: - Growth Rate Calculations

    /// Calculate the growth rate between two months.
    ///
    /// Growth rate is calculated as: (MRR_end - MRR_start) / MRR_start
    ///
    /// - Parameters:
    ///   - startMonth: The starting month (1-indexed)
    ///   - endMonth: The ending month (1-indexed)
    /// - Returns: Growth rate as a decimal (e.g., 0.15 for 15% growth)
    public func calculateGrowthRate(from startMonth: Int, to endMonth: Int) -> Double {
        let startMRR = calculateMRR(forMonth: startMonth)
        let endMRR = calculateMRR(forMonth: endMonth)

        guard startMRR > 0 else { return 0 }
        return (endMRR - startMRR) / startMRR
    }

    // MARK: - Comprehensive Projections

    /// Project MRR, revenue, and customer count over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Tuple containing time series for MRR, revenue, and customers
    public func project(months: Int) -> (
        mrr: TimeSeries<Double>,
        revenue: TimeSeries<Double>,
        customers: TimeSeries<Double>
    ) {
        let mrrSeries = projectMRR(months: months)
        let customerSeries = projectCustomerCount(months: months)

        // Revenue is the same as MRR for a subscription business
        let revenueSeries = mrrSeries

        return (mrr: mrrSeries, revenue: revenueSeries, customers: customerSeries)
    }
}
