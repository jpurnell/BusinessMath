# Part I: Basics & Foundations

Master the core concepts and tools that form the foundation of BusinessMath.

## Overview

Part I introduces you to the essential building blocks of the BusinessMath library. Whether you're new to financial modeling or an experienced developer, this section provides the fundamental knowledge you need to work effectively with temporal data, financial calculations, and the library's API patterns.

Think of this section as your foundation—the concepts you learn here will be used throughout every other part of the documentation. We'll cover the `TimeSeries` data structure that underpins most operations, introduce the time value of money calculations that power financial analysis, and explore the fluent API patterns that make complex models readable and maintainable.

By the end of this part, you'll be comfortable creating time series, performing basic financial calculations, debugging issues, and using the library's core tools to build your own analyses.

## What You'll Learn

- **Time Series Operations**: How to create, manipulate, and analyze temporal data using the `TimeSeries<T>` structure
- **Time Value of Money**: Core financial calculations including present value, future value, NPV, IRR, and annuities
- **Fluent APIs**: SwiftUI-style declarative syntax for building readable, maintainable financial models
- **Templates & Patterns**: Reusable patterns for common financial modeling scenarios
- **Error Handling**: How to handle errors gracefully and debug issues in your models

## Chapters in This Part

### Getting Started
- <doc:1.1-GettingStarted> - Quick introduction to BusinessMath with your first calculations

### Core Data Structures
- <doc:1.2-TimeSeries> - The foundation of temporal data handling in BusinessMath

### Fundamental Financial Concepts
- <doc:1.3-TimeValueOfMoney> - Present value, future value, and the time value of money

### API Patterns & Developer Tools
- <doc:1.4-FluentAPIGuide> - Declarative APIs for building readable models
- <doc:1.5-TemplateGuide> - Pre-built patterns for common scenarios

### Troubleshooting & Development
- <doc:1.6-DebuggingGuide> - Diagnosing and fixing issues in your models
- <doc:1.7-ErrorHandlingGuide> - Handling errors gracefully in production code

## Prerequisites

No prior experience with BusinessMath is required for this section. However, you should have:

- Basic Swift programming knowledge
- Familiarity with common financial concepts (interest, growth rates, etc.)
- Understanding of basic mathematics (algebra, percentages)

If you're completely new to financial concepts, don't worry—we explain the math and finance principles as we go.

## Suggested Reading Order

We recommend reading the chapters in this part sequentially:

1. **Start with Getting Started** (<doc:1.1-GettingStarted>) to see the library in action
2. **Master TimeSeries** (<doc:1.2-TimeSeries>) to understand the core data structure
3. **Learn Time Value of Money** (<doc:1.3-TimeValueOfMoney>) for fundamental financial calculations
4. **Explore Fluent APIs** (<doc:1.4-FluentAPIGuide>) to write more readable code
5. **Review Templates** (<doc:1.5-TemplateGuide>) for reusable patterns
6. **Keep Debugging and Error Handling guides** (<doc:1.6-DebuggingGuide>, <doc:1.7-ErrorHandlingGuide>) as references

## Key Concepts

### Time Series as Foundation

The `TimeSeries<T>` structure is the heart of BusinessMath. It combines temporal data (dates/periods) with numeric values, enabling calendar-aware operations like year-over-year growth, quarterly aggregations, and date-based filtering. Nearly every financial model you build will use time series.

```swift
let quarters = Period.year(2025).quarters()
let revenue = TimeSeries(periods: quarters, values: [100, 110, 121, 133])
let growth = revenue.percentChange() // Year-over-year growth rates
```

### Time Value of Money

Money today is worth more than money tomorrow—this fundamental principle drives almost all financial analysis. Part I teaches you how to:
- Calculate present and future values
- Compare investment alternatives
- Evaluate loans and payment schedules
- Compute internal rates of return

### Fluent API Design

BusinessMath uses SwiftUI-style fluent APIs that let you chain operations together declaratively:

```swift
import BusinessMath

// Define quarters for 2025
let quarters = Period.year(2025).quarters()

// Create and configure revenue model using fluent API
let model = RevenueModel()
    .baseRevenue(100_000)
    .growthRate(0.15)
    .periods(quarters)
    .calculate()

print("Q1 2025 revenue: \(model.revenue[0].currency(0))")  // $100,000
print("Q4 2025 revenue: \(model.revenue[3].currency(0))")  // $152,088

// Simple RevenueModel implementation for playground use
struct RevenueModel {
    private var base: Double = 0
    private var growth: Double = 0
    private var periods: [Period] = []
    var revenue: [Double] = []

    func baseRevenue(_ value: Double) -> RevenueModel {
        var copy = self
        copy.base = value
        return copy
    }

    func growthRate(_ value: Double) -> RevenueModel {
        var copy = self
        copy.growth = value
        return copy
    }

    func periods(_ value: [Period]) -> RevenueModel {
        var copy = self
        copy.periods = value
        return copy
    }

    func calculate() -> RevenueModel {
        var copy = self
        copy.revenue = periods.enumerated().map { i, _ in
            base * pow(1.0 + growth, Double(i))
        }
        return copy
    }
}
```

This pattern makes complex financial models more readable and easier to maintain.

## Next Steps

After completing Part I, you're ready to:

- **Dive into Analysis** (<doc:Part2-Analysis>) to learn statistical methods and risk metrics
- **Build Financial Models** (<doc:Part3-Modeling>) to create revenue forecasts and valuations
- **Run Simulations** (<doc:Part4-Simulation>) to model uncertainty with Monte Carlo methods
- **Optimize Decisions** (<doc:Part5-Optimization>) to find optimal solutions using mathematical optimization

## Common Questions

**Do I need to read all of Part I before moving forward?**

At minimum, read chapters 1.1 (Getting Started), 1.2 (TimeSeries), and 1.3 (Time Value of Money). The other chapters can be read as needed when you encounter those patterns in your work.

**Can I skip the error handling and debugging guides?**

You can skip them initially, but we recommend bookmarking them. You'll want to refer back when you encounter issues or need to handle errors in production code.

**What if I'm already familiar with financial concepts?**

Feel free to skim or skip the financial theory explanations and focus on how those concepts map to BusinessMath APIs. The code examples will be most valuable to you.

## Related Topics

- <doc:LearningPath> - Recommended learning paths for different roles
- <doc:Part2-Analysis> - Statistical analysis and risk metrics
- <doc:Part3-Modeling> - Building financial models and forecasts
