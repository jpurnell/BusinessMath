//
//  poissonDistribution.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Poisson Distribution: Measures the probability of a random event happening over some interval of some time or space. Assumes two things: 1) Probability of the occurence is constant for any two intervals of time or space. 2) The occurence of the even in any interval is independent of the occurence in any other interval
/// Computes the Poisson probability for a given event.
///
/// The Poisson distribution expresses the probability of a given number of events occurring in a fixed interval of time or space, if these events occur with a constant mean rate and are independent of the time since the last event.
///
/// - Parameters:
///     - x: The number of successes that result from the experiment (non-negative).
///     - µ: The mean number of successes that occur in a specified region.
///
/// - Returns: The Poisson probability of observing exactly `x` occurrences in the interval.
///
/// - Precondition: `x` must be a non-negative integer and `µ` has to be a non-negative value.
/// - Complexity: O(n), where `n` is the value of `x`, due to the factorial operation.
///
///    let x = 5
///    let µ = 3.5
///    let result = poisson(x, µ: µ)
///    print(result)
///
/// Use this function when you need to model the number of times an event happened in a time interval.
public func poisson<T: Real>(_ x: Int, µ: T) -> T {
    let numerator = T.pow(µ, T(x)) * T.exp(-1 * µ)
    let denominator = x.factorial()
    return numerator / T(denominator)
}
