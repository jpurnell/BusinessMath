//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import Testing
import Testing
import Numerics
@testable import BusinessMath


@Suite("LinearRegressionTests") struct LinearRegressionTests {

	func testlinearRegression() {
		let carAge: [Double] = [10, 8, 3, 3, 2, 1]
		let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
		let linearRegressionFunction = try! linearRegression(carAge, carPrice)
		let result = (linearRegressionFunction(4) * 1000).rounded(.up) / 1000
		#expect(result == 6952.927)
	}
	
    @Test("MultiplyVectors") func LMultiplyVectors() {
        let values: [Double] = [1, 2, 3, 4, 5]
        let multipliers: [Double] = [10, 10, 10, 10, 10]
        let result = try! multiplyVectors(values, multipliers)
        #expect(result == [10, 20, 30, 40, 50])
    }

    @Test("Slope") func LSlope() {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (try! slope(carAge, carPrice) * 1000).rounded(.up) / 1000
        #expect(result == -1272.519)
    }
    
    @Test("Intercept") func LIntercept() {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (try! intercept(carAge, carPrice) * 1000).rounded(.up) / 1000
        #expect(result == 12043.003)
    }
       
    @Test("RSquared") func LRSquared() {
        // Example from https://www.wallstreetmojo.com/r-squared-formula/
        let x: [Double] = [35.56, 43.44, 73.17, 113.0]
        let y: [Double] = [44.783, 53.982, 92.141, 135.986]
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let carResult = (rSquared(carAge, carPrice) * 100000).rounded(.up) / 100000
        let result = (rSquared(x, y) * 100000).rounded(.up) / 100000
        #expect(result == 0.99865)
        #expect(carResult == 0.93443)
    }
    
    @Test("RSquaredAdjusted") func LRSquaredAdjusted() {
        let x: [Double] = [58, 61, 62, 65, 65, 68, 72, 74, 78, 85, 90, 95]
        let y: [Double] = [1, 1, 2, 2, 1, 2, 2, 3, 3, 4, 4, 5]
        let result = (rSquared(x, y) * 100000).rounded(.up) / 100000
        #expect(result == 0.91983)
    }
}

@Suite("Linear Regression - Properties")
struct RegressionProperties {

	@Test("Regression line passes through (meanX, meanY)")
	func regression_passes_through_means() throws {
		let x = [10.0, 8, 3, 3, 2, 1]
		let y = [500.0, 400, 7000, 8500, 11000, 10500]
		let m = try slope(x, y)
		let b = try intercept(x, y)
		let mx = mean(x)
		let my = mean(y)
		#expect(close(m * mx + b, my, accuracy: 1e-9))
	}

	@Test("R^2 equals squared correlation for simple linear regression")
	func rSquared_equals_corr_squared() {
		let x = [1.0, 2.0, 3.0, 4.0, 5.0]
		let y = x.map { 2.0 * $0 + 1.0 } // perfect linear
		let r2 = rSquared(x, y)
		let r = correlationCoefficient(x, y, .sample)
		#expect(close(r2, r * r, accuracy: 1e-12))
		#expect(close(r2, 1.0, accuracy: 1e-12))
	}

	@Test("rSquared is within [0, 1]")
	func rSquared_bounds() {
		let x = [35.56, 43.44, 73.17, 113.0]
		let y = [44.783, 53.982, 92.141, 135.986]
		let r2 = rSquared(x, y)
		#expect(r2 >= -1e-12 && r2 <= 1.0 + 1e-12)
	}

	@Test("linearRegression function matches slope/intercept")
	func linearRegression_function_matches_parameters() throws {
		let x = [10.0, 8, 3, 3, 2, 1]
		let y = [500.0, 400, 7000, 8500, 11000, 10500]
		let f = try linearRegression(x, y)
		let m = try slope(x, y)
		let b = try intercept(x, y)

		let testX = 4.0
		let y1 = f(testX)
		let y2 = m * testX + b
		#expect(close(y1, y2, accuracy: 1e-9))
	}

	@Test("multiplyVectors throws on length mismatch")
	func multiplyVectors_length_mismatch_throws() {
		do {
				_ = try multiplyVectors([1.0, 2.0], [10.0])
				Issue.record("Expected ArrayError.mismatchedLengths")
			} catch let error as ArrayError {
				#expect(error == .mismatchedLengths)
			} catch {
				Issue.record("Expected ArrayError.mismatchedLengths, got \(error)")
			}
	}
}
