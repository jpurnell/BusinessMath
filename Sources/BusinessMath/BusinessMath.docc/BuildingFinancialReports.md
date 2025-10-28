# Building Multi-Period Financial Reports

Create comprehensive financial reports with operational metrics, period summaries, and trend analysis.

## Overview

BusinessMath provides a complete financial reporting system that combines financial statements, operational metrics, and multi-period analysis. This tutorial demonstrates how to build a quarterly financial report with trend analysis, similar to what you'd see in a Goldman Sachs research report or company earnings presentation.

The financial reporting system consists of three main components:

- **OperationalMetrics**: Track industry-specific business drivers (production volumes, pricing, customer counts, etc.)
- **FinancialPeriodSummary**: Generate comprehensive "one-pager" financial summaries for a single period
- **MultiPeriodReport**: Aggregate multiple periods for trend analysis and growth rate calculations

This approach is presentation-agnostic - you provide the data structure, and choose how to display it (SwiftUI views, CLI output, or chart visualizations).

## Creating an Entity

Every financial model starts with an entity representing the company or business unit you're analyzing:

```swift
import BusinessMath

let entity = Entity(
    id: "ACME",
    primaryType: .ticker,
    name: "Acme Corporation"
)
```

The entity serves as a consistent identifier across all financial statements and metrics.

## Building Financial Statements

Create financial statements for each period you want to analyze. For a quarterly report, you'll typically create four quarterly income statements and balance sheets.

### Income Statement for Q1

```swift
let periods = (1...4).map({Period.quarter(year: 2025, quarter: $0)})

// Revenue accounts
let revenue = try Account(
	entity: entity,
	name: "Product Revenue",
	type: .revenue,
	timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_100_000, 1_200_000, 1_100_000])
)

	// Expense accounts
	let cogs = try Account(
		entity: entity,
		name: "Cost of Goods Sold",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: [400_000, 450_000, 475_000, 440_000]),
		expenseType: .costOfGoodsSold
	)

	let opex = try Account(
		entity: entity,
		name: "Operating Expenses",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: [300_000, 325_000, 310_000, 330_000]),
		expenseType: .operatingExpense
	)

	let depreciation = try Account(
		entity: entity,
		name: "Depreciation & Amortization",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: [50_000, 55_000, 60_000, 52_000]),
		expenseType: .depreciationAmortization
	)

	let interest = try Account(
		entity: entity,
		name: "Interest Expense",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: [25_000, 25_000, 25_000, 25_000]),
		expenseType: .interestExpense
	)

	let tax = try Account(
		entity: entity,
		name: "Income Tax",
		type: .expense,
		timeSeries: TimeSeries(periods: periods, values: [47_250, 50_000, 50_250, 50_000]),
		expenseType: .taxExpense
	)

	// Create income statement
	let incomeStatement = try IncomeStatement(
		entity: entity,
		periods: periods,
		revenueAccounts: [revenue],
		expenseAccounts: [cogs, opex, depreciation, interest, tax]
	)

	// Asset accounts
	let cash = try Account(
		entity: entity,
		name: "Cash & Equivalents",
		type: .asset,
		timeSeries: TimeSeries(periods: periods, values: [500_000, 520_000, 550_000, 570_000]),
		assetType: .cashAndEquivalents
	)

	let receivables = try Account(
		entity: entity,
		name: "Accounts Receivable",
		type: .asset,
		timeSeries: TimeSeries(periods: periods, values: [300_000, 280_000, 260_000, 270_000]),
		assetType: .accountsReceivable
	)

let ppe = try Account(
	entity: entity,
	name: "Property, Plant & Equipment",
	type: .asset,
	timeSeries: TimeSeries(periods: periods, values: [2_000_000, 2_000_000, 2_000_000, 2_000_000]),
	assetType: .propertyPlantEquipment
)

// Liability accounts
let payables = try Account(
	entity: entity,
	name: "Accounts Payable",
	type: .liability,
	timeSeries: TimeSeries(periods: periods, values: [200_000, 180_000, 160_000, 180_000]),
	liabilityType: .accountsPayable
)

let debt = try Account(
	entity: entity,
	name: "Long-Term Debt",
	type: .liability,
	timeSeries: TimeSeries(periods: periods, values: [1_000_000, 1_000_000, 1_000_000, 1_000_000]),
	liabilityType: .longTermDebt
)

// Equity accounts
let equity = try Account(
	entity: entity,
	name: "Shareholders' Equity",
	type: .equity,
	timeSeries: TimeSeries(periods: periods, values: [1_600_000, 1_700_000, 1_800_000, 1_750_000]),
	equityType: .retainedEarnings
)

// Create balance sheet
let balanceSheet = try BalanceSheet(
	entity: entity,
	periods: periods,
	assetAccounts: [cash, receivables, ppe],
	liabilityAccounts: [payables, debt],
	equityAccounts: [equity]
)
```

## Adding Operational Metrics

Operational metrics track the business drivers behind your financial performance. These are industry-specific and highly flexible:

```swift
let q1Metrics = OperationalMetrics<Double>(
    entity: entity,
    period: q1,
    metrics: [
        // SaaS metrics
        "monthly_recurring_revenue": 300_000,
        "customer_count": 250,
        "average_revenue_per_user": 1_200,
        "customer_acquisition_cost": 5_000,
        "churn_rate": 0.02,
        "net_revenue_retention": 1.15,

        // Unit economics
        "gross_margin_per_customer": 720,
        "lifetime_value": 36_000,
        "ltv_to_cac_ratio": 7.2
    ]
)
```

For different industries, you'd track different metrics:

**E-commerce:**
- `units_sold`, `average_order_value`, `conversion_rate`

**Oil & Gas:**
- `production_boe_per_day`, `realized_price_per_boe`, `lifting_cost_per_boe`

**Manufacturing:**
- `units_produced`, `capacity_utilization`, `cost_per_unit`

## Creating a Financial Period Summary

The `FinancialPeriodSummary` combines your income statement, balance sheet, and operational metrics into a comprehensive one-pager:

```swift
let q1Summary = try FinancialPeriodSummary(
	entity: entity,
	period: periods[0],
	incomeStatement: incomeStatement,
	balanceSheet: balanceSheet,
	operationalMetrics: operationalMetrics[0]
)

// Access key metrics
print("Q1 2025 Financial Summary")
print("Revenue: $\(q1Summary.revenue)")
print("EBITDA: $\(q1Summary.ebitda)")
print("Net Income: $\(q1Summary.netIncome)")
print("Operating Margin: \(q1Summary.operatingMargin * 100)%")
print("ROE: \(q1Summary.roe * 100)%")
print("Debt/EBITDA: \(q1Summary.debtToEBITDARatio)x")
print("Current Ratio: \(q1Summary.currentRatio)x")
```

The period summary automatically calculates:
- **Margins**: Gross, operating, and net margins
- **Profitability**: ROA, ROE
- **Leverage**: Debt/Equity, Debt/EBITDA, Net Debt/EBITDA
- **Liquidity**: Current ratio, quick ratio, cash ratio
- **Credit**: Interest coverage, debt ratios
- **Valuation**: P/E, P/B, P/S, EV/EBITDA (when market data provided)

## Building a Multi-Period Report

Once you have multiple period summaries, create a `MultiPeriodReport` for trend analysis:

```swift
// Create summaries for all four quarters
let summaries = try periods.indices.map { index in
	try FinancialPeriodSummary(
		entity: entity,
		period: periods[index],
		incomeStatement: incomeStatement,
		balanceSheet: balanceSheet,
		operationalMetrics: operationalMetrics[index]
	)
}

// Create multi-period report
let report = try MultiPeriodReport(
    entity: entity,
    periodSummaries: summaries
)

print("Acme Corporation - FY2025 Quarterly Report")
print("Periods: \(report.periodCount)")
```

## Analyzing Growth Rates

Calculate period-over-period growth for key metrics:

```swift
// Revenue growth rates
let revenueGrowth = report.revenueGrowth()
for (index, growth) in revenueGrowth.enumerated() {
    let quarter = index + 2  // Q2, Q3, Q4 (growth from prior quarter)
    print("Q\(quarter) revenue growth: \(growth * 100)%")
}

// EBITDA growth
let ebitdaGrowth = report.ebitdaGrowth()
print("Average EBITDA growth: \(mean(ebitdaGrowth) * 100)%")

// Net income growth
let netIncomeGrowth = report.netIncomeGrowth()
```

Growth rates are calculated as: `(Current - Prior) / Prior`

## Tracking Trends

Analyze how key ratios evolve over time:

```swift
// Margin trends
let grossMargins = report.grossMarginTrend()
let operatingMargins = report.operatingMarginTrend()
let netMargins = report.netMarginTrend()

print("Margin Expansion Analysis:")
print("Q1 Operating Margin: \(operatingMargins[0] * 100)%")
print("Q4 Operating Margin: \(operatingMargins[3] * 100)%")
let expansion = (operatingMargins[3] - operatingMargins[0]) * 100
print("Margin expansion: \(expansion) bps")

// Leverage trends
let debtToEquity = report.debtToEquityTrend()
let debtToEBITDA = report.debtToEBITDATrend()

// Profitability trends
let roeTrend = report.roeTrend()
let roaTrend = report.roaTrend()

// Valuation trends (if market data available)
let peRatios = report.peRatioTrend()
let evToEBITDA = report.evToEBITDATrend()
```

## Analyzing Operational Metrics

Create a time series from operational metrics to track business drivers:

```swift
let metricsTimeSeries = try OperationalMetricsTimeSeries(
    metrics: operationalMetrics  // Array of OperationalMetrics for each period
)

// Extract specific metric
let mrrSeries = metricsTimeSeries.timeSeries(for: "monthly_recurring_revenue")
let customerSeries = metricsTimeSeries.timeSeries(for: "customer_count")

// Calculate growth rates
let mrrGrowth = metricsTimeSeries.growthRate(metric: "monthly_recurring_revenue")
let customerGrowth = metricsTimeSeries.growthRate(metric: "customer_count")

// Analyze unit economics trends
let revenuePerCustomer = quarters.map { quarter in
    let mrr = mrrSeries![quarter]!
    let customers = customerSeries![quarter]!
    return (mrr * 12) / customers  // Annual revenue per customer
}

print("ARPU Trend:")
for (index, arpu) in revenuePerCustomer.enumerated() {
    print("Q\(index + 1): $\(arpu)")
}
```

## Accessing Specific Periods

Retrieve data for specific periods from the report:

```swift
// By index
let q1Data = report[0]
let q4Data = report[3]

// By period
let q2 = Period.quarter(year: 2025, quarter: 2)
if let q2Data = report[q2] {
    print("Q2 Revenue: $\(q2Data.revenue)")
    print("Q2 EBITDA: $\(q2Data.ebitda)")
}

// Annual summary (if provided)
if let annual = report.annualSummary {
    print("FY2025 Total Revenue: $\(annual.revenue)")
    print("FY2025 Net Income: $\(annual.netIncome)")
}
```

## Complete Example

Here's a complete workflow for building a quarterly financial report:

```swift
import BusinessMath

// 1. Create entity
let company = Entity(id: "SHOP", primaryType: .ticker, name: "ShopCo")

// 2. Define periods
let quarters = Period.year(2025).quarters()

// 3. Create financial statements for each quarter
var incomeStatements: [IncomeStatement<Double>] = []
var balanceSheets: [BalanceSheet<Double>] = []
var operationalMetrics: [OperationalMetrics<Double>] = []

for (index, quarter) in quarters.enumerated() {
    // Create income statement (simplified)
    let revenue = try Account(
        entity: company,
        name: "Revenue",
        type: .revenue,
        timeSeries: TimeSeries(periods: [quarter], values: [1000 * Double(index + 1)])
    )
    // ... add all accounts

    let is = try IncomeStatement(
        entity: company,
        periods: [quarter],
        revenueAccounts: [revenue],
        expenseAccounts: [/* expenses */]
    )
    incomeStatements.append(is)

    // Create balance sheet
    // ... similar pattern

    // Create operational metrics
    let metrics = OperationalMetrics<Double>(
        entity: company,
        period: quarter,
        metrics: [
            "units_sold": 10_000 * Double(index + 1),
            "customers": 500 * Double(index + 1)
        ]
    )
    operationalMetrics.append(metrics)
}

// 4. Create period summaries
let summaries = try quarters.indices.map {
    try FinancialPeriodSummary(
        entity: company,
        period: quarters[$0],
        incomeStatement: incomeStatements[$0],
        balanceSheet: balanceSheets[$0],
        operationalMetrics: operationalMetrics[$0]
    )
}

// 5. Create multi-period report
let report = try MultiPeriodReport(entity: company, periodSummaries: summaries)

// 6. Analyze results
print("Revenue Growth: \(report.revenueGrowth())")
print("Margin Trend: \(report.operatingMarginTrend())")
print("Leverage Trend: \(report.debtToEBITDATrend())")

// 7. Export as JSON (Codable support)
let encoder = JSONEncoder()
let jsonData = try encoder.encode(report)
```

## Key Design Principles

The financial reporting system follows these principles:

1. **Presentation-Agnostic**: Provides data structures only, not UI/formatting
2. **Type-Safe**: Leverages Swift generics for numeric types
3. **Industry-Agnostic**: Flexible operational metrics adapt to any business model
4. **Comprehensive**: Automatically calculates 40+ financial ratios
5. **Codable**: Full JSON serialization support
6. **Validated**: Entity matching ensures data consistency

## Best Practices

**Use Consistent Periods**: Ensure all statements for a given period use the same `Period` object:

```swift
let q1 = Period.quarter(year: 2025, quarter: 1)
// Use q1 for all Q1 accounts
```

**Validate Entity Consistency**: The system automatically validates that all summaries belong to the same entity:

```swift
// This will throw MultiPeriodReportError.entityMismatch
let report = try MultiPeriodReport(
    entity: entity1,
    periodSummaries: [summary1ForEntity1, summary2ForEntity2]  // Error!
)
```

**Handle Optional Metrics**: Some ratios require specific data:

```swift
// Valuation metrics require market data
if let peRatio = summary.peRatio {
    print("P/E Ratio: \(peRatio)")
} else {
    print("P/E Ratio: N/A (no market data)")
}

// Efficiency ratios require specific accounts
if let inventoryTurnover = summary.inventoryTurnoverRatio {
    print("Inventory Turnover: \(inventoryTurnover)x")
}
```

**Calculate Derived Metrics**: Use operational metrics to calculate unit economics:

```swift
let revenuePerCustomer = metrics.derived(
    numerator: "total_revenue",
    denominator: "customer_count"
)
```

## Next Steps

- Explore <doc:FinancialStatementsGuide> for detailed financial statement modeling
- Learn about <doc:FinancialRatiosGuide> for comprehensive ratio analysis
- Follow <doc:VisualizationGuide> to create charts and visualizations from your reports
- Review <doc:ScenarioAnalysisGuide> for sensitivity analysis and forecasting

## See Also

- ``OperationalMetrics``
- ``FinancialPeriodSummary``
- ``MultiPeriodReport``
- ``IncomeStatement``
- ``BalanceSheet``
- ``Entity``
- ``Period``
- ``TimeSeries``
