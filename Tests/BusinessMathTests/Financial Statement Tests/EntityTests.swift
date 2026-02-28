//
//  EntityTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Entity Tests")
struct EntityTests {

	// MARK: - Basic Entity Creation

	@Test("Entity can be created with minimal parameters")
	func entityCreationMinimal() {
		let entity = Entity(
			id: "TEST001",
			name: "Test Company"
		)

		#expect(entity.id == "TEST001")
		#expect(entity.name == "Test Company")
		#expect(entity.primaryIdentifierType == .internal)
		#expect(entity.identifiers.isEmpty)
		#expect(entity.currency == nil)
		#expect(entity.fiscalYearEnd == nil)
		#expect(entity.metadata.isEmpty)
	}

	@Test("Entity can be created with all parameters")
	func entityCreationComplete() {
		var identifiers: [EntityIdentifierType: String] = [:]
		identifiers[.cusip] = "037833100"
		identifiers[.isin] = "US0378331005"

		let entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc.",
			identifiers: identifiers,
			currency: "USD",
			fiscalYearEnd: MonthDay(month: 9, day: 30),
			metadata: ["sector": "Technology"]
		)

		#expect(entity.id == "AAPL")
		#expect(entity.primaryIdentifierType == .ticker)
		#expect(entity.name == "Apple Inc.")
		#expect(entity.identifiers[.cusip] == "037833100")
		#expect(entity.identifiers[.isin] == "US0378331005")
		#expect(entity.currency == "USD")
		#expect(entity.fiscalYearEnd?.month == 9)
		#expect(entity.fiscalYearEnd?.day == 30)
		#expect(entity.metadata["sector"] == "Technology")
	}

	// MARK: - Identifier Retrieval

	@Test("identifier(for:) returns primary ID when type matches")
	func identifierRetrievalPrimary() {
		let entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc."
		)

		let ticker = entity.identifier(for: .ticker)
		#expect(ticker == "AAPL")
	}

	@Test("identifier(for:) returns alternative identifier when available")
	func identifierRetrievalAlternative() {
		var entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc."
		)
		entity.identifiers[.cusip] = "037833100"
		entity.identifiers[.isin] = "US0378331005"

		let cusip = entity.identifier(for: .cusip)
		let isin = entity.identifier(for: .isin)

		#expect(cusip == "037833100")
		#expect(isin == "US0378331005")
	}

	@Test("identifier(for:) returns nil when not found")
	func identifierRetrievalNotFound() {
		let entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc."
		)

		let cusip = entity.identifier(for: .cusip)
		#expect(cusip == nil)
	}

	@Test("identifier(for:) prefers alternative over primary")
	func identifierRetrievalPriority() {
		var entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc."
		)
		// Add ticker as alternative (same type as primary)
		entity.identifiers[.ticker] = "AAPL.O"

		let ticker = entity.identifier(for: .ticker)
		// Should return the alternative, not the primary
		#expect(ticker == "AAPL.O")
	}

	// MARK: - Identifier Types

	@Test("All identifier types can be used")
	func allIdentifierTypes() {
		var entity = Entity(id: "TEST", name: "Test")

		entity.identifiers[.ticker] = "TICK"
		entity.identifiers[.cusip] = "CUSIP123"
		entity.identifiers[.isin] = "US1234567890"
		entity.identifiers[.lei] = "LEI1234567890ABCDEFGH"
		entity.identifiers[.internal] = "INT001"
		entity.identifiers[.taxId] = "12-3456789"
		entity.identifiers[.custom("SEDOL")] = "SEDOL123"

		#expect(entity.identifier(for: .ticker) == "TICK")
		#expect(entity.identifier(for: .cusip) == "CUSIP123")
		#expect(entity.identifier(for: .isin) == "US1234567890")
		#expect(entity.identifier(for: .lei) == "LEI1234567890ABCDEFGH")
		#expect(entity.identifier(for: .internal) == "INT001")
		#expect(entity.identifier(for: .taxId) == "12-3456789")
		#expect(entity.identifier(for: .custom("SEDOL")) == "SEDOL123")
	}

	// MARK: - Equality and Hashing

	@Test("Entities with same ID are equal")
	func entityEqualitySameId() {
		let entity1 = Entity(id: "AAPL", name: "Apple Inc.")
		let entity2 = Entity(id: "AAPL", name: "Apple Corporation")

		#expect(entity1 == entity2)
	}

	@Test("Entities with different IDs are not equal")
	func entityEqualityDifferentId() {
		let entity1 = Entity(id: "AAPL", name: "Apple Inc.")
		let entity2 = Entity(id: "MSFT", name: "Microsoft Corporation")

		#expect(entity1 != entity2)
	}

	@Test("Entities can be used as dictionary keys")
	func entityAsDictionaryKey() {
		let apple = Entity(id: "AAPL", name: "Apple Inc.")
		let microsoft = Entity(id: "MSFT", name: "Microsoft Corporation")

		var dict: [Entity: String] = [:]
		dict[apple] = "Technology"
		dict[microsoft] = "Software"

		#expect(dict[apple] == "Technology")
		#expect(dict[microsoft] == "Software")
		#expect(dict.count == 2)
	}

	@Test("Entities with same ID hash to same value")
	func entityHashingSameId() {
		let entity1 = Entity(id: "AAPL", name: "Apple Inc.")
		let entity2 = Entity(id: "AAPL", name: "Different Name")

		#expect(entity1.hashValue == entity2.hashValue)
	}

	// MARK: - MonthDay Tests

	@Test("MonthDay can be created")
	func monthDayCreation() {
		let monthDay = MonthDay(month: 12, day: 31)

		#expect(monthDay.month == 12)
		#expect(monthDay.day == 31)
	}

	@Test("MonthDay can represent calendar year end")
	func monthDayCalendarYearEnd() {
		let yearEnd = MonthDay(month: 12, day: 31)

		#expect(yearEnd.month == 12)
		#expect(yearEnd.day == 31)
	}

	@Test("MonthDay is hashable")
	func monthDayHashable() {
		let md1 = MonthDay(month: 6, day: 30)
		let md2 = MonthDay(month: 6, day: 30)
		let md3 = MonthDay(month: 12, day: 31)

		#expect(md1 == md2)
		#expect(md1 != md3)
	}

	// MARK: - Codable Tests

	@Test("Entity is Codable")
	func entityCodable() throws {
		var entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc.",
			currency: "USD",
			fiscalYearEnd: MonthDay(month: 9, day: 30),
			metadata: ["sector": "Technology"]
		)
		entity.identifiers[.cusip] = "037833100"

		let encoded = try JSONEncoder().encode(entity)
		let decoded = try JSONDecoder().decode(Entity.self, from: encoded)

		#expect(decoded.id == entity.id)
		#expect(decoded.primaryIdentifierType == entity.primaryIdentifierType)
		#expect(decoded.name == entity.name)
		#expect(decoded.identifiers[.cusip] == "037833100")
		#expect(decoded.currency == "USD")
		#expect(decoded.fiscalYearEnd?.month == 9)
		#expect(decoded.metadata["sector"] == "Technology")
	}

	@Test("MonthDay is Codable")
	func monthDayCodable() throws {
		let monthDay = MonthDay(month: 6, day: 30)

		let encoded = try JSONEncoder().encode(monthDay)
		let decoded = try JSONDecoder().decode(MonthDay.self, from: encoded)

		#expect(decoded.month == 6)
		#expect(decoded.day == 30)
	}

	// MARK: - Metadata Management

	@Test("Entity metadata can be modified")
	func entityMetadataModification() {
		var entity = Entity(id: "TEST", name: "Test Company")

		#expect(entity.metadata.isEmpty)

		entity.metadata["region"] = "EMEA"
		entity.metadata["industry"] = "Finance"

		#expect(entity.metadata["region"] == "EMEA")
		#expect(entity.metadata["industry"] == "Finance")
		#expect(entity.metadata.count == 2)
	}

	@Test("Entity identifiers can be modified")
	func entityIdentifiersModification() {
		var entity = Entity(id: "TEST", name: "Test Company")

		#expect(entity.identifiers.isEmpty)

		entity.identifiers[.ticker] = "TST"
		entity.identifiers[.cusip] = "123456789"

		#expect(entity.identifiers[.ticker] == "TST")
		#expect(entity.identifiers[.cusip] == "123456789")
		#expect(entity.identifiers.count == 2)
	}
}
