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

	// MARK: - Liquidity Ratios (Quick, Cash)

	@Test("Quick Ratio - with inventory")
	func testQuickRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Cash: $50k
		let cash = try makeCashAccount(entity: entity, periods: periods)

		// Accounts Receivable: $30k
		let ar = try makeARAccount(entity: entity, periods: periods)

		// Inventory: $20k (should be excluded from quick ratio)
		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [20_000, 20_000, 20_000, 20_000]),
			metadata: inventoryMetadata
		)

		// Accounts Payable: $20k
		let ap = try makeAPAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar, inventory],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let quickRatio = balanceSheet.quickRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Quick Ratio = (Current Assets - Inventory) / Current Liabilities
		// = (50k + 30k + 20k - 20k) / 20k
		// = 80k / 20k = 4.0
		#expect(quickRatio[q1]! == 4.0, "Quick ratio should be 4.0")

		// Quick ratio should be lower than current ratio (due to inventory exclusion)
		let currentRatio = balanceSheet.currentRatio
		#expect(quickRatio[q1]! < currentRatio[q1]!, "Quick ratio should be less than current ratio when inventory exists")
	}

	@Test("Quick Ratio - no inventory")
	func testQuickRatioNoInventory() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Service company with no inventory
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

		let quickRatio = balanceSheet.quickRatio
		let currentRatio = balanceSheet.currentRatio

		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Without inventory, quick ratio should equal current ratio
		#expect(quickRatio[q1]! == currentRatio[q1]!, "Quick ratio should equal current ratio when no inventory")
	}

	@Test("Cash Ratio - basic calculation")
	func testCashRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Cash: $50k
		let cash = try makeCashAccount(entity: entity, periods: periods)

		// AR: $30k (not included in cash ratio)
		let ar = try makeARAccount(entity: entity, periods: periods)

		// AP: $20k
		let ap = try makeAPAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, ar],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let cashRatio = balanceSheet.cashRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Cash Ratio = Cash / Current Liabilities
		// = 50k / 20k = 2.5
		#expect(cashRatio[q1]! == 2.5, "Cash ratio should be 2.5")

		// Cash ratio should be lower than both current and quick ratios
		let currentRatio = balanceSheet.currentRatio
		let quickRatio = balanceSheet.quickRatio
		#expect(cashRatio[q1]! < quickRatio[q1]!, "Cash ratio should be less than quick ratio")
		#expect(cashRatio[q1]! < currentRatio[q1]!, "Cash ratio should be less than current ratio")
	}

	@Test("Cash Ratio - with marketable securities")
	func testCashRatioWithSecurities() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)

		// Marketable securities should be included in cash ratio
		var securitiesMetadata = AccountMetadata()
		securitiesMetadata.category = "Current"
		let securities = try Account(
			entity: entity,
			name: "Marketable Securities",
			type: .asset,
			timeSeries: TimeSeries(periods: periods, values: [10_000, 10_000, 10_000, 10_000]),
			metadata: securitiesMetadata
		)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, securities],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let cashRatio = balanceSheet.cashRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Cash Ratio = (Cash + Marketable Securities) / Current Liabilities
		// = (50k + 10k) / 20k = 3.0
		#expect(cashRatio[q1]! == 3.0, "Cash ratio should include marketable securities")
	}

	@Test("Cash Ratio - no cash accounts")
	func testCashRatioNoCash() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Company with only AR (no cash)
		let ar = try makeARAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [ar],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let cashRatio = balanceSheet.cashRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// With no cash, cash ratio should be 0
		#expect(cashRatio[q1]! == 0.0, "Cash ratio should be 0 when no cash accounts exist")
	}

	// MARK: - Leverage Ratios (Debt Ratio)

	@Test("Debt Ratio - basic calculation")
	func testDebtRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		let ap = try makeAPAccount(entity: entity, periods: periods)
		let debt = try makeLongTermDebtAccount(entity: entity, periods: periods)

		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, equipment],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		let debtRatio = balanceSheet.debtRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Total Assets = 50k + 100k = 150k
		// Total Liabilities = 20k + 80k = 100k
		// Debt Ratio = 100k / 150k = 0.6667
		let expectedDebtRatio = 100_000.0 / 150_000.0
		#expect(abs(debtRatio[q1]! - expectedDebtRatio) < 0.001, "Debt ratio should be ~0.667")
	}

	@Test("Debt Ratio - no debt")
	func testDebtRatioNoDebt() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		// Company with no liabilities (100% equity financed)
		let cash = try makeCashAccount(entity: entity, periods: periods)
		let equity = try makeEquityAccount(entity: entity, periods: periods)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		let debtRatio = balanceSheet.debtRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Debt Ratio = 0 / 50k = 0
		#expect(debtRatio[q1]! == 0.0, "Debt ratio should be 0 with no liabilities")
	}

	@Test("Debt Ratio - high leverage")
	func testDebtRatioHighLeverage() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let equipment = try makeEquipmentAccount(entity: entity, periods: periods)

		// High debt load
		let debt = try Account(
			entity: entity,
			name: "Total Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: periods, values: [120_000, 120_000, 120_000, 120_000])
		)

		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [30_000, 30_000, 30_000, 30_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash, equipment],
			liabilityAccounts: [debt],
			equityAccounts: [equity]
		)

		let debtRatio = balanceSheet.debtRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Total Assets = 50k + 100k = 150k
		// Total Liabilities = 120k
		// Debt Ratio = 120k / 150k = 0.80 (high leverage)
		#expect(abs(debtRatio[q1]! - 0.80) < 0.01, "Debt ratio should be ~0.80")
		#expect(debtRatio[q1]! > 0.6, "Should indicate high leverage")
	}

	@Test("Debt Ratio vs Equity Ratio")
	func testDebtRatioVsEquityRatio() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let cash = try makeCashAccount(entity: entity, periods: periods)
		let ap = try makeAPAccount(entity: entity, periods: periods)

		// Create equity that balances: Assets (50k) = Liabilities (20k) + Equity (30k)
		let equity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: periods, values: [30_000, 33_000, 36_000, 39_000])
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: periods,
			assetAccounts: [cash],
			liabilityAccounts: [ap],
			equityAccounts: [equity]
		)

		let debtRatio = balanceSheet.debtRatio
		let equityRatio = balanceSheet.equityRatio
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Debt Ratio + Equity Ratio should equal 1.0
		let sum = debtRatio[q1]! + equityRatio[q1]!
		#expect(abs(sum - 1.0) < 0.001, "Debt ratio + equity ratio should equal 1.0")
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
