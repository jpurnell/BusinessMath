//
//  JumpDiffusion.swift
//  BusinessMath
//
//  Merton Jump-Diffusion: GBM + Poisson-distributed jumps
//

import Numerics

/// Merton jump-diffusion process: GBM with Poisson-distributed jumps.
///
/// The process evolves as:
///
///     dS/S = (μ - λk)dt + σdW + JdN
///
/// where:
/// - μ is the drift
/// - σ is the diffusion volatility
/// - λ is the jump intensity (expected jumps per year)
/// - J is the log-jump size: ln(1 + J) ~ N(jumpMean, jumpVolatility²)
/// - N is a Poisson process with intensity λ
/// - k = E[e^J - 1] is the expected jump size
///
/// ## When to Use
///
/// Use jump-diffusion for assets subject to sudden price shocks:
/// - Commodity supply disruptions (pipeline explosion, OPEC announcement)
/// - Credit events (sudden downgrade, covenant breach)
/// - Geopolitical events (sanctions, wars)
///
/// The continuous component (GBM) captures normal market fluctuations.
/// The jump component captures tail events that GBM underestimates.
///
/// ## Example
///
/// ```swift
/// let oil = JumpDiffusion(
///     name: "WTI_Shock",
///     drift: 0.05, volatility: 0.25,
///     jumpIntensity: 2.0,     // ~2 shocks per year
///     jumpMean: -0.05,         // Average 5% down-jump
///     jumpVolatility: 0.10     // Jump size uncertainty
/// )
/// ```
///
/// ## Reference
///
/// Merton, R.C. (1976) "Option pricing when underlying stock returns are discontinuous"
public struct JumpDiffusion: StochasticProcess, Sendable {
    /// The state type is a scalar.
    public typealias State = Double

    /// Process name for audit trails.
    public let name: String

    /// Annualized drift rate (μ).
    public let drift: Double

    /// Annualized diffusion volatility (σ).
    public let volatility: Double

    /// Jump intensity (λ): expected number of jumps per year.
    public let jumpIntensity: Double

    /// Mean of the log-jump size distribution.
    ///
    /// Negative values model downward shocks (e.g., commodity price collapse).
    public let jumpMean: Double

    /// Volatility of the log-jump size distribution.
    ///
    /// Zero produces fixed-size jumps. Larger values create more dispersed jumps.
    public let jumpVolatility: Double

    /// Jump-diffusion cannot produce negative values (exponential form).
    public let allowsNegativeValues: Bool = false

    /// Jump-diffusion is driven by a single Brownian motion (plus Poisson jumps).
    public let factors: Int = 1

    // LIVE: reserved for future seeded jump generation
    private var jumpRNGState: UInt64 = 0

    /// Creates a Merton jump-diffusion process.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - drift: Annualized drift rate (μ).
    ///   - volatility: Annualized diffusion volatility (σ).
    ///   - jumpIntensity: Expected jumps per year (λ). Must be non-negative.
    ///   - jumpMean: Mean of log-jump size distribution.
    ///   - jumpVolatility: Volatility of log-jump size. Must be non-negative.
    public init(
        name: String,
        drift: Double,
        volatility: Double,
        jumpIntensity: Double,
        jumpMean: Double,
        jumpVolatility: Double
    ) {
        self.name = name
        self.drift = drift
        self.volatility = volatility
        self.jumpIntensity = jumpIntensity
        self.jumpMean = jumpMean
        self.jumpVolatility = jumpVolatility
    }

    /// Evolve the price by one time step with GBM dynamics plus Poisson jumps.
    ///
    /// The step combines:
    /// 1. GBM continuous component (drift-adjusted for jump compensation)
    /// 2. Poisson-distributed number of jumps in [t, t+dt]
    /// 3. Each jump has log-normal size: ln(J) ~ N(jumpMean, jumpVol²)
    ///
    /// The normalDraws parameter drives the diffusion. Jump randomness is
    /// derived deterministically from the normalDraws value to maintain
    /// reproducibility without requiring additional random inputs.
    ///
    /// - Parameters:
    ///   - current: Current price. If zero or negative, returned unchanged.
    ///   - dt: Time step in years.
    ///   - normalDraws: Standard normal draw for the diffusion component.
    /// - Returns: The price at the next time step. Always positive for positive input.
    public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
        guard current > 0, dt > 0 else { return current }
        guard jumpIntensity > 0 else {
            // No jumps — pure GBM
            let driftTerm = (drift - volatility * volatility / 2.0) * dt // fp-safety:disable — constant 2.0
            let diffusionTerm = volatility * dt.squareRoot() * normalDraws
            return current * Double.exp(driftTerm + diffusionTerm)
        }

        // Expected jump size for drift compensation
        let k = Double.exp(jumpMean + jumpVolatility * jumpVolatility / 2.0) - 1.0 // fp-safety:disable — constant 2.0

        // GBM component with jump-compensated drift
        let adjustedDrift = drift - jumpIntensity * k
        let driftTerm = (adjustedDrift - volatility * volatility / 2.0) * dt // fp-safety:disable — constant 2.0
        let diffusionTerm = volatility * dt.squareRoot() * normalDraws

        // Poisson jump count using the normal draw to derive a uniform for Poisson.
        //
        // Transform normalDraws through the normal CDF to get a uniform [0,1]. This called a
        // private Abramowitz & Stegun approximation that lived in this file, and it was not
        // merely less accurate than `T.erf` — it was **wrong**. A&S 7.1.26 approximates
        // `erf(x)` with `t = 1 / (1 + p*x)` *and* `exp(-x^2)` at the same argument, and
        // `Phi(x) = (1 + erf(x / sqrt 2)) / 2`, so both halves must take `x / sqrt 2`. The
        // local copy put `absX` in the polynomial and `absX^2 / 2` in the exponential, so the
        // two disagreed by a factor of sqrt 2. Measured against the true normal CDF:
        //
        // | x | true | as it was | error |
        // |---|---|---|---|
        // | 0.25 | 0.598706326 | 0.626677195 | 2.80e-02 |
        // | 0.50 | 0.691462461 | 0.728327668 | **3.69e-02** |
        // | 1.00 | 0.841344746 | 0.870328641 | 2.90e-02 |
        //
        // Nearly four points of probability at the peak. The same approximation applied
        // consistently errs by 6.9e-08, so the inconsistency cost a factor of 532,000.
        //
        // It mattered because this value is a *uniform*: the result feeds
        // `poissonInverseCDF`, and a transform that is not uniform biases the jump counts
        // away from the intensity the model was given. `BlackScholesModel` already recorded
        // moving off its own copy of this approximation for a smaller reason — 6.25e-04 on an
        // index-scale option — and this file kept one.
        let poissonMean = jumpIntensity * dt
        let uniformForPoisson = normalCDF(x: normalDraws)
        let jumpCount = poissonInverseCDF(mean: poissonMean, u: uniformForPoisson)

        // Accumulate jump component
        var jumpComponent = 0.0
        if jumpCount > 0 {
            // Derive jump sizes deterministically from normalDraws
            var jumpSeed = normalDraws.bitPattern &+ 7
            for _ in 0..<jumpCount {
                jumpSeed = jumpSeed &* 6364136223846793005 &+ 1442695040888963407
                let u1Bits = jumpSeed
                jumpSeed = jumpSeed &* 6364136223846793005 &+ 1442695040888963407
                let u2Bits = jumpSeed
                let u1 = Double(u1Bits) / Double(UInt64.max) // fp-safety:disable — UInt64.max is constant
                let u2 = Double(u2Bits) / Double(UInt64.max) // fp-safety:disable — UInt64.max is constant
                // The shared transform, taking `z2` — the cosine branch this site
                // already computed, so every value it has ever produced is
                // unchanged. What the shared routine replaces is the local pole
                // guard `max(u1, 1e-15)`, a clamp that would have put an atom at
                // radius 8.31; `boxMullerSeed` remaps only the single point u₁ = 0
                // and leaves the rest of the draw exactly uniform. Reachable only
                // when `u1Bits` is exactly zero, one LCG state in 2⁶⁴, so no output
                // moves in practice — the guard is right rather than merely rare.
                let (_, z): (Double, Double) = boxMullerSeed(u1, u2)
                jumpComponent += jumpMean + jumpVolatility * z
            }
        }

        return current * Double.exp(driftTerm + diffusionTerm + jumpComponent)
    }

    /// Poisson inverse CDF: given uniform u, return smallest k where CDF(k) >= u.
    ///
    /// For small means (≤ 30), uses exact CDF computation.
    /// For large means (> 30), uses normal approximation: Poisson(λ) ≈ N(λ, λ).
    private func poissonInverseCDF(mean: Double, u: Double) -> Int {
        guard mean > 0, u > 0 else { return 0 }

        if mean > 30 {
            // Normal approximation for large lambda: Poisson(λ) ≈ N(λ, λ).
            let z = inverseNormalCDF(p: u)
            let result = mean + mean.squareRoot() * z
            return max(0, Int(result.rounded()))
        }

        // Exact computation for small lambda
        let expNegMean = Double.exp(-mean)
        var p = expNegMean
        var cdf = p
        var k = 0

        while cdf < u && k < 200 {
            k += 1
            p *= mean / Double(k) // fp-safety:disable — k starts at 1 and increments
            cdf += p
        }

        return k
    }

}
