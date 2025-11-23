//
//  Skewness Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Testing
import Numerics
@testable import BusinessMath

@Suite("SkewnessTests") struct SkewnessTests {

	@Test("CoefficientOfSkew") func LCoefficientOfSkew() {
		let result = coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
		#expect(result == 1)
	}
	
    @Test("SkewS") func LSkewS() {
        let values: [Double] = [96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]
        let result = (skewS(values) * 100000000.0).rounded(.up) / 100000000
        #expect(result == -0.06157035)
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
