//
//  TrialRandomness.swift
//  BusinessMath
//

import Foundation
import SwiftDeterminism

/// The random numbers of one simulation trial, addressable by what they decide.
///
/// ## Why not a shared generator
///
/// Two requirements pull against a single mutable generator.
///
/// 1. **Determinism under parallelism.** If trials shared one generator, the numbers a trial
///    saw would depend on which thread reached it first. Here a trial is a value derived from
///    `(masterSeed, trialIndex)` alone, so any scheduling gives bit-identical results.
/// 2. **Common random numbers.** Greedy seed selection compares candidate seed sets. If each
///    evaluation drew a fresh stream, the comparison would be dominated by sampling noise
///    rather than by the seeds. Here the draw for "does edge `u→v` fire" or "what is node
///    `v`'s threshold" is a fixed function of the trial and the edge or node — the same in
///    every candidate evaluation, whatever order the cascade happens to visit them in.
///
/// The numbers come from `SplitMix64` in SwiftDeterminism. That generator is a counter
/// passed through a mixing function, so "the `k`th draw of this trial" is computed directly
/// rather than by stepping.
///
/// ```swift
/// import BusinessMath
///
/// let trial = TrialRandomness(masterSeed: 42, trial: 3)
/// let again = TrialRandomness(masterSeed: 42, trial: 3)
/// print(trial.uniform(forNode: 7) == again.uniform(forNode: 7))   // true
/// ```
public struct TrialRandomness: Sendable, Equatable {

	private static let goldenRatioIncrement: UInt64 = 0x9E37_79B9_7F4A_7C15

	private let key: UInt64

	/// Derives the randomness of one trial.
	///
	/// - Parameters:
	///   - masterSeed: The seed of the whole estimate.
	///   - trial: Which trial, from zero. Different trials give independent-looking streams.
	public init(masterSeed: UInt64, trial: Int) {
		var generator = SplitMix64(
			seed: masterSeed &+ UInt64(truncatingIfNeeded: trial) &* Self.goldenRatioIncrement)
		self.key = generator.next()
	}

	/// A uniform draw in `[0, 1)` for the directed edge `from → to`.
	///
	/// The same trial always returns the same number for the same pair, and the draw for
	/// `u → v` is independent of the draw for `v → u`.
	///
	/// - Parameters:
	///   - from: Source node index.
	///   - to: Target node index.
	public func uniform(from: Int, to: Int) -> Double {
		let slot = (UInt64(truncatingIfNeeded: from) << 32) | (UInt64(truncatingIfNeeded: to) & 0xFFFF_FFFF)
		return draw(salt: 0x1, slot: slot)
	}

	/// A uniform draw in `[0, 1)` for one node, such as its activation threshold.
	///
	/// - Parameter node: Node index.
	public func uniform(forNode node: Int) -> Double {
		draw(salt: 0x2, slot: UInt64(truncatingIfNeeded: node))
	}

	private func draw(salt: UInt64, slot: UInt64) -> Double {
		var generator = SplitMix64(
			seed: (key ^ (salt &* 0xD6E8_FEB8_6659_FD93)) &+ (slot &* Self.goldenRatioIncrement))
		// Top 53 bits of the 64-bit output scaled into [0, 1): the same mapping the standard
		// library uses, without the generic range machinery on the per-edge hot path.
		return Double(generator.next() >> 11) * 0x1p-53
	}
}
