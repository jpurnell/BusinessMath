//
//  Seasonality.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Numerics

// MARK: - Seasonality Error

/// Errors that can occur during seasonality analysis.
public enum SeasonalityError: Error, Sendable {
	/// Insufficient data for the requested operation.
	case insufficientData(required: Int, provided: Int)

	/// Mismatched array sizes between time series and seasonal indices.
	case mismatchedSizes(timeSeriesCount: Int, indicesCount: Int)

	/// Invalid periods per year value.
	case invalidPeriodsPerYear(Int)

	/// Division by zero in multiplicative decomposition.
	case divisionByZero(String)
}

// MARK: - Decomposition Method

/// The method used for time series decomposition.
///
/// Time series decomposition separates a time series into three components:
/// trend, seasonal, and residual. The method determines how these components
/// combine to form the original series.
///
/// ## Choosing a Decomposition Method
///
/// | Method | Formula | When to Use |
/// |--------|---------|-------------|
/// | **Additive** | `Value = Trend + Seasonal + Residual` | Seasonal variation is constant over time |
/// | **Multiplicative** | `Value = Trend × Seasonal × Residual` | Seasonal variation grows with the trend |
///
/// ## Examples
///
/// **Additive:** Monthly temperature (seasonal variation is constant)
/// - Trend: warming climate
/// - Seasonal: ±20°F variation each year
/// - The variation stays the same regardless of the trend level
///
/// **Multiplicative:** Retail sales (seasonal variation grows with business)
/// - Trend: business growth
/// - Seasonal: 50% higher in Q4
/// - As sales grow, the absolute seasonal variation grows too
public enum DecompositionMethod: Sendable {
	/// Additive decomposition: Value = Trend + Seasonal + Residual
	///
	/// Use when seasonal fluctuations are roughly constant over time,
	/// independent of the level of the time series.
	case additive

	/// Multiplicative decomposition: Value = Trend × Seasonal × Residual
	///
	/// Use when seasonal fluctuations grow proportionally with the level
	/// of the time series.
	case multiplicative
}

// MARK: - Time Series Decomposition

/// The result of decomposing a time series into trend, seasonal, and residual components.
///
/// Time series decomposition is a fundamental technique in time series analysis that
/// separates a series into three components:
///
/// - **Trend**: The long-term progression of the series (growth or decline)
/// - **Seasonal**: Regular, repeating patterns (quarterly, monthly, etc.)
/// - **Residual**: Random, irregular fluctuations not explained by trend or seasonality
///
/// ## Decomposition Methods
///
/// **Additive:** `Value = Trend + Seasonal + Residual`
/// - Use when seasonal variation is constant
///
/// **Multiplicative:** `Value = Trend × Seasonal × Residual`
/// - Use when seasonal variation grows with the level
///
/// ## Use Cases
///
/// - **Forecasting:** Model trend and seasonality separately
/// - **Anomaly Detection:** Identify unusual residuals
/// - **Seasonality Analysis:** Quantify seasonal effects
/// - **Detrending:** Remove long-term patterns to see short-term effects
/// - **Quality Control:** Separate signal from noise
///
/// ## Example
///
/// ```swift
/// // Quarterly sales data with seasonality
/// let sales = TimeSeries(
///     periods: quarters,
///     values: [100, 120, 80, 100, 110, 132, 88, 110],
///     metadata: TimeSeriesMetadata(name: "Sales")
/// )
///
/// let decomposition = try decomposeTimeSeries(
///     timeSeries: sales,
///     periodsPerYear: 4,
///     method: .multiplicative
/// )
///
/// // Analyze components
/// print("Trend shows \(decomposition.trend.valuesArray.last!) at end")
/// print("Q4 seasonal index: \(decomposition.seasonal.valuesArray[3])")
/// print("Average residual: \(decomposition.residual.valuesArray.reduce(0,+)/Double(decomposition.residual.count))")
/// ```
public struct TimeSeriesDecomposition<T: Real & Sendable>: Sendable {
	/// The trend component showing long-term progression.
	///
	/// Calculated using centered moving average to smooth out
	/// short-term fluctuations and reveal the underlying direction.
	public let trend: TimeSeries<T>

	/// The seasonal component showing repeating patterns.
	///
	/// For multiplicative decomposition, these are multipliers (e.g., 1.2 = 20% above average).
	/// For additive decomposition, these are differences (e.g., +20 = 20 units above trend).
	public let seasonal: TimeSeries<T>

	/// The residual component showing unexplained variation.
	///
	/// Represents random fluctuations, measurement errors, or effects
	/// not captured by the trend and seasonal components.
	///
	/// For multiplicative: `Residual = Original / (Trend × Seasonal)`
	/// For additive: `Residual = Original - Trend - Seasonal`
	public let residual: TimeSeries<T>

	/// The decomposition method used (additive or multiplicative).
	public let method: DecompositionMethod

	/// Creates a new time series decomposition result.
	public init(
		trend: TimeSeries<T>,
		seasonal: TimeSeries<T>,
		residual: TimeSeries<T>,
		method: DecompositionMethod
	) {
		self.trend = trend
		self.seasonal = seasonal
		self.residual = residual
		self.method = method
	}
}

// MARK: - Seasonal Indices

/// Calculates seasonal indices for a time series.
///
/// Seasonal indices quantify the typical seasonal pattern by calculating the average
/// effect of each season relative to the overall level. For example, a quarterly
/// index of 1.2 for Q4 means Q4 is typically 20% above the annual average.
///
/// **Formula (Multiplicative):**
/// ```
/// Index[season] = Average(Value[season] / Trend[season])
/// ```
///
/// The indices are normalized to average to 1.0, meaning:
/// - Index > 1.0: Above average for that season
/// - Index = 1.0: Average for that season
/// - Index < 1.0: Below average for that season
///
/// - Parameters:
///   - timeSeries: The time series data to analyze
///   - periodsPerYear: Number of periods in one seasonal cycle (e.g., 4 for quarterly, 12 for monthly)
/// - Returns: Array of seasonal indices, one per season
/// - Throws: `SeasonalityError` if insufficient data or invalid parameters
///
/// ## Examples
///
/// **Quarterly Business Cycle:**
/// ```swift
/// // Sales data with Q4 holiday spike
/// let sales = TimeSeries(
///     periods: quarters,
///     values: [100, 105, 110, 165, 110, 115, 120, 180],
///     metadata: TimeSeriesMetadata(name: "Sales")
/// )
///
/// let indices = try seasonalIndices(timeSeries: sales, periodsPerYear: 4)
/// // Result: [0.95, 1.00, 1.05, 1.60]
/// // Q4 is 60% above average
/// ```
///
/// **Monthly Subscription Revenue:**
/// ```swift
/// let mrr = createMonthlyData(values: subscriptionData)
/// let indices = try seasonalIndices(timeSeries: mrr, periodsPerYear: 12)
/// // Shows which months typically have higher/lower revenue
/// ```
///
/// ## Requirements
///
/// - At least 2 complete seasonal cycles (e.g., 8 quarters for quarterly data)
/// - periodsPerYear must be positive and divide evenly into the data length
///
/// ## Use Cases
///
/// - **Forecasting:** Apply historical seasonal patterns to projections
/// - **Budgeting:** Adjust targets based on typical seasonal effects
/// - **Performance Analysis:** Compare actual vs. seasonally-adjusted results
/// - **Capacity Planning:** Plan resources for high/low seasons
public func seasonalIndices<T: Real & Sendable>(
	timeSeries: TimeSeries<T>,
	periodsPerYear: Int
) throws -> [T] {
	guard periodsPerYear > 0 else {
		throw SeasonalityError.invalidPeriodsPerYear(periodsPerYear)
	}

	guard timeSeries.count >= periodsPerYear * 2 else {
		throw SeasonalityError.insufficientData(
			required: periodsPerYear * 2,
			provided: timeSeries.count
		)
	}

	let values = timeSeries.valuesArray

	// Calculate centered moving average (trend)
	let trend = calculateCenteredMovingAverage(values: values, window: periodsPerYear)

	// Calculate ratios (value / trend) for each period
	var seasonalRatios: [[T]] = Array(repeating: [], count: periodsPerYear)

	for i in 0..<values.count {
		if i < trend.count && !trend[i].isNaN && trend[i] != T.zero {
			let ratio = values[i] / trend[i]
			let seasonIndex = i % periodsPerYear
			seasonalRatios[seasonIndex].append(ratio)
		}
	}

	// Average the ratios for each season
	var indices: [T] = []
	for ratios in seasonalRatios {
		guard !ratios.isEmpty else {
			indices.append(T(1))
			continue
		}
		let average = ratios.reduce(T.zero, +) / T(ratios.count)
		indices.append(average)
	}

	// Normalize so indices average to 1.0
	let indexSum = indices.reduce(T.zero, +)
	let indexAverage = indexSum / T(indices.count)

	if indexAverage != T.zero {
		indices = indices.map { $0 / indexAverage }
	}

	return indices
}

// MARK: - Seasonally Adjust

/// Removes seasonal effects from a time series to reveal the underlying trend.
///
/// Seasonal adjustment (also called deseasonalization) removes the regular,
/// predictable seasonal patterns to make it easier to identify the true underlying
/// trend and compare periods that would otherwise be affected by seasonality.
///
/// **Formula:**
/// ```
/// Adjusted Value = Original Value / Seasonal Index
/// ```
///
/// - Parameters:
///   - timeSeries: The time series to adjust
///   - indices: Seasonal indices for each period (from `seasonalIndices()`)
/// - Returns: Seasonally adjusted time series
/// - Throws: `SeasonalityError` if indices don't match the seasonal pattern
///
/// ## Examples
///
/// **Remove Holiday Seasonality:**
/// ```swift
/// let sales = TimeSeries(periods: quarters, values: [100, 120, 80, 100, ...])
/// let indices = try seasonalIndices(timeSeries: sales, periodsPerYear: 4)
/// let adjusted = try seasonallyAdjust(timeSeries: sales, indices: indices)
///
/// // adjusted now shows underlying trend without Q4 holiday spikes
/// ```
///
/// **Compare Year-Over-Year Growth:**
/// ```swift
/// // Without adjustment, Q4 always looks like huge growth
/// let rawGrowth = (salesQ4 - salesQ3) / salesQ3  // Misleading
///
/// // With adjustment, see true underlying growth
/// let adjustedGrowth = (adjustedQ4 - adjustedQ3) / adjustedQ3  // Accurate
/// ```
///
/// ## Use Cases
///
/// - **Trend Analysis:** See true growth without seasonal noise
/// - **Performance Evaluation:** Compare periods fairly (e.g., Q1 vs Q4)
/// - **Leading Indicators:** Detect turning points earlier
/// - **Reporting:** Present "apples to apples" comparisons
/// - **Anomaly Detection:** Identify unusual patterns more easily
///
/// ## Important Notes
///
/// - The number of indices must match `periodsPerYear`
/// - Use indices calculated from the same or similar data
/// - Adjusted data is for analysis only; forecasts should include seasonality
public func seasonallyAdjust<T: Real & Sendable>(
	timeSeries: TimeSeries<T>,
	indices: [T]
) throws -> TimeSeries<T> {
	guard !indices.isEmpty else {
		throw SeasonalityError.mismatchedSizes(
			timeSeriesCount: timeSeries.count,
			indicesCount: indices.count
		)
	}

	// Validate that the time series length makes sense for the indices
	// The indices represent one complete cycle (e.g., 4 quarters)
	// While we allow any length, we should warn if indices don't match a pattern
	let periodsPerYear = indices.count
	if timeSeries.count < periodsPerYear {
		throw SeasonalityError.insufficientData(
			required: periodsPerYear,
			provided: timeSeries.count
		)
	}

	var adjustedValues: [T] = []

	for (i, value) in timeSeries.valuesArray.enumerated() {
		let seasonIndex = i % indices.count
		let seasonalIndex = indices[seasonIndex]

		guard seasonalIndex != T.zero else {
			throw SeasonalityError.divisionByZero("Seasonal index is zero at position \(seasonIndex)")
		}

		// Divide by seasonal index to remove seasonality
		let adjusted = value / seasonalIndex
		adjustedValues.append(adjusted)
	}

	return TimeSeries(
		periods: timeSeries.periods,
		values: adjustedValues,
		metadata: TimeSeriesMetadata(name: "\(timeSeries.metadata.name) - Seasonally Adjusted")
	)
}

// MARK: - Apply Seasonal

/// Applies seasonal patterns to a time series (adds seasonality back).
///
/// This is the inverse of `seasonallyAdjust()`. It applies seasonal indices
/// to a trend or forecast to add realistic seasonal variation.
///
/// **Formula:**
/// ```
/// Seasonalized Value = Original Value × Seasonal Index
/// ```
///
/// - Parameters:
///   - timeSeries: The time series to seasonalize (typically a trend or forecast)
///   - indices: Seasonal indices to apply
/// - Returns: Time series with seasonal patterns applied
/// - Throws: `SeasonalityError` if indices don't match the seasonal pattern
///
/// ## Examples
///
/// **Add Seasonality to Forecast:**
/// ```swift
/// // Start with trend-only forecast
/// let trendForecast = try linearTrend.project(periods: 4)
///
/// // Apply historical seasonal pattern
/// let indices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)
/// let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)
///
/// // seasonalForecast now includes realistic seasonal variation
/// ```
///
/// **Reconstruct Original Data:**
/// ```swift
/// let adjusted = try seasonallyAdjust(timeSeries: original, indices: indices)
/// let reconstructed = try applySeasonal(timeSeries: adjusted, indices: indices)
///
/// // reconstructed ≈ original (within rounding)
/// ```
///
/// ## Use Cases
///
/// - **Forecasting:** Add seasonality to trend-based projections
/// - **Simulation:** Generate realistic seasonal data
/// - **Budgeting:** Create seasonal budget targets from annual goals
/// - **Validation:** Verify seasonal adjustment is reversible
///
/// ## Important Notes
///
/// - `applySeasonal()` and `seasonallyAdjust()` are inverse operations
/// - Apply seasonal indices from the same periodsPerYear
/// - Indices cycle: index[0], index[1], ..., index[n-1], index[0], ...
public func applySeasonal<T: Real & Sendable>(
	timeSeries: TimeSeries<T>,
	indices: [T]
) throws -> TimeSeries<T> {
	guard !indices.isEmpty else {
		throw SeasonalityError.mismatchedSizes(
			timeSeriesCount: timeSeries.count,
			indicesCount: indices.count
		)
	}

	var seasonalizedValues: [T] = []

	for (i, value) in timeSeries.valuesArray.enumerated() {
		let seasonIndex = i % indices.count
		let seasonalIndex = indices[seasonIndex]

		// Multiply by seasonal index to apply seasonality
		let seasonalized = value * seasonalIndex
		seasonalizedValues.append(seasonalized)
	}

	return TimeSeries(
		periods: timeSeries.periods,
		values: seasonalizedValues,
		metadata: TimeSeriesMetadata(name: "\(timeSeries.metadata.name) - Seasonalized")
	)
}

// MARK: - Decompose Time Series

/// Decomposes a time series into trend, seasonal, and residual components.
///
/// Time series decomposition is a fundamental analysis technique that separates
/// a series into three interpretable components:
///
/// 1. **Trend:** Long-term progression (growth, decline, or stability)
/// 2. **Seasonal:** Regular, repeating patterns within each cycle
/// 3. **Residual:** Random fluctuations not explained by trend or seasonality
///
/// **Additive Model:**
/// ```
/// Value = Trend + Seasonal + Residual
/// ```
///
/// **Multiplicative Model:**
/// ```
/// Value = Trend × Seasonal × Residual
/// ```
///
/// - Parameters:
///   - timeSeries: The time series to decompose
///   - periodsPerYear: Number of periods in one seasonal cycle
///   - method: Decomposition method (additive or multiplicative)
/// - Returns: `TimeSeriesDecomposition` containing trend, seasonal, and residual components
/// - Throws: `SeasonalityError` if insufficient data or invalid parameters
///
/// ## Examples
///
/// **Quarterly Sales Analysis:**
/// ```swift
/// let sales = TimeSeries(periods: quarters, values: salesData)
///
/// let decomp = try decomposeTimeSeries(
///     timeSeries: sales,
///     periodsPerYear: 4,
///     method: .multiplicative
/// )
///
/// print("Underlying growth: \(decomp.trend)")
/// print("Seasonal pattern: \(decomp.seasonal)")
/// print("Unusual events: \(decomp.residual)")
/// ```
///
/// **Monthly Website Traffic:**
/// ```swift
/// let traffic = TimeSeries(periods: months, values: visitorData)
///
/// let decomp = try decomposeTimeSeries(
///     timeSeries: traffic,
///     periodsPerYear: 12,
///     method: .additive
/// )
///
/// // Identify months with unusual traffic (high residuals)
/// let anomalies = decomp.residual.valuesArray
///     .enumerated()
///     .filter { abs($0.element) > threshold }
/// ```
///
/// ## Choosing Additive vs Multiplicative
///
/// **Use Additive when:**
/// - Seasonal variation is constant over time
/// - Example: Temperature (±20°F each winter)
///
/// **Use Multiplicative when:**
/// - Seasonal variation grows with the level
/// - Example: Retail sales (Q4 is always 50% higher, grows with business size)
///
/// ## Requirements
///
/// - At least 2 complete seasonal cycles
/// - periodsPerYear must evenly divide into data length (for best results)
///
/// ## Use Cases
///
/// - **Forecasting:** Model and project each component separately
/// - **Anomaly Detection:** Identify unusual residuals
/// - **Seasonality Quantification:** Measure seasonal effects precisely
/// - **Reporting:** Explain what drives the data
/// - **Detrending:** Remove long-term patterns for analysis
public func decomposeTimeSeries<T: Real & Sendable>(
	timeSeries: TimeSeries<T>,
	periodsPerYear: Int,
	method: DecompositionMethod
) throws -> TimeSeriesDecomposition<T> {
	guard periodsPerYear > 0 else {
		throw SeasonalityError.invalidPeriodsPerYear(periodsPerYear)
	}

	guard timeSeries.count >= periodsPerYear * 2 else {
		throw SeasonalityError.insufficientData(
			required: periodsPerYear * 2,
			provided: timeSeries.count
		)
	}

	let values = timeSeries.valuesArray
	let periods = timeSeries.periods

	// Step 1: Calculate trend using centered moving average
	let trendValues = calculateCenteredMovingAverage(values: values, window: periodsPerYear)

	// Step 2: Calculate seasonal indices
	let indices = try seasonalIndices(timeSeries: timeSeries, periodsPerYear: periodsPerYear)

	// Step 3: Calculate seasonal and residual components based on method
	var seasonalValues: [T] = []
	var residualValues: [T] = []

	switch method {
	case .additive:
		// Seasonal = repeating pattern of indices adjusted for additive
		// For additive, we need indices that sum to 0
		let indexSum = indices.reduce(T.zero, +)
		let indexAverage = indexSum / T(indices.count)
		let additiveIndices = indices.map { $0 - indexAverage }

		for i in 0..<values.count {
			let seasonIndex = i % periodsPerYear
			seasonalValues.append(additiveIndices[seasonIndex])

			// Residual = Original - Trend - Seasonal
			let residual = values[i] - trendValues[i] - additiveIndices[seasonIndex]
			residualValues.append(residual)
		}

	case .multiplicative:
		// Seasonal = repeating pattern of indices
		for i in 0..<values.count {
			let seasonIndex = i % periodsPerYear
			seasonalValues.append(indices[seasonIndex])

			// Residual = Original / (Trend × Seasonal)
			let trendSeasonal = trendValues[i] * indices[seasonIndex]
			let residual: T
			if trendSeasonal != T.zero && !trendSeasonal.isNaN {
				residual = values[i] / trendSeasonal
			} else {
				residual = T(1)  // Neutral multiplicative residual
			}
			residualValues.append(residual)
		}
	}

	// Create time series for each component
	let trend = TimeSeries(
		periods: periods,
		values: trendValues,
		metadata: TimeSeriesMetadata(name: "\(timeSeries.metadata.name) - Trend")
	)

	let seasonal = TimeSeries(
		periods: periods,
		values: seasonalValues,
		metadata: TimeSeriesMetadata(name: "\(timeSeries.metadata.name) - Seasonal")
	)

	let residual = TimeSeries(
		periods: periods,
		values: residualValues,
		metadata: TimeSeriesMetadata(name: "\(timeSeries.metadata.name) - Residual")
	)

	return TimeSeriesDecomposition(
		trend: trend,
		seasonal: seasonal,
		residual: residual,
		method: method
	)
}

// MARK: - Helper Functions

/// Calculates a centered moving average for trend extraction.
///
/// A centered moving average places the average at the center of the window,
/// providing a better estimate of the trend at each point.
///
/// - Parameters:
///   - values: The values to smooth
///   - window: The window size (typically periodsPerYear)
/// - Returns: Array of smoothed values (same length as input, with NaN at edges)
private func calculateCenteredMovingAverage<T: Real & Sendable>(
	values: [T],
	window: Int
) -> [T] {
	var result: [T] = Array(repeating: T.nan, count: values.count)

	guard window > 0 && window <= values.count else {
		return result
	}

	// For even window sizes, we need a two-pass average
	let isEven = window % 2 == 0

	if isEven {
		// First pass: calculate window-sized moving average
		for i in 0...(values.count - window) {
			let sum = values[i..<(i + window)].reduce(T.zero, +)
			let avg = sum / T(window)

			// Store at position that represents the "center"
			let centerIndex = i + window / 2
			if centerIndex < values.count {
				result[centerIndex] = avg
			}
		}

		// Second pass: average pairs to get true center
		var centeredResult: [T] = Array(repeating: T.nan, count: values.count)
		for i in 1..<(result.count - 1) {
			if !result[i].isNaN && !result[i - 1].isNaN {
				centeredResult[i] = (result[i] + result[i - 1]) / T(2)
			}
		}
		result = centeredResult
	} else {
		// For odd window sizes, calculate directly
		let halfWindow = window / 2

		for i in halfWindow..<(values.count - halfWindow) {
			let start = i - halfWindow
			let end = i + halfWindow + 1
			let sum = values[start..<end].reduce(T.zero, +)
			let avg = sum / T(window)
			result[i] = avg
		}
	}

	return result
}
