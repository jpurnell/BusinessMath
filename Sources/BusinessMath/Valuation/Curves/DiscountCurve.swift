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
/// let curve = DiscountCurve(asOfDate: Date(), tenors: [1.0, 2.0, 3.0, 5.0], discountFactors: [0.97, 0.94, 0.91, 0.85])
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
            let zeroR = -log(df) / t // fp-safety:disable — guarded above (t > 0)
            return exp(-zeroR * tenor)
        }

        // Extrapolation beyond last tenor: flat zero rate from last point
        if tenor >= tenors[tenors.count - 1] {
            let lastDF = discountFactors[tenors.count - 1]
            let lastT = tenors[tenors.count - 1]
            guard lastT > 0 else { return 1.0 }
            let zeroR = -log(lastDF) / lastT // fp-safety:disable — guarded above
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
        return -log(df) / tenor // fp-safety:disable — tenor > 1e-15 from guard above
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
        return -(log(df2) - log(df1)) / interval // fp-safety:disable — abs(interval) > 1e-15 from guard above
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

    /// Where a gap year sits between the segment's two anchors, as a fraction.
    ///
    /// - Parameters:
    ///   - year: The gap year.
    ///   - lastKnownYear: The previous quoted tenor, or 0 for time zero.
    ///   - target: The quoted tenor being solved.
    /// - Returns: 0 at the left anchor, 1 at the right.
    private static func gapFraction(_ year: Int, from lastKnownYear: Int, to target: Int) -> Double {
        let span = target - lastKnownYear
        guard span > 0 else { return 0 }
        return Double(year - lastKnownYear) / Double(span) // fp-safety:disable — guarded above
    }

    /// A gap year's discount factor on the log-linear line between the two anchors.
    ///
    /// Written out three times before this: once in the Newton residual, once in its
    /// derivative, and once when the solved gaps were finally stored. Three copies of one
    /// interpolation is three chances for them to drift apart, and the residual and its
    /// derivative disagreeing is the kind of defect that shows up only as slow convergence.
    ///
    /// - Parameters:
    ///   - lnDFLast: `ln DF` at the left anchor; zero at time zero.
    ///   - terminal: The discount factor at the tenor being solved.
    ///   - frac: Where the gap year sits between them.
    /// - Returns: The interpolated discount factor.
    private static func gapDiscountFactor(lnDFLast: Double, terminal: Double, frac: Double) -> Double {
        let lnTerminal = log(max(terminal, 1e-300))
        let lnDFG = lnDFLast * (1.0 - frac) + lnTerminal * frac
        return exp(lnDFG)
    }

    /// The annuity of the years already solved, from 1 up to and including `lastKnownYear`.
    ///
    /// - Parameters:
    ///   - dfMap: Discount factors solved so far.
    ///   - lastKnownYear: The previous quoted tenor; 0 before anything is solved.
    /// - Returns: The sum of the settled discount factors, or zero when none are.
    private static func annuityOfSettledYears(_ dfMap: [Int: Double], through lastKnownYear: Int) -> Double {
        guard lastKnownYear >= 1 else { return 0 }
        var sum = 0.0
        for y in 1...lastKnownYear {
            if let df = dfMap[y] { sum += df }
        }
        return sum
    }

    /// Solves the par condition at one quoted tenor for its discount factor.
    ///
    /// The gap years between the anchors are not free: each is log-linear in the unknown,
    /// so the annuity is a function of it and the par equation
    ///
    ///     coupon * (settled + gaps(DF) + DF) + DF = 1
    ///
    /// is nonlinear. Newton on `DF` converges in a handful of steps from the par rate read
    /// as a flat zero rate.
    ///
    /// - Parameters:
    ///   - coupon: The par rate at this tenor.
    ///   - year: The tenor being solved.
    ///   - lastKnownYear: The previous quoted tenor, or 0 for time zero.
    ///   - lnDFLast: `ln DF` at the left anchor.
    ///   - sumKnown: The annuity of the already-settled years.
    /// - Returns: The discount factor at `year`, kept strictly positive.
    private static func solveTerminalDiscountFactor(
        coupon: Double, year: Int, lastKnownYear: Int,
        lnDFLast: Double, sumKnown: Double
    ) -> Double {
        var dfYear = exp(-coupon * Double(year))

        for _ in 0..<50 {
            var sumAll = sumKnown
            var dSumAll = 1.0  // the derivative of the DF(year) term itself
            for g in (lastKnownYear + 1)..<year {
                let frac = gapFraction(g, from: lastKnownYear, to: year)
                let dfG = gapDiscountFactor(lnDFLast: lnDFLast, terminal: dfYear, frac: frac)
                sumAll += dfG
                dSumAll += dfG * frac / max(dfYear, 1e-300)
            }
            sumAll += dfYear

            let fVal = coupon * sumAll + dfYear - 1.0
            let dfVal = coupon * dSumAll + 1.0
            guard abs(dfVal) > 1e-300 else { break }

            let step = fVal / dfVal
            dfYear -= step
            dfYear = max(dfYear, 1e-10)
            if abs(step) < 1e-15 { break }
        }
        return dfYear
    }

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

        // A first pass used to run here: it walked every integer year, bootstrapped the
        // quoted ones and interpolated the rest, and then threw the whole map away with a
        // `dfMap.removeAll()` before the real solve began. Its own trailing comment
        // explained why — years interpolated before their upper bracket existed were
        // anchored on the wrong neighbour — but the code was left in place, computing a
        // complete curve that nothing ever read. Nothing between it and the `removeAll`
        // touched `dfMap`, so deleting it is bit-identical; only the wasted work goes.


        var prevParYear = 0

        for entry in sorted {
            let year = Int(entry.tenor)
            let coupon = entry.rate

            // The left anchor for this segment: the previous quoted tenor, or time zero,
            // where the discount factor is 1 and so `ln DF` is 0. That second case is the
            // one that applies when nothing is quoted at year 1.
            let lastKnownYear = prevParYear
            let lastKnownDF: Double = lastKnownYear > 0 ? (dfMap[lastKnownYear] ?? 1.0) : 1.0
            guard lastKnownDF > 0 else { continue }
            let lnDFLast: Double = lastKnownYear > 0 ? log(lastKnownDF) : 0.0

            let sumKnown = annuityOfSettledYears(dfMap, through: lastKnownYear)

            let dfYear = solveTerminalDiscountFactor(
                coupon: coupon, year: year, lastKnownYear: lastKnownYear,
                lnDFLast: lnDFLast, sumKnown: sumKnown)

            for g in (lastKnownYear + 1)..<year {
                let frac = gapFraction(g, from: lastKnownYear, to: year)
                dfMap[g] = gapDiscountFactor(lnDFLast: lnDFLast, terminal: dfYear, frac: frac)
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
