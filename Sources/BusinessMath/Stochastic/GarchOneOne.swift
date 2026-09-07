//
//  GarchOneOne.swift
//  BusinessMath
//
//  GARCH(1,1): σ²ₜ = ω + α·r²ₜ₋₁ + β·σ²ₜ₋₁,  rₜ = σₜ·zₜ
//

import Foundation
import Numerics

/// The state of a GARCH process: the latest return and the variance that produced it.
///
/// Two components, because the variance is what carries memory. A process holding only
/// the return would have nowhere to accumulate the volatility clustering that is the
/// whole reason to use GARCH.
public struct GarchState: ProcessState, Sendable, Equatable {

	/// Arithmetic is in `Double`.
	public typealias Scalar = Double

	/// One standard normal draw per step; the variance is deterministic given the
	/// previous state.
	public typealias NormalDraws = Double

	/// Two components: the return and the conditional variance.
	public static var dimension: Int { 2 }

	/// The most recent return, `rₜ`.
	public let value: Double

	/// The conditional variance that generated it, `σ²ₜ`.
	public let variance: Double

	/// Creates a state.
	///
	/// - Parameters:
	///   - value: The most recent return.
	///   - variance: The conditional variance that generated it, non-negative.
	public init(value: Double, variance: Double) {
		self.value = value
		self.variance = variance
	}

	/// The conditional volatility, `σₜ`.
	public var volatility: Double {
		Swift.max(0, variance).squareRoot()
	}
}

/// A GARCH(1,1) process: returns whose volatility clusters.
///
/// Financial returns are close to uncorrelated but nowhere near independent — a large
/// move is followed by more large moves, in either direction. That is what GARCH
/// captures and what an i.i.d. distribution cannot, however fat its tails.
///
/// Binds Risk Solver's `PsiGARCH11(omega, alpha, beta)`.
///
/// ```swift
/// // Daily equity-like returns: persistent, with a long-run vol near 1.6% a day.
/// let garch = GarchOneOne(name: "Equity", constant: 0.000004,
///                         shockWeight: 0.08, persistenceWeight: 0.90)!
/// print(garch.stationaryVariance.squareRoot())   // ≈ 0.0141
/// print(garch.persistence)                        // 0.98 — slow decay
/// ```
///
/// ## The recursion
///
/// ```
/// σ²ₜ = ω + α·r²ₜ₋₁ + β·σ²ₜ₋₁
/// rₜ  = σₜ·zₜ,   z ~ N(0, 1)
/// ```
///
/// `α` is how sharply volatility reacts to the last move; `β` is how long it
/// remembers. Their sum is the persistence, and for equity returns it is typically
/// just under one — which is why a quiet market stays quiet and a turbulent one stays
/// turbulent for weeks.
///
/// ## Why the returns are uncorrelated but not independent
///
/// `E[rₜ | past] = 0` for every history, so the returns themselves have no
/// autocorrelation at any lag — a fact worth testing, because it is what makes GARCH
/// compatible with an efficient market. The **squared** returns are strongly
/// autocorrelated, and that is the clustering. Both are asserted in the tests; a
/// process with either one wrong is not GARCH.
///
/// ## Stationarity, and the fat tails that come free
///
/// `α + β < 1` is required for a finite long-run variance, `ω/(1 − α − β)`, and is
/// refused otherwise: above one the variance diverges and every stationary quantity
/// this type reports would be describing something that does not exist.
///
/// The unconditional distribution has kurtosis above three even though every step is
/// conditionally normal — mixing normals with different variances always does. That is
/// not an extra assumption; it falls out, and is finite only when
/// `3α² + 2αβ + β² < 1`, which ``hasFiniteFourthMoment`` reports.
///
/// ## `dt` is one period
///
/// GARCH is a discrete-time model with no continuous-time limit that preserves its
/// structure, so unlike ``AutoregressiveOne`` there is no exact sub-period step to
/// offer. ``step(from:dt:normalDraws:)`` advances one period for any positive `dt`
/// and says so here rather than silently scaling something that has no scaling law.
public struct GarchOneOne: StochasticProcess, Sendable {

	/// The state carries the return and its variance.
	public typealias State = GarchState

	/// A label for reporting.
	public let name: String

	/// `ω`, the variance floor. Positive.
	public let constant: Double

	/// `α`, the weight on the last squared return. Non-negative.
	public let shockWeight: Double

	/// `β`, the weight on the last variance. Non-negative.
	public let persistenceWeight: Double

	/// Returns are signed.
	public let allowsNegativeValues: Bool = true

	/// One source of randomness.
	public let factors: Int = 1

	/// Creates a GARCH(1,1) process.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - constant: `ω`, strictly positive. At zero the variance can collapse to
	///     zero permanently, which is an absorbing state rather than a model.
	///   - shockWeight: `α`, non-negative.
	///   - persistenceWeight: `β`, non-negative.
	/// - Returns: `nil` unless `ω > 0`, `α ≥ 0`, `β ≥ 0` and `α + β < 1`.
	public init?(name: String, constant: Double, shockWeight: Double, persistenceWeight: Double) {
		guard constant > 0, constant.isFinite else { return nil }
		guard shockWeight >= 0, shockWeight.isFinite else { return nil }
		guard persistenceWeight >= 0, persistenceWeight.isFinite else { return nil }
		guard shockWeight + persistenceWeight < 1 else { return nil }
		self.name = name
		self.constant = constant
		self.shockWeight = shockWeight
		self.persistenceWeight = persistenceWeight
	}

	/// Advances one period.
	///
	/// - Parameters:
	///   - current: The previous return and variance.
	///   - dt: Ignored beyond being positive — GARCH steps one period at a time.
	///   - normalDraws: A standard normal draw.
	/// - Returns: The next return and the variance that produced it.
	public func step(from current: GarchState, dt: Double, normalDraws: Double) -> GarchState {
		guard dt > 0 else { return current }
		let lastSquared: Double = current.value * current.value
		let reaction: Double = shockWeight * lastSquared
		let memory: Double = persistenceWeight * current.variance
		let variance: Double = constant + reaction + memory
		let safeVariance: Double = Swift.max(0, variance)
		let volatility: Double = safeVariance.squareRoot()
		return GarchState(value: volatility * normalDraws, variance: safeVariance)
	}

	// MARK: - Analytical properties

	/// `α + β`, how much of today's volatility survives to tomorrow.
	public var persistence: Double {
		shockWeight + persistenceWeight
	}

	/// The unconditional variance, `ω/(1 − α − β)`.
	public var stationaryVariance: Double {
		// `α + β < 1` is an initialiser invariant, so this is strictly positive.
		// Restated because the guard is far from the division.
		let remaining: Double = 1 - persistence
		guard remaining > 0 else { return .infinity }
		return constant / remaining
	}

	/// A state already at the long-run variance, with no return yet.
	///
	/// The natural place to start a path: beginning at some other variance means the
	/// first stretch of the simulation is the process finding its level, which is a
	/// transient nobody usually wants in their sample.
	public var stationaryState: GarchState {
		GarchState(value: 0, variance: stationaryVariance)
	}

	/// How long a volatility shock takes to decay halfway, in periods.
	public var volatilityHalfLife: Double {
		guard persistence > 0, persistence < 1 else { return .infinity }
		return Foundation.log(0.5) / Foundation.log(persistence)
	}

	/// Whether the unconditional fourth moment is finite, `3α² + 2αβ + β² < 1`.
	///
	/// When it is not, the kurtosis of the return distribution is infinite: sample
	/// kurtosis will keep climbing as the sample grows rather than settling, and any
	/// risk measure that leans on a fourth moment is meaningless. Perfectly ordinary
	/// fitted parameters land here, so it is worth being able to ask.
	public var hasFiniteFourthMoment: Bool {
		let a: Double = shockWeight
		let b: Double = persistenceWeight
		let combined: Double = 3 * a * a + 2 * a * b + b * b
		return combined < 1
	}

	/// The unconditional kurtosis of the returns, or `nil` if the fourth moment
	/// diverges.
	///
	/// `3(1 − (α+β)²) / (1 − (α+β)² − 2α²)`. Strictly greater than three whenever
	/// `α > 0`: conditionally normal steps with a varying variance are a mixture of
	/// normals, and a mixture of normals is always heavier-tailed than any one of
	/// them.
	public var unconditionalKurtosis: Double? {
		guard hasFiniteFourthMoment else { return nil }
		let sum: Double = persistence
		let squared: Double = sum * sum
		let numerator: Double = 3 * (1 - squared)
		let denominator: Double = 1 - squared - 2 * shockWeight * shockWeight
		guard denominator > 0 else { return nil }
		return numerator / denominator
	}
}
