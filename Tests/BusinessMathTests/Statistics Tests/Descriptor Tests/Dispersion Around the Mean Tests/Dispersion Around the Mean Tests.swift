//
//  Dispersion Around the Mean Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
import OSLog
@testable import BusinessMath

final class DispersionAroundtheMeanTests: XCTestCase {
	
	let loggerDispersionAroundTheMean = Logger(subsystem: "Business Math > Tests > Business Math Tests > Statistics > Descriptor Tests > Dispersion Around the Mean", category: "Dispersion Around the Mean Tests")

	func testCoefficientOfVariation() {
		let array: [Double] = [0, 1, 2, 3, 4]
		let stdDev = stdDev(array)
		let mean = mean(array)
		let result = try! coefficientOfVariation(stdDev, mean: mean)
		XCTAssertEqual(result, (Double.sqrt(2.5) / 2) * 100)
	}
	
	func testIndexOfDispersion() {
		loggerDispersionAroundTheMean.warning("Test not implemented for \(self.name)")
		XCTAssert(true)
	}

	func testStdDevP() {
	 let result = stdDevP([0, 1, 2, 3, 4])
	 XCTAssertEqual(result, Double.sqrt(2))
	 }

	 func testStdDevS() {
		 let result = (stdDevS([96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]) * 10000.0).rounded(.up) / 10000
		 XCTAssertEqual(result, 27.7243)
	 }

	 func testStdDev() {
		 let result = stdDev([0, 1, 2, 3, 4])
		 XCTAssertEqual(result, Double.sqrt(2.5))
	 }

    func testSumOfSquaredAvgDiff() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = sumOfSquaredAvgDiff(doubleArray)
        XCTAssertEqual(result, 10)
    }

	func testTStatistic() {
		let result = tStatistic(x: 1)
		XCTAssertEqual(result, 1)
	}

    func testVarianceP() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = varianceP(doubleArray)
        XCTAssertEqual(result, 2)
    }

    func testVarianceS() {
        let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
        let result = varianceS(doubleArray)
        XCTAssertEqual(result, 2.5)
    }
	
	func testVarianceTDist() {
		loggerDispersionAroundTheMean.warning("Test not implemented for \(self.name)")
		XCTAssert(true)
	}
}
