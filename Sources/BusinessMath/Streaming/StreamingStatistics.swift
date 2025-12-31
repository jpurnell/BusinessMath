//
//  StreamingStatistics.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Statistics Result Types

/// Rolling statistics over a window of values
public struct RollingStats {
    public let mean: Double
    public let variance: Double
    public let stdDev: Double
    public let min: Double
    public let max: Double
    public let sum: Double
    public let count: Int

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

/// Cumulative statistics over all values seen so far
public struct CumulativeStats {
    public let mean: Double
    public let variance: Double
    public let stdDev: Double
    public let min: Double
    public let max: Double
    public let sum: Double
    public let count: Int

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

public struct AsyncRollingMeanSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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

public struct AsyncCumulativeMeanSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Double
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
        private var sum: Double = 0.0
        private var count: Int = 0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

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

public struct AsyncRollingVarianceSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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

public struct AsyncRollingStdDevSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Double
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int

    init(base: Base, window: Int) {
        self.base = base
        self.window = window
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(varianceIterator: base.rollingVariance(window: window).makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var varianceIterator: AsyncRollingVarianceSequence<Base>.Iterator

        init(varianceIterator: AsyncRollingVarianceSequence<Base>.Iterator) {
            self.varianceIterator = varianceIterator
        }

        public mutating func next() async throws -> Double? {
            guard let variance = try await varianceIterator.next() else {
                return nil
            }
            return sqrt(variance)
        }
    }
}

// MARK: - Rolling Min

public struct AsyncRollingMinSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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

public struct AsyncRollingMaxSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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

public struct AsyncRollingSumSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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

public struct AsyncCumulativeSumSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Double
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
        private var sum: Double = 0.0

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

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

public struct AsyncEMASequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
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
        private var ema: Double?

        init(base: Base.AsyncIterator, alpha: Double) {
            self.baseIterator = base
            self.alpha = alpha
        }

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

public struct AsyncRollingStatisticsSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = RollingStats
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

public struct AsyncCumulativeStatisticsSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = CumulativeStats
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
        private var sum: Double = 0.0
        private var mean: Double = 0.0
        private var m2: Double = 0.0  // Sum of squared deviations
        private var min: Double = .infinity
        private var max: Double = -.infinity

        init(base: Base.AsyncIterator) {
            self.baseIterator = base
        }

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
