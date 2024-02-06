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
	let loggerCentralTendencyTest = Logger(subsystem: "Business Math > Tests > Business Math Tests > Statistics > Descriptor Tests > Central Tendency", category: "Central Tendency Tests")
    
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
		loggerCentralTendencyTest.warning("Test not implemented for \(self.name)")
		XCTAssert(true)
	}
	
	func testLogarithmicMean() {
		loggerCentralTendencyTest.warning("Test not implemented for \(self.name)")
		XCTAssert(true)
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
		print(result)
		print(resultOne)
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
