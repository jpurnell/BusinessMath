//
//  Test Template.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class NormalDistributionFunctionTests: XCTestCase {
    
    func testStandardize() {
        let result = (standardize(x: 11.96, mean: 10, stdev: 1) * 1000).rounded() / 1000
        XCTAssertEqual(result, 1.96)
    }
    
    func testNormSInv() {
        let result = (normSInv(probability: 0.975) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }
    
    func testNormInv() {
        let resultZero = normInv(probability: 0.5, mean: 0, stdev: 1)
        XCTAssertEqual(resultZero, 0)
        let result = (normInv(probability: 0.975, mean: 10, stdev: 1) * 1000).rounded(.up) / 1000
        XCTAssertEqual(result, 11.96)
    }
    
    func testZScore() {
        let result = (zScore(percentile: 0.975) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 1.959964)
    }
    
    func testNormDist() {
        let result = normDist(x: 0, mean: 0, stdev: 1)
        let resultNotes = (normDist(x: 10, mean: 10.1, stdev: 0.04) * 1000000).rounded(.up) / 1000000
        XCTAssertEqual(result, 0.5)
        XCTAssertEqual(resultNotes, 0.00621)
    }
    
    func testNormSDist() {
        let result = (normSDist(zScore: 1.95996398454) * 1000).rounded(.up) / 1000
        let resultNeg = (normSDist(zScore: -1.95996398454) * 1000).rounded() / 1000
        let resultZero = (normSDist(zScore: 0.0) * 1000).rounded() / 1000
        XCTAssertEqual(result, 0.975)
        XCTAssertEqual(resultNeg, 0.025)
        XCTAssertEqual(resultZero, 0.5)
    }
    
    func testPercentile() {
        let result = (percentile(zScore: 1.95996398454) * 1000).rounded() / 1000
        XCTAssertEqual(result, 0.975)
    }
    
    func testNormalCDF() {
        let result = (normalCDF(x: 1.96, mean: 0, stdDev: 1) * 1000.0).rounded(.down) / 1000
        XCTAssertEqual(result, 0.975)
    }

}
