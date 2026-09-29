//
//  CreditTermStructure.swift
//  BusinessMath
//
//  Bootstrap credit term structure from market CDS quotes
//

import Foundation
import Numerics

// MARK: - Hazard Rate Curve

/// Hazard rate curve with term structure of default intensities.
///
/// Stores piecewise constant hazard rates bootstrapped from market CDS quotes.
/// Provides methods to calculate survival probabilities, default probabilities,
/// and CDS spreads at any tenor.
///
/// ## Example
///
/// ```swift
/// let curve = bootstrapCreditCurve(
///     tenors: [1.0, 3.0, 5.0],
///     cdsSpreads: [0.0100, 0.0150, 0.0200],
///     recoveryRate: 0.40
/// )
///
/// let survival3yr = curve.survivalProbability(time: 3.0)
/// let default5yr = curve.defaultProbability(time: 5.0)
/// let spread4yr = curve.cdsSpread(maturity: 4.0, recoveryRate: 0.40)
/// ```
public struct HazardRateCurve<T: Real & BinaryFloatingPoint & Sendable>: Sendable {

    /// Time series of hazard rates (piecewise constant)
    public let hazardRates: TimeSeries<T>

    /// Initialize with hazard rate curve.
    ///
    /// - Parameter hazardRates: Time series of piecewise constant hazard rates
    public init(hazardRates: TimeSeries<T>) {
        self.hazardRates = hazardRates
    }

    /// Calculate survival probability at time t.
    ///
    /// The probability that default has not occurred by time t.
    ///
    /// Formula:
    /// ```
    /// S(t) = exp(-∫₀ᵗ λ(s) ds)
    /// ```
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Survival probability (0 to 1)
    public func survivalProbability(time: T) -> T {
        // `nan > 0` is false, so an unusable time returned a survival probability of 1 —
        // certain survival, the safest possible reading, for a name nobody could evaluate.
        // `ConstantHazardRate` and `TimeVaryingHazardRate` in `HazardRateModel.swift` have
        // no such guard and propagate correctly; this is the member of the family that
        // drifted. `time == 0` genuinely is certain survival and keeps its answer.
        guard !time.isNaN else { return T.nan }
        guard time > T.zero else { return T(1) }

        let integral = integrateHazardRate(upTo: time)
        return T.exp(-integral)
    }

    /// Calculate default probability by time t.
    ///
    /// The probability that default occurs on or before time t.
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Cumulative default probability (0 to 1)
    public func defaultProbability(time: T) -> T {
        return T(1) - survivalProbability(time: time)
    }

    /// Calculate forward hazard rate between two times.
    ///
    /// The instantaneous default intensity implied between two future dates.
    ///
    /// Formula:
    /// ```
    /// λ_forward = [∫₀ᵗ² λ(s) ds - ∫₀ᵗ¹ λ(s) ds] / (t₂ - t₁)
    /// ```
    ///
    /// - Parameters:
	///   - t1: Start time
	///   - t2: End time
    /// - Returns: Forward hazard rate
    public func forwardHazardRate(from t1: T, to t2: T) -> T {
        // See `survivalProbability(time:)`: a zero forward hazard is the safe end, and both
        // comparisons are false for a `nan`.
        guard !t1.isNaN, !t2.isNaN else { return T.nan }
        guard t2 > t1 else { return T.zero }

        let integral2 = integrateHazardRate(upTo: t2)
        let integral1 = integrateHazardRate(upTo: t1)

        return (integral2 - integral1) / (t2 - t1)
    }

    /// Calculate CDS spread for a given maturity.
    ///
    /// Uses the credit curve to price a CDS and extract the fair spread.
    ///
    /// - Parameters:
    ///   - maturity: CDS maturity in years. Must be finite, non-negative and no greater than
    ///     1,000; the premium leg is a quarterly schedule and a maturity outside that range
    ///     cannot be placed on it.
    ///   - recoveryRate: Expected recovery rate (default: 0.40)
    /// - Returns: Fair CDS spread as decimal, or `nan` when no spread exists: a maturity that
    ///   cannot be scheduled, or one shorter than a single quarter, where the premium schedule
    ///   is empty and the risky annuity is therefore zero.
    public func cdsSpread(maturity: T, recoveryRate: T = T(40) / T(100)) -> T {
        // `Int(_:)` on a floating-point value traps outright — on a non-finite value and on
        // anything outside `Int`'s range — and the number it produces here is also the trip
        // count of the schedule loop below, so a finiteness-only screen would swap the crash
        // for a loop that does not end. A maturity that cannot be put on a quarterly schedule
        // has no fair spread, and the caller is told exactly that. It is not told a number:
        // `T.zero` would read as a fair spread of 0 bp — protection on this name is free —
        // which is the misreading the guard at the foot of this same function documents, and
        // `survivalProbability(time:)` above already answers a `nan` time with `nan`.
        //
        // The upper bound is the schedule grid, not the credit market: 1,000 years is four
        // thousand quarterly dates, past any tenor that has ever been quoted and still small
        // enough to materialise.
        let maxTenorYears: T = T(1_000)
        guard maturity.isFinite, maturity >= T.zero, maturity <= maxTenorYears else {
            return T.nan
        }

        // Build discount curve (assume flat at 5% for simplicity)
        let riskFreeRate = T(5) / T(100)
        // Quarterly dates falling on or before maturity. This was `Int(maturity) * 4`, which
        // counted only the *whole years*: a 1.5-year CDS was priced off a one-year premium
        // leg, silently dropping the last two coupons. The `t <= maturity` filter below is
        // what the count has always been checked against, and it is what makes the corrected
        // count safe. For whole-year maturities the two expressions agree exactly.
        let quarterlyDates: T = maturity * T(4)
        let numPeriods = Int(quarterlyDates)
        var discountTimes: [T] = []
        var discountFactors: [T] = []

        // A half-open range: `1...numPeriods` traps when `numPeriods` is zero, which it is for
        // every maturity shorter than one quarter.
        for i in 1..<(numPeriods + 1) {
            let t = T(i) / T(4)
            if t <= maturity {
                discountTimes.append(t)
                discountFactors.append(T.exp(-riskFreeRate * t))
            }
        }

        // A maturity shorter than one quarter has no premium payment date at all, so the risky
        // annuity is zero and `protection / annuity` has no value. This used to return
        // `T.zero` and was unreachable while the loop above trapped first; zero here would say
        // the same thing the annuity guard below refuses to say, that protection is free.
        guard !discountTimes.isEmpty else { return T.nan }

        let periods = discountTimes.map { time -> Period in
            Period.year(Int(time) + 2024)
        }
        _ = TimeSeries<T>(periods: periods, values: discountFactors)  // Discount curve (for reference)

        // Calculate premium leg (risky annuity)
        let accrualPeriod = T(1) / T(4)  // Quarterly
        var premiumAnnuity = T.zero

        for i in 0..<discountTimes.count {
            let t = discountTimes[i]
            let df = discountFactors[i]
            let survival = survivalProbability(time: t)
            premiumAnnuity += df * survival * accrualPeriod
        }

        // Calculate protection leg
        let lossGivenDefault = T(1) - recoveryRate
        var protectionLeg = T.zero

        for i in 0..<discountTimes.count {
            let t = discountTimes[i]
            let df = discountFactors[i]

            // Marginal default probability in this period
            let survivalStart = i == 0 ? T(1) : survivalProbability(time: discountTimes[i-1])
            let survivalEnd = survivalProbability(time: t)
            let marginalDefault = survivalStart - survivalEnd

            protectionLeg += df * marginalDefault * lossGivenDefault
        }

        // Fair spread: protection / annuity.
        //
        // A `nan` annuity — one bad hazard rate on the curve makes `integrateHazardRate` and
        // therefore every survival probability `nan` — fails `> 0` and used to return zero: a
        // fair spread of 0 bp, i.e. protection on this name is free because it cannot default.
        // On a credit screen that ranks or thresholds fair spreads, the one name that could
        // not be evaluated sorted to the safest position in the book. `defaultProbability` on
        // the same object propagates correctly, so the two accessors disagreed about one curve.
        guard !premiumAnnuity.isNaN else { return premiumAnnuity }
        guard premiumAnnuity > T.zero else { return T.zero }
        return protectionLeg / premiumAnnuity
    }

    /// Integrate hazard rate from 0 to t using piecewise constant approximation
    private func integrateHazardRate(upTo time: T) -> T {
        let rates = hazardRates.valuesArray
        _ = hazardRates.periods  // Not used in integration

        guard !rates.isEmpty else { return T.zero }

        var integral = T.zero
        var currentTime = T.zero

        for i in 0..<rates.count {
            let rate = rates[i]

            // Determine time range for this hazard rate
            let nextTime: T
            if i < rates.count - 1 {
                nextTime = T(i + 1)  // Assume annual periods
            } else {
                nextTime = time
            }

            let endTime = min(nextTime, time)
            if endTime <= currentTime {
                break
            }

            let duration = endTime - currentTime
            integral += rate * duration

            currentTime = endTime
            if currentTime >= time {
                break
            }
        }

        // If time extends beyond curve, use last rate
        if currentTime < time && !rates.isEmpty {
            let lastRate = rates[rates.count - 1]
            integral += lastRate * (time - currentTime)
        }

        return integral
    }
}

// MARK: - Bootstrapping

/// Bootstrap credit curve from market CDS quotes.
///
/// Takes market CDS spreads at various tenors and calibrates a piecewise
/// constant hazard rate curve that reproduces these market quotes.
///
/// ## Algorithm
///
/// 1. Start with the shortest maturity
/// 2. For each tenor, solve for the hazard rate that matches the market spread
/// 3. Use previously bootstrapped rates for earlier periods
/// 4. Build a complete term structure
///
/// ## Example
///
/// ```swift
/// let curve = bootstrapCreditCurve(
///     tenors: [1.0, 3.0, 5.0, 7.0, 10.0],
///     cdsSpreads: [0.0050, 0.0100, 0.0150, 0.0175, 0.0200],
///     recoveryRate: 0.40
/// )
/// ```
///
/// - Parameters:
///   - tenors: Array of CDS maturities in years
///   - cdsSpreads: Array of market CDS spreads (as decimals)
///   - recoveryRate: Expected recovery rate (default: 0.40)
/// - Returns: Calibrated hazard rate curve
public func bootstrapCreditCurve<T: Real & BinaryFloatingPoint & Sendable>(
    tenors: [T],
    cdsSpreads: [T],
    recoveryRate: T = T(40) / T(100)
) -> HazardRateCurve<T> {
    guard tenors.count == cdsSpreads.count else {
        preconditionFailure("Tenors count (\(tenors.count)) must match spreads count (\(cdsSpreads.count))")
    }

    guard !tenors.isEmpty else {
        // Return empty curve
        let periods = [Period.year(2024)]
        let rates = [T.zero]
        return HazardRateCurve(hazardRates: TimeSeries(periods: periods, values: rates))
    }

    // Sort by tenor
    let sorted = zip(tenors, cdsSpreads).sorted { $0.0 < $1.0 }
    let sortedTenors = sorted.map { $0.0 }
    let sortedSpreads = sorted.map { $0.1 }

    // Bootstrap hazard rates
    var hazardRates: [T] = []

    for i in 0..<sortedTenors.count {
        let tenor = sortedTenors[i]
        let spread = sortedSpreads[i]

        // For first tenor, use simple approximation
        if i == 0 {
            // λ ≈ spread / (1 - R)
            let lossGivenDefault = T(1) - recoveryRate
            let hazard = spread / lossGivenDefault
            hazardRates.append(hazard)
        } else {
            // For later tenors, solve for hazard that matches market spread
            let hazard = bootstrapHazardRate(
                targetTenor: tenor,
                targetSpread: spread,
                previousTenors: Array(sortedTenors[0..<i]),
                previousRates: hazardRates,
                recoveryRate: recoveryRate
            )
            hazardRates.append(hazard)
        }
    }

    // Create time series
    let baseYear = 2024
    let periods = sortedTenors.enumerated().map { (i, _) in Period.year(baseYear + i) }
    let hazardCurve = TimeSeries(periods: periods, values: hazardRates)

    return HazardRateCurve(hazardRates: hazardCurve)
}

/// Bootstrap a single hazard rate to match a market CDS spread.
///
/// Uses iterative search to find the hazard rate that produces a CDS
/// spread matching the market quote, given previously bootstrapped rates.
private func bootstrapHazardRate<T: Real & BinaryFloatingPoint & Sendable>(
    targetTenor: T,
    targetSpread: T,
    previousTenors: [T],
    previousRates: [T],
    recoveryRate: T
) -> T {
    // Initial guess: use simple approximation
    let lossGivenDefault = T(1) - recoveryRate
    var hazard = targetSpread / lossGivenDefault

    // Newton-Raphson iteration to match market spread
    let maxIterations = 20
    let tolerance = T(1) / T(10000)  // 0.0001

    for _ in 0..<maxIterations {
        // Build temporary curve with current guess
        let allRates = previousRates + [hazard]
        let allTenors = previousTenors + [targetTenor]

        let tempCurve = buildTempCurve(tenors: allTenors, rates: allRates)

        // Calculate implied spread
        let impliedSpread = tempCurve.cdsSpread(maturity: targetTenor, recoveryRate: recoveryRate)

        // Check convergence
        let error = impliedSpread - targetSpread
        let absError = error < T.zero ? -error : error
        if absError < tolerance {
            break
        }

        // Update hazard rate (simple adjustment)
        // If implied spread too high, reduce hazard; if too low, increase hazard
        let adjustment = error * T(5) / T(10)  // Scale factor
        hazard = hazard - adjustment

        // Ensure hazard stays positive
        hazard = max(hazard, T(1) / T(10000))
    }

    return hazard
}

/// Build a temporary hazard rate curve for bootstrapping.
private func buildTempCurve<T: Real & BinaryFloatingPoint & Sendable>(tenors: [T], rates: [T]) -> HazardRateCurve<T> {
    let baseYear = 2024
    let periods = tenors.enumerated().map { (i, _) in Period.year(baseYear + i) }
    let hazardCurve = TimeSeries(periods: periods, values: rates)
    return HazardRateCurve(hazardRates: hazardCurve)
}
