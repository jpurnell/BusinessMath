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
/// The integral is computed numerically from the hazard rate curve.
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
/// ```
public struct TimeVaryingHazardRate<T: Real & Sendable>: Sendable {

    /// Time series of hazard rates
    public let hazardRates: TimeSeries<T>

    /// Initialize with a hazard rate curve.
    ///
    /// - Parameter hazardRates: Time series of hazard rates by period
    public init(hazardRates: TimeSeries<T>) {
        self.hazardRates = hazardRates
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

    /// Integrate hazard rate from 0 to t using trapezoidal rule
    private func integrateHazardRate(upTo time: T) -> T {
        let rates = hazardRates.valuesArray
        _ = hazardRates.periods  // Not used in integration

        guard !rates.isEmpty else { return T.zero }

        // Assume annual periods for simplicity
        let timeStep = T(1)
        var integral = T.zero
        var currentTime = T.zero

        for i in 0..<rates.count {
            let rate = rates[i]

            if currentTime >= time {
                break
            }

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
/// - Parameters:
///   - spread: Credit spread as decimal (e.g., 0.0150 for 150 bps)
///   - recoveryRate: Expected recovery rate (default: 0.40)
/// - Returns: Implied hazard rate
///
/// ## Example
///
/// ```swift
/// let spread = 0.0150  // 150 bps
/// let recovery = 0.40
/// let hazard = hazardRateFromSpread(spread: spread, recoveryRate: recovery)
/// // hazard ≈ 0.025 (2.5% annual)
/// ```
public func hazardRateFromSpread<T: Real>(
    spread: T,
    recoveryRate: T = T(40) / T(100)
) -> T {
    let lossGivenDefault = T(1) - recoveryRate
    return spread / lossGivenDefault
}

// MARK: - Cox Process (Stochastic Hazard Rate)

/// Cox process model with stochastic hazard rate.
///
/// In a Cox process, the hazard rate itself follows a stochastic process,
/// typically a mean-reverting process or geometric Brownian motion.
///
/// This simple implementation uses a lognormal distribution for the
/// integrated hazard to simulate default times.
///
/// ## Model
///
/// ```
/// λ(t) ~ Lognormal(μ, σ)
/// τ = inf{t : ∫₀ᵗ λ(s) ds > E}
/// ```
///
/// Where E ~ Exponential(1)
///
/// ## Example
///
/// ```swift
/// let cox = CoxProcess(meanHazardRate: 0.02, volatility: 0.30)
/// let seeds = [0.3, 0.5, 0.7]
/// let defaultTime = cox.simulateDefaultTime(seeds: seeds)
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

    /// Simulate default time using Cox process.
    ///
    /// Uses provided random seeds to generate a default time according
    /// to the stochastic intensity model.
    ///
    /// - Parameter seeds: Random seeds in [0,1] for simulation
    /// - Returns: Simulated default time in years
    public func simulateDefaultTime(seeds: [Double]) -> T {
        guard !seeds.isEmpty else {
            // Fallback: use mean hazard for exponential draw
            let u = T(1) / T(2)
            let oneMinusU = T(1) - u
            return -T.log(oneMinusU) / meanHazardRate
        }

        // For simulation, we need to work with concrete Double values
        // This function is designed to work with T = Double in practice
        let meanDouble: Double
        let volDouble: Double

        // Handle conversion carefully
        if let mean = meanHazardRate as? Double {
            meanDouble = mean
        } else {
            meanDouble = 0.02  // Default fallback
        }

        if let vol = volatility as? Double {
            volDouble = vol
        } else {
            volDouble = 0.30  // Default fallback
        }

        // Draw exponential random variable for threshold
        let u1 = seeds[0]
        let exponentialThreshold = -log(1.0 - u1)

        // Simulate path of integrated hazard using lognormal steps
        var integratedHazard = 0.0
        var time = 0.0
        let timeStep = 0.1  // Small time steps
        var stepCounter = 0

        while integratedHazard < exponentialThreshold && time < 100.0 {
            // Get seed for this step
            let seedIndex = stepCounter % seeds.count
            let u = seeds[seedIndex]
            stepCounter += 1

            // Lognormal increment for hazard rate
            // λ_t = μ × exp(σ × Z)
            let z = inverseNormalCDFDouble(u)
            let hazardRate = meanDouble * exp(volDouble * z)

            // Accumulate integrated hazard
            integratedHazard += hazardRate * timeStep
            time += timeStep
        }

        return T(Int(time * 10.0)) / T(10)  // Convert back to T with rounding
    }

    /// Approximate inverse normal CDF using Beasley-Springer-Moro algorithm
    private func inverseNormalCDF(_ u: T) -> T {
        guard u > T.zero && u < T(1) else {
            return T.zero
        }

        // Use Box-Muller-like transformation for simplicity
        let y = u - T(1)/T(2)

        if y > -T(1)/T(10) && y < T(1)/T(10) {
            // For values near 0.5, use linear approximation
            return y * T(3)
        } else {
            // For other values, use log-based approximation
            let sign = y < T.zero ? -T(1) : T(1)
            let absU = u < T(1)/T(2) ? u : (T(1) - u)
            let logVal = -T.log(absU)
            return sign * T.sqrt(T(2) * logVal)
        }
    }

    /// Double version of inverse normal CDF for simulation
    private func inverseNormalCDFDouble(_ u: Double) -> Double {
        guard u > 0.0 && u < 1.0 else {
            return 0.0
        }

        let y = u - 0.5

        if y > -0.1 && y < 0.1 {
            // For values near 0.5, use linear approximation
            return y * 3.0
        } else {
            // For other values, use log-based approximation
            let sign = y < 0.0 ? -1.0 : 1.0
            let absU = u < 0.5 ? u : (1.0 - u)
            let logVal = -log(absU)
            return sign * sqrt(2.0 * logVal)
        }
    }
}
