//
//  SeededRNG.swift
//  TestSupport
//
//  Deterministic pseudo-random number generator for reproducible tests
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
