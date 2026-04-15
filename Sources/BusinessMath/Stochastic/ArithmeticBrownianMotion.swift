//
//  ArithmeticBrownianMotion.swift
//  BusinessMath
//
//  Arithmetic Brownian Motion: dS = μdt + σdW
//

import RealModule

/// Arithmetic Brownian Motion: a process with constant drift and diffusion.
///
/// The process evolves as:
///
///     dS = μ · dt + σ · dW
///
/// In discrete form:
///
///     S(t+dt) = S(t) + μ · dt + σ · √dt · Z
///
/// ## Key Property: Supports Negative Values
///
/// Unlike ``GeometricBrownianMotion``, ABM can produce negative values.
/// This is appropriate for:
/// - Financial futures (WTI went to -$37.63 in April 2020)
/// - Credit spreads (can compress to negative in distressed-to-performing transitions)
/// - Interest rate changes (rates can be negative)
/// - Any quantity where negative values are economically meaningful
///
/// ## When to Use
///
/// Use ABM when the underlying can go negative and returns are additive (not multiplicative).
/// For assets where negative values are not meaningful, use ``GeometricBrownianMotion``.
/// For mean-reverting quantities, use ``OrnsteinUhlenbeck``.
///
/// ## Example
///
/// ```swift
/// let futures = ArithmeticBrownianMotion(name: "WTI_Futures", drift: 0.5, volatility: 5.0)
/// let nextPrice = futures.step(from: 72.50, dt: 1.0/12.0, normalDraws: -2.0)
/// // nextPrice can be negative — that's valid for financial contracts
/// ```
public struct ArithmeticBrownianMotion: StochasticProcess, Sendable {
    /// The state type is a scalar.
    public typealias State = Double

    /// Process name for audit trails.
    public let name: String

    /// Annualized drift rate (μ).
    public let drift: Double

    /// Annualized volatility (σ).
    public let volatility: Double

    /// ABM can produce negative values.
    public let allowsNegativeValues: Bool = true

    /// ABM is driven by a single Brownian motion.
    public let factors: Int = 1

    /// Creates an Arithmetic Brownian Motion process.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - drift: Annualized drift rate (μ).
    ///   - volatility: Annualized volatility (σ). Must be non-negative.
    public init(name: String, drift: Double, volatility: Double) {
        self.name = name
        self.drift = drift
        self.volatility = volatility
    }

    /// Evolve the state by one time step.
    ///
    ///     S(t+dt) = S(t) + μ · dt + σ · √dt · Z
    ///
    /// - Parameters:
    ///   - current: Current state value.
    ///   - dt: Time step in years. If zero, returns current unchanged.
    ///   - normalDraws: Standard normal draw (Z ~ N(0,1)).
    /// - Returns: The state at the next time step. May be negative.
    public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        guard dt > 0 else { return current }
        return current + drift * dt + volatility * dt.squareRoot() * normalDraws
    }
}
