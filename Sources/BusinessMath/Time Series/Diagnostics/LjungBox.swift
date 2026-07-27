//
//  LjungBox.swift
//  BusinessMath
//
//  Step 6 of the Forecast Evaluation & Diagnostics tier (Diagnostics II).
//
//  The Ljung–Box portmanteau test: does autocorrelation structure remain in a series
//  (typically model residuals)? Rejecting "white noise" means the model left signal on
//  the table.
//

import Foundation
import Numerics

/// Result of the Ljung–Box test for residual autocorrelation.
public struct LjungBoxResult<T: BinaryFloatingPoint & Sendable>: Sendable {
    /// The Ljung–Box statistic `Q`.
    public let statistic: T
    /// Degrees of freedom (`lags − fittedParameters`).
    public let degreesOfFreedom: Int
    /// p-value from the χ² distribution.
    public let pValue: T
    /// Number of lags tested.
    public let lags: Int

    public init(statistic: T, degreesOfFreedom: Int, pValue: T, lags: Int) {
        self.statistic = statistic
        self.degreesOfFreedom = degreesOfFreedom
        self.pValue = pValue
        self.lags = lags
    }

    /// True ⇒ reject "the series is white noise" at `alpha` (autocorrelation remains).
    public func rejectsWhiteNoise(alpha: T) -> Bool { pValue < alpha }
}

public extension TimeSeries where T: BinaryFloatingPoint {

    /// Ljung–Box test (Ljung & Box 1978) on this series (typically model residuals).
    ///
    /// `Q = n(n+2) Σₖ ρ(k)² / (n−k)`, compared to a χ² distribution with
    /// `lags − fittedParameters` degrees of freedom.
    ///
    /// - Parameters:
    ///   - lags: The number of autocorrelation lags to include (`≥ 1`).
    ///   - fittedParameters: Model parameters to subtract from the dof (e.g. `p+q` for
    ///     an ARIMA model). Defaults to `0` (testing a raw series).
    /// - Returns: A ``LjungBoxResult`` with the statistic and χ² p-value.
    /// - Throws: ``ForecastError`` when `lags < 1`, `dof ≤ 0`, or the series is too short.
    func ljungBox(lags: Int, fittedParameters: Int = 0) throws -> LjungBoxResult<T> {
        let n = valuesArray.count
        guard lags >= 1 else {
            throw ForecastError.invalidParameter("lags must be ≥ 1")
        }
        let dof = lags - fittedParameters
        guard dof >= 1 else {
            throw ForecastError.invalidParameter("lags must exceed fittedParameters (dof ≤ 0)")
        }
        guard n >= lags + 2 else {
            throw ForecastError.insufficientData(required: lags + 2, got: n)
        }

        let acf = autocorrelation(maxLag: lags)
        var sum = T.zero
        for k in 1...acf.count {
            let rho = acf[k - 1]
            let numerator = rho * rho
            let denominator = T(n - k)
            sum += numerator / denominator
        }
        let nT = T(n)
        let factor = nT * (nT + T(2))
        let q = factor * sum

        let cdf = try chiSquaredCDF(x: q, df: dof)
        let pValue = T(1) - cdf
        return LjungBoxResult(statistic: q, degreesOfFreedom: dof, pValue: pValue, lags: acf.count)
    }
}
