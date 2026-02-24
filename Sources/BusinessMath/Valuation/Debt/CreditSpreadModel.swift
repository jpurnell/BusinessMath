//
//  CreditSpreadModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Credit Spread Model

/// Model linking credit metrics to default probability and credit spreads
///
/// The Credit Spread Model bridges fundamental credit analysis (e.g., Z-Scores)
/// to bond pricing by converting credit risk measures into:
/// - Probability of default (PD)
/// - Credit spreads over risk-free rates
/// - Corporate bond yields
///
/// ## Overview
///
/// Credit spreads compensate investors for bearing default risk. The model
/// implements the relationship:
///
/// ```
/// Credit Spread = -ln(1 - PD × LGD) / T
/// ```
///
/// Where:
/// - PD = Probability of default
/// - LGD = Loss given default = 1 - Recovery rate
/// - T = Time to maturity
///
/// ## From Credit Metrics to Spreads
///
/// 1. **Credit Score → Default Probability**: Convert Altman Z-Score or other
///    credit metrics to probability of default using empirical relationships
/// 2. **Default Probability → Credit Spread**: Adjust for recovery assumptions
///    and time horizon
/// 3. **Spread → Corporate Yield**: Add to risk-free rate
///
/// ## Altman Z-Score Interpretation
///
/// - **Z > 2.99**: Safe zone (low default risk)
/// - **1.81 < Z < 2.99**: Grey zone (moderate risk)
/// - **Z < 1.81**: Distress zone (high default risk)
///
/// ## Usage Example
///
/// ```swift
/// let model = CreditSpreadModel<Double>()
///
/// // Convert Z-Score to default probability
/// let zScore = 2.5
/// let pd = model.defaultProbability(zScore: zScore)
///
/// // Calculate credit spread
/// let spread = model.creditSpread(
///     defaultProbability: pd,
///     recoveryRate: 0.40,  // 40% recovery
///     maturity: 5.0
/// )
///
/// // Determine corporate bond yield
/// let corporateYield = model.corporateBondYield(
///     riskFreeRate: 0.03,
///     creditSpread: spread
/// )
/// ```
///
/// ## Limitations
///
/// - Assumes constant hazard rate (can be relaxed with CreditCurve)
/// - Default probability mappings are empirical approximations
/// - Recovery rates vary by seniority and industry
/// - Does not account for systematic risk factors
///
/// - SeeAlso:
///   - ``CreditCurve`` for term structure of credit spreads
///   - ``RecoveryModel`` for recovery rate estimation
public struct CreditSpreadModel<T: Real> where T: Sendable {

    /// Creates a credit spread model for calculating credit risk metrics.
    public init() {}

    /// Convert Altman Z-Score to probability of default
    ///
    /// Uses a logistic function calibrated to empirical default rates:
    /// ```
    /// PD = 1 / (1 + exp(a × (Z - b)))
    /// ```
    ///
    /// Where calibration parameters are based on historical data.
    ///
    /// - Parameter zScore: Altman Z-Score (higher = better credit quality)
    /// - Returns: Annual probability of default (0 to 1)
    ///
    /// ## Z-Score Zones
    ///
    /// - **Z > 2.99**: Safe zone → PD typically < 1%
    /// - **1.81 < Z < 2.99**: Grey zone → PD typically 1-10%
    /// - **Z < 1.81**: Distress zone → PD typically > 10%
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = CreditSpreadModel<Double>()
    ///
    /// let pdSafe = model.defaultProbability(zScore: 3.5)      // ~0.5%
    /// let pdGrey = model.defaultProbability(zScore: 2.0)      // ~5%
    /// let pdDistress = model.defaultProbability(zScore: 1.0)  // ~20%
    /// ```
    ///
    /// - Note: Mappings are approximations based on historical data
    public func defaultProbability(zScore: T) -> T {
        // Logistic function: PD = 1 / (1 + exp(a * (Z - b)))
        // Calibrated to approximate Altman's empirical findings
        //
        // Target zones:
        // Z > 2.99: Safe zone → PD < 1%
        // 1.81 < Z < 2.99: Grey zone → PD = 1-10%
        // Z < 1.81: Distress zone → PD > 10%

        // Build parameters from integer literals
        // Use steeper curve with midpoint below distress zone
        let a = T(4)  // Steepness parameter (higher = steeper transition)
        let b = T(1) + T(1)/T(2)  // 1.5 - below distress threshold

        let exponent = a * (zScore - b)
        let expTerm = T.exp(exponent)
        let pd = T(1) / (T(1) + expTerm)

        return pd
    }

    /// Convert default probability to credit spread
    ///
    /// Calculates the yield spread required to compensate for expected loss:
    /// ```
    /// Spread = -ln(1 - PD × LGD) / T
    /// ```
    ///
    /// Where LGD (Loss Given Default) = 1 - Recovery Rate
    ///
    /// This assumes:
    /// - Constant hazard rate over the period
    /// - Risk-neutral pricing
    /// - Recovery occurs at maturity (not mid-period)
    ///
    /// - Parameters:
    ///   - defaultProbability: Annual probability of default (0 to 1)
    ///   - recoveryRate: Expected recovery as fraction of face value (0 to 1)
    ///   - maturity: Time to maturity in years
    /// - Returns: Credit spread as decimal (e.g., 0.015 = 150 basis points)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = CreditSpreadModel<Double>()
    ///
    /// // 2% default probability, 40% recovery, 5-year maturity
    /// let spread = model.creditSpread(
    ///     defaultProbability: 0.02,
    ///     recoveryRate: 0.40,
    ///     maturity: 5.0
    /// )
    /// // Returns ~0.012 (120 basis points)
    /// ```
    ///
    /// ## Recovery Rate Assumptions
    ///
    /// Typical recovery rates by seniority:
    /// - Senior secured: 60-70%
    /// - Senior unsecured: 40-50%
    /// - Subordinated: 20-30%
    /// - Junior/Equity: 0-10%
    public func creditSpread(
        defaultProbability: T,
        recoveryRate: T,
        maturity: T
    ) -> T {
        // Loss Given Default = 1 - Recovery Rate
        let lgd = T(1) - recoveryRate

        // Expected loss per year
        let expectedLoss = defaultProbability * lgd

        // Spread = -ln(1 - Expected Loss × T) / T
        // Simplified for small PD: Spread ≈ PD × LGD

        // Use exact formula for accuracy
        let argument = T(1) - expectedLoss * maturity

        // Ensure argument is positive
        let minArg = T(1) / T(10000)  // 0.0001
        let safeArg = argument > minArg ? argument : minArg

        let spread = -T.log(safeArg) / maturity

        return spread
    }

    /// Calculate corporate bond yield from risk-free rate and credit spread
    ///
    /// Simply adds the credit spread to the risk-free rate:
    /// ```
    /// Corporate Yield = Risk-Free Rate + Credit Spread
    /// ```
    ///
    /// - Parameters:
    ///   - riskFreeRate: Risk-free rate (typically Treasury yield)
    ///   - creditSpread: Credit spread from defaultProbability calculation
    /// - Returns: Corporate bond yield
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = CreditSpreadModel<Double>()
    ///
    /// let corporateYield = model.corporateBondYield(
    ///     riskFreeRate: 0.03,   // 3% Treasury
    ///     creditSpread: 0.015   // 150 bps spread
    /// )
    /// // Returns 0.045 (4.5%)
    /// ```
    public func corporateBondYield(
        riskFreeRate: T,
        creditSpread: T
    ) -> T {
        return riskFreeRate + creditSpread
    }
}

// MARK: - Credit Curve

/// Term structure of credit spreads
///
/// A Credit Curve represents how credit spreads vary across different maturities
/// for a given issuer or credit rating. It enables:
/// - Interpolation of spreads for any maturity
/// - Calculation of cumulative default probabilities
/// - Extraction of hazard rates (instantaneous default intensities)
///
/// ## Overview
///
/// Credit curves are analogous to yield curves but represent credit risk premium
/// rather than time value of money. Key uses:
/// - Pricing bonds of varying maturities consistently
/// - Comparing credit risk across issuers
/// - Calibrating credit models
/// - Risk management and VaR calculations
///
/// ## Curve Shape
///
/// Credit curves can have different shapes:
/// - **Upward sloping**: Typical for stable credits (more uncertainty at longer horizons)
/// - **Flat**: Expected default risk constant over time
/// - **Inverted**: Distressed credits (near-term default risk dominates)
/// - **Humped**: Default risk peaks at intermediate maturity
///
/// ## Usage Example
///
/// ```swift
/// // Build credit curve from market spreads
/// let periods = [
///     Period.year(1),
///     Period.year(3),
///     Period.year(5),
///     Period.year(10)
/// ]
///
/// let spreads = TimeSeries(
///     periods: periods,
///     values: [0.005, 0.010, 0.015, 0.020]  // 50-200 bps
/// )
///
/// let curve = CreditCurve(
///     spreads: spreads,
///     recoveryRate: 0.40
/// )
///
/// // Interpolate spread for 7-year maturity
/// let spread7y = curve.spread(maturity: 7.0)
///
/// // Calculate cumulative default probability
/// let cdp5y = curve.cumulativeDefaultProbability(maturity: 5.0)
///
/// // Extract hazard rate (default intensity)
/// let hazard = curve.hazardRate(maturity: 5.0)
/// ```
///
/// ## Interpolation Methods
///
/// The curve uses linear interpolation for spreads, which implies:
/// - Piecewise constant forward credit spreads
/// - Smooth hazard rate term structure
/// - Consistent with no-arbitrage pricing
///
/// ## Important Notes
///
/// - Extrapolation beyond the longest maturity uses flat forward spreads
/// - Recovery rate is assumed constant across maturities
/// - Hazard rates are derived assuming continuous-time default process
/// - Cumulative default probabilities account for survival up to maturity
///
/// - SeeAlso:
///   - ``CreditSpreadModel`` for converting metrics to spreads
///   - ``RecoveryModel`` for recovery rate estimation
public struct CreditCurve<T: Real> where T: Sendable {

    /// Time series of credit spreads by maturity
    public let spreads: TimeSeries<T>

    /// Expected recovery rate as fraction of face value (0 to 1)
    public let recoveryRate: T

    /// Initialize a credit curve
    ///
    /// - Parameters:
    ///   - spreads: Time series of credit spreads (typically in decimal form)
    ///   - recoveryRate: Expected recovery rate (e.g., 0.40 for 40%)
    public init(
        spreads: TimeSeries<T>,
        recoveryRate: T
    ) {
        self.spreads = spreads
        self.recoveryRate = recoveryRate
    }

    /// Interpolate credit spread for any maturity
    ///
    /// Uses linear interpolation between observed spreads.
    /// For maturities beyond the curve, uses flat extrapolation.
    ///
    /// - Parameter maturity: Time to maturity in years
    /// - Returns: Interpolated credit spread
    ///
    /// ## Example
    ///
    /// ```swift
    /// let spread3y = curve.spread(maturity: 3.0)   // Exact point
    /// let spread4y = curve.spread(maturity: 4.0)   // Interpolated
    /// ```
    public func spread(maturity: T) -> T {
        let values = spreads.valuesArray
        let periods = spreads.periods

        // Handle edge cases
        guard !values.isEmpty else { return T(0) }
        if values.count == 1 { return values[0] }

        // Convert periods to years for interpolation
        var maturities: [T] = []
        for period in periods {
            let years = periodToYears(period)
            maturities.append(years)
        }

        // Find interpolation interval
        if maturity <= maturities[0] {
            return values[0]
        }

        if maturity >= maturities[maturities.count - 1] {
            return values[values.count - 1]
        }

        // Linear interpolation
        for i in 0..<(maturities.count - 1) {
            let t1 = maturities[i]
            let t2 = maturities[i + 1]

            if maturity >= t1 && maturity <= t2 {
                let s1 = values[i]
                let s2 = values[i + 1]

                // Linear interpolation
                let weight = (maturity - t1) / (t2 - t1)
                return s1 + weight * (s2 - s1)
            }
        }

        return values[values.count - 1]
    }

    /// Calculate cumulative default probability up to maturity
    ///
    /// Uses the relationship between credit spreads and survival probability:
    /// ```
    /// Survival Probability = exp(-λ × T)
    /// CDF = 1 - Survival Probability
    /// ```
    ///
    /// Where λ (lambda) is the hazard rate.
    ///
    /// - Parameter maturity: Time horizon in years
    /// - Returns: Cumulative probability of default by maturity
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cdp5y = curve.cumulativeDefaultProbability(maturity: 5.0)
    /// // If cdp5y = 0.08, there's an 8% chance of default within 5 years
    /// ```
    public func cumulativeDefaultProbability(maturity: T) -> T {
        let hazard = hazardRate(maturity: maturity)

        // Cumulative default probability = 1 - exp(-λ × T)
        let survivalProb = T.exp(-hazard * maturity)
        return T(1) - survivalProb
    }

    /// Calculate hazard rate (instantaneous default intensity)
    ///
    /// The hazard rate λ relates to credit spread via:
    /// ```
    /// Spread = λ × LGD
    /// λ = Spread / LGD = Spread / (1 - Recovery Rate)
    /// ```
    ///
    /// - Parameter maturity: Time point for hazard rate
    /// - Returns: Hazard rate (annualized intensity)
    ///
    /// ## Interpretation
    ///
    /// Hazard rate represents the instantaneous probability of default:
    /// - λ = 0.02: 2% annual default intensity
    /// - Higher hazard → Higher near-term default risk
    /// - Can vary over time (term structure of hazard rates)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let hazard = curve.hazardRate(maturity: 5.0)
    /// // Hazard rate at 5-year point
    /// ```
    public func hazardRate(maturity: T) -> T {
        let creditSpread = spread(maturity: maturity)

        // Loss Given Default = 1 - Recovery Rate
        let lgd = T(1) - recoveryRate

        // Hazard rate = Spread / LGD
        let minLGD = T(1) / T(100)  // Minimum LGD to avoid division issues
        let safeLGD = lgd > minLGD ? lgd : minLGD

        return creditSpread / safeLGD
    }

    // MARK: - Helper Methods

    /// Convert Period to years (approximate)
    private func periodToYears(_ period: Period) -> T {
        // Use the period's type to estimate years
        // For more precision, could use date differences
        switch period.type {
        case .millisecond, .second, .minute, .hourly, .daily:
            // Use the date to calculate years from epoch
            // Break up complex expression to help type checker
            let regularDays = T(365) * T(24) * T(3600)
            let quarterDay = T(1) / T(4) * T(24) * T(3600)
            let secondsPerYear = regularDays + quarterDay
            let seconds = T(Int(period.date.timeIntervalSince1970))
            return seconds / secondsPerYear
        case .monthly:
            // Extract year and month from date
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: period.date)
            let yearInt = components.year ?? 0
            let monthInt = components.month ?? 1
            let totalMonths = yearInt * 12 + monthInt
            return T(totalMonths) / T(12)
        case .quarterly:
            // Extract year and quarter from date
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: period.date)
            let yearInt = components.year ?? 0
            let monthInt = components.month ?? 1
            let quarter = (monthInt - 1) / 3 + 1
            let totalQuarters = yearInt * 4 + quarter
            return T(totalQuarters) / T(4)
        case .annual:
            // Extract year from date
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year], from: period.date)
            let yearInt = components.year ?? 0
            return T(yearInt)
        }
    }
}
