//
//  distributionStudentT.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Student's t, with any positive real degrees of freedom.
///
/// Binds Risk Solver's `PsiStudent` and, through ``PercentileParameterisable``,
/// `PsiStudentAlt`.
///
/// ```swift
/// let heavy = DistributionStudentT(degreesOfFreedom: 3)
/// let tail = heavy?.quantile(0.99)     // far beyond a normal's 2.33
/// ```
///
/// ## Why this exists separately from the t tests
///
/// The library already had ``tCDF(t:df:)`` and ``studentTPDF(t:df:)``, which is what a
/// hypothesis test needs: a p-value from a statistic. A *distribution* needs the
/// inverse as well, and needs to be a value that can be sampled, composed into a Monte
/// Carlo model, and handed to anything expecting a ``ContinuousDistribution``. Those
/// free functions also take an `Int`, which is right for a test — degrees of freedom
/// there come from counting observations — and wrong here, where a t is often used as a
/// heavy-tailed model in its own right and `ν` is a fitted shape with no obligation to
/// be whole.
///
/// ## The tails are the point
///
/// At `ν = 1` this is Cauchy and has no mean at all; below `ν = 2` there is no
/// variance; below `ν = 4` no kurtosis. ``mean`` and ``variance`` return `nil` in those
/// ranges rather than a number, because the alternative is a risk model that reports a
/// finite expected loss for a distribution that does not have one.
public struct DistributionStudentT: ContinuousDistribution, Sendable {

	/// The degrees of freedom, `ν`. Any positive real; small values are heavy-tailed.
	public let degreesOfFreedom: Double

	/// Creates a Student's t.
	///
	/// - Parameter degreesOfFreedom: `ν`, strictly positive and finite.
	/// - Returns: `nil` otherwise.
	public init?(degreesOfFreedom: Double) {
		guard degreesOfFreedom > 0, degreesOfFreedom.isFinite else { return nil }
		self.degreesOfFreedom = degreesOfFreedom
	}

	/// Creates a Student's t with whole degrees of freedom.
	///
	/// - Parameter degreesOfFreedom: `ν`, at least one.
	/// - Returns: `nil` for a non-positive count.
	public init?(degreesOfFreedom: Int) {
		self.init(degreesOfFreedom: Double(degreesOfFreedom))
	}

	// MARK: - The distribution

	/// The density at `t`.
	///
	/// Assembled in logs. The normalising constant is a ratio of gamma functions that
	/// overflows a `Double` around `ν = 340` while the density it belongs to is a
	/// perfectly ordinary number near one — here the two really do move against each
	/// other, unlike the APARCH moment, because `Γ((ν+1)/2)/Γ(ν/2)` grows only like
	/// `√(ν/2)` while each half overflows on its own.
	///
	/// - Parameter t: Any finite value.
	/// - Returns: The density, which is strictly positive everywhere.
	public func pdf(_ t: Double) -> Double {
		guard t.isFinite else { return 0 }
		guard degreesOfFreedom > 0 else { return Double.nan }
		let half: Double = degreesOfFreedom / 2
		let halfPlus: Double = (degreesOfFreedom + 1) / 2
		let logNumerator: Double = Double.logGamma(halfPlus)
		let logDenominator: Double = Double.logGamma(half)
		let logGammaRatio: Double = logNumerator - logDenominator
		let logSpread: Double = Double.log(degreesOfFreedom * Double.pi) / 2
		let normaliser: Double = logGammaRatio - logSpread
		let squared: Double = t * t
		let scaled: Double = squared / degreesOfFreedom
		let logKernel: Double = Double.log(1 + scaled)
		let shaped: Double = halfPlus * logKernel
		let total: Double = normaliser - shaped
		return Double.exp(total)
	}

	/// `P(X ≤ t)`.
	///
	/// Through the regularised incomplete beta, which is the standard route and the one
	/// ``tCDF(t:df:)`` already takes; the difference here is that `ν` never passes
	/// through an `Int`.
	///
	/// - Parameter t: Any value.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ t: Double) -> Double {
		guard t.isFinite else { return t > 0 ? 1 : 0 }
		if t == 0 { return 0.5 }
		let squared: Double = t * t
		let denominator: Double = degreesOfFreedom + squared
		guard denominator > 0 else { return Double.nan }
		let x: Double = degreesOfFreedom / denominator
		let half: Double = degreesOfFreedom / 2
		let incomplete = totalizedResult {
			try regularizedIncompleteBeta(x: x, a: half, b: 0.5)
		}
		guard incomplete.isFinite else { return Double.nan }
		let tailMass: Double = incomplete / 2
		return t > 0 ? 1 - tailMass : tailMass
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// Inverts the CDF's beta relation rather than root-finding on ``cdf(_:)``: with
	/// `x = I⁻¹(2·min(p, 1−p); ν/2, ½)` the quantile is `±√(ν(1−x)/x)`, signed by which
	/// side of the median `p` falls on. Exact inversion matters more here than for most
	/// distributions, because a bisection on a t with small `ν` is bisecting something
	/// that runs to infinity fast.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile; `±infinity` at the closed ends.
	public func quantile(_ p: Double) -> Double {
		guard p > 0, p < 1 else { return p <= 0 ? -.infinity : .infinity }
		// Exact by intent: the median of a `t` is exactly zero, and this is the one
		// probability where the beta inversion below would be handed `I⁻¹(1; a, b)`.
		if p.isEqual(to: 0.5) { return 0 }
		let lower: Bool = p < 0.5
		let tail: Double = lower ? p : 1 - p
		let doubled: Double = 2 * tail
		let half: Double = degreesOfFreedom / 2
		let x = totalizedResult {
			try inverseRegularizedIncompleteBeta(p: doubled, a: half, b: 0.5)
		}
		guard x.isFinite, x > 0 else { return lower ? -.infinity : .infinity }
		let complement: Double = 1 - x
		let ratio: Double = complement / x
		let magnitude: Double = degreesOfFreedom * ratio
		guard magnitude >= 0 else { return Double.nan }
		let root: Double = magnitude.squareRoot()
		return lower ? -root : root
	}

	// MARK: - Moments, where they exist

	/// Zero for `ν > 1`, and `nil` at or below it.
	///
	/// `nil` rather than zero at `ν ≤ 1`: the density is symmetric there too, so zero
	/// looks like the obvious answer, but the defining integral does not converge and
	/// a Cauchy has no mean. Sample averages from one do not settle anywhere.
	public var mean: Double? {
		degreesOfFreedom > 1 ? 0 : nil
	}

	/// `ν/(ν−2)` for `ν > 2`, and `nil` at or below it.
	public var variance: Double? {
		guard degreesOfFreedom > 2 else { return nil }
		let shortfall: Double = degreesOfFreedom - 2
		guard shortfall > 0 else { return nil }
		return degreesOfFreedom / shortfall
	}

	/// The square root of ``variance``, where that exists.
	public var standardDeviation: Double? {
		guard let variance else { return nil }
		return variance.squareRoot()
	}

	/// The excess kurtosis: `6/(ν−4)` for `ν > 4`, and `nil` at or below it.
	///
	/// Worth having explicitly because it is the number that says how much heavier than
	/// normal the tails are, and because the range where it stops existing — `ν ≤ 4`,
	/// well inside where people fit t distributions to returns — is exactly where a
	/// moment-matching routine would otherwise be handed an infinity.
	public var excessKurtosis: Double? {
		guard degreesOfFreedom > 4 else { return nil }
		let shortfall: Double = degreesOfFreedom - 4
		guard shortfall > 0 else { return nil }
		return 6 / shortfall
	}
}

extension DistributionStudentT: SeedableDistribution {

	/// Draws by inverse transform, so one uniform makes one draw.
	///
	/// The ratio construction — `Z / √(V/ν)` with `V ~ χ²(ν)` — is the textbook one and
	/// is not used here: it consumes a normal plus a chi-squared draw, and the
	/// chi-squared consumes an unbounded number of uniforms once `ν` is fractional.
	/// Inverse transform keeps the draw to one uniform, which is what quasi-random and
	/// stratified sampling require to work at all.
	///
	/// - Parameter generator: The random source.
	/// - Returns: A draw from `t(ν)`.
	public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
		return drawn { Double.random(in: 0..<1, using: &generator) }
	}

	/// A draw from system entropy, not reproducible by contract.
	///
	/// ## Why this is built differently from `next(using:)`
	///
	/// The ratio construction, `Z / √(V/ν)` with `V ~ χ²(ν)`, rather than the inverse
	/// transform above. The two produce the same distribution by different routes, and
	/// each is right for its own path.
	///
	/// `next(using:)` must spend exactly one uniform, because quasi-random and
	/// stratified sampling read a distribution through its quantile and break if a
	/// draw consumes an unpredictable number of points. Nothing here has that
	/// obligation — this path is documented as non-reproducible — and building it from
	/// ``distributionNormal(mean:stdDev:_:_:)`` and ``gammaVariate(shape:scale:seed:)``
	/// keeps the unseeded entry point in the two free functions that already own it,
	/// rather than opening a third.
	///
	/// - Returns: A draw from `t(ν)`.
	public func random() -> Double {
		guard degreesOfFreedom > 0 else { return Double.nan }
		let normal: Double = distributionNormal(mean: 0.0, stdDev: 1.0)
		let half: Double = degreesOfFreedom / 2
		let chiSquare: Double = gammaVariate(shape: half, scale: 2)
		let scaled: Double = chiSquare / degreesOfFreedom
		guard scaled > 0 else { return normal }
		let root: Double = scaled.squareRoot()
		guard root > 0 else { return normal }
		return normal / root
	}

	/// A draw from system entropy. An alias for ``random()``.
	///
	/// - Returns: A draw from `t(ν)`.
	public func next() -> Double {
		return random()
	}

	/// Inverse transform on one uniform, with the closed ends kept out of reach.
	///
	/// - Parameter uniform: Produces a value in `[0, 1)`.
	/// - Returns: The quantile there.
	private func drawn(_ uniform: () -> Double) -> Double {
		let u: Double = uniform()
		let smallest: Double = Double.ulpOfOne
		let largest: Double = 1 - smallest
		let clamped: Double = Swift.min(Swift.max(u, smallest), largest)
		return quantile(clamped)
	}
}
