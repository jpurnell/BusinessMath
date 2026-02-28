//
//  Covariance and Correlation Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import Testing
import Numerics
#if canImport(OSLog)
import OSLog
#endif
@testable import BusinessMath

@Suite("CovarianceandCorrelationTests") struct CovarianceandCorrelationTests {
	let logger = Logger(subsystem: "com.justinpurnell.businessMath.CovarianceandCorrelationTests", category: #function)

    @Test("CovarianceS") func LCovarianceS() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
        let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
        let result = ((covarianceS(xVar, yVar) * 1000).rounded()) / 1000
        #expect(result == 0.63)
    }

    @Test("CovarianceP") func LCovarianceP() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [2, 2.8, 4, 3.2]
        let yVar = [8.0, 11, 12, 8]
        let result = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
        #expect(result == 0.85)
    }

    @Test("Covariance") func LCovariance() {
        // Test from https://www.educba.com/covariance-formula/
        let xVar = [1.8, 1.5, 2.1, 2.4, 0.2]
        let yVar = [2.5, 4.3, 4.5, 4.1, 2.2]
        let result = ((covariance(xVar, yVar) * 100).rounded()) / 100
        let resultS = ((covarianceS(xVar, yVar) * 100).rounded()) / 100
        let resultP = ((covarianceP(xVar, yVar) * 100).rounded()) / 100
        #expect(result != resultP)
        #expect(result == resultS)
    }

    @Test("CorrelationCoefficient") func LCorrelationCoefficient() {
        let x = [20.0, 23, 45, 78, 21]
        let y = [200.0, 300, 500, 700, 100]
        
		let result = correlationCoefficient(x, y, .sample)
        let s = (result * 10000).rounded() / 10000
        #expect(s == 0.9487)
		
        let resultP = correlationCoefficient(x, y, .population)
        let sP = (resultP * 10000).rounded() / 10000
        #expect(sP == 0.9487)
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

@Suite("Covariance and Correlation - NaN and Infinity Input Rejection")
struct CovarianceCorrelationNaNInfinityTests {

	@Test("covarianceS propagates NaN from x")
	func covarianceS_propagates_nan_from_x() {
		let x = [1.0, Double.nan, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = covarianceS(x, y)
		#expect(result.isNaN)
	}

	@Test("covarianceS propagates NaN from y")
	func covarianceS_propagates_nan_from_y() {
		let x = [1.0, 2.0, 3.0]
		let y = [2.0, Double.nan, 6.0]
		let result = covarianceS(x, y)
		#expect(result.isNaN)
	}

	@Test("covarianceP propagates NaN from x")
	func covarianceP_propagates_nan_from_x() {
		let x = [1.0, Double.nan, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = covarianceP(x, y)
		#expect(result.isNaN)
	}

	@Test("covarianceP propagates NaN from y")
	func covarianceP_propagates_nan_from_y() {
		let x = [1.0, 2.0, 3.0]
		let y = [2.0, Double.nan, 6.0]
		let result = covarianceP(x, y)
		#expect(result.isNaN)
	}

	@Test("correlationCoefficient propagates NaN")
	func correlation_propagates_nan() {
		let x1 = [1.0, Double.nan, 3.0]
		let y1 = [2.0, 4.0, 6.0]
		let result1 = correlationCoefficient(x1, y1, .sample)
		#expect(result1.isNaN)

		let x2 = [1.0, 2.0, 3.0]
		let y2 = [2.0, Double.nan, 6.0]
		let result2 = correlationCoefficient(x2, y2, .population)
		#expect(result2.isNaN)
	}

	@Test("covariance handles infinity")
	func covariance_handles_infinity() {
		let x = [1.0, Double.infinity, 3.0]
		let y = [2.0, 4.0, 6.0]
		let resultS = covarianceS(x, y)
		let resultP = covarianceP(x, y)
		#expect(resultS.isInfinite || resultS.isNaN)
		#expect(resultP.isInfinite || resultP.isNaN)
	}

	@Test("correlationCoefficient handles infinity")
	func correlation_handles_infinity() {
		let x = [1.0, Double.infinity, 3.0, 4.0]
		let y = [2.0, 4.0, 6.0, 8.0]
		let result = correlationCoefficient(x, y, .sample)
		#expect(result.isNaN || result.isInfinite)
	}
}

@Suite("Covariance and Correlation - Empty Array Rejection")
struct CovarianceCorrelationEmptyArrayTests {

	@Test("covarianceS handles empty arrays")
	func covarianceS_empty_arrays() {
		let x: [Double] = []
		let y: [Double] = []
		let result = covarianceS(x, y)
		#expect(result.isNaN || result == 0.0)
	}

	@Test("covarianceP handles empty arrays")
	func covarianceP_empty_arrays() {
		let x: [Double] = []
		let y: [Double] = []
		let result = covarianceP(x, y)
		#expect(result.isNaN || result == 0.0)
	}

	@Test("covariance handles empty arrays")
	func covariance_empty_arrays() {
		let x: [Double] = []
		let y: [Double] = []
		let result = covariance(x, y)
		#expect(result.isNaN || result == 0.0)
	}

	@Test("correlationCoefficient handles empty arrays")
	func correlation_empty_arrays() {
		let x: [Double] = []
		let y: [Double] = []
		let resultS = correlationCoefficient(x, y, .sample)
		let resultP = correlationCoefficient(x, y, .population)
		#expect(resultS.isNaN || resultS == 0.0)
		#expect(resultP.isNaN || resultP == 0.0)
	}

	@Test("covariance handles single-element arrays")
	func covariance_single_element() {
		let x = [5.0]
		let y = [10.0]
		let result = covarianceS(x, y)
		// Single element has undefined sample covariance (division by n-1 = 0)
		#expect(result.isNaN || result.isInfinite || result == 0.0)
	}

	@Test("correlationCoefficient handles single-element arrays")
	func correlation_single_element() {
		let x = [5.0]
		let y = [10.0]
		let result = correlationCoefficient(x, y, .sample)
		#expect(result.isNaN || result == 0.0)
	}
}

@Suite("Covariance and Correlation - Stress Tests")
struct CovarianceCorrelationStressTests {

	@Test("covarianceS handles large datasets", .timeLimit(.minutes(1)))
	func covarianceS_large_datasets() {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 }
		let result = covarianceS(x, y)
		#expect(result.isFinite)
		#expect(result > 0)
	}

	@Test("covarianceP handles large datasets", .timeLimit(.minutes(1)))
	func covarianceP_large_datasets() {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 }
		let result = covarianceP(x, y)
		#expect(result.isFinite)
		#expect(result > 0)
	}

	@Test("correlationCoefficient handles large datasets", .timeLimit(.minutes(1)))
	func correlation_large_datasets() {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 + 3.0 }
		let resultS = correlationCoefficient(x, y, .sample)
		let resultP = correlationCoefficient(x, y, .population)
		#expect(resultS.isFinite)
		#expect(resultP.isFinite)
		// Perfect linear relationship
		#expect(abs(resultS - 1.0) < 1e-10)
		#expect(abs(resultP - 1.0) < 1e-10)
	}
}
