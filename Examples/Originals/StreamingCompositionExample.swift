//
//  StreamingCompositionExample.swift
//  BusinessMath Examples
//
//  Comprehensive guide to stream composition (Phase 2.5)
//  Learn merge, zip, debounce, throttle, and advanced stream operators
//
//  Created on December 30, 2025.
//

import Foundation
import BusinessMath

// MARK: - Example 1: Merge - Combining Multiple Data Sources

func example1_MergeStreams() async throws {
    print("=== Example 1: Merge - Combining Multiple Streams ===\n")

    print("Merging sales from two stores:")

    // Store A sales
    let storeA = AsyncValueStream([100.0, 150.0, 120.0])

    // Store B sales
    let storeB = AsyncValueStream([200.0, 180.0, 220.0])

    print("Combined sales feed:")
    var totalSales = 0.0
    for try await sale in storeA.merge(with: storeB) {
        totalSales += sale
        print("  Sale: $\(String(format: "%.0f", sale))")
    }

    print("Total: $\(String(format: "%.0f", totalSales))")
    print("\nMerge interleaves values from multiple sources\n")
}

// MARK: - Example 2: Zip - Pairing Related Streams

func example2_ZipStreams() async throws {
    print("=== Example 2: Zip - Pairing Related Streams ===\n")

    // Product prices
    let prices = AsyncValueStream([29.99, 49.99, 19.99, 99.99])

    // Quantities sold
    let quantities = AsyncValueStream([10.0, 5.0, 20.0, 3.0])

    print("Calculating revenue from price × quantity:")
    print("Price   | Qty | Revenue")
    print("--------|-----|----------")

    for try await (price, qty) in prices.zip(with: quantities) {
        let revenue = price * qty
        print("$\(String(format: "%5.2f", price)) | \(String(format: "%3.0f", qty)) | $\(String(format: "%7.2f", revenue))")
    }

    print("\nZip pairs corresponding values from two streams\n")
}

// MARK: - Example 3: CombineLatest - Reactive Updates

func example3_CombineLatest() async throws {
    print("=== Example 3: CombineLatest - Reactive Calculations ===\n")

    // Exchange rate updates
    let exchangeRates = AsyncValueStream([1.0, 1.05, 1.08, 1.06])

    // Product price updates
    let usdPrices = AsyncValueStream([100.0, 100.0, 105.0])

    print("Live currency conversion (USD to EUR):")
    print("Emits whenever either price or rate updates\n")

    var update = 1
    for try await (usdPrice, rate) in usdPrices.combineLatest(with: exchangeRates) {
        let eurPrice = usdPrice * rate
        print("Update \(update): $\(String(format: "%.0f", usdPrice)) USD × \(String(format: "%.2f", rate)) = €\(String(format: "%.0f", eurPrice)) EUR")
        update += 1
    }

    print("\nCombineLatest emits when either stream produces a value\n")
}

// MARK: - Example 4: Debounce - Search Input Handling

func example4_Debounce() async throws {
    print("=== Example 4: Debounce - Search Input Optimization ===\n")

    // Simulating rapid keystrokes: "h", "he", "hel", "hell", "hello"
    print("User typing: h-e-l-l-o (rapid keystrokes)")
    print("Debounce waits for 50ms of silence before searching\n")

    let keystrokes = AsyncDelayedStream(
        ["h", "he", "hel", "hell", "hello"],
        delay: .milliseconds(10)
    )

    print("Search queries sent:")
    for try await query in keystrokes.debounce(interval: .milliseconds(50)) {
        print("  🔍 Searching for: '\(query)'")
    }

    print("\nOnly the final complete term is searched!")
    print("Debounce reduces unnecessary API calls\n")
}

// MARK: - Example 5: Throttle - Rate Limiting

func example5_Throttle() async throws {
    print("=== Example 5: Throttle - Rate Limiting API Calls ===\n")

    // High-frequency sensor readings
    let readings = AsyncValueStream([1, 2, 3, 4, 5, 6, 7, 8, 9, 10])

    print("Sensor emits 10 readings rapidly")
    print("Throttle limits to 1 every 50ms:\n")

    let start = ContinuousClock.now
    var count = 0

    for try await value in readings.throttle(interval: .milliseconds(50)) {
        let elapsed = ContinuousClock.now - start
        let ms = elapsed.components.attoseconds / 1_000_000_000_000_000
        print("t=\(String(format: "%3d", ms))ms: Reading \(value)")
        count += 1
    }

    print("\nThrottle prevents overwhelming downstream systems\n")
}

// MARK: - Example 6: Sample - Periodic Monitoring

func example6_Sample() async throws {
    print("=== Example 6: Sample - Periodic Monitoring ===\n")

    print("Sampling high-frequency data every 20ms:")

    // Continuous stream
    let stream = AsyncGeneratorStream {
        Double.random(in: 0...100)
    }

    var samples: [Double] = []
    for try await value in stream.sample(interval: .milliseconds(20)) {
        samples.append(value)
        if samples.count >= 5 {
            break
        }
    }

    print("Collected samples:")
    for (idx, sample) in samples.enumerated() {
        print("  Sample \(idx + 1): \(String(format: "%.1f", sample))")
    }

    print("\nSample takes periodic snapshots of continuous data\n")
}

// MARK: - Example 7: Distinct - Removing Consecutive Duplicates

func example7_Distinct() async throws {
    print("=== Example 7: Distinct - Change Detection ===\n")

    // Sensor state: 1=idle, 2=active, 3=warning
    let states = AsyncValueStream([1, 1, 1, 2, 2, 3, 3, 3, 2, 2, 1])

    print("Sensor state changes (filtering consecutive duplicates):")
    print("Raw: 1-1-1-2-2-3-3-3-2-2-1\n")

    print("State transitions:")
    for try await state in states.distinct() {
        let stateStr = state == 1 ? "Idle" : state == 2 ? "Active" : "Warning"
        print("  → \(stateStr)")
    }

    print("\nDistinct only emits when value changes\n")
}

// MARK: - Example 8: Take and Skip

func example8_TakeAndSkip() async throws {
    print("=== Example 8: Take and Skip - Stream Slicing ===\n")

    let numbers = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])

    // Take first 3
    print("Take first 3:")
    var taken: [Double] = []
    for try await value in numbers.take(3) {
        taken.append(value)
    }
    print("  Result: \(taken)")

    // Skip first 7, take rest
    print("\nSkip first 7:")
    var skipped: [Double] = []
    let numbers2 = AsyncValueStream([1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0])
    for try await value in numbers2.skip(7) {
        skipped.append(value)
    }
    print("  Result: \(skipped)")

    print("\nTake/Skip slice streams by count\n")
}

// MARK: - Example 9: TakeWhile and SkipWhile

func example9_TakeWhileSkipWhile() async throws {
    print("=== Example 9: TakeWhile and SkipWhile - Conditional Slicing ===\n")

    // Stock prices
    let prices = AsyncValueStream([95.0, 98.0, 102.0, 105.0, 99.0, 103.0, 108.0, 110.0])

    print("Take while price < $100:")
    var takeResults: [Double] = []
    for try await price in prices.takeWhile({ $0 < 100.0 }) {
        takeResults.append(price)
    }
    print("  Taken: \(takeResults.map { String(format: "$%.0f", $0) }.joined(separator: ", "))")

    print("\nSkip while price < $100:")
    var skipResults: [Double] = []
    let prices2 = AsyncValueStream([95.0, 98.0, 102.0, 105.0, 99.0, 103.0, 108.0, 110.0])
    for try await price in prices2.skipWhile({ $0 < 100.0 }) {
        skipResults.append(price)
    }
    print("  Remaining: \(skipResults.map { String(format: "$%.0f", $0) }.joined(separator: ", "))")

    print("\nTakeWhile/SkipWhile use predicates\n")
}

// MARK: - Example 10: StartWith - Initial Values

func example10_StartWith() async throws {
    print("=== Example 10: StartWith - Providing Defaults ===\n")

    // Live prices (may start empty)
    let liveStream = AsyncValueStream([105.0, 108.0, 106.0])

    print("Stream with initial cached value:")

    var allPrices: [Double] = []
    for try await price in liveStream.startWith(100.0) {
        allPrices.append(price)
    }

    print("  Prices: \(allPrices.map { String(format: "$%.0f", $0) }.joined(separator: " → "))")
    print("  First value (100) was prepended\n")

    print("StartWith ensures streams always have an initial value\n")
}

// MARK: - Example 11: Real-World - Multi-Source Monitoring Dashboard

func example11_MonitoringDashboard() async throws {
    print("=== Example 11: Real-World - Monitoring Dashboard ===\n")

    print("Combining multiple data sources for real-time dashboard:\n")

    // CPU readings
    let cpuReadings = AsyncValueStream([45.0, 52.0, 48.0])

    // Memory readings
    let memoryReadings = AsyncValueStream([60.0, 65.0, 63.0])

    print("System Metrics:")
    print("CPU%  | Memory% | Status")
    print("------|---------|--------")

    for try await (cpu, memory) in cpuReadings.zip(with: memoryReadings) {
        let status = cpu > 80.0 || memory > 80.0 ? "⚠️  High" : "✓ OK"
        print("\(String(format: "%4.0f", cpu))% | \(String(format: "%6.0f", memory))%   | \(status)")
    }

    print("\nZip synchronizes multiple metric streams\n")
}

// MARK: - Example 12: Real-World - E-commerce Cart Updates

func example12_ShoppingCartUpdates() async throws {
    print("=== Example 12: Real-World - Shopping Cart with Debounce ===\n")

    print("User rapidly changes quantity: 1 → 2 → 3 → 4 → 5")
    print("Debounce prevents API spam\n")

    // Rapid quantity changes
    let quantities = AsyncDelayedStream([1, 2, 3, 4, 5], delay: .milliseconds(50))

    print("API calls made:")
    var apiCalls = 0

    for try await qty in quantities.debounce(interval: .milliseconds(200)) {
        apiCalls += 1
        print("  📡 Update cart: quantity = \(qty)")
    }

    print("\nOnly \(apiCalls) API call instead of 5!")
    print("Debounce waits for user to stop changing quantity\n")
}

// MARK: - Example 13: Real-World - Price Alert System

func example13_PriceAlertSystem() async throws {
    print("=== Example 13: Real-World - Price Alert System ===\n")

    // Stock price updates
    let prices = AsyncValueStream([
        95.0, 95.0, 96.0, 96.0, 96.0,  // No alerts
        101.0, 101.0,                   // Above $100!
        99.0, 99.0, 98.0                // Back below
    ])

    // Alert threshold
    let threshold = 100.0

    print("Price Alert: Notify when price crosses $\(String(format: "%.0f", threshold))")
    print("Using distinct to avoid duplicate alerts:\n")

    var lastAlert: String? = nil

    for try await price in prices.distinct() {
        let status = price > threshold ? "Above" : "Below"

        if status != lastAlert {
            if price > threshold {
                print("🔔 ALERT: Price is now $\(String(format: "%.0f", price)) (above threshold)")
            } else if lastAlert == "Above" {
                print("✓ Price normalized: $\(String(format: "%.0f", price))")
            }
            lastAlert = status
        }
    }

    print("\nDistinct prevents alert spam\n")
}

// MARK: - Example 14: Real-World - Live Trading Dashboard

func example14_TradingDashboard() async throws {
    print("=== Example 14: Real-World - Live Trading Dashboard ===\n")

    // Stock prices
    let stockPrices = AsyncValueStream([100.0, 102.0, 101.0, 105.0])

    // Portfolio size (shares owned)
    let sharesOwned = AsyncValueStream([10.0, 10.0, 15.0])  // Bought 5 more shares

    print("Live Portfolio Value Calculator:")
    print("Stock | Shares | Portfolio Value")
    print("------|--------|----------------")

    for try await (price, shares) in stockPrices.combineLatest(with: sharesOwned) {
        let value = price * shares
        print("$\(String(format: "%3.0f", price))  | \(String(format: "%6.0f", shares))  | $\(String(format: "%8.0f", value))")
    }

    print("\nCombineLatest keeps portfolio value always current\n")
}

// MARK: - Example 15: Chaining Multiple Operators

func example15_OperatorChaining() async throws {
    print("=== Example 15: Chaining Multiple Operators ===\n")

    // Raw sensor data
    let rawData = AsyncValueStream([
        10.0, 10.0, 11.0, 11.0, 11.0,  // Stable
        12.0, 13.0, 14.0, 15.0,         // Rising
        100.0,                          // Spike!
        16.0, 17.0, 18.0, 19.0, 20.0
    ])

    print("Processing pipeline:")
    print("1. Filter out spikes (> 50)")
    print("2. Remove consecutive duplicates")
    print("3. Take first 8 valid readings\n")

    print("Valid readings:")
    var count = 0

    for try await value in rawData
        .filter({ $0 < 50.0 })           // Remove spikes
        .distinct()                       // Remove duplicates
        .take(8) {                        // Limit output

        count += 1
        print("  \(count). \(String(format: "%.0f", value))")
    }

    print("\nOperators can be chained for complex processing\n")
}

// MARK: - Run All Examples

@main
struct StreamingCompositionExamples {
    static func main() async throws {
        print("\n" + String(repeating: "=", count: 60))
        print("Streaming Composition Examples (Phase 2.5)")
        print(String(repeating: "=", count: 60) + "\n")

        try await example1_MergeStreams()
        try await example2_ZipStreams()
        try await example3_CombineLatest()
        try await example4_Debounce()
        try await example5_Throttle()
        try await example6_Sample()
        try await example7_Distinct()
        try await example8_TakeAndSkip()
        try await example9_TakeWhileSkipWhile()
        try await example10_StartWith()
        try await example11_MonitoringDashboard()
        try await example12_ShoppingCartUpdates()
        try await example13_PriceAlertSystem()
        try await example14_TradingDashboard()
        try await example15_OperatorChaining()

        print(String(repeating: "=", count: 60))
        print("All examples completed successfully!")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Helper Types

/// AsyncSequence that emits values with a delay
struct AsyncDelayedStream<Element>: AsyncSequence {
    typealias AsyncIterator = Iterator

    private let values: [Element]
    private let delay: Duration

    init(_ values: [Element], delay: Duration) {
        self.values = values
        self.delay = delay
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values, delay: delay)
    }

    struct Iterator: AsyncIteratorProtocol {
        private var index: Int = 0
        private let values: [Element]
        private let delay: Duration

        init(values: [Element], delay: Duration) {
            self.values = values
            self.delay = delay
        }

        mutating func next() async throws -> Element? {
            guard index < values.count else { return nil }

            if index > 0 {
                try await Task.sleep(for: delay)
            }

            let value = values[index]
            index += 1
            return value
        }
    }
}
