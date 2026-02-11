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

/// CUSUM (Cumulative Sum) control chart signal for detecting mean shifts.
///
/// CUSUM is a statistical process control method that detects small shifts in the process mean
/// by accumulating deviations from a target. More sensitive to persistent shifts than simple
/// threshold-based methods. Widely used in quality control and real-time monitoring.
///
/// ## Example
/// ```swift
/// let signal = CUSUMSignal(
///     direction: .upward,
///     cumulativeSum: 15.3,
///     isSignaling: true,
///     index: 42
/// )
/// if signal.isSignaling {
///     print("Process mean has shifted \(signal.direction) at position \(signal.index)")
/// }
/// ```
public struct CUSUMSignal {
    /// The direction of the detected shift (upward, downward, or stable).
    public let direction: CUSUMDirection

    /// The cumulative sum of deviations from the target.
    ///
    /// Positive values indicate upward drift, negative values indicate downward drift.
    /// Magnitude represents the strength of the signal.
    public let cumulativeSum: Double

    /// Whether the signal exceeds the control limit (true = out of control).
    ///
    /// When true, indicates a significant shift in the process mean requiring investigation.
    public let isSignaling: Bool

    /// The position in the stream where this signal was generated.
    public let index: Int

    /// Creates a CUSUM signal.
    ///
    /// - Parameters:
    ///   - direction: The shift direction detected.
    ///   - cumulativeSum: The accumulated sum of deviations.
    ///   - isSignaling: Whether the signal exceeds control limits.
    ///   - index: The stream position.
    public init(direction: CUSUMDirection, cumulativeSum: Double, isSignaling: Bool, index: Int) {
        self.direction = direction
        self.cumulativeSum = cumulativeSum
        self.isSignaling = isSignaling
        self.index = index
    }
}

/// EWMA (Exponentially Weighted Moving Average) control chart signal.
///
/// EWMA is a statistical process control method that detects small shifts by weighting
/// recent observations more heavily. More responsive than traditional control charts while
/// still filtering noise. Particularly effective for autocorrelated data.
///
/// ## Example
/// ```swift
/// let signal = EWMASignal(
///     ewma: 102.5,
///     upperControlLimit: 105.0,
///     lowerControlLimit: 95.0,
///     isOutOfControl: false,
///     index: 50
/// )
/// if signal.isOutOfControl {
///     print("Process out of control at \(signal.index)")
/// }
/// ```
public struct EWMASignal {
    /// The current exponentially weighted moving average value.
    public let ewma: Double

    /// The upper control limit (UCL) for detecting high anomalies.
    ///
    /// When EWMA exceeds this limit, the process is out of control on the high side.
    public let upperControlLimit: Double

    /// The lower control limit (LCL) for detecting low anomalies.
    ///
    /// When EWMA falls below this limit, the process is out of control on the low side.
    public let lowerControlLimit: Double

    /// Whether the EWMA is outside control limits (true = anomaly detected).
    public let isOutOfControl: Bool

    /// The position in the stream where this signal was generated.
    public let index: Int

    /// Creates an EWMA signal.
    ///
    /// - Parameters:
    ///   - ewma: The exponentially weighted moving average value.
    ///   - upperControlLimit: The upper control limit.
    ///   - lowerControlLimit: The lower control limit.
    ///   - isOutOfControl: Whether the EWMA is outside control limits.
    ///   - index: The stream position.
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

/// Outlier detection result identifying extreme values in streaming data.
///
/// Detects values that deviate significantly from the typical pattern using statistical
/// methods like z-score, IQR, or MAD. Each method has different sensitivity and robustness
/// characteristics suitable for different data distributions.
///
/// ## Example
/// ```swift
/// let detection = OutlierDetection(
///     value: 250.0,
///     score: 3.5,
///     isOutlier: true,
///     method: "z-score",
///     index: 127
/// )
/// if detection.isOutlier {
///     print("Outlier \(detection.value) detected using \(detection.method) (score: \(detection.score))")
/// }
/// ```
public struct OutlierDetection {
    /// The observed value being evaluated.
    public let value: Double

    /// The anomaly score computed by the detection method.
    ///
    /// Higher scores indicate more extreme outliers. Interpretation depends on the method:
    /// - Z-score: Number of standard deviations from mean
    /// - IQR: Distance beyond IQR bounds
    /// - MAD: Median absolute deviations from median
    public let score: Double

    /// Whether this value is classified as an outlier.
    public let isOutlier: Bool

    /// The detection method used (e.g., "z-score", "iqr", "mad").
    public let method: String

    /// The position in the stream where this value occurred.
    public let index: Int

    /// Creates an outlier detection result.
    ///
    /// - Parameters:
    ///   - value: The observed value.
    ///   - score: The anomaly score.
    ///   - isOutlier: Whether classified as an outlier.
    ///   - method: The detection method name.
    ///   - index: The stream position.
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

/// Detected breakpoint in time series segmentation.
///
/// Identifies locations where the time series characteristics change significantly, such as
/// abrupt shifts in mean, variance, or trend. Used for segmenting data into homogeneous
/// intervals for analysis or modeling different regimes separately.
///
/// ## Example
/// ```swift
/// let breakpoint = Breakpoint(
///     index: 150,
///     costReduction: 45.2,
///     leftMean: 100.5,
///     rightMean: 125.3
/// )
/// print("Mean shifted from \(breakpoint.leftMean) to \(breakpoint.rightMean) at index \(breakpoint.index)")
/// ```
public struct Breakpoint {
    /// The position in the stream where the breakpoint occurs.
    ///
    /// Values before this index belong to one segment, values at or after belong to the next.
    public let index: Int

    /// The reduction in segmentation cost achieved by this breakpoint.
    ///
    /// Higher values indicate stronger evidence for the breakpoint. Measures how much
    /// better the data is explained by splitting at this location.
    public let costReduction: Double

    /// The mean of the segment to the left of the breakpoint.
    public let leftMean: Double

    /// The mean of the segment to the right of the breakpoint.
    public let rightMean: Double

    /// Creates a breakpoint detection result.
    ///
    /// - Parameters:
    ///   - index: The breakpoint position.
    ///   - costReduction: The cost reduction from splitting here.
    ///   - leftMean: Mean of the left segment.
    ///   - rightMean: Mean of the right segment.
    public init(index: Int, costReduction: Double, leftMean: Double, rightMean: Double) {
        self.index = index
        self.costReduction = costReduction
        self.leftMean = leftMean
        self.rightMean = rightMean
    }
}

/// Seasonal anomaly detection result for data with repeating patterns.
///
/// Identifies values that deviate from expected seasonal patterns by comparing observed
/// values against seasonal baselines. Particularly useful for detecting anomalies in
/// business metrics with daily, weekly, or monthly cycles (e.g., retail sales, web traffic).
///
/// ## Example
/// ```swift
/// let anomaly = SeasonalAnomaly(
///     value: 150.0,
///     expectedValue: 100.0,
///     deviation: 50.0,
///     isAnomaly: true,
///     index: 42
/// )
/// if anomaly.isAnomaly {
///     print("Seasonal anomaly: observed \(anomaly.value), expected \(anomaly.expectedValue)")
/// }
/// ```
public struct SeasonalAnomaly {
    /// The observed value being evaluated.
    public let value: Double

    /// The expected value based on seasonal patterns.
    ///
    /// Computed from historical data for this position in the seasonal cycle.
    public let expectedValue: Double

    /// The deviation from expected (value - expectedValue).
    ///
    /// Positive deviations indicate values above expected, negative indicate below expected.
    public let deviation: Double

    /// Whether this value is classified as a seasonal anomaly.
    ///
    /// True when deviation exceeds threshold relative to typical seasonal variation.
    public let isAnomaly: Bool

    /// The position in the stream where this value occurred.
    public let index: Int

    /// Creates a seasonal anomaly detection result.
    ///
    /// - Parameters:
    ///   - value: The observed value.
    ///   - expectedValue: The seasonally-adjusted expected value.
    ///   - deviation: The difference from expected.
    ///   - isAnomaly: Whether classified as anomalous.
    ///   - index: The stream position.
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

/// Composite anomaly score combining multiple detection methods.
///
/// Aggregates results from multiple anomaly detection techniques (z-score, IQR, MAD) into
/// a single consolidated score. Provides more robust detection by reducing false positives
/// from any single method. The composite score indicates overall anomaly strength.
///
/// ## Example
/// ```swift
/// let composite = CompositeAnomalyScore(
///     value: 150.0,
///     score: 0.85,
///     methodScores: ["z-score": 0.9, "iqr": 0.8, "mad": 0.85],
///     index: 42
/// )
/// if composite.score > 0.8 {
///     print("Strong anomaly detected (score: \(composite.score))")
/// }
/// ```
public struct CompositeAnomalyScore {
    /// The observed value being evaluated.
    public let value: Double

    /// The aggregated anomaly score from all methods (0.0 to 1.0).
    ///
    /// Higher scores indicate stronger evidence of anomaly. Typically computed as
    /// the average or weighted average of individual method scores, normalized to 0-1 range.
    public let score: Double

    /// Individual anomaly scores from each detection method.
    ///
    /// Maps method names (e.g., "z-score", "iqr", "mad") to their respective scores,
    /// enabling detailed analysis of which methods flagged the anomaly.
    public let methodScores: [String: Double]

    /// The position in the stream where this value occurred.
    public let index: Int

    /// Creates a composite anomaly score.
    ///
    /// - Parameters:
    ///   - value: The observed value.
    ///   - score: The aggregated anomaly score (0 to 1).
    ///   - methodScores: Individual scores from each method.
    ///   - index: The stream position.
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

/// AsyncSequence that applies CUSUM control charting for mean shift detection.
///
/// CUSUM (Cumulative Sum) monitors cumulative deviations from a target value to detect
/// persistent shifts in the process mean. More sensitive to small, sustained shifts than
/// simple threshold methods. Uses tabular CUSUM with separate cumulative sums for upward
/// and downward shifts.
///
/// ## Example
/// ```swift
/// let stream = createProcessDataStream()
/// for try await signal in stream.cusum(target: 100.0, drift: 1.0, threshold: 5.0) {
///     if signal.isSignaling {
///         print("Process shifted \(signal.direction) at position \(signal.index)")
///     }
/// }
/// ```
///
/// ## Parameter Guidance
/// - **target**: The target mean (centerline)
/// - **drift**: Half the shift size you want to detect (typically 0.5-1.0 σ)
/// - **threshold**: Decision threshold, typically 4-5 for good detection/false alarm balance
public struct AsyncCUSUMSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields CUSUM signals indicating shift detection.
    public typealias Element = CUSUMSignal

    /// The async iterator type for this sequence.
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

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields CUSUM signals.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), target: target, drift: drift, threshold: threshold)
    }

    /// Iterator that computes CUSUM statistics asynchronously.
    public struct Iterator: AsyncIteratorProtocol {
        private var baseIterator: Base.AsyncIterator
        private let target: Double
        private let drift: Double
        private let threshold: Double
        private var cPlusIndex: Double = 0.0
        private var cMinusIndex: Double = 0.0
        private var index = 0
		public var cPlusIndexValue: Double { cPlusIndex }
		public var cMinusIndexValue: Double { cMinusIndex }

        init(base: Base.AsyncIterator, target: Double, drift: Double, threshold: Double) {
            self.baseIterator = base
            self.target = target
            self.drift = drift
            self.threshold = threshold
        }

        /// Yields the next CUSUM signal after processing a value.
        ///
        /// - Returns: A CUSUM signal with current cumulative sums and shift detection status.
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

/// AsyncSequence that applies EWMA control charting for anomaly detection.
///
/// EWMA (Exponentially Weighted Moving Average) provides a smoothed running average that
/// weighs recent observations more heavily. Control limits are computed based on the EWMA
/// distribution. More responsive to small shifts than traditional control charts while
/// filtering random noise. Particularly effective for autocorrelated processes.
///
/// Formula: Z(t) = λ × X(t) + (1-λ) × Z(t-1)
///
/// ## Example
/// ```swift
/// let stream = createProcessDataStream()
/// for try await signal in stream.ewma(target: 100.0, lambda: 0.2, controlLimitSigma: 3.0) {
///     if signal.isOutOfControl {
///         print("Out of control at \(signal.index): EWMA=\(signal.ewma)")
///     }
/// }
/// ```
///
/// ## Parameter Guidance
/// - **target**: The target mean (centerline)
/// - **lambda**: Smoothing parameter (0.2-0.3 typical for small shifts, 0.4 for responsiveness)
/// - **controlLimitSigma**: Number of standard deviations for control limits (typically 3)
public struct AsyncEWMASequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields EWMA signals indicating process control status.
    public typealias Element = EWMASignal

    /// The async iterator type for this sequence.
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

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields EWMA signals.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), target: target, lambda: lambda, controlLimitSigma: controlLimitSigma)
    }

    /// Iterator for the EWMA anomaly detection sequence.
    ///
    /// Maintains EWMA state and computes control limits at each step. The iterator
    /// tracks all observed values to estimate process variability, which is used
    /// to compute control limits that tighten as more data is collected.
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

        /// Advances to the next EWMA signal in the sequence.
        ///
        /// Computes the EWMA statistic using the formula Z(t) = λ × X(t) + (1-λ) × Z(t-1),
        /// estimates process standard deviation from observed values, and computes control
        /// limits based on the EWMA distribution: target ± L × σ × √(λ/(2-λ)).
        ///
        /// - Returns: The next EWMA signal, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

/// AsyncSequence that detects outliers using statistical methods.
///
/// Outlier detection identifies individual observations that deviate significantly from the
/// expected pattern. Unlike control charting (CUSUM/EWMA) which tracks process shifts, outlier
/// detection focuses on identifying individual anomalous points. Supports multiple detection
/// methods (z-score, IQR, MAD) that can be selected based on data characteristics.
///
/// The detector uses a rolling window to establish baseline statistics, then compares each
/// new value against those statistics. Critically, the new value is tested **before** being
/// added to the baseline window, preventing contamination of statistics.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([98, 102, 99, 101, 150, 100])
/// for try await detection in stream.detectOutliers(method: .zScore(threshold: 2.0), window: 10) {
///     if detection.isOutlier {
///         print("Outlier detected at \(detection.index): \(detection.value)")
///     }
/// }
/// ```
///
/// ## Parameter Guidance
/// - **method**: Detection method (z-score for normal data, IQR for skewed, MAD for robust)
/// - **window**: Rolling window size (20-50 typical for stable baselines)
///
/// ## Method Selection
/// - **Z-Score**: Best for normally distributed data, sensitive to extreme values
/// - **IQR**: Robust to outliers, works well with skewed distributions
/// - **MAD**: Most robust, resistant to extreme outliers in baseline
///
/// - SeeAlso: ``OutlierDetection``, ``OutlierMethod``
public struct AsyncOutlierDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields outlier detection results.
    public typealias Element = OutlierDetection

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let method: OutlierMethod
    private let window: Int

    init(base: Base, method: OutlierMethod, window: Int) {
        self.base = base
        self.method = method
        self.window = window
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields outlier detection results.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), method: method, window: window)
    }

    /// Iterator for the outlier detection sequence.
    ///
    /// Maintains a rolling window of historical values for computing baseline statistics.
    /// Each new value is tested against the current baseline **before** being added to
    /// the window, ensuring outliers don't contaminate the reference statistics.
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

        /// Advances to the next outlier detection result.
        ///
        /// Tests the incoming value against baseline statistics computed from the buffer,
        /// then adds the value to the buffer for future comparisons. This ordering prevents
        /// outliers from affecting their own detection.
        ///
        /// - Returns: The next outlier detection result, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

/// AsyncSequence that detects structural breaks (change points) in time series data.
///
/// Breakpoint detection identifies points where the statistical properties of the series
/// change abruptly, such as shifts in mean level. This is useful for detecting regime
/// changes, process modifications, or external interventions. Uses binary segmentation,
/// an iterative algorithm that recursively splits the series at points of maximum cost
/// reduction.
///
/// **Note**: This iterator collects all values from the base sequence before performing
/// detection, then yields the discovered breakpoints. It is not truly "streaming" but
/// provides an async interface for consistency.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([100, 102, 98, 101, 150, 152, 148, 151])
/// for try await breakpoint in stream.detectBreakpoints(method: .binarySegmentation(minSegmentSize: 2, maxBreakpoints: 5)) {
///     print("Breakpoint at index \(breakpoint.index): \(breakpoint.leftMean) → \(breakpoint.rightMean)")
/// }
/// ```
///
/// ## Parameter Guidance
/// - **minSegmentSize**: Minimum observations per segment (5-10 typical to ensure reliable statistics)
/// - **maxBreakpoints**: Maximum number of breaks to detect (prevents over-segmentation)
///
/// ## Algorithm
/// Binary segmentation works by:
/// 1. Finding the split point that minimizes total variance
/// 2. Recursively splitting the resulting segments
/// 3. Stopping when no significant improvements are found
///
/// - SeeAlso: ``Breakpoint``, ``BreakpointMethod``
public struct AsyncBreakpointDetectionSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields detected breakpoints.
    public typealias Element = Breakpoint

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let method: BreakpointMethod

    init(base: Base, method: BreakpointMethod) {
        self.base = base
        self.method = method
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields detected breakpoints.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base, method: method)
    }

    /// Iterator for the breakpoint detection sequence.
    ///
    /// Collects all values from the base sequence on first invocation, performs binary
    /// segmentation to find change points, then yields breakpoints one at a time. This
    /// batch-collect-then-yield pattern is necessary because binary segmentation requires
    /// the complete series to evaluate split points.
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

        /// Advances to the next detected breakpoint.
        ///
        /// On first call, collects all values from the base sequence and runs binary
        /// segmentation to identify change points. Subsequent calls yield the detected
        /// breakpoints in index order.
        ///
        /// - Returns: The next breakpoint, or `nil` if all breakpoints have been yielded.
        /// - Throws: Rethrows any error from the base sequence.
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

/// AsyncSequence that detects anomalies in seasonal (periodic) time series data.
///
/// Seasonal anomaly detection identifies values that deviate from their expected seasonal
/// pattern. The detector learns separate baseline statistics (mean and standard deviation)
/// for each position in the seasonal cycle, then flags values that deviate significantly
/// from their position-specific baseline.
///
/// This is particularly useful for data with regular cyclical patterns (hourly, daily,
/// weekly, monthly, etc.) where the expected value at any time depends on the position
/// within the cycle rather than just recent history.
///
/// ## Example
/// ```swift
/// // Detect weekly anomalies (period=7 for days of week)
/// let stream = AsyncValueStream([100, 80, 85, 90, 95, 120, 110,  // Week 1
///                                105, 82, 87, 88, 92, 150, 115]) // Week 2 (Saturday anomaly)
/// for try await anomaly in stream.detectSeasonalAnomalies(period: 7, threshold: 2.0) {
///     if anomaly.isAnomaly {
///         print("Seasonal anomaly at \(anomaly.index): expected \(anomaly.expectedValue), got \(anomaly.value)")
///     }
/// }
/// ```
///
/// ## Parameter Guidance
/// - **period**: Length of the seasonal cycle (7 for weekly, 12 for monthly, 24 for hourly daily patterns)
/// - **threshold**: Deviation threshold in standard deviations (2.0-3.0 typical)
///
/// ## Requirements
/// - Needs at least 2 complete periods (2×period observations) to begin detecting anomalies
/// - Works best with stable seasonal patterns; adapts as more cycles are observed
///
/// - SeeAlso: ``SeasonalAnomaly``
public struct AsyncSeasonalAnomalySequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields seasonal anomaly detection results.
    public typealias Element = SeasonalAnomaly

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let period: Int
    private let threshold: Double

    init(base: Base, period: Int, threshold: Double) {
        self.base = base
        self.period = period
        self.threshold = threshold
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields seasonal anomaly detection results.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), period: period, threshold: threshold)
    }

    /// Iterator for the seasonal anomaly detection sequence.
    ///
    /// Maintains position-specific statistics (mean and standard deviation) for each
    /// position in the seasonal cycle. Updates these statistics incrementally as more
    /// complete cycles are observed, allowing the detector to adapt to evolving patterns.
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

        /// Advances to the next seasonal anomaly detection result.
        ///
        /// Updates seasonal statistics from historical buffer, tests the new value against
        /// its position-specific baseline, then adds the value to the buffer. Requires at
        /// least 2 complete periods before flagging anomalies.
        ///
        /// - Returns: The next seasonal anomaly result, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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

/// AsyncSequence that computes composite anomaly scores by combining multiple detection methods.
///
/// Composite anomaly detection aggregates scores from multiple methods (z-score, IQR, MAD)
/// to provide a more robust anomaly score than any single method alone. This ensemble approach
/// reduces false positives by requiring consensus across methods, while still catching
/// anomalies that any individual method detects.
///
/// Each method contributes a normalized score, which are averaged and scaled to produce a
/// composite score in the range [0, 1], where higher scores indicate stronger evidence of
/// anomaly. Individual method scores are also provided for diagnostic purposes.
///
/// ## Example
/// ```swift
/// let stream = AsyncValueStream([98, 102, 99, 101, 200, 100])
/// for try await composite in stream.compositeAnomalyScore(window: 10, methods: [.zScore, .iqr, .mad]) {
///     print("Composite score: \(composite.score)")
///     print("Method scores: \(composite.methodScores)")
///     if composite.score > 0.7 {
///         print("Strong anomaly consensus!")
///     }
/// }
/// ```
///
/// ## Parameter Guidance
/// - **window**: Rolling window size for baseline (20-50 typical)
/// - **methods**: Detection methods to combine (use all 3 for maximum robustness)
///
/// ## Use Cases
/// - High-stakes anomaly detection where false positives are costly
/// - Data with unknown distribution characteristics
/// - Situations requiring explainable anomaly scores
///
/// - SeeAlso: ``CompositeAnomalyScore``, ``AnomalyMethod``
public struct AsyncCompositeAnomalySequence<Base: AsyncSequence>: AsyncSequence where Base.Element == Double {
    /// Yields composite anomaly scores.
    public typealias Element = CompositeAnomalyScore

    /// The async iterator type for this sequence.
    public typealias AsyncIterator = Iterator

    private let base: Base
    private let window: Int
    private let methods: [AnomalyMethod]

    init(base: Base, window: Int, methods: [AnomalyMethod]) {
        self.base = base
        self.window = window
        self.methods = methods
    }

    /// Creates the async iterator for this sequence.
    ///
    /// - Returns: An iterator that yields composite anomaly scores.
    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator(), window: window, methods: methods)
    }

    /// Iterator for the composite anomaly detection sequence.
    ///
    /// Maintains a rolling window for baseline statistics and computes scores from multiple
    /// detection methods. Averages the method scores and normalizes to [0, 1] range to
    /// produce the final composite score.
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

        /// Advances to the next composite anomaly score.
        ///
        /// Computes anomaly scores using each specified detection method, averages them,
        /// and normalizes to produce a composite score. Individual method scores are
        /// preserved for diagnostics and explainability.
        ///
        /// - Returns: The next composite anomaly score, or `nil` if the base sequence is exhausted.
        /// - Throws: Rethrows any error from the base sequence.
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
