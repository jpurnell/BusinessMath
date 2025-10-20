# Time Series Analysis

Work with temporal data using periods and time series containers.

## Overview

Time series are fundamental to business analysis, representing data indexed by time periods. BusinessMath provides comprehensive support for creating, manipulating, and analyzing time series data through two core components:

- **Periods**: Type-safe temporal identifiers (daily, monthly, quarterly, annual)
- **Time Series**: Generic containers associating values with periods

## Periods

Periods represent discrete time intervals in your data. They provide a strongly-typed way to work with temporal data at different granularities.

### Creating Periods

```swift
// Monthly periods
let jan2025 = Period.month(year: 2025, month: 1)
let feb2025 = Period.month(year: 2025, month: 2)

// Quarterly periods
let q1_2025 = Period.quarter(year: 2025, quarter: 1)
let q2_2025 = Period.quarter(year: 2025, quarter: 2)

// Annual periods
let fy2025 = Period.year(2025)
let fy2026 = Period.year(2026)

// Daily periods
let today = Period.day(Date())
let tomorrow = Period.day(Date().addingTimeInterval(86400))
```

### Period Properties

```swift
let period = Period.month(year: 2025, month: 3)

// Get dates
let start = period.startDate  // March 1, 2025 00:00:00
let end = period.endDate      // March 31, 2025 23:59:59

// Get label
let label = period.label      // "2025-03"

// Custom formatting
let formatter = DateFormatter()
formatter.dateFormat = "MMMM yyyy"
let formatted = period.formatted(using: formatter)  // "March 2025"
```

### Period Arithmetic

Periods support arithmetic operations for moving through time:

```swift
let jan = Period.month(year: 2025, month: 1)

// Addition
let feb = jan + 1     // February 2025
let mar = jan + 2     // March 2025

// Subtraction
let dec = jan - 1     // December 2024

// Distance
let months = jan.distance(to: mar)  // 2

// Ranges
let q1 = jan...(jan + 2)  // [Jan, Feb, Mar]
for month in q1 {
    print(month.label)
}
```

### Period Subdivision

Larger periods can be subdivided into smaller periods:

```swift
// Year to quarters
let year = Period.year(2025)
let quarters = year.quarters()  // [Q1 2025, Q2 2025, Q3 2025, Q4 2025]

// Year to months
let months = year.months()  // [Jan 2025, Feb 2025, ..., Dec 2025]

// Quarter to months
let q1 = Period.quarter(year: 2025, quarter: 1)
let q1Months = q1.months()  // [Jan 2025, Feb 2025, Mar 2025]

// Month to days (leap year aware)
let march = Period.month(year: 2025, month: 3)
let days = march.days()  // [Mar 1, Mar 2, ..., Mar 31]
```

### Period Comparison

Periods are comparable using type-first ordering:

```swift
let daily = Period.day(Date())
let monthly = Period.month(year: 2025, month: 1)
let quarterly = Period.quarter(year: 2025, quarter: 1)
let annual = Period.year(2025)

// Type-first comparison: daily < monthly < quarterly < annual
daily < monthly      // true
monthly < quarterly  // true
quarterly < annual   // true

// Within same type, chronological order
Period.month(year: 2025, month: 1) < Period.month(year: 2025, month: 2)  // true
Period.year(2024) < Period.year(2025)  // true
```

## Time Series

A time series associates values with periods, enabling temporal data analysis.

### Creating Time Series

```swift
// From parallel arrays
let periods = [
    Period.month(year: 2025, month: 1),
    Period.month(year: 2025, month: 2),
    Period.month(year: 2025, month: 3)
]
let values: [Double] = [100_000, 120_000, 115_000]

let ts = TimeSeries(periods: periods, values: values)

// From dictionary
let data: [Period: Double] = [
    Period.month(year: 2025, month: 1): 100_000,
    Period.month(year: 2025, month: 2): 120_000,
    Period.month(year: 2025, month: 3): 115_000
]
let ts2 = TimeSeries(data: data)

// With metadata
let metadata = TimeSeriesMetadata(
    name: "Monthly Revenue",
    description: "Revenue by month for FY2025",
    unit: "USD"
)
let ts3 = TimeSeries(periods: periods, values: values, metadata: metadata)
```

### Accessing Values

```swift
let ts = TimeSeries(periods: periods, values: values)

// Subscript access (returns Optional)
if let janRevenue = ts[Period.month(year: 2025, month: 1)] {
    print("January: $\(janRevenue)")
}

// Subscript with default value
let febRevenue = ts[Period.month(year: 2025, month: 2), default: 0.0]

// Access all values as array
let allValues = ts.valuesArray  // [100_000, 120_000, 115_000]

// First and last values
let first = ts.first  // Optional(100_000)
let last = ts.last    // Optional(115_000)

// Count and isEmpty
let count = ts.count      // 3
let empty = ts.isEmpty    // false
```

### Iteration

Time series conform to `Sequence`, enabling iteration:

```swift
// Iterate over values
for value in ts {
    print(value)
}

// Use standard Sequence operations
let total = ts.reduce(0.0, +)           // Sum all values
let doubled = ts.map { $0 * 2.0 }       // Double all values
let positive = ts.filter { $0 > 0 }     // Keep positive values
let max = ts.max()                       // Find maximum value
```

### Range Extraction

Extract subsets of time series:

```swift
let ts = TimeSeries(
    periods: (1...12).map { Period.month(year: 2025, month: $0) },
    values: [100, 105, 110, 108, 115, 120, 118, 125, 130, 128, 135, 140]
)

// Extract Q1 (Jan-Mar)
let q1Start = Period.month(year: 2025, month: 1)
let q1End = Period.month(year: 2025, month: 3)
let q1 = ts.range(from: q1Start, to: q1End)
// Result: TimeSeries with 3 periods [Jan, Feb, Mar]

// Extract H1 (Jan-Jun)
let h1 = ts.range(
    from: Period.month(year: 2025, month: 1),
    to: Period.month(year: 2025, month: 6)
)
// Result: TimeSeries with 6 periods
```

## Time Series Operations

Transform and combine time series with operations.

### Transformations

```swift
let revenue = TimeSeries(periods: periods, values: [100, 120, 115])

// Map values
let revenueInK = revenue.mapValues { $0 / 1000.0 }
// Result: [100, 120, 115]

// Filter values
let highRevenue = revenue.filterValues { $0 > 110 }
// Result: TimeSeries with Feb and Mar only

// Zip two time series
let costs = TimeSeries(periods: periods, values: [60, 70, 65])
let profit = revenue.zip(with: costs) { revenue, cost in revenue - cost }
// Result: [40, 50, 50]
```

### Filling Missing Data

```swift
// Create time series with gaps
let sparsePeriods = [
    Period.month(year: 2025, month: 1),
    Period.month(year: 2025, month: 3),  // Missing February
    Period.month(year: 2025, month: 5)   // Missing April
]
let sparseValues = [100.0, 120.0, 140.0]
let sparse = TimeSeries(periods: sparsePeriods, values: sparseValues)

// Define complete range
let allMonths = Array(Period.month(year: 2025, month: 1)...Period.month(year: 2025, month: 5))

// Forward fill
let forwardFilled = sparse.fillForward(over: allMonths)
// Result: [100, 100, 120, 120, 140] (carries forward)

// Backward fill
let backwardFilled = sparse.fillBackward(over: allMonths)
// Result: [100, 120, 120, 140, 140] (carries backward)

// Fill with constant
let constantFilled = sparse.fillMissing(with: 0.0, over: allMonths)
// Result: [100, 0, 120, 0, 140]

// Linear interpolation
let interpolated = sparse.interpolate(over: allMonths)
// Result: [100, 110, 120, 130, 140] (linear between points)
```

### Aggregation

Convert time series to coarser granularity:

```swift
// Monthly to quarterly
let monthly = TimeSeries(
    periods: (1...12).map { Period.month(year: 2025, month: $0) },
    values: [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
)

let quarterly = monthly.aggregate(to: .quarterly, method: .sum)
// Q1: 33 (10+11+12), Q2: 42 (13+14+15), Q3: 51, Q4: 60

// Quarterly to annual
let annual = quarterly.aggregate(to: .annual, method: .sum)
// 2025: 186 (sum of all quarters)

// Other aggregation methods
let avgQuarterly = monthly.aggregate(to: .quarterly, method: .average)
let maxQuarterly = monthly.aggregate(to: .quarterly, method: .max)
let minQuarterly = monthly.aggregate(to: .quarterly, method: .min)
let firstQuarterly = monthly.aggregate(to: .quarterly, method: .first)
let lastQuarterly = monthly.aggregate(to: .quarterly, method: .last)
```

## Time Series Analytics

Analyze trends, growth, and patterns in time series data.

### Growth Rates

```swift
let ts = TimeSeries(
    periods: (1...5).map { Period.year(2020 + $0) },
    values: [100, 110, 121, 133, 146]
)

// Period-over-period growth
let growth = ts.growthRate(lag: 1)
// Result: [10%, 10%, 9.9%, 9.8%] (year-over-year)

// CAGR over entire period (automatically calculates years from dates)
let compoundGrowth = ts.cagr(
    from: Period.year(2021),
    to: Period.year(2025)
)
// Result: ~10% CAGR

// Percent change
let pctChange = ts.percentChange(lag: 1)
// Same as growth rate in decimal form
```

### Moving Averages

```swift
let daily = TimeSeries(
    periods: (0..<10).map { Period.day(Date().addingTimeInterval(Double($0) * 86400)) },
    values: [100, 105, 98, 102, 108, 104, 110, 106, 112, 115]
)

// Simple moving average (3-day)
let sma = daily.movingAverage(window: 3)
// Smooths out daily fluctuations

// Exponential moving average
let ema = daily.exponentialMovingAverage(alpha: 0.3)
// Gives more weight to recent values
```

### Cumulative Operations

```swift
let monthly = TimeSeries(
    periods: (1...12).map { Period.month(year: 2025, month: $0) },
    values: [10, 12, 11, 13, 15, 14, 16, 18, 17, 19, 21, 20]
)

// Year-to-date cumulative
let ytd = monthly.cumulative()
// Result: [10, 22, 33, 46, 61, 75, 91, 109, 126, 145, 166, 186]

// Rolling sums (quarterly)
let rolling = monthly.rollingSum(window: 3)
// Result: [-, -, 33, 36, 39, 42, 45, 48, 51, 54, 57, 60]
```

### Differences

```swift
let ts = TimeSeries(
    periods: periods,
    values: [100, 120, 115, 130]
)

// First difference (change from previous period)
let diff = ts.diff(lag: 1)
// Result: [20, -5, 15]

// Second difference (change in change)
let diff2 = diff.diff(lag: 1)
// Result: [-25, 20]
```

## Fiscal Calendars

Work with fiscal years that don't align with calendar years.

### Creating Fiscal Calendars

```swift
// Standard calendar year (Dec 31)
let standard = FiscalCalendar.standard

// Apple's fiscal year (Sep 30)
let apple = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))

// Australian government (Jun 30)
let australia = FiscalCalendar(yearEnd: MonthDay(month: 6, day: 30))

// UK government (Mar 31)
let uk = FiscalCalendar(yearEnd: MonthDay(month: 3, day: 31))
```

### Fiscal Period Mapping

```swift
let calendar = FiscalCalendar(yearEnd: MonthDay(month: 9, day: 30))  // Apple FY

let date = Date()  // e.g., November 15, 2024

// Get fiscal year
let fiscalYear = calendar.fiscalYear(for: date)
// Result: 2025 (FY2025 runs Oct 2024 - Sep 2025)

// Get fiscal quarter
let fiscalQuarter = calendar.fiscalQuarter(for: date)
// Result: 1 (Q1 is Oct-Dec)

// Get fiscal month
let fiscalMonth = calendar.fiscalMonth(for: date)
// Result: 2 (November is 2nd month of fiscal year)

// Map Period to fiscal period
let period = Period.month(year: 2024, month: 11)
let fiscalPeriod = calendar.periodInFiscalYear(period)
// Result: 2
```

## Best Practices

### Choose the Right Period Granularity

- **Daily**: Operational metrics, production data, sensor readings
- **Monthly**: Financial reporting, revenue analysis, most business metrics
- **Quarterly**: Executive reporting, earnings analysis, seasonal patterns
- **Annual**: Strategic planning, multi-year trends, fiscal year summaries

### Handle Missing Data Appropriately

- **Forward fill**: Use for status-like data (price levels, inventory counts)
- **Backward fill**: Use when future values apply to past (policy changes)
- **Interpolation**: Use for continuous metrics (temperature, demand curves)
- **Constant fill**: Use when absence means zero (sales in closed stores)

### Metadata is Your Friend

Always include descriptive metadata for clarity:

```swift
let metadata = TimeSeriesMetadata(
    name: "Monthly Recurring Revenue",
    description: "MRR by month including new, expansion, and contraction",
    unit: "USD"
)
let mrr = TimeSeries(periods: periods, values: values, metadata: metadata)
```

### Use Type Safety

Leverage Swift's type system to prevent errors:

```swift
// Good: Type prevents mixing incompatible periods
let monthly = TimeSeries<Double>(...)  // Monthly periods
let quarterly = TimeSeries<Double>(...)  // Quarterly periods

// Comparison at compile time ensures same period types
// Mixing period types in operations will fail safely
```

## See Also

- <doc:GettingStarted>
- <doc:TimeValueOfMoney>
- <doc:GrowthModeling>
- ``Period``
- ``TimeSeries``
- ``FiscalCalendar``
