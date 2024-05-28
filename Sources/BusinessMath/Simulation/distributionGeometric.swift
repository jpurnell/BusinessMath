//
//  distributionGeometric.swift
//  
//
//  Created by Justin Purnell on 5/18/24.
//

import Foundation
import Numerics


// From https://personal.utdallas.edu/~pankaj/3341/SP07/NOTES/lecture_week_8.pdf

/// Generates a random number from a geometric distribution with success probability `p`.
///
/// The geometric distribution models the number of trials needed to get the first success in a sequence of independent Bernoulli trials.
/// It is a discrete probability distribution with parameter `p`, where `p` is the probability of success on each trial.
///
/// - Parameters:
///   - p: The probability of success on each trial. It should be a value between 0 and 1.
/// - Returns: A random number generated from the geometric distribution with success probability `p`.
///
/// - Note: The function generates random numbers using a uniform random number generator to simulate Bernoulli trials until the first success occurs.
///         Make sure to seed the random number generator appropriately when using `distributionUniform()`.
///
/// - Example:
///   ```swift
///   let probabilityOfSuccess: Double = 0.5
///   let randomValue: Double = distributionGeometric(probabilityOfSuccess)
///   // randomValue will be a random number generated from the geometric distribution with parameter p = 0.5
public func distributionGeometric<T: Real>(_ p: T) -> T {
	var x: T = T(0)
	var u: T = distributionUniform()
	while u <= p {
		x = x + 1
	}
	return x
}
