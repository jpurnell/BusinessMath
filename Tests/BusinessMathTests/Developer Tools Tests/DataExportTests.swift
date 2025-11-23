//
//  DataExportTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import Foundation
import Testing
import RealModule
@testable import BusinessMath

/// Tests for Data Export developer tools.
///
/// These tests define expected behavior for exporting financial models
/// and analysis results to various formats (CSV, JSON).
@Suite("DataExportTests") struct DataExportTests {

    // MARK: - CSV Export Tests

    @Test("DataExport_ExportsModelToCSV") func LDataExport_ExportsModelToCSV() {
        // Given: A financial model
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

        // When: Exporting to CSV
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Should produce valid CSV
        #expect(!csvOutput.isEmpty, "CSV output should not be empty")

        // And: Should have header row
        #expect(csvOutput.contains("Component"), "Should have Component column")
        #expect(csvOutput.contains("Type"), "Should have Type column")
        #expect(csvOutput.contains("Amount"), "Should have Amount column")

        // And: Should include revenue components
        #expect(csvOutput.contains("Product A"), "Should include Product A")
        #expect(csvOutput.contains("Product B"), "Should include Product B")

        // And: Should include cost components
        #expect(csvOutput.contains("Salaries"), "Should include Salaries")
        #expect(csvOutput.contains("COGS"), "Should include COGS")
    }

    @Test("DataExport_ExportsTimeSeriesToCSV") func LDataExport_ExportsTimeSeriesToCSV() {
        // Given: A time series
        let series = TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, 150, 200]
        )

        // When: Exporting to CSV
        let exporter = TimeSeriesExporter(series: series)
        let csvOutput = exporter.exportToCSV()

        // Then: Should produce valid CSV
        #expect(!csvOutput.isEmpty, "CSV output should not be empty")

        // And: Should have period and value columns
        #expect(csvOutput.contains("Period"), "Should have Period column")
        #expect(csvOutput.contains("Value"), "Should have Value column")

        // And: Should include all periods
        #expect(csvOutput.contains("2020"), "Should include 2020")
        #expect(csvOutput.contains("2021"), "Should include 2021")
        #expect(csvOutput.contains("2022"), "Should include 2022")

        // And: Should include all values
        #expect(csvOutput.contains("100"), "Should include value 100")
        #expect(csvOutput.contains("150"), "Should include value 150")
        #expect(csvOutput.contains("200"), "Should include value 200")
    }

    // MARK: - JSON Export Tests

    @Test("DataExport_ExportsModelToJSON") func LDataExport_ExportsModelToJSON() {
        // Given: A financial model
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Expenses", 40_000)
            }
        }

        // When: Exporting to JSON
        let exporter = DataExporter(model: model)
        let jsonOutput = exporter.exportToJSON()

        // Then: Should produce valid JSON
        #expect(!jsonOutput.isEmpty, "JSON output should not be empty")

        // And: Should be parseable JSON
        let jsonData = jsonOutput.data(using: .utf8)
        #expect(jsonData != nil, "Should produce valid UTF-8 data")

        if let jsonData = jsonData {
            let parsed = try? JSONSerialization.jsonObject(with: jsonData)
            #expect(parsed != nil, "Should be valid JSON")
        }

        // And: Should include model data
        #expect(jsonOutput.contains("revenue"), "Should have revenue section")
        #expect(jsonOutput.contains("costs"), "Should have costs section")
        #expect(jsonOutput.contains("Sales"), "Should include Sales component")
        #expect(jsonOutput.contains("Expenses"), "Should include Expenses component")
    }

    @Test("DataExport_ExportsTimeSeriesToJSON") func LDataExport_ExportsTimeSeriesToJSON() {
        // Given: A time series
        let series = TimeSeries<Double>(
            periods: [.quarter(year: 2023, quarter: 1), .quarter(year: 2023, quarter: 2)],
            values: [1000, 1200]
        )

        // When: Exporting to JSON
        let exporter = TimeSeriesExporter(series: series)
        let jsonOutput = exporter.exportToJSON()

        // Then: Should produce valid JSON
        #expect(!jsonOutput.isEmpty, "JSON output should not be empty")

        let jsonData = jsonOutput.data(using: .utf8)
        #expect(jsonData != nil)

        if let jsonData = jsonData {
            let parsed = try? JSONSerialization.jsonObject(with: jsonData)
            #expect(parsed != nil, "Should be valid JSON")
        }

        // And: Should include period and value data
        #expect(jsonOutput.contains("periods") || jsonOutput.contains("data"), "Should have data structure")
    }

    // MARK: - Investment Export Tests

    @Test("DataExport_ExportsInvestmentAnalysis") func LDataExport_ExportsInvestmentAnalysis() {
        // Given: An investment with analysis
        let investment = Investment {
            InitialCost(50_000)
            CashFlows {
                [
                    CashFlow(period: 1, amount: 15_000),
                    CashFlow(period: 2, amount: 20_000),
                    CashFlow(period: 3, amount: 25_000)
                ]
            }
            DiscountRate(0.10)
        }

        // When: Exporting analysis to CSV
        let exporter = InvestmentExporter(investment: investment)
        let csvOutput = exporter.exportToCSV()

        // Then: Should include investment metrics
        #expect(!csvOutput.isEmpty)
        #expect(csvOutput.contains("NPV") || csvOutput.contains("Period"), "Should include metrics or cash flows")

        // And: Should include cash flow data
        #expect(csvOutput.contains("15000") || csvOutput.contains("15,000"), "Should include cash flow amounts")
    }

    // MARK: - Empty Data Handling Tests

    @Test("DataExport_HandlesEmptyModel") func LDataExport_HandlesEmptyModel() {
        // Given: An empty financial model
        let model = FinancialModel()

        // When: Exporting empty model
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Should not crash and should indicate empty
        #expect(!csvOutput.isEmpty, "Should return header or empty indicator")
        #expect(csvOutput.contains("Component") || csvOutput.contains("empty"), "Should have header or empty message")
    }

    @Test("DataExport_HandlesEmptyTimeSeries") func LDataExport_HandlesEmptyTimeSeries() {
        // Given: An empty time series
        let series = TimeSeries<Double>(periods: [], values: [])

        // When: Exporting empty series
        let exporter = TimeSeriesExporter(series: series)
        let csvOutput = exporter.exportToCSV()

        // Then: Should handle gracefully
        #expect(!csvOutput.isEmpty, "Should return header or message")
        #expect(csvOutput.contains("Period") || csvOutput.contains("empty"), "Should indicate empty series")
    }

    // MARK: - CSV Format Validation Tests

    @Test("DataExport_CSVUsesCommaDelimiters") func LDataExport_CSVUsesCommaDelimiters() {
        // Given: A simple model
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 50_000)
            }
        }

        // When: Exporting to CSV
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Should use comma delimiters
        #expect(csvOutput.contains(","), "CSV should use comma delimiters")

        // And: Should have proper line breaks
        #expect(csvOutput.contains("\n"), "CSV should have line breaks")
    }

    // MARK: - JSON Format Validation Tests

    @Test("DataExport_JSONIsPrettyPrinted") func LDataExport_JSONIsPrettyPrinted() {
        // Given: A model with data
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Revenue", amount: 100_000)
            }
        }

        // When: Exporting to JSON
        let exporter = DataExporter(model: model)
        let jsonOutput = exporter.exportToJSON()

        // Then: Should be formatted (have indentation/whitespace)
        let hasIndentation = jsonOutput.contains("  ") || jsonOutput.contains("\t")
        let hasNewlines = jsonOutput.contains("\n")

        #expect(hasIndentation || hasNewlines, "JSON should be formatted/pretty-printed")
    }

    // MARK: - Custom Options Tests

    @Test("DataExport_SupportsIncludeMetadataOption") func LDataExport_SupportsIncludeMetadataOption() {
        // Given: A model with metadata
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }
        }

        // When: Exporting with metadata included
        let exporter = DataExporter(model: model)
        let jsonWithMetadata = exporter.exportToJSON(includeMetadata: true)

        // Then: Should include model metadata
		#expect(
            jsonWithMetadata.contains("metadata") ||
            jsonWithMetadata.contains("version") ||
            jsonWithMetadata.contains("created"),
            "Should include metadata when requested"
        )
    }

    // MARK: - Large Data Tests

    @Test("DataExport_HandlesLargeTimeSeries") func LDataExport_HandlesLargeTimeSeries() {
        // Given: A large time series
        let periods = (2000...2100).map { Period.year($0) }
        let values = (0..<101).map { Double($0 * 1000) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        // When: Exporting large series
        let exporter = TimeSeriesExporter(series: series)

        // Then: Should complete without errors
        _ = exporter.exportToCSV()
        _ = exporter.exportToJSON()

        let csvOutput = exporter.exportToCSV()
        #expect(csvOutput.count > 1000, "Should have substantial output for large series")
    }
}
