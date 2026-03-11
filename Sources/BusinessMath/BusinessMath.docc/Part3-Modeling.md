# Part III: Modeling

Build comprehensive financial models from revenue forecasts to complex valuations.

## Overview

Part III is the heart of BusinessMath—where you transform data and analysis into forward-looking financial models. This is where finance professionals spend most of their time: forecasting revenue, projecting cash flows, valuing companies and securities, and evaluating investment opportunities.

This part covers everything from simple trend-based forecasts to sophisticated discounted cash flow models, from loan amortization schedules to options-based real assets valuation. Whether you're modeling a startup's revenue growth, valuing a bond portfolio, or analyzing complex capital structures, you'll find the tools and patterns you need here.

Financial modeling is both art and science. The science is in the mathematical rigor and industry-standard methodologies. The art is in making thoughtful assumptions, structuring models clearly, and communicating results effectively. Part III teaches you both.

## What You'll Learn

- **Growth & Forecasting**: Trend analysis, seasonal patterns, and revenue projections
- **Financial Statement Modeling**: Income statements, balance sheets, and cash flow statements
- **Valuation Techniques**: DCF, DDM, bond pricing, credit derivatives, and real options
- **Investment Analysis**: NPV, IRR, payback periods, and profitability metrics
- **Capital Structure**: Equity financing, debt analysis, and WACC calculations

## Chapters in This Part

### General Modeling
- <doc:3.1-GrowthModeling>
- <doc:3.2-ForecastingGuide>

### Financial Modeling & Reporting
- <doc:3.3-BuildingRevenueModel>
- <doc:3.4-BuildingFinancialReports>
- <doc:3.5-FinancialStatementsGuide>
- <doc:3.6-LeaseAccountingGuide>
- <doc:3.7-LoanAmortization>

### Valuation & Investment Analysis
- <doc:3.8-InvestmentAnalysis>
- <doc:3.9-EquityValuationGuide>
- <doc:3.10-BondValuationGuide>
- <doc:3.11-CreditDerivativesGuide>
- <doc:3.12-RealOptionsGuide>

### Capital Structure
- <doc:3.13-EquityFinancingGuide>
- <doc:3.14-DebtAndFinancingGuide>

## Prerequisites

Before tackling financial modeling, ensure you're comfortable with time series operations, time value of money calculations, and basic analytical techniques from Part II. For valuation topics (chapters 3.8-3.12), you should also understand financial ratios and risk measurement.

## Suggested Reading Order

The reading path depends on your goals:

**For Operations/FP&A Professionals:**
1. <doc:3.1-GrowthModeling>
2. <doc:3.2-ForecastingGuide>
3. <doc:3.3-BuildingRevenueModel>
4. <doc:3.4-BuildingFinancialReports>
5. <doc:3.5-FinancialStatementsGuide>

**For Investment Analysts:**
1. <doc:3.8-InvestmentAnalysis>
2. <doc:3.9-EquityValuationGuide>
3. <doc:3.10-BondValuationGuide>
4. <doc:3.1-GrowthModeling>
5. <doc:3.12-RealOptionsGuide>

**For Corporate Finance:**
1. <doc:3.13-EquityFinancingGuide>
2. <doc:3.14-DebtAndFinancingGuide>
3. <doc:3.7-LoanAmortization>
4. <doc:3.6-LeaseAccountingGuide>
5. <doc:3.5-FinancialStatementsGuide>

**For Quantitative Finance:**
1. <doc:3.10-BondValuationGuide>
2. <doc:3.11-CreditDerivativesGuide>
3. <doc:3.12-RealOptionsGuide>
4. <doc:3.9-EquityValuationGuide>
5. <doc:3.2-ForecastingGuide>

## Key Concepts

### Revenue Forecasting

The foundation of most financial models is a revenue forecast:

```swift
let quarters = Period.year(2025).quarters()
let model = FinancialModel {
    Revenue {
        Product("SaaS Subscriptions")
            .price(99)
            .customers(1000)
    }
}

let revenue = model.totalRevenue(for: quarters[0])
```

### Valuation Methodologies

BusinessMath implements industry-standard valuation approaches:

**Discounted Cash Flow (DCF):**
```swift
let freeCashFlows = [10_000.0, 12_000.0, 14_000.0, 16_000.0, 18_000.0]
let terminalValue = 18_000 * (1 + 0.025) / (0.09 - 0.025)  // Gordon growth
let allCashFlows = freeCashFlows + [terminalValue]
let valuation = npv(discountRate: 0.09, cashFlows: allCashFlows)
```

**Dividend Discount Model (DDM):**
```swift
let equity = GordonGrowthModel(
    dividendPerShare: 2.50,
    growthRate: 0.05,
    requiredReturn: 0.10
)
let value = equity.valuePerShare()
```

**Bond Pricing:**
```swift
let bond = Bond(
    faceValue: 1000,
    couponRate: 0.05,
    maturityDate: Calendar.current.date(byAdding: .year, value: 10, to: Date())!,
    paymentFrequency: .semiAnnual,
    issueDate: Date()
)
let price = bond.price(yield: 0.045)
```

### Financial Statement Integration

Connect revenue models to complete financial statements:

```swift
let quarters = Period.year(2025).quarters()
let model = FinancialModel {
    Revenue {
        Product("SaaS Subscriptions")
            .price(99)
            .customers(1000)
    }

    Costs {
        Fixed("Salaries", 50_000)
        Variable("Server Costs", 0.20)
    }
}

let revenue = model.totalRevenue(for: quarters[0])
let expenses = model.totalExpenses(for: quarters[0])
let profit = model.profit(for: quarters[0])
```

## Real-World Applications

### Startup Financial Modeling
Build three-statement models for early-stage companies. Project revenue growth, model burn rates, and calculate funding requirements. Integrate customer acquisition costs and lifetime value.

### M&A Valuation
Value acquisition targets using multiple methods (DCF, comparables, precedent transactions). Model synergies, calculate accretion/dilution, and structure deal terms.

### Portfolio Management
Value fixed income portfolios with duration and convexity analysis. Model credit risk with CDS pricing. Evaluate equity positions with fundamental valuation.

### Corporate Planning
Create integrated financial models for strategic planning. Model different growth scenarios, evaluate capital allocation decisions, and assess financing alternatives.

## Model Building Best Practices

1. **Start Simple**: Begin with a minimal viable model, then add complexity incrementally
2. **Separate Assumptions**: Keep inputs/assumptions in separate, clearly labeled sections
3. **Validate at Each Step**: Test intermediate calculations before building further
4. **Use Sensitivity Analysis**: Understand which assumptions drive your results (<doc:2.1-DataTableAnalysis>)
5. **Document Reasoning**: Comment why you made specific modeling choices
6. **Version Control**: Use git to track model evolution and assumptions over time

## Next Steps

After mastering financial modeling:

- **Add Uncertainty** (<doc:Part4-Simulation>): Model risk and uncertainty with Monte Carlo simulation
- **Optimize Decisions** (<doc:Part5-Optimization>): Find optimal strategies using mathematical optimization
- **Analyze Scenarios** (<doc:4.2-ScenarioAnalysisGuide>): Structured scenario planning and stress testing

## Common Questions

**How accurate should my forecasts be?**

All forecasts are wrong—the goal is to be approximately right rather than precisely wrong. Focus on getting the key drivers and general magnitude correct. Use sensitivity analysis to understand the range of outcomes.

**Should I model to the penny?**

No. False precision suggests false certainty. Round to appropriate significance (thousands or millions for most business models). Precision to the dollar is rarely meaningful when you're forecasting years ahead.

**How many scenarios should I model?**

Start with three: base case, upside, and downside. This captures the range of reasonable outcomes without overwhelming stakeholders. For detailed risk analysis, use Monte Carlo simulation (<doc:Part4-Simulation>) instead.

**When should I use DCF vs. multiples vs. other methods?**

Use multiple methods and triangulate. DCF is powerful but assumption-heavy. Comparables provide market context. Each method has strengths and weaknesses—the best answer comes from synthesizing multiple approaches.

## Related Topics

- <doc:Part2-Analysis>
- <doc:Part4-Simulation>
- <doc:Part5-Optimization>
- <doc:2.1-DataTableAnalysis>
