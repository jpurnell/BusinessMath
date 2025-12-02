//
//  DocumentationExamplesTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests verify that documentation examples actually work
//

import Foundation
import Testing
import RealModule
@testable import BusinessMath

/// Tests that verify all documentation examples compile and work correctly.
///
/// These tests serve as "executable documentation" - they ensure that every
/// example shown in the library's documentation actually works as advertised.
@Suite("DocumentationExamplesTests") struct DocumentationExamplesTests {

    // MARK: - Quick Start Examples

    @Test("QuickStart_BasicFinancialModel") func LQuickStart_BasicFinancialModel() {
        // Example from Quick Start Guide
        // This should be the first example users see

        let model = FinancialModel {
            Revenue {
                Product("SaaS Subscriptions")
                    .price(99)
                    .customers(1000)
            }

            Costs {
                Fixed("Salaries", 50_000)
                Variable("Cloud Costs", 0.15)
            }
        }

        // Verify calculations work as documented
        let revenue = model.calculateRevenue()
        let costs = model.calculateCosts(revenue: revenue)
        let profit = model.calculateProfit()

        #expect(abs(revenue - 99_000) < 1.0)
        #expect(abs(costs - 64_850) < 1.0)  // 50k + 15% of 99k
        #expect(abs(profit - 34_150) < 1.0)
    }

    @Test("QuickStart_TimeSeriesAnalysis") func LQuickStart_TimeSeriesAnalysis() {
        // Example from Quick Start: Time Series
        let sales = TimeSeries<Double>(
            periods: [.year(2021), .year(2022), .year(2023)],
            values: [100_000, 125_000, 150_000]
        )

        // Should validate data quality
        let validation = sales.validate()
        #expect(validation.isValid, "Data should be valid")

        // Should support export
        let exporter = TimeSeriesExporter(series: sales)
        let csvOutput = exporter.exportToCSV()
        #expect(!csvOutput.isEmpty)
        #expect(csvOutput.contains("2021"))
    }

    @Test("QuickStart_InvestmentAnalysis") func LQuickStart_InvestmentAnalysis() {
        // Example from Quick Start: Investment
        let investment = Investment {
            InitialCost(50_000)
            CashFlows {
                [
                    CashFlow(period: 1, amount: 20_000),
                    CashFlow(period: 2, amount: 25_000),
                    CashFlow(period: 3, amount: 30_000)
                ]
            }
            DiscountRate(0.10)
        }

        // Verify documented metrics
        #expect(investment.npv > 0, "Should have positive NPV")
        #expect(investment.irr != nil, "Should calculate IRR")
        #expect(investment.paybackPeriod != nil, "Should calculate payback period")
    }

    // MARK: - Feature Examples

    @Test("Example_ModelInspection") func LExample_ModelInspection() {
        // Example from ModelInspector documentation
        let model = FinancialModel {
            Revenue {
                Product("Product A").price(100).quantity(500)
                Product("Product B").price(200).quantity(200)
            }

            Costs {
                Fixed("Salaries", 50_000)
                Fixed("Rent", 10_000)
                Variable("COGS", 0.35)
            }
        }

        let inspector = ModelInspector(model: model)

        // Should list all components
        let revenues = inspector.listRevenueSources()
        #expect(revenues.count == 2)

        let costs = inspector.listCostDrivers()
        #expect(costs.count == 3)

        // Should generate summary
        let summary = inspector.generateSummary()
        #expect(!summary.isEmpty)
        #expect(summary.contains("Revenue Components: 2"))
    }

    @Test("Example_CalculationTracing") func LExample_CalculationTracing() {
        // Example from CalculationTrace documentation
        let model = FinancialModel {
            Revenue {
                Product("Widget Sales").price(50).quantity(1000)
            }

            Costs {
                Fixed("Overhead", 10_000)
                Variable("Materials", 0.25)
            }
        }

        let trace = CalculationTrace(model: model)
        let profit = trace.calculateProfit()

        // Should have traced all steps
        #expect(!trace.steps.isEmpty)
        #expect(profit > 0)

        // Should be able to format trace
        let formattedTrace = trace.formatTrace()
        #expect(formattedTrace.contains("Revenue"))
        #expect(formattedTrace.contains("Costs"))
        #expect(formattedTrace.contains("Profit"))
    }

    @Test("Example_DataExport") func LExample_DataExport() {
        // Example from DataExport documentation
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Expenses", 40_000)
            }
        }

        let exporter = DataExporter(model: model)

        // Should export to CSV
        let csvOutput = exporter.exportToCSV()
        #expect(!csvOutput.isEmpty)
        #expect(csvOutput.contains("Component"))
        #expect(csvOutput.contains("Sales"))

        // Should export to JSON
        let jsonOutput = exporter.exportToJSON()
        #expect(!jsonOutput.isEmpty)

        // JSON should be valid
        if let jsonData = jsonOutput.data(using: .utf8) {
            let parsed = try? JSONSerialization.jsonObject(with: jsonData)
            #expect(parsed != nil, "Should produce valid JSON")
        }
    }

    // MARK: - Integration Examples

    @Test("Example_CompleteWorkflow") func LExample_CompleteWorkflow() {
        // Example showing complete workflow from model → analysis → export
        // This is a "real world" example users might follow

        // 1. Build a financial model
        let model = FinancialModel {
            Revenue {
                Product("Enterprise Plan").price(999).quantity(100)
                Product("Pro Plan").price(299).quantity(500)
                Product("Basic Plan").price(99).quantity(2000)
            }

            Costs {
                Fixed("Engineering", 200_000)
                Fixed("Sales & Marketing", 150_000)
                Fixed("Infrastructure", 50_000)
                Variable("Payment Processing", 0.029)
                Variable("Customer Support", 0.05)
            }
        }

        // 2. Analyze the model
        let inspector = ModelInspector(model: model)
        let validation = inspector.validateStructure()
        #expect(validation.isValid, "Model should be valid")

        let profit = model.calculateProfit()
        #expect(profit > 0, "Should be profitable")

        // 3. Trace calculations for documentation
        let trace = CalculationTrace(model: model)
        _ = trace.calculateProfit()
        let formattedTrace = trace.formatTrace()
        #expect(!formattedTrace.isEmpty)

        // 4. Export for reporting
        let exporter = DataExporter(model: model)
        let csvReport = exporter.exportToCSV()
        #expect(csvReport.contains("Enterprise Plan"))
        #expect(csvReport.contains("Engineering"))
    }

    @Test("Example_TimeSeriesWorkflow") func LExample_TimeSeriesWorkflow() {
        // Example showing time series analysis workflow
        let historicalRevenue = TimeSeries<Double>(
            periods: [
                .year(2020), .year(2021), .year(2022), .year(2023)
            ],
            values: [500_000, 625_000, 750_000, 900_000]
        )

        // Should validate data quality
        let validation = historicalRevenue.validate(detectOutliers: true)
        #expect(validation.isValid, "Data should be valid")
        #expect(validation.errors.isEmpty, "Should have no errors")

        // Should have correct count
        #expect(historicalRevenue.count == 4)

        // Should support export to multiple formats
        let exporter = TimeSeriesExporter(series: historicalRevenue)

        let csv = exporter.exportToCSV()
        #expect(csv.contains("2020"))
        #expect(csv.contains("500000"))

        let json = exporter.exportToJSON()
        #expect(!json.isEmpty)
        #expect(json.contains("2023"))
    }

    // MARK: - Error Handling Examples

    @Test("Example_ValidationAndErrorHandling") func LExample_ValidationAndErrorHandling() {
        // Example showing proper error handling

        // 1. Validate time series before analysis
        let problematicData = TimeSeries<Double>(
            periods: [.year(2020), .year(2021)],
            values: [100, .nan]  // Contains NaN
        )

        let validation = problematicData.validate()
        #expect(!validation.isValid, "Should detect NaN")
        #expect(!validation.errors.isEmpty, "Should have error messages")

        // 2. Validate financial model structure
        let emptyModel = FinancialModel()
        let inspector = ModelInspector(model: emptyModel)
        let modelValidation = inspector.validateStructure()
        #expect(!modelValidation.isValid, "Should detect empty model")
        #expect(!modelValidation.issues.isEmpty)
    }

    // MARK: - Performance Examples

    @Test("Example_LargeScaleModeling") func LExample_LargeScaleModeling() {
        // Example showing library handles large datasets

        // Build a model with many components
        var model = FinancialModel()

        // Add 50 revenue products
        for i in 1...50 {
            model.revenueComponents.append(
                RevenueComponent(name: "Product \(i)", amount: Double(i * 1000))
            )
        }

        // Add 20 cost components
        for i in 1...20 {
            let costType: CostType = i % 2 == 0 ? .fixed(Double(i * 500)) : .variable(0.01 * Double(i))
            model.costComponents.append(
                CostComponent(name: "Cost \(i)", type: costType)
            )
        }

        // Should handle calculations efficiently
        let startTime = Date()
        let profit = model.calculateProfit()
        let duration = Date().timeIntervalSince(startTime)

        #expect(profit == profit)
        #expect(duration < 0.1, "Should complete in < 100ms")

        // Should handle inspection efficiently
        let inspector = ModelInspector(model: model)
        let summary = inspector.generateSummary()
		print(summary)
        #expect(summary.contains("Revenue Components: 50"))
    }

    // MARK: - Best Practices Examples

    @Test("Example_BestPractice_ModelValidation") func LExample_BestPractice_ModelValidation() {
        // Example showing recommended validation workflow

        let model = FinancialModel {
            Revenue {
                Product("Main Product").price(100).quantity(1000)
            }

            Costs {
                Fixed("Operations", 50_000)
                Variable("Variable Costs", 0.30)
            }
        }

        // Best Practice: Always validate before using
        let inspector = ModelInspector(model: model)
        let validation = inspector.validateStructure()

        if validation.isValid {
            // Safe to use model
            let profit = model.calculateProfit()
            #expect(profit > 0)
        } else {
            // Handle validation errors
            for issue in validation.issues {
                print("Model issue: \(issue)")
            }
			#expect(validation.issues.contains("Model should be valid"))
        }
    }

    @Test("Example_BestPractice_TraceForDebugging") func LExample_BestPractice_TraceForDebugging() {
        // Example showing how to use tracing for debugging

        let model = FinancialModel {
            Revenue {
                Product("Product").price(100).quantity(100)
            }
            Costs {
                Variable("Costs", 0.80)
            }
        }

        // Use tracing to understand calculations
        let trace = CalculationTrace(model: model)
        let profit = trace.calculateProfit()

        // Low profit? Check the trace
        if profit < 1000 {
            print("Profit is low, checking calculation steps:")
            for step in trace.steps {
                print("  \(step.description)")
            }
        }

        #expect(abs(profit - 2_000) < 1.0)  // 10k revenue - 8k costs
    }
}
