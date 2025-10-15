//
//  Bayes Tests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/17/25.
//

import Foundation
import Testing
import Numerics
@testable import BusinessMath

@Suite("Bayes' Theorem Tests")
struct BayesTests {

	@Test("Medical test with 1% disease prevalence")
	func medicalTestCase() {
		// Classic example: Disease has 1% prevalence
		// Test is 99% accurate for true positives (sensitivity)
		// Test has 2% false positive rate (1 - specificity)
		let probabilityD = 0.01
		let probabilityTrueGivenD = 0.99
		let probabilityTrueGivenNotD = 0.02

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// Round to 6 decimal places for comparison
		let roundedResult = (result * 1000000).rounded() / 1000000.0
		let expectedResult = 0.333333

		#expect(roundedResult == expectedResult)
	}

	@Test("High prior probability")
	func highPriorProbability() {
		// When prior probability is high, posterior should also be high
		let probabilityD = 0.80
		let probabilityTrueGivenD = 0.90
		let probabilityTrueGivenNotD = 0.10

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// With high prior and good test, posterior should be very high
		#expect(result > 0.95)
	}

	@Test("Perfect test accuracy")
	func perfectTestAccuracy() {
		// Perfect test: 100% sensitivity, 0% false positives
		let probabilityD = 0.10
		let probabilityTrueGivenD = 1.0
		let probabilityTrueGivenNotD = 0.0

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// Perfect test means positive result guarantees disease
		#expect(result == 1.0)
	}

	@Test("Low prior probability with imperfect test")
	func lowPriorImperfectTest() {
		// Rare disease (0.1%), decent test
		let probabilityD = 0.001
		let probabilityTrueGivenD = 0.95
		let probabilityTrueGivenNotD = 0.05

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// Even with positive test, posterior should be low due to low prior
		#expect(result < 0.02)
		#expect(result > 0.01)
	}

	@Test("Symmetric case")
	func symmetricCase() {
		// Equal prior, symmetric test accuracy
		let probabilityD = 0.50
		let probabilityTrueGivenD = 0.80
		let probabilityTrueGivenNotD = 0.20

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// With equal prior and symmetric test, posterior should be 0.8
		let roundedResult = (result * 100).rounded() / 100
		#expect(roundedResult == 0.80)
	}
}
