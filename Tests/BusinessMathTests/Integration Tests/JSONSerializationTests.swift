import Testing
import Foundation
@testable import BusinessMath

@Suite("JSON Serialization Tests")
struct JSONSerializationTests {

	// MARK: - Basic Types

	@Test("Encode and decode TimeSeries")
	func timeSeriesCodable() throws {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2)
		]
		let values = [100_000.0, 110_000.0]
		let original = TimeSeries(periods: periods, values: values)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(TimeSeries<Double>.self, from: data)

		#expect(decoded.periods.count == original.periods.count)
		#expect(decoded.valuesArray == original.valuesArray)
	}

	@Test("Encode and decode Period")
	func periodCodable() throws {
		let original = Period.quarter(year: 2024, quarter: 3)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(Period.self, from: data)

		#expect(decoded == original)
	}

	@Test("Encode and decode Entity")
	func entityCodable() throws {
		let original = Entity(
			id: "ACME",
			primaryType: .ticker,
			name: "Acme Corp",
			fiscalYearEnd: MonthDay(month: 12, day: 31)
		)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(Entity.self, from: data)

		#expect(decoded.name == original.name)
		#expect(decoded.id == original.id)
	}

	@Test("Encode and decode Account")
	func accountCodable() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [Period.quarter(year: 2024, quarter: 1)]
		let values = [50_000.0]
		let timeSeries = TimeSeries(periods: periods, values: values)

		let original = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: timeSeries
		)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(Account<Double>.self, from: data)

		#expect(decoded.name == original.name)
		#expect(decoded.balanceSheetRole == original.balanceSheetRole)
		#expect(decoded.timeSeries.valuesArray == original.timeSeries.valuesArray)
	}

	// MARK: - Financial Statements

	@Test("Encode and decode IncomeStatement")
	func incomeStatementCodable() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: periods, values: [100_000.0])
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: periods, values: [60_000.0]),
		)

		let original = try IncomeStatement(
			entity: entity,
			periods: periods,
			accounts: [revenue, cogs]
		)

		let encoder = JSONEncoder()
		encoder.outputFormatting = .prettyPrinted
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(IncomeStatement<Double>.self, from: data)

		#expect(decoded.entity.name == original.entity.name)
		#expect(decoded.periods.count == original.periods.count)
		#expect(decoded.totalRevenue.valuesArray == original.totalRevenue.valuesArray)
	}

	@Test("Encode and decode BalanceSheet")
	func balanceSheetCodable() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Co")
		let periods = [Period.quarter(year: 2024, quarter: 1)]

		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0]),
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			balanceSheetRole: .commonStock,
			timeSeries: TimeSeries(periods: periods, values: [50_000.0]),
		)

		let original = try BalanceSheet(
			entity: entity,
			periods: periods,
			accounts: [cash, equity]
		)

		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		let decoder = JSONDecoder()
		let decoded = try decoder.decode(BalanceSheet<Double>.self, from: data)

		#expect(decoded.entity.name == original.entity.name)
		#expect(decoded.totalAssets.valuesArray == original.totalAssets.valuesArray)
	}

	// MARK: - JSON Utilities

	@Test("Export to JSON file with pretty printing")
	func exportToJSONFile() throws {
		let periods = [Period.quarter(year: 2024, quarter: 1)]
		let values = [100_000.0]
		let timeSeries = TimeSeries(periods: periods, values: values)

		let tempDir = FileManager.default.temporaryDirectory
		let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
		defer { try? FileManager.default.removeItem(at: fileURL) }

		// Use an encoder with pretty printing
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let serializer = JSONSerializer(encoder: encoder)

		try serializer.exportToJSON(
			timeSeries,
			to: fileURL
		)

		let content = try String(contentsOf: fileURL, encoding: .utf8)
		#expect(content.contains("{"))
		#expect(content.contains("periods"))
		#expect(content.contains("values"))

		// Verify it's pretty printed (has newlines)
		#expect(content.contains("\n"))
	}

	@Test("Import from JSON file")
	func importFromJSONFile() throws {
		let original = TimeSeries(
			periods: [Period.quarter(year: 2024, quarter: 1)],
			values: [100_000.0]
		)

		let tempDir = FileManager.default.temporaryDirectory
		let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
		defer { try? FileManager.default.removeItem(at: fileURL) }

		// Export
		try JSONSerializer().exportToJSON(original, to: fileURL)

		// Import
		let imported = try JSONSerializer().importFromJSON(
			TimeSeries<Double>.self,
			from: fileURL
		)

		#expect(imported.periods.count == original.periods.count)
		#expect(imported.valuesArray == original.valuesArray)
	}

	@Test("Convert to JSON string")
	func toJSONString() throws {
		let timeSeries = TimeSeries(
			periods: [Period.quarter(year: 2024, quarter: 1)],
			values: [100_000.0]
		)

		let jsonString = try JSONSerializer().toJSONString(timeSeries, pretty: false)

		#expect(jsonString.contains("periods"))
		#expect(jsonString.contains("values"))
		#expect(jsonString.contains("100000"))
	}

	@Test("Parse from JSON string")
	func fromJSONString() throws {
		// First generate valid JSON
		let original = TimeSeries(
			periods: [Period.quarter(year: 2024, quarter: 1)],
			values: [100_000.0]
		)
		let jsonString = try JSONSerializer().toJSONString(original)

		// Then parse it back
		let timeSeries = try JSONSerializer().fromJSONString(
			TimeSeries<Double>.self,
			from: jsonString
		)

		#expect(timeSeries.periods.count == 1)
		#expect(timeSeries.valuesArray[0] == 100_000.0)
	}
	@Test("Decode invalid JSON throws")
			func decodeInvalidJSONThrows() throws {
					let invalid = "{ not valid json }".data(using: .utf8)!
					do {
							_ = try JSONDecoder().decode(TimeSeries<Double>.self, from: invalid)
							Issue.record("Expected decoding to fail")
					} catch {
							// Expected
					}
			}

			@Test("Import from invalid JSON file throws")
			func importInvalidJSONFileThrows() throws {
					let tempDir = FileManager.default.temporaryDirectory
					let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".json")
					defer { try? FileManager.default.removeItem(at: fileURL) }

					try "{not json}".write(to: fileURL, atomically: true, encoding: .utf8)

					do {
							_ = try JSONSerializer().importFromJSON(TimeSeries<Double>.self, from: fileURL)
							Issue.record("Expected import to fail")
					} catch {
							// Expected
					}
			}
}
