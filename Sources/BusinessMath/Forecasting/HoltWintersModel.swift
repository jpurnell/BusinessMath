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
/// let historicalData = TimeSeries(periods: Period.documentationQuarters, values: [100, 120, 140, 160])
/// let periods = Period.documentationQuarters
/// var model = HoltWintersModel<Double>(seasonalPeriods: 12)  // Monthly data
/// try model.train(on: historicalData)
///
/// let forecast = model.predict(periods: 12)
/// let withConfidence = try model.predictWithConfidence(periods: 12, confidenceLevel: 0.95)
/// ```
public struct HoltWintersModel<T: Real & Sendable & Codable>: Sendable {

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
	/// One-step-ahead fit errors, one per training observation.
	///
	/// `internal` rather than `private` so the test suite can assert on them directly.
	/// They are not part of the public API, but they are the quantity behind
	/// ``predictWithConfidence(periods:confidenceLevel:)``'s interval width, and they
	/// were wrong — the fitted value multiplied by the seasonal in an additive model —
	/// for as long as nothing could see them.
	internal var residuals: [T] = []

	/// How many observations the model was trained on.
	///
	/// Needed by ``predictValues(periods:)`` to know which point of the seasonal cycle
	/// the series stopped at. Forecasting used to index the seasonal array from zero
	/// regardless, which is right only when the training length happens to be a whole
	/// number of cycles.
	private var trainedCount: Int = 0

	// MARK: - Initialization

	/// Creates a Holt-Winters forecasting model.
	///
	/// - Parameters:
	///   - alpha: Level smoothing (0-1). Defaults to 0.2.
	///   - beta: Trend smoothing (0-1). Defaults to 0.1.
	///   - gamma: Seasonal smoothing (0-1). Defaults to 0.1.
	///   - seasonalPeriods: Number of periods in one seasonal cycle.
	public init(
		alpha: T,
		beta: T,
		gamma: T,
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
	/// - Throws: `ForecastError.insufficientData` if not enough data.
	/// Train the Holt-Winters model on a generic array of values.
	///
	/// Estimates level, trend, and seasonal components using exponential smoothing.
	/// This method works independently of `TimeSeries` and does not set `lastPeriod`.
	///
	/// - Parameter values: Array of numeric values to train on (requires at least `2 * seasonalPeriods` values).
	/// - Throws: ``ForecastError/insufficientData(required:got:)`` if insufficient data.
	///
	/// ## Important
	///
	/// This method does NOT set `lastPeriod`. To generate forecasts as a `TimeSeries`,
	/// either use `train(on:)` with a `TimeSeries` object, or manually set `lastPeriod` after calling this method.
	///
	/// ## Example
	///
	/// ```swift
	/// // Two full seasonal cycles: train(values:) requires seasonalPeriods * 2
	/// let monthlyData = [120.0, 135, 148, 160, 172, 185, 190, 178, 165, 150, 138, 125,
	///                    128, 142, 156, 168, 181, 194, 200, 187, 173, 158, 145, 132]
	/// var model = HoltWintersModel<Double>(alpha: 0.2, beta: 0.1, gamma: 0.1, seasonalPeriods: 12)
	/// try model.train(values: monthlyData)
	/// let futureValues = model.predictValues(periods: 6)
	/// ```
	public mutating func train(values: [T]) throws {
		let required = seasonalPeriods * 2
		guard values.count >= required else {
			throw ForecastError.insufficientData(required: required, got: values.count)
		}

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

			// The one-step-ahead fitted value, l + b + s, which is what this model
			// forecasts. It used to multiply by the seasonal rather than add it — the
			// multiplicative form, in an otherwise wholly additive model. The seasonals
			// here are deviations about zero, not scaling factors, so a level of 150 and
			// a seasonal of −10 produced a fitted value of −1500 instead of 140. On a
			// noiseless series the model fits exactly and the residuals still came out
			// in the hundreds. They feed the mean squared error behind
			// ``predictWithConfidence(periods:confidenceLevel:)``, so every interval it
			// produced was built on them.
			let fitted = (currentLevel + currentTrend) + currentSeasonal[seasonalIndex]
			errors.append(value - fitted)

			currentLevel = newLevel
			currentTrend = newTrend
			currentSeasonal[seasonalIndex] = newSeasonal
		}

		self.level = currentLevel
		self.trend = currentTrend
		self.seasonal = currentSeasonal
		self.residuals = errors
		self.trainedCount = values.count
	}

	/// Train the Holt-Winters model on a time series (convenience method).
	///
	/// Delegates to `train(values:)` and automatically sets `lastPeriod`.
	///
	/// - Parameter data: Time series to train on (requires at least `2 * seasonalPeriods` values).
	/// - Throws: ``ForecastError/insufficientData(required:got:)`` if insufficient data.
	///
	/// ## Example
	///
	/// ```swift
	/// // Holt-Winters needs at least two full cycles, so 24 months of data
	/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
	/// let sales = [120.0, 135, 148, 160, 172, 185, 190, 178, 165, 150, 138, 125,
	///              128, 142, 156, 168, 181, 194, 200, 187, 173, 158, 145, 132]
	/// let monthlySales = TimeSeries(periods: months, values: sales)
	///
	/// var model = HoltWintersModel<Double>(alpha: 0.2, beta: 0.1, gamma: 0.1, seasonalPeriods: 12)
	/// try model.train(on: monthlySales)
	/// if let forecast = model.predict(periods: 6) {
	///     // Use forecast TimeSeries
	/// }
	/// ```
	public mutating func train(on data: TimeSeries<T>) throws {
		try train(values: data.valuesArray)
		self.lastPeriod = data.periods.last
	}

	// MARK: - Prediction

	/// Predict future values using the trained Holt-Winters model.
	///
	/// Returns an array of predicted values without Period labels. This is the core prediction
	/// method that works independently of `TimeSeries`.
	///
	/// - Parameter periods: Number of future values to predict.
	/// - Returns: Array of predicted values, or empty array if model not trained or periods ≤ 0.
	///
	/// ## Example
	///
	/// ```swift
	/// // Two full seasonal cycles: train(values:) requires seasonalPeriods * 2
	/// let monthlyData = [120.0, 135, 148, 160, 172, 185, 190, 178, 165, 150, 138, 125,
	///                    128, 142, 156, 168, 181, 194, 200, 187, 173, 158, 145, 132]
	/// var model = HoltWintersModel<Double>(alpha: 0.2, beta: 0.1, gamma: 0.1, seasonalPeriods: 12)
	/// try model.train(values: monthlyData)
	/// let futureValues = model.predictValues(periods: 6)
	/// ```
	public func predictValues(periods: Int) -> [T] {
		guard let level = level,
			  let trend = trend,
			  let seasonal = seasonal else {
			return []
		}

		guard periods > 0 else { return [] }

		var forecastValues: [T] = []

		for h in 1...periods {
			// Calculate forecast: (level + h * trend) + seasonal component.
			//
			// The phase continues from where training stopped. This used to be
			// `(h - 1) % seasonalPeriods`, which starts every forecast at the first
			// point of the cycle no matter where the data ended — correct only when the
			// training length is a whole number of cycles, which is the case in this
			// type's own example and was the case in its tests. Train on 17 monthly
			// points instead of 24 and the forecast came back shifted by five months,
			// with nothing to indicate it.
			let seasonalIndex = (trainedCount + h - 1) % seasonalPeriods
			let pointForecast = (level + T(h) * trend) + seasonal[seasonalIndex]
			forecastValues.append(pointForecast)
		}

		return forecastValues
	}

	/// Predict future values as a TimeSeries (convenience method).
	///
	/// Delegates to `predictValues(periods:)` and generates Period labels using `lastPeriod`.
	/// Returns `nil` if `lastPeriod` has not been set (call `train(on:)` with a TimeSeries first).
	///
	/// - Parameter periods: Number of periods to forecast.
	/// - Returns: A time series with the forecasted values, or `nil` if `lastPeriod` not set.
	///
	/// ## Example
	///
	/// ```swift
	/// // Holt-Winters needs at least two full cycles, so 24 months of data
	/// let months = (0..<24).map { Period.month(year: 2024 + $0 / 12, month: $0 % 12 + 1) }
	/// let sales = [120.0, 135, 148, 160, 172, 185, 190, 178, 165, 150, 138, 125,
	///              128, 142, 156, 168, 181, 194, 200, 187, 173, 158, 145, 132]
	/// let monthlySales = TimeSeries(periods: months, values: sales)
	///
	/// var model = HoltWintersModel<Double>(alpha: 0.2, beta: 0.1, gamma: 0.1, seasonalPeriods: 12)
	/// try model.train(on: monthlySales)
	/// if let forecast = model.predict(periods: 6) {
	///     // Use forecast TimeSeries
	/// }
	/// ```
	public func predict(periods: Int) -> TimeSeries<T>? {
		guard let lastPeriod = lastPeriod else {
			return nil
		}

		let forecastValues = predictValues(periods: periods)
		guard !forecastValues.isEmpty else {
			return TimeSeries(periods: [], values: [])
		}

		var forecastPeriods: [Period] = []

		for h in 1...periods {
			let nextPeriod = lastPeriod.advanced(by: h)
			forecastPeriods.append(nextPeriod)
		}

		return TimeSeries(periods: forecastPeriods, values: forecastValues)
	}

	/// Predicts future values with confidence intervals.
	///
	/// - Parameters:
	///   - periods: Number of periods to forecast.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%).
	/// - Returns: Forecast with confidence intervals.
	/// - Throws: ``ForecastError`` if model not trained or lastPeriod not set.
	///
	/// - Important: These bands are **parametric and in-sample** (from the training
	///   residuals), so on drifting/event-driven series they can be optimistically
	///   narrow. For out-of-sample uncertainty use
	///   ``BacktestReport/empiricalIntervals(around:confidenceLevel:)`` with a
	///   rolling-origin ``TimeSeries/backtest(_:config:)``.
	public func predictWithConfidence(
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> {
		guard let forecast = predict(periods: periods) else {
			throw ForecastError.modelNotTrained
		}

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

	// MARK: - Convenience Methods

	/// Trains on historical data and immediately generates a forecast.
	///
	/// This is a convenience method that combines `train(on:)` and `predict(periods:)`
	/// into a single call for quick forecasting tasks.
	///
	/// - Parameters:
	///   - timeSeries: The historical time series data to train on.
	///   - periods: Number of periods to forecast.
	/// - Returns: A time series with the forecasted values.
	/// - Throws: `ForecastError.insufficientData` if not enough training data.
	public func forecast(timeSeries: TimeSeries<T>, periods: Int) throws -> TimeSeries<T> {
		var mutableModel = self
		try mutableModel.train(on: timeSeries)
		guard let forecast = mutableModel.predict(periods: periods) else {
			throw ForecastError.modelNotTrained
		}
		return forecast
	}

	/// Trains on historical data and generates a forecast with confidence intervals.
	///
	/// This is a convenience method that combines `train(on:)` and
	/// `predictWithConfidence(periods:confidenceLevel:)` into a single call.
	///
	/// - Parameters:
	///   - timeSeries: The historical time series data to train on.
	///   - periods: Number of periods to forecast.
	///   - confidenceLevel: Confidence level (e.g., 0.95 for 95%).
	/// - Returns: Forecast with confidence intervals.
	/// - Throws: `ForecastError.insufficientData` or `ForecastError.invalidConfidenceLevel`.
	public func forecastWithConfidence(
		timeSeries: TimeSeries<T>,
		periods: Int,
		confidenceLevel: T
	) throws -> ForecastWithConfidence<T> {
		var mutableModel = self
		try mutableModel.train(on: timeSeries)
		return try mutableModel.predictWithConfidence(periods: periods, confidenceLevel: confidenceLevel)
	}
}

// MARK: - HoltWintersModel Double Defaults

extension HoltWintersModel where T == Double {
	/// Creates a Holt-Winters forecasting model with default smoothing parameters.
	///
	/// - Parameters:
	///   - alpha: Level smoothing (0-1). Defaults to 0.2.
	///   - beta: Trend smoothing (0-1). Defaults to 0.1.
	///   - gamma: Seasonal smoothing (0-1). Defaults to 0.1.
	///   - seasonalPeriods: Number of periods in one seasonal cycle.
	public init(
		alpha: Double = 0.2,
		beta: Double = 0.1,
		gamma: Double = 0.1,
		seasonalPeriods: Int
	) {
		self.alpha = alpha
		self.beta = beta
		self.gamma = gamma
		self.seasonalPeriods = seasonalPeriods
	}
}
