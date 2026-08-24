//
//  BenchmarkReplicationTests.swift
//  BusinessMath
//
//  Step 9 of the Forecast Evaluation & Diagnostics tier.
//
//  Replicates the CORE finding of "The Unreasonable Difficulty of Time Series
//  Forecasting" (Suzy Ahyah, 2026) using ONLY BusinessMath — no Python, no statsmodels,
//  no Nixtla. It runs every BusinessMath forecaster through the rolling-origin backtest
//  on two deterministic regimes and shows:
//
//    • strongly-seasonal series  → low spectral entropy, seasonal methods beat naive
//    • chaotic (event-driven)     → high spectral entropy, nothing beats naive
//
//  Deterministic fixtures (no RNG): a two-harmonic seasonal signal, and a logistic-map
//  chaotic series standing in for the article's exchange/bitcoin regime.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// Pads `text` to `width`, left-aligned by default.
///
/// Replaces `String(format: "%-14@", …)`, whose `%@` bridges through `NSString`
/// and is undefined on Linux. Plain Swift keeps the table aligned everywhere.
private func pad(_ text: String, _ width: Int, right: Bool = false) -> String {
	guard text.count < width else { return text }
	let fill = String(repeating: " ", count: width - text.count)
	return right ? fill + text : text + fill
}


@Suite("Article benchmark replication (BusinessMath only)")
struct BenchmarkReplicationTests {

    private func monthlySeries(_ values: [Double]) -> TimeSeries<Double> {
        let start = Period.month(year: 2020, month: 1)
        return TimeSeries(periods: (0..<values.count).map { start.advanced(by: $0) }, values: values)
    }

    /// Strongly-seasonal, period-12, deterministic (two harmonics + gentle trend).
    /// The mild trend keeps seasonal-naive from being *exactly* perfect, so MASE has a
    /// meaningful (non-degenerate) scale — as with any real series.
    private func seasonalSeries(n: Int) -> TimeSeries<Double> {
        monthlySeries((0..<n).map { t in
            let base = 100.0
            let trend = 0.2 * Double(t)
            let s1 = 15.0 * sin(2.0 * .pi * Double(t) / 12.0)
            let s2 = 5.0 * sin(2.0 * .pi * Double(t) / 6.0)
            return base + trend + s1 + s2
        })
    }

    /// Chaotic logistic map (r=3.99) — deterministic but low-forecastability.
    private func chaoticSeries(n: Int) -> TimeSeries<Double> {
        var x = 0.4
        var values: [Double] = []
        for _ in 0..<n {
            x = 3.99 * x * (1.0 - x)
            values.append(100.0 + 50.0 * x)
        }
        return monthlySeries(values)
    }

    private func forecasters() -> [(String, any Forecaster<Double>)] {
        [
            ("Naive",         NaiveForecaster<Double>()),
            ("SeasonalNaive", SeasonalNaiveForecaster<Double>(seasonLength: 12)),
            ("Drift",         DriftForecaster<Double>()),
            ("MovingAverage", MovingAverageModel<Double>(window: 12)),
            ("HoltWinters",   HoltWintersModel<Double>(alpha: 0.3, beta: 0.1, gamma: 0.3, seasonalPeriods: 12)),
            ("LinearTrend",   LinearTrend<Double>())
        ]
    }

    /// Runs the full benchmark table and returns per-model out-of-sample MAE.
    private func runRegime(_ name: String, _ series: TimeSeries<Double>) throws -> [String: Double] {
        let config = BacktestConfig(initialTrainSize: 36, horizon: 6, step: 6, seasonLength: 12)
        let f = try series.forecastability()
        print("\n=== \(name) ===")
        print("spectral entropy = \(Double(f.spectralEntropy).number(3))  →  verdict: \(f.verdict.rawValue)")
        print("\(pad("model", 14))  \(pad("OOS MAE", 10, right: true))  \(pad("MASE", 8, right: true))")
        var maeByModel: [String: Double] = [:]
        for (label, model) in forecasters() {
            let report = try series.backtest(model, config: config)
            maeByModel[label] = Double(report.mae)
            let maseStr = report.mase.map { Double($0).number(3) } ?? "—"
            print("\(pad(label, 14))  \(pad(Double(report.mae).number(4), 10, right: true))  \(pad(maseStr, 8, right: true))")
        }
        return maeByModel
    }

    @Test("Seasonal regime: low entropy, seasonal methods beat naive")
    func seasonalRegime() throws {
        let series = seasonalSeries(n: 72)
        let f = try series.forecastability()
        let mae = try runRegime("SEASONAL (period-12, deterministic)", series)

        // Low spectral entropy — structure present.
        #expect(f.verdict == .strong || f.verdict == .moderate)
        // Seasonal-aware methods beat the plain naive forecaster.
        #expect(try #require(mae["SeasonalNaive"]) < (try #require(mae["Naive"])))
        #expect(try #require(mae["HoltWinters"]) < (try #require(mae["Naive"])))
    }

    @Test("Chaotic regime: high entropy, nothing beats naive")
    func chaoticRegime() throws {
        let series = chaoticSeries(n: 72)
        let f = try series.forecastability()
        let mae = try runRegime("CHAOTIC (logistic map r=3.99)", series)

        // High spectral entropy — little exploitable structure.
        #expect(f.verdict == .noise || f.verdict == .weak)
        // No forecaster meaningfully beats naive (seasonal structure does not help).
        let naive = try #require(mae["Naive"])
        let best = try #require(mae.values.min())
        #expect(best >= naive * 0.75)   // best improvement over naive is modest at most
    }

    @Test("The two regimes are clearly separated by forecastability")
    func regimeContrast() throws {
        let seasonalEntropy = try Double(seasonalSeries(n: 72).forecastability().spectralEntropy)
        let chaoticEntropy = try Double(chaoticSeries(n: 72).forecastability().spectralEntropy)
        #expect(seasonalEntropy < chaoticEntropy)
    }
}
