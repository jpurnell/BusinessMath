//
//  distributionTriangular.swift
//  
//
//  Created by Justin Purnell on 3/21/22.
//

import Foundation
import Numerics
#if canImport(OSLog)
import OSLog
#endif

// Triangular Distribution function
// From https://en.wikipedia.org/wiki/Triangular_distribution#Generating_triangular-distributed_random_variates

/// Generates a random number from a triangular distribution over the interval [a, b] with mode at c.
///
/// The triangular distribution is a continuous probability distribution with lower limit `a`, upper limit `b`, and mode `c`.
/// It is often used in simulation because of its simplicity and computational efficiency.
///
/// - Parameters:
///   - a: The lower bound of the interval.
///   - b: The upper bound of the interval.
///   - c: The mode (most frequent value) of the distribution. It must be within the interval [a, b].
///   - uSeed: Random seed value in [0, 1] (default: newly generated)
/// - Returns: A random number generated from the triangular distribution between `a` and `b` with mode `c`.
///
/// - Note: The function uses the inverse transform sampling method to generate a random number from the triangular distribution. The method distinguishes between two cases based on the cumulative distribution function (CDF) of the triangular distribution:
///   \[ F(x) = \frac{(x - a)^2}{(b - a)(c - a)} \] when \( a \leq x \leq c \)
///   \[ F(x) = 1 - \frac{(b - x)^2}{(b - a)(b - c)} \] when \( c < x \leq b \)
///
/// - Example:
///   ```swift
///   let lowerBound: Double = 0.0
///   let upperBound: Double = 10.0
///   let mode: Double = 5.0
///   let randomValue: Double = triangularDistribution(low: lowerBound, high: upperBound, base: mode)
///   // randomValue will be a random number generated from the triangular distribution with parameters a = 0.0, b = 10.0, and c = 5.0

public func triangularDistribution<T: Real>(low a: T, high b: T, base c: T, _ uSeed: Double = Double.random(in: 0...1)) -> T {
    let fc = (c - a) / (b - a)
	// Convert Double seed to type T with high precision (6 decimal places)
	let uInt = Int(uSeed * 1_000_000)
	let u = T(uInt) / T(1_000_000)
    if u > 0 && u < fc {
        let s = u * (b - a) * (c - a)
        return a + sqrt(s)
    } else {
        let s = (1 - u) * (b - a) * (b - c)
        return b - sqrt(s)
    }
}

/// A triangular distribution generator for producing random values with a specified mode.
///
/// The triangular distribution is useful in simulation when you know the minimum, maximum,
/// and most likely value but don't have enough data for more complex distributions.
public struct DistributionTriangular: DistributionRandom, Sendable {
	let low: Double
	let high: Double
	let base: Double

	/// Creates a triangular distribution generator.
	/// - Parameters:
	///   - low: Lower bound of the distribution
	///   - high: Upper bound of the distribution
	///   - base: Mode (most likely value) within [low, high]
	public init(low: Double, high: Double, base: Double) {
		self.low = low
		self.high = high
		self.base = base
	}

	/// Generates a random value from the triangular distribution.
	/// - Returns: A random Double from the triangular distribution
	public func random() -> Double {
		triangularDistribution(low: low, high: high, base: base)
	}

	/// Generates the next random value from the triangular distribution.
	/// - Returns: A random Double from the triangular distribution
	public func next() -> Double {
		return random()
	}
}
