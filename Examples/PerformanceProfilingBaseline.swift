//
//  PerformanceProfilingBaseline.swift
//  BusinessMath Examples
//
//  Created on December 2, 2025.
//
//  This script establishes a performance baseline for BusinessMath library
//  using the ModelProfiler built in Phase 2. It measures common operations
//  and identifies optimization opportunities.

import Foundation
@preconcurrency import BusinessMath

/// Performance Profiling Baseline
///
/// Measures and reports performance for:
/// 1. NPV calculations (varying cash flow counts)
/// 2. IRR calculations
/// 3. Monte Carlo simulations
/// 4. Time series operations
/// 5. Template-based model creation
/// 6. Real Estate investment calculations (new!)
@main
struct PerformanceProfilingBaseline {

    static func main() async throws {
        print("=== BusinessMath Performance Profiling Baseline ===")
        print("Date: \(Date())")
        print("Using ModelProfiler from Phase 2\n")

        let profiler = ModelProfiler()

        // MARK: - 1. NPV Calculations
        print("📊 Profiling NPV Calculations...")

        // Small dataset (10 periods)
        let smallCashFlows = Array(repeating: 10_000.0, count: 10)
        _ = await profiler.measure(operation: "NPV - 10 periods", category: "NPV") { @Sendable in
            npv(discountRate: 0.08, cashFlows: smallCashFlows)
        }

        // Medium dataset (100 periods)
        let mediumCashFlows = Array(repeating: 10_000.0, count: 100)
        _ = await profiler.measure(operation: "NPV - 100 periods", category: "NPV") { @Sendable in
            npv(discountRate: 0.08, cashFlows: mediumCashFlows)
        }

        // Large dataset (1000 periods)
        let largeCashFlows = Array(repeating: 10_000.0, count: 1000)
        _ = await profiler.measure(operation: "NPV - 1000 periods", category: "NPV") { @Sendable in
            npv(discountRate: 0.08, cashFlows: largeCashFlows)
        }

        print("  ✓ NPV profiling complete\n")

        // MARK: - 2. IRR Calculations
        print("📊 Profiling IRR Calculations...")

        // Typical cash flows with initial investment
        let irrCashFlows = [-100_000.0, 20_000.0, 30_000.0, 40_000.0, 50_000.0, 60_000.0]
        _ = await profiler.measure(operation: "IRR - 6 periods", category: "IRR") { @Sendable in
            try? irr(cashFlows: irrCashFlows)
        }

        // Longer project (20 periods)
        let longProjectCF = [-500_000.0] + Array(repeating: 50_000.0, count: 19)
        _ = await profiler.measure(operation: "IRR - 20 periods", category: "IRR") { @Sendable in
            try? irr(cashFlows: longProjectCF)
        }

        print("  ✓ IRR profiling complete\n")

        // MARK: - 3. Monte Carlo Simulations
        print("📊 Profiling Monte Carlo Simulations...")

        // Small simulation (100 iterations)
        _ = try await profiler.measureAsync(operation: "Monte Carlo - 100 iterations", category: "Simulation") { @Sendable in
            let simulation = MonteCarloSimulation(iterations: 100) { inputs in
                let randomReturn = Double.random(in: -0.2...0.3)
                return 100_000 * (1 + randomReturn)
            }
            return try simulation.run()
        }

        // Medium simulation (1,000 iterations)
        _ = try await profiler.measureAsync(operation: "Monte Carlo - 1,000 iterations", category: "Simulation") { @Sendable in
            let simulation = MonteCarloSimulation(iterations: 1_000) { inputs in
                let randomReturn = Double.random(in: -0.2...0.3)
                return 100_000 * (1 + randomReturn)
            }
            return try simulation.run()
        }

        // Large simulation (10,000 iterations)
        _ = try await profiler.measureAsync(operation: "Monte Carlo - 10,000 iterations", category: "Simulation") { @Sendable in
            let simulation = MonteCarloSimulation(iterations: 10_000) { inputs in
                let randomReturn = Double.random(in: -0.2...0.3)
                return 100_000 * (1 + randomReturn)
            }
            return try simulation.run()
        }

        print("  ✓ Monte Carlo profiling complete\n")

        // MARK: - 4. Time Series Operations
        print("📊 Profiling Time Series Operations...")

        let periods = (1...100).map { Period.month(year: 2025, month: $0 % 12 + 1) }
        let values = (1...100).map { _ in Double.random(in: 10_000...50_000) }

        _ = await profiler.measure(operation: "TimeSeries creation - 100 periods", category: "TimeSeries") { @Sendable in
            TimeSeries(periods: periods, values: values)
        }

        let ts = TimeSeries(periods: periods, values: values)

        _ = await profiler.measure(operation: "TimeSeries operations (sum/mean)", category: "TimeSeries") { @Sendable in
            let sum = ts.reduce(0.0, +)
            let mean = sum / Double(ts.periods.count)
            return (sum, mean)
        }

        print("  ✓ Time Series profiling complete\n")

        // MARK: - 5. Template-Based Model Creation
        print("📊 Profiling Template Operations...")

        let saasTemplate = SaaSTemplate()
        let saasParams: [String: Any] = [
            "initialMRR": 50_000.0,
            "churnRate": 0.05,
            "newCustomersPerMonth": 200.0,
            "averageRevenuePerUser": 99.0
        ]

        // Note: Skipping template creation profiling due to Sendable constraints with [String: Any]
        // Template creation is typically very fast (<1ms)

        if let saasModel = try? saasTemplate.create(parameters: saasParams) as? SaaSModel {
            _ = await profiler.measure(operation: "SaaS template - project 12 months", category: "Templates") { @Sendable in
                saasModel.project(months: 12)
            }

            _ = await profiler.measure(operation: "SaaS template - calculate LTV", category: "Templates") { @Sendable in
                saasModel.calculateLTV()
            }
        }

        print("  ✓ Template profiling complete\n")

        // MARK: - 6. Real Estate Investment Calculations (NEW!)
        print("📊 Profiling Real Estate Operations...")

        let realEstateTemplate = RealEstateTemplate()
        let reParams: [String: Any] = [
            "purchasePrice": 500_000.0,
            "downPaymentPercentage": 0.25,
            "interestRate": 0.055,
            "loanTermYears": 30.0,
            "annualRent": 36_000.0,
            "annualOperatingExpenses": 12_000.0,
            "annualAppreciationRate": 0.03
        ]

        // Note: Skipping template creation profiling due to Sendable constraints with [String: Any]
        // Template creation is typically very fast (<1ms)

        if let reModel = try? realEstateTemplate.create(parameters: reParams) as? RealEstateModel {
            _ = await profiler.measure(operation: "Real Estate - cash flow projection (10 years)", category: "Real Estate") { @Sendable in
                reModel.projectCashFlow(years: 10)
            }

            _ = await profiler.measure(operation: "Real Estate - IRR calculation", category: "Real Estate") { @Sendable in
                reModel.calculateIRR(holdingPeriodYears: 10)
            }

            _ = await profiler.measure(operation: "Real Estate - year 5 metrics", category: "Real Estate") { @Sendable in
                let _ = reModel.afterTaxCashFlow(year: 5)
                let _ = reModel.propertyValue(atYear: 5)
                let _ = reModel.equity(atYear: 5)
            }
        }

        print("  ✓ Real Estate profiling complete\n")

        // MARK: - Generate Performance Report
        print("=== Performance Report ===\n")

        let report = await profiler.report(sortBy: .averageTime)
        print(report.formatted())

        // MARK: - Identify Bottlenecks
        print("\n=== Performance Bottlenecks ===\n")

        let bottlenecks = await profiler.bottlenecks(threshold: 0.010) // 10ms threshold
        if bottlenecks.isEmpty {
            print("✓ No significant bottlenecks detected (all operations < 10ms)\n")
        } else {
            print("Operations exceeding 10ms threshold:")
            for bottleneck in bottlenecks {
                print("  ⚠️  \(bottleneck.operation)")
                print("      Average: \(String(format: "%.3f", bottleneck.averageTime * 1000))ms")
                print("      Max: \(String(format: "%.3f", bottleneck.maxTime * 1000))ms")
                print("      Executions: \(bottleneck.executionCount)\n")
            }
        }

        // MARK: - Performance Targets & Recommendations
        print("=== Performance Targets & Analysis ===\n")

        print("Target Performance (Recommended):")
        print("  • NPV calculation: <10ms")
        print("  • IRR calculation: <50ms")
        print("  • Monte Carlo (10k): <500ms")
        print("  • Template creation: <5ms")
        print("  • Time series ops: <5ms\n")

        let npvOperations = report.operations.filter { $0.operation.contains("NPV") }
        let irrOperations = report.operations.filter { $0.operation.contains("IRR") }
        let mcOperations = report.operations.filter { $0.operation.contains("Monte Carlo") }

        print("Current Performance Summary:")
        if !npvOperations.isEmpty {
            let avgNPV = npvOperations.map { $0.averageTime }.reduce(0, +) / Double(npvOperations.count)
            print("  NPV: \(String(format: "%.3f", avgNPV * 1000))ms avg \(avgNPV < 0.010 ? "✓" : "⚠️")")
        }
        if !irrOperations.isEmpty {
            let avgIRR = irrOperations.map { $0.averageTime }.reduce(0, +) / Double(irrOperations.count)
            print("  IRR: \(String(format: "%.3f", avgIRR * 1000))ms avg \(avgIRR < 0.050 ? "✓" : "⚠️")")
        }
        if !mcOperations.isEmpty {
            let mc10k = mcOperations.first { $0.operation.contains("10,000") }
            if let mc = mc10k {
                print("  Monte Carlo (10k): \(String(format: "%.0f", mc.averageTime * 1000))ms \(mc.averageTime < 0.500 ? "✓" : "⚠️")")
            }
        }

        // MARK: - Export Results
        print("\n=== Exporting Results ===\n")

        let csvReport = await profiler.report().asCSV()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let csvFile = documentsPath.appendingPathComponent("performance_baseline_\(Date().timeIntervalSince1970).csv")

        try csvReport.write(to: csvFile, atomically: true, encoding: .utf8)
        print("✓ Baseline results exported to:")
        print("  \(csvFile.path)\n")

        print("=== Profiling Complete ===")
        print("\nNext Steps:")
        print("  1. Review bottlenecks (if any)")
        print("  2. Compare against targets")
        print("  3. Identify optimization opportunities")
        print("  4. Re-run after optimizations to measure improvement\n")
    }
}
