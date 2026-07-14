//
//  SeedableDistribution.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-14.
//

import Foundation
import Numerics

/// A distribution that can sample deterministically from a caller-supplied generator.
///
/// `SeedableDistribution` refines ``DistributionRandom`` with a generator-parameterized
/// variant of `next()`. Conforming types draw *all* of their randomness from the
/// provided `RandomNumberGenerator`, so a seeded generator (such as ``SplitMix64``)
/// reproduces the identical sample stream on every run.
///
/// ``MonteCarloSimulation`` requires every input's distribution to conform to this
/// protocol when a seed is set; inputs that cannot honor the seed make the run throw
/// `SimulationError.seedingUnsupported` rather than silently losing determinism.
///
/// ## Conforming
///
/// Implement `next(using:)` by sourcing every uniform draw from the generator:
///
/// ```swift
/// extension DistributionUniform: SeedableDistribution {
///     public func next<G: RandomNumberGenerator>(using generator: inout G) -> Double {
///         Double.random(in: min...max, using: &generator)
///     }
/// }
/// ```
///
/// The unseeded `next()` and the seeded `next(using:)` must follow the same
/// probability law — only the randomness source differs.
public protocol SeedableDistribution<T>: DistributionRandom {
	/// Generates the next random value, drawing all randomness from `generator`.
	///
	/// - Parameter generator: The random source; a seeded generator makes the
	///   returned stream fully reproducible.
	/// - Returns: A random value following the distribution's probability law.
	func next<G: RandomNumberGenerator>(using generator: inout G) -> T
}
