//
//  DistributionRandom.swift
//  BusinessMath
//
//  Created by Justin Purnell on 2/24/25.
//

import Numerics

/// Protocol for random number generators from probability distributions.
///
/// Types conforming to `DistributionRandom` generate random values following
/// a specific probability distribution (e.g., normal, uniform, exponential).
///
/// ## Usage
///
/// ```swift
/// let normal = DistributionNormal(mean: 0.0, stdDev: 1.0)
/// let sample = normal.next()  // Random value from N(0,1)
/// ```
///
/// ## Conforming Types
///
/// The library provides implementations for:
/// - `DistributionNormal`: Normal (Gaussian) distribution
/// - `DistributionUniform`: Uniform distribution
/// - `DistributionExponential`: Exponential distribution
/// - `DistributionTriangular`: Triangular distribution
/// - `DistributionLogNormal`: Log-normal distribution
/// - `DistributionGamma`: Gamma distribution
/// - And more...
///
/// ## Implementation Requirements
///
/// Conforming types must:
/// - Define an associated type `T` conforming to `Real`
/// - Implement `next()` to generate random values
///
/// ## Example Conformance
///
/// ```swift
/// struct CustomDistribution: DistributionRandom {
///     typealias T = Double
///
///     func next() -> Double {
///         // Generate random value from custom distribution
///         return myRandomAlgorithm()
///     }
/// }
/// ```
public protocol DistributionRandom {
	/// The numeric type for random values.
	associatedtype T: Real

	/// Generates the next random value from this distribution.
	///
	/// - Returns: A random value following the distribution's probability law
	func next() -> T
}
