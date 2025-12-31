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
    public let interval: Int

    public init(interval: Int) {
        self.interval = interval
    }

    public func shouldReport(iteration: Int) -> Bool {
        return iteration % interval == 0
    }

    public mutating func update(with metrics: ConvergenceMetrics) {
        // Fixed strategy doesn't adapt
    }
}

// MARK: - Exponential Backoff Strategy

/// Reports progress with exponentially increasing intervals
public struct ExponentialBackoffStrategy: ProgressStrategy {
    public let initialInterval: Int
    public let maxInterval: Int
    public let backoffFactor: Double

    private var currentInterval: Int
    private var nextReportIteration: Int

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

    public mutating func update(with metrics: ConvergenceMetrics) {
        // Exponential backoff doesn't use metrics
    }
}

// MARK: - Convergence-Based Strategy

/// Adapts reporting frequency based on convergence rate
public struct ConvergenceBasedStrategy: ProgressStrategy {
    public let minInterval: Int
    public let maxInterval: Int
    public let convergenceThreshold: Double

    private var currentInterval: Int
    private var lastReportedIteration: Int
    private var recentMetrics: [ConvergenceMetrics]
    private let metricsWindowSize: Int

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

    public mutating func shouldReport(iteration: Int) -> Bool {
        if iteration - lastReportedIteration >= currentInterval {
            lastReportedIteration = iteration
            return true
        }
        return false
    }

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
    public let windowSize: Int
    public let improvementThreshold: Double
    public let gradientThreshold: Double

    private var metricsHistory: [ConvergenceMetrics]

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
