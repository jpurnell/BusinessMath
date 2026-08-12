//
//  boxMuellerSeed.swift
//
//
//  Created by Justin Purnell on 5/28/24.
//

import Foundation
import Numerics

// MARK: - The transform

/// The Box-Muller transform, in one place.
///
/// Box-Muller turns two independent uniforms into two independent standard normal
/// variates. The pair shares a radius and differs only in the angle:
///
/// ```
/// r = sqrt(-2 · ln u₁)      θ = 2π · u₂
/// z₁ = r · sin θ            z₂ = r · cos θ
/// ```
///
/// This file is the package's single definition of that arithmetic. It exists as a
/// shared routine rather than a formula each caller retypes because the formula has
/// one sharp edge — `u₁ = 0` gives `ln 0 = -∞` and a non-finite radius — and every
/// site that wrote it out invented its own guard. The guards did not agree with each
/// other, and some of them were wrong in ways the site's own tests could not see.
///
/// ## The pole, and why not a clamp
///
/// The obvious fix is `max(u₁, ε)`. It keeps the result finite and it is wrong in a
/// specific way: it maps a whole interval of draws onto a single value, so `ε` carries
/// a point mass the normal distribution does not have. The size of the artifact
/// depends on how small `ε` is — 1e-15 puts an atom at radius 8.31, 1e-10 at 6.79,
/// 2.2e-308 at 37.64 — but it is always an atom.
///
/// Drawing `u₁` as `1 - Double.random(in: 0..<1)` has no such artifact. For any
/// representable `u < 1`, IEEE subtraction of `u` from 1 is exact, so the result is
/// strictly positive; and `u ↦ 1 - u` is measure-preserving, so the draw stays exactly
/// uniform on `(0, 1]`. Reasoning first recorded in `git show d247691`.
///
/// Where the uniform arrives from a caller rather than being drawn here, the same
/// principle applies with one adjustment: an incoming seed is already fixed, so
/// nothing can be subtracted from it without changing the distribution. Only the
/// single point `u₁ = 0` needs moving, and it moves to 1 — a set of measure zero
/// mapped onto another, with no interval collapsed.
///
/// ## Precision
///
/// The seed-taking entry points used to route their seeds through
/// ``distributionUniform(_:)``, which quantizes to multiples of 1e-7. That put the
/// whole distribution on a ten-million-point lattice and capped the radius any
/// legitimate draw could reach at `sqrt(-2·log(1e-7))` = 5.6777, with the clamp value
/// sitting alone above it at 8.3113. A seed *is* a uniform; passing it through a
/// second uniform generator only discarded 46 bits of it. The quantization is gone,
/// so the seed form and the generator form now differ only in where their uniforms
/// come from.
///
/// The gap that closes is small and worth naming so nobody mistakes it for a hazard:
/// `|z| > 5.6777` covers 1.37e-8 of a standard normal, roughly one thousandth of a
/// draw in a 10,000-iteration run. It is closed because a routine that ten call sites
/// share should not be the least precise of the things it replaces — `PortfolioUtilities`
/// already drew full 53-bit uniforms and must not lose them by adopting this.
///
/// ## Choosing an entry point
///
/// | Need | Call |
/// |------|------|
/// | Two normals, reproducible from a generator | ``boxMullerSeed(using:)`` |
/// | Two normals from uniforms you already hold | ``boxMullerSeed(_:_:)`` |
/// | One radius (Rayleigh, or a single-variate site) | ``boxMullerRadius(using:)`` |
/// | One radius from a uniform you already hold | ``boxMullerRadius(_:)`` |
///
/// Prefer the `using:` forms. They take the caller's `RandomNumberGenerator` `inout`,
/// which is the shape the rest of the library standardised on (`git show 4b021b8`,
/// `git show d247691`): one seeded generator can drive several blocks of draws without
/// the caller inventing seed arithmetic, and nothing is shared with a process-global
/// stream.

// MARK: - Shared arithmetic

/// Maps a seed on the closed interval `[0, 1]` onto `(0, 1]`.
///
/// Only `0` moves, and it moves to `1`. That is a set of measure zero mapped onto
/// another, so the draw stays exactly uniform — unlike a clamp, which collapses an
/// interval and leaves a point mass behind.
///
/// Values outside the documented `[0, 1]` contract, including `NaN`, also return `1`
/// rather than propagating a non-finite result to the caller.
///
/// This lives beside Box-Muller because that is where the pole was first a problem,
/// but nothing about it is Box-Muller-specific: every inverse transform whose
/// generator function is singular at `u = 0` — the Box-Muller radius through
/// `log u`, ``distributionPareto(scale:shape:seed:)`` through `u^(-1/α)` — needs
/// the same half-open interval and should ask for it here rather than invent its
/// own guard. The guards those sites used to write for themselves did not agree
/// with each other, and one of them (`T(Int(1e-10))`, which is zero) did nothing at all.
@usableFromInline
internal func openUnitUniform<T>(seed: T) -> T where T: BinaryFloatingPoint {
	guard seed > 0 else { return T(1) }
	return seed <= T(1) ? seed : T(1)
}

/// The shared radius, `sqrt(-2 · ln u)`.
///
/// - Parameter uniform: A uniform on `(0, 1]`. Callers holding a seed on the closed
///   `[0, 1]` should pass it through ``openUnitUniform(seed:)`` first.
@usableFromInline
internal func boxMullerRadius<T: Real>(uniform: T) -> T where T: BinaryFloatingPoint {
	T.sqrt(T(-2) * T.log(uniform))
}

/// The transform proper: a radius and an angle, resolved into two variates.
///
/// - Parameters:
///   - uniform: A uniform on `(0, 1]`, setting the radius.
///   - angleUniform: A uniform on `[0, 1]`, setting the angle. Any finite value is
///     safe here; the angle is periodic.
@usableFromInline
internal func boxMullerPair<T: Real>(uniform: T, angleUniform: T) -> (z1: T, z2: T) where T: BinaryFloatingPoint {
	// The two variates share a radius and differ only in the angle: sin and cos of the
	// same 2πu₂. Writing `T.cos(2 * T.pi) * u2` instead — cos of a full turn, which is
	// the constant 1, scaled by u₂ — made z2 equal to the radius times a uniform, which
	// is not normal and is not independent of z1. Fixed in `git show dc42570`; the
	// correlation assertion in `BoxMullerCanonicalTests` is what now holds it in place.
	let radius = boxMullerRadius(uniform: uniform)
	let angle = 2 * T.pi * angleUniform
	return (radius * T.sin(angle), radius * T.cos(angle))
}

// MARK: - Pairs

/// Generates two independent standard normal variates, drawing both uniforms from
/// `generator`.
///
/// This is the entry point to prefer. The same generator state always produces the
/// same pair, and one generator threaded through many calls gives independent blocks
/// of draws — see the discussion in ``ScenarioGenerator`` for why that matters more
/// than it sounds.
///
/// `u₁` is drawn as `1 - Double.random(in: 0..<1)`, which lands in `(0, 1]` exactly
/// and never reaches the `log(0)` pole. Both uniforms carry the full 53-bit
/// significand.
///
/// - Parameter generator: The random source. Taken `inout` so the caller owns the
///   stream and its reproducibility.
/// - Returns: A tuple of two independent standard normal values `(z1, z2)`, each with
///   mean 0 and variance 1, and uncorrelated with one another.
///
/// ## Example
/// ```swift
/// var rng = DeterministicRNG(seed: 42)
/// let (z1, z2): (Double, Double) = boxMullerSeed(using: &rng)
/// ```
public func boxMullerSeed<T: Real, G: RandomNumberGenerator>(using generator: inout G) -> (z1: T, z2: T) where T: BinaryFloatingPoint {
	// `1 - u` rather than a clamp: exact for every representable u < 1, and
	// measure-preserving, so the draw stays exactly uniform on (0, 1].
	let u1 = 1.0 - Double.random(in: 0.0..<1.0, using: &generator)
	let u2 = Double.random(in: 0.0..<1.0, using: &generator)
	return boxMullerPair(uniform: T(u1), angleUniform: T(u2))
}

/// Generates two independent standard normal variates from two uniforms the caller
/// already holds.
///
/// Use this when the uniforms come from somewhere that is not a
/// `RandomNumberGenerator` — a recorded stream, or bits derived from another value.
/// When you have a generator, ``boxMullerSeed(using:)`` is the better call.
///
/// - Parameters:
///   - u1Seed: A uniform on `[0, 1]`, setting the radius. Zero is the `log(0)` pole
///     and is remapped to 1 (radius 0); see `openUnitUniform(seed:)` for why that
///     is not a clamp.
///   - u2Seed: A uniform on `[0, 1]`, setting the angle.
/// - Returns: A tuple of two independent standard normal values `(z1, z2)`.
///
/// - Note: Seeds are used at full precision. Before this they were routed through
///   ``distributionUniform(_:)`` and quantized to multiples of 1e-7, so two seeds
///   closer together than that produced identical output.
public func boxMullerSeed<T: Real>(_ u1Seed: Double = Double.random(in: 0...1), _ u2Seed: Double = Double.random(in: 0...1)) -> (z1: T, z2: T) where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	boxMullerPair(uniform: openUnitUniform(seed: T(u1Seed)), angleUniform: T(u2Seed))
}

// MARK: - Radius only

/// Generates a Box-Muller radius, drawing its single uniform from `generator`.
///
/// The radius `sqrt(-2 · ln u)` is a Rayleigh variate with unit scale, and it is the
/// quantity ``distributionRayleigh(scale:seed:)`` wants. Asking ``boxMullerSeed(using:)``
/// for it instead would consume two uniforms and compute a sine and a cosine only to
/// discard both.
///
/// - Parameter generator: The random source, taken `inout`.
/// - Returns: A non-negative Rayleigh(1) variate.
public func boxMullerRadius<T: Real, G: RandomNumberGenerator>(using generator: inout G) -> T where T: BinaryFloatingPoint {
	let u = 1.0 - Double.random(in: 0.0..<1.0, using: &generator)
	return boxMullerRadius(uniform: T(u))
}

/// Generates a Box-Muller radius from a uniform the caller already holds.
///
/// - Parameter uSeed: A uniform on `[0, 1]`. Zero is the `log(0)` pole and is remapped
///   to 1 (radius 0).
/// - Returns: A non-negative Rayleigh(1) variate.
public func boxMullerRadius<T: Real>(_ uSeed: Double = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint { // stochastic:exempt — the uniform arguments default to fresh draws; pass them explicitly for reproducibility
	boxMullerRadius(uniform: openUnitUniform(seed: T(uSeed)))
}
