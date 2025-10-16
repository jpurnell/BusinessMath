 Phase 4: Growth & Trend Models

  4.1 Growth Calculations (Sources/BusinessMath/Time Series/Growth/GrowthRate.swift)

  /// Simple growth rate between two values
  public func growthRate<T: Real>(from: T, to: T) -> T

  /// Compound Annual Growth Rate
  public func cagr<T: Real>(
      beginningValue: T,
      endingValue: T,
      years: T
  ) -> T

  /// Apply growth rate forward
  public func applyGrowth<T: Real>(
      baseValue: T,
      rate: T,
      periods: Int,
      compounding: CompoundingFrequency = .annual
  ) -> [T]

  public enum CompoundingFrequency {
      case annual, semiannual, quarterly, monthly, daily, continuous
  }

  4.2 Trend Models (Sources/BusinessMath/Time Series/Growth/TrendModel.swift)

  public protocol TrendModel {
      associatedtype T: Real

      func project(periods: Int) -> TimeSeries<T>
      func fit(to series: TimeSeries<T>)
  }

  public struct LinearTrend<T: Real>: TrendModel {
      // Uses existing linear regression
  }

  public struct ExponentialTrend<T: Real>: TrendModel {
      // Log-linear regression
  }

  public struct LogisticTrend<T: Real>: TrendModel {
      // S-curve growth (for market saturation)
  }

  Design Decisions:
  - Protocol-based for extensibility
  - Leverage existing regression functions
  - Return TimeSeries for easy composition
  - Support custom trend functions via closure

  4.3 Seasonality (Sources/BusinessMath/Time Series/Growth/Seasonality.swift)

  /// Calculate seasonal indices from historical data
  public func seasonalIndices<T: Real>(
      _ series: TimeSeries<T>,
      periodsPerYear: Int
  ) -> [T]

  /// Apply seasonal adjustment
  public func seasonallyAdjust<T: Real>(
      _ series: TimeSeries<T>,
      indices: [T]
  ) -> TimeSeries<T>

  /// Decompose series into trend + seasonal + residual
  public func decomposeTimeSeries<T: Real>(
      _ series: TimeSeries<T>,
      periodsPerYear: Int,
      method: DecompositionMethod = .additive
  ) -> TimeSeriesDecomposition<T>

  public enum DecompositionMethod {
      case additive      // Y = T + S + E
      case multiplicative // Y = T × S × E
  }

  public struct TimeSeriesDecomposition<T: Real> {
      public let trend: TimeSeries<T>
      public let seasonal: TimeSeries<T>
      public let residual: TimeSeries<T>
  }

  ---
