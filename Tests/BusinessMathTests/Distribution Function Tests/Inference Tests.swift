//
//  Inference Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class InferenceTests: XCTestCase {

    func testConfidence() {
        let result = (confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high * 1000000.0).rounded(.up) / 1000000.0
        XCTAssertEqual(result, 0.692952)
    }

    func testpValueOfZTest() {
        print("\(#function) incomplete")
    }
}
