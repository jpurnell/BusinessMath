//
//  AutoregressiveOne.swift
//  BusinessMath
//
//  AR(1): Xₜ = c + φ·Xₜ₋₁ + σ·εₜ
//

import Foundation
import Numerics

/// A first-order autoregressive process — the discrete-time mean-reverting series.
///
/// The workhorse for anything that drifts back toward a level: an interest rate, an
/// occupancy rate, a spread, a demand index. Each period is the last one pulled a
/// fraction of the way home, plus a shock.
///
/// Binds Risk Solver's `PsiAR1(mean, sigma, phi)`.
///
/// ```swift
/// // A spread reverting to 120bp, with a half-life of about three periods.
/// if let spread = AutoregressiveOne(name: "Spread", persistence: 0.8,
///                                   longRunMean: 0.012, shockVolatility: 0.002) {
///     let shocks = DistributionNormal(0, 1)
///     var generator = DeterministicRNG(seed: 7)
///     var level = spread.longRunMean
///     for _ in 0..<12 {
///         level = spread.step(from: level, dt: 1,
///                             normalDraws: shocks.next(using: &generator))
///     }
///     print(spread.halfLife)   // 3.106...
/// }
/// ```
///
/// ## Why this is not `DistributionRandom`
///
/// Every other Risk Solver row in this package is a distribution: draws are
/// independent, so one `next(using:)` says everything. Here a draw depends on the last
/// one, which is the entire point — the coverage proposal calls this out, and
/// ``StochasticProcess`` is the protocol that already models it, alongside GBM,
/// Ornstein–Uhlenbeck, jump diffusion and the rest.
///
/// ## AR(1) is the exact discretisation of an Ornstein–Uhlenbeck process
///
/// They are the same process seen at different resolutions, and this implementation
/// uses that rather than pretending `dt` means nothing. Over a step of `dt`:
///
/// ```
/// X(t+dt) = μ + (X(t) − μ)·φ^dt + σ_step·Z
/// σ_step  = σ·√((1 − φ^(2·dt)) / (1 − φ²))
/// ```
///
/// At `dt = 1` the powers collapse and this is exactly `c + φX + σZ`, the textbook
/// recursion — checked directly rather than assumed. At other steps it is the exact
/// transition, not an Euler approximation, so a half-period step twice equals a
/// whole-period step once.
///
/// ## Stationarity
///
/// `|φ| < 1` is required. At `φ = 1` the process is a random walk with no long-run
/// mean and a variance that grows without bound; above 1 it explodes. Neither has the
/// stationary moments this type reports, so both are refused at construction rather
/// than allowed to produce numbers those accessors would describe wrongly.
public struct AutoregressiveOne: StochasticProcess, Sendable {

	/// The state is a single number.
	public typealias State = Double

	/// A label for reporting.
	public let name: String

	/// `φ`, the fraction of the current deviation carried into the next period.
	///
	/// Strictly between −1 and 1. Near 1 the series is slow and trending; near 0 it is
	/// almost independent draws; negative values alternate.
	public let persistence: Double

	/// `μ`, the level the process reverts to.
	public let longRunMean: Double

	/// `σ`, the standard deviation of the per-period shock. Positive.
	public let shockVolatility: Double

	/// An AR(1) is defined on the whole real line.
	public let allowsNegativeValues: Bool = true

	/// One source of randomness.
	public let factors: Int = 1

	/// Creates an AR(1) process.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - persistence: `φ`, strictly inside (−1, 1).
	///   - longRunMean: `μ`, the level reverted to.
	///   - shockVolatility: `σ`, positive.
	/// - Returns: `nil` if `|φ| ≥ 1`, if `σ ≤ 0`, or if any argument is not finite.
	public init?(name: String, persistence: Double, longRunMean: Double, shockVolatility: Double) {
		guard persistence.isFinite, abs(persistence) < 1 else { return nil }
		guard longRunMean.isFinite else { return nil }
		guard shockVolatility > 0, shockVolatility.isFinite else { return nil }
		self.name = name
		self.persistence = persistence
		self.longRunMean = longRunMean
		self.shockVolatility = shockVolatility
	}

	/// Advances the process by `dt`.
	///
	/// - Parameters:
	///   - current: The current level.
	///   - dt: The step, in periods. `1` is one period of the textbook recursion.
	///   - normalDraws: A standard normal draw.
	/// - Returns: The level after the step.
	public func step(from current: Double, dt: Double, normalDraws: Double) -> Double {
		guard dt > 0 else { return current }

		// φ^dt, via logs so a negative φ raised to a fractional power does not become
		// a NaN. A negative persistence alternates sign each *whole* period, and the
		// only fractional step with an unambiguous meaning is one that preserves that.
		let magnitude: Double = abs(persistence)
		let decayMagnitude: Double = Foundation.pow(magnitude, dt)
		let alternating: Bool = persistence < 0 && dt.truncatingRemainder(dividingBy: 2) >= 1
		let decay: Double = alternating ? -decayMagnitude : decayMagnitude

		let deviation: Double = current - longRunMean
		let carried: Double = deviation * decay

		// The exact conditional standard deviation over a step of dt. At dt = 1 the
		// numerator is 1 − φ², cancelling the denominator, and this is simply σ.
		let squared: Double = persistence * persistence
		let remaining: Double = 1 - Foundation.pow(squared, dt)
		let stationary: Double = 1 - squared
		guard stationary > 0 else { return current }
		let variance: Double = shockVolatility * shockVolatility * remaining / stationary
		let spread: Double = variance.squareRoot()

		return longRunMean + carried + spread * normalDraws
	}

	// MARK: - Analytical properties

	/// `c` in the textbook form `Xₜ = c + φXₜ₋₁ + σεₜ`.
	///
	/// Reported because most references parameterise by the intercept rather than by
	/// the mean, and the two are easy to confuse: `c = μ(1 − φ)`, so an intercept
	/// passed where a mean belongs gives a process reverting to the wrong level.
	public var intercept: Double {
		longRunMean * (1 - persistence)
	}

	/// The variance of the process once it has forgotten where it started,
	/// `σ²/(1 − φ²)`.
	///
	/// Always larger than the shock variance, and much larger as `φ` approaches 1 —
	/// persistence accumulates shocks rather than dissipating them.
	public var stationaryVariance: Double {
		let squared: Double = persistence * persistence
		// `|φ| < 1` is an initialiser invariant, so `1 − φ²` is strictly positive —
		// restated here because the guard proving it is a hundred lines away, and a
		// reader of this line alone cannot see it.
		let remaining: Double = 1 - squared
		guard remaining > 0 else { return .infinity }
		return shockVolatility * shockVolatility / remaining
	}

	/// The standard deviation of the stationary distribution.
	public var stationaryStandardDeviation: Double {
		stationaryVariance.squareRoot()
	}

	/// The autocorrelation at a lag, `φ^k`.
	///
	/// - Parameter lag: The lag in periods, non-negative.
	/// - Returns: The correlation between `Xₜ` and `Xₜ₊lag`.
	public func autocorrelation(lag: Int) -> Double {
		guard lag >= 0 else { return 0 }
		return Foundation.pow(persistence, Double(lag))
	}

	/// How long a shock takes to decay to half its size, in periods.
	///
	/// `ln(0.5)/ln(|φ|)`. Infinite for `φ = 0`, where a shock does not persist at all
	/// and there is nothing to decay.
	public var halfLife: Double {
		let magnitude: Double = abs(persistence)
		guard magnitude > 0 else { return 0 }
		let logMagnitude: Double = Foundation.log(magnitude)
		// The decay rate, positive exactly when |φ| < 1 — which is both the condition
		// for a half-life to exist and the guard on the divisor below.
		let decayRate: Double = -logMagnitude
		guard decayRate > 0 else { return .infinity }
		let halved: Double = -Foundation.log(0.5)
		return halved / decayRate
	}

	/// `E[X(t)]` given a starting level, `μ + (x₀ − μ)φ^t`.
	///
	/// - Parameters:
	///   - t: Periods elapsed.
	///   - x0: The starting level.
	/// - Returns: The expected level.
	public func expectedValue(at t: Double, from x0: Double) -> Double {
		let decay: Double = Foundation.pow(abs(persistence), t)
		let signed: Double = persistence < 0 && t.truncatingRemainder(dividingBy: 2) >= 1 ? -decay : decay
		let deviation: Double = x0 - longRunMean
		return longRunMean + deviation * signed
	}
}
