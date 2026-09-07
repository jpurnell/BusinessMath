//
//  distributionPert.swift
//  BusinessMath
//

import Foundation
import Numerics

/// A PERT distribution: a three-point estimate that trusts the middle one.
///
/// The standard distribution for project risk. Someone gives you an optimistic case,
/// a most-likely case and a pessimistic case, and PERT turns those into a smooth
/// distribution over `[min, max]` — unlike a triangular, which puts a corner at the
/// mode and gives the extremes more weight than anyone intended.
///
/// Binds Risk Solver's `PsiPert(a, c, b)` — minimum, likely, maximum.
///
/// ```swift
/// // A task: 4 days if everything goes right, 6 most likely, 16 if it does not.
/// if let duration = DistributionPert(min: 4, likely: 6, max: 16) {
///     print(duration.mean)          // 7.333... — pulled toward the mode, not the midpoint
///     print(duration.quantile(0.9))
/// }
/// ```
///
/// ## The re-parameterisation
///
/// PERT is a Beta on `[min, max]` whose shapes come from where the mode sits:
///
/// ```
/// μ = (min + λ·likely + max) / (λ + 2)          λ = 4 by convention
/// α = (μ − min)(2·likely − min − max) / ((likely − μ)(max − min))
/// β = α(max − μ) / (μ − min)
/// ```
///
/// The `λ = 4` is what makes it PERT rather than any other Beta: it is the weight the
/// technique places on the modal estimate, and it is why the mean sits four-sixths of
/// the way toward the mode rather than at the midpoint of the range.
///
/// Where the mode is exactly central the general formula for `α` is `0/0`, and the
/// limit is `α = β = λ/2 + 1 = 3` — a symmetric Beta. Implemented as that limit rather
/// than special-cased, so a symmetric estimate gives a symmetric distribution because
/// the algebra says so.
///
/// **Built on ``DistributionBeta``, not beside it.** A second Beta that could disagree
/// with the first about its own tail is the failure this package's structure exists to
/// prevent.
public struct DistributionPert: ContinuousDistribution, Sendable {

	/// The numeric type produced by this distribution.
	public typealias T = Double

	/// The optimistic case — the lower bound of the support.
	public let min: Double

	/// The most likely case, strictly inside the range.
	public let likely: Double

	/// The pessimistic case — the upper bound of the support.
	public let max: Double

	/// The weight placed on the modal estimate. Four is the PERT convention.
	public let lambda: Double

	/// The underlying Beta on `[0, 1]`, which owns the mathematics.
	private let beta: DistributionBeta

	/// `max - min`, and its reciprocal, formed once beside the guard proving it
	/// positive so the hot paths multiply rather than divide.
	private let width: Double
	private let inverseWidth: Double

	/// Creates a PERT distribution from a three-point estimate.
	///
	/// - Parameters:
	///   - min: The optimistic case.
	///   - likely: The most likely case, strictly between `min` and `max`.
	///   - max: The pessimistic case.
	///   - lambda: The weight on the modal estimate. Defaults to 4, which is what
	///     makes this PERT; Risk Solver exposes no other value.
	/// - Returns: `nil` unless `min < likely < max` with every value finite, or if
	///   `lambda` is not positive. A mode on a bound is refused rather than nudged:
	///   the Beta shapes diverge there, and the distribution a nudge would produce is
	///   not the one that was asked for.
	public init?(min: Double, likely: Double, max: Double, lambda: Double = 4) {
		guard min.isFinite, likely.isFinite, max.isFinite else { return nil }
		guard min < likely, likely < max else { return nil }
		guard lambda > 0, lambda.isFinite else { return nil }

		let span: Double = max - min
		guard span > 0 else { return nil }

		// The PERT mean: the three estimates weighted λ : 1 : 1 on the mode.
		let weighted: Double = min + lambda * likely + max
		let divisor: Double = lambda + 2
		guard divisor > 0 else { return nil }
		let mu: Double = weighted / divisor

		let alpha: Double
        let betaShape: Double
		// The mode is central exactly when 2·likely == min + max, and there the general
		// formula is 0/0. Its limit is the symmetric Beta with both shapes λ/2 + 1.
		let centrality: Double = 2 * likely - min - max
		let offsetFromMean: Double = likely - mu
		if abs(offsetFromMean) < 1e-12 || abs(centrality) < 1e-12 {
			let symmetric: Double = lambda / 2 + 1
			alpha = symmetric
			betaShape = symmetric
		} else {
			let numerator: Double = (mu - min) * centrality
			let denominator: Double = offsetFromMean * span
			guard denominator != 0 else { return nil }
			let shape: Double = numerator / denominator
			guard shape > 0, shape.isFinite else { return nil }
			let lowerArm: Double = mu - min
			guard lowerArm > 0 else { return nil }
			let upperArm: Double = max - mu
			let paired: Double = shape * upperArm / lowerArm
			guard paired > 0, paired.isFinite else { return nil }
			alpha = shape
			betaShape = paired
		}

		self.min = min
		self.likely = likely
		self.max = max
		self.lambda = lambda
		self.width = span
		self.inverseWidth = 1 / span
		self.beta = DistributionBeta(alpha: alpha, beta: betaShape)
	}

	/// The first shape parameter of the underlying Beta.
	public var alpha: Double { beta.alpha }

	/// The second shape parameter of the underlying Beta.
	public var betaShape: Double { beta.beta }

	/// The mean, `(min + λ·likely + max) / (λ + 2)`.
	///
	/// Note this is *not* the midpoint of the range, and not the mode either: it sits
	/// four-sixths of the way from the midpoint toward the mode, which is the whole
	/// point of the technique.
	public var mean: Double {
		let weighted: Double = min + lambda * likely + max
		let divisor: Double = lambda + 2
		guard divisor > 0 else { return likely }
		return weighted / divisor
	}

	/// The probability that a draw falls at or below `x`.
	///
	/// - Parameter x: Any value. Outside `[min, max]` this returns 0 or 1.
	/// - Returns: A probability in [0, 1].
	public func cdf(_ x: Double) -> Double {
		guard x > min else { return 0 }
		guard x < max else { return 1 }
		let offset: Double = x - min
		let scaled: Double = offset * inverseWidth
		return beta.cdf(scaled)
	}

	/// The value below which a draw falls with probability `p`.
	///
	/// - Parameter p: A probability in the open interval (0, 1).
	/// - Returns: The quantile, inside `[min, max]`.
	public func quantile(_ p: Double) -> Double {
		guard p > 0 else { return min }
		guard p < 1 else { return max }
		let unit: Double = beta.quantile(p)
		let scaled: Double = unit * width
		return min + scaled
	}
}
