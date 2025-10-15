# ``BusinessMath``

A comprehensive Swift library for business mathematics, time series analysis, and financial modeling.

## Overview

BusinessMath provides a complete toolkit for business and financial calculations in Swift. Built with modern Swift features including generics, strict concurrency, and the Swift Testing framework, it offers production-ready implementations of time series analysis, time value of money calculations, growth modeling, and seasonal decomposition.

The library is designed for:
- **Financial Analysts** building valuation models and cash flow forecasts
- **Business Planners** analyzing revenue trends and growth projections
- **Data Scientists** performing time series analysis and forecasting
- **Software Engineers** integrating financial calculations into applications
- **Students** learning business mathematics and financial modeling

### Key Features

- **Temporal Structures**: Comprehensive period types (daily, monthly, quarterly, annual) with arithmetic operations
- **Time Series**: Generic container for temporal data with operations, analytics, and transformations
- **Time Value of Money**: Complete TVM functions including PV, FV, PMT, NPV, IRR, XIRR, and XNPV
- **Growth Models**: CAGR calculations, trend fitting (linear, exponential, logistic), and forecasting
- **Seasonal Analysis**: Seasonal decomposition, adjustment, and pattern application
- **Fiscal Calendars**: Support for custom fiscal year-ends (Apple, Australia, UK, etc.)

### Design Principles

- **Type Safety**: Leverages Swift's type system with generics and protocol conformance
- **Precision**: Uses actual calendar calculations (365.25 days/year) for financial accuracy
- **Concurrency**: Full Swift 6 compliance with Sendable conformance throughout
- **Documentation**: Comprehensive DocC documentation with formulas and real-world examples
- **Testing**: Over 500 tests covering edge cases, real-world scenarios, and integration workflows

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:TimeSeries>
- <doc:TimeValueOfMoney>
- <doc:GrowthModeling>

### Tutorials

- <doc:BuildingRevenueModel>
- <doc:LoanAmortization>
- <doc:InvestmentAnalysis>

### Core Temporal Structures

- ``Period``
- ``PeriodType``
- ``FiscalCalendar``

### Time Series

- ``TimeSeries``
- ``TimeSeriesMetadata``

### Time Value of Money

- ``presentValue(futureValue:rate:periods:)``
- ``futureValue(presentValue:rate:periods:)``
- ``presentValueAnnuity(payment:rate:periods:type:)``
- ``futureValueAnnuity(payment:rate:periods:type:)``
- ``payment(presentValue:rate:periods:futureValue:type:)``
- ``npv(discountRate:cashFlows:)``
- ``irr(cashFlows:guess:tolerance:maxIterations:)``
- ``xnpv(rate:dates:cashFlows:)``
- ``xirr(dates:cashFlows:guess:tolerance:maxIterations:)``

### Growth and Forecasting

- ``growthRate(from:to:)``
- ``cagr(beginningValue:endingValue:years:)``
- ``TrendModel``
- ``LinearTrend``
- ``ExponentialTrend``
- ``LogisticTrend``

### Seasonality

- ``seasonalIndices(timeSeries:periodsPerYear:)``
- ``seasonallyAdjust(timeSeries:indices:)``
- ``decomposeTimeSeries(timeSeries:periodsPerYear:method:)``
- ``TimeSeriesDecomposition``

### Supporting Types

- ``AnnuityType``
- ``CompoundingFrequency``
- ``DecompositionMethod``
- ``AggregationMethod``

## See Also

- [GitHub Repository](https://github.com/yourusername/BusinessMath)
- [API Reference](https://yourusername.github.io/BusinessMath/documentation/businessmath/)
