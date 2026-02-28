//
//  CDSPricing.swift
//  BusinessMath
//
//  Credit Default Swap pricing using ISDA standard model
//

import Foundation
import Numerics

// MARK: - Credit Default Swap

/// Credit Default Swap (CDS) contract.
///
/// A CDS is a financial derivative that allows an investor to "swap" or offset
/// their credit risk with that of another investor. The buyer makes periodic
/// premium payments and receives protection against default.
///
/// ## Two Legs of CDS
///
/// **Premium Leg**: Present value of premium payments
/// ```
/// PV(Premium) = Spread × Σ[DF(t) × Survival(t) × Δt]
/// ```
///
/// **Protection Leg**: Present value of default protection
/// ```
/// PV(Protection) = (1 - Recovery) × Σ[DF(t) × Default(t)]
/// ```
///
/// ## Fair Spread
///
/// The spread where PV(Premium) = PV(Protection)
///
/// ## Example
///
/// ```swift
/// let cds = CDS(
///     notional: 10_000_000,
///     spread: 0.0150,  // 150 bps
///     maturity: 5.0,
///     recoveryRate: 0.40,
///     paymentFrequency: .quarterly
/// )
///
/// let fairSpread = cds.fairSpread(
///     discountCurve: discountCurve,
///     hazardRate: 0.02
/// )
/// ```
public struct CDS<T: Real & Sendable>: Sendable where T: Sendable {

    // MARK: - Properties

    /// Notional amount of the contract
    public let notional: T

    /// Annual spread (premium) as a decimal (e.g., 0.0150 for 150 bps)
    public let spread: T

    /// Maturity of the contract in years
    public let maturity: T

    /// Expected recovery rate in the event of default (typically 0.40)
    public let recoveryRate: T

    /// Frequency of premium payments
    public let paymentFrequency: PaymentFrequency

    // MARK: - Initialization

    /// Initialize a Credit Default Swap contract.
    ///
    /// - Parameters:
    ///   - notional: Notional amount of protection
    ///   - spread: Annual premium spread (as decimal, e.g., 0.0150 for 150 bps)
    ///   - maturity: Years to maturity
    ///   - recoveryRate: Expected recovery rate (typically 0.40)
    ///   - paymentFrequency: Frequency of premium payments
    public init(
        notional: T,
        spread: T,
        maturity: T,
        recoveryRate: T,
        paymentFrequency: PaymentFrequency
    ) {
        self.notional = notional
        self.spread = spread
        self.maturity = maturity
        self.recoveryRate = recoveryRate
        self.paymentFrequency = paymentFrequency
    }

    // MARK: - Premium Leg Valuation

    /// Calculate present value of the premium leg.
    ///
    /// The premium leg is the present value of all premium payments,
    /// weighted by the probability that the reference entity survives
    /// to make each payment.
    ///
    /// Formula:
    /// ```
    /// PV(Premium) = Spread × Σ[DF(tᵢ) × S(tᵢ) × Δtᵢ]
    /// ```
    ///
    /// Where:
    /// - DF(t) = Discount factor at time t
    /// - S(t) = Survival probability at time t
    /// - Δt = Accrual period (e.g., 0.25 for quarterly)
    ///
    /// - Parameters:
    ///   - discountCurve: Discount factors for each payment date
    ///   - survivalProbabilities: Survival probabilities for each payment date
    /// - Returns: Present value of premium payments
    public func premiumLegPV(
        discountCurve: TimeSeries<T>,
        survivalProbabilities: TimeSeries<T>
    ) -> T {
        let periods = discountCurve.periods
        let discountFactors = discountCurve.valuesArray
        let survival = survivalProbabilities.valuesArray

        guard periods.count == survival.count else {
            return T.zero
        }

        // Accrual period based on payment frequency
        let accrualPeriod: T = {
            switch paymentFrequency {
            case .monthly: return T(1) / T(12)
            case .quarterly: return T(1) / T(4)
            case .semiAnnual: return T(1) / T(2)
            case .annual: return T(1)
            }
        }()

        var pv = T.zero
        for i in 0..<periods.count {
            let df = discountFactors[i]
            let s = survival[i]
            pv += df * s * accrualPeriod
        }

        return notional * spread * pv
    }

    // MARK: - Protection Leg Valuation

    /// Calculate present value of the protection leg.
    ///
    /// The protection leg is the present value of the protection payment
    /// in the event of default, weighted by the probability of default
    /// in each period.
    ///
    /// Formula:
    /// ```
    /// PV(Protection) = (1 - R) × Σ[DF(tᵢ) × (S(tᵢ₋₁) - S(tᵢ))]
    /// ```
    ///
    /// Where:
    /// - R = Recovery rate
    /// - S(tᵢ₋₁) - S(tᵢ) = Probability of default in period i
    ///
    /// - Parameters:
    ///   - discountCurve: Discount factors for each period
    ///   - survivalProbabilities: Survival probabilities for each period
    /// - Returns: Present value of protection payments
    public func protectionLegPV(
        discountCurve: TimeSeries<T>,
        survivalProbabilities: TimeSeries<T>
    ) -> T {
        let periods = discountCurve.periods
        let discountFactors = discountCurve.valuesArray
        let survival = survivalProbabilities.valuesArray

        guard periods.count == survival.count else {
            return T.zero
        }

        let lossGivenDefault = T(1) - recoveryRate

        var pv = T.zero
        var prevSurvival = T(1)  // Start at 100% survival

        for i in 0..<periods.count {
            let df = discountFactors[i]
            let s = survival[i]

            // Default probability in this period = previous survival - current survival
            let defaultProb = prevSurvival - s

            pv += df * defaultProb
            prevSurvival = s
        }

        return notional * lossGivenDefault * pv
    }

    // MARK: - Fair Spread Calculation

    /// Calculate the fair spread where PV(Premium) = PV(Protection).
    ///
    /// The fair spread is the annual premium that makes the CDS contract
    /// have zero value at inception (premium leg equals protection leg).
    ///
    /// Formula:
    /// ```
    /// Fair Spread = PV(Protection) / PV(Premium Annuity)
    /// ```
    ///
    /// - Parameters:
    ///   - discountCurve: Discount factors
    ///   - hazardRate: Constant hazard rate (instantaneous default probability)
    /// - Returns: Fair spread as a decimal (e.g., 0.0150 for 150 bps)
    public func fairSpread(
        discountCurve: TimeSeries<T>,
        hazardRate: T
    ) -> T {
        // Build survival curve from hazard rate
        let periods = discountCurve.periods
        let accrualPeriod: T = {
            switch paymentFrequency {
            case .monthly: return T(1) / T(12)
            case .quarterly: return T(1) / T(4)
            case .semiAnnual: return T(1) / T(2)
            case .annual: return T(1)
            }
        }()

        let maturities = periods.enumerated().map { (i, _) in
            T(i + 1) * accrualPeriod
        }

        let survivalProbs = maturities.map { t in
            T.exp(-hazardRate * t)
        }
        let survivalCurve = TimeSeries<T>(periods: periods, values: survivalProbs)

        // Calculate protection leg
        let protectionPV = protectionLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // Calculate premium annuity (premium leg with spread = 1.0)
        let tempCDS = CDS(
            notional: notional,
            spread: T(1),
            maturity: maturity,
            recoveryRate: recoveryRate,
            paymentFrequency: paymentFrequency
        )

        let premiumAnnuity = tempCDS.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        guard premiumAnnuity > T.zero else {
            return T.zero
        }

        return protectionPV / premiumAnnuity
    }

    // MARK: - Mark-to-Market

    /// Calculate mark-to-market value of an existing CDS position.
    ///
    /// The MTM represents the value gained or lost on a CDS position
    /// due to changes in market spreads.
    ///
    /// For a protection buyer:
    /// - Positive MTM: Market spread increased (bought protection cheaply)
    /// - Negative MTM: Market spread decreased (bought protection expensively)
    ///
    /// Formula:
    /// ```
    /// MTM = PV(Protection) - PV(Premium at contract spread)
    ///     = (Market Spread - Contract Spread) × PV(Premium Annuity)
    /// ```
    ///
    /// - Parameters:
    ///   - contractSpread: Original spread on the contract
    ///   - marketSpread: Current market spread
    ///   - discountCurve: Current discount curve
    ///   - hazardRate: Implied hazard rate from market spread
    /// - Returns: Mark-to-market value (positive = gain for protection buyer)
    public func mtm(
        contractSpread: T,
        marketSpread: T,
        discountCurve: TimeSeries<T>,
        hazardRate: T
    ) -> T {
        // Build survival curve
        let periods = discountCurve.periods
        let accrualPeriod: T = {
            switch paymentFrequency {
            case .monthly: return T(1) / T(12)
            case .quarterly: return T(1) / T(4)
            case .semiAnnual: return T(1) / T(2)
            case .annual: return T(1)
            }
        }()

        let maturities = periods.enumerated().map { (i, _) in
            T(i + 1) * accrualPeriod
        }

        let survivalProbs = maturities.map { t in
            T.exp(-hazardRate * t)
        }
        let survivalCurve = TimeSeries<T>(periods: periods, values: survivalProbs)

        // Calculate risky annuity (premium leg with spread = 1.0)
        let tempCDS = CDS(
            notional: notional,
            spread: T(1),
            maturity: maturity,
            recoveryRate: recoveryRate,
            paymentFrequency: paymentFrequency
        )

        let riskyAnnuity = tempCDS.premiumLegPV(
            discountCurve: discountCurve,
            survivalProbabilities: survivalCurve
        )

        // MTM = (Market Spread - Contract Spread) × Risky Annuity
        return (marketSpread - contractSpread) * riskyAnnuity
    }
}

// MARK: - Helper Functions

/// Build survival probabilities from a constant hazard rate.
///
/// For a constant hazard rate λ, the survival probability at time t is:
/// ```
/// S(t) = exp(-λt)
/// ```
///
/// - Parameters:
///   - hazardRate: Constant hazard rate (λ)
///   - maturities: Time points at which to calculate survival
/// - Returns: Array of survival probabilities
public func survivalProbabilities<T: Real>(
    hazardRate: T,
    maturities: [T]
) -> [T] {
    return maturities.map { t in
        T.exp(-hazardRate * t)
    }
}

/// Build survival probabilities from a credit spread curve.
///
/// Extracts survival probabilities from market credit spreads using
/// the relationship:
/// ```
/// Spread ≈ Hazard Rate × (1 - Recovery Rate)
/// ```
///
/// Then:
/// ```
/// S(t) = exp(-λt) where λ = Spread / (1 - R)
/// ```
///
/// - Parameters:
///   - creditCurve: Market credit spread curve
///   - discountCurve: Risk-free discount curve
/// - Returns: Time series of survival probabilities
public func survivalProbabilitiesFromSpreads<T: Real>(
    creditCurve: CreditCurve<T>,
    discountCurve: TimeSeries<T>
) -> TimeSeries<T> {
    let periods = creditCurve.spreads.periods
    let spreads = creditCurve.spreads.valuesArray
    let recovery = creditCurve.recoveryRate

    var survivalProbs: [T] = []
    var cumulativeTime = T.zero
    let timeStep = T(1) / T(4)  // Quarterly

    for (i, _) in periods.enumerated() {
        cumulativeTime = T(i + 1) * timeStep
        let spread = spreads[i]

        // Convert spread to hazard rate
        let hazardRate = spread / (T(1) - recovery)

        // Calculate survival probability
        let survival = T.exp(-hazardRate * cumulativeTime)
        survivalProbs.append(survival)
    }

    return TimeSeries<T>(periods: periods, values: survivalProbs)
}

// Note: CreditCurve is defined in CreditSpreadModel.swift (Phase 2)
