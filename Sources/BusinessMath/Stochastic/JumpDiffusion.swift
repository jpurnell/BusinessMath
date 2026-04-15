//
//  JumpDiffusion.swift
//  BusinessMath
//
//  Merton Jump-Diffusion: GBM + Poisson-distributed jumps
//

import RealModule

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

    // Internal state for deterministic jump generation
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
            let driftTerm = (drift - volatility * volatility / 2.0) * dt
            let diffusionTerm = volatility * dt.squareRoot() * normalDraws
            return current * Double.exp(driftTerm + diffusionTerm)
        }

        // Expected jump size for drift compensation
        let k = Double.exp(jumpMean + jumpVolatility * jumpVolatility / 2.0) - 1.0

        // GBM component with jump-compensated drift
        let adjustedDrift = drift - jumpIntensity * k
        let driftTerm = (adjustedDrift - volatility * volatility / 2.0) * dt
        let diffusionTerm = volatility * dt.squareRoot() * normalDraws

        // Poisson jump count using the normal draw to derive a uniform for Poisson
        // Transform normalDraws through the normal CDF to get a uniform [0,1]
        let poissonMean = jumpIntensity * dt
        let uniformForPoisson = normalCDF(normalDraws)
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
                let u1 = max(Double(u1Bits) / Double(UInt64.max), 1e-15)
                let u2 = Double(u2Bits) / Double(UInt64.max)
                let z = (-2.0 * Double.log(u1)).squareRoot() * Double.cos(2.0 * .pi * u2)
                jumpComponent += jumpMean + jumpVolatility * z
            }
        }

        return current * Double.exp(driftTerm + diffusionTerm + jumpComponent)
    }

    /// Approximate normal CDF for transforming normal draw to uniform.
    private func normalCDF(_ x: Double) -> Double {
        // Abramowitz & Stegun approximation
        let a1 = 0.254829592
        let a2 = -0.284496736
        let a3 = 1.421413741
        let a4 = -1.453152027
        let a5 = 1.061405429
        let p = 0.3275911

        let sign: Double = x < 0 ? -1.0 : 1.0
        let absX = abs(x)
        let t = 1.0 / (1.0 + p * absX)
        let y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * Double.exp(-absX * absX / 2.0)

        return 0.5 * (1.0 + sign * y)
    }

    /// Poisson inverse CDF: given uniform u, return smallest k where CDF(k) >= u.
    ///
    /// For small means (≤ 30), uses exact CDF computation.
    /// For large means (> 30), uses normal approximation: Poisson(λ) ≈ N(λ, λ).
    private func poissonInverseCDF(mean: Double, u: Double) -> Int {
        guard mean > 0, u > 0 else { return 0 }

        if mean > 30 {
            // Normal approximation for large lambda
            // Inverse normal CDF approximation (Beasley-Springer-Moro)
            let z = inverseNormalCDF(u)
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
            p *= mean / Double(k)
            cdf += p
        }

        return k
    }

    /// Simple inverse normal CDF (rational approximation).
    private func inverseNormalCDF(_ u: Double) -> Double {
        // Beasley-Springer-Moro approximation
        let a = [0.0, -3.969683028665376e+01, 2.209460984245205e+02,
                 -2.759285104469687e+02, 1.383577518672690e+02,
                 -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [0.0, -5.447609879822406e+01, 1.615858368580409e+02,
                 -1.556989798598866e+02, 6.680131188771972e+01,
                 -1.328068155288572e+01]
        let c = [0.0, -7.784894002430293e-03, -3.223964580411365e-01,
                 -2.400758277161838e+00, -2.549732539343734e+00,
                 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [0.0, 7.784695709041462e-03, 3.224671290700398e-01,
                 2.445134137142996e+00, 3.754408661907416e+00]

        let pLow = 0.02425
        let pHigh = 1.0 - pLow

        if u < pLow {
            let q = (-2.0 * Double.log(u)).squareRoot()
            return (((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) /
                   ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1.0)
        } else if u <= pHigh {
            let q = u - 0.5
            let r = q * q
            return (((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q /
                   (((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1.0)
        } else {
            let q = (-2.0 * Double.log(1.0 - u)).squareRoot()
            return -(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) /
                    ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1.0)
        }
    }
}
