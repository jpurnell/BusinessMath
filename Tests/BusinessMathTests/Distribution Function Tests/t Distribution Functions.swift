//
//  t Distribution Functions.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("t Distribution Tests")
struct TDistributionTests {

	@Test("tStatistic computes (x - mean) / stdErr")
	func tStatistic_basic() throws {
		let x = 5.0
		let mean = 3.0
		let stdErr = 1.0
		let tStat = tStatistic(x: x, mean: mean, stdErr: stdErr)
		#expect(tStat == 2.0)
	}

	@Test("tStatistic with default parameters")
	func tStatistic_default() throws {
		let tStatDefault = tStatistic(x: 1.0)
		#expect(tStatDefault == 1.0) // (1 - 0) / 1
	}

	@Test("pValueStudent is within (0,1)")
	func pValue_bounds() throws {
		let tValue = 2.0
		let dF = 10.0
		let pVal = pValueStudent(tValue, dFr: dF)
		#expect(pVal > 0.0)
		#expect(pVal < 1.0)
	}

	@Test("pValueStudent at t=0 is higher than at t=2 (PDF peak at center)")
	func pValue_center_higher() throws {
		let dF = 10.0
		let pValAtZero = pValueStudent(0.0, dFr: dF)
		let pValAtTwo = pValueStudent(2.0, dFr: dF)
		#expect(pValAtZero > pValAtTwo)
	}

	@Test("pValueStudent with large df remains within (0,1)")
	func pValue_large_df() throws {
		let tValue = 2.0
		let pValLargeDf = pValueStudent(tValue, dFr: 100.0)
		#expect(pValLargeDf > 0.0)
		#expect(pValLargeDf < 1.0)
	}
}
