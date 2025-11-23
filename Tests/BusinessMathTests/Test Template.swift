//
//  Test Template.swift
//
//
//  Created by Justin Purnell on 3/26/22.
//

//import Testing
//@testable import BusinessMath
//import func BusinessMath.npv   // disambiguates the free function
//
//@Suite("Subject Tests")
//struct SubjectTests {
//
//	@Test("NPV calculation")
//	func testNPV() {
//		let rate: Double = 0.08
//		let cashFlows: [Double] = [
//			-15, -200, -875, -875,
//			208.75, 208.75, 208.75, 208.75, 208.75, 208.75,
//			208.75, 208.75, 208.75, 208.75, 208.75, 208.75,
//			208.75, 208.75, 208.75, 208.75, 208.75, 208.75,
//			208.75, 208.75, 208.75, 208.75, 208.75, 208.75,
//			208.75, 208.75, 208.75
//		]
//
//		// Be explicit to avoid type-checker edge cases
//		let rawNPV: Double = npv(discountRate: rate, cashFlows: cashFlows)
//		let result = (rawNPV * 1000).rounded() / 1000
//
//		#expect(result == 167.133)
//	}
//}
