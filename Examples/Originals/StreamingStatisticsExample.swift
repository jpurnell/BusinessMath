//
//  StreamingStatisticsExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to streaming statistics (Phase 2.2)
//  Learn rolling windows, cumulative stats, EMA, and variance calculation
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Rolling Mean for Moving Averages

func example1_RollingMean() async throws {
    print("=== Example 1: Rolling Mean (Moving Average) ===\n")

    // Daily revenue data
    let dailyRevenue = AsyncValueStream([
        1200.0, 1350.0, 1180.0, 1420.0, 1390.0,
        1510.0, 1280.0, 1450.0, 1520.0, 1380.0
    ])

    // Calculate 3-day moving average
    print("Daily Revenue | 3-Day Moving Avg")
    print("--------------|------------------")

    var day = 3
    for try await avg in dailyRevenue.rollingMean(window: 3) {
        print("Day \(String(format: "%2d", day))        | $\(String(format: "%.2f", avg))")
        day += 1
    }
    print()
}

// MARK: - Example 2: Cumulative Mean for Running Averages

func example2_CumulativeMean() async throws {
    print("=== Example 2: Cumulative Mean (Running Average) ===\n")

    // Customer satisfaction scores
    let scores = AsyncValueStream([4.5, 4.8, 3.2, 4.9, 5.0, 4.7, 4.6])

    print("Rating | Running Average | Status")
    print("-------|-----------------|--------")

    var count = 1
    for try await avg in scores.cumulativeMean() {
        let status = avg >= 4.5 ? "✓ Good" : "⚠ Review"
        print("\(String(format: "%.1f", AsyncValueStream([4.5, 4.8, 3.2, 4.9, 5.0, 4.7, 4.6])[count - 1]))   | \(String(format: "%.2f", avg))            | \(status)")
        count += 1
    }
    print()
}

// MARK: - Example 3: Rolling Variance for Quality Control

func example3_RollingVariance() async throws {
    print("=== Example 3: Rolling Variance for Quality Control ===\n")

    // Manufacturing tolerance measurements (in mm)
    let measurements = AsyncValueStream([
        10.02, 10.01, 9.99, 10.00, 10.01,  // Good consistency
        10.05, 9.95, 10.08, 9.92, 10.10    // Increased variance
    ])

    print("Monitoring production consistency (5-sample window):")
    print("Variance < 0.001 = Excellent, < 0.005 = Good, >= 0.005 = Review\n")

    var batch = 1
    for try await variance in measurements.rollingVariance(window: 5) {
        let quality = variance < 0.001 ? "Excellent ✓" :
                     variance < 0.005 ? "Good" :
                     "Review ⚠"
        print("Batch \(batch): Variance = \(String(format: "%.6f", variance)) → \(quality)")
        batch += 1
    }
    print()
}

// MARK: - Example 4: Rolling Standard Deviation

func example4_RollingStdDev() async throws {
    print("=== Example 4: Rolling Standard Deviation ===\n")

    // Stock price volatility
    let prices = AsyncValueStream([
        100.0, 101.0, 99.5, 102.0, 101.5,
        103.0, 98.0, 105.0, 97.0, 106.0
    ])

    print("Stock Price Volatility Analysis (3-period window):")
    print("StdDev < 2.0 = Low volatility, >= 2.0 = High volatility\n")

    var period = 1
    for try await stdDev in prices.rollingStdDev(window: 3) {
        let volatility = stdDev < 2.0 ? "Low" : "High"
        print("Period \(period): σ = \(String(format: "%.2f", stdDev)) → \(volatility) volatility")
        period += 1
    }
    print()
}

// MARK: - Example 5: Rolling Min and Max

func example5_RollingMinMax() async throws {
    print("=== Example 5: Rolling Min/Max for Range Tracking ===\n")

    // Temperature readings
    let temperatures = AsyncValueStream([72.0, 75.0, 68.0, 78.0, 71.0, 69.0, 76.0, 73.0])

    print("Temperature Range (3-hour window):")

    // We'll need to collect both min and max, so let's use comprehensive stats
    var hour = 3
    for try await stats in temperatures.rollingStatistics(window: 3) {
        let range = stats.max - stats.min
        print("Hour \(hour): Min=\(String(format: "%.0f", stats.min))°F, Max=\(String(format: "%.0f", stats.max))°F, Range=\(String(format: "%.0f", range))°F")
        hour += 1
    }
    print()
}

// MARK: - Example 6: Cumulative Sum for Running Totals

func example6_CumulativeSum() async throws {
    print("=== Example 6: Cumulative Sum for Running Totals ===\n")

    // Monthly sales
    let monthlySales = AsyncValueStream([
        45_000.0, 52_000.0, 48_000.0, 61_000.0,
        55_000.0, 58_000.0, 63_000.0, 59_000.0
    ])

    print("Month | Sales    | Year-to-Date | Target")
    print("------|----------|--------------|--------")

    let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"]
    let salesArray = [45_000.0, 52_000.0, 48_000.0, 61_000.0, 55_000.0, 58_000.0, 63_000.0, 59_000.0]

    var idx = 0
    for try await ytd in monthlySales.cumulativeSum() {
        let target = Double(idx + 1) * 50_000.0
        let status = ytd >= target ? "✓" : "⚠"
        print("\(months[idx])   | $\(String(format: "%6.0f", salesArray[idx]))K | $\(String(format: "%6.0fK", ytd / 1000))     | \(status)")
        idx += 1
    }
    print()
}

// MARK: - Example 7: Exponential Moving Average (EMA)

func example7_ExponentialMovingAverage() async throws {
    print("=== Example 7: Exponential Moving Average (EMA) ===\n")

    // Server response times (ms)
    let responseTimes = AsyncValueStream([
        120.0, 115.0, 130.0, 125.0, 200.0,  // Spike!
        128.0, 122.0, 118.0, 121.0, 119.0
    ])

    print("Server Response Time Smoothing (α = 0.3):")
    print("Raw Time | EMA    | Difference")
    print("---------|--------|------------")

    let rawTimes = [120.0, 115.0, 130.0, 125.0, 200.0, 128.0, 122.0, 118.0, 121.0, 119.0]
    var idx = 0

    for try await ema in responseTimes.exponentialMovingAverage(alpha: 0.3) {
        let diff = rawTimes[idx] - ema
        let indicator = abs(diff) > 20 ? " ⚠ Spike" : ""
        print("\(String(format: "%6.0f", rawTimes[idx]))ms | \(String(format: "%5.1f", ema))ms | \(String(format: "%+5.1f", diff))ms\(indicator)")
        idx += 1
    }
    print()
}

// MARK: - Example 8: Comprehensive Rolling Statistics

func example8_ComprehensiveRollingStats() async throws {
    print("=== Example 8: Comprehensive Rolling Statistics ===\n")

    // Website response times
    let responseTimes = AsyncValueStream([
        45.0, 52.0, 48.0, 51.0, 150.0,  // Outlier!
        49.0, 47.0, 50.0, 46.0, 53.0
    ])

    print("Website Performance Metrics (5-request window):")
    print("Mean | StdDev | Min | Max | Status")
    print("-----|--------|-----|-----|--------")

    for try await stats in responseTimes.rollingStatistics(window: 5) {
        let status = stats.mean < 60.0 && stats.stdDev < 20.0 ? "Good ✓" :
                    stats.mean < 100.0 ? "Acceptable" :
                    "Poor ⚠"
        print("\(String(format: "%4.0f", stats.mean))ms | \(String(format: "%5.1f", stats.stdDev))ms | \(String(format: "%3.0f", stats.min))ms | \(String(format: "%3.0f", stats.max))ms | \(status)")
    }
    print()
}

// MARK: - Example 9: Comprehensive Cumulative Statistics

func example9_ComprehensiveCumulativeStats() async throws {
    print("=== Example 9: Comprehensive Cumulative Statistics ===\n")

    // Customer order values
    let orders = AsyncValueStream([150.0, 89.0, 220.0, 175.0, 95.0, 310.0, 142.0, 205.0])

    print("Cumulative Order Analytics:")
    print("Orders | Avg Order | StdDev | Min  | Max  | Total")
    print("-------|-----------|--------|------|------|-------")

    for try await stats in orders.cumulativeStatistics() {
        print("  \(stats.count)    | $\(String(format: "%6.2f", stats.mean))  | $\(String(format: "%5.2f", stats.stdDev)) | $\(String(format: "%3.0f", stats.min)) | $\(String(format: "%3.0f", stats.max)) | $\(String(format: "%5.0f", stats.sum))")
    }
    print()
}

// MARK: - Example 10: Real-World - Trading Strategy with Bollinger Bands

func example10_BollingerBands() async throws {
    print("=== Example 10: Real-World - Bollinger Bands Trading Strategy ===\n")

    // Stock prices
    let prices = AsyncValueStream([
        100.0, 102.0, 101.0, 103.0, 105.0,
        104.0, 106.0, 108.0, 107.0, 105.0,
        103.0, 104.0, 106.0, 108.0, 110.0
    ])

    print("Stock: ACME Corp (20-period Bollinger Bands)")
    print("Price  | SMA   | Upper | Lower | Signal")
    print("-------|-------|-------|-------|--------")

    let priceArray = [
        100.0, 102.0, 101.0, 103.0, 105.0,
        104.0, 106.0, 108.0, 107.0, 105.0,
        103.0, 104.0, 106.0, 108.0, 110.0
    ]
    var idx = 0

    // Bollinger Bands = SMA ± (2 * StdDev)
    for try await stats in prices.rollingStatistics(window: 5) {
        let currentPrice = priceArray[idx + 4]  // Price at end of window
        let upper = stats.mean + (2 * stats.stdDev)
        let lower = stats.mean - (2 * stats.stdDev)

        let signal: String
        if currentPrice > upper {
            signal = "SELL ↓"
        } else if currentPrice < lower {
            signal = "BUY ↑"
        } else {
            signal = "HOLD —"
        }

        print("$\(String(format: "%5.1f", currentPrice)) | $\(String(format: "%5.1f", stats.mean)) | $\(String(format: "%5.1f", upper)) | $\(String(format: "%5.1f", lower)) | \(signal)")
        idx += 1
    }
    print()
}

// MARK: - Example 11: Combining Statistics for Anomaly Detection

func example11_StatisticalAnomalyDetection() async throws {
    print("=== Example 11: Statistical Anomaly Detection ===\n")

    // Network latency measurements
    let latencies = AsyncValueStream([
        15.0, 17.0, 16.0, 18.0, 15.0,
        14.0, 16.0, 85.0,  // Anomaly!
        17.0, 16.0, 15.0
    ])

    print("Network Latency Monitoring:")
    print("Using Z-score method: |z| > 2.5 indicates anomaly\n")

    let latencyArray = [15.0, 17.0, 16.0, 18.0, 15.0, 14.0, 16.0, 85.0, 17.0, 16.0, 15.0]
    var idx = 0

    for try await stats in latencies.rollingStatistics(window: 5) {
        let currentValue = latencyArray[idx + 4]
        let zScore = (currentValue - stats.mean) / stats.stdDev

        let status: String
        if abs(zScore) > 2.5 {
            status = "🚨 ANOMALY!"
        } else if abs(zScore) > 1.5 {
            status = "⚠ Warning"
        } else {
            status = "✓ Normal"
        }

        print("Latency: \(String(format: "%5.1f", currentValue))ms | Mean: \(String(format: "%5.1f", stats.mean))ms | Z-score: \(String(format: "%+5.2f", zScore)) | \(status)")
        idx += 1
    }
    print()
}

// MARK: - Example 12: Memory Efficiency Demonstration

func example12_MemoryEfficiency() async throws {
    print("=== Example 12: Memory Efficiency with Large Streams ===\n")

    print("Processing 1,000,000 values with O(1) memory...")

    // Generate a large stream
    let largeStream = AsyncGeneratorStream {
        Double.random(in: 0...100)
    }

    var count = 0
    let startTime = Date()

    // Calculate rolling statistics - only keeps window in memory!
    for try await stats in largeStream.rollingStatistics(window: 100) {
        count += 1
        if count >= 1_000_000 {
            break
        }

        // Print progress every 100k
        if count % 100_000 == 0 {
            print("  Processed \(count / 1000)K values...")
        }
    }

    let elapsed = Date().timeIntervalSince(startTime)
    let throughput = Double(count) / elapsed

    print("✓ Completed!")
    print("  Total: \(count) statistics calculated")
    print("  Time: \(String(format: "%.2f", elapsed))s")
    print("  Throughput: \(String(format: "%.0f", throughput)) stats/sec")
    print("  Memory: O(1) - only 100-value window kept in memory\n")
}

// MARK: - Run All Examples

@main
struct StreamingStatisticsExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Streaming Statistics Examples (Phase 2.2)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_RollingMean()
        try await example2_CumulativeMean()
        try await example3_RollingVariance()
        try await example4_RollingStdDev()
        try await example5_RollingMinMax()
        try await example6_CumulativeSum()
        try await example7_ExponentialMovingAverage()
        try await example8_ComprehensiveRollingStats()
        try await example9_ComprehensiveCumulativeStats()
        try await example10_BollingerBands()
        try await example11_StatisticalAnomalyDetection()
        try await example12_MemoryEfficiency()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
