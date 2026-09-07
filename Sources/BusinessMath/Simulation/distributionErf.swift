//
//  distributionErf.swift
//  BusinessMath
//

import Foundation
import Numerics

/// An error-function distribution — a normal wearing a physicist's parameterisation.
///
/// Binds Risk Solver's `PsiErf(h)`. The single parameter `h` is an *inverse* scale:
/// larger `h` means a narrower distribution, which is the opposite of what a reader
/// expecting a standard deviation will assume, and is the only thing about this family
/// that catches anyone out.
///
/// ```swift
/// if let noise = DistributionErf(h: 2.5) {
///     print(noise.standardDeviation)   // 0.282842712475 — narrow, because h is large
/// }
/// ```
///
/// ## It is a normal
///
/// ```
/// σ = 1 / (h·√2)      centred at zero
/// ```
///
/// The name comes from writing the CDF with the error function, `½(1 + erf(h·x))`,
/// which is the same curve as `Φ(x/σ)` with that `σ`. There is no distinct
/// mathematics here, which is exactly why it delegates to ``DistributionNormal``
/// rather than restating it: a second normal that could disagree with the first about
/// its own tail is the failure this package's structure exists to prevent.
public struct DistributionErf: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The inverse scale. **Larger `h` gives a narrower distribution.**
	public let h: Double

	/// The equivalent normal, which owns the mathematics.
	private let normal: DistributionNormal

	/// Creates an error-function distribution.
	///
	/// - Parameter h: The inverse scale, strictly positive.
	/// - Returns: `nil` if `h` is not positive and finite. At `h = 0` the distribution
	///   has infinite spread and no density to sample from.
	public init?(h: Double) {
		guard h > 0, h.isFinite else { return nil }
		let root: Double = Double(2).squareRoot()
		let denominator: Double = h * root
		guard denominator > 0 else { return nil }
		self.h = h
		self.normal = DistributionNormal(0, 1 / denominator)
	}

	/// The standard deviation, `1/(h√2)`.
	public var standardDeviation: Double { normal.stdDev }

	/// The mean, which is zero: this family is centred by definition.
	public var mean: Double { 0 }

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double { normal.cdf(x) }

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile.
	public func quantile(_ p: Double) -> Double { normal.quantile(p) }
}
