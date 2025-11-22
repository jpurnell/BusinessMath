//
//  binomialDescriptorTests.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Testing
import Numerics
@testable import BusinessMath

final class BinomialDescriptorTests: XCTestCase {

    public func testMeanBinomial() {
        XCTAssertEqual(meanBinomial(n: 1000, prob: 0.6) , 600)
    }
    
    public func teststdDevBinomial() {
        XCTAssertEqual(stdDevBinomial(n: 1000, prob: 0.6), Double.sqrt(1000 * 0.6 * 0.4))
    }
    
    public func testVarianceBinomial() {
        XCTAssertEqual(varianceBinomial(n: 1000, prob: 0.6), (1000 * (0.4) * (0.6)))
    }
}

@Suite("Binomial descriptors - Edge cases")
struct BinomialProperties {

	@Test("p = 0 and p = 1 edge cases")
	func p_zero_and_one() {
		let n = 10.0
		#expect(meanBinomial(n: Int(n), prob: 0.0) == 0.0)
		#expect(varianceBinomial(n: Int(n), prob: 0.0) == 0.0)
		#expect(stdDevBinomial(n: Int(n), prob: 0.0) == 0.0)

		#expect(meanBinomial(n: Int(n), prob: 1.0) == n)
		#expect(varianceBinomial(n: Int(n), prob: 1.0) == 0.0)
		#expect(stdDevBinomial(n: Int(n), prob: 1.0) == 0.0)
	}
}
