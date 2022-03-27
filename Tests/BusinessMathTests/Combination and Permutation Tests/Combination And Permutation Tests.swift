//
//  Combination And Permutation Tests.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class CombinationAndPermutationTests: XCTestCase {
    func testFactorial() {
        let result = factorial(4)
        let resultZero = factorial(0)
        let resultOne = factorial(1)
        let resultExtension = 5.factorial()
        XCTAssertEqual(result, 24)
        XCTAssertEqual(resultZero, 1)
        XCTAssertEqual(resultOne, 1)
        XCTAssertEqual(resultExtension, 120)
    }
    
    func testCombination() {
        let result = combination(10, c: 3)
        XCTAssertEqual(result, 120)
    }
    
    func testPermutation() {
        let result = permutation(5, p: 3)
        XCTAssertEqual(result, 60)
    }
}
