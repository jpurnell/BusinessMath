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

/// Trend detection result
public struct TrendDetection {
    public let direction: TrendDirection
    public let slope: Double
    public let confidence: Double

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

/// Change point detection result
public struct ChangePoint {
    public let type: ChangePointType
    public let magnitude: Double
    public let index: Int

    public init(type: ChangePointType, magnitude: Double, index: Int) {
        self.type = type
        self.magnitude = magnitude
        self.index = index
    }
}

/// Streaming forecast error metrics
public struct StreamingForecastError {
    public let mae: Double  // Mean Absolute Error
    public let rmse: Double // Root Mean Squared Error
    public let mape: Double // Mean Absolute Percentage Error

    public init(mae: Double, rmse: Double, mape: Double) {
        self.mae = mae
        self.rmse = rmse
        self.mape = mape
    }
}

/// Double exponential smoothing forecast
public struct DoubleExponentialForecast {
    public let level: Double
    public let trend: Double

    public init(level: Double, trend: Double) {
        self.level = level
        self.trend = trend
    }

    public func forecast(steps: Int) -> Double {
        return level + Double(steps) * trend
    }
}

/// Triple exponential smoothing forecast
public struct TripleExponentialForecast {
    public let level: Double
    public let trend: Double
    public let seasonalFactors: [Double]

    public init(level: Double, trend: Double, seasonalFactors: [Double]) {
        self.level = level
        self.trend = trend
        self.seasonalFactors = seasonalFactors
    }

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

/// Pair of actual and forecasted values
public struct ForecastPair {
    public let actual: Double
    public let forecast: Double

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

public struct AsyncSimpleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Double
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let alpha: Double

    init(base: Base, alpha: Double) {
        self.base = base
        self.alpha = alpha
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), alpha: alpha)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let alpha: Double
        private var forecast: Double?

        init(base: Base.AsyncIterator, alpha: Double) {
            self.baseIterator = base
            self.alpha = alpha
        }

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

public struct AsyncDoubleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = DoubleExponentialForecast
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let alpha: Double
    private let beta: Double

    init(base: Base, alpha: Double, beta: Double) {
        self.base = base
        self.alpha = alpha
        self.beta = beta
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), alpha: alpha, beta: beta)
    }

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

public struct AsyncTripleExponentialSmoothingSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = TripleExponentialForecast
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

    public func makeAsyncIterator() -> Iterator {
        Iterator(
            base: base.makeAsyncIterator(),
            alpha: alpha,
            beta: beta,
            gamma: gamma,
            seasonLength: seasonLength
        )
    }

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

public struct AsyncMovingAverageForecastSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Double
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int

    init(base: Base, window: Int) {
        self.base = base
        self.window = window
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

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

public struct AsyncTrendDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = TrendDetection
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int

    init(base: Base, window: Int) {
        self.base = base
        self.window = window
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

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

public struct AsyncChangePointDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = ChangePoint
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int
    private let threshold: Double

    init(base: Base, window: Int, threshold: Double) {
        self.base = base
        self.window = window
        self.threshold = threshold
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window, threshold: threshold)
    }

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

public struct AsyncForecastErrorSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == ForecastPair {
    public typealias Element = StreamingForecastError
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var count: Int = 0
        private var sumAbsError: Double = 0.0
        private var sumSqError: Double = 0.0
        private var sumAbsPercentError: Double = 0.0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

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
