//
//  HazardRateModel.swift
//  BusinessMath
//
//  Reduced-form credit models using hazard rates (intensity-based)
//

import Foundation
import Numerics

// MARK: - Constant Hazard Rate

/// Constant hazard rate model (exponential default distribution).
///
/// In the constant hazard rate model, the instantaneous probability of default
/// remains constant over time. This leads to an exponential distribution of
/// default times.
///
/// ## Key Formulas
///
/// **Survival Probability**:
/// ```
/// S(t) = exp(-λt)
/// ```
///
/// **Default Probability**:
/// ```
/// P(τ ≤ t) = 1 - exp(-λt)
/// ```
///
/// **Default Density**:
/// ```
/// f(t) = λ × exp(-λt)
/// ```
///
/// Where λ is the constant hazard rate.
///
/// ## Example
///
/// ```swift
/// let hazard = ConstantHazardRate(hazardRate: 0.02)  // 2% annual
/// let survival5yr = hazard.survivalProbability(time: 5.0)
/// let default5yr = hazard.defaultProbability(time: 5.0)
/// ```
public struct ConstantHazardRate<T: Real & Sendable>: Sendable {

    /// Constant hazard rate λ (instantaneous default probability)
    public let hazardRate: T

    /// Initialize with a constant hazard rate.
    ///
    /// - Parameter hazardRate: Annual hazard rate (λ) as decimal
    public init(hazardRate: T) {
        self.hazardRate = hazardRate
    }

    /// Calculate survival probability at time t.
    ///
    /// The probability that default has not occurred by time t.
    ///
    /// Formula: S(t) = exp(-λt)
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Survival probability (0 to 1)
    public func survivalProbability(time: T) -> T {
        return T.exp(-hazardRate * time)
    }

    /// Calculate default probability by time t.
    ///
    /// The probability that default occurs on or before time t.
    ///
    /// Formula: P(τ ≤ t) = 1 - exp(-λt)
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Cumulative default probability (0 to 1)
    public func defaultProbability(time: T) -> T {
        return T(1) - survivalProbability(time: time)
    }

    /// Calculate default probability density at time t.
    ///
    /// The instantaneous probability of default at exactly time t.
    ///
    /// Formula: f(t) = λ × exp(-λt)
    ///
    /// - Parameter time: Time point in years
    /// - Returns: Default density
    public func defaultDensity(time: T) -> T {
        return hazardRate * T.exp(-hazardRate * time)
    }
}

// MARK: - Time-Varying Hazard Rate

/// Time-varying hazard rate model.
///
/// The hazard rate changes over time according to a specified curve.
/// This allows modeling of term structure in credit risk.
///
/// ## Survival Probability
///
/// For time-varying hazard λ(t):
/// ```
/// S(t) = exp(-∫₀ᵗ λ(s) ds)
/// ```
///
/// The integral is computed numerically from the hazard rate curve, by the
/// trapezoidal rule across each period the curve actually spans.
///
/// ## The curve's periods set the timescale
///
/// Each point of the curve is a rate that applies across its own ``Period``, and the
/// integral advances by that period's length. A twelve-point monthly curve therefore
/// describes one year, not twelve. The ``dayCount`` convention decides what "length"
/// means, and defaults to ``DayCountConvention/actual365``, under which a common
/// calendar year is worth exactly 1.0.
///
/// Periods are not assumed to be uniform: a curve may be quarterly at the short end
/// and annual further out, and may contain a ``PeriodType/custom`` transition stub.
/// Each point contributes its own width.
///
/// ## Example
///
/// ```swift
/// let periods = (2024...2028).map { Period.year($0) }
/// let rates = [0.01, 0.015, 0.02, 0.025, 0.03]
/// let hazardCurve = TimeSeries(periods: periods, values: rates)
///
/// let model = TimeVaryingHazardRate(hazardRates: hazardCurve)
/// let survival3yr = model.survivalProbability(time: 3.0)
///
/// // A curve bootstrapped from CDS quotes accrues on ACT/360; say so.
/// let cdsBasis = TimeVaryingHazardRate(hazardRates: hazardCurve, dayCount: .actual360)
/// ```
public struct TimeVaryingHazardRate<T: Real & Sendable>: Sendable {

    /// Time series of hazard rates
    public let hazardRates: TimeSeries<T>

    /// The convention used to convert each period of the curve into a year fraction.
    ///
    /// Defaults to ``DayCountConvention/actual365``. The choice is material: over a
    /// 365-day year ``DayCountConvention/actual360`` accrues 1.389% more hazard than
    /// ``DayCountConvention/actual365`` for the same quoted rates, so a curve
    /// integrated on the wrong basis produces a survival probability that is wrong
    /// by more than most of the spread being modelled.
    public let dayCount: DayCountConvention

    /// Initialize with a hazard rate curve.
    ///
    /// - Parameters:
    ///   - hazardRates: Time series of hazard rates by period. Each rate is quoted
    ///     per annum and applies across its own period; the periods need not all be
    ///     the same length.
    ///   - dayCount: How each period is converted into a year fraction. Defaults to
    ///     ``DayCountConvention/actual365``. Use ``DayCountConvention/actual360`` for
    ///     a curve bootstrapped from CDS quotes, whose premium leg accrues on that
    ///     basis, and ``DayCountConvention/thirty360`` for one derived from US
    ///     corporate bond spreads.
    public init(hazardRates: TimeSeries<T>, dayCount: DayCountConvention = .actual365) {
        self.hazardRates = hazardRates
        self.dayCount = dayCount
    }

    /// Calculate survival probability at time t.
    ///
    /// Integrates the hazard rate curve from 0 to t:
    /// S(t) = exp(-∫₀ᵗ λ(s) ds)
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Survival probability (0 to 1)
    public func survivalProbability(time: T) -> T {
        let integral = integrateHazardRate(upTo: time)
        return T.exp(-integral)
    }

    /// Calculate default probability by time t.
    ///
    /// - Parameter time: Time horizon in years
    /// - Returns: Cumulative default probability (0 to 1)
    public func defaultProbability(time: T) -> T {
        return T(1) - survivalProbability(time: time)
    }

    /// Integrate the hazard curve from 0 to `time` by the trapezoidal rule.
    ///
    /// Each point of the curve advances the clock by the length of *its own* period,
    /// measured with ``dayCount``. The previous implementation discarded
    /// `hazardRates.periods` entirely and stepped by a hardcoded `T(1)`, so every
    /// curve was read as though its points were a year apart. A twelve-point monthly
    /// curve was integrated over twelve years: on a monthly curve ramping 2% to 24%
    /// across 2025, that put the whole term structure's cumulative hazard at 1.45
    /// against a true 0.1214, a factor of 11.9 — and, at the one-year horizon a
    /// caller would actually ask about, returned the January rate alone and reported
    /// a 2.0% default probability where the curve says 11.4%. Neither number looks
    /// wrong on its own.
    ///
    /// The shape of the rule is unchanged: the first period is a rectangle at its own
    /// rate, each later period a trapezoid between its rate and the previous one, and
    /// a horizon beyond the end of the curve extrapolates flat at the last rate. Only
    /// the widths are now real.
    ///
    /// The curve is assumed to be contiguous — each period taken to begin where the
    /// last ended — which is what a term structure is. Gaps between periods are not
    /// detected.
    private func integrateHazardRate(upTo time: T) -> T {
        let rates = hazardRates.valuesArray
        let periods = hazardRates.periods

        guard !rates.isEmpty else { return T.zero }
        // `valuesArray` is built by looking each period up in `values`, so the two are
        // the same length for any series that can be constructed. Belt and braces: a
        // mismatch would index out of bounds below.
        guard periods.count == rates.count else { return T.zero }

        var integral = T.zero
        var currentTime = T.zero

        for i in 0..<rates.count {
            let rate = rates[i]

            if currentTime >= time {
                break
            }

            let timeStep: T = dayCount.yearFraction(of: periods[i])
            let nextTime = min(currentTime + timeStep, time)
            let duration = nextTime - currentTime

            // Trapezoidal rule: average rate × duration
            if i == 0 {
                integral += rate * duration
            } else {
                let prevRate = rates[i - 1]
                integral += (prevRate + rate) / T(2) * duration
            }

            currentTime = nextTime
        }

        // If time extends beyond curve, use last rate
        if currentTime < time && !rates.isEmpty {
            let lastRate = rates[rates.count - 1]
            integral += lastRate * (time - currentTime)
        }

        return integral
    }
}

// MARK: - Hazard Rate from Spread

/// Extract hazard rate from credit spread.
///
/// Uses the approximation that credit spread equals the product of
/// hazard rate and loss given default:
///
/// ```
/// Spread ≈ λ × (1 - R)
/// ```
///
/// Therefore:
/// ```
/// λ ≈ Spread / (1 - R)
/// ```
///
/// This is exact for continuous-time models with flat term structure.
///
/// ## Why this returns an optional
///
/// The division has no answer at the edges of its domain, and the answers it used to
/// give there were worse than none. A recovery rate of exactly 1.0 makes the loss
/// given default zero and the quotient `±infinity`, which then propagates silently
/// into every survival probability computed from it. A recovery rate above 1.0 makes
/// the loss given default *negative* and returns a **negative hazard rate** — a
/// number that is not merely inaccurate but meaningless, since `exp(-λt)` with λ < 0
/// is a survival probability greater than one. Both cases arrive as ordinary
/// `Double`s that no downstream check catches.
///
/// `Optional` rather than `throws`, following the reasoning recorded for
/// ``PeriodType/convert(_:to:)``: this has a single failure mode — the inputs are not
/// a well-formed spread and recovery rate — so a typed error would carry nothing a
/// `nil` does not, and `nil` composes with `??` and `map` in the expression positions
/// this function is used in. Contrast
/// ``calibrateMertonModel(equityValue:equityVolatility:debtFaceValue:riskFreeRate:maturity:)``
/// next door, which throws because it has two distinguishable failures — bad inputs
/// and non-convergence — and the caller needs to know which.
///
/// - Parameters:
///   - spread: Credit spread as decimal (e.g., 0.0150 for 150 bps). Must be finite
///     and non-negative; a negative spread does not imply a negative default
///     intensity, it implies the quote is not a credit spread.
///   - recoveryRate: Expected recovery rate as a fraction of par (default: 0.40).
///     Must be finite and in `0..<1`. At 1.0 there is no loss to compensate for and
///     no spread can imply an intensity; above 1.0 or below 0.0 it is not a recovery
///     rate.
/// - Returns: The implied hazard rate, or `nil` if the inputs do not determine a
///   finite, non-negative one.
///
/// ## Example
///
/// ```swift
/// let spread = 0.0150  // 150 bps
/// let recovery = 0.40
/// let hazard = hazardRateFromSpread(spread: spread, recoveryRate: recovery)
/// // hazard ≈ 0.025 (2.5% annual)
///
/// // Full recovery leaves nothing for a spread to compensate.
/// let undefined = hazardRateFromSpread(spread: spread, recoveryRate: 1.0)  // nil
/// ```
public func hazardRateFromSpread<T: Real>(
    spread: T,
    recoveryRate: T = T(40) / T(100)
) -> T? {
    guard spread.isFinite, spread >= T.zero else { return nil }
    guard recoveryRate.isFinite, recoveryRate >= T.zero, recoveryRate < T(1) else { return nil }

    let lossGivenDefault = T(1) - recoveryRate
    // `recoveryRate < 1` makes this strictly positive, and a strictly positive
    // divisor cannot produce an infinity from a finite numerator.
    guard lossGivenDefault > T.zero else { return nil }
    return spread / lossGivenDefault // fp-safety:disable — guarded non-zero above
}

// MARK: - Cox Process (Stochastic Hazard Rate)

/// Cox process model with stochastic hazard rate.
///
/// In a Cox process, the hazard rate itself follows a stochastic process,
/// typically a mean-reverting process or geometric Brownian motion.
///
/// This implementation holds the intensity constant over each step of a fixed grid and
/// redraws it from a lognormal each step, then finds the time at which the accumulated
/// intensity crosses an independent Exponential(1) threshold.
///
/// ## Model
///
/// ```
/// λ(t) = μ × exp(σ Z_t),  Z_t ~ N(0, 1) i.i.d. across steps
/// τ = inf{t : ∫₀ᵗ λ(s) ds > E},  E ~ Exponential(1)
/// ```
///
/// Because the shocks are independent across steps, the accumulated intensity averages
/// them, and over a long horizon `∫₀ᵗ λ ≈ μ exp(σ²/2) t`. Setting `volatility` to zero
/// recovers the constant-intensity case exactly, where `τ ~ Exponential(μ)`.
///
/// ## Example
///
/// ```swift
/// let cox = CoxProcess(meanHazardRate: 0.02, volatility: 0.30)
/// let defaultTime = cox.simulateDefaultTime(seed: 42)
/// ```
public struct CoxProcess<T: Real & Sendable>: Sendable {

    /// Mean hazard rate
    public let meanHazardRate: T

    /// Volatility of hazard rate
    public let volatility: T

    /// Initialize Cox process.
    ///
    /// - Parameters:
    ///   - meanHazardRate: Long-run average hazard rate
    ///   - volatility: Volatility of hazard rate process
    public init(meanHazardRate: T, volatility: T) {
        self.meanHazardRate = meanHazardRate
        self.volatility = volatility
    }

}

// MARK: - Cox Process Simulation

/// Default-time simulation for the Cox process.
///
/// ## Why this is constrained to `BinaryFloatingPoint`
///
/// Simulation needs to turn a uniform — which the standard library hands over as a
/// `Double` — into a value of `T`, and `Real` alone offers no conversion from `Double`.
/// The previous implementation papered over that with `meanHazardRate as? Double`, falling
/// back to the literals `0.02` and `0.30` when the cast failed. For any `T` other than
/// `Double` that silently discarded the caller's parameters: a `CoxProcess<Float>` built
/// with a 15% hazard rate simulated a 2% one and returned 16.0 years where the same model
/// in `Double` returns 2.2.
///
/// Constraining the extension rather than keeping a fallback makes the bad case
/// unrepresentable — a `T` that cannot carry a uniform simply has no
/// `simulateDefaultTime`, diagnosed by the compiler at the call site. Constraining to
/// `T == Double` would also have worked, but needlessly: `Float` can carry a uniform
/// perfectly well, and the arithmetic below is all `Real` operations in `T`.
extension CoxProcess where T: BinaryFloatingPoint {

    /// The width of the intensity grid, in years.
    ///
    /// The intensity is held constant across each step and redrawn at the start of the
    /// next, so this is a parameter of the model and not only of its numerics: a smaller
    /// step averages more independent shocks over the same span and narrows the
    /// distribution of the integrated intensity.
    private static var timeStep: T { T(1) / T(10) }

    /// Simulate a default time from the Cox process.
    ///
    /// Steps a piecewise-constant intensity forward until the accumulated intensity
    /// crosses an Exponential(1) threshold, and returns the crossing time. Within the step
    /// that crosses, the intensity is constant, so the crossing is solved exactly rather
    /// than rounded to the grid.
    ///
    /// - Parameters:
    ///   - horizon: The longest time that can be returned, in years. A path that has not
    ///     defaulted by then is right-censored and `horizon` is returned — so a simulation
    ///     run at a hazard rate low enough for the horizon to bind produces a mass of
    ///     outcomes sitting exactly on it. At the default of 100 years and λ = 2%, that is
    ///     13.5% of paths, and the sample mean of the returned times is 43.2 rather than
    ///     the 50 that `1/λ` would suggest. Raise it when simulating low intensities.
    ///   - seed: Seed for a private ``DeterministicRNG``. The same seed, model and horizon
    ///     reproduce the same default time exactly. `nil` (the default) draws from system
    ///     entropy and is non-reproducible by contract — use `seed:` or
    ///     ``simulateDefaultTime(horizon:using:)`` when reproducibility matters.
    /// - Returns: Simulated default time in years, in `0...horizon`; `T.nan` if the model
    ///   parameters or the horizon are not finite.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let cox = CoxProcess(meanHazardRate: 0.02, volatility: 0.30)
    /// let defaultTime = cox.simulateDefaultTime(seed: 42)
    /// ```
    public func simulateDefaultTime(horizon: T = 100, seed: UInt64? = nil) -> T {
        if let seed {
            var generator = DeterministicRNG(seed: seed)
            return simulateDefaultTime(horizon: horizon, using: &generator)
        }
        var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
        return simulateDefaultTime(horizon: horizon, using: &generator)
    }

    /// Simulate a default time, drawing every shock from `generator`.
    ///
    /// The generator-parameterized form of ``simulateDefaultTime(horizon:seed:)``,
    /// following the same convention as ``SeedableDistribution/next(using:)``: all
    /// randomness comes from the caller's generator, so the caller owns reproducibility and
    /// can draw a whole portfolio of paths from one stream.
    ///
    /// That is the form a Monte Carlo wants. The `seeds: [Double]` parameter this replaced
    /// consumed a fixed array by index, wrapping with `stepCounter % seeds.count`, so a
    /// path stepped over a hundred grid points with three seeds repeated the same three
    /// shocks thirty-three times. The path had period three; every variance, quantile and
    /// expected shortfall drawn from it described that cycle rather than the model. It was
    /// also deterministic, which made it look correct.
    ///
    /// - Parameters:
    ///   - horizon: The longest time that can be returned, in years. See
    ///     ``simulateDefaultTime(horizon:seed:)`` for what censoring at it costs.
    ///   - generator: The random source. Advanced once for the threshold and twice per
    ///     grid step thereafter, so consumption is data-dependent: it is proportional to
    ///     the default time the path happens to produce.
    /// - Returns: Simulated default time in years, in `0...horizon`; `T.nan` if the model
    ///   parameters or the horizon are not finite.
    public func simulateDefaultTime<G: RandomNumberGenerator>(horizon: T = 100, using generator: inout G) -> T {
        guard meanHazardRate.isFinite, volatility.isFinite, horizon.isFinite else { return T.nan }
        guard horizon > T(0) else { return T(0) }
        // A non-positive intensity never accumulates, so no default can occur: censor.
        guard meanHazardRate > T(0) else { return horizon }

        // τ is the time at which the accumulated intensity crosses an Exponential(1) draw.
        var remaining = Self.exponentialUnitDraw(using: &generator)
        var time = T(0)
        let step = Self.timeStep

        while time < horizon {
            let z = Self.standardNormalDraw(using: &generator)
            let intensity = meanHazardRate * T.exp(volatility * z)
            let width = min(step, horizon - time)
            let accumulated = intensity * width

            if accumulated >= remaining {
                // The intensity is constant across this step, so the crossing solves
                // intensity × Δ = remaining exactly — no need to round up to the grid.
                guard intensity > T(0) else { return time }
                // `accumulated >= remaining` makes the quotient no larger than `width`, so
                // the min only absorbs a last-ulp rounding at the horizon.
                return min(horizon, time + remaining / intensity) // fp-safety:disable — guarded by intensity > 0 above
            }

            remaining -= accumulated
            time += width
        }

        return horizon
    }

    /// One Exponential(1) draw.
    ///
    /// The uniform is reflected to `(0, 1]` before the logarithm for the reason set out on
    /// ``ScenarioGenerator``'s normal draw: `Double.random(in: 0..<1)` can return exactly
    /// zero, `log(0)` is `-infinity`, and `u ↦ 1 - u` removes the pole without distorting
    /// the distribution the way clamping to an epsilon would.
    ///
    /// - Parameter generator: The random source. Advanced once.
    /// - Returns: A draw from Exponential(1), in `[0, ∞)`.
    private static func exponentialUnitDraw<G: RandomNumberGenerator>(using generator: inout G) -> T {
        let u = 1.0 - Double.random(in: 0..<1, using: &generator)   // (0, 1]
        return T(-Double.log(u))
    }

    /// One standard normal draw, by Box–Muller.
    ///
    /// This replaces a private "inverse normal CDF" that was not one. It returned
    /// `(u - 0.5) × 3` on `0.4 < u < 0.6` — the true slope of the normal quantile at the
    /// median is `√(2π) ≈ 2.5066` — and `±√(2 log(1/min(u, 1-u)))` outside, which is a tail
    /// asymptote applied across the whole body. The two branches do not meet: at `u = 0.6`
    /// the value jumps from `0.30` to `1.372`, so the function was discontinuous and no
    /// shock in `(0.30, 1.372)` was reachable at all. At `u = 0.61` it returned `1.372`
    /// against a true quantile of `0.279`, a factor of 4.9.
    ///
    /// The transform is done in `Double`, where the uniforms are born and where the pole at
    /// the endpoint is best controlled; the result is a standard variate carrying no
    /// dependence on the model's parameters, so converting it to `T` costs nothing. Every
    /// quantity that touches `meanHazardRate` or `volatility` is computed in `T`.
    ///
    /// - Parameter generator: The random source. Advanced twice.
    /// - Returns: A draw from N(0, 1).
    private static func standardNormalDraw<G: RandomNumberGenerator>(using generator: inout G) -> T {
        // The shared transform, which draws the same two uniforms this used to draw
        // for itself and takes the same cosine branch, so the output is bit-identical.
        let (_, z): (Double, Double) = boxMullerSeed(using: &generator)
        return T(z)
    }
}
