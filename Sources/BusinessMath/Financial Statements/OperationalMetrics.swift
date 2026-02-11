//
//  OperationalMetrics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/23/25.
//

import Foundation
import Numerics

/// Operational metrics that track key business drivers and performance indicators.
///
/// OperationalMetrics provides a flexible, industry-agnostic way to track the operational
/// drivers behind financial performance. Unlike financial statements which are standardized,
/// operational metrics vary significantly by industry and business model.
///
/// ## Design Philosophy
///
/// This structure is intentionally flexible because:
/// - Companies evolve and their key metrics change over time
/// - Different industries track fundamentally different drivers
/// - Operational definitions vary between companies
///
/// ## Industry Examples
///
/// **E-commerce:**
/// ```swift
/// let metrics = OperationalMetrics<Double>(
///     entity: entity,
///     period: q1,
///     metrics: [
///         "units_sold": 15_000,
///         "average_order_value": 85.50,
///         "active_customers": 12_500,
///         "conversion_rate": 0.032
///     ]
/// )
/// ```
///
/// **SaaS:**
/// ```swift
/// let metrics = OperationalMetrics<Double>(
///     entity: entity,
///     period: q1,
///     metrics: [
///         "monthly_recurring_revenue": 2_500_000,
///         "customer_count": 850,
///         "net_revenue_retention": 1.15,
///         "customer_acquisition_cost": 12_000
///     ]
/// )
/// ```
///
/// **Oil & Gas:**
/// ```swift
/// let metrics = OperationalMetrics<Double>(
///     entity: entity,
///     period: q1,
///     metrics: [
///         "production_boe_per_day": 125_000,
///         "realized_price_per_boe": 68.50,
///         "wells_drilled": 12,
///         "lifting_cost_per_boe": 18.25
///     ]
/// )
/// ```
///
/// ## Multi-Period Tracking
///
/// Use `OperationalMetricsTimeSeries` to track metrics over multiple periods:
///
/// ```swift
/// let quarters = Period.year(2025).quarters()
/// let metricsList = try [
///     OperationalMetrics(entity: entity, period: quarters[0], metrics: [...]),
///     OperationalMetrics(entity: entity, period: quarters[1], metrics: [...]),
///     OperationalMetrics(entity: entity, period: quarters[2], metrics: [...]),
///     OperationalMetrics(entity: entity, period: quarters[3], metrics: [...])
/// ]
///
/// let timeSeries = OperationalMetricsTimeSeries(metrics: metricsList)
/// let unitsGrowth = timeSeries.growthRate(metric: "units_sold")
/// ```
public struct OperationalMetrics<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// The entity these metrics belong to
	public let entity: Entity

	/// The period these metrics cover
	public let period: Period

	/// Dictionary of metric names to values
	/// Metric names should use snake_case for consistency (e.g., "units_sold", "average_order_value")
	public let metrics: [String: T]

	/// Optional metadata for documentation and context
	public var metadata: OperationalMetricsMetadata?

	/// Creates operational metrics for a specific entity and period.
	///
	/// - Parameters:
	///   - entity: The entity these metrics belong to
	///   - period: The period these metrics cover
	///   - metrics: Dictionary of metric names to values
	///   - metadata: Optional metadata for documentation
	public init(
		entity: Entity,
		period: Period,
		metrics: [String: T],
		metadata: OperationalMetricsMetadata? = nil
	) {
		self.entity = entity
		self.period = period
		self.metrics = metrics
		self.metadata = metadata
	}

	/// Access a specific metric by name.
	///
	/// - Parameter name: The metric name
	/// - Returns: The metric value, or nil if not found
	public subscript(name: String) -> T? {
		metrics[name]
	}

	/// Calculate a derived metric from two base metrics.
	///
	/// Useful for computing ratios and per-unit metrics:
	///
	/// ```swift
	/// // Revenue per customer
	/// let revenuePerCustomer = metrics.derived(
	///     numerator: "total_revenue",
	///     denominator: "customer_count"
	/// )
	///
	/// // Cost per unit
	/// let costPerUnit = metrics.derived(
	///     numerator: "total_cost",
	///     denominator: "units_sold"
	/// )
	/// ```
	///
	/// - Parameters:
	///   - numerator: Name of numerator metric
	///   - denominator: Name of denominator metric
	/// - Returns: The calculated ratio, or nil if either metric is missing or denominator is zero
	public func derived(numerator: String, denominator: String) -> T? {
		guard let num = metrics[numerator],
			  let denom = metrics[denominator],
			  denom != T(0) else {
			return nil
		}
		return num / denom
	}
}

/// Metadata for operational metrics to provide context and documentation.
public struct OperationalMetricsMetadata: Codable, Sendable {
	/// Industry classification (e.g., "E-commerce", "SaaS", "Oil & Gas")
	public var industry: String?

	/// Description of the business model
	public var businessModel: String?

	/// Documentation of metric definitions
	/// Maps metric names to their definitions
	public var metricDefinitions: [String: String]?

	/// Notes about data quality, methodology, or special circumstances
	public var notes: String?
	/// Creates a metadata object with the parameters
	/// - industry: Industry classification (e.g., "E-commerce", "SaaS", "Oil & Gas")
	/// - businessModel: Description of the business model
	/// - metricDefinitions:  Documentation of metric definitions; Maps metric names to their definitions
	/// - notes: Notes about data quality, methodology, or special circumstances
	public init(
		industry: String? = nil,
		businessModel: String? = nil,
		metricDefinitions: [String: String]? = nil,
		notes: String? = nil
	) {
		self.industry = industry
		self.businessModel = businessModel
		self.metricDefinitions = metricDefinitions
		self.notes = notes
	}
}

/// Time series collection of operational metrics across multiple periods.
///
/// Provides analysis capabilities for operational metrics over time, including
/// growth rates, trends, and period-over-period comparisons.
///
/// ## Example
///
/// ```swift
/// let quarters = Period.year(2025).quarters()
/// let metricsList = [
///     OperationalMetrics(entity: entity, period: quarters[0], metrics: ["units_sold": 10_000]),
///     OperationalMetrics(entity: entity, period: quarters[1], metrics: ["units_sold": 11_000]),
///     OperationalMetrics(entity: entity, period: quarters[2], metrics: ["units_sold": 12_100]),
///     OperationalMetrics(entity: entity, period: quarters[3], metrics: ["units_sold": 13_310])
/// ]
///
/// let timeSeries = OperationalMetricsTimeSeries(metrics: metricsList)
///
/// // Get time series for a specific metric
/// let unitsSold = timeSeries.timeSeries(for: "units_sold")
///
/// // Calculate quarter-over-quarter growth
/// let growth = timeSeries.growthRate(metric: "units_sold")
/// ```
public struct OperationalMetricsTimeSeries<T: Real & Sendable>: Codable, Sendable where T: Codable {
	/// All operational metrics, sorted by period
	public let metrics: [OperationalMetrics<T>]

	/// Creates a time series from a list of operational metrics.
	///
	/// Metrics will be sorted by period automatically.
	///
	/// - Parameter metrics: Array of operational metrics
	/// - Throws: If metrics are for different entities
	public init(metrics: [OperationalMetrics<T>]) throws {
		guard !metrics.isEmpty else {
			self.metrics = []
			return
		}

		// Verify all metrics are for the same entity
		let firstEntity = metrics[0].entity
		guard metrics.allSatisfy({ $0.entity.id == firstEntity.id }) else {
			throw OperationalMetricsError.entityMismatch
		}

		// Sort by period
		self.metrics = metrics.sorted { $0.period.startDate < $1.period.startDate }
	}

	/// Extract a TimeSeries for a specific metric across all periods.
	///
	/// - Parameter metricName: Name of the metric to extract
	/// - Returns: TimeSeries of the metric, or nil if metric not found in any period
	public func timeSeries(for metricName: String) -> TimeSeries<T>? {
		var values: [(Period, T)] = []

		for operationalMetric in metrics {
			if let value = operationalMetric[metricName] {
				values.append((operationalMetric.period, value))
			}
		}

		guard !values.isEmpty else {
			return nil
		}

		let periods = values.map { $0.0 }
		let metricValues = values.map { $0.1 }

		return TimeSeries(periods: periods, values: metricValues)
	}

	/// Calculate period-over-period growth rates for a metric.
	///
	/// Returns a TimeSeries of growth rates (as decimals, e.g., 0.10 = 10% growth).
	///
	/// - Parameter metric: Name of the metric
	/// - Returns: TimeSeries of growth rates, or nil if metric not found
	public func growthRate(metric: String) -> TimeSeries<T>? {
		guard let ts = timeSeries(for: metric) else {
			return nil
		}

		return ts.periodOverPeriodGrowth()
	}

	/// Access operational metrics for a specific period.
	///
	/// - Parameter period: The period to look up
	/// - Returns: OperationalMetrics for that period, or nil if not found
	public subscript(period: Period) -> OperationalMetrics<T>? {
		metrics.first { $0.period == period }
	}
}

/// Errors related to operational metrics.
public enum OperationalMetricsError: Error, CustomStringConvertible {
	/// Metrics belong to different entities
	case entityMismatch

	/// Required metric not found
	case metricNotFound(String)
        
        /// Human-readable error for debugging
	public var description: String {
		switch self {
		case .entityMismatch:
			return "All operational metrics must belong to the same entity"
		case .metricNotFound(let name):
			return "Required metric '\(name)' not found"
		}
	}
}
