//
//  AdaptiveProgress.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Foundation

// MARK: - Convergence Metrics

/// Metrics capturing the state of an optimization iteration
public struct ConvergenceMetrics: Sendable, Codable {
    /// Current iteration number
    public let iteration: Int

    /// Current objective function value
    public let objectiveValue: Double

    /// Norm of the gradient (if available)
    public let gradientNorm: Double

    /// Size of the step taken
    public let stepSize: Double

    /// Relative change from previous iteration
    public let relativeChange: Double

    /// Create convergence metrics for an optimization iteration.
    ///
    /// Captures the complete state of an optimizer at a particular iteration,
    /// enabling progress monitoring and convergence detection.
    ///
    /// ## Parameters
    /// - iteration: Current iteration number (0-indexed)
    /// - objectiveValue: Current value of the objective function being optimized
    /// - gradientNorm: L2 norm of the gradient (magnitude of steepest descent direction)
    /// - stepSize: Size of the step taken in this iteration
    /// - relativeChange: Relative change from previous iteration (|new - old| / |old|)
    ///
    /// ## Example
    /// ```swift
    /// let metrics = ConvergenceMetrics(
    ///     iteration: 100,
    ///     objectiveValue: 42.5,
    ///     gradientNorm: 0.0001,
    ///     stepSize: 0.01,
    ///     relativeChange: 0.00005
    /// )
    /// ```
    public init(
        iteration: Int,
        objectiveValue: Double,
        gradientNorm: Double,
        stepSize: Double,
        relativeChange: Double
    ) {
        self.iteration = iteration
        self.objectiveValue = objectiveValue
        self.gradientNorm = gradientNorm
        self.stepSize = stepSize
        self.relativeChange = relativeChange
    }

    /// Calculate improvement from a previous metrics
    public func improvementFrom(_ previous: ConvergenceMetrics) -> Double {
        guard previous.objectiveValue != 0 else { return 0 }
        return abs((previous.objectiveValue - objectiveValue) / previous.objectiveValue)
    }

    /// Check if metrics indicate stagnation
    public func isStagnant(threshold: Double) -> Bool {
        return gradientNorm < threshold && relativeChange < threshold
    }
}

// MARK: - Progress Strategy Protocol

/// Protocol defining when progress updates should be reported
public protocol ProgressStrategy: Sendable {
    /// Determine if progress should be reported for the given iteration
    mutating func shouldReport(iteration: Int) -> Bool

    /// Update strategy with convergence metrics
    mutating func update(with metrics: ConvergenceMetrics)
}

// MARK: - Fixed Interval Strategy

/// Reports progress at fixed iteration intervals
public struct FixedIntervalStrategy: ProgressStrategy {
    /// The fixed number of iterations between progress reports.
    ///
    /// Progress is reported every `interval` iterations (when iteration % interval == 0).
    public let interval: Int

    /// Create a fixed interval progress strategy.
    ///
    /// This is the simplest strategy - report every N iterations regardless of
    /// convergence rate or other metrics.
    ///
    /// - Parameter interval: Number of iterations between reports
    ///
    /// ## Example
    /// ```swift
    /// let strategy = FixedIntervalStrategy(interval: 100)
    /// // Reports at iterations: 0, 100, 200, 300, ...
    /// ```
    public init(interval: Int) {
        self.interval = interval
    }

    /// Check if progress should be reported for the current iteration.
    ///
    /// - Parameter iteration: Current iteration number
    /// - Returns: True if iteration is a multiple of the interval
    public func shouldReport(iteration: Int) -> Bool {
        return iteration % interval == 0
    }

    /// Update strategy with convergence metrics.
    ///
    /// Fixed interval strategy doesn't adapt, so this does nothing.
    ///
    /// - Parameter metrics: Metrics from the current iteration (unused)
    public mutating func update(with metrics: ConvergenceMetrics) {
        // Fixed strategy doesn't adapt
    }
}

// MARK: - Exponential Backoff Strategy

/// Reports progress with exponentially increasing intervals
public struct ExponentialBackoffStrategy: ProgressStrategy {
    /// Initial reporting interval (first report after this many iterations).
    ///
    /// The first report happens at iteration 0, then after `initialInterval` iterations.
    public let initialInterval: Int

    /// Maximum reporting interval (caps exponential growth).
    ///
    /// Even as intervals grow exponentially, they won't exceed this limit.
    public let maxInterval: Int

    /// Factor by which interval grows after each report.
    ///
    /// Default is 2.0 (doubling). Values > 1 cause exponential growth in intervals.
    /// Examples: 1.5 (50% growth), 2.0 (doubling), 3.0 (tripling).
    public let backoffFactor: Double

    private var currentInterval: Int
    private var nextReportIteration: Int

    /// Create an exponential backoff progress strategy.
    ///
    /// This strategy starts with frequent reports and exponentially decreases
    /// reporting frequency over time. Useful for long-running optimizations where
    /// early progress is more interesting than later incremental improvements.
    ///
    /// ## Parameters
    /// - initialInterval: Starting interval between reports
    /// - maxInterval: Maximum interval (caps growth)
    /// - backoffFactor: Multiplier for interval growth (default: 2.0)
    ///
    /// ## Example
    /// ```swift
    /// var strategy = ExponentialBackoffStrategy(
    ///     initialInterval: 10,    // Report every 10 iterations initially
    ///     maxInterval: 1000,      // Cap at every 1000 iterations
    ///     backoffFactor: 2.0      // Double interval each time (10, 20, 40, 80, ...)
    /// )
    /// ```
    ///
    /// ## Interval Sequence
    /// With initialInterval=10 and backoffFactor=2.0:
    /// - Report at iterations: 0, 10, 30, 70, 150, 310, 630, ...
    /// - Intervals: 10, 20, 40, 80, 160, 320, 640, ... (until maxInterval)
    public init(
        initialInterval: Int,
        maxInterval: Int,
        backoffFactor: Double = 2.0
    ) {
        self.initialInterval = initialInterval
        self.maxInterval = maxInterval
        self.backoffFactor = backoffFactor
        self.currentInterval = initialInterval
        self.nextReportIteration = 0  // Report at iteration 0
    }

    /// Check if progress should be reported for the current iteration.
    ///
    /// Reports at exponentially spaced intervals, automatically growing
    /// the interval after each report.
    ///
    /// - Parameter iteration: Current iteration number
    /// - Returns: True if progress should be reported
    public mutating func shouldReport(iteration: Int) -> Bool {
        if iteration >= nextReportIteration {
            // Schedule next report using current interval
            nextReportIteration = iteration + currentInterval

            // Increase interval for future reports
            let newInterval = Int(Double(currentInterval) * backoffFactor)
            currentInterval = min(newInterval, maxInterval)

            return true
        }
        return false
    }

    /// Update strategy with convergence metrics.
    ///
    /// Exponential backoff doesn't use metrics - it follows a fixed schedule.
    ///
    /// - Parameter metrics: Metrics from the current iteration (unused)
    public mutating func update(with metrics: ConvergenceMetrics) {
        // Exponential backoff doesn't use metrics
    }
}

// MARK: - Convergence-Based Strategy

/// Adapts reporting frequency based on convergence rate
public struct ConvergenceBasedStrategy: ProgressStrategy {
    /// Minimum reporting interval (fastest reporting frequency).
    ///
    /// When convergence is fast, reporting interval decreases toward this limit.
    public let minInterval: Int

    /// Maximum reporting interval (slowest reporting frequency).
    ///
    /// When convergence is slow, reporting interval increases toward this limit.
    public let maxInterval: Int

    /// Improvement threshold for determining convergence speed.
    ///
    /// When average improvement exceeds this threshold, convergence is considered "fast"
    /// and reporting becomes more frequent.
    public let convergenceThreshold: Double

    private var currentInterval: Int
    private var lastReportedIteration: Int
    private var recentMetrics: [ConvergenceMetrics]
    private let metricsWindowSize: Int

    /// Create a convergence-based adaptive progress strategy.
    ///
    /// This strategy automatically adjusts reporting frequency based on how fast
    /// the optimizer is converging. Fast convergence triggers more frequent updates
    /// so you don't miss important progress.
    ///
    /// ## Parameters
    /// - minInterval: Fastest reporting (e.g., every iteration = 1)
    /// - maxInterval: Slowest reporting (e.g., every 100 iterations)
    /// - convergenceThreshold: Improvement threshold (e.g., 0.01 = 1%)
    /// - metricsWindowSize: Number of recent iterations to analyze (default: 5)
    ///
    /// ## Example
    /// ```swift
    /// var strategy = ConvergenceBasedStrategy(
    ///     minInterval: 1,      // Report as often as every iteration when converging fast
    ///     maxInterval: 50,     // Report as rarely as every 50 iterations when slow
    ///     convergenceThreshold: 0.01,  // 1% improvement is "fast"
    ///     metricsWindowSize: 5
    /// )
    /// ```
    public init(
        minInterval: Int,
        maxInterval: Int,
        convergenceThreshold: Double,
        metricsWindowSize: Int = 5
    ) {
        self.minInterval = minInterval
        self.maxInterval = maxInterval
        self.convergenceThreshold = convergenceThreshold
        self.metricsWindowSize = metricsWindowSize
        self.currentInterval = minInterval
        self.lastReportedIteration = -minInterval
        self.recentMetrics = []
    }

    /// Check if progress should be reported for the current iteration.
    ///
    /// Reports when enough iterations have passed since the last report,
    /// where "enough" is determined by the adaptive interval.
    ///
    /// - Parameter iteration: Current iteration number
    /// - Returns: True if progress should be reported
    public mutating func shouldReport(iteration: Int) -> Bool {
        if iteration - lastReportedIteration >= currentInterval {
            lastReportedIteration = iteration
            return true
        }
        return false
    }

    /// Update strategy with new convergence metrics.
    ///
    /// Analyzes recent improvements and adapts the reporting interval:
    /// - Fast convergence (improvement > threshold): Decrease interval (report more often)
    /// - Slow convergence (improvement < threshold): Increase interval (report less often)
    ///
    /// - Parameter metrics: Metrics from the current iteration
    public mutating func update(with metrics: ConvergenceMetrics) {
        recentMetrics.append(metrics)
        if recentMetrics.count > metricsWindowSize {
            recentMetrics.removeFirst()
        }

        // Adjust interval based on convergence rate
        if recentMetrics.count >= 2 {
            let recentImprovement = calculateAverageImprovement()

            if recentImprovement > convergenceThreshold {
                // Fast convergence - report more frequently
                currentInterval = max(minInterval, currentInterval - 1)
            } else {
                // Slow convergence - report less frequently
                currentInterval = min(maxInterval, currentInterval + 1)
            }
        }
    }

    private func calculateAverageImprovement() -> Double {
        guard recentMetrics.count >= 2 else { return 0 }

        var totalImprovement = 0.0
        for i in 1..<recentMetrics.count {
            totalImprovement += recentMetrics[i].improvementFrom(recentMetrics[i - 1])
        }

        return totalImprovement / Double(recentMetrics.count - 1)
    }
}

// MARK: - Convergence Detector

/// Detects convergence patterns and anomalies
public struct ConvergenceDetector: Sendable {
    /// Number of recent iterations to analyze for convergence detection.
    ///
    /// Larger windows (10-20) provide more robust detection but slower response.
    /// Smaller windows (3-5) respond quickly but may trigger prematurely.
    public let windowSize: Int

    /// Minimum average relative improvement threshold for convergence.
    ///
    /// When average improvement over the window falls below this threshold,
    /// and gradient norms are small, convergence is declared. Typical values: 1e-6 to 1e-8.
    public let improvementThreshold: Double

    /// Maximum gradient norm threshold for convergence.
    ///
    /// When gradient norms in the window are all below this threshold,
    /// it indicates the optimizer is near a critical point. Typical values: 1e-6 to 1e-8.
    public let gradientThreshold: Double

    private var metricsHistory: [ConvergenceMetrics]

    /// Create a convergence detector with specified thresholds.
    ///
    /// ## Parameters
    /// - windowSize: Number of recent iterations to analyze (typically 5-10)
    /// - improvementThreshold: Minimum average improvement to consider converged (e.g., 1e-6)
    /// - gradientThreshold: Maximum gradient norm to consider converged (e.g., 1e-6)
    ///
    /// ## Example
    /// ```swift
    /// var detector = ConvergenceDetector(
    ///     windowSize: 10,
    ///     improvementThreshold: 1e-6,
    ///     gradientThreshold: 1e-6
    /// )
    /// ```
    public init(
        windowSize: Int,
        improvementThreshold: Double,
        gradientThreshold: Double
    ) {
        self.windowSize = windowSize
        self.improvementThreshold = improvementThreshold
        self.gradientThreshold = gradientThreshold
        self.metricsHistory = []
    }

    /// Update the detector with new convergence metrics.
    ///
    /// Maintains a sliding window of recent metrics for convergence analysis.
    ///
    /// - Parameter metrics: Metrics from the current iteration
    public mutating func update(with metrics: ConvergenceMetrics) {
        metricsHistory.append(metrics)
        if metricsHistory.count > windowSize {
            metricsHistory.removeFirst()
        }
    }

    /// Check if optimization has converged
    public var hasConverged: Bool {
        guard metricsHistory.count >= windowSize else { return false }

        let recentWindow = Array(metricsHistory.suffix(windowSize))

        // Check gradient norm
        let allGradientsSmall = recentWindow.allSatisfy { $0.gradientNorm < gradientThreshold }

        // Check improvement
        var totalImprovement = 0.0
        for i in 1..<recentWindow.count {
            totalImprovement += recentWindow[i].improvementFrom(recentWindow[i - 1])
        }
        let avgImprovement = totalImprovement / Double(recentWindow.count - 1)
        let improvementSmall = avgImprovement < improvementThreshold

        return allGradientsSmall && improvementSmall
    }

    /// Check if optimization is oscillating
    public var isOscillating: Bool {
        guard metricsHistory.count >= windowSize else { return false }

        let recentWindow = Array(metricsHistory.suffix(windowSize))

        // Count sign changes in objective value differences
        var signChanges = 0
        for i in 1..<recentWindow.count {
            let diff1 = recentWindow[i].objectiveValue - recentWindow[i - 1].objectiveValue
            if i < recentWindow.count - 1 {
                let diff2 = recentWindow[i + 1].objectiveValue - recentWindow[i].objectiveValue
                if (diff1 > 0 && diff2 < 0) || (diff1 < 0 && diff2 > 0) {
                    signChanges += 1
                }
            }
        }

        // If more than half of the intervals show sign changes, it's oscillating
        return signChanges > windowSize / 2
    }

    /// Estimate convergence rate
    public var convergenceRate: Double {
        guard metricsHistory.count >= 2 else { return 0 }

        let recentWindow = Array(metricsHistory.suffix(min(windowSize, metricsHistory.count)))

        var totalImprovement = 0.0
        for i in 1..<recentWindow.count {
            totalImprovement += recentWindow[i].improvementFrom(recentWindow[i - 1])
        }

        return totalImprovement / Double(recentWindow.count - 1)
    }

    /// Get convergence status description
    public var status: String {
        if hasConverged {
            return "Converged"
        } else if isOscillating {
            return "Oscillating"
        } else {
            return "In Progress"
        }
    }
}
