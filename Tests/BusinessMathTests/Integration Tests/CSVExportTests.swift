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
}
