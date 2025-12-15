# Fluent API Guide

Build financial models with intuitive, declarative syntax inspired by SwiftUI.

## Overview

The BusinessMath Fluent API provides a SwiftUI-style declarative syntax for building financial models, investments, scenarios, and time series. Instead of imperative construction with initializers and setters, you describe *what* you want in a natural, readable way.

This guide shows you how to:
- Build financial models using ``ModelBuilder``
- Define investment analyses with ``InvestmentBuilder``
- Create scenarios using ``ScenarioBuilder``
- Construct time series with ``TimeSeriesBuilder``
- Choose when to use fluent APIs vs. traditional construction
- Test and debug builder-based code

## Why Fluent APIs?

Traditional construction can be verbose and error-prone:

```swift
// Traditional approach - imperative and verbose
var revenueAccount = try Account(
    entity: company,
    name: "Product Revenue",
    type: .revenue,
    timeSeries: TimeSeries(periods: periods, values: revenueValues)
)

var cogsAccount = try Account(
    entity: company,
    name: "Cost of Goods Sold",
    type: .expense,
    timeSeries: TimeSeries(periods: periods, values: cogsValues),
    expenseType: .costOfGoodsSold
)

var model = FinancialModel(entity: company)
model.addAccount(revenueAccount)
model.addAccount(cogsAccount)
```

Fluent APIs are declarative and readable:

```swift
// Fluent approach - declarative and clear
let model = buildModel(for: company) {
    Revenue("Product Revenue", periods: periods, values: revenueValues)
    Expense("Cost of Goods Sold", periods: periods, values: cogsValues, type: .costOfGoodsSold)
}
```

The fluent syntax makes your intent clear, reduces boilerplate, and catches errors at compile time.

## ModelBuilder: Building Financial Models

### Basic Model Construction

Start with revenue and cost components:

```swift
import BusinessMath

let company = Entity(
    id: "ACME001",
    primaryType: .ticker,
    name: "Acme Corp"
)

let q1_2025 = Period.quarter(year: 2025, quarter: 1)
let periods = [q1_2025, q1_2025 + 1, q1_2025 + 2, q1_2025 + 3]

// Build a simple revenue model
let model = buildModel(for: company) {
    Revenue("Product Sales", periods: periods, values: [100_000, 110_000, 120_000, 130_000])

    Expense("Manufacturing Costs",
           periods: periods,
           values: [60_000, 66_000, 72_000, 78_000],
           type: .costOfGoodsSold)

    Expense("Operating Expenses",
           periods: periods,
           values: [20_000, 20_000, 20_000, 20_000],
           type: .operatingExpense)
}

// Access results
let totalRevenue = model.totalRevenue(for: q1_2025)  // 100,000
let totalExpenses = model.totalExpenses(for: q1_2025)  // 80,000
let netIncome = totalRevenue - totalExpenses  // 20,000
```

### Product-Based Revenue Models

Define revenue from products with pricing and quantity:

```swift
let model = buildModel(for: company) {
    // Product with price and quantity
    Product("Widget")
        .price(periods: periods, values: [10.0, 10.0, 10.5, 10.5])
        .quantity(periods: periods, values: [10_000, 11_000, 11_500, 12_000])

    Product("Gadget")
        .price(periods: periods, values: [25.0, 25.0, 26.0, 26.0])
        .quantity(periods: periods, values: [2_000, 2_200, 2_300, 2_400])

    // Fixed costs
    FixedCost("Rent", periods: periods, value: 5_000)
    FixedCost("Salaries", periods: periods, value: 15_000)

    // Variable costs (% of revenue)
    VariableCost("Materials", rate: 0.40)  // 40% of revenue
    VariableCost("Shipping", rate: 0.05)   // 5% of revenue
}

// Revenue is automatically calculated from price × quantity
// Variable costs are automatically calculated as % of revenue
```

### Multiple Revenue Sources

Combine different revenue streams:

```swift
let model = buildModel(for: company) {
    // Product revenue
    Revenue("Hardware Sales", periods: periods, values: [80_000, 85_000, 90_000, 95_000])

    // Recurring revenue
    Revenue("Software Subscriptions", periods: periods, values: [20_000, 22_000, 24_000, 26_000])

    // Service revenue
    Revenue("Consulting Services", periods: periods, values: [10_000, 12_000, 15_000, 18_000])

    // Cost structure
    Expense("Cost of Goods Sold",
           periods: periods,
           values: [50_000, 53_000, 56_000, 59_000],
           type: .costOfGoodsSold)

    Expense("Operating Expenses",
           periods: periods,
           values: [30_000, 30_000, 30_000, 30_000],
           type: .operatingExpense)
}

// Total revenue = 80k + 20k + 10k = 110k in Q1
```

### Conditional Components

Use Swift control flow within builders:

```swift
let includeInternationalSales = true
let hasNewProduct = false

let model = buildModel(for: company) {
    // Always included
    Revenue("Domestic Sales", periods: periods, values: [100_000, 110_000, 120_000, 130_000])

    // Conditionally included
    if includeInternationalSales {
        Revenue("International Sales", periods: periods, values: [30_000, 35_000, 40_000, 45_000])
    }

    if hasNewProduct {
        Product("New Widget")
            .price(periods: periods, values: [15.0, 15.0, 15.0, 15.0])
            .quantity(periods: periods, values: [5_000, 5_500, 6_000, 6_500])
    }

    // Costs
    FixedCost("Operating Expenses", periods: periods, value: 20_000)
    VariableCost("Materials", rate: 0.35)
}
```

### Array-Based Components

Build components from collections:

```swift
// Define products in an array
let products = [
    ("Widget A", 10.0, 10_000),
    ("Widget B", 15.0, 8_000),
    ("Widget C", 20.0, 6_000)
]

let model = buildModel(for: company) {
    // Add all products dynamically
    ForEach(products) { name, price, quantity in
        Product(name)
            .price(periods: periods, values: Array(repeating: price, count: 4))
            .quantity(periods: periods, values: Array(repeating: quantity, count: 4))
    }

    // Fixed costs
    FixedCost("Overhead", periods: periods, value: 25_000)
}
```

## InvestmentBuilder: Investment Analysis

### Simple Investment Analysis

Define cash flows and automatically calculate metrics:

```swift
import BusinessMath

// Traditional approach - manual NPV/IRR calculation
let cashFlows = [-100_000.0, 30_000, 35_000, 40_000, 45_000]
let npv = npv(discountRate: 0.10, cashFlows: cashFlows)
let irr = try irr(cashFlows: cashFlows)

// Fluent approach - automatic calculation with rich context
let investment = buildInvestment {
    Name("Warehouse Expansion")
    InitialInvestment(100_000)

    CashFlow(year: 1, amount: 30_000)
    CashFlow(year: 2, amount: 35_000)
    CashFlow(year: 3, amount: 40_000)
    CashFlow(year: 4, amount: 45_000)

    DiscountRate(0.10)
}

// All metrics calculated automatically
print("NPV: $\(investment.npv)")              // ~$16,100
print("IRR: \(investment.irr * 100)%")        // ~14.8%
print("Payback: \(investment.paybackPeriod) years")  // 3 years
print("ROI: \(investment.roi * 100)%")        // ~50%
```

### Investment with Dates

Use specific dates for irregular cash flows:

```swift
let today = Date()
let oneYearOut = Calendar.current.date(byAdding: .year, value: 1, to: today)!
let twoYearsOut = Calendar.current.date(byAdding: .year, value: 2, to: today)!
let threeYearsOut = Calendar.current.date(byAdding: .year, value: 3, to: today)!

let investment = buildInvestment {
    Name("Equipment Purchase")

    CashFlow(date: today, amount: -75_000)        // Initial investment
    CashFlow(date: oneYearOut, amount: 25_000)    // Year 1 return
    CashFlow(date: twoYearsOut, amount: 30_000)   // Year 2 return
    CashFlow(date: threeYearsOut, amount: 35_000) // Year 3 return

    DiscountRate(0.08)
}

// Uses XNPV/XIRR for irregular intervals
print("NPV: $\(investment.npv)")
print("IRR: \(investment.irr * 100)%")
```

### Investment Categories

Group and analyze related investments:

```swift
let investment = buildInvestment {
    Name("Digital Transformation Initiative")
    Category("Technology")

    InitialInvestment(250_000)

    // Cash flows by category
    CashFlowCategory("Cost Savings") {
        CashFlow(year: 1, amount: 50_000)
        CashFlow(year: 2, amount: 60_000)
        CashFlow(year: 3, amount: 70_000)
    }

    CashFlowCategory("Revenue Growth") {
        CashFlow(year: 1, amount: 30_000)
        CashFlow(year: 2, amount: 40_000)
        CashFlow(year: 3, amount: 50_000)
    }

    DiscountRate(0.12)
}

// Analyze by category
let costSavingsNPV = investment.npv(for: "Cost Savings")
let revenueGrowthNPV = investment.npv(for: "Revenue Growth")
```

### Comparing Multiple Investments

Build a portfolio for comparison:

```swift
let investmentA = buildInvestment {
    Name("Project A - Quick Win")
    InitialInvestment(50_000)
    CashFlow(year: 1, amount: 30_000)
    CashFlow(year: 2, amount: 30_000)
    DiscountRate(0.10)
}

let investmentB = buildInvestment {
    Name("Project B - Long-term Growth")
    InitialInvestment(100_000)
    CashFlow(year: 1, amount: 20_000)
    CashFlow(year: 2, amount: 30_000)
    CashFlow(year: 3, amount: 40_000)
    CashFlow(year: 4, amount: 50_000)
    DiscountRate(0.10)
}

// Compare metrics
print("Project A: NPV = $\(investmentA.npv), IRR = \(investmentA.irr * 100)%")
print("Project B: NPV = $\(investmentB.npv), IRR = \(investmentB.irr * 100)%")

// Decision: Project B has higher NPV, but Project A has higher IRR and faster payback
```

## ScenarioBuilder: Scenario Analysis

### Creating Scenarios

Define base, best, and worst case scenarios:

```swift
import BusinessMath

// Base case scenario
let baseCase = buildScenario {
    Name("Base Case")
    Description("Expected performance with current assumptions")

    Driver("Revenue Growth", value: 0.15)      // 15% growth
    Driver("Gross Margin", value: 0.60)        // 60% margin
    Driver("Operating Expenses", value: 200_000)
    Driver("Tax Rate", value: 0.25)            // 25% tax
}

// Best case scenario
let bestCase = buildScenario {
    Name("Best Case")
    Description("Optimistic performance with favorable conditions")

    Driver("Revenue Growth", value: 0.25)      // 25% growth
    Driver("Gross Margin", value: 0.65)        // 65% margin
    Driver("Operating Expenses", value: 180_000)
    Driver("Tax Rate", value: 0.25)
}

// Worst case scenario
let worstCase = buildScenario {
    Name("Worst Case")
    Description("Conservative performance in adverse conditions")

    Driver("Revenue Growth", value: 0.05)      // 5% growth
    Driver("Gross Margin", value: 0.55)        // 55% margin
    Driver("Operating Expenses", value: 220_000)
    Driver("Tax Rate", value: 0.30)            // Higher taxes
}
```

### Scenario Adjustments

Modify scenarios by adjusting specific drivers:

```swift
let scenario = buildScenario {
    Name("Market Expansion")

    // Base assumptions
    Driver("Domestic Revenue", value: 1_000_000)
    Driver("Cost of Goods Sold", value: 600_000)
    Driver("Operating Expenses", value: 200_000)

    // Adjustments for expansion
    Adjustment("Add International Revenue") {
        AddDriver("International Revenue", value: 300_000)
        AdjustDriver("Operating Expenses", increase: 50_000)  // Hire international team
        AdjustDriver("Cost of Goods Sold", multiplyBy: 1.10)  // 10% higher COGS internationally
    }
}

// Scenario reflects all adjustments
let totalRevenue = scenario.totalRevenue  // 1,300,000
let totalCosts = scenario.totalCosts      // 660,000
let totalOpEx = scenario.operatingExpenses // 250,000
```

### Conditional Scenarios

Use logic to define scenario variants:

```swift
let marketCondition = "recession"
let hasNewProduct = true

let scenario = buildScenario {
    Name("2025 Planning")

    // Adjust based on market conditions
    if marketCondition == "growth" {
        Driver("Revenue Growth", value: 0.20)
        Driver("Gross Margin", value: 0.65)
    } else if marketCondition == "recession" {
        Driver("Revenue Growth", value: 0.05)
        Driver("Gross Margin", value: 0.55)
    } else {
        Driver("Revenue Growth", value: 0.10)
        Driver("Gross Margin", value: 0.60)
    }

    // New product launch
    if hasNewProduct {
        AddDriver("New Product Revenue", value: 150_000)
        AddDriver("New Product Marketing", value: 30_000)
    }

    // Base expenses
    Driver("Operating Expenses", value: 200_000)
}
```

### Sensitivity Analysis

Vary drivers to understand impact:

```swift
let baseScenario = buildScenario {
    Name("Sensitivity Base")
    Driver("Revenue", value: 1_000_000)
    Driver("Gross Margin", value: 0.60)
    Driver("Operating Expenses", value: 200_000)
}

// Analyze sensitivity to revenue changes
let revenueScenarios = [-20%, -10%, 0%, +10%, +20%].map { change in
    buildScenario {
        Name("Revenue \(change > 0 ? "+" : "")\(change)%")

        Driver("Revenue", value: 1_000_000 * (1.0 + change))
        Driver("Gross Margin", value: 0.60)
        Driver("Operating Expenses", value: 200_000)
    }
}

// Compare results across all scenarios
for scenario in revenueScenarios {
    let netIncome = scenario.revenue * scenario.grossMargin - scenario.opex
    print("\(scenario.name): Net Income = $\(netIncome)")
}
// Revenue -20%: Net Income = $280,000
// Revenue -10%: Net Income = $340,000
// Revenue +0%: Net Income = $400,000
// Revenue +10%: Net Income = $460,000
// Revenue +20%: Net Income = $520,000
```

## TimeSeriesBuilder: Declarative Time Series

### Building Time Series

Create time series with natural syntax:

```swift
import BusinessMath

let jan = Period.month(year: 2025, month: 1)

// Traditional approach
let periods = (0..<12).map { jan + $0 }
let values = [100, 105, 110, 108, 115, 120, 118, 125, 130, 128, 135, 140]
let ts = TimeSeries(periods: periods, values: values)

// Fluent approach
let revenue = buildTimeSeries(startingAt: jan) {
    Entry(100)  // January
    Entry(105)  // February
    Entry(110)  // March
    Entry(108)  // April
    Entry(115)  // May
    Entry(120)  // June
    Entry(118)  // July
    Entry(125)  // August
    Entry(130)  // September
    Entry(128)  // October
    Entry(135)  // November
    Entry(140)  // December
}
```

### Named Entries

Add labels for clarity:

```swift
let revenue = buildTimeSeries(startingAt: jan) {
    Entry(100, label: "January")
    Entry(105, label: "February")
    Entry(110, label: "March")
    Entry(108, label: "April")
    Entry(115, label: "May")
    Entry(120, label: "June")
    Entry(118, label: "July")
    Entry(125, label: "August")
    Entry(130, label: "September")
    Entry(128, label: "October")
    Entry(135, label: "November")
    Entry(140, label: "December")
}

// Labels available for debugging and display
print(revenue.label(for: jan))  // "January"
```

### Array-Based Construction

Generate entries from data:

```swift
let historicalData = [
    100, 105, 110, 108, 115, 120,
    118, 125, 130, 128, 135, 140
]

let revenue = buildTimeSeries(startingAt: jan) {
    ForEach(historicalData) { value in
        Entry(value)
    }
}

// Or with indices
let revenue2 = buildTimeSeries(startingAt: jan) {
    ForEach(Array(historicalData.enumerated())) { index, value in
        Entry(value, label: "Month \(index + 1)")
    }
}
```

### Conditional Entries

Use control flow to build time series:

```swift
let includeSeasonalBoost = true
let holidayMonths = [11, 12]  // November, December

let revenue = buildTimeSeries(startingAt: jan) {
    ForEach(1...12) { month in
        let baseRevenue = 100_000.0

        // Apply seasonal boost for holiday months
        if includeSeasonalBoost && holidayMonths.contains(month) {
            Entry(baseRevenue * 1.3, label: "Month \(month) - Holiday Boost")
        } else {
            Entry(baseRevenue, label: "Month \(month)")
        }
    }
}
```

### Computed Entries

Calculate values based on previous entries:

```swift
let revenue = buildTimeSeries(startingAt: jan) {
    Entry(100, label: "Base")

    // Each month grows by 5%
    Growth(rate: 0.05, periods: 11)  // 11 more months
}

// Result: [100, 105, 110.25, 115.76, 121.55, ...]

// Or with explicit calculations
let revenue2 = buildTimeSeries(startingAt: jan) {
    var current = 100.0

    ForEach(1...12) { month in
        Entry(current, label: "Month \(month)")
        current *= 1.05  // Grow by 5%
    }
}
```

## Advanced Patterns

### Nested Builders

Combine builders for complex models:

```swift
let model = buildModel(for: company) {
    // Build revenue from a scenario
    let revenueScenario = buildScenario {
        Driver("Base Revenue", value: 100_000)
        Driver("Growth Rate", value: 0.10)
    }

    let revenueTS = buildTimeSeries(startingAt: q1) {
        ForEach(0..<4) { quarter in
            let revenue = revenueScenario.baseRevenue * pow(1 + revenueScenario.growthRate, Double(quarter) / 4.0)
            Entry(revenue)
        }
    }

    Revenue("Product Sales", timeSeries: revenueTS)

    // Costs as % of revenue
    VariableCost("COGS", rate: 0.40)
    FixedCost("Operating Expenses", periods: periods, value: 20_000)
}
```

### Custom Components

Define reusable builder components:

```swift
// Custom product bundle component
struct ProductBundle {
    let name: String
    let products: [(String, Double, Int)]

    @ModelBuilder
    func buildComponent(for periods: [Period]) -> [ModelComponent] {
        ForEach(products) { productName, price, quantity in
            Product(productName)
                .price(periods: periods, values: Array(repeating: price, count: periods.count))
                .quantity(periods: periods, values: Array(repeating: quantity, count: periods.count))
        }
    }
}

// Use custom component
let model = buildModel(for: company) {
    ProductBundle(
        name: "Widget Bundle",
        products: [
            ("Widget A", 10.0, 10_000),
            ("Widget B", 15.0, 8_000),
            ("Widget C", 20.0, 6_000)
        ]
    ).buildComponent(for: periods)

    FixedCost("Overhead", periods: periods, value: 25_000)
}
```

## Best Practices

### When to Use Fluent APIs

**Use fluent builders when:**
- Building models with multiple components
- Creating scenarios for comparison
- Defining investments for analysis
- Constructing time series from structured data
- Readability is important (presentations, documentation)
- You want compile-time validation

**Use traditional construction when:**
- Building single-component objects
- Performance is critical (tight loops)
- Migrating existing code incrementally
- Integration with external systems
- Dynamic construction from external data sources

### Performance Considerations

Fluent APIs have minimal overhead:

```swift
// Both approaches have similar performance
// Fluent (negligible overhead from result builder)
let model1 = buildModel(for: company) {
    Revenue("Sales", periods: periods, values: values)
    FixedCost("Overhead", periods: periods, value: 10_000)
}

// Traditional (slightly less memory allocation)
var model2 = FinancialModel(entity: company)
model2.addRevenue("Sales", periods: periods, values: values)
model2.addFixedCost("Overhead", periods: periods, value: 10_000)

// For 1000+ components, consider traditional approach
// For < 100 components, fluent APIs are fine
```

### Error Handling in Builders

Handle errors gracefully:

```swift
// Throwing from within builders
let model = buildModel(for: company) {
    // This compiles but may throw at runtime
    try Revenue("Sales", periods: periods, values: values)

    // Better: validate before building
    if periods.count != values.count {
        // Handle error before builder
        fatalError("Periods and values must match")
    }

    Revenue("Sales", periods: periods, values: values)
}

// Or use Result type
let modelResult = Result {
    try buildModel(for: company) {
        try Revenue("Sales", periods: periods, values: values)
        FixedCost("Overhead", periods: periods, value: 10_000)
    }
}

switch modelResult {
case .success(let model):
    print("Model built successfully")
case .failure(let error):
    print("Error building model: \(error)")
}
```

### Testing Builder-Based Code

Test fluent APIs like any other code:

```swift
import Testing
@testable import BusinessMath

@Test("ModelBuilder creates correct structure")
func testModelBuilder() {
    let company = Entity(id: "TEST", primaryType: .ticker, name: "Test")
    let periods = [Period.quarter(year: 2025, quarter: 1)]

    let model = buildModel(for: company) {
        Revenue("Sales", periods: periods, values: [100_000])
        FixedCost("Overhead", periods: periods, value: 20_000)
    }

    #expect(model.entity == company)
    #expect(model.revenueAccounts.count == 1)
    #expect(model.totalRevenue(for: periods[0]) == 100_000)
    #expect(model.totalExpenses(for: periods[0]) == 20_000)
}

@Test("InvestmentBuilder calculates metrics")
func testInvestmentBuilder() {
    let investment = buildInvestment {
        InitialInvestment(100_000)
        CashFlow(year: 1, amount: 30_000)
        CashFlow(year: 2, amount: 40_000)
        CashFlow(year: 3, amount: 50_000)
        DiscountRate(0.10)
    }

    #expect(investment.initialInvestment == 100_000)
    #expect(investment.cashFlows.count == 4)
    #expect(investment.npv > 0)  // Positive NPV
    #expect(investment.irr > 0.10)  // IRR > discount rate
}
```

## Common Workflows

### Complete Financial Model

Build a comprehensive financial model:

```swift
let company = Entity(id: "ACME", primaryType: .ticker, name: "Acme Corp")
let jan = Period.month(year: 2025, month: 1)
let months = (0..<12).map { jan + $0 }

let model = buildModel(for: company) {
    // Revenue streams
    Product("Widget Pro")
        .price(periods: months, values: Array(repeating: 10.0, count: 12))
        .quantity(periods: months, values: [10_000, 11_000, 12_000, 13_000, 14_000, 15_000,
                                            16_000, 17_000, 18_000, 19_000, 20_000, 21_000])

    Revenue("Subscription Services",
           periods: months,
           values: buildTimeSeries(startingAt: jan) {
               Entry(5_000)
               Growth(rate: 0.05, periods: 11)  // 5% monthly growth
           }.valuesArray)

    // Cost structure
    VariableCost("Materials", rate: 0.40)  // 40% of revenue
    VariableCost("Shipping", rate: 0.05)   // 5% of revenue

    FixedCost("Salaries", periods: months, value: 50_000)
    FixedCost("Rent", periods: months, value: 10_000)
    FixedCost("Utilities", periods: months, value: 2_000)
}

// Analyze results
for month in months {
    let revenue = model.totalRevenue(for: month)
    let expenses = model.totalExpenses(for: month)
    let netIncome = revenue - expenses

    print("\(month): Revenue = $\(revenue), Expenses = $\(expenses), Net Income = $\(netIncome)")
}
```

### Scenario Comparison Workflow

Compare multiple scenarios:

```swift
// Define scenarios
let scenarios = [
    buildScenario {
        Name("Conservative")
        Driver("Revenue Growth", value: 0.05)
        Driver("Gross Margin", value: 0.55)
        Driver("Operating Expenses", value: 220_000)
    },
    buildScenario {
        Name("Base Case")
        Driver("Revenue Growth", value: 0.15)
        Driver("Gross Margin", value: 0.60)
        Driver("Operating Expenses", value: 200_000)
    },
    buildScenario {
        Name("Aggressive")
        Driver("Revenue Growth", value: 0.25)
        Driver("Gross Margin", value: 0.65)
        Driver("Operating Expenses", value: 180_000)
    }
]

// Build model for each scenario
let baseRevenue = 1_000_000.0

for scenario in scenarios {
    let yearEndRevenue = baseRevenue * (1 + scenario.revenueGrowth)
    let grossProfit = yearEndRevenue * scenario.grossMargin
    let netIncome = grossProfit - scenario.operatingExpenses

    print("\(scenario.name):")
    print("  Revenue: $\(yearEndRevenue)")
    print("  Gross Profit: $\(grossProfit)")
    print("  Net Income: $\(netIncome)")
    print()
}
```

### Investment Portfolio Analysis

Analyze multiple investments:

```swift
// Define investment options
let investments = [
    buildInvestment {
        Name("Project A - Equipment Upgrade")
        Category("Capital Expenditure")
        InitialInvestment(75_000)
        CashFlow(year: 1, amount: 25_000)
        CashFlow(year: 2, amount: 30_000)
        CashFlow(year: 3, amount: 35_000)
        DiscountRate(0.10)
    },
    buildInvestment {
        Name("Project B - Market Expansion")
        Category("Growth")
        InitialInvestment(150_000)
        CashFlow(year: 1, amount: 30_000)
        CashFlow(year: 2, amount: 50_000)
        CashFlow(year: 3, amount: 70_000)
        CashFlow(year: 4, amount: 90_000)
        DiscountRate(0.10)
    },
    buildInvestment {
        Name("Project C - Cost Reduction")
        Category("Efficiency")
        InitialInvestment(50_000)
        CashFlow(year: 1, amount: 20_000)
        CashFlow(year: 2, amount: 20_000)
        CashFlow(year: 3, amount: 20_000)
        DiscountRate(0.10)
    }
]

// Rank by NPV
let ranked = investments.sorted { $0.npv > $1.npv }

print("Investment Rankings by NPV:")
for (index, investment) in ranked.enumerated() {
    print("\(index + 1). \(investment.name)")
    print("   NPV: $\(investment.npv)")
    print("   IRR: \(investment.irr * 100)%")
    print("   Payback: \(investment.paybackPeriod) years")
    print()
}
```

## Next Steps

- Learn about <doc:TemplateGuide> for pre-built industry models
- Explore <doc:BuildingRevenueModel> for complete modeling workflows
- Read <doc:ScenarioAnalysisGuide> for advanced scenario techniques
- Check <doc:InvestmentAnalysis> for valuation patterns
- Review <doc:ErrorHandlingGuide> for handling errors in builders

## See Also

- ``ModelBuilder``
- ``InvestmentBuilder``
- ``ScenarioBuilder``
- ``TimeSeriesBuilder``
- ``FinancialModel``
- ``Investment``
- ``FinancialScenario``
- ``TimeSeries``
