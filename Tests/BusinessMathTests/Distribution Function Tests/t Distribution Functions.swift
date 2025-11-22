//
//  t Distribution Functions.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
import OSLog
@testable import BusinessMath

final class TDistributionTests: XCTestCase {
	let tDistributionTestLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "T Distribution Tests")
    func testTDistributionFunctions() {
		// Test tStatistic calculation
		// t = (x - mean) / stdErr
		let x = 5.0
		let mean = 3.0
		let stdErr = 1.0
		let tStat = tStatistic(x: x, mean: mean, stdErr: stdErr)
		XCTAssertEqual(tStat, 2.0)  // (5 - 3) / 1 = 2

		// Test with default parameters
		let tStatDefault = tStatistic(x: 1.0)
		XCTAssertEqual(tStatDefault, 1.0)  // (1 - 0) / 1 = 1

		// Test pValueStudent (t-distribution PDF)
		let tValue = 2.0
		let dF = 10.0
		let pVal = pValueStudent(tValue, dFr: dF)

		// P-value should be between 0 and 1
		XCTAssertGreaterThan(pVal, 0.0)
		XCTAssertLessThan(pVal, 1.0)

		// Test that p-value at t=0 is higher (center of distribution)
		let pValAtZero = pValueStudent(0.0, dFr: dF)
		XCTAssertGreaterThan(pValAtZero, pVal)

		// Test with larger degrees of freedom (should approach normal)
		let pValLargeDf = pValueStudent(tValue, dFr: 100.0)
		XCTAssertGreaterThan(pValLargeDf, 0.0)
		XCTAssertLessThan(pValLargeDf, 1.0)
    }

}
