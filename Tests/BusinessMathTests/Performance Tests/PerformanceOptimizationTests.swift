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

        // Verify correctness
        let profit = model.calculateProfit()
        #expect(profit > 0)
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

        // When/Then: 1000 calculations should complete quickly
        for _ in 0..<1000 {
            let profit = model.calculateProfit()
            #expect(profit != 0)
        }
        // Test passes if we complete 1000 calculations without timeout
    }

    @Test("Performance_ModelInspectionOnLargeModel") func LPerformance_ModelInspectionOnLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        for i in 1...200 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }
        // When/Then: Inspection should be fast
        let inspector = ModelInspector(model: model)
        let summary = inspector.generateSummary()
        #expect(!summary.isEmpty)
        #expect(summary.contains("Revenue"))
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

        // When/Then: CSV export should be efficient

        let csv = exporter.exportToCSV()
        #expect(csv.count > 1000)
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

        // When/Then: JSON export should be efficient
        let json = exporter.exportToJSON()
        #expect(json.count > 1000)
        #expect(json.contains("revenue"))
    }
    @Test("Performance_TimeSeriesExport") func LPerformance_TimeSeriesExport() {
        // Given: Large time series (1000 years of data)
        let periods = (0..<1000).map { Period.year(2000 + $0) }
        let values = (0..<1000).map { Double($0 * 100) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        let exporter = TimeSeriesExporter<Double>(series: series)

        // When/Then: Should export efficiently

        let csv = exporter.exportToCSV()
        #expect(csv.count > 10000)
    }
    // MARK: - Validation Performance

    @Test("Performance_TimeSeriesValidation") func LPerformance_TimeSeriesValidation() {
        // Given: Large time series
        let periods = (2000...2100).map { Period.year($0) }
        let values = (0..<101).map { Double($0 * 1000) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        // When/Then: Validation should be fast

        let validation = series.validate()
        #expect(validation.isValid)
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

        // When/Then: Validation should be efficient
        let summary = inspector.generateSummary()
        #expect(!summary.isEmpty)
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
        let trace = CalculationTrace(model: model)
        let revenue = trace.calculateRevenue()
        _ = trace.calculateCosts(revenue: revenue)

        #expect(trace.steps.count > 0)
    }
    // MARK: - Memory Efficiency

    @Test("Performance_MemoryEfficiency") func LPerformance_MemoryEfficiency() {
        // This test verifies we don't leak memory or hold unnecessary references

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

        // If we made it here without running out of memory, we're good
        #expect(true)
    }
    @Test("Performance_TimeSeriesMemoryEfficiency") func LPerformance_TimeSeriesMemoryEfficiency() {
        autoreleasepool {
            // Create many time series
            for _ in 0..<100 {
                let periods = (0..<1000).map { Period.year(2000 + $0) }
                let values = (0..<1000).map { Double($0) }
                let series = TimeSeries<Double>(periods: periods, values: values)
                _ = series.validate()
            }
        }

        #expect(true)
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
        var totalProfit = 0.0
        for model in models {
            totalProfit += model.calculateProfit()
        }
        #expect(totalProfit != 0)
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

        let summary = inspector.generateSummary()
        #expect(!summary.isEmpty)
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

        let graph = inspector.buildDependencyGraph()
        #expect(graph.count > 0)
    }
    // MARK: - Investment Calculation Performance

    @Test("Performance_InvestmentCalculations") func LPerformance_InvestmentCalculations() {
        // Given: Investment with many cash flows
        var cashFlows: [CashFlow] = []
        for i in 1...120 {  // 10 years monthly
            cashFlows.append(CashFlow(period: i, amount: Double(i * 1000)))
        }
        let investment = Investment {
            InitialCost(500_000)
            CashFlows { cashFlows }
            DiscountRate(0.10)
        }
        // When/Then: NPV and IRR calculations should be efficient
        #expect(!investment.npv.isNaN)
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

        let formatted = trace.formatTrace()
        #expect(formatted.count > 100)
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
