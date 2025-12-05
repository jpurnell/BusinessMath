//
//  TimeSeriesBuilderTests.swift
//  BusinessMath
//
//  Created on December 1, 2025.
//

import Testing
import Foundation
@testable import BusinessMath

/// Comprehensive tests for the TimeSeriesBuilder fluent API
///
/// Tests cover:
/// - Basic builder syntax with arrow operators (Period => value)
/// - Projection-based construction (starting, growing, custom)
/// - Convenience constructors (constant, linear, exponential)
/// - Conditional and array-based building
/// - Integration with time series operations
/// - Edge cases and validation
@Suite("TimeSeriesBuilder DSL Tests")
struct TimeSeriesBuilderTests {

    // MARK: - Basic Builder Syntax

    @Test("TimeSeries with basic arrow syntax")
    func basicArrowSyntax() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.year(2024) => 110_000.0
            Period.year(2025) => 121_000.0
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(vals[0] == 100_000.0)
        #expect(vals[1] == 110_000.0)
        #expect(vals[2] == 121_000.0)
    }

    @Test("TimeSeries with mixed period types")
    func mixedPeriodTypes() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.quarter(year: 2024, quarter: 1) => 27_500.0
            Period.month(year: 2024, month: 2) => 9_000.0
        }

        #expect(series.count == 3)
        #expect(series.periods.count == 3)
    }

    @Test("Empty TimeSeries")
    func emptyTimeSeries() {
        let series = TimeSeries<Double> {
            // Empty
        }

        #expect(series.count == 0)
        #expect(series.isEmpty)
    }

    @Test("Single value TimeSeries")
    func singleValueTimeSeries() {
        let series = TimeSeries {
            Period.year(2024) => 1_000_000.0
        }

        #expect(series.count == 1)
        #expect(series.valuesArray[0] == 1_000_000.0)
    }

    // MARK: - Projection-Based Construction

    @Test("TimeSeries with starting value only")
    func projectionStartingOnly() {
        let series = TimeSeries(from: 2023, to: 2027) {
            starting(at: 100_000.0)
        }

        #expect(series.count == 5) // 2023-2027 inclusive
        // All values should be the same
        for value in series.valuesArray {
            #expect(value == 100_000.0)
        }
    }

    @Test("TimeSeries with growth rate")
    func projectionWithGrowth() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: 100_000.0)
            growing(by: 0.10)
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 100_000.0) < 0.01) // Year 0
        #expect(abs(vals[1] - 110_000.0) < 0.01) // Year 1: 100k * 1.1
        #expect(abs(vals[2] - 121_000.0) < 0.01) // Year 2: 100k * 1.1^2
    }

    @Test("TimeSeries with custom generator")
    func projectionCustomGenerator() {
        let series = TimeSeries(from: 2023, to: 2027) {
            custom { i in
                100_000.0 + Double(i) * 5_000.0
            }
        }

        #expect(series.count == 5)
        let vals = series.valuesArray
        #expect(vals[0] == 100_000.0)  // i=0
        #expect(vals[1] == 105_000.0)  // i=1
        #expect(vals[2] == 110_000.0)  // i=2
        #expect(vals[3] == 115_000.0)  // i=3
        #expect(vals[4] == 120_000.0)  // i=4
    }

    @Test("Custom generator takes priority over growth")
    func customGeneratorPriority() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: 100_000.0)
            growing(by: 0.10)
            custom { i in Double(i) * 1_000.0 }
        }

        // Custom generator should win
        let vals = series.valuesArray
        #expect(vals[0] == 0.0)
        #expect(vals[1] == 1_000.0)
        #expect(vals[2] == 2_000.0)
    }

    // MARK: - Convenience Constructors

    @Test("Constant time series")
    func constantTimeSeries() {
        let series = TimeSeries.constant(value: 50_000.0, from: 2023, to: 2027)

        #expect(series.count == 5)
        for value in series.valuesArray {
            #expect(value == 50_000.0)
        }
    }

    @Test("Linear growth time series")
    func linearGrowthTimeSeries() {
        let series = TimeSeries.linear(
            start: 100_000.0,
            growth: 10_000.0,
            from: 2023,
            to: 2026
        )

        #expect(series.count == 4)
        let vals = series.valuesArray
        #expect(vals[0] == 100_000.0)  // 100k + 0*10k
        #expect(vals[1] == 110_000.0)  // 100k + 1*10k
        #expect(vals[2] == 120_000.0)  // 100k + 2*10k
        #expect(vals[3] == 130_000.0)  // 100k + 3*10k
    }

    @Test("Exponential growth time series")
    func exponentialGrowthTimeSeries() {
        let series = TimeSeries.exponential(
            start: 100_000.0,
            rate: 0.10,
            from: 2023,
            to: 2025
        )

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 100_000.0) < 0.01)
        #expect(abs(vals[1] - 110_000.0) < 0.01)
        #expect(abs(vals[2] - 121_000.0) < 0.01)
    }

    @Test("Negative growth rate")
    func negativeGrowthRate() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: 100_000.0)
            growing(by: -0.10) // 10% decline per year
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 100_000.0) < 0.01)
        #expect(abs(vals[1] - 90_000.0) < 0.01)  // 100k * 0.9
        #expect(abs(vals[2] - 81_000.0) < 0.01)  // 100k * 0.9^2
    }

    @Test("Zero growth rate")
    func zeroGrowthRate() {
        let series = TimeSeries(from: 2023, to: 2026) {
            starting(at: 100_000.0)
            growing(by: 0.0)
        }

        #expect(series.count == 4)
        for value in series.valuesArray {
            #expect(abs(value - 100_000.0) < 0.01)
        }
    }

    // MARK: - Period Construction

    @Test("Monthly time series with explicit months")
    func monthlyTimeSeriesExplicit() {
        let series = TimeSeries<Double> {
            Month.january.period(year: 2024) => 10_000.0
            Month.february.period(year: 2024) => 11_000.0
            Month.march.period(year: 2024) => 12_000.0
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(vals[0] == 10_000.0)
        #expect(vals[1] == 11_000.0)
        #expect(vals[2] == 12_000.0)
    }

    @Test("Quarterly time series")
    func quarterlyTimeSeries() {
        let series = TimeSeries<Double> {
            Quarter.q1.period(year: 2024) => 300_000.0
            Quarter.q2.period(year: 2024) => 350_000.0
            Quarter.q3.period(year: 2024) => 320_000.0
            Quarter.q4.period(year: 2024) => 400_000.0
        }

        #expect(series.count == 4)
        let vals = series.valuesArray
        #expect(vals[0] == 300_000.0)
        #expect(vals[1] == 350_000.0)
        #expect(vals[2] == 320_000.0)
        #expect(vals[3] == 400_000.0)
    }

    // MARK: - Fluent Operations

    @Test("Map operation on builder-created series")
    func mapOperation() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.year(2024) => 110_000.0
            Period.year(2025) => 121_000.0
        }

        let doubled = series.map { $0 * 2 }
        let doubledArray = Array(doubled)

        #expect(doubledArray.count == 3)
        #expect(doubledArray[0] == 200_000.0)
        #expect(doubledArray[1] == 220_000.0)
        #expect(doubledArray[2] == 242_000.0)
    }

    @Test("Filter operation on builder-created series")
    func filterOperation() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.year(2024) => 150_000.0
            Period.year(2025) => 120_000.0
            Period.year(2026) => 180_000.0
        }

        let filtered = series.filter { $0 > 125_000.0 }
        let filteredArray = Array(filtered)

        #expect(filteredArray.count == 2)
        #expect(filteredArray.contains(150_000.0))
        #expect(filteredArray.contains(180_000.0))
    }

    // MARK: - Edge Cases

    @Test("Single year range")
    func singleYearRange() {
        let series = TimeSeries(from: 2024, to: 2024) {
            starting(at: 100_000.0)
            growing(by: 0.10)
        }

        #expect(series.count == 1)
        #expect(series.valuesArray[0] == 100_000.0)
    }

    @Test("Large year range")
    func largeYearRange() {
        let series = TimeSeries(from: 2020, to: 2050) {
            starting(at: 100_000.0)
            growing(by: 0.05)
        }

        #expect(series.count == 31) // 2020-2050 inclusive
        let vals = series.valuesArray
        #expect(vals[0] == 100_000.0)
        // Last value should be significantly higher due to compound growth
        #expect(vals[30] > 400_000.0)
    }

    @Test("Zero starting value")
    func zeroStartingValue() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: 0.0)
            growing(by: 0.10)
        }

        #expect(series.count == 3)
        for value in series.valuesArray {
            #expect(value == 0.0) // 0 * anything = 0
        }
    }

    @Test("Negative starting value")
    func negativeStartingValue() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: -100_000.0)
        }

        #expect(series.count == 3)
        for value in series.valuesArray {
            #expect(value == -100_000.0)
        }
    }

    @Test("Very small values")
    func verySmallValues() {
        let series = TimeSeries {
            Period.year(2023) => 0.01
            Period.year(2024) => 0.02
            Period.year(2025) => 0.03
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 0.01) < 0.0001)
        #expect(abs(vals[1] - 0.02) < 0.0001)
        #expect(abs(vals[2] - 0.03) < 0.0001)
    }

    @Test("Very large values")
    func veryLargeValues() {
        let series = TimeSeries {
            Period.year(2023) => 1_000_000_000.0 // 1 trillion
            Period.year(2024) => 2_000_000_000.0 // 2 trillion
        }

        #expect(series.count == 2)
        let vals = series.valuesArray
        #expect(vals[0] == 1_000_000_000.0)
        #expect(vals[1] == 2_000_000_000.0)
    }

    @Test("High growth rate")
    func highGrowthRate() {
        let series = TimeSeries(from: 2023, to: 2025) {
            starting(at: 100_000.0)
            growing(by: 1.0) // 100% growth per year
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 100_000.0) < 0.01)
        #expect(abs(vals[1] - 200_000.0) < 0.01)  // 100k * 2^1
        #expect(abs(vals[2] - 400_000.0) < 0.01)  // 100k * 2^2
    }

    @Test("Fractional growth rate")
    func fractionalGrowthRate() {
        let series = TimeSeries(from: 2023, to: 2024) {
            starting(at: 100_000.0)
            growing(by: 0.035) // 3.5% growth
        }

        #expect(series.count == 2)
        let vals = series.valuesArray
        #expect(abs(vals[0] - 100_000.0) < 0.01)
        #expect(abs(vals[1] - 103_500.0) < 0.01)
    }

    @Test("Conditional building")
    func conditionalBuilding() {
        let includeQ2 = true

        let series = TimeSeries<Double> {
            Quarter.q1.period(year: 2024) => 100_000.0

            if includeQ2 {
                Quarter.q2.period(year: 2024) => 110_000.0
            }

            Quarter.q3.period(year: 2024) => 120_000.0
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(vals[1] == 110_000.0)
    }

    @Test("Array-based building")
    func arrayBasedBuilding() {
        let yearlyData = [
            (2023, 100_000.0),
            (2024, 110_000.0),
            (2025, 121_000.0)
        ]

        let series = TimeSeries<Double> {
            for (year, value) in yearlyData {
                Period.year(year) => value
            }
        }

        #expect(series.count == 3)
        let vals = series.valuesArray
        #expect(vals[0] == 100_000.0)
        #expect(vals[1] == 110_000.0)
        #expect(vals[2] == 121_000.0)
    }

    @Test("Accessing values by period subscript")
    func subscriptAccess() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.year(2024) => 110_000.0
            Period.year(2025) => 121_000.0
        }

        #expect(series[Period.year(2023)] == 100_000.0)
        #expect(series[Period.year(2024)] == 110_000.0)
        #expect(series[Period.year(2025)] == 121_000.0)
        #expect(series[Period.year(2026)] == nil) // Not in series
    }

    @Test("Accessing values with default")
    func subscriptWithDefault() {
        let series = TimeSeries {
            Period.year(2024) => 100_000.0
        }

        #expect(series[Period.year(2024), default: 0.0] == 100_000.0)
        #expect(series[Period.year(2025), default: 0.0] == 0.0) // Uses default
    }

    @Test("First and last values")
    func firstAndLastValues() {
        let series = TimeSeries {
            Period.year(2023) => 100_000.0
            Period.year(2024) => 110_000.0
            Period.year(2025) => 121_000.0
        }

        #expect(series.first == 100_000.0)
        #expect(series.last == 121_000.0)
    }

    @Test("Empty series first and last")
    func emptyFirstLast() {
        let series = TimeSeries<Double> {
            // Empty
        }

        #expect(series.first == nil)
        #expect(series.last == nil)
    }
}
