//
//  Shuffle.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Draws from a fixed collection **without replacement**, in a reproducible order.
///
/// Binds Risk Solver's `PsiShuffle(data)`.
///
/// ```swift
/// var deck = Shuffle(data: [1.0, 2.0, 3.0, 4.0, 5.0])
/// var rng = DeterministicRNG(seed: 42)
/// let first = deck.next(using: &rng)    // some element
/// let second = deck.next(using: &rng)   // a different element
/// ```
///
/// ## Not a distribution, and deliberately not one
///
/// This does not conform to ``DistributionRandom`` or ``ContinuousDistribution``,
/// because it is not a distribution: successive draws are **not independent**, and it
/// has no fixed CDF. Once an element is taken it cannot come again, so the law changes
/// after every draw. Conforming it would let a caller pass it wherever an independent
/// sampler is expected — into a Monte Carlo input, into a quasi-random point set — and
/// get answers that look ordinary and are wrong. A separate type refuses that at the
/// type level rather than in a warning nobody reads.
///
/// For sampling **with** replacement, where draws are independent and the law is fixed,
/// use ``DistributionDiscreteUniform``. Frontline draws the same distinction between
/// `PsiShuffle` and `PsiResample`.
///
/// ## The permutation
///
/// A Fisher–Yates shuffle, taking one element at a time so a caller drawing `k` items
/// from `n` pays for `k` steps and not `n`. Each of the `n!` orderings is equally
/// likely, which is the property the algorithm is chosen for and which
/// ``permuted(using:)`` exposes when the whole ordering is wanted at once.
public struct Shuffle: Sendable {

	/// The remaining elements, in an order that is unspecified after the first draw.
	private var remaining: [Double]

	/// The elements originally supplied, unchanged by drawing.
	public let data: [Double]

	/// Creates a shuffler over `data`.
	///
	/// - Parameter data: The elements to draw from. May be empty, in which case
	///   ``next(using:)`` returns `nil` immediately; an empty collection is a
	///   legitimate thing to shuffle, unlike an empty distribution, which has no
	///   law at all.
	public init(data: [Double]) {
		self.data = data
		self.remaining = data
	}

	/// How many elements are still available.
	public var remainingCount: Int { remaining.count }

	/// Whether every element has been drawn.
	public var isExhausted: Bool { remaining.isEmpty }

	/// Draws one element without replacement.
	///
	/// - Parameter generator: The random source; seed it for a reproducible order.
	/// - Returns: An element not yet drawn, or `nil` once all are gone. `nil` rather
	///   than a repeat or a trap: exhaustion is an ordinary outcome of sampling
	///   without replacement, and silently starting over would turn this into sampling
	///   with replacement without saying so.
	public mutating func next<G: RandomNumberGenerator>(using generator: inout G) -> Double? {
		guard !remaining.isEmpty else { return nil }
		let index = Int(generator.next(upperBound: UInt64(remaining.count)))
		// Swap the chosen element to the end and drop it — the Fisher–Yates step,
		// O(1) rather than the O(n) that removing from the middle would cost.
		remaining.swapAt(index, remaining.count - 1)
		return remaining.removeLast()
	}

	/// Restores every element, so the collection can be drawn from again.
	public mutating func reset() {
		remaining = data
	}

	/// The whole collection in a uniformly random order.
	///
	/// Independent of how many elements have already been drawn — it permutes ``data``,
	/// not what remains.
	///
	/// - Parameter generator: The random source; seed it for a reproducible ordering.
	/// - Returns: A permutation of ``data``, each of the `n!` orderings equally likely.
	public func permuted<G: RandomNumberGenerator>(using generator: inout G) -> [Double] {
		var working = data
		guard working.count > 1 else { return working }
		for i in stride(from: working.count - 1, to: 0, by: -1) {
			let j = Int(generator.next(upperBound: UInt64(i + 1)))
			working.swapAt(i, j)
		}
		return working
	}
}
