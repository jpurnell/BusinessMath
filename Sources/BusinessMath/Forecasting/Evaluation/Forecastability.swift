//
//  Forecastability.swift
//  BusinessMath
//
//  Step 5 of the Forecast Evaluation & Diagnostics tier.
//
//  "Should I even model this?" — a model-free measure of how much exploitable structure
//  a series contains, via the normalized spectral entropy of its periodogram, plus the
//  Fail-Silent refusal gate (R2) that throws rather than forecasting pure noise.
//

import Foundation
import Numerics

// MARK: - Report types

/// A plain-language bucket for a series' forecastability.
public enum ForecastabilityVerdict: String, Sendable, Codable {
    /// Indistinguishable from noise — do not trust point forecasts.
    case noise
    /// Little exploitable structure.
    case weak
    /// Some exploitable structure.
    case moderate
    /// Strong, concentrated structure — highly forecastable.
    case strong
}

/// A verdict on how much exploitable structure a series contains.
public struct ForecastabilityReport<T: BinaryFloatingPoint & Sendable>: Sendable {
    /// Normalized spectral entropy in `[0, 1]`. `1` = white noise (unforecastable),
    /// near `0` = concentrated spectrum (very forecastable). Goerg (2013).
    public let spectralEntropy: T
    /// Convenience: `1 − spectralEntropy`. Higher = more forecastable.
    public let forecastability: T
    /// Skill vs seasonal-naive from a backtest (`1 − modelMASE`); `nil` unless supplied
    /// — the spectral measure itself is model-free.
    public let skillVsNaive: T?
    /// Plain-language bucket.
    public let verdict: ForecastabilityVerdict

    /// Creates a forecastability report.
    public init(spectralEntropy: T, forecastability: T, skillVsNaive: T?, verdict: ForecastabilityVerdict) {
        self.spectralEntropy = spectralEntropy
        self.forecastability = forecastability
        self.skillVsNaive = skillVsNaive
        self.verdict = verdict
    }
}

// MARK: - API

public extension TimeSeries where T: BinaryFloatingPoint {

    /// Measures forecastability from the normalized spectral entropy of the series.
    ///
    /// - Parameter seasonLength: currently advisory only; reserved for a season-aware
    ///   refinement. Pass `nil` to use the plain spectral measure.
    /// - Returns: a ``ForecastabilityReport`` (model-free; `skillVsNaive` is `nil`).
    /// - Throws: ``ForecastError/insufficientData(required:got:)`` for very short series.
    func forecastability(seasonLength: Int? = nil) throws -> ForecastabilityReport<T> {
        let values = valuesArray
        guard values.count >= 4 else {
            throw ForecastError.insufficientData(required: 4, got: values.count)
        }
        let entropy = Self.normalizedSpectralEntropy(values.map { Double($0) })
        let verdict = Self.classify(entropy)
        let entropyT = T(entropy)
        let forecastabilityT = T(1.0 - entropy)
        return ForecastabilityReport(
            spectralEntropy: entropyT,
            forecastability: forecastabilityT,
            skillVsNaive: nil,
            verdict: verdict)
    }

    /// Fail-Silent gate (R2): throws unless the series is forecastable enough.
    ///
    /// Throws ``BacktestError/unforecastableSeries(spectralEntropy:threshold:)`` when the
    /// normalized spectral entropy exceeds `maxSpectralEntropy`. This is the single
    /// enforcement point used by `BacktestConfig.refusal == .strict(...)`, exposed
    /// directly so callers can refuse before producing any forecast at all.
    ///
    /// - Parameter maxSpectralEntropy: the refusal threshold in `[0, 1]` (e.g. `0.9`).
    /// - Returns: the ``ForecastabilityReport`` when the series passes.
    @discardableResult
    func requireForecastable(maxSpectralEntropy: Double) throws -> ForecastabilityReport<T> {
        let report = try forecastability()
        let entropy = Double(report.spectralEntropy)
        guard entropy <= maxSpectralEntropy else {
            throw BacktestError.unforecastableSeries(spectralEntropy: entropy, threshold: maxSpectralEntropy)
        }
        return report
    }

    // MARK: - Internals

    /// Normalized Shannon entropy of the demeaned series' power spectrum, in `[0, 1]`.
    /// Excludes the DC (mean) bin. Degenerate/constant series map to `1` (noise).
    private static func normalizedSpectralEntropy(_ values: [Double]) -> Double {
        let n = values.count
        guard n >= 2 else { return 1.0 }

        let mean = values.reduce(0.0, +) / Double(n) // fp-safety:disable — n >= 2 guarded above
        let demeaned = values.map { $0 - mean }

        let backend = FFTBackendSelector.selectBackend()
        let spectrum = backend.powerSpectrum(demeaned)
        let half = spectrum.count / 2
        guard half >= 2 else { return 1.0 }

        // Positive frequencies, excluding DC at index 0.
        let psd = Array(spectrum[1..<half])
        let total = psd.reduce(0.0, +)
        guard total > 0 else { return 1.0 }

        var entropy = 0.0
        for power in psd {
            let p = power / total
            if p > 0 { entropy -= p * Foundation.log(p) }
        }
        let maxEntropy = Foundation.log(Double(psd.count))
        guard maxEntropy > 0 else { return 1.0 }
        let normalized = entropy / maxEntropy
        return Swift.min(Swift.max(normalized, 0.0), 1.0)
    }

    /// Initial verdict thresholds (calibrated against benchmark regimes during Green).
    private static func classify(_ entropy: Double) -> ForecastabilityVerdict {
        switch entropy {
        case ..<0.5:  return .strong
        case ..<0.75: return .moderate
        case ..<0.9:  return .weak
        default:      return .noise
        }
    }
}
