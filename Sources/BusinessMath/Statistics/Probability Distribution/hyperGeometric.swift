//
//  hyperGeometric.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

// MARK: - Hypergeometric Distribution: If a sample is selected without replacement from a known finite population and contains a relatively large proportion of the population, such that the probability of a success is measurably altered from one selection to the next, the hypergeometric distribution should be used.
// Assume a stable has total = 10 horses, and r = 4 of them have a contagious disesase, what is the probability of selecting a sample of n = 3 in which there are x = 2 diseased horses?
/// Calculates the probability mass function for a hypergeometric distribution.
///
/// The function computes the probability of getting exactly x successes (in statistical trials), given the population size (`total`), population success state size (`r`), and number of trials (`n`).

public func hypergeometric<T: Real>(total: Int, r: Int, n: Int, x: Int) -> T {
    return T(combination(r, c: x) * combination(total - r, c: n - x)) / T(combination(total, c: n))
}
