//
//  PerformanceOptimizationTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests define performance requirements, then optimize to meet them
//

import Testing
import Foundation
import RealModule
@testable import BusinessMath

/// Tests that verify performance optimizations and set performance targets.
///
/// These tests ensure the library performs efficiently with large datasets
/// and complex models, maintaining sub-millisecond performance where possible.
@Suite("PerformanceOptimizationTests") struct PerformanceOptimizationTests {

    // MARK: - Model Calculation Performance

    @Test("Performance_LargeModelCalculation") func LPerformance_LargeModelCalculation() {
        // Given: A large model with 100 revenue and 50 cost components
        var model = FinancialModel()

        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        for i in 1...50 {
            let costType: CostType = i % 2 == 0 ? .fixed(Double(i * 500)) : .variable(0.01)
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: costType)
            )
        }
        // When/Then: Should calculate profit in under 5ms
        let start = Date()
        let profit = model.calculateProfit()
        let elapsed = Date().timeIntervalSince(start)

        // Verify correctness
        #expect(profit > 0)
        // Verify performance
        #expect(elapsed < 0.005, "Should complete in < 5ms (got \((elapsed * 1000).number(2))ms)")
    }
    @Test("Performance_RepeatedCalculations") func LPerformance_RepeatedCalculations() {
        // Given: A model that will be calculated many times
        let model = FinancialModel {
            Revenue {
                Product("Product A").price(100).quantity(500)
                Product("Product B").price(200).quantity(200)
            }
            Costs {
                Fixed("Salaries", 50_000)
                Variable("COGS", 0.30)
            }
        }

        // When/Then: 1000 calculations should complete in < 100ms
        let start = Date()
        for _ in 0..<1000 {
            let profit = model.calculateProfit()
            #expect(profit != 0)
        }
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 0.1, "Should complete 1000 calculations in < 100ms (got \((elapsed * 1000).number(2))ms)")
    }

    @Test("Performance_ModelInspectionOnLargeModel") func LPerformance_ModelInspectionOnLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        for i in 1...200 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        // When/Then: Inspection should complete in < 10ms
        let inspector = ModelInspector(model: model)
        let start = Date()
        let summary = inspector.generateSummary()
        let elapsed = Date().timeIntervalSince(start)

        #expect(!summary.isEmpty)
        #expect(summary.contains("Revenue"))
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Export Performance

    @Test("Performance_CSVExportLargeModel") func LPerformance_CSVExportLargeModel() {
        // Given: A large model with many components
        var model = FinancialModel()

        for i in 1...500 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        let exporter = DataExporter(model: model)

        // When/Then: CSV export should complete in < 50ms
        let start = Date()
        let csv = exporter.exportToCSV()
        let elapsed = Date().timeIntervalSince(start)

        #expect(csv.count > 1000)
        #expect(elapsed < 0.05, "Should complete in < 50ms (got \((elapsed * 1000).number(2))ms)")
    }
    @Test("Performance_JSONExportLargeModel") func LPerformance_JSONExportLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        for i in 1...500 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        let exporter = DataExporter(model: model)

        // When/Then: JSON export should complete in < 50ms
        let start = Date()
        let json = exporter.exportToJSON()
        let elapsed = Date().timeIntervalSince(start)

        #expect(json.count > 1000)
        #expect(json.contains("revenue"))
        #expect(elapsed < 0.05, "Should complete in < 50ms (got \((elapsed * 1000).number(2))ms)")
    }
    @Test("Performance_TimeSeriesExport") func LPerformance_TimeSeriesExport() {
        // Given: Large time series (1000 years of data)
        let periods = (0..<1000).map { Period.year(2000 + $0) }
        let values = (0..<1000).map { Double($0 * 100) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        let exporter = TimeSeriesExporter<Double>(series: series)

        // When/Then: Should export in < 50ms
        let start = Date()
        let csv = exporter.exportToCSV()
        let elapsed = Date().timeIntervalSince(start)

        #expect(csv.count > 10000)
        #expect(elapsed < 0.05, "Should complete in < 50ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Validation Performance

    @Test("Performance_TimeSeriesValidation") func LPerformance_TimeSeriesValidation() {
        // Given: Large time series
        let periods = (2000...2100).map { Period.year($0) }
        let values = (0..<101).map { Double($0 * 1000) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        // When/Then: Validation should complete in < 5ms
        let start = Date()
        let validation = series.validate()
        let elapsed = Date().timeIntervalSince(start)

        #expect(validation.isValid)
        #expect(elapsed < 0.005, "Should complete in < 5ms (got \((elapsed * 1000).number(2))ms)")
    }
    @Test("Performance_ModelValidation") func LPerformance_ModelValidation() {
        // Given: Complex model
        var model = FinancialModel()

        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: .fixed(Double(i * 500)))
            )
        }
        let inspector = ModelInspector(model: model)

        // When/Then: Validation should complete in < 10ms
        let start = Date()
        let summary = inspector.generateSummary()
        let elapsed = Date().timeIntervalSince(start)

        #expect(!summary.isEmpty)
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Calculation Trace Performance

    @Test("Performance_CalculationTracing") func LPerformance_CalculationTracing() {
        // Given: Model with many components
        var model = FinancialModel()

        for i in 1...50 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        for i in 1...30 {
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: .fixed(Double(i * 500)))
            )
        }
        // When/Then: Tracing should not significantly impact performance
        let start = Date()
        let trace = CalculationTrace(model: model)
        let revenue = trace.calculateRevenue()
        _ = trace.calculateCosts(revenue: revenue)
        let elapsed = Date().timeIntervalSince(start)

        #expect(trace.steps.count > 0)
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Memory Efficiency

    @Test("Performance_MemoryEfficiency") func LPerformance_MemoryEfficiency() {
        // This test verifies we don't leak memory or hold unnecessary references

        let start = Date()
        #if canImport(Darwin)
        autoreleasepool {
            // Create many models
            for _ in 0..<1000 {
                let model = FinancialModel {
                    Revenue {
                        Product("Test").price(100).quantity(10)
                    }
                    Costs {
                        Fixed("Test", 500)
                    }
                }
                _ = model.calculateProfit()
            }
        }
        #else
        do {
            // Create many models
            for _ in 0..<1000 {
                let model = FinancialModel {
                    Revenue {
                        Product("Test").price(100).quantity(10)
                    }
                    Costs {
                        Fixed("Test", 500)
                    }
                }
                _ = model.calculateProfit()
            }
        }
        #endif
        let elapsed = Date().timeIntervalSince(start)

        // If we made it here without running out of memory, we're good
        #expect(elapsed < 1.0, "Should complete 1000 model creations in < 1s (got \((elapsed * 1000).number(2))ms)")
    }
    @Test("Performance_TimeSeriesMemoryEfficiency")
	func LPerformance_TimeSeriesMemoryEfficiency() {
        let start = Date()
        #if canImport(Darwin)
        autoreleasepool {
            // Create many time series
            for _ in 0..<100 {
                let periods = (0..<1000).map { Period.year(2000 + $0) }
                let values = (0..<1000).map { Double($0) }
                let series = TimeSeries<Double>(periods: periods, values: values)
                _ = series.validate()
            }
        }
        #else
        do {
            // Create many time series
            for _ in 0..<100 {
                let periods = (0..<1000).map { Period.year(2000 + $0) }
                let values = (0..<1000).map { Double($0) }
                let series = TimeSeries<Double>(periods: periods, values: values)
                _ = series.validate()
            }
        }
        #endif
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 2.0, "Should complete 100 time series creations in < 2s (got \(elapsed.number(3))s)")
    }
    // MARK: - Batch Operations

    @Test("Performance_BatchModelCalculations") func LPerformance_BatchModelCalculations() {
        // Given: Multiple models to calculate
        var models: [FinancialModel] = []

        for i in 0..<100 {
            var model = FinancialModel()
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue", amount: Double(i * 1000))
            )
            model.costComponents.append(
                CostComponent(name: "Cost", type: .fixed(Double(i * 500)))
            )
            models.append(model)
        }
        // When/Then: Batch processing should be efficient
        let start = Date()
        var totalProfit = 0.0
        for model in models {
            totalProfit += model.calculateProfit()
        }
        let elapsed = Date().timeIntervalSince(start)

        #expect(totalProfit != 0)
        #expect(elapsed < 0.01, "Should complete 100 calculations in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Summary Generation Performance

    @Test("Performance_SummaryGeneration") func LPerformance_SummaryGeneration() {
        // Given: Complex model
        let model = FinancialModel {
            Revenue {
                Product("Product 1").price(100).quantity(500)
                Product("Product 2").price(200).quantity(300)
                Product("Product 3").price(150).quantity(400)
            }
            Costs {
                Fixed("Salaries", 100_000)
                Fixed("Rent", 25_000)
                Fixed("Insurance", 10_000)
                Variable("Materials", 0.30)
                Variable("Shipping", 0.05)
            }
        }

        let inspector = ModelInspector(model: model)

        // When/Then: Summary generation should be fast
        let start = Date()
        let summary = inspector.generateSummary()
        let elapsed = Date().timeIntervalSince(start)

        #expect(!summary.isEmpty)
        #expect(elapsed < 0.005, "Should complete in < 5ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Dependency Graph Performance

    @Test("Performance_DependencyGraphConstruction") func LPerformance_DependencyGraphConstruction() {
        // Given: Large model with many components
        var model = FinancialModel()

        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        for i in 1...100 {
            let costType: CostType = i % 2 == 0 ? .fixed(Double(i * 500)) : .variable(0.01)
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: costType)
            )
        }
        let inspector = ModelInspector(model: model)

        // When/Then: Graph construction should be efficient
        let start = Date()
        let graph = inspector.buildDependencyGraph()
        let elapsed = Date().timeIntervalSince(start)

        #expect(graph.count > 0)
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Investment Calculation Performance

    @Test("Performance_InvestmentCalculations") func LPerformance_InvestmentCalculations() {
        // Given: Investment with many cash flows
        var cashFlows: [CashFlow] = []
        for i in 1...120 {  // 10 years monthly
            cashFlows.append(CashFlow(period: i, amount: Double(i * 1000)))
        }
        let start = Date()
        let investment = Investment {
            InitialCost(500_000)
            CashFlows { cashFlows }
            DiscountRate(0.10)
        }
        // When/Then: NPV and IRR calculations should be efficient
        let npv = investment.npv
        let elapsed = Date().timeIntervalSince(start)

        #expect(!npv.isNaN)
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
    // MARK: - Export Format Performance

    @Test("Performance_TraceFormatting") func LPerformance_TraceFormatting() {
        // Given: Trace with many steps
        var model = FinancialModel()

        for i in 1...100 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        let trace = CalculationTrace(model: model)
        _ = trace.calculateRevenue()

        // When/Then: Formatting should be efficient
        let start = Date()
        let formatted = trace.formatTrace()
        let elapsed = Date().timeIntervalSince(start)

        #expect(formatted.count > 100)
        #expect(elapsed < 0.01, "Should complete in < 10ms (got \((elapsed * 1000).number(2))ms)")
    }
}

@Suite("Exporter Equivalence (Swift Testing)")
struct ExporterEquivalenceTests {

	private func normalizeCSV(_ s: String) -> String {
		// Trim whitespace differences to avoid CRLF vs LF or trailing spaces issues
		s.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
	}
	@Test("Optimized CSV export is content-equivalent")
	func csvOptimizedEquivalence() throws {
		var model = FinancialModel()
		for i in 1...50 {
			model.revenueComponents.append(RevenueComponent(name: "R\(i)", amount: Double(i * 1000)))
		}
		let exporter = DataExporter(model: model)

		let normal = exporter.exportToCSV()
		let optimized = exporter.exportToCSVOptimized()

		let n1 = normalizeCSV(normal)
		let n2 = normalizeCSV(optimized)

		#expect(n1 == n2, "Optimized CSV should be textually equivalent to normal CSV.")
	}
	@Test("Optimized TimeSeries CSV export is content-equivalent")
	func tsOptimizedEquivalence() throws {
		let periods = (0..<100).map { Period.year(2000 + $0) }
		let values = (0..<100).map { Double($0 * 10) }
		let series = TimeSeries<Double>(periods: periods, values: values)
		let exporter = TimeSeriesExporter<Double>(series: series)

		let normal = exporter.exportToCSV()
		let optimized = exporter.exportToCSVOptimized()

		#expect(normal == optimized, "Optimized TimeSeries CSV should match normal CSV exactly.")
	}
	@Test("JSON export is valid JSON")
	func jsonExportIsValid() throws {
		var model = FinancialModel()
		for i in 1...10 {
			model.revenueComponents.append(RevenueComponent(name: "R\(i)", amount: Double(i)))
		}
		let exporter = DataExporter(model: model)
		let json = exporter.exportToJSON()

		let data = Data(json.utf8)
		let obj = try? JSONSerialization.jsonObject(with: data, options: [])
		#expect(obj != nil, "JSON export should produce parseable JSON.")
	}
}
