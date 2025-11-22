//
//  HoltWintersModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - HoltWintersModel

/// Holt-Winters triple exponential smoothing forecasting model.
///
/// `HoltWintersModel` implements the Holt-Winters method for time series
/// forecasting with trend and seasonality. It uses three smoothing parameters:
/// - α (alpha): level smoothing
/// - β (beta): trend smoothing
/// - γ (gamma): seasonal smoothing
///
/// ## Usage
///
/// ```swift
/// var model = HoltWintersModel<Double>(seasonalPeriods: 12)  // Monthly data
/// try model.train(on: historicalData)
///
/// let forecast = model.predict(periods: 12)
/// let withConfidence = model.predictWithConfidence(periods: 12, confidenceLevel: 0.95)
/// ```
public struct HoltWintersModel<T: Real & Sendable & Codable> {

	// MARK: - Properties

	/// Level smoothing parameter (0 < α ≤ 1).
	public let alpha: T

	/// Trend smoothing parameter (0 < β ≤ 1).
	public let beta: T

	/// Seasonal smoothing parameter (0 < γ ≤ 1).
	public let gamma: T

	/// Number of periods in one seasonal cycle.
	public let seasonalPeriods: Int

	// State after training
	private var level: T?
	private var trend: T?
	private var seasonal: [T]?
	private var lastPeriod: Period?
	private var residuals: [T] = []

	// MARK: - Initialization

	/// Creates a Holt-Winters forecasting model.
	///
	/// - Parameters:
	///   - alpha: Level smoothing (0-1). Defaults to 0.2.
	///   - beta: Trend smoothing (0-1). Defaults to 0.1.
	///   - gamma: Seasonal smoothing (0-1). Defaults to 0.1.
	///   - seasonalPeriods: Number of periods in one seasonal cycle.
	public init(
		alpha: T = 0.2,
		beta: T = 0.1,
		gamma: T = 0.1,
		seasonalPeriods: Int
	) {
		self.alpha = alpha
		self.beta = beta
		self.gamma = gamma
		self.seasonalPeriods = seasonalPeriods
	}

	// MARK: - Training

	/// Trains the model on historical data.
	///
	/// Requires at least 2 * seasonalPeriods of data.
	///
	/// - Parameter data: The historical time series data.
	/// - Throws: `ForecastError.insufficientData` if not enough data.
	public mutating func train(on data: TimeSeries<T>) throws {
		let required = seasonalPeriods * 2
		guard data.count >= required else {
			throw ForecastError.insufficientData(required: required, got: data.count)
		}

		let values = data.valuesArray

		// Initialize level as average of first seasonal cycle
		let initialLevel = values.prefix(seasonalPeriods).reduce(T(0), +) / T(seasonalPeriods)

		// Initialize trend from first two cycles
		let firstCycleAvg = values.prefix(seasonalPeriods).reduce(T(0), +) / T(seasonalPeriods)
		let secondCycleAvg = values.dropFirst(seasonalPeriods).prefix(seasonalPeriods).reduce(T(0), +) / T(seasonalPeriods)
		let initialTrend = (secondCycleAvg - firstCycleAvg) / T(seasonalPeriods)

		// Initialize seasonal components
		var initialSeasonal: [T] = []
		for i in 0..<seasonalPeriods {
			let cycleValues = stride(from: i, to: values.count, by: seasonalPeriods).map { values[$0] }
			let cycleMean = cycleValues.reduce(T(0), +) / T(cycleValues.count)
			let overallMean = values.reduce(T(0), +) / T(values.count)
			initialSeasonal.append(cycleMean - overallMean)
		}

		var currentLevel = initialLevel
		var currentTrend = initialTrend
		var currentSeasonal = initialSeasonal
		var errors: [T] = []

		// Run through all data points to update parameters
		for (t, value) in values.enumerated() {
			let seasonalIndex = t % seasonalPeriods

			// Update level
			let newLevel = alpha * (value - currentSeasonal[seasonalIndex]) +
							(T(1) - alpha) * (currentLevel + currentTrend)

			// Update trend
			let newTrend = beta * (newLevel - currentLevel) + (T(1) - beta) * currentTrend

			// Update seasonal
			let newSeasonal = gamma * (value - newLevel) + (T(1) - gamma) * currentSeasonal[seasonalIndex]

			// Calculate residual
			let fitted = (currentLevel + currentTrend) * currentSeasonal[seasonalIndex]
			errors.append(value - fitted)

			currentLevel = newLevel
			currentTrend = newTrend
			currentSeasonal[seasonalIndex] = newSeasonal
		}

		self.level = currentLevel
		self.trend = currentTrend
		self.seasonal = currentSeasonal
		self.lastPeriod = data.periods.last
		self.residuals = errors
	}

	// MARK: - Prediction

	/// Predicts future values.
	///
	/// - Parameter periods: Number of periods to forecast.
	/// - Returns: A time series with the forecasted values.
	public func predict(periods: Int) -> TimeSeries<T> {
		guard let level = level,
			  let trend = trend,
			  let seasonal = seasonal,
			  let lastPeriod = lastPeriod else {
			// Model not trained - return empty forecast
			return TimeSeries(periods: [], values: [])
		}

		var forecastPeriods: [Period] = []
		var forecastValues: [T] = []

		for h in 1...periods {
			// Generate next period
			let nextPeriod = lastPeriod.advanced(by: h)
			forecastPeriods.append(nextPeriod)

			// Calculate forecast: (level + h * trend) + seasonal component
			let seasonalIndex = (h - 1) % seasonalPeriods
			let pointForecast = (level + T(h) * trend) + seasonal[seasonalIndex]

			forecastValues.append(pointForecast)
		}

		return TimeSeries(periods: forecastPeriods, values: forecastValues)
	}

	/// Predicts future values with confidence intervals.
	///
	/// - Parameters:
	///   - periods: Number of periods to forecast.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%).
	/// - Returns: Forecast with confidence intervals.
	public func predictWithConfidence(
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> {
		let forecast = predict(periods: periods)

		// Calculate standard error from residuals
		let mse = residuals.map { $0 * $0 }.reduce(T(0), +) / T(max(residuals.count, 1))
		let standardError = T.sqrt(mse)

		// Z-score for confidence level (approximate)
		// Using simple arithmetic to create fractional values
		let zScore: T
		let level99 = T(99) / T(100)  // 0.99
		let level95 = T(95) / T(100)  // 0.95
		let level90 = T(9) / T(10)    // 0.90
		
		guard confidenceLevel <= T(1) else {
			throw ForecastError.invalidConfidenceLevel
		}

		if confidenceLevel >= level99 {
			zScore = T(2576) / T(1000)  // 2.576
		} else if confidenceLevel >= level95 {
			zScore = T(196) / T(100)    // 1.96
		} else if confidenceLevel >= level90 {
			zScore = T(1645) / T(1000)  // 1.645
		} else {
			zScore = T(128) / T(100)    // 1.28
		}

		// Confidence intervals widen with forecast horizon
		var lowerValues: [T] = []
		var upperValues: [T] = []

		for (h, value) in forecast.valuesArray.enumerated() {
			let horizonFactor = T.sqrt(T(h + 1))
			let margin = zScore * standardError * horizonFactor

			lowerValues.append(value - margin)
			upperValues.append(value + margin)
		}

		return ForecastWithConfidence(
			forecast: forecast,
			lowerBound: TimeSeries(periods: forecast.periods, values: lowerValues),
			upperBound: TimeSeries(periods: forecast.periods, values: upperValues),
			confidenceLevel: confidenceLevel
		)
	}
}
