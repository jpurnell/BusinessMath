//
//  OwenScramble.swift
//  BusinessMath
//
//  Created 2026-09-04. Phase 0 of the Excel/Risk Solver coverage work.
//

import Foundation

/// Nested uniform scrambling of a base-2 radical inverse — Owen's scramble, computed
/// by hashing.
///
/// A plain Sobol sequence is deterministic, which costs two things: every run of a
/// simulation gives the identical answer with no way to estimate its error, and the
/// sequence's regular structure can align with a periodicity in the model and bias
/// the result.
///
/// Owen scrambling fixes both by permuting the digits of each coordinate — but
/// *nested*, so the permutation applied to a digit depends on all the digits above it.
/// That is what preserves the equidistribution: a scrambled Sobol sequence is still a
/// Sobol sequence, with the same balance properties, and now unbiased in expectation.
///
/// The direct construction stores a permutation tree. Burley's observation is that a
/// sufficiently strong hash of the higher-order bits *is* such a tree, evaluated
/// lazily, which makes the whole thing a handful of multiplies with no storage at all.
///
/// Reference: Brent Burley, *Practical Hash-Based Owen Scrambling*, Journal of
/// Computer Graphics Techniques 9 (2020), 1–20.
///
/// - Parameters:
///   - value: The coordinate, as a fixed-point fraction in the high bits.
///   - seed: Chooses which of the possible scrambles to apply.
/// - Returns: The scrambled coordinate, in the same representation.
internal func owenScramble(_ value: UInt32, seed: UInt32) -> UInt32 {
	// Reversing puts the *high*-order digits of the fraction in the low-order bits of
	// the word. A hash mixes low bits into high ones, so after reversal each digit is
	// perturbed by the digits that precede it and by no others — which is exactly the
	// nesting the construction calls for. Reversing again restores the fraction.
	var bits = value.reversedBitOrder

	// Burley's mixing constants (§5). These are the algorithm: an avalanche schedule
	// found by search over multiplier quality, with nothing to derive them from. They
	// are reproduced exactly so that a scramble here matches one anywhere else the
	// same paper is implemented.
	bits ^= bits &* 0x3d20_adea
	bits = bits &+ seed
	bits = bits &* ((seed >> 16) | 1)
	bits ^= bits &* 0x0552_6c56
	bits ^= bits &* 0x53a2_2864

	return bits.reversedBitOrder
}

extension UInt32 {
	/// This value with its bit order reversed — bit 0 becomes bit 31, and so on.
	///
	/// The standard divide-and-conquer swap: exchange adjacent bits, then pairs, then
	/// nibbles, then bytes, then halves. Each mask selects the lanes moving one way and
	/// its complement selects the other, so every step is one shift pair and one or.
	internal var reversedBitOrder: UInt32 {
		var value = self
		value = ((value >> 1) & 0x5555_5555) | ((value & 0x5555_5555) << 1)
		value = ((value >> 2) & 0x3333_3333) | ((value & 0x3333_3333) << 2)
		value = ((value >> 4) & 0x0f0f_0f0f) | ((value & 0x0f0f_0f0f) << 4)
		value = ((value >> 8) & 0x00ff_00ff) | ((value & 0x00ff_00ff) << 8)
		return (value >> 16) | (value << 16)
	}
}
