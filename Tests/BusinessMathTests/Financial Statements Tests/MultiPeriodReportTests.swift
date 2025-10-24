import Testing
import Foundation
@testable import BusinessMath

/// Test suite for multi-period financial reports
@Suite("Multi-Period Report Tests")
struct MultiPeriodReportTests {

	// MARK: - Test Data Setup

	/// Creates test company with 4 quarters of data
	func createQuarterlyData() throws -> (
		Entity,
		[IncomeStatement<Double>],
		[BalanceSheet<Double>],
		[MarketData<Double>]
	) {
		let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc")
		let quarters = Period.year(2025).quarters()

		var incomeStatements: [IncomeStatement<Double>] = []
		var balanceSheets: [BalanceSheet<Double>] = []
		var marketDataList: [MarketData<Double>] = []

		// Create data for each quarter with growth
		for (index, quarter) in quarters.enumerated() {
			let multiplier = 1.0 + Double(index) * 0.1  // 10% growth per quarter

			// Income Statement
			let revenue = try Account(
				entity: entity,
				name: "Revenue",
				type: .revenue,
				timeSeries: TimeSeries(periods: [quarter], values: [100_000 * multiplier])
			)

			let cogs = try Account(
				entity: entity,
				name: "COGS",
				type: .expense,
				timeSeries: TimeSeries(periods: [quarter], values: [40_000 * multiplier]),
				expenseType: .costOfGoodsSold
			)

			let opex = try Account(
				entity: entity,
				name: "Operating Expenses",
				type: .expense,
				timeSeries: TimeSeries(periods: [quarter], values: [30_000 * multiplier]),
				expenseType: .operatingExpense
			)

			let da = try Account(
				entity: entity,
				name: "D&A",
				type: .expense,
				timeSeries: TimeSeries(periods: [quarter], values: [5_000]),
				expenseType: .depreciationAmortization
			)

			let interest = try Account(
				entity: entity,
				name: "Interest",
				type: .expense,
				timeSeries: TimeSeries(periods: [quarter], values: [1_000]),
				expenseType: .interestExpense
			)

			let tax = try Account(
				entity: entity,
				name: "Tax",
				type: .expense,
				timeSeries: TimeSeries(periods: [quarter], values: [6_000 * multiplier]),
				expenseType: .taxExpense
			)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: [quarter],
				revenueAccounts: [revenue],
				expenseAccounts: [cogs, opex, da, interest, tax]
			)
			incomeStatements.append(incomeStatement)

			// Balance Sheet
			let cash = try Account(
				entity: entity,
				name: "Cash",
				type: .asset,
				timeSeries: TimeSeries(periods: [quarter], values: [50_000 + Double(index) * 5_000]),
				assetType: .cashAndEquivalents
			)

			let ar = try Account(
				entity: entity,
				name: "AR",
				type: .asset,
				timeSeries: TimeSeries(periods: [quarter], values: [20_000 * multiplier]),
				assetType: .accountsReceivable
			)

			let ppe = try Account(
				entity: entity,
				name: "PPE",
				type: .asset,
				timeSeries: TimeSeries(periods: [quarter], values: [100_000]),
				assetType: .propertyPlantEquipment
			)

			let ap = try Account(
				entity: entity,
				name: "AP",
				type: .liability,
				timeSeries: TimeSeries(periods: [quarter], values: [15_000]),
				liabilityType: .accountsPayable
			)

			let debt = try Account(
				entity: entity,
				name: "Debt",
				type: .liability,
				timeSeries: TimeSeries(periods: [quarter], values: [50_000 - Double(index) * 2_000]),
				liabilityType: .longTermDebt
			)

			let equity = try Account(
				entity: entity,
				name: "Equity",
				type: .equity,
				timeSeries: TimeSeries(periods: [quarter], values: [100_000 + Double(index) * 10_000]),
				equityType: .retainedEarnings
			)

			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: [quarter],
				assetAccounts: [cash, ar, ppe],
				liabilityAccounts: [ap, debt],
				equityAccounts: [equity]
			)
			balanceSheets.append(balanceSheet)

			// Market Data
			let price = TimeSeries(periods: [quarter], values: [150.0 + Double(index) * 10.0])
			let shares = TimeSeries(periods: [quarter], values: [1_000.0])
			let marketData = MarketData(price: price, sharesOutstanding: shares)
			marketDataList.append(marketData)
		}

		return (entity, incomeStatements, balanceSheets, marketDataList)
	}

	// MARK: - Basic Tests

	@Test("Create multi-period report from quarterly data")
	func testCreateQuarterlyReport() throws {
		let (entity, incomeStatements, balanceSheets, marketDataList) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		var summaries: [FinancialPeriodSummary<Double>] = []
		for i in 0..<4 {
			let summary = try FinancialPeriodSummary(
				entity: entity,
				period: quarters[i],
				incomeStatement: incomeStatements[i],
				balanceSheet: balanceSheets[i],
				marketData: marketDataList[i]
			)
			summaries.append(summary)
		}

		let report = try MultiPeriodReport(
			entity: entity,
			periodSummaries: summaries
		)

		#expect(report.periodCount == 4)
		#expect(report[0].period == quarters[0])
		#expect(report[3].period == quarters[3])
	}

	@Test("Multi-period report automatically sorts periods")
	func testPeriodsAreSorted() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		// Create summaries in random order
		let summaries = try [
			FinancialPeriodSummary(entity: entity, period: quarters[2], incomeStatement: incomeStatements[2], balanceSheet: balanceSheets[2]),
			FinancialPeriodSummary(entity: entity, period: quarters[0], incomeStatement: incomeStatements[0], balanceSheet: balanceSheets[0]),
			FinancialPeriodSummary(entity: entity, period: quarters[3], incomeStatement: incomeStatements[3], balanceSheet: balanceSheets[3]),
			FinancialPeriodSummary(entity: entity, period: quarters[1], incomeStatement: incomeStatements[1], balanceSheet: balanceSheets[1])
		]

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		// Verify sorted order
		#expect(report[0].period == quarters[0])
		#expect(report[1].period == quarters[1])
		#expect(report[2].period == quarters[2])
		#expect(report[3].period == quarters[3])
	}

	@Test("Multi-period report rejects empty periods")
	func testRejectsEmptyPeriods() throws {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "TestCo")

		#expect(throws: MultiPeriodReportError.self) {
			_ = try MultiPeriodReport<Double>(entity: entity, periodSummaries: [])
		}
	}

	@Test("Multi-period report rejects entity mismatch")
	func testRejectsEntityMismatch() throws {
		let entity1 = Entity(id: "AAPL", primaryType: .ticker, name: "Apple")
		let entity2 = Entity(id: "MSFT", primaryType: .ticker, name: "Microsoft")
		let q1 = Period.quarter(year: 2025, quarter: 1)

		let (_, incomeStatements, balanceSheets, _) = try createQuarterlyData()

		let summary1 = try FinancialPeriodSummary(
			entity: entity1,
			period: q1,
			incomeStatement: incomeStatements[0],
			balanceSheet: balanceSheets[0]
		)

		let summary2 = try FinancialPeriodSummary(
			entity: entity2,
			period: q1,
			incomeStatement: incomeStatements[1],
			balanceSheet: balanceSheets[1]
		)

		#expect(throws: MultiPeriodReportError.self) {
			_ = try MultiPeriodReport(entity: entity1, periodSummaries: [summary1, summary2])
		}
	}

	// MARK: - Growth Rate Tests

	@Test("Calculate revenue growth rates")
	func testRevenueGrowth() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)
		let growth = report.revenueGrowth()

		// Should have 3 growth rates (Q2/Q1, Q3/Q2, Q4/Q3)
		#expect(growth.count == 3)

		// Q2 vs Q1: 110k / 100k - 1 = 0.10 (10%)
		#expect(abs(growth[0] - 0.10) < 0.01, "Q2 revenue growth should be ~10%")

		// Q3 vs Q2: 120k / 110k - 1 = 0.091 (9.1%)
		#expect(abs(growth[1] - 0.091) < 0.01, "Q3 revenue growth should be ~9.1%")
	}

	@Test("Calculate EBITDA growth rates")
	func testEBITDAGrowth() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)
		let growth = report.ebitdaGrowth()

		#expect(growth.count == 3)
		// EBITDA growing with revenue (10% per quarter)
		for g in growth {
			#expect(g > 0, "EBITDA should be growing")
		}
	}

	@Test("Calculate net income growth rates")
	func testNetIncomeGrowth() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)
		let growth = report.netIncomeGrowth()

		#expect(growth.count == 3)
		for g in growth {
			#expect(g > 0, "Net income should be growing")
		}
	}

	// MARK: - Trend Analysis Tests

	@Test("Track margin trends across periods")
	func testMarginTrends() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		let grossMargins = report.grossMarginTrend()
		let operatingMargins = report.operatingMarginTrend()
		let netMargins = report.netMarginTrend()

		#expect(grossMargins.count == 4)
		#expect(operatingMargins.count == 4)
		#expect(netMargins.count == 4)

		// All margins should be positive and consistent
		for i in 0..<4 {
			#expect(grossMargins[i] > 0)
			#expect(operatingMargins[i] > 0)
			#expect(netMargins[i] > 0)
		}
	}

	@Test("Track ROE and ROA trends")
	func testProfitabilityTrends() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		let roeTrend = report.roeTrend()
		let roaTrend = report.roaTrend()

		#expect(roeTrend.count == 4)
		#expect(roaTrend.count == 4)

		for i in 0..<4 {
			#expect(roeTrend[i] > 0)
			#expect(roaTrend[i] > 0)
		}
	}

	@Test("Track leverage ratios over time")
	func testLeverageTrends() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		let debtToEquity = report.debtToEquityTrend()
		let debtToEBITDA = report.debtToEBITDATrend()

		#expect(debtToEquity.count == 4)
		#expect(debtToEBITDA.count == 4)

		// Debt decreasing over time, so leverage should decline
		#expect(debtToEquity[3] < debtToEquity[0], "Debt/Equity should decline")
	}

	@Test("Track valuation multiples over time")
	func testValuationTrends() throws {
		let (entity, incomeStatements, balanceSheets, marketDataList) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0],
				marketData: marketDataList[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		let peRatios = report.peRatioTrend()
		let pbRatios = report.pbRatioTrend()
		let psRatios = report.psRatioTrend()

		#expect(peRatios.count == 4)
		#expect(pbRatios.count == 4)
		#expect(psRatios.count == 4)

		// All should have values (not nil)
		for i in 0..<4 {
			#expect(peRatios[i] != nil)
			#expect(pbRatios[i] != nil)
			#expect(psRatios[i] != nil)
		}
	}

	// MARK: - Period Access Tests

	@Test("Access period summary by period")
	func testAccessByPeriod() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		let q2Summary = report[quarters[1]]
		#expect(q2Summary != nil)
		#expect(q2Summary?.period == quarters[1])
	}

	@Test("Access period summary by index")
	func testAccessByIndex() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		#expect(report[0].period == quarters[0])
		#expect(report[1].period == quarters[1])
		#expect(report[2].period == quarters[2])
		#expect(report[3].period == quarters[3])
	}

	// MARK: - Annual Summary Tests

	@Test("Multi-period report with annual summary")
	func testWithAnnualSummary() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		// Create annual financial statements with annual period data
		let annualPeriod = Period.year(2025)

		// Annual revenue account
		let annualRevenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [460_000])  // Sum of quarters
		)

		let annualCOGS = try Account(
			entity: entity,
			name: "COGS",
			type: .expense,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [184_000]),
			expenseType: .costOfGoodsSold
		)

		let annualOpex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [138_000]),
			expenseType: .operatingExpense
		)

		let annualDA = try Account(
			entity: entity,
			name: "D&A",
			type: .expense,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [20_000]),
			expenseType: .depreciationAmortization
		)

		let annualInterest = try Account(
			entity: entity,
			name: "Interest",
			type: .expense,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [4_000]),
			expenseType: .interestExpense
		)

		let annualTax = try Account(
			entity: entity,
			name: "Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [27_600]),
			expenseType: .taxExpense
		)

		let annualIncomeStatement = try IncomeStatement(
			entity: entity,
			periods: [annualPeriod],
			revenueAccounts: [annualRevenue],
			expenseAccounts: [annualCOGS, annualOpex, annualDA, annualInterest, annualTax]
		)

		// Annual balance sheet (using Q4 ending balances)
		let annualCash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [65_000]),
			assetType: .cashAndEquivalents
		)

		let annualAR = try Account(
			entity: entity,
			name: "AR",
			type: .asset,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [26_000]),
			assetType: .accountsReceivable
		)

		let annualEquipment = try Account(
			entity: entity,
			name: "Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [100_000]),
			assetType: .propertyPlantEquipment
		)

		let annualAP = try Account(
			entity: entity,
			name: "AP",
			type: .liability,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [15_000]),
			liabilityType: .accountsPayable
		)

		let annualDebt = try Account(
			entity: entity,
			name: "Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [46_000]),
			liabilityType: .longTermDebt
		)

		let annualEquity = try Account(
			entity: entity,
			name: "Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: [annualPeriod], values: [130_000]),
			equityType: .commonStock
		)

		let annualBalanceSheet = try BalanceSheet(
			entity: entity,
			periods: [annualPeriod],
			assetAccounts: [annualCash, annualAR, annualEquipment],
			liabilityAccounts: [annualAP, annualDebt],
			equityAccounts: [annualEquity]
		)

		let annualSummary = try FinancialPeriodSummary(
			entity: entity,
			period: annualPeriod,
			incomeStatement: annualIncomeStatement,
			balanceSheet: annualBalanceSheet
		)

		let report = try MultiPeriodReport(
			entity: entity,
			periodSummaries: summaries,
			annualSummary: annualSummary
		)

		#expect(report.periodCount == 4)
		#expect(report.annualSummary != nil)
		#expect(report.annualSummary?.period == annualPeriod)
	}

	// MARK: - Codable Tests

	@Test("Multi-period report is Codable")
	func testCodable() throws {
		let (entity, incomeStatements, balanceSheets, _) = try createQuarterlyData()
		let quarters = Period.year(2025).quarters()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let original = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		// Encode
		let encoder = JSONEncoder()
		let data = try encoder.encode(original)

		// Decode
		let decoder = JSONDecoder()
		let decoded = try decoder.decode(MultiPeriodReport<Double>.self, from: data)

		#expect(decoded.entity.id == original.entity.id)
		#expect(decoded.periodCount == original.periodCount)
		#expect(decoded[0].revenue == original[0].revenue)
	}
}
