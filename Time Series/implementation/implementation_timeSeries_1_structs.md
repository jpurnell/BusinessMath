TIME SERIES IMPLEMENTATION PLAN

  Phase 1: Core Temporal Structures

  1.1 PeriodType Enum (Sources/BusinessMath/Time Series/PeriodType.swift)

  public enum PeriodType: String, Codable, Comparable {
      case daily
      case weekly
      case monthly
      case quarterly
      case annual

      // Conversion factors, ordering, etc.
  }

  Design Decisions:
  - Make it Comparable to support period type comparisons
  - Include computed properties: daysApproximate, monthsEquivalent
  - Method to convert between period types

  1.2 Period Struct (Sources/BusinessMath/Time Series/Period.swift)

  public struct Period: Hashable, Comparable, Codable {
      public let type: PeriodType
      public let date: Date

      // Factory methods: Period.month(year: 2025, month: 1)
      // Computed properties: startDate, endDate, label, index
  }

  Design Decisions:
  - Value type (struct) for immutability
  - Hashable for use in dictionaries
  - Comparable for sorting and ranges
  - Date-based internally for precision
  - Factory methods for ergonomic creation
  - Support for period ranges: Period.year(2025).quarters() → [Q1, Q2, Q3, Q4]

  1.3 Period Arithmetic (Sources/BusinessMath/Time Series/PeriodArithmetic.swift)

  // Extensions on Period to support:
  period + 3  // Add 3 periods
  period - 1  // Subtract 1 period
  period1...period10  // Range of periods
  period1.distance(to: period2)  // Number of periods between

  Design Decisions:
  - Operator overloading for intuitive API
  - Support for stride/range operations
  - Respect fiscal calendar boundaries

  1.4 FiscalCalendar Struct (Sources/BusinessMath/Time Series/FiscalCalendar.swift)

  public struct FiscalCalendar {
      public let yearEnd: MonthDay  // e.g., December 31, or June 30

      func fiscalYear(for date: Date) -> Int
      func fiscalQuarter(for date: Date) -> Int
      func periodInFiscalYear(_ period: Period) -> Int
  }

  Design Decisions:
  - Default to calendar year (Dec 31)
  - Immutable configuration
  - Methods to map calendar dates to fiscal periods

  ---
