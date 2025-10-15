//
//  Bayes Tests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/17/25.
//

import Foundation
import Testing
import Numerics


@Suite("Bayes' Theorem Tests")
struct BayesTests {

	@Test("Basic test case")
	func basicTestCase() async throws {
		let probabilityD = 0.01
		let probabilityTGivenD = 0.99
		let probabilityTGivenNotD = 0.02
		
		let expectedResult = 0.3333333333333333
		
		let result = try await bayes(probabilityD: probabilityD, probabilityTrueGivenD: probabilityTGivenD, probabilityTrueGivenNotD: probabilityTGivenNotD) * 1000000.rounded() / 1000000.0
		
		#expect(result == expectedResult)
	}
	
}

func bayes(probabilityD: Double, probabilityTrueGivenD: Double, probabilityTrueGivenNotD: Double) async throws -> Double {
    let probabilityNotD = 1 - probabilityD
    let probabilityT = (probabilityD * probabilityTrueGivenD) + (probabilityNotD * probabilityTrueGivenNotD)
    let probabilityDGivenT = (probabilityD * probabilityTrueGivenD) / probabilityT
    return probabilityDGivenT
}
