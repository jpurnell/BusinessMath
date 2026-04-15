//
//  DiscountCurve.swift
//  BusinessMath
//
//  A discount curve mapping tenors to discount factors with interpolation,
//  zero rate extraction, forward rate calculation, and bootstrapping.
//
//  Created by Justin Purnell on 2026-04-15.
//

import Foundation

// MARK: - CurveInterpolation

/// Interpolation method for a ``DiscountCurve``.
///
/// Controls how the curve estimates discount factors between observed tenor points.
///
/// - ``logLinear``: Interpolates linearly on the *logarithm* of discount factors.
///   This is the default because it guarantees positive discount factors and corresponds
///   to piecewise-constant forward rates.
/// - ``linear``: Interpolates linearly on continuously compounded zero rates.
public enum CurveInterpolation: Sendable {
    /// Log-linear interpolation on discount factors (default).
    ///
    /// Ensures positive discount factors and produces piecewise-constant forward rates.
    case logLinear

    /// Linear interpolation on continuously compounded zero rates.
    case linear
}

// MARK: - DiscountCurve

/// A discount curve that maps tenors (in years) to discount factors.
///
/// `DiscountCurve` stores a set of observed discount factors at discrete tenor points
/// and provides interpolated discount factors, continuously compounded zero rates,
/// and forward rates at arbitrary tenors.
///
/// ## Creating a Curve
///
/// ```swift
/// let curve = DiscountCurve(
///     asOfDate: Date(),
///     tenors: [0.5, 1.0, 2.0, 5.0, 10.0],
///     discountFactors: [0.985, 0.970, 0.940, 0.860, 0.740]
/// )
/// ```
///
/// ## Bootstrapping from Par Swap Rates
///
/// ```swift
/// let curve = DiscountCurve.bootstrap(
///     parRates: [(1.0, 0.04), (2.0, 0.045), (5.0, 0.05)],
///     asOfDate: Date()
/// )
/// ```
///
/// ## Extracting Rates
///
/// ```swift
/// let df3Y = curve.discountFactor(at: 3.0)
/// let zero3Y = curve.zeroRate(at: 3.0)
/// let fwd1Y2Y = curve.forwardRate(from: 1.0, to: 2.0)
/// ```
public struct DiscountCurve: Sendable {

    /// The valuation date of this curve.
    public let asOfDate: Date

    /// Tenor points in years, sorted in ascending order.
    public let tenors: [Double]

    /// Discount factors at each tenor point. `discountFactors[i]` corresponds to `tenors[i]`.
    public let discountFactors: [Double]

    /// The interpolation method used between tenor points.
    public let interpolation: CurveInterpolation

    /// Creates a discount curve from tenor points and their corresponding discount factors.
    ///
    /// - Parameters:
    ///   - asOfDate: The valuation date of the curve.
    ///   - tenors: Tenor points in years, must be sorted ascending.
    ///   - discountFactors: Discount factors at each tenor. Must have the same count as `tenors`.
    ///   - interpolation: Interpolation method (default: ``CurveInterpolation/logLinear``).
    public init(
        asOfDate: Date,
        tenors: [Double],
        discountFactors: [Double],
        interpolation: CurveInterpolation = .logLinear
    ) {
        self.asOfDate = asOfDate
        self.tenors = tenors
        self.discountFactors = discountFactors
        self.interpolation = interpolation
    }

    // MARK: - Discount Factor

    /// Returns the discount factor at an arbitrary tenor via interpolation.
    ///
    /// - At tenor 0 the discount factor is 1.0.
    /// - Between knots the value is interpolated according to the curve's ``interpolation`` method.
    /// - Beyond the last tenor, flat extrapolation is used (the last discount factor's
    ///   implied zero rate is extended).
    ///
    /// - Parameter tenor: Time in years. Must be non-negative.
    /// - Returns: The interpolated (or extrapolated) discount factor.
    public func discountFactor(at tenor: Double) -> Double {
        // DF(0) = 1 by definition
        guard tenor > 0 else { return 1.0 }

        // Empty curve: return 1
        guard !tenors.isEmpty else { return 1.0 }

        // Single knot: extend its zero rate
        if tenors.count == 1 {
            guard let df = discountFactors.first, let t = tenors.first, t > 0 else { return 1.0 }
            let zeroR = -log(df) / t
            return exp(-zeroR * tenor)
        }

        // Extrapolation beyond last tenor: flat zero rate from last point
        if tenor >= tenors[tenors.count - 1] {
            let lastDF = discountFactors[tenors.count - 1]
            let lastT = tenors[tenors.count - 1]
            guard lastT > 0 else { return 1.0 }
            let zeroR = -log(lastDF) / lastT
            return exp(-zeroR * tenor)
        }

        // Before first tenor: interpolate from DF(0)=1
        if tenor <= tenors[0] {
            let t1 = tenors[0]
            let df1 = discountFactors[0]
            guard t1 > 0 else { return 1.0 }
            return interpolateBetween(
                t0: 0.0, df0: 1.0,
                t1: t1, df1: df1,
                at: tenor
            )
        }

        // Find bracket
        let (lo, hi) = findBracket(for: tenor)
        return interpolateBetween(
            t0: tenors[lo], df0: discountFactors[lo],
            t1: tenors[hi], df1: discountFactors[hi],
            at: tenor
        )
    }

    // MARK: - Zero Rate

    /// Returns the continuously compounded zero rate at a given tenor.
    ///
    /// ```
    /// r(t) = -ln(DF(t)) / t
    /// ```
    ///
    /// For `tenor == 0`, returns the instantaneous short rate (zero rate at the first
    /// available tenor, or 0 if the curve is empty).
    ///
    /// - Parameter tenor: Time in years.
    /// - Returns: Continuously compounded zero rate.
    public func zeroRate(at tenor: Double) -> Double {
        guard tenor > 1e-15 else {
            // Return the short rate: zero rate at the first tenor, or 0
            guard let firstT = tenors.first, firstT > 0,
                  let firstDF = discountFactors.first else { return 0.0 }
            return -log(firstDF) / firstT
        }
        let df = discountFactor(at: tenor)
        guard df > 0 else { return 0.0 }
        return -log(df) / tenor
    }

    // MARK: - Forward Rate

    /// Returns the continuously compounded forward rate between two tenors.
    ///
    /// ```
    /// f(t1, t2) = -(ln(DF(t2)) - ln(DF(t1))) / (t2 - t1)
    /// ```
    ///
    /// When `t1` equals `t2`, returns the zero rate at that tenor (the instantaneous
    /// forward rate approximation).
    ///
    /// - Parameters:
    ///   - t1: Start tenor in years.
    ///   - t2: End tenor in years.
    /// - Returns: Forward rate between `t1` and `t2`.
    public func forwardRate(from t1: Double, to t2: Double) -> Double {
        let interval = t2 - t1
        guard abs(interval) > 1e-15 else {
            return zeroRate(at: t1)
        }
        let df1 = discountFactor(at: t1)
        let df2 = discountFactor(at: t2)
        guard df1 > 0, df2 > 0 else { return 0.0 }
        return -(log(df2) - log(df1)) / interval
    }

    // MARK: - Shifted Curve

    /// Returns a new curve with all zero rates shifted by a parallel amount.
    ///
    /// Each discount factor is recomputed as:
    /// ```
    /// DF_new(t) = exp(-(r(t) + amount) * t)
    /// ```
    ///
    /// - Parameter amount: The parallel shift in rate space (e.g., 0.001 for +10bp).
    /// - Returns: A new ``DiscountCurve`` with shifted rates.
    public func shifted(by amount: Double) -> DiscountCurve {
        let newDFs = zip(tenors, discountFactors).map { (t, df) -> Double in
            guard t > 0, df > 0 else { return df }
            let r = -log(df) / t
            return exp(-(r + amount) * t)
        }
        return DiscountCurve(
            asOfDate: asOfDate,
            tenors: tenors,
            discountFactors: newDFs,
            interpolation: interpolation
        )
    }

    // MARK: - Bootstrap

    /// Bootstraps a discount curve from par swap rates.
    ///
    /// Assumes annual fixed-leg payments and iterative bootstrapping.
    /// For a par swap at tenor *N* with coupon *c*, the par condition is:
    /// ```
    /// c * (DF(1) + DF(2) + ... + DF(N)) + DF(N) = 1
    /// ```
    /// Solving for `DF(N)`:
    /// ```
    /// DF(N) = (1 - c * Σ DF(i), i=1..N-1) / (1 + c)
    /// ```
    ///
    /// When par rates are supplied at non-consecutive integer tenors (e.g., 1, 2, 3, 5),
    /// intermediate annual DFs are obtained by log-linear interpolation on the
    /// already-bootstrapped curve before solving the next tenor.
    ///
    /// - Parameters:
    ///   - parRates: Array of (tenor, par rate) tuples. Tenors must be positive.
    ///   - asOfDate: The valuation date for the resulting curve.
    /// - Returns: A bootstrapped ``DiscountCurve``.
    public static func bootstrap(
        parRates: [(tenor: Double, rate: Double)],
        asOfDate: Date
    ) -> DiscountCurve {
        guard !parRates.isEmpty else {
            return DiscountCurve(asOfDate: asOfDate, tenors: [], discountFactors: [])
        }

        let sorted = parRates.sorted { $0.tenor < $1.tenor }

        // We store DFs at all integer years up to the maximum tenor
        // so that intermediate payment dates are always available.
        let maxTenor = Int(sorted.last?.tenor ?? 0)
        guard maxTenor >= 1 else {
            return DiscountCurve(asOfDate: asOfDate, tenors: [], discountFactors: [])
        }

        // Map from integer year -> DF
        var dfMap: [Int: Double] = [:]

        // Index into sorted par rates
        var parIndex = 0

        // Build par rate lookup for quick access
        var parRateLookup: [Int: Double] = [:]
        for entry in sorted {
            let year = Int(entry.tenor)
            parRateLookup[year] = entry.rate
        }

        for year in 1...maxTenor {
            if let c = parRateLookup[year] {
                // We have a par rate at this tenor -- bootstrap DF
                var sumPrior = 0.0
                for y in 1..<year {
                    sumPrior += dfMap[y] ?? 1.0
                }
                let denominator = 1.0 + c
                guard abs(denominator) > 1e-15 else { continue }
                dfMap[year] = (1.0 - c * sumPrior) / denominator
            } else {
                // No par rate at this tenor -- interpolate from the curve so far.
                // Find the nearest bootstrapped tenors that bracket this year.
                let knownTenors = dfMap.keys.sorted()
                guard !knownTenors.isEmpty else { continue }

                // Find lower and upper bracket
                let lowerKeys = knownTenors.filter { $0 < year }
                let upperKeys = knownTenors.filter { $0 > year }

                if let lo = lowerKeys.last, let hi = upperKeys.first {
                    // Log-linear interpolation between lo and hi
                    let dfLo = dfMap[lo] ?? 1.0
                    let dfHi = dfMap[hi] ?? 1.0
                    guard dfLo > 0, dfHi > 0 else { continue }
                    let frac = Double(year - lo) / Double(hi - lo)
                    let lnDF = log(dfLo) * (1.0 - frac) + log(dfHi) * frac
                    dfMap[year] = exp(lnDF)
                } else if let lo = lowerKeys.last {
                    // Extrapolate from last known DF using its zero rate
                    let dfLo = dfMap[lo] ?? 1.0
                    guard dfLo > 0, lo > 0 else { continue }
                    let r = -log(dfLo) / Double(lo)
                    dfMap[year] = exp(-r * Double(year))
                }
            }
        }

        // Now we have dfMap filled. But some intermediate years may have been
        // interpolated using a *future* par-rate anchor. We need a second pass
        // for tenors that were interpolated before their upper bracket was set.
        // Re-bootstrap properly: process par rates in order, filling gaps as we go.
        dfMap.removeAll()

        var prevParYear = 0

        for entry in sorted {
            let year = Int(entry.tenor)
            let c = entry.rate

            // Fill any gap years between prevParYear+1 and year-1 by interpolation
            // We need an upper DF to interpolate, but we don't have it yet.
            // Instead, solve for DF(year) first assuming we'll fill gaps after,
            // then fill gaps using log-linear between prevParYear and year.

            // Step 1: Temporarily compute DF(year) assuming gaps are log-linearly filled
            // We'll iterate: guess DF(year), fill gaps, re-solve.

            // For the first pass, estimate DF(year) using only known DFs
            // and log-linear interpolation for gaps.

            // Actually, the cleaner approach: solve the par equation directly.
            // c * [DF(1) + ... + DF(year)] + DF(year) = 1
            // Let S_known = sum of DF(i) for i in 1..year-1 where i is in dfMap
            // Let S_gap = sum of DF(i) for gap years
            // DF(year) = (1 - c*(S_known + S_gap)) / (1 + c)
            //
            // For gap years between lastKnown and year, use log-linear:
            //   DF(i) = DF(lastKnown)^((year-i)/(year-lastKnown)) * DF(year)^((i-lastKnown)/(year-lastKnown))
            //
            // This makes S_gap a function of DF(year), so we can solve algebraically.

            let lastKnownYear = prevParYear  // 0 means DF(0)=1
            let lastKnownDF: Double = lastKnownYear > 0 ? (dfMap[lastKnownYear] ?? 1.0) : 1.0
            guard lastKnownDF > 0 else { continue }
            let lnDFLast = lastKnownYear > 0 ? log(lastKnownDF) : 0.0

            // Sum of known DFs from years 1 to lastKnownYear
            var sumKnown = 0.0
            for y in 1...max(1, lastKnownYear) {
                if let df = dfMap[y] {
                    sumKnown += df
                }
            }

            // Gap years: lastKnownYear+1 to year-1
            // For each gap year g, DF(g) = exp(lnDFLast*(1-frac_g) + lnDFYear*frac_g)
            //   where frac_g = (g - lastKnownYear) / (year - lastKnownYear)
            // Let span = year - lastKnownYear
            let span = year - lastKnownYear
            // lnDF(g) = lnDFLast + frac_g * (lnDFYear - lnDFLast)
            // DF(g) = exp(lnDFLast) * exp(frac_g * (lnDFYear - lnDFLast))
            //       = DFLast * (DFYear/DFLast)^frac_g
            //
            // S_gap = sum_{g=lastKnown+1}^{year-1} DFLast * (DFYear/DFLast)^(frac_g)
            //
            // Let x = DFYear / DFLast (unknown), then:
            // S_gap = DFLast * sum_{g} x^(frac_g)
            // and DF(year) = DFLast * x^1 = DFLast * x
            //
            // Par equation: c * (sumKnown + S_gap + DFYear) + DFYear = 1
            //   c * (sumKnown + DFLast * sum(x^frac_g) + DFLast*x) + DFLast*x = 1
            //
            // This is nonlinear in x. Use Newton's method to solve.

            // For simplicity and robustness, use a direct iterative approach:
            // Start with an initial guess for DF(year)
            let rGuess: Double = c  // par rate as initial zero rate guess
            var dfYear = exp(-rGuess * Double(year))

            for _ in 0..<50 {  // Newton iterations
                // Fill gap DFs
                var sumAll = sumKnown
                for g in (lastKnownYear + 1)..<year {
                    let frac = Double(g - lastKnownYear) / Double(span)
                    let lnDFG = lnDFLast * (1.0 - frac) + log(max(dfYear, 1e-300)) * frac
                    sumAll += exp(lnDFG)
                }
                sumAll += dfYear  // Add DF(year) itself

                // Par equation: c * sumAll + dfYear = 1
                // f(dfYear) = c * sumAll + dfYear - 1 = 0
                let fVal = c * sumAll + dfYear - 1.0

                // Derivative: d(fVal)/d(dfYear)
                // d(sumAll)/d(dfYear) = sum of d(DF(g))/d(dfYear) + 1
                var dSumAll = 1.0  // from the dfYear term
                for g in (lastKnownYear + 1)..<year {
                    let frac = Double(g - lastKnownYear) / Double(span)
                    let lnDFG = lnDFLast * (1.0 - frac) + log(max(dfYear, 1e-300)) * frac
                    let dfG = exp(lnDFG)
                    // d(dfG)/d(dfYear) = dfG * frac / dfYear
                    dSumAll += dfG * frac / max(dfYear, 1e-300)
                }
                let dfVal = c * dSumAll + 1.0

                guard abs(dfVal) > 1e-300 else { break }
                let step = fVal / dfVal
                dfYear -= step
                dfYear = max(dfYear, 1e-10)  // Keep positive

                if abs(step) < 1e-15 { break }
            }

            // Store gap DFs
            for g in (lastKnownYear + 1)..<year {
                let frac = Double(g - lastKnownYear) / Double(span)
                let lnDFG = lnDFLast * (1.0 - frac) + log(max(dfYear, 1e-300)) * frac
                dfMap[g] = exp(lnDFG)
            }
            dfMap[year] = dfYear
            prevParYear = year
        }

        // Build output arrays
        let allYears = dfMap.keys.sorted()
        let outTenors = allYears.map { Double($0) }
        let outDFs = allYears.map { dfMap[$0] ?? 1.0 }

        return DiscountCurve(
            asOfDate: asOfDate,
            tenors: outTenors,
            discountFactors: outDFs
        )
    }

    // MARK: - Private Helpers

    /// Finds the bracket indices for a given tenor within the tenors array.
    private func findBracket(for tenor: Double) -> (lo: Int, hi: Int) {
        var lo = 0
        var hi = tenors.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if tenors[mid] <= tenor { lo = mid } else { hi = mid }
        }
        return (lo, hi)
    }

    /// Interpolates a discount factor between two knot points.
    private func interpolateBetween(
        t0: Double, df0: Double,
        t1: Double, df1: Double,
        at tenor: Double
    ) -> Double {
        let span = t1 - t0
        guard span > 1e-15 else { return df0 }
        let frac = (tenor - t0) / span

        switch interpolation {
        case .logLinear:
            // Interpolate linearly on ln(DF)
            guard df0 > 0, df1 > 0 else { return df0 }
            let lnDF = log(df0) * (1.0 - frac) + log(df1) * frac
            return exp(lnDF)

        case .linear:
            // Interpolate linearly on zero rates
            let r0: Double = t0 > 1e-15 ? -log(max(df0, 1e-15)) / t0 : 0.0
            let r1: Double = t1 > 1e-15 ? -log(max(df1, 1e-15)) / t1 : 0.0
            let r = r0 * (1.0 - frac) + r1 * frac
            return exp(-r * tenor)
        }
    }
}
