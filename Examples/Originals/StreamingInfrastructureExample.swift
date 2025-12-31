//
//  StreamingInfrastructureExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to streaming data infrastructure (Phase 2.1)
//  Learn async streams, windowing, buffering, and error handling
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Basic Stream Creation

func example1_BasicStreamCreation() async throws {
    print("=== Example 1: Basic Stream Creation ===\n")

    // Create a stream from an array
    let values = [1.0, 2.0, 3.0, 4.0, 5.0]
    let stream = AsyncValueStream(values)

    print("Processing values from stream:")
    for try await value in stream {
        print("  Received: \(value)")
    }
    print()
}

// MARK: - Example 2: Stream Generation

func example2_StreamGeneration() async throws {
    print("=== Example 2: Stream Generation ===\n")

    // Generate an infinite stream of random prices
    let priceStream = AsyncGeneratorStream {
        // Simulate stock price with random walk
        return Double.random(in: 95...105)
    }

    print("Generating 10 random stock prices:")
    var count = 0
    for try await price in priceStream {
        print("  Price \(count + 1): $\(String(format: "%.2f", price))")
        count += 1
        if count >= 10 { break }
    }
    print()
}

// MARK: - Example 3: Stream Transformation

func example3_StreamTransformation() async throws {
    print("=== Example 3: Stream Transformation ===\n")

    let sales = AsyncValueStream([100.0, 150.0, 200.0, 175.0, 225.0])

    // Transform: apply 10% discount
    let discounted = sales.map { $0 * 0.9 }

    // Filter: only sales over $150 after discount
    let significant = discounted.filter { $0 > 150.0 }

    print("Significant sales after 10% discount:")
    for try await sale in significant {
        print("  $\(String(format: "%.2f", sale))")
    }
    print()
}

// MARK: - Example 4: Tumbling Windows

func example4_TumblingWindows() async throws {
    print("=== Example 4: Tumbling Windows (Non-Overlapping) ===\n")

    // Stream of hourly transactions
    let transactions = AsyncValueStream([
        10.0, 15.0, 20.0,  // Hour 1
        25.0, 30.0, 35.0,  // Hour 2
        40.0, 45.0, 50.0   // Hour 3
    ])

    // Group into 3-transaction windows
    print("Processing tumbling windows of 3 transactions:")
    var windowNum = 1
    for try await window in transactions.tumblingWindow(size: 3) {
        let total = window.reduce(0, +)
        print("  Window \(windowNum): \(window.map { "$\($0)" }.joined(separator: ", ")) = $\(total)")
        windowNum += 1
    }
    print()
}

// MARK: - Example 5: Sliding Windows

func example5_SlidingWindows() async throws {
    print("=== Example 5: Sliding Windows (Overlapping) ===\n")

    // Stream of daily sales
    let dailySales = AsyncValueStream([100.0, 120.0, 110.0, 130.0, 125.0, 140.0])

    // 3-day moving window, sliding by 1 day
    print("3-day moving averages:")
    for try await window in dailySales.slidingWindow(size: 3, step: 1) {
        let average = window.reduce(0, +) / Double(window.count)
        print("  Days \(window.map { "$\($0)" }.joined(separator: ", ")) → Avg: $\(String(format: "%.2f", average))")
    }
    print()
}

// MARK: - Example 6: Buffering for Batch Processing

func example6_Buffering() async throws {
    print("=== Example 6: Buffering for Batch Processing ===\n")

    // Stream of individual orders
    let orders = AsyncValueStream([15.0, 20.0, 25.0, 30.0, 18.0, 22.0, 27.0, 35.0])

    // Buffer in batches of 3 for batch processing
    print("Processing orders in batches of 3:")
    var batchNum = 1
    for try await batch in orders.buffer(size: 3) {
        let batchTotal = batch.reduce(0, +)
        print("  Batch \(batchNum): \(batch.count) orders, Total: $\(batchTotal)")
        batchNum += 1
    }
    print()
}

// MARK: - Example 7: Error Handling with Retry

func example7_ErrorHandlingRetry() async throws {
    print("=== Example 7: Error Handling with Retry ===\n")

    // Simulate unreliable API calls
    var callCount = 0
    let unreliableStream = AsyncGeneratorStream<Double> {
        callCount += 1
        if callCount % 3 == 0 {
            throw NSError(domain: "NetworkError", code: 500)
        }
        return Double.random(in: 0...100)
    }

    // Retry up to 3 times on error
    let resilient = unreliableStream.retry(maxAttempts: 3)

    print("Fetching data with automatic retry:")
    var successCount = 0
    for try await value in resilient {
        print("  ✓ Received: \(String(format: "%.1f", value))")
        successCount += 1
        if successCount >= 5 { break }
    }
    print()
}

// MARK: - Example 8: Error Handling with Fallback

func example8_ErrorHandlingFallback() async throws {
    print("=== Example 8: Error Handling with Fallback ===\n")

    // Stream that might fail
    var attemptNum = 0
    let risky = AsyncGeneratorStream<Double> {
        attemptNum += 1
        if attemptNum == 3 {
            throw NSError(domain: "DataError", code: 404)
        }
        return Double(attemptNum * 10)
    }

    // Provide fallback value on error
    let safe = risky.catchErrors { error in
        print("  ⚠️  Error occurred: \(error.localizedDescription), using fallback")
        return -1.0  // Sentinel value
    }

    print("Processing with error fallback:")
    var count = 0
    for try await value in safe {
        if value == -1.0 {
            print("  Fallback value received")
        } else {
            print("  Normal value: \(value)")
        }
        count += 1
        if count >= 5 { break }
    }
    print()
}

// MARK: - Example 9: Backpressure with Throttle

func example9_Throttling() async throws {
    print("=== Example 9: Backpressure with Throttle ===\n")

    // High-frequency stream
    let rapidStream = AsyncValueStream([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

    // Throttle to at most one value per 100ms
    let throttled = rapidStream.throttle(interval: .milliseconds(100))

    print("Throttling high-frequency stream:")
    let start = ContinuousClock.now
    for try await value in throttled {
        let elapsed = (ContinuousClock.now - start).components.seconds
        print("  t=\(elapsed)s: Value \(value)")
    }
    print()
}

// MARK: - Example 10: Real-World Scenario - Live Stock Monitoring

func example10_LiveStockMonitoring() async throws {
    print("=== Example 10: Real-World - Live Stock Price Monitoring ===\n")

    // Simulate live stock price feed
    let prices = AsyncValueStream([
        100.0, 101.5, 102.0, 101.0, 103.5,
        105.0, 104.0, 106.5, 108.0, 107.0
    ])

    // Calculate 3-period moving average
    print("Stock: ACME Corp")
    print("Price | 3-Period MA | Signal")
    print("------|-------------|--------")

    for try await window in prices.slidingWindow(size: 3, step: 1) {
        let current = window.last!
        let ma = window.reduce(0, +) / 3.0
        let signal = current > ma ? "BUY ↑" : "SELL ↓"

        print("$\(String(format: "%5.1f", current)) | $\(String(format: "%6.2f", ma))     | \(signal)")
    }
    print()
}

// MARK: - Example 11: Combining Multiple Operations

func example11_CombiningOperations() async throws {
    print("=== Example 11: Combining Multiple Operations ===\n")

    // Raw sensor data stream
    let sensorData = AsyncValueStream([
        95.0, 102.0, 98.0, 450.0,  // Spike!
        101.0, 99.0, 103.0, 100.0
    ])

    print("Processing sensor data pipeline:")
    print("Step 1: Filter outliers (> 200)")
    print("Step 2: Apply calibration (*0.98)")
    print("Step 3: Calculate 3-value rolling average\n")

    let processed = sensorData
        .filter { $0 < 200.0 }              // Remove outliers
        .map { $0 * 0.98 }                   // Apply calibration
        .slidingWindow(size: 3, step: 1)    // Rolling window

    print("Results:")
    for try await window in processed {
        let avg = window.reduce(0, +) / Double(window.count)
        print("  Window: \(window.map { String(format: "%.1f", $0) }.joined(separator: ", ")) → Avg: \(String(format: "%.2f", avg))")
    }
    print()
}

// MARK: - Run All Examples

@main
struct StreamingInfrastructureExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Streaming Infrastructure Examples (Phase 2.1)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_BasicStreamCreation()
        try await example2_StreamGeneration()
        try await example3_StreamTransformation()
        try await example4_TumblingWindows()
        try await example5_SlidingWindows()
        try await example6_Buffering()
        try await example7_ErrorHandlingRetry()
        try await example8_ErrorHandlingFallback()
        try await example9_Throttling()
        try await example10_LiveStockMonitoring()
        try await example11_CombiningOperations()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}
