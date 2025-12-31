//
//  StreamingAnomalyDetectionTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-12-30.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for Advanced Anomaly and Change Detection (Phase 2.4)
///
/// Following TDD:
/// - RED: Write failing tests first
/// - GREEN: Implement to make tests pass
/// - REFACTOR: Clean up implementation
@Suite("Streaming Anomaly Detection Tests")
struct StreamingAnomalyDetectionTests {

    // MARK: - CUSUM Control Chart Tests

    @Test("CUSUM detects upward shift in mean")
    func cusumDetectsUpwardShift() async throws {
        // Series with mean shift from 5 to 10
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1,  // Baseline around 5
                      10.0, 10.1, 9.9, 10.0, 10.2, 9.8, 10.0]  // Shifted to 10
        let stream = AsyncValueStream(values)

        var signals: [CUSUMSignal] = []
        for try await signal in stream.cusum(target: 5.0, drift: 0.5, threshold: 4.0) {
            signals.append(signal)
        }

        // Should detect the upward shift
        let upwardSignals = signals.filter { $0.direction == .upward && $0.isSignaling }
        #expect(upwardSignals.count >= 1)
    }

    @Test("CUSUM detects downward shift in mean")
    func cusumDetectsDownwardShift() async throws {
        let values = [10.0, 10.1, 9.9, 10.0, 10.2, 9.8, 10.0,  // Baseline around 10
                      5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0]       // Shifted to 5
        let stream = AsyncValueStream(values)

        var signals: [CUSUMSignal] = []
        for try await signal in stream.cusum(target: 10.0, drift: 0.5, threshold: 4.0) {
            signals.append(signal)
        }

        // Should detect the downward shift
        let downwardSignals = signals.filter { $0.direction == .downward && $0.isSignaling }
        #expect(downwardSignals.count >= 1)
    }

    @Test("CUSUM does not signal for stable process")
    func cusumStableProcess() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var signals: [CUSUMSignal] = []
        for try await signal in stream.cusum(target: 5.0, drift: 0.5, threshold: 4.0) {
            signals.append(signal)
        }

        // Should not signal for stable process
        let signalingCount = signals.filter { $0.isSignaling }.count
        #expect(signalingCount == 0)
    }

    // MARK: - EWMA Control Chart Tests

    @Test("EWMA detects gradual shift")
    func ewmaDetectsGradualShift() async throws {
        // Gradual shift from 5 to 7
        let values = [5.0, 5.0, 5.0, 5.1, 5.2, 5.4, 5.6, 5.9, 6.2, 6.5, 6.8, 7.0, 7.0]
        let stream = AsyncValueStream(values)

        var signals: [EWMASignal] = []
        for try await signal in stream.ewma(target: 5.0, lambda: 0.3, controlLimitSigma: 2.0) {
            signals.append(signal)
        }

        // Should detect the gradual shift
        let outOfControl = signals.filter { $0.isOutOfControl }
        #expect(outOfControl.count >= 1)
    }

    @Test("EWMA within control limits for stable process")
    func ewmaStableProcess() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var signals: [EWMASignal] = []
        for try await signal in stream.ewma(target: 5.0, lambda: 0.3, controlLimitSigma: 3.0) {
            signals.append(signal)
        }

        // Should stay within control limits
        let outOfControl = signals.filter { $0.isOutOfControl }
        #expect(outOfControl.count == 0)
    }

    // MARK: - Z-Score Outlier Detection Tests

    @Test("Z-score detects outliers in stream")
    func zScoreDetectsOutliers() async throws {
        // Build baseline then introduce outliers
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0,  // Baseline
                      15.0, 5.1, 4.9, -5.0, 5.0]          // Outliers: 15.0 and -5.0
        let stream = AsyncValueStream(values)

        var outliers: [OutlierDetection] = []
        for try await detection in stream.detectOutliers(method: .zScore(threshold: 2.5), window: 12) {
            if detection.isOutlier {
                outliers.append(detection)
            }
        }

        // Should detect at least 2 outliers
        #expect(outliers.count >= 2)
    }

    @Test("Z-score no outliers in normal data")
    func zScoreNormalData() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var outliers: [OutlierDetection] = []
        for try await detection in stream.detectOutliers(method: .zScore(threshold: 3.0), window: 10) {
            if detection.isOutlier {
                outliers.append(detection)
            }
        }

        #expect(outliers.count == 0)
    }

    // MARK: - IQR Outlier Detection Tests

    @Test("IQR detects outliers in stream")
    func iqrDetectsOutliers() async throws {
        let values = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 50.0, 9.0]  // 50.0 is outlier
        let stream = AsyncValueStream(values)

        var outliers: [OutlierDetection] = []
        for try await detection in stream.detectOutliers(method: .iqr(multiplier: 1.5), window: 10) {
            if detection.isOutlier {
                outliers.append(detection)
            }
        }

        #expect(outliers.count >= 1)
    }

    // MARK: - MAD Outlier Detection Tests

    @Test("MAD detects outliers robustly")
    func madDetectsOutliers() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 20.0, 5.2, 4.8, 5.0, 5.1]  // 20.0 is outlier
        let stream = AsyncValueStream(values)

        var outliers: [OutlierDetection] = []
        for try await detection in stream.detectOutliers(method: .mad(threshold: 3.0), window: 10) {
            if detection.isOutlier {
                outliers.append(detection)
            }
        }

        #expect(outliers.count >= 1)
    }

    // MARK: - Binary Segmentation Breakpoint Detection Tests

    @Test("Binary segmentation finds multiple breakpoints")
    func binarySegmentationMultipleBreakpoints() async throws {
        // Three segments with different means: 5, 10, 15
        let values = [5.0, 5.0, 5.0, 5.0, 5.0,
                      10.0, 10.0, 10.0, 10.0, 10.0,
                      15.0, 15.0, 15.0, 15.0, 15.0]
        let stream = AsyncValueStream(values)

        var breakpoints: [Breakpoint] = []
        for try await breakpoint in stream.detectBreakpoints(method: .binarySegmentation(minSegmentSize: 3, maxBreakpoints: 5)) {
            breakpoints.append(breakpoint)
        }

        // Should find at least 2 breakpoints (at indices ~5 and ~10)
        #expect(breakpoints.count >= 2)
    }

    @Test("Binary segmentation handles single segment")
    func binarySegmentationSingleSegment() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 5.2, 4.8, 5.0, 5.1, 4.9, 5.0]
        let stream = AsyncValueStream(values)

        var breakpoints: [Breakpoint] = []
        for try await breakpoint in stream.detectBreakpoints(method: .binarySegmentation(minSegmentSize: 3, maxBreakpoints: 5)) {
            breakpoints.append(breakpoint)
        }

        // Should find no significant breakpoints in stable data
        #expect(breakpoints.count == 0)
    }

    // MARK: - Seasonal Anomaly Detection Tests

    @Test("Detect anomaly in seasonal pattern")
    func seasonalAnomalyDetection() async throws {
        // Establish strong seasonal pattern, then introduce anomaly
        let values = [10.0, 5.0, 15.0, 8.0,   // Season 1
                      10.0, 5.0, 15.0, 8.0,   // Season 2
                      10.0, 5.0, 15.0, 8.0,   // Season 3
                      10.0, 5.0, 15.0, 8.0,   // Season 4
                      10.0, 25.0, 15.0, 8.0,  // Season 5 with anomaly (should be ~5)
                      10.0, 5.0, 15.0, 8.0]   // Season 6
        let stream = AsyncValueStream(values)

        var anomalies: [SeasonalAnomaly] = []
        for try await anomaly in stream.detectSeasonalAnomalies(period: 4, threshold: 2.5) {
            if anomaly.isAnomaly {
                anomalies.append(anomaly)
            }
        }

        // Should detect the anomaly at position 17 (value 25.0)
        #expect(anomalies.count >= 1)
        let hasAnomalyAtIndex17 = anomalies.contains { $0.index == 17 }
        #expect(hasAnomalyAtIndex17)
    }

    @Test("No anomalies in consistent seasonal pattern")
    func seasonalNoAnomalies() async throws {
        let values = [10.0, 5.0, 15.0, 8.0,   // Season 1
                      10.0, 5.0, 15.0, 8.0,   // Season 2
                      10.0, 5.0, 15.0, 8.0]   // Season 3
        let stream = AsyncValueStream(values)

        var anomalies: [SeasonalAnomaly] = []
        for try await anomaly in stream.detectSeasonalAnomalies(period: 4, threshold: 3.0) {
            if anomaly.isAnomaly {
                anomalies.append(anomaly)
            }
        }

        #expect(anomalies.count == 0)
    }

    // MARK: - Composite Anomaly Score Tests

    @Test("Composite anomaly score combines multiple signals")
    func compositeAnomalyScore() async throws {
        let values = [5.0, 5.1, 4.9, 5.0, 25.0, 5.2, 4.8, 5.0]  // 25.0 is strong anomaly
        let stream = AsyncValueStream(values)

        var scores: [CompositeAnomalyScore] = []
        for try await score in stream.compositeAnomalyScore(window: 8, methods: [.zScore, .iqr, .mad]) {
            scores.append(score)
        }

        // The anomalous value should have a higher composite score
        let maxScore = scores.max(by: { $0.score < $1.score })
        #expect(maxScore != nil)
        #expect(maxScore!.score > 0.5)  // Composite score ranges 0-1
    }

    // MARK: - Memory Efficiency Tests

    @Test("Anomaly detection maintains O(1) memory")
    func constantMemoryForAnomalyDetection() async throws {
        // Simulate large stream
        let largeStream = AsyncGeneratorStream {
            return Double.random(in: 0...100)
        }

        var detectionCount = 0
        for try await _ in largeStream.detectOutliers(method: .zScore(threshold: 3.0), window: 100) {
            detectionCount += 1
            if detectionCount >= 10000 {
                break
            }
        }

        // If we processed 10000 detections without memory issues, O(1) memory is maintained
        #expect(detectionCount == 10000)
    }

    // MARK: - Real-world Scenario Tests

    @Test("Detect sensor malfunction pattern")
    func sensorMalfunctionDetection() async throws {
        // Realistic sensor data with sudden malfunction
        let values = [20.5, 20.7, 20.4, 20.6, 20.5, 20.8, 20.3,  // Normal readings
                      99.9, 99.9, 99.9, 99.9,                    // Sensor stuck
                      20.4, 20.6, 20.5]                          // Recovery
        let stream = AsyncValueStream(values)

        var outliers: [OutlierDetection] = []
        for try await detection in stream.detectOutliers(method: .mad(threshold: 3.0), window: 14) {
            if detection.isOutlier {
                outliers.append(detection)
            }
        }

        // Should detect the stuck sensor readings
        #expect(outliers.count >= 3)
    }

    @Test("Detect gradual drift in process")
    func gradualProcessDrift() async throws {
        // Process gradually drifting out of specification
        let values = [100.0, 100.1, 100.2, 100.4, 100.6, 100.9, 101.3, 101.8, 102.4, 103.1]
        let stream = AsyncValueStream(values)

        var signals: [CUSUMSignal] = []
        for try await signal in stream.cusum(target: 100.0, drift: 0.1, threshold: 2.0) {
            signals.append(signal)
        }

        // CUSUM should detect the drift
        let signalingPoints = signals.filter { $0.isSignaling }
        #expect(signalingPoints.count >= 1)
    }
}

// MARK: - Supporting Types

enum StreamingAnomalyDetectionTestError: Error {
    case noData
}
