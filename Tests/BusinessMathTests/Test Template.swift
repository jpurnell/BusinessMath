//
//  Test Template.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

import XCTest
import Numerics
@testable import BusinessMath

final class SubjectTests: XCTestCase {

    func testNPv() {
        let rate = 0.08
        let cashFlows = [-15,-200,-875,-875,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75,208.75]
        let result = (npv(discountRate: rate, cashFlows: cashFlows) * 1000).rounded() / 1000
        XCTAssertEqual(result, 167.133)
    }
}
