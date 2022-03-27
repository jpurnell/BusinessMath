//
//  binomialDescriptorTests.swift
//  
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
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
