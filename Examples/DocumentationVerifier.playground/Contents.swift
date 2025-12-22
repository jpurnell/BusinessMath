import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Set up the reporting period
	let q1 = Period.quarter(year: 2025, quarter: 1)

	// Create the company entity
	let entity = Entity(
		id: "TECH001",
		primaryType: .ticker,
		name: "TechCorp Inc",
		identifiers: [.ticker: "TECH"],
		currency: "USD"
	)

	// Create income statement accounts
	let revenueAccount = try! Account(
		entity: entity,
		name: "Revenue",
		type: .revenue,
		timeSeries: TimeSeries(periods: [q1], values: [10_000_000.0])
	)

	let cogsAccount = try! Account(
		entity: entity,
		name: "Cost of Goods Sold",
		type: .expense,
		timeSeries: TimeSeries(periods: [q1], values: [4_000_000.0]),
		expenseType: .costOfGoodsSold
	)

	let opexAccount = try! Account(
		entity: entity,
		name: "Operating Expenses",
		type: .expense,
		timeSeries: TimeSeries(periods: [q1], values: [3_000_000.0]),
		expenseType: .operatingExpense
	)

	let interestAccount = try! Account(
		entity: entity,
		name: "Interest Expense",
		type: .expense,
		timeSeries: TimeSeries(periods: [q1], values: [500_000.0]),
		expenseType: .interestExpense
	)

	let taxAccount = try! Account(
		entity: entity,
		name: "Tax Expense",
		type: .expense,
		timeSeries: TimeSeries(periods: [q1], values: [625_000.0]),
		expenseType: .taxExpense
	)

	let incomeStatement = try! IncomeStatement<Double>(
		entity: entity,
		periods: [q1],
		revenueAccounts: [revenueAccount],
		expenseAccounts: [cogsAccount, opexAccount, interestAccount, taxAccount]
	)

	// Create balance sheet accounts
	let cashAccount = try! Account<Double>(
		entity: entity,
		name: "Cash",
		type: .asset,
		timeSeries: TimeSeries(periods: [q1], values: [2_000_000.0]),
		assetType: .cashAndEquivalents
	)

	let arAccount = try! Account<Double>(
		entity: entity,
		name: "Accounts Receivable",
		type: .asset,
		timeSeries: TimeSeries(periods: [q1], values: [3_500_000.0]),
		assetType: .accountsReceivable
	)

	let inventoryAccount = try! Account<Double>(
		entity: entity,
		name: "Inventory",
		type: .asset,
		timeSeries: TimeSeries(periods: [q1], values: [2_500_000.0]),
		assetType: .inventory
	)

	let ppeAccount = try! Account<Double>(
		entity: entity,
		name: "Property & Equipment",
		type: .asset,
		timeSeries: TimeSeries(periods: [q1], values: [15_000_000.0]),
		assetType: .propertyPlantEquipment
	)

	let apAccount = try! Account<Double>(
		entity: entity,
		name: "Accounts Payable",
		type: .liability,
		timeSeries: TimeSeries(periods: [q1], values: [1_500_000.0]),
		liabilityType: .accountsPayable
	)

	let shortTermDebtAccount = try! Account<Double>(
		entity: entity,
		name: "Short-term Debt",
		type: .liability,
		timeSeries: TimeSeries(periods: [q1], values: [1_000_000.0]),
		liabilityType: .shortTermDebt
	)

	let longTermDebtAccount = try! Account<Double>(
		entity: entity,
		name: "Long-term Debt",
		type: .liability,
		timeSeries: TimeSeries(periods: [q1], values: [10_000_000.0]),
		liabilityType: .longTermDebt
	)

	let equityAccount = try! Account<Double>(
		entity: entity,
		name: "Shareholders' Equity",
		type: .equity,
		timeSeries: TimeSeries(periods: [q1], values: [10_500_000.0]),
		equityType: .commonStock
	)

	let balanceSheet = try! BalanceSheet<Double>(
		entity: entity,
		periods: [q1],
		assetAccounts: [cashAccount, arAccount, inventoryAccount, ppeAccount],
		liabilityAccounts: [apAccount, shortTermDebtAccount, longTermDebtAccount],
		equityAccounts: [equityAccount]
	)

	// Define loan covenants
	let covenants = [
		FinancialCovenant(
			name: "Minimum Current Ratio",
			requirement: .minimumRatio(metric: .currentRatio, threshold: 1.5)
		),
		FinancialCovenant(
			name: "Maximum Debt-to-Equity",
			requirement: .maximumRatio(metric: .debtToEquity, threshold: 2.0)
		),
		FinancialCovenant(
			name: "Minimum Interest Coverage",
			requirement: .minimumRatio(metric: .interestCoverage, threshold: 3.0)
		)
	]

	// Check covenant compliance
	let monitor = CovenantMonitor(covenants: covenants)
	let results = monitor.checkCompliance(
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		period: q1
	)

	// Display results
	for result in results {
		let status = result.isCompliant ? "✓ PASS" : "✗ FAIL"
		print("\(status) \(result.covenant.name)")
		print("  Actual: \(result.actualValue.number(2))")
		print("  Required: \(result.requiredValue.number(2))")
	}


// Calculate interest coverage ratio
let coverage = calculateInterestCoverage(
	incomeStatement: incomeStatement,
	balanceSheet: balanceSheet,
	period: q1
)

print("Interest Coverage: \(coverage.number(1))x")

if coverage < 2.0 {
	print("Warning: Low interest coverage - difficulty servicing debt")
} else if coverage > 5.0 {
	print("Strong: Company can easily cover interest payments")
} else {
	print("Adequate: Company can cover interest but monitor closely")
}

// Calculate EBIT and interest expense for context
let ebit = incomeStatement.operatingIncome[q1]!
let interestExpense = interestAccount.timeSeries[q1]!
print("\nOperating Income (EBIT): \(ebit.currency(0))")
print("Interest Expense: \(interestExpense.currency(0))")
print("Coverage Ratio: \((ebit / interestExpense).number(1))x")


	// Leasing: $2,000/month for 5 years
	let leasePV = leasePaymentsPV(
		periodicPayment: 2_000,
		periods: 60,
		discountRate: 0.06 / 12
	)

	// Buying: $100,000 purchase, $500 annual maintenance, $20,000 salvage
	let buyPV = buyAssetPV(
		purchasePrice: 100_000,
		salvageValue: 20_000,
		holdingPeriod: 5,
		discountRate: 0.06,
		maintenanceCost: 500
	)

	let analysis = LeaseVsBuyAnalysis(leasePV: leasePV, buyPV: buyPV)

	print("Net Advantage to Leasing: \(analysis.netAdvantageToLeasing.currency())")
	print("Should lease? \(analysis.shouldLease)")
	print("Savings: \(analysis.savingsPercentage.percent())")


let payments = Array(repeating: 5_000.0, count: 60)  // $5,000/month for 5 years

let lease = Lease(
	payments: payments,
	discountRate: 0.05 / 12,  // Monthly discount rate
	residualValue: 0
)

print("Lease Liability: \(lease.presentValue().currency())")
print("Right-of-Use Asset: \(lease.rightOfUseAsset().currency())")

// Generate amortization schedule
let schedule = lease.detailedSchedule()
for (index, entry) in schedule.prefix(12).enumerated() {
	print("Month \(index + 1):")
	print("  Payment: \(entry.payment.currency())")
	print("  Interest: \(entry.interest.currency())")
	print("  Principal: \(entry.principal.currency())")
	print("  Balance: \(entry.balance.currency())")
}

let transaction = SaleAndLeaseback(
	salePrice: 5_000_000,
	bookValue: 4_000_000,
	leaseTerm: 20,
	annualLeasePayment: 400_000,
	discountRate: 0.06
)

print("Gain on Sale: \(transaction.gainOnSale.currency())")
print("PV of Lease Obligations: \(transaction.leaseObligationPV.currency())")
print("Net Cash Benefit: \(transaction.netCashBenefit.currency())")
print("Economically Beneficial? \(transaction.isEconomicallyBeneficial)")


let classification = classifyLease(
	leaseTerm: 8,
	assetUsefulLife: 10,
	presentValue: 90_000,
	assetFairValue: 100_000,
	ownershipTransfer: false,
	purchaseOption: false
)

switch classification {
case .finance:
	print("Finance Lease - capitalize on balance sheet")
case .operating:
	print("Operating Lease - expense as incurred")
}


	// Existing debt: $500M term loan
	let termLoan = DebtInstrument(
		principal: 500_000_000,
		interestRate: 0.055,
		startDate: Date(),
		maturityDate: Calendar.current.date(byAdding: .year, value: 7, to: Date())!,
		paymentFrequency: .quarterly,
		amortizationType: .levelPayment
	)

	let termLoanSchedule = termLoan.schedule()

	// Current capital structure
	let termLoanStructure = CapitalStructure(
		debtValue: 500_000_000,
		equityValue: 1_000_000_000,
		costOfDebt: 0.055,
		costOfEquity: 0.11,
		taxRate: 0.25
	)

	print("=== Debt Analysis ===")
	print("Quarterly Payment: \(termLoanSchedule.payment[termLoanSchedule.periods.first!]!.currency())")
	print("Annual Debt Service: \((termLoanSchedule.payment[termLoanSchedule.periods.first!]! * 4).currency())")
	print("Total Interest (Life of Loan): \(termLoanSchedule.totalInterest.currency())")
	print()
	print("=== Capital Structure ===")
print("WACC: \(termLoanStructure.wacc.percent())")
print("Debt Ratio: \(termLoanStructure.debtRatio.percent())")
	print("Annual Tax Shield: \(termLoanStructure.annualTaxShield.currency())")
print("After-tax Cost of Debt: \(termLoanStructure.afterTaxCostOfDebt.percent())")


	// Founders start with 10M shares
	let founder1 = CapTable.Shareholder(name: "Founder 1", shares: 6_000_000, investmentDate: Date(), pricePerShare: 0.001)
	let founder2 = CapTable.Shareholder(name: "Founder 2", shares: 4_000_000, investmentDate: Date(), pricePerShare: 0.001)

	var initialCapTable = CapTable(shareholders: [founder1, founder2], optionPool: 0)

	print("=== At Founding ===")
	var initialOwnership = initialCapTable.ownership()
print("Founder 1: \(initialOwnership["Founder 1"]!.percent())")
print("Founder 2: \(initialOwnership["Founder 2"]!.percent())")

	// Seed: $2M at $8M pre
	initialCapTable = initialCapTable.modelRound(
		newInvestment: 2_000_000,
		preMoneyValuation: 8_000_000,
		optionPoolIncrease: 0.0,
		investorName: "Seed Investors",
		poolTiming: .postRound
	)

	print("\n=== After Seed ($2M at $8M pre) ===")
	initialOwnership = initialCapTable.ownership()
	for (name, pct) in initialOwnership.sorted(by: { $0.value > $1.value }) {
		print("\(name): \(pct.percent())")
	}

	// Series A: $10M at $40M pre
	initialCapTable = initialCapTable.modelRound(
		newInvestment: 10_000_000,
		preMoneyValuation: 40_000_000,
		optionPoolIncrease: 0.0,
		investorName: "Series A Lead"
	)
	print("\n=== After Series A ($10M at $40M pre) ===")
	initialOwnership = initialCapTable.ownership()
	for (name, pct) in initialOwnership.sorted(by: { $0.value > $1.value }) {
		print("\(name): \(pct.percent())")
	}
