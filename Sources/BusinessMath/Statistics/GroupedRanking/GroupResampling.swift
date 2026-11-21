//
//  GroupResampling.swift
//  BusinessMath
//

import Foundation
import Numerics

/// Resampling whole groups, never rows.
///
/// Rows within a group share the group's propensity to choose, so a row-level bootstrap or fold assignment would put
/// a group's candidates on both sides of a split and understate every uncertainty. Everything here works on groups, and
/// a resample is a vector of weights (how many times each group appears), so a fit takes `groupWeights` and no data is copied.
///
/// ## Determinism
///
/// Every function takes a generator, and the same generator state gives the same result. None touches the system
/// generator. Draws use ``below(_:using:)``, which is unbiased and does not depend on the standard library's own bounded-draw
/// algorithm, so a result does not change between Swift releases. Use ``SplitMix64`` (from SwiftDeterminism) for a seeded stream.
public enum GroupResampling {

	/// A whole number from zero up to, not including, `bound`, drawn without modulo bias; zero when `bound` is not positive.
	public static func below<G: RandomNumberGenerator>(_ bound: Int, using generator: inout G) -> Int {
		guard bound > 1 else { return 0 }
		let limit = UInt64(bound)
		// Reject the short final block of the 64-bit range so every residue is equally likely.
		let threshold = (0 &- limit) % limit
		var draw = generator.next()
		while draw < threshold { draw = generator.next() }
		return Int(draw % limit)
	}

	/// How many times each of `groups` groups appears in one bootstrap resample: `groups` draws with replacement.
	///
	/// The weights are whole numbers (as `T`), and sum to `groups`.
	///
	/// - Returns: An empty array when `groups` is not positive.
	public static func bootstrapWeights<T: BinaryFloatingPoint, G: RandomNumberGenerator>(
		groups: Int, using generator: inout G
	) -> [T] {
		guard groups > 0 else { return [] }
		var counts = [Int](repeating: 0, count: groups)
		for _ in 0..<groups { counts[below(groups, using: &generator)] += 1 }
		return counts.map { T($0) }
	}

	/// A fold number for each of `groups` groups: balanced (fold sizes differ by at most one), shuffled, every fold used
	/// when `groups >= folds`.
	///
	/// - Returns: An empty array when `groups` or `folds` is not positive.
	public static func foldAssignment<G: RandomNumberGenerator>(groups: Int, folds: Int, using generator: inout G) -> [Int] {
		guard groups > 0, folds > 0 else { return [] }
		var order = Array(0..<groups)
		var index = groups - 1
		while index > 0 {
			let other = below(index + 1, using: &generator)
			if other != index { order.swapAt(index, other) }
			index -= 1
		}
		var result = [Int](repeating: 0, count: groups)
		for (position, group) in order.enumerated() { result[group] = position % folds }
		return result
	}
}
