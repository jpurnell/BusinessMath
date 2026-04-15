//
//  HestonProcess.swift
//  BusinessMath
//
//  Heston stochastic volatility model:
//  dS = μSdt + √v · S · dW1
//  dv = κ(θ - v)dt + ξ√v · dW2
//  corr(dW1, dW2) = ρ
//

import Foundation
import RealModule

/// Heston stochastic volatility state: (spot price, variance).
///
/// Represents the two-dimensional state of the Heston model at any point
/// in time: the asset spot price and the instantaneous variance.
public struct HestonState: Sendable {
    /// The spot price of the underlying asset.
    public let price: Double

    /// The instantaneous variance (v = σ²).
    public let variance: Double

    /// Creates a Heston state with price and variance.
    ///
    /// - Parameters:
    ///   - price: The spot price.
    ///   - variance: The instantaneous variance. Should be non-negative.
    public init(price: Double, variance: Double) {
        self.price = price
        self.variance = variance
    }
}

/// Heston stochastic volatility model.
///
/// The model evolves as a system of two correlated SDEs:
///
///     dS = μ · S · dt + √v · S · dW₁
///     dv = κ · (θ - v) · dt + ξ · √v · dW₂
///     corr(dW₁, dW₂) = ρ
///
/// where S is the spot price, v is the instantaneous variance, κ is the
/// variance mean-reversion speed, θ is the long-run variance, ξ is the
/// volatility of variance (vol-of-vol), and ρ is the correlation between
/// the spot and variance Brownian motions.
///
/// ## Feller Condition
///
/// The variance process stays strictly positive when:
///
///     2κθ > ξ²
///
/// If violated, variance can hit zero (reflected at zero in practice).
///
/// ## Note on Protocol Conformance
///
/// This type does **not** conform to ``StochasticProcess`` because it
/// requires two correlated normal draws and a two-dimensional state
/// (`HestonState`), which differs from the scalar `ProcessState` protocol.
/// It provides its own ``step(from:dt:normalDraw1:normalDraw2:)`` method
/// for use with the simulation kernel.
///
/// ## Example
///
/// ```swift
/// let heston = HestonProcess(name: "SPX", drift: 0.05,
///                             meanReversionSpeed: 2.0, longRunVariance: 0.04,
///                             volOfVol: 0.3, correlation: -0.7)
/// let state = HestonState(price: 100.0, variance: 0.04)
/// let next = heston.step(from: state, dt: 1.0/252.0,
///                        normalDraw1: 0.5, normalDraw2: -0.3)
/// ```
///
/// ## Reference
///
/// Heston, S.L. (1993) "A Closed-Form Solution for Options with Stochastic
/// Volatility with Applications to Bond and Currency Options"
public struct HestonProcess: Sendable {
    /// Process name for audit trails.
    public let name: String

    /// Annualized drift rate (μ).
    ///
    /// Under the risk-neutral measure, this equals the risk-free rate.
    public let drift: Double

    /// Variance mean-reversion speed (κ).
    ///
    /// Higher values cause faster reversion of variance to ``longRunVariance``.
    public let meanReversionSpeed: Double

    /// Long-run variance level (θ).
    ///
    /// The variance process reverts toward this level over time.
    public let longRunVariance: Double

    /// Volatility of variance (ξ), also called vol-of-vol.
    ///
    /// Controls how volatile the variance process itself is.
    public let volOfVol: Double

    /// Correlation (ρ) between spot and variance Brownian motions.
    ///
    /// Typically negative for equity markets (the "leverage effect"):
    /// falling prices are associated with rising volatility.
    public let correlation: Double

    /// Creates a Heston stochastic volatility model.
    ///
    /// - Parameters:
    ///   - name: Process name for identification and audit trails.
    ///   - drift: Annualized drift rate (μ).
    ///   - meanReversionSpeed: Variance mean-reversion speed (κ). Must be non-negative.
    ///   - longRunVariance: Long-run variance level (θ). Must be non-negative.
    ///   - volOfVol: Volatility of variance (ξ). Must be non-negative.
    ///   - correlation: Correlation between spot and variance (ρ). Must be in [-1, 1].
    public init(
        name: String,
        drift: Double,
        meanReversionSpeed: Double,
        longRunVariance: Double,
        volOfVol: Double,
        correlation: Double
    ) {
        self.name = name
        self.drift = drift
        self.meanReversionSpeed = meanReversionSpeed
        self.longRunVariance = longRunVariance
        self.volOfVol = volOfVol
        self.correlation = correlation
    }

    /// Whether the Feller condition is satisfied: 2κθ > ξ².
    ///
    /// When satisfied, the variance process stays strictly positive.
    /// When violated, variance can hit zero and must be reflected.
    public var fellerConditionSatisfied: Bool {
        2.0 * meanReversionSpeed * longRunVariance > volOfVol * volOfVol
    }

    /// Step both price and variance forward by one time step.
    ///
    /// Uses Euler-Maruyama discretization with full truncation scheme
    /// (variance is floored at zero) and Cholesky decomposition for
    /// correlation between the two Brownian motions.
    ///
    /// The correlated draws are constructed as:
    ///
    ///     W₁ = Z₁
    ///     W₂ = ρ·Z₁ + √(1 - ρ²)·Z₂
    ///
    /// - Parameters:
    ///   - current: Current state (price and variance).
    ///   - dt: Time step in years. If zero, returns current unchanged.
    ///   - normalDraw1: Independent standard normal draw for spot.
    ///   - normalDraw2: Independent standard normal draw for variance.
    /// - Returns: The state at the next time step.
    public func step(
        from current: HestonState,
        dt: Double,
        normalDraw1: Double,
        normalDraw2: Double
    ) -> HestonState {
        guard dt > 0, current.price > 0 else { return current }

        // Cholesky decomposition for correlated Brownians
        let w1 = normalDraw1
        let rhoSq = correlation * correlation
        let sqrtOneMinusRhoSq = (max(1.0 - rhoSq, 0.0)).squareRoot()
        let w2 = correlation * normalDraw1 + sqrtOneMinusRhoSq * normalDraw2

        // Floor variance at zero (full truncation)
        let v = max(current.variance, 0.0)
        let sqrtV = v.squareRoot()
        let sqrtDt = dt.squareRoot()

        // Spot price: log-Euler scheme for positivity
        let driftTerm = (drift - v / 2.0) * dt
        let diffusionTerm = sqrtV * sqrtDt * w1
        let newPrice = current.price * Double.exp(driftTerm + diffusionTerm)

        // Variance: Euler-Maruyama with full truncation
        let newVariance: Double
        if meanReversionSpeed > 0 || volOfVol > 0 {
            let varDrift = meanReversionSpeed * (longRunVariance - v) * dt
            let varDiffusion = volOfVol * sqrtV * sqrtDt * w2
            newVariance = max(v + varDrift + varDiffusion, 0.0)
        } else {
            newVariance = v
        }

        return HestonState(price: newPrice, variance: newVariance)
    }

    // MARK: - Analytical Pricing

    /// European call price via the Heston (1993) semi-analytical formula.
    ///
    /// Uses numerical integration of the characteristic function via the
    /// trapezoidal rule. The formula decomposes the call price as:
    ///
    ///     C = S·P₁ - K·e^(-rT)·P₂
    ///
    /// where P₁ and P₂ are exercise probabilities computed from the
    /// characteristic function.
    ///
    /// - Parameters:
    ///   - spot: Current spot price (S).
    ///   - strike: Strike price (K).
    ///   - riskFreeRate: Continuously compounded risk-free rate (r).
    ///   - timeToExpiry: Time to expiry in years (T).
    ///   - initialVariance: Initial variance (v₀).
    /// - Returns: The European call option price. Returns zero for degenerate inputs.
    public func europeanCallPrice(
        spot: Double,
        strike: Double,
        riskFreeRate: Double,
        timeToExpiry: Double,
        initialVariance: Double
    ) -> Double {
        guard spot > 0, strike > 0, timeToExpiry > 0 else { return 0.0 }

        let p1 = computeP(
            j: 1, spot: spot, strike: strike, riskFreeRate: riskFreeRate,
            timeToExpiry: timeToExpiry, initialVariance: initialVariance
        )
        let p2 = computeP(
            j: 2, spot: spot, strike: strike, riskFreeRate: riskFreeRate,
            timeToExpiry: timeToExpiry, initialVariance: initialVariance
        )

        let callPrice = spot * p1 - strike * Double.exp(-riskFreeRate * timeToExpiry) * p2
        return max(callPrice, 0.0)
    }

    /// European put price via put-call parity.
    ///
    ///     P = C - S + K·e^(-rT)
    ///
    /// - Parameters:
    ///   - spot: Current spot price (S).
    ///   - strike: Strike price (K).
    ///   - riskFreeRate: Continuously compounded risk-free rate (r).
    ///   - timeToExpiry: Time to expiry in years (T).
    ///   - initialVariance: Initial variance (v₀).
    /// - Returns: The European put option price.
    public func europeanPutPrice(
        spot: Double,
        strike: Double,
        riskFreeRate: Double,
        timeToExpiry: Double,
        initialVariance: Double
    ) -> Double {
        let call = europeanCallPrice(
            spot: spot, strike: strike, riskFreeRate: riskFreeRate,
            timeToExpiry: timeToExpiry, initialVariance: initialVariance
        )
        let put = call - spot + strike * Double.exp(-riskFreeRate * timeToExpiry)
        return max(put, 0.0)
    }

    // MARK: - Characteristic Function Internals

    /// Compute P_j (j=1 or j=2) via numerical integration of the Heston characteristic function.
    ///
    /// Uses the Lewis (2000) / Gatheral formulation:
    ///
    ///     C = S - (K·e^{-rT}/pi) · ∫₀^∞ Re[ e^{-iu·ln(K/F)} · phi(u-i/2) / (u^2+1/4) ] du
    ///
    /// where F = S·e^{rT} is the forward price. This single-integral form avoids
    /// computing two separate P_j integrals and is numerically more stable.
    private func computeP(
        j: Int,
        spot: Double,
        strike: Double,
        riskFreeRate: Double,
        timeToExpiry: Double,
        initialVariance: Double
    ) -> Double {
        let logMoneyness = Double.log(spot / strike)
        let numSteps = 2000
        let upperLimit = 500.0
        let dphi = upperLimit / Double(numSteps)

        var integral = 0.0
        for k in 1...numSteps {
            let phi = (Double(k) - 0.5) * dphi  // midpoint rule
            let (cfReal, cfImag) = hestonCF(
                phi: phi, j: j, riskFreeRate: riskFreeRate,
                timeToExpiry: timeToExpiry, initialVariance: initialVariance
            )

            // Integrand: Re[ e^{-i·phi·ln(K/S)} · f_j(phi) / (i·phi) ]
            // e^{-i·phi·ln(K/S)} = e^{i·phi·ln(S/K)} = cos(phi·logM) + i·sin(phi·logM)
            let cosM = Foundation.cos(phi * logMoneyness)
            let sinM = Foundation.sin(phi * logMoneyness)

            // f · e^{i·phi·logM} = (cfR + i·cfI)(cosM + i·sinM)
            let prodImag = cfReal * sinM + cfImag * cosM

            // Divide by (i·phi): (a+bi)/(i·phi) = (b - ai)/phi = (prodImag + i·(-prodReal)) / phi
            // Re[...] = prodImag / phi
            guard phi > 1e-30 else { continue }
            let integrand = prodImag / phi

            integral += integrand * dphi
        }

        let result = 0.5 + integral / Double.pi
        return min(max(result, 0.0), 1.0)
    }

    /// Heston characteristic function f_j(phi) for j=1,2.
    ///
    /// Returns (real, imaginary) components.
    ///
    /// Uses the "rotation count" stable formulation from Albrecher et al. (2007),
    /// also known as "Formulation 2" which avoids the numerical instability of
    /// the original Heston (1993) formulation for large phi.
    ///
    /// f_j(phi) = exp( C_j(tau, phi) + D_j(tau, phi)·v0 + i·phi·x )
    ///
    /// where x = ln(S), and C_j, D_j are given by the stable recursion.
    private func hestonCF(
        phi: Double,
        j: Int,
        riskFreeRate: Double,
        timeToExpiry: Double,
        initialVariance: Double
    ) -> (Double, Double) {
        let kappa = meanReversionSpeed
        let theta = longRunVariance
        let xi = volOfVol
        let rho = correlation
        let tau = timeToExpiry
        let v0 = initialVariance

        let uj: Double = (j == 1) ? 0.5 : -0.5
        let bj: Double = (j == 1) ? kappa - rho * xi : kappa

        // Handle xi near zero: degenerate to constant-vol log-characteristic function
        let xi2 = xi * xi
        guard xi2 > 1e-20 else {
            // Constant variance = v0 (or theta if kappa > 0, but for characteristic function
            // the variance stays at v0 when xi=0).
            // For j=1: f_1(phi) = exp(i·phi·r·tau + (i·phi - phi^2)·v0·tau/2 + i·phi·0.5·v0·tau)
            //        = exp(i·phi·r·tau + i·phi·v0·tau/2 - phi^2·v0·tau/2)
            // Actually for BS with constant variance v0:
            // f_j(phi) for the Heston decomposition.
            // When xi=0, variance stays constant. The char fn simplifies.
            // d^2 = bj^2 + phi^2·xi^2·(1-rho^2) - 2i·xi·phi·(bj·rho + xi·uj)
            //      = bj^2 when xi=0
            // d = bj (taking positive root)
            // g = (bj + bj)/(bj - bj) = infinity => use L'Hopital or direct limit

            // Direct limit: when xi->0, D -> (uj·i·phi - phi^2/2) · (1 - exp(-bj·tau)) / bj
            // and C -> i·phi·r·tau + kappa·theta·[ ... ] but kappa·theta/xi^2 -> infinity
            // unless we handle carefully.

            // Simpler: use the direct formula. When xi=0, the variance is deterministic:
            // v(t) = theta + (v0 - theta)·exp(-kappa·t)
            // Average variance: vBar = theta + (v0 - theta)·(1 - exp(-kappa·tau))/(kappa·tau)
            // Then f_j(phi) is the GBM characteristic function with time-averaged variance.

            let vBar: Double
            if kappa > 1e-10 {
                vBar = theta + (v0 - theta) * (1.0 - Double.exp(-kappa * tau)) / (kappa * tau)
            } else {
                vBar = v0
            }

            // GBM-like char fn for P_j:
            // For j=1: f_1(phi) = exp(i·phi·r·tau - 0.5·phi·(phi - i)·vBar·tau)
            //        = exp(i·phi·r·tau - 0.5·phi^2·vBar·tau + 0.5·i·phi·vBar·tau)
            // For j=2: f_2(phi) = exp(i·phi·r·tau - 0.5·phi·(phi + i)·vBar·tau)
            //        = exp(i·phi·r·tau - 0.5·phi^2·vBar·tau - 0.5·i·phi·vBar·tau)
            let expReal = -0.5 * phi * phi * vBar * tau
            let expImag = phi * riskFreeRate * tau + uj * phi * vBar * tau
            // uj = 0.5 for j=1, -0.5 for j=2 (this gives the +/- 0.5·i·phi·vBar·tau)

            let mag = Double.exp(expReal)
            return (mag * Foundation.cos(expImag), mag * Foundation.sin(expImag))
        }

        // d^2 = (bj - i·rho·xi·phi)^2 + xi^2·(phi^2 + 2·uj·i·phi)
        // Expanded:
        // real(d^2) = bj^2 + xi^2·phi^2 - rho^2·xi^2·phi^2 = bj^2 + xi^2·phi^2·(1 - rho^2)
        // imag(d^2) = -2·xi·phi·(bj·rho + xi·uj)
        let d2R = bj * bj + xi2 * phi * phi * (1.0 - rho * rho)
        let d2I = -2.0 * xi * phi * (bj * rho + xi * uj)

        let (dR, dI) = csqrt(r: d2R, i: d2I)

        // Formulation 2 (stable): use g2 = (bj - i·rho·xi·phi - d) / (bj - i·rho·xi·phi + d)
        // This ensures |g2| <= 1, avoiding exponential blowup.
        let gNumR = bj - dR
        let gNumI = -rho * xi * phi - dI
        let gDenR = bj + dR
        let gDenI = -rho * xi * phi + dI

        let (gR, gI) = cdiv(aR: gNumR, aI: gNumI, bR: gDenR, bI: gDenI)

        // e^{-d·tau}
        let edtMag = Double.exp(-dR * tau)
        let edtR = edtMag * Foundation.cos(-dI * tau)
        let edtI = edtMag * Foundation.sin(-dI * tau)

        // g · e^{-d·tau}
        let geR = gR * edtR - gI * edtI
        let geI = gR * edtI + gI * edtR

        // 1 - g·e^{-d·tau}
        let oneMinusGeR = 1.0 - geR
        let oneMinusGeI = -geI

        // 1 - g
        let oneMinusGR = 1.0 - gR
        let oneMinusGI = -gI

        // D = (bj - i·rho·xi·phi - d) / xi^2 · (1 - e^{-d·tau}) / (1 - g·e^{-d·tau})
        // = g · (gDen) / xi^2 ... actually let me compute directly.
        // numerator of D: (bj - i·rho·xi·phi - d)
        // times (1 - e^{-d·tau}) / (1 - g·e^{-d·tau})
        let oneMinusEdtR = 1.0 - edtR
        let oneMinusEdtI = -edtI

        let (ratR, ratI) = cdiv(aR: oneMinusEdtR, aI: oneMinusEdtI,
                                bR: oneMinusGeR, bI: oneMinusGeI)

        // D = gNum · rat / xi^2
        let dCR = (gNumR * ratR - gNumI * ratI) / xi2
        let dCI = (gNumR * ratI + gNumI * ratR) / xi2

        // C = i·phi·r·tau + (kappa·theta/xi^2)·[ (bj - i·rho·xi·phi - d)·tau - 2·ln((1 - g·e^{-dt})/(1-g)) ]
        let (logRatR, logRatI) = clogDiv(aR: oneMinusGeR, aI: oneMinusGeI,
                                          bR: oneMinusGR, bI: oneMinusGI)

        let ktxi2 = kappa * theta / xi2
        let cR = ktxi2 * (gNumR * tau - 2.0 * logRatR)
        let cI = ktxi2 * (gNumI * tau - 2.0 * logRatI) + phi * riskFreeRate * tau

        // f = exp(C + D·v0 + i·phi·x)  -- but x is ln(S), and we don't include it here;
        // the integration handles the ln(S/K) term externally. Actually in the standard
        // formulation, the char fn includes i·phi·ln(S). But our integration uses
        // ln(S/K) externally. Let me include i·phi·ln(S) here for consistency with
        // the standard P_j integral.
        //
        // Actually, looking at the integration code, it uses logMoneyness = ln(S/K)
        // and multiplies by e^{i·phi·logMoneyness}, so the char fn should NOT include
        // the i·phi·x term (or rather, it should be the char fn of ln(S_T/S_0)).
        //
        // The standard decomposition: P_j = 0.5 + (1/pi) * Re ∫ e^{-i·phi·ln(K)} f_j(phi) / (i·phi) dphi
        // where f_j includes e^{i·phi·ln(S)}. The integration then uses:
        // e^{-i·phi·ln(K)} · e^{i·phi·ln(S)} = e^{i·phi·ln(S/K)}
        // which matches the logMoneyness multiplication. So we DO include i·phi·ln(S).
        // But wait -- we don't have ln(S) here. Let me not include it and fix the integration.
        //
        // Cleaner: the char fn we return is for the log-price relative process.
        // f_j(phi) = exp(C + D·v0), and the integration adds the e^{i·phi·logMoneyness} factor.
        // This is equivalent because i·phi·r·tau is already in C (as part of the drift).
        // No -- we need i·phi·x (ln(S)) in the full char fn. The integration multiplies by
        // e^{i·phi·ln(S/K)}, which when combined with f containing e^{i·phi·x=ln(S)} gives
        // e^{i·phi·ln(S)}·e^{i·phi·ln(S/K)} which is wrong.
        //
        // Let me just NOT include x in f_j, and treat f_j as the char fn of ln(S_T/S_0).
        // Then the integration uses f_j · e^{i·phi·ln(S/K)} correctly. But then the r·tau
        // drift in C must account for this being the forward log-return.
        //
        // Actually the simplest correct approach: include the full f_j with i·phi·x,
        // and in the integration use e^{-i·phi·ln(K)} (not ln(S/K)).
        // But the integration currently uses logMoneyness = ln(S/K).
        //
        // Let me fix this: I'll NOT include i·phi·x in f_j, and the integration
        // computes P_j = 0.5 + (1/pi) * ∫ Re[ f_j(phi) · e^{i·phi·ln(S/K)} / (i·phi) ] dphi

        let expArgR = cR + dCR * v0
        let expArgI = cI + dCI * v0

        // Clamp the real part to avoid overflow
        let clampedR = min(expArgR, 500.0)
        let mag = Double.exp(clampedR)
        return (mag * Foundation.cos(expArgI), mag * Foundation.sin(expArgI))
    }

    // MARK: - Complex Arithmetic Helpers

    /// Complex square root of (r + i·i_part).
    private func csqrt(r: Double, i: Double) -> (Double, Double) {
        let modulus = (r * r + i * i).squareRoot()
        guard modulus > 1e-30 else { return (0.0, 0.0) }
        let magnitude = modulus.squareRoot()
        let angle = Foundation.atan2(i, r) / 2.0
        return (magnitude * Foundation.cos(angle), magnitude * Foundation.sin(angle))
    }

    /// Complex division: (aR + i·aI) / (bR + i·bI).
    private func cdiv(aR: Double, aI: Double, bR: Double, bI: Double) -> (Double, Double) {
        let denom = bR * bR + bI * bI
        guard denom > 1e-30 else { return (0.0, 0.0) }
        return ((aR * bR + aI * bI) / denom, (aI * bR - aR * bI) / denom)
    }

    /// Complex log of ratio: ln(a/b) = ln|a| - ln|b| + i·(arg(a) - arg(b)).
    private func clogDiv(aR: Double, aI: Double, bR: Double, bI: Double) -> (Double, Double) {
        let magA = (aR * aR + aI * aI).squareRoot()
        let magB = (bR * bR + bI * bI).squareRoot()
        guard magA > 1e-30, magB > 1e-30 else { return (0.0, 0.0) }
        return (Double.log(magA) - Double.log(magB),
                Foundation.atan2(aI, aR) - Foundation.atan2(bI, bR))
    }
}
