//
//  StreamingForecasting.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Forecast Result Types

/// Direction of detected trend
public enum TrendDirection {
    case upward
    case downward
    case flat
}

/// Result of trend detection in a time series.
///
/// Identifies the direction, steepness, and statistical confidence of a detected trend.
/// Streaming trend detection continuously updates as new data arrives, making it suitable
/// for real-time monitoring.
///
/// ## Example
/// ```swift
/// let trend = TrendDetection(
///     direction: .upward,
///     slope: 2.5,
///     confidence: 0.95
/// )
/// print("Detected \(trend.direction) trend with \(trend.confidence * 100)% confidence")
/// ```
public struct TrendDetection {
    /// The direction of the detected trend (upward, downward, or flat).
    public let direction: TrendDirection

    /// The slope of the trend line, measured in units per time period.
    ///
    /// Positive values indicate upward trends, negative values indicate downward trends.
    /// Magnitude represents the rate of change.
    public let slope: Double

    /// Statistical confidence level of the trend detection, ranging from 0 to 1.
    ///
    /// Higher values indicate stronger statistical evidence for the detected trend.
    /// Typically, confidence above 0.95 is considered statistically significant.
    public let confidence: Double

    /// Creates a trend detection result.
    ///
    /// - Parameters:
    ///   - direction: The direction of the trend.
    ///   - slope: The trend line slope (rate of change per period).
    ///   - confidence: Statistical confidence level (0 to 1).
    public init(direction: TrendDirection, slope: Double, confidence: Double) {
        self.direction = direction
        self.slope = slope
        self.confidence = confidence
    }
}

/// Type of change point
public enum ChangePointType {
    case levelShift
    case trendChange
    case varianceChange
}

/// Result of change point detection in a time series.
///
/// Identifies significant structural changes in streaming data, such as sudden level shifts,
/// trend changes, or changes in variance. Change points indicate moments where the statistical
/// properties of the series fundamentally change.
///
/// ## Example
/// ```swift
/// let changePoint = ChangePoint(
///     type: .levelShift,
///     magnitude: 15.3,
///     index: 127
/// )
/// print("Level shift of \(changePoint.magnitude) detected at position \(changePoint.index)")
/// ```
public struct ChangePoint {
    /// The type of structural change detected.
    public let type: ChangePointType

    /// The magnitude of the change in the series' statistical properties.
    ///
    /// For level shifts, this represents the change in mean value.
    /// For trend changes, this represents the change in slope.
    /// For variance changes, this represents the ratio of new variance to old variance.
    public let magnitude: Double

    /// The index in the stream where the change point was detected.
    ///
    /// Represents the position (0-based) in the data stream.
    public let index: Int

    /// Creates a change point detection result.
    ///
    /// - Parameters:
    ///   - type: The type of structural change.
    ///   - magnitude: The size of the change.
    ///   - index: The position in the stream where the change occurred.
    public init(type: ChangePointType, magnitude: Double, index: Int) {
        self.type = type
        self.magnitude = magnitude
        self.index = index
    }
}

/// Forecast accuracy metrics computed over streaming data.
///
/// Tracks three complementary error metrics that provide different perspectives on
/// forecast quality: absolute errors (MAE), squared errors (RMSE), and percentage errors (MAPE).
/// These metrics update continuously as new observations arrive.
///
/// ## Example
/// ```swift
/// let errors = StreamingForecastError(
///     mae: 5.2,
///     rmse: 6.8,
///     mape: 0.12
/// )
/// print("Forecast accuracy: MAE=\(errors.mae), RMSE=\(errors.rmse), MAPE=\(errors.mape * 100)%")
/// ```
public struct StreamingForecastError {
    /// Mean Absolute Error: average absolute difference between forecasts and actuals.
    ///
    /// MAE is in the same units as the data and is less sensitive to outliers than RMSE.
    public let mae: Double

    /// Root Mean Squared Error: square root of average squared forecast errors.
    ///
    /// RMSE penalizes large errors more heavily than MAE and is in the same units as the data.
    public let rmse: Double

    /// Mean Absolute Percentage Error: average absolute percentage error.
    ///
    /// MAPE expresses errors as a percentage (0 to 1 scale) and is scale-independent,
    /// making it useful for comparing forecasts across different data series.
    public let mape: Double

    /// Creates forecast error metrics.
    ///
    /// - Parameters:
    ///   - mae: Mean absolute error.
    ///   - rmse: Root mean squared error.
    ///   - mape: Mean absolute percentage error (0 to 1 scale).
    public init(mae: Double, rmse: Double, mape: Double) {
        self.mae = mae
        self.rmse = rmse
        self.mape = mape
    }
}

/// Double exponential smoothing forecast with level and trend components.
///
/// Also known as Holt's linear trend method, this captures both the current level
/// and the rate of change (trend) in a time series. Useful for data with trends
/// but no seasonal patterns.
///
/// ## Example
/// ```swift
/// let forecast = DoubleExponentialForecast(level: 100.0, trend: 2.5)
/// let oneStepAhead = forecast.forecast(steps: 1)   // 102.5
/// let tenStepsAhead = forecast.forecast(steps: 10) // 125.0
/// ```
///
/// - SeeAlso: ``TripleExponentialForecast`` for seasonal data
public struct DoubleExponentialForecast {
    /// The current level (baseline value) of the time series.
    public let level: Double

    /// The current trend (rate of change per period) of the time series.
    ///
    /// Positive values indicate an upward trend, negative values indicate a downward trend.
    public let trend: Double

    /// Creates a double exponential smoothing forecast.
    ///
    /// - Parameters:
    ///   - level: The current baseline value.
    ///   - trend: The rate of change per period.
    public init(level: Double, trend: Double) {
        self.level = level
        self.trend = trend
    }

    /// Projects the forecast forward by a specified number of steps.
    ///
    /// Uses the formula: level + (steps × trend)
    ///
    /// - Parameter steps: Number of time periods to forecast ahead.
    /// - Returns: The forecasted value.
    public func forecast(steps: Int) -> Double {
        return level + Double(steps) * trend
    }
}

/// Triple exponential smoothing forecast with level, trend, and seasonal components.
///
/// Also known as Holt-Winters method, this extends double exponential smoothing to handle
/// seasonal patterns. The seasonal factors repeat cyclically, making it ideal for data
/// with regular seasonal variations (daily, weekly, monthly, etc.).
///
/// ## Example
/// ```swift
/// let forecast = TripleExponentialForecast(
///     level: 100.0,
///     trend: 2.5,
///     seasonalFactors: [0.8, 0.9, 1.0, 1.2, 1.1] // 5-period seasonal cycle
/// )
/// let nextPeriod = forecast.forecast(steps: 1)  // Applies first seasonal factor
/// let sixthPeriod = forecast.forecast(steps: 6) // Cycles back to second factor
/// ```
///
/// - SeeAlso: ``DoubleExponentialForecast`` for non-seasonal data
public struct TripleExponentialForecast {
    /// The current level (deseasonalized baseline value) of the time series.
    public let level: Double

    /// The current trend (rate of change per period) of the time series.
    public let trend: Double

    /// Seasonal factors for each period in the seasonal cycle.
    ///
    /// Multiplicative seasonal factors where 1.0 = average, > 1.0 = above average,
    /// < 1.0 = below average. The array length defines the seasonal period
    /// (e.g., 12 for monthly seasonality, 7 for weekly, 4 for quarterly).
    public let seasonalFactors: [Double]

    /// Creates a triple exponential smoothing forecast.
    ///
    /// - Parameters:
    ///   - level: The deseasonalized baseline value.
    ///   - trend: The rate of change per period.
    ///   - seasonalFactors: Multiplicative seasonal factors for each period in the cycle.
    public init(level: Double, trend: Double, seasonalFactors: [Double]) {
        self.level = level
        self.trend = trend
        self.seasonalFactors = seasonalFactors
    }

    /// Projects the forecast forward by a specified number of steps.
    ///
    /// Applies both trend and seasonal components: (level + steps × trend) × seasonalFactor
    ///
    /// - Parameter steps: Number of time periods to forecast ahead.
    /// - Returns: The forecasted value with seasonal adjustment applied.
    public func forecast(steps: Int) -> Double {
        let seasonIndex = (steps - 1) % seasonalFactors.count
        return (level + Double(steps) * trend) * seasonalFactors[seasonIndex]
    }
}

// MARK: - AsyncSequence Extensions for Forecasting

extension AsyncSequence where Element == Double {

    // MARK: - Exponential Smoothing

    /// Simple exponential smoothing forecast
    /// - Parameter alpha: Smoothing parameter (0 < alpha <= 1)
    public func simpleExponentialSmoothing(alpha: Double) -> AsyncSimpleExponentialSmoothingSequence<Self> {
        AsyncSimpleExponentialSmoothingSequence(base: self, alpha: alpha)
    }

    /// Double exponential smoothing (Holt's method) - captures level and trend
    /// - Parameters:
    ///   - alpha: Level smoothing parameter (0 < alpha <= 1)
    ///   - beta: Trend smoothing parameter (0 < beta <= 1)
    public func doubleExponentialSmoothing(alpha: Double, beta: Double) -> AsyncDoubleExponentialSmoothingSequence<Self> {
        AsyncDoubleExponentialSmoothingSequence(base: self, alpha: alpha, beta: beta)
    }

    /// Triple exponential smoothing (Holt-Winters method) - captures level, trend, and seasonality
    /// - Parameters:
    ///   - alpha: Level smoothing parameter (0 < alpha <= 1)
    ///   - beta: Trend smoothing parameter (0 < beta <= 1)
    ///   - gamma: Seasonal smoothing parameter (0 < gamma <= 1)
    ///   - seasonLength: Number of periods in a season
    public func tripleExponentialSmoothing(
        alpha: Double,
        beta: Double,
        gamma: Double,
        seasonLength: Int
    ) -> AsyncTripleExponentialSmoothingSequence<Self> {
        AsyncTripleExponentialSmoothingSequence(
            base: self,
            alpha: alpha,
            beta: beta,
            gamma: gamma,
            seasonLength: seasonLength
        )
    }

    // MARK: - Moving Average Forecast

    /// Moving average forecast - uses mean of window as next forecast
    public func movingAverageForecast(window: Int) -> AsyncMovingAverageForecastSequence<Self> {
        AsyncMovingAverageForecastSequence(base: self, window: window)
    }

    // MARK: - Trend Detection

    /// Detect trend direction and slope over a window
    public func detectTrend(window: Int) -> AsyncTrendDetectionSequence<Self> {
        AsyncTrendDetectionSequence(base: self, window: window)
    }

    // MARK: - Change Point Detection

    /// Detect change points in the stream
    public func detectChangePoints(window: Int, threshold: Double) -> AsyncChangePointDetectionSequence<Self> {
        AsyncChangePointDetectionSequence(base: self, window: window, threshold: threshold)
    }
}

/// Pair of actual and forecasted values for error calculation.
///
/// Used to track forecasts alongside their corresponding actual values, enabling
/// computation of forecast accuracy metrics over streaming data.
///
/// ## Example
/// ```swift
/// let pair = ForecastPair(actual: 105.3, forecast: 102.5)
/// let error = pair.actual - pair.forecast  // 2.8
/// ```
public struct ForecastPair: Sendable {
    /// The actual observed value.
    public let actual: Double

    /// The forecasted value for this observation.
    public let forecast: Double

    /// Creates a forecast/actual pair.
    ///
    /// - Parameters:
    ///   - actual: The observed value.
    ///   - forecast: The predicted value.
    public init(actual: Double, forecast: Double) {
        self.actual = actual
        self.forecast = forecast
    }
}

// Extension for forecast pair streams
extension AsyncSequence where Element == ForecastPair {
    /// Calculate forecast error metrics
    public func forecastErrors() -> AsyncForecastErrorSequence<Self> {
        AsyncForecastErrorSequence(base: self)
    }
}

// MARK: - Simple Exponential Smoothing

/// AsyncSequence that applies simple exponential smoothing to streaming data.
///
/// Simple exponential smoothing produces forecasts as a weighted average of past observations,
/// with exponentially decreasing weights for older data. Higher alpha values respond faster
/// to changes but may be noisier. Best for data without trends or seasonality.
///
/// Formula: F(t+1) = α × Y(t) + (1-α) × F(t)
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 105, 103, 108, 107])
/// for try await forecast in stream.simpleExponentialSmoothing(alpha: 0.3) {
///     print("Smoothed forecast: \(forecast)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **alpha = 0.1 to 0.3**: Slow response, very smooth, good for stable data
/// - **alpha = 0.5**: Balanced smoothing
/// - **alpha = 0.7 to 0.9**: Fast response, less smooth, good for volatile data
///
/// - SeeAlso: ``AsyncDoubleExponentialSmoothingSequence`` for data with trends
public struct AsyncSimpleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields smoothed forecast values.
    public typealias Element = Double

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let alpha: Double

    init(base: Base, alpha: Double) {
        self.base = base
        self.alpha = alpha
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields exponentially smoothed forecasts.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), alpha: alpha)
    }

    /// Iterator that computes exponentially smoothed forecasts asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let alpha: Double
        private var forecast: Double?

        init(base: Base.AsyncIterator, alpha: Double) {
            self.baseIterator = base
            self.alpha = alpha
        }

        /// Yields the next smoothed forecast.
        ///
        /// - Returns: The exponentially smoothed forecast value.
        public mutating func next() async throws -> Double? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            if let currentForecast = forecast {
                // Update: F(t+1) = alpha * Y(t) + (1-alpha) * F(t)
                forecast = alpha * value + (1.0 - alpha) * currentForecast
            } else {
                // Initialize with first value
                forecast = value
            }

            return forecast
        }
    }
}

// MARK: - Double Exponential Smoothing (Holt's Method)

/// AsyncSequence that applies double exponential smoothing (Holt's method) to streaming data.
///
/// Double exponential smoothing extends simple smoothing to handle data with trends by
/// maintaining separate components for level and trend. Suitable for data with linear trends
/// but no seasonal patterns.
///
/// Formulas:
/// - Level: L(t) = α × Y(t) + (1-α) × (L(t-1) + T(t-1))
/// - Trend: T(t) = β × (L(t) - L(t-1)) + (1-β) × T(t-1)
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 103, 105, 109, 112])
/// for try await forecast in stream.doubleExponentialSmoothing(alpha: 0.3, beta: 0.1) {
///     let nextStep = forecast.forecast(steps: 1)
///     print("Level: \(forecast.level), Trend: \(forecast.trend), Next: \(nextStep)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **alpha**: Level smoothing (0.1-0.3 for stable data, 0.5-0.9 for volatile data)
/// - **beta**: Trend smoothing (typically 0.1-0.2 for slow trend changes)
///
/// - SeeAlso: ``AsyncTripleExponentialSmoothingSequence`` for seasonal data
public struct AsyncDoubleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields forecast objects containing level and trend components.
    public typealias Element = DoubleExponentialForecast

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let alpha: Double
    private let beta: Double

    init(base: Base, alpha: Double, beta: Double) {
        self.base = base
        self.alpha = alpha
        self.beta = beta
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields double exponential smoothing forecasts.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), alpha: alpha, beta: beta)
    }

    /// Iterator that computes double exponential smoothing forecasts asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let alpha: Double
        private let beta: Double
        private var level: Double?
        private var trend: Double?
        private var previousValue: Double?

        init(base: Base.AsyncIterator, alpha: Double, beta: Double) {
            self.baseIterator = base
            self.alpha = alpha
            self.beta = beta
        }

        /// Yields the next forecast with updated level and trend components.
        ///
        /// - Returns: A forecast object containing level and trend for projection.
        public mutating func next() async throws -> DoubleExponentialForecast? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            if let currentLevel = level, let currentTrend = trend {
                // Update level: L(t) = alpha * Y(t) + (1-alpha) * (L(t-1) + T(t-1))
                let newLevel = alpha * value + (1.0 - alpha) * (currentLevel + currentTrend)

                // Update trend: T(t) = beta * (L(t) - L(t-1)) + (1-beta) * T(t-1)
                let newTrend = beta * (newLevel - currentLevel) + (1.0 - beta) * currentTrend

                level = newLevel
                trend = newTrend
            } else if let prev = previousValue {
                // Initialize with first two values
                level = value
                trend = value - prev
            } else {
                // Store first value
                previousValue = value
                level = value
                trend = 0.0
            }

            return DoubleExponentialForecast(level: level!, trend: trend!)
        }
    }
}

// MARK: - Triple Exponential Smoothing (Holt-Winters Method)

/// AsyncSequence that applies triple exponential smoothing (Holt-Winters method) to streaming data.
///
/// Triple exponential smoothing extends double smoothing to handle seasonal patterns by
/// maintaining components for level, trend, and seasonality. Suitable for data with both
/// trends and repeating seasonal patterns.
///
/// Formulas:
/// - Level: L(t) = α × (Y(t) / S(t-s)) + (1-α) × (L(t-1) + T(t-1))
/// - Trend: T(t) = β × (L(t) - L(t-1)) + (1-β) × T(t-1)
/// - Seasonal: S(t) = γ × (Y(t) / L(t)) + (1-γ) × S(t-s)
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 110, 95, 105, 115, 100, 110, 120])
/// for try await forecast in stream.tripleExponentialSmoothing(
///     alpha: 0.3, beta: 0.1, gamma: 0.2, seasonLength: 4
/// ) {
///     let nextStep = forecast.forecast(steps: 1)
///     print("Next forecast: \(nextStep)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **alpha**: Level smoothing (0.1-0.3 typical)
/// - **beta**: Trend smoothing (0.1-0.2 typical)
/// - **gamma**: Seasonal smoothing (0.1-0.3 typical)
/// - **seasonLength**: Number of periods in one seasonal cycle (e.g., 12 for monthly, 7 for daily)
public struct AsyncTripleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields forecast objects containing level, trend, and seasonal components.
    public typealias Element = TripleExponentialForecast

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let alpha: Double
    private let beta: Double
    private let gamma: Double
    private let seasonLength: Int

    init(base: Base, alpha: Double, beta: Double, gamma: Double, seasonLength: Int) {
        self.base = base
        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.seasonLength = seasonLength
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields triple exponential smoothing forecasts.
    public func makeAsyncIterator() -> Iterator {
        Iterator(
            base: base.makeAsyncIterator(),
            alpha: alpha,
            beta: beta,
            gamma: gamma,
            seasonLength: seasonLength
        )
    }

    /// Iterator that computes triple exponential smoothing forecasts asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let alpha: Double
        private let beta: Double
        private let gamma: Double
        private let seasonLength: Int
        private var level: Double?
        private var trend: Double?
        private var seasonalFactors: [Double]
        private var initializationBuffer: [Double] = []
        private var currentIndex: Int = 0

        init(base: Base.AsyncIterator, alpha: Double, beta: Double, gamma: Double, seasonLength: Int) {
            self.baseIterator = base
            self.alpha = alpha
            self.beta = beta
            self.gamma = gamma
            self.seasonLength = seasonLength
            self.seasonalFactors = Array(repeating: 1.0, count: seasonLength)
        }

        /// Yields the next forecast with updated level, trend, and seasonal components.
        ///
        /// - Returns: A forecast object containing all three components for projection.
        public mutating func next() async throws -> TripleExponentialForecast? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            // Collect initial season for initialization
            if initializationBuffer.count < seasonLength {
                initializationBuffer.append(value)

                if initializationBuffer.count == seasonLength {
                    // Initialize level, trend, and seasonal factors
                    level = initializationBuffer.reduce(0.0, +) / Double(seasonLength)
                    trend = 0.0

                    // Initialize seasonal factors
                    for (i, val) in initializationBuffer.enumerated() {
                        seasonalFactors[i] = val / level!
                    }
                }

                return TripleExponentialForecast(
                    level: level ?? value,
                    trend: trend ?? 0.0,
                    seasonalFactors: seasonalFactors
                )
            }

            guard let currentLevel = level, let currentTrend = trend else {
                return nil
            }

            let seasonIndex = currentIndex % seasonLength

            // Deseasonalize
            let deseasonalized = value / seasonalFactors[seasonIndex]

            // Update level
            let newLevel = alpha * deseasonalized + (1.0 - alpha) * (currentLevel + currentTrend)

            // Update trend
            let newTrend = beta * (newLevel - currentLevel) + (1.0 - beta) * currentTrend

            // Update seasonal factor
            seasonalFactors[seasonIndex] = gamma * (value / newLevel) + (1.0 - gamma) * seasonalFactors[seasonIndex]

            level = newLevel
            trend = newTrend
            currentIndex += 1

            return TripleExponentialForecast(
                level: newLevel,
                trend: newTrend,
                seasonalFactors: seasonalFactors
            )
        }
    }
}

// MARK: - Moving Average Forecast

/// AsyncSequence that forecasts using the moving average method.
///
/// The moving average forecast uses the mean of the most recent window of values as the
/// next forecast. This simple method works well for stable data without strong trends or
/// seasonality. Larger windows produce smoother forecasts but are slower to respond to changes.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 102, 98, 105, 103, 107])
/// for try await forecast in stream.movingAverageForecast(window: 3) {
///     print("Next forecast: \(forecast)")
/// }
/// // Uses mean of last 3 values to forecast next value
/// ```
///
/// ## Window Size Guidance
/// - **Small window (3-5)**: Responsive to recent changes, but noisier
/// - **Medium window (7-15)**: Balanced smoothing and responsiveness
/// - **Large window (20+)**: Very smooth, but slow to detect changes
public struct AsyncMovingAverageForecastSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields forecast values (mean of the window).
    public typealias Element = Double

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int

    init(base: Base, window: Int) {
        self.base = base
        self.window = window
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields moving average forecasts.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator that computes moving average forecasts asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Yields the next moving average forecast.
        ///
        /// - Returns: The mean of the current window of values.
        public mutating func next() async throws -> Double? {
            guard !isComplete else { return nil }

            // Fill buffer to window size
            while buffer.count < window {
                guard let value = try await baseIterator.next() else {
                    isComplete = true
                    return nil
                }
                buffer.append(value)
            }

            // Forecast is mean of current window
            let forecast = buffer.reduce(0.0, +) / Double(buffer.count)

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return forecast
        }
    }
}

// MARK: - Trend Detection

/// AsyncSequence that detects trends in streaming data using linear regression.
///
/// Continuously analyzes the most recent window of data to detect trend direction, slope,
/// and statistical significance. Uses least-squares linear regression to fit a trend line
/// and compute confidence metrics. Useful for monitoring whether data is trending up, down,
/// or remaining flat.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 102, 105, 108, 112, 115])
/// for try await trend in stream.detectTrend(window: 5) {
///     print("Direction: \(trend.direction), Slope: \(trend.slope), Confidence: \(trend.confidence)")
/// }
/// ```
///
/// ## Interpretation
/// - **Direction**: `.upward`, `.downward`, or `.flat` based on slope and significance
/// - **Slope**: Rate of change per period (units per time step)
/// - **Confidence**: R² value (0 to 1), where higher values indicate stronger trends
public struct AsyncTrendDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields trend detection results.
    public typealias Element = TrendDetection

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int

    init(base: Base, window: Int) {
        self.base = base
        self.window = window
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields trend detection results.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }
	
	/// Iterator that yields generated values asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }
        
        /// Yields the next value from the array, or nil when exhausted.
        public mutating func next() async throws -> TrendDetection? {
            guard !isComplete else { return nil }

            // Fill buffer to window size
            while buffer.count < window {
                guard let value = try await baseIterator.next() else {
                    isComplete = true
                    return nil
                }
                buffer.append(value)
            }

            // Calculate linear regression slope
            let n = Double(buffer.count)
            let sumX = (0..<buffer.count).reduce(0.0) { $0 + Double($1) }
            let sumY = buffer.reduce(0.0, +)
            let sumXY = Swift.zip(0..<buffer.count, buffer).reduce(0.0) { $0 + Double($1.0) * $1.1 }
            let sumX2 = (0..<buffer.count).reduce(0.0) { $0 + Double($1) * Double($1) }

            let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)

            // Calculate R-squared for confidence
            let meanY = sumY / n
            let ssTotal = buffer.reduce(0.0) { $0 + pow($1 - meanY, 2) }
            let ssResidual = Swift.zip(0..<buffer.count, buffer).reduce(0.0) {
                let predicted = slope * Double($1.0) + (meanY - slope * (n - 1) / 2)
                return $0 + pow($1.1 - predicted, 2)
            }
            let rSquared = 1.0 - (ssResidual / ssTotal)

            // Determine direction
            let direction: TrendDirection
            if abs(slope) < 0.1 {
                direction = .flat
            } else if slope > 0 {
                direction = .upward
            } else {
                direction = .downward
            }

            let trend = TrendDetection(
                direction: direction,
                slope: slope,
                confidence: Swift.max(0, Swift.min(1, rSquared))
            )

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return trend
        }
    }
}

// MARK: - Change Point Detection

/// AsyncSequence that detects structural changes (change points) in streaming data.
///
/// Monitors the stream for significant shifts in statistical properties. Currently focuses
/// on level shift detection by comparing consecutive windows. When the mean shifts by more
/// than the threshold, a change point is emitted. Useful for detecting regime changes,
/// anomalous events, or phase transitions in business metrics.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 102, 98, 105, 150, 148, 152, 155])
/// for try await changePoint in stream.detectChangePoints(window: 3, threshold: 20) {
///     print("Change detected at index \(changePoint.index): \(changePoint.type)")
///     print("Magnitude: \(changePoint.magnitude)")
/// }
/// // Detects level shift from ~100 to ~150
/// ```
///
/// ## Parameter Guidance
/// - **window**: Size of window for computing statistics (larger = smoother, slower to detect)
/// - **threshold**: Minimum change to consider significant (domain-specific, e.g., 2× std dev)
public struct AsyncChangePointDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields change point detections.
    public typealias Element = ChangePoint

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int
    private let threshold: Double

    init(base: Base, window: Int, threshold: Double) {
        self.base = base
        self.window = window
        self.threshold = threshold
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields change point detections.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window, threshold: threshold)
    }

    /// Iterator that detects change points asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private let threshold: Double
        private var buffer: [Double] = []
        private var previousMean: Double?
        private var index: Int = 0

        init(base: Base.AsyncIterator, window: Int, threshold: Double) {
            self.baseIterator = base
            self.window = window
            self.threshold = threshold
        }

        /// Yields the next change point when detected.
        ///
        /// - Returns: A change point when a significant shift is detected, or nil when the stream ends.
        public mutating func next() async throws -> ChangePoint? {
            // Read values until we detect a change point
            while true {
                guard let value = try await baseIterator.next() else {
                    return nil
                }

                buffer.append(value)
                index += 1

                // Keep buffer at window size
                if buffer.count > window {
                    buffer.removeFirst()
                }

                // Need at least one full window
                if buffer.count < window {
                    continue
                }

                let currentMean = buffer.reduce(0.0, +) / Double(buffer.count)

                if let prevMean = previousMean {
                    let change = abs(currentMean - prevMean)

                    if change > threshold {
                        previousMean = currentMean
                        return ChangePoint(
                            type: .levelShift,
                            magnitude: currentMean - prevMean,
                            index: index
                        )
                    }
                }

                previousMean = currentMean
            }
        }
    }
}

// MARK: - Forecast Error Calculation

/// AsyncSequence that computes cumulative forecast error metrics from forecast/actual pairs.
///
/// Takes a stream of ``ForecastPair`` values and continuously computes running error metrics
/// (MAE, RMSE, MAPE). Each emitted value represents the cumulative error metrics up to that point,
/// enabling real-time monitoring of forecast accuracy as new predictions and actuals arrive.
///
/// ## Example
/// ```swift
/// let pairs = AsyncValueStream([
///     ForecastPair(actual: 100, forecast: 98),
///     ForecastPair(actual: 105, forecast: 103),
///     ForecastPair(actual: 110, forecast: 112)
/// ])
///
/// for try await errors in pairs.forecastErrors() {
///     print("MAE: \(errors.mae), RMSE: \(errors.rmse), MAPE: \(errors.mape * 100)%")
/// }
/// ```
///
/// ## Use Cases
/// - Monitor forecast model performance in real-time
/// - Compare multiple forecasting methods
/// - Detect when forecast accuracy degrades (trigger model retraining)
/// - Track error metrics over different time periods
public struct AsyncForecastErrorSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == ForecastPair {
    /// Yields cumulative forecast error metrics.
    public typealias Element = StreamingForecastError

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields cumulative forecast error metrics.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator that computes forecast error metrics asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var count: Int = 0
        private var sumAbsError: Double = 0.0
        private var sumSqError: Double = 0.0
        private var sumAbsPercentError: Double = 0.0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Yields the next cumulative error metrics after incorporating a new forecast/actual pair.
        ///
        /// - Returns: Cumulative error metrics (MAE, RMSE, MAPE) up to this point.
        public mutating func next() async throws -> StreamingForecastError? {
            guard let pair = try await baseIterator.next() else {
                return nil
            }

            count += 1
            let error = pair.actual - pair.forecast
            sumAbsError += abs(error)
            sumSqError += error * error

            if pair.actual != 0 {
                sumAbsPercentError += abs(error / pair.actual)
            }

            let mae = sumAbsError / Double(count)
            let rmse = sqrt(sumSqError / Double(count))
            let mape = sumAbsPercentError / Double(count)

            return StreamingForecastError(mae: mae, rmse: rmse, mape: mape)
        }
    }
}
