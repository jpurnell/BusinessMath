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
import TestSupport  // identical(_:_:) — bit-for-bit comparison
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

    @Test("DataExport_ExportsModelToJSON") func LDataExport_ExportsModelToJSON() throws {
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
        let jsonData = try #require(jsonOutput.data(using: .utf8), "Should produce valid UTF-8 data")

        let parsed = try #require(try? JSONSerialization.jsonObject(with: jsonData), "Should be valid JSON")
        _ = parsed

        // And: Should include model data
        #expect(jsonOutput.contains("revenue"), "Should have revenue section")
        #expect(jsonOutput.contains("costs"), "Should have costs section")
        #expect(jsonOutput.contains("Sales"), "Should include Sales component")
        #expect(jsonOutput.contains("Expenses"), "Should include Expenses component")
    }

    @Test("DataExport_ExportsTimeSeriesToJSON") func LDataExport_ExportsTimeSeriesToJSON() throws {
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

        let jsonData = try #require(jsonOutput.data(using: .utf8))

        let parsed = try #require(try? JSONSerialization.jsonObject(with: jsonData), "Should be valid JSON")
        _ = parsed

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

    // MARK: - Non-Finite Value Tests

    // JSON has no literal for NaN or ±Infinity: `{"amount": nan}` is not JSON, and handing a
    // non-finite number to `JSONSerialization.data` raises an Objective-C
    // `NSInvalidArgumentException` — not a Swift error, so `try?` does not catch it and the
    // process aborts. `null`, however, *is* legal JSON, and it is self-documenting in band: a
    // consumer reading the export sees that a number is absent and knows. So the export
    // represents the value as `null` rather than refusing — one unusable field does not cost
    // the caller the ten thousand good ones around it.

    @Test("DataExport_EmitsNullForNonFiniteRevenueAmount") func LDataExport_EmitsNullForNonFiniteRevenueAmount() throws {
        // Given: A model whose revenue amount is non-finite (e.g. a division by zero
        // upstream in FormulaEvaluator, which returns a non-finite result rather than throwing)
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Good", amount: 100_000))
        model.revenueComponents.append(RevenueComponent(name: "Bad", amount: Double.nan))

        // When: Exporting to JSON
        let exporter = DataExporter(model: model)
        let json = exporter.exportToJSON()

        // Then: The export succeeds and the result is genuinely parseable JSON
        let data = try #require(json.data(using: .utf8), "Should produce UTF-8 data")
        let parsed = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any],
            "Export must round-trip through a real JSON parser: \(json)"
        )

        let revenue = try #require(parsed["revenue"] as? [[String: Any]], "Should have a revenue array")
        #expect(revenue.count == 2, "Neither component may be dropped: \(json)")

        // And: The finite component is untouched
        #expect(revenue[0]["name"] as? String == "Good")
        #expect(revenue[0]["amount"] as? Double == 100_000)

        // And: The non-finite one is JSON null — not a substituted zero, not a missing key
        #expect(revenue[1]["name"] as? String == "Bad")
        let badAmount = try #require(revenue[1]["amount"], "The key must survive, carrying null")
        #expect(badAmount is NSNull, "NaN must be represented as null, not \(badAmount)")
        #expect(json.contains("\"amount\" : null"), "Emitted text should read null: \(json)")
    }

    @Test("DataExport_EmitsNullForBothInfinities") func LDataExport_EmitsNullForBothInfinities() throws {
        // Given: A model carrying +infinity, -infinity and NaN across both cost shapes
        var model = FinancialModel()
        model.costComponents.append(CostComponent(name: "Runaway", type: .variable(Double.infinity)))
        model.costComponents.append(CostComponent(name: "Collapse", type: .variable(-Double.infinity)))
        model.costComponents.append(CostComponent(name: "Undefined", type: .variable(Double.nan)))
        model.costComponents.append(CostComponent(name: "Unbounded", type: .fixed(Double.infinity)))

        let exporter = DataExporter(model: model)
        let json = exporter.exportToJSON()

        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let costs = try #require(parsed["costs"] as? [[String: Any]])
        #expect(costs.count == 4, "Every component survives: \(json)")

        // Then: Each non-finite value — in either direction — is null, and the surrounding
        // structure (name, type discriminator) is intact
        for (index, expectedKey) in [(0, "percentage"), (1, "percentage"), (2, "percentage"), (3, "amount")] {
            let value = try #require(costs[index][expectedKey], "costs[\(index)].\(expectedKey) must be present")
            #expect(value is NSNull, "costs[\(index)].\(expectedKey) should be null, was \(value)")
        }
        #expect(costs[0]["name"] as? String == "Runaway")
        #expect(costs[1]["type"] as? String == "variable")
        #expect(costs[3]["type"] as? String == "fixed")
    }

    @Test("DataExport_EmitsNullForNonFiniteTimeSeriesValue") func LDataExport_EmitsNullForNonFiniteTimeSeriesValue() throws {
        // Given: A time series containing non-finite observations
        let series = TimeSeries<Double>(
            periods: [.year(2023), .year(2024), .year(2025)],
            values: [1000, -Double.infinity, Double.nan]
        )

        let exporter = TimeSeriesExporter(series: series)
        let json = exporter.exportToJSON()

        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let observations = try #require(parsed["data"] as? [[String: Any]])
        #expect(observations.count == 3, "No observation is dropped: \(json)")

        // Then: The finite observation keeps its value; the others become null but keep
        // their period, so the series stays aligned with its index
        #expect(observations[0]["value"] as? Double == 1000)
        let negInf = try #require(observations[1]["value"])
        #expect(negInf is NSNull, "-Infinity should be null, was \(negInf)")
        #expect(observations[1]["period"] as? String != nil, "The period label must survive")
        let nan = try #require(observations[2]["value"])
        #expect(nan is NSNull, "NaN should be null, was \(nan)")
    }

    @Test("DataExport_EmitsNullForNonFiniteInvestmentCashFlow") func LDataExport_EmitsNullForNonFiniteInvestmentCashFlow() throws {
        // Given: An investment with a non-finite cash flow amount
        let investment = Investment {
            InitialCost(50_000)
            CashFlows {
                [
                    CashFlow(period: 1, amount: 15_000),
                    CashFlow(period: 2, amount: Double.nan)
                ]
            }
            DiscountRate(0.10)
        }

        let exporter = InvestmentExporter(investment: investment)
        let json = exporter.exportToJSON()

        let data = try #require(json.data(using: .utf8))
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let cashFlows = try #require(parsed["cash_flows"] as? [[String: Any]])
        #expect(cashFlows.count == 2, "Both cash flows survive: \(json)")

        // Then: The good cash flow is fully intact — including its derived present value
        #expect(cashFlows[0]["amount"] as? Double == 15_000)
        #expect(cashFlows[0]["present_value"] as? Double != nil)

        // And: The bad one nulls both the amount and the present value derived from it
        let amount = try #require(cashFlows[1]["amount"])
        #expect(amount is NSNull, "NaN amount should be null, was \(amount)")
        let presentValue = try #require(cashFlows[1]["present_value"])
        #expect(presentValue is NSNull, "A present value derived from NaN should be null, was \(presentValue)")
        #expect(cashFlows[1]["period"] as? Int == 2, "The period is finite and must survive")
    }

    @Test("DataExport_NonFiniteValueNeverReachesJSONSerialization") func LDataExport_NonFiniteValueNeverReachesJSONSerialization() throws {
        // This is the regression test for the defect that started all of this, and it asserts
        // the mechanism rather than the symptom. `JSONSerialization.data(withJSONObject:)`
        // does not *throw* on a non-finite number — it raises an Objective-C
        // `NSInvalidArgumentException`, which `try?` cannot catch, so the process dies with
        // SIGABRT. The guarantee is therefore not "export throws" and not "export returns
        // something"; it is "a non-finite number is never handed to JSONSerialization at all".
        let hostile: [String: Any] = [
            "nan": Double.nan,
            "positiveInfinity": Double.infinity,
            "negativeInfinity": -Double.infinity,
            "float": Float.nan,
            "nested": ["rows": [["value": Double.nan]]],
            "finite": 42.0,
            "text": "unchanged"
        ]

        // Given: This really is a dictionary that would kill the process. If this expectation
        // ever fails, the hazard has changed and the test below has stopped meaning anything.
        #expect(
            !JSONSerialization.isValidJSONObject(hostile),
            "The fixture must actually be un-serializable, or this test proves nothing"
        )

        // When: It is sanitized
        let sanitized = sanitizedForJSON(hostile)

        // Then: It is safe to serialize — and serializing it does not abort. Reaching the
        // line after this call is itself the assertion the original defect failed.
        #expect(JSONSerialization.isValidJSONObject(sanitized), "Sanitized graph must be serializable")
        let data = try JSONSerialization.data(withJSONObject: sanitized, options: [.sortedKeys])
        let parsed = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        // And: Only the non-finite values changed
        #expect(parsed["nan"] is NSNull)
        #expect(parsed["positiveInfinity"] is NSNull)
        #expect(parsed["negativeInfinity"] is NSNull)
        #expect(parsed["float"] is NSNull, "Float is walked too, not only Double")
        // "Untouched" is a claim about the bits, not about proximity: the sanitizer must
        // hand a finite number straight through, and a tolerance would let it round-trip
        // the value through a lossy path and still pass.
        let finite = try #require(parsed["finite"] as? Double)
        #expect(identical(finite, 42.0), "Finite numbers are untouched")
        #expect(parsed["text"] as? String == "unchanged", "Non-numeric values are untouched")

        let nested = try #require(parsed["nested"] as? [String: Any])
        let rows = try #require(nested["rows"] as? [[String: Any]])
        let nestedValue = try #require(rows[0]["value"])
        #expect(nestedValue is NSNull, "The walk descends through nested arrays and dictionaries")
    }

    @Test("DataExport_SanitizerTerminatesOnPathologicalNesting") func LDataExport_SanitizerTerminatesOnPathologicalNesting() {
        // The walker is recursive, so its depth guard is load-bearing. Past the limit a
        // subtree cannot be certified finite, so it becomes null — the same in-band signal,
        // never an unbounded recursion and never an un-serializable graph.
        var deep: Any = Double.nan
        for _ in 0..<200 {
            deep = ["child": deep]
        }

        let sanitized = sanitizedForJSON(["root": deep])
        #expect(
            JSONSerialization.isValidJSONObject(sanitized),
            "A graph deeper than the guard must still be serializable"
        )
    }

    @Test("DataExport_JSONFormatIsUnchangedForFiniteModels") func LDataExport_JSONFormatIsUnchangedForFiniteModels() {
        // Given: A model with only finite values
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

        // Then: Output is byte-for-byte what it was before any of the non-finite work —
        // before the throwing change and before the null change. A model whose values were
        // always finite must be entirely unaffected by either.
        let expected = """
        {
          "costs" : [
            {
              "amount" : 40000,
              "name" : "Expenses",
              "type" : "fixed"
            }
          ],
          "revenue" : [
            {
              "amount" : 100000,
              "name" : "Sales"
            }
          ]
        }
        """
        #expect(jsonOutput == expected, "JSON format regressed:\n\(jsonOutput)")
    }

    @Test("DataExport_CSVWritesASCIITokensForNonFiniteValues") func LDataExport_CSVWritesASCIITokensForNonFiniteValues() {
        // Given: A model with non-finite amounts in both the Amount and Percentage columns
        //
        // Unlike JSON — which has no representation for a non-finite number and therefore
        // refuses — CSV can carry one faithfully. `nan` / `inf` / `-inf` are the tokens that
        // `Double(_: String)`, strtod, pandas and R all round-trip, so CSV export emits the
        // value rather than refusing. What it must never emit is a *display* glyph.
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Bad", amount: Double.nan))
        model.costComponents.append(CostComponent(name: "Runaway", type: .variable(Double.infinity)))
        model.costComponents.append(CostComponent(name: "Collapse", type: .variable(-Double.infinity)))
        model.costComponents.append(CostComponent(name: "Undefined", type: .variable(Double.nan)))
        model.costComponents.append(CostComponent(name: "Unbounded", type: .fixed(Double.infinity)))

        // When: Exporting to CSV
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Every column uses the same lowercase ASCII token
        #expect(csvOutput.contains("Bad,Revenue,Fixed,nan,"), "Amount column writes 'nan': \(csvOutput)")
        #expect(csvOutput.contains("Unbounded,Cost,Fixed,inf,"), "Amount column writes 'inf': \(csvOutput)")
        #expect(csvOutput.contains("Runaway,Cost,Variable,,inf"), "Percentage column writes 'inf': \(csvOutput)")
        #expect(csvOutput.contains("Collapse,Cost,Variable,,-inf"), "Percentage column writes '-inf': \(csvOutput)")
        #expect(csvOutput.contains("Undefined,Cost,Variable,,nan"), "Percentage column writes 'nan': \(csvOutput)")

        // And: No display glyph reaches a data column
        #expect(!csvOutput.contains("∞"), "CSV must not contain the display glyph: \(csvOutput)")
        #expect(!csvOutput.contains("NaN"), "CSV must not contain the display casing: \(csvOutput)")
        let isASCII = csvOutput.unicodeScalars.allSatisfy { $0.isASCII }
        #expect(isASCII, "CSV data columns must be ASCII: \(csvOutput)")
    }

    @Test("DataExport_OptimizedCSVWritesTheSameNonFiniteTokens") func LDataExport_OptimizedCSVWritesTheSameNonFiniteTokens() {
        // Given: The same model exported through the optimized string-building path
        var model = FinancialModel()
        model.revenueComponents.append(RevenueComponent(name: "Bad", amount: Double.nan))
        model.costComponents.append(CostComponent(name: "Runaway", type: .variable(Double.infinity)))
        model.costComponents.append(CostComponent(name: "Collapse", type: .variable(-Double.infinity)))

        let exporter = DataExporter(model: model)
        let optimized = exporter.exportToCSVOptimized()

        // Then: The optimized path agrees with the normal path token-for-token
        #expect(optimized.contains("Bad,Revenue,Fixed,nan,"), "Amount column writes 'nan': \(optimized)")
        #expect(optimized.contains("Runaway,Cost,Variable,,inf"), "Percentage column writes 'inf': \(optimized)")
        #expect(optimized.contains("Collapse,Cost,Variable,,-inf"), "Percentage column writes '-inf': \(optimized)")
        let isASCII = optimized.unicodeScalars.allSatisfy { $0.isASCII }
        #expect(isASCII, "Optimized CSV must be ASCII: \(optimized)")
    }

    @Test("DataExport_TimeSeriesCSVWritesASCIITokensForNonFiniteValues") func LDataExport_TimeSeriesCSVWritesASCIITokensForNonFiniteValues() {
        // Given: A time series with non-finite observations
        let series = TimeSeries<Double>(
            periods: [.year(2023), .year(2024), .year(2025)],
            values: [1000, -Double.infinity, Double.nan]
        )

        let exporter = TimeSeriesExporter(series: series)
        let csvOutput = exporter.exportToCSV()

        // Then: The value column uses the same tokens as every other data column
        #expect(csvOutput.contains("2024,-inf"), "Should write '-inf': \(csvOutput)")
        #expect(csvOutput.contains("2025,nan"), "Should write 'nan': \(csvOutput)")
        let isASCII = csvOutput.unicodeScalars.allSatisfy { $0.isASCII }
        #expect(isASCII, "CSV data columns must be ASCII: \(csvOutput)")
    }

    @Test("DataExport_InvestmentCSVWritesASCIITokensForNonFiniteValues") func LDataExport_InvestmentCSVWritesASCIITokensForNonFiniteValues() {
        // Given: An investment whose present values are non-finite (a -100% discount rate
        // divides every cash flow by zero)
        let investment = Investment {
            InitialCost(50_000)
            CashFlows {
                [
                    CashFlow(period: 1, amount: 15_000),
                    CashFlow(period: 2, amount: -20_000)
                ]
            }
            DiscountRate(-1.0)
        }

        let exporter = InvestmentExporter(investment: investment)
        let csvOutput = exporter.exportToCSV()

        // Then: The derived present values are written as ASCII tokens, never a glyph
        #expect(csvOutput.contains("1,15000.0,inf"), "Present value writes 'inf': \(csvOutput)")
        #expect(csvOutput.contains("2,-20000.0,-inf"), "Present value writes '-inf': \(csvOutput)")
        let isASCII = csvOutput.unicodeScalars.allSatisfy { $0.isASCII }
        #expect(isASCII, "CSV data columns must be ASCII: \(csvOutput)")
    }

    @Test("DataExport_CSVFormatIsUnchangedForFiniteModels") func LDataExport_CSVFormatIsUnchangedForFiniteModels() {
        // Given: A model with only finite values, exercising every column including
        // the variable-cost percentage whose rendering was the one that changed
        let model = FinancialModel {
            Revenue {
                RevenueComponent(name: "Sales", amount: 100_000)
            }

            Costs {
                Fixed("Expenses", 40_000)
                Variable("COGS", 0.30)
            }
        }

        // When: Exporting to CSV
        let exporter = DataExporter(model: model)
        let csvOutput = exporter.exportToCSV()

        // Then: Output is byte-for-byte what it was before the non-finite change.
        // A finite model must be entirely unaffected — only the non-finite branch moved.
        let expected = """
        Component,Type,Category,Amount,Percentage
        Sales,Revenue,Fixed,100000.0,
        Expenses,Cost,Fixed,40000.0,
        COGS,Cost,Variable,,30.00%
        """
        #expect(csvOutput == expected, "CSV format regressed:\n\(csvOutput)")
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
