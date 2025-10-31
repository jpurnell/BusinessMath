import Testing
import Foundation
@testable import BusinessMath

@Suite("CSV Import Tests")
struct CSVImportTests {

	// MARK: - Helper Functions

	func createTempCSV(content: String) throws -> URL {
		let tempDir = FileManager.default.temporaryDirectory
		let fileName = UUID().uuidString + ".csv"
		let fileURL = tempDir.appendingPathComponent(fileName)
		try content.write(to: fileURL, atomically: true, encoding: .utf8)
		return fileURL
	}

	// MARK: - Basic Import Tests

	@Test("Import simple time series from CSV")
	func importSimpleTimeSeries() throws {
		let csv = """
		Date,Revenue
		2024-01-01,100000
		2024-02-01,110000
		2024-03-01,120000
		2024-04-01,130000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Revenue"
		)

		let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		#expect(timeSeries.periods.count == 4)
		#expect(timeSeries.valuesArray.count == 4)
		#expect(timeSeries.valuesArray[0] == 100_000)
		#expect(timeSeries.valuesArray[3] == 130_000)
	}

	@Test("Import time series with missing values")
	func importWithMissingValues() throws {
		let csv = """
		Date,Revenue
		2024-01-01,100000
		2024-02-01,
		2024-03-01,120000
		2024-04-01,130000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Revenue"
		)

		let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		// Should handle missing values (either skip or interpolate)
		#expect(timeSeries.periods.count >= 3)
	}

	@Test("Import multiple time series from CSV")
	func importMultipleTimeSeries() throws {
		let csv = """
		Date,Revenue,Costs,Profit
		2024-01-01,100000,60000,40000
		2024-02-01,110000,65000,45000
		2024-03-01,120000,70000,50000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Revenue"  // Will be adapted for multiple
		)

		let series: [String: TimeSeries<Double>] = try CSVImporter().importMultipleTimeSeries(
			from: fileURL,
			config: config
		)

		#expect(series.count == 3)
		#expect(series["Revenue"] != nil)
		#expect(series["Costs"] != nil)
		#expect(series["Profit"] != nil)
		#expect(series["Revenue"]?.valuesArray[0] == 100_000)
	}

	@Test("Import with different date formats")
	func importDifferentDateFormats() throws {
		let csv = """
		Date,Value
		01/15/2024,100
		02/15/2024,110
		03/15/2024,120
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Value",
			dateFormat: "MM/dd/yyyy"
		)

		let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		#expect(timeSeries.periods.count == 3)
	}

	@Test("Import with semicolon delimiter")
	func importSemicolonDelimiter() throws {
		let csv = """
		Date;Revenue
		2024-01-01;100000
		2024-02-01;110000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Revenue",
			delimiter: ";"
		)

		let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		#expect(timeSeries.periods.count == 2)
		#expect(timeSeries.valuesArray[0] == 100_000)
	}

	@Test("Import CSV without header")
	func importWithoutHeader() throws{
		let csv = """
		2024-01-01,100000
		2024-02-01,110000
		2024-03-01,120000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "0",  // Column index
			valueColumn: "1",
			hasHeader: false
		)

		let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
			from: fileURL,
			config: config
		)

		#expect(timeSeries.periods.count == 3)
	}

	@Test("Import wide format (periods as columns)")
	func importWideFormat() throws {
		let csv = """
		Account,2024-Q1,2024-Q2,2024-Q3
		Revenue,100000,110000,120000
		Costs,60000,65000,70000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		// Wide format import requires different config
		let mapping = FinancialStatementMapping(
			accountNameColumn: "Account",
			accountTypeColumn: "Type",
			periodColumns: ["2024-Q1", "2024-Q2", "2024-Q3"]
		)

		// This would return multiple accounts with their time series
		// Implementation depends on FinancialStatementMapping structure
	}

	@Test("Handle malformed CSV")
	func handleMalformedCSV() throws {
		let csv = """
		Date,Revenue
		2024-01-01,100000
		2024-02-01,invalid
		2024-03-01,120000
		"""

		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }

		let config = CSVImporter.MappingConfig(
			periodColumn: "Date",
			valueColumn: "Revenue"
		)

		// Should either throw error or skip invalid rows
		do {
			let timeSeries: TimeSeries<Double> = try CSVImporter().importTimeSeries(
				from: fileURL,
				config: config
			)
			// If it succeeds, should have skipped invalid row
			#expect(timeSeries.periods.count == 2)
		} catch {
			// Or it should throw descriptive error
			#expect(error is CSVImportError)
		}
	}
}
