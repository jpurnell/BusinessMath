//
//  Test Template.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("Normal Distribution Function Tests")
struct NormalDistributionFunctionTests {

	@Test("standardize")
	func standardizeTest() throws {
		let result = (standardize(x: 11.96, mean: 10, stdev: 1) * 1000).rounded() / 1000
		#expect(result == 1.96)
	}

	@Test("normSInv")
	func normSInvTest() throws {
		let result = (normSInv(probability: 0.975) * 1_000_000).rounded(.up) / 1_000_000
		#expect(result == 1.959964)
	}

	@Test("normInv")
	func normInvTest() throws {
		let resultZero = normInv(probability: 0.5, mean: 0, stdev: 1)
		#expect(resultZero == 0)

		let result = (normInv(probability: 0.975, mean: 10, stdev: 1) * 1000).rounded(.up) / 1000
		#expect(result == 11.96)
	}

	@Test("zScore")
	func zScoreTest() throws {
		let result = (zScore(percentile: 0.975) * 1_000_000).rounded(.up) / 1_000_000
		#expect(result == 1.959964)
	}

	@Test("normDist")
	func normDistTest() throws {
		let result = normDist(x: 0, mean: 0, stdev: 1)
		let resultNotes = (normDist(x: 10, mean: 10.1, stdev: 0.04) * 1_000_000).rounded(.up) / 1_000_000

		#expect(result == 0.5)
		#expect(resultNotes == 0.00621)
	}

	@Test("normSDist")
	func normSDistTest() throws {
		let result = (normSDist(zScore: 1.95996398454) * 1000).rounded(.up) / 1000
		let resultNeg = (normSDist(zScore: -1.95996398454) * 1000).rounded() / 1000
		let resultZero = (normSDist(zScore: 0.0) * 1000).rounded() / 1000

		#expect(result == 0.975)
		#expect(resultNeg == 0.025)
		#expect(resultZero == 0.5)
	}

	@Test("percentile")
	func percentileTest() throws {
		let result = (percentile(zScore: 1.95996398454) * 1000).rounded() / 1000
		#expect(result == 0.975)
	}

	@Test("normalCDF")
	func normalCDFTest() throws {
		let result = (normalCDF(x: 1.96, mean: 0, stdDev: 1) * 1000.0).rounded(.down) / 1000
		#expect(result == 0.975)
	}
}
