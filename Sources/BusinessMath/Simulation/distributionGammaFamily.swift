//
//  distributionGammaFamily.swift
//  BusinessMath
//

import Foundation
import Numerics

// MARK: - Erlang

/// An Erlang distribution: the waiting time until the `k`-th event of a Poisson process.
///
/// A gamma distribution whose shape is a whole number, and that restriction is what
/// gives it its meaning: `k` independent exponential waits laid end to end. Queueing and
/// reliability models reach for it because the parameter is a *count* of stages, which
/// is something a modeller can state from the structure of the system rather than fit.
///
/// Binds Risk Solver's `PsiErlang(k, beta)`, which is
/// `scipy.stats.erlang(a: k, scale: beta)`.
///
/// ```
/// F(x) = P(k, x/β)         the regularized lower incomplete gamma
/// Q(u) = β · P⁻¹(k, u)
/// ```
///
/// - SeeAlso: ``DistributionGamma``, which is the same law with a real-valued shape.
public struct DistributionErlang: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The number of stages, `k`. A positive whole number.
	public let stages: Int

	/// The scale of each stage, Frontline's `beta`. Positive; the mean is `k·β`.
	public let scale: Double

	private let shape: Double
	private let inverseScale: Double

	/// Creates an Erlang distribution.
	///
	/// - Parameters:
	///   - stages: The shape `k`, a positive whole number. The restriction to integers
	///     is the distribution's definition, not a limitation — for a fractional shape
	///     the law is a gamma and ``DistributionGamma`` is the type.
	///   - scale: Frontline's `beta`, positive and finite.
	/// - Returns: `nil` if `stages` is not positive, or `scale` is not positive and
	///   finite.
	public init?(stages: Int, scale: Double) {
		guard stages > 0, scale > 0, scale.isFinite else { return nil }
		self.stages = stages
		self.scale = scale
		self.shape = Double(stages)
		self.inverseScale = 1 / scale
	}

	/// P(X ≤ x), zero at or below the origin.
	public func cdf(_ x: Double) -> Double {
		guard x > 0 else { return 0 }
		return regularizedLowerIncompleteGamma(a: shape, x: x * inverseScale)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is zero, the
	///   lower bound of the support; at or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return 0 }
		guard p < 1 else { return .infinity }
		// `ContinuousDistribution` declares `quantile` non-throwing, so an error has to
		// become a value. NaN is the honest one: it says "no answer" and propagates,
		// where any finite substitute would be a number the caller could mistake for a
		// quantile. The catch is written out rather than hidden behind `try?` so the
		// conversion is visible at the point it happens.
		do {
			let standardised = try inverseRegularizedLowerIncompleteGamma(p: p, a: shape)
			return scale * standardised
		} catch { // logging: unreachable — the initialiser and the guards above exclude every input this throws on
			return .nan
		}
	}
}

// MARK: - Pearson type V, the inverse gamma

/// A Pearson type V distribution — the inverse gamma: the reciprocal of a gamma variate.
///
/// Right-skewed with a heavy right tail, and used as the conjugate prior for the
/// variance of a normal, which is where most people meet it. In risk work it models a
/// duration or a cost that is usually modest but occasionally very large.
///
/// Binds Risk Solver's `PsiPearson5(alpha, beta)`, which is
/// `scipy.stats.invgamma(a: alpha, scale: beta)`.
///
/// ```
/// F(x) = Q(α, β/x)         the UPPER regularized incomplete gamma, at β/x
/// Q(u) = β / P⁻¹(α, 1 − u)
/// ```
///
/// Two things are easy to get backwards here and both were checked against SciPy rather
/// than derived from memory: the argument is the **reciprocal** `β/x`, and the tail is
/// the **upper** one. Using `P` instead of `Q`, or `x/β` instead of `β/x`, each produces
/// a monotone function on the right support that round-trips against its own inverse.
///
/// The mean exists only for `α > 1` and the variance only for `α > 2`.
public struct DistributionPearson5: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The shape, Frontline's `alpha`. Positive.
	public let alpha: Double

	/// The scale, Frontline's `beta`. Positive.
	public let beta: Double

	/// Creates a Pearson type V distribution.
	///
	/// - Parameters:
	///   - alpha: The shape, positive and finite.
	///   - beta: The scale, positive and finite.
	/// - Returns: `nil` if either is not positive and finite.
	public init?(alpha: Double, beta: Double) {
		guard alpha > 0, alpha.isFinite, beta > 0, beta.isFinite else { return nil }
		self.alpha = alpha
		self.beta = beta
	}

	/// P(X ≤ x), zero at or below the origin.
	public func cdf(_ x: Double) -> Double {
		guard x > 0 else { return 0 }
		return regularizedUpperIncompleteGamma(a: alpha, x: beta / x)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is zero; at
	///   or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return 0 }
		guard p < 1 else { return .infinity }
		// Inverting `Q(α, β/x) = p` means solving `P(α, β/x) = 1 − p`, so the inverse of
		// the *lower* function is asked for the complement. NaN on failure, for the
		// reason given on ``DistributionErlang/quantile(_:)``.
		do {
			let inner = try inverseRegularizedLowerIncompleteGamma(p: 1 - p, a: alpha)
			guard inner > 0 else { return .infinity }
			return beta / inner
		} catch { // logging: unreachable — alpha is positive and 1-p lies in (0,1) by the guards above
			return .nan
		}
	}
}

// MARK: - Pearson type VI, the beta prime

/// A Pearson type VI distribution — the beta prime: the odds of a beta variate, scaled.
///
/// If `B` is beta-distributed on (0,1), then `β·B/(1−B)` follows this law on (0,∞). It
/// is the distribution of a ratio of two gamma variates, which is why it turns up when
/// modelling a quantity defined as one uncertain amount divided by another.
///
/// Binds Risk Solver's `PsiPearson6(alpha1, alpha2, beta)`, which is
/// `scipy.stats.betaprime(a: alpha1, b: alpha2, scale: beta)`.
///
/// ```
/// F(x) = I(y/(1+y); α₁, α₂)      for y = x/β
/// Q(u) = β·z/(1 − z)             for z = I⁻¹(u; α₁, α₂)
/// ```
///
/// The mean exists only for `α₂ > 1`.
public struct DistributionPearson6: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The first shape, Frontline's `alpha1`. Positive.
	public let alpha1: Double

	/// The second shape, Frontline's `alpha2`. Positive; controls the tail.
	public let alpha2: Double

	/// The scale, Frontline's `beta`. Positive.
	public let beta: Double

	private let inverseBeta: Double

	/// Creates a Pearson type VI distribution.
	///
	/// - Parameters:
	///   - alpha1: The first shape, positive and finite.
	///   - alpha2: The second shape, positive and finite.
	///   - beta: The scale, positive and finite.
	/// - Returns: `nil` if any of the three is not positive and finite.
	public init?(alpha1: Double, alpha2: Double, beta: Double) {
		guard alpha1 > 0, alpha1.isFinite, alpha2 > 0, alpha2.isFinite else { return nil }
		guard beta > 0, beta.isFinite else { return nil }
		self.alpha1 = alpha1
		self.alpha2 = alpha2
		self.beta = beta
		self.inverseBeta = 1 / beta
	}

	/// P(X ≤ x), zero at or below the origin.
	public func cdf(_ x: Double) -> Double {
		guard x > 0 else { return 0 }
		let y: Double = x * inverseBeta
		// `1 + y` exceeds one for any positive `y`, and `x > 0` was checked above.
		let denominator: Double = 1 + y
		guard denominator > 0 else { return 0 }
		let mapped: Double = y / denominator
		do {
			return try regularizedIncompleteBeta(x: mapped, a: alpha1, b: alpha2)
		} catch { // logging: unreachable — mapped lies in (0,1) and both shapes are positive
			return .nan
		}
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). At or below zero the answer is zero; at
	///   or above one it is infinite.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return 0 }
		guard p < 1 else { return .infinity }
		do {
			let z = try inverseRegularizedIncompleteBeta(p: p, a: alpha1, b: alpha2)
			let complement: Double = 1 - z
			guard complement > 0 else { return .infinity }
			return beta * z / complement
		} catch { // logging: unreachable — p lies in (0,1) and both shapes are positive
			return .nan
		}
	}
}
