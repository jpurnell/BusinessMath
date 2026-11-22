//
//  GroupResamplingTests.swift
//  BusinessMath
//
//  Group-level resampling: unbiased draws, bootstrap weights, balanced folds, quantiles.
//

import Testing
import Foundation
import Numerics
@testable import BusinessMath

/// A generator that returns a scripted sequence of draws, so the rejection path can be reached on purpose.
private struct ScriptedGenerator: RandomNumberGenerator {
	var draws: [UInt64]
	var used = 0
	mutating func next() -> UInt64 {
		let value = draws[used % draws.count]
		used += 1
		return value
	}
}

@Suite("Grouped choice: resampling")
struct GroupResamplingTests {

	@Test("A bounded draw stays in range and returns zero for a bound that is not above one")
	func belowRange() {
		var generator = SplitMix64(seed: 1)
		for bound in [1, 2, 3, 7, 100] {
			for _ in 0..<200 { let value = GroupResampling.below(bound, using: &generator); #expect(value >= 0 && value < bound) }
		}
		#expect(GroupResampling.below(0, using: &generator) == 0)
		#expect(GroupResampling.below(-5, using: &generator) == 0)
	}

	@Test("A draw in the biased short block is rejected and the next one used")
	func belowRejects() {
		// 2^64 mod 3 = 1, so a draw of 0 falls in the rejected block for bound 3; the next draw, 5, gives 5 % 3 = 2.
		var generator = ScriptedGenerator(draws: [0, 5])
		let value = GroupResampling.below(3, using: &generator)
		#expect(value == 2)
		#expect(generator.used == 2)
		// A draw of 1 is the first accepted one: 1 % 3 = 1, with no second draw.
		var accepting = ScriptedGenerator(draws: [1])
		#expect(GroupResampling.below(3, using: &accepting) == 1)
		#expect(accepting.used == 1)
	}

	@Test("Draws are spread evenly across the range")
	func belowUniform() {
		var generator = SplitMix64(seed: 42)
		var counts = [Int](repeating: 0, count: 6)
		for _ in 0..<60_000 { counts[GroupResampling.below(6, using: &generator)] += 1 }
		// Expected 10,000 each; the standard deviation is about 91, so 500 is more than five of them.
		for count in counts { #expect(abs(count - 10_000) < 500) }
	}

	@Test("Bootstrap weights are whole numbers that sum to the number of groups, and repeat for a seed")
	func bootstrapWeights() {
		var a = SplitMix64(seed: 5)
		var b = SplitMix64(seed: 5)
		var c = SplitMix64(seed: 6)
		let first: [Double] = GroupResampling.bootstrapWeights(groups: 50, using: &a)
		let second: [Double] = GroupResampling.bootstrapWeights(groups: 50, using: &b)
		let other: [Double] = GroupResampling.bootstrapWeights(groups: 50, using: &c)
		#expect(zip(first, second).allSatisfy { $0.isEqual(to: $1) })
		#expect(zip(first, other).contains { !$0.isEqual(to: $1) })
		#expect(first.count == 50)
		#expect(first.reduce(0, +) == 50)
		#expect(first.allSatisfy { $0 == $0.rounded() && $0 >= 0 })
		var empty = SplitMix64(seed: 5)
		let none: [Double] = GroupResampling.bootstrapWeights(groups: 0, using: &empty)
		#expect(none.isEmpty)
	}

	@Test("Folds are balanced, every fold is used, and the assignment repeats for a seed")
	func folds() {
		var a = SplitMix64(seed: 9)
		var b = SplitMix64(seed: 9)
		var c = SplitMix64(seed: 10)
		let first = GroupResampling.foldAssignment(groups: 23, folds: 5, using: &a)
		#expect(first == GroupResampling.foldAssignment(groups: 23, folds: 5, using: &b))
		#expect(first != GroupResampling.foldAssignment(groups: 23, folds: 5, using: &c))
		var sizes = [Int](repeating: 0, count: 5)
		for fold in first { sizes[fold] += 1 }
		#expect(sizes.sorted() == [4, 4, 5, 5, 5])
		#expect(first.allSatisfy { $0 >= 0 && $0 < 5 })
		var d = SplitMix64(seed: 1)
		#expect(GroupResampling.foldAssignment(groups: 0, folds: 3, using: &d).isEmpty)
		#expect(GroupResampling.foldAssignment(groups: 3, folds: 0, using: &d).isEmpty)
		// Fewer groups than folds: each group alone, some folds empty.
		let few = GroupResampling.foldAssignment(groups: 2, folds: 5, using: &d)
		#expect(few.count == 2)
		#expect(Set(few).count == 2)
	}

	@Test("Quantiles interpolate linearly and the tail of a level is half what it leaves out")
	func quantiles() {
		let sorted = [1.0, 2.0, 3.0, 4.0]
		#expect(abs(GroupedCrossValidation.percentile(sorted, 0.5) - 2.5) < 1e-12)
		#expect(GroupedCrossValidation.percentile(sorted, 0) == 1)
		#expect(GroupedCrossValidation.percentile(sorted, 1) == 4)
		#expect(abs(GroupedCrossValidation.percentile(sorted, 1.0 / 3.0) - 2) < 1e-12)
		#expect(GroupedCrossValidation.percentile(sorted, -1) == 1)
		#expect(GroupedCrossValidation.percentile(sorted, 2) == 4)
		#expect(GroupedCrossValidation.percentile([7.0], 0.9) == 7)
		#expect(GroupedCrossValidation.percentile([Double](), 0.9) == 0)
		#expect(GroupedCrossValidation.percentile(sorted, Double.nan) == 1)
		#expect(abs(GroupedCrossValidation.tailProbability(level: 0.9) - 0.05) < 1e-15)
		#expect(GroupedCrossValidation.tailProbability(level: 1.5) == 0)
		#expect(abs(GroupedCrossValidation.tailProbability(level: -1) - 0.5) < 1e-12)
	}
}
