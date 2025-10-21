import Testing
import Foundation
@testable import BusinessMath

/// Test suite for DuPont Analysis (3-way and 5-way ROE decomposition)
@Suite("DuPont Analysis Tests")
struct DuPontAnalysisTests {

	// MARK: - Test Data Setup

	/// Creates test company for DuPont analysis
	/// Returns: (entity, incomeStatement, balanceSheet)
	func createTestCompany() throws -> (Entity, IncomeStatement<Double>, BalanceSheet<Double>) {
		let entity = Entity(id: "TEST", primaryType: .ticker, name: "Test Company")
		let quarters = Period.year(2025).quarters()

		// Income Statement - moderate profitability
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [1_000, 1_100, 1_200, 1_300]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "Operating"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [600, 660, 720, 780]),
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [200, 220, 240, 260]),
			metadata: opexMetadata
		)

		var daMetadata = AccountMetadata()
		daMetadata.category = "Non-Cash"
		let da = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [50, 50, 50, 50]),
			metadata: daMetadata
		)

		var interestMetadata = AccountMetadata()
		interestMetadata.category = "Interest"
		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [20, 20, 20, 20]),
			metadata: interestMetadata
		)

		var taxMetadata = AccountMetadata()
		taxMetadata.category = "Tax"
		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [32.5, 37.5, 42.5, 47.5]),
			metadata: taxMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex, da, interest, tax]
		)

		// Balance Sheet
		var cashMetadata = AccountMetadata()
		cashMetadata.category = "Current"
		let cash = try Account(
			entity: entity,
			name: "Cash",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [100, 110, 120, 130]),
			metadata: cashMetadata
		)

		var arMetadata = AccountMetadata()
		arMetadata.category = "Current"
		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [150, 165, 180, 195]),
			metadata: arMetadata
		)

		var ppeMetadata = AccountMetadata()
		ppeMetadata.category = "Non-Current"
		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [800, 850, 900, 950]),
			metadata: ppeMetadata
		)

		var apMetadata = AccountMetadata()
		apMetadata.category = "Current"
		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [100, 110, 120, 130]),
			metadata: apMetadata
		)

		var debtMetadata = AccountMetadata()
		debtMetadata.category = "Long-Term"
		let debt = try Account(
			entity: entity,
			name: "Long-Term Debt",
			type: .liability,
			timeSeries: TimeSeries(periods: quarters, values: [300, 300, 300, 300]),
			metadata: debtMetadata
		)

		var equityMetadata = AccountMetadata()
		equityMetadata.category = "Common"
		let equity = try Account(
			entity: entity,
			name: "Shareholders Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [650, 715, 780, 845]),
			metadata: equityMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [cash, ar, ppe],
			liabilityAccounts: [ap, debt],
			equityAccounts: [equity]
		)

		return (entity, incomeStatement, balanceSheet)
	}

	// MARK: - DuPont 3-Way Tests

	@Test("DuPont 3-way decomposition - basic calculation")
	func testDuPont3Way() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let dupont = dupontAnalysis(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Q1 calculation:
		// Net Income = 1000 - 600 - 200 - 50 - 20 - 32.5 = 97.5
		// Revenue = 1000
		// Net Margin = 97.5 / 1000 = 0.0975 (9.75%)

		// Assets = 100 + 150 + 800 = 1050
		// Average Assets = 1050 (first period)
		// Asset Turnover = 1000 / 1050 = 0.952

		// Equity = 650
		// Average Equity = 650 (first period)
		// Equity Multiplier = 1050 / 650 = 1.615

		// ROE = 0.0975 × 0.952 × 1.615 = 0.15 (15%)
		// Or directly: ROE = 97.5 / 650 = 0.15

		let q1Margin = dupont.netMargin[quarters[0]]!
		let q1Turnover = dupont.assetTurnover[quarters[0]]!
		let q1Multiplier = dupont.equityMultiplier[quarters[0]]!
		let q1ROE = dupont.roe[quarters[0]]!

		#expect(abs(q1Margin - 0.0975) < 0.001, "Q1 net margin should be ~9.75%")
		#expect(abs(q1Turnover - 0.952) < 0.01, "Q1 asset turnover should be ~0.952")
		#expect(abs(q1Multiplier - 1.615) < 0.01, "Q1 equity multiplier should be ~1.615")
		#expect(abs(q1ROE - 0.15) < 0.001, "Q1 ROE should be ~15%")

		// Verify that ROE equals the product of components
		let calculatedROE = q1Margin * q1Turnover * q1Multiplier
		#expect(abs(calculatedROE - q1ROE) < 0.001, "ROE should equal product of components")
	}

	@Test("DuPont components identify ROE improvement strategies")
	func testDuPontImprovementStrategies() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let dupont = dupontAnalysis(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Strategy 1: Improve profitability (increase margins)
		// Strategy 2: Improve efficiency (increase turnover)
		// Strategy 3: Increase leverage (increase multiplier)

		// As the company grows revenue Q1→Q4, check which component drives ROE changes
		let q1ROE = dupont.roe[quarters[0]]!
		let q4ROE = dupont.roe[quarters[3]]!

		#expect(q4ROE >= q1ROE, "ROE should improve or stay stable as business grows")

		// Net margin should be relatively stable (similar % margins)
		let q1Margin = dupont.netMargin[quarters[0]]!
		let q4Margin = dupont.netMargin[quarters[3]]!
		#expect(abs(q4Margin - q1Margin) < 0.02, "Margins should be relatively stable (within 2%)")
	}

	@Test("High-margin, low-turnover business (luxury goods)")
	func testHighMarginLowTurnover() throws {
		let entity = Entity(id: "LUXURY", primaryType: .ticker, name: "Luxury Goods Co")
		let quarters = Period.year(2025).quarters()

		// High margin business: 40% gross margin, 20% net margin
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [500, 500, 500, 500]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "Operating"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [300, 300, 300, 300]),
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [100, 100, 100, 100]),
			metadata: opexMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		// Large asset base (luxury inventory, stores)
		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [2000, 2000, 2000, 2000]),
			metadata: inventoryMetadata
		)

		var equityMetadata = AccountMetadata()
		equityMetadata.category = "Common"
		let equity = try Account(
			entity: entity,
			name: "Shareholders Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [2000, 2000, 2000, 2000]),
			metadata: equityMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [inventory],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		let dupont = dupontAnalysis(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = quarters[0]

		// High margin business characteristics
		let netMargin = dupont.netMargin[q1]!
		let assetTurnover = dupont.assetTurnover[q1]!

		#expect(netMargin > 0.15, "Luxury goods should have high margins (>15%)")
		#expect(assetTurnover < 0.5, "Luxury goods should have low turnover (<0.5)")
	}

	@Test("Low-margin, high-turnover business (retail)")
	func testLowMarginHighTurnover() throws {
		let entity = Entity(id: "RETAIL", primaryType: .ticker, name: "Retail Co")
		let quarters = Period.year(2025).quarters()

		// Low margin business: 2% net margin
		var revenueMetadata = AccountMetadata()
		revenueMetadata.category = "Operating"
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			type: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [5000, 5000, 5000, 5000]),
			metadata: revenueMetadata
		)

		var cogsMetadata = AccountMetadata()
		cogsMetadata.category = "Operating"
		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [4500, 4500, 4500, 4500]),
			metadata: cogsMetadata
		)

		var opexMetadata = AccountMetadata()
		opexMetadata.category = "Operating"
		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			type: .expense,
			timeSeries: TimeSeries(periods: quarters, values: [400, 400, 400, 400]),
			metadata: opexMetadata
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			revenueAccounts: [revenue],
			expenseAccounts: [cogs, opex]
		)

		// Small asset base (fast inventory turnover)
		var inventoryMetadata = AccountMetadata()
		inventoryMetadata.category = "Current"
		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			type: .asset,
			timeSeries: TimeSeries(periods: quarters, values: [300, 300, 300, 300]),
			metadata: inventoryMetadata
		)

		var equityMetadata = AccountMetadata()
		equityMetadata.category = "Common"
		let equity = try Account(
			entity: entity,
			name: "Shareholders Equity",
			type: .equity,
			timeSeries: TimeSeries(periods: quarters, values: [300, 300, 300, 300]),
			metadata: equityMetadata
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			assetAccounts: [inventory],
			liabilityAccounts: [],
			equityAccounts: [equity]
		)

		let dupont = dupontAnalysis(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let q1 = quarters[0]

		// Low margin, high turnover business characteristics
		let netMargin = dupont.netMargin[q1]!
		let assetTurnover = dupont.assetTurnover[q1]!

		#expect(netMargin < 0.05, "Retail should have low margins (<5%)")
		#expect(assetTurnover > 5.0, "Retail should have high turnover (>5)")
	}

	// MARK: - DuPont 5-Way Tests

	@Test("DuPont 5-way decomposition - extended analysis")
	func testDuPont5Way() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let dupont5 = dupontAnalysis5Way(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Q1 calculation:
		// Revenue = 1000
		// Operating Income (EBIT) = 1000 - 600 - 200 - 50 = 150
		// EBT = EBIT - Interest = 150 - 20 = 130
		// Net Income = EBT - Tax = 130 - 32.5 = 97.5

		// Tax Burden = Net Income / EBT = 97.5 / 130 = 0.75
		// Interest Burden = EBT / EBIT = 130 / 150 = 0.867
		// Operating Margin = EBIT / Revenue = 150 / 1000 = 0.15
		// Asset Turnover = Revenue / Assets = 1000 / 1050 = 0.952
		// Equity Multiplier = Assets / Equity = 1050 / 650 = 1.615

		// ROE = 0.75 × 0.867 × 0.15 × 0.952 × 1.615 = 0.15

		let q1TaxBurden = dupont5.taxBurden[quarters[0]]!
		let q1InterestBurden = dupont5.interestBurden[quarters[0]]!
		let q1OpMargin = dupont5.operatingMargin[quarters[0]]!
		let q1Turnover = dupont5.assetTurnover[quarters[0]]!
		let q1Multiplier = dupont5.equityMultiplier[quarters[0]]!
		let q1ROE = dupont5.roe[quarters[0]]!

		#expect(abs(q1TaxBurden - 0.75) < 0.01, "Q1 tax burden should be ~0.75")
		#expect(abs(q1InterestBurden - 0.867) < 0.01, "Q1 interest burden should be ~0.867")
		#expect(abs(q1OpMargin - 0.15) < 0.01, "Q1 operating margin should be ~15%")
		#expect(abs(q1Turnover - 0.952) < 0.01, "Q1 asset turnover should be ~0.952")
		#expect(abs(q1Multiplier - 1.615) < 0.01, "Q1 equity multiplier should be ~1.615")
		#expect(abs(q1ROE - 0.15) < 0.01, "Q1 ROE should be ~15%")

		// Verify that ROE equals the product of all 5 components
		let calculatedROE = q1TaxBurden * q1InterestBurden * q1OpMargin * q1Turnover * q1Multiplier
		#expect(abs(calculatedROE - q1ROE) < 0.001, "ROE should equal product of 5 components")
	}

	@Test("5-way analysis separates operating performance from financing")
	func testOperatingVsFinancing() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let dupont5 = dupontAnalysis5Way(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// Operating performance: Operating Margin × Asset Turnover
		// Financing impact: Tax Burden × Interest Burden × Equity Multiplier

		for quarter in quarters {
			let taxBurden = dupont5.taxBurden[quarter]!
			let interestBurden = dupont5.interestBurden[quarter]!
			let opMargin = dupont5.operatingMargin[quarter]!
			let turnover = dupont5.assetTurnover[quarter]!
			let multiplier = dupont5.equityMultiplier[quarter]!

			// Operating ROA = Operating Margin × Asset Turnover
			let operatingROA = opMargin * turnover

			// Financing multiplier = Tax Burden × Interest Burden × Equity Multiplier
			let financingMultiplier = taxBurden * interestBurden * multiplier

			// ROE = Operating ROA × Financing Multiplier
			let calculatedROE = operatingROA * financingMultiplier
			let actualROE = dupont5.roe[quarter]!

			#expect(abs(calculatedROE - actualROE) < 0.001,
					"ROE should equal operating performance × financing impact")
		}
	}

	@Test("Interest burden less than 1 indicates interest expense impact")
	func testInterestBurdenImpact() throws {
		let (_, incomeStatement, balanceSheet) = try createTestCompany()

		let dupont5 = dupontAnalysis5Way(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet
		)

		let quarters = Period.year(2025).quarters()

		// With interest expense, interest burden should be < 1
		for quarter in quarters {
			let interestBurden = dupont5.interestBurden[quarter]!
			#expect(interestBurden < 1.0, "Interest burden should be < 1 when company has interest expense")
			#expect(interestBurden > 0.5, "Interest burden should be reasonable (> 0.5 for this test company)")
		}
	}
}
