//
//  Central Tendency Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
import OSLog
@testable import BusinessMath

final class CentralTendencyTests: XCTestCase {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.CentralTendencyTests", category: #function)
    
    func testArithmeticGeometricMean() {
        let x: Double = 4
        let y: Double = 9
        let result = (arithmeticGeometricMean([x, y]) * 10000).rounded() / 10000
        XCTAssertEqual(result, 6.2475)
    }
	
	func testArithmeticHarmonicMean() {
		let x: Double = 4
		let y: Double = 9
		let result = (arithmeticHarmonicMean([x, y]) * 10000).rounded() / 10000
		XCTAssertEqual(result, 6.0)
	}
	
	func testContraHarmonicMean() {
		let values: [Double] = [1, 2, 3, 4, 5]
		let result = (contraharmonicMean(values) * 10000).rounded() / 10000
		XCTAssertEqual(result, 3.6667)
		
		let x: Double = 4
		let y: Double = 9
		let specializedResult = (contraharmonicMean([x, y]) * 10000).rounded() / 10000
		XCTAssertEqual(specializedResult, 7.4615)
	}

	func testGeometricMean() {
		let x: Double = 4
		let y: Double = 9
		let result = geometricMean([x, y])
		XCTAssertEqual(result, 6.0)
	}
	
    func testHarmonicMean() {
		let values = [1.0, 4.0, 4.0]
		let result = harmonicMean(values)
		XCTAssertEqual(result, 2)
		
        let x: Double = 4
        let y: Double = 9
        let specializedResult = (harmonicMean([x, y]) * 10000).rounded() / 10000
        XCTAssertEqual(specializedResult, 5.5385)
    }
	
	func testIdentricMean() {
		// Test with standard values
		let x: Double = 3.0
		let y: Double = 4.0
		let result = (identricMean(x, y) * 10000).rounded() / 10000
		XCTAssertEqual(result, 3.488, accuracy: 0.0001)
		
		// Test that identric mean is symmetric
		let reversed = (identricMean(y, x) * 10000).rounded() / 10000
		XCTAssertEqual(result, reversed, accuracy: 0.0001)
		
		// Test with another pair of values
		let a: Double = 2.0
		let b: Double = 8.0
		let result2 = (identricMean(a, b) * 10000).rounded() / 10000
		// Identric mean of 2 and 8 is approximately 4.6718
		XCTAssertEqual(result2, 4.6718, accuracy: 0.0001)
	}
	
	func testLogarithmicMean() {
		// Test with standard values
		let x: Double = 3.0
		let y: Double = 4.0
		let result = (logarithmicMean(x, y) * 10000).rounded() / 10000
		XCTAssertEqual(result, 3.4761, accuracy: 0.0001)
		
		// Test that logarithmic mean is symmetric
		let reversed = (logarithmicMean(y, x) * 10000).rounded() / 10000
		XCTAssertEqual(result, reversed, accuracy: 0.0001)
		
		// Test with values where logarithmic mean is between geometric and arithmetic means
		let a: Double = 2.0
		let b: Double = 8.0
		let logMean = logarithmicMean(a, b)
		let geoMean = geometricMean([a, b])
		let arithMean = mean([a, b])
		
		// Logarithmic mean should be between geometric and arithmetic means
		XCTAssertTrue(logMean > geoMean, "Logarithmic mean (\(logMean)) should be greater than geometric mean (\(geoMean))")
		XCTAssertTrue(logMean < arithMean, "Logarithmic mean (\(logMean)) should be less than arithmetic mean (\(arithMean))")
	}
	
	func testMean() {
		let doubleArray: [Double] = [0.0, 1.0, 2.0, 3.0, 4.0]
		let result = mean(doubleArray)
		XCTAssertEqual(result, 2.0)
	}

	func testMedian() {
		let result = median([0.0, 1.0, 2.0, 3.0, 4.0, 5.0])
		let resultOdd = median([0.0, 1.0, 2.0, 3.0, 4.0])
		let resultOne = median([1.0, 1, 1, 1, 1, 1, 2])
		XCTAssertEqual(result, 2.5)
		XCTAssertEqual(resultOdd, 2.0)
		XCTAssertEqual(resultOne, 1)
	}

	func testMode() {
		let doubleArray: [Float] = [0.0, 2.0, 2.0, 3.0, 2.0]
		let result = mode(doubleArray)
		XCTAssertEqual(result, 2)
	}


}
