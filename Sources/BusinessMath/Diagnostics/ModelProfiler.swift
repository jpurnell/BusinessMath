//
//  ModelProfiler.swift
//  BusinessMath
//
//  Created on December 2, 2025.
//

import Foundation

#if canImport(OSLog)
import OSLog
#endif

// MARK: - Model Profiler

/// Performance profiling tool for financial models
///
/// The ModelProfiler provides comprehensive performance tracking and analysis
/// for financial calculations with minimal overhead (target ≤5%). It integrates
/// with Apple's Instruments via signposts for detailed timeline analysis.
///
/// ## Features
///
/// - **Performance Measurement**: Track execution time for calculations
/// - **Memory Usage**: Monitor memory footprint of operations
/// - **Statistical Analysis**: Compute mean, median, percentiles of timings
/// - **Signpost Integration**: Visualize performance in Instruments
/// - **Bottleneck Detection**: Identify slow operations automatically
///
/// ## Example Usage
///
/// ```swift
/// let profiler = ModelProfiler()
///
/// // Profile a calculation
/// let result = profiler.measure(operation: "NPV Calculation") {
///     calculateNPV(cashFlows: flows, discountRate: 0.08)
/// }
///
/// // Get performance report
/// let report = profiler.report()
/// print(report.number())
/// ```
public actor ModelProfiler {

    /// Performance metrics for an operation
    private var metrics: [String: [PerformanceMetric]] = [:]

    /// Logger for performance tracking
    /// Disabled in DEBUG builds (including playgrounds) to avoid OSLog linking issues
    #if canImport(OSLog) && !DEBUG
    private let logger = Logger.performance
    #endif

    /// Performance threshold for warnings (in seconds)
    private var warningThreshold: TimeInterval = 1.0

    /// Initialize a new profiler
    public init() {}

    // MARK: - Performance Measurement

    /// Measure the performance of an operation
    ///
    /// Executes the operation and records timing, memory usage, and other metrics.
    ///
    /// - Parameters:
    ///   - operation: Name of the operation being measured
    ///   - category: Optional category for grouping
    ///   - block: The operation to measure
    ///
    /// - Returns: The result of the operation
    ///
    /// Example:
    /// ```swift
    /// let npv = await profiler.measure(operation: "NPV") {
    ///     calculateNPV(flows, rate: 0.08)
    /// }
    /// ```
	public func measure<T: Sendable>(
        operation: String,
        category: String? = nil,
        block: @Sendable () throws -> T
    ) rethrows -> T {
        let start = Date()
        let startMemory = currentMemoryUsage()

        let result = try block()

        let duration = Date().timeIntervalSince(start)
        let endMemory = currentMemoryUsage()
        let memoryDelta = endMemory - startMemory

        let metric = PerformanceMetric(
            operation: operation,
            category: category,
            duration: duration,
            memoryUsed: memoryDelta,
            timestamp: start
        )

        // Store metric
        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(metric)

        // Log warning if slow
        if duration > warningThreshold {
            #if canImport(OSLog) && !DEBUG
            logger.performanceWarning(operation, duration: duration, threshold: warningThreshold)
            #endif
        } else {
            #if canImport(OSLog) && !DEBUG
            logger.performance(operation, duration: duration)
            #endif
        }

        return result
    }

    /// Measure an async operation
    ///
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - category: Optional category
    ///   - block: Async operation to measure
    ///
    /// - Returns: Result of the operation
	public func measureAsync<T: Sendable>(
        operation: String,
        category: String? = nil,
        block: @Sendable () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        let startMemory = currentMemoryUsage()

        let result = try await block()

        let duration = Date().timeIntervalSince(start)
        let endMemory = currentMemoryUsage()
        let memoryDelta = endMemory - startMemory

        let metric = PerformanceMetric(
            operation: operation,
            category: category,
            duration: duration,
            memoryUsed: memoryDelta,
            timestamp: start
        )

        if metrics[operation] == nil {
            metrics[operation] = []
        }
        metrics[operation]?.append(metric)

        if duration > warningThreshold {
            #if canImport(OSLog) && !DEBUG
            logger.performanceWarning(operation, duration: duration, threshold: warningThreshold)
            #endif
        }

        return result
    }

    // MARK: - Reporting

    /// Generate a comprehensive performance report
    ///
    /// - Parameters:
    ///   - operations: Specific operations to include (nil = all)
    ///   - sortBy: How to sort the results
    ///
    /// - Returns: Performance report with statistics
    public func report(
        operations: [String]? = nil,
        sortBy: ReportSortOption = .totalTime
    ) -> PerformanceReport {
        let operationsToInclude = operations ?? Array(metrics.keys)

        var operationStats: [OperationStatistics] = []

        for operation in operationsToInclude {
            guard let measurements = metrics[operation], !measurements.isEmpty else {
                continue
            }

            let durations = measurements.map { $0.duration }
            let memoryUsages = measurements.map { $0.memoryUsed }
			let percentiles = try? Percentiles(values: durations)

            let stats = OperationStatistics(
                operation: operation,
                category: measurements.first?.category,
                executionCount: measurements.count,
                totalTime: durations.reduce(0, +),
                averageTime: average(durations),
				stdDevTime: stdDev(durations),
                minTime: durations.min() ?? 0,
                maxTime: durations.max() ?? 0,
                medianTime: median(durations),
                percentile95: percentiles?.p95 ?? 0,
				percentile99: percentiles?.p99 ?? 0,
                totalMemory: memoryUsages.reduce(0, +),
                averageMemory: memoryUsages.reduce(0, +) / Int64(memoryUsages.count)
            )

            operationStats.append(stats)
        }

        // Sort results
        switch sortBy {
        case .totalTime:
            operationStats.sort { $0.totalTime > $1.totalTime }
        case .averageTime:
            operationStats.sort { $0.averageTime > $1.averageTime }
        case .executionCount:
            operationStats.sort { $0.executionCount > $1.executionCount }
        case .maxTime:
            operationStats.sort { $0.maxTime > $1.maxTime }
        }

        return PerformanceReport(
            operations: operationStats,
            totalOperations: operationStats.reduce(0) { $0 + $1.executionCount },
            totalTime: operationStats.reduce(0) { $0 + $1.totalTime },
            timestamp: Date()
        )
    }

    /// Get bottlenecks (slowest operations)
    ///
    /// - Parameter threshold: Minimum duration in seconds
    /// - Returns: List of slow operations
    public func bottlenecks(threshold: TimeInterval? = nil) -> [OperationStatistics] {
        let effectiveThreshold = threshold ?? warningThreshold
        let report = self.report()

        return report.operations.filter { $0.averageTime > effectiveThreshold }
    }

    /// Reset all collected metrics
    public func reset() {
        metrics.removeAll()
    }

    /// Reset metrics for a specific operation
    ///
    /// - Parameter operation: Name of operation to reset
    public func reset(operation: String) {
        metrics.removeValue(forKey: operation)
    }
	
	public func setWarningThreshold(_ threshold: TimeInterval) async {
		self.warningThreshold = threshold
	}

    // MARK: - Statistics Helpers

    private func average(_ values: [TimeInterval]) -> TimeInterval {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func stdDev(_ values: [TimeInterval]) -> TimeInterval {
        guard values.count > 1 else { return 0 }
        let avg = average(values)
        let variance = values.reduce(0) { $0 + pow($1 - avg, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }

    private func currentMemoryUsage() -> Int64 {
        // Memory tracking using Mach APIs can crash in Swift Playgrounds
        // Disable it to ensure stability in playground environments
        #if DEBUG
        // In debug/playground mode, skip memory tracking to avoid crashes
        return 0
        #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return 0
        }

        return Int64(info.resident_size)
        #else
        return 0  // Memory tracking not available on Linux
        #endif
    }
}

// MARK: - Performance Metric

/// A single performance measurement
public struct PerformanceMetric: Sendable {
    /// Name of the operation
    public let operation: String

    /// Optional category for grouping
    public let category: String?

    /// Duration of execution
    public let duration: TimeInterval

    /// Memory used during operation (in bytes)
    public let memoryUsed: Int64

    /// When the measurement was taken
    public let timestamp: Date
}

// MARK: - Operation Statistics

/// Statistical summary of an operation's performance
public struct OperationStatistics: Sendable {
    /// Operation name
    public let operation: String

    /// Optional category
    public let category: String?

    /// Number of times executed
    public let executionCount: Int

    /// Total time across all executions
    public let totalTime: TimeInterval

    /// Average execution time
    public let averageTime: TimeInterval
	
	/// Std Deviation execution Time
	public let stdDevTime: TimeInterval
    /// Fastest execution
    public let minTime: TimeInterval

    /// Slowest execution
    public let maxTime: TimeInterval

    /// Median execution time
    public let medianTime: TimeInterval

    /// 95th percentile time
    public let percentile95: TimeInterval

    /// 99th percentile time
    public let percentile99: TimeInterval

    /// Total memory used
    public let totalMemory: Int64

    /// Average memory per execution
    public let averageMemory: Int64
}

// MARK: - Performance Report

/// Comprehensive performance report
public struct PerformanceReport: Sendable {
    /// Statistics for each operation
    public let operations: [OperationStatistics]

    /// Total number of operations measured
    public let totalOperations: Int

    /// Total time across all operations
    public let totalTime: TimeInterval

    /// When the report was generated
    public let timestamp: Date

    /// Format as human-readable text
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public func formatted() -> String {
        var output = "=== Performance Report ===\n"
        output += "Generated: \(timestamp)\n"
        output += "Total Operations: \(totalOperations)\n"
		output += "Total Time: \(totalTime.number())s\n\n"

        if operations.isEmpty {
            output += "No operations recorded.\n"
            return output
        }

        // Header row with proper padding
        let opHeader = "Operation".padding(toLength: 40, withPad: " ", startingAt: 0)
        let countHeader = "Count".padding(toLength: 8, withPad: " ", startingAt: 0)
        let totalHeader = "Total".padding(toLength: 12, withPad: " ", startingAt: 0)
        let avgHeader = "Avg".padding(toLength: 12, withPad: " ", startingAt: 0)
        let minHeader = "Min".padding(toLength: 12, withPad: " ", startingAt: 0)
        let maxHeader = "Max".padding(toLength: 12, withPad: " ", startingAt: 0)

        output += "\(opHeader) \(countHeader) \(totalHeader) \(avgHeader) \(minHeader) \(maxHeader)\n"
        output += String(repeating: "-", count: 97) + "\n"

        for op in operations {
			let opName = "\(op.operation.padding(toLength: 40, withPad: " ", startingAt: 0))"
			let count = "\(Double(op.executionCount).number(0).padding(toLength: 8, withPad: " ", startingAt: 0))"
			let total = "\(op.totalTime.number().padding(toLength: 12, withPad: " ", startingAt: 0))"
			let avg = "\(op.averageTime.number().padding(toLength: 12, withPad: " ", startingAt: 0))"
			let min = "\(op.minTime.number().padding(toLength: 12, withPad: " ", startingAt: 0))"
			let max = "\(op.maxTime.number().padding(toLength: 12, withPad: " ", startingAt: 0))"

			output += "\(opName) \(count) \(total) \(avg) \(min) \(max)\n"
        }

        return output
    }

    /// Format as CSV for export
    public func asCSV() -> String {
        var csv = "Operation,Category,Count,TotalTime,AvgTime,StdDevTime,MinTime,MaxTime,MedianTime,P95,P99,TotalMemory,AvgMemory\n"

        for op in operations {
            csv += "\(op.operation),"
            csv += "\(op.category ?? ""),"
            csv += "\(op.executionCount),"
            csv += "\(op.totalTime),"
            csv += "\(op.averageTime),"
			csv += "\(op.stdDevTime),"
            csv += "\(op.minTime),"
            csv += "\(op.maxTime),"
            csv += "\(op.medianTime),"
            csv += "\(op.percentile95),"
            csv += "\(op.percentile99),"
            csv += "\(op.totalMemory),"
            csv += "\(op.averageMemory)\n"
        }

        return csv
    }
}

// MARK: - Report Sorting

/// Options for sorting performance reports
public enum ReportSortOption: Sendable {
    case totalTime
    case averageTime
    case executionCount
    case maxTime
}
