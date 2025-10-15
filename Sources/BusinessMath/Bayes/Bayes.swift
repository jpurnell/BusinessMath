//
//  Bayes.swift
//  BusinessMath
//
//  Created by Justin Purnell on 9/17/25.
//

import Foundation
import Numerics

/// Calculates the posterior probability using Bayes' Theorem.
///
/// Bayes' Theorem calculates the probability of event D given that event T has occurred,
/// based on prior knowledge of conditions related to the events.
///
/// Formula: P(D|T) = [P(T|D) × P(D)] / [P(T|D) × P(D) + P(T|¬D) × P(¬D)]
///
/// - Parameters:
///   - probabilityD: The prior probability of event D occurring, P(D)
///   - probabilityTrueGivenD: The probability of observing T given that D is true, P(T|D)
///   - probabilityTrueGivenNotD: The probability of observing T given that D is false, P(T|¬D)
/// - Returns: The posterior probability of D given T, P(D|T)
///
/// - Example:
///   ```swift
///   // Medical test: 1% disease prevalence, 99% true positive rate, 2% false positive rate
///   let result = bayes(0.01, 0.99, 0.02)
///   // Result ≈ 0.333 or 33.3% chance of having the disease given a positive test
///   ```
public func bayes(_ probabilityD: Double, _ probabilityTrueGivenD: Double, _ probabilityTrueGivenNotD: Double) -> Double {
	let pNotD = 1 - probabilityD
	let pT = probabilityTrueGivenD * probabilityD + probabilityTrueGivenNotD * pNotD
	let probabilityDGivenT = (probabilityTrueGivenD * probabilityD) / pT
	return probabilityDGivenT
}
