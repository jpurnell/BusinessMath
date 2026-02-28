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
		let result = standardize(x: 11.96, mean: 10, stdev: 1)
		#expect(abs(result - 1.96) < 0.001)
	}

	@Test("normSInv")
	func normSInvTest() throws {
		let result = normSInv(probability: 0.975)
		#expect(abs(result - 1.959964) < 0.000001)
	}

	@Test("normInv")
	func normInvTest() throws {
		let resultZero = normInv(probability: 0.5, mean: 0, stdev: 1)
		#expect(abs(resultZero - 0.0) < 1e-10)

		let result = normInv(probability: 0.975, mean: 10, stdev: 1)
		#expect(abs(result - 11.96) < 0.001)
	}

	@Test("zScore")
	func zScoreTest() throws {
		let result = zScore(percentile: 0.975)
		#expect(abs(result - 1.959964) < 0.000001)
	}

	@Test("normDist")
	func normDistTest() throws {
		let result = normDist(x: 0, mean: 0, stdev: 1)
		let resultNotes = normDist(x: 10, mean: 10.1, stdev: 0.04)

		#expect(abs(result - 0.5) < 1e-10)
		#expect(abs(resultNotes - 0.00621) < 0.000001)
	}

	@Test("normSDist")
	func normSDistTest() throws {
		let result = normSDist(zScore: 1.95996398454)
		let resultNeg = normSDist(zScore: -1.95996398454)
		let resultZero = normSDist(zScore: 0.0)

		#expect(abs(result - 0.975) < 0.001)
		#expect(abs(resultNeg - 0.025) < 0.001)
		#expect(abs(resultZero - 0.5) < 1e-10)
	}

	@Test("percentile")
	func percentileTest() throws {
		let result = percentile(zScore: 1.95996398454)
		#expect(abs(result - 0.975) < 0.001)
	}

	@Test("normalCDF")
	func normalCDFTest() throws {
		let result = normalCDF(x: 1.96, mean: 0, stdDev: 1)
		#expect(abs(result - 0.975) < 0.001)
	}
}
