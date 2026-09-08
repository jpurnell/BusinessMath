//
//  AsymmetricGarch.swift
//  BusinessMath
//
//  EGARCH(1,1) and APARCH(1,1) — the two conditional-variance recursions that
//  ``GarchOneOne`` cannot express, plus the ARCH(1) and unconditional-volatility
//  entry points that it can.
//
//  Why two new types and not three: ARCH(1) *is* GARCH(1,1) with the persistence
//  weight at zero, so it gets a factory rather than a duplicate recursion. EGARCH
//  and APARCH are different equations — one models the log variance so that the
//  coefficients need no positivity constraint, the other raises volatility to a
//  free power rather than assuming the square. Neither is a special case of the
//  other or of GARCH.
//
//  Both are asymmetric: a negative return raises tomorrow's variance more than a
//  positive one of the same size. That is the leverage effect, and it is the whole
//  reason to reach past GARCH(1,1), which by construction cannot see the sign of a
//  shock — it squares it first.
//

import Foundation
import Numerics

// MARK: - Entry points GARCH(1,1) was missing

public extension GarchOneOne {

	/// Creates a GARCH(1,1) from the volatility it should settle at, rather than from
	/// the variance floor.
	///
	/// A model is usually stated the way it is here — "5% daily vol, α of 0.1, β of
	/// 0.85" — and `ω` is then whatever makes that true. Since the stationary variance
	/// is `ω / (1 − α − β)`, the floor is `σ²(1 − α − β)`. Deriving it beats asking a
	/// caller to, because getting it wrong produces a model that runs perfectly well
	/// and settles somewhere else.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - unconditionalVolatility: The `σ` the process settles at. Strictly positive.
	///   - shockWeight: `α`, non-negative.
	///   - persistenceWeight: `β`, non-negative.
	/// - Returns: `nil` unless the volatility is positive and `α + β < 1`.
	init?(name: String, unconditionalVolatility: Double,
		  shockWeight: Double, persistenceWeight: Double) {
		guard unconditionalVolatility > 0, unconditionalVolatility.isFinite else { return nil }
		guard shockWeight >= 0, persistenceWeight >= 0 else { return nil }
		let decay: Double = 1 - shockWeight - persistenceWeight
		guard decay > 0 else { return nil }
		let variance: Double = unconditionalVolatility * unconditionalVolatility
		let floor: Double = variance * decay
		self.init(name: name, constant: floor,
				  shockWeight: shockWeight, persistenceWeight: persistenceWeight)
	}

	/// An ARCH(1) process: GARCH(1,1) with no memory of yesterday's variance.
	///
	/// Engle's original model. It is not given its own type because it is not its own
	/// recursion — `β = 0` is the entire difference, and a second type carrying the
	/// same three lines would be a place for them to drift apart.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - unconditionalVolatility: The `σ` the process settles at. Strictly positive.
	///   - shockWeight: `α`, in `[0, 1)`.
	/// - Returns: `nil` unless the volatility is positive and `α < 1`.
	static func arch(name: String, unconditionalVolatility: Double,
					 shockWeight: Double) -> GarchOneOne? {
		GarchOneOne(name: name, unconditionalVolatility: unconditionalVolatility,
					shockWeight: shockWeight, persistenceWeight: 0)
	}
}

// MARK: - EGARCH(1,1)

/// Nelson's exponential GARCH — a conditional variance modelled in logs.
///
/// ```
/// ln σ²ₜ = ω + β ln σ²ₜ₋₁ + α · g(zₜ₋₁),   g(z) = θ z + γ (|z| − E|z|)
/// ```
///
/// where `z` is the previous standardised return. Two things follow from working in
/// logs, and they are the reasons to prefer this over ``GarchOneOne``:
///
/// - **No positivity constraints.** `exp` of anything is positive, so `ω`, `α`, `θ`
///   and `γ` are free to be negative. GARCH needs `ω > 0` and non-negative weights
///   precisely because it models the variance directly, and those constraints bind
///   in estimation.
/// - **Asymmetry is expressible.** `θ` multiplies `z` with its sign intact, so a
///   fall and a rise of the same size produce different variances. GARCH squares the
///   shock before it ever reaches the recursion and cannot represent this at all.
///
/// The `α · g(z)` nesting — rather than folding `α` into `θ` and `γ` — matches the
/// four coefficients Frontline's `PsiEGARCH11` signature takes. It is redundant:
/// `(α, θ, γ)` and `(1, αθ, αγ)` are the same process. That is a property of their
/// parameterisation, not a defect here, and it is documented rather than quietly
/// normalised away so a model transcribed from a spreadsheet keeps its coefficients.
public struct ExponentialGarch: StochasticProcess, Sendable {

	/// Same state as GARCH — the return and the variance that produced it.
	public typealias State = GarchState

	/// A label for reporting.
	public let name: String

	/// `ω`, the level of the log variance. Any finite value.
	public let constant: Double

	/// `α`, the weight on the news impact curve. Any finite value.
	public let shockWeight: Double

	/// `β`, the weight on yesterday's log variance. `|β| < 1` for stationarity.
	public let persistenceWeight: Double

	/// `θ`, the sign term. Negative gives the usual leverage effect: a fall raises
	/// variance more than a rise.
	public let leverage: Double

	/// `γ`, the magnitude term — how much a large shock of either sign matters.
	public let magnitude: Double

	/// Returns are signed.
	public let allowsNegativeValues: Bool = true

	/// One source of randomness.
	public let factors: Int = 1

	/// `E|z|` for a standard normal, `√(2/π)`.
	///
	/// Derived rather than written out: the constant is only correct for a Gaussian
	/// innovation, and a literal would survive a change of innovation distribution
	/// without anyone noticing it had stopped being true.
	///
	/// Written as twice the density at zero, which is the same number by a one-line
	/// argument — `E|z| = 2∫₀^∞ z φ(z) dz = 2[−φ(z)]₀^∞ = 2φ(0)` — and which reaches it
	/// through the library's own ``normalPDF(x:mean:stdDev:)`` rather than through a
	/// second spelling of the Gaussian constant.
	public static var expectedAbsoluteNormal: Double {
		2 * normalPDF(x: 0.0)
	}

	/// Creates an EGARCH(1,1).
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - constant: `ω`, the log-variance level.
	///   - shockWeight: `α`, the scale on the news impact curve.
	///   - persistenceWeight: `β`. Must satisfy `|β| < 1`.
	///   - leverage: `θ`, the sign term. Defaults to zero, a symmetric model.
	///   - magnitude: `γ`, the size term. Defaults to one.
	/// - Returns: `nil` unless every coefficient is finite and `|β| < 1`.
	public init?(name: String, constant: Double, shockWeight: Double,
				 persistenceWeight: Double, leverage: Double = 0, magnitude: Double = 1) {
		guard constant.isFinite, shockWeight.isFinite, persistenceWeight.isFinite else { return nil }
		guard leverage.isFinite, magnitude.isFinite else { return nil }
		guard Swift.abs(persistenceWeight) < 1 else { return nil }
		self.name = name
		self.constant = constant
		self.shockWeight = shockWeight
		self.persistenceWeight = persistenceWeight
		self.leverage = leverage
		self.magnitude = magnitude
	}

	/// Creates an EGARCH(1,1) from the volatility its log variance settles at.
	///
	/// `g` has mean zero under a standard normal innovation, so `E[ln σ²] = ω/(1 − β)`
	/// and `ω = (1 − β) ln σ²`. Note what that pins: the *geometric* mean of the
	/// variance, not the arithmetic one. `exp(E[ln σ²]) ≤ E[σ²]` by Jensen, so a
	/// simulated path from this initialiser has a slightly higher average variance
	/// than the figure passed in. Said here because the gap is real, small, and
	/// otherwise looks like a bug.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - unconditionalVolatility: The `σ` whose log the variance settles at.
	///   - shockWeight: `α`.
	///   - persistenceWeight: `β`, with `|β| < 1`.
	///   - leverage: `θ`. Defaults to zero.
	///   - magnitude: `γ`. Defaults to one.
	/// - Returns: `nil` unless the volatility is positive and `|β| < 1`.
	public init?(name: String, unconditionalVolatility: Double, shockWeight: Double,
				 persistenceWeight: Double, leverage: Double = 0, magnitude: Double = 1) {
		guard unconditionalVolatility > 0, unconditionalVolatility.isFinite else { return nil }
		guard Swift.abs(persistenceWeight) < 1 else { return nil }
		let variance: Double = unconditionalVolatility * unconditionalVolatility
		let logVariance: Double = Double.log(variance)
		let decay: Double = 1 - persistenceWeight
		let level: Double = logVariance * decay
		self.init(name: name, constant: level, shockWeight: shockWeight,
				  persistenceWeight: persistenceWeight, leverage: leverage, magnitude: magnitude)
	}

	/// The news impact curve, `g(z) = θz + γ(|z| − E|z|)`.
	///
	/// - Parameter z: A standardised return.
	/// - Returns: What that return does to tomorrow's log variance, before `α`.
	public func newsImpact(_ z: Double) -> Double {
		let signed: Double = leverage * z
		let excess: Double = Swift.abs(z) - Self.expectedAbsoluteNormal
		let sized: Double = magnitude * excess
		return signed + sized
	}

	/// Advances one period.
	///
	/// - Parameters:
	///   - current: The previous return and variance.
	///   - dt: Ignored beyond being positive — EGARCH steps one period at a time.
	///   - normalDraws: A standard normal draw.
	/// - Returns: The next return and the variance that produced it.
	public func step(from current: GarchState, dt: Double, normalDraws: Double) -> GarchState {
		guard dt > 0 else { return current }
		guard current.variance > 0 else { return current }
		let volatility: Double = current.variance.squareRoot()
		// The variance being positive is not quite enough: a variance below the
		// smallest normal takes its square root down to zero, and the standardised
		// return is a division by it.
		guard volatility > 0 else { return current }
		let z: Double = current.value / volatility
		let impact: Double = shockWeight * newsImpact(z)
		let memory: Double = persistenceWeight * Double.log(current.variance)
		let logVariance: Double = constant + memory + impact
		let variance: Double = Double.exp(logVariance)
		guard variance.isFinite, variance > 0 else { return current }
		let nextVolatility: Double = variance.squareRoot()
		return GarchState(value: nextVolatility * normalDraws, variance: variance)
	}

	// MARK: - Analytical properties

	/// `β`. Below one in absolute value the log variance is mean-reverting.
	public var persistence: Double { persistenceWeight }

	/// The variance the log recursion settles at, `exp(ω / (1 − β))`.
	///
	/// The geometric mean, per the note on the volatility initialiser.
	public var stationaryVariance: Double {
		let decay: Double = 1 - persistenceWeight
		guard decay != 0 else { return .infinity }
		let level: Double = constant / decay
		return Double.exp(level)
	}

	/// A state already at the stationary variance, with a zero return.
	public var stationaryState: GarchState {
		GarchState(value: 0, variance: stationaryVariance)
	}

	/// Periods for a log-variance shock to decay by half, or `nil` at `β ≤ 0`.
	///
	/// Undefined without positive persistence: at `β = 0` there is nothing to decay,
	/// and at `β < 0` the shock alternates in sign rather than decaying monotonically,
	/// so a half-life would describe the wrong shape.
	public var volatilityHalfLife: Double? {
		guard persistenceWeight > 0, persistenceWeight < 1 else { return nil }
		let numerator: Double = Double.log(0.5)
		let denominator: Double = Double.log(persistenceWeight)
		guard denominator != 0 else { return nil }
		return numerator / denominator
	}
}

// MARK: - APARCH(1,1)

/// The asymmetric power ARCH of Ding, Granger and Engle.
///
/// ```
/// σₜ^δ = ω + α (|rₜ₋₁| − γ rₜ₋₁)^δ + β σₜ₋₁^δ
/// ```
///
/// Two generalisations of GARCH at once, and the second is the interesting one:
///
/// - `γ` tilts the absolute return, so a fall and a rise of the same size enter with
///   different weights — the leverage effect again, reached differently from EGARCH.
/// - `δ` is a *free power*. GARCH asserts `δ = 2`, that the right thing to model is
///   the variance. Taylor and Schwert's models assert `δ = 1`, the absolute
///   deviation. APARCH declines to assert and estimates it, which is what makes it
///   the family the others sit inside: `γ = 0, δ = 2` is exactly ``GarchOneOne``.
///
/// The state still carries a variance rather than `σ^δ`, so it interoperates with
/// GARCH and EGARCH and so `volatility` means the same thing in all three.
public struct AsymmetricPowerArch: StochasticProcess, Sendable {

	/// Same state as GARCH — the return and the variance that produced it.
	public typealias State = GarchState

	/// A label for reporting.
	public let name: String

	/// `ω`, the floor on `σ^δ`. Strictly positive.
	public let constant: Double

	/// `α`, the weight on the tilted absolute shock. Non-negative.
	public let shockWeight: Double

	/// `β`, the weight on yesterday's `σ^δ`. Non-negative.
	public let persistenceWeight: Double

	/// `γ`, the tilt, in `(−1, 1)`. Positive is the usual leverage direction.
	public let asymmetry: Double

	/// `δ`, the power. Strictly positive. Two recovers GARCH.
	public let power: Double

	/// `1/δ`, computed once beside the guard that establishes `δ > 0`.
	///
	/// Stored rather than recomputed at each of the two places that raise a `σ^δ` back
	/// to a `σ`, so the reciprocal exists in one spot next to the check that makes it
	/// safe instead of twice, far from it.
	private let inversePower: Double

	/// Returns are signed.
	public let allowsNegativeValues: Bool = true

	/// One source of randomness.
	public let factors: Int = 1

	/// Creates an APARCH(1,1).
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - constant: `ω`, strictly positive.
	///   - shockWeight: `α`, non-negative.
	///   - persistenceWeight: `β`, non-negative.
	///   - asymmetry: `γ`, strictly inside `(−1, 1)`. At `|γ| ≥ 1` the tilted shock
	///     `|r| − γr` goes negative on one side, and a negative base raised to a
	///     fractional power is not a real number.
	///   - power: `δ`, strictly positive. Defaults to two.
	/// - Returns: `nil` unless every constraint above holds.
	public init?(name: String, constant: Double, shockWeight: Double,
				 persistenceWeight: Double, asymmetry: Double = 0, power: Double = 2) {
		guard constant > 0, constant.isFinite else { return nil }
		guard shockWeight >= 0, shockWeight.isFinite else { return nil }
		guard persistenceWeight >= 0, persistenceWeight.isFinite else { return nil }
		guard asymmetry > -1, asymmetry < 1 else { return nil }
		guard power > 0, power.isFinite else { return nil }
		self.name = name
		self.constant = constant
		self.shockWeight = shockWeight
		self.persistenceWeight = persistenceWeight
		self.asymmetry = asymmetry
		self.power = power
		self.inversePower = 1 / power
	}

	/// Creates an APARCH(1,1) from the volatility it should settle at, rather than from
	/// the floor on `σ^δ`.
	///
	/// The counterpart of ``ExponentialGarch/init(name:unconditionalVolatility:shockWeight:persistenceWeight:leverage:magnitude:)``,
	/// and the form a model is usually stated in — "20% annualised vol, δ of 1.5, a tilt
	/// of 0.3" — where `ω` is whatever makes that true.
	///
	/// ## The derivation, and why it is not circular
	///
	/// `σ^δ` settles at `ω / (1 − α·κ − β)` where `κ = E(|z| − γz)^δ`, so
	/// `ω = σ^δ (1 − α·κ − β)`. At `δ = 2` this collapses to the familiar
	/// `ω = σ²(1 − α − β)`, since `κ = E[z²] = 1` there.
	///
	/// It looks as though `κ` should depend on the process and therefore on `ω`, which
	/// would make this circular. It does not: `κ` is an expectation over the
	/// *innovation*, not over the process, so it is fixed by `γ` and `δ` alone —
	/// see ``expectedTiltedPower(asymmetry:power:)``. What it does depend on is the
	/// innovation being standard normal, which is the same assumption
	/// ``isStationary`` and every other analytical member here already makes.
	///
	/// - Parameters:
	///   - name: A label for reporting.
	///   - unconditionalVolatility: The `σ` the process settles at. Strictly positive.
	///   - shockWeight: `α`, non-negative.
	///   - persistenceWeight: `β`, non-negative.
	///   - asymmetry: `γ`, strictly inside `(−1, 1)`.
	///   - power: `δ`, strictly positive. Defaults to two.
	/// - Returns: `nil` if any parameter is outside its support, or if the coefficients
	///   are not stationary — a process that does not settle has no volatility to settle
	///   at, so there is no `ω` to derive and refusing is the only honest answer.
	public init?(name: String, unconditionalVolatility: Double, shockWeight: Double,
				 persistenceWeight: Double, asymmetry: Double = 0, power: Double = 2) {
		guard unconditionalVolatility > 0, unconditionalVolatility.isFinite else { return nil }
		guard shockWeight >= 0, shockWeight.isFinite else { return nil }
		guard persistenceWeight >= 0, persistenceWeight.isFinite else { return nil }
		guard asymmetry > -1, asymmetry < 1 else { return nil }
		guard power > 0, power.isFinite else { return nil }

		let kappa: Double = Self.expectedTiltedPower(asymmetry: asymmetry, power: power)
		let reaction: Double = shockWeight * kappa
		let multiplier: Double = reaction + persistenceWeight
		let decay: Double = 1 - multiplier
		guard decay > 0 else { return nil }

		let powered: Double = Double.pow(unconditionalVolatility, power)
		let floor: Double = powered * decay
		guard floor > 0, floor.isFinite else { return nil }
		self.init(name: name, constant: floor, shockWeight: shockWeight,
				  persistenceWeight: persistenceWeight, asymmetry: asymmetry, power: power)
	}

	/// Advances one period.
	///
	/// - Parameters:
	///   - current: The previous return and variance.
	///   - dt: Ignored beyond being positive — APARCH steps one period at a time.
	///   - normalDraws: A standard normal draw.
	/// - Returns: The next return and the variance that produced it.
	public func step(from current: GarchState, dt: Double, normalDraws: Double) -> GarchState {
		guard dt > 0 else { return current }
		guard current.variance >= 0 else { return current }
		let previousVolatility: Double = current.variance.squareRoot()
		let tilted: Double = Self.tilt(current.value, asymmetry: asymmetry)
		let reaction: Double = shockWeight * Double.pow(tilted, power)
		let memory: Double = persistenceWeight * Double.pow(previousVolatility, power)
		let powered: Double = constant + reaction + memory
		guard powered > 0, powered.isFinite else { return current }
		let volatility: Double = Double.pow(powered, inversePower)
		guard volatility.isFinite else { return current }
		let variance: Double = volatility * volatility
		return GarchState(value: volatility * normalDraws, variance: variance)
	}

	/// The tilted absolute shock, `|r| − γr`, floored at zero.
	///
	/// The floor cannot bind while `|γ| < 1`, which the initialiser enforces; it is
	/// there because the alternative to a guard on a base about to be raised to a
	/// fractional power is a `NaN` that propagates for the rest of the path.
	///
	/// - Parameters:
	///   - value: The previous return.
	///   - asymmetry: `γ`.
	/// - Returns: The base of the shock term.
	public static func tilt(_ value: Double, asymmetry: Double) -> Double {
		let size: Double = Swift.abs(value)
		let signed: Double = asymmetry * value
		let tilted: Double = size - signed
		return Swift.max(0, tilted)
	}

	/// `α · E(|z| − γz)^δ + β`, the factor a shock to `σ^δ` is multiplied by each
	/// period. Below one the process is stationary.
	public var powerPersistence: Double {
		let reaction: Double = shockWeight * expectedTiltedPower
		return reaction + persistenceWeight
	}

	/// Whether shocks to `σ^δ` decay.
	public var isStationary: Bool { powerPersistence < 1 }

	/// `E(|z| − γz)^δ` under a standard normal `z`, in closed form.
	///
	/// This is the `κ` of Ding, Granger and Engle, and it does not need integrating.
	/// Split the expectation by the sign of `z`: above zero the tilted shock is
	/// `((1 − γ)z)^δ` and below it `((1 + γ)|z|)^δ`, so the tilt factors straight out
	/// and what is left is the absolute moment of a standard normal, which is exact:
	///
	/// ```
	/// E(|z| − γz)^δ = [(1 − γ)^δ + (1 + γ)^δ] · 2^(δ/2 − 1) · Γ((δ+1)/2) / √π
	/// ```
	///
	/// Worth stating why this is not quadrature. The obvious implementation integrates
	/// `(|z| − γz)^δ φ(z)` on a grid, and for `δ = 2` that is accurate to rounding — so
	/// a test written at the GARCH corner passes and the method looks sound. It is not:
	/// at fractional `δ` the integrand behaves like `|z|^δ` near the origin, whose
	/// higher derivatives are unbounded there, and Simpson's error falls off as
	/// `n^-(δ+1)` rather than `n^-4`. At `δ = 1.5` a grid of 800 is out by 7e-7 and
	/// doubling it buys a factor of five rather than sixteen. The closed form is exact
	/// at every `δ`, cheaper, and removes a tuning parameter that had no right answer.
	public var expectedTiltedPower: Double {
		Self.expectedTiltedPower(asymmetry: asymmetry, power: power)
	}

	/// `E(|z| − γz)^δ` from the two shape parameters alone, before any value exists.
	///
	/// Static because the unconditional-volatility initialiser needs it to derive `ω`,
	/// and `ω` has to be known before there is a distribution to ask.
	///
	/// - Parameters:
	///   - asymmetry: `γ`, strictly inside `(−1, 1)`.
	///   - power: `δ`, strictly positive.
	/// - Returns: The expectation under a standard normal innovation.
	public static func expectedTiltedPower(asymmetry: Double, power: Double) -> Double {
		let lowSide: Double = Double.pow(1 - asymmetry, power)
		let highSide: Double = Double.pow(1 + asymmetry, power)
		let sides: Double = lowSide + highSide
		// 2^(δ/2 − 1) · Γ((δ+1)/2) / √π — the standard normal's δ-th absolute moment,
		// halved, since each side of the split carries half the mass.
		//
		// Assembled in logs, which is how the rest of the library writes a ratio of
		// gamma terms — see `inverseRegularizedIncompleteBeta`. It buys no extra range
		// here: the `2^(δ/2)` and the gamma grow together rather than against each
		// other, so the moment overflows around δ ≈ 301, before `Γ((δ+1)/2)` itself
		// does at δ ≈ 342. What it does buy is arithmetic with no division by a
		// constant in it, which is worth having when the alternative is a `/√π` no
		// reader and no checker can see a guard for.
		let logTwo: Double = Double.log(2)
		let exponent: Double = power / 2 - 1
		let logScale: Double = exponent * logTwo
		let shape: Double = (power + 1) / 2
		let logGammaTerm: Double = Double.logGamma(shape)
		let logRoot: Double = Double.log(Double.pi) / 2
		let logMoment: Double = logScale + logGammaTerm - logRoot
		let halfMoment: Double = Double.exp(logMoment)
		return sides * halfMoment
	}

	/// The `σ^δ` the process settles at, `ω / (1 − multiplier)`, or `nil` when it does
	/// not settle.
	public var stationaryPoweredVolatility: Double? {
		let decay: Double = 1 - powerPersistence
		guard decay > 0 else { return nil }
		return constant / decay
	}

	/// The variance the process settles at, or `nil` when it does not settle.
	public var stationaryVariance: Double? {
		guard let powered = stationaryPoweredVolatility else { return nil }
		let volatility: Double = Double.pow(powered, inversePower)
		return volatility * volatility
	}

	/// A state already at the stationary variance, or `nil` when there is none.
	public var stationaryState: GarchState? {
		guard let variance = stationaryVariance else { return nil }
		return GarchState(value: 0, variance: variance)
	}
}
