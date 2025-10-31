//
//  MovingAverageModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/31/25.
//

import Foundation
import Numerics

// MARK: - MovingAverageModel

/// Simple moving average forecasting model.
///
/// `MovingAverageModel` forecasts future values as the average of the last
/// N observations. This is a simple but effective method for short-term
/// forecasting of stationary time series.
///
/// ## Usage
///
/// ```swift
/// var model = MovingAverageModel<Double>(window: 12)
/// try model.train(on: historicalData)
///
/// let forecast = model.predict(periods: 6)
/// ```
public struct MovingAverageModel<T: Real & Sendable & Codable> {

	// MARK: - Properties

	/// The number of historical periods to average.
	public let window: Int

	// State after training
	private var movingAverage: T?
	private var lastPeriod: Period?
	private var historicalValues: [T] = []

	// MARK: - Initialization

	/// Creates a moving average forecasting model.
	///
	/// - Parameter window: Number of periods to average.
	public init(window: Int) {
		self.window = window
	}

	// MARK: - Training

	/// Trains the model on historical data.
	///
	/// Requires at least `window` periods of data.
	///
	/// - Parameter data: The historical time series data.
	/// - Throws: `ForecastError.insufficientData` if not enough data.
	public mutating func train(on data: TimeSeries<T>) throws {
		guard data.count >= window else {
			throw ForecastError.insufficientData(required: window, got: data.count)
		}

		// Calculate moving average of last `window` values
		let lastValues = Array(data.valuesArray.suffix(window))
		let average = lastValues.reduce(T(0), +) / T(window)

		self.movingAverage = average
		self.lastPeriod = data.periods.last
		self.historicalValues = Array(data.valuesArray)
	}

	// MARK: - Prediction

	/// Predicts future values.
	///
	/// All forecasted values are the same (the moving average).
	///
	/// - Parameter periods: Number of periods to forecast.
	/// - Returns: A time series with the forecasted values.
	public func predict(periods: Int) -> TimeSeries<T> {
		guard let average = movingAverage,
			  let lastPeriod = lastPeriod else {
			return TimeSeries(periods: [], values: [])
		}

		var forecastPeriods: [Period] = []
		var forecastValues: [T] = []

		for h in 1...periods {
			let nextPeriod = lastPeriod.advanced(by: h)
			forecastPeriods.append(nextPeriod)
			forecastValues.append(average)
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
	) -> ForecastWithConfidence<T> {
		let forecast = predict(periods: periods)

		guard let average = movingAverage else {
			return ForecastWithConfidence(
				forecast: forecast,
				lowerBound: forecast,
				upperBound: forecast,
				confidenceLevel: confidenceLevel
			)
		}

		// Calculate standard deviation of historical values
		let mean = historicalValues.reduce(T(0), +) / T(historicalValues.count)
		let squaredDiffs = historicalValues.map { ($0 - mean) * ($0 - mean) }
		let variance = squaredDiffs.reduce(T(0), +) / T(max(historicalValues.count - 1, 1))
		let standardError = T.sqrt(variance / T(window))

		// Z-score for confidence level
		let zScore: T
		let level99 = T(99) / T(100)  // 0.99
		let level95 = T(95) / T(100)  // 0.95
		let level90 = T(9) / T(10)    // 0.90

		if confidenceLevel >= level99 {
			zScore = T(2576) / T(1000)  // 2.576
		} else if confidenceLevel >= level95 {
			zScore = T(196) / T(100)    // 1.96
		} else if confidenceLevel >= level90 {
			zScore = T(1645) / T(1000)  // 1.645
		} else {
			zScore = T(128) / T(100)    // 1.28
		}

		// Confidence intervals (constant width since forecast is constant)
		let margin = zScore * standardError

		var lowerValues: [T] = []
		var upperValues: [T] = []

		for value in forecast.valuesArray {
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
