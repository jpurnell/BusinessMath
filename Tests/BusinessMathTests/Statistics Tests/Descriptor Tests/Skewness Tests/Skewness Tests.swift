//
//  Skewness Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Testing
import Numerics
@testable import BusinessMath

final class SkewnessTests: XCTestCase {

	func testCoefficientOfSkew() {
		let result = coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
		XCTAssertEqual(result, 1)
	}
	
    func testSkewS() {
        let values: [Double] = [96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]
        let result = (skewS(values) * 100000000.0).rounded(.up) / 100000000
        XCTAssertEqual(result, -0.06157035)
    }
}

@Suite("Skewness - Properties")
struct SkewnessProperties {

	@Test("Skewness is zero (or near) for symmetric data")
	func skewness_of_symmetric_data() {
		let x = [-2.0, -1.0, 0.0, 1.0, 2.0]
		let s = skewS(x)
		#expect(abs(s) < 1e-12)
	}
}
