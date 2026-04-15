//
//  GeometricBrownianMotion.swift
//  BusinessMath
//
//  Geometric Brownian Motion: dS = μSdt + σSdW
//

import RealModule

/// Geometric Brownian Motion: the standard model for equity and commodity spot prices.
///
/// The process evolves as:
///
///     dS = μ · S · dt + σ · S · dW
///
/// In discrete form (exact discretization):
///
///     S(t+dt) = S(t) · exp((μ - σ²/2) · dt + σ · √dt · Z)
///
/// where Z is a standard normal draw.
///
/// ## Properties
///
/// - **Always positive:** The exponential form guarantees S > 0 for S₀ > 0.
/// - **Log-normal returns:** ln(S(t)/S₀) ~ N((μ - σ²/2)t, σ²t)
/// - **Analytical moments:** E[S(T)] = S₀ · e^(μT), Var[S(T)] = S₀² · e^(2μT) · (e^(σ²T) - 1)
///
/// ## When to Use
///
/// Use GBM for assets where negative values are not meaningful:
/// - Equity spot prices
/// - Commodity physical delivery prices
/// - Exchange rates (though OU may be more appropriate for mean-reverting FX)
///
/// For assets that can go negative (financial futures, credit spreads),
/// use ``ArithmeticBrownianMotion`` or ``OrnsteinUhlenbeck`` instead.
///
/// ## Example
///
/// ```swift
/// let oil = GeometricBrownianMotion(name: "WTI", drift: 0.05, volatility: 0.25)
/// let nextPrice = oil.step(from: 72.50, dt: 1.0/12.0, normalDraws: 0.5)
/// // nextPrice ≈ 75.28
/// ```
///
/// ## Reference
///
/// Hull, J.C. (2018) "Options, Futures, and Other Derivatives", Ch. 14.
public struct GeometricBrownianMotion: StochasticProcess, Sendable {
    /// The state type is a scalar (single price).
    public typealias State = Double

    /// Process name for audit trails.
    public let name: String

    /// Annualized drift rate (μ).
    ///
    /// Under the risk-neutral measure, this equals the risk-free rate.
    /// Under the physical measure, this is the expected return.
    public let drift: Double

    /// Annualized volatility (σ).
    ///
    /// Standard deviation of log-returns on an annualized basis.
    public let volatility: Double

    /// GBM cannot produce negative values (exponential form).
    public let allowsNegativeValues: Bool = false

    /// GBM is driven by a single Brownian motion.
    public let factors: Int = 1

    /// Creates a Geometric Brownian Motion process.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - drift: Annualized drift rate (μ). Risk-free rate under Q, expected return under P.
    ///   - volatility: Annualized volatility (σ). Must be non-negative.
    public init(name: String, drift: Double, volatility: Double) {
        self.name = name
        self.drift = drift
        self.volatility = volatility
    }

    /// Evolve the price by one time step using exact discretization.
    ///
    /// Uses the log-normal exact solution rather than Euler-Maruyama,
    /// eliminating discretization bias:
    ///
    ///     S(t+dt) = S(t) · exp((μ - σ²/2) · dt + σ · √dt · Z)
    ///
    /// - Parameters:
    ///   - current: Current price. If zero or negative, returned unchanged.
    ///   - dt: Time step in years. If zero, returns current unchanged.
    ///   - normalDraws: Standard normal draw (Z ~ N(0,1)).
    /// - Returns: The price at the next time step. Always positive for positive input.
    public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        guard current > 0, dt > 0 else { return current }

        let driftTerm = (drift - volatility * volatility / 2.0) * dt
        let diffusionTerm = volatility * dt.squareRoot() * normalDraws

        return current * Double.exp(driftTerm + diffusionTerm)
    }
}
