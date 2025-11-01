//
//  DataExportTests.swift
//  BusinessMath Tests
//
//  Created on November 1, 2025.
//  TDD: Tests written FIRST, then implementation
//

import XCTest
import RealModule
@testable import BusinessMath

/// Tests for Data Export developer tools.
///
/// These tests define expected behavior for exporting financial models
/// and analysis results to various formats (CSV, JSON).
final class DataExportTests: XCTestCase {

    // MARK: - CSV Export Tests

    func testDataExport_ExportsModelToCSV() {
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
        XCTAssertFalse(csvOutput.isEmpty, "CSV output should not be empty")

        // And: Should have header row
        XCTAssertTrue(csvOutput.contains("Component"), "Should have Component column")
        XCTAssertTrue(csvOutput.contains("Type"), "Should have Type column")
        XCTAssertTrue(csvOutput.contains("Amount"), "Should have Amount column")

        // And: Should include revenue components
        XCTAssertTrue(csvOutput.contains("Product A"), "Should include Product A")
        XCTAssertTrue(csvOutput.contains("Product B"), "Should include Product B")

        // And: Should include cost components
        XCTAssertTrue(csvOutput.contains("Salaries"), "Should include Salaries")
        XCTAssertTrue(csvOutput.contains("COGS"), "Should include COGS")
    }

    func testDataExport_ExportsTimeSeriesToCSV() {
        // Given: A time series
        let series = TimeSeries<Double>(
            periods: [.year(2020), .year(2021), .year(2022)],
            values: [100, 150, 200]
        )

        // When: Exporting to CSV
        let exporter = TimeSeriesExporter(series: series)
        let csvOutput = exporter.exportToCSV()

        // Then: Should produce valid CSV
        XCTAssertFalse(csvOutput.isEmpty, "CSV output should not be empty")

        // And: Should have period and value columns
        XCTAssertTrue(csvOutput.contains("Period"), "Should have Period column")
        XCTAssertTrue(csvOutput.contains("Value"), "Should have Value column")

        // And: Should include all periods
        XCTAssertTrue(csvOutput.contains("2020"), "Should include 2020")
        XCTAssertTrue(csvOutput.contains("2021"), "Should include 2021")
        XCTAssertTrue(csvOutput.contains("2022"), "Should include 2022")

        // And: Should include all values
        XCTAssertTrue(csvOutput.contains("100"), "Should include value 100")
        XCTAssertTrue(csvOutput.contains("150"), "Should include value 150")
        XCTAssertTrue(csvOutput.contains("200"), "Should include value 200")
    }

    // MARK: - JSON Export Tests

    func testDataExport_ExportsModelToJSON() {
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
        XCTAssertFalse(jsonOutput.isEmpty, "JSON output should not be empty")

        // And: Should be parseable JSON
        let jsonData = jsonOutput.data(using: .utf8)
        XCTAssertNotNil(jsonData, "Should produce valid UTF-8 data")

        if let jsonData = jsonData {
            let parsed = try? JSONSerialization.jsonObject(with: jsonData)
            XCTAssertNotNil(parsed, "Should be valid JSON")
        }

        // And: Should include model data
        XCTAssertTrue(jsonOutput.contains("revenue"), "Should have revenue section")
        XCTAssertTrue(jsonOutput.contains("costs"), "Should have costs section")
        XCTAssertTrue(jsonOutput.contains("Sales"), "Should include Sales component")
        XCTAssertTrue(jsonOutput.contains("Expenses"), "Should include Expenses component")
    }

    func testDataExport_ExportsTimeSeriesToJSON() {
        // Given: A time series
        let series = TimeSeries<Double>(
            periods: [.quarter(year: 2023, quarter: 1), .quarter(year: 2023, quarter: 2)],
            values: [1000, 1200]
        )

        // When: Exporting to JSON
        let exporter = TimeSeriesExporter(series: series)
        let jsonOutput = exporter.exportToJSON()

        // Then: Should produce valid JSON
        XCTAssertFalse(jsonOutput.isEmpty, "JSON output should not be empty")

        let jsonData = jsonOutput.data(using: .utf8)
        XCTAssertNotNil(jsonData)

        if let jsonData = jsonData {
            let parsed = try? JSONSerialization.jsonObject(with: jsonData)
            XCTAssertNotNil(parsed, "Should be valid JSON")
        }

        // And: Should include period and value data
        XCTAssertTrue(jsonOutput.contains("periods") || jsonOutput.contains("data"), "Should have data structure")
    }

    // MARK: - Investment Export Tests

    func testDataExport_ExportsInvestmentAnalysis() {
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
        XCTAssertFalse(csvOutput.isEmpty)
        XCTAssertTrue(csvOutput.contains("NPV") || csvOutput.contains("Period"), "Should include metrics or cash flows")

        // And: Should include cash flow data
        XCTAssertTrue(csvOutput.contains("15000") || csvOutput.contains("15,000"), "Should include cash flow amounts")
    }

    // MARK: - Empty Data Handling Tests

    func testDataExport_HandlesEmptyModel() {
        // Given: An empty financial model
        let model = FinancialModel()

        // When: Exporting empty model
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Should not crash and should indicate empty
        XCTAssertFalse(csvOutput.isEmpty, "Should return header or empty indicator")
        XCTAssertTrue(csvOutput.contains("Component") || csvOutput.contains("empty"), "Should have header or empty message")
    }

    func testDataExport_HandlesEmptyTimeSeries() {
        // Given: An empty time series
        let series = TimeSeries<Double>(periods: [], values: [])

        // When: Exporting empty series
        let exporter = TimeSeriesExporter(series: series)
        let csvOutput = exporter.exportToCSV()

        // Then: Should handle gracefully
        XCTAssertFalse(csvOutput.isEmpty, "Should return header or message")
        XCTAssertTrue(csvOutput.contains("Period") || csvOutput.contains("empty"), "Should indicate empty series")
    }

    // MARK: - CSV Format Validation Tests

    func testDataExport_CSVUsesCommaDelimiters() {
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
        XCTAssertTrue(csvOutput.contains(","), "CSV should use comma delimiters")

        // And: Should have proper line breaks
        XCTAssertTrue(csvOutput.contains("\n"), "CSV should have line breaks")
    }

    // MARK: - JSON Format Validation Tests

    func testDataExport_JSONIsPrettyPrinted() {
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

        XCTAssertTrue(hasIndentation || hasNewlines, "JSON should be formatted/pretty-printed")
    }

    // MARK: - Custom Options Tests

    func testDataExport_SupportsIncludeMetadataOption() {
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
        XCTAssertTrue(
            jsonWithMetadata.contains("metadata") ||
            jsonWithMetadata.contains("version") ||
            jsonWithMetadata.contains("created"),
            "Should include metadata when requested"
        )
    }

    // MARK: - Large Data Tests

    func testDataExport_HandlesLargeTimeSeries() {
        // Given: A large time series
        let periods = (2000...2100).map { Period.year($0) }
        let values = (0..<101).map { Double($0 * 1000) }
        let series = TimeSeries<Double>(periods: periods, values: values)

        // When: Exporting large series
        let exporter = TimeSeriesExporter(series: series)

        // Then: Should complete without errors
        XCTAssertNoThrow(exporter.exportToCSV())
        XCTAssertNoThrow(exporter.exportToJSON())

        let csvOutput = exporter.exportToCSV()
        XCTAssertGreaterThan(csvOutput.count, 1000, "Should have substantial output for large series")
    }
}
