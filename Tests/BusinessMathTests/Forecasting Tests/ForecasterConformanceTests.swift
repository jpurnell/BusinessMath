//
//  ForecasterConformanceTests.swift
//  BusinessMath
//
//  RED phase — Step 1 of the Forecast Evaluation & Diagnostics tier.
//  Verifies the model-agnostic `Forecaster` protocol, the `AnyForecaster` adapter,
//  the exogenous-ready seam (`ForecastRegressors`), and retroactive conformances
//  for the existing trend / Holt-Winters / moving-average models.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Forecaster protocol conformance")
struct ForecasterConformanceTests {

    /// Builds a monthly TimeSeries starting Jan 2025 from a value array.
    private func monthly(_ values: [Double], startMonth: Int = 1) -> TimeSeries<Double> {
        let periods = (0..<values.count).map { Period.month(year: 2025, month: startMonth + $0) }
        return TimeSeries(periods: periods, values: values)
    }

    // MARK: - AnyForecaster adapter

    @Test("AnyForecaster.univariate ignores exogenous input and forwards to the closure")
    func anyForecasterUnivariate() throws {
        let forecaster = AnyForecaster<Double>(univariate: { history, horizon in
            // Trivial forecaster: repeat the last value.
            let last = history.last ?? 0
            let lastPeriod = history.periods.last ?? Period.month(year: 2025, month: 1)
            let periods = (1...horizon).map { lastPeriod.advanced(by: $0) }
            return TimeSeries(periods: periods, values: Array(repeating: last, count: horizon))
        })

        // Supplying exogenous regressors must not change the result for a univariate forecaster.
        let drivers = ForecastRegressors<Double>(historical: [monthly([1, 1, 1])], future: [])
        let withEx = try forecaster.trainedForecast(from: monthly([10, 20, 30]), exogenous: drivers, horizon: 2)
        let withoutEx = try forecaster.trainedForecast(from: monthly([10, 20, 30]), horizon: 2)

        #expect(withEx.valuesArray == [30, 30])
        #expect(withoutEx.valuesArray == [30, 30])
    }

    @Test("The 2-arg convenience overload forwards exogenous: nil")
    func convenienceOverloadForwardsNil() throws {
        // The full-form closure asserts it receives nil when called via the 2-arg overload.
        let forecaster = AnyForecaster<Double> { history, exogenous, horizon in
            #expect(exogenous == nil)
            let last = history.last ?? 0
            let lastPeriod = history.periods.last ?? Period.month(year: 2025, month: 1)
            let periods = (1...horizon).map { lastPeriod.advanced(by: $0) }
            return TimeSeries(periods: periods, values: Array(repeating: last, count: horizon))
        }
        let result = try forecaster.trainedForecast(from: monthly([5, 6, 7]), horizon: 1)
        #expect(result.valuesArray == [7])
    }

    // MARK: - Trend model conformance

    @Test("LinearTrend conforms and forecasts an exact linear continuation")
    func linearTrendConformance() throws {
        // y = index + 1 → slope 1, intercept 1. Forecast of horizon 3 continues 6,7,8.
        let model = LinearTrend<Double>()
        let forecast = try model.trainedForecast(from: monthly([1, 2, 3, 4, 5]), horizon: 3)
        #expect(forecast.count == 3)
        #expect(abs(forecast.valuesArray[0] - 6.0) < 1e-9)
        #expect(abs(forecast.valuesArray[1] - 7.0) < 1e-9)
        #expect(abs(forecast.valuesArray[2] - 8.0) < 1e-9)
    }

    @Test("Forecast periods immediately follow the training history (no overlap)")
    func forecastPeriodsFollowHistory() throws {
        let history = monthly([1, 2, 3, 4, 5])
        let forecast = try LinearTrend<Double>().trainedForecast(from: history, horizon: 2)
        // First forecast period must be strictly after the last training period.
        #expect(forecast.periods.first! > history.periods.last!)
    }

    // MARK: - Holt-Winters & Moving-Average conformance

    @Test("HoltWintersModel conforms and returns a horizon-length forecast")
    func holtWintersConformance() throws {
        // seasonalPeriods 2 requires ≥ 4 points.
        let model = HoltWintersModel<Double>(alpha: 0.5, beta: 0.3, gamma: 0.2, seasonalPeriods: 2)
        let forecast = try model.trainedForecast(from: monthly([10, 20, 12, 22, 14, 24]), horizon: 4)
        #expect(forecast.count == 4)
        #expect(forecast.valuesArray.allSatisfy { $0.isFinite })
    }

    @Test("MovingAverageModel conforms and returns a horizon-length forecast")
    func movingAverageConformance() throws {
        let model = MovingAverageModel<Double>(window: 3)
        let forecast = try model.trainedForecast(from: monthly([2, 4, 6, 8, 10]), horizon: 2)
        #expect(forecast.count == 2)
        #expect(forecast.valuesArray.allSatisfy { $0.isFinite })
    }

    // MARK: - Existential use (the whole point: one harness drives many models)

    @Test("A heterogeneous array of forecasters can be driven uniformly")
    func heterogeneousForecasters() throws {
        let history = monthly([1, 2, 3, 4, 5, 6])
        let forecasters: [any Forecaster<Double>] = [
            LinearTrend<Double>(),
            MovingAverageModel<Double>(window: 2),
            AnyForecaster<Double>(univariate: { h, horizon in
                let last = h.last ?? 0
                let lp = h.periods.last ?? Period.month(year: 2025, month: 1)
                return TimeSeries(periods: (1...horizon).map { lp.advanced(by: $0) },
                                  values: Array(repeating: last, count: horizon))
            })
        ]
        for f in forecasters {
            let out = try f.trainedForecast(from: history, horizon: 3)
            #expect(out.count == 3)
        }
    }
}
