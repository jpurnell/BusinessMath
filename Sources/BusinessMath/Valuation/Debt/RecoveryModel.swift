//
//  RecoveryModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2025-01-25.
//

import Foundation
import Numerics

// MARK: - Seniority

/// Debt seniority in capital structure
///
/// Seniority determines priority in bankruptcy and directly impacts recovery rates.
/// Higher seniority means earlier claim on assets in liquidation.
///
/// ## Recovery Rate Hierarchy
///
/// Typical recovery rates by seniority (historical averages):
/// - **Senior Secured**: 60-80% (collateralized, first priority)
/// - **Senior Unsecured**: 40-60% (unsecured, but senior claim)
/// - **Subordinated**: 20-40% (junior to senior debt)
/// - **Junior/Equity**: 0-20% (last in priority, often zero recovery)
///
/// ## Factors Affecting Recovery
///
/// Recovery rates vary based on:
/// - Industry (e.g., manufacturing vs. services)
/// - Asset tangibility (real estate vs. intellectual property)
/// - Economic cycle (recession vs. expansion)
/// - Jurisdiction (bankruptcy laws)
/// - Company-specific factors (asset quality, going concern value)
///
/// - SeeAlso: ``RecoveryModel`` for recovery rate calculations
public enum Seniority: Sendable, CaseIterable {
    /// Senior secured debt - highest priority, backed by collateral
    ///
    /// Typical recovery: **70%** (range: 60-80%)
    ///
    /// Examples:
    /// - Secured bank loans
    /// - Equipment financing
    /// - Mortgage bonds
    case seniorSecured

    /// Senior unsecured debt - unsecured but senior claim
    ///
    /// Typical recovery: **50%** (range: 40-60%)
    ///
    /// Examples:
    /// - Senior notes
    /// - Senior bonds
    /// - Trade credit
    case seniorUnsecured

    /// Subordinated debt - junior to senior debt
    ///
    /// Typical recovery: **30%** (range: 20-40%)
    ///
    /// Examples:
    /// - Subordinated notes
    /// - Mezzanine debt
    /// - Convertible bonds (debt component)
    case subordinated

    /// Junior debt - lowest priority among debt
    ///
    /// Typical recovery: **10%** (range: 0-20%)
    ///
    /// Examples:
    /// - Junior subordinated debt
    /// - Preferred stock (in some jurisdictions)
    /// - Deep subordinated notes
    case junior
}

// MARK: - Recovery Model

/// Model for estimating recovery rates and calculating loss given default
///
/// The Recovery Model provides standard recovery rates by seniority and enables
/// calculation of:
/// - Loss Given Default (LGD)
/// - Implied recovery rates from market spreads
/// - Expected Loss (EL)
///
/// ## Overview
///
/// Recovery rate is the fraction of exposure recovered after default. It varies by:
/// - **Seniority**: Senior debt recovers more than junior debt
/// - **Collateral**: Secured debt recovers more than unsecured
/// - **Industry**: Asset-heavy industries have higher recovery
/// - **Economic conditions**: Recessions reduce recovery rates
///
/// ## Key Relationships
///
/// ```
/// LGD = 1 - Recovery Rate
/// Expected Loss = PD × LGD × Exposure
/// Credit Spread ≈ PD × LGD / Maturity
/// ```
///
/// ## Usage Example
///
/// ```swift
/// let model = RecoveryModel<Double>()
///
/// // Standard recovery rate for senior unsecured
/// let recoveryRate = RecoveryModel.standardRecoveryRate(
///     seniority: .seniorUnsecured
/// )
/// // Returns 0.50 (50%)
///
/// // Calculate Loss Given Default
/// let lgd = model.lossGivenDefault(recoveryRate: recoveryRate)
/// // Returns 0.50 (50% loss)
///
/// // Calculate Expected Loss
/// let el = model.expectedLoss(
///     defaultProbability: 0.02,  // 2% PD
///     recoveryRate: recoveryRate,
///     exposure: 1_000_000.0      // $1M exposure
/// )
/// // Returns $10,000 (0.02 × 0.50 × $1M)
/// ```
///
/// ## Implied Recovery from Market Spreads
///
/// Market credit spreads embed assumptions about recovery rates:
///
/// ```swift
/// // Back out implied recovery from observed spread
/// let impliedRecovery = model.impliedRecoveryRate(
///     spread: 0.020,              // 200 bps spread
///     defaultProbability: 0.02,   // 2% PD
///     maturity: 5.0               // 5 years
/// )
/// ```
///
/// This is useful for:
/// - Calibrating models to market data
/// - Detecting mispricing opportunities
/// - Stress testing recovery assumptions
///
/// ## Important Notes
///
/// - Standard recovery rates are historical averages, not guarantees
/// - Actual recovery can vary significantly by situation
/// - Recovery rates tend to be procyclical (lower in recessions)
/// - Time to recovery matters (not modeled here)
/// - Recovery of par vs. market value distinction
///
/// - SeeAlso:
///   - ``Seniority`` for debt priority in capital structure
///   - ``CreditSpreadModel`` for spread calculations
public struct RecoveryModel<T: Real> where T: Sendable {

    public init() {}

    /// Standard recovery rate by seniority
    ///
    /// Returns industry-standard recovery rates based on historical data.
    /// These are typical values; actual recovery varies by situation.
    ///
    /// - Parameter seniority: Debt seniority level
    /// - Returns: Expected recovery rate as decimal (0 to 1)
    ///
    /// ## Recovery Rates by Seniority
    ///
    /// | Seniority | Recovery Rate | Range |
    /// |-----------|---------------|-------|
    /// | Senior Secured | 70% | 60-80% |
    /// | Senior Unsecured | 50% | 40-60% |
    /// | Subordinated | 30% | 20-40% |
    /// | Junior | 10% | 0-20% |
    ///
    /// ## Example
    ///
    /// ```swift
    /// let seniorSecured = RecoveryModel<Double>.standardRecoveryRate(
    ///     seniority: .seniorSecured
    /// )
    /// // Returns 0.70 (70%)
    ///
    /// let junior = RecoveryModel<Double>.standardRecoveryRate(
    ///     seniority: .junior
    /// )
    /// // Returns 0.10 (10%)
    /// ```
    ///
    /// ## Data Source
    ///
    /// Based on Moody's Ultimate Recovery Database and academic studies
    /// of corporate defaults.
    public static func standardRecoveryRate(seniority: Seniority) -> T {
        switch seniority {
        case .seniorSecured:
            // Senior secured debt: ~70% recovery
            return T(7) / T(10)
        case .seniorUnsecured:
            // Senior unsecured debt: ~50% recovery
            return T(1) / T(2)
        case .subordinated:
            // Subordinated debt: ~30% recovery
            return T(3) / T(10)
        case .junior:
            // Junior debt: ~10% recovery
            return T(1) / T(10)
        }
    }

    /// Calculate implied recovery rate from market spread
    ///
    /// Back-solves the credit spread formula to determine what recovery rate
    /// is implied by the observed market spread, given a default probability.
    ///
    /// ## Formula
    ///
    /// ```
    /// Spread ≈ PD × LGD / T = PD × (1 - R) / T
    /// Implied Recovery = 1 - (Spread × T) / PD
    /// ```
    ///
    /// Where:
    /// - Spread = Credit spread over risk-free rate
    /// - PD = Probability of default
    /// - R = Recovery rate
    /// - T = Time to maturity
    ///
    /// - Parameters:
    ///   - spread: Credit spread (as decimal, e.g., 0.020 for 200 bps)
    ///   - defaultProbability: Annual probability of default
    ///   - maturity: Time to maturity in years
    /// - Returns: Implied recovery rate (0 to 1)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = RecoveryModel<Double>()
    ///
    /// // Bond trades at 200 bps spread, 2% PD, 5-year maturity
    /// let impliedRecovery = model.impliedRecoveryRate(
    ///     spread: 0.020,
    ///     defaultProbability: 0.02,
    ///     maturity: 5.0
    /// )
    /// // Calculate what recovery the market is implying
    /// ```
    ///
    /// ## Use Cases
    ///
    /// - **Model Calibration**: Fit recovery assumptions to market prices
    /// - **Relative Value**: Compare implied recovery to historical norms
    /// - **Stress Testing**: Assess impact of recovery assumption changes
    ///
    /// ## Important Notes
    ///
    /// - Assumes constant hazard rate (simplified)
    /// - Implied recovery can be negative if spread is very high
    /// - Can exceed 100% if spread is very low (model breakdown)
    /// - Most reliable for investment-grade credits
    public func impliedRecoveryRate(
        spread: T,
        defaultProbability: T,
        maturity: T
    ) -> T {
        // Reverse the exact credit spread formula:
        // Spread = -ln(1 - PD × LGD × T) / T
        //
        // Solving for LGD:
        // spread × T = -ln(1 - PD × LGD × T)
        // exp(-spread × T) = 1 - PD × LGD × T
        // PD × LGD × T = 1 - exp(-spread × T)
        // LGD = (1 - exp(-spread × T)) / (PD × T)
        // Recovery = 1 - LGD

        let minPD = T(1) / T(10000)  // 0.0001
        let safePD = defaultProbability > minPD ? defaultProbability : minPD

        let minT = T(1) / T(100)  // 0.01 year
        let safeT = maturity > minT ? maturity : minT

        // Calculate LGD from spread
        let argument = -spread * safeT
        let expTerm = T.exp(argument)
        let numerator = T(1) - expTerm
        let denominator = safePD * safeT

        let impliedLGD = numerator / denominator
        let impliedRecovery = T(1) - impliedLGD

        return impliedRecovery
    }

    /// Calculate Loss Given Default (LGD)
    ///
    /// LGD is the complement of recovery rate - the fraction of exposure
    /// expected to be lost if default occurs.
    ///
    /// ## Formula
    ///
    /// ```
    /// LGD = 1 - Recovery Rate
    /// ```
    ///
    /// - Parameter recoveryRate: Expected recovery rate (0 to 1)
    /// - Returns: Loss given default (0 to 1)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = RecoveryModel<Double>()
    ///
    /// let lgd = model.lossGivenDefault(recoveryRate: 0.40)
    /// // Returns 0.60 (60% loss)
    /// ```
    ///
    /// ## Interpretation
    ///
    /// | Recovery Rate | LGD | Meaning |
    /// |---------------|-----|---------|
    /// | 100% | 0% | Full recovery |
    /// | 60% | 40% | Lose 40¢ per $1 |
    /// | 40% | 60% | Lose 60¢ per $1 |
    /// | 0% | 100% | Total loss |
    ///
    /// ## Usage in Credit Models
    ///
    /// LGD is a key input to:
    /// - Expected loss calculations
    /// - Credit spread determination
    /// - Regulatory capital (Basel III)
    /// - Economic capital models
    /// - Credit VaR calculations
    public func lossGivenDefault(recoveryRate: T) -> T {
        return T(1) - recoveryRate
    }

    /// Calculate Expected Loss (EL)
    ///
    /// Expected loss is the average loss expected over a time horizon,
    /// accounting for both default probability and severity.
    ///
    /// ## Formula
    ///
    /// ```
    /// Expected Loss = PD × LGD × Exposure
    ///               = PD × (1 - Recovery Rate) × Exposure
    /// ```
    ///
    /// - Parameters:
    ///   - defaultProbability: Annual probability of default (0 to 1)
    ///   - recoveryRate: Expected recovery rate (0 to 1)
    ///   - exposure: Exposure at default (same units as desired output)
    /// - Returns: Expected loss in same units as exposure
    ///
    /// ## Example
    ///
    /// ```swift
    /// let model = RecoveryModel<Double>()
    ///
    /// // $1M loan, 2% PD, 40% recovery
    /// let el = model.expectedLoss(
    ///     defaultProbability: 0.02,
    ///     recoveryRate: 0.40,
    ///     exposure: 1_000_000.0
    /// )
    /// // Returns $12,000
    /// // Calculation: 0.02 × (1 - 0.40) × $1M = 0.02 × 0.60 × $1M
    /// ```
    ///
    /// ## Components
    ///
    /// 1. **PD (Probability of Default)**: Chance of default occurring
    /// 2. **LGD (Loss Given Default)**: Severity if default occurs
    /// 3. **Exposure**: Amount at risk
    ///
    /// ## Use Cases
    ///
    /// - **Loan Loss Reserves**: CECL/IFRS 9 provisions
    /// - **Pricing**: Risk-adjusted return calculations
    /// - **Risk Management**: Portfolio credit risk
    /// - **Regulatory Capital**: Basel III EL calculations
    /// - **Economic Capital**: Unexpected loss = sqrt(Var(Loss) - EL²)
    ///
    /// ## Important Notes
    ///
    /// - This is an **average** - actual loss is binary (0 or LGD × Exposure)
    /// - Expected loss over 1 year; multi-year requires survival probabilities
    /// - Assumes independence (no contagion or systematic risk)
    /// - Exposure should be at default, not current (may include undrawn commitments)
    public func expectedLoss(
        defaultProbability: T,
        recoveryRate: T,
        exposure: T
    ) -> T {
        let lgd = lossGivenDefault(recoveryRate: recoveryRate)
        return defaultProbability * lgd * exposure
    }
}
