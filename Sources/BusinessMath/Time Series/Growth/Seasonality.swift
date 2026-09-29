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
/// let periods = Period.documentationQuarters
/// let quarters = Period.documentationQuarters
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
	///
	/// Positions where the trend is undefined — the ends of the series, where the centred
	/// moving average has no full window — carry `nan` under both methods. They are not
	/// perfectly-explained observations and must be screened out before ranking or averaging.
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

/// Calculates seasonal indices from a generic array of values.
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
/// This is the core implementation that works with any numeric array.
///
/// - Parameters:
///   - values: Array of numeric values representing the time series
///   - periodsPerYear: Number of periods in one seasonal cycle (e.g., 4 for quarterly, 12 for monthly)
/// - Returns: Array of seasonal indices, one per season
/// - Throws: `SeasonalityError` if insufficient data or invalid parameters, or
///   ``BusinessMathError/dataQuality(message:context:)`` if any observation is not finite.
///   A single `nan` is smeared across the whole moving-average window that contains it, so
///   there is no one season that could be marked instead.
///   `SeasonalityError.divisionByZero` if the trend passes through zero (see below), and
///   `SeasonalityError.insufficientData` if the centred moving average leaves a season with
///   no usable observation — reachable only at `periodsPerYear == 2` with exactly four
///   values, where five are needed.
///
/// ## The trend must keep one sign
///
/// These indices are multipliers, so they exist only where the ratio `value / trend` does. A
/// series whose trend crosses zero — a business moving from loss into profit, a net-flow
/// figure, a temperature in Celsius — has no multiplicative seasonal description: the ratio is
/// unbounded at the crossing and inverts its sign beyond it. The function refuses rather than
/// averaging those ratios, because the normalisation step conceals the problem completely: the
/// indices still sum to `periodsPerYear`, which is the invariant a caller would check, while
/// the season ranking they encode can be wrong end to end.
///
/// A wholly negative trend is accepted and is meaningful — a loss that deepens 30% every Q4 is
/// a multiplicative statement — and returns the same indices as the negated series.
///
/// There is no escape hatch through ``decomposeTimeSeries(timeSeries:periodsPerYear:method:)``
/// with `.additive`: that method derives its seasonal component from these same ratios, so it
/// refuses on the same data. See its documentation.
///
/// ## Example
///
/// ```swift
/// let salesData: [Double] = [100, 105, 110, 165, 110, 115, 120, 180]
/// let indices = try seasonalIndices(values: salesData, periodsPerYear: 4)
/// // Result: [0.95, 1.00, 1.05, 1.60]
/// // Q4 is 60% above average
/// ```
///
/// ## Requirements
///
/// - At least 2 complete seasonal cycles (e.g., 8 values for quarterly data)
/// - At `periodsPerYear == 2`, five values rather than four — the centred average of an even
///   two-wide window is defined at only `count - 3` positions
/// - periodsPerYear must be positive
/// - The trend must not change sign or reach zero
///
/// ## Use Cases
///
/// - **Forecasting:** Apply historical seasonal patterns to projections
/// - **Budgeting:** Adjust targets based on typical seasonal effects
/// - **Performance Analysis:** Compare actual vs. seasonally-adjusted results
/// - **Capacity Planning:** Plan resources for high/low seasons
public func seasonalIndices<T: Real & Sendable>(
	values: [T],
	periodsPerYear: Int
) throws -> [T] {
	guard periodsPerYear > 0 else {
		throw SeasonalityError.invalidPeriodsPerYear(periodsPerYear)
	}

	guard values.count >= periodsPerYear * 2 else {
		throw SeasonalityError.insufficientData(
			required: periodsPerYear * 2,
			provided: values.count
		)
	}

	// A `nan` observation is absorbed by the centred moving average, so the trend is `nan`
	// across the whole window around it and every ratio in that window is dropped from the
	// seasonal average below with no diagnostic. Measured on the quarterly series
	// [100, 105, 110, 165, 110, 115, 120, 180] with index 3 replaced by `nan`: every season
	// loses all of its ratios, the `ratios.isEmpty` fallback fabricates `T(1)` four times, and
	// the caller is returned [1.0, 1.0, 1.0, 1.0] — "this business has no seasonal pattern at
	// all" — normalised to a sum of exactly 4, which is the invariant a caller would check.
	// The clean answer for that series is [0.8697, 0.8913, 0.9075, 1.3315].
	//
	// On the twelve-quarter series the failure is quieter and worse. With index 5
	// contaminated the indices move from [0.8705, 0.8912, 0.9068, 1.3315] to
	// [0.9537, 0.8670, 0.8816, 1.2978] — Q1 overstated by 9.6%, the Q4 peak understated by
	// 2.5% — still summing to 4, still not flagged, and every figure deseasonalised with them
	// inherits the error.
	//
	// This refuses rather than marking one season (contract §3.5). The result has one entry
	// per season, not one per observation, and a single contaminated observation corrupts
	// every season sharing a moving-average window with it, so there is no one position that
	// marking would honestly identify.
	guard values.allSatisfy({ $0.isFinite }) else {
		throw BusinessMathError.dataQuality(
			message: "Seasonal indices require finite observations",
			context: ["invalid_count": "\(values.filter { !$0.isFinite }.count)"]
		)
	}

	// Calculate centered moving average (trend)
	let trend = calculateCenteredMovingAverage(values: values, window: periodsPerYear)

	// A seasonal index is a *multiplier*: `Index[season] = mean(Value / Trend)`, normalised so
	// the indices average to 1. That statement only means anything while the trend keeps one
	// sign. A trend that passes through zero makes `Value / Trend` unbounded near the crossing
	// and flips its sign on the far side, so each season's "multiplier" is the average of
	// numbers that share neither a scale nor a sign — and the normalisation hides it, because
	// dividing by the mean restores the sum-to-`periodsPerYear` invariant whatever the ratios
	// were.
	//
	// Measured on [-60, -45, -30, -5, -20, -5, 10, 35, 20, 35, 50, 75] — an exactly linear
	// trend from -55 to +55 carrying the fixed offsets [-5, 0, +5, +20], i.e. a business
	// crossing from loss into profit with a seasonal swing that is constant in currency. The
	// centred moving average runs -30, -20, -10, 0, 10, 20, 30, 40, and the function returned
	// [0.8136, 0.6780, 1.0169, 1.4915] summing to exactly 4. Season 1, the one season with no
	// seasonal offset at all, is reported 32% below average; season 3's ratios were 0.1667 and
	// 3.5, which measure distance from the zero crossing rather than any seasonal effect.
	//
	// The exact zero is not the dangerous part and the `trend[i] != T.zero` filter below does
	// not address it. Shifting the same series up by 5 gives a trend of -25, -15, -5, 5, 15,
	// 25, 35, 45 — no exact zero anywhere, nothing filtered — and the indices come back
	// [0.7975, 0.4557, 1.6835, 1.0633], still summing to 4, with the season ranking inverted:
	// the largest true effect (+20) is reported as roughly average and the neutral season as
	// 54% below. So the test is on the *sign span*, not on equality with zero.
	//
	// A wholly negative trend is fine and stays accepted: `(-v) / (-t)` is the ratio of the
	// positive case, and the same series negated returns byte-identical indices. A run of
	// losses that deepen every Q4 is a coherent multiplicative statement.
	//
	// This is not contamination and must not be routed into the finite-values guard above
	// (contract §5): every observation here is a real, finite measurement. The data is sound
	// and the multiplicative *model* is undefined for it, so the diagnosis names the model.
	// `SeasonalityError.divisionByZero` is the case written for exactly this — its own
	// documentation reads "Division by zero in multiplicative decomposition" — rather than a
	// new case, which would break an exhaustive `switch` in a consumer.
	let definedTrend: [T] = trend.filter { !$0.isNaN }
	let trendTouchesZero: Bool = definedTrend.contains { $0 == T.zero }
	let trendHasPositive: Bool = definedTrend.contains { $0 > T.zero }
	let trendHasNegative: Bool = definedTrend.contains { $0 < T.zero }
	let trendSpansZero: Bool = trendTouchesZero || (trendHasPositive && trendHasNegative)
	guard !trendSpansZero else {
		throw SeasonalityError.divisionByZero(
			"""
			Seasonal indices are multiplicative (value / trend) and are undefined for a series \
			whose trend passes through zero: the ratio is unbounded at the crossing and changes \
			sign across it, so the averaged index is not a multiplier. Every observation is \
			valid — this is a property of the series, not a data-quality problem. Model the \
			seasonal effect in the series' own units instead of as a proportion.
			""")
	}

	// Calculate ratios (value / trend) for each period
	var seasonalRatios: [[T]] = Array(repeating: [], count: periodsPerYear)

	for i in 0..<values.count {
		// `trend[i] != T.zero` is unreachable after the sign-span guard above, which refuses
		// any defined zero. It is kept as the local precondition for the division rather than
		// tidied away: without it the line reads as an unguarded divide.
		if i < trend.count && !trend[i].isNaN && trend[i] != T.zero {
			let ratio = values[i] / trend[i]
			let seasonIndex = i % periodsPerYear
			seasonalRatios[seasonIndex].append(ratio)
		}
	}

	// Average the ratios for each season.
	//
	// The `T(1)` that used to sit here was the prohibited constant (contract §4). A seasonal
	// index of 1 is not "unknown": it is the precise statement that this season carries no
	// seasonal effect, and it then propagates into the normalisation so the remaining seasons
	// are rescaled around a season that was never measured.
	//
	// It is reachable on entirely clean, positive, monotone data. With `periodsPerYear = 2`
	// and the minimum four observations the contract above allows, [10, 20, 30, 40] gives a
	// centred moving average defined at index 2 only, so season 0 gets the single ratio 1.5,
	// season 1 gets none and is fabricated as 1, and after normalisation the caller is handed
	// [1.2, 0.8] — a ±20% seasonal swing on a perfectly straight line — summing to exactly 2,
	// which is the invariant a careful caller would check.
	//
	// The shortfall is geometric, not statistical. For an odd window the centred average is
	// defined at `count - periodsPerYear + 1` consecutive positions and for an even window of
	// four or more at `count - periodsPerYear`; both are at least `periodsPerYear` once
	// `count >= periodsPerYear * 2`, so every season is covered. The single exception is
	// `periodsPerYear == 2`, where the second averaging pass loses one further position and
	// only `count - 3` remain — one position, covering one season, when `count == 4`. Five
	// observations cover both, which is why `periodsPerYear * 2 + 1` is the exact requirement
	// for the only configuration that can reach this.
	//
	// Marking the season `.nan` instead (contract §3.5) would not help: the normalisation sums
	// the indices, so one `.nan` makes all of them `.nan`, and `seasonallyAdjust` then divides
	// by it silently — `nan != T.zero` is true, so its zero-index guard does not fire. The
	// caller would get an all-`nan` array and no diagnosis. The contamination guard at the top
	// of this function already chose to refuse for the same reason.
	var indices: [T] = []
	for ratios in seasonalRatios {
		guard !ratios.isEmpty else {
			throw SeasonalityError.insufficientData(
				required: periodsPerYear * 2 + 1,
				provided: values.count
			)
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

/// Calculates seasonal indices for a time series (convenience method).
///
/// Delegates to `seasonalIndices(values:periodsPerYear:)` for the core calculation.
///
/// - Parameters:
///   - timeSeries: The time series data to analyze
///   - periodsPerYear: Number of periods in one seasonal cycle (e.g., 4 for quarterly, 12 for monthly)
/// - Returns: Array of seasonal indices, one per season
/// - Throws: `SeasonalityError` if insufficient data or invalid parameters, or
///   ``BusinessMathError/dataQuality(message:context:)`` if any observation is not finite,
///   or `SeasonalityError.divisionByZero` if the trend passes through zero — these indices
///   are multipliers and a multiplicative description does not exist for such a series. See
///   ``seasonalIndices(values:periodsPerYear:)``.
///
/// ## Examples
///
/// **Quarterly Business Cycle:**
/// ```swift
/// let periods = Period.documentationQuarters
/// let quarters = Period.documentationQuarters
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
/// let monthlyPeriods = (1...12).map { Period.month(year: 2024, month: $0) }
/// let mrr = TimeSeries(periods: monthlyPeriods, values: [100, 105, 98, 102, 108, 104, 110, 106, 112, 115, 130, 160])
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
	return try seasonalIndices(values: timeSeries.valuesArray, periodsPerYear: periodsPerYear)
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
/// let eightQuarters = (0..<8).map { Period.quarter(year: 2024 + $0 / 4, quarter: $0 % 4 + 1) }
/// let sales = TimeSeries(periods: eightQuarters, values: [100, 120, 80, 160, 110, 130, 88, 176])
/// let indices = try seasonalIndices(timeSeries: sales, periodsPerYear: 4)
/// let adjusted = try seasonallyAdjust(timeSeries: sales, indices: indices)
///
/// // adjusted now shows underlying trend without Q4 holiday spikes
/// ```
///
/// **Compare Year-Over-Year Growth:**
/// ```swift
/// let salesQ3 = 100.0, salesQ4 = 160.0
/// let adjustedQ3 = 100.0, adjustedQ4 = 104.0
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
/// let eightQuarters = (0..<8).map { Period.quarter(year: 2024 + $0 / 4, quarter: $0 % 4 + 1) }
/// let historical = TimeSeries(periods: eightQuarters, values: [100, 120, 80, 160, 110, 130, 88, 176])
/// var linearTrend = LinearTrend<Double>()
/// try linearTrend.fit(to: historical)
/// // Start with trend-only forecast
/// let indices = try seasonalIndices(timeSeries: historical, periodsPerYear: 4)
///
/// // project(periods:) is optional — an unfitted model has nothing to project
/// if let trendForecast = try linearTrend.project(periods: 4) {
///     // Apply historical seasonal pattern
///     let seasonalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)
///     print(seasonalForecast)
/// }
///
/// // seasonalForecast now includes realistic seasonal variation
/// ```
///
/// **Reconstruct Original Data:**
/// ```swift
/// let indices = [0.95, 1.00, 1.05, 1.60]
/// let original = TimeSeries(periods: Period.documentationQuarters, values: [100, 110, 120, 130])
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
/// - Throws: `SeasonalityError` if insufficient data or invalid parameters, or
///   ``BusinessMathError/dataQuality(message:context:)`` if any observation is not finite
///   (propagated from `seasonalIndices(timeSeries:periodsPerYear:)`), or
///   `SeasonalityError.divisionByZero` if the trend passes through zero — **under either
///   method**, for the reason below.
///
/// ## A trend that passes through zero is refused under both methods
///
/// A multiplicative decomposition genuinely has no meaning for such a series: `Value = Trend ×
/// Seasonal` cannot describe a trend that is zero, and the residual `Value / (Trend ×
/// Seasonal)` is unbounded at the crossing.
///
/// A textbook *additive* decomposition would be well defined there — `Value = Trend + Seasonal
/// + Residual` never divides by the trend, and a seasonal swing measured in the series' own
/// units survives the sign change intact. This implementation nevertheless refuses, and the
/// reason is worth stating plainly rather than hiding: its additive seasonal component is not
/// computed additively. It is obtained by re-centring the *multiplicative* indices returned by
/// ``seasonalIndices(timeSeries:periodsPerYear:)`` (`index - mean(indices)`), so it inherits
/// every ratio those indices were built from. Given a zero-crossing trend it would be centring
/// numbers that measure distance from the crossing, then subtracting them from values that
/// carry units.
///
/// So the two methods agree here because they share the ratio computation, not because
/// additive decomposition is undefined. Computing a genuinely additive index — the per-season
/// mean of `value - trend`, centred to sum to zero — would lift this restriction for
/// `.additive` and would change every additive result this function has ever returned. That is
/// a deliberate API decision, not a guard to add in passing.
///
/// ## Undefined residuals at the ends of the series
///
/// The trend is a centred moving average, so it is undefined for roughly `periodsPerYear / 2`
/// positions at each end. Both methods report the residual there as `nan` rather than as a
/// value: additive because `value - nan - seasonal` propagates, multiplicative because a
/// residual of `1` would claim a perfect fit at a position with no trend estimate. Screen with
/// `isNaN` before ranking or averaging residuals.
///
/// ## Examples
///
/// **Quarterly Sales Analysis:**
/// ```swift
/// let eightQuarters = (0..<8).map { Period.quarter(year: 2024 + $0 / 4, quarter: $0 % 4 + 1) }
/// let sales = TimeSeries(periods: eightQuarters, values: [100, 120, 80, 160, 110, 130, 88, 176])
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
/// let monthlyPeriods = (1...12).map { Period.month(year: 2024, month: $0) }
/// let traffic = TimeSeries(periods: monthlyPeriods, values: [100, 105, 98, 102, 108, 104, 110, 106, 112, 115, 130, 160])
///
/// let decomp = try decomposeTimeSeries(
///     timeSeries: traffic,
///     periodsPerYear: 12,
///     method: .additive
/// )
///
/// // Identify months with unusual traffic (high residuals)
/// let threshold = 10.0
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

			// The `T(1)` that used to sit in the `else` arm was not a neutral residual. In a
			// multiplicative decomposition a residual of exactly 1 states that trend x seasonal
			// reproduces this observation perfectly, which is the single most favourable thing
			// the model can say about a point.
			//
			// It fired on clean data, because the centred moving average is undefined at the
			// ends of the series. Measured on
			// [100, 105, 110, 165, 110, 115, 120, 180, 120, 125, 130, 195] at
			// periodsPerYear = 4, the residuals at indices 0, 1, 2 and 11 came back as exactly
			// 1.0 while the eight interior residuals ran 1.0194 to 1.0228 — a flawless fit
			// claimed at the four positions with no trend estimate at all, and a caller ranking
			// periods by |residual - 1| to find the worst-explained quarter is handed those
			// four as the four best.
			//
			// The additive branch above already answers `nan` at exactly those positions,
			// because `value - nan - seasonal` propagates. This brings the multiplicative
			// branch into line with its sibling rather than inventing a policy for it.
			let residual: T
			if !trendSeasonal.isNaN && trendSeasonal != T.zero {
				residual = values[i] / trendSeasonal
			} else {
				residual = T.nan
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
