//
//  SeedableDriver.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-08-11.
//

import Foundation
import Numerics

/// A driver that can sample deterministically from a caller-supplied generator.
///
/// `SeedableDriver` refines ``Driver`` the way ``SeedableDistribution`` refines
/// ``DistributionRandom``: with a generator-parameterized variant of `sample(for:)`.
/// Conforming types draw *all* of their randomness from the provided generator, so a
/// seeded ``Xoshiro256StarStar`` reproduces the identical sample stream on every run.
///
/// The unseeded ``Driver/sample(for:)`` and the seeded ``sample(for:using:)`` must
/// follow the same probability law — only the randomness source differs.
///
/// ## Why the generator type is concrete
///
/// ``SeedableDistribution/next(using:)`` is generic over `RandomNumberGenerator` because a
/// distribution is never type-erased. A driver is: ``AnyDriver`` is the storage type for
/// driver graphs throughout this library, and ``SumDriver`` and ``ProductDriver`` hold their
/// operands as `AnyDriver`. A generic requirement cannot survive that erasure, so this
/// protocol names ``Xoshiro256StarStar`` — the same generator
/// ``MonteCarloSimulation`` runs its seeded CPU path on, and the same concrete choice
/// ``SimulationInput``'s seeded sampler makes.
///
/// ## Conformance is not universal, deliberately
///
/// Not every driver can honor a seed, and the ones that cannot do not conform:
///
/// - ``DeterministicDriver`` conforms. It consumes nothing from the generator and returns
///   the same value on every run, which is reproducibility in its strongest form.
/// - ``ProbabilisticDriver`` conforms, but reports ``supportsSeeding`` at run time: it can
///   only thread a generator through a distribution that itself conforms to
///   ``SeedableDistribution``, and the distribution is erased into a closure when the
///   driver is built.
/// - ``ConstrainedDriver`` conforms *conditionally* — `where Base: SeedableDriver` — because
///   it stores its base driver unerased. A constraint applied to a reproducible draw is
///   reproducible; applied to an unreproducible one it is not, and the type system says so.
/// - ``SumDriver`` and ``ProductDriver`` conform unconditionally and check at run time,
///   because their operands are already erased to `AnyDriver` by the time the type exists.
/// - ``TimeVaryingDriver`` does **not** conform. Its sampler is a caller-supplied closure
///   that owns its own randomness; there is nothing to thread a generator into.
///
/// ## Failure is loud
///
/// Where seedability is a run-time property, ``sample(for:using:)`` throws
/// `SimulationError.seedingUnsupported` rather than quietly returning a draw the caller's
/// generator did not produce. This is the rule ``MonteCarloSimulation`` applies to inputs
/// that cannot honor a seed, for the same reason: a result that looks reproducible and is
/// not is worse than one that refuses to run.
///
/// ## Example
///
/// ```swift
/// let quarters = Period.documentationQuarters
/// let growth = ProbabilisticDriver<Double>.normal(name: "Growth", mean: 0.10, stdDev: 0.05)
///
/// var generator = Xoshiro256StarStar(seed: 42)
/// let path = try Period.year(2025).quarters().map { quarter in
///     try growth.sample(for: quarter, using: &generator)
/// }
/// // Re-seeding with 42 reproduces `path` exactly.
/// ```
public protocol SeedableDriver<Value>: Driver {
	/// Whether this driver can actually honor a seed.
	///
	/// `true` for drivers whose randomness is fully sourced from the caller's generator.
	/// `false` where the driver was built over a distribution that does not conform to
	/// ``SeedableDistribution``, or where a composite has at least one such operand;
	/// ``sample(for:using:)`` throws `SimulationError.seedingUnsupported` in that case.
	///
	/// Check it before running a long simulation, so the refusal costs nothing.
	var supportsSeeding: Bool { get }

	/// Generates a sample for the given period, drawing all randomness from `generator`.
	///
	/// - Parameters:
	///   - period: The time period for which to generate a value.
	///   - generator: The random source; a seeded generator makes the returned stream
	///     fully reproducible.
	/// - Returns: A sampled value following the same probability law as
	///   ``Driver/sample(for:)``.
	/// - Throws: `SimulationError.seedingUnsupported` when this driver — or one of its
	///   operands — cannot source its randomness from `generator`.
	func sample(for period: Period, using generator: inout Xoshiro256StarStar) throws -> Value
}

public extension SeedableDriver {
	/// Whether this driver can honor a seed; `true` for conforming types that have no
	/// run-time escape hatch.
	///
	/// Types whose seedability depends on how they were built — ``ProbabilisticDriver``,
	/// ``AnyDriver``, ``SumDriver``, ``ProductDriver`` — override this.
	var supportsSeeding: Bool { true }
}
