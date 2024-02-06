//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class SimulationTests: XCTestCase {

	func testDistributionLogNormal() {
		// Shape can be evaluated in Excel via histogram
		//        var array: [Double] = []
		//        for _ in 0..<10000 {
		//            array.append(distributionLogNormal(mean: 0, variance: 1))
		//        }
		// print(array)
		XCTAssert(true)
	}
	
	func testDistributionNormal() {
		var array: [Double] = []
		for _ in 0..<1000 {
			array.append(distributionNormal(mean: 0, stdDev: 1))
		}
		let mu = (mean(array) * 10).rounded() / 10
		let sd = (stdDev(array) * 10).rounded() / 10
		XCTAssertEqual(mu, 0)
		XCTAssertEqual(sd, 1)
	}

	func testTriangularZero() {
		let a = 0.6
		let b = 1.0
		let c = 0.7
		
		var testBed: [Double] = []
		for _ in stride(from: 0.0, to: 1.0, by: 0.0001) {
			testBed.append(triangularDistribution(low: a, high: b, base: c))
		}
		let countUnderC = testBed.filter({$0 <= c}).count
		let roundedCount = (Double(countUnderC) / 10.0).rounded() * 10.0
		let roundedHigh = roundedCount * 1.02
		let roundedLow = roundedCount * 0.98
		let expectedObservations = ((c - a) * (2 / (b - a)) * (1 / 2) * 10000).rounded()
		print("Approx Count Under C \(countUnderC): Expected: \(expectedObservations)")
		
		//TODO: Should be sliced, with the highest count as base
		
		XCTAssertGreaterThan(expectedObservations, roundedLow)
		XCTAssertLessThan(expectedObservations, roundedHigh)
    }
    
    func testUniformDistribution() {
        let resultZero = distributionUniform(min: 0, max: 0)
        XCTAssertEqual(resultZero, 0)
        let resultOne = distributionUniform(min: 1, max: 1)
        XCTAssertEqual(resultOne, 1)
        let min = 2.0
        let max = 40.0
        let result = distributionUniform(min: min, max: max)
        XCTAssertLessThanOrEqual(result, max, "Value must be below \(max)")
        XCTAssertGreaterThanOrEqual(result, min)
    }
}

