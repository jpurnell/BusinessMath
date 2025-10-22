import Testing
import Foundation
import OSLog
@testable import BusinessMath

/// Test suite for credit metrics and composite scoring systems
@Suite("Credit Metrics Tests")
struct CreditMetricsTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath > \(#file)", category: "\(#function)")

	// MARK: - Test Data Setup

	/// Creates a financially healthy company for testing
	/// Strong profitability, solid balance sheet, low debt
	func createHealthyCompany() throws -> (
		Entity,
		IncomeStatement<Double>,
		BalanceSheet<Double>,
		CashFlowStatement<Double>,
		TimeSeries<Double> // marketPrice
	) {
		let entity = Entity(id: "HEALTHY", primaryType: .ticker, name: "Healthy Corp")
		let quarters = [
			Period.quarter(year: 2024, quarter: 4), // Prior
			Period.quarter(year: 2025, quarter: 1)  // Current
		]

		// Income Statement - profitable with improving margins
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 120_000]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "COGS"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [40_000, 45_000]), // Improving margin: 60% -> 62.5%
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 35_000]),
			metadata: opexMetadata
		)

		var depreciationMetadata = AccountMetadata()
		depreciationMetadata.category = "Non-Cash"
		depreciationMetadata.tags.append("D&A")
		let depreciation = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 5_000]),
			metadata: depreciationMetadata
		)

		var interestMetadata = AccountMetadata()
		interestMetadata.category = "Interest"
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [2_000, 2_000]),
			metadata: interestMetadata
		)

		var taxMetadata = AccountMetadata()
		taxMetadata.category = "Tax"
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 7_000]),
			metadata: taxMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, depreciation, interest, tax]
		)

		// Balance Sheet - strong working capital, low debt
		var cashMetadata = AccountMetadata()
		cashMetadata.category = "Current"
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 60_000]),
			metadata: cashMetadata
		)

		var arMetadata = AccountMetadata()
		arMetadata.category = "Current"
		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [20_000, 24_000]),
			metadata: arMetadata
		)

		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [15_000, 18_000]),
			metadata: inventoryMetadata
		)

		var ppeMetadata = AccountMetadata()
		ppeMetadata.category = "Non-Current"
		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 105_000]),
			metadata: ppeMetadata
		)

		var apMetadata = AccountMetadata()
		apMetadata.category = "Current"
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [10_000, 12_000]),
			metadata: apMetadata
		)

		var debtMetadata = AccountMetadata()
		debtMetadata.category = "Long-Term"
		let debt = try Account(
			entity: entity,
			name: "Long-Term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 25_000]), // Paying down debt
			metadata: debtMetadata
		)

		var retainedEarningsMetadata = AccountMetadata()
		retainedEarningsMetadata.category = "Retained"
		let retainedEarnings = try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [80_000, 98_000]),
			metadata: retainedEarningsMetadata
		)

		var commonStockMetadata = AccountMetadata()
		commonStockMetadata.category = "Common"
		let commonStock = try Account(
			entity: entity,
			name: "Common Stock",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [65_000, 65_000]), // No new issuance
			metadata: commonStockMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [cash, ar, inventory, ppe],
			liabilityAccounts: [ap, debt],
			equityAccounts: [retainedEarnings, commonStock]
		)

		// Cash Flow Statement - strong operating cash flow
		var cfOperationsMetadata = AccountMetadata()
		cfOperationsMetadata.category = "Operating"
		let cfOperations = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: quarters, values: [25_000, 35_000]), // CFO > Net Income (quality earnings)
			metadata: cfOperationsMetadata
		)

		var cfInvestingMetadata = AccountMetadata()
		cfInvestingMetadata.category = "Investing"
		let cfInvesting = try Account(
			entity: entity,
			name: "Cash from Investing",
			type: .investing,
			timeSeries: TimeSeries(periods: quarters, values: [-10_000, -15_000]),
			metadata: cfInvestingMetadata
		)

		var cfFinancingMetadata = AccountMetadata()
		cfFinancingMetadata.category = "Financing"
		let cfFinancing = try Account(
			entity: entity,
			name: "Cash from Financing",
			type: .financing,
			timeSeries: TimeSeries(periods: quarters, values: [-5_000, -10_000]),
			metadata: cfFinancingMetadata
		)

		let cashFlowStatement = try CashFlowStatement(
			entity: entity,
			periods: quarters,
			operatingAccounts: [cfOperations],
			investingAccounts: [cfInvesting],
			financingAccounts: [cfFinancing]
		)

		// Market data for Z-Score
		let marketPrice = TimeSeries(periods: quarters, values: [100.0, 120.0])

		return (entity, incomeStatement, balanceSheet, cashFlowStatement, marketPrice)
	}

	/// Creates a distressed company for testing
	/// Unprofitable, high debt, negative cash flow
	func createDistressedCompany() throws -> (
		Entity,
		IncomeStatement<Double>,
		BalanceSheet<Double>,
		CashFlowStatement<Double>,
		TimeSeries<Double> // marketPrice
	) {
		let entity = Entity(id: "DISTRESS", primaryType: .ticker, name: "Distressed Inc")
		let quarters = [
			Period.quarter(year: 2024, quarter: 4), // Prior
			Period.quarter(year: 2025, quarter: 1)  // Current
		]

		// Income Statement - unprofitable, declining revenue
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [80_000, 70_000]), // Declining
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "COGS"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 48_000]), // Margin worsening: 37.5% -> 31.4%
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [35_000, 35_000]),
			metadata: opexMetadata
		)

		var depreciationMetadata = AccountMetadata()
		depreciationMetadata.category = "Non-Cash"
		depreciationMetadata.tags.append("D&A")
		let depreciation = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [8_000, 8_000]),
			metadata: depreciationMetadata
		)

		var interestMetadata = AccountMetadata()
		interestMetadata.category = "Interest"
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [10_000, 12_000]), // High interest burden
			metadata: interestMetadata
		)

		var taxMetadata = AccountMetadata()
		taxMetadata.category = "Tax"
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [0, 0]), // No taxes (unprofitable)
			metadata: taxMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, depreciation, interest, tax]
		)

		// Balance Sheet - negative working capital, high debt
		var cashMetadata = AccountMetadata()
		cashMetadata.category = "Current"
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 3_000]), // Burning cash
			metadata: cashMetadata
		)

		var arMetadata = AccountMetadata()
		arMetadata.category = "Current"
		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [15_000, 18_000]),
			metadata: arMetadata
		)

		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [25_000, 30_000]), // Excess inventory
			metadata: inventoryMetadata
		)

		var ppeMetadata = AccountMetadata()
		ppeMetadata.category = "Non-Current"
		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [60_000, 55_000]), // Asset impairment
			metadata: ppeMetadata
		)

		var apMetadata = AccountMetadata()
		apMetadata.category = "Current"
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 35_000]), // Can't pay vendors
			metadata: apMetadata
		)

		var shortTermDebtMetadata = AccountMetadata()
		shortTermDebtMetadata.category = "Current"
		let shortTermDebt = try Account(
			entity: entity,
			name: "Short-Term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [20_000, 25_000]),
			metadata: shortTermDebtMetadata
		)

		var debtMetadata = AccountMetadata()
		debtMetadata.category = "Long-Term"
		let debt = try Account(
			entity: entity,
			name: "Long-Term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [80_000, 85_000]), // Taking on more debt
			metadata: debtMetadata
		)

		var retainedEarningsMetadata = AccountMetadata()
		retainedEarningsMetadata.category = "Retained"
		let retainedEarnings = try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [-25_000, -48_000]), // Accumulated losses
			metadata: retainedEarningsMetadata
		)

		var commonStockMetadata = AccountMetadata()
		commonStockMetadata.category = "Common"
		let commonStock = try Account(
			entity: entity,
			name: "Common Stock",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [10_000, 15_000]), // Desperate equity raise
			metadata: commonStockMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [cash, ar, inventory, ppe],
			liabilityAccounts: [ap, shortTermDebt, debt],
			equityAccounts: [retainedEarnings, commonStock]
		)

		// Cash Flow Statement - negative operating cash flow
		var cfOperationsMetadata = AccountMetadata()
		cfOperationsMetadata.category = "Operating"
		let cfOperations = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: quarters, values: [-15_000, -20_000]), // Negative OCF
			metadata: cfOperationsMetadata
		)

		var cfInvestingMetadata = AccountMetadata()
		cfInvestingMetadata.category = "Investing"
		let cfInvesting = try Account(
			entity: entity,
			name: "Cash from Investing",
			type: .investing,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 3_000]), // Selling assets
			metadata: cfInvestingMetadata
		)

		var cfFinancingMetadata = AccountMetadata()
		cfFinancingMetadata.category = "Financing"
		let cfFinancing = try Account(
			entity: entity,
			name: "Cash from Financing",
			type: .financing,
			timeSeries: TimeSeries(periods: quarters, values: [8_000, 15_000]), // Raising debt/equity
			metadata: cfFinancingMetadata
		)

		let cashFlowStatement = try CashFlowStatement(
			entity: entity,
			periods: quarters,
			operatingAccounts: [cfOperations],
			investingAccounts: [cfInvesting],
			financingAccounts: [cfFinancing]
		)

		// Market data - low stock price
		let marketPrice = TimeSeries(periods: quarters, values: [5.0, 3.0])

		return (entity, incomeStatement, balanceSheet, cashFlowStatement, marketPrice)
	}

	// MARK: - Altman Z-Score Tests

	@Test("Altman Z-Score - healthy company in safe zone")
	func testZScoreHealthy() throws {
		let (_, incomeStatement, balanceSheet, _, marketPrice) = try createHealthyCompany()
		let sharesOutstanding = TimeSeries(
			periods: balanceSheet.periods,
			values: [1_000.0, 1_000.0]
		)

		let zScore = altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let z = zScore[q1]!

		// Healthy company should have Z-Score > 2.99 (safe zone)
		#expect(z > 2.99, "Healthy company should be in safe zone (Z > 2.99)")

		// Z-Score should be positive for all periods
		for period in balanceSheet.periods {
			#expect(zScore[period]! > 0, "Z-Score should be positive")
		}
	}

	@Test("Altman Z-Score - distressed company in danger zone")
	func testZScoreDistressed() throws {
		let (_, incomeStatement, balanceSheet, _, marketPrice) = try createDistressedCompany()
		let sharesOutstanding = TimeSeries(
			periods: balanceSheet.periods,
			values: [1_000.0, 1_000.0]
		)

		let zScore = altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let z = zScore[q1]!

		// Distressed company should have Z-Score < 1.81 (distress zone)
		#expect(z < 1.81, "Distressed company should be in danger zone (Z < 1.81)")
	}

	@Test("Altman Z-Score - grey zone detection")
	func testZScoreGreyZone() throws {
		// Create a company with moderate health (grey zone: 1.81 - 2.99)
		let entity = Entity(id: "GREY", primaryType: .ticker, name: "Grey Zone Inc")
		let quarters = [Period.quarter(year: 2025, quarter: 1)]

		// Moderate financials
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "COGS"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [60_000]),
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [25_000]),
			metadata: opexMetadata
		)

		var depreciationMetadata = AccountMetadata()
		depreciationMetadata.category = "Non-Cash"
		depreciationMetadata.tags.append("D&A")
		let depreciation = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [5_000]),
			metadata: depreciationMetadata
		)

		var interestMetadata = AccountMetadata()
		interestMetadata.category = "Interest"
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [3_000]),
			metadata: interestMetadata
		)

		var taxMetadata = AccountMetadata()
		taxMetadata.category = "Tax"
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [2_000]),
			metadata: taxMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, depreciation, interest, tax]
		)

		var cashMetadata = AccountMetadata()
		cashMetadata.category = "Current"
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [20_000]),
			metadata: cashMetadata
		)

		var arMetadata = AccountMetadata()
		arMetadata.category = "Current"
		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [15_000]),
			metadata: arMetadata
		)

		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [20_000]),
			metadata: inventoryMetadata
		)

		var ppeMetadata = AccountMetadata()
		ppeMetadata.category = "Non-Current"
		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [80_000]),
			metadata: ppeMetadata
		)

		var apMetadata = AccountMetadata()
		apMetadata.category = "Current"
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [15_000]),
			metadata: apMetadata
		)

		var debtMetadata = AccountMetadata()
		debtMetadata.category = "Long-Term"
		let debt = try Account(
			entity: entity,
			name: "Long-Term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [60_000]),
			metadata: debtMetadata
		)

		var retainedEarningsMetadata = AccountMetadata()
		retainedEarningsMetadata.category = "Retained"
		let retainedEarnings = try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [30_000]),
			metadata: retainedEarningsMetadata
		)

		var commonStockMetadata = AccountMetadata()
		commonStockMetadata.category = "Common"
		let commonStock = try Account(
			entity: entity,
			name: "Common Stock",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [10_000]),
			metadata: commonStockMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [cash, ar, inventory, ppe],
			liabilityAccounts: [ap, debt],
			equityAccounts: [retainedEarnings, commonStock]
		)

		let marketPrice = TimeSeries(periods: quarters, values: [50.0])
		let sharesOutstanding = TimeSeries(periods: quarters, values: [1_000.0])

		let zScore = altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let q1 = Period.quarter(year: 2025, quarter: 1)
		let z = zScore[q1]!

		// Should be in grey zone (1.81 - 2.99)
		#expect(z >= 1.81 && z <= 2.99, "Company should be in grey zone (1.81 ≤ Z ≤ 2.99)")
	}

	@Test("Altman Z-Score - components calculation verification")
	func testZScoreComponents() throws {
		let (_, incomeStatement, balanceSheet, _, marketPrice) = try createHealthyCompany()
		let sharesOutstanding = TimeSeries(
			periods: balanceSheet.periods,
			values: [1_000.0, 1_000.0]
		)

		let q1 = Period.quarter(year: 2025, quarter: 1)

		// Calculate components manually
		let totalAssets = balanceSheet.totalAssets[q1]!
		let workingCapital = (balanceSheet.currentAssets - balanceSheet.currentLiabilities)[q1]!
		let retainedEarnings = balanceSheet.retainedEarnings[q1]!
		let ebit = incomeStatement.operatingIncome[q1]!
		let totalLiabilities = balanceSheet.totalLiabilities[q1]!
		let sales = incomeStatement.totalRevenue[q1]!
		let marketValue = (marketPrice * sharesOutstanding)[q1]!

		// Z-Score formula: 1.2×A + 1.4×B + 3.3×C + 0.6×D + 1.0×E
		let a = workingCapital / totalAssets
		let b = retainedEarnings / totalAssets
		let c = ebit / totalAssets
		let d = marketValue / totalLiabilities
		let e = sales / totalAssets

		let expectedZ = 1.2 * a + 1.4 * b + 3.3 * c + 0.6 * d + 1.0 * e

		let zScore = altmanZScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let actualZ = zScore[q1]!

		#expect(abs(actualZ - expectedZ) < 0.01, "Z-Score calculation should match formula")
	}

	// MARK: - Piotroski F-Score Tests

	@Test("Piotroski F-Score - strong company scores high")
	func testPiotroskiHealthy() throws {
		let (_, incomeStatement, balanceSheet, cashFlowStatement, _) = try createHealthyCompany()

		let priorPeriod = Period.quarter(year: 2024, quarter: 4)
		let currentPeriod = Period.quarter(year: 2025, quarter: 1)

		let score = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: currentPeriod,
			priorPeriod: priorPeriod
		)

		// Strong company should score 7-9
		#expect(score.totalScore >= 7, "Healthy company should have F-Score ≥ 7")
		#expect(score.totalScore <= 9, "F-Score max is 9")

		// Check individual categories
		#expect(score.profitability >= 3, "Strong profitability signals")
		#expect(score.leverage >= 2, "Improving leverage")
		#expect(score.efficiency >= 1, "Improving efficiency")

		// Check specific signals for healthy company
		#expect(score.signals["positiveNetIncome"] == true, "Should have positive net income")
		#expect(score.signals["positiveOperatingCashFlow"] == true, "Should have positive OCF")
		#expect(score.signals["qualityEarnings"] == true, "OCF should exceed net income")
		#expect(score.signals["decreasingDebt"] == true, "Should be paying down debt")
		#expect(score.signals["noNewEquity"] == true, "No new equity issuance")
	}

	@Test("Piotroski F-Score - weak company scores low")
	func testPiotroskiDistressed() throws {
		let (_, incomeStatement, balanceSheet, cashFlowStatement, _) = try createDistressedCompany()

		let priorPeriod = Period.quarter(year: 2024, quarter: 4)
		let currentPeriod = Period.quarter(year: 2025, quarter: 1)

		let score = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: currentPeriod,
			priorPeriod: priorPeriod
		)

		// Weak company should score 0-3
		#expect(score.totalScore < 4, "Distressed company should have F-Score < 4")
		#expect(score.totalScore >= 0, "F-Score min is 0")

		// Check specific signals for distressed company
		#expect(score.signals["positiveNetIncome"] == false, "Should have negative net income")
		#expect(score.signals["positiveOperatingCashFlow"] == false, "Should have negative OCF")
		#expect(score.signals["decreasingDebt"] == false, "Should be taking on more debt")
		#expect(score.signals["noNewEquity"] == false, "Should have new equity issuance")
	}

	@Test("Piotroski F-Score - individual signal calculations")
	func testPiotroskiSignals() throws {
		let (_, incomeStatement, balanceSheet, cashFlowStatement, _) = try createHealthyCompany()

		let priorPeriod = Period.quarter(year: 2024, quarter: 4)
		let currentPeriod = Period.quarter(year: 2025, quarter: 1)

		let score = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: currentPeriod,
			priorPeriod: priorPeriod
		)

		// Verify all 9 signals are present
		let expectedSignals = [
			"positiveNetIncome",
			"positiveOperatingCashFlow",
			"increasingROA",
			"qualityEarnings",
			"decreasingDebt",
			"increasingCurrentRatio",
			"noNewEquity",
			"increasingGrossMargin",
			"increasingAssetTurnover"
		]

		for signal in expectedSignals {
			#expect(score.signals[signal] != nil, "Signal '\(signal)' should be present")
		}

		// Verify score components sum correctly
		#expect(
			score.totalScore == score.profitability + score.leverage + score.efficiency,
			"Total score should equal sum of components"
		)

		// Verify component bounds
		#expect(score.profitability >= 0 && score.profitability <= 4, "Profitability: 0-4")
		#expect(score.leverage >= 0 && score.leverage <= 3, "Leverage: 0-3")
		#expect(score.efficiency >= 0 && score.efficiency <= 2, "Efficiency: 0-2")
	}

	@Test("Piotroski F-Score - year-over-year improvement detection")
	func testPiotroskiYoYChange() throws {
		// Test that improving fundamentals increase F-Score
		let (_, incomeStatement, balanceSheet, cashFlowStatement, _) = try createHealthyCompany()

		let priorPeriod = Period.quarter(year: 2024, quarter: 4)
		let currentPeriod = Period.quarter(year: 2025, quarter: 1)

		let score = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: currentPeriod,
			priorPeriod: priorPeriod
		)

		// Verify improvement signals are detected
		// Note: Current ratio stays constant (8.5) as both CA and CL grow proportionally
		#expect(score.signals["increasingGrossMargin"] == true, "Gross margin improved: 60% -> 62.5%")
		#expect(score.signals["increasingAssetTurnover"] == true, "Asset turnover improved")

		// Since the healthy company is improving overall, ROA should be increasing
		let netIncomeCurrent = incomeStatement.netIncome[currentPeriod]!
		let netIncomePrior = incomeStatement.netIncome[priorPeriod]!

		if netIncomeCurrent > netIncomePrior {
			#expect(score.signals["increasingROA"] == true, "ROA should be increasing with higher net income")
		}

		// Verify other expected signals for healthy company
		#expect(score.signals["positiveNetIncome"] == true, "Should have positive net income")
		#expect(score.signals["decreasingDebt"] == true, "Should be paying down debt")
	}

	@Test("Piotroski F-Score - boundary case with zero values")
	func testPiotroskiBoundary() throws {
		// Test edge cases (e.g., zero debt, zero equity issuance)
		let entity = Entity(id: "ZERO", primaryType: .ticker, name: "Zero Debt Corp")
		let quarters = [
			Period.quarter(year: 2024, quarter: 4),
			Period.quarter(year: 2025, quarter: 1)
		]

		// Minimal setup with zero debt
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 110_000]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "COGS"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [60_000, 65_000]),
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [20_000, 22_000]),
			metadata: opexMetadata
		)

		var depreciationMetadata = AccountMetadata()
		depreciationMetadata.category = "Non-Cash"
		depreciationMetadata.tags.append("D&A")
		let depreciation = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 5_000]),
			metadata: depreciationMetadata
		)

		var interestMetadata = AccountMetadata()
		interestMetadata.category = "Interest"
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [0, 0]), // Zero debt
			metadata: interestMetadata
		)

		var taxMetadata = AccountMetadata()
		taxMetadata.category = "Tax"
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [4_000, 5_000]),
			metadata: taxMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, depreciation, interest, tax]
		)

		var cashMetadata = AccountMetadata()
		cashMetadata.category = "Current"
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 55_000]),
			metadata: cashMetadata
		)

		var ppeMetadata = AccountMetadata()
		ppeMetadata.category = "Non-Current"
		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 105_000]),
			metadata: ppeMetadata
		)

		var apMetadata = AccountMetadata()
		apMetadata.category = "Current"
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [10_000, 11_000]),
			metadata: apMetadata
		)

		var retainedEarningsMetadata = AccountMetadata()
		retainedEarningsMetadata.category = "Retained"
		let retainedEarnings = try Account(
			entity: entity,
			name: "Retained Earnings",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 111_000]),
			metadata: retainedEarningsMetadata
		)

		var commonStockMetadata = AccountMetadata()
		commonStockMetadata.category = "Common"
		let commonStock = try Account(
			entity: entity,
			name: "Common Stock",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [40_000, 40_000]), // No new equity
			metadata: commonStockMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [cash, ppe],
			liabilityAccounts: [ap],
			equityAccounts: [retainedEarnings, commonStock]
		)

		var cfOperationsMetadata = AccountMetadata()
		cfOperationsMetadata.category = "Operating"
		let cfOperations = try Account(
			entity: entity,
			name: "Cash from Operations",
			type: .operating,
			timeSeries: TimeSeries(periods: quarters, values: [15_000, 18_000]),
			metadata: cfOperationsMetadata
		)

		var cfInvestingMetadata = AccountMetadata()
		cfInvestingMetadata.category = "Investing"
		let cfInvesting = try Account(
			entity: entity,
			name: "Cash from Investing",
			type: .investing,
			timeSeries: TimeSeries(periods: quarters, values: [-5_000, -6_000]),
			metadata: cfInvestingMetadata
		)

		var cfFinancingMetadata = AccountMetadata()
		cfFinancingMetadata.category = "Financing"
		let cfFinancing = try Account(
			entity: entity,
			name: "Cash from Financing",
			type: .financing,
			timeSeries: TimeSeries(periods: quarters, values: [-5_000, -7_000]),
			metadata: cfFinancingMetadata
		)

		let cashFlowStatement = try CashFlowStatement(
			entity: entity,
			periods: quarters,
			operatingAccounts: [cfOperations],
			investingAccounts: [cfInvesting],
			financingAccounts: [cfFinancing]
		)

		let priorPeriod = Period.quarter(year: 2024, quarter: 4)
		let currentPeriod = Period.quarter(year: 2025, quarter: 1)

		let score = piotroskiScore(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			cashFlowStatement: cashFlowStatement,
			period: currentPeriod,
			priorPeriod: priorPeriod
		)

		// Company with zero debt should score well on debt reduction
		// (or handle gracefully - no debt change counts as positive)
		#expect(score.totalScore >= 0 && score.totalScore <= 9, "Score should be in valid range")
		#expect(score.signals["noNewEquity"] == true, "No equity issuance detected")
	}
}
