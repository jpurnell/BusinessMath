//
//  SABRModel.swift
//  BusinessMath
//
//  Created by Justin Purnell on 4/15/26.
//

import Foundation
import Numerics

// MARK: - SABRParameters

/// SABR model parameters for a single expiry.
///
/// The SABR (Stochastic Alpha Beta Rho) model is a stochastic volatility model
/// widely used for interest rate derivatives and equity options. It captures the
/// observed volatility smile/skew through a parsimonious set of parameters.
///
/// ## Usage
///
/// ```swift
/// let params = SABRParameters(alpha: 0.3, beta: 0.5, rho: -0.25, nu: 0.4)
/// let vol = params.impliedVol(forward: 100, strike: 110, timeToExpiry: 1.0)
/// ```
///
/// ## Parameters
///
/// - `alpha`: Controls the overall level of volatility. For beta=1 (lognormal),
///   ATM implied vol approximately equals alpha.
/// - `beta`: The CEV exponent controlling the backbone. beta=0 gives normal dynamics,
///   beta=1 gives lognormal dynamics.
/// - `rho`: Correlation between the forward rate and its volatility. Negative rho
///   produces a downward-sloping skew (higher vols for lower strikes).
/// - `nu`: Volatility of volatility. Higher nu produces more pronounced smile
///   (higher wing volatilities relative to ATM).
public struct SABRParameters: Sendable {
    /// Initial volatility level.
    public let alpha: Double
    /// CEV exponent (0 = normal, 1 = lognormal).
    public let beta: Double
    /// Spot-vol correlation, must be in (-1, 1).
    public let rho: Double
    /// Volatility of volatility, must be non-negative.
    public let nu: Double

    /// Creates a set of SABR model parameters.
    ///
    /// - Parameters:
    ///   - alpha: Initial volatility level. Must be positive.
    ///   - beta: CEV exponent in [0, 1]. 0 = normal dynamics, 1 = lognormal dynamics.
    ///   - rho: Spot-vol correlation in (-1, 1). Negative values produce downward skew.
    ///   - nu: Volatility of volatility. Must be non-negative.
    public init(alpha: Double, beta: Double, rho: Double, nu: Double) {
        self.alpha = alpha
        self.beta = beta
        self.rho = rho
        self.nu = nu
    }

    /// SABR implied volatility via the Hagan (2002) closed-form approximation.
    ///
    /// Computes the Black implied volatility for a given forward, strike, and time
    /// to expiry using the Hagan et al. (2002) asymptotic expansion.
    ///
    /// - Parameters:
    ///   - forward: The forward price of the underlying.
    ///   - strike: The option strike price. Must be positive.
    ///   - timeToExpiry: Time to expiration in years. Must be positive.
    /// - Returns: The SABR-implied Black volatility.
    public func impliedVol(forward: Double, strike: Double, timeToExpiry: Double) -> Double {
        guard forward > 0, strike > 0, timeToExpiry > 0, alpha > 0 else {
            return 0.0
        }

        let f = forward
        let k = strike
        let t = timeToExpiry

        // ATM case: F == K
        let fkRatio = abs(f - k) / max(f, k)
        if fkRatio < 1e-12 {
            return atmImpliedVol(forward: f, timeToExpiry: t)
        }

        let oneBeta = 1.0 - beta
        let fk = f * k
        let fkBetaHalf = Double.pow(fk, oneBeta / 2.0)
        let logFK = Double.log(f / k)

        // z and x(z) from Hagan (2002)
        let z = (nu / alpha) * fkBetaHalf * logFK
        let xz = xOfZ(z)

        // Leading term
        let numerator = alpha
        let a1 = oneBeta * oneBeta / 24.0 * logFK * logFK
        let a2 = oneBeta * oneBeta * oneBeta * oneBeta / 1920.0 * logFK * logFK * logFK * logFK
        let denominator = fkBetaHalf * (1.0 + a1 + a2)

        // Correction terms
        let term1 = oneBeta * oneBeta / 24.0 * alpha * alpha
            / Double.pow(fk, oneBeta)
        let term2 = 0.25 * rho * beta * nu * alpha / fkBetaHalf
        let term3 = (2.0 - 3.0 * rho * rho) / 24.0 * nu * nu
        let correction = 1.0 + (term1 + term2 + term3) * t

        return numerator / denominator * (z / xz) * correction
    }

    // MARK: - Private Helpers

    /// ATM implied vol (F == K case).
    private func atmImpliedVol(forward: Double, timeToExpiry: Double) -> Double {
        let oneBeta = 1.0 - beta
        let fBeta = Double.pow(forward, oneBeta)

        let term1 = oneBeta * oneBeta / 24.0 * alpha * alpha
            / (fBeta * fBeta)
        let term2 = 0.25 * rho * beta * nu * alpha / fBeta
        let term3 = (2.0 - 3.0 * rho * rho) / 24.0 * nu * nu
        let correction = 1.0 + (term1 + term2 + term3) * timeToExpiry

        return alpha / fBeta * correction
    }

    /// Computes x(z) = log((sqrt(1 - 2*rho*z + z^2) + z - rho) / (1 - rho)).
    private func xOfZ(_ z: Double) -> Double {
        guard abs(z) > 1e-12 else {
            return 1.0
        }
        let discriminant = 1.0 - 2.0 * rho * z + z * z
        guard discriminant > 0 else {
            return 1.0
        }
        let sqrtDisc = Double.sqrt(discriminant)
        let numerator = sqrtDisc + z - rho
        let denominator = 1.0 - rho

        guard denominator > 1e-15, numerator > 1e-15 else {
            return 1.0
        }

        return Double.log(numerator / denominator)
    }
}
