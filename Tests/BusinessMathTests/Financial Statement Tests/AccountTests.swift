//
//  AccountTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Account Tests")
struct AccountTests {

	// Test helper: create a simple entity
	func makeEntity() -> Entity {
		return Entity(
			id: "TEST",
			primaryType: .internal,
			name: "Test Company"
		)
	}

	// Test helper: create a simple time series
	func makeTimeSeries() -> TimeSeries<Double> {
		let periods = [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]
		let values: [Double] = [100_000, 110_000, 120_000, 130_000]
		return TimeSeries(periods: periods, values: values)
	}

	// MARK: - Basic Account Creation

	@Test("Account can be created with minimal parameters")
	func accountCreationMinimal() throws {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		let account = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: timeSeries
		)

		#expect(account.entity == entity)
		#expect(account.name == "Revenue")
		#expect(account.incomeStatementRole == .revenue)
		#expect(account.timeSeries.periods.count == 4)
		#expect(account.metadata == nil)
	}

	@Test("Account can be created with metadata")
	func accountCreationWithMetadata() throws {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		var metadata = AccountMetadata()
		metadata.category = "Sales"
		metadata.subCategory = "Product Revenue"
		metadata.tags = ["recurring", "core"]
		metadata.description = "Primary product sales"

		let account = try Account(
			entity: entity,
			name: "Product Revenue",
			incomeStatementRole: .revenue,
			timeSeries: timeSeries,
			metadata: metadata
		)

		#expect(account.metadata?.category == "Sales")
		#expect(account.metadata?.subCategory == "Product Revenue")
		#expect(account.metadata?.tags.count == 2)
		#expect(account.metadata?.description == "Primary product sales")
	}

	// MARK: - Validation Tests

	@Test("Account creation fails with empty name")
	func accountCreationEmptyName() {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		#expect(throws: AccountError.self) {
			_ = try Account(
				entity: entity,
				name: "",
				incomeStatementRole: .revenue,
				timeSeries: timeSeries
			)
		}
	}

	@Test("Account creation fails with whitespace-only name")
	func accountCreationWhitespaceName() {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		#expect(throws: AccountError.self) {
			_ = try Account(
				entity: entity,
				name: "   ",
				incomeStatementRole: .revenue,
				timeSeries: timeSeries
			)
		}
	}

	@Test("Account creation fails with empty time series")
	func accountCreationEmptyTimeSeries() {
		let entity = makeEntity()
		let emptyTimeSeries = TimeSeries<Double>(periods: [], values: [])

		#expect(throws: AccountError.self) {
			_ = try Account(
				entity: entity,
				name: "Revenue",
				incomeStatementRole: .revenue,
				timeSeries: emptyTimeSeries
			)
		}
	}

	// MARK: - Account Types

	@Test("Revenue account is categorized correctly")
	func revenueAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Sales",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		#expect(account.isIncomeStatement)
		#expect(!account.isBalanceSheet)
		#expect(!account.isCashFlow)
	}

	@Test("Expense account is categorized correctly")
	func expenseAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Cost of Goods Sold",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: makeTimeSeries()
		)

		#expect(account.isIncomeStatement)
		#expect(!account.isBalanceSheet)
		#expect(!account.isCashFlow)
	}

	@Test("Asset account is categorized correctly")
	func assetAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Cash",
			balanceSheetRole: .otherCurrentAssets,
			timeSeries: makeTimeSeries()
		)

		#expect(!account.isIncomeStatement)
		#expect(account.isBalanceSheet)
		#expect(!account.isCashFlow)
	}

	@Test("Liability account is categorized correctly")
	func liabilityAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Accounts Payable",
			balanceSheetRole: .otherCurrentLiabilities,
			timeSeries: makeTimeSeries()
		)

		#expect(!account.isIncomeStatement)
		#expect(account.isBalanceSheet)
		#expect(!account.isCashFlow)
	}

	@Test("Equity account is categorized correctly")
	func equityAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Retained Earnings",
			balanceSheetRole: .commonStock,
			timeSeries: makeTimeSeries()
		)

		#expect(!account.isIncomeStatement)
		#expect(account.isBalanceSheet)
		#expect(!account.isCashFlow)
	}

	@Test("Operating cash flow account is categorized correctly")
	func operatingAccountCategories() throws {
		let account = try Account(
			entity: makeEntity(),
			name: "Cash from Operations",
			cashFlowRole: .otherOperatingActivities,
			timeSeries: makeTimeSeries()
		)

		#expect(!account.isIncomeStatement)
		#expect(!account.isBalanceSheet)
		#expect(account.isCashFlow)
	}

	// MARK: - TimeSeries Access

	@Test("Account time series values can be accessed")
	func timeSeriesAccess() throws {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		let account = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: timeSeries
		)

		let q1 = Period.quarter(year: 2024, quarter: 1)
		let value = account.timeSeries[q1]

		#expect(value == 100_000)
	}

	@Test("Account periods match time series")
	func accountPeriods() throws {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		let account = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: timeSeries
		)

		#expect(account.timeSeries.periods.count == 4)
		#expect(account.timeSeries.periods[0] == Period.quarter(year: 2024, quarter: 1))
		#expect(account.timeSeries.periods[3] == Period.quarter(year: 2024, quarter: 4))
	}

	// MARK: - Equality and Hashing

	@Test("Accounts with same entity, name, and type are equal")
	func accountEquality() throws {
		let entity = makeEntity()

		let account1 = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		let account2 = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		#expect(account1 == account2)
	}

	@Test("Accounts with different names are not equal")
	func accountInequalityDifferentName() throws {
		let entity = makeEntity()

		let account1 = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		let account2 = try Account(
			entity: entity,
			name: "Other Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		#expect(account1 != account2)
	}

	@Test("Accounts with different types are not equal")
	func accountInequalityDifferentType() throws {
		let entity = makeEntity()

		let account1 = try Account(
			entity: entity,
			name: "Cost",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: makeTimeSeries()
		)

		let account2 = try Account(
			entity: entity,
			name: "Cost",
			balanceSheetRole: .otherCurrentAssets,
			timeSeries: makeTimeSeries()
		)

		#expect(account1 != account2)
	}

	@Test("Accounts can be used as dictionary keys")
	func accountAsDictionaryKey() throws {
		let entity = makeEntity()

		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		let cogs = try Account(
			entity: entity,
			name: "COGS",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: makeTimeSeries()
		)

		var dict: [Account<Double>: String] = [:]
		dict[revenue] = "Income"
		dict[cogs] = "Cost"

		#expect(dict[revenue] == "Income")
		#expect(dict[cogs] == "Cost")
		#expect(dict.count == 2)
	}

	// MARK: - Metadata Tests

	@Test("AccountMetadata can be created empty")
	func metadataCreationEmpty() {
		let metadata = AccountMetadata()

		#expect(metadata.description == nil)
		#expect(metadata.category == nil)
		#expect(metadata.subCategory == nil)
		#expect(metadata.tags.isEmpty)
		#expect(metadata.externalId == nil)
	}

	@Test("AccountMetadata can be created with all fields")
	func metadataCreationComplete() {
		let metadata = AccountMetadata(
			description: "Test description",
			category: "Test category",
			subCategory: "Test subcategory",
			tags: ["tag1", "tag2"],
			externalId: "EXT-001"
		)

		#expect(metadata.description == "Test description")
		#expect(metadata.category == "Test category")
		#expect(metadata.subCategory == "Test subcategory")
		#expect(metadata.tags.count == 2)
		#expect(metadata.externalId == "EXT-001")
	}

	@Test("AccountMetadata is equatable")
	func metadataEquatable() {
		let metadata1 = AccountMetadata(
			description: "Test",
			category: "Category",
			tags: ["tag1"]
		)

		let metadata2 = AccountMetadata(
			description: "Test",
			category: "Category",
			tags: ["tag1"]
		)

		let metadata3 = AccountMetadata(
			description: "Different",
			category: "Category",
			tags: ["tag1"]
		)

		#expect(metadata1 == metadata2)
		#expect(metadata1 != metadata3)
	}

	// MARK: - Codable Tests

	@Test("Account is Codable")
	func accountCodable() throws {
		let entity = makeEntity()
		let timeSeries = makeTimeSeries()

		var metadata = AccountMetadata()
		metadata.category = "Sales"

		let account = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: timeSeries,
			metadata: metadata
		)

		let encoded = try JSONEncoder().encode(account)
		let decoded = try JSONDecoder().decode(Account<Double>.self, from: encoded)

		#expect(decoded.entity == account.entity)
		#expect(decoded.name == account.name)
		#expect(decoded.incomeStatementRole == account.incomeStatementRole)
		#expect(decoded.metadata?.category == "Sales")
	}

	@Test("AccountMetadata is Codable")
	func metadataCodable() throws {
		let metadata = AccountMetadata(
			description: "Test",
			category: "Category",
			tags: ["tag1", "tag2"]
		)

		let encoded = try JSONEncoder().encode(metadata)
		let decoded = try JSONDecoder().decode(AccountMetadata.self, from: encoded)

		#expect(decoded == metadata)
	}

	// MARK: - CustomStringConvertible

	@Test("Account has descriptive string representation")
	func accountDescription() throws {
		let entity = Entity(
			id: "AAPL",
			primaryType: .ticker,
			name: "Apple Inc."
		)

		let account = try Account(
			entity: entity,
			name: "Product Revenue",
			incomeStatementRole: .revenue,
			timeSeries: makeTimeSeries()
		)

		let description = account.description
		#expect(description.contains("Apple Inc."))
		#expect(description.contains("Product Revenue"))
		#expect(description.contains("revenue"))
	}
	@Suite("Hashability Semantics Tests")
	struct HashabilitySemanticsTests {

		@Test("Entities with same ID behave as one in a Set")
		func entitySetUniqueness() {
			let e1 = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc.")
			let e2 = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Corporation")
			var set: Set<Entity> = []
			set.insert(e1)
			set.insert(e2)
			#expect(set.count == 1, "Equal entities should not duplicate in a Set")
		}

		@Test("Accounts with same identity behave as one in a Set")
		func accountSetUniqueness() throws {
			let entity = Entity(id: "TEST", primaryType: .internal, name: "Test Co")
			let periods = [Period.quarter(year: 2025, quarter: 1)]
			let ts = TimeSeries(periods: periods, values: [100.0])
			let a1 = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: ts)
			let a2 = try Account(entity: entity, name: "Revenue", incomeStatementRole: .revenue, timeSeries: ts)
			var set: Set<Account<Double>> = []
			set.insert(a1)
			set.insert(a2)
			#expect(set.count == 1, "Equal accounts should not duplicate in a Set")
		}
	}
}
