//
//  ModelProfilerTests.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Tests for the ModelProfiler performance tracking system
///
/// Verifies that:
/// - Performance measurements are accurate
/// - Statistical calculations are correct
/// - Reports generate properly
/// - Bottleneck detection works
/// - Memory tracking functions (on supported platforms)
/// - Actor isolation is maintained
@Suite("ModelProfiler Tests")
struct ModelProfilerTests {

    // MARK: - Basic Measurement

    @Test("Measure simple operation")
    func measureSimpleOperation() async {
        let profiler = ModelProfiler()

        let result = await profiler.measure(operation: "Simple") {
            42
        }

        #expect(result == 42)

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        #expect(report.operations[0].operation == "Simple")
        #expect(report.operations[0].executionCount == 1)
    }

    @Test("Measure operation with work")
    func measureOperationWithWork() async {
        let profiler = ModelProfiler()

        let result = await profiler.measure(operation: "Calculation") {
            var sum = 0.0
            for i in 1...1000 {
                sum += Double(i)
            }
            return sum
        }

        #expect(result == 500_500.0)

        let report = await profiler.report()
        #expect(report.operations[0].totalTime > 0)
        #expect(report.operations[0].averageTime > 0)
    }

    @Test("Measure multiple operations")
    func measureMultipleOperations() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Op1") { 1 }
        await profiler.measure(operation: "Op2") { 2 }
        await profiler.measure(operation: "Op3") { 3 }

        let report = await profiler.report()
        #expect(report.operations.count == 3)
        #expect(report.totalOperations == 3)
    }

    @Test("Measure same operation multiple times")
    func measureSameOperationMultipleTimes() async {
        let profiler = ModelProfiler()

        for i in 1...5 {
            await profiler.measure(operation: "Repeated") {
                i * 2
            }
        }

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        #expect(report.operations[0].executionCount == 5)
    }

    @Test("Measure operation with category")
    func measureWithCategory() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "NPV", category: "Valuation") {
            1000.0
        }

        let report = await profiler.report()
        #expect(report.operations[0].category == "Valuation")
    }

    // MARK: - Async Measurement

    @Test("Measure async operation")
    func measureAsyncOperation() async {
        let profiler = ModelProfiler()

        let result = await profiler.measureAsync(operation: "AsyncOp") {
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            return 42
        }

        #expect(result == 42)

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        #expect(report.operations[0].averageTime >= 0.001) // At least 1ms
    }

    // MARK: - Statistics

    @Test("Statistics calculation for single measurement")
    func singleMeasurementStatistics() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Single") {
            Thread.sleep(forTimeInterval: 0.001) // 1ms
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        #expect(stats.minTime == stats.maxTime)
        #expect(stats.minTime == stats.averageTime)
        #expect(stats.medianTime == stats.averageTime)
    }

    @Test("Statistics calculation for multiple measurements")
    func multipleMeasurementStatistics() async {
        let profiler = ModelProfiler()

        // Create measurements with varying durations
        for delay in [1, 2, 3, 4, 5] {
            await profiler.measure(operation: "Varying") {
                Thread.sleep(forTimeInterval: Double(delay) / 1000.0)
            }
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        #expect(stats.executionCount == 5)
        #expect(stats.minTime < stats.maxTime)
        #expect(stats.averageTime > stats.minTime)
        #expect(stats.averageTime < stats.maxTime)
        #expect(stats.medianTime > 0)
    }

    @Test("Percentile calculations")
    func percentileCalculations() async {
        let profiler = ModelProfiler()

        // Create 100 measurements with known distribution
        for i in 1...100 {
            await profiler.measure(operation: "Distribution") {
                Thread.sleep(forTimeInterval: Double(i) / 100000.0)
                return i
            }
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        // 95th percentile should be near the 95th value
        #expect(stats.percentile95 > stats.medianTime)
        #expect(stats.percentile99 > stats.percentile95)
        #expect(stats.percentile99 <= stats.maxTime)
    }

    // MARK: - Report Generation

    @Test("Empty report")
    func emptyReport() async {
        let profiler = ModelProfiler()

        let report = await profiler.report()

        #expect(report.operations.isEmpty)
        #expect(report.totalOperations == 0)
        #expect(report.totalTime == 0)
    }

    @Test("Report formatting")
    func reportFormatting() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Test") { 42 }

        let report = await profiler.report()
        let formatted = report.formatted()

        #expect(formatted.contains("Performance Report"))
        #expect(formatted.contains("Test"))
        #expect(formatted.contains("Total Operations: 1"))
    }

    @Test("Report CSV export")
    func reportCSVExport() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Export") { 100 }

        let report = await profiler.report()
        let csv = report.asCSV()

        #expect(csv.contains("Operation,Category,Count"))
        #expect(csv.contains("Export"))
    }

    @Test("Report sorting by total time")
    func reportSortingTotalTime() async {
        let profiler = ModelProfiler()

        // Fast operation
        await profiler.measure(operation: "Fast") {
            Thread.sleep(forTimeInterval: 0.001)
        }

        // Slow operation
        await profiler.measure(operation: "Slow") {
            Thread.sleep(forTimeInterval: 0.005)
        }

        let report = await profiler.report(sortBy: .totalTime)

        // Slowest should be first
        #expect(report.operations[0].operation == "Slow")
        #expect(report.operations[1].operation == "Fast")
    }

    @Test("Report sorting by execution count")
    func reportSortingExecutionCount() async {
        let profiler = ModelProfiler()

        // Operation executed once
        await profiler.measure(operation: "Once") { 1 }

        // Operation executed multiple times
        for _ in 1...5 {
            await profiler.measure(operation: "Multiple") { 2 }
        }

        let report = await profiler.report(sortBy: .executionCount)

        #expect(report.operations[0].operation == "Multiple")
        #expect(report.operations[0].executionCount == 5)
    }

    @Test("Report filtering specific operations")
    func reportFiltering() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Op1") { 1 }
        await profiler.measure(operation: "Op2") { 2 }
        await profiler.measure(operation: "Op3") { 3 }

        let report = await profiler.report(operations: ["Op1", "Op3"])

        #expect(report.operations.count == 2)
        #expect(report.operations.contains { $0.operation == "Op1" })
        #expect(report.operations.contains { $0.operation == "Op3" })
    }

    // MARK: - Bottleneck Detection

    @Test("Detect bottlenecks with default threshold")
    func detectBottlenecksDefault() async {
        let profiler = ModelProfiler()

        // Fast operation (under threshold)
        await profiler.measure(operation: "Fast") {
            Thread.sleep(forTimeInterval: 0.01)
        }

        // Slow operation (over threshold)
        await profiler.measure(operation: "Slow") {
            Thread.sleep(forTimeInterval: 1.1)
        }

        let bottlenecks = await profiler.bottlenecks()

        #expect(bottlenecks.count == 1)
        #expect(bottlenecks[0].operation == "Slow")
    }

    @Test("Detect bottlenecks with custom threshold")
    func detectBottlenecksCustom() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Op1") {
            Thread.sleep(forTimeInterval: 0.005)
        }

        await profiler.measure(operation: "Op2") {
            Thread.sleep(forTimeInterval: 0.015)
        }

        // With 10ms threshold, only Op2 should be flagged
        let bottlenecks = await profiler.bottlenecks(threshold: 0.01)

        #expect(bottlenecks.count == 1)
        #expect(bottlenecks[0].operation == "Op2")
    }

    @Test("No bottlenecks when all operations are fast")
    func noBottlenecks() async {
        let profiler = ModelProfiler()

        for i in 1...10 {
            await profiler.measure(operation: "Fast\(i)") {
                i * 2
            }
        }

        let bottlenecks = await profiler.bottlenecks()

        #expect(bottlenecks.isEmpty)
    }

    // MARK: - Reset Functionality

    @Test("Reset all metrics")
    func resetAll() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Op1") { 1 }
        await profiler.measure(operation: "Op2") { 2 }

        var report = await profiler.report()
        #expect(report.operations.count == 2)

        await profiler.reset()

        report = await profiler.report()
        #expect(report.operations.isEmpty)
    }

    @Test("Reset specific operation")
    func resetSpecificOperation() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Keep") { 1 }
        await profiler.measure(operation: "Remove") { 2 }

        await profiler.reset(operation: "Remove")

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        #expect(report.operations[0].operation == "Keep")
    }

    // MARK: - Warning Threshold

    @Test("Custom warning threshold")
    func customWarningThreshold() async {
        var profiler = ModelProfiler()
        await profiler.setWarningThreshold(0.005) // 5ms

        await profiler.measure(operation: "Fast") {
            Thread.sleep(forTimeInterval: 0.001)
        }

        await profiler.measure(operation: "Slow") {
            Thread.sleep(forTimeInterval: 0.01)
        }

        let bottlenecks = await profiler.bottlenecks()
        #expect(bottlenecks.count == 1)
    }

    // MARK: - Error Handling

    @Test("Measure operation that throws")
    func measureThrowingOperation() async throws {
        let profiler = ModelProfiler()

        struct TestError: Error {}

        do {
            let _: Int = try await profiler.measure(operation: "Throws") {
                throw TestError()
            }
            Issue.record("Should have thrown")
        } catch {
            // Expected - error propagates through rethrows
        }

        // Operation that throws won't be recorded since rethrows propagates the error
        // This is correct behavior - we only measure successful operations
        let report = await profiler.report()
        #expect(report.operations.isEmpty)
    }

    // MARK: - Concurrent Access

    @Test("Concurrent measurements")
    func concurrentMeasurements() async {
        let profiler = ModelProfiler()

        await withTaskGroup(of: Void.self) { group in
            for i in 1...50 {
                group.addTask {
                    await profiler.measure(operation: "Concurrent\(i % 5)") {
                        Thread.sleep(forTimeInterval: 0.0001)
                    }
                }
            }
        }

        let report = await profiler.report()
        #expect(report.totalOperations == 50)
    }

    // MARK: - Memory Tracking

    @Test("Memory usage tracking")
    func memoryUsageTracking() async {
        let profiler = ModelProfiler()

        await profiler.measure(operation: "Memory") {
            // Allocate some memory
            let _ = Array(repeating: 0, count: 100_000)
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        // Memory tracking may not be available on all platforms
        // Just verify the field exists and is non-negative
        #expect(stats.totalMemory >= 0)
        #expect(stats.averageMemory >= 0)
    }

    // MARK: - Integration Tests

    @Test("Complete profiling workflow")
    func completeWorkflow() async {
        let profiler = ModelProfiler()

        // Simulate a financial model execution
        await profiler.measure(operation: "LoadData", category: "IO") {
            Thread.sleep(forTimeInterval: 0.002)
        }

        for _ in 1...10 {
            await profiler.measure(operation: "Calculate", category: "Core") {
                var sum = 0.0
                for i in 1...1000 {
                    sum += Double(i)
                }
                return sum
            }
        }

        await profiler.measure(operation: "SaveResults", category: "IO") {
            Thread.sleep(forTimeInterval: 0.001)
        }

        let report = await profiler.report()
        #expect(report.operations.count == 3)
        #expect(report.totalOperations == 12)

        let ioOps = report.operations.filter { $0.category == "IO" }
        #expect(ioOps.count == 2)
    }
}

