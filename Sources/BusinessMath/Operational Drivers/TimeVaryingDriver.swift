//
//  TimeVaryingDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

/// A driver whose distribution or behavior varies by time period.
///
/// `TimeVaryingDriver` enables modeling of business variables that change over time,
/// such as seasonality, growth trends, or period-specific uncertainty.
///
/// ## Use Cases
///
/// **Seasonality:**
/// - Holiday sales spikes (Q4 revenue boost)
/// - Summer slowdowns
/// - Monthly patterns (payroll timing)
///
/// **Growth/Decline:**
/// - Inflation (costs increase over time)
/// - Market penetration (revenue growth)
/// - Depreciation (asset values decline)
///
/// **Period-Specific Uncertainty:**
/// - Q1 forecasts more uncertain than Q4 actuals
/// - Launch periods have higher variance
/// - Stable vs volatile periods
///
/// ## Creating Time-Varying Drivers
///
/// ### Seasonal Revenue (Discrete Periods)
///
/// ```swift
/// let seasonalRevenue = TimeVaryingDriver<Double>(name: "Seasonal Revenue") { period in
///     let baseRevenue = 100_000.0
///
///     // Q4 gets 30% holiday boost
///     let seasonalMultiplier: Double
///     if period.type == .quarterly && period.quarter == 4 {
///         seasonalMultiplier = 1.3
///     } else {
///         seasonalMultiplier = 1.0
///     }
///
///     // Sample from scaled distribution
///     let mean = baseRevenue * seasonalMultiplier
///     return ProbabilisticDriver.normal(name: "Revenue", mean: mean, stdDev: 10_000.0)
///         .sample(for: period)
/// }
/// ```
///
/// ### Growth with Inflation (Continuous)
///
/// ```swift
/// let inflationaryCosts = TimeVaryingDriver<Double>(name: "Costs with Inflation") { period in
///     let baseCost = 50_000.0
///     let inflationRate = 0.03  // 3% annual
///
///     // Calculate years since baseline
///     let yearsSince2025 = Double(period.year - 2025)
///     let inflationMultiplier = pow(1.0 + inflationRate, yearsSince2025)
///
///     let adjustedCost = baseCost * inflationMultiplier
///     return DeterministicDriver(name: "Cost", value: adjustedCost).sample(for: period)
/// }
/// ```
///
/// ### Declining Uncertainty Over Time
///
/// ```swift
/// let forecastRevenue = TimeVaryingDriver<Double>(name: "Forecast Revenue") { period in
///     let meanRevenue = 100_000.0
///
///     // Earlier periods more uncertain
///     let monthsOut = period.startDate.timeIntervalSince(Date()) / (30.0 * 24.0 * 60.0 * 60.0)
///     let baseStdDev = 5_000.0
///     let uncertaintyMultiplier = 1.0 + (monthsOut / 12.0)  // Grows with time
///     let stdDev = baseStdDev * uncertaintyMultiplier
///
///     return ProbabilisticDriver.normal(name: "Revenue", mean: meanRevenue, stdDev: stdDev)
///         .sample(for: period)
/// }
/// ```
///
/// ### Product Lifecycle
///
/// ```swift
/// let productRevenue = TimeVaryingDriver<Double>(name: "Product Lifecycle") { period in
///     let monthsSinceLaunch = calculateMonthsSince(launchDate: launchDate, period: period)
///
///     let (mean, stdDev): (Double, Double)
///     if monthsSinceLaunch < 6 {
///         // Launch phase: Low mean, high variance
///         mean = 50_000.0
///         stdDev = 20_000.0
///     } else if monthsSinceLaunch < 24 {
///         // Growth phase: Increasing mean, moderate variance
///         mean = 50_000.0 + Double(monthsSinceLaunch - 6) * 10_000.0
///         stdDev = 15_000.0
///     } else {
///         // Mature phase: Stable mean, low variance
///         mean = 200_000.0
///         stdDev = 10_000.0
///     }
///
///     return ProbabilisticDriver.normal(name: "Revenue", mean: mean, stdDev: stdDev)
///         .sample(for: period)
/// }
/// ```
///
/// ## Combining with Other Drivers
///
/// Time-varying drivers work seamlessly with all operations:
///
/// ```swift
/// let seasonalQuantity = TimeVaryingDriver<Double>(...) { period in ... }
/// let fixedPrice = DeterministicDriver(name: "Price", value: 100.0)
/// let revenue = seasonalQuantity * fixedPrice  // Product still works
/// ```
///
/// ## Monte Carlo Projection
///
/// Time-varying drivers fully support Monte Carlo analysis:
///
/// ```swift
/// let periods = Period.year(2025).quarters()
/// let projection = DriverProjection(driver: seasonalRevenue, periods: periods)
/// let results = projection.projectMonteCarlo(iterations: 10_000)
///
/// // Each period has different statistics reflecting its distribution
/// for period in periods {
///     print("\(period.label): Mean = \(results.statistics[period]!.mean)")
/// }
/// ```
///
/// ## Important Notes
///
/// - The sampler closure is called once per period per iteration
/// - For deterministic time variation, return a fixed value
/// - For probabilistic time variation, sample from appropriate distribution
/// - The period parameter provides full date/time context for logic
public struct TimeVaryingDriver<T>: Driver, Sendable where T: Real, T: BinaryFloatingPoint, T: Sendable {
	// MARK: - Properties

	/// The name of this driver.
	public let name: String

	/// The period-specific sampling function.
	///
	/// This closure receives the period and returns a sampled value.
	/// It can implement any time-dependent logic needed.
	private let sampler: @Sendable (Period) -> T

	// MARK: - Initialization

	/// Creates a time-varying driver with period-specific sampling logic.
	///
	/// The sampler closure receives the period and should return an appropriate
	/// value for that specific time period. This enables modeling of seasonality,
	/// growth trends, and any other time-dependent behavior.
	///
	/// - Parameters:
	///   - name: The name of this driver for reporting and debugging.
	///   - sampler: A closure that generates values based on the period.
	///
	/// ## Example
	/// ```swift
	/// let seasonal = TimeVaryingDriver<Double>(name: "Seasonal Sales") { period in
	///     let base = 100_000.0
	///     let q4Boost = period.quarter == 4 ? 1.3 : 1.0
	///     let mean = base * q4Boost
	///     return ProbabilisticDriver.normal(name: "Sales", mean: mean, stdDev: 10_000.0)
	///         .sample(for: period)
	/// }
	/// ```
	public init(name: String, sampler: @escaping @Sendable (Period) -> T) {
		self.name = name
		self.sampler = sampler
	}

	// MARK: - Driver Protocol

	/// Generates a value for the specified period using the period-specific logic.
	///
	/// - Parameter period: The time period for which to generate a value.
	/// - Returns: A value appropriate for the specified period.
	public func sample(for period: Period) -> T {
		return sampler(period)
	}
}

// MARK: - Convenience Factory Methods

extension TimeVaryingDriver {
	/// Creates a time-varying driver with linear growth.
	///
	/// - Parameters:
	///   - name: The name of this driver.
	///   - baseValue: The starting value.
	///   - annualGrowthRate: The annual growth rate (e.g., 0.03 for 3%).
	///   - baseYear: The reference year for the base value.
	///   - stdDevPercentage: Optional standard deviation as percentage of mean (for uncertainty).
	///
	/// ## Example
	/// ```swift
	/// // Costs grow 3% per year with 5% uncertainty
	/// let growingCosts = TimeVaryingDriver.withGrowth(
	///     name: "Operating Costs",
	///     baseValue: 50_000.0,
	///     annualGrowthRate: 0.03,
	///     baseYear: 2025,
	///     stdDevPercentage: 0.05
	/// )
	/// ```
	public static func withGrowth(
		name: String,
		baseValue: T,
		annualGrowthRate: Double,
		baseYear: Int,
		stdDevPercentage: Double? = nil
	) -> TimeVaryingDriver<T> {
		return TimeVaryingDriver(name: name) { period in
			let yearsSinceBase = Double(period.year - baseYear)
			let growthMultiplier = pow(1.0 + annualGrowthRate, yearsSinceBase)
			let adjustedValue = T(Double(baseValue) * growthMultiplier)

			if let stdDevPct = stdDevPercentage {
				let stdDev = T(Double(adjustedValue) * stdDevPct)
				return ProbabilisticDriver.normal(
					name: name,
					mean: Double(adjustedValue),
					stdDev: Double(stdDev)
				).sample(for: period)
			} else {
				return adjustedValue
			}
		}
	}

	/// Creates a time-varying driver with quarterly seasonality.
	///
	/// - Parameters:
	///   - name: The name of this driver.
	///   - baseValue: The baseline value for non-seasonal periods.
	///   - q1Multiplier: Multiplier for Q1 (default: 1.0).
	///   - q2Multiplier: Multiplier for Q2 (default: 1.0).
	///   - q3Multiplier: Multiplier for Q3 (default: 1.0).
	///   - q4Multiplier: Multiplier for Q4 (default: 1.0).
	///   - stdDevPercentage: Optional standard deviation as percentage of seasonally-adjusted mean.
	///
	/// ## Example
	/// ```swift
	/// // Retail revenue: Q4 gets 30% boost, Q1 has 10% decline
	/// let retailRevenue = TimeVaryingDriver.withSeasonality(
	///     name: "Retail Revenue",
	///     baseValue: 100_000.0,
	///     q1Multiplier: 0.9,
	///     q2Multiplier: 1.0,
	///     q3Multiplier: 1.0,
	///     q4Multiplier: 1.3,
	///     stdDevPercentage: 0.10
	/// )
	/// ```
	public static func withSeasonality(
		name: String,
		baseValue: T,
		q1Multiplier: Double = 1.0,
		q2Multiplier: Double = 1.0,
		q3Multiplier: Double = 1.0,
		q4Multiplier: Double = 1.0,
		stdDevPercentage: Double? = nil
	) -> TimeVaryingDriver<T> {
		return TimeVaryingDriver(name: name) { period in
			// Determine seasonal multiplier
			let multiplier: Double
			if period.type == .quarterly {
				switch period.quarter {
				case 1: multiplier = q1Multiplier
				case 2: multiplier = q2Multiplier
				case 3: multiplier = q3Multiplier
				case 4: multiplier = q4Multiplier
				default: multiplier = 1.0
				}
			} else {
				// For non-quarterly periods, use average
				multiplier = (q1Multiplier + q2Multiplier + q3Multiplier + q4Multiplier) / 4.0
			}

			let adjustedValue = T(Double(baseValue) * multiplier)

			if let stdDevPct = stdDevPercentage {
				let stdDev = T(Double(adjustedValue) * stdDevPct)
				return ProbabilisticDriver.normal(
					name: name,
					mean: Double(adjustedValue),
					stdDev: Double(stdDev)
				).sample(for: period)
			} else {
				return adjustedValue
			}
		}
	}
}
