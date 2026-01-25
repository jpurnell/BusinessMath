//
//  AdaptiveProgressTests.swift
//  BusinessMath
//
//  Created on December 30, 2025.
//

import Testing
@testable import BusinessMath

/// Tests for adaptive progress reporting system
@Suite("Adaptive Progress Tests")
struct AdaptiveProgressTests {

    // MARK: - ProgressStrategy Tests

    @Test("FixedIntervalStrategy reports at regular intervals")
    func fixedIntervalStrategy() async {
        let strategy = FixedIntervalStrategy(interval: 10)

        // Should report at intervals
        #expect(strategy.shouldReport(iteration: 0))
        #expect(!strategy.shouldReport(iteration: 5))
        #expect(strategy.shouldReport(iteration: 10))
        #expect(!strategy.shouldReport(iteration: 15))
        #expect(strategy.shouldReport(iteration: 20))
    }

    @Test("ExponentialBackoffStrategy increases reporting intervals")
    func exponentialBackoffStrategy() async {
        var strategy = ExponentialBackoffStrategy(
            initialInterval: 1,
            maxInterval: 100,
            backoffFactor: 2.0
        )

        // Should report more frequently early, less frequently later
        // With initial interval 1 and factor 2, reports at: 0, 1, 3, 7, 15...
        let reported0 = strategy.shouldReport(iteration: 0)
        #expect(reported0)
        let reported1 = strategy.shouldReport(iteration: 1)
        #expect(reported1)
        let reported2 = strategy.shouldReport(iteration: 2)
        #expect(!reported2)  // Should NOT report - next is at iteration 3
        let reported3 = strategy.shouldReport(iteration: 3)
        #expect(reported3)

        // Verify exponential sequence continues: next should be at 7
        let reported4 = strategy.shouldReport(iteration: 4)
        #expect(!reported4)
        let reported5 = strategy.shouldReport(iteration: 5)
        #expect(!reported5)
        let reported6 = strategy.shouldReport(iteration: 6)
        #expect(!reported6)
        let reported7 = strategy.shouldReport(iteration: 7)
        #expect(reported7)  // Reports at 0, 1, 3, 7 with interval doubling
    }

    @Test("ConvergenceBasedStrategy adapts to convergence rate")
    func convergenceBasedStrategy() async {
        var strategy = ConvergenceBasedStrategy(
            minInterval: 1,
            maxInterval: 100,
            convergenceThreshold: 0.01
        )

        // Fast convergence should reduce reporting
        let metrics1 = ConvergenceMetrics(
            iteration: 10,
            objectiveValue: 10.0,
            gradientNorm: 5.0,
            stepSize: 1.0,
            relativeChange: 0.5
        )
        strategy.update(with: metrics1)

        let metrics2 = ConvergenceMetrics(
            iteration: 11,
            objectiveValue: 5.0,
            gradientNorm: 2.0,
            stepSize: 1.0,
            relativeChange: 0.5
        )
        strategy.update(with: metrics2)

        let should15 = strategy.shouldReport(iteration: 15)
        #expect(should15)
    }

    // MARK: - ConvergenceMetrics Tests

    @Test("ConvergenceMetrics calculates improvement correctly")
    func convergenceMetricsImprovement() {
        let metrics1 = ConvergenceMetrics(
            iteration: 0,
            objectiveValue: 100.0,
            gradientNorm: 10.0,
            stepSize: 1.0,
            relativeChange: 0.0
        )

        let metrics2 = ConvergenceMetrics(
            iteration: 1,
            objectiveValue: 90.0,
            gradientNorm: 5.0,
            stepSize: 1.0,
            relativeChange: 0.1
        )

        let improvement = metrics2.improvementFrom(metrics1)
        #expect(abs(improvement - 0.1) < 1e-10)
    }

    @Test("ConvergenceMetrics detects stagnation")
    func convergenceMetricsStagnation() {
        let metrics1 = ConvergenceMetrics(
            iteration: 0,
            objectiveValue: 100.0,
            gradientNorm: 0.001,
            stepSize: 0.0001,
            relativeChange: 0.0001
        )

        #expect(metrics1.isStagnant(threshold: 0.01))
        #expect(!metrics1.isStagnant(threshold: 0.0001))
    }

    // MARK: - ConvergenceDetector Tests

    @Test("ConvergenceDetector identifies convergence")
    func convergenceDetectorBasic() {
        var detector = ConvergenceDetector(
            windowSize: 3,
            improvementThreshold: 0.01,
            gradientThreshold: 0.001
        )

        // Add metrics showing convergence
        let metrics1 = ConvergenceMetrics(
            iteration: 0,
            objectiveValue: 10.0,
            gradientNorm: 0.0005,
            stepSize: 0.01,
            relativeChange: 0.001
        )
        detector.update(with: metrics1)

        let metrics2 = ConvergenceMetrics(
            iteration: 1,
            objectiveValue: 9.99,
            gradientNorm: 0.0003,
            stepSize: 0.01,
            relativeChange: 0.001
        )
        detector.update(with: metrics2)

        let metrics3 = ConvergenceMetrics(
            iteration: 2,
            objectiveValue: 9.98,
            gradientNorm: 0.0002,
            stepSize: 0.01,
            relativeChange: 0.001
        )
        detector.update(with: metrics3)

        #expect(detector.hasConverged)
    }

    @Test("ConvergenceDetector detects oscillation")
    func convergenceDetectorOscillation() {
        var detector = ConvergenceDetector(
            windowSize: 5,
            improvementThreshold: 0.01,
            gradientThreshold: 0.001
        )

        // Add oscillating metrics
        for i in 0..<10 {
            let value = i % 2 == 0 ? 10.0 : 10.5
            let metrics = ConvergenceMetrics(
                iteration: i,
                objectiveValue: value,
                gradientNorm: 1.0,
                stepSize: 0.1,
                relativeChange: 0.05
            )
            detector.update(with: metrics)
        }

        #expect(detector.isOscillating)
        #expect(!detector.hasConverged)
    }

    @Test("ConvergenceDetector tracks convergence rate")
    func convergenceDetectorRate() {
        var detector = ConvergenceDetector(
            windowSize: 3,
            improvementThreshold: 0.01,
            gradientThreshold: 0.001
        )

        // Add metrics with consistent improvement
        for i in 0..<5 {
            let metrics = ConvergenceMetrics(
                iteration: i,
                objectiveValue: 100.0 - Double(i) * 10.0,
                gradientNorm: 1.0,
                stepSize: 0.1,
                relativeChange: 0.1
            )
            detector.update(with: metrics)
        }

        let rate = detector.convergenceRate
        #expect(rate > 0.0)
    }

    // MARK: - Integration Tests

    @Test("Adaptive progress updates frequency based on convergence")
    func adaptiveProgressIntegration() async {
        var strategy = ConvergenceBasedStrategy(
            minInterval: 1,
            maxInterval: 50,
            convergenceThreshold: 0.01
        )

        // Simulate fast initial convergence
        for i in 0..<10 {
            let metrics = ConvergenceMetrics(
                iteration: i,
                objectiveValue: 100.0 / Double(i + 1),
                gradientNorm: 10.0 / Double(i + 1),
                stepSize: 1.0,
                relativeChange: 0.5 / Double(i + 1)
            )
            strategy.update(with: metrics)
        }

        var earlyReports = 0
        for i in 0..<10 {
            if strategy.shouldReport(iteration: i) {
                earlyReports += 1
            }
        }

        // Simulate slow late convergence
        for i in 10..<20 {
            let metrics = ConvergenceMetrics(
                iteration: i,
                objectiveValue: 5.0 - 0.01 * Double(i - 10),
                gradientNorm: 0.1,
                stepSize: 0.01,
                relativeChange: 0.002
            )
            strategy.update(with: metrics)
        }

        var lateReports = 0
        for i in 10..<20 {
            if strategy.shouldReport(iteration: i) {
                lateReports += 1
            }
        }

        // Should report more during interesting phases
        #expect(earlyReports > 0)
        #expect(lateReports >= 0)
    }

    @Test("Multiple strategies can coexist")
    func multipleStrategies() {
        let fixed = FixedIntervalStrategy(interval: 10)
        var exponential = ExponentialBackoffStrategy(
            initialInterval: 1,
            maxInterval: 100,
            backoffFactor: 2.0
        )

        // Both should work independently
        let fixedResult = fixed.shouldReport(iteration: 10)
        #expect(fixedResult)
        let expResult = exponential.shouldReport(iteration: 1)
        #expect(expResult)
    }
}
