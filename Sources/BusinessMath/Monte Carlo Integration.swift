//
//  Monte Carlo Integration.swift
//
//
//  Created by Justin Purnell on 3/27/22.
//

import Foundation
import Numerics

///MARK: - Adapted from https:///www.cantorsparadise.com/demystifying-monto-carlo-integration-7c9bd0e37689
/// Estimates the integral of a function over a given range using the Monte Carlo method.
///
/// The Monte Carlo method uses random sampling to numerically estimate the value of an integral. In this implementation, the function is evaluated at uniformly distributed random points and the average value is used as the estimate of the integral.
///
/// - Parameters:
///	- f: The function to be integrated. The function should take a single parameter of type `T` and return a value of type `T`.
///	- n: The number of iterations to perform for the Monte Carlo estimation. A higher number of iterations generally leads to a more accurate estimate. Defaults to 10,000
///
/// - Returns: The estimated value of the integral.
///
/// - Note:
///   - The function `distributionUniform()` is assumed to generate uniformly distributed random values in the range (0, 1).
///   - The function `Double.random(in:)` is used to initialize the random seed.
///
/// - Example:
///   ```swift
///   let result = integrate({ x in x * x }, iterations: 10000)
///   print("Estimated integral: \(result)")
///   ```
///
/// - Requires:
///   - Implementation of the `distributionUniform()` function for generating uniformly distributed random values.
///
/// - Important:
///   - Ensure that the number of iterations `n` is sufficiently large to obtain a reliable estimation of the integral.
public func integrate<T: Real>(_ f: (T) -> T, iterations n: Int = 10000, seed: Double? = Double.random(in: 0...1)) -> T where T: BinaryFloatingPoint {
	let randomSeed = seed ?? Double.random(in: 0...1)
	var m = T(randomSeed)
    for i in 0..<n {
        m += ((f(distributionUniform()) - m)) / T((i + 1))
    }
    return m
}
