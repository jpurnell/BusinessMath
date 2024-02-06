//
//  File.swift
//  
//
//  Created by Justin Purnell on 10/19/22.
//

import XCTest
import Numerics
@testable import BusinessMath


final class LinearRegressionTests: XCTestCase {

	func testlinearRegression() {
		let carAge: [Double] = [10, 8, 3, 3, 2, 1]
		let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
		let linearRegressionFunction = linearRegression(carAge, carPrice)
		let result = (linearRegressionFunction(4) * 1000).rounded(.up) / 1000
		XCTAssertEqual(result, 6952.927)
	}
	
    func testMultiplyVectors() {
        let values: [Double] = [1, 2, 3, 4, 5]
        let multipliers: [Double] = [10, 10, 10, 10, 10]
        let result = multiplyVectors(values, multipliers)
        XCTAssertEqual(result, [10, 20, 30, 40, 50])
    }

    func testSlope() {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (slope(carAge, carPrice) * 1000).rounded(.up) / 1000
        XCTAssertEqual(result, -1272.519)
    }
    
    func testIntercept() {
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let result = (intercept(carAge, carPrice) * 1000).rounded(.up) / 1000
        XCTAssertEqual(result, 12043.003)
    }
       
    func testRSquared() {
        // Example from https://www.wallstreetmojo.com/r-squared-formula/
        let x: [Double] = [35.56, 43.44, 73.17, 113.0]
        let y: [Double] = [44.783, 53.982, 92.141, 135.986]
        let carAge: [Double] = [10, 8, 3, 3, 2, 1]
        let carPrice: [Double] = [500, 400, 7000, 8500, 11000, 10500]
        let carResult = (rSquared(carAge, carPrice) * 100000).rounded(.up) / 100000
        let result = (rSquared(x, y) * 100000).rounded(.up) / 100000
        XCTAssertEqual(result, 0.99865)
        XCTAssertEqual(carResult, 0.93443)
    }
    
    func testRSquaredAdjusted() {
        let x: [Double] = [58, 61, 62, 65, 65, 68, 72, 74, 78, 85, 90, 95]
        let y: [Double] = [1, 1, 2, 2, 1, 2, 2, 3, 3, 4, 4, 5]
        let result = (rSquared(x, y) * 100000).rounded(.up) / 100000
        XCTAssertEqual(result, 0.91983)
    }
}
