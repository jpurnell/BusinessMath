//
//  BalanceSheetTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Balance Sheet Tests")
struct BalanceSheetTests {

	// MARK: - Test Helpers

	func makeEntity() -> Entity {
		return Entity(
			id: "TEST",
			primaryType: .internal,
			name: "Test Company"
		)
	}

	func makePeriods() -> [Period] {
		return [
			Period.quarter(year: 2024, quarter: 1),
			Period.quarter(year: 2024, quarter: 2),
			Period.quarter(year: 2024, quarter: 3),
			Period.quarter(year: 2024, quarter: 4)
		]
	}

	func makeCashAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [50_000, 55_000, 60_000, 65_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Current"
		return try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeARAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [30_000, 33_000, 36_000, 39_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Current"
		return try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeEquipmentAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [100_000, 95_000, 90_000, 85_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Fixed"
		return try Account(
			entity: entity,
			name: "Equipment",
			type: .asset,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeAPAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [20_000, 22_000, 24_000, 26_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Current"
		return try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeLongTermDebtAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [80_000, 78_000, 76_000, 74_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		var metadata = AccountMetadata()
		metadata.category = "Long-term"
		return try Account(
			entity: entity,
			name: "Long-term Debt",
			type: .liability,
			timeSeries: timeSeries,
			metadata: metadata
		)
	}

	func makeEquityAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [80_000, 83_000, 86_000, 89_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		return try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: timeSeries
		)
	}

	// MARK: - Basic Creation

	@Test("Balance sheet can be created with assets, liabilities, and equity")
	func balanceSheetCreation() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		#expect(balanceSheet.entity == entity)
		#expect(balanceSheet.periods.count == 4)
		#expect(balanceSheet.assetAccounts.count == 1)
		#expect(balanceSheet.liabilityAccounts.count == 1)
		#expect(balanceSheet.equityAccounts.count == 1)
	}

	@Test("Balance sheet can be created with multiple accounts")
	func balanceSheetMultipleAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, equipment],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		#expect(balanceSheet.assetAccounts.count == 3)
		#expect(balanceSheet.liabilityAccounts.count == 2)
		#expect(balanceSheet.equityAccounts.count == 1)
	}

	// MARK: - Validation Tests

	@Test("Balance sheet creation fails with entity mismatch")
	func balanceSheetEntityMismatch() throws {
		let entity1 = makeEntity()
		let entity2 = Entity(id: "OTHER", primaryType: .internal, name: "Other Company")
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity1, periods: periods)
		let ap = try makeAPAccount(entity: entity2, periods: periods)
		let equity = try makeEquityAccount(entity: entity1, periods: periods)

		#expect(throws: BalanceSheetError.self) {
			_ = try BalanceSheet(
				entity: entity1,
				periods: periods,
				assetAccounts: [cash],
				liabilityAccounts: [ap],
				equityAccounts: [equity]
			)
		}
	}

	@Test("Balance sheet creation fails with wrong account type in assets")
	func balanceSheetWrongAssetType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let liability = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		#expect(throws: BalanceSheetError.self) {
			_ = try BalanceSheet(
				entity: entity,
				periods: periods,
				assetAccounts: [liability], // Wrong type!
				liabilityAccounts: [],
				equityAccounts: [equity]
			)
		}
	}

	@Test("Balance sheet creation fails with wrong account type in liabilities")
	func balanceSheetWrongLiabilityType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		#expect(throws: BalanceSheetError.self) {
			_ = try BalanceSheet(
				entity: entity,
				periods: periods,
				assetAccounts: [cash],
				liabilityAccounts: [cash], // Wrong type!
				equityAccounts: [equity]
			)
		}
	}

	@Test("Balance sheet creation fails with wrong account type in equity")
	func balanceSheetWrongEquityType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)

		#expect(throws: BalanceSheetError.self) {
			_ = try BalanceSheet(
				entity: entity,
				periods: periods,
				assetAccounts: [cash],
				liabilityAccounts: [ap],
				equityAccounts: [cash] // Wrong type!
			)
		}
	}

	// MARK: - Aggregated Totals

	@Test("Total assets is sum of all asset accounts")
	func totalAssets() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar],
			liabilityAccounts: [],
			equityAccounts: []
		)

		let total = balanceSheet.totalAssets
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 80_000) // 50k + 30k
	}

	@Test("Total liabilities is sum of all liability accounts")
	func totalLiabilities() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [],
			liabilityAccounts: [ap, debt],
			equityAccounts: []
		)

		let total = balanceSheet.totalLiabilities
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 100_000) // 20k + 80k
	}

	@Test("Total equity is sum of all equity accounts")
	func totalEquity() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let equity1 = try makeEquityAccount(entity: entity, periods: periods)

		let values2: [Double] = [10_000, 11_000, 12_000, 13_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let equity2 = try Account(
			entity: entity,
			name: "Common Stock",
			type: .equity,
			timeSeries: timeSeries2
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [],
			liabilityAccounts: [],
			equityAccounts: [equity1, equity2]
		)

		let total = balanceSheet.totalEquity
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 90_000) // 80k + 10k
	}

	// MARK: - Current Assets/Liabilities

	@Test("Current assets are assets with Current category")
	func currentAssets() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, equipment],
			liabilityAccounts: [],
			equityAccounts: []
		)

		let current = balanceSheet.currentAssets
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Only cash and AR are current (50k + 30k)
		#expect(current[q1] == 80_000)
	}

	@Test("Current liabilities are liabilities with Current category")
	func currentLiabilities() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [],
			liabilityAccounts: [ap, debt],
			equityAccounts: []
		)

		let current = balanceSheet.currentLiabilities
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Only AP is current (20k)
		#expect(current[q1] == 20_000)
	}

	// MARK: - Financial Ratios

	@Test("Current ratio is current assets divided by current liabilities")
	func currentRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let ratio = balanceSheet.currentRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Current Assets: 80k, Current Liabilities: 20k, Ratio: 4.0
		#expect(ratio[q1] == 4.0)
	}

	@Test("Debt to equity is total liabilities divided by total equity")
	func debtToEquity() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		let ratio = balanceSheet.debtToEquity
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Liabilities: 100k, Equity: 80k, Ratio: 1.25
		#expect(ratio[q1] == 1.25)
	}

	@Test("Equity ratio is total equity divided by total assets")
	func equityRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, equipment],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		let ratio = balanceSheet.equityRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Assets: 180k, Equity: 80k, Ratio: 0.444...
		let expectedRatio = 80_000.0 / 180_000.0
		#expect(abs(ratio[q1]! - expectedRatio) < 0.001)
	}

	@Test("Working capital is current assets minus current liabilities")
	func workingCapital() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let wc = balanceSheet.workingCapital
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Current Assets: 80k, Current Liabilities: 20k, WC: 60k
		#expect(wc[q1] == 60_000)
	}

	// MARK: - Accounting Equation Validation

	@Test("Validate passes when assets equal liabilities plus equity")
	func validatePassesWhenBalanced() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, equipment], // 50+30+100 = 180
			liabilityAccounts: [ap, debt],         // 20+80 = 100
			equityAccounts: [equity]               // 80
		)

		// Should not throw
		try balanceSheet.validate(tolerance: 0.01)
	}

	@Test("Validate fails when assets do not equal liabilities plus equity")
	func validateFailsWhenUnbalanced() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Create unbalanced balance sheet
		let values1: [Double] = [100_000, 100_000, 100_000, 100_000]
		let timeSeries1 = TimeSeries(periods: periods, values: values1)
		let cash = try Account(entity: entity, name: "Cash", type: .asset, timeSeries: timeSeries1)

		let values2: [Double] = [50_000, 50_000, 50_000, 50_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let ap = try Account(entity: entity, name: "AP", type: .liability, timeSeries: timeSeries2)

		let values3: [Double] = [30_000, 30_000, 30_000, 30_000]
		let timeSeries3 = TimeSeries(periods: periods, values: values3)
		let equity = try Account(entity: entity, name: "Equity", type: .equity, timeSeries: timeSeries3)

		// Assets: 100k, Liabilities: 50k, Equity: 30k
		// 100k != 80k (unbalanced!)
		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		#expect(throws: BalanceSheetError.self) {
			try balanceSheet.validate(tolerance: 0.01)
		}
	}

	// MARK: - Materialization

	@Test("Materialized balance sheet has all metrics pre-computed")
	func materialization() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, equipment],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		let materialized = balanceSheet.materialize()

		#expect(materialized.entity == entity)
		#expect(materialized.periods.count == 4)

		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Check all pre-computed metrics
		#expect(materialized.totalAssets[q1] == 180_000)
		#expect(materialized.totalLiabilities[q1] == 100_000)
		#expect(materialized.totalEquity[q1] == 80_000)
		#expect(materialized.currentAssets[q1] == 80_000)
		#expect(materialized.currentLiabilities[q1] == 20_000)
		#expect(materialized.currentRatio[q1] == 4.0)
		#expect(materialized.debtToEquity[q1] == 1.25)
		#expect(materialized.workingCapital[q1] == 60_000)
	}

	// MARK: - Codable

	@Test("Balance sheet is Codable")
	func balanceSheetCodable() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let encoded = try JSONEncoder().encode(balanceSheet)
		let decoded = try JSONDecoder().decode(BalanceSheet<Double>.self, from: encoded)

		#expect(decoded.entity == balanceSheet.entity)
		#expect(decoded.periods.count == balanceSheet.periods.count)
		#expect(decoded.assetAccounts.count == balanceSheet.assetAccounts.count)
		#expect(decoded.liabilityAccounts.count == balanceSheet.liabilityAccounts.count)
		#expect(decoded.equityAccounts.count == balanceSheet.equityAccounts.count)
	}
}
