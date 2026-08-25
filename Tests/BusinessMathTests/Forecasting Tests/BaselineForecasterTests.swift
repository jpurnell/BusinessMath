//
//  BaselineForecasterTests.swift
//  BusinessMath
//
//  RED phase — Step 2 of the Forecast Evaluation & Diagnostics tier.
//  Naive, Seasonal-Naive, and Drift benchmark forecasters. These are the yardsticks
//  every other forecast is measured against (and the denominator for MASE).
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Baseline forecasters")
struct BaselineForecasterTests {

    private func monthly(_ values: [Double]) -> TimeSeries<Double> {
        let periods = (0..<values.count).map { Period.month(year: 2025, month: 1 + $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - Naive

    @Test("Naive carries the last value forward")
    func naive() throws {
        let f = try NaiveForecaster<Double>().trainedForecast(from: monthly([10, 11, 12, 13]), horizon: 3)
        #expect(f.valuesArray == [13, 13, 13])
    }

    @Test("Naive forecast periods follow the history")
    func naivePeriods() throws {
        let history = monthly([10, 11, 12, 13])
        let f = try NaiveForecaster<Double>().trainedForecast(from: history, horizon: 2)
        #expect(try #require(f.periods.first) > (try #require(history.periods.last)))
        #expect(f.count == 2)
    }

    // MARK: - Seasonal Naive

    @Test("Seasonal-naive repeats the last full season")
    func seasonalNaiveOneSeason() throws {
        // Last season (m=4) is [5,6,7,8]; horizon 4 repeats it exactly.
        let f = try SeasonalNaiveForecaster<Double>(seasonLength: 4)
            .trainedForecast(from: monthly([1, 2, 3, 4, 5, 6, 7, 8]), horizon: 4)
        #expect(f.valuesArray == [5, 6, 7, 8])
    }

    @Test("Seasonal-naive cycles when horizon exceeds one season")
    func seasonalNaiveMultiSeason() throws {
        // horizon 6 with m=4: [5,6,7,8, 5,6]
        let f = try SeasonalNaiveForecaster<Double>(seasonLength: 4)
            .trainedForecast(from: monthly([1, 2, 3, 4, 5, 6, 7, 8]), horizon: 6)
        #expect(f.valuesArray == [5, 6, 7, 8, 5, 6])
    }

    @Test("Seasonal-naive requires at least one full season")
    func seasonalNaiveInsufficient() throws {
        #expect(throws: (any Error).self) {
            _ = try SeasonalNaiveForecaster<Double>(seasonLength: 4)
                .trainedForecast(from: monthly([1, 2, 3]), horizon: 2)
        }
    }

    // MARK: - Drift

    @Test("Drift extrapolates the average slope (last + h·mean-diff)")
    func drift() throws {
        // [1,2,3,4,5]: slope = (5-1)/(5-1) = 1, last = 5 → 6,7,8
        let f = try DriftForecaster<Double>().trainedForecast(from: monthly([1, 2, 3, 4, 5]), horizon: 3)
        #expect(abs(f.valuesArray[0] - 6.0) < 1e-9)
        #expect(abs(f.valuesArray[1] - 7.0) < 1e-9)
        #expect(abs(f.valuesArray[2] - 8.0) < 1e-9)
    }

    @Test("Drift on a flat series equals naive")
    func driftFlat() throws {
        // slope 0 → repeats last value
        let f = try DriftForecaster<Double>().trainedForecast(from: monthly([7, 7, 7, 7]), horizon: 2)
        #expect(f.valuesArray == [7, 7])
    }

    // MARK: - Forecaster integration

    @Test("Baselines are usable as `any Forecaster`")
    func baselinesAsExistentials() throws {
        let history = monthly([1, 2, 3, 4, 5, 6, 7, 8])
        let baselines: [any Forecaster<Double>] = [
            NaiveForecaster<Double>(),
            SeasonalNaiveForecaster<Double>(seasonLength: 4),
            DriftForecaster<Double>()
        ]
        for b in baselines {
            #expect(try b.trainedForecast(from: history, horizon: 3).count == 3)
        }
    }
}
