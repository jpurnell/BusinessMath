//
//  CashFlowStatementTests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 10/15/25.
//

import Foundation
import Testing
@testable import BusinessMath

@Suite("Cash Flow Statement Tests")
struct CashFlowStatementTests {

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

	func makeOperatingCFAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [40_000, 45_000, 50_000, 55_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		return try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: timeSeries
		)
	}

	func makeInvestingCFAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [-20_000, -15_000, -10_000, -5_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		return try Account(
			entity: entity,
			name: "Capital Expenditures",
			type: .investing,
			timeSeries: timeSeries
		)
	}

	func makeFinancingCFAccount(entity: Entity, periods: [Period]) throws -> Account<Double> {
		let values: [Double] = [10_000, -5_000, -3_000, -2_000]
		let timeSeries = TimeSeries(periods: periods, values: values)
		return try Account(
			entity: entity,
			name: "Debt Proceeds",
			type: .financing,
			timeSeries: timeSeries
		)
	}

	// MARK: - Basic Creation

	@Test("Cash flow statement can be created with operating, investing, and financing accounts")
	func cashFlowStatementCreation() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		#expect(cashFlowStmt.entity == entity)
		#expect(cashFlowStmt.periods.count == 4)
		#expect(cashFlowStmt.operatingAccounts.count == 1)
		#expect(cashFlowStmt.investingAccounts.count == 1)
		#expect(cashFlowStmt.financingAccounts.count == 1)
	}

	@Test("Cash flow statement can be created with multiple accounts")
	func cashFlowStatementMultipleAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating1 = try makeOperatingCFAccount(entity: entity, periods: periods)

		let values2: [Double] = [5_000, 6_000, 7_000, 8_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let operating2 = try Account(
			entity: entity,
			name: "Working Capital Changes",
			type: .operating,
			timeSeries: timeSeries2
		)

		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating1, operating2],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		#expect(cashFlowStmt.operatingAccounts.count == 2)
	}

	// MARK: - Validation Tests

	@Test("Cash flow statement creation fails with entity mismatch")
	func cashFlowStatementEntityMismatch() throws {
		let entity1 = makeEntity()
		let entity2 = Entity(id: "OTHER", primaryType: .internal, name: "Other Company")
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity1, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity2, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity1, periods: periods)

		#expect(throws: CashFlowStatementError.self) {
			_ = try CashFlowStatement(
				entity: entity1,
				periods: periods,
				operatingAccounts: [operating],
				investingAccounts: [investing],
				financingAccounts: [financing]
			)
		}
	}

	@Test("Cash flow statement creation fails with wrong account type in operating")
	func cashFlowStatementWrongOperatingType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		#expect(throws: CashFlowStatementError.self) {
			_ = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [investing], // Wrong type!
				investingAccounts: [],
				financingAccounts: [financing]
			)
		}
	}

	@Test("Cash flow statement creation fails with wrong account type in investing")
	func cashFlowStatementWrongInvestingType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		#expect(throws: CashFlowStatementError.self) {
			_ = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [operating],
				investingAccounts: [financing], // Wrong type!
				financingAccounts: [financing]
			)
		}
	}

	@Test("Cash flow statement creation fails with wrong account type in financing")
	func cashFlowStatementWrongFinancingType() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)

		#expect(throws: CashFlowStatementError.self) {
			_ = try CashFlowStatement(
				entity: entity,
				periods: periods,
				operatingAccounts: [operating],
				investingAccounts: [investing],
				financingAccounts: [operating] // Wrong type!
			)
		}
	}

	// MARK: - Aggregated Cash Flows

	@Test("Operating cash flow is sum of all operating accounts")
	func operatingCashFlow() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating1 = try makeOperatingCFAccount(entity: entity, periods: periods)

		let values2: [Double] = [5_000, 6_000, 7_000, 8_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let operating2 = try Account(
			entity: entity,
			name: "Working Capital Changes",
			type: .operating,
			timeSeries: timeSeries2
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating1, operating2],
			investingAccounts: [],
			financingAccounts: []
		)

		let total = cashFlowStmt.operatingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 45_000) // 40k + 5k
	}

	@Test("Investing cash flow is sum of all investing accounts")
	func investingCashFlow() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let investing1 = try makeInvestingCFAccount(entity: entity, periods: periods)

		let values2: [Double] = [10_000, 5_000, 3_000, 2_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let investing2 = try Account(
			entity: entity,
			name: "Asset Sales",
			type: .investing,
			timeSeries: timeSeries2
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [],
			investingAccounts: [investing1, investing2],
			financingAccounts: []
		)

		let total = cashFlowStmt.investingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == -10_000) // -20k + 10k
	}

	@Test("Financing cash flow is sum of all financing accounts")
	func financingCashFlow() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let financing1 = try makeFinancingCFAccount(entity: entity, periods: periods)

		let values2: [Double] = [-2_000, -3_000, -4_000, -5_000]
		let timeSeries2 = TimeSeries(periods: periods, values: values2)
		let financing2 = try Account(
			entity: entity,
			name: "Dividend Payments",
			type: .financing,
			timeSeries: timeSeries2
		)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [],
			investingAccounts: [],
			financingAccounts: [financing1, financing2]
		)

		let total = cashFlowStmt.financingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(total[q1] == 8_000) // 10k + (-2k)
	}

	// MARK: - Net Cash Flow

	@Test("Net cash flow is sum of operating, investing, and financing")
	func netCashFlow() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		let net = cashFlowStmt.netCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Operating: 40k, Investing: -20k, Financing: 10k, Net: 30k
		#expect(net[q1] == 30_000)
	}

	// MARK: - Free Cash Flow

	@Test("Free cash flow is operating cash flow plus investing cash flow")
	func freeCashFlow() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		let fcf = cashFlowStmt.freeCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Operating: 40k, Investing: -20k, FCF: 20k
		#expect(fcf[q1] == 20_000)
	}

	// MARK: - Empty Account Handling

	@Test("Cash flow statement handles empty operating accounts")
	func emptyOperatingAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		let operating = cashFlowStmt.operatingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(operating[q1] == 0)
	}

	@Test("Cash flow statement handles empty investing accounts")
	func emptyInvestingAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [],
			financingAccounts: [financing]
		)

		let investing = cashFlowStmt.investingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(investing[q1] == 0)
	}

	@Test("Cash flow statement handles empty financing accounts")
	func emptyFinancingAccounts() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: []
		)

		let financing = cashFlowStmt.financingCashFlow
		let q1 = Period.quarter(year: 2024, quarter: 1)

		#expect(financing[q1] == 0)
	}

	// MARK: - Materialization

	@Test("Materialized cash flow statement has all metrics pre-computed")
	func materialization() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		let materialized = cashFlowStmt.materialize()

		#expect(materialized.entity == entity)
		#expect(materialized.periods.count == 4)

		let q1 = Period.quarter(year: 2024, quarter: 1)

		// Check all pre-computed metrics
		#expect(materialized.operatingCashFlow[q1] == 40_000)
		#expect(materialized.investingCashFlow[q1] == -20_000)
		#expect(materialized.financingCashFlow[q1] == 10_000)
		#expect(materialized.netCashFlow[q1] == 30_000)
		#expect(materialized.freeCashFlow[q1] == 20_000)
	}

	// MARK: - Codable

	@Test("Cash flow statement is Codable")
	func cashFlowStatementCodable() throws {
		let entity = makeEntity()
		let periods = makePeriods()

		let operating = try makeOperatingCFAccount(entity: entity, periods: periods)
		let investing = try makeInvestingCFAccount(entity: entity, periods: periods)
		let financing = try makeFinancingCFAccount(entity: entity, periods: periods)

		let cashFlowStmt = try CashFlowStatement(
			entity: entity,
			periods: periods,
			operatingAccounts: [operating],
			investingAccounts: [investing],
			financingAccounts: [financing]
		)

		let encoded = try JSONEncoder().encode(cashFlowStmt)
		let decoded = try JSONDecoder().decode(CashFlowStatement<Double>.self, from: encoded)

		#expect(decoded.entity == cashFlowStmt.entity)
		#expect(decoded.periods.count == cashFlowStmt.periods.count)
		#expect(decoded.operatingAccounts.count == cashFlowStmt.operatingAccounts.count)
		#expect(decoded.investingAccounts.count == cashFlowStmt.investingAccounts.count)
		#expect(decoded.financingAccounts.count == cashFlowStmt.financingAccounts.count)
	}
}
