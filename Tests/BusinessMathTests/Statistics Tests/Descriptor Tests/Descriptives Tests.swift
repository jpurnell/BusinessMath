//
//  Descriptives Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Descriptives Tests")
struct DescriptivesTests {

	@Test("Triangular distribution with zero range")
	func triangularZero() {
		let _ = triangularDistribution(low: 0, high: 1, base: 0.5)
		let resultZero = triangularDistribution(low: 0, high: 0, base: 0)
		let resultOne = triangularDistribution(low: 1, high: 1, base: 1)
		#expect(resultZero == 0)
		#expect(resultOne == 1)
	}

	@Test("Uniform distribution basic tests")
	func uniformDistribution() {
		let resultZero = distributionUniform(min: 0, max: 0)
		#expect(resultZero == 0)
		let resultOne = distributionUniform(min: 1, max: 1)
		#expect(resultOne == 1)
		let min = 2.0
		let max = 40.0
		let result = distributionUniform(min: min, max: max)
		#expect(result <= max)
		#expect(result >= min)
	}

	@Test("Normal distribution statistical properties")
	func distributionNormal() {
		// Seeded RNG for deterministic test
		struct SeededRNG {
			var state: UInt64
			mutating func next() -> Double {
				state = state &* 6364136223846793005 &+ 1
				let upper = Double((state >> 32) & 0xFFFFFFFF)
				return upper / Double(UInt32.max)
			}
		}

		var rng = SeededRNG(state: 54321)
		var array: [Double] = []
		// Increased sample size for better statistical properties
		for _ in 0..<10000 {
			var u1 = rng.next()
			var u2 = rng.next()
			// Clamp to avoid edge cases
			u1 = max(0.0001, min(0.9999, u1))
			u2 = max(0.0001, min(0.9999, u2))
			array.append(BusinessMath.distributionNormal(mean: 0, stdDev: 1, u1, u2))
		}

		let mu = mean(array)
		let sd = stdDev(array)

		// Tightened tolerance with larger sample size and seeded RNG
		#expect(abs(mu) < 0.1, "Mean should be close to 0, got \(mu)")
		#expect(abs(sd - 1.0) < 0.1, "StdDev should be close to 1, got \(sd)")
	}

	@Test("Triangular distribution varies with different base")
	func triangularVariation() {
		let resultQuarterBase = triangularDistribution(low: 0, high: 1, base: 0.25)
		let resultThreeQuartersBase = triangularDistribution(low: 0, high: 1, base: 0.75)
		#expect(resultQuarterBase != resultThreeQuartersBase)
	}

	@Test("Uniform distribution with wider range")
	func uniformDistributionWiderRange() {
		let min = -10.0
		let max = 10.0
		let result = distributionUniform(min: min, max: max)
		#expect(result <= max)
		#expect(result >= min)
	}

}
