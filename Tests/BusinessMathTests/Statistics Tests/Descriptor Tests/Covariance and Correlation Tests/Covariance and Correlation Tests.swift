//
//  Covariance and Correlation Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Testing
import Numerics
import OSLog
@testable import BusinessMath

@testable import BusinessMath

final class CovarianceandCorrelationTests: XCTestCase {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.CovarianceandCorrelationTests", category: #function)

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

@Suite("Covariance and Correlation - Properties")
struct CovarianceCorrelationProperties {

	@Test("Covariance symmetry and constants")
	func covariance_symmetry_and_constant() {
		let x = [1.0, 2.0, 3.0, 4.0]
		let y = [2.0, 3.0, 4.0, 5.0]

		let covSxy = covarianceS(x, y)
		let covSyx = covarianceS(y, x)
		#expect(close(covSxy, covSyx, accuracy: 1e-12))

		let z = [3.0, 3.0, 3.0, 3.0]
		#expect(close(covarianceS(x, z), 0.0, accuracy: 1e-12))
		#expect(close(covarianceP(x, z), 0.0, accuracy: 1e-12))
	}

	@Test("Sample vs population covariance relationship")
	func covariance_sample_population_relationship() {
		let x = [1.8, 1.5, 2.1, 2.4, 0.2]
		let y = [2.5, 4.3, 4.5, 4.1, 2.2]
		let n = Double(x.count)
		let covPVal = covarianceP(x, y)
		let covSVal = covarianceS(x, y)
		#expect(close(covSVal, covPVal * n / (n - 1.0), accuracy: 1e-12))
	}

	@Test("Correlation bounds and linear relationships")
	func correlation_bounds_and_linearity() {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = x.map { 2.0 * $0 + 10.0 } // perfect positive linear
		let yNeg = x.map { -3.0 * $0 + 5.0 } // perfect negative linear

		let r1 = correlationCoefficient(x, y, .sample)
		#expect(close(r1, 1.0, accuracy: 1e-12))

		let r2 = correlationCoefficient(x, yNeg, .sample)
		#expect(close(r2, -1.0, accuracy: 1e-12))

		let rSelf = correlationCoefficient(x, x, .sample)
		#expect(close(rSelf, 1.0, accuracy: 1e-12))

		// Bounds
		#expect(abs(correlationCoefficient(x, [5,4,3,2,1].map(Double.init), .sample)) <= 1.0 + 1e-12)
	}
}
