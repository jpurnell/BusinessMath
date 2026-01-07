import Testing
import Foundation
import OSLog
@testable import BusinessMath

/// Test suite for valuation metrics (P/E, P/B, P/S, EV multiples)
@Suite("Valuation Metrics Tests")
struct ValuationMetricsTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath > \(#file)", category: "\(#function)")
	// MARK: - Test Data Setup

	/// Creates a test company with market data for valuation metrics testing
	/// Returns: (entity, incomeStatement, balanceSheet, marketPrice, sharesOutstanding)
	func createTestCompanyWithMarketData() throws -> (
		Entity,
		IncomeStatement<Double>,
		BalanceSheet<Double>,
		TimeSeries<Double>,
		TimeSeries<Double>
	) {
		let entity = Entity(id: "AAPL", primaryType: .ticker, name: "Apple Inc")
		let quarters = Period.year(2025).quarters()

		// Income Statement - profitable growth company	
		let revenue = try Account(
			entity: entity,
			name: "Revenue",
			incomeStatementRole: .revenue,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 110_000, 120_000, 130_000])
		)

		let cogs = try Account(
			entity: entity,
			name: "Cost of Goods Sold",
			incomeStatementRole: .costOfGoodsSold,
			timeSeries: TimeSeries(periods: quarters, values: [40_000, 44_000, 48_000, 52_000]),
		)

		let opex = try Account(
			entity: entity,
			name: "Operating Expenses",
			incomeStatementRole: .operatingExpenseOther,
			timeSeries: TimeSeries(periods: quarters, values: [30_000, 32_000, 34_000, 36_000]),
		)

		let depreciation = try Account(
			entity: entity,
			name: "Depreciation & Amortization",
			incomeStatementRole: .depreciationAmortization,
			timeSeries: TimeSeries(periods: quarters, values: [5_000, 5_000, 5_000, 5_000]),
		)

		let interest = try Account(
			entity: entity,
			name: "Interest Expense",
			incomeStatementRole: .interestExpense,
			timeSeries: TimeSeries(periods: quarters, values: [1_000, 1_000, 1_000, 1_000]),
		)

		let tax = try Account(
			entity: entity,
			name: "Income Tax",
			incomeStatementRole: .incomeTaxExpense,
			timeSeries: TimeSeries(periods: quarters, values: [6_000, 7_000, 8_000, 9_000]),
		)

		let incomeStatement = try IncomeStatement(
			entity: entity,
			periods: quarters,
			accounts: [revenue, cogs, opex, depreciation, interest, tax]
		)

		// Balance Sheet	
		let cash = try Account(
			entity: entity,
			name: "Cash",
			balanceSheetRole: .cashAndEquivalents,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 55_000, 60_000, 65_000]),
		)

		let ar = try Account(
			entity: entity,
			name: "Accounts Receivable",
			balanceSheetRole: .accountsReceivable,
			timeSeries: TimeSeries(periods: quarters, values: [20_000, 22_000, 24_000, 26_000]),
		)

		let inventory = try Account(
			entity: entity,
			name: "Inventory",
			balanceSheetRole: .inventory,
			timeSeries: TimeSeries(periods: quarters, values: [15_000, 16_000, 17_000, 18_000]),
		)

		let ppe = try Account(
			entity: entity,
			name: "Property Plant Equipment",
			balanceSheetRole: .propertyPlantEquipment,
			timeSeries: TimeSeries(periods: quarters, values: [100_000, 105_000, 110_000, 115_000]),
		)

		let ap = try Account(
			entity: entity,
			name: "Accounts Payable",
			balanceSheetRole: .accountsPayable,
			timeSeries: TimeSeries(periods: quarters, values: [15_000, 16_000, 17_000, 18_000]),
		)

		let debt = try Account(
			entity: entity,
			name: "Long-Term Debt",
			balanceSheetRole: .longTermDebt,
			timeSeries: TimeSeries(periods: quarters, values: [50_000, 48_000, 46_000, 44_000]),
		)

		let equity = try Account(
			entity: entity,
			name: "Shareholders Equity",
			balanceSheetRole: .retainedEarnings,
			timeSeries: TimeSeries(periods: quarters, values: [120_000, 138_000, 148_000, 166_000]),
		)

		let balanceSheet = try BalanceSheet(
			entity: entity,
			periods: quarters,
			accounts: [cash, ar, inventory, ppe, ap, debt, equity]
		)

		// Market Data
		// Stock price rises over the year (growth stock)
		let marketPrice = TimeSeries(periods: quarters, values: [150.0, 160.0, 170.0, 180.0])
		// Shares remain constant (no buybacks this scenario)
		let sharesOutstanding = TimeSeries(periods: quarters, values: [1_000.0, 1_000.0, 1_000.0, 1_000.0])

		return (entity, incomeStatement, balanceSheet, marketPrice, sharesOutstanding)
	}

	// MARK: - P/E Ratio Tests

	@Test("Price-to-Earnings - growth stock with high P/E")
	func testPriceToEarnings() throws {
		let (_, incomeStatement, _, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let pe = priceToEarnings(
			incomeStatement: incomeStatement,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Net Income = 100K - 40K - 30K - 5K - 1K - 6K = 18K
		// EPS = 18K / 1000 = 18
		// P/E = 150 / 18 = 8.33
		let q1PE = pe[quarters[0]]!
		#expect(abs(q1PE - 8.33) < 0.1, "Q1 P/E should be ~8.33")

		// Q4: Net Income = 130K - 52K - 36K - 5K - 1K - 9K = 27K
		// EPS = 27K / 1000 = 27
		// P/E = 180 / 27 = 6.67
		let q4PE = pe[quarters[3]]!
		#expect(abs(q4PE - 6.67) < 0.1, "Q4 P/E should be ~6.67")

		// P/E should be positive for profitable company
		for quarter in quarters {
			#expect(pe[quarter]! > 0, "P/E should be positive for profitable company")
		}
	}

	// MARK: - P/B Ratio Tests

	@Test("Price-to-Book - value stock comparison")
	func testPriceToBook() throws {
		let (_, _, balanceSheet, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let pb = priceToBook(
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Book Value = 120K / 1000 shares = 120 per share
		// P/B = 150 / 120 = 1.25
		let q1PB = pb[quarters[0]]!
		#expect(abs(q1PB - 1.25) < 0.01, "Q1 P/B should be ~1.25")

		// Q4: Book Value = 166K / 1000 = 166 per share
		// P/B = 180 / 166 = 1.084
		let q4PB = pb[quarters[3]]!
		#expect(abs(q4PB - 1.084) < 0.01, "Q4 P/B should be ~1.084")

		// P/B typically above 1 for growth companies
		for quarter in quarters {
			#expect(pb[quarter]! > 1.0, "P/B should be above 1 for this growth company")
		}
	}

	// MARK: - P/S Ratio Tests

	@Test("Price-to-Sales - revenue multiple")
	func testPriceToSales() throws {
		let (_, incomeStatement, _, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let ps = priceToSales(
			incomeStatement: incomeStatement,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Market Cap = 150 * 1000 = 150K
		// Revenue = 100K
		// P/S = 150K / 100K = 1.5
		let q1PS = ps[quarters[0]]!
		#expect(abs(q1PS - 1.5) < 0.01, "Q1 P/S should be ~1.5")

		// Q4: Market Cap = 180 * 1000 = 180K
		// Revenue = 130K
		// P/S = 180K / 130K = 1.385
		let q4PS = ps[quarters[3]]!
		#expect(abs(q4PS - 1.385) < 0.01, "Q4 P/S should be ~1.385")

		// P/S should be positive
		for quarter in quarters {
			#expect(ps[quarter]! > 0, "P/S should be positive")
		}
	}

	// MARK: - Enterprise Value Tests

	@Test("Enterprise Value - accounts for debt and cash")
	func testEnterpriseValue() throws {
		let (_, _, balanceSheet, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let ev = enterpriseValue(
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: Market Cap = 150 * 1000 = 150K
		// Debt = 50K
		// Cash = 50K
		// EV = 150K + 50K - 50K = 150K
		let q1EV = ev[quarters[0]]!
		#expect(abs(q1EV - 150_000) < 1, "Q1 EV should be ~150K")

		// Q4: Market Cap = 180K, Debt = 44K, Cash = 65K
		// EV = 180K + 44K - 65K = 159K
		let q4EV = ev[quarters[3]]!
		#expect(abs(q4EV - 159_000) < 1, "Q4 EV should be ~159K")
	}

	@Test("Enterprise Value - cash-rich company has lower EV than market cap")
	func testEnterpriseValueCashRich() throws {
		let (_, _, balanceSheet, _, sharesOutstanding) = try createTestCompanyWithMarketData()

		// Create a cash-rich scenario - high cash, low debt
		let quarters = Period.year(2025).quarters()
		let marketPrice = TimeSeries(periods: quarters, values: [200.0, 200.0, 200.0, 200.0])

		let ev = enterpriseValue(
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		// Calculate market cap: price * shares = 200 * 1000 = 200,000
		let marketCap = marketCapitalization(marketPrice: marketPrice, sharesOutstanding: sharesOutstanding)
		let q4MarketCap = marketCap[quarters[3]]!

		// By Q4, cash (65K) exceeds debt (44K), making this a net cash company
		// EV should be less than market cap in Q4
		let q4EV = ev[quarters[3]]!
		#expect(q4EV < q4MarketCap, "EV should be less than market cap when cash > debt")

		// As cash grows and debt shrinks, EV should approach market cap - net cash
		// Q1: Cash=50K, Debt=50K -> EV = 200K (no net cash)
		// Q4: Cash=65K, Debt=44K -> EV = 179K (21K net cash)
		let q1EV = ev[quarters[0]]!
		let q1MarketCap = marketCap[quarters[0]]!
		#expect(q1EV <= q1MarketCap, "EV should be at most equal to market cap when debt = cash")
		#expect(q4EV < q1EV, "EV should decrease as company becomes more cash-rich")
	}

	// MARK: - EV/EBITDA Tests

	@Test("EV/EBITDA - capital-structure-neutral valuation")
	func testEVtoEBITDA() throws {
		let (_, incomeStatement, balanceSheet, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let evEbitda = evToEbitda(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: EV = 150K (calculated above)
		// Operating Income (EBIT) = Revenue - COGS - OpEx - D&A = 100K - 40K - 30K - 5K = 25K
		// EBITDA = Operating Income + D&A = 25K + 5K = 30K
		// EV/EBITDA = 150K / 30K = 5.0
		let q1EVtoEBITDA = evEbitda[quarters[0]]!
		#expect(abs(q1EVtoEBITDA - 5.0) < 0.1, "Q1 EV/EBITDA should be ~5.0")

		// Typical range is 8-15x, but this is a very profitable company with low debt
		for quarter in quarters {
			#expect(evEbitda[quarter]! > 0, "EV/EBITDA should be positive")
		}
	}

	// MARK: - EV/Sales Tests

	@Test("EV/Sales - alternative to P/S")
	func testEVtoSales() throws {
		let (_, incomeStatement, balanceSheet, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let evSales = evToSales(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Q1: EV = 150K, Revenue = 100K
		// EV/Sales = 150K / 100K = 1.5
		let q1EVtoSales = evSales[quarters[0]]!
		#expect(abs(q1EVtoSales - 1.5) < 0.01, "Q1 EV/Sales should be ~1.5")

		// Q4: EV = 159K, Revenue = 130K
		// EV/Sales = 159K / 130K = 1.223
		let q4EVtoSales = evSales[quarters[3]]!
		#expect(abs(q4EVtoSales - 1.223) < 0.01, "Q4 EV/Sales should be ~1.223")
	}

	// MARK: - Comparative Tests

	@Test("Compare P/E vs EV/EBITDA for leveraged company")
	func testPEvsEVEBITDA() throws {
		let (_, incomeStatement, balanceSheet, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let pe = priceToEarnings(
			incomeStatement: incomeStatement,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let evEbitda = evToEbitda(
			incomeStatement: incomeStatement,
			balanceSheet: balanceSheet,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// EV/EBITDA is typically lower than P/E because:
		// - EBITDA > Net Income (doesn't include interest, tax, D&A)
		// - EV accounts for debt which P/E doesn't
		for quarter in quarters {
			let peValue = pe[quarter]!
			let evEbitdaValue = evEbitda[quarter]!

			// For this company, P/E should be higher than EV/EBITDA
			#expect(peValue > evEbitdaValue, "P/E typically higher than EV/EBITDA for leveraged company")
		}
	}

	@Test("Earnings yield is inverse of P/E")
	func testEarningsYield() throws {
		let (_, incomeStatement, _, marketPrice, sharesOutstanding) = try createTestCompanyWithMarketData()

		let pe = priceToEarnings(
			incomeStatement: incomeStatement,
			marketPrice: marketPrice,
			sharesOutstanding: sharesOutstanding
		)

		let quarters = Period.year(2025).quarters()

		// Earnings Yield = E/P = 1 / (P/E)
		// Should be in reasonable range (5-20%)
		for quarter in quarters {
			let earningsYield = 1.0 / pe[quarter]!
			#expect(earningsYield > 0.05, "Earnings yield should be > 5%")
			#expect(earningsYield < 0.30, "Earnings yield should be < 30%")
		}
	}
}
