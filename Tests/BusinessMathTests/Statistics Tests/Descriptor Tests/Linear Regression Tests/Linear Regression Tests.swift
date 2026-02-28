//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import Testing
import Numerics
@testable import BusinessMath


@Suite("LinearRegressionTests") struct LinearRegressionTests {

	@Test("Linear regression car age/price prediction")
	func testlinearRegression() throws {
		let carAge: [Double] = [10, 8, 3, 3, 2, 1]
		let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
		let linearRegressionFunction = try linearRegression(carAge, carPrice)
		let result = (linearRegressionFunction(4) * 1000).rounded(.up) / 1000
		#expect(abs(result - 6952.927) < 0.001)
	}
	
    @Test("MultiplyVectors") func LMultiplyVectors() throws {
        let values: [Double] = [1, 2, 3, 4, 5]
        let multipliers: [Double] = [10, 10, 10, 10, 10]
        let result = try multiplyVectors(values, multipliers)
        #expect(result == [10, 20, 30, 40, 50])
    }

    @Test("Slope") func LSlope() throws {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (try slope(carAge, carPrice) * 1000).rounded(.up) / 1000
        #expect(result == -1272.519)
    }
    
    @Test("Intercept") func LIntercept() throws {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (try intercept(carAge, carPrice) * 1000).rounded(.up) / 1000
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

@Suite("Linear Regression - NaN and Infinity Input Rejection")
struct LinearRegressionNaNInfinityTests {

	@Test("slope propagates NaN from x values")
	func slope_propagates_nan_from_x() throws {
		let x = [1.0, Double.nan, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = try? slope(x, y)
		#expect(result == nil || result!.isNaN)
	}

	@Test("slope propagates NaN from y values")
	func slope_propagates_nan_from_y() throws {
		let x = [1.0, 2.0, 3.0]
		let y = [2.0, Double.nan, 6.0]
		let result = try? slope(x, y)
		#expect(result == nil || result!.isNaN)
	}

	@Test("intercept propagates NaN from x values")
	func intercept_propagates_nan_from_x() throws {
		let x = [1.0, Double.nan, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = try? intercept(x, y)
		#expect(result == nil || result!.isNaN)
	}

	@Test("intercept propagates NaN from y values")
	func intercept_propagates_nan_from_y() throws {
		let x = [1.0, 2.0, 3.0]
		let y = [2.0, Double.nan, 6.0]
		let result = try? intercept(x, y)
		#expect(result == nil || result!.isNaN)
	}

	@Test("rSquared handles NaN inputs")
	func rSquared_handles_nan() {
		let x1 = [1.0, Double.nan, 3.0]
		let y1 = [2.0, 4.0, 6.0]
		let result1 = rSquared(x1, y1)
		#expect(result1.isNaN)

		let x2 = [1.0, 2.0, 3.0]
		let y2 = [2.0, Double.nan, 6.0]
		let result2 = rSquared(x2, y2)
		#expect(result2.isNaN)
	}

	@Test("linearRegression propagates NaN")
	func linearRegression_propagates_nan() throws {
		let x = [1.0, Double.nan, 3.0]
		let y = [2.0, 4.0, 6.0]

		do {
			let f = try linearRegression(x, y)
			let result = f(1.0)
			#expect(result.isNaN)
		} catch {
			// Function might throw on NaN input, which is also acceptable
		}
	}

	@Test("slope handles infinity")
	func slope_handles_infinity() throws {
		let x = [1.0, Double.infinity, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = try? slope(x, y)
		#expect(result == nil || result!.isInfinite || result!.isNaN)
	}

	@Test("intercept handles infinity")
	func intercept_handles_infinity() throws {
		let x = [1.0, 2.0, 3.0]
		let y = [2.0, Double.infinity, 6.0]
		let result = try? intercept(x, y)
		#expect(result == nil || result!.isInfinite || result!.isNaN)
	}

	@Test("rSquared handles infinity")
	func rSquared_handles_infinity() {
		let x = [1.0, Double.infinity, 3.0]
		let y = [2.0, 4.0, 6.0]
		let result = rSquared(x, y)
		#expect(result.isNaN || result.isInfinite)
	}
}

@Suite("Linear Regression - Stress Tests")
struct LinearRegressionStressTests {

	@Test("slope handles large datasets", .timeLimit(.minutes(1)))
	func slope_large_datasets() throws {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 + 3.0 }
		let result = try slope(x, y)
		#expect(result.isFinite)
		#expect(abs(result - 2.0) < 1e-6)
	}

	@Test("intercept handles large datasets", .timeLimit(.minutes(1)))
	func intercept_large_datasets() throws {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 + 3.0 }
		let result = try intercept(x, y)
		#expect(result.isFinite)
		#expect(abs(result - 3.0) < 1e-6)
	}

	@Test("rSquared handles large datasets", .timeLimit(.minutes(1)))
	func rSquared_large_datasets() {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 + 3.0 }
		let result = rSquared(x, y)
		#expect(result.isFinite)
		// Perfect linear relationship
		#expect(abs(result - 1.0) < 1e-10)
	}

	@Test("linearRegression handles large datasets", .timeLimit(.minutes(1)))
	func linearRegression_large_datasets() throws {
		let x = (1...100_000).map { Double($0) }
		let y = (1...100_000).map { Double($0) * 2.0 + 3.0 }
		let f = try linearRegression(x, y)

		// Test prediction
		let prediction = f(50_000)
		let expected = 50_000.0 * 2.0 + 3.0
		#expect(abs(prediction - expected) < 1e-6)
	}
}
