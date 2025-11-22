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
	
		//	@Test("Import wide format (periods as columns)")
		//	func importWideFormat() throws {
		//		// Wide format has accounts as rows and periods as columns:
		//		let csv = """
		//		Account,2024-Q1,2024-Q2,2024-Q3
		//		Revenue,100000,110000,120000
		//		Costs,60000,65000,70000
		//		"""
		//
		//		let fileURL = try createTempCSV(content: csv)
		//		defer { try? FileManager.default.removeItem(at: fileURL) }
		//
		//		// Configure for wide format import
		//		let config = CSVImporter.WideFormatConfig(
		//			accountColumn: "Account",
		//			periodColumns: ["2024-Q1", "2024-Q2", "2024-Q3"]
		//		)
		//
		//		// Import wide format - should return dictionary of account -> time series
		//		let series: [String: TimeSeries<Double>] = try CSVImporter().importWideFormat(
		//			from: fileURL,
		//			config: config
		//		)
		//
		//		// Verify correct number of accounts extracted
		//		#expect(series.count == 2, "Should extract 2 accounts (Revenue and Costs)")
		//
		//		// Verify accounts are present
		//		#expect(series["Revenue"] != nil, "Should have Revenue account")
		//		#expect(series["Costs"] != nil, "Should have Costs account")
		//
		//		// Verify period sequence matches column headers
		//		if let revenueSeries = series["Revenue"] {
		//			#expect(revenueSeries.periods.count == 3, "Should have 3 periods")
		//
		//			// Verify values are correctly mapped
		//			#expect(revenueSeries.valuesArray[0] == 100_000, "Q1 Revenue should be 100,000")
		//			#expect(revenueSeries.valuesArray[1] == 110_000, "Q2 Revenue should be 110,000")
		//			#expect(revenueSeries.valuesArray[2] == 120_000, "Q3 Revenue should be 120,000")
		//		}
		//
		//		if let costsSeries = series["Costs"] {
		//			#expect(costsSeries.periods.count == 3, "Should have 3 periods")
		//
		//			// Verify values are correctly mapped
		//			#expect(costsSeries.valuesArray[0] == 60_000, "Q1 Costs should be 60,000")
		//			#expect(costsSeries.valuesArray[1] == 65_000, "Q2 Costs should be 65,000")
		//			#expect(costsSeries.valuesArray[2] == 70_000, "Q3 Costs should be 70,000")
		//		}
		//	}
	
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
	
	@Test("Import simple time series - verify parsed periods")
	func importSimpleTimeSeries_periods() throws {
		let csv = """
	 Date,Revenue
	 2024-01-01,100000
	 2024-02-01,110000
	 2024-03-01,120000
	 2024-04-01,130000
	 """
		
		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }
		
		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Revenue")
		let ts: TimeSeries<Double> = try CSVImporter().importTimeSeries(from: fileURL, config: config)
		
		#expect(ts.periods.count == 4)
		#expect(ts.valuesArray.first == 100_000)
			// Check the first and last day periods match the input dates
		#expect(ts.periods[0] == .day(ISO8601DateFormatter().date(from: "2024-01-01T00:00:00Z")!),
				"If daylight/timezone handling differs, normalize using your Period equality")
	}
	
	@Test("Import missing values - skipped rows (deterministic)")
	func importWithMissingValues_skips() throws {
		let csv = """
	 Date,Revenue
	 2024-01-01,100000
	 2024-02-01,
	 2024-03-01,120000
	 2024-04-01,130000
	 """
		
		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }
		
		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Revenue")
		let ts: TimeSeries<Double> = try CSVImporter().importTimeSeries(from: fileURL, config: config)
		
		#expect(ts.periods.count == 3, "Missing rows should be skipped")
		#expect(ts.valuesArray == [100_000, 120_000, 130_000])
	}
	
	@Test("Import quarter labels like 2024-Q1")
	func importQuarterLabels() throws {
		let csv = """
	 Period,Value
	 2024-Q1,100
	 2024-Q2,200
	 """
		
		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }
		
		let config = CSVImporter.MappingConfig(periodColumn: "Period", valueColumn: "Value")
		let ts: TimeSeries<Double> = try CSVImporter().importTimeSeries(from: fileURL, config: config)
		
		#expect(ts.periods.count == 2)
		#expect(ts.periods[0] == .quarter(year: 2024, quarter: 1))
		#expect(ts.periods[1] == .quarter(year: 2024, quarter: 2))
	}
	
	@Test("Import trims whitespace")
	func importTrimsWhitespace() throws {
		let csv = """
	 Date,Value
	  2024-01-01 , 100000
	 """
		
		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }
		
		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Value")
		let ts: TimeSeries<Double> = try CSVImporter().importTimeSeries(from: fileURL, config: config)
		
		#expect(ts.valuesArray == [100_000])
		#expect(ts.periods.count == 1)
	}
	
//	@Test(.disabled("Import multiple time series - alignment and lengths"))
//	func importMultiple_alignment() throws {
//		let csv = """
//	 Date,Revenue,Costs
//	 2024-01-01,100000,60000
//	 2024-02-01,110000,65000
//	 """
//		
//		let fileURL = try createTempCSV(content: csv)
//		defer { try? FileManager.default.removeItem(at: fileURL) }
//		
//		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Revenue")
//		let series = try CSVImporter().importMultipleTimeSeries(from: fileURL, config: config)
//		
//		#expect(series.keys.sorted() == ["Costs", "Revenue"])
//		let r = try #require(series["Revenue"])
//		let c = try #require(series["Costs"])
//		
//		#expect(r.periods == c.periods, "Periods should align across series")
//		#expect(r.valuesArray.count == 2 && c.valuesArray.count == 2)
//		#expect(r.valuesArray == [100_000, 110_000])
//		#expect(c.valuesArray == [60_000, 65_000])
//	}
	
//	@Test(.disabled("Missing value column should throw missingColumn"))
//	func importMissingColumnThrows() throws {
//		let csv = """
//	 Date,Wrong
//	 2024-01-01,100000
//	 """
//		
//		let fileURL = try createTempCSV(content: csv)
//		defer { try? FileManager.default.removeItem(at: fileURL) }
//		
//		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Revenue")
//		
//		do {
//			_ = try CSVImporter().importTimeSeries(from: fileURL, config: config)
//			Issue.record("Expected CSVImportError.missingColumn")
//		} catch let err as CSVImportError {
//			switch err {
//				case .missingColumn(let name):
//					#expect(name == "Revenue")
//				default:
//					Issue.record("Unexpected CSVImportError: \(err)")
//			}
//		}
//	}
	
	@Test("Malformed CSV row is skipped (deterministic)")
	func malformedRowSkipped() throws {
		let csv = """
	 Date,Revenue
	 2024-01-01,100000
	 2024-02-01,invalid
	 2024-03-01,120000
	 """
		
		let fileURL = try createTempCSV(content: csv)
		defer { try? FileManager.default.removeItem(at: fileURL) }
		
		let config = CSVImporter.MappingConfig(periodColumn: "Date", valueColumn: "Revenue")
		let ts: TimeSeries<Double> = try CSVImporter().importTimeSeries(from: fileURL, config: config)
		
		#expect(ts.valuesArray == [100_000, 120_000])
		#expect(ts.periods.count == 2)
	}
}
