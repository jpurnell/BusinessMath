import Testing
import Foundation
@testable import BusinessMath

@Suite("CSV Export Tests")
struct CSVExportTests {

	// MARK: - Helper Functions

	func createTempURL() -> URL {
		let tempDir = FileManager.default.temporaryDirectory
		let fileName = UUID().uuidString + ".csv"
		return tempDir.appendingPathComponent(fileName)
	}

	func readCSV(_ url: URL) throws -> String {
		return try String(contentsOf: url, encoding: .utf8)
	}

	// MARK: - Export Tests

	@Test("Export time series to CSV (long format)")
	func exportLongFormat() throws {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3)
		]
		let values = [100_000.0, 110_000.0, 120_000.0]
		let timeSeries = TimeSeries(periods: periods, values: values)

		let fileURL = createTempURL()
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVExporter.ExportConfig(layout: .long)

		try CSVExporter().exportTimeSeries(
			timeSeries,
			to: fileURL,
			config: config
		)

		let content = try readCSV(fileURL)
		#expect(content.contains("Period,Value"))
		// Dates exported as ISO 8601: 2024-01-01, 2024-04-01, 2024-07-01
		#expect(content.contains("2024-01-01,100000"))
		#expect(content.contains("2024-04-01,110000"))
		#expect(content.contains("2024-07-01,120000"))
	}

	@Test("Export time series to CSV (wide format)")
	func exportWideFormat() throws {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3)
		]
		let values = [100_000.0, 110_000.0, 120_000.0]
		let timeSeries = TimeSeries(periods: periods, values: values)

		let fileURL = createTempURL()
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVExporter.ExportConfig(layout: .wide)

		try CSVExporter().exportTimeSeries(
			timeSeries,
			to: fileURL,
			config: config
		)

		let content = try readCSV(fileURL)
		// Wide format with ISO dates: 2024-01-01,2024-04-01,2024-07-01
		//                              100000,110000,120000
		#expect(content.contains("2024-01-01") && content.contains("2024-04-01") && content.contains("2024-07-01"))
		#expect(content.contains("100000") && content.contains("110000") && content.contains("120000"))
	}

	@Test("Export multiple time series")
	func exportMultipleSeries() throws {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]

		let revenue = TimeSeries(periods: periods, values: [100_000.0, 110_000.0])
		let costs = TimeSeries(periods: periods, values: [60_000.0, 65_000.0])

		let series = ["Revenue": revenue, "Costs": costs]

		let fileURL = createTempURL()
		defer { try? FileManager.default.removeItem(at: fileURL) }

		try CSVExporter().exportMultipleTimeSeries(
			series,
			to: fileURL
		)

		let content = try readCSV(fileURL)
		// Column order is alphabetical: Costs, Revenue
		#expect(content.contains("Period") && content.contains("Revenue") && content.contains("Costs"))
		// Dates are ISO 8601: 2024-01-01 for Q1, 2024-04-01 for Q2
		#expect(content.contains("2024-01-01") && content.contains("60000") && content.contains("100000"))
		#expect(content.contains("2024-04-01") && content.contains("65000") && content.contains("110000"))
	}

	@Test("Export with custom number formatting")
	func exportCustomNumberFormat() throws {
		let periods = [Period.quarter(year: 2024, quarter: 1)]
		let values = [1234.5678]
		let timeSeries = TimeSeries(periods: periods, values: values)

		let fileURL = createTempURL()
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 2

		let config = CSVExporter.ExportConfig(numberFormat: formatter)

		try CSVExporter().exportTimeSeries(
			timeSeries,
			to: fileURL,
			config: config
		)

		let content = try readCSV(fileURL)
		#expect(content.contains("1234.57") || content.contains("1,234.57"))
	}

	@Test("Round-trip: export then import")
	func roundTripTest() throws {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]
		let values = [100_000.0, 110_000.0, 120_000.0, 130_000.0]
		let original = TimeSeries(periods: periods, values: values)

		let fileURL = createTempURL()
		defer { try? FileManager.default.removeItem(at: fileURL) }

		// Export
		try CSVExporter().exportTimeSeries(original, to: fileURL)

		// Import
		let config = CSVImporter.MappingConfig(
			periodColumn: "Period",
			valueColumn: "Value"
		)
		let imported: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		// Verify equality
		#expect(imported.periods.count == original.periods.count)
		#expect(imported.valuesArray.count == original.valuesArray.count)

		for i in 0..<original.valuesArray.count {
			#expect(abs(imported.valuesArray[i] - original.valuesArray[i]) < 0.01)
		}
	}
	
	@Test("Export long format - strict header and row order")
	func exportLongFormat_strict() throws {
			let periods = [
					Period.quarter(year: 2024, quarter: 1), // 2024-01-01
					Period.quarter(year: 2024, quarter: 2), // 2024-04-01
					Period.quarter(year: 2024, quarter: 3)  // 2024-07-01
			]
			let values: [Double] = [100_000, 110_000, 120_000]
			let ts = TimeSeries(periods: periods, values: values)

			let fileURL = createTempURL()
			defer { try? FileManager.default.removeItem(at: fileURL) }

			try CSVExporter().exportTimeSeries(ts, to: fileURL, config: .init(layout: .long))

			let content = try readCSV(fileURL)
			let lines = content.split(whereSeparator: \.isNewline).map(String.init)
			#expect(lines.count == 4)

			#expect(lines[0] == "Period,Value")

			// Helper to normalize numeric text (strip thousands separators, keep '.' decimal)
			func parseNumeric(_ s: String) -> Double? {
					let normalized = s.replacingOccurrences(of: ",", with: "")
					return Double(normalized)
			}

			let expected = [
					("2024-01-01", 100_000.0),
					("2024-04-01", 110_000.0),
					("2024-07-01", 120_000.0)
			]

			for i in 1..<lines.count {
					let cols = lines[i].split(separator: ",").map(String.init)
					#expect(cols.count == 2)
					#expect(cols[0] == expected[i-1].0)
					let parsed = parseNumeric(cols[1])
					#expect(parsed != nil && abs(parsed! - expected[i-1].1) < 0.01)
			}
	}

	@Test("Export multiple time series - header order alphabetical and aligned rows")
	func exportMultipleSeries_orderAndAlignment() throws {
			let periods = [
					Period.quarter(year: 2024, quarter: 1), // 2024-01-01
					Period.quarter(year: 2024, quarter: 2)  // 2024-04-01
			]
			let revenue = TimeSeries(periods: periods, values: [100_000, 110_000])
			let costs = TimeSeries(periods: periods, values: [60_000, 65_000])

			let series = ["Revenue": revenue, "Costs": costs]

			let fileURL = createTempURL()
			defer { try? FileManager.default.removeItem(at: fileURL) }

			try CSVExporter().exportMultipleTimeSeries(series, to: fileURL)

			let content = try readCSV(fileURL)
			let lines = content.split(whereSeparator: \.isNewline).map(String.init)
			#expect(lines.count == 3)

			let header = lines[0].split(separator: ",").map(String.init)
			#expect(header == ["Period", "Costs", "Revenue"], "Expect alphabetical order after Period")

			let row1 = lines[1].split(separator: ",").map(String.init)
			let row2 = lines[2].split(separator: ",").map(String.init)

			func parse(_ s: String) -> Double? {
					Double(s.replacingOccurrences(of: ",", with: ""))
			}

			#expect(row1.count == 3 && row1[0] == "2024-01-01")
			#expect(parse(row1[1]) == 60_000 && parse(row1[2]) == 100_000)

			#expect(row2.count == 3 && row2[0] == "2024-04-01")
			#expect(parse(row2[1]) == 65_000 && parse(row2[2]) == 110_000)
	}

}
