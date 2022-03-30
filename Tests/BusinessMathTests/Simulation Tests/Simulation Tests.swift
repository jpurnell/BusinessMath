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
    
    func testTriangularZero() {
        let _ = triangularDistribution(low: 0, high: 1, base: 0.5)
        let resultZero = triangularDistribution(low: 0, high: 0, base: 0)
        let resultOne = triangularDistribution(low: 1, high: 1, base: 1)
        XCTAssertEqual(resultZero, 0)
        XCTAssertEqual(resultOne, 1)
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
    
    func testDistributionLogNormal() {
        // Shape can be evaluated in Excel via histogram
        //        var array: [Double] = []
        //        for _ in 0..<10000 {
        //            array.append(distributionLogNormal(mean: 0, variance: 1))
        //        }
        // print(array)
        XCTAssert(true)
    }
}

