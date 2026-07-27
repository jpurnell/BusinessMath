//
//  ForecastabilityTests.swift
//  BusinessMath
//
//  RED phase — Step 5 of the Forecast Evaluation & Diagnostics tier.
//  Spectral-entropy forecastability + the Fail-Silent refusal path (R2).
//
//  Deterministic fixtures (no RNG): a pure sine is highly forecastable (entropy ≈ 0);
//  an impulse has a flat spectrum (entropy ≈ 1); a constant series is degenerate noise.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

@Suite("Forecastability & refusal")
struct ForecastabilityTests {

    private func series(_ values: [Double]) -> TimeSeries<Double> {
        let start = Period.month(year: 2025, month: 1)
        return TimeSeries(periods: (0..<values.count).map { start.advanced(by: $0) }, values: values)
    }

    /// A clean sine with an integer number of cycles → power in one FFT bin.
    private func sine(n: Int, cycles: Double) -> TimeSeries<Double> {
        series((0..<n).map { sin(2.0 * .pi * cycles * Double($0) / Double(n)) })
    }

    /// An impulse → approximately flat spectrum.
    private func impulse(n: Int) -> TimeSeries<Double> {
        var v = [Double](repeating: 0, count: n); v[0] = 1
        return series(v)
    }

    // MARK: - Spectral entropy regimes

    @Test("A pure sine is highly forecastable (low spectral entropy, strong verdict)")
    func sineForecastable() throws {
        let report = try sine(n: 32, cycles: 4).forecastability()
        #expect(report.spectralEntropy < 0.5)
        #expect(report.verdict == .strong)
    }

    @Test("An impulse is unforecastable (high spectral entropy, noise verdict)")
    func impulseNoise() throws {
        let report = try impulse(n: 16).forecastability()
        #expect(report.spectralEntropy > 0.85)
        #expect(report.verdict == .noise)
    }

    @Test("A constant series is degenerate noise (entropy 1)")
    func constantNoise() throws {
        let report = try series(Array(repeating: 5.0, count: 16)).forecastability()
        #expect(abs(report.spectralEntropy - 1.0) < 1e-9)
        #expect(report.verdict == .noise)
    }

    @Test("forecastability == 1 − spectralEntropy")
    func forecastabilityComplement() throws {
        let report = try sine(n: 32, cycles: 3).forecastability()
        #expect(abs(report.forecastability - (1.0 - report.spectralEntropy)) < 1e-12)
    }

    // MARK: - requireForecastable (refusal gate)

    @Test("requireForecastable returns a report for a forecastable series")
    func requirePasses() throws {
        let report = try sine(n: 32, cycles: 4).requireForecastable(maxSpectralEntropy: 0.9)
        #expect(report.spectralEntropy < 0.9)
    }

    @Test("requireForecastable throws unforecastableSeries for noise")
    func requireThrows() {
        #expect(throws: BacktestError.self) {
            _ = try self.impulse(n: 16).requireForecastable(maxSpectralEntropy: 0.9)
        }
    }

    // MARK: - Refusal wired into backtest (R2)

    @Test("Strict backtest completes on a forecastable series")
    func strictBacktestPasses() throws {
        let report = try sine(n: 40, cycles: 5).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 20, horizon: 2, refusal: .strict(maxSpectralEntropy: 0.9)))
        #expect(report.foldCount > 0)
    }

    @Test("Strict backtest refuses a noise-like series")
    func strictBacktestRefuses() {
        #expect(throws: BacktestError.self) {
            _ = try self.impulse(n: 20).backtest(
                NaiveForecaster<Double>(),
                config: BacktestConfig(initialTrainSize: 10, horizon: 2, refusal: .strict(maxSpectralEntropy: 0.5)))
        }
    }

    @Test("Lenient backtest (default) computes even on noise")
    func lenientComputesOnNoise() throws {
        let report = try impulse(n: 20).backtest(
            NaiveForecaster<Double>(),
            config: BacktestConfig(initialTrainSize: 10, horizon: 2))
        #expect(report.foldCount > 0)
    }
}
