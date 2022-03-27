//
//  Skewness Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class SkewnessTests: XCTestCase {

    func testSkewS() {
        let values: [Double] = [96, 13, 84, 59, 92, 24, 68, 80, 89, 88, 37, 27, 44, 66, 14, 15, 87, 34, 36, 48, 64, 26, 79, 53]
        let result = (skewS(values) * 100000000.0).rounded(.up) / 100000000
        XCTAssertEqual(result, -0.06157035)
    }

    func testCoefficientOfSkew() {
        let result = coefficientOfSkew(mean: 1, median: 0, stdDev: 3)
        XCTAssertEqual(result, 1)
    }
}
