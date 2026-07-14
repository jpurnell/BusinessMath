//
//  SplitMix64.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2026-07-14.
//

import Foundation

/// A fast, seedable random number generator with a published reference implementation.
///
/// `SplitMix64` (Vigna, 2015) produces a deterministic stream of 64-bit values from a
/// seed: the same seed always yields the same sequence, on every platform and Swift
/// version. BusinessMath uses it to drive reproducible Monte Carlo runs — pass a seed
/// to ``MonteCarloSimulation`` and every CPU-path sample flows through this generator.
///
/// The algorithm is a single additive state update followed by a mixing function, so
/// it is both allocation-free and faster than `SystemRandomNumberGenerator`. It is
/// statistically strong for simulation work, but it is **not** cryptographically
/// secure — never use it for keys, tokens, or anything security-sensitive.
///
/// ## Example
///
/// ```swift
/// var rng = SplitMix64(seed: 42)
/// let u = Double.random(in: 0...1, using: &rng)   // identical on every run
/// ```
public struct SplitMix64: RandomNumberGenerator, Sendable {

	/// The generator's internal 64-bit state, advanced by the golden-ratio increment.
	private var state: UInt64

	/// Creates a generator whose output stream is fully determined by `seed`.
	///
	/// - Parameter seed: Any 64-bit value. Equal seeds produce equal streams.
	public init(seed: UInt64) {
		self.state = seed
	}

	/// Returns the next 64-bit value in the deterministic stream.
	///
	/// Matches Vigna's reference `splitmix64.c`: seed 0 yields
	/// `0xE220A8397B1DCDAF` as its first output.
	///
	/// - Returns: The next pseudorandom 64-bit value.
	public mutating func next() -> UInt64 {
		state &+= 0x9E3779B97F4A7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
		z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
		return z ^ (z >> 31)
	}
}
