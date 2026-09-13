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
/// ## When the evidence is impossible
///
/// The denominator `P(T)` is zero exactly when no pathway to the observation exists —
/// `bayes(0, s, 0)` and `bayes(1, 0, f)`. The posterior is then genuinely undefined, and
/// this returns `nan` rather than inventing a probability. That follows the package's
/// convention for a free function; ``bayesChecked(_:_:_:)`` is the throwing companion,
/// in the shape of `factorial` and `factorialChecked`.
///
/// A zero prior with a non-zero false-positive rate is **not** degenerate: the denominator
/// is `f·(1−p)`, and the posterior is exactly 0. Likewise `bayes(1, s, f)` is exactly 1.
///
/// - Note: this used to be `Double`-only, against the package's rule that numeric
///   functions are generic over `T: Real`.
public func bayes<T: Real>(_ probabilityD: T, _ probabilityTrueGivenD: T, _ probabilityTrueGivenNotD: T) -> T {
	let pNotD = T(1) - probabilityD
	let pT = probabilityTrueGivenD * probabilityD + probabilityTrueGivenNotD * pNotD
	// No guard: `0/0` is `nan`, which is the honest answer for an impossible observation,
	// and every other case divides normally. See the note above.
	let probabilityDGivenT = (probabilityTrueGivenD * probabilityD) / pT
	return probabilityDGivenT
}

/// The posterior probability, refusing inputs that are not probabilities or admit no
/// evidence pathway.
///
/// The checked half of the pair. ``bayes(_:_:_:)`` returns `nan` where this throws, which
/// is the same division of labour as `factorial` and `factorialChecked`: reach for this
/// one when a bad prior deep in a decision model would be hard to trace back from a `nan`.
///
/// - Parameters:
///   - probabilityD: The prior probability of `D`, in `[0, 1]`.
///   - probabilityTrueGivenD: `P(T|D)`, in `[0, 1]`.
///   - probabilityTrueGivenNotD: `P(T|¬D)`, in `[0, 1]`.
/// - Returns: The posterior probability of `D` given `T`.
/// - Throws: ``BusinessMathError/invalidInput(message:value:expectedRange:)`` if any
///   argument is outside `[0, 1]` or is not a number;
///   ``BusinessMathError/divisionByZero(context:)`` when no evidence pathway exists, so
///   that `P(T)` is zero and the posterior is undefined.
public func bayesChecked<T: Real>(
	_ probabilityD: T,
	_ probabilityTrueGivenD: T,
	_ probabilityTrueGivenNotD: T
) throws -> T {
	let named: [(String, T)] = [
		("probabilityD", probabilityD),
		("probabilityTrueGivenD", probabilityTrueGivenD),
		("probabilityTrueGivenNotD", probabilityTrueGivenNotD)
	]
	for (name, value) in named {
		guard !value.isNaN, value >= T(0), value <= T(1) else {
			throw BusinessMathError.invalidInput(
				message: "\(name) must be a probability",
				value: "\(value)",
				expectedRange: "0 ... 1"
			)
		}
	}

	let pNotD = T(1) - probabilityD
	let pT = probabilityTrueGivenD * probabilityD + probabilityTrueGivenNotD * pNotD
	guard pT > T(0) else {
		throw BusinessMathError.divisionByZero(
			context: "P(T) is zero: no evidence pathway exists, so the posterior is undefined"
		)
	}
	return (probabilityTrueGivenD * probabilityD) / pT
}
