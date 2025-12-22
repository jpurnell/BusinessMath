import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport


	// Define the company
 let acme = Entity(
	 id: "ACME001",
	 primaryType: .ticker,
	 name: "Acme Corporation",
	 identifiers: [.ticker: "ACME"],
	 currency: "USD",
	 metadata: ["description": "Leading provider of widgets"]
 )
	// Define the periods we're modeling
	let q1 = Period.quarter(year: 2025, quarter: 1)
	let q2 = Period.quarter(year: 2025, quarter: 2)
	let q3 = Period.quarter(year: 2025, quarter: 3)
	let q4 = Period.quarter(year: 2025, quarter: 4)
	let periods = [q1, q2, q3, q4]

	// Revenue
	let revenue = try Account(
		entity: acme,
		name: "Product Revenue",
		type: .revenue,
		timeSeries: TimeSeries(
			periods: periods,
			values: [1_000_000, 1_100_000, 1_200_000, 1_300_000]
		),
	)

	// Cost of Goods Sold
	let cogs = try Account(
		entity: acme,
		name: "Cost of Goods Sold",
		type: .expense,
		timeSeries: TimeSeries(
			periods: periods,
			values: [400_000, 440_000, 480_000, 520_000]
		),
		expenseType: .costOfGoodsSold,
		metadata: AccountMetadata(category: "COGS")
	)

	// Operating Expenses
	let salary = try Account(
		entity: acme,
		name: "Salaries",
		type: .expense,
		timeSeries: TimeSeries(
			periods: periods,
			values: [200_000, 200_000, 200_000, 200_000]
		),
		expenseType: .operatingExpense,
		metadata: AccountMetadata(category: "Operating", subCategory: "Salary")
	)

	let marketing = try Account(
		entity: acme,
		name: "Marketing",
		type: .expense,
		timeSeries: TimeSeries(
			periods: periods,
			values: [50_000, 60_000, 70_000, 80_000]
		),
		expenseType: .operatingExpense,
		metadata: AccountMetadata(category: "Operating", subCategory: "Marketing")
	)

	let interestExpense = try Account(
		entity: acme,
		name: "Interest Expense",
		type: .expense,
		timeSeries: TimeSeries(
			periods: periods,
			values: [10_000, 10_000, 10_000, 10_000]
		),
		expenseType: .interestExpense,
		metadata: AccountMetadata(category: "Financing", subCategory: "Interest")
	)

	let incomeTax = try Account(
		entity: acme,
		name: "Income Tax",
		type: .expense,
		timeSeries: TimeSeries(
			periods: periods,
			values: [60_000, 69_000, 78_000, 87_000]
		),
		expenseType: .taxExpense,
		metadata: AccountMetadata(category: "Tax")
	)

	// Create the Income Statement
	let incomeStatement = try IncomeStatement(
		entity: acme,
		periods: periods,
		revenueAccounts: [revenue],
		expenseAccounts: [cogs, salary, marketing, interestExpense, incomeTax]
	)

	// Access computed values
	print("\nQ1 Revenue:\t\t\t\(incomeStatement.totalRevenue[q1]!.currency())")
	print("Q1 Gross Profit:\t\(incomeStatement.grossProfit[q1]!.currency())")
	print("Q1 Operating Income:\(incomeStatement.operatingIncome[q1]!.currency())")
	print("Q1 Net Income:\t\t\(incomeStatement.netIncome[q1]!.currency())")

	// Calculate margins
print("Q1 Gross Margin:\t\(incomeStatement.grossMargin[q1]!.percent(1))")
print("Q1 Net Margin:\t\t\(incomeStatement.netMargin[q1]!.percent(1))")

	// Assets
	let cash = try Account(
		entity: acme,
		name: "Cash and Equivalents",
		type: .asset,
		timeSeries: TimeSeries(
			periods: periods,
			values: [500_000, 600_000, 750_000, 900_000]
		),
		assetType: .cashAndEquivalents,
		metadata: AccountMetadata(category: "Current Assets", subCategory: "Cash")
	)

	let receivables = try Account(
		entity: acme,
		name: "Accounts Receivable",
		type: .asset,
		timeSeries: TimeSeries(
			periods: periods,
			values: [300_000, 330_000, 360_000, 390_000]
		),
		assetType: .accountsReceivable,
		metadata: AccountMetadata(category: "Current Assets")
	)

	let ppe = try Account(
		entity: acme,
		name: "Property, Plant & Equipment",
		type: .asset,
		timeSeries: TimeSeries(
			periods: periods,
			values: [1_000_000, 980_000, 960_000, 940_000]
		),
		assetType: .propertyPlantEquipment,
		metadata: AccountMetadata(category: "Fixed Assets")
	)

	// Liabilities
	let payables = try Account(
		entity: acme,
		name: "Accounts Payable",
		type: .liability,
		timeSeries: TimeSeries(
			periods: periods,
			values: [150_000, 165_000, 180_000, 195_000]
		),
		liabilityType: .accountsPayable,
		metadata: AccountMetadata(category: "Current Liabilities")
	)

	let longTermDebt = try Account(
		entity: acme,
		name: "Long-term Debt",
		type: .liability,
		timeSeries: TimeSeries(
			periods: periods,
			values: [500_000, 500_000, 500_000, 500_000]
		),
		liabilityType: .longTermDebt,
		metadata: AccountMetadata(category: "Long-term Liabilities")
	)

	// Equity
	let commonStock = try Account(
		entity: acme,
		name: "Common Stock",
		type: .equity,
		timeSeries: TimeSeries(
			periods: periods,
			values: [1_000_000, 1_000_000, 1_000_000, 1_000_000]
		),
		equityType: .commonStock,
		metadata: AccountMetadata(category: "Equity")
	)

	let retainedEarnings = try Account(
		entity: acme,
		name: "Retained Earnings",
		type: .equity,
		timeSeries: TimeSeries(
			periods: periods,
			values: [150_000, 245_000, 390_000, 535_000]
		),
		equityType: .retainedEarnings,
		metadata: AccountMetadata(category: "Equity")
	)

	// Create the Balance Sheet
	let balanceSheet = try BalanceSheet(
		entity: acme,
		periods: periods,
		assetAccounts: [cash, receivables, ppe],
		liabilityAccounts: [payables, longTermDebt],
		equityAccounts: [commonStock, retainedEarnings]
	)

	// Access computed values
print("Q1 Total Assets: \(balanceSheet.totalAssets[q1]!.currency())")
print("Q1 Total Liabilities: \(balanceSheet.totalLiabilities[q1]!.currency())")
print("Q1 Total Equity: \(balanceSheet.totalEquity[q1]!.currency())")

	// Verify balance sheet equation: Assets = Liabilities + Equity
	let assets = balanceSheet.totalAssets[q1]!
	let liabilities = balanceSheet.totalLiabilities[q1]!
	let equity = balanceSheet.totalEquity[q1]!
	print("Balance Check: \(assets == liabilities + equity)")

	// Calculate ratios
print("Q1 Current Ratio: \(balanceSheet.currentRatio[q1]!.number())")
print("Q1 Debt-to-Equity: \(balanceSheet.debtToEquity[q1]!.number())")

	// Operating Activities
	let cashFromOperations = try Account(
		entity: acme,
		name: "Cash from Operations",
		type: .operating,
		timeSeries: TimeSeries(
			periods: periods,
			values: [280_000, 345_000, 420_000, 480_000]
		),
		metadata: AccountMetadata(category: "Operating Activities")
	)

	// Investing Activities
	let capex = try Account(
		entity: acme,
		name: "Capital Expenditures",
		type: .investing,
		timeSeries: TimeSeries(
			periods: periods,
			values: [-50_000, -30_000, -40_000, -60_000]
		),
		metadata: AccountMetadata(category: "Investing Activities")
	)

	// Financing Activities
	let debtProceeds = try Account(
		entity: acme,
		name: "Debt Proceeds",
		type: .financing,
		timeSeries: TimeSeries(
			periods: periods,
			values: [0, 0, 0, 0]
		),
		metadata: AccountMetadata(category: "Financing Activities")
	)

	let dividends = try Account(
		entity: acme,
		name: "Dividends Paid",
		type: .financing,
		timeSeries: TimeSeries(
			periods: periods,
			values: [-30_000, -35_000, -40_000, -45_000]
		),
		metadata: AccountMetadata(category: "Financing Activities")
	)

	// Create the Cash Flow Statement
	let cashFlowStatement = try CashFlowStatement(
		entity: acme,
		periods: periods,
		operatingAccounts: [cashFromOperations],
		investingAccounts: [capex],
		financingAccounts: [debtProceeds, dividends]
		
	)

	// Access computed values
	print("Q1 Operating Cash Flow: \(cashFlowStatement.operatingCashFlow[q1]!.currency())")
print("Q1 Investing Cash Flow: \(cashFlowStatement.investingCashFlow[q1]!.currency(0, signStrategy: .accounting))")
	print("Q1 Financing Cash Flow: \(cashFlowStatement.financingCashFlow[q1]!.currency(0, signStrategy: .accounting))")
	print("Q1 Net Cash Flow: \(cashFlowStatement.netCashFlow[q1]!.currency(0, signStrategy: .accounting))")

	// Free Cash Flow (Operating - CapEx)
	print("Q1 Free Cash Flow: \(cashFlowStatement.freeCashFlow[q1]!.currency(0, signStrategy: .accounting))")


	// 1. Build all three statements (as shown above)

	// 2. Create a Financial Projection that ties them together
	struct CompanyProjection {
		let entity: Entity
		let periods: [Period]
		let incomeStatement: IncomeStatement<Double>
		let balanceSheet: BalanceSheet<Double>
		let cashFlowStatement: CashFlowStatement<Double>

		// Validation: Check that statements are consistent
		func validate() -> Bool {
			for period in periods {
				// Balance sheet must balance
				let assets = balanceSheet.totalAssets[period]!
				let liabilities = balanceSheet.totalLiabilities[period]!
				let equity = balanceSheet.totalEquity[period]!

				if abs(assets - (liabilities + equity)) > 0.01 {
					return false
				}
			}
			return true
		}

		// Summary report
		func printSummary(for period: Period) {
			print("=== \(entity.name) - \(period.label) ===")
			print("\nIncome Statement:")
			print("  Revenue: \(incomeStatement.totalRevenue[period]!.currency(0, signStrategy: .accounting))")
			print("  Net Income: \(incomeStatement.netIncome[period]!.currency(0, signStrategy: .accounting))")
			print("  Net Margin: \(incomeStatement.netMargin[period]!.percent(1))")

			print("\nBalance Sheet:")
			print("  Total Assets: \(balanceSheet.totalAssets[period]!.currency(0, signStrategy: .accounting))")
			print("  Total Equity: \(balanceSheet.totalEquity[period]!.currency(0, signStrategy: .accounting))")
			print("  Debt-to-Equity: \(balanceSheet.debtToEquity[period]!.number(1))x")

			print("\nCash Flow:")
			print("  Operating CF: \(cashFlowStatement.operatingCashFlow[period]!.currency(0, signStrategy: .accounting))")
			print("  Free Cash Flow: \(cashFlowStatement.freeCashFlow[period]!.currency(0, signStrategy: .accounting))")
		}
	}

	let projection = CompanyProjection(
		entity: acme,
		periods: periods,
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		cashFlowStatement: cashFlowStatement
	)

	// Validate and print
	if projection.validate() {
		print("✓ Financial statements are balanced")
		projection.printSummary(for: q1)
	} else {
		print("✗ Financial statements do not balance")
	}

	// Find all current assets
	let currentAssets = balanceSheet.assetAccounts.filter {
		$0.metadata?.category == "Current Assets"
	}

	// Calculate current assets total
	let currentAssetsTotal = currentAssets.reduce(TimeSeries<Double>(periods: periods, values: Array(repeating: 0.0, count: periods.count))) { result, account in
		result + account.timeSeries
	}

	// Find all operating expenses
	let opex = incomeStatement.expenseAccounts.filter {
		$0.type == .expense
	}

	// Group expenses by category
	let expensesByCategory = Dictionary(grouping: incomeStatement.expenseAccounts) {
		$0.metadata?.category ?? "Uncategorized"
	}

let categoryMax = (expensesByCategory.keys.map({$0.description.lengthOfBytes(using: .utf8)}).max() ?? 0)

	for (category, accounts) in expensesByCategory {
		let total = accounts.reduce(0.0) { sum, account in
			sum + (account.timeSeries[q1] ?? 0.0)
		}
		print("\(category.paddingLeft(toLength: categoryMax)): \(total.currency())")
	}
