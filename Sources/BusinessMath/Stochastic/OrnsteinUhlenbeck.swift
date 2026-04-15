//
//  OrnsteinUhlenbeck.swift
//  BusinessMath
//
//  Ornstein-Uhlenbeck mean-reverting process: dX = κ(θ - X)dt + σdW
//

import RealModule

/// Ornstein-Uhlenbeck mean-reverting process.
///
/// The process evolves as:
///
///     dX = κ · (θ - X) · dt + σ · dW
///
/// where κ is the mean-reversion speed, θ is the long-run equilibrium,
/// and σ is the volatility.
///
/// ## Exact Discretization
///
/// Uses the exact solution (not Euler-Maruyama) to eliminate discretization bias:
///
///     X(t+dt) = X(t)·e^(-κdt) + θ·(1 - e^(-κdt)) + σ·√((1 - e^(-2κdt))/(2κ))·Z
///
/// ## Analytical Moments
///
/// - Expected value: E[X(t)] = θ + (x₀ - θ)·e^(-κt)
/// - Variance: Var[X(t)] = σ²/(2κ)·(1 - e^(-2κt))
/// - Stationary variance: σ²/(2κ) as t → ∞
///
/// ## When to Use
///
/// Use OU for quantities that mean-revert to an equilibrium:
/// - Commodity prices (oil reverts to marginal production cost)
/// - Credit spreads (revert to long-run average)
/// - Interest rates (central bank target acts as attractor)
/// - Volatility (mean-reverting around a long-run level)
///
/// OU allows negative values — appropriate for spreads and rates.
/// For assets where negative values are not meaningful, use ``GeometricBrownianMotion``.
///
/// ## Reference
///
/// Uhlenbeck, G.E. & Ornstein, L.S. (1930) "On the Theory of Brownian Motion"
public struct OrnsteinUhlenbeck: StochasticProcess, Sendable {
    /// The state type is a scalar.
    public typealias State = Double

    /// Process name for audit trails.
    public let name: String

    /// Mean-reversion speed (κ).
    ///
    /// Higher values cause faster reversion to ``longRunMean``.
    /// κ = 0 degenerates to arithmetic Brownian motion (no reversion).
    public let speed: Double

    /// Long-run equilibrium level (θ).
    ///
    /// The process reverts toward this value over time.
    public let longRunMean: Double

    /// Volatility (σ).
    ///
    /// The diffusion coefficient controlling randomness.
    public let volatility: Double

    /// OU can produce negative values (mean-reversion around any level).
    public let allowsNegativeValues: Bool = true

    /// OU is driven by a single Brownian motion.
    public let factors: Int = 1

    /// Creates an Ornstein-Uhlenbeck mean-reverting process.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - speed: Mean-reversion speed (κ). Must be non-negative. Zero disables reversion.
    ///   - longRunMean: Long-run equilibrium level (θ).
    ///   - volatility: Volatility (σ). Must be non-negative.
    public init(name: String, speed: Double, longRunMean: Double, volatility: Double) {
        self.name = name
        self.speed = speed
        self.longRunMean = longRunMean
        self.volatility = volatility
    }

    /// Evolve the state by one time step using exact discretization.
    ///
    /// For κ > 0:
    ///
    ///     X(t+dt) = X(t)·e^(-κdt) + θ·(1 - e^(-κdt)) + σ·√((1 - e^(-2κdt))/(2κ))·Z
    ///
    /// For κ = 0 (degenerate case, no mean reversion):
    ///
    ///     X(t+dt) = X(t) + σ·√dt·Z
    ///
    /// - Parameters:
    ///   - current: Current state value.
    ///   - dt: Time step in years.
    ///   - normalDraws: Standard normal draw (Z ~ N(0,1)).
    /// - Returns: The state at the next time step.
    public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        guard dt > 0 else { return current }

        if speed > 0 {
            let expKdt = Double.exp(-speed * dt)
            let meanPart = current * expKdt + longRunMean * (1.0 - expKdt)
            let variancePart = (1.0 - Double.exp(-2.0 * speed * dt)) / (2.0 * speed)
            let volPart = volatility * variancePart.squareRoot()
            return meanPart + volPart * normalDraws
        } else {
            // κ = 0: pure diffusion (no drift toward mean, no reversion)
            return current + volatility * dt.squareRoot() * normalDraws
        }
    }

    /// Analytical expected value at time t given initial value x₀.
    ///
    ///     E[X(t)] = θ + (x₀ - θ)·e^(-κt)
    ///
    /// - Parameters:
    ///   - initial: Starting value x₀.
    ///   - time: Time in years from start.
    /// - Returns: The expected value at time t.
    public func expectedValue(from initial: Double, at time: Double) -> Double {
        longRunMean + (initial - longRunMean) * Double.exp(-speed * time)
    }

    /// Analytical variance at time t.
    ///
    ///     Var[X(t)] = σ²/(2κ)·(1 - e^(-2κt))
    ///
    /// As t → ∞, this converges to the stationary variance σ²/(2κ).
    ///
    /// - Parameter time: Time in years from start.
    /// - Returns: The variance at time t.
    public func variance(at time: Double) -> Double {
        guard speed > 0 else {
            // κ = 0: variance grows linearly (Brownian motion)
            return volatility * volatility * time
        }
        return (volatility * volatility) / (2.0 * speed) * (1.0 - Double.exp(-2.0 * speed * time))
    }
}
