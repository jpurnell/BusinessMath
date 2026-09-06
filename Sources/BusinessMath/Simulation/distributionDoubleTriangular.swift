//
//  distributionDoubleTriangular.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A double triangular distribution: two triangular pieces meeting at the mode, with
/// the probability mass on each side stated rather than implied.
///
/// Binds Risk Solver's `PsiDblTriang(min, likely, max, p)`.
///
/// ```swift
/// if let cost = DistributionDoubleTriangular(min: 0, likely: 4, max: 10, p: 0.7) {
///     print(cost.cdf(4))   // 0.7 — the mode sits at the stated 70th percentile
/// }
/// ```
///
/// ## What `p` buys, and why the density jumps
///
/// An ordinary triangular distribution fixes the mass below the mode: it is
/// `(likely − min)/(max − min)`, whatever you wanted it to be. For the example above
/// that would be 40%, and an estimator who believes the mode is also the 70th
/// percentile has no way to say so.
///
/// `p` says it. The consequence is that the two triangles have different heights where
/// they meet — the lower piece rises to `2p/(likely − min)` and the upper piece starts
/// from `2(1 − p)/(max − likely)` — so **the density is discontinuous at the mode**
/// unless `p` happens to equal the ordinary triangular's value. That jump is the point
/// of the distribution, not a defect in it. The CDF stays continuous throughout.
///
/// ## The formulas
///
/// ```
/// F(x) = p·((x − min)/(likely − min))²                      for min ≤ x ≤ likely
/// F(x) = p + (1 − p)·(1 − ((max − x)/(max − likely))²)      for likely ≤ x ≤ max
///
/// Q(u) = min + (likely − min)·√(u/p)                        for u ≤ p
/// Q(u) = max − (max − likely)·√((1 − u)/(1 − p))            for u > p
/// ```
///
/// Both branches agree at the mode, which is what keeps the CDF continuous: the first
/// gives `p` and the second gives `p` too.
public struct DistributionDoubleTriangular: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support.
	public let min: Double

	/// The mode, where the two triangles meet. Strictly inside the support.
	public let likely: Double

	/// The upper bound of the support.
	public let max: Double

	/// The probability mass below the mode — equivalently, the percentile the mode
	/// sits at. Strictly between zero and one.
	public let p: Double

	/// Creates a double triangular distribution.
	///
	/// - Parameters:
	///   - min: The lower bound.
	///   - likely: The mode. Must lie strictly between `min` and `max`.
	///   - max: The upper bound.
	///   - p: The probability mass below the mode, strictly in (0, 1).
	/// - Returns: `nil` unless `min < likely < max` and `0 < p < 1`, with all four
	///   finite. The strict inequalities are not fussiness: `likely == min` with
	///   `p > 0` asks for positive mass in an interval of zero width, and `p == 0`
	///   asks for a triangle with no area but a real base. Both divide by zero in the
	///   quantile, so they are refused at construction rather than producing an
	///   infinity later, far from the cause.
	public init?(min: Double, likely: Double, max: Double, p: Double) {
		guard min.isFinite, likely.isFinite, max.isFinite, p.isFinite else { return nil }
		guard min < likely, likely < max else { return nil }
		guard p > 0, p < 1 else { return nil }
		self.min = min
		self.likely = likely
		self.max = max
		self.p = p

		// Every divisor the two branches need, formed here where the guards above
		// prove each one positive: the mode is strictly inside the support, and p is
		// strictly inside the unit interval.
		self.inverseLowerSpan = 1 / (likely - min)
		self.inverseUpperSpan = 1 / (max - likely)
		self.inverseP = 1 / p
		self.inverseComplement = 1 / (1 - p)
	}

	/// `1/(likely − min)`, positive because the mode is strictly above `min`.
	private let inverseLowerSpan: Double

	/// `1/(max − likely)`, positive because the mode is strictly below `max`.
	private let inverseUpperSpan: Double

	/// `1/p`, finite because `p` is strictly positive.
	private let inverseP: Double

	/// `1/(1 − p)`, finite because `p` is strictly below one.
	private let inverseComplement: Double

	/// P(X ≤ x), zero below the support and one above it.
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }

		if x <= likely {
			let fraction: Double = (x - min) * inverseLowerSpan
			return p * fraction * fraction
		}
		let remaining: Double = (max - x) * inverseUpperSpan
		let filled: Double = 1 - remaining * remaining
		return p + (1 - p) * filled
	}

	/// The value at which the CDF equals `pr`.
	///
	/// - Parameter pr: A probability. Values at or outside the endpoints clamp to the
	///   support, which is finite here.
	public func quantile(_ pr: Double) -> Double {
		guard pr > 0 else { return min }
		guard pr < 1 else { return max }

		if pr <= p {
			let fraction: Double = pr * inverseP
			return min + (likely - min) * fraction.squareRoot()
		}
		let fraction: Double = (1 - pr) * inverseComplement
		return max - (max - likely) * fraction.squareRoot()
	}
}
