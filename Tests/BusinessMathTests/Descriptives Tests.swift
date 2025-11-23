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
		var array: [Double] = []
		for _ in 0..<1000 {
			array.append(BusinessMath.distributionNormal(mean: 0, stdDev: 1))
		}
		let mu = (mean(array) * 10000).rounded() / 10000
		let sd = (stdDev(array) * 10000).rounded() / 10000
		#expect(mu > -2)
		#expect(mu < 2)
		#expect(sd > -2)
		#expect(sd < 2)
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
