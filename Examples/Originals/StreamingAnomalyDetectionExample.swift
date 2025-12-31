//
//  StreamingAnomalyDetectionExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to streaming anomaly detection (Phase 2.4)
//  Learn CUSUM, EWMA, outlier detection, and change point methods
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: CUSUM for Process Control

func example1_CUSUMProcessControl() async throws {
    print("=== Example 1: CUSUM for Manufacturing Process Control ===\n")

    // Product weight measurements (target: 1000g)
    let weights = AsyncValueStream([
        1000.0, 1001.0, 999.0, 1000.0, 1002.0,  // Normal operation
        1005.0, 1008.0, 1010.0, 1012.0, 1015.0  // Process shifted upward
    ])

    print("Monitoring product weight (target: 1000g):")
    print("Sample | Weight | C+ Index | C- Index | Status")
    print("-------|--------|----------|----------|--------")

    var sample = 1
    for try await signal in weights.cusum(target: 1000.0, drift: 0.5, threshold: 5.0) {
        let status = signal.isSignaling ?
            (signal.direction == .upward ? "🚨 HIGH" : "🚨 LOW") :
            "✓ OK"

        print("  \(String(format: "%2d", sample))   | \(String(format: "%4.0f", [1000.0, 1001.0, 999.0, 1000.0, 1002.0, 1005.0, 1008.0, 1010.0, 1012.0, 1015.0][sample-1]))g  | \(String(format: "%7.2f", signal.cPlusIndex))  | \(String(format: "%7.2f", signal.cMinusIndex))  | \(status)")
        sample += 1
    }

    print("\nCUSUM detects when process mean has shifted from target\n")
}

// MARK: - Example 2: CUSUM for Detecting Mean Shifts

func example2_CUSUMRuntimeDetection() async throws {
    print("=== Example 2: CUSUM for Server Response Time Monitoring ===\n")

    // Server response times (target: 50ms)
    let responseTimes = AsyncValueStream([
        50.0, 48.0, 52.0, 49.0, 51.0,  // Baseline ~50ms
        55.0, 58.0, 62.0, 65.0, 68.0   // Performance degradation
    ])

    print("Detecting performance degradation:")

    var detected = false
    var requestNum = 1

    for try await signal in responseTimes.cusum(target: 50.0, drift: 1.0, threshold: 10.0) {
        if signal.isSignaling && !detected {
            print("⚠️  Alert! Performance degradation detected at request \(requestNum)")
            print("   Mean response time has shifted above 50ms baseline")
            detected = true
            break
        }
        requestNum += 1
    }
    print()
}

// MARK: - Example 3: EWMA for Gradual Drift Detection

func example3_EWMAGradualDrift() async throws {
    print("=== Example 3: EWMA for Detecting Gradual Drift ===\n")

    // Temperature sensor readings with slow drift
    let temperatures = AsyncValueStream([
        20.0, 20.1, 20.0, 20.2, 20.3,
        20.5, 20.7, 21.0, 21.3, 21.6,
        22.0, 22.4, 22.8, 23.2, 23.6
    ])

    print("Temperature Drift Monitoring (target: 20°C):")
    print("Reading | Temp  | EWMA  | Distance | Status")
    print("--------|-------|-------|----------|--------")

    let temps = [20.0, 20.1, 20.0, 20.2, 20.3, 20.5, 20.7, 21.0, 21.3, 21.6, 22.0, 22.4, 22.8, 23.2, 23.6]
    var reading = 1

    for try await signal in temperatures.ewma(target: 20.0, lambda: 0.2, controlLimit: 2.0) {
        let temp = temps[reading - 1]
        let status = signal.isAnomalous ? "🚨 Drift!" : "✓ OK"

        print("   \(String(format: "%2d", reading))   | \(String(format: "%.1f", temp))°C | \(String(format: "%.2f", signal.ewmaValue))°C | \(String(format: "%7.2f", signal.distance))   | \(status)")
        reading += 1
    }

    print("\nEWMA is sensitive to small, gradual changes\n")
}

// MARK: - Example 4: Z-Score Outlier Detection

func example4_ZScoreOutlierDetection() async throws {
    print("=== Example 4: Z-Score Outlier Detection ===\n")

    // Transaction amounts
    let transactions = AsyncValueStream([
        45.0, 52.0, 48.0, 50.0, 49.0,
        51.0, 47.0, 250.0,  // Outlier!
        50.0, 48.0, 52.0, 49.0
    ])

    print("Transaction Fraud Detection:")
    print("Txn | Amount  | Z-Score | Status")
    print("----|---------|---------|--------")

    let amounts = [45.0, 52.0, 48.0, 50.0, 49.0, 51.0, 47.0, 250.0, 50.0, 48.0, 52.0, 49.0]
    var txn = 1

    for try await detection in transactions.detectOutliers(method: .zScore(threshold: 3.0), window: 7) {
        let amount = amounts[txn - 1]
        let status = detection.isOutlier ? "🚨 FRAUD?" : "✓ Normal"

        print(" \(String(format: "%2d", txn)) | $\(String(format: "%6.2f", amount)) | \(String(format: "%+6.2f", detection.score))  | \(status)")
        txn += 1
    }

    print("\nZ-score > 3.0 indicates significant deviation from normal\n")
}

// MARK: - Example 5: IQR Outlier Detection (Robust)

func example5_IQROutlierDetection() async throws {
    print("=== Example 5: IQR Outlier Detection (Robust Method) ===\n")

    // API latency measurements
    let latencies = AsyncValueStream([
        15.0, 17.0, 16.0, 18.0, 15.0,
        16.0, 17.0, 89.0,  // Spike!
        16.0, 15.0, 17.0, 18.0, 16.0
    ])

    print("API Latency Spike Detection:")
    print("Request | Latency | IQR Score | Status")
    print("--------|---------|-----------|--------")

    let lats = [15.0, 17.0, 16.0, 18.0, 15.0, 16.0, 17.0, 89.0, 16.0, 15.0, 17.0, 18.0, 16.0]
    var req = 1

    for try await detection in latencies.detectOutliers(method: .iqr(multiplier: 1.5), window: 7) {
        let latency = lats[req - 1]
        let status = detection.isOutlier ? "🚨 Spike!" : "✓ Normal"

        print("   \(String(format: "%2d", req))   | \(String(format: "%5.1f", latency))ms | \(String(format: "%8.2f", detection.score))  | \(status)")
        req += 1
    }

    print("\nIQR method is robust to extreme values\n")
}

// MARK: - Example 6: MAD Outlier Detection (Most Robust)

func example6_MADOutlierDetection() async throws {
    print("=== Example 6: MAD Outlier Detection (Most Robust) ===\n")

    // System metrics with occasional corruption
    let metrics = AsyncValueStream([
        100.0, 102.0, 99.0, 101.0, 98.0,
        999.0,  // Data corruption!
        100.0, 101.0, 99.0, 102.0, 100.0
    ])

    print("Detecting Data Corruption:")
    print("Reading | Value | MAD Score | Status")
    print("--------|-------|-----------|--------")

    let vals = [100.0, 102.0, 99.0, 101.0, 98.0, 999.0, 100.0, 101.0, 99.0, 102.0, 100.0]
    var reading = 1

    for try await detection in metrics.detectOutliers(method: .mad(threshold: 3.5), window: 5) {
        let value = vals[reading - 1]
        let status = detection.isOutlier ? "🚨 Corrupt!" : "✓ Valid"

        print("   \(String(format: "%2d", reading))   | \(String(format: "%5.0f", value))  | \(String(format: "%8.2f", detection.score))   | \(status)")
        reading += 1
    }

    print("\nMAD (Median Absolute Deviation) is most robust to outliers\n")
}

// MARK: - Example 7: Breakpoint Detection

func example7_BreakpointDetection() async throws {
    print("=== Example 7: Breakpoint Detection ===\n")

    // User engagement before and after feature launch
    let engagement = AsyncValueStream([
        50.0, 52.0, 48.0, 51.0, 49.0, 50.0, 52.0,  // Before: ~50
        75.0, 78.0, 76.0, 80.0, 77.0, 79.0, 78.0   // After: ~78 (feature launched!)
    ])

    print("Detecting Feature Impact on User Engagement:")

    for try await breakpoint in engagement.detectBreakpoints(minSegmentSize: 3, maxBreakpoints: 2) {
        print("📍 Breakpoint detected at position \(breakpoint.position)")
        print("   Change magnitude: \(String(format: "%+.1f", breakpoint.magnitude)) engagement points")
        print("   Before: \(String(format: "%.1f", breakpoint.beforeMean)), After: \(String(format: "%.1f", breakpoint.afterMean))")
    }

    print("\nBreakpoint detection identifies structural changes in data\n")
}

// MARK: - Example 8: Seasonal Anomaly Detection

func example8_SeasonalAnomalyDetection() async throws {
    print("=== Example 8: Seasonal Anomaly Detection ===\n")

    // Quarterly sales (repeating seasonal pattern)
    let sales = AsyncValueStream([
        100.0, 80.0, 110.0, 90.0,   // Year 1 - normal pattern
        105.0, 85.0, 115.0, 95.0,   // Year 2 - normal growth
        110.0, 150.0, 120.0, 100.0  // Year 3 - Q2 anomaly!
    ])

    print("Quarterly Sales Anomaly Detection:")
    print("Quarter | Sales | Expected | Deviation | Status")
    print("--------|-------|----------|-----------|--------")

    let salesData = [100.0, 80.0, 110.0, 90.0, 105.0, 85.0, 115.0, 95.0, 110.0, 150.0, 120.0, 100.0]
    let quarters = ["Q1Y1", "Q2Y1", "Q3Y1", "Q4Y1", "Q1Y2", "Q2Y2", "Q3Y2", "Q4Y2", "Q1Y3", "Q2Y3", "Q3Y3", "Q4Y3"]
    var idx = 0

    for try await detection in sales.detectSeasonalAnomalies(seasonLength: 4, threshold: 2.5) {
        let actual = salesData[idx]
        let status = detection.isAnomaly ? "🚨 Anomaly!" : "✓ Normal"

        print(" \(quarters[idx])   | $\(String(format: "%3.0f", actual))K | $\(String(format: "%6.1f", detection.expectedValue))K | \(String(format: "%8.2f", detection.deviation))   | \(status)")
        idx += 1
    }

    print("\nSeasonal detection accounts for repeating patterns\n")
}

// MARK: - Example 9: Composite Anomaly Scoring

func example9_CompositeAnomalyScoring() async throws {
    print("=== Example 9: Composite Anomaly Scoring ===\n")

    // Network traffic with various anomalies
    let traffic = AsyncValueStream([
        1000.0, 1050.0, 980.0, 1020.0, 1010.0,
        1030.0, 2500.0,  // DDoS attack!
        1040.0, 1020.0, 990.0, 1060.0, 1030.0
    ])

    print("Multi-Method Network Intrusion Detection:")
    print("Packet | Traffic | Composite | Severity")
    print("-------|---------|-----------|----------")

    let trafficData = [1000.0, 1050.0, 980.0, 1020.0, 1010.0, 1030.0, 2500.0, 1040.0, 1020.0, 990.0, 1060.0, 1030.0]
    var packet = 1

    for try await composite in traffic.compositeAnomalyScore(
        methods: [.zScore(threshold: 3.0), .iqr(multiplier: 1.5), .mad(threshold: 3.5)],
        window: 5
    ) {
        let traff = trafficData[packet - 1]
        let severity: String
        if composite.averageScore > 2.0 {
            severity = "🚨 CRITICAL"
        } else if composite.averageScore > 1.0 {
            severity = "⚠️  Warning"
        } else {
            severity = "✓ Normal"
        }

        print("  \(String(format: "%2d", packet))   | \(String(format: "%4.0f", traff))   | \(String(format: "%8.2f", composite.averageScore))  | \(severity)")
        packet += 1
    }

    print("\nComposite scoring combines multiple detection methods\n")
}

// MARK: - Example 10: Real-World - E-commerce Fraud Detection

func example10_FraudDetectionPipeline() async throws {
    print("=== Example 10: Real-World - E-commerce Fraud Detection ===\n")

    // Transaction amounts throughout the day
    let transactions = AsyncValueStream([
        45.0, 67.0, 32.0, 89.0, 54.0,  // Normal shopping
        72.0, 41.0, 95.0, 63.0, 78.0,
        850.0,  // Suspicious high-value transaction
        52.0, 48.0, 71.0, 59.0, 82.0,
        950.0, 920.0,  // Multiple high-value (stolen card?)
        65.0, 73.0, 58.0
    ])

    print("Real-time Fraud Detection System:")
    print("\nUsing multi-layered detection:")
    print("  - Z-score for statistical outliers")
    print("  - CUSUM for pattern changes")
    print("  - Composite scoring for high confidence\n")

    print("Txn | Amount  | Risk Score | Decision")
    print("----|---------|------------|----------")

    let amounts = [45.0, 67.0, 32.0, 89.0, 54.0, 72.0, 41.0, 95.0, 63.0, 78.0, 850.0, 52.0, 48.0, 71.0, 59.0, 82.0, 950.0, 920.0, 65.0, 73.0, 58.0]
    var txn = 1

    for try await composite in transactions.compositeAnomalyScore(
        methods: [.zScore(threshold: 2.5), .iqr(multiplier: 1.5)],
        window: 10
    ) {
        let amount = amounts[txn - 1]
        let riskScore = composite.averageScore

        let decision: String
        if riskScore > 2.0 {
            decision = "🚨 BLOCK"
        } else if riskScore > 1.0 {
            decision = "⚠️  Review"
        } else {
            decision = "✓ Approve"
        }

        print(" \(String(format: "%2d", txn)) | $\(String(format: "%6.2f", amount)) | \(String(format: "%9.2f", riskScore))  | \(decision)")
        txn += 1
    }
    print()
}

// MARK: - Example 11: System Health Monitoring

func example11_SystemHealthMonitoring() async throws {
    print("=== Example 11: Comprehensive System Health Monitoring ===\n")

    // CPU utilization percentage
    let cpuUsage = AsyncValueStream([
        25.0, 28.0, 26.0, 30.0, 27.0,  // Normal baseline
        29.0, 31.0, 35.0, 42.0, 55.0,  // Gradual increase
        68.0, 82.0, 85.0, 87.0, 90.0   // Critical levels
    ])

    print("Multi-Stage Alert System:")

    var stage = "Baseline"
    var measurement = 1

    for try await signal in cpuUsage.ewma(target: 30.0, lambda: 0.3, controlLimit: 2.5) {
        let usage = [25.0, 28.0, 26.0, 30.0, 27.0, 29.0, 31.0, 35.0, 42.0, 55.0, 68.0, 82.0, 85.0, 87.0, 90.0][measurement - 1]

        // Determine alert stage
        if signal.distance > 4.0 && stage != "Critical" {
            stage = "Critical"
            print("\n🚨 CRITICAL ALERT (Measurement \(measurement)): CPU usage at \(String(format: "%.0f", usage))%")
            print("   EWMA distance: \(String(format: "%.2f", signal.distance))")
            print("   Action: Scale infrastructure immediately\n")
        } else if signal.isAnomalous && signal.distance > 2.5 && stage == "Baseline" {
            stage = "Warning"
            print("\n⚠️  WARNING (Measurement \(measurement)): Elevated CPU usage detected")
            print("   EWMA distance: \(String(format: "%.2f", signal.distance))")
            print("   Action: Monitor closely\n")
        }

        measurement += 1
    }

    print("System health monitoring complete")
    print("Final stage: \(stage)\n")
}

// MARK: - Example 12: Comparing Detection Methods

func example12_ComparingMethods() async throws {
    print("=== Example 12: Comparing Detection Methods ===\n")

    // Data with both gradual drift and sudden spike
    let data = AsyncValueStream([
        50.0, 51.0, 52.0, 53.0, 54.0,  // Gradual drift
        55.0, 56.0, 150.0,              // Sudden spike!
        57.0, 58.0, 59.0, 60.0
    ])

    print("Testing Different Detection Methods:\n")

    // CUSUM - good for mean shifts
    print("1. CUSUM (detects sustained mean shifts):")
    var cusumDetections = 0
    for try await signal in data.cusum(target: 50.0, drift: 1.0, threshold: 8.0) {
        if signal.isSignaling {
            cusumDetections += 1
        }
    }
    print("   Detections: \(cusumDetections)")

    // Z-Score - good for sudden outliers
    print("\n2. Z-Score (detects sudden outliers):")
    var zScoreOutliers = 0
    for try await detection in data.detectOutliers(method: .zScore(threshold: 3.0), window: 6) {
        if detection.isOutlier {
            zScoreOutliers += 1
        }
    }
    print("   Outliers: \(zScoreOutliers)")

    // EWMA - good for gradual drift
    print("\n3. EWMA (detects gradual drift):")
    var ewmaAnomalies = 0
    for try await signal in data.ewma(target: 50.0, lambda: 0.2, controlLimit: 2.0) {
        if signal.isAnomalous {
            ewmaAnomalies += 1
        }
    }
    print("   Anomalies: \(ewmaAnomalies)")

    print("\nConclusion:")
    print("  - CUSUM: Best for sustained shifts")
    print("  - Z-Score: Best for sudden spikes")
    print("  - EWMA: Best for gradual changes")
    print("  - Composite: Combines strengths of all methods\n")
}

// MARK: - Run All Examples

@main
struct StreamingAnomalyDetectionExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Streaming Anomaly Detection Examples (Phase 2.4)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_CUSUMProcessControl()
        try await example2_CUSUMRuntimeDetection()
        try await example3_EWMAGradualDrift()
        try await example4_ZScoreOutlierDetection()
        try await example5_IQROutlierDetection()
        try await example6_MADOutlierDetection()
        try await example7_BreakpointDetection()
        try await example8_SeasonalAnomalyDetection()
        try await example9_CompositeAnomalyScoring()
        try await example10_FraudDetectionPipeline()
        try await example11_SystemHealthMonitoring()
        try await example12_ComparingMethods()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
