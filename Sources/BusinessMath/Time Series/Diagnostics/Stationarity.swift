//
//  Stationarity.swift
//  BusinessMath
//
//  Step 6 of the Forecast Evaluation & Diagnostics tier (Diagnostics II, R1).
//
//  Unit-root / stationarity tests. The article stresses stationarity as a prerequisite
//  for learnability; these tell a user whether to difference before fitting a model.
//
//  ADF (H0: unit root / NON-stationary) and KPSS (H0: stationary) have opposite null
//  hypotheses. Running both disambiguates: agreement is a confident verdict, and
//  disagreement is flagged rather than presented as false certainty (Fail-Silent).
//
//  Note: p-values are approximate (interpolated between the standard critical values);
//  the `isStationary` decision uses the 5% critical value and is the actionable output.
//

import Foundation
import Numerics

/// The deterministic component removed before a KPSS test.
public enum KPSSRegression: Sendable { case level, trend }

/// Outcome of a unit-root / stationarity test.
public struct StationarityTestResult<T: BinaryFloatingPoint & Sendable>: Sendable {
    /// The test statistic.
    public let statistic: T
    /// Approximate p-value (interpolated between standard critical values).
    public let pValue: T
    /// The lag order used.
    public let usedLag: Int
    /// Interpreted verdict for this test's null hypothesis (see per-test docs).
    public let isStationary: Bool
    /// Plain-language recommendation.
    public let recommendation: String

    public init(statistic: T, pValue: T, usedLag: Int, isStationary: Bool, recommendation: String) {
        self.statistic = statistic
        self.pValue = pValue
        self.usedLag = usedLag
        self.isStationary = isStationary
        self.recommendation = recommendation
    }
}

public extension TimeSeries where T: BinaryFloatingPoint {

    /// Augmented Dickey–Fuller test with a constant term.
    ///
    /// H0: the series has a unit root (**non-stationary**). A sufficiently negative
    /// statistic rejects H0 ⇒ `isStationary == true`. The lag defaults to the Schwert
    /// rule `⌊12·(n/100)^{1/4}⌋` (capped to preserve degrees of freedom).
    ///
    /// - Parameter lag: Number of lagged differences; `nil` uses the Schwert default.
    /// - Returns: A ``StationarityTestResult`` (H0 = non-stationary).
    /// - Throws: ``ForecastError/insufficientData(required:got:)`` for short series.
    func augmentedDickeyFuller(lag: Int? = nil) throws -> StationarityTestResult<T> {
        let y = valuesArray.map { Double($0) }
        let n = y.count
        let p = Self.resolveLag(lag, n: n, base: 12.0)
        guard n >= p + 4 else {
            throw ForecastError.insufficientData(required: p + 4, got: n)
        }

        // Δy_t = α + β·y_{t-1} + Σ γ_i·Δy_{t-i} + ε_t, for t = p+1 … n-1.
        var diffs = [Double](repeating: 0, count: n)   // diffs[t] = y[t]-y[t-1], valid t≥1
        for t in 1..<n { diffs[t] = y[t] - y[t - 1] }

        var rows: [[Double]] = []
        var dependent: [Double] = []
        for t in (p + 1)..<n {
            var row: [Double] = [y[t - 1]]
            for i in 1...p { row.append(diffs[t - i]) }
            rows.append(row)
            dependent.append(diffs[t])
        }

        let regression = try multipleLinearRegression(X: rows, y: dependent)
        let beta = regression.coefficients[0]
        let seBeta = regression.standardErrors[1]   // [intercept, β, γ…]
        guard seBeta > 0 else {
            throw ForecastError.invalidParameter("degenerate ADF regression (zero standard error)")
        }
        let stat = beta / seBeta

        // Constant-case asymptotic critical values.
        let stationary = stat < -2.86
        let pValue = Self.adfPValue(stat)
        let recommendation = stationary
            ? "stationary (ADF rejects the unit root)"
            : "non-stationary — difference (d=1) before fitting a trend model"
        return StationarityTestResult(
            statistic: T(stat), pValue: T(pValue), usedLag: p,
            isStationary: stationary, recommendation: recommendation)
    }

    /// KPSS stationarity test.
    ///
    /// H0: the series is (level- or trend-)**stationary** — the complement of ADF. A
    /// large statistic rejects H0 ⇒ `isStationary == false`.
    ///
    /// - Parameters:
    ///   - regression: `.level` (default) or `.trend` deterministic component.
    ///   - lag: Bartlett-window lag for the long-run variance; `nil` uses `⌊4·(n/100)^{1/4}⌋`.
    /// - Returns: A ``StationarityTestResult`` (H0 = stationary).
    /// - Throws: ``ForecastError/insufficientData(required:got:)`` for short series.
    func kpss(regression: KPSSRegression = .level, lag: Int? = nil) throws -> StationarityTestResult<T> {
        let y = valuesArray.map { Double($0) }
        let n = y.count
        guard n >= 8 else { throw ForecastError.insufficientData(required: 8, got: n) }
        let L = Self.resolveLag(lag, n: n, base: 4.0)

        // Residuals from the deterministic component.
        let residuals: [Double]
        switch regression {
        case .level:
            let mean = y.reduce(0.0, +) / Double(n)
            residuals = y.map { $0 - mean }
        case .trend:
            let rows = (0..<n).map { [Double($0)] }
            let fit = try multipleLinearRegression(X: rows, y: y)
            residuals = fit.residuals
        }

        // Partial sums and their sum of squares.
        var partial = 0.0
        var sumSquaredPartials = 0.0
        for e in residuals {
            partial += e
            sumSquaredPartials += partial * partial
        }

        // Bartlett-kernel long-run variance.
        let nDouble = Double(n)
        var variance = residuals.reduce(0.0) { $0 + $1 * $1 } / nDouble
        if L >= 1 {
            for l in 1...L {
                var cross = 0.0
                for t in l..<n { cross += residuals[t] * residuals[t - l] }
                let weight = 1.0 - Double(l) / Double(L + 1)
                variance += 2.0 * weight * cross / nDouble
            }
        }
        guard variance > 0 else {
            throw ForecastError.invalidParameter("degenerate KPSS long-run variance")
        }

        let stat = sumSquaredPartials / (nDouble * nDouble * variance)
        let critical5 = regression == .level ? 0.463 : 0.146
        let stationary = stat < critical5
        let pValue = Self.kpssPValue(stat, regression: regression)
        let recommendation = stationary
            ? "stationary (KPSS fails to reject stationarity)"
            : "non-stationary — difference or detrend before fitting"
        return StationarityTestResult(
            statistic: T(stat), pValue: T(pValue), usedLag: L,
            isStationary: stationary, recommendation: recommendation)
    }

    // MARK: - Internals

    /// Schwert-style default lag, capped so the regression keeps enough observations.
    private static func resolveLag(_ lag: Int?, n: Int, base: Double) -> Int {
        if let lag { return Swift.max(0, lag) }
        let raw = Int((base * pow(Double(n) / 100.0, 0.25)).rounded(.down))
        let cap = Swift.max(1, (n - 5) / 3)
        return Swift.max(1, Swift.min(raw, cap))
    }

    /// Approximate ADF p-value (constant case) by interpolating standard critical values.
    private static func adfPValue(_ stat: Double) -> Double {
        // (statistic, p): more negative ⇒ smaller p.
        let points: [(Double, Double)] = [(-3.43, 0.01), (-2.86, 0.05), (-2.57, 0.10)]
        return interpolatedP(stat, points: points, largerStatMeansLargerP: true)
    }

    /// Approximate KPSS p-value by interpolating standard critical values.
    private static func kpssPValue(_ stat: Double, regression: KPSSRegression) -> Double {
        let points: [(Double, Double)] = regression == .level
            ? [(0.347, 0.10), (0.463, 0.05), (0.574, 0.025), (0.739, 0.01)]
            : [(0.119, 0.10), (0.146, 0.05), (0.176, 0.025), (0.216, 0.01)]
        // KPSS: larger statistic ⇒ smaller p.
        return interpolatedP(stat, points: points, largerStatMeansLargerP: false)
    }

    /// Piecewise-linear p-value interpolation, clamped to (0.001, 0.999).
    private static func interpolatedP(
        _ stat: Double,
        points: [(Double, Double)],
        largerStatMeansLargerP: Bool
    ) -> Double {
        // Below the first threshold.
        if stat <= points[0].0 {
            return largerStatMeansLargerP ? 0.001 : 0.999
        }
        // Above the last threshold.
        if let last = points.last, stat >= last.0 {
            return largerStatMeansLargerP ? 0.999 : 0.001
        }
        for i in 1..<points.count {
            let (x0, p0) = points[i - 1]
            let (x1, p1) = points[i]
            if stat >= x0 && stat <= x1 {
                let frac = (stat - x0) / (x1 - x0)
                let p = p0 + frac * (p1 - p0)
                return Swift.min(Swift.max(p, 0.001), 0.999)
            }
        }
        return 0.5
    }
}
