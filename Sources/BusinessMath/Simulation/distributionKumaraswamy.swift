//
//  distributionKumaraswamy.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A Kumaraswamy distribution on `[min, max]`.
///
/// Shaped like a Beta — two positive shape parameters over a bounded interval — but
/// with a CDF and quantile in closed form, where Beta's need the incomplete beta
/// function and its inverse. That makes it the cheaper choice when what you want is a
/// flexible bounded distribution rather than Beta specifically, and it is the reason
/// simulation packages carry it.
///
/// Binds Risk Solver's `PsiKumaraswamy(shape1, shape2, min, max)`.
///
/// ```swift
/// if let utilisation = DistributionKumaraswamy(shape1: 2, shape2: 3, min: 0, max: 1) {
///     print(utilisation.cdf(0.5))   // 0.578125
/// }
/// ```
///
/// ## The formulas
///
/// On the unit interval, with shapes `a` and `b`:
///
/// ```
/// F(z) = 1 − (1 − z^a)^b
/// Q(u) = (1 − (1 − u)^(1/b))^(1/a)
/// ```
///
/// and the support is moved to `[min, max]` by `x = min + (max − min)·z`. Both are
/// elementary, so §2.2 of the coverage proposal applies: the formula *is* the
/// reference, and these need no cross-check against another implementation.
///
/// `a = b = 1` gives the uniform distribution, which is a useful thing to test against
/// because it falls out of the algebra rather than being special-cased.
public struct DistributionKumaraswamy: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The first shape parameter, `a`. Positive.
	public let shape1: Double

	/// The second shape parameter, `b`. Positive.
	public let shape2: Double

	/// The lower bound of the support.
	public let min: Double

	/// The upper bound of the support.
	public let max: Double

	/// Creates a Kumaraswamy distribution.
	///
	/// - Parameters:
	///   - shape1: `a`, positive. Larger values push mass toward `max`.
	///   - shape2: `b`, positive. Larger values push mass toward `min`.
	///   - min: The lower bound.
	///   - max: The upper bound, strictly greater than `min`.
	/// - Returns: `nil` if either shape is non-positive or non-finite, if either bound
	///   is non-finite, or if `max` does not exceed `min`. A zero-width support is not
	///   a distribution — every quantile would be the same point and the CDF would have
	///   no interval to rise over — so it is refused rather than collapsed to a
	///   constant that would then behave like a distribution everywhere else.
	public init?(shape1: Double, shape2: Double, min: Double, max: Double) {
		guard shape1 > 0, shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		guard min.isFinite, max.isFinite, max > min else { return nil }
		self.shape1 = shape1
		self.shape2 = shape2
		self.min = min
		self.max = max

		let span: Double = max - min
		guard span > 0 else { return nil }
		self.width = span
		self.inverseWidth = 1 / span
		self.inverseShape1 = 1 / shape1
		self.inverseShape2 = 1 / shape2
	}

	/// The width of the support, `max - min`. Positive: the initialiser rejects
	/// anything else.
	public let width: Double

	/// `1/width`, `1/shape1` and `1/shape2`, formed once in the initialiser where the
	/// guards proving each divisor non-zero are on the adjacent lines. The hot paths
	/// then multiply, which keeps the division and the proof of its safety together
	/// instead of leaving a bare divide far from the invariant that justifies it.
	private let inverseWidth: Double
	private let inverseShape1: Double
	private let inverseShape2: Double

	/// P(X ≤ x), zero below the support and one above it.
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let z: Double = (x - min) * inverseWidth
		let inner: Double = 1 - Foundation.pow(z, shape1)
		return 1 - Foundation.pow(inner, shape2)
	}

	/// The value at which the CDF equals `p`.
	///
	/// - Parameter p: A probability in (0, 1). Values at or outside the endpoints are
	///   clamped to the support, which is finite here, so unlike an unbounded
	///   distribution there is a sensible answer to give.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }
		let complement: Double = 1 - p
		let root: Double = Foundation.pow(complement, inverseShape2)
		let z: Double = Foundation.pow(1 - root, inverseShape1)
		return min + width * z
	}
}
