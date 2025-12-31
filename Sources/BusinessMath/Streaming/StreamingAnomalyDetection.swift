//
//  StreamingAnomalyDetection.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Foundation

// MARK: - Anomaly Detection Result Types

/// Direction of shift detected by CUSUM
public enum CUSUMDirection {
    case upward
    case downward
    case stable
}

/// CUSUM control chart signal
public struct CUSUMSignal {
    public let direction: CUSUMDirection
    public let cumulativeSum: Double
    public let isSignaling: Bool
    public let index: Int

    public init(direction: CUSUMDirection, cumulativeSum: Double, isSignaling: Bool, index: Int) {
        self.direction = direction
        self.cumulativeSum = cumulativeSum
        self.isSignaling = isSignaling
        self.index = index
    }
}

/// EWMA control chart signal
public struct EWMASignal {
    public let ewma: Double
    public let upperControlLimit: Double
    public let lowerControlLimit: Double
    public let isOutOfControl: Bool
    public let index: Int

    public init(ewma: Double, upperControlLimit: Double, lowerControlLimit: Double, isOutOfControl: Bool, index: Int) {
        self.ewma = ewma
        self.upperControlLimit = upperControlLimit
        self.lowerControlLimit = lowerControlLimit
        self.isOutOfControl = isOutOfControl
        self.index = index
    }
}

/// Outlier detection method
public enum OutlierMethod {
    case zScore(threshold: Double)
    case iqr(multiplier: Double)
    case mad(threshold: Double)
}

/// Outlier detection result
public struct OutlierDetection {
    public let value: Double
    public let score: Double
    public let isOutlier: Bool
    public let method: String
    public let index: Int

    public init(value: Double, score: Double, isOutlier: Bool, method: String, index: Int) {
        self.value = value
        self.score = score
        self.isOutlier = isOutlier
        self.method = method
        self.index = index
    }
}

/// Breakpoint detection method
public enum BreakpointMethod {
    case binarySegmentation(minSegmentSize: Int, maxBreakpoints: Int)
}

/// Detected breakpoint in time series
public struct Breakpoint {
    public let index: Int
    public let costReduction: Double
    public let leftMean: Double
    public let rightMean: Double

    public init(index: Int, costReduction: Double, leftMean: Double, rightMean: Double) {
        self.index = index
        self.costReduction = costReduction
        self.leftMean = leftMean
        self.rightMean = rightMean
    }
}

/// Seasonal anomaly detection result
public struct SeasonalAnomaly {
    public let value: Double
    public let expectedValue: Double
    public let deviation: Double
    public let isAnomaly: Bool
    public let index: Int

    public init(value: Double, expectedValue: Double, deviation: Double, isAnomaly: Bool, index: Int) {
        self.value = value
        self.expectedValue = expectedValue
        self.deviation = deviation
        self.isAnomaly = isAnomaly
        self.index = index
    }
}

/// Method for composite anomaly scoring
public enum AnomalyMethod {
    case zScore
    case iqr
    case mad
}

/// Composite anomaly score combining multiple methods
public struct CompositeAnomalyScore {
    public let value: Double
    public let score: Double  // 0.0 to 1.0
    public let methodScores: [String: Double]
    public let index: Int

    public init(value: Double, score: Double, methodScores: [String: Double], index: Int) {
        self.value = value
        self.score = score
        self.methodScores = methodScores
        self.index = index
    }
}

// MARK: - AsyncSequence Extensions for Anomaly Detection

extension AsyncSequence where Element == Double {

    /// CUSUM (Cumulative Sum) control chart for detecting shifts in mean
    /// - Parameters:
    ///   - target: Target mean value
    ///   - drift: Half the shift you want to detect
    ///   - threshold: Decision threshold (typically 4-5)
    public func cusum(target: Double, drift: Double, threshold: Double) -> AsyncCUSUMSequence<Self> {
        AsyncCUSUMSequence(base: self, target: target, drift: drift, threshold: threshold)
    }

    /// EWMA (Exponentially Weighted Moving Average) control chart
    /// - Parameters:
    ///   - target: Target mean value
    ///   - lambda: Smoothing parameter (0 < λ ≤ 1), typically 0.2-0.3
    ///   - controlLimitSigma: Number of standard deviations for control limits
    public func ewma(target: Double, lambda: Double, controlLimitSigma: Double) -> AsyncEWMASequence<Self> {
        AsyncEWMASequence(base: self, target: target, lambda: lambda, controlLimitSigma: controlLimitSigma)
    }

    /// Detect outliers using various statistical methods
    /// - Parameters:
    ///   - method: Outlier detection method to use
    ///   - window: Size of rolling window for statistics
    public func detectOutliers(method: OutlierMethod, window: Int) -> AsyncOutlierDetectionSequence<Self> {
        AsyncOutlierDetectionSequence(base: self, method: method, window: window)
    }

    /// Detect breakpoints (change points) in the series
    /// - Parameter method: Breakpoint detection method
    public func detectBreakpoints(method: BreakpointMethod) -> AsyncBreakpointDetectionSequence<Self> {
        AsyncBreakpointDetectionSequence(base: self, method: method)
    }

    /// Detect anomalies in seasonal patterns
    /// - Parameters:
    ///   - period: Length of seasonal period
    ///   - threshold: Z-score threshold for anomaly detection
    public func detectSeasonalAnomalies(period: Int, threshold: Double) -> AsyncSeasonalAnomalySequence<Self> {
        AsyncSeasonalAnomalySequence(base: self, period: period, threshold: threshold)
    }

    /// Calculate composite anomaly score using multiple methods
    /// - Parameters:
    ///   - window: Size of rolling window
    ///   - methods: Array of detection methods to combine
    public func compositeAnomalyScore(window: Int, methods: [AnomalyMethod]) -> AsyncCompositeAnomalySequence<Self> {
        AsyncCompositeAnomalySequence(base: self, window: window, methods: methods)
    }
}

// MARK: - CUSUM Control Chart

public struct AsyncCUSUMSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = CUSUMSignal
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let target: Double
    private let drift: Double
    private let threshold: Double

    init(base: Base, target: Double, drift: Double, threshold: Double) {
        self.base = base
        self.target = target
        self.drift = drift
        self.threshold = threshold
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), target: target, drift: drift, threshold: threshold)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let target: Double
        private let drift: Double
        private let threshold: Double
        private var cPlusIndex: Double = 0.0
        private var cMinusIndex: Double = 0.0
        private var index = 0

        init(base: Base.AsyncIterator, target: Double, drift: Double, threshold: Double) {
            self.baseIterator = base
            self.target = target
            self.drift = drift
            self.threshold = threshold
        }

        public mutating func next() async throws -> CUSUMSignal? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            // Tabular CUSUM
            let deviation = value - target
            cPlusIndex = Swift.max(0, cPlusIndex + deviation - drift)
            cMinusIndex = Swift.max(0, cMinusIndex - deviation - drift)

            let direction: CUSUMDirection
            let cumulativeSum: Double
            let isSignaling: Bool

            if cPlusIndex > threshold {
                direction = .upward
                cumulativeSum = cPlusIndex
                isSignaling = true
            } else if cMinusIndex > threshold {
                direction = .downward
                cumulativeSum = cMinusIndex
                isSignaling = true
            } else {
                direction = .stable
                cumulativeSum = Swift.max(cPlusIndex, cMinusIndex)
                isSignaling = false
            }

            let signal = CUSUMSignal(
                direction: direction,
                cumulativeSum: cumulativeSum,
                isSignaling: isSignaling,
                index: index
            )

            index += 1
            return signal
        }
    }
}

// MARK: - EWMA Control Chart

public struct AsyncEWMASequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = EWMASignal
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let target: Double
    private let lambda: Double
    private let controlLimitSigma: Double

    init(base: Base, target: Double, lambda: Double, controlLimitSigma: Double) {
        self.base = base
        self.target = target
        self.lambda = lambda
        self.controlLimitSigma = controlLimitSigma
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), target: target, lambda: lambda, controlLimitSigma: controlLimitSigma)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let target: Double
        private let lambda: Double
        private let controlLimitSigma: Double
        private var ewma: Double?
        private var index = 0
        private var values: [Double] = []

        init(base: Base.AsyncIterator, target: Double, lambda: Double, controlLimitSigma: Double) {
            self.baseIterator = base
            self.target = target
            self.lambda = lambda
            self.controlLimitSigma = controlLimitSigma
        }

        public mutating func next() async throws -> EWMASignal? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            values.append(value)

            // Update EWMA: Z_t = λ * X_t + (1-λ) * Z_{t-1}
            if let currentEWMA = ewma {
                ewma = lambda * value + (1.0 - lambda) * currentEWMA
            } else {
                ewma = value
            }

            // Estimate process standard deviation
            let sigma: Double
            if values.count >= 2 {
                let mean = values.reduce(0.0, +) / Double(values.count)
                let variance = values.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(values.count - 1)
                sigma = sqrt(variance)
            } else {
                sigma = 1.0  // Default until we have enough data
            }

            // Control limits: target ± L * σ * sqrt(λ/(2-λ))
            let limitFactor = controlLimitSigma * sigma * sqrt(lambda / (2.0 - lambda))
            let ucl = target + limitFactor
            let lcl = target - limitFactor

            let isOutOfControl = ewma! < lcl || ewma! > ucl

            let signal = EWMASignal(
                ewma: ewma!,
                upperControlLimit: ucl,
                lowerControlLimit: lcl,
                isOutOfControl: isOutOfControl,
                index: index
            )

            index += 1
            return signal
        }
    }
}

// MARK: - Outlier Detection

public struct AsyncOutlierDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = OutlierDetection
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let method: OutlierMethod
    private let window: Int

    init(base: Base, method: OutlierMethod, window: Int) {
        self.base = base
        self.method = method
        self.window = window
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), method: method, window: window)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let method: OutlierMethod
        private let window: Int
        private var buffer: [Double] = []
        private var index = 0

        init(base: Base.AsyncIterator, method: OutlierMethod, window: Int) {
            self.baseIterator = base
            self.method = method
            self.window = window
        }

        public mutating func next() async throws -> OutlierDetection? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            // Detect outlier using current buffer BEFORE adding new value
            // This prevents the outlier from contaminating the baseline statistics
            let detection: OutlierDetection

            switch method {
            case .zScore(let threshold):
                detection = detectWithZScore(value: value, threshold: threshold)
            case .iqr(let multiplier):
                detection = detectWithIQR(value: value, multiplier: multiplier)
            case .mad(let threshold):
                detection = detectWithMAD(value: value, threshold: threshold)
            }

            // Now add to buffer for future comparisons
            buffer.append(value)
            if buffer.count > window {
                buffer.removeFirst()
            }

            index += 1
            return detection
        }

        private func detectWithZScore(value: Double, threshold: Double) -> OutlierDetection {
            guard buffer.count >= 2 else {
                return OutlierDetection(value: value, score: 0.0, isOutlier: false, method: "z-score", index: index)
            }

            let mean = buffer.reduce(0.0, +) / Double(buffer.count)
            let variance = buffer.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(buffer.count - 1)
            let stdDev = sqrt(variance)

            let zScore = stdDev > 0 ? abs(value - mean) / stdDev : 0.0
            let isOutlier = zScore > threshold

            return OutlierDetection(value: value, score: zScore, isOutlier: isOutlier, method: "z-score", index: index)
        }

        private func detectWithIQR(value: Double, multiplier: Double) -> OutlierDetection {
            guard buffer.count >= 4 else {
                return OutlierDetection(value: value, score: 0.0, isOutlier: false, method: "iqr", index: index)
            }

            let sorted = buffer.sorted()
            let q1Index = sorted.count / 4
            let q3Index = 3 * sorted.count / 4
            let q1 = sorted[q1Index]
            let q3 = sorted[q3Index]
            let iqr = q3 - q1

            let lowerBound = q1 - multiplier * iqr
            let upperBound = q3 + multiplier * iqr

            let isOutlier = value < lowerBound || value > upperBound
            let score = iqr > 0 ? Swift.min(abs(value - q1), abs(value - q3)) / iqr : 0.0

            return OutlierDetection(value: value, score: score, isOutlier: isOutlier, method: "iqr", index: index)
        }

        private func detectWithMAD(value: Double, threshold: Double) -> OutlierDetection {
            guard buffer.count >= 2 else {
                return OutlierDetection(value: value, score: 0.0, isOutlier: false, method: "mad", index: index)
            }

            // Median Absolute Deviation
            let median = calculateMedian(buffer)
            let deviations = buffer.map { abs($0 - median) }
            let mad = calculateMedian(deviations)

            // Modified Z-score: M_i = 0.6745 * (x_i - median) / MAD
            let modifiedZScore = mad > 0 ? 0.6745 * abs(value - median) / mad : 0.0
            let isOutlier = modifiedZScore > threshold

            return OutlierDetection(value: value, score: modifiedZScore, isOutlier: isOutlier, method: "mad", index: index)
        }

        private func calculateMedian(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            let count = sorted.count
            if count == 0 { return 0.0 }
            if count % 2 == 0 {
                return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
            } else {
                return sorted[count / 2]
            }
        }
    }
}

// MARK: - Binary Segmentation Breakpoint Detection

public struct AsyncBreakpointDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = Breakpoint
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let method: BreakpointMethod

    init(base: Base, method: BreakpointMethod) {
        self.base = base
        self.method = method
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, method: method)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private let base: Base
        private let method: BreakpointMethod
        private var allValues: [Double] = []
        private var hasCollected = false
        private var breakpoints: [Breakpoint] = []
        private var currentIndex = 0

        init(base: Base, method: BreakpointMethod) {
            self.base = base
            self.method = method
        }

        public mutating func next() async throws -> Breakpoint? {
            // First, collect all values from the stream
            if !hasCollected {
                var iterator = base.makeAsyncIterator()
                while let value = try await iterator.next() {
                    allValues.append(value)
                }
                hasCollected = true

                // Perform binary segmentation
                switch method {
                case .binarySegmentation(let minSegmentSize, let maxBreakpoints):
                    breakpoints = performBinarySegmentation(
                        values: allValues,
                        minSegmentSize: minSegmentSize,
                        maxBreakpoints: maxBreakpoints
                    )
                }
            }

            // Return breakpoints one at a time
            guard currentIndex < breakpoints.count else {
                return nil
            }

            let breakpoint = breakpoints[currentIndex]
            currentIndex += 1
            return breakpoint
        }

        private func performBinarySegmentation(values: [Double], minSegmentSize: Int, maxBreakpoints: Int) -> [Breakpoint] {
            guard values.count >= 2 * minSegmentSize else {
                return []
            }

            var detectedBreakpoints: [Breakpoint] = []
            var segments = [(start: 0, end: values.count)]

            while detectedBreakpoints.count < maxBreakpoints && !segments.isEmpty {
                var bestBreakpoint: Breakpoint?
                var bestSegmentIndex: Int?

                // Find the best breakpoint among all current segments
                for (segIndex, segment) in segments.enumerated() {
                    if let bp = findBestBreakpoint(in: values, start: segment.start, end: segment.end, minSize: minSegmentSize) {
                        if bestBreakpoint == nil || bp.costReduction > bestBreakpoint!.costReduction {
                            bestBreakpoint = bp
                            bestSegmentIndex = segIndex
                        }
                    }
                }

                guard let breakpoint = bestBreakpoint, let segIndex = bestSegmentIndex else {
                    break  // No more significant breakpoints found
                }

                // Only add if cost reduction is significant
                if breakpoint.costReduction > 0.1 {
                    detectedBreakpoints.append(breakpoint)

                    // Split the segment
                    let segment = segments[segIndex]
                    segments.remove(at: segIndex)
                    segments.append((start: segment.start, end: breakpoint.index))
                    segments.append((start: breakpoint.index, end: segment.end))
                } else {
                    break
                }
            }

            return detectedBreakpoints.sorted { $0.index < $1.index }
        }

        private func findBestBreakpoint(in values: [Double], start: Int, end: Int, minSize: Int) -> Breakpoint? {
            guard end - start >= 2 * minSize else {
                return nil
            }

            let segment = Array(values[start..<end])
            let segmentMean = segment.reduce(0.0, +) / Double(segment.count)
            let totalCost = segment.map { pow($0 - segmentMean, 2) }.reduce(0.0, +)

            var bestBreakpoint: Breakpoint?
            var maxCostReduction = 0.0

            for i in (start + minSize)..<(end - minSize) {
                let left = Array(values[start..<i])
                let right = Array(values[i..<end])

                let leftMean = left.reduce(0.0, +) / Double(left.count)
                let rightMean = right.reduce(0.0, +) / Double(right.count)

                let leftCost = left.map { pow($0 - leftMean, 2) }.reduce(0.0, +)
                let rightCost = right.map { pow($0 - rightMean, 2) }.reduce(0.0, +)
                let splitCost = leftCost + rightCost

                let costReduction = totalCost - splitCost

                if costReduction > maxCostReduction {
                    maxCostReduction = costReduction
                    bestBreakpoint = Breakpoint(
                        index: i,
                        costReduction: costReduction,
                        leftMean: leftMean,
                        rightMean: rightMean
                    )
                }
            }

            return bestBreakpoint
        }
    }
}

// MARK: - Seasonal Anomaly Detection

public struct AsyncSeasonalAnomalySequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = SeasonalAnomaly
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let period: Int
    private let threshold: Double

    init(base: Base, period: Int, threshold: Double) {
        self.base = base
        self.period = period
        self.threshold = threshold
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), period: period, threshold: threshold)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let period: Int
        private let threshold: Double
        private var buffer: [Double] = []
        private var seasonalMeans: [Double] = []
        private var seasonalStdDevs: [Double] = []
        private var index = 0

        init(base: Base.AsyncIterator, period: Int, threshold: Double) {
            self.baseIterator = base
            self.period = period
            self.threshold = threshold
            self.seasonalMeans = Array(repeating: 0.0, count: period)
            self.seasonalStdDevs = Array(repeating: 0.0, count: period)
        }

        public mutating func next() async throws -> SeasonalAnomaly? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            let seasonIndex = index % period
            let anomaly: SeasonalAnomaly

            // Need at least 2 complete periods to detect anomalies
            if buffer.count >= 2 * period {
                // Update seasonal statistics from existing buffer (before adding new value)
                updateSeasonalStatistics()

                // Check for anomaly using statistics calculated from existing buffer
                let expectedValue = seasonalMeans[seasonIndex]
                let stdDev = seasonalStdDevs[seasonIndex]

                // Handle case where seasonal values are perfectly constant (stdDev = 0)
                let deviation: Double
                let isAnomaly: Bool
                if stdDev > 0 {
                    deviation = abs(value - expectedValue) / stdDev
                    isAnomaly = deviation > threshold
                } else {
                    // If stdDev is 0, any difference from expected value is an anomaly
                    deviation = abs(value - expectedValue)
                    isAnomaly = deviation > 0.1  // Small tolerance for floating point
                }

                anomaly = SeasonalAnomaly(
                    value: value,
                    expectedValue: expectedValue,
                    deviation: deviation,
                    isAnomaly: isAnomaly,
                    index: index
                )
            } else {
                // Not enough data yet
                anomaly = SeasonalAnomaly(
                    value: value,
                    expectedValue: value,
                    deviation: 0.0,
                    isAnomaly: false,
                    index: index
                )
            }

            // Add to buffer after detection
            buffer.append(value)
            index += 1
            return anomaly
        }

        private mutating func updateSeasonalStatistics() {
            // Calculate mean and std dev for each position in the period
            for seasonIndex in 0..<period {
                var seasonalValues: [Double] = []
                var idx = seasonIndex
                while idx < buffer.count {
                    seasonalValues.append(buffer[idx])
                    idx += period
                }

                if !seasonalValues.isEmpty {
                    let mean = seasonalValues.reduce(0.0, +) / Double(seasonalValues.count)
                    seasonalMeans[seasonIndex] = mean

                    if seasonalValues.count >= 2 {
                        let variance = seasonalValues.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(seasonalValues.count - 1)
                        seasonalStdDevs[seasonIndex] = sqrt(variance)
                    }
                }
            }
        }
    }
}

// MARK: - Composite Anomaly Score

public struct AsyncCompositeAnomalySequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    public typealias Element = CompositeAnomalyScore
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int
    private let methods: [AnomalyMethod]

    init(base: Base, window: Int, methods: [AnomalyMethod]) {
        self.base = base
        self.window = window
        self.methods = methods
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window, methods: methods)
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let window: Int
        private let methods: [AnomalyMethod]
        private var buffer: [Double] = []
        private var index = 0

        init(base: Base.AsyncIterator, window: Int, methods: [AnomalyMethod]) {
            self.baseIterator = base
            self.window = window
            self.methods = methods
        }

        public mutating func next() async throws -> CompositeAnomalyScore? {
            guard let value = try await baseIterator.next() else {
                return nil
            }

            buffer.append(value)
            if buffer.count > window {
                buffer.removeFirst()
            }

            var methodScores: [String: Double] = [:]
            var totalScore = 0.0

            for method in methods {
                let score: Double
                switch method {
                case .zScore:
                    score = calculateZScore(value: value)
                    methodScores["z-score"] = score
                case .iqr:
                    score = calculateIQRScore(value: value)
                    methodScores["iqr"] = score
                case .mad:
                    score = calculateMADScore(value: value)
                    methodScores["mad"] = score
                }
                totalScore += score
            }

            // Normalize composite score to 0-1 range
            let compositeScore = methods.isEmpty ? 0.0 : Swift.min(1.0, totalScore / Double(methods.count) / 3.0)

            let result = CompositeAnomalyScore(
                value: value,
                score: compositeScore,
                methodScores: methodScores,
                index: index
            )

            index += 1
            return result
        }

        private func calculateZScore(value: Double) -> Double {
            guard buffer.count >= 2 else { return 0.0 }
            let mean = buffer.reduce(0.0, +) / Double(buffer.count)
            let variance = buffer.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(buffer.count - 1)
            let stdDev = sqrt(variance)
            return stdDev > 0 ? abs(value - mean) / stdDev : 0.0
        }

        private func calculateIQRScore(value: Double) -> Double {
            guard buffer.count >= 4 else { return 0.0 }
            let sorted = buffer.sorted()
            let q1 = sorted[sorted.count / 4]
            let q3 = sorted[3 * sorted.count / 4]
            let iqr = q3 - q1
            return iqr > 0 ? Swift.min(abs(value - q1), abs(value - q3)) / iqr : 0.0
        }

        private func calculateMADScore(value: Double) -> Double {
            guard buffer.count >= 2 else { return 0.0 }
            let median = calculateMedian(buffer)
            let deviations = buffer.map { abs($0 - median) }
            let mad = calculateMedian(deviations)
            return mad > 0 ? 0.6745 * abs(value - median) / mad : 0.0
        }

        private func calculateMedian(_ values: [Double]) -> Double {
            let sorted = values.sorted()
            let count = sorted.count
            if count == 0 { return 0.0 }
            if count % 2 == 0 {
                return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
            } else {
                return sorted[count / 2]
            }
        }
    }
}
