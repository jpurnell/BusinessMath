//
//  QuasiRandomPointSet.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// A set of points spread over the unit hypercube more evenly than chance would.
///
/// Pseudo-random sampling clumps. Over *n* draws the gaps and clusters are what make
/// a Monte Carlo error fall only as `1/√n`, and most of the sample is spent
/// re-covering ground the earlier draws already covered. A stratified or
/// low-discrepancy point set removes the clumping by construction, and the error can
/// fall closer to `1/n`.
///
/// Conformers deliver whole point sets rather than a stream of draws, because that is
/// what the construction requires: a Latin hypercube design cannot be produced one
/// point at a time without knowing how many there will be, and the balance properties
/// of a Sobol sequence hold at powers of two rather than at every prefix.
///
/// ## Coordinates are open
///
/// Every coordinate lies strictly inside `(0, 1)`. These points are consumed by
/// ``ContinuousDistribution/quantile(_:)``, and a coordinate of exactly 0 or 1 is an
/// infinity for any unbounded support.
///
/// ## Topics
/// ### Conforming types
/// - ``LatinHypercubeSampler``
/// - ``SobolSequence``
/// - ``HaltonSequence``
public protocol QuasiRandomPointSet: Sendable {

	/// How many coordinates each point carries.
	var dimension: Int { get }

	/// `count` points, each with ``dimension`` coordinates strictly inside `(0, 1)`.
	///
	/// - Parameter count: How many points to produce.
	/// - Returns: A `count` × ``dimension`` array, outer index the point.
	func points(count: Int) -> [[Double]]
}

/// How a simulation places its sample points.
///
/// The default is ``pseudoRandom``, which is what every run did before this type
/// existed and what every run still does unless told otherwise.
///
/// ## Eligibility
///
/// Anything other than ``pseudoRandom`` requires every input to be able to state a
/// quantile — that is, to conform to ``ContinuousDistribution`` or
/// ``DiscreteDistribution``. A point set hands each input one coordinate per
/// iteration, and only an inverse transform can turn a chosen coordinate into a draw.
///
/// A run that cannot honour the request throws
/// ``SimulationError/quasiRandomUnsupported(inputName:details:)`` naming the input,
/// rather than quietly reverting to pseudo-random. Reverting would produce numbers
/// that are individually plausible and collectively not what was asked for.
public enum SamplingMethod: Sendable, Hashable {

	/// Independent pseudo-random draws, one per input per iteration.
	case pseudoRandom

	/// Latin hypercube: each dimension is divided into `n` equal strata and every
	/// stratum is used exactly once.
	///
	/// Requires a seed. The stratification is deterministic but the assignment of
	/// strata to points is a random permutation, so an unseeded run is reproducible in
	/// its coverage and not in its values — a partial determinism that reads as
	/// reproducible and is not.
	case latinHypercube

	/// A Sobol low-discrepancy sequence, using the Joe & Kuo (2008) direction numbers.
	///
	/// - Parameter scrambled: Applies Owen scrambling, which removes the sequence's
	///   deterministic structure while keeping its uniformity. Requires a seed.
	case sobol(scrambled: Bool)

	/// A Halton low-discrepancy sequence.
	///
	/// - Parameter scrambled: Applies a random digit permutation per dimension.
	///   Requires a seed. Unscrambled Halton correlates badly between high dimensions
	///   — see ``HaltonSequence``.
	case halton(scrambled: Bool)

	/// Whether this method needs a seed to be fully reproducible.
	public var requiresSeed: Bool {
		switch self {
		case .pseudoRandom: return false
		case .latinHypercube: return true
		case .sobol(let scrambled): return scrambled
		case .halton(let scrambled): return scrambled
		}
	}

	/// Whether this method draws its points from a ``QuasiRandomPointSet``.
	public var isQuasiRandom: Bool {
		if case .pseudoRandom = self { return false }
		return true
	}
}
