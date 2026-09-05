//
//  gammaCDF.swift
//  BusinessMath
//
//  Created 2026-09-04. Both functions are a change of variable on
//  regularizedLowerIncompleteGamma, which was already in the package — privately.
//

import Foundation
import Numerics

/// Cumulative distribution function of the gamma distribution.
///
/// ```
/// P(X ≤ x | k, θ) = P(k, x/θ)
/// ```
///
/// where `P` is ``regularizedLowerIncompleteGamma(a:x:)``. Parameterised by **shape
/// and scale**, which is the convention `scipy.stats.gamma(a, scale=θ)` uses. A rate
/// parameterisation — as ``DistributionGamma`` uses — is the reciprocal: pass
/// `scale: 1/λ`.
///
/// - Parameters:
///   - x: The value. Must be non-negative.
///   - shape: The shape *k*. Must be positive.
///   - scale: The scale *θ*. Must be positive.
/// - Returns: P(X ≤ x) in [0, 1], or `T.nan` for invalid input.
///
/// ## See Also
/// - ``gammaQuantile(p:shape:scale:)``
/// - ``erlangCDF(_:k:beta:)``
public func gammaCDF<T: Real>(_ x: T, shape: T, scale: T) -> T {
	guard shape > T.zero, scale > T.zero else { return T.nan }
	guard x >= T.zero, !x.isNaN else { return T.nan }
	let scaled: T = x / scale
	return regularizedLowerIncompleteGamma(a: shape, x: scaled)
}

/// The gamma quantile: the value at which ``gammaCDF(_:shape:scale:)`` equals `p`.
///
/// - Parameters:
///   - p: A probability in the open interval (0, 1).
///   - shape: The shape *k*. Must be positive.
///   - scale: The scale *θ*. Must be positive.
/// - Returns: The corresponding value.
/// - Throws: `BusinessMathError.invalidInput` for a probability outside (0, 1) or a
///   non-positive shape.
public func gammaQuantile<T: Real>(p: T, shape: T, scale: T) throws -> T {
	let unitScale: T = try inverseRegularizedLowerIncompleteGamma(p: p, a: shape)
	return unitScale * scale
}

/// Cumulative distribution function of the Erlang distribution.
///
/// The Erlang is the gamma restricted to an integer shape — the waiting time for the
/// *k*-th event of a Poisson process. Frontline's `PsiErlang(k, β)` states it this
/// way, and this delegates rather than reimplementing so the two cannot disagree.
///
/// - Parameters:
///   - x: The value. Must be non-negative.
///   - k: The shape, a positive integer.
///   - beta: The scale. Must be positive.
/// - Returns: P(X ≤ x) in [0, 1], or `T.nan` for invalid input.
public func erlangCDF<T: Real>(_ x: T, k: Int, beta: T) -> T {
	guard k > 0 else { return T.nan }
	return gammaCDF(x, shape: T(k), scale: beta)
}

/// The Erlang quantile: the value at which ``erlangCDF(_:k:beta:)`` equals `p`.
///
/// - Parameters:
///   - p: A probability in the open interval (0, 1).
///   - k: The shape, a positive integer.
///   - beta: The scale. Must be positive.
/// - Returns: The corresponding value.
/// - Throws: `BusinessMathError.invalidInput` for invalid input.
public func erlangQuantile<T: Real>(p: T, k: Int, beta: T) throws -> T {
	guard k > 0 else {
		throw BusinessMathError.invalidInput(
			message: "Erlang shape must be a positive integer",
			value: "\(k)", expectedRange: "[1, ∞)")
	}
	return try gammaQuantile(p: p, shape: T(k), scale: beta)
}
