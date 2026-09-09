//
//  SubscriptionBoxModel.swift
//  BusinessMath
//
//  Created on October 31, 2025.
//

import Foundation
import Numerics

/// A financial model template for Subscription Box businesses.
///
/// This model handles key subscription box metrics including:
/// - Subscriber growth and churn
/// - Box pricing and fulfillment costs
/// - Customer acquisition cost (CAC) and lifetime value (LTV)
/// - Unit economics (LTV:CAC ratio, payback period)
/// - Revenue and profit projections
/// - Retention analysis
///
/// Example:
/// ```swift
/// let model = SubscriptionBoxModel(
///     initialSubscribers: 1_000,
///     monthlyBoxPrice: 49.99,
///     costOfGoodsPerBox: 20,
///     shippingCostPerBox: 5,
///     monthlyChurnRate: 0.08,
///     newSubscribersPerMonth: 150,
///     customerAcquisitionCost: 40
/// )
///
/// let ltv = model.calculateCustomerLifetimeValue()
/// let ltvToCAC = model.calculateLTVtoCAC()
/// let projection = model.project(months: 12)
/// ```
public struct SubscriptionBoxModel: Sendable {
    // MARK: - Properties

    /// Initial number of subscribers
    public let initialSubscribers: Double

    /// Monthly subscription box price
    public let monthlyBoxPrice: Double

    /// Cost of goods per box
    public let costOfGoodsPerBox: Double

    /// Shipping cost per box
    public let shippingCostPerBox: Double

    /// Monthly churn rate (percentage of subscribers lost)
    public let monthlyChurnRate: Double

    /// Number of new subscribers acquired per month
    public let newSubscribersPerMonth: Double

    /// Customer acquisition cost
    public let customerAcquisitionCost: Double

    // MARK: - Initialization
	/// Creates a Subscription as a Service model with baseline financial parameters.
	/// - Parameters:
	///   - initialSubscribers: Initial number of subscribers
	///   - monthlyBoxPrice: Monthly subscription box price
	///   - costOfGoodsPerBox: Cost of goods per box
	///   - shippingCostPerBox: Shipping cost per box
	///   - monthlyChurnRate: Monthly churn rate (percentage of subscribers lost)
	///   - newSubscribersPerMonth: Number of new subscribers acquired per month
	///   - customerAcquisitionCost: Customer acquisition cost
    public init(
        initialSubscribers: Double,
        monthlyBoxPrice: Double,
        costOfGoodsPerBox: Double,
        shippingCostPerBox: Double,
        monthlyChurnRate: Double,
        newSubscribersPerMonth: Double,
        customerAcquisitionCost: Double
    ) {
        self.initialSubscribers = initialSubscribers
        self.monthlyBoxPrice = monthlyBoxPrice
        self.costOfGoodsPerBox = costOfGoodsPerBox
        self.shippingCostPerBox = shippingCostPerBox
        self.monthlyChurnRate = monthlyChurnRate
        self.newSubscribersPerMonth = newSubscribersPerMonth
        self.customerAcquisitionCost = customerAcquisitionCost
    }

    // MARK: - Subscriber Calculations

    /// Calculate subscriber count for a specific month.
    ///
    /// - Parameter month: The month to calculate (1-indexed)
    /// - Returns: Number of subscribers at the end of the month
    public func calculateSubscribers(forMonth month: Int) -> Double {
        var subscribers = initialSubscribers

        for _ in 1...month {
            // Calculate churned subscribers
            let churnedSubscribers = subscribers * monthlyChurnRate

            // Net change
            subscribers = subscribers - churnedSubscribers + newSubscribersPerMonth
        }

        return subscribers
    }

    /// Project subscriber count over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Time series of subscriber counts
    public func projectSubscribers(months: Int) -> TimeSeries<Double> {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }

        let values = (1...months).map { calculateSubscribers(forMonth: $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - Revenue Calculations

    /// Calculate monthly revenue for a specific month.
    ///
    /// Revenue = Subscribers * Box Price
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Revenue for the specified month
    public func calculateRevenue(forMonth month: Int) -> Double {
        let subscribers = calculateSubscribers(forMonth: month)
        return subscribers * monthlyBoxPrice
    }

    // MARK: - Cost Calculations

    /// Calculate fulfillment cost per box.
    ///
    /// Fulfillment Cost = COGS + Shipping
    ///
    /// - Returns: Cost to fulfill one box
    public func calculateFulfillmentCostPerBox() -> Double {
        return costOfGoodsPerBox + shippingCostPerBox
    }

    /// Calculate total costs for a specific month.
    ///
    /// Total Costs = (Fulfillment * Subscribers) + (CAC * New Subscribers)
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Total costs for the specified month
    public func calculateTotalCosts(forMonth month: Int) -> Double {
        let subscribers = calculateSubscribers(forMonth: month)
        let fulfillmentCosts = subscribers * calculateFulfillmentCostPerBox()
        let acquisitionCosts = newSubscribersPerMonth * customerAcquisitionCost
        return fulfillmentCosts + acquisitionCosts
    }

    // MARK: - Gross Margin Calculations

    /// Calculate gross margin per box.
    ///
    /// Gross Margin = Box Price - COGS - Shipping
    ///
    /// - Returns: Gross margin per box
    public func calculateGrossMarginPerBox() -> Double {
        return monthlyBoxPrice - costOfGoodsPerBox - shippingCostPerBox
    }

    /// Calculate gross margin percentage.
    ///
    /// Gross Margin % = Gross Margin / Box Price
    ///
    /// - Returns: Gross margin percentage
    public func calculateGrossMarginPercentage() -> Double {
        guard monthlyBoxPrice > 0 else { return 0 }
        return calculateGrossMarginPerBox() / monthlyBoxPrice // fp-safety:disable — guarded above
    }

    // MARK: - LTV Calculations

    /// Contribution margin earned per subscriber per month.
    ///
    /// The same quantity as ``calculateGrossMarginPerBox()``, named for what
    /// `Marketing/Value/` calls it. This is what acquisition cost is recovered out of.
    public var marginPerPeriod: Double { calculateGrossMarginPerBox() }

    /// Monthly retention, or `nil` if the churn rate is not a rate.
    ///
    /// - Returns: `1 − monthlyChurnRate`, or `nil` outside `[0, 1]`. A churn of 1.2 is not
    ///   a retention of −0.2; it is a number that cannot have come from counting
    ///   subscribers.
    public var retentionRate: Double? {
        guard monthlyChurnRate >= 0, monthlyChurnRate <= 1, monthlyChurnRate.isFinite else {
            return nil
        }
        return 1 - monthlyChurnRate
    }

    /// Customer lifetime value, delegated to `Marketing/Value/`.
    ///
    /// ```swift
    /// let model = SubscriptionBoxModel(initialSubscribers: 1_000, monthlyBoxPrice: 40,
    ///                                  costOfGoodsPerBox: 15, shippingCostPerBox: 5,
    ///                                  monthlyChurnRate: 0.08,
    ///                                  newSubscribersPerMonth: 100,
    ///                                  customerAcquisitionCost: 60)
    /// let value = try model.lifetimeValue()
    /// print(value.value)
    /// ```
    ///
    /// Defaults to ``CLVDefinition/perpetuityDue`` — margin over churn, exactly what
    /// ``calculateCustomerLifetimeValue()`` has always returned, now named.
    ///
    /// Zero churn throws ``CLVError/divergentPerpetuity(retention:discountRate:)`` rather
    /// than returning zero, because nobody ever leaving is the case where the series does
    /// not converge. A box sold at a loss keeps its **negative** lifetime value, which is
    /// a finding rather than an error.
    ///
    /// - Parameters:
    ///   - definition: Which lifetime value. Defaults to the industry convention.
    ///   - discountRate: Monthly discount rate, non-negative.
    ///   - horizon: Months to project, used only by ``CLVDefinition/finiteHorizon``.
    /// - Returns: The value, with the retention and margin it came from.
    /// - Throws: ``CLVError``.
    public func lifetimeValue(definition: CLVDefinition = .perpetuityDue,
                              discountRate: Double = 0,
                              horizon: Int = 12) throws -> CLVResult<Double> {
        guard let retention = retentionRate else { throw CLVError.invalidRetention }
        return try customerLifetimeValue(marginPerPeriod: marginPerPeriod,
                                         retention: retention,
                                         definition: definition,
                                         discountRate: discountRate,
                                         horizon: horizon)
    }

    /// Unit economics against the acquisition cost, delegated to `Marketing/Value/`.
    ///
    /// - Parameters:
    ///   - definition: Which lifetime value to put in the numerator.
    ///   - discountRate: Monthly discount rate.
    ///   - horizon: Months to project, for a finite horizon.
    /// - Returns: The metrics, or `nil` when the acquisition cost is not positive, or when
    ///   the margin is not — a box sold at a loss never recovers its acquisition cost, and
    ///   the payback is absent rather than instant.
    /// - Throws: ``CLVError`` if the lifetime value itself is undefined.
    public func acquisitionMetrics(definition: CLVDefinition = .perpetuityDue,
                                   discountRate: Double = 0,
                                   horizon: Int = 12) throws -> AcquisitionMetrics<Double>? {
        let value = try lifetimeValue(definition: definition,
                                      discountRate: discountRate,
                                      horizon: horizon)
        return AcquisitionMetrics(lifetimeValue: value.value,
                                  acquisitionCost: customerAcquisitionCost,
                                  marginPerPeriod: marginPerPeriod)
    }

    /// Calculate customer lifetime value.
    ///
    /// LTV = Gross Margin per Box / Churn Rate
    ///
    /// This represents the total gross profit expected from a customer
    /// over their lifetime with the subscription.
    ///
    /// - Returns: Customer lifetime value, or **zero when the churn rate is zero** — which
    ///   is the case where the value is unbounded, not the case where it is nothing.
    @available(*, deprecated, message: "Use lifetimeValue(definition:discountRate:horizon:), which returns the same number and throws on the zero-churn case this returns 0 for.")
    public func calculateCustomerLifetimeValue() -> Double {
        guard monthlyChurnRate > 0 else { return 0 }
        return calculateGrossMarginPerBox() / monthlyChurnRate // fp-safety:disable — guarded above
    }

    // MARK: - Unit Economics

    /// Calculate LTV to CAC ratio.
    ///
    /// A healthy subscription business typically has LTV:CAC > 3.0
    ///
    /// - Returns: LTV:CAC ratio, or 0 when the acquisition cost is not positive.
    @available(*, deprecated, message: "Use acquisitionMetrics()?.ratio, which returns nil rather than zero when the ratio is undefined.")
    public func calculateLTVtoCAC() -> Double {
        guard customerAcquisitionCost > 0 else { return 0 }
        return calculateCustomerLifetimeValue() / customerAcquisitionCost // fp-safety:disable — guarded above
    }

    /// Calculate CAC payback period in months.
    ///
    /// Payback Period = CAC / Gross Margin per Box
    ///
    /// This represents how many months it takes to recover the customer acquisition cost.
    ///
    /// - Returns: Number of months to payback CAC, or **zero when the gross margin is not
    ///   positive** — a box sold at a loss never pays back, and zero months says it pays
    ///   back instantly.
    @available(*, deprecated, message: "Use acquisitionMetrics()?.paybackPeriods, which returns nil rather than zero for a box that never pays back.")
    public func calculateCACPaybackMonths() -> Double {
        let grossMargin = calculateGrossMarginPerBox()
        guard grossMargin > 0 else { return 0 }
        return customerAcquisitionCost / grossMargin // fp-safety:disable — guarded above
    }

    // MARK: - Profit Calculations

    /// Calculate profit for a specific month.
    ///
    /// Profit = Revenue - Total Costs
    ///
    /// - Parameter month: The month to calculate
    /// - Returns: Profit for the specified month
    public func calculateProfit(forMonth month: Int) -> Double {
        let revenue = calculateRevenue(forMonth: month)
        let costs = calculateTotalCosts(forMonth: month)
        return revenue - costs
    }

    // MARK: - Retention Analysis

    /// Calculate retention rate.
    ///
    /// Retention Rate = 1 - Churn Rate
    ///
    /// - Returns: Monthly retention rate, which is **negative** for a churn rate above
    ///   one rather than being refused.
    @available(*, deprecated, message: "Use the retentionRate property, which returns nil for a churn rate outside [0, 1] instead of a negative retention.")
    public func calculateRetentionRate() -> Double {
        return 1.0 - monthlyChurnRate
    }

    // MARK: - Comprehensive Projections

    /// Project subscribers, revenue, and profit over multiple months.
    ///
    /// - Parameter months: Number of months to project
    /// - Returns: Tuple containing time series for subscribers, revenue, and profit
    public func project(months: Int) -> (
        subscribers: TimeSeries<Double>,
        revenue: TimeSeries<Double>,
        profit: TimeSeries<Double>
    ) {
        let baseYear = 2025
        let periods = (1...months).map { monthIndex -> Period in
            let year = baseYear + (monthIndex - 1) / 12
            let month = ((monthIndex - 1) % 12) + 1
            return Period.month(year: year, month: month)
        }

        let subscriberValues = (1...months).map { calculateSubscribers(forMonth: $0) }
        let revenueValues = (1...months).map { calculateRevenue(forMonth: $0) }
        let profitValues = (1...months).map { calculateProfit(forMonth: $0) }

        return (
            subscribers: TimeSeries(periods: periods, values: subscriberValues),
            revenue: TimeSeries(periods: periods, values: revenueValues),
            profit: TimeSeries(periods: periods, values: profitValues)
        )
    }
}
