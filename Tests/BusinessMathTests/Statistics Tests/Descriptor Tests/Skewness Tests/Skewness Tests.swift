//
//  Skewness Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
@testable import BusinessMath

@Suite("SkewnessTests") struct SkewnessTests {

	@Test("CoefficientOfSkew") func LCoefficientOfSkew() throws {
		let result = try coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
		#expect(result == 1)
	}

	@Test("CoefficientOfSkew throws on zero stdDev") func LCoefficientOfSkewThrowsOnZeroStdDev() {
		#expect(throws: BusinessMathError.self) {
			_ = try coefficientOfSkew(mean: 1.0, median: 0.0, stdDev: 0.0)
		}
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

@Suite("Skewness - NaN and Infinity Input Rejection")
struct SkewnessNaNInfinityTests {

	@Test("skewS propagates NaN")
	func skewS_propagates_nan() {
		let values = [1.0, 2.0, Double.nan, 4.0, 5.0]
		let result = skewS(values)
		#expect(result.isNaN)
	}

	@Test("skewS handles infinity")
	func skewS_handles_infinity() {
		let values = [1.0, 2.0, Double.infinity, 4.0, 5.0]
		let result = skewS(values)
		#expect(result.isNaN || result.isInfinite)
	}

	@Test("coefficientOfSkew propagates NaN from mean")
	func coefficient_of_skew_propagates_nan_from_mean() throws {
		let result = try coefficientOfSkew(mean: Double.nan, median: 2.0, stdDev: 1.0)
		#expect(result.isNaN)
	}

	@Test("coefficientOfSkew propagates NaN from median")
	func coefficient_of_skew_propagates_nan_from_median() throws {
		let result = try coefficientOfSkew(mean: 2.0, median: Double.nan, stdDev: 1.0)
		#expect(result.isNaN)
	}

	@Test("coefficientOfSkew rejects NaN stdDev")
	func coefficient_of_skew_rejects_nan_stdDev() {
		// NaN stdDev is treated as invalid (zero-like) and throws divisionByZero
		#expect(throws: BusinessMathError.self) {
			_ = try coefficientOfSkew(mean: 2.0, median: 1.0, stdDev: Double.nan)
		}
	}

	@Test("coefficientOfSkew handles infinity")
	func coefficient_of_skew_handles_infinity() throws {
		let result1 = try coefficientOfSkew(mean: Double.infinity, median: 1.0, stdDev: 1.0)
		#expect(result1.isInfinite || result1.isNaN)

		let result2 = try coefficientOfSkew(mean: 2.0, median: 1.0, stdDev: Double.infinity)
		#expect(result2.isFinite && result2 == 0.0)  // (2-1) / infinity = 0
	}
}

@Suite("Skewness - Empty Array and Edge Cases")
struct SkewnessEmptyArrayTests {

	@Test("skewS handles empty array")
	func skewS_empty_array() {
		let values: [Double] = []
		let result = skewS(values)
		#expect(result.isNaN || result == 0.0)
	}

	@Test("skewS handles single element")
	func skewS_single_element() {
		let values = [5.0]
		let result = skewS(values)
		// Single element has undefined skewness (stdDev = 0)
		#expect(result.isNaN || result == 0.0)
	}

	@Test("skewS handles two elements")
	func skewS_two_elements() {
		let values = [1.0, 2.0]
		let result = skewS(values)
		// Two elements may have undefined skewness depending on implementation
		#expect(result.isNaN || result.isFinite)
	}
}
