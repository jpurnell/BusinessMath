//
//  Inference Tests.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import OSLog
import Numerics
@testable import BusinessMath

final class InferenceTests: XCTestCase {
	let inferenceTestLogger = Logger(subsystem: "Business Math > Tests > BusinessMathTests > Distribution Tests", category: "Inference Tests")

    func testConfidence() {
        let result = (confidence(alpha: 0.05, stdev: 2.5, sampleSize: 50).high * 1000000.0).rounded(.up) / 1000000.0
        XCTAssertEqual(result, 0.692952)
    }

    func testpValueOfZTest() {
		inferenceTestLogger.error("Test not implemented for \(self.name, privacy: .public)")
    }
}
