Phase 2: Time Series Container

  2.1 TimeSeries Struct (Sources/BusinessMath/Time Series/TimeSeries.swift)

  public struct TimeSeries<T: Real> {
      public let periods: [Period]
      private let values: [Period: T]
      public let metadata: TimeSeriesMetadata

      // Subscript access: timeSeries[period]
      // Array-style: timeSeries.valuesArray
      // Filtering: timeSeries.range(from:to:)
  }

  public struct TimeSeriesMetadata {
      public let name: String
      public let units: String?
      public let category: String?
  }

  Design Decisions:
  - Generic over Real for flexibility (Double, Float, etc.)
  - Dictionary storage for O(1) lookup
  - Sorted periods array for ordered iteration
  - Metadata for reporting and debugging
  - Support for missing values (return nil or default?)

  2.2 Time Series Operations (Sources/BusinessMath/Time Series/TimeSeriesOperations.swift)

  // Functional operations:
  timeSeries.map { $0 * 1.1 }  // Apply transformation
  timeSeries1.zip(timeSeries2) { $0 + $1 }  // Combine two series
  timeSeries.fillForward()  // Forward-fill missing values
  timeSeries.aggregate(by: .quarterly, method: .sum)  // Roll up to quarters

  Design Decisions:
  - Immutable operations (return new TimeSeries)
  - Period alignment must match for binary operations
  - Aggregation methods: sum, average, first, last, end-of-period
  - Missing value strategies: forward-fill, backward-fill, interpolate, zero

  2.3 Time Series Analytics (Sources/BusinessMath/Time Series/TimeSeriesAnalytics.swift)

  // Growth calculations:
  timeSeries.growthRate(lag: 1)  // Period-over-period
  timeSeries.growthRate(lag: 4)  // Year-over-year (if quarterly)
  timeSeries.cagr(from:to:)  // Compound annual growth rate
  timeSeries.movingAverage(window: 3)  // 3-period moving average
  timeSeries.seasonalIndices(periodsPerYear: 12)  // For monthly data

  Design Decisions:
  - Return new TimeSeries for transformations
  - Leverage existing statistics functions (mean, stdDev)
  - Handle edge cases (insufficient data, division by zero)

  ---
