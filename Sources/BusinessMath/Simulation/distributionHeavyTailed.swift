//
//  distributionHeavyTailed.swift
//  BusinessMath
//

import Foundation
import Numerics

/// `1/π`, formed once at file scope.
///
/// The guard is not ceremony even though `Double.pi` is a constant: it is where the
/// invariant behind every use is stated, and it makes the division total rather than
/// resting on a fact recorded only in a comment.
private let inversePi: Double = {
	let halfTurn = Double.pi
	guard halfTurn > 0 else { return 0 }
	return 1 / halfTurn
}()

// MARK: - Cauchy

/// A Cauchy distribution: symmetric, and so heavy-tailed that it has **no mean**.
///
/// Not a pathological curiosity — it is the ratio of two independent standard normals,
/// and it is what a t-distribution becomes at one degree of freedom. Its tails are heavy
/// enough that the sample mean of `n` draws is itself Cauchy with the same scale, so
/// averaging does not converge and the law of large numbers does not apply. Any code
/// that computes a mean from Cauchy draws is computing noise.
///
/// Binds Risk Solver's `PsiCauchy(loc, lambda)`.
///
/// ```
/// F(x) = 1/2 + arctan((x − loc)/λ)/π
/// Q(u) = loc + λ·tan(π·(u − 1/2))
/// ```
///
/// ## The first argument is the location
///
/// Frontline's prose contradicts its own signature about whether argument one is the
/// location or the scale. The work list resolves it the way it resolves the same clash
/// in ``DistributionLaplace``: **the signature is authoritative**, so `loc` is the
/// location and `lambda` the scale, matching `scipy.stats.cauchy(loc:scale:)`.
public struct DistributionCauchy: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The median and mode. Not the mean — a Cauchy has none.
	public let location: Double

	/// The half-width at half-maximum, Frontline's `lambda`. Positive.
	public let scale: Double

	/// `1/scale`, formed beside the guard proving it non-zero.
	private let inverseScale: Double

	/// Creates a Cauchy distribution.
	///
	/// - Parameters:
	///   - location: The median.
	///   - scale: The half-width at half-maximum, positive and finite.
	/// - Returns: `nil` if `scale` is not positive and finite, or `location` not finite.
	public init?(location: Double, scale: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.inverseScale = 1 / scale
	}

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let standardised: Double = (x - location) * inverseScale
		let angle: Double = Foundation.atan(standardised)
		return 0.5 + angle * inversePi
	}

	/// The value at which the CDF equals `p`.
	///
	/// ## Why not `tan(π(p − ½))`
	///
	/// That is the textbook form, and it loses accuracy in exactly the place a
	/// heavy-tailed distribution is read. For `p = 1e-8` the argument sits a hair from
	/// `−π/2`, where `tan` is near-vertical, so a one-ulp error in the angle becomes a
	/// large relative error in the result — measured against SciPy it was 1.7e-9, small
	/// in absolute terms and wrong in the digits that matter for a tail quantile.
	///
	/// The cotangent identity `tan(π(u − ½)) = −1/tan(πu)` avoids it. For small `u`,
	/// `tan(πu)` is close to `πu` and computed accurately, and its reciprocal is stable.
	/// The upper tail mirrors through `1 − u`. Near the median `tan(πu)` is large, so
	/// the quotient is a small, accurate correction to `location` rather than a
	/// difference of two big numbers.
	///
	/// - Parameter p: A probability in (0, 1); the endpoints are infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		// The median, where both branches would divide by an effectively infinite
		// tangent. The distribution is symmetric, so the answer is the location. The
		// comparison is a deliberate IEEE one: 0.5 is exact in binary and the caller
		// either passed it or did not.
		guard !p.isEqual(to: 0.5) else { return location }

		if p < 0.5 {
			let tangent: Double = Foundation.tan(Double.pi * p)
			guard tangent != 0 else { return -.infinity }
			return location - scale / tangent
		}
		let tangent: Double = Foundation.tan(Double.pi * (1 - p))
		guard tangent != 0 else { return .infinity }
		return location + scale / tangent
	}
}

// MARK: - Laplace

/// A Laplace distribution: two exponential tails back to back, meeting in a peak.
///
/// Sharper at the centre and heavier in the tails than a normal of the same variance,
/// which is why it turns up wherever errors are usually small but occasionally large —
/// and why minimising absolute error, rather than squared error, is the maximum
/// likelihood fit for it.
///
/// Binds Risk Solver's `PsiLaplace(loc, beta)`.
///
/// ```
/// F(x) = ½·exp((x − loc)/β)          for x ≤ loc
/// F(x) = 1 − ½·exp(−(x − loc)/β)     for x > loc
/// Q(u) = loc + β·ln(2u)              for u < ½
/// Q(u) = loc − β·ln(2(1 − u))        for u ≥ ½
/// ```
///
/// ## The first argument is the location
///
/// The same prose-versus-signature clash as ``DistributionCauchy``, which the work list
/// notes runs "in reverse" between the two. Resolved the same way and for the same
/// reason: the signature is authoritative, so this matches
/// `scipy.stats.laplace(loc:scale:)`.
public struct DistributionLaplace: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The mean, median and mode, which coincide.
	public let location: Double

	/// The scale, Frontline's `beta`. Positive. The variance is `2β²`.
	public let scale: Double

	/// `1/scale`, formed beside the guard proving it non-zero.
	private let inverseScale: Double

	/// Creates a Laplace distribution.
	///
	/// - Parameters:
	///   - location: The centre.
	///   - scale: The scale, positive and finite.
	/// - Returns: `nil` if `scale` is not positive and finite, or `location` not finite.
	public init?(location: Double, scale: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.location = location
		self.scale = scale
		self.inverseScale = 1 / scale
	}

	/// P(X ≤ x).
	public func cdf(_ x: Double) -> Double {
		let standardised: Double = (x - location) * inverseScale
		if standardised <= 0 {
			return 0.5 * Foundation.exp(standardised)
		}
		return 1 - 0.5 * Foundation.exp(-standardised)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1); the endpoints are infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return -.infinity }
		guard p < 1 else { return .infinity }
		if p < 0.5 {
			return location + scale * Foundation.log(2 * p)
		}
		// `log1p` rather than `log(1 - p)`: for p close to one the subtraction throws
		// away the significant digits, and the upper tail is the half being computed.
		let logComplement: Double = Foundation.log(2.0) + Foundation.log1p(-p)
		return location - scale * logComplement
	}
}

// MARK: - Lévy

/// A Lévy distribution: one-sided, and so heavy-tailed that its **mean is infinite**.
///
/// The stable distribution with α = ½ and β = 1, and the hitting-time law for Brownian
/// motion reaching a fixed level. Its tail decays as `x^(−3/2)`, slowly enough that no
/// moment exists, so a simulation that averages Lévy draws produces a number that grows
/// with the sample size rather than converging to anything.
///
/// Binds Risk Solver's `PsiLevy(loc, scale)`.
///
/// ```
/// F(x) = erfc(√(scale / (2·(x − loc))))     for x > loc
/// Q(u) = loc + scale / Φ⁻¹(1 − u/2)²
/// ```
///
/// where `Φ⁻¹` is the standard normal quantile.
public struct DistributionLevy: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support; the distribution has no mass at or below it.
	public let location: Double

	/// The scale. Positive.
	public let scale: Double

	/// Creates a Lévy distribution.
	///
	/// - Parameters:
	///   - location: The lower bound of the support.
	///   - scale: The scale, positive and finite.
	/// - Returns: `nil` if `scale` is not positive and finite, or `location` not finite.
	public init?(location: Double, scale: Double) {
		guard location.isFinite, scale > 0, scale.isFinite else { return nil }
		self.location = location
		self.scale = scale
	}

	/// P(X ≤ x), zero at or below `location`.
	public func cdf(_ x: Double) -> Double {
		guard x > location else { return 0 }
		let doubledDisplacement: Double = 2 * (x - location)
		guard doubledDisplacement > 0 else { return 0 }
		let ratio: Double = scale / doubledDisplacement
		return Foundation.erfc(ratio.squareRoot())
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is
	///   `location`; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return location }
		guard p < 1 else { return .infinity }
		// Φ⁻¹(1 − p/2). The argument stays in the upper half of the unit interval, so
		// the normal quantile is evaluated where it is well conditioned.
		let upper: Double = 1 - p / 2
		let z: Double = inverseNormalCDF(p: upper)
		let zSquared: Double = z * z
		// Zero only if the normal quantile returned zero, which happens at p = 1 —
		// already handled above. Guarded so the division is total rather than relying
		// on that argument holding.
		guard zSquared > 0 else { return .infinity }
		return location + scale / zSquared
	}
}
