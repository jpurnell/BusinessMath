# BusinessMathDSL - Declarative Financial Modeling

A Swift result builder DSL for creating financial projections with clean, type-safe, declarative syntax.

## Overview

BusinessMathDSL is a separate opt-in module for the BusinessMath package that provides result builder syntax for financial modeling. It complements the existing fluent API by offering a more declarative approach to building cash flow models.

## Installation

BusinessMathDSL is included in the BusinessMath package. Simply import it:

```swift
import BusinessMathDSL
```

## Quick Start

### Basic Cash Flow Model

```swift
import BusinessMathDSL

let projection = CashFlowModel(
    revenue: Revenue {
        Base(1_000_000)
        GrowthRate(0.15)
    },
    expenses: Expenses {
        Fixed(100_000)
        Variable(percentage: 0.40)
    },
    taxes: Taxes {
        CorporateRate(0.21)
    }
)

// Calculate year 1
let year1 = projection.calculate(year: 1)
print("Year 1 Revenue: \(year1.revenue)")
print("Year 1 Net Income: \(year1.netIncome)")

// Calculate multi-year projections
let fiveYears = projection.calculateYears(1...5)
```

## Components

### 1. Revenue

Model revenue with base amounts, growth rates, and quarterly seasonality.

```swift
let revenue = Revenue {
    Base(5_000_000)                     // $5M annual base
    GrowthRate(0.20)                    // 20% YoY growth
    Seasonality([1.5, 1.0, 0.75, 0.75]) // Q1 strong, Q3-Q4 weak
}

// Annual revenue
let year1 = revenue.value(forYear: 1)  // 5,000,000
let year2 = revenue.value(forYear: 2)  // 6,000,000 (20% growth)

// Quarterly revenue with seasonality
let year1Q1 = revenue.value(forYear: 1, quarter: 1)  // 1,875,000
let year1Q2 = revenue.value(forYear: 1, quarter: 2)  // 1,250,000
```

**Key Points:**
- `Base(amount)` - Annual revenue baseline
- `GrowthRate(rate)` - Compound annual growth rate (e.g., 0.15 = 15%)
- `Seasonality([q1, q2, q3, q4])` - Quarterly multipliers (must sum to 4.0)

### 2. Expenses

Model three types of expenses: fixed, variable (% of revenue), and one-time.

```swift
let expenses = Expenses {
    Fixed(200_000)                // Rent
    Fixed(300_000)                // Salaries
    Variable(percentage: 0.30)    // COGS (30% of revenue)
    Variable(percentage: 0.05)    // Commissions (5% of revenue)
    OneTime(1_000_000, in: 2)     // Capital investment in year 2
    OneTime(200_000, in: 4)       // Equipment upgrade in year 4
}

let year1Total = expenses.value(forYear: 1, revenue: 1_000_000)
// = 500,000 (fixed) + 350,000 (35% of revenue) + 0 (no one-time) = 850,000

let year2Total = expenses.value(forYear: 2, revenue: 1_200_000)
// = 500,000 + 420,000 + 1,000,000 (one-time) = 1,920,000
```

**Key Points:**
- `Fixed(amount)` - Constant annual costs (can specify multiple)
- `Variable(percentage:)` - Scales with revenue (can specify multiple)
- `OneTime(amount, in: year)` - One-off expenses in specific years

### 3. Depreciation

Model asset depreciation using straight-line schedules.

```swift
let depreciation = Depreciation {
    StraightLine(asset: 2_000_000, years: 10)  // Building
    StraightLine(asset: 500_000, years: 5)     // Equipment
    StraightLine(asset: 100_000, years: 3)     // Computers
}

let year1 = depreciation.value(forYear: 1)   // 333,333 total
let year6 = depreciation.value(forYear: 6)   // 200,000 (only building)
let year11 = depreciation.value(forYear: 11) // 0 (all fully depreciated)
```

**Key Points:**
- `StraightLine(asset:, years:)` - Asset value and depreciation period
- Depreciation is a non-cash expense (reduces taxes but added back for FCF)
- Multiple schedules are automatically combined

### 4. Taxes

Model corporate and state tax rates.

```swift
let taxes = Taxes {
    CorporateRate(0.21)  // 21% federal
    StateRate(0.06)      // 6% state
}

print(taxes.effectiveRate)  // 0.27 (27% total)

let taxOn1M = taxes.value(on: 1_000_000)  // 270,000
```

**Key Points:**
- `CorporateRate(rate)` - Federal corporate tax rate
- `StateRate(rate)` - State/local tax rate
- Taxes calculated on EBIT (after depreciation)
- Negative EBIT (losses) results in zero tax

## Complete Example

```swift
import BusinessMathDSL

// Create a comprehensive 5-year financial model
let projection = CashFlowModel(
    revenue: Revenue {
        Base(5_000_000)
        GrowthRate(0.20)
        Seasonality([1.5, 1.0, 0.75, 0.75])
    },
    expenses: Expenses {
        Fixed(500_000)              // Annual overhead
        Variable(percentage: 0.35)  // 35% COGS
        OneTime(1_000_000, in: 2)   // Year 2 expansion
    },
    depreciation: Depreciation {
        StraightLine(asset: 2_000_000, years: 10)
        StraightLine(asset: 500_000, years: 5)
    },
    taxes: Taxes {
        CorporateRate(0.21)
        StateRate(0.06)
    }
)

// Annual projections
for year in 1...5 {
    let result = projection.calculate(year: year)
    print("Year \(year):")
    print("  Revenue:      \(result.revenue)")
    print("  Expenses:     \(result.expenses)")
    print("  EBITDA:       \(result.ebitda)")
    print("  Depreciation: \(result.depreciation)")
    print("  EBIT:         \(result.ebit)")
    print("  Taxes:        \(result.taxes)")
    print("  Net Income:   \(result.netIncome)")
    print()
}

// Free cash flow (Net Income + Depreciation)
let year1FCF = projection.freeCashFlow(year: 1)
print("Year 1 Free Cash Flow: \(year1FCF)")

// Quarterly breakdown for year 1
let quarters = projection.calculateQuarters(year: 1)
for (index, quarter) in quarters.enumerated() {
    print("Q\(index + 1) Revenue: \(quarter.revenue)")
}
```

## Cash Flow Calculation Flow

The model follows standard financial statement logic:

```
Revenue (R)
  - Expenses (E)
  = EBITDA (Earnings Before Interest, Taxes, Depreciation, Amortization)
  - Depreciation (D)
  = EBIT (Earnings Before Interest and Taxes)
  - Taxes (T) [calculated on EBIT]
  = Net Income (NI)

Free Cash Flow = Net Income + Depreciation
```

## CashFlowResult Structure

Each calculation returns a `CashFlowResult` with:

```swift
public struct CashFlowResult {
    public let revenue: Double
    public let expenses: Double
    public let ebitda: Double
    public let depreciation: Double
    public let ebit: Double
    public let taxes: Double
    public let netIncome: Double
}
```

## Validation

Components use `fatalError` for invalid inputs to catch programmer errors during development:

- **Revenue**: Base cannot be negative, growth rate cannot be < -100%
- **Seasonality**: Must have exactly 4 factors that sum to 4.0
- **Expenses**: Amounts cannot be negative, percentages must be 0-1
- **Depreciation**: Asset values and years must be positive
- **Taxes**: Rates must be between 0 and 1

**Note**: Validate user input before creating components in production code.

## Property Wrapper

For stored properties, you can use the `@CashFlowProjection` property wrapper:

```swift
struct FinancialPlan {
    @CashFlowProjection
    var projection = CashFlowModel(
        revenue: Revenue {
            Base(1_000_000)
            GrowthRate(0.15)
        }
    )
}

let plan = FinancialPlan()
let results = plan.projection.calculate(year: 1)
```

## Comparison with Fluent API

BusinessMath also includes a fluent API (different module). Choose based on your preference:

**Result Builder DSL (this module):**
```swift
let projection = CashFlowModel(
    revenue: Revenue {
        Base(1_000_000)
        GrowthRate(0.15)
    }
)
```

**Fluent API (BusinessMath):**
```swift
let projection = FinancialModel()
    .revenue(base: 1_000_000)
    .growth(rate: 0.15)
```

Both approaches produce equivalent models and calculations.

## Liquidation Waterfall Distributions

Model private equity and venture capital distribution waterfalls with priority-based profit allocation.

### Basic Waterfall Structure

```swift
let waterfall = LiquidationWaterfall {
    Tier("LP Capital Return", to: "LP") {
        CapitalReturn(1_000_000)  // Return original investment first
    }
    Tier("LP Preferred Return", to: "LP") {
        PreferredReturn(0.08, years: 3)  // 8% annual for 3 years
    }
    Tier("Residual Split", to: ["LP", "GP"]) {
        ProRata(split: ["LP": 0.80, "GP": 0.20])  // 80/20 split
    }
}

let result = waterfall.distribute(2_000_000)
// result.distributions["LP"] → 1,640,000
// result.distributions["GP"] → 360,000
```

### GP Catch-Up Provision

```swift
let waterfall = LiquidationWaterfall {
    Tier("LP Capital + Preferred", to: "LP") {
        CapitalReturn(1_000_000)
        PreferredReturn(0.08, years: 3)
    }
    Tier("GP Catch-Up", to: "GP") {
        CatchUp(targetPercentage: 0.20)  // Brings GP to 20% of profits
    }
    Tier("Residual", to: ["LP", "GP"]) {
        ProRata(split: ["LP": 0.80, "GP": 0.20])
    }
}

// Distribution: $2M
// LP gets: 1M capital + 240k preferred = 1,240,000
// GP catch-up brings them to 20% of total profits
// Remaining splits 80/20
let result = waterfall.distribute(2_000_000)
```

**Key Components:**
- `CapitalReturn(amount)` - Return of original capital
- `PreferredReturn(rate, years:)` - Hurdle rate over period
- `CatchUp(targetPercentage:)` - Brings GP to target % of profits
- `ProRata(split:)` - Percentage-based distribution
- `Residual()` - Distributes remainder to tier recipients

## Scenario Analysis

Perform what-if analysis, sensitivity testing, and Monte Carlo simulation for business planning.

### Simple Scenario Comparison

```swift
let analysis = ScenarioAnalysis {
    Scenario("Conservative") {
        Parameter("revenue", value: 800_000)
        Parameter("growth", value: 0.05)
        Parameter("expenses", value: 0.65)
    }
    Scenario("Base Case") {
        Parameter("revenue", value: 1_000_000)
        Parameter("growth", value: 0.15)
        Parameter("expenses", value: 0.60)
    }
    Scenario("Aggressive") {
        Parameter("revenue", value: 1_500_000)
        Parameter("growth", value: 0.25)
        Parameter("expenses", value: 0.55)
    }
}

// Evaluate with custom function
let results = analysis.evaluate { scenario in
    let revenue = scenario.parameters["revenue"]!
    let growth = scenario.parameters["growth"]!
    let expenses = scenario.parameters["expenses"]!
    return revenue * (1 + growth) * (1 - expenses)
}

print(results["Conservative"])  // 294,000
print(results["Aggressive"])    // 843,750
```

### Parameter Sensitivity Analysis

Test how changes in one parameter affect outcomes:

```swift
let analysis = ScenarioAnalysis {
    BaseScenario {
        Parameter("revenue", value: 1_000_000)
        Parameter("expenses", value: 0.60)
        Parameter("taxRate", value: 0.21)
    }
    Vary("growth", from: 0.05, to: 0.25, steps: 5)
}
// Creates 5 scenarios with growth: [5%, 10%, 15%, 20%, 25%]

let stats = analysis.statistics { scenario in
    let revenue = scenario.parameters["revenue"]!
    let growth = scenario.parameters["growth"]!
    return revenue * growth
}

print("Mean: \(stats.mean)")
print("Median: \(stats.median)")
print("Std Dev: \(stats.stdDev)")
print("Range: \(stats.min) to \(stats.max)")
```

### Multi-Parameter Variations

Create scenarios with multiple varying parameters (Cartesian product):

```swift
let analysis = ScenarioAnalysis {
    BaseScenario {
        Parameter("initialPrice", value: 100)
    }
    Vary("volume", from: 1000, to: 2000, steps: 3)    // [1000, 1500, 2000]
    Vary("discount", values: [0.0, 0.10, 0.20])       // [0%, 10%, 20%]
}
// Creates 3 × 3 = 9 scenarios (all combinations)

let results = analysis.evaluate { scenario in
    let price = scenario.parameters["initialPrice"]!
    let volume = scenario.parameters["volume"]!
    let discount = scenario.parameters["discount"]!
    return price * volume * (1 - discount)
}

// Find best and worst outcomes
let best = analysis.best { scenario in
    let volume = scenario.parameters["volume"]!
    let discount = scenario.parameters["discount"]!
    return volume * (1 - discount)
}
print("Best scenario: \(best?.name ?? "None")")
```

### Tornado Chart Analysis

Identify which parameters have the greatest impact on outcomes:

```swift
let analysis = ScenarioAnalysis {
    BaseScenario {
        Parameter("revenue", value: 1_000_000)
        Parameter("expenses", value: 600_000)
        Parameter("growth", value: 0.15)
    }
    TornadoChart {
        Vary("revenue", by: 0.20)    // ±20% → [0.8×, 1.0×, 1.2×]
        Vary("expenses", by: 0.10)   // ±10% → [0.9×, 1.0×, 1.1×]
        Vary("growth", by: 0.05)     // ±5 pp → [0.95×, 1.0×, 1.05×]
    }
}

// Each parameter gets low/base/high scenarios
// Analyze which parameter creates largest swing in outcomes
let results = analysis.evaluate { scenario in
    let revenue = scenario.parameters["revenue"]!
    let expenses = scenario.parameters["expenses"]!
    return revenue - expenses
}

// Sort by impact range to create tornado chart
// Parameter with widest range has most influence
```

### Monte Carlo Simulation

Model uncertainty with probability distributions:

```swift
let analysis = ScenarioAnalysis {
    BaseScenario {
        Parameter("fixedCosts", value: 500_000)
    }
    MonteCarlo(trials: 10_000) {
        RandomParameter("revenue",
            distribution: .normal(mean: 1_000_000, stdDev: 200_000))
        RandomParameter("expenseRate",
            distribution: .uniform(min: 0.50, max: 0.70))
        RandomParameter("taxRate",
            distribution: .triangular(min: 0.15, mode: 0.21, max: 0.30))
    }
}

// Run 10,000 random scenarios
let evaluate = { (scenario: Scenario) -> Double in
    let revenue = scenario.parameters["revenue"]!
    let expenseRate = scenario.parameters["expenseRate"]!
    let taxRate = scenario.parameters["taxRate"]!
    let fixedCosts = scenario.parameters["fixedCosts"]!

    let grossProfit = revenue * (1 - expenseRate) - fixedCosts
    return grossProfit * (1 - taxRate)
}

// Statistical analysis
let stats = analysis.statistics(for: evaluate)
print("Mean outcome: \(stats.mean)")
print("Median outcome: \(stats.median)")
print("Std deviation: \(stats.stdDev)")

// Risk percentiles
let p10 = analysis.percentile(10, for: evaluate)  // 10th percentile (downside)
let p50 = analysis.percentile(50, for: evaluate)  // Median
let p90 = analysis.percentile(90, for: evaluate)  // 90th percentile (upside)

print("10% chance outcome is below: \(p10)")
print("90% chance outcome is below: \(p90)")
```

### Probability Distributions

**Normal Distribution** - Bell curve, best for parameters with historical volatility:
```swift
.normal(mean: 0.15, stdDev: 0.05)
// 68% of values within ±1 std dev (0.10 to 0.20)
// 95% of values within ±2 std dev (0.05 to 0.25)
```

**Uniform Distribution** - Equal probability across range, best for unknown distribution:
```swift
.uniform(min: 0.50, max: 0.70)
// All values between 50% and 70% equally likely
```

**Triangular Distribution** - Most likely value with min/max bounds, best for expert estimates:
```swift
.triangular(min: 0.15, mode: 0.21, max: 0.30)
// Peaks at 21%, with linear probability to extremes
// Good for pessimistic/likely/optimistic estimates
```

### Integration with Cash Flow Models

Use scenario parameters to drive financial projections:

```swift
let scenarios = ScenarioAnalysis {
    Scenario("Conservative") {
        Parameter("baseRevenue", value: 800_000)
        Parameter("growthRate", value: 0.05)
        Parameter("expenseRate", value: 0.65)
    }
    Scenario("Aggressive") {
        Parameter("baseRevenue", value: 1_500_000)
        Parameter("growthRate", value: 0.25)
        Parameter("expenseRate", value: 0.55)
    }
}

// Evaluate using full cash flow model
let netIncomeResults = scenarios.evaluate { scenario in
    let projection = CashFlowModel(
        revenue: Revenue {
            Base(scenario.parameters["baseRevenue"]!)
            GrowthRate(scenario.parameters["growthRate"]!)
        },
        expenses: Expenses {
            Variable(percentage: scenario.parameters["expenseRate"]!)
        },
        taxes: Taxes {
            CorporateRate(0.21)
        }
    )
    return projection.calculate(year: 1).netIncome
}

print("Conservative Year 1 Net Income: \(netIncomeResults["Conservative"]!)")
print("Aggressive Year 1 Net Income: \(netIncomeResults["Aggressive"]!)")
```

## DCF Valuation Models

Build complete discounted cash flow (DCF) valuations with forecasts, terminal values, and WACC calculations.

### Basic DCF Valuation

```swift
let dcf = DCFModel {
    Forecast(5) {  // 5-year forecast
        ForecastRevenue(base: 1_000_000, cagr: 0.15)  // $1M base, 15% CAGR
        EBITDA(margin: 0.25)                          // 25% EBITDA margin
        CapEx(percentage: 0.08)                       // 8% of revenue
        WorkingCapital(daysOfSales: 45)               // 45 days tied up
    }

    TerminalValue {
        PerpetualGrowth(rate: 0.03)  // 3% perpetual growth
    }

    WACC {
        CostOfEquity(0.12)      // 12% cost of equity
        CostOfDebt(0.05)        // 5% cost of debt (pre-tax)
        TaxRate(0.21)           // 21% tax rate
        DebtToEquity(0.30)      // 30% debt, 70% equity
    }
}

let valuation = dcf.calculateEnterpriseValue()
print("Enterprise Value: $\(valuation.enterpriseValue)")
print("PV of Cash Flows: $\(valuation.presentValueOfFCF)")
print("PV of Terminal Value: $\(valuation.presentValueOfTerminalValue)")
```

### Forecast Components

**Revenue Forecast**: Base amount with compound annual growth rate

```swift
ForecastRevenue(base: 1_000_000, cagr: 0.15)
// Year 1: $1,000,000
// Year 2: $1,150,000 (15% growth)
// Year 3: $1,322,500 (15% growth)
// Year 4: $1,520,875
// Year 5: $1,749,006
```

**EBITDA Margin**: Earnings before interest, taxes, depreciation, and amortization

```swift
EBITDA(margin: 0.25)  // 25% of revenue
```

**Capital Expenditures**: Investments in fixed assets

```swift
CapEx(percentage: 0.08)  // 8% of revenue each year
```

**Depreciation**: Non-cash expense

```swift
ForecastDepreciation(percentage: 0.05)  // 5% of revenue
```

**Working Capital**: Cash tied up in operations

```swift
WorkingCapital(daysOfSales: 45)  // 45 days of revenue
// Automatically calculates incremental working capital changes
```

### Complete Forecast Example

```swift
let forecast = Forecast(5) {
    ForecastRevenue(base: 1_000_000, cagr: 0.15)
    EBITDA(margin: 0.25)
    ForecastDepreciation(percentage: 0.05)
    CapEx(percentage: 0.08)
    WorkingCapital(daysOfSales: 45)
}

// Access projections
print("Revenues: \(forecast.projectedRevenues)")
print("EBITDA: \(forecast.projectedEBITDA)")
print("Free Cash Flows: \(forecast.freeCashFlows)")
```

### Terminal Value Methods

**Perpetual Growth Method** (Gordon Growth Model):

```swift
TerminalValue {
    PerpetualGrowth(rate: 0.03)  // 3% perpetual growth
}
// TV = FCF_final * (1 + g) / (WACC - g)
```

**Exit Multiple Method**:

```swift
TerminalValue {
    ExitMultiple(evEbitda: 10.0)  // 10x EV/EBITDA multiple
}
// TV = Final EBITDA * Multiple
```

### WACC (Weighted Average Cost of Capital)

**Standard WACC Calculation**:

```swift
WACC {
    CostOfEquity(0.12)      // 12% required return on equity
    CostOfDebt(0.05)        // 5% interest rate on debt
    TaxRate(0.21)           // 21% corporate tax rate
    DebtToEquity(0.30)      // 30% debt / 70% equity split
}
// WACC = E/(D+E) * Re + D/(D+E) * Rd * (1-T)
// WACC = 0.70 * 0.12 + 0.30 * 0.05 * 0.79 = 9.59%
```

**Using After-Tax Cost of Debt**:

```swift
WACC {
    CostOfEquity(0.12)
    AfterTaxCostOfDebt(0.04)  // Already accounts for tax shield
    DebtToEquity(0.40)
}
```

**Custom WACC Rate**:

```swift
WACC {
    CustomRate(0.10)  // Directly specify 10% WACC
}
```

### Complete DCF with Exit Multiple

```swift
let dcf = DCFModel {
    Forecast(5) {
        ForecastRevenue(base: 1_000_000, cagr: 0.15)
        EBITDA(margin: 0.25)
        CapEx(percentage: 0.08)
    }

    TerminalValue {
        ExitMultiple(evEbitda: 10.0)  // Exit at 10x EBITDA
    }

    WACC {
        CustomRate(0.10)  // 10% discount rate
    }
}

let result = dcf.calculateEnterpriseValue()
print("Enterprise Value: $\(result.enterpriseValue)")
print("Terminal Value: $\(result.terminalValue)")
print("Terminal Multiple: \(result.terminalValueMultiple)x")
```

### Sensitivity Analysis on Valuation

Test how valuation changes with different discount rates:

```swift
let waccRates = [0.08, 0.10, 0.12, 0.14]
let valuations = waccRates.map { rate in
    let dcf = DCFModel {
        Forecast(5) {
            ForecastRevenue(base: 1_000_000, cagr: 0.15)
            EBITDA(margin: 0.25)
            CapEx(percentage: 0.08)
        }

        TerminalValue {
            PerpetualGrowth(rate: 0.03)
        }

        WACC {
            CustomRate(rate)
        }
    }
    return (rate, dcf.calculateEnterpriseValue().enterpriseValue)
}

for (rate, value) in valuations {
    print("WACC \(rate * 100)%: $\(Int(value))")
}
// WACC 8.0%: Higher valuation
// WACC 10.0%: Mid valuation
// WACC 12.0%: Lower valuation
// WACC 14.0%: Lowest valuation
```

### Integration with Existing CashFlowModel

Use projected cash flows from existing models:

```swift
// Create cash flow projection
let projection = CashFlowModel(
    revenue: Revenue {
        Base(1_000_000)
        GrowthRate(0.15)
    },
    expenses: Expenses {
        Variable(percentage: 0.60)
    },
    taxes: Taxes {
        CorporateRate(0.21)
    }
)

// Use in DCF valuation
let dcf = DCFModel {
    FromCashFlowModel(projection, years: 5)

    TerminalValue {
        PerpetualGrowth(rate: 0.03)
    }

    WACC {
        CustomRate(0.10)
    }
}

let valuation = dcf.calculateEnterpriseValue()
```

### Valuation Result Metrics

The `ValuationResult` provides detailed breakdown:

```swift
let result = dcf.calculateEnterpriseValue()

print("Enterprise Value: $\(result.enterpriseValue)")
print("PV of Forecast FCFs: $\(result.presentValueOfFCF)")
print("PV of Terminal Value: $\(result.presentValueOfTerminalValue)")
print("Terminal Value (undiscounted): $\(result.terminalValue)")
print("Forecast Period: \(result.forecastYears) years")
print("Discount Rate (WACC): \(result.wacc * 100)%")
print("Free Cash Flows: \(result.freeCashFlows)")
```

## Advanced Usage

### Multi-Year Batch Calculations

```swift
let results = projection.calculateYears(1...10)
let totalRevenue = results.reduce(0) { $0 + $1.revenue }
let totalNetIncome = results.reduce(0) { $0 + $1.netIncome }
```

### Custom Analysis

```swift
let projection = CashFlowModel(/* ... */)

// Calculate IRR on cash flows
let cashFlows = (1...5).map { projection.freeCashFlow(year: $0) }

// Find break-even year
let breakEvenYear = (1...10).first { year in
    projection.calculate(year: year).netIncome > 0
}

// Calculate cumulative metrics
var cumulativeRevenue = 0.0
for year in 1...5 {
    cumulativeRevenue += projection.calculate(year: year).revenue
}
```

## Testing

The module includes comprehensive tests demonstrating usage:

```swift
import Testing
@testable import BusinessMathDSL

@Test("Complete cash flow model")
func testModel() async throws {
    let projection = CashFlowModel(
        revenue: Revenue {
            Base(1_000_000)
            GrowthRate(0.15)
        },
        expenses: Expenses {
            Fixed(100_000)
            Variable(percentage: 0.40)
        },
        taxes: Taxes {
            CorporateRate(0.21)
        }
    )

    let year1 = projection.calculate(year: 1)
    #expect(year1.revenue == 1_000_000)
    #expect(abs(year1.netIncome - expected) < 0.01)
}
```

## License

Part of the BusinessMath package. See LICENSE for details.

## Contributing

Contributions welcome! Please follow TDD guidelines (see CONTRIBUTING.md).

## Future Enhancements

Planned features (see roadmap):
- Valuation model builder (DCF, multiples)
- Options pricing builder
- Portfolio optimization builder
