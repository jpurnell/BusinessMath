//
//  HullWhiteProcess.swift
//  BusinessMath
//
//  Hull-White one-factor short rate model: dr = [θ(t) - κr(t)]dt + σdW
//

import RealModule

/// Hull-White one-factor short rate model.
///
/// The process evolves as:
///
///     dr(t) = [θ(t) - κ · r(t)] dt + σ · dW(t)
///
/// where κ is the mean-reversion speed, θ/κ is the long-run level
/// (simplified to constant θ), and σ is the volatility.
///
/// ## Exact Discretization
///
/// Uses the exact solution (not Euler-Maruyama) to eliminate discretization bias:
///
///     r(t+dt) = r(t)·e^(-κdt) + (θ/κ)·(1 - e^(-κdt)) + σ·√((1 - e^(-2κdt))/(2κ))·Z
///
/// ## Properties
///
/// - **Allows negative rates:** Short rates can go negative, consistent with
///   modern rate environments.
/// - **Mean-reverting:** Rates revert toward the long-run level θ/κ.
/// - **Analytically tractable:** Bond prices and European swaptions have
///   closed-form solutions.
///
/// ## When to Use
///
/// Use Hull-White for modeling the short rate in:
/// - Interest rate derivatives pricing (caps, floors, swaptions)
/// - Yield curve evolution under the risk-neutral measure
/// - CVA/DVA calculations requiring rate dynamics
///
/// For equity/commodity modeling, use ``GeometricBrownianMotion`` or
/// ``OrnsteinUhlenbeck`` instead.
///
/// ## Example
///
/// ```swift
/// let hw = HullWhiteProcess(name: "USD-3M", meanReversionSpeed: 0.1,
///                            longRunLevel: 0.03, volatility: 0.01)
/// let nextRate = hw.step(from: 0.025, dt: 1.0/12.0, normalDraws: 0.5)
/// ```
///
/// ## Reference
///
/// Hull, J. & White, A. (1990) "Pricing Interest-Rate-Derivative Securities"
public struct HullWhiteProcess: StochasticProcess, Sendable {
    /// The state type is a scalar (single short rate).
    public typealias State = Double

    /// Process name for audit trails.
    public let name: String

    /// Mean-reversion speed (κ).
    ///
    /// Higher values cause faster reversion to ``longRunLevel``.
    /// Must be non-negative. Zero disables mean reversion.
    public let meanReversionSpeed: Double

    /// Long-run equilibrium level (θ/κ).
    ///
    /// The rate reverts toward this level over time. In the full Hull-White model
    /// this would be time-dependent; here we use a constant for simplicity.
    public let longRunLevel: Double

    /// Volatility (σ).
    ///
    /// The diffusion coefficient controlling randomness of rate movements.
    public let volatility: Double

    /// Hull-White short rates can go negative.
    public let allowsNegativeValues: Bool = true

    /// Hull-White is driven by a single Brownian motion.
    public let factors: Int = 1

    /// Creates a Hull-White one-factor short rate process.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - meanReversionSpeed: Mean-reversion speed (κ). Must be non-negative.
    ///   - longRunLevel: Long-run equilibrium level (θ/κ).
    ///   - volatility: Volatility (σ). Must be non-negative.
    public init(name: String, meanReversionSpeed: Double, longRunLevel: Double, volatility: Double) {
        self.name = name
        self.meanReversionSpeed = meanReversionSpeed
        self.longRunLevel = longRunLevel
        self.volatility = volatility
    }

    /// Evolve the short rate by one time step using exact discretization.
    ///
    /// For κ > 0:
    ///
    ///     r(t+dt) = r(t)·e^(-κdt) + (θ/κ)·(1 - e^(-κdt)) + σ·√((1 - e^(-2κdt))/(2κ))·Z
    ///
    /// For κ = 0 (degenerate case, no mean reversion):
    ///
    ///     r(t+dt) = r(t) + σ·√dt·Z
    ///
    /// - Parameters:
    ///   - current: Current short rate.
    ///   - dt: Time step in years. If zero, returns current unchanged.
    ///   - normalDraws: Standard normal draw (Z ~ N(0,1)).
    /// - Returns: The short rate at the next time step.
    public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        guard dt > 0 else { return current }

        if meanReversionSpeed > 0 {
            let expKdt = Double.exp(-meanReversionSpeed * dt)
            let meanPart = current * expKdt + longRunLevel * (1.0 - expKdt)
            let variancePart = (1.0 - Double.exp(-2.0 * meanReversionSpeed * dt)) / (2.0 * meanReversionSpeed)
            let volPart = volatility * variancePart.squareRoot()
            return meanPart + volPart * normalDraws
        } else {
            // κ = 0: pure diffusion (no mean reversion)
            return current + volatility * dt.squareRoot() * normalDraws
        }
    }
}
