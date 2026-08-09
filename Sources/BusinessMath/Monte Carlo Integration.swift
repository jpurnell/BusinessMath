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
///	- seed: Seed for the deterministic generator. Passing the same seed with the
///	  same `f` and `n` reproduces the estimate exactly. `nil` (the default) draws
///	  from system entropy, so the estimate differs run to run.
/// - Returns: The estimated value of the integral.
///
/// - Note:
///   - Sampling runs through ``DeterministicRNG`` (`xoshiro256**`), the same generator
///     ``MonteCarloSimulation`` uses for seeded CPU runs, so a seed reproduces across
///     platforms and runs.
///   - Estimates are means over `n` samples: seeded and unseeded runs follow the same
///     probability law and both converge on the true integral.
///
/// - Example:
///   ```swift
///   let result = integrate({ x in x * x }, iterations: 10000, seed: 42)
///   print("Estimated integral: \(result)")   // same value on every run
///   ```
///
/// - Important:
///   - Ensure that the number of iterations `n` is sufficiently large to obtain a reliable estimation of the integral.
public func integrate<T: Real>(_ f: (T) -> T, iterations n: Int = 10000, seed: UInt64? = nil) -> T where T: BinaryFloatingPoint {
	if let seed {
		var generator = DeterministicRNG(seed: seed)
		return integrate(f, iterations: n, using: &generator)
	}
	var generator = SystemRandomNumberGenerator() // stochastic:exempt — the documented unseeded path; pass `seed:` for reproducibility
	return integrate(f, iterations: n, using: &generator)
}

/// Estimates the integral of a function over [0, 1], drawing every sample from `generator`.
///
/// The generator-parameterized form of ``integrate(_:iterations:seed:)``, following the
/// same convention as ``SeedableDistribution/next(using:)``: all randomness comes from the
/// caller's generator, so the caller owns reproducibility and can interleave this estimate
/// with other draws on one stream.
///
/// - Parameters:
///   - f: The function to be integrated.
///   - n: The number of samples to draw. Values of zero or less return zero.
///   - generator: The random source for the uniform draws.
/// - Returns: The estimated value of the integral — the running mean of `f` over `n`
///   uniform samples, which is unbiased for any `n >= 1`.
///
/// - Example:
///   ```swift
///   var rng = SplitMix64(seed: 42)
///   let result: Double = integrate({ $0 * $0 }, iterations: 100_000, using: &rng)
///   ```
public func integrate<T: Real, G: RandomNumberGenerator>(_ f: (T) -> T, iterations n: Int = 10000, using generator: inout G) -> T where T: BinaryFloatingPoint {
	guard n > 0 else { return T(0) }
	// Welford running mean: m starts at zero so the estimate is the plain average of the
	// samples. Seeding m with a random value — as this once did — biases the result by
	// that value divided by n.
	var m = T(0)
	for i in 0..<n {
		let sample: T = distributionUniform(Double.random(in: 0..<1, using: &generator))
		m += (f(sample) - m) / T(i + 1) // fp-safety:disable — i + 1 >= 1
	}
	return m
}
