import Foundation
import BusinessMath
import OSLog
import PlaygroundSupport

	// Define the company and periods
	let company = Entity(
	 id: "TECH001",
	 primaryType: .ticker,
	 name: "TechCo"
	)

	let q1 = Period.quarter(year: 2025, quarter: 1)
	let quarters = [q1, q1 + 1, q1 + 2, q1 + 3]

	// Create base case drivers
	let baseRevenue = DeterministicDriver(name: "Revenue", value: 1_000_000)
	let baseCosts = DeterministicDriver(name: "Costs", value: 600_000)
	let baseOpEx = DeterministicDriver(name: "OpEx", value: 200_000)

	var baseOverrides: [String: AnyDriver<Double>] = [:]
	baseOverrides["Revenue"] = AnyDriver(baseRevenue)
	baseOverrides["Costs"] = AnyDriver(baseCosts)
	baseOverrides["OpEx"] = AnyDriver(baseOpEx)

	// Create base case scenario
	let baseCase = FinancialScenario(
	 name: "Base Case",
	 description: "Expected performance",
	 driverOverrides: baseOverrides
	)

	// Define how to build financial statements from drivers
	let builder: ScenarioRunner.StatementBuilder = { drivers, periods in
	 // Extract driver values
	 let revenue = drivers["Revenue"]!.sample(for: periods[0])
	 let costs = drivers["Costs"]!.sample(for: periods[0])
	 let opex = drivers["OpEx"]!.sample(for: periods[0])

	 // Build Income Statement
	 let revenueAccount = try Account(
		entity: company,
		name: "Revenue",
		type: .revenue,
		timeSeries: TimeSeries(periods: periods, values: Array(repeating: revenue, count: periods.count)),
		 
	 )

	 let cogsAccount = try Account(
		entity: company,
		name: "COGS",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: Array(repeating: costs, count: periods.count)),
		expenseType: .costOfGoodsSold,
		
	 )

	 let opexAccount = try Account(
		entity: company,
		name: "Operating Expenses",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: Array(repeating: opex, count: periods.count)),
		expenseType: .operatingExpense
		
	 )

	 let incomeStatement = try IncomeStatement(
		 entity: company,
		 periods: periods,
		 revenueAccounts: [revenueAccount],
		 expenseAccounts: [cogsAccount, opexAccount]
	 )

	 // Build simple Balance Sheet (required for complete projection)
	 let cashAccount = try Account(
		entity: company,
		name: "Cash",
		type: .asset,
		timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000, 600_000, 650_000]),
		assetType: .cashAndEquivalents
	 )

	 let equityAccount = try Account(
		entity: company,
		name: "Equity",
		type: .equity,
		timeSeries: TimeSeries(periods: periods, values: [500_000, 550_000, 600_000, 650_000])
	 )

	 let balanceSheet = try BalanceSheet(
		 entity: company,
		 periods: periods,
		 assetAccounts: [cashAccount],
		 liabilityAccounts: [],
		 equityAccounts: [equityAccount]
	 )

	 // Build simple Cash Flow Statement
	 let cfAccount = try Account(
		entity: company,
		name: "Operating Cash Flow",
		type: .operating,
		timeSeries: incomeStatement.netIncome,
		metadata: AccountMetadata(category: "Operating Activities")
	 )

	 let cashFlowStatement = try CashFlowStatement(
		entity: company,
		periods: periods,
		operatingAccounts: [cfAccount],
		investingAccounts: [],
		financingAccounts: []
	 )

	 return (incomeStatement, balanceSheet, cashFlowStatement)
	}

	// Run the base case
	let runner = ScenarioRunner()
	let baseProjection = try runner.run(
	 scenario: baseCase,
	 entity: company,
	 periods: quarters,
	 builder: builder
	)

print("Base Case Q1 Net Income: \(baseProjection.incomeStatement.netIncome[q1]!.currency(0))")


	// Create probabilistic drivers with proper distributions
	let uncertainRevenue = ProbabilisticDriver<Double>(
		name: "Revenue",
		distribution: DistributionNormal(1_000_000.0, 100_000.0)
	)

	let uncertainCosts = ProbabilisticDriver<Double>(
		name: "Costs",
		distribution: DistributionNormal(600_000.0, 50_000.0)
	)

	var monteCarloOverrides: [String: AnyDriver<Double>] = [:]
	monteCarloOverrides["Revenue"] = AnyDriver(uncertainRevenue)
	monteCarloOverrides["Costs"] = AnyDriver(uncertainCosts)
	monteCarloOverrides["OpEx"] = AnyDriver(baseOpEx)  // Keep OpEx fixed

	let uncertainScenario = FinancialScenario(
		name: "Monte Carlo",
		description: "Probabilistic scenario",
		driverOverrides: monteCarloOverrides
	)

	// Run simulation (10,000 iterations)
	let simulation = try runFinancialSimulation(
		scenario: uncertainScenario,
		entity: company,
		periods: quarters,
		iterations: 10_000,
		builder: builder
	)

	// Define metric extractor for net income
	let netIncomeMetric: (FinancialProjection) -> Double = { projection in
		return projection.incomeStatement.netIncome[q1]!
	}

	// Analyze results - basic statistics
	print("\n=== Monte Carlo Simulation Results (10,000 iterations) ===")
	let meanIncome = simulation.mean(metric: netIncomeMetric)
	print("Mean Net Income: \(meanIncome.currency(0))")

	// Calculate percentiles
	print("\nPercentiles:")
	let p5 = simulation.percentile(0.05, metric: netIncomeMetric)
	let p25 = simulation.percentile(0.25, metric: netIncomeMetric)
	let p50 = simulation.percentile(0.50, metric: netIncomeMetric)  // Median
	let p75 = simulation.percentile(0.75, metric: netIncomeMetric)
	let p95 = simulation.percentile(0.95, metric: netIncomeMetric)

	print("  5th:  \(p5.currency(0))")
	print("  25th: \(p25.currency(0))")
	print("  50th: \(p50.currency(0)) (median)")
	print("  75th: \(p75.currency(0))")
	print("  95th: \(p95.currency(0))")

	// Risk metrics
	print("\nRisk Metrics:")
	let var95 = simulation.valueAtRisk(0.95, metric: netIncomeMetric)
	let cvar95 = simulation.conditionalValueAtRisk(0.95, metric: netIncomeMetric)
print("Value at Risk (95%): \(var95.currency(0))")
print("CVaR (95%): \(cvar95.currency(0))")

	// Confidence intervals
	let ci90 = simulation.confidenceInterval(0.90, metric: netIncomeMetric)
print("90% Confidence Interval: [\(ci90.lowerBound.currency(0)), \(ci90.upperBound.currency(0))]")

	// Probability analysis
	print("\nProbability Analysis:")
	let probLoss = simulation.probabilityOfLoss(metric: netIncomeMetric)
	let probBelow100k = simulation.probabilityBelow(100_000, metric: netIncomeMetric)
	let probAbove200k = simulation.probabilityAbove(200_000, metric: netIncomeMetric)
print("Probability of loss (NI < $0): \(probLoss.percent(1))")
print("Probability NI < $100k: \(probBelow100k.percent(1))")
print("Probability NI > $200k: \(probAbove200k.percent(1))")
