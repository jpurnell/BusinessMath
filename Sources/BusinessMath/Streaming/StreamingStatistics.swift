//
//  StreamingStatistics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Statistics Result Types

/// Comprehensive rolling statistics over a fixed window of values.
///
/// Provides a complete statistical summary of the most recent observations in the stream,
/// computed over a fixed-size rolling window. As new values arrive, the oldest values are
/// dropped, maintaining constant memory usage regardless of stream length.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await stats in stream.rollingStatistics(window: 3) {
///     print("Mean: \(stats.mean), StdDev: \(stats.stdDev)")
/// }
/// // Window [10, 20, 30]: mean ≈ 20
/// // Window [20, 30, 40]: mean ≈ 30
/// // Window [30, 40, 50]: mean ≈ 40
/// ```
///
/// - SeeAlso: ``CumulativeStats``, ``AsyncRollingStatisticsSequence``
public struct RollingStats {
    /// The arithmetic mean of values in the window.
    public let mean: Double

    /// The sample variance of values in the window (Bessel's correction applied).
    public let variance: Double

    /// The sample standard deviation of values in the window.
    public let stdDev: Double

    /// The minimum value in the window.
    public let min: Double

    /// The maximum value in the window.
    public let max: Double

    /// The sum of all values in the window.
    public let sum: Double

    /// The number of values in the window.
    public let count: Int

    /// Creates comprehensive rolling statistics.
    ///
    /// - Parameters:
    ///   - mean: The arithmetic mean of the window.
    ///   - variance: The sample variance with Bessel's correction.
    ///   - stdDev: The sample standard deviation.
    ///   - min: The minimum value in the window.
    ///   - max: The maximum value in the window.
    ///   - sum: The sum of all values in the window.
    ///   - count: The number of values in the window.
    public init(mean: Double, variance: Double, stdDev: Double, min: Double, max: Double, sum: Double, count: Int) {
        self.mean = mean
        self.variance = variance
        self.stdDev = stdDev
        self.min = min
        self.max = max
        self.sum = sum
        self.count = count
    }
}

/// Comprehensive cumulative statistics over all values seen in the stream so far.
///
/// Provides a complete statistical summary of all observations from the beginning of the
/// stream up to the current point. Unlike rolling statistics, cumulative statistics consider
/// the entire history, making them suitable for long-term trend analysis and overall
/// characterization of the data distribution.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await stats in stream.cumulativeStatistics() {
///     print("Mean: \(stats.mean), Count: \(stats.count)")
/// }
/// // After value 10: mean = 10, count = 1
/// // After value 20: mean = 15, count = 2
/// // After value 30: mean = 20, count = 3
/// // ...
/// ```
///
/// - SeeAlso: ``RollingStats``, ``AsyncCumulativeStatisticsSequence``
public struct CumulativeStats {
    /// The arithmetic mean of all values seen so far.
    public let mean: Double

    /// The sample variance of all values (Bessel's correction applied).
    public let variance: Double

    /// The sample standard deviation of all values.
    public let stdDev: Double

    /// The minimum value seen so far.
    public let min: Double

    /// The maximum value seen so far.
    public let max: Double

    /// The sum of all values seen so far.
    public let sum: Double

    /// The total number of values seen so far.
    public let count: Int

    /// Creates comprehensive cumulative statistics.
    ///
    /// - Parameters:
    ///   - mean: The arithmetic mean of all values.
    ///   - variance: The sample variance with Bessel's correction.
    ///   - stdDev: The sample standard deviation.
    ///   - min: The minimum value seen.
    ///   - max: The maximum value seen.
    ///   - sum: The sum of all values.
    ///   - count: The total number of values.
    public init(mean: Double, variance: Double, stdDev: Double, min: Double, max: Double, sum: Double, count: Int) {
        self.mean = mean
        self.variance = variance
        self.stdDev = stdDev
        self.min = min
        self.max = max
        self.sum = sum
        self.count = count
    }
}

// MARK: - AsyncSequence Extensions for Statistics

extension AsyncSequence where Element == Double {

    // MARK: - Mean

    /// Calculate rolling mean over a fixed window
    public func rollingMean(window: Int) -> AsyncRollingMeanSequence<Self> {
        AsyncRollingMeanSequence(base: self, window: window)
    }

    /// Calculate cumulative mean over all values seen so far
    public func cumulativeMean() -> AsyncCumulativeMeanSequence<Self> {
        AsyncCumulativeMeanSequence(base: self)
    }

    // MARK: - Variance and Standard Deviation

    /// Calculate rolling variance over a fixed window
    public func rollingVariance(window: Int) -> AsyncRollingVarianceSequence<Self> {
        AsyncRollingVarianceSequence(base: self, window: window)
    }

    /// Calculate rolling standard deviation over a fixed window
    public func rollingStdDev(window: Int) -> AsyncRollingStdDevSequence<Self> {
        AsyncRollingStdDevSequence(base: self, window: window)
    }

    // MARK: - Min/Max

    /// Calculate rolling minimum over a fixed window
    public func rollingMin(window: Int) -> AsyncRollingMinSequence<Self> {
        AsyncRollingMinSequence(base: self, window: window)
    }

    /// Calculate rolling maximum over a fixed window
    public func rollingMax(window: Int) -> AsyncRollingMaxSequence<Self> {
        AsyncRollingMaxSequence(base: self, window: window)
    }

    // MARK: - Sum

    /// Calculate rolling sum over a fixed window
    public func rollingSum(window: Int) -> AsyncRollingSumSequence<Self> {
        AsyncRollingSumSequence(base: self, window: window)
    }

    /// Calculate cumulative sum over all values seen so far
    public func cumulativeSum() -> AsyncCumulativeSumSequence<Self> {
        AsyncCumulativeSumSequence(base: self)
    }

    // MARK: - Exponential Moving Average

    /// Calculate exponential moving average
    /// - Parameter alpha: Smoothing factor (0 < alpha <= 1), higher values give more weight to recent values
    public func exponentialMovingAverage(alpha: Double) -> AsyncEMASequence<Self> {
        AsyncEMASequence(base: self, alpha: alpha)
    }

    // MARK: - Comprehensive Statistics

    /// Calculate comprehensive rolling statistics over a fixed window
    public func rollingStatistics(window: Int) -> AsyncRollingStatisticsSequence<Self> {
        AsyncRollingStatisticsSequence(base: self, window: window)
    }

    /// Calculate comprehensive cumulative statistics over all values seen so far
    public func cumulativeStatistics() -> AsyncCumulativeStatisticsSequence<Self> {
        AsyncCumulativeStatisticsSequence(base: self)
    }
}

// MARK: - Rolling Mean

/// AsyncSequence that computes rolling mean over a fixed window.
///
/// Calculates the arithmetic mean of the most recent N values in the stream. The window
/// fills up first, then slides forward as new values arrive, maintaining constant memory
/// usage. Useful for smoothing noisy data and identifying short-term trends.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await mean in stream.rollingMean(window: 3) {
///     print(mean)
/// }
/// // Output: 20.0 (mean of [10, 20, 30])
/// //         30.0 (mean of [20, 30, 40])
/// //         40.0 (mean of [30, 40, 50])
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size (5-20 for smoothing, 50-200 for long-term trends)
///
/// - SeeAlso: ``AsyncCumulativeMeanSequence``, ``AsyncEMASequence``
public struct AsyncRollingMeanSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling mean values.
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
    /// - Returns: An iterator that yields rolling mean values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling mean sequence.
    ///
    /// Maintains a circular buffer of the most recent values. Fills the buffer to window
    /// size before emitting the first mean, then slides the window forward one value at
    /// a time.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next rolling mean value.
        ///
        /// Fills the buffer to window size, computes the mean, then attempts to slide
        /// the window forward. Returns `nil` when the stream is exhausted.
        ///
        /// - Returns: The next rolling mean, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

            // Calculate mean for current window
            let sum = buffer.reduce(0.0, +)
            let mean = sum / Double(buffer.count)

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                // No more values - mark complete so next call returns nil
                isComplete = true
            }

            return mean
        }
    }
}

// MARK: - Cumulative Mean

/// AsyncSequence that computes cumulative mean over all values seen so far.
///
/// Calculates the arithmetic mean of all values from the beginning of the stream up to
/// each point. Unlike rolling mean which maintains a fixed window, cumulative mean
/// considers the complete history, providing a running average that converges over time.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await mean in stream.cumulativeMean() {
///     print(mean)
/// }
/// // Output: 10.0 (mean of [10])
/// //         15.0 (mean of [10, 20])
/// //         20.0 (mean of [10, 20, 30])
/// //         25.0 (mean of [10, 20, 30, 40])
/// //         30.0 (mean of [10, 20, 30, 40, 50])
/// ```
///
/// ## Use Cases
/// - Long-term average tracking
/// - Convergence analysis
/// - Overall data characterization
///
/// - SeeAlso: ``AsyncRollingMeanSequence``, ``AsyncCumulativeSumSequence``
public struct AsyncCumulativeMeanSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields cumulative mean values.
    public typealias Element = Double

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields cumulative mean values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator for the cumulative mean sequence.
    ///
    /// Maintains running sum and count, computing mean incrementally as each new value
    /// arrives. Constant memory usage regardless of stream length.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var sum: Double = 0.0
        private var count: Int = 0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Advances to the next cumulative mean value.
        ///
        /// Updates running sum and count, then returns the updated mean.
        ///
        /// - Returns: The next cumulative mean, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> Double? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            count += 1
            sum += value
            return sum / Double(count)
        }
    }
}

// MARK: - Rolling Variance (Welford's Algorithm)

/// AsyncSequence that computes rolling variance over a fixed window.
///
/// Calculates the sample variance (with Bessel's correction) of the most recent N values
/// using Welford's numerically stable online algorithm. Variance measures the spread of
/// data points around the mean, useful for assessing volatility and risk.
///
/// Formula: Var(X) = Σ(x - mean)² / (n - 1)
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 20, 10])
/// for try await variance in stream.rollingVariance(window: 3) {
///     print("Variance: \(variance)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size (10-30 for volatility tracking, larger for stable estimates)
///
/// ## Technical Note
/// Uses Welford's algorithm for numerical stability, avoiding catastrophic cancellation
/// errors that can occur with the naïve two-pass formula.
///
/// - SeeAlso: ``AsyncRollingStdDevSequence``, ``AsyncRollingStatisticsSequence``
public struct AsyncRollingVarianceSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling variance values.
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
    /// - Returns: An iterator that yields rolling variance values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling variance sequence.
    ///
    /// Maintains a buffer of recent values and computes variance using Welford's
    /// numerically stable algorithm, which avoids precision loss from large intermediate
    /// values.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next rolling variance value.
        ///
        /// Fills buffer, computes variance with Welford's algorithm, then slides window.
        ///
        /// - Returns: The next rolling variance, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

            // Calculate variance using Welford's online algorithm
            let variance = calculateVariance(buffer)

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return variance
        }

        private func calculateVariance(_ values: [Double]) -> Double {
            guard values.count > 1 else { return 0.0 }

            var mean = 0.0
            var m2 = 0.0

            for (i, value) in values.enumerated() {
                let delta = value - mean
                mean += delta / Double(i + 1)
                let delta2 = value - mean
                m2 += delta * delta2
            }

            // Sample variance: divide by (n-1)
            return m2 / Double(values.count - 1)
        }
    }
}

// MARK: - Rolling Standard Deviation

/// AsyncSequence that computes rolling standard deviation over a fixed window.
///
/// Calculates the sample standard deviation (square root of variance) of the most recent
/// N values. Standard deviation is in the same units as the original data, making it more
/// intuitive than variance for assessing spread and volatility.
///
/// Formula: StdDev(X) = √(Var(X))
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 20, 10])
/// for try await stdDev in stream.rollingStdDev(window: 3) {
///     print("Std Dev: \(stdDev)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size (20-30 for volatility assessment, 252 for annualized financial volatility)
///
/// - SeeAlso: ``AsyncRollingVarianceSequence``
public struct AsyncRollingStdDevSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling standard deviation values.
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
    /// - Returns: An iterator that yields rolling standard deviation values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(varianceIterator: base.rollingVariance(window: window).makeAsyncIterator())
    }

    /// Iterator for the rolling standard deviation sequence.
    ///
    /// Wraps the rolling variance iterator and computes square root of each variance value.
    /// This composition approach ensures the same numerical stability as the variance
    /// computation.
    public struct Iterator: AsyncIteratorProtocol {
        private var varianceIterator: AsyncRollingVarianceSequence<Base>.Iterator

        init(varianceIterator: AsyncRollingVarianceSequence<Base>.Iterator) {
            self.varianceIterator = varianceIterator
        }

        /// Advances to the next rolling standard deviation value.
        ///
        /// Gets the next variance and returns its square root.
        ///
        /// - Returns: The next rolling standard deviation, or `nil` if exhausted.
        /// - Throws: Rethrows any error from the variance sequence.
        public mutating func next() async throws -> Double? {
            guard let variance = try await varianceIterator.next() else {
                return nil
            }
            return sqrt(variance)
        }
    }
}

// MARK: - Rolling Min

/// AsyncSequence that computes rolling minimum over a fixed window.
///
/// Tracks the smallest value in the most recent N observations. Useful for identifying
/// support levels, worst-case scenarios, and downside risk in financial data.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([15, 20, 10, 25, 12])
/// for try await min in stream.rollingMin(window: 3) {
///     print("Min: \(min)")
/// }
/// // Output: 10.0 (min of [15, 20, 10])
/// //         10.0 (min of [20, 10, 25])
/// //         10.0 (min of [10, 25, 12])
/// ```
///
/// - SeeAlso: ``AsyncRollingMaxSequence``
public struct AsyncRollingMinSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling minimum values.
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
    /// - Returns: An iterator that yields rolling minimum values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling minimum sequence.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next rolling minimum value.
        ///
        /// - Returns: The next rolling minimum, or `nil` if exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

            // Calculate min
            let min = buffer.min() ?? 0.0

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return min
        }
    }
}

// MARK: - Rolling Max

/// AsyncSequence that computes rolling maximum over a fixed window.
///
/// Tracks the largest value in the most recent N observations. Useful for identifying
/// resistance levels, peak performance, and upside potential in financial data.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([15, 20, 30, 25, 18])
/// for try await max in stream.rollingMax(window: 3) {
///     print("Max: \(max)")
/// }
/// // Output: 30.0 (max of [15, 20, 30])
/// //         30.0 (max of [20, 30, 25])
/// //         30.0 (max of [30, 25, 18])
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size (20-30 for recent peaks, 252 for annual highs in finance)
///
/// - SeeAlso: ``AsyncRollingMinSequence``
public struct AsyncRollingMaxSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling maximum values.
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
    /// - Returns: An iterator that yields rolling maximum values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling maximum sequence.
    ///
    /// Maintains a buffer of recent values and finds the maximum in the current window.
    /// Slides the window forward one value at a time as new observations arrive.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next rolling maximum value.
        ///
        /// Fills buffer to window size, finds the maximum, then slides the window.
        ///
        /// - Returns: The next rolling maximum, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

            // Calculate max
            let max = buffer.max() ?? 0.0

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return max
        }
    }
}

// MARK: - Rolling Sum

/// AsyncSequence that computes rolling sum over a fixed window.
///
/// Calculates the sum of the most recent N values in the stream. Rolling sums are useful
/// for tracking total activity within a time window, such as sales volume, transaction
/// totals, or aggregate performance metrics.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await sum in stream.rollingSum(window: 3) {
///     print("Sum: \(sum)")
/// }
/// // Output: 60.0 (sum of [10, 20, 30])
/// //         90.0 (sum of [20, 30, 40])
/// //         120.0 (sum of [30, 40, 50])
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size (7 for weekly totals, 30 for monthly totals, custom for specific periods)
///
/// ## Use Cases
/// - Revenue tracking over time periods
/// - Transaction volume monitoring
/// - Resource consumption analysis
///
/// - SeeAlso: ``AsyncCumulativeSumSequence``, ``AsyncRollingMeanSequence``
public struct AsyncRollingSumSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields rolling sum values.
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
    /// - Returns: An iterator that yields rolling sum values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling sum sequence.
    ///
    /// Maintains a buffer of recent values and computes their sum. Slides the window
    /// forward as new values arrive, maintaining constant memory usage.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next rolling sum value.
        ///
        /// Fills buffer to window size, computes the sum, then slides the window.
        ///
        /// - Returns: The next rolling sum, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

            // Calculate sum
            let sum = buffer.reduce(0.0, +)

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return sum
        }
    }
}

// MARK: - Cumulative Sum

/// AsyncSequence that computes cumulative sum over all values seen so far.
///
/// Calculates the running total of all values from the beginning of the stream up to each
/// point. Each output represents the sum of all values observed so far, making it useful for
/// tracking total accumulation, portfolio value over time, or year-to-date totals.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await sum in stream.cumulativeSum() {
///     print("Cumulative Sum: \(sum)")
/// }
/// // Output: 10.0  (sum of [10])
/// //         30.0  (sum of [10, 20])
/// //         60.0  (sum of [10, 20, 30])
/// //         100.0 (sum of [10, 20, 30, 40])
/// //         150.0 (sum of [10, 20, 30, 40, 50])
/// ```
///
/// ## Use Cases
/// - Portfolio value tracking
/// - Year-to-date revenue calculation
/// - Total resource consumption
/// - Integration of rate data to obtain totals
///
/// ## Technical Note
/// Uses constant memory regardless of stream length, maintaining only the running sum.
///
/// - SeeAlso: ``AsyncRollingSumSequence``, ``AsyncCumulativeMeanSequence``
public struct AsyncCumulativeSumSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields cumulative sum values.
    public typealias Element = Double

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields cumulative sum values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator for the cumulative sum sequence.
    ///
    /// Maintains a running sum, adding each new value as it arrives. Memory usage
    /// remains constant regardless of how many values are processed.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var sum: Double = 0.0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Advances to the next cumulative sum value.
        ///
        /// Adds the next value to the running sum and returns the updated total.
        ///
        /// - Returns: The next cumulative sum, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> Double? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            sum += value
            return sum
        }
    }
}

// MARK: - Exponential Moving Average

/// AsyncSequence that computes exponential moving average (EMA).
///
/// Calculates a weighted moving average that gives exponentially decreasing weight to older
/// observations. Unlike simple moving averages, EMA responds more quickly to recent changes
/// while still incorporating historical data. The smoothing factor alpha controls the rate
/// of decay: higher values weight recent data more heavily.
///
/// Formula: EMA(t) = α × value(t) + (1 - α) × EMA(t-1)
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 25, 15])
/// for try await ema in stream.exponentialMovingAverage(alpha: 0.3) {
///     print("EMA: \(ema)")
/// }
/// // Output: 10.0  (first value)
/// //         13.0  (0.3 × 20 + 0.7 × 10)
/// //         18.1  (0.3 × 30 + 0.7 × 13)
/// //         ...
/// ```
///
/// ## Parameter Guidance
/// - **alpha**: Smoothing factor (0 < α ≤ 1)
///   - 0.1-0.2: Heavy smoothing, slow response to changes (long-term trends)
///   - 0.3-0.5: Balanced smoothing (general purpose)
///   - 0.6-0.9: Light smoothing, fast response (short-term trends)
///   - Common conversions: α ≈ 2/(N+1) where N is equivalent window size
///
/// ## Use Cases
/// - Price trend analysis in financial markets
/// - Signal smoothing with responsiveness
/// - Adaptive forecasting
/// - Technical indicators (MACD, EMA crossovers)
///
/// ## Technical Note
/// The first value initializes the EMA directly. Subsequent values apply the exponential
/// weighting formula, creating a smooth continuous sequence.
///
/// - SeeAlso: ``AsyncRollingMeanSequence``, ``AsyncCumulativeMeanSequence``
public struct AsyncEMASequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields exponential moving average values.
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
    /// - Returns: An iterator that yields exponential moving average values.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), alpha: alpha)
    }

    /// Iterator for the exponential moving average sequence.
    ///
    /// Maintains the current EMA value and updates it exponentially with each new observation.
    /// The first value initializes the EMA, and subsequent values are blended according to
    /// the smoothing factor alpha.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let alpha: Double
        private var ema: Double?

        init(base: Base.AsyncIterator, alpha: Double) {
            self.baseIterator = base
            self.alpha = alpha
        }

        /// Advances to the next exponential moving average value.
        ///
        /// For the first value, initializes EMA directly. For subsequent values, applies
        /// the exponential weighting formula: EMA = α × value + (1 - α) × previous_EMA.
        ///
        /// - Returns: The next EMA value, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> Double? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            if let currentEma = ema {
                ema = alpha * value + (1.0 - alpha) * currentEma
            } else {
                ema = value
            }

            return ema
        }
    }
}

// MARK: - Comprehensive Rolling Statistics

/// AsyncSequence that computes comprehensive rolling statistics over a fixed window.
///
/// Calculates a complete statistical summary (mean, variance, standard deviation, min, max,
/// sum, count) for the most recent N values in the stream. This provides a full characterization
/// of the rolling window at each step, useful when multiple statistics are needed simultaneously.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await stats in stream.rollingStatistics(window: 3) {
///     print("Window [mean: \(stats.mean), stdDev: \(stats.stdDev), range: \(stats.min)-\(stats.max)]")
/// }
/// // Output: Window [mean: 20.0, stdDev: 10.0, range: 10.0-30.0]
/// //         Window [mean: 30.0, stdDev: 10.0, range: 20.0-40.0]
/// //         Window [mean: 40.0, stdDev: 10.0, range: 30.0-50.0]
/// ```
///
/// ## Parameter Guidance
/// - **window**: Window size
///   - 20-30: Short-term analysis, responsive to changes
///   - 50-100: Medium-term trends, balanced stability
///   - 200-252: Long-term patterns (e.g., annual trading days)
///
/// ## Use Cases
/// - Real-time risk monitoring (volatility + range)
/// - Quality control (mean + std dev)
/// - Market analysis (price statistics)
/// - Performance dashboards requiring multiple metrics
///
/// ## Technical Note
/// Uses Welford's numerically stable algorithm for variance calculation, avoiding
/// precision loss that can occur with naive two-pass formulas. All statistics are
/// computed in a single pass over the window.
///
/// - SeeAlso: ``RollingStats``, ``AsyncCumulativeStatisticsSequence``
public struct AsyncRollingStatisticsSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields comprehensive rolling statistics.
    public typealias Element = RollingStats

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
    /// - Returns: An iterator that yields rolling statistics.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window)
    }

    /// Iterator for the rolling statistics sequence.
    ///
    /// Maintains a buffer of recent values and computes all statistics at each step.
    /// Uses Welford's algorithm for numerically stable variance computation.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private var buffer: [Double] = []
        private var isComplete = false

        init(base: Base.AsyncIterator, window: Int) {
            self.baseIterator = base
            self.window = window
        }

        /// Advances to the next set of rolling statistics.
        ///
        /// Fills buffer to window size, computes all statistics in a single pass, then
        /// slides the window. Returns `nil` when the stream is exhausted.
        ///
        /// - Returns: The next rolling statistics, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> RollingStats? {
            guard !isComplete else { return nil }

            // Fill buffer to window size
            while buffer.count < window {
                guard let value = try await baseIterator.next() else {
                    isComplete = true
                    return nil
                }
                buffer.append(value)
            }

            // Calculate all statistics
            let stats = calculateStats(buffer)

            // Try to slide window for next iteration
            if let nextValue = try await baseIterator.next() {
                buffer.removeFirst()
                buffer.append(nextValue)
            } else {
                isComplete = true
            }

            return stats
        }

        private func calculateStats(_ values: [Double]) -> RollingStats {
            let count = values.count
            let sum = values.reduce(0.0, +)
            let mean = sum / Double(count)

            // Welford's algorithm for variance
            var m2 = 0.0
            var runningMean = 0.0
            for (i, value) in values.enumerated() {
                let delta = value - runningMean
                runningMean += delta / Double(i + 1)
                let delta2 = value - runningMean
                m2 += delta * delta2
            }
            let variance = count > 1 ? m2 / Double(count - 1) : 0.0
            let stdDev = sqrt(variance)

            let min = values.min() ?? 0.0
            let max = values.max() ?? 0.0

            return RollingStats(
                mean: mean,
                variance: variance,
                stdDev: stdDev,
                min: min,
                max: max,
                sum: sum,
                count: count
            )
        }
    }
}

// MARK: - Comprehensive Cumulative Statistics

/// AsyncSequence that computes comprehensive cumulative statistics over all values seen so far.
///
/// Calculates a complete statistical summary (mean, variance, standard deviation, min, max,
/// sum, count) for all values from the beginning of the stream up to each point. Unlike rolling
/// statistics, cumulative statistics consider the entire history, providing a progressively
/// refined characterization of the complete dataset.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([10, 20, 30, 40, 50])
/// for try await stats in stream.cumulativeStatistics() {
///     print("After \(stats.count) values: mean = \(stats.mean), stdDev = \(stats.stdDev)")
/// }
/// // Output: After 1 values: mean = 10.0, stdDev = 0.0
/// //         After 2 values: mean = 15.0, stdDev = 7.07
/// //         After 3 values: mean = 20.0, stdDev = 10.0
/// //         After 4 values: mean = 25.0, stdDev = 12.91
/// //         After 5 values: mean = 30.0, stdDev = 15.81
/// ```
///
/// ## Use Cases
/// - Overall dataset characterization
/// - Long-term trend analysis
/// - Convergence monitoring
/// - Historical performance tracking
/// - Quality metrics over entire production run
///
/// ## Technical Note
/// Uses Welford's online algorithm for numerically stable variance calculation, allowing
/// incremental updates without storing all values. Maintains constant memory usage regardless
/// of stream length.
///
/// The algorithm updates mean and variance incrementally with each new value:
/// - Mean: μ(n) = μ(n-1) + (x(n) - μ(n-1)) / n
/// - Variance: σ²(n) = Σ(x - μ)² / (n - 1)
///
/// This approach avoids catastrophic cancellation errors that can occur when computing
/// variance as E[X²] - E[X]² with large means.
///
/// - SeeAlso: ``CumulativeStats``, ``AsyncRollingStatisticsSequence``
public struct AsyncCumulativeStatisticsSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields comprehensive cumulative statistics.
    public typealias Element = CumulativeStats

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base

    init(base: Base) {
        self.base = base
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields cumulative statistics.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    /// Iterator for the cumulative statistics sequence.
    ///
    /// Maintains running statistics incrementally using Welford's online algorithm for
    /// numerical stability. Updates all statistics with each new value without storing
    /// historical data.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private var count: Int = 0
        private var sum: Double = 0.0
        private var mean: Double = 0.0
        private var m2: Double = 0.0  // Sum of squared deviations
        private var min: Double = .infinity
        private var max: Double = -.infinity

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

        /// Advances to the next set of cumulative statistics.
        ///
        /// Updates all statistics incrementally with the next value using Welford's algorithm.
        /// Returns the complete statistical summary after incorporating the new observation.
        ///
        /// - Returns: The next cumulative statistics, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
        public mutating func next() async throws -> CumulativeStats? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            // Update count and sum
            count += 1
            sum += value

            // Update min and max
            if value < min { min = value }
            if value > max { max = value }

            // Update mean and variance using Welford's online algorithm
            let delta = value - mean
            mean += delta / Double(count)
            let delta2 = value - mean
            m2 += delta * delta2

            let variance = count > 1 ? m2 / Double(count - 1) : 0.0
            let stdDev = sqrt(variance)

            return CumulativeStats(
                mean: mean,
                variance: variance,
                stdDev: stdDev,
                min: min,
                max: max,
                sum: sum,
                count: count
            )
        }
    }
}
