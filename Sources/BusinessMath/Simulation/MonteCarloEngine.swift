//
//  MonteCarloEngine.swift
//  BusinessMath
//
//  Generic Monte Carlo pricing engine for path-dependent derivatives.
//

import Foundation
import Numerics

// MARK: - MonteCarloPricingResult

/// The result of a Monte Carlo pricing simulation.
///
/// Contains the estimated price, its standard error, and metadata about
/// the simulation configuration used to produce the estimate.
///
/// ## Interpretation
///
/// The ``price`` is the discounted expected payoff estimated by averaging
/// across ``pathCount`` simulation paths. The ``standardError`` quantifies
/// sampling uncertainty: the true price lies within approximately
/// `price +/- 2 * standardError` with 95% confidence.
///
/// Under ``antithetic`` sampling the paths come in negatively correlated pairs, so
/// ``pathCount`` is not the number of *independent* observations — the pair is. The
/// standard error is measured across the pair means and over their count, which is
/// what lets the interval narrow as the technique intends.
///
/// ## Example
///
/// ```swift
/// let gbm = GeometricBrownianMotion(name: "GBM", drift: 0.05, volatility: 0.20)
/// let call = EuropeanPayoff(strike: 100.0, optionType: .call)
///
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
    /// Computed as `sampleStdDev / sqrt(observations)`, where an observation is a single
    /// path in plain sampling and an antithetic *pair mean* under ``antithetic``.
    /// Decreases as path count increases, at a rate of `O(1/sqrt(N))`.
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
            // Generate N/2 pairs; each pair produces 2 paths. Antithetic sampling has no
            // meaning below one pair, so one pair is the floor — `paths / 2` is zero for a
            // single-path request, which left nothing to average and returned 0.0 / 0.0.
            // `pathCount` then reports the two paths, not the one that was asked for.
            pairsCount = Swift.max(1, paths / 2)
            effectivePaths = pairsCount * 2
        } else {
            pairsCount = paths
            effectivePaths = paths
        }

        var sumPayoffs = 0.0

        // The independent observations, accumulated by Welford's online algorithm. An
        // antithetic pair is negatively correlated by construction, so the unit that varies
        // independently is the pair *mean*, not the individual path.
        var observationCount = 0
        var observationMean = 0.0
        var sumSquaredDeviations = 0.0
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
            var observation = discountedOriginal

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
                observation = (discountedOriginal + discountedAntithetic) / 2.0
            }

            // Welford's update, not `E[X^2] - E[X]^2`. The textbook form subtracts two
            // nearly equal numbers, and where antithetic sampling cancels a payoff exactly
            // the true spread is rounding: the difference then loses every significant
            // digit and can come out negative. Welford's `M2` is a sum of products of two
            // deviations that always share a sign, so it cannot.
            observationCount += 1
            let delta: Double = observation - observationMean
            let count: Double = Double(observationCount)
            observationMean += delta / count // fp-safety:disable — observationCount was just incremented, so count >= 1
            let deltaAfterUpdate: Double = observation - observationMean
            sumSquaredDeviations += delta * deltaAfterUpdate
        }

        // The price averages every path, in the order it always has, so a pinned price
        // stays bit-identical; only the standard error below changes.
        let n = Double(effectivePaths)
        let mean = sumPayoffs / n // fp-safety:disable — effectivePaths >= 1: plain sampling guards paths > 0, antithetic floors at one pair

        // Sample variance of the observations, over their own count. Pooling 2N antithetic
        // paths as 2N independent draws ignores the negative correlation the technique
        // exists to create: it reports the plain-sampling spread and hides the whole
        // variance reduction, leaving the documented `price +/- 2 * standardError`
        // interval about 40% too wide.
        let m = Double(observationCount)
        let variance: Double
        if observationCount > 1 {
            variance = sumSquaredDeviations / (m - 1.0) // fp-safety:disable — observationCount >= 2 in this branch, so m - 1 >= 1
        } else {
            variance = 0.0
        }
        let standardError = variance >= 0 ? (variance.squareRoot() / m.squareRoot()) : 0.0

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
        // The shared transform, via the seed-taking form rather than
        // `boxMullerSeed(using:)`. The generator form draws `u₁ = 1 - random`, which
        // would reflect this engine's uniform and change every pinned price it has
        // ever produced; handing it the raw draw keeps the stream exactly where it was.
        // What changes is the guard: `max(u1, 1e-15)` was a clamp with an atom at
        // radius 8.31, reachable for u₁ below 1e-15 — about one draw in 10¹⁵ — and the
        // shared rule moves only the exact zero, one draw in 2⁵³.
        let u1 = openUnitUniform(Double.self, using: &rng)
        let u2 = openUnitUniform(Double.self, using: &rng)
        let (_, z): (Double, Double) = boxMullerSeed(u1, u2)
        return z
    }
}
