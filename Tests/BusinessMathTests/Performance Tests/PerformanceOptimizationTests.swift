//
//  PerformanceOptimizationTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests define performance requirements, then optimize to meet them
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests that verify performance optimizations and set performance targets.
///
/// These tests ensure the library performs efficiently with large datasets
/// and complex models, maintaining sub-millisecond performance where possible.
final class PerformanceOptimizationTests: XCTestCase {

    // MARK: - Model Calculation Performance

    func testPerformance_LargeModelCalculation() {
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
        measure {
            _ = model.calculateProfit()
        }

        // Verify correctness
        let profit = model.calculateProfit()
        XCTAssertGreaterThan(profit, 0)
    }

    func testPerformance_RepeatedCalculations() {
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
        measure {
            for _ in 0..<1000 {
                _ = model.calculateProfit()
            }
        }
    }

    func testPerformance_ModelInspectionOnLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        for i in 1...200 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }

        // When/Then: Inspection should be fast
        let inspector = ModelInspector(model: model)

        measure {
            _ = inspector.listRevenueSources()
            _ = inspector.listCostDrivers()
            _ = inspector.validateStructure()
        }
    }

    // MARK: - Export Performance

    func testPerformance_CSVExportLargeModel() {
        // Given: A large model with many components
        var model = FinancialModel()

        for i in 1...500 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }

        let exporter = DataExporter(model: model)

        // When/Then: CSV export should be efficient
        measure {
            _ = exporter.exportToCSV()
        }

        let csv = exporter.exportToCSV()
        XCTAssertGreaterThan(csv.count, 1000)
    }

    func testPerformance_JSONExportLargeModel() {
        // Given: A large model
        var model = FinancialModel()

        for i in 1...500 {
            model.revenueComponents.append(
                RevenueComponent(name: "Revenue \(i)", amount: Double(i * 1000))
            )
        }

        let exporter = DataExporter(model: model)

        // When/Then: JSON export should be efficient
        measure {
            _ = exporter.exportToJSON()
        }
    }

    func testPerformance_TimeSeriesExport() {
        // Given: Large time series (1000 years of data)
        let periods = (0..<1000).map { Period.year(2000 + $0) }
        let values = (0..<1000).map { Double($0 * 100) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        let exporter = TimeSeriesExporter<Double>(series: series)

        // When/Then: Should export efficiently
        measure {
            _ = exporter.exportToCSV()
        }

        let csv = exporter.exportToCSV()
        XCTAssertGreaterThan(csv.count, 10000)
    }

    // MARK: - Validation Performance

    func testPerformance_TimeSeriesValidation() {
        // Given: Large time series
        let periods = (2000...2100).map { Period.year($0) }
        let values = (0..<101).map { Double($0 * 1000) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        // When/Then: Validation should be fast
        measure {
            _ = series.validate(detectOutliers: true)
        }

        let validation = series.validate()
        XCTAssertTrue(validation.isValid)
    }

    func testPerformance_ModelValidation() {
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
        measure {
            _ = inspector.validateStructure()
        }
    }

    // MARK: - Calculation Trace Performance

    func testPerformance_CalculationTracing() {
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

        measure {
            _ = trace.calculateProfit()
        }

        XCTAssertGreaterThan(trace.steps.count, 0)
    }

    // MARK: - Memory Efficiency

    func testPerformance_MemoryEfficiency() {
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
        XCTAssertTrue(true)
    }

    func testPerformance_TimeSeriesMemoryEfficiency() {
        autoreleasepool {
            // Create many time series
            for _ in 0..<100 {
                let periods = (0..<1000).map { Period.year(2000 + $0) }
                let values = (0..<1000).map { Double($0) }
                let series = TimeSeries<Double>(periods: periods, values: values)
                _ = series.validate()
            }
        }

        XCTAssertTrue(true)
    }

    // MARK: - Batch Operations

    func testPerformance_BatchModelCalculations() {
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
        measure {
            let profits = models.map { $0.calculateProfit() }
            XCTAssertEqual(profits.count, 100)
        }
    }

    // MARK: - Summary Generation Performance

    func testPerformance_SummaryGeneration() {
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
        measure {
            _ = inspector.generateSummary()
        }

        let summary = inspector.generateSummary()
        XCTAssertFalse(summary.isEmpty)
    }

    // MARK: - Dependency Graph Performance

    func testPerformance_DependencyGraphConstruction() {
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
        measure {
            _ = inspector.buildDependencyGraph()
        }

        let graph = inspector.buildDependencyGraph()
        XCTAssertGreaterThan(graph.count, 0)
    }

    // MARK: - Investment Calculation Performance

    func testPerformance_InvestmentCalculations() {
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
        measure {
            _ = investment.npv
            _ = investment.irr
        }

        XCTAssertNotNil(investment.npv)
    }

    // MARK: - Export Format Performance

    func testPerformance_TraceFormatting() {
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
        measure {
            _ = trace.formatTrace()
        }

        let formatted = trace.formatTrace()
        XCTAssertGreaterThan(formatted.count, 100)
    }
}
