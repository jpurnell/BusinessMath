//
//  TrendModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - TrendModel Protocol

/// A protocol for trend models that can fit to time series data and project future values.
///
/// Trend models analyze historical data patterns to make projections about future values.
/// Different trend models use different mathematical approaches to capture various growth
/// patterns: linear, exponential, logistic, or custom.
///
/// ## Usage Pattern
///
/// All trend models follow a two-step process:
///
/// 1. **Fit** the model to historical data
/// 2. **Project** future values based on the fitted model
///
/// ```swift
/// var model = LinearTrend<Double>()
/// try model.fit(to: historicalData)
/// let forecast = try model.project(periods: 12)  // 12-period forecast
/// ```
///
/// ## Available Trend Models
///
/// - ``LinearTrend``: Constant rate of change (straight line)
/// - ``ExponentialTrend``: Accelerating or decelerating growth (exponential curve)
/// - ``LogisticTrend``: S-curve approaching a maximum capacity
/// - ``CustomTrend``: User-defined trend function
///
/// ## When to Use Each Model
///
/// | Model | Best For | Example Use Cases |
/// |-------|----------|-------------------|
/// | **Linear** | Steady, consistent growth | Revenue with stable market, headcount growth |
/// | **Exponential** | Accelerating growth | Viral products, early-stage startups, compound returns |
/// | **Logistic** | Growth with saturation | Market penetration, user adoption, epidemic spread |
/// | **Custom** | Complex or unique patterns | Seasonal adjusted, multi-factor models |
///
/// ## Error Handling
///
/// Trend models can throw errors during fitting or projection:
/// - Insufficient data points for the model
/// - Invalid data (e.g., non-positive values for exponential trends)
/// - Projection constraints violated
///
/// ## Thread Safety
///
/// All trend model types conform to `Sendable`, making them safe to use across
/// concurrency boundaries.
public protocol TrendModel<Value>: Sendable {
	/// The numeric type used for values in the time series.
	associatedtype Value: Real

	/// Fits the trend model to historical time series data.
	///
	/// This method analyzes the provided time series and determines the parameters
	/// of the trend model that best represent the historical pattern.
	///
	/// - Parameter timeSeries: The historical data to fit the model to.
	/// - Throws: An error if the data is insufficient or invalid for this trend model.
	///
	/// - Note: This method mutates the model by storing fitted parameters.
	///   You must call `fit(to:)` before calling `project(periods:)`.
	mutating func fit(to timeSeries: TimeSeries<Value>) throws

	/// Projects future values based on the fitted trend model.
	///
	/// This method generates a forecast by extending the fitted trend pattern
	/// into the future for the specified number of periods.
	///
	/// - Parameter periods: The number of future periods to project.
	/// - Returns: A time series containing the projected values.
	/// - Throws: An error if the model hasn't been fitted yet or if projection fails.
	///
	/// - Important: You must call `fit(to:)` before calling this method.
	func project(periods: Int) throws -> TimeSeries<Value>
}

// MARK: - Trend Model Error

/// Errors that can occur during trend model operations.
public enum TrendModelError: Error, Sendable {
	/// The model hasn't been fitted to data yet.
	case modelNotFitted

	/// Insufficient data points to fit the model.
	case insufficientData(required: Int, provided: Int)

	/// Invalid data for this trend model type.
	case invalidData(String)

	/// Projection failed due to mathematical constraints.
	case projectionFailed(String)
}

// MARK: - LinearTrend

/// A trend model that fits a straight line to time series data.
///
/// Linear trends assume a constant rate of change over time, making them suitable
/// for data that grows (or declines) at a steady pace.
///
/// **Mathematical Model:**
/// ```
/// y = mx + b
/// ```
/// Where:
/// - m = slope (rate of change per period)
/// - b = intercept (value at time 0)
/// - x = time period
///
/// ## When to Use
///
/// Linear trends work well when:
/// - Growth rate is relatively constant
/// - No acceleration or deceleration
/// - Short to medium-term forecasts
/// - Business is in steady state
///
/// ## Examples
///
/// **Revenue Forecasting:**
/// ```swift
/// // Historical quarterly revenue
/// let revenue = TimeSeries(
///     periods: [.quarter(2024, 1), .quarter(2024, 2), .quarter(2024, 3)],
///     values: [100_000.0, 105_000.0, 110_000.0],
///     metadata: TimeSeriesMetadata(name: "Revenue")
/// )
///
/// var model = LinearTrend<Double>()
/// try model.fit(to: revenue)
///
/// // Forecast next 4 quarters
/// let forecast = try model.project(periods: 4)
/// // Result: [115_000, 120_000, 125_000, 130_000]
/// ```
///
/// **Headcount Planning:**
/// ```swift
/// let employees = TimeSeries(
///     periods: [.year(2020), .year(2021), .year(2022)],
///     values: [50.0, 65.0, 80.0],
///     metadata: TimeSeriesMetadata(name: "Employees")
/// )
///
/// var model = LinearTrend<Double>()
/// try model.fit(to: employees)
///
/// let projection = try model.project(periods: 3)
/// // Projects steady growth: ~95, ~110, ~125 employees
/// ```
///
/// ## Advantages
/// - Simple and interpretable
/// - Fast computation
/// - Works with as few as 2 data points
/// - Stable extrapolation
///
/// ## Limitations
/// - Cannot model acceleration or deceleration
/// - May underestimate exponential growth
/// - Less accurate for long-term projections
/// - No natural bounds (can project negative values)
///
/// ## Implementation Details
///
/// Uses least-squares linear regression from ``linearRegression(_:_:)`` to
/// find the best-fit line through the historical data points.
public struct LinearTrend<T: Real & Sendable>: TrendModel, Sendable {
	/// The numeric type for trend values.
	///
	/// Conforms to `Real` for mathematical operations and `Sendable` for concurrency safety.
	public typealias Value = T

	private var fittedSlope: T?
	private var fittedIntercept: T?
	private var lastPeriod: Period?
	private var metadata: TimeSeriesMetadata?
	private var fittedDataCount: Int = 0
	private var residuals: [T] = []

	/// Creates a new linear trend model.
	public init() {}

	/// The fitted slope (rate of change per period).
	///
	/// Returns `nil` if the model hasn't been fitted yet.
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// try model.fit(to: revenue)
	/// print("Growth rate: \(model.slopeValue ?? 0) per period")
	/// ```
	public var slopeValue: T? { fittedSlope }

	/// The fitted intercept (value at time 0).
	///
	/// Returns `nil` if the model hasn't been fitted yet.
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// try model.fit(to: revenue)
	/// print("Base value: \(model.interceptValue ?? 0)")
	/// ```
	public var interceptValue: T? { fittedIntercept }

	/// A summary of the fitted model parameters.
	///
	/// Returns a human-readable description of the model, including the
	/// linear equation and fitted parameters.
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// try model.fit(to: revenue)
	/// print(model.summary)
	/// // Output: "LinearTrend: y = 5000.0x + 100000.0 (fitted on 12 data points)"
	/// ```
	public var summary: String {
		guard let slope = fittedSlope, let intercept = fittedIntercept else {
			return "LinearTrend: Not fitted"
		}
		return "LinearTrend: y = \(slope)x + \(intercept) (fitted on \(fittedDataCount) data points)"
	}

	/// Fit the linear trend model to historical time series data.
	///
	/// Uses least-squares linear regression to find the best-fit line through the data.
	/// The model equation is: y = mx + b, where m is slope and b is intercept.
	///
	/// - Parameter timeSeries: Historical data to fit (requires at least 2 points)
	/// - Throws: ``TrendModelError/insufficientData(required:provided:)`` if fewer than 2 data points
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// let revenue = TimeSeries(periods: [...], values: [100000, 110000, 121000])
	/// try model.fit(to: revenue)
	/// print("Slope: \(model.slopeValue ?? 0)")  // Growth per period
	/// ```
	public mutating func fit(to timeSeries: TimeSeries<T>) throws {
		guard timeSeries.count >= 2 else {
			throw TrendModelError.insufficientData(required: 2, provided: timeSeries.count)
		}

		// Extract periods and values
		let periods = timeSeries.periods
		let values = timeSeries.valuesArray

		// Create x values as sequential indices
		let xValues = (0..<values.count).map { T($0) }

		// Fit linear regression - store slope and intercept
		self.fittedSlope = try slope(xValues, values)
		self.fittedIntercept = try intercept(xValues, values)
		self.lastPeriod = periods.last
		self.metadata = timeSeries.metadata
		self.fittedDataCount = values.count

		// Calculate and store residuals for confidence intervals
		self.residuals = []
		for (i, actual) in values.enumerated() {
			let fitted = self.fittedSlope! * T(i) + self.fittedIntercept!
			self.residuals.append(actual - fitted)
		}
	}

	/// Project the linear trend forward for a specified number of periods.
	///
	/// Generates future values by extending the fitted line: y = mx + b.
	/// Each projected period continues the linear growth pattern.
	///
	/// - Parameter periods: Number of periods to project forward (must be ≥ 0)
	/// - Returns: Time series containing projected values
	/// - Throws: ``TrendModelError/modelNotFitted`` if model hasn't been fitted yet,
	///           or ``TrendModelError/projectionFailed(_:)`` if periods is negative
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// try model.fit(to: historicalRevenue)
	/// let forecast = try model.project(periods: 12)  // Next 12 periods
	/// ```
	public func project(periods: Int) throws -> TimeSeries<T> {
		guard let slope = fittedSlope, let intercept = fittedIntercept else {
			throw TrendModelError.modelNotFitted
		}

		guard let lastPeriod = lastPeriod else {
			throw TrendModelError.modelNotFitted
		}

		guard periods >= 0 else {
			throw TrendModelError.projectionFailed("Cannot project negative periods")
		}

		guard periods > 0 else {
			// Return empty time series
			return TimeSeries(
				periods: [],
				values: [],
				metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Linear Trend")
			)
		}

		// Generate projections starting from the next period after fitted data
		let startIndex = fittedDataCount
		var futureValues: [T] = []
		var futurePeriods: [Period] = []

		var currentPeriod = lastPeriod

		for i in 0..<periods {
			let index = T(startIndex + i)
			// Linear function: y = slope * x + intercept
			let projectedValue = slope * index + intercept
			futureValues.append(projectedValue)

			// Advance to next period
			currentPeriod = currentPeriod.next()
			futurePeriods.append(currentPeriod)
		}

		return TimeSeries(
			periods: futurePeriods,
			values: futureValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Linear Trend")
		)
	}

	/// Projects future values with confidence intervals.
	///
	/// Generates a forecast with upper and lower bounds representing the specified
	/// confidence level. The confidence intervals widen over time (forecast horizon effect).
	///
	/// - Parameters:
	///   - periods: Number of future periods to project.
	///   - confidenceLevel: The confidence level (e.g., 0.95 for 95% confidence).
	/// - Returns: A forecast with confidence intervals.
	/// - Throws: `TrendModelError.modelNotFitted` if the model hasn't been fitted yet,
	///           or `ForecastError.invalidConfidenceLevel` if confidence level is invalid.
	///
	/// ## Example
	/// ```swift
	/// var model = LinearTrend<Double>()
	/// try model.fit(to: historical)
	///
	/// let forecastWithCI = try model.projectWithConfidence(
	///     periods: 12,
	///     confidenceLevel: 0.95
	/// )
	///
	/// for i in 0..<12 {
	///     let forecast = forecastWithCI.forecast.valuesArray[i]
	///     let lower = forecastWithCI.lowerBound.valuesArray[i]
	///     let upper = forecastWithCI.upperBound.valuesArray[i]
	///     print("Forecast: \(forecast), 95% CI: [\(lower), \(upper)]")
	/// }
	/// ```
	///
	/// ## Notes
	/// - Confidence intervals widen as forecast horizon increases
	/// - Better model fit (lower residuals) produces narrower intervals
	/// - More historical data provides tighter confidence bounds
	public func projectWithConfidence(
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> where T: BinaryFloatingPoint {
		// Generate point forecast
		let forecast = try project(periods: periods)

		// Validate confidence level
		guard confidenceLevel > T.zero && confidenceLevel <= T(1) else {
			throw ForecastError.invalidConfidenceLevel
		}

		// Handle empty forecast
		guard periods > 0 else {
			return ForecastWithConfidence(
				forecast: forecast,
				lowerBound: forecast,
				upperBound: forecast,
				confidenceLevel: confidenceLevel
			)
		}

		// Calculate standard error from residuals
		let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(T.zero, +)
		let degreesOfFreedom = max(residuals.count - 2, 1)  // -2 for slope and intercept
		let mse = sumSquaredResiduals / T(degreesOfFreedom)
		let standardError = sqrt(mse)

		// Get z-score for confidence level using built-in function
		let zScoreValue = zScore(ci: confidenceLevel)

		// Calculate confidence intervals with widening for forecast horizon
		var lowerValues: [T] = []
		var upperValues: [T] = []

		let n = T(fittedDataCount)

		for (h, forecastValue) in forecast.valuesArray.enumerated() {
			let horizon = T(h + 1)

			// Standard error increases with forecast horizon
			// Formula: SE * sqrt(1 + 1/n + (h^2)/(n * sum((x - mean(x))^2)))
			// Simplified approximation for equally-spaced time points
			let term1 = T(1)
			let term2 = T(1) / n
			let term3 = (horizon * horizon) / (T(12) * n)
			let varianceFactor = sqrt(term1 + term2 + term3)
			let forecastSE = standardError * varianceFactor

			let margin = zScoreValue * forecastSE
			lowerValues.append(forecastValue - margin)
			upperValues.append(forecastValue + margin)
		}

		let lowerBound = TimeSeries(
			periods: forecast.periods,
			values: lowerValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Lower Bound")
		)

		let upperBound = TimeSeries(
			periods: forecast.periods,
			values: upperValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Upper Bound")
		)

		return ForecastWithConfidence(
			forecast: forecast,
			lowerBound: lowerBound,
			upperBound: upperBound,
			confidenceLevel: confidenceLevel
		)
	}
}

// MARK: - ExponentialTrend

/// A trend model that fits an exponential curve to time series data.
///
/// Exponential trends capture accelerating or decelerating growth patterns,
/// making them suitable for data that compounds over time.
///
/// **Mathematical Model:**
/// ```
/// y = a × e^(bx)
/// ```
/// Or equivalently:
/// ```
/// y = a × (1 + r)^x
/// ```
/// Where:
/// - a = initial value
/// - b = growth rate coefficient
/// - r = effective growth rate
/// - x = time period
///
/// ## When to Use
///
/// Exponential trends work well when:
/// - Growth compounds over time
/// - Early-stage rapid expansion
/// - Viral or network effects
/// - Investment returns
///
/// ## Examples
///
/// **User Growth:**
/// ```swift
/// let users = TimeSeries(
///     periods: [.month(2024, 1), .month(2024, 2), .month(2024, 3)],
///     values: [1000.0, 1500.0, 2250.0],
///     metadata: TimeSeriesMetadata(name: "Active Users")
/// )
///
/// var model = ExponentialTrend<Double>()
/// try model.fit(to: users)
///
/// let projection = try model.project(periods: 3)
/// // Projects accelerating growth following exponential pattern
/// ```
///
/// **Investment Returns:**
/// ```swift
/// let portfolio = TimeSeries(
///     periods: [.year(2020), .year(2021), .year(2022)],
///     values: [10000.0, 11000.0, 12100.0],  // 10% annual growth
///     metadata: TimeSeriesMetadata(name: "Portfolio Value")
/// )
///
/// var model = ExponentialTrend<Double>()
/// try model.fit(to: portfolio)
///
/// let forecast = try model.project(periods: 5)
/// // Projects compound growth over 5 years
/// ```
///
/// ## Advantages
/// - Captures compounding effects
/// - Natural for percentage growth rates
/// - Good for financial projections
/// - Models viral/network effects
///
/// ## Limitations
/// - Can overestimate long-term growth
/// - Requires positive values (uses logarithms)
/// - May produce unrealistic projections
/// - Sensitive to outliers
///
/// ## Implementation Details
///
/// Uses log-linear regression: transforms data using logarithms, fits a linear
/// model, then transforms predictions back using exponentials.
public struct ExponentialTrend<T: Real & Sendable>: TrendModel, Sendable {
	/// The numeric type for trend values.
	///
	/// Conforms to `Real` for mathematical operations and `Sendable` for concurrency safety.
	public typealias Value = T

	private var fittedLogSlope: T?
	private var fittedLogIntercept: T?
	private var lastPeriod: Period?
	private var metadata: TimeSeriesMetadata?
	private var fittedDataCount: Int = 0
	private var residuals: [T] = []

	/// Creates a new exponential trend model.
	public init() {}

	/// The fitted log-space slope (growth rate coefficient).
	///
	/// Returns `nil` if the model hasn't been fitted yet.
	///
	/// This is the 'b' parameter in the equation: y = a × e^(bx)
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: users)
	/// if let b = model.logSlope {
	///     let growthRate = (exp(b) - 1) * 100
	///     print("Compound growth rate: \(growthRate)% per period")
	/// }
	/// ```
	public var logSlope: T? { fittedLogSlope }

	/// The fitted log-space intercept (initial value coefficient).
	///
	/// Returns `nil` if the model hasn't been fitted yet.
	///
	/// The initial value 'a' can be calculated as: a = exp(logIntercept)
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: users)
	/// if let logA = model.logIntercept {
	///     let initialValue = exp(logA)
	///     print("Initial value: \(initialValue)")
	/// }
	/// ```
	public var logIntercept: T? { fittedLogIntercept }

	/// The effective compound growth rate per period.
	///
	/// Returns `nil` if the model hasn't been fitted yet.
	///
	/// Converts the log-slope to an effective percentage growth rate.
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: users)
	/// if let rate = model.growthRate {
	///     print("Growing at \((rate * 100).number(2))% per period")
	/// }
	/// ```
	public var growthRate: T? {
		guard let logSlope = fittedLogSlope else { return nil }
		return T.exp(logSlope) - T(1)
	}

	/// A summary of the fitted model parameters.
	///
	/// Returns a human-readable description of the model, including the
	/// exponential equation and fitted parameters.
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: users)
	/// print(model.summary)
	/// // Output: "ExponentialTrend: y = 1000.0 × e^(0.2x) [15% growth rate] (fitted on 6 data points)"
	/// ```
	public var summary: String {
		guard let logSlope = fittedLogSlope, let logIntercept = fittedLogIntercept else {
			return "ExponentialTrend: Not fitted"
		}
		let a = T.exp(logIntercept)
		let rate = (T.exp(logSlope) - T(1)) * T(100)
		return "ExponentialTrend: y = \(a) × e^(\(logSlope)x) [\(rate)% growth rate] (fitted on \(fittedDataCount) data points)"
	}

	/// Fit the exponential trend model to historical time series data.
	///
	/// Uses log-linear regression: log-transforms the data, fits a linear model,
	/// then transforms back. The model equation is: y = a × e^(bx).
	///
	/// - Parameter timeSeries: Historical data to fit (requires at least 2 points, all positive values)
	/// - Throws: ``TrendModelError/insufficientData(required:provided:)`` if fewer than 2 data points,
	///           or ``TrendModelError/invalidData(_:)`` if any values are ≤ 0
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// let users = TimeSeries(periods: [...], values: [1000, 1150, 1323])
	/// try model.fit(to: users)
	/// print("Growth rate: \((model.growthRate ?? 0) * 100)%")
	/// ```
	public mutating func fit(to timeSeries: TimeSeries<T>) throws {
		guard timeSeries.count >= 2 else {
			throw TrendModelError.insufficientData(required: 2, provided: timeSeries.count)
		}

		let periods = timeSeries.periods
		let values = timeSeries.valuesArray

		// Check for non-positive values
		guard values.allSatisfy({ $0 > T.zero }) else {
			throw TrendModelError.invalidData("Exponential trend requires all positive values")
		}

		// Log-transform the values
		let logValues = values.map { T.log($0) }

		// Create x values as sequential indices
		let xValues = (0..<values.count).map { T($0) }

		// Fit linear regression to log-transformed data
		// Store slope and intercept for log-linear model
		// Then we can transform back: exp(slope * x + intercept)
		self.fittedLogSlope = try slope(xValues, logValues)
		self.fittedLogIntercept = try intercept(xValues, logValues)

		self.lastPeriod = periods.last
		self.metadata = timeSeries.metadata
		self.fittedDataCount = values.count

		// Calculate and store residuals for confidence intervals
		self.residuals = []
		for (i, actual) in values.enumerated() {
			let logFitted = self.fittedLogSlope! * T(i) + self.fittedLogIntercept!
			let fitted = T.exp(logFitted)
			self.residuals.append(actual - fitted)
		}
	}

	/// Project the exponential trend forward for a specified number of periods.
	///
	/// Generates future values following the exponential growth pattern: y = a × e^(bx).
	/// Each projected period continues the compound growth rate.
	///
	/// - Parameter periods: Number of periods to project forward (must be ≥ 0)
	/// - Returns: Time series containing projected values
	/// - Throws: ``TrendModelError/modelNotFitted`` if model hasn't been fitted yet,
	///           or ``TrendModelError/projectionFailed(_:)`` if periods is negative
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: historicalUsers)
	/// let forecast = try model.project(periods: 12)  // Next 12 periods with exponential growth
	/// ```
	public func project(periods: Int) throws -> TimeSeries<T> {
		guard let logSlope = fittedLogSlope, let logIntercept = fittedLogIntercept else {
			throw TrendModelError.modelNotFitted
		}

		guard let lastPeriod = lastPeriod else {
			throw TrendModelError.modelNotFitted
		}

		guard periods >= 0 else {
			throw TrendModelError.projectionFailed("Cannot project negative periods")
		}

		guard periods > 0 else {
			return TimeSeries(
				periods: [],
				values: [],
				metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Exponential Trend")
			)
		}

		// Generate projections starting from the next period after fitted data
		let startIndex = fittedDataCount
		var futureValues: [T] = []
		var futurePeriods: [Period] = []

		var currentPeriod = lastPeriod

		for i in 0..<periods {
			let index = T(startIndex + i)
			// Exponential function: exp(logSlope * x + logIntercept)
			let logValue = logSlope * index + logIntercept
			let projectedValue = T.exp(logValue)
			futureValues.append(projectedValue)

			// Advance to next period
			currentPeriod = currentPeriod.next()
			futurePeriods.append(currentPeriod)
		}

		return TimeSeries(
			periods: futurePeriods,
			values: futureValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Exponential Trend")
		)
	}

	/// Projects future values with confidence intervals.
	///
	/// Generates a forecast with upper and lower bounds representing the specified
	/// confidence level. The confidence intervals widen over time (forecast horizon effect).
	///
	/// - Parameters:
	///   - periods: Number of future periods to project.
	///   - confidenceLevel: The confidence level (e.g., 0.95 for 95% confidence).
	/// - Returns: A forecast with confidence intervals.
	/// - Throws: `TrendModelError.modelNotFitted` if the model hasn't been fitted yet,
	///           or `ForecastError.invalidConfidenceLevel` if confidence level is invalid.
	///
	/// ## Example
	/// ```swift
	/// var model = ExponentialTrend<Double>()
	/// try model.fit(to: historical)
	///
	/// let forecastWithCI = try model.projectWithConfidence(
	///     periods: 12,
	///     confidenceLevel: 0.95
	/// )
	/// ```
	public func projectWithConfidence(
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> where T: BinaryFloatingPoint {
		// Generate point forecast
		let forecast = try project(periods: periods)

		// Validate confidence level
		guard confidenceLevel > T.zero && confidenceLevel <= T(1) else {
			throw ForecastError.invalidConfidenceLevel
		}

		// Handle empty forecast
		guard periods > 0 else {
			return ForecastWithConfidence(
				forecast: forecast,
				lowerBound: forecast,
				upperBound: forecast,
				confidenceLevel: confidenceLevel
			)
		}

		// Calculate standard error from residuals
		let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(T.zero, +)
		let degreesOfFreedom = max(residuals.count - 2, 1)
		let mse = sumSquaredResiduals / T(degreesOfFreedom)
		let standardError = sqrt(mse)

		// Get z-score for confidence level
		let zScoreValue = zScore(ci: confidenceLevel)

		// Calculate confidence intervals
		var lowerValues: [T] = []
		var upperValues: [T] = []

		let n = T(fittedDataCount)

		for (h, forecastValue) in forecast.valuesArray.enumerated() {
			let horizon = T(h + 1)

			// Standard error increases with forecast horizon
			let term1 = T(1)
			let term2 = T(1) / n
			let term3 = (horizon * horizon) / (T(12) * n)
			let varianceFactor = sqrt(term1 + term2 + term3)
			let forecastSE = standardError * varianceFactor

			let margin = zScoreValue * forecastSE
			// For exponential trend, ensure lower bound stays positive
			lowerValues.append(max(forecastValue - margin, T.zero))
			upperValues.append(forecastValue + margin)
		}

		let lowerBound = TimeSeries(
			periods: forecast.periods,
			values: lowerValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Lower Bound")
		)

		let upperBound = TimeSeries(
			periods: forecast.periods,
			values: upperValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Upper Bound")
		)

		return ForecastWithConfidence(
			forecast: forecast,
			lowerBound: lowerBound,
			upperBound: upperBound,
			confidenceLevel: confidenceLevel
		)
	}
}

// MARK: - LogisticTrend

/// A trend model that fits an S-shaped logistic curve to time series data.
///
/// Logistic trends model growth that starts exponentially but gradually slows
/// as it approaches a maximum capacity or saturation point.
///
/// **Mathematical Model:**
/// ```
/// y = L / (1 + e^(-k(x - x₀)))
/// ```
/// Where:
/// - L = carrying capacity (maximum value)
/// - k = steepness of the curve
/// - x₀ = midpoint (inflection point)
/// - x = time period
///
/// ## When to Use
///
/// Logistic trends work well when:
/// - Growth has natural limits
/// - Market saturation occurs
/// - S-curve adoption patterns
/// - Resource constraints exist
///
/// ## Examples
///
/// **Market Penetration:**
/// ```swift
/// let marketShare = TimeSeries(
///     periods: [.year(2020), .year(2021), .year(2022)],
///     values: [5.0, 15.0, 30.0],  // Percentage of market
///     metadata: TimeSeriesMetadata(name: "Market Share")
/// )
///
/// // Market capacity is 80%
/// var model = LogisticTrend<Double>(capacity: 80.0)
/// try model.fit(to: marketShare)
///
/// let projection = try model.project(periods: 10)
/// // Projects S-curve approaching 80% but never exceeding it
/// ```
///
/// **Product Adoption:**
/// ```swift
/// let users = TimeSeries(
///     periods: [.quarter(2024, 1), .quarter(2024, 2), .quarter(2024, 3)],
///     values: [10_000.0, 50_000.0, 150_000.0],
///     metadata: TimeSeriesMetadata(name: "Total Users")
/// )
///
/// // Maximum addressable market: 1 million users
/// var model = LogisticTrend<Double>(capacity: 1_000_000.0)
/// try model.fit(to: users)
///
/// let forecast = try model.project(periods: 8)
/// // Projects adoption curve that slows as it approaches 1M
/// ```
///
/// ## Advantages
/// - Natural saturation modeling
/// - Realistic long-term projections
/// - Models S-curve adoption
/// - Bounded growth (won't project above capacity)
///
/// ## Limitations
/// - Requires specifying capacity in advance
/// - Needs data showing inflection point for good fit
/// - More complex than linear/exponential
/// - Sensitive to capacity parameter choice
///
/// ## Implementation Details
///
/// Uses nonlinear least-squares fitting to estimate the steepness (k) and
/// midpoint (x₀) parameters given a fixed capacity (L).
public struct LogisticTrend<T: Real & Sendable>: TrendModel, Sendable {
	/// The numeric type for trend values.
	///
	/// Conforms to `Real` for mathematical operations and `Sendable` for concurrency safety.
	public typealias Value = T

	/// The maximum capacity that growth approaches asymptotically.
	public let capacity: T

	private var k: T?  // Steepness parameter
	private var x0: T?  // Midpoint parameter
	private var lastPeriod: Period?
	private var metadata: TimeSeriesMetadata?
	private var fittedDataCount: Int = 0
	private var residuals: [T] = []

	/// Creates a new logistic trend model with the specified capacity.
	///
	/// - Parameter capacity: The maximum value that the growth curve approaches.
	///   This represents the theoretical limit or saturation point.
	public init(capacity: T) {
		self.capacity = capacity
	}

	/// Fits the logistic trend model to historical time series data.
	///
	/// Estimates the steepness (k) and midpoint (x₀) parameters for the logistic curve
	/// given the fixed capacity. Uses simple heuristics based on data characteristics.
	///
	/// - Parameter timeSeries: Historical data to fit (requires at least 3 points, all positive and below capacity)
	/// - Throws: ``TrendModelError/insufficientData(required:provided:)`` if fewer than 3 data points,
	///           or ``TrendModelError/invalidData(_:)`` if any values are ≤ 0 or ≥ capacity
	///
	/// ## Example
	/// ```swift
	/// var model = LogisticTrend<Double>(capacity: 100_000.0)
	/// let users = TimeSeries(periods: [...], values: [1000, 5000, 15000])
	/// try model.fit(to: users)
	/// ```
	public mutating func fit(to timeSeries: TimeSeries<T>) throws {
		guard timeSeries.count >= 3 else {
			throw TrendModelError.insufficientData(required: 3, provided: timeSeries.count)
		}

		let periods = timeSeries.periods
		let values = timeSeries.valuesArray

		// Check that all values are positive and below capacity
		guard values.allSatisfy({ $0 > T.zero && $0 < capacity }) else {
			throw TrendModelError.invalidData("Logistic trend requires positive values below capacity")
		}

		// Use simple parameter estimation
		// For a logistic curve, we can estimate k and x0 from the data

		// Estimate midpoint as the index where value is closest to L/2
		let halfCapacity = capacity / T(2)
		var bestMidpointIndex = 0
		var minDistance = T.infinity

		for (index, value) in values.enumerated() {
			let diff = value - halfCapacity
			let distance = diff < T.zero ? -diff : diff  // abs(diff)
			if distance < minDistance {
				minDistance = distance
				bestMidpointIndex = index
			}
		}

		self.x0 = T(bestMidpointIndex)

		// Estimate steepness k from the growth rate near the midpoint
		// k ≈ (growth rate) / (L/4) near the midpoint
		// Use a simple approximation based on the data spread
		let dataRange = values.max()! - values.min()!
		let indexRange = T(values.count - 1)

		// Simple heuristic: k controls how quickly the curve rises
		// Higher k = steeper curve
		self.k = T(4) * dataRange / (capacity * indexRange)

		// Clamp k to reasonable values
		if let currentK = self.k {
			let minK = T(1) / T(10)  // 0.1
			let maxK = T(10)
			if currentK < minK {
				self.k = minK
			} else if currentK > maxK {
				self.k = maxK
			}
		}

		self.lastPeriod = periods.last
		self.metadata = timeSeries.metadata
		self.fittedDataCount = values.count

		// Calculate and store residuals for confidence intervals
		self.residuals = []
		// Capture values to avoid mutating self in closure
		let kValue = self.k!
		let x0Value = self.x0!
		let capacityValue = self.capacity

		for (i, actual) in values.enumerated() {
			let exponent = -kValue * (T(i) - x0Value)
			let denominator = T(1) + T.exp(exponent)
			let fitted = capacityValue / denominator
			self.residuals.append(actual - fitted)
		}
	}

	/// Projects the logistic trend forward for a specified number of periods.
	///
	/// Generates future values following the S-curve pattern approaching the capacity limit.
	/// Each projected value respects the maximum capacity constraint.
	///
	/// - Parameter periods: Number of periods to project forward (must be ≥ 0)
	/// - Returns: Time series containing projected values
	/// - Throws: ``TrendModelError/modelNotFitted`` if model hasn't been fitted yet,
	///           or ``TrendModelError/projectionFailed(_:)`` if periods is negative
	///
	/// ## Example
	/// ```swift
	/// var model = LogisticTrend<Double>(capacity: 1_000_000.0)
	/// try model.fit(to: userGrowth)
	/// let forecast = try model.project(periods: 12)  // Next 12 periods with S-curve growth
	/// ```
	public func project(periods: Int) throws -> TimeSeries<T> {
		guard let k = k, let x0 = x0 else {
			throw TrendModelError.modelNotFitted
		}

		guard let lastPeriod = lastPeriod else {
			throw TrendModelError.modelNotFitted
		}

		guard periods >= 0 else {
			throw TrendModelError.projectionFailed("Cannot project negative periods")
		}

		guard periods > 0 else {
			return TimeSeries(
				periods: [],
				values: [],
				metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Logistic Trend")
			)
		}

		// Logistic function: L / (1 + e^(-k(x - x0)))
		let logisticFunction: (T) -> T = { x in
			let exponent = -k * (x - x0)
			let denominator = T(1) + T.exp(exponent)
			return self.capacity / denominator
		}

		// Generate projections
		let startIndex = fittedDataCount
		var futureValues: [T] = []
		var futurePeriods: [Period] = []

		var currentPeriod = lastPeriod

		for i in 0..<periods {
			let index = T(startIndex + i)
			let projectedValue = logisticFunction(index)
			futureValues.append(projectedValue)

			currentPeriod = currentPeriod.next()
			futurePeriods.append(currentPeriod)
		}

		return TimeSeries(
			periods: futurePeriods,
			values: futureValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Logistic Trend")
		)
	}

	/// Projects future values with confidence intervals.
	///
	/// Generates a forecast with upper and lower bounds representing the specified
	/// confidence level. The confidence intervals widen over time (forecast horizon effect).
	///
	/// - Parameters:
	///   - periods: Number of future periods to project.
	///   - confidenceLevel: The confidence level (e.g., 0.95 for 95% confidence).
	/// - Returns: A forecast with confidence intervals.
	/// - Throws: `TrendModelError.modelNotFitted` if the model hasn't been fitted yet,
	///           or `ForecastError.invalidConfidenceLevel` if confidence level is invalid.
	///
	/// ## Example
	/// ```swift
	/// var model = LogisticTrend<Double>(capacity: 1000.0)
	/// try model.fit(to: historical)
	///
	/// let forecastWithCI = try model.projectWithConfidence(
	///     periods: 12,
	///     confidenceLevel: 0.95
	/// )
	/// ```
	public func projectWithConfidence(
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> where T: BinaryFloatingPoint {
		// Generate point forecast
		let forecast = try project(periods: periods)

		// Validate confidence level
		guard confidenceLevel > T.zero && confidenceLevel <= T(1) else {
			throw ForecastError.invalidConfidenceLevel
		}

		// Handle empty forecast
		guard periods > 0 else {
			return ForecastWithConfidence(
				forecast: forecast,
				lowerBound: forecast,
				upperBound: forecast,
				confidenceLevel: confidenceLevel
			)
		}

		// Calculate standard error from residuals
		let sumSquaredResiduals = residuals.map { $0 * $0 }.reduce(T.zero, +)
		let degreesOfFreedom = max(residuals.count - 3, 1)  // -3 for logistic parameters
		let mse = sumSquaredResiduals / T(degreesOfFreedom)
		let standardError = sqrt(mse)

		// Get z-score for confidence level
		let zScoreValue = zScore(ci: confidenceLevel)

		// Calculate confidence intervals
		var lowerValues: [T] = []
		var upperValues: [T] = []

		let n = T(fittedDataCount)

		for (h, forecastValue) in forecast.valuesArray.enumerated() {
			let horizon = T(h + 1)

			// Standard error increases with forecast horizon
			// Break down complex expression to avoid compiler timeout
			let term1 = T(1)
			let term2 = T(1) / n
			let term3 = (horizon * horizon) / (T(12) * n)
			let varianceFactor = sqrt(term1 + term2 + term3)
			let forecastSE = standardError * varianceFactor

			let margin = zScoreValue * forecastSE
			// Ensure bounds respect capacity constraint
			lowerValues.append(max(forecastValue - margin, T.zero))
			upperValues.append(min(forecastValue + margin, capacity))
		}

		let lowerBound = TimeSeries(
			periods: forecast.periods,
			values: lowerValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Lower Bound")
		)

		let upperBound = TimeSeries(
			periods: forecast.periods,
			values: upperValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Upper Bound")
		)

		return ForecastWithConfidence(
			forecast: forecast,
			lowerBound: lowerBound,
			upperBound: upperBound,
			confidenceLevel: confidenceLevel
		)
	}
}

// MARK: - CustomTrend

/// A trend model that uses a custom function to project future values.
///
/// Custom trends allow you to define your own projection logic using a closure,
/// providing maximum flexibility for unique or complex trend patterns.
///
/// **Mathematical Model:**
/// ```
/// y = f(x)
/// ```
/// Where f is any user-defined function of time period x.
///
/// ## When to Use
///
/// Custom trends work well when:
/// - Standard models don't fit your pattern
/// - You have domain-specific knowledge
/// - Combining multiple factors
/// - Implementing seasonal adjustments
///
/// ## Examples
///
/// **Quadratic Growth:**
/// ```swift
/// let data = TimeSeries(
///     periods: [.year(2020), .year(2021), .year(2022)],
///     values: [1.0, 4.0, 9.0],
///     metadata: TimeSeriesMetadata(name: "Quadratic Data")
/// )
///
/// // Custom trend: f(t) = t²
/// var model = CustomTrend<Double> { t in
///     t * t
/// }
/// try model.fit(to: data)
///
/// let projection = try model.project(periods: 3)
/// // Projects: 16, 25, 36 (continuing quadratic pattern)
/// ```
///
/// **Seasonal Pattern:**
/// ```swift
/// // Custom trend with seasonality
/// var model = CustomTrend<Double> { t in
///     let baseGrowth = 1000.0 * (1.0 + 0.1 * t)  // 10% annual growth
///     let seasonal = sin(t * .pi / 2)  // Quarterly seasonality
///     return baseGrowth * (1.0 + 0.2 * seasonal)
/// }
/// ```
///
/// **Piecewise Function:**
/// ```swift
/// // Different growth rates for different periods
/// var model = CustomTrend<Double> { t in
///     if t < 10.0 {
///         return 100.0 + 10.0 * t  // Linear early growth
///     } else {
///         return 200.0 + 5.0 * (t - 10.0)  // Slower later growth
///     }
/// }
/// ```
///
/// ## Advantages
/// - Complete flexibility
/// - Can encode domain knowledge
/// - Support complex patterns
/// - Combine multiple models
///
/// ## Limitations
/// - No automatic parameter fitting
/// - Requires manual function design
/// - No built-in validation
/// - User responsible for correctness
///
/// ## Implementation Details
///
/// The custom function receives the time period index (starting from 0 for the
/// first historical period) and returns the projected value. During projection,
/// it continues calling the function with increasing indices.
public struct CustomTrend<T: Real & Sendable>: TrendModel, Sendable {
	/// The numeric type for trend values.
	///
	/// Conforms to `Real` for mathematical operations and `Sendable` for concurrency safety.
	public typealias Value = T

	/// The custom trend function that maps time period indices to values.
	public let trendFunction: @Sendable (T) -> T

	private var lastPeriod: Period?
	private var metadata: TimeSeriesMetadata?
	private var fittedDataCount: Int = 0

	/// Creates a new custom trend model with the specified function.
	///
	/// - Parameter trendFunction: A closure that takes a time period index and
	///   returns the projected value. The closure must be `@Sendable` for
	///   thread safety.
	///
	/// ## Example
	/// ```swift
	/// // Exponential function: y = 100 * 1.05^t
	/// let model = CustomTrend<Double> { t in
	///     100.0 * pow(1.05, t)
	/// }
	/// ```
	public init(trendFunction: @escaping @Sendable (T) -> T) {
		self.trendFunction = trendFunction
	}

	/// Fits the custom trend model by storing time series metadata.
	///
	/// For custom trends, "fitting" simply records the historical data characteristics.
	/// The projection function is already defined by the user at initialization.
	///
	/// - Parameter timeSeries: Historical data (requires at least 1 point)
	/// - Throws: ``TrendModelError/insufficientData(required:provided:)`` if empty
	///
	/// ## Example
	/// ```swift
	/// var model = CustomTrend<Double> { t in t * t }
	/// try model.fit(to: historicalData)  // Stores metadata for projection
	/// ```
	public mutating func fit(to timeSeries: TimeSeries<T>) throws {
		guard timeSeries.count >= 1 else {
			throw TrendModelError.insufficientData(required: 1, provided: timeSeries.count)
		}

		// For custom trend, "fitting" just means storing metadata
		// The function is already provided by the user
		self.lastPeriod = timeSeries.periods.last
		self.metadata = timeSeries.metadata
		self.fittedDataCount = timeSeries.count
	}

	/// Projects future values using the custom trend function.
	///
	/// Generates forecast by applying the user-defined trend function to future period indices.
	/// The function continues from where the fitted data ended.
	///
	/// - Parameter periods: Number of periods to project forward (must be ≥ 0)
	/// - Returns: Time series containing projected values
	/// - Throws: ``TrendModelError/modelNotFitted`` if model hasn't been fitted yet,
	///           or ``TrendModelError/projectionFailed(_:)`` if periods is negative
	///
	/// ## Example
	/// ```swift
	/// var model = CustomTrend<Double> { t in 100.0 * pow(1.05, t) }
	/// try model.fit(to: historical)
	/// let forecast = try model.project(periods: 12)  // Next 12 periods using custom function
	/// ```
	public func project(periods: Int) throws -> TimeSeries<T> {
		guard lastPeriod != nil else {
			throw TrendModelError.modelNotFitted
		}

		guard periods >= 0 else {
			throw TrendModelError.projectionFailed("Cannot project negative periods")
		}

		guard periods > 0 else {
			return TimeSeries(
				periods: [],
				values: [],
				metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Custom Trend")
			)
		}

		// Generate projections using the custom function
		let startIndex = fittedDataCount
		var futureValues: [T] = []
		var futurePeriods: [Period] = []

		var currentPeriod = lastPeriod!

		for i in 0..<periods {
			let index = T(startIndex + i)
			let projectedValue = trendFunction(index)
			futureValues.append(projectedValue)

			currentPeriod = currentPeriod.next()
			futurePeriods.append(currentPeriod)
		}

		return TimeSeries(
			periods: futurePeriods,
			values: futureValues,
			metadata: TimeSeriesMetadata(name: "\(metadata?.name ?? "Projection") - Custom Trend")
		)
	}
}
