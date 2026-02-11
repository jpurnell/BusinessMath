//
//  MertonModel.swift
//  BusinessMath
//
//  Merton structural model - treat equity as call option on firm assets
//

import Foundation
import Numerics

// MARK: - Merton Model

/// Merton Model for structural credit risk.
///
/// The Merton Model treats a firm's equity as a European call option on its assets,
/// with the strike price equal to the face value of debt. This provides a theoretical
/// framework for linking equity values to credit risk.
///
/// ## Key Relationships
///
/// **Equity as Call Option**:
/// ```
/// E = V × N(d₁) - D × e^(-rT) × N(d₂)
/// ```
///
/// **Debt Value**:
/// ```
/// D_value = D × e^(-rT) - Put_value
///         = V - E
/// ```
///
/// **Default Probability**:
/// ```
/// P(Default) = N(-d₂)
/// ```
///
/// Where:
/// - V = Asset value
/// - D = Debt face value
/// - E = Equity value
/// - r = Risk-free rate
/// - T = Time to maturity
/// - σ = Asset volatility
///
/// ## Example
///
/// ```swift
/// let model = MertonModel(
///     assetValue: 100_000_000,
///     assetVolatility: 0.25,
///     debtFaceValue: 80_000_000,
///     riskFreeRate: 0.05,
///     maturity: 1.0
/// )
///
/// let equityValue = model.equityValue()
/// let defaultProb = model.defaultProbability()
/// let creditSpread = model.creditSpread()
/// ```
public struct MertonModel<T: Real & Sendable>: Sendable {

    // MARK: - Properties

    /// Current value of firm's assets
    public let assetValue: T

    /// Volatility of firm's assets (as decimal, e.g., 0.25 for 25%)
    public let assetVolatility: T

    /// Face value of debt (strike price)
    public let debtFaceValue: T

    /// Risk-free interest rate (as decimal)
    public let riskFreeRate: T

    /// Time to debt maturity in years
    public let maturity: T

    // MARK: - Initialization

    /// Initialize a Merton Model.
    ///
    /// - Parameters:
    ///   - assetValue: Current market value of firm's assets
    ///   - assetVolatility: Volatility of asset returns
    ///   - debtFaceValue: Face value of zero-coupon debt
    ///   - riskFreeRate: Risk-free interest rate
    ///   - maturity: Years until debt matures
    public init(
        assetValue: T,
        assetVolatility: T,
        debtFaceValue: T,
        riskFreeRate: T,
        maturity: T
    ) {
        self.assetValue = assetValue
        self.assetVolatility = assetVolatility
        self.debtFaceValue = debtFaceValue
        self.riskFreeRate = riskFreeRate
        self.maturity = maturity
    }

    // MARK: - Equity Valuation

    /// Calculate equity value as a call option on firm assets.
    ///
    /// Equity holders have the right (but not obligation) to pay off debt
    /// and claim residual assets. This is equivalent to a call option with:
    /// - Underlying: Firm assets (V)
    /// - Strike: Debt face value (D)
    /// - Expiry: Debt maturity (T)
    ///
    /// Formula:
    /// ```
    /// E = V × N(d₁) - D × e^(-rT) × N(d₂)
    /// ```
    ///
    /// - Returns: Market value of equity
    public func equityValue() -> T {
        return BlackScholesModel<T>.price(
            optionType: .call,
            spotPrice: assetValue,
            strikePrice: debtFaceValue,
            timeToExpiry: maturity,
            riskFreeRate: riskFreeRate,
            volatility: assetVolatility
        )
    }

    // MARK: - Debt Valuation

    /// Calculate debt value as risk-free debt minus put option value.
    ///
    /// Risky debt can be viewed as:
    /// 1. Risk-free bond (D × e^(-rT))
    /// 2. Minus a put option (limited liability protection to equity holders)
    ///
    /// Alternatively: D_risky = V - E (by asset = equity + debt identity)
    ///
    /// - Returns: Market value of risky debt
    public func debtValue() -> T {
        // Use asset identity: Debt = Assets - Equity
        return assetValue - equityValue()
    }

    // MARK: - Credit Spread

    /// Calculate credit spread implied by the Merton model.
    ///
    /// The credit spread is the additional yield over the risk-free rate
    /// required to compensate for default risk.
    ///
    /// Formula:
    /// ```
    /// Spread = -(1/T) × ln(D_market / D_riskfree)
    /// ```
    ///
    /// Where:
    /// - D_market = Current market value of debt
    /// - D_riskfree = PV of face value at risk-free rate
    ///
    /// - Returns: Credit spread as a decimal (e.g., 0.0150 for 150 bps)
    public func creditSpread() -> T {
        let marketDebt = debtValue()
        let riskFreeDebt = debtFaceValue * T.exp(-riskFreeRate * maturity)

        guard marketDebt > T.zero && riskFreeDebt > T.zero else {
            return T.zero
        }

        let ratio = marketDebt / riskFreeDebt
        let spread = -T.log(ratio) / maturity

        return spread
    }

    // MARK: - Default Probability

    /// Calculate probability of default at maturity.
    ///
    /// Default occurs when asset value falls below debt face value.
    /// Under Merton's assumptions:
    ///
    /// ```
    /// P(Default) = P(V_T < D) = N(-d₂)
    /// ```
    ///
    /// Where N is the cumulative normal distribution and d₂ comes from
    /// the Black-Scholes formula.
    ///
    /// - Returns: Probability of default (0 to 1)
    public func defaultProbability() -> T {
        let d2 = calculateD2()
        return cumulativeNormal(-d2)
    }

    // MARK: - Distance to Default

    /// Calculate distance to default (standardized measure).
    ///
    /// Distance to default measures how many standard deviations the
    /// asset value is away from the default threshold.
    ///
    /// Formula:
    /// ```
    /// DD = [ln(V/D) + (r - 0.5σ²)T] / (σ√T)
    /// ```
    ///
    /// Interpretation:
    /// - DD > 3: Very safe
    /// - DD = 2: Moderate risk
    /// - DD < 1: High risk
    /// - DD < 0: Assets below debt (default territory)
    ///
    /// - Returns: Distance to default in standard deviations
    public func distanceToDefault() -> T {
        let numerator = T.log(assetValue / debtFaceValue) +
                       (riskFreeRate - T(1)/T(2) * assetVolatility * assetVolatility) * maturity
        let denominator = assetVolatility * T.sqrt(maturity)

        return numerator / denominator
    }

    // MARK: - Private Helpers

    /// Calculate d2 parameter from Black-Scholes formula
    private func calculateD2() -> T {
        let d1 = calculateD1()
        return d1 - assetVolatility * T.sqrt(maturity)
    }

    /// Calculate d1 parameter from Black-Scholes formula
    private func calculateD1() -> T {
        let numerator = T.log(assetValue / debtFaceValue) +
                       (riskFreeRate + T(1)/T(2) * assetVolatility * assetVolatility) * maturity
        let denominator = assetVolatility * T.sqrt(maturity)

        return numerator / denominator
    }

    /// Cumulative normal distribution function
    private func cumulativeNormal(_ x: T) -> T {
        return (T(1) + T.erf(x / T.sqrt(T(2)))) / T(2)
    }
}

// MARK: - Model Calibration

/// Error types for Merton model calibration
public enum MertonCalibrationError: Error, LocalizedError {
    case noConvergence
    case invalidInputs

    /// Human-readable error description.
    public var errorDescription: String? {
        switch self {
        case .noConvergence:
            return "Calibration failed to converge"
        case .invalidInputs:
            return "Invalid inputs for calibration"
        }
    }
}

/// Calibrate Merton Model from observable equity market data.
///
/// Given market equity value and volatility, solve for implied asset value
/// and asset volatility using iterative methods.
///
/// The system of equations:
/// ```
/// E = V × N(d₁) - D × e^(-rT) × N(d₂)
/// σ_E × E = σ_V × V × N(d₁)
/// ```
///
/// Uses Newton-Raphson iteration to solve simultaneously.
///
/// - Parameters:
///   - equityValue: Observed market equity value
///   - equityVolatility: Observed equity volatility
///   - debtFaceValue: Face value of debt
///   - riskFreeRate: Risk-free rate
///   - maturity: Time to debt maturity
/// - Returns: Calibrated Merton model
/// - Throws: `MertonCalibrationError` if calibration fails
public func calibrateMertonModel<T: Real>(
    equityValue: T,
    equityVolatility: T,
    debtFaceValue: T,
    riskFreeRate: T,
    maturity: T
) throws -> MertonModel<T> {
    // Input validation
    guard equityValue > T.zero,
          equityVolatility > T.zero,
          debtFaceValue > T.zero,
          maturity > T.zero else {
        throw MertonCalibrationError.invalidInputs
    }

    // Initial guess: Asset value = Equity + PV(Debt)
    var assetValue = equityValue + debtFaceValue * T.exp(-riskFreeRate * maturity)

    // Initial guess for asset volatility using leverage relationship
    // σ_V ≈ σ_E × (E / V)
    var assetVolatility = equityVolatility * (equityValue / assetValue)

    // Newton-Raphson iteration
    let maxIterations = 100
    let tolerance = T(1) / T(1000000)  // 0.000001

    for _ in 0..<maxIterations {
        let model = MertonModel(
            assetValue: assetValue,
            assetVolatility: assetVolatility,
            debtFaceValue: debtFaceValue,
            riskFreeRate: riskFreeRate,
            maturity: maturity
        )

        let impliedEquity = model.equityValue()
        let error = impliedEquity - equityValue

        // Check convergence
        let absError = error < T.zero ? -error : error
        if absError / equityValue < tolerance {
            return model
        }

        // Calculate gradient (derivative of equity w.r.t. asset value)
        // ∂E/∂V ≈ N(d₁)
        let logRatio = T.log(assetValue / debtFaceValue)
        let volSquared = assetVolatility * assetVolatility
        let drift = riskFreeRate + T(1)/T(2) * volSquared
        let numerator = logRatio + drift * maturity
        let denominator = assetVolatility * T.sqrt(maturity)
        let d1 = numerator / denominator
        let nd1 = cumulativeNormal(d1)

        // Update asset value using Newton step
        let step = error / nd1
        assetValue = assetValue - step

        // Ensure asset value stays positive and reasonable
        assetValue = max(assetValue, equityValue + debtFaceValue / T(10))

        // Update asset volatility estimate
        // Using σ_V ≈ σ_E × (E / V) × (1 / N(d₁))
        assetVolatility = equityVolatility * (equityValue / assetValue) / nd1
        assetVolatility = max(T(1)/T(100), min(assetVolatility, T(1)))  // Clamp to [0.01, 1.0]
    }

    throw MertonCalibrationError.noConvergence
}

// MARK: - Helper Functions

/// Cumulative normal distribution function
private func cumulativeNormal<T: Real>(_ x: T) -> T {
    return (T(1) + T.erf(x / T.sqrt(T(2)))) / T(2)
}

