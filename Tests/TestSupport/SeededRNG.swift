//
//  SeededRNG.swift
//  TestSupport
//
//  Deterministic pseudo-random number generators for reproducible tests
//

import Foundation

/// Simple Linear Congruential Generator for reproducible pseudo-random sequences
///
/// Uses LCG parameters from Numerical Recipes: a=1664525, c=1013904223, m=2^32
/// This provides truly random-looking but deterministic sequences for testing.
public class SeededRNG {
	private var state: UInt64

	public init(seed: UInt64 = 12345) {
		self.state = seed
	}

	/// Generate next random Double in [0,1)
	public func next() -> Double {
		// LCG formula: state = (a * state + c) mod m
		let a: UInt64 = 1664525
		let c: UInt64 = 1013904223
		let m: UInt64 = UInt64(1) << 32  // 2^32

		state = (a &* state &+ c) % m
		return Double(state) / Double(m)
	}

	/// Generate array of random doubles
	public func nextArray(count: Int) -> [Double] {
		return (0..<count).map { _ in next() }
	}

	/// Reset generator to initial seed
	public func reset(seed: UInt64 = 12345) {
		self.state = seed
	}
}

/// Knuth's MMIX-style Linear Congruential Generator (value-type variant).
///
/// Uses the LCG multiplier `6364136223846793005` from Knuth's MMIX
/// (TAOCP §3.3.4, Table 1, Line 26). The output is the upper 32 bits of
/// the state divided by `UInt32.max`, producing values in `[0, 1]`.
///
/// **Why this exists alongside the LCG-based ``SeededRNG``:** several
/// existing test files in BusinessMath had inlined this exact LCG variant
/// as a local `struct SeededRNG { var state: UInt64; ... }`. Consolidating
/// them under a shared type required preserving the bit-exact output
/// sequence so that test assertions wouldn't need re-tuning. This type
/// matches that local sequence exactly.
///
/// `MMIXSeededRNG` is a value type (struct) with `mutating func next()`,
/// matching the API the migrated test files were already using. For new
/// tests, prefer `SeededRNG` unless you have a specific reason to need
/// the MMIX sequence.
public struct MMIXSeededRNG {
	/// Internal LCG state. Public so tests can save and restore positions
	/// if needed.
	public var state: UInt64

	/// Create a generator seeded with the given state.
	public init(state: UInt64 = 12345) {
		self.state = state
	}

	/// Generate the next random `Double` in `[0, 1]`.
	///
	/// Mutates `state` in place using the MMIX LCG formula:
	///     state = state * 6364136223846793005 + 1
	public mutating func next() -> Double {
		state = state &* 6364136223846793005 &+ 1
		let upper = Double((state >> 32) & 0xFFFFFFFF)
		return upper / Double(UInt32.max)
	}

	/// Generate the next random `Double` mapped to `[-1, 1]`.
	///
	/// Convenience for tests that need signed random values without
	/// re-implementing the mapping. Equivalent to `next() * 2 - 1`.
	public mutating func nextSigned() -> Double {
		return next() * 2.0 - 1.0
	}
}
