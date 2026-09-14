//
//  Bayes Tests.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/17/25.
//

import Foundation
import Testing
import Numerics
import TestSupport  // identical(_:_:)
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

		// Expected value is 1/3 ≈ 0.333333...
		#expect(abs(result - 1.0 / 3.0) < 1e-6)
	}

	@Test("High prior probability")
	func highPriorProbability() {
		// When prior probability is high, posterior should also be high
		let probabilityD = 0.80
		let probabilityTrueGivenD = 0.90
		let probabilityTrueGivenNotD = 0.10

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// With high prior and good test, posterior should be very high
		// 36/37 exactly. `> 0.95` passes for 0.951 and for 0.999 alike.
		#expect(abs(result - 36.0 / 37.0) < 1e-15, "posterior was \(result)")
	}

	@Test("Perfect test accuracy")
	func perfectTestAccuracy() {
		// Perfect test: 100% sensitivity, 0% false positives
		let probabilityD = 0.10
		let probabilityTrueGivenD = 1.0
		let probabilityTrueGivenNotD = 0.0

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// Perfect test means positive result guarantees disease
		#expect(abs(result - 1.0) < 1e-6)
	}

	@Test("Low prior probability with imperfect test")
	func lowPriorImperfectTest() {
		// Rare disease (0.1%), decent test
		let probabilityD = 0.001
		let probabilityTrueGivenD = 0.95
		let probabilityTrueGivenNotD = 0.05

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// Even with positive test, posterior should be low due to low prior
		// The band 0.01–0.02 spans a factor of two on a posterior that has one value.
		#expect(abs(result - 0.018664047151277015) < 1e-15, "posterior was \(result)")
	}

	@Test("Symmetric case")
	func symmetricCase() {
		// Equal prior, symmetric test accuracy
		let probabilityD = 0.50
		let probabilityTrueGivenD = 0.80
		let probabilityTrueGivenNotD = 0.20

		let result = bayes(probabilityD, probabilityTrueGivenD, probabilityTrueGivenNotD)

		// With equal prior and symmetric test, posterior should be 0.8
		#expect(abs(result - 0.80) < 1e-9)
	}
}

/// The contract at the boundaries, and the property that catches a transposition.
///
/// The original five tests covered the ordinary cases and none of the ones that can
/// actually break. Two gaps in particular:
///
/// - **The zero denominator was never reached.** `perfectTestAccuracy` is named for the
///   degenerate case and exercises none of it: prior 0.10, sensitivity 1.0, FPR 0.0 gives
///   `P(T) = 0.1`, a perfectly ordinary number.
/// - **Nothing could detect a transposed sensitivity and false-positive rate.**
///   `symmetricCase` looks designed for it and is *invariant* under the swap — at prior
///   0.5 with s = 0.8 and f = 0.2 both orders give 0.8.
@Suite("Bayes' Theorem: contract and properties")
struct BayesContractTests {

	/// `P(T) = 0` only when no pathway to the observation exists.
	@Test("An impossible observation has no posterior")
	func degenerateDenominator() {
		// Prior 0 with no false positives, and a certain non-event: both give 0/0.
		#expect(bayes(0.0, 0.99, 0.0).isNaN)
		#expect(bayes(1.0, 0.0, 0.5).isNaN)

		// Neither of these is degenerate: the denominator is f·(1−p) and s·p respectively.
		#expect(identical(bayes(0.0, 0.99, 0.02), 0.0))
		#expect(identical(bayes(1.0, 0.99, 0.02), 1.0))
	}

	@Test("The checked form throws where the free form returns NaN")
	func checkedFormThrows() throws {
		#expect(throws: BusinessMathError.self) { _ = try bayesChecked(0.0, 0.99, 0.0) }
		#expect(throws: BusinessMathError.self) { _ = try bayesChecked(1.0, 0.0, 0.5) }

		// And it rejects arguments that are not probabilities at all.
		#expect(throws: BusinessMathError.self) { _ = try bayesChecked(1.5, 0.99, 0.02) }
		#expect(throws: BusinessMathError.self) { _ = try bayesChecked(0.01, -0.1, 0.02) }
		#expect(throws: BusinessMathError.self) { _ = try bayesChecked(Double.nan, 0.99, 0.02) }

		// Where both agree, they agree exactly.
		let checked = try bayesChecked(0.01, 0.99, 0.02)
		#expect(identical(checked, bayes(0.01, 0.99, 0.02)))
	}

	/// Posterior odds are prior odds times the likelihood ratio.
	///
	/// An algebraically distinct route to the same quantity, and — unlike the formula as
	/// written — **asymmetric in sensitivity and FPR**, so it fails at every point if the
	/// two are transposed. That is the property no existing test could check.
	@Test("Posterior odds are prior odds times the likelihood ratio")
	func posteriorOddsIdentity() {
		for (prior, sensitivity, fpr) in [(0.01, 0.99, 0.02), (0.3, 0.8, 0.15), (0.75, 0.6, 0.4)] {
			let posterior = bayes(prior, sensitivity, fpr)
			let priorOdds = prior / (1.0 - prior)
			let expected = priorOdds * (sensitivity / fpr)
			let posteriorOdds = posterior / (1.0 - posterior)
			let relative = abs(posteriorOdds - expected) / expected
			#expect(relative < 1e-13,
					"prior \(prior), s \(sensitivity), f \(fpr): odds \(posteriorOdds) against \(expected)")
		}
	}

	/// A test that carries no information returns the prior, for any prior.
	@Test("An uninformative test returns the prior")
	func uninformativeTestReturnsPrior() {
		for prior in [0.001, 0.05, 0.2, 0.5, 0.8, 0.999] {
			for rate in [0.1, 0.5, 0.9] {
				let posterior = bayes(prior, rate, rate)
				#expect(abs(posterior - prior) < 1e-15,
						"prior \(prior) with s = f = \(rate) gave \(posterior)")
			}
		}
	}

	/// With a test worth taking, a higher prior gives a higher posterior.
	@Test("The posterior increases with the prior when the test is informative")
	func monotoneInPrior() {
		let priors = stride(from: 0.05, through: 0.95, by: 0.05).map { $0 }
		var previous = -1.0
		for prior in priors {
			let posterior = bayes(prior, 0.9, 0.1)
			#expect(posterior > previous, "prior \(prior) gave \(posterior), not above \(previous)")
			previous = posterior
		}
	}

	/// The function is generic now, so the constraint has to hold at another width.
	@Test("The same identities hold in Float")
	func holdsInFloat() {
		let posterior: Float = bayes(Float(0.5), Float(0.8), Float(0.2))
		#expect(abs(posterior - 0.8) < 1e-6, "Float gave \(posterior)")
		#expect(bayes(Float(0.0), Float(0.99), Float(0.0)).isNaN)
	}
}
