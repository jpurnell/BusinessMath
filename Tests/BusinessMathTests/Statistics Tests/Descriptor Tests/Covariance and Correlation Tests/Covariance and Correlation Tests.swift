//
//  Covariance and Correlation Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class CovarianceandCorrelationTests: XCTestCase {

    func testCovarianceS() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
        let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
        let result = ((covarianceS(xVar, yVar) * 1000).rounded()) / 1000
        XCTAssertEqual(result, 0.63)
    }

    func testCovarianceP() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [2, 2.8, 4, 3.2]
        let yVar = [8.0, 11, 12, 8]
        let result = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
        XCTAssertEqual(result, 0.85)
    }

    func testCovariance() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
        let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
        let result = ((covariance(xVar, yVar) * 100).rounded()) / 100
        let resultS = ((covarianceS(xVar, yVar) * 100).rounded()) / 100
        let resultP = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
        XCTAssertNotEqual(result, resultP)
        XCTAssertEqual(result, resultS)
    }

    func testCorrelationCoefficient() {
        let x = [20.0, 23, 45, 78, 21]
        let y = [200.0, 300, 500, 700, 100]
        let result = correlationCoefficient(x, y, .sample)
        let s = (result * 10000).rounded() / 10000
        XCTAssertEqual(s, 0.9487)
        let resultP = correlationCoefficient(x, y, .population)
        let sP = (resultP * 10000).rounded() / 10000
        XCTAssertEqual(sP, 0.9487)
    }
}
