//
//  Autocorrelation.swift
//  BusinessMath
//
//  Step 3 of the Forecast Evaluation & Diagnostics tier (Diagnostics I).
//
//  Sample autocorrelation (ACF), partial autocorrelation (PACF via the
//  Durbin–Levinson recursion), and ACF-based dominant-season detection. These are the
//  tools for answering "did the model extract the structure?" and "what is the season?"
//

import Foundation
import Numerics

public extension TimeSeries where T: BinaryFloatingPoint {

    /// Sample autocorrelation function for lags `1...maxLag` (index 0 holds lag 1).
    ///
    /// Uses the standard estimator `ρ(h) = Σ(yₜ−ȳ)(yₜ₊ₕ−ȳ) / Σ(yₜ−ȳ)²`, where the
    /// `1/n` normalization cancels in the ratio (matching `statsmodels.acf` with
    /// `adjusted=False`). `maxLag` is clamped to `n−1`. A constant series (zero
    /// variance) returns all zeros rather than NaN; an empty/one-point series returns `[]`.
    ///
    /// - Parameter maxLag: The largest lag to compute.
    /// - Returns: Autocorrelations for lags `1...min(maxLag, n−1)`.
    func autocorrelation(maxLag: Int) -> [T] {
        let y = valuesArray
        let n = y.count
        guard n >= 2, maxLag >= 1 else { return [] }
        let lags = Swift.min(maxLag, n - 1)

        let ybar = mean(y)
        let dev = y.map { $0 - ybar }

        var gamma0 = T.zero
        for d in dev { gamma0 += d * d }
        guard gamma0 > T.zero else { return Array(repeating: T.zero, count: lags) }

        var result: [T] = []
        result.reserveCapacity(lags)
        for h in 1...lags {
            var s = T.zero
            for t in 0..<(n - h) {
                s += dev[t] * dev[t + h]
            }
            result.append(s / gamma0)
        }
        return result
    }

    /// Partial autocorrelation for lags `1...maxLag` via the Durbin–Levinson recursion.
    ///
    /// PACF at lag `k` is the correlation between `yₜ` and `yₜ₋ₖ` after removing the
    /// linear effect of the intermediate lags. By construction PACF(1) == ACF(1).
    ///
    /// - Parameter maxLag: The largest lag to compute.
    /// - Returns: Partial autocorrelations for lags `1...min(maxLag, n−1)`.
    func partialAutocorrelation(maxLag: Int) -> [T] {
        let acf = autocorrelation(maxLag: maxLag)
        let p = acf.count
        guard p >= 1 else { return [] }

        var pacf = [T](repeating: T.zero, count: p)
        var phiPrev = [T](repeating: T.zero, count: p + 1)  // 1-indexed coefficients

        pacf[0] = acf[0]
        phiPrev[1] = acf[0]
        if p == 1 { return pacf }

        for k in 2...p {
            var numerator = acf[k - 1]
            var denominator = T(1)
            for j in 1..<k {
                let numTerm = phiPrev[j] * acf[k - j - 1]
                numerator -= numTerm
                let denTerm = phiPrev[j] * acf[j - 1]
                denominator -= denTerm
            }
            let phiKK: T = denominator != T.zero ? numerator / denominator : T.zero
            pacf[k - 1] = phiKK

            var phiCur = [T](repeating: T.zero, count: p + 1)
            for j in 1..<k {
                let adjust = phiKK * phiPrev[k - j]
                phiCur[j] = phiPrev[j] - adjust
            }
            phiCur[k] = phiKK
            phiPrev = phiCur
        }
        return pacf
    }

    /// Suggests the dominant seasonal period from the ACF (R4).
    ///
    /// Returns the lag `h ≥ 2` whose autocorrelation is the strongest **and** exceeds
    /// the approximate 95% white-noise band `1.96/√n`. Returns `nil` when no lag clears
    /// the band (no detectable seasonality) — callers then fall back to a non-seasonal
    /// season length of 1. This is purely advisory: it *suggests*, it does not override
    /// an explicit season length supplied elsewhere.
    ///
    /// - Parameter maxLag: The largest candidate period to consider.
    /// - Returns: The suggested season length, or `nil` if none is detectable.
    func dominantSeasonLength(maxLag: Int) -> Int? {
        let n = valuesArray.count
        guard n >= 2 else { return nil }
        let acf = autocorrelation(maxLag: maxLag)
        guard acf.count >= 2 else { return nil }

        let z = T(196) / T(100)              // 1.96
        let band = z / T.sqrt(T(n))

        var bestLag: Int? = nil
        var bestValue = band                 // candidate must exceed the band
        for h in 2...acf.count {
            let value = acf[h - 1]
            if value > bestValue {
                bestValue = value
                bestLag = h
            }
        }
        return bestLag
    }
}
