//
//  MonteCarloEngine.swift
//  BusinessMath
//
//  Generic Monte Carlo pricing engine for path-dependent derivatives.
//

import Foundation
import RealModule

// MARK: - MonteCarloPricingResult

/// The result of a Monte Carlo pricing simulation.
///
/// Contains the estimated price, its standard error, and metadata about
/// the simulation configuration used to produce the estimate.
///
/// ## Interpretation
///
/// The ``price`` is the discounted expected payoff estimated by averaging
/// across ``pathCount`` independent simulation paths. The ``standardError``
/// quantifies sampling uncertainty: the true price lies within approximately
/// `price +/- 2 * standardError` with 95% confidence.
///
/// ## Example
///
/// ```swift
/// let result = MonteCarloEngine.price(
///     process: gbm, payoff: call,
///     spot: 100, riskFreeRate: 0.05,
///     timeToExpiry: 1.0, steps: 252, paths: 10000, seed: 42
/// )
/// print("Price: \(result.price) +/- \(result.standardError)")
/// ```
public struct MonteCarloPricingResult: Sendable {
    /// The estimated option price (discounted expected payoff).
    public let price: Double

    /// The standard error of the price estimate.
    ///
    /// Computed as `sampleStdDev / sqrt(pathCount)`. Decreases as
    /// path count increases, at a rate of `O(1/sqrt(N))`.
    public let standardError: Double

    /// The number of Monte Carlo paths used in the simulation.
    public let pathCount: Int

    /// Whether antithetic variates were used to reduce variance.
    public let antithetic: Bool

    /// Creates a Monte Carlo pricing result.
    ///
    /// - Parameters:
    ///   - price: The estimated option price.
    ///   - standardError: The standard error of the estimate.
    ///   - pathCount: The number of simulation paths.
    ///   - antithetic: Whether antithetic variates were used.
    public init(price: Double, standardError: Double, pathCount: Int, antithetic: Bool) {
        self.price = price
        self.standardError = standardError
        self.pathCount = pathCount
        self.antithetic = antithetic
    }
}

// MARK: - MonteCarloEngine

/// A generic Monte Carlo engine for pricing path-dependent derivatives.
///
/// `MonteCarloEngine` generates price paths using any ``StochasticProcess``
/// with scalar state (`State == Double`), evaluates a ``Payoff`` along each path,
/// discounts the terminal value, and computes the sample mean and standard error.
///
/// ## Supported Features
///
/// - **Path-dependent payoffs:** Asian, barrier, lookback options observe each step.
/// - **Antithetic variates:** Halves the number of random draws needed and reduces
///   variance by pairing each path with its mirror (negated normal draws).
/// - **Deterministic reproducibility:** Same seed always produces the same price.
///
/// ## Example
///
/// ```swift
/// let gbm = GeometricBrownianMotion(name: "SPX", drift: 0.05, volatility: 0.20)
/// let call = EuropeanPayoff(strike: 100.0, optionType: .call)
///
/// let result = MonteCarloEngine.price(
///     process: gbm, payoff: call,
///     spot: 100.0, riskFreeRate: 0.05,
///     timeToExpiry: 1.0, steps: 252, paths: 10000,
///     seed: 42, antithetic: true
/// )
/// ```
///
/// ## Reference
///
/// Glasserman, P. (2003) "Monte Carlo Methods in Financial Engineering", Ch. 4.
public struct MonteCarloEngine: Sendable {

    /// Price a derivative using Monte Carlo simulation.
    ///
    /// Generates price paths by stepping a ``StochasticProcess`` forward in time,
    /// feeds each step to the ``Payoff`` via ``Payoff/observe(value:time:)``,
    /// evaluates the terminal payoff, discounts it, and averages across all paths.
    ///
    /// - Parameters:
    ///   - process: The stochastic process for the underlying. Must have `State == Double`.
    ///   - payoff: The payoff to evaluate. Mutated per-path via observe/reset.
    ///   - spot: Initial spot price of the underlying.
    ///   - riskFreeRate: Annualized risk-free rate for discounting.
    ///   - timeToExpiry: Total time horizon in years.
    ///   - steps: Number of discrete time steps per path.
    ///   - paths: Number of Monte Carlo paths to simulate.
    ///   - seed: Seed for the deterministic random number generator.
    ///   - antithetic: If `true`, use antithetic variates to reduce variance. Defaults to `false`.
    /// - Returns: A ``MonteCarloPricingResult`` containing the estimated price and standard error.
    public static func price<P: StochasticProcess, PO: Payoff>(
        process: P,
        payoff: PO,
        spot: Double,
        riskFreeRate: Double,
        timeToExpiry: Double,
        steps: Int,
        paths: Int,
        seed: UInt64,
        antithetic: Bool = false
    ) -> MonteCarloPricingResult where P.State == Double {
        guard paths > 0, steps > 0, timeToExpiry > 0 else {
            return MonteCarloPricingResult(price: 0.0, standardError: 0.0, pathCount: paths, antithetic: antithetic)
        }

        let dt = timeToExpiry / Double(steps)
        let discountFactor = Double.exp(-riskFreeRate * timeToExpiry)
        var rng = DeterministicRNG(seed: seed)

        let effectivePaths: Int
        let pairsCount: Int

        if antithetic {
            // Generate N/2 pairs; each pair produces 2 paths
            pairsCount = paths / 2
            effectivePaths = pairsCount * 2
        } else {
            pairsCount = paths
            effectivePaths = paths
        }

        var sumPayoffs = 0.0
        var sumPayoffsSquared = 0.0
        var payoffCopy = payoff

        for _ in 0..<pairsCount {
            // Generate normal draws for this path
            var normalDraws = [Double]()
            normalDraws.reserveCapacity(steps)
            for _ in 0..<steps {
                normalDraws.append(nextNormalDraw(using: &rng))
            }

            // Simulate the original path
            let originalPayoffValue = simulatePath(
                process: process,
                payoff: &payoffCopy,
                spot: spot,
                dt: dt,
                normalDraws: normalDraws
            )
            let discountedOriginal = originalPayoffValue * discountFactor
            sumPayoffs += discountedOriginal
            sumPayoffsSquared += discountedOriginal * discountedOriginal

            if antithetic {
                // Simulate the antithetic path (negated draws)
                let antitheticDraws = normalDraws.map { -$0 }
                let antitheticPayoffValue = simulatePath(
                    process: process,
                    payoff: &payoffCopy,
                    spot: spot,
                    dt: dt,
                    normalDraws: antitheticDraws
                )
                let discountedAntithetic = antitheticPayoffValue * discountFactor
                sumPayoffs += discountedAntithetic
                sumPayoffsSquared += discountedAntithetic * discountedAntithetic
            }
        }

        let n = Double(effectivePaths)
        let mean = sumPayoffs / n
        // Sample variance: E[X^2] - E[X]^2, with Bessel correction
        let variance: Double
        if effectivePaths > 1 {
            let meanOfSquares = sumPayoffsSquared / n
            let squareOfMean = mean * mean
            // Use n/(n-1) Bessel correction
            variance = (meanOfSquares - squareOfMean) * n / (n - 1.0)
        } else {
            variance = 0.0
        }
        let standardError = variance >= 0 ? (variance.squareRoot() / n.squareRoot()) : 0.0

        return MonteCarloPricingResult(
            price: mean,
            standardError: standardError,
            pathCount: effectivePaths,
            antithetic: antithetic
        )
    }

    // MARK: - Private Helpers

    /// Simulate a single price path and return the terminal payoff.
    ///
    /// - Parameters:
    ///   - process: The stochastic process.
    ///   - payoff: The payoff (reset and mutated).
    ///   - spot: Initial spot price.
    ///   - dt: Time step size.
    ///   - normalDraws: Pre-generated normal draws for each step.
    /// - Returns: The terminal payoff value (undiscounted).
    private static func simulatePath<P: StochasticProcess, PO: Payoff>(
        process: P,
        payoff: inout PO,
        spot: Double,
        dt: Double,
        normalDraws: [Double]
    ) -> Double where P.State == Double {
        payoff.reset()

        var current = spot
        var time = 0.0

        // Observe the initial spot
        payoff.observe(value: current, time: time)

        for draw in normalDraws {
            current = process.step(from: current, dt: dt, normalDraws: draw)
            time += dt
            payoff.observe(value: current, time: time)
        }

        return payoff.terminalValue(finalSpot: current)
    }

    /// Generate a standard normal draw using the Box-Muller transform.
    ///
    /// - Parameter rng: A mutable random number generator.
    /// - Returns: A standard normal variate (Z ~ N(0,1)).
    private static func nextNormalDraw(using rng: inout DeterministicRNG) -> Double {
        let u1 = max(Double.random(in: 0.0..<1.0, using: &rng), 1e-15)
        let u2 = Double.random(in: 0.0..<1.0, using: &rng)
        return (-2.0 * Double.log(u1)).squareRoot() * Foundation.cos(2.0 * Double.pi * u2)
    }
}
