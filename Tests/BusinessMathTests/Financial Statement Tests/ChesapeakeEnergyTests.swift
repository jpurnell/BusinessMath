import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive test demonstrating complete financial reporting system
/// using Chesapeake Energy as a realistic oil & gas example.
///
/// This test suite showcases:
/// - Multi-period quarterly financial statements (Q1-Q4 2025)
/// - Annual summary
/// - Industry-specific operational metrics (production, pricing, costs)
/// - Complete financial analysis (margins, ratios, valuation, trends)
/// - Growth rate and trend analysis
@Suite("Chesapeake Energy - Complete Financial Reporting")
struct ChesapeakeEnergyTests {

	// MARK: - Test Data

	/// Create comprehensive Chesapeake Energy financial data for 2025
	/// Includes 4 quarters + annual summary with realistic oil & gas metrics
	func createChesapeakeData() throws -> (
		Entity,
		[Period],
		[IncomeStatement<Double>],
		[BalanceSheet<Double>],
		[OperationalMetrics<Double>]
	) {
		let entity = Entity(id: "CHK", primaryType: .ticker, name: "Chesapeake Energy Corporation")
		let quarters = Period.year(2025).quarters()

		// Quarterly operational and financial data
		// Revenue grows with production and pricing improvements
		let quarterlyData: [(
			production: Double,      // BOE/day
			realizedPrice: Double,   // $/BOE
			liftingCost: Double,     // $/BOE
			revenue: Double,         // $MM
			opex: Double,            // $MM
			capex: Double            // $MM
		)] = [
			// Q1 2025
			(production: 488_000, realizedPrice: 62.50, liftingCost: 12.80, revenue: 2_730, opex: 580, capex: 650),
			// Q2 2025
			(production: 495_000, realizedPrice: 64.20, liftingCost: 12.60, revenue: 2_880, opex: 590, capex: 675),
			// Q3 2025
			(production: 502_000, realizedPrice: 65.80, liftingCost: 12.40, revenue: 2_990, opex: 600, capex: 700),
			// Q4 2025
			(production: 510_000, realizedPrice: 67.50, liftingCost: 12.20, revenue: 3_120, opex: 610, capex: 725)
		]

		var incomeStatements: [IncomeStatement<Double>] = []
		var balanceSheets: [BalanceSheet<Double>] = []
		var operationalMetrics: [OperationalMetrics<Double>] = []

		for (index, quarter) in quarters.enumerated() {
			let data = quarterlyData[index]

			// MARK: Income Statement

			let revenue = try Account(
				entity: entity,
				name: "Oil & Gas Revenue",
				incomeStatementRole: .revenue,
				timeSeries: TimeSeries(periods: [quarter], values: [data.revenue])
			)

			// Operating costs
			let loe = try Account(
				entity: entity,
				name: "Lease Operating Expenses",
				incomeStatementRole: .operatingExpenseOther,
				timeSeries: TimeSeries(periods: [quarter], values: [data.opex * 0.45])
			)

			let gathering = try Account(
				entity: entity,
				name: "Gathering & Transportation",
				incomeStatementRole: .operatingExpenseOther,
				timeSeries: TimeSeries(periods: [quarter], values: [data.opex * 0.25])
			)

			let production_taxes = try Account(
				entity: entity,
				name: "Production Taxes",
				incomeStatementRole: .operatingExpenseOther,
				timeSeries: TimeSeries(periods: [quarter], values: [data.revenue * 0.08])
			)

			let ga = try Account(
				entity: entity,
				name: "G&A",
				incomeStatementRole: .operatingExpenseOther,
				timeSeries: TimeSeries(periods: [quarter], values: [data.opex * 0.30])
			)

			let dd_a = try Account(
				entity: entity,
				name: "DD&A",
				incomeStatementRole: .depreciationAmortization,
				timeSeries: TimeSeries(periods: [quarter], values: [data.capex * 0.40])
			)

			let interest = try Account(
				entity: entity,
				name: "Interest Expense",
				incomeStatementRole: .interestExpense,
				timeSeries: TimeSeries(periods: [quarter], values: [125])
			)

			let tax = try Account(
				entity: entity,
				name: "Income Tax",
				incomeStatementRole: .incomeTaxExpense,
				timeSeries: TimeSeries(periods: [quarter], values: [(data.revenue - data.opex - data.capex * 0.40 - 125) * 0.21])
			)

			let incomeStatement = try IncomeStatement(
				entity: entity,
				periods: [quarter],
				accounts: [revenue, loe, gathering, production_taxes, ga, dd_a, interest, tax]
			)
			incomeStatements.append(incomeStatement)

			// MARK: Balance Sheet

			// Assets grow with retained earnings and capex
			let baseAssets = 15_000.0 + Double(index) * 500

			let cash = try Account(
				entity: entity,
				name: "Cash & Equivalents",
				balanceSheetRole: .cashAndEquivalents,
				timeSeries: TimeSeries(periods: [quarter], values: [800 + Double(index) * 50])
			)

			let ar = try Account(
				entity: entity,
				name: "Accounts Receivable",
				balanceSheetRole: .accountsReceivable,
				timeSeries: TimeSeries(periods: [quarter], values: [data.revenue * 0.30])
			)

			let inventory = try Account(
				entity: entity,
				name: "Inventory",
				balanceSheetRole: .inventory,
				timeSeries: TimeSeries(periods: [quarter], values: [150])
			)

			let ppe = try Account(
				entity: entity,
				name: "Property, Plant & Equipment",
				balanceSheetRole: .propertyPlantEquipment,
				timeSeries: TimeSeries(periods: [quarter], values: [baseAssets])
			)

			// Liabilities
			let ap = try Account(
				entity: entity,
				name: "Accounts Payable",
				balanceSheetRole: .accountsPayable,
				timeSeries: TimeSeries(periods: [quarter], values: [data.opex * 0.40])
			)

			let currentDebt = try Account(
				entity: entity,
				name: "Current Portion of Debt",
				balanceSheetRole: .shortTermDebt,
				timeSeries: TimeSeries(periods: [quarter], values: [200])
			)

			let longTermDebt = try Account(
				entity: entity,
				name: "Long-Term Debt",
				balanceSheetRole: .longTermDebt,
				timeSeries: TimeSeries(periods: [quarter], values: [5_500 - Double(index) * 100])  // Debt paydown
			)

			// Equity grows with retained earnings
			let equity = try Account(
				entity: entity,
				name: "Shareholders' Equity",
				balanceSheetRole: .retainedEarnings,
				timeSeries: TimeSeries(periods: [quarter], values: [10_000 + Double(index) * 200])
			)

			let balanceSheet = try BalanceSheet(
				entity: entity,
				periods: [quarter],
				accounts: [cash, ar, inventory, ppe, ap, currentDebt, longTermDebt, equity]
			)
			balanceSheets.append(balanceSheet)

			// MARK: Operational Metrics

			let metrics = OperationalMetrics<Double>(
				entity: entity,
				period: quarter,
				metrics: [
					// Production
					"production_boe_per_day": data.production,
					"oil_production_bbl_per_day": data.production * 0.48,  // 48% oil
					"gas_production_mcf_per_day": data.production * 0.52 * 6,  // 52% gas, 6:1 ratio
					"oil_weighting_percent": 0.48,

					// Pricing
					"realized_price_per_boe": data.realizedPrice,
					"oil_price_per_bbl": data.realizedPrice * 1.35,  // Oil premium
					"gas_price_per_mcf": data.realizedPrice / 6.0,

					// Costs
					"lifting_cost_per_boe": data.liftingCost,
					"gathering_cost_per_boe": 4.20,
					"cash_operating_cost_per_boe": data.liftingCost + 4.20,

					// Capital & Wells
					"capex_mm": data.capex,
					"drilling_completion_capex_mm": data.capex * 0.85,
					"wells_drilled": 12 + Double(index) * 2,
					"wells_completed": 11 + Double(index) * 2,
					"average_lateral_length_feet": 10_500 + Double(index) * 200,

					// Reserves
					"proved_reserves_mmboe": 2_650,
					"reserve_life_years": 2_650 / (data.production * 365 / 1_000),

					// Hedging
					"oil_hedge_percent": 0.55 - Double(index) * 0.05,  // Reducing hedges
					"gas_hedge_percent": 0.45 - Double(index) * 0.05
				]
			)
			operationalMetrics.append(metrics)
		}

		return (entity, quarters, incomeStatements, balanceSheets, operationalMetrics)
	}

	// MARK: - Basic Tests

	@Test("Create Chesapeake quarterly financial statements")
	func testQuarterlyStatements() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

		#expect(entity.id == "CHK")
		#expect(quarters.count == 4)
		#expect(incomeStatements.count == 4)
		#expect(balanceSheets.count == 4)

		// Verify Q1 2025 metrics
		let q1 = quarters[0]
		#expect(incomeStatements[0].totalRevenue[q1] == 2_730)
		#expect(incomeStatements[0].netIncome[q1]! > 0, "Should be profitable")
	}

	@Test("Create Chesapeake operational metrics")
	func testOperationalMetrics() throws {
		let (_, _, _, _, operationalMetrics) = try createChesapeakeData()

		#expect(operationalMetrics.count == 4)

		// Verify Q1 production and pricing
		let q1Metrics = operationalMetrics[0]
		#expect(q1Metrics["production_boe_per_day"] == 488_000)
		#expect(q1Metrics["realized_price_per_boe"] == 62.50)
		#expect(q1Metrics["lifting_cost_per_boe"] == 12.80)

		// Verify production growth over year
		let q1Production = operationalMetrics[0]["production_boe_per_day"]!
		let q4Production = operationalMetrics[3]["production_boe_per_day"]!
		#expect(q4Production > q1Production, "Production should grow")
	}

	// MARK: - Financial Period Summary Tests

	@Test("Create Chesapeake quarterly financial summaries")
	func testQuarterlySummaries() throws {
		let (entity, quarters, incomeStatements, balanceSheets, operationalMetrics) = try createChesapeakeData()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0],
				operationalMetrics: operationalMetrics[$0]
			)
		}

		#expect(summaries.count == 4)

		// Verify Q1 summary
		let q1Summary = summaries[0]
		#expect(q1Summary.revenue == 2_730)
		#expect(q1Summary.ebitda > 0)
		#expect(q1Summary.netIncome > 0)
		#expect(q1Summary.operationalMetrics?["production_boe_per_day"] == 488_000)

		// Verify margins improve over time
		let q1Margin = summaries[0].operatingMargin
		let q4Margin = summaries[3].operatingMargin
		#expect(q4Margin > q1Margin, "Operating margin should improve")
	}

	@Test("Verify Chesapeake credit metrics")
	func testCreditMetrics() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

		let q1Summary = try FinancialPeriodSummary(
			entity: entity,
			period: quarters[0],
			incomeStatement: incomeStatements[0],
			balanceSheet: balanceSheets[0]
		)

		// Credit metrics
		#expect(q1Summary.debt > 0)
		#expect(q1Summary.debtToEBITDARatio > 0)
		#expect(q1Summary.debtToEBITDARatio < 3.0, "Debt/EBITDA should be reasonable for E&P")
		#expect(q1Summary.interestCoverageRatio! > 5.0, "Should have strong interest coverage")
	}

	@Test("Verify Chesapeake liquidity ratios")
	func testLiquidityRatios() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

		let q1Summary = try FinancialPeriodSummary(
			entity: entity,
			period: quarters[0],
			incomeStatement: incomeStatements[0],
			balanceSheet: balanceSheets[0]
		)

		#expect(q1Summary.currentRatio > 1.0, "Should have positive working capital")
		#expect(q1Summary.cash > 0)
		#expect(q1Summary.workingCapital > 0)
	}

	// MARK: - Multi-Period Report Tests

	@Test("Create Chesapeake multi-period report")
	func testMultiPeriodReport() throws {
		let (entity, quarters, incomeStatements, balanceSheets, operationalMetrics) = try createChesapeakeData()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0],
				operationalMetrics: operationalMetrics[$0]
			)
		}

		let report = try MultiPeriodReport(
			entity: entity,
			periodSummaries: summaries
		)

		#expect(report.periodCount == 4)
		#expect(report.entity.id == "CHK")
	}

	@Test("Analyze Chesapeake revenue growth")
	func testRevenueGrowth() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)
		let revenueGrowth = report.revenueGrowth()

		#expect(revenueGrowth.count == 3, "Should have 3 growth rates for 4 quarters")

		// Verify positive growth each quarter
		for growth in revenueGrowth {
			#expect(growth > 0, "Revenue should grow each quarter")
		}

		// Q1 to Q2 growth
		let q2Growth = revenueGrowth[0]
		let expectedQ2Growth = (2_880.0 - 2_730.0) / 2_730.0
		#expect(abs(q2Growth - expectedQ2Growth) < 0.001, "Q2 growth should be ~5.5%")
	}

	@Test("Analyze Chesapeake margin trends")
	func testMarginTrends() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0]
			)
		}

		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)
		let margins = report.operatingMarginTrend()

		#expect(margins.count == 4)

		// Margins should improve as prices increase and costs decrease
		#expect(margins[3] > margins[0], "Operating margin should improve Q1 to Q4")
	}

	@Test("Analyze Chesapeake leverage trends")
	func testLeverageTrends() throws {
		let (entity, quarters, incomeStatements, balanceSheets, _) = try createChesapeakeData()

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

		// Leverage should decrease over time as debt is paid down
		#expect(debtToEquity[3] < debtToEquity[0], "Debt/Equity should decrease")
		#expect(debtToEBITDA[3] < debtToEBITDA[0], "Debt/EBITDA should decrease")
	}

	// MARK: - Operational Metrics Time Series Tests

	@Test("Track Chesapeake production trends")
	func testProductionTrends() throws {
		let (_, quarters, _, _, operationalMetrics) = try createChesapeakeData()

		let timeSeries = try OperationalMetricsTimeSeries(metrics: operationalMetrics)
		let production = timeSeries.timeSeries(for: "production_boe_per_day")

		#expect(production != nil)

		let productionValues = quarters.map { production![$0]! }
		#expect(productionValues.count == 4)

		// Verify production grows each quarter
		for i in 1..<productionValues.count {
			#expect(productionValues[i] > productionValues[i-1], "Production should grow each quarter")
		}
	}

	@Test("Calculate Chesapeake production growth rate")
	func testProductionGrowth() throws {
		let (_, _, _, _, operationalMetrics) = try createChesapeakeData()

		let timeSeries = try OperationalMetricsTimeSeries(metrics: operationalMetrics)
		let growth = timeSeries.growthRate(metric: "production_boe_per_day")

		#expect(growth != nil)
		#expect(growth!.periods.count == 3, "Should have 3 growth rates for 4 quarters")

		// All growth rates should be positive
		for period in growth!.periods {
			let rate = growth![period]!
			#expect(rate > 0, "Production growth should be positive")
		}
	}

	@Test("Analyze Chesapeake unit economics trends")
	func testUnitEconomics() throws {
		let (_, quarters, _, _, operationalMetrics) = try createChesapeakeData()

		let timeSeries = try OperationalMetricsTimeSeries(metrics: operationalMetrics)

		let realizedPrice = timeSeries.timeSeries(for: "realized_price_per_boe")!
		let liftingCost = timeSeries.timeSeries(for: "lifting_cost_per_boe")!

		// Extract values for each quarter
		let prices = quarters.map { realizedPrice[$0]! }
		let costs = quarters.map { liftingCost[$0]! }

		// Prices should increase
		#expect(prices[3] > prices[0], "Realized prices should increase")

		// Costs should decrease
		#expect(costs[3] < costs[0], "Lifting costs should decrease")

		// Margin expansion
		let q1Margin = prices[0] - costs[0]
		let q4Margin = prices[3] - costs[3]
		#expect(q4Margin > q1Margin, "Unit margin should expand")
	}

	// MARK: - Integration Tests

	@Test("Complete Chesapeake financial analysis workflow")
	func testCompleteWorkflow() throws {
		// 1. Create financial data
		let (entity, quarters, incomeStatements, balanceSheets, operationalMetrics) = try createChesapeakeData()

		// 2. Create period summaries
		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0],
				operationalMetrics: operationalMetrics[$0]
			)
		}

		// 3. Create multi-period report
		let report = try MultiPeriodReport(entity: entity, periodSummaries: summaries)

		// 4. Analyze trends
		let revenueGrowth = report.revenueGrowth()
		let marginTrend = report.operatingMarginTrend()
		let leverageTrend = report.debtToEBITDATrend()

		// 5. Verify comprehensive analysis
		#expect(revenueGrowth.allSatisfy { $0 > 0 }, "All quarters should show revenue growth")
		#expect(marginTrend.last! > marginTrend.first!, "Margins should expand")
		#expect(leverageTrend.last! < leverageTrend.first!, "Leverage should decrease")

		// 6. Access specific period data
		let q1 = report[0]
		#expect(q1.revenue == 2_730)
		#expect(q1.operationalMetrics?["production_boe_per_day"] == 488_000)

		// 7. Create operational metrics time series
		let opTimeSeries = try OperationalMetricsTimeSeries(metrics: operationalMetrics)
		let prodGrowth = opTimeSeries.growthRate(metric: "production_boe_per_day")
		#expect(prodGrowth != nil)
	}

	@Test("Chesapeake data is Codable")
	func testCodable() throws {
		let (entity, quarters, incomeStatements, balanceSheets, operationalMetrics) = try createChesapeakeData()

		let summaries = try quarters.indices.map {
			try FinancialPeriodSummary(
				entity: entity,
				period: quarters[$0],
				incomeStatement: incomeStatements[$0],
				balanceSheet: balanceSheets[$0],
				operationalMetrics: operationalMetrics[$0]
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
