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
/// - Returns: P(X ≤ x) in `[0, 1]`, or `T.nan` when a shape or scale is unusable or `x` is
///   `nan`. The gamma support is `[0, ∞)`, so **below it the answer is 0, not `nan`** —
///   including at `-infinity` — and at `+infinity` it is 1.
///
/// ## See Also
/// - ``gammaQuantile(p:shape:scale:)``
/// - ``erlangCDF(_:k:beta:)``
public func gammaCDF<T: Real>(_ x: T, shape: T, scale: T) -> T {
	guard shape > T.zero, scale > T.zero else { return T.nan }
	// This was one guard answering two questions — `guard x >= T.zero, !x.isNaN else { return
	// T.nan }` — and the two questions have different answers. "Below the support" and "cannot
	// be evaluated" are not the same fact: a caller passing `-1` has asked a perfectly
	// answerable question and was told the probability could not be computed, when it is
	// exactly 0. Splitting them is what contract §4 exists for.
	guard !x.isNaN else { return T.nan } // A NaN names no point on the line, so there is no probability to report.
	// One guard now covers the whole of the lower half: a finite negative, a negative zero and
	// `-infinity` all have no gamma mass at or below them, and P(shape, 0) is 0 in any case.
	// Screening `isNaN` above and *ordering* here, rather than screening `isFinite`, is what
	// keeps `+infinity` on its own path: it is the upper limit of the support and
	// `regularizedLowerIncompleteGamma` already answers 1 there.
	guard x > T.zero else { return T.zero }
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
/// - Returns: P(X ≤ x) in `[0, 1]`, or `T.nan` for a non-positive `k` or `beta` or a `nan`
///   `x`. Below the support the answer is 0 and at `+infinity` it is 1, inherited from
///   ``gammaCDF(_:shape:scale:)`` rather than restated here.
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
