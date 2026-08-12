//
//  File.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics

/// Performs a Bernoulli trial and returns the outcome.
///
/// Bernoulli trials are experiments with exactly two possible outcomes, "success" and "failure", in which the probability of success is the same every time the experiment is conducted. In this function, success is encoded as `1`, and failure is encoded as `0`. The outcome is determined based on the provided probability of success (p).
///
/// - Parameter p: The probability of success for the Bernoulli trial. It should adhere to the `Real` type (a protocol in the Swift Standard Library defining a common API for all types that can represent real numbers).
///
/// - Returns: An `Int` representing the outcome of the Bernoulli trial (`1` for success, `0` for failure).
///
/// - Precondition: `p` must be a value between `0` and `1` (inclusive).
///
/// - Complexity: O(1), since it uses a constant number of operations.
///
///    let p = 0.5
///    let outcome = bernoulliTrial(p: p)
///    print(outcome)
///
/// Use this function when you're dealing with events that only have two possible outcomes, like tossing a coin, answering a true-or-false question, etc.
public func bernoulliTrial<T: Real>(p: T, seed: UInt64? = nil) -> Int {
    if let seed {
        var generator = DeterministicRNG(seed: seed)
        return bernoulliTrial(p: p, using: &generator)
    }
    var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
    return bernoulliTrial(p: p, using: &generator)
}

/// Performs a Bernoulli trial, drawing from `generator`.
///
/// The generator-parameterized form of ``bernoulliTrial(p:seed:)``, following the same
/// convention as ``integrate(_:iterations:using:)``: all randomness comes from the
/// caller's generator, so the caller owns reproducibility and can interleave this draw
/// with others on one stream.
///
/// - Parameters:
///   - p: Probability of success. Values at or below zero always fail; at or above one,
///     always succeed.
///   - generator: The random source for the draw.
/// - Returns: `1` on success, `0` on failure.
public func bernoulliTrial<T: Real, G: RandomNumberGenerator>(p: T, using generator: inout G) -> Int {
    // Fixed: Previous code `T(Int(Double.random(...) * 1e9 / 1e9))` always truncated to 0
    // because Int() truncates decimals. Now correctly compares random value to probability.
    //
    // Generate random integer in large range and compare scaled values.
    // This avoids floating-point precision issues and type conversion problems.
    let scale = 1_000_000_000
    let randomInt = Int.random(in: 0..<scale, using: &generator)
    let threshold = T(scale)  // Real has init from Int
    // p * scale compared to randomInt
    // If p * scale > randomInt, return success
    if p * threshold > T(randomInt) {
        return 1
    }
    return 0
}
