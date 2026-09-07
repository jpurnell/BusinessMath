//
//  distributionBetaGeneralised.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A Beta distribution over an arbitrary interval rather than `[0, 1]`.
///
/// The Beta's shape flexibility with the units the quantity is actually measured in.
/// Binds Risk Solver's `PsiBetaGen(alpha1, alpha2, a, b)`.
///
/// ```swift
/// if let utilisation = DistributionBetaGeneralised(shape1: 2, shape2: 3, min: 10, max: 30) {
///     print(utilisation.quantile(0.25))   // 14.860441675122
/// }
/// ```
///
/// **Built on ``DistributionBeta``.** The affine map is the whole of the difference,
/// and a second Beta that could disagree with the first about its own tail is the
/// failure this package's structure exists to prevent.
public struct DistributionBetaGeneralised: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The first shape parameter, `α > 0`.
	public let shape1: Double

	/// The second shape parameter, `β > 0`.
	public let shape2: Double

	/// The lower bound of the support.
	public let min: Double

	/// The upper bound of the support.
	public let max: Double

	/// The unit-interval Beta this scales.
	private let beta: DistributionBeta

	/// `max - min`, and its reciprocal, formed beside the guard proving it positive.
	private let width: Double
	private let inverseWidth: Double

	/// Creates a Beta over `[min, max]`.
	///
	/// - Parameters:
	///   - shape1: `α`, positive.
	///   - shape2: `β`, positive.
	///   - min: The lower bound.
	///   - max: The upper bound, strictly greater than `min`.
	/// - Returns: `nil` if either shape is non-positive, either bound is not finite, or
	///   the interval has no width. A zero-width support is not a distribution — every
	///   quantile would be the same point — so it is refused rather than collapsed.
	public init?(shape1: Double, shape2: Double, min: Double, max: Double) {
		guard shape1 > 0, shape1.isFinite, shape2 > 0, shape2.isFinite else { return nil }
		guard min.isFinite, max.isFinite, max > min else { return nil }
		let span: Double = max - min
		guard span > 0 else { return nil }
		self.shape1 = shape1
		self.shape2 = shape2
		self.min = min
		self.max = max
		self.width = span
		self.inverseWidth = 1 / span
		self.beta = DistributionBeta(alpha: shape1, beta: shape2)
	}

	/// The mean, `min + (max − min)·α/(α + β)`.
	public var mean: Double {
		let total: Double = shape1 + shape2
		guard total > 0 else { return min }
		let fraction: Double = shape1 / total
		return min + width * fraction
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value; outside `[min, max]` this returns 0 or 1.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let offset: Double = x - min
		return beta.cdf(offset * inverseWidth)
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, inside `[min, max]`.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }
		let unit: Double = beta.quantile(p)
		return min + unit * width
	}
}

/// A Beta fitted to a three-point estimate **and** a stated mean.
///
/// Where ``DistributionPert`` derives its mean from the estimate, this takes the mean
/// as given — which is what a modeller wants when they know the average outcome
/// separately from the most likely one, and the two disagree.
///
/// Binds Risk Solver's `PsiBetaSubj(a, c, mean, b)`.
///
/// ```swift
/// // Most likely 3, but experience says the average comes out at 4.
/// if let cost = DistributionBetaSubjective(min: 0, likely: 3, mean: 4, max: 10) {
///     print(cost.quantile(0.9))   // 7.107159771878
/// }
/// ```
///
/// ## Why the mean is constrained, not free
///
/// The shapes come from the same expression PERT uses, with the stated mean in place
/// of PERT's derived one:
///
/// ```
/// α = (mean − min)(2·likely − min − max) / ((likely − mean)(max − min))
/// β = α(max − mean) / (mean − min)
/// ```
///
/// Both must come out positive, and they do not for every combination a caller might
/// type: a mean on the wrong side of the mode, or too close to a bound, describes no
/// Beta at all. Those are refused rather than clamped, because the nearest Beta that
/// does exist is an answer to a question nobody asked.
public struct DistributionBetaSubjective: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The lower bound of the support.
	public let min: Double

	/// The most likely value.
	public let likely: Double

	/// The mean, as stated rather than as derived.
	public let mean: Double

	/// The upper bound of the support.
	public let max: Double

	/// The generalised Beta this resolves to.
	private let scaled: DistributionBetaGeneralised

	/// Creates a Beta from a three-point estimate and a stated mean.
	///
	/// - Parameters:
	///   - min: The lower bound.
	///   - likely: The most likely value, strictly inside the range.
	///   - mean: The mean, strictly inside the range.
	///   - max: The upper bound.
	/// - Returns: `nil` unless `min < likely < max`, `min < mean < max`, and the
	///   resulting shapes are both positive — which they are not for every
	///   combination. A mean and a mode that cannot belong to the same Beta is a
	///   contradiction in the estimate, not a rounding problem.
	public init?(min: Double, likely: Double, mean: Double, max: Double) {
		guard min.isFinite, likely.isFinite, mean.isFinite, max.isFinite else { return nil }
		guard min < likely, likely < max else { return nil }
		guard mean > min, mean < max else { return nil }

		let span: Double = max - min
		guard span > 0 else { return nil }
		let offsetFromMean: Double = likely - mean
		guard abs(offsetFromMean) > 1e-12 else { return nil }

		let centrality: Double = 2 * likely - min - max
		let numerator: Double = (mean - min) * centrality
		let denominator: Double = offsetFromMean * span
		guard denominator != 0 else { return nil }
		let alpha: Double = numerator / denominator
		guard alpha > 0, alpha.isFinite else { return nil }

		let lowerArm: Double = mean - min
		guard lowerArm > 0 else { return nil }
		let upperArm: Double = max - mean
		let betaShape: Double = alpha * upperArm / lowerArm
		guard betaShape > 0, betaShape.isFinite else { return nil }

		guard let built = DistributionBetaGeneralised(shape1: alpha, shape2: betaShape,
													  min: min, max: max) else { return nil }
		self.min = min
		self.likely = likely
		self.mean = mean
		self.max = max
		self.scaled = built
	}

	/// The first shape parameter of the underlying Beta.
	public var shape1: Double { scaled.shape1 }

	/// The second shape parameter of the underlying Beta.
	public var shape2: Double { scaled.shape2 }

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value; outside `[min, max]` this returns 0 or 1.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double { scaled.cdf(x) }

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, inside `[min, max]`.
	public func quantile(_ p: Double) -> Double { scaled.quantile(p) }
}
