//
//  AutoregressiveMovingAverage.swift
//  BusinessMath
//
//  ARMA(p, q): Xₜ = μ + Σφᵢ(Xₜ₋ᵢ − μ) + εₜ + Σθⱼεₜ₋ⱼ
//

import Foundation
import Numerics

/// The state of an ARMA process: the recent deviations and the recent shocks.
///
/// Both are needed, and for different reasons. The autoregressive part reads past
/// *values*; the moving-average part reads past *errors*, which are not recoverable
/// from the values once the process has run. A state carrying only one of the two
/// could not step the other.
public struct ARMAState: ProcessState, Sendable, Equatable {

	/// Arithmetic is in `Double`.
	public typealias Scalar = Double

	/// One standard normal draw per step.
	public typealias NormalDraws = Double

	/// Two components conceptually — values and errors — whatever their orders.
	public static var dimension: Int { 2 }

	/// Recent deviations from the mean, most recent first. Length `p`.
	public let deviations: [Double]

	/// Recent shocks, most recent first. Length `q`.
	public let errors: [Double]

	/// The most recent level, mean included.
	public let value: Double

	/// Creates a state.
	///
	/// - Parameters:
	///   - value: The most recent level.
	///   - deviations: Recent deviations from the mean, most recent first.
	///   - errors: Recent shocks, most recent first.
	public init(value: Double, deviations: [Double], errors: [Double]) {
		self.value = value
		self.deviations = deviations
		self.errors = errors
	}
}

/// An ARMA(p, q) process, covering the whole family Frontline documents up to order
/// two.
///
/// One implementation rather than five. `PsiAR1`, `PsiAR2`, `PsiMA1`, `PsiMA2` and
/// `PsiARMA11` are the same recursion with different coefficient vectors, and writing
/// them separately would produce five processes able to disagree about the case where
/// they overlap.
///
/// ```swift
/// // ARMA(1,1): persistent, with a one-period shock echo.
/// if let process = AutoregressiveMovingAverage(
///     name: "Spread", mean: 0.012, volatility: 0.002,
///     autoregressive: [0.8], movingAverage: [0.3]) {
///     print(process.autocorrelation(lag: 1))   // 0.8447...
/// }
/// ```
///
/// ## The recursion
///
/// ```
/// Xₜ = μ + Σᵢ φᵢ(Xₜ₋ᵢ − μ) + εₜ + Σⱼ θⱼ εₜ₋ⱼ,   ε ~ N(0, σ²)
/// ```
///
/// The `φ` are the autoregressive coefficients — how much of the last deviations
/// carries forward — and the `θ` the moving-average ones, how much of the last shocks
/// echoes. An empty `φ` is a pure MA; an empty `θ` a pure AR.
///
/// ## Stationarity is checked, not assumed
///
/// The AR side must have its characteristic roots outside the unit circle or the
/// process explodes and none of the stationary quantities here mean anything. For the
/// orders this covers that reduces to conditions the initialiser can test outright:
///
/// | Order | Condition |
/// |---|---|
/// | AR(1) | `|φ₁| < 1` |
/// | AR(2) | `|φ₂| < 1`, `φ₁ + φ₂ < 1`, `φ₂ − φ₁ < 1` |
///
/// The MA side is always stationary — a finite sum of shocks cannot diverge — so no
/// condition is imposed on `θ`. Invertibility is a different property and is not
/// required to *simulate*, only to infer, so it is not checked here.
///
/// ## `dt` is one period
///
/// ARMA is discrete-time. Unlike ``AutoregressiveOne``, whose AR(1) case has an exact
/// continuous-time counterpart in Ornstein–Uhlenbeck, there is no sub-period step that
/// preserves an MA term's structure — so ``step(from:dt:normalDraws:)`` advances one
/// period for any positive `dt` and says so rather than scaling something with no
/// scaling law.
///
/// - Note: ``AutoregressiveOne`` remains the right type for a pure AR(1) that needs a
///   fractional `dt`. This one covers the family; that one covers the continuous-time
///   correspondence. ``matchesAutoregressiveOne(_:)`` asserts they agree where they
///   overlap.
public struct AutoregressiveMovingAverage: StochasticProcess, Sendable {

	/// The state carries both histories.
	public typealias State = ARMAState

	/// A label for reporting.
	public let name: String

	/// `μ`, the level the process reverts to.
	public let mean: Double

	/// `σ`, the standard deviation of each shock. Positive.
	public let volatility: Double

	/// The autoregressive coefficients `φ₁…φ_p`, most recent lag first.
	public let autoregressive: [Double]

	/// The moving-average coefficients `θ₁…θ_q`, most recent lag first.
	public let movingAverage: [Double]

	/// Defined on the whole real line.
	public let allowsNegativeValues: Bool = true

	/// One source of randomness.
	public let factors: Int = 1

	/// Creates an ARMA process.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - mean: `μ`.
	///   - volatility: `σ`, strictly positive.
	///   - autoregressive: `φ`, at most two coefficients. Empty for a pure MA.
	///   - movingAverage: `θ`, at most two coefficients. Empty for a pure AR.
	/// - Returns: `nil` if `σ` is not positive, if either order exceeds two, if any
	///   coefficient is not finite, or if the AR side is not stationary.
	public init?(name: String, mean: Double, volatility: Double,
				 autoregressive: [Double] = [], movingAverage: [Double] = []) {
		guard volatility > 0, volatility.isFinite, mean.isFinite else { return nil }
		guard autoregressive.count <= 2, movingAverage.count <= 2 else { return nil }
		guard autoregressive.allSatisfy({ $0.isFinite }) else { return nil }
		guard movingAverage.allSatisfy({ $0.isFinite }) else { return nil }
		guard Self.isStationary(autoregressive) else { return nil }
		self.name = name
		self.mean = mean
		self.volatility = volatility
		self.autoregressive = autoregressive
		self.movingAverage = movingAverage
	}

	/// Whether an autoregressive coefficient vector gives a stationary process.
	///
	/// - Parameter phi: The coefficients, most recent lag first.
	/// - Returns: `true` if the characteristic roots lie outside the unit circle.
	public static func isStationary(_ phi: [Double]) -> Bool {
		switch phi.count {
		case 0:
			return true
		case 1:
			return abs(phi[0]) < 1
		case 2:
			// The stationarity triangle for AR(2). All three are needed: the first
			// alone admits explosive oscillation, and the pair without it admits a
			// unit root on the boundary.
			let second = phi[1]
			guard abs(second) < 1 else { return false }
			let sum: Double = phi[0] + second
			guard sum < 1 else { return false }
			let difference: Double = second - phi[0]
			return difference < 1
		default:
			return false
		}
	}

	/// A state at the long-run mean with no accumulated history.
	///
	/// The natural place to start a path. Beginning elsewhere means the first stretch
	/// of the simulation is the process finding its level, which is a transient nobody
	/// usually wants in their sample.
	public var stationaryState: ARMAState {
		ARMAState(value: mean,
				  deviations: [Double](repeating: 0, count: autoregressive.count),
				  errors: [Double](repeating: 0, count: movingAverage.count))
	}

	/// Advances one period.
	///
	/// - Parameters:
	///   - current: The previous state.
	///   - dt: Ignored beyond being positive — ARMA steps one period at a time.
	///   - normalDraws: A standard normal draw.
	/// - Returns: The next state.
	public func step(from current: ARMAState, dt: Double, normalDraws: Double) -> ARMAState {
		guard dt > 0 else { return current }

		let shock: Double = volatility * normalDraws

		var deviation: Double = shock
		for (index, coefficient) in autoregressive.enumerated() where index < current.deviations.count {
			let contribution: Double = coefficient * current.deviations[index]
			deviation += contribution
		}
		for (index, coefficient) in movingAverage.enumerated() where index < current.errors.count {
			let contribution: Double = coefficient * current.errors[index]
			deviation += contribution
		}

		var nextDeviations = current.deviations
		if !nextDeviations.isEmpty {
			nextDeviations.removeLast()
			nextDeviations.insert(deviation, at: 0)
		}
		var nextErrors = current.errors
		if !nextErrors.isEmpty {
			nextErrors.removeLast()
			nextErrors.insert(shock, at: 0)
		}

		return ARMAState(value: mean + deviation, deviations: nextDeviations, errors: nextErrors)
	}

	// MARK: - Analytical properties

	/// The variance of the stationary distribution.
	///
	/// Closed form for the orders this covers. A pure MA is `σ²(1 + Σθ²)`; an AR(1) is
	/// `σ²/(1 − φ²)`; AR(2) and ARMA(1,1) have their own expressions, all derived from
	/// the Yule–Walker equations.
	public var stationaryVariance: Double? {
		let shockVariance: Double = volatility * volatility
		switch (autoregressive.count, movingAverage.count) {
		case (0, _):
			var total: Double = 1
			for theta in movingAverage { total += theta * theta }
			return shockVariance * total

		case (1, 0):
			let phi = autoregressive[0]
			let remaining: Double = 1 - phi * phi
			guard remaining > 0 else { return nil }
			return shockVariance / remaining

		case (1, 1):
			let phi = autoregressive[0], theta = movingAverage[0]
			let remaining: Double = 1 - phi * phi
			guard remaining > 0 else { return nil }
			let cross: Double = 2 * phi * theta
			let numerator: Double = 1 + cross + theta * theta
			return shockVariance * numerator / remaining

		case (2, 0):
			let one = autoregressive[0], two = autoregressive[1]
			// γ₀ = σ²(1 − φ₂) / ((1 + φ₂)((1 − φ₂)² − φ₁²))
			let onePlus: Double = 1 + two
			let oneMinus: Double = 1 - two
			let squared: Double = oneMinus * oneMinus - one * one
			let denominator: Double = onePlus * squared
			guard denominator != 0 else { return nil }
			return shockVariance * oneMinus / denominator

		default:
			return nil
		}
	}

	/// The autocorrelation at a lag.
	///
	/// - Parameter lag: The lag in periods, non-negative.
	/// - Returns: The correlation between `Xₜ` and `Xₜ₊lag`, or `nil` for an order
	///   whose closed form is not carried here.
	///
	/// This is the property that distinguishes the members of the family from each
	/// other, and from any i.i.d. series with the same stationary distribution. An
	/// MA(q) cuts to exactly zero beyond lag `q`; an AR decays geometrically and never
	/// reaches zero. Nothing about the variance would notice the difference.
	public func autocorrelation(lag: Int) -> Double? {
		guard lag >= 0 else { return nil }
		if lag == 0 { return 1 }

		switch (autoregressive.count, movingAverage.count) {
		case (0, let q):
			// MA(q): zero beyond lag q — the sharp cut-off that identifies the family.
			guard lag <= q else { return 0 }
			var numerator: Double = movingAverage[lag - 1]
			for index in 0..<(q - lag) {
				let product: Double = movingAverage[index] * movingAverage[index + lag]
				numerator += product
			}
			var denominator: Double = 1
			for theta in movingAverage { denominator += theta * theta }
			guard denominator > 0 else { return nil }
			return numerator / denominator

		case (1, 0):
			return Foundation.pow(autoregressive[0], Double(lag))

		case (1, 1):
			let phi = autoregressive[0], theta = movingAverage[0]
			let cross: Double = 2 * phi * theta
			let denominator: Double = 1 + cross + theta * theta
			guard denominator != 0 else { return nil }
			let paired: Double = 1 + phi * theta
			let sum: Double = phi + theta
			let first: Double = paired * sum / denominator
			guard lag > 1 else { return first }
			let decay: Double = Foundation.pow(phi, Double(lag - 1))
			return first * decay

		case (2, 0):
			// Yule–Walker: ρ₁ = φ₁/(1 − φ₂), then ρₖ = φ₁ρₖ₋₁ + φ₂ρₖ₋₂.
			let one = autoregressive[0], two = autoregressive[1]
			let remaining: Double = 1 - two
			guard remaining != 0 else { return nil }
			var previous: Double = 1
			var current: Double = one / remaining
			if lag == 1 { return current }
			for _ in 2...lag {
				let next: Double = one * current + two * previous
				previous = current
				current = next
			}
			return current

		default:
			return nil
		}
	}

	/// Whether this process is the same law as an ``AutoregressiveOne``.
	///
	/// True only for a pure AR(1) with matching parameters. Exists so the overlap
	/// between the two types can be asserted rather than assumed: they are separate
	/// because one models the continuous-time correspondence and the other the
	/// discrete family, and separate implementations of one law are exactly what this
	/// package's structure is meant to prevent going unchecked.
	///
	/// - Parameter other: The AR(1) process to compare against.
	/// - Returns: `true` if both describe the same process.
	public func matchesAutoregressiveOne(_ other: AutoregressiveOne) -> Bool {
		guard autoregressive.count == 1, movingAverage.isEmpty else { return false }
		guard abs(autoregressive[0] - other.persistence) < 1e-12 else { return false }
		guard abs(mean - other.longRunMean) < 1e-12 else { return false }
		return abs(volatility - other.shockVolatility) < 1e-12
	}
}
