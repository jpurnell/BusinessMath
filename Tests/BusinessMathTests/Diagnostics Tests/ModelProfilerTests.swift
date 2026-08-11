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
///
/// ## Where the durations come from
///
/// Tests that assert on a *duration* — sorting, thresholds, statistics, percentiles —
/// inject a ``ManualElapsedTimeSource`` and advance it inside the measured block, so the
/// measurement reports the duration the test named. They used to sleep for it, which sets
/// a floor on elapsed time and no ceiling: under load a block that slept 1 ms could outlast
/// one that slept 50 ms, and two of these tests flipped for exactly that reason. None of
/// those tests was ever a claim about how long the machine took.
///
/// `measureOperationWithWork` is the exception and stays on the real clock; see the note
/// there.
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

    /// Deliberately left on the real monotonic source.
    ///
    /// Every other timing assertion here supplies its own durations, which means none of
    /// them would notice if the default source stopped advancing. This one would: it is
    /// the claim that real work, measured by a profiler nobody configured, registers a
    /// duration above zero. A manual source would turn that into a tautology.
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

        #expect(abs(result - 500_500.0) < 1e-6)

        let report = await profiler.report()
        #expect(report.operations[0].totalTime > 0)
        #expect(report.operations[0].averageTime > 0)
    }

    @Test("Measure multiple operations")
    func measureMultipleOperations() async {
        let profiler = ModelProfiler()

        let _ = await profiler.measure(operation: "Op1") { 1 }
		let _ = await profiler.measure(operation: "Op2") { 2 }
		let _ = await profiler.measure(operation: "Op3") { 3 }

        let report = await profiler.report()
        #expect(report.operations.count == 3)
        #expect(report.totalOperations == 3)
    }

    @Test("Measure same operation multiple times")
    func measureSameOperationMultipleTimes() async {
        let profiler = ModelProfiler()

        for i in 1...5 {
			let _ = await profiler.measure(operation: "Repeated") {
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

		let _ = await profiler.measure(operation: "NPV", category: "Valuation") {
            1000.0
        }

        let report = await profiler.report()
        #expect(report.operations[0].category == "Valuation")
    }

    // MARK: - Async Measurement

    @Test("Measure async operation")
    func measureAsyncOperation() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        let result = await profiler.measureAsync(operation: "AsyncOp") {
            await Task.yield()
            time.advance(by: .milliseconds(1))
            return 42
        }

        #expect(result == 42)

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        // Was: sleep 1ms and assert "at least 1ms", which a slow machine could only
        // overshoot. The same lower bound holds, and now an upper one does too.
        #expect(report.operations[0].averageTime >= 0.001)
        #expect(report.operations[0].averageTime < 0.002)
    }

    // MARK: - Statistics

    @Test("Statistics calculation for single measurement")
    func singleMeasurementStatistics() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        await profiler.measure(operation: "Single") {
            time.advance(by: .milliseconds(1))
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        #expect(stats.minTime == stats.maxTime)
        #expect(stats.minTime == stats.averageTime)
        #expect(stats.medianTime == stats.averageTime)
        // The value they all agree on is now known, not merely self-consistent.
        #expect(abs(stats.minTime - 0.001) < 1e-12)
    }

    @Test("Statistics calculation for multiple measurements")
    func multipleMeasurementStatistics() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        // Create measurements with varying durations
        for delay in [1, 2, 3, 4, 5] {
            await profiler.measure(operation: "Varying") {
                time.advance(by: .milliseconds(delay))
            }
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        #expect(stats.executionCount == 5)
        #expect(stats.minTime < stats.maxTime)
        #expect(stats.averageTime > stats.minTime)
        #expect(stats.averageTime < stats.maxTime)
        #expect(stats.medianTime > 0)
        // 1, 2, 3, 4, 5 ms: the ordering claims above, plus the values they order.
        #expect(abs(stats.minTime - 0.001) < 1e-12)
        #expect(abs(stats.maxTime - 0.005) < 1e-12)
        #expect(abs(stats.averageTime - 0.003) < 1e-12)
        #expect(abs(stats.medianTime - 0.003) < 1e-12)
        #expect(abs(stats.totalTime - 0.015) < 1e-12)
    }

    @Test("Percentile calculations")
    func percentileCalculations() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        // Create 100 measurements with known distribution: 10µs, 20µs, ... 1ms.
        // The same ramp the sleeps described, now actually delivered.
        for i in 1...100 {
			let _ = await profiler.measure(operation: "Distribution") {
                time.advance(by: .microseconds(i * 10))
                return i
            }
        }

        let report = await profiler.report()
        let stats = report.operations[0]

        // 95th percentile should be near the 95th value
        #expect(stats.percentile95 > stats.medianTime)
        #expect(stats.percentile99 > stats.percentile95)
        #expect(stats.percentile99 <= stats.maxTime)

        // The distribution the ramp defines, which sleeping never guaranteed.
        #expect(abs(stats.minTime - 0.000_01) < 1e-12)
        #expect(abs(stats.maxTime - 0.001) < 1e-12)
        #expect(abs(stats.medianTime - 0.000_505) < 1e-12) // mean of the 50th and 51st
        #expect(stats.percentile95 >= 0.000_95)
        #expect(stats.percentile99 >= 0.000_99)
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

		let _ = await profiler.measure(operation: "Test") { 42 }

        let report = await profiler.report()
        let formatted = report.formatted()

        #expect(formatted.contains("Performance Report"))
        #expect(formatted.contains("Test"))
        #expect(formatted.contains("Total Operations: 1"))
    }

    @Test("Report CSV export")
    func reportCSVExport() async {
        let profiler = ModelProfiler()

		let _ = await profiler.measure(operation: "Export") { 100 }

        let report = await profiler.report()
        let csv = report.asCSV()

        #expect(csv.contains("Operation,Category,Count"))
        #expect(csv.contains("Export"))
    }

    @Test("Report sorting by total time")
    func reportSortingTotalTime() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        // Fast operation
        await profiler.measure(operation: "Fast") {
            time.advance(by: .milliseconds(1))
        }

        // Slow operation
        await profiler.measure(operation: "Slow") {
            time.advance(by: .milliseconds(50))
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
		let _ = await profiler.measure(operation: "Once") { 1 }

        // Operation executed multiple times
        for _ in 1...5 {
			let _ = await profiler.measure(operation: "Multiple") { 2 }
        }

        let report = await profiler.report(sortBy: .executionCount)

        #expect(report.operations[0].operation == "Multiple")
        #expect(report.operations[0].executionCount == 5)
    }

    @Test("Report filtering specific operations")
    func reportFiltering() async {
        let profiler = ModelProfiler()

		let _ = await profiler.measure(operation: "Op1") { 1 }
		let _ = await profiler.measure(operation: "Op2") { 2 }
		let _ = await profiler.measure(operation: "Op3") { 3 }

        let report = await profiler.report(operations: ["Op1", "Op3"])

        #expect(report.operations.count == 2)
        #expect(report.operations.contains { $0.operation == "Op1" })
        #expect(report.operations.contains { $0.operation == "Op3" })
    }

    // MARK: - Bottleneck Detection

    @Test("Detect bottlenecks with default threshold")
    func detectBottlenecksDefault() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        // Fast operation (under the 1s default threshold)
        await profiler.measure(operation: "Fast") {
            time.advance(by: .milliseconds(10))
        }

        // Slow operation (over it) — no longer at the cost of a real 1.1s wait
        await profiler.measure(operation: "Slow") {
            time.advance(by: .milliseconds(1_100))
        }

        let bottlenecks = await profiler.bottlenecks()

        #expect(bottlenecks.count == 1)
        #expect(bottlenecks[0].operation == "Slow")
    }

    @Test("Detect bottlenecks with custom threshold")
    func detectBottlenecksCustom() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        await profiler.measure(operation: "Op1") {
            // Intentionally no advance — this operation takes exactly zero
            let _ = (0..<100).reduce(0, +)
        }

        await profiler.measure(operation: "Op2") {
            time.advance(by: .milliseconds(100))
        }

        // With 50ms threshold, only Op2 (100ms exactly) should be flagged
        let bottlenecks = await profiler.bottlenecks(threshold: 0.05)

        #expect(bottlenecks.count == 1)
        #expect(bottlenecks[0].operation == "Op2")
    }

    @Test("No bottlenecks when all operations are fast")
    func noBottlenecks() async {
        let profiler = ModelProfiler()

        for i in 1...10 {
			let _ = await profiler.measure(operation: "Fast\(i)") {
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

		let _ = await profiler.measure(operation: "Op1") { 1 }
		let _ = await profiler.measure(operation: "Op2") { 2 }

        var report = await profiler.report()
        #expect(report.operations.count == 2)

        await profiler.reset()

        report = await profiler.report()
        #expect(report.operations.isEmpty)
    }

    @Test("Reset specific operation")
    func resetSpecificOperation() async {
        let profiler = ModelProfiler()

		let _ = await profiler.measure(operation: "Keep") { 1 }
		let _ = await profiler.measure(operation: "Remove") { 2 }

        await profiler.reset(operation: "Remove")

        let report = await profiler.report()
        #expect(report.operations.count == 1)
        #expect(report.operations[0].operation == "Keep")
    }

    // MARK: - Warning Threshold

	@Test("Custom warning threshold")
    func customWarningThreshold() async {
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)
        await profiler.setWarningThreshold(0.050) // 50ms

        await profiler.measure(operation: "Fast") {
            time.advance(by: .milliseconds(1))
        }

        await profiler.measure(operation: "Slow") {
            time.advance(by: .milliseconds(100))
        }

        // The threshold now sits between two durations the test chose, rather than
        // between two sleeps whose order the scheduler was free to reverse.
        let bottlenecks = await profiler.bottlenecks()
        #expect(bottlenecks.count == 1)
        #expect(bottlenecks[0].operation == "Slow")
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
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        await withTaskGroup(of: Void.self) { group in
            for i in 1...50 {
                group.addTask {
                    await profiler.measure(operation: "Concurrent\(i % 5)") {
                        time.advance(by: .milliseconds(1))
                    }
                }
            }
        }

        let report = await profiler.report()
        #expect(report.totalOperations == 50)
        // Fifty tasks contending on one shared source, and every measurement still
        // brackets exactly its own advance: none lost, none double-counted. The old
        // sleep produced contention but no way to check what the contention did.
        #expect(abs(report.totalTime - 0.050) < 1e-9)
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
        let time = ManualElapsedTimeSource()
        let profiler = ModelProfiler(elapsedTime: time)

        // Simulate a financial model execution
        await profiler.measure(operation: "LoadData", category: "IO") {
            time.advance(by: .milliseconds(2))
        }

        for _ in 1...10 {
			let _ = await profiler.measure(operation: "Calculate", category: "Core") {
                var sum = 0.0
                for i in 1...1000 {
                    sum += Double(i)
                }
                return sum
            }
        }

        await profiler.measure(operation: "SaveResults", category: "IO") {
            time.advance(by: .milliseconds(1))
        }

        let report = await profiler.report()
        #expect(report.operations.count == 3)
        #expect(report.totalOperations == 12)

        let ioOps = report.operations.filter { $0.category == "IO" }
        #expect(ioOps.count == 2)
        // The IO half of the workflow cost 2ms + 1ms; the compute half, being pure
        // computation against a manual source, cost nothing.
        #expect(abs(ioOps.reduce(0) { $0 + $1.totalTime } - 0.003) < 1e-12)
        #expect(abs(report.totalTime - 0.003) < 1e-12)
    }
}

